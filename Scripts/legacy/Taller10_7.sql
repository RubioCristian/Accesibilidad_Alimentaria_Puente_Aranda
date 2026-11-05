
SELECT
    (SELECT COUNT(*)
     FROM movilidad.andenes a
     WHERE EXISTS (
         SELECT 1
         FROM territorio.area_estudio e
         WHERE ST_Intersects(a.geom, e.geom)
     )) AS andenes_objetivo,

    (SELECT COUNT(*)
     FROM movilidad.ejes_andenes x
     JOIN movilidad.andenes a
       ON a.objectid = x.objectid_anden
     WHERE EXISTS (
         SELECT 1
         FROM territorio.area_estudio e
         WHERE ST_Intersects(a.geom, e.geom)
     )) AS andenes_procesados;


WITH pendientes AS (
    SELECT a.objectid, a.geom
    FROM movilidad.andenes a
    WHERE ST_Intersects(
        a.geom,
        (SELECT geom
         FROM territorio.area_estudio
         LIMIT 1)
    )
    AND NOT EXISTS (
        SELECT 1
        FROM movilidad.ejes_andenes x
        WHERE x.objectid_anden = a.objectid
    )
    ORDER BY a.objectid
    LIMIT 25
),
ejes AS (
    SELECT
        objectid,
        ST_Multi(
            ST_CollectionExtract(
                CG_ApproximateMedialAxis(geom), 2
            )
        )::geometry(MultiLineString, 9377) AS geom
    FROM pendientes
)
INSERT INTO movilidad.ejes_andenes (
    objectid_anden, geom
)
SELECT objectid, geom
FROM ejes
WHERE NOT ST_IsEmpty(geom)
ON CONFLICT (objectid_anden) DO NOTHING
RETURNING objectid_anden;


SELECT
    COUNT(*) AS andenes_convertidos,
    SUM(ST_NumGeometries(geom)) AS ramas,
    COUNT(*) FILTER (
        WHERE NOT ST_IsValid(geom)
    ) AS invalidos,
    COUNT(*) FILTER (
        WHERE ST_IsEmpty(geom)
    ) AS vacios
FROM movilidad.ejes_andenes;



SELECT
    r.status AS codigo_http,
    (r.content::jsonb ->> 'count')::integer
        AS lotes_disponibles
FROM http_get(
    'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/catastro/lote/MapServer/0/query'
    || '?where=1%3D1'
    || '&geometry=-74.1270%2C4.6170%2C-74.1100%2C4.6312'
    || '&geometryType=esriGeometryEnvelope'
    || '&inSR=4326'
    || '&spatialRel=esriSpatialRelIntersects'
    || '&returnCountOnly=true'
    || '&f=json'
) AS r;


WITH codigos AS (
    SELECT STRING_AGG(
        QUOTE_LITERAL(mancodigo), ','
    ) AS lista
    FROM (
        SELECT DISTINCT mancodigo
        FROM territorio.v_manzanas_estudio
        WHERE mancodigo IS NOT NULL
    ) m
),
consulta AS (
    SELECT http_get(
        'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/catastro/lote/MapServer/0/query'
        || '?where='
        || replace(
            'MANZCODIGO IN (' || lista || ')',
            ' ', '%20'
        )
        || '&returnCountOnly=true'
        || '&f=json'
    ) AS r
    FROM codigos
)
SELECT
    (r).status AS codigo_http,
    ((r).content::jsonb ->> 'count')::integer
        AS lotes_seleccionados,
    (r).content::jsonb ? 'error' AS error_servicio
FROM consulta;


CREATE TABLE IF NOT EXISTS staging.lotes_ids (
    objectid BIGINT PRIMARY KEY
);

WITH codigos AS (
    SELECT STRING_AGG(
        '%27' || mancodigo || '%27',
        '%2C'
    ) AS lista
    FROM (
        SELECT DISTINCT mancodigo
        FROM territorio.v_manzanas_estudio
        WHERE mancodigo IS NOT NULL
    ) m
),
respuesta AS (
    SELECT http_post(
        'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/catastro/lote/MapServer/0/query',
        'where=MANZCODIGO%20IN%20(' || lista || ')'
        || '&returnIdsOnly=true'
        || '&f=json',
        'application/x-www-form-urlencoded'
    ) AS r
    FROM codigos
)
INSERT INTO staging.lotes_ids (objectid)
SELECT
    jsonb_array_elements_text(
        (r).content::jsonb -> 'objectIds'
    )::bigint
FROM respuesta
WHERE (r).status = 200
  AND NOT ((r).content::jsonb ? 'error')
ON CONFLICT (objectid) DO NOTHING;


SELECT COUNT(*) AS lotes_identificados
FROM staging.lotes_ids;


CREATE TABLE IF NOT EXISTS staging.lotes_respuestas (
    lote INTEGER PRIMARY KEY,
    codigo_http INTEGER,
    contenido JSONB,
    fecha_descarga TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


WITH ids AS (
    SELECT STRING_AGG(objectid::text, ',' ORDER BY objectid) AS lista
    FROM (
        SELECT objectid
        FROM staging.lotes_ids
        ORDER BY objectid
        LIMIT 100
    ) t
),
respuesta AS (
    SELECT http_post(
        'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/catastro/lote/MapServer/0/query',
        'objectIds=' || lista
        || '&outFields=*'
        || '&returnGeometry=true'
        || '&outSR=4326'
        || '&f=json',
        'application/x-www-form-urlencoded'
    ) AS r
    FROM ids
)
INSERT INTO staging.lotes_respuestas (
    lote, codigo_http, contenido
)
SELECT
    1,
    (r).status,
    (r).content::jsonb
FROM respuesta
ON CONFLICT (lote)
DO UPDATE SET
    codigo_http = EXCLUDED.codigo_http,
    contenido = EXCLUDED.contenido,
    fecha_descarga = CURRENT_TIMESTAMP
RETURNING
    lote,
    codigo_http,
    jsonb_array_length(
        COALESCE(contenido -> 'features', '[]'::jsonb)
    ) AS lotes_descargados,
    contenido ? 'error' AS error_servicio;


CREATE OR REPLACE PROCEDURE staging.descargar_lotes(
    lote_inicial INTEGER,
    lote_final INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    n INTEGER;
    lista_ids TEXT;
    respuesta http_response;
    datos JSONB;
    cantidad INTEGER;
BEGIN
    FOR n IN lote_inicial..lote_final LOOP

        SELECT STRING_AGG(
            objectid::text, ',' ORDER BY objectid
        )
        INTO lista_ids
        FROM (
            SELECT
                objectid,
                ROW_NUMBER() OVER (
                    ORDER BY objectid
                ) AS fila
            FROM staging.lotes_ids
        ) t
        WHERE fila BETWEEN (n - 1) * 100 + 1
                       AND n * 100;

        IF lista_ids IS NULL THEN
            EXIT;
        END IF;

        SELECT *
        INTO respuesta
        FROM http_post(
            'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/catastro/lote/MapServer/0/query',
            'objectIds=' || lista_ids
            || '&outFields=*'
            || '&returnGeometry=true'
            || '&outSR=4326'
            || '&f=json',
            'application/x-www-form-urlencoded'
        );

        IF respuesta.status <> 200 THEN
            RAISE EXCEPTION
                'Error HTTP en lote %: %',
                n, respuesta.status;
        END IF;

        datos := respuesta.content::jsonb;

        IF datos ? 'error'
           OR jsonb_typeof(datos -> 'features') IS DISTINCT FROM 'array'
        THEN
            RAISE EXCEPTION 'Respuesta inválida en lote %', n;
        END IF;

        cantidad := jsonb_array_length(datos -> 'features');

        IF cantidad <> array_length(
            string_to_array(lista_ids, ','), 1
        ) THEN
            RAISE EXCEPTION
                'Lote % incompleto: % registros',
                n, cantidad;
        END IF;

        INSERT INTO staging.lotes_respuestas (
            lote, codigo_http, contenido
        )
        VALUES (n, respuesta.status, datos)
        ON CONFLICT (lote)
        DO UPDATE SET
            codigo_http = EXCLUDED.codigo_http,
            contenido = EXCLUDED.contenido,
            fecha_descarga = CURRENT_TIMESTAMP;

        RAISE NOTICE
            'Lote %: % registros guardados',
            n, cantidad;

        COMMIT;
    END LOOP;
END;
$$;



CALL staging.descargar_lotes(2, 6);

SELECT
    COUNT(*) AS lotes_descargados,
    SUM(
        jsonb_array_length(contenido -> 'features')
    ) AS registros_descargados
FROM staging.lotes_respuestas;



CALL staging.descargar_lotes(7, 12);
CALL staging.descargar_lotes(13, 18);
CALL staging.descargar_lotes(19, 24);


SELECT
    COUNT(*) AS lotes_descargados,
    SUM(
        jsonb_array_length(contenido -> 'features')
    ) AS registros_descargados,
    COUNT(*) FILTER (
        WHERE codigo_http <> 200
           OR contenido ? 'error'
    ) AS lotes_con_error
FROM staging.lotes_respuestas;


CREATE TABLE IF NOT EXISTS staging.lotes (
    objectid BIGINT PRIMARY KEY,
    atributos JSONB,
    geom geometry(MultiPolygon, 4326)
);


WITH elementos AS (
    SELECT
        jsonb_array_elements(
            contenido -> 'features'
        ) AS elemento
    FROM staging.lotes_respuestas
    WHERE codigo_http = 200
      AND NOT (contenido ? 'error')
),
anillos AS (
    SELECT
        (e.elemento -> 'attributes' ->> 'OBJECTID')::bigint
            AS objectid,
        e.elemento -> 'attributes' AS atributos,
        ST_SetSRID(
            ST_GeomFromGeoJSON(
                jsonb_build_object(
                    'type', 'LineString',
                    'coordinates', r.anillo
                )::text
            ),
            4326
        ) AS linea
    FROM elementos e
    CROSS JOIN LATERAL jsonb_array_elements(
        e.elemento -> 'geometry' -> 'rings'
    ) AS r(anillo)
    WHERE e.elemento -> 'geometry' -> 'rings'
          IS NOT NULL
),
poligonos AS (
    SELECT
        objectid,
        MAX(atributos::text)::jsonb AS atributos,
        ST_Multi(
            ST_CollectionExtract(
                ST_BuildArea(ST_Collect(linea)),
                3
            )
        )::geometry(MultiPolygon, 4326) AS geom
    FROM anillos
    GROUP BY objectid
)
INSERT INTO staging.lotes (
    objectid,
    atributos,
    geom
)
SELECT objectid, atributos, geom
FROM poligonos
ON CONFLICT (objectid)
DO UPDATE SET
    atributos = EXCLUDED.atributos,
    geom = EXCLUDED.geom;

SELECT
    COUNT(*) AS total_lotes,
    COUNT(DISTINCT objectid) AS identificadores_unicos,
    COUNT(*) FILTER (
        WHERE geom IS NULL
    ) AS geometrias_nulas,
    COUNT(*) FILTER (
        WHERE ST_IsEmpty(geom)
    ) AS geometrias_vacias,
    COUNT(*) FILTER (
        WHERE NOT ST_IsValid(geom)
    ) AS geometrias_invalidas,
    MIN(ST_SRID(geom)) AS srid_minimo,
    MAX(ST_SRID(geom)) AS srid_maximo
FROM staging.lotes;



CREATE TABLE IF NOT EXISTS territorio.lotes (
    objectid BIGINT PRIMARY KEY,
    codigo_lote TEXT,
    codigo_manzana TEXT,
    geom geometry(MultiPolygon, 9377)
);

INSERT INTO territorio.lotes (
    objectid,
    codigo_lote,
    codigo_manzana,
    geom
)
SELECT
    objectid,
    atributos ->> 'LOTCODIGO',
    atributos ->> 'MANZCODIGO',
    ST_Transform(geom, 9377)
FROM staging.lotes
ON CONFLICT (objectid)
DO UPDATE SET
    codigo_lote = EXCLUDED.codigo_lote,
    codigo_manzana = EXCLUDED.codigo_manzana,
    geom = EXCLUDED.geom;

CREATE INDEX IF NOT EXISTS idx_lotes_geom
ON territorio.lotes USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_lotes_manzana
ON territorio.lotes (codigo_manzana);



SELECT
    COUNT(*) AS total_lotes,
    COUNT(*) FILTER (
        WHERE NOT ST_IsValid(geom)
    ) AS invalidos,
    COUNT(*) FILTER (
        WHERE ST_IsEmpty(geom)
    ) AS vacios,
    COUNT(*) FILTER (
        WHERE codigo_manzana IS NULL
    ) AS sin_codigo_manzana,
    MIN(ST_SRID(geom)) AS srid_min,
    MAX(ST_SRID(geom)) AS srid_max
FROM territorio.lotes;


SELECT
    COUNT(*) AS lotes_relacionados,
    COUNT(DISTINCT l.objectid) AS lotes_unicos,
    COUNT(DISTINCT m.objectid) AS manzanas_con_lotes
FROM territorio.lotes l
JOIN territorio.v_manzanas_estudio m
    ON l.codigo_manzana = m.mancodigo;


WITH evaluacion AS (
    SELECT
        l.objectid,

        EXISTS (
            SELECT 1
            FROM movilidad.andenes a
            WHERE ST_DWithin(
                ST_Boundary(l.geom),
                a.geom,
                5
            )
        ) AS anden_5m,

        EXISTS (
            SELECT 1
            FROM movilidad.andenes a
            WHERE ST_DWithin(
                ST_Boundary(l.geom),
                a.geom,
                10
            )
        ) AS anden_10m

    FROM territorio.lotes l
)
SELECT
    COUNT(*) AS total_lotes,

    COUNT(*) FILTER (
        WHERE anden_5m
    ) AS lotes_anden_5m,

    COUNT(*) FILTER (
        WHERE anden_10m
    ) AS lotes_anden_10m,

    COUNT(*) FILTER (
        WHERE NOT anden_10m
    ) AS lotes_sin_anden_10m

FROM evaluacion;


SELECT
    l.objectid,
    l.codigo_lote,
    l.codigo_manzana,
    a.objectid AS anden_cercano,
    ROUND(
        ST_Distance(
            ST_Boundary(l.geom),
            a.geom
        )::numeric, 2
    ) AS distancia_anden_m
FROM territorio.lotes l
CROSS JOIN LATERAL (
    SELECT objectid, geom
    FROM movilidad.andenes
    ORDER BY ST_Distance(
        ST_Boundary(l.geom), geom
    )
    LIMIT 1
) a
WHERE NOT EXISTS (
    SELECT 1
    FROM movilidad.andenes an
    WHERE ST_DWithin(
        ST_Boundary(l.geom),
        an.geom,
        10
    )
)
ORDER BY distancia_anden_m DESC;


CREATE TABLE IF NOT EXISTS movilidad.accesos_lotes (
    objectid_lote BIGINT PRIMARY KEY,
    codigo_lote TEXT,
    codigo_manzana TEXT,
    objectid_anden BIGINT,
    distancia_eje_m DOUBLE PRECISION,
    punto_acceso geometry(Point, 9377),
    punto_red geometry(Point, 9377)
);



INSERT INTO movilidad.accesos_lotes (
    objectid_lote,
    codigo_lote,
    codigo_manzana,
    objectid_anden,
    distancia_eje_m,
    punto_acceso,
    punto_red
)
SELECT
    l.objectid,
    l.codigo_lote,
    l.codigo_manzana,
    a.objectid_anden,
    ST_Distance(
        ST_Boundary(l.geom), a.geom
    ),
    ST_ClosestPoint(
        ST_Boundary(l.geom), a.geom
    ),
    ST_ClosestPoint(
        a.geom, ST_Boundary(l.geom)
    )
FROM territorio.lotes l
CROSS JOIN LATERAL (
    SELECT objectid_anden, geom
    FROM movilidad.ejes_andenes
    ORDER BY ST_Distance(
        ST_Boundary(l.geom), geom
    )
    LIMIT 1
) a
ON CONFLICT (objectid_lote)
DO UPDATE SET
    codigo_lote = EXCLUDED.codigo_lote,
    codigo_manzana = EXCLUDED.codigo_manzana,
    objectid_anden = EXCLUDED.objectid_anden,
    distancia_eje_m = EXCLUDED.distancia_eje_m,
    punto_acceso = EXCLUDED.punto_acceso,
    punto_red = EXCLUDED.punto_red;


SELECT
    COUNT(*) AS lotes_con_acceso,
    ROUND(AVG(distancia_eje_m)::numeric, 2)
        AS distancia_media_m,
    ROUND(MAX(distancia_eje_m)::numeric, 2)
        AS distancia_maxima_m,
    COUNT(*) FILTER (
        WHERE distancia_eje_m > 20
    ) AS accesos_mas_20m,
    COUNT(*) FILTER (
        WHERE punto_acceso IS NULL
           OR punto_red IS NULL
    ) AS puntos_nulos
FROM movilidad.accesos_lotes;



WITH conexiones AS (
    SELECT
        a.objectid_anden AS anden_1,
        b.objectid_anden AS anden_2,
        ST_Distance(a.geom, b.geom) AS distancia_m
    FROM movilidad.ejes_andenes a
    JOIN movilidad.ejes_andenes b
        ON a.objectid_anden < b.objectid_anden
       AND ST_DWithin(a.geom, b.geom, 2)
)
SELECT
    COUNT(*) AS pares_cercanos,
    COUNT(*) FILTER (
        WHERE distancia_m = 0
    ) AS pares_en_contacto,
    COUNT(*) FILTER (
        WHERE distancia_m > 0
    ) AS pares_separados_hasta_2m,
    ROUND(MAX(distancia_m)::numeric, 2)
        AS separacion_maxima_m
FROM conexiones;


WITH pares AS (
    SELECT
        a.objectid_anden AS anden_1,
        b.objectid_anden AS anden_2
    FROM movilidad.ejes_andenes a
    JOIN movilidad.ejes_andenes b
        ON a.objectid_anden < b.objectid_anden
       AND ST_DWithin(a.geom, b.geom, 2)
),
evaluacion AS (
    SELECT
        p.anden_1,
        p.anden_2,
        ST_Intersects(a.geom, b.geom) AS poligonos_intersectan,
        ST_Distance(a.geom, b.geom) AS separacion_poligonos_m
    FROM pares p
    JOIN movilidad.andenes a
        ON a.objectid = p.anden_1
    JOIN movilidad.andenes b
        ON b.objectid = p.anden_2
)
SELECT
    COUNT(*) AS pares_evaluados,
    COUNT(*) FILTER (
        WHERE poligonos_intersectan
    ) AS poligonos_en_contacto,
    COUNT(*) FILTER (
        WHERE NOT poligonos_intersectan
    ) AS poligonos_separados,
    ROUND(
        MAX(separacion_poligonos_m)::numeric, 2
    ) AS separacion_maxima_poligonos_m
FROM evaluacion;



WITH pares AS (
    SELECT
        a.objectid_anden AS anden_1,
        b.objectid_anden AS anden_2
    FROM movilidad.ejes_andenes a
    JOIN movilidad.ejes_andenes b
      ON a.objectid_anden < b.objectid_anden
     AND ST_DWithin(a.geom, b.geom, 2)
),
separados AS (
    SELECT
        p.anden_1,
        p.anden_2,
        ST_Distance(a.geom, b.geom) AS distancia_m
    FROM pares p
    JOIN movilidad.andenes a
      ON a.objectid = p.anden_1
    JOIN movilidad.andenes b
      ON b.objectid = p.anden_2
    WHERE NOT ST_Intersects(a.geom, b.geom)
)
SELECT
    COUNT(*) AS pares_separados,
    MIN(distancia_m) AS distancia_minima_m,
    MAX(distancia_m) AS distancia_maxima_m,
    COUNT(*) FILTER (
        WHERE distancia_m < 0.01
    ) AS separados_menos_1cm,
    COUNT(*) FILTER (
        WHERE distancia_m >= 0.01
    ) AS separados_1cm_o_mas
FROM separados;


WITH pares AS (
    SELECT
        a.objectid_anden AS anden_1,
        b.objectid_anden AS anden_2,
        a.geom AS eje_1,
        b.geom AS eje_2
    FROM movilidad.ejes_andenes a
    JOIN movilidad.ejes_andenes b
      ON a.objectid_anden < b.objectid_anden
     AND ST_DWithin(a.geom, b.geom, 2)
),
evaluacion AS (
    SELECT
        ST_Touches(p1.geom, p2.geom) AS se_tocan,
        ST_Overlaps(p1.geom, p2.geom) AS se_superponen,
        ST_Intersects(p1.geom, p2.geom) AS intersectan,
        ST_Distance(p.eje_1, p.eje_2) AS separacion_ejes_m
    FROM pares p
    JOIN movilidad.andenes p1
      ON p1.objectid = p.anden_1
    JOIN movilidad.andenes p2
      ON p2.objectid = p.anden_2
)
SELECT
    COUNT(*) AS pares_evaluados,
    COUNT(*) FILTER (WHERE se_tocan) AS contacto_bordes,
    COUNT(*) FILTER (WHERE se_superponen) AS superposiciones,
    COUNT(*) FILTER (
        WHERE NOT intersectan
    ) AS separados_precision,
    ROUND(MAX(separacion_ejes_m)::numeric, 3)
        AS distancia_maxima_ejes_m
FROM evaluacion;


CREATE TABLE IF NOT EXISTS movilidad.conexiones_andenes (
    anden_1 BIGINT,
    anden_2 BIGINT,
    tipo_conexion TEXT,
    distancia_m DOUBLE PRECISION,
    geom geometry(LineString, 9377),
    validada BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (anden_1, anden_2)
);

WITH pares AS (
    SELECT
        a.objectid_anden AS anden_1,
        b.objectid_anden AS anden_2,
        a.geom AS eje_1,
        b.geom AS eje_2
    FROM movilidad.ejes_andenes a
    JOIN movilidad.ejes_andenes b
      ON a.objectid_anden < b.objectid_anden
     AND ST_DWithin(a.geom, b.geom, 2)
),
clasificacion AS (
    SELECT
        p.anden_1,
        p.anden_2,
        CASE
            WHEN ST_Touches(a.geom, b.geom)
                THEN 'Contacto de bordes'
            WHEN ST_Overlaps(a.geom, b.geom)
                THEN 'Superposicion'
            WHEN ST_DWithin(a.geom, b.geom, 0.01)
                THEN 'Tolerancia geometrica'
            ELSE 'Revisar'
        END AS tipo_conexion,
        ST_Distance(p.eje_1, p.eje_2) AS distancia_m,
        ST_ShortestLine(p.eje_1, p.eje_2) AS geom
    FROM pares p
    JOIN movilidad.andenes a
      ON a.objectid = p.anden_1
    JOIN movilidad.andenes b
      ON b.objectid = p.anden_2
)
INSERT INTO movilidad.conexiones_andenes (
    anden_1,
    anden_2,
    tipo_conexion,
    distancia_m,
    geom
)
SELECT
    anden_1,
    anden_2,
    tipo_conexion,
    distancia_m,
    geom
FROM clasificacion
ON CONFLICT (anden_1, anden_2) DO NOTHING;


SELECT
    tipo_conexion,
    COUNT(*) AS cantidad,
    ROUND(MAX(distancia_m)::numeric, 3)
        AS distancia_maxima_m
FROM movilidad.conexiones_andenes
GROUP BY tipo_conexion
ORDER BY cantidad DESC;


WITH evaluacion AS (
    SELECT
        c.anden_1,
        c.anden_2,
        c.tipo_conexion,
        ST_Length(c.geom) AS longitud_m,
        ST_Length(
            ST_Difference(
                c.geom,
                ST_Buffer(
                    ST_Union(a.geom, b.geom),
                    0.01
                )
            )
        ) AS longitud_fuera_m
    FROM movilidad.conexiones_andenes c
    JOIN movilidad.andenes a
        ON a.objectid = c.anden_1
    JOIN movilidad.andenes b
        ON b.objectid = c.anden_2
)
SELECT
    COUNT(*) AS conexiones_evaluadas,
    COUNT(*) FILTER (
        WHERE longitud_fuera_m <= 0.05
    ) AS conexiones_sobre_andenes,
    COUNT(*) FILTER (
        WHERE longitud_fuera_m > 0.05
    ) AS conexiones_por_revisar,
    ROUND(
        MAX(longitud_fuera_m)::numeric, 3
    ) AS maxima_longitud_fuera_m
FROM evaluacion;


WITH RECURSIVE
nodos AS (
    SELECT objectid_anden AS id
    FROM movilidad.ejes_andenes
),
conexiones AS (
    SELECT
        anden_1 AS origen,
        anden_2 AS destino
    FROM movilidad.conexiones_andenes

    UNION ALL

    SELECT
        anden_2,
        anden_1
    FROM movilidad.conexiones_andenes
),
alcance AS (
    SELECT id AS origen, id AS alcanzado
    FROM nodos

    UNION

    SELECT
        a.origen,
        c.destino
    FROM alcance a
    JOIN conexiones c
        ON a.alcanzado = c.origen
)
SELECT
    COUNT(DISTINCT componente) AS componentes_conectados,
    MAX(cantidad) AS andenes_componente_principal
FROM (
    SELECT
        alcanzado,
        MIN(origen) AS componente
    FROM alcance
    GROUP BY alcanzado
) grupos
JOIN (
    SELECT
        MIN(origen) AS grupo,
        COUNT(*) AS cantidad
    FROM alcance
    GROUP BY alcanzado
) tamanos
ON grupos.componente = tamanos.grupo;


WITH RECURSIVE
nodos AS (
    SELECT objectid_anden AS id
    FROM movilidad.ejes_andenes
),
enlaces AS (
    SELECT anden_1 AS origen, anden_2 AS destino
    FROM movilidad.conexiones_andenes

    UNION ALL

    SELECT anden_2, anden_1
    FROM movilidad.conexiones_andenes
),
alcance(origen, alcanzado) AS (
    SELECT id, id FROM nodos

    UNION

    SELECT a.origen, e.destino
    FROM alcance a
    JOIN enlaces e
      ON a.alcanzado = e.origen
),
grupos AS (
    SELECT
        alcanzado AS anden,
        MIN(origen) AS componente
    FROM alcance
    GROUP BY alcanzado
),
tamanos AS (
    SELECT componente, COUNT(*) AS cantidad
    FROM grupos
    GROUP BY componente
)
SELECT
    COUNT(*) AS componentes_totales,
    COUNT(*) FILTER (
        WHERE cantidad = 1
    ) AS componentes_aislados,
    COUNT(*) FILTER (
        WHERE cantidad BETWEEN 2 AND 5
    ) AS componentes_2_a_5,
    COUNT(*) FILTER (
        WHERE cantidad > 5
    ) AS componentes_mayores_5,
    MAX(cantidad) AS mayor_componente
FROM tamanos;


CREATE OR REPLACE VIEW movilidad.v_componentes_andenes AS
WITH RECURSIVE
nodos AS (
    SELECT objectid_anden AS id
    FROM movilidad.ejes_andenes
),
enlaces AS (
    SELECT anden_1 AS origen, anden_2 AS destino
    FROM movilidad.conexiones_andenes

    UNION ALL

    SELECT anden_2, anden_1
    FROM movilidad.conexiones_andenes
),
alcance(origen, alcanzado) AS (
    SELECT id, id FROM nodos

    UNION

    SELECT a.origen, e.destino
    FROM alcance a
    JOIN enlaces e
      ON a.alcanzado = e.origen
),
grupos AS (
    SELECT
        alcanzado AS objectid_anden,
        MIN(origen) AS componente
    FROM alcance
    GROUP BY alcanzado
)
SELECT
    g.objectid_anden,
    g.componente,
    a.geom
FROM grupos g
JOIN movilidad.ejes_andenes a
    ON a.objectid_anden = g.objectid_anden;


WITH pares AS (
    SELECT
        a.componente AS componente_1,
        b.componente AS componente_2,
        ST_Distance(a.geom, b.geom) AS distancia_m
    FROM movilidad.v_componentes_andenes a
    JOIN movilidad.v_componentes_andenes b
        ON a.componente <> b.componente
       AND a.objectid_anden < b.objectid_anden
       AND ST_DWithin(a.geom, b.geom, 20)
)
SELECT
    COUNT(*) AS pares_cercanos,
    COUNT(*) FILTER (
        WHERE distancia_m <= 5
    ) AS hasta_5m,
    COUNT(*) FILTER (
        WHERE distancia_m > 5
          AND distancia_m <= 10
    ) AS entre_5_y_10m,
    COUNT(*) FILTER (
        WHERE distancia_m > 10
          AND distancia_m <= 20
    ) AS entre_10_y_20m
FROM pares;



SELECT
    a.objectid_anden AS anden_1,
    b.objectid_anden AS anden_2,
    a.componente AS componente_1,
    b.componente AS componente_2,
    ROUND(
        ST_Distance(a.geom, b.geom)::numeric,
        3
    ) AS distancia_m,
    ST_Intersects(
        p1.geom, p2.geom
    ) AS poligonos_intersectan,
    ST_AsText(
        ST_Transform(
            ST_StartPoint(
                ST_ShortestLine(a.geom, b.geom)
            ),
            4326
        )
    ) AS ubicacion
FROM movilidad.v_componentes_andenes a
JOIN movilidad.v_componentes_andenes b
    ON a.objectid_anden < b.objectid_anden
   AND a.componente <> b.componente
   AND ST_DWithin(a.geom, b.geom, 5)
JOIN movilidad.andenes p1
    ON p1.objectid = a.objectid_anden
JOIN movilidad.andenes p2
    ON p2.objectid = b.objectid_anden
ORDER BY distancia_m
LIMIT 39;


WITH pares AS (
    SELECT
        a.objectid_anden AS anden_1,
        b.objectid_anden AS anden_2,
        ST_ShortestLine(a.geom, b.geom) AS enlace
    FROM movilidad.v_componentes_andenes a
    JOIN movilidad.v_componentes_andenes b
        ON a.objectid_anden < b.objectid_anden
       AND a.componente <> b.componente
       AND ST_DWithin(a.geom, b.geom, 5)
),
evaluacion AS (
    SELECT
        p.*,
        ST_CoveredBy(
            p.enlace,
            ST_Buffer(
                ST_Union(a.geom, b.geom),
                0.01
            )
        ) AS enlace_sobre_anden
    FROM pares p
    JOIN movilidad.andenes a
        ON a.objectid = p.anden_1
    JOIN movilidad.andenes b
        ON b.objectid = p.anden_2
    WHERE ST_Intersects(a.geom, b.geom)
)
SELECT
    COUNT(*) AS conexiones_evaluadas,
    COUNT(*) FILTER (
        WHERE enlace_sobre_anden
    ) AS conexiones_geometricamente_validas,
    COUNT(*) FILTER (
        WHERE NOT enlace_sobre_anden
    ) AS conexiones_por_revisar
FROM evaluacion;


CREATE TABLE IF NOT EXISTS movilidad.conexiones_adicionales (
    anden_1 BIGINT,
    anden_2 BIGINT,
    longitud_m DOUBLE PRECISION,
    geom geometry(LineString, 9377),
    validada BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (anden_1, anden_2)
);

WITH pares AS (
    SELECT
        a.objectid_anden AS anden_1,
        b.objectid_anden AS anden_2,
        ST_ShortestLine(a.geom, b.geom) AS enlace
    FROM movilidad.v_componentes_andenes a
    JOIN movilidad.v_componentes_andenes b
      ON a.objectid_anden < b.objectid_anden
     AND a.componente <> b.componente
     AND ST_DWithin(a.geom, b.geom, 5)
),
candidatos AS (
    SELECT p.*
    FROM pares p
    JOIN movilidad.andenes a
      ON a.objectid = p.anden_1
    JOIN movilidad.andenes b
      ON b.objectid = p.anden_2
    WHERE ST_Intersects(a.geom, b.geom)
      AND ST_CoveredBy(
          p.enlace,
          ST_Buffer(ST_Union(a.geom, b.geom), 0.01)
      )
)
INSERT INTO movilidad.conexiones_adicionales (
    anden_1,
    anden_2,
    longitud_m,
    geom
)
SELECT
    anden_1,
    anden_2,
    ST_Length(enlace),
    enlace
FROM candidatos
ON CONFLICT (anden_1, anden_2) DO NOTHING;



SELECT
    COUNT(*) AS conexiones_adicionales,
    ROUND(MAX(longitud_m)::numeric, 2)
        AS longitud_maxima_m,
    COUNT(*) FILTER (
        WHERE validada
    ) AS conexiones_verificadas
FROM movilidad.conexiones_adicionales;



WITH RECURSIVE
nodos AS (
    SELECT objectid_anden AS id
    FROM movilidad.ejes_andenes
),
enlaces AS (
    SELECT anden_1 AS origen, anden_2 AS destino
    FROM movilidad.conexiones_andenes

    UNION ALL

    SELECT anden_1, anden_2
    FROM movilidad.conexiones_adicionales

    UNION ALL

    SELECT anden_2, anden_1
    FROM movilidad.conexiones_andenes

    UNION ALL

    SELECT anden_2, anden_1
    FROM movilidad.conexiones_adicionales
),
alcance(origen, alcanzado) AS (
    SELECT id, id FROM nodos

    UNION

    SELECT a.origen, e.destino
    FROM alcance a
    JOIN enlaces e
        ON a.alcanzado = e.origen
),
grupos AS (
    SELECT
        alcanzado,
        MIN(origen) AS componente
    FROM alcance
    GROUP BY alcanzado
),
tamanos AS (
    SELECT
        componente,
        COUNT(*) AS cantidad
    FROM grupos
    GROUP BY componente
)
SELECT
    COUNT(*) AS componentes_totales,
    MAX(cantidad) AS andenes_componente_principal,
    COUNT(*) FILTER (
        WHERE cantidad = 1
    ) AS componentes_aislados
FROM tamanos;



SELECT
    r.status AS codigo_http,
    (r.content::jsonb ->> 'count')::integer
        AS elementos_encontrados,
    r.content::jsonb ? 'error'
        AS error_servicio
FROM http_get(
    'https://sinu.sdp.gov.co/serverp/rest/services/POT555/Sistema_del_Cuidado_y_Servicios_Sociales/MapServer/168/query'
    || '?where=1%3D1'
    || '&geometry=-74.1270%2C4.6170%2C-74.1100%2C4.6312'
    || '&geometryType=esriGeometryEnvelope'
    || '&inSR=4326'
    || '&spatialRel=esriSpatialRelIntersects'
    || '&returnCountOnly=true'
    || '&f=json'
) AS r;



CREATE TABLE IF NOT EXISTS staging.red_peatonal_pot_respuestas (
    lote INTEGER PRIMARY KEY,
    codigo_http INTEGER,
    contenido JSONB,
    fecha_descarga TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


WITH respuesta AS (
    SELECT http_get(
        'https://sinu.sdp.gov.co/serverp/rest/services/POT555/Sistema_del_Cuidado_y_Servicios_Sociales/MapServer/168/query'
        || '?where=1%3D1'
        || '&geometry=-74.1270%2C4.6170%2C-74.1100%2C4.6312'
        || '&geometryType=esriGeometryEnvelope'
        || '&inSR=4326'
        || '&spatialRel=esriSpatialRelIntersects'
        || '&outFields=*'
        || '&returnGeometry=true'
        || '&outSR=4326'
        || '&orderByFields=OBJECTID'
        || '&resultOffset=300'
        || '&resultRecordCount=300'
        || '&f=json'
    ) AS r
)
INSERT INTO staging.red_peatonal_pot_respuestas (
    lote, codigo_http, contenido
)
SELECT
    2,
    (r).status,
    (r).content::jsonb
FROM respuesta
ON CONFLICT (lote)
DO UPDATE SET
    codigo_http = EXCLUDED.codigo_http,
    contenido = EXCLUDED.contenido,
    fecha_descarga = CURRENT_TIMESTAMP
RETURNING
    lote,
    codigo_http,
    jsonb_array_length(
        COALESCE(contenido -> 'features', '[]'::jsonb)
    ) AS registros,
    contenido ? 'error' AS error_servicio;


CREATE TABLE IF NOT EXISTS movilidad.red_peatonal_pot (
    objectid BIGINT PRIMARY KEY,
    nombre_via TEXT,
    tipo_clasificacion INTEGER,
    atributos JSONB,
    geom geometry(MultiLineString, 9377)
);

WITH elementos AS (
    SELECT
        jsonb_array_elements(
            contenido -> 'features'
        ) AS e
    FROM staging.red_peatonal_pot_respuestas
    WHERE codigo_http = 200
      AND NOT (contenido ? 'error')
),
datos AS (
    SELECT
        (e -> 'attributes' ->> 'OBJECTID')::bigint AS objectid,
        e -> 'attributes' AS atributos,
        ST_Transform(
            ST_SetSRID(
                ST_GeomFromGeoJSON(
                    jsonb_build_object(
                        'type', 'MultiLineString',
                        'coordinates',
                        e -> 'geometry' -> 'paths'
                    )::text
                ),
                4326
            ),
            9377
        )::geometry(MultiLineString, 9377) AS geom
    FROM elementos
    WHERE e -> 'geometry' -> 'paths' IS NOT NULL
)
INSERT INTO movilidad.red_peatonal_pot (
    objectid,
    nombre_via,
    tipo_clasificacion,
    atributos,
    geom
)
SELECT
    objectid,
    atributos ->> 'NOMBRE_VIA',
    NULLIF(
        atributos ->> 'TIPO_CLASIFICACION', ''
    )::integer,
    atributos,
    geom
FROM datos
ON CONFLICT (objectid)
DO UPDATE SET
    nombre_via = EXCLUDED.nombre_via,
    tipo_clasificacion = EXCLUDED.tipo_clasificacion,
    atributos = EXCLUDED.atributos,
    geom = EXCLUDED.geom;

CREATE INDEX IF NOT EXISTS idx_red_peatonal_pot_geom
ON movilidad.red_peatonal_pot USING GIST (geom);



SELECT
    COUNT(*) AS registros,
    COUNT(*) FILTER (
        WHERE geom IS NULL
    ) AS nulos,
    COUNT(*) FILTER (
        WHERE ST_IsEmpty(geom)
    ) AS vacios,
    COUNT(*) FILTER (
        WHERE NOT ST_IsValid(geom)
    ) AS invalidos,
    MIN(ST_SRID(geom)) AS srid_min,
    MAX(ST_SRID(geom)) AS srid_max,
    ROUND(
        (SUM(ST_Length(geom)) / 1000)::numeric,
        2
    ) AS longitud_km
FROM movilidad.red_peatonal_pot;



WITH lineas AS (
    SELECT
        p.objectid,
        (ST_Dump(p.geom)).geom AS geom
    FROM movilidad.red_peatonal_pot p
),
puntos AS (
    SELECT
        objectid,
        ST_LineInterpolatePoint(geom, 0.5) AS geom
    FROM lineas
    WHERE ST_Length(geom) > 0
),
distancias AS (
    SELECT
        p.objectid,
        ST_Distance(p.geom, v.geom) AS distancia_m
    FROM puntos p
    CROSS JOIN LATERAL (
        SELECT geom
        FROM movilidad.malla_vial
        ORDER BY geom <-> p.geom
        LIMIT 1
    ) v
)
SELECT
    COUNT(*) AS puntos_evaluados,
    COUNT(*) FILTER (
        WHERE distancia_m <= 2
    ) AS hasta_2m,
    COUNT(*) FILTER (
        WHERE distancia_m > 2 AND distancia_m <= 5
    ) AS entre_2_y_5m,
    COUNT(*) FILTER (
        WHERE distancia_m > 5 AND distancia_m <= 10
    ) AS entre_5_y_10m,
    COUNT(*) FILTER (
        WHERE distancia_m > 10
    ) AS mas_10m,
    ROUND(AVG(distancia_m)::numeric, 2)
        AS distancia_media_m
FROM distancias;


WITH lineas AS (
    SELECT
        p.objectid,
        (ST_Dump(p.geom)).geom AS geom
    FROM movilidad.red_peatonal_pot p
),
muestras AS (
    SELECT
        l.objectid,
        ST_LineInterpolatePoint(
            l.geom,
            g.n::double precision / c.total
        ) AS geom
    FROM lineas l
    CROSS JOIN LATERAL (
        SELECT GREATEST(
            CEIL(ST_Length(l.geom) / 10)::integer,
            1
        ) AS total
    ) c
    CROSS JOIN LATERAL generate_series(
        0, c.total
    ) AS g(n)
    WHERE ST_Length(l.geom) > 0
),
distancias AS (
    SELECT
        m.objectid,
        ST_Distance(m.geom, v.geom) AS distancia_m
    FROM muestras m
    CROSS JOIN LATERAL (
        SELECT geom
        FROM movilidad.malla_vial
        ORDER BY geom <-> m.geom
        LIMIT 1
    ) v
)
SELECT
    COUNT(*) AS puntos_evaluados,
    COUNT(*) FILTER (
        WHERE distancia_m <= 2
    ) AS hasta_2m,
    COUNT(*) FILTER (
        WHERE distancia_m > 2
    ) AS mas_2m,
    ROUND(MAX(distancia_m)::numeric, 2)
        AS distancia_maxima_m,
    ROUND(AVG(distancia_m)::numeric, 2)
        AS distancia_media_m
FROM distancias;


WITH pares AS (
    SELECT
        a.objectid_anden AS anden_1,
        b.objectid_anden AS anden_2,
        a.componente AS componente_1,
        b.componente AS componente_2,
        ST_ShortestLine(a.geom, b.geom) AS enlace
    FROM movilidad.v_componentes_andenes a
    JOIN movilidad.v_componentes_andenes b
        ON a.objectid_anden < b.objectid_anden
       AND a.componente <> b.componente
       AND ST_DWithin(a.geom, b.geom, 20)
    WHERE ST_Distance(a.geom, b.geom) > 2
),
evaluacion AS (
    SELECT
        p.*,
        EXISTS (
            SELECT 1
            FROM movilidad.malla_vial v
            WHERE v.clasificacion = 3
              AND ST_Intersects(p.enlace, v.geom)
        ) AS cruza_via_local,
        EXISTS (
            SELECT 1
            FROM movilidad.malla_vial v
            WHERE v.clasificacion = 1
              AND ST_DWithin(p.enlace, v.geom, 5)
        ) AS cerca_via_arterial
    FROM pares p
)
SELECT
    COUNT(*) AS pares_evaluados,
    COUNT(*) FILTER (
        WHERE cruza_via_local
    ) AS cruces_via_local,
    COUNT(*) FILTER (
        WHERE cruza_via_local
          AND NOT cerca_via_arterial
    ) AS candidatos_sin_arterial_cercana,
    COUNT(*) FILTER (
        WHERE cerca_via_arterial
    ) AS proximos_a_arteriales
FROM evaluacion;



WITH intersecciones AS (
    SELECT
        n.id,
        n.geom
    FROM movilidad.red_nodos n
    JOIN movilidad.red_aristas a
      ON a.source = n.id OR a.target = n.id
    GROUP BY n.id, n.geom
    HAVING COUNT(DISTINCT a.id) >= 3
       AND COUNT(*) FILTER (
           WHERE a.clasificacion = 3
       ) >= 1
),
pares AS (
    SELECT
        a.objectid_anden AS anden_1,
        b.objectid_anden AS anden_2,
        ST_ShortestLine(a.geom, b.geom) AS enlace
    FROM movilidad.v_componentes_andenes a
    JOIN movilidad.v_componentes_andenes b
      ON a.objectid_anden < b.objectid_anden
     AND a.componente <> b.componente
     AND ST_DWithin(a.geom, b.geom, 20)
    WHERE ST_Distance(a.geom, b.geom) > 2
),
candidatos AS (
    SELECT p.*
    FROM pares p
    WHERE EXISTS (
        SELECT 1
        FROM movilidad.malla_vial v
        WHERE v.clasificacion = 3
          AND ST_Crosses(p.enlace, v.geom)
    )
    AND NOT EXISTS (
        SELECT 1
        FROM movilidad.malla_vial v
        WHERE v.clasificacion = 1
          AND ST_DWithin(p.enlace, v.geom, 5)
    )
)
SELECT
    COUNT(*) AS candidatos_evaluados,
    COUNT(*) FILTER (
        WHERE EXISTS (
            SELECT 1
            FROM intersecciones i
            WHERE ST_DWithin(c.enlace, i.geom, 12)
        )
    ) AS candidatos_cerca_esquinas
FROM candidatos c;



WITH intersecciones AS (
    SELECT n.id, n.geom
    FROM movilidad.red_nodos n
    JOIN movilidad.red_aristas a
        ON a.source = n.id OR a.target = n.id
    GROUP BY n.id, n.geom
    HAVING COUNT(DISTINCT a.id) >= 3
       AND COUNT(*) FILTER (
           WHERE a.clasificacion = 3
       ) >= 1
),
pares AS (
    SELECT
        a.objectid_anden AS anden_1,
        b.objectid_anden AS anden_2,
        ST_ShortestLine(a.geom, b.geom) AS enlace
    FROM movilidad.v_componentes_andenes a
    JOIN movilidad.v_componentes_andenes b
        ON a.objectid_anden < b.objectid_anden
       AND a.componente <> b.componente
       AND ST_DWithin(a.geom, b.geom, 20)
    WHERE ST_Distance(a.geom, b.geom) > 2
),
candidatos AS (
    SELECT *
    FROM pares p
    WHERE EXISTS (
        SELECT 1
        FROM movilidad.malla_vial v
        WHERE v.clasificacion = 3
          AND ST_Crosses(p.enlace, v.geom)
    )
    AND NOT EXISTS (
        SELECT 1
        FROM movilidad.malla_vial v
        WHERE v.clasificacion = 1
          AND ST_DWithin(p.enlace, v.geom, 5)
    )
),
asignacion AS (
    SELECT
        c.anden_1,
        c.anden_2,
        i.id AS interseccion_id
    FROM candidatos c
    CROSS JOIN LATERAL (
        SELECT id
        FROM intersecciones
        WHERE ST_DWithin(geom, c.enlace, 12)
        ORDER BY ST_Distance(geom, c.enlace), id
        LIMIT 1
    ) i
),
resumen AS (
    SELECT
        interseccion_id,
        COUNT(*) AS cantidad
    FROM asignacion
    GROUP BY interseccion_id
)
SELECT
    COALESCE(SUM(cantidad), 0) AS conexiones_candidatas,
    COUNT(*) AS intersecciones_diferentes,
    COALESCE(MAX(cantidad), 0)
        AS max_conexiones_por_interseccion
FROM resumen;


CREATE OR REPLACE VIEW movilidad.v_componentes_andenes AS
WITH RECURSIVE
nodos AS (
    SELECT objectid_anden AS id
    FROM movilidad.ejes_andenes
),
enlaces AS (
    SELECT anden_1 AS origen, anden_2 AS destino
    FROM movilidad.conexiones_andenes

    UNION

    SELECT anden_1, anden_2
    FROM movilidad.conexiones_adicionales

    UNION

    SELECT anden_2, anden_1
    FROM movilidad.conexiones_andenes

    UNION

    SELECT anden_2, anden_1
    FROM movilidad.conexiones_adicionales
),
alcance(origen, alcanzado) AS (
    SELECT id, id FROM nodos

    UNION

    SELECT a.origen, e.destino
    FROM alcance a
    JOIN enlaces e
        ON a.alcanzado = e.origen
),
grupos AS (
    SELECT
        alcanzado AS objectid_anden,
        MIN(origen) AS componente
    FROM alcance
    GROUP BY alcanzado
)
SELECT
    g.objectid_anden,
    g.componente,
    a.geom
FROM grupos g
JOIN movilidad.ejes_andenes a
    ON a.objectid_anden = g.objectid_anden;


SELECT
    COUNT(*) AS andenes,
    COUNT(DISTINCT componente) AS componentes,
    MAX(cantidad) AS mayor_componente
FROM (
    SELECT
        componente,
        COUNT(*) AS cantidad
    FROM movilidad.v_componentes_andenes
    GROUP BY componente
) AS resumen
CROSS JOIN LATERAL (
    SELECT COUNT(*) AS total
    FROM movilidad.ejes_andenes
) AS referencia
GROUP BY referencia.total;


WITH intersecciones AS (
    SELECT n.id, n.geom
    FROM movilidad.red_nodos n
    JOIN movilidad.red_aristas a
      ON a.source = n.id OR a.target = n.id
    GROUP BY n.id, n.geom
    HAVING COUNT(DISTINCT a.id) >= 3
       AND COUNT(*) FILTER (
           WHERE a.clasificacion = 3
       ) >= 1
),
pares AS (
    SELECT
        a.objectid_anden AS anden_1,
        b.objectid_anden AS anden_2,
        a.componente AS componente_1,
        b.componente AS componente_2,
        ST_ShortestLine(a.geom, b.geom) AS enlace
    FROM movilidad.v_componentes_andenes a
    JOIN movilidad.v_componentes_andenes b
      ON a.objectid_anden < b.objectid_anden
     AND a.componente <> b.componente
     AND ST_DWithin(a.geom, b.geom, 20)
    WHERE ST_Distance(a.geom, b.geom) > 2
),
candidatos AS (
    SELECT *
    FROM pares p
    WHERE EXISTS (
        SELECT 1
        FROM movilidad.malla_vial v
        WHERE v.clasificacion = 3
          AND ST_Crosses(p.enlace, v.geom)
    )
    AND NOT EXISTS (
        SELECT 1
        FROM movilidad.malla_vial v
        WHERE v.clasificacion = 1
          AND ST_DWithin(p.enlace, v.geom, 5)
    )
),
asignacion AS (
    SELECT
        c.*,
        i.id AS interseccion_id,
        ST_Length(c.enlace) AS longitud_m
    FROM candidatos c
    CROSS JOIN LATERAL (
        SELECT id
        FROM intersecciones
        WHERE ST_DWithin(geom, c.enlace, 12)
        ORDER BY ST_Distance(geom, c.enlace), id
        LIMIT 1
    ) i
),
seleccion AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY
                interseccion_id,
                LEAST(componente_1, componente_2),
                GREATEST(componente_1, componente_2)
            ORDER BY longitud_m, anden_1, anden_2
        ) AS posicion
    FROM asignacion
)
SELECT
    COUNT(*) AS candidatos_actualizados,
    COUNT(DISTINCT interseccion_id)
        AS intersecciones,
    COUNT(*) FILTER (
        WHERE posicion = 1
    ) AS candidatos_sin_redundancia,
    COUNT(*) FILTER (
        WHERE posicion > 1
    ) AS candidatos_redundantes
FROM seleccion;


CREATE OR REPLACE VIEW movilidad.v_cruces_candidatos AS
WITH intersecciones AS (
    SELECT n.id, n.geom
    FROM movilidad.red_nodos n
    JOIN movilidad.red_aristas a
      ON a.source = n.id OR a.target = n.id
    GROUP BY n.id, n.geom
    HAVING COUNT(DISTINCT a.id) >= 3
       AND COUNT(*) FILTER (
           WHERE a.clasificacion = 3
       ) >= 1
),
pares AS (
    SELECT
        a.objectid_anden AS anden_1,
        b.objectid_anden AS anden_2,
        a.componente AS componente_1,
        b.componente AS componente_2,
        ST_ShortestLine(a.geom, b.geom) AS geom
    FROM movilidad.v_componentes_andenes a
    JOIN movilidad.v_componentes_andenes b
      ON a.objectid_anden < b.objectid_anden
     AND a.componente <> b.componente
     AND ST_DWithin(a.geom, b.geom, 20)
    WHERE ST_Distance(a.geom, b.geom) > 2
),
candidatos AS (
    SELECT *
    FROM pares p
    WHERE EXISTS (
        SELECT 1
        FROM movilidad.malla_vial v
        WHERE v.clasificacion = 3
          AND ST_Crosses(p.geom, v.geom)
    )
    AND NOT EXISTS (
        SELECT 1
        FROM movilidad.malla_vial v
        WHERE v.clasificacion = 1
          AND ST_DWithin(p.geom, v.geom, 5)
    )
),
asignacion AS (
    SELECT
        c.*,
        i.id AS interseccion_id,
        ST_Length(c.geom) AS longitud_m
    FROM candidatos c
    CROSS JOIN LATERAL (
        SELECT id
        FROM intersecciones
        WHERE ST_DWithin(geom, c.geom, 12)
        ORDER BY ST_Distance(geom, c.geom), id
        LIMIT 1
    ) i
),
seleccion AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY
                interseccion_id,
                LEAST(componente_1, componente_2),
                GREATEST(componente_1, componente_2)
            ORDER BY longitud_m, anden_1, anden_2
        ) AS posicion
    FROM asignacion
)
SELECT
    anden_1,
    anden_2,
    componente_1,
    componente_2,
    interseccion_id,
    ROUND(longitud_m::numeric, 2) AS longitud_m,
    geom
FROM seleccion
WHERE posicion = 1;


SELECT
    COUNT(*) AS cruces_candidatos,
    COUNT(DISTINCT interseccion_id) AS intersecciones,
    ROUND(MIN(longitud_m), 2) AS longitud_minima_m,
    ROUND(MAX(longitud_m), 2) AS longitud_maxima_m
FROM movilidad.v_cruces_candidatos;



SELECT
    anden_1,
    anden_2,
    interseccion_id,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM movilidad.v_cruces_candidatos
ORDER BY longitud_m ASC
LIMIT 10;


CREATE TABLE IF NOT EXISTS movilidad.validacion_cruces (
    anden_1 BIGINT NOT NULL,
    anden_2 BIGINT NOT NULL,
    estado TEXT NOT NULL DEFAULT 'Pendiente',
    observacion TEXT,
    PRIMARY KEY (anden_1, anden_2),
    CONSTRAINT estado_cruce_valido
        CHECK (estado IN (
            'Pendiente',
            'Validado',
            'Descartado'
        ))
);

INSERT INTO movilidad.validacion_cruces (
    anden_1,
    anden_2
)
SELECT anden_1, anden_2
FROM movilidad.v_cruces_candidatos
ON CONFLICT (anden_1, anden_2)
DO NOTHING;


SELECT
    estado,
    COUNT(*) AS cantidad
FROM movilidad.validacion_cruces
GROUP BY estado;




