
CREATE TABLE IF NOT EXISTS movilidad.malla_vial (
    objectid BIGINT PRIMARY KEY,
    codigo_vial TEXT,
    nombre_via TEXT,
    clasificacion INTEGER,
    geom geometry(MultiLineString, 9377)
);

INSERT INTO movilidad.malla_vial (
    objectid,
    codigo_vial,
    nombre_via,
    clasificacion,
    geom
)
SELECT
    objectid,
    atributos ->> 'MVICODIGO',
    atributos ->> 'MVINOMBRE',
    (atributos ->> 'MVITCLA')::integer,
    ST_Transform(geom, 9377)
FROM staging.malla_vial
ON CONFLICT (objectid)
DO UPDATE SET
    codigo_vial = EXCLUDED.codigo_vial,
    nombre_via = EXCLUDED.nombre_via,
    clasificacion = EXCLUDED.clasificacion,
    geom = EXCLUDED.geom;

CREATE INDEX IF NOT EXISTS idx_malla_vial_geom
ON movilidad.malla_vial
USING GIST (geom);


SELECT
    COUNT(*) AS total_tramos,
    COUNT(*) FILTER (
        WHERE NOT ST_IsValid(geom)
    ) AS invalidos,
    COUNT(*) FILTER (
        WHERE ST_IsEmpty(geom)
    ) AS vacios,
    MIN(ST_SRID(geom)) AS srid_minimo,
    MAX(ST_SRID(geom)) AS srid_maximo,
    ROUND(
        (SUM(ST_Length(geom)) / 1000)::numeric,
        2
    ) AS longitud_total_km
FROM movilidad.malla_vial;


SELECT
    'territorio.localidad' AS capa,
    COUNT(*) AS registros
FROM territorio.localidad

UNION ALL

SELECT
    'territorio.manzana',
    COUNT(*)
FROM territorio.manzana

UNION ALL

SELECT
    'territorio.v_manzanas_estudio',
    COUNT(*)
FROM territorio.v_manzanas_estudio

UNION ALL

SELECT
    'alimentos.v_oferta_alimentaria',
    COUNT(*)
FROM alimentos.v_oferta_alimentaria

UNION ALL

SELECT
    'movilidad.malla_vial',
    COUNT(*)
FROM movilidad.malla_vial

UNION ALL

SELECT
    'analisis.v_proximidad_alimentos',
    COUNT(*)
FROM analisis.v_proximidad_alimentos

UNION ALL

SELECT
    'analisis.v_proximidad_abastecimiento',
    COUNT(*)
FROM analisis.v_proximidad_abastecimiento;


SELECT
    (respuesta.content::jsonb ->> 'count')::integer
        AS andenes_disponibles,
    respuesta.status AS codigo_http
FROM http_get(
    'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/Mapa_Referencia/Mapa_Referencia/MapServer/16/query'
    || '?where=1%3D1'
    || '&geometry=-74.1270%2C4.6170%2C-74.1100%2C4.6312'
    || '&geometryType=esriGeometryEnvelope'
    || '&inSR=4326'
    || '&spatialRel=esriSpatialRelIntersects'
    || '&returnCountOnly=true'
    || '&f=json'
) AS respuesta;


CREATE TABLE IF NOT EXISTS staging.andenes_respuestas (
    id BIGSERIAL PRIMARY KEY,
    lote INTEGER UNIQUE,
    codigo_http INTEGER,
    contenido JSONB,
    fecha_descarga TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


WITH respuesta AS (
    SELECT http_get(
        'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/Mapa_Referencia/Mapa_Referencia/MapServer/16/query'
        || '?where=1%3D1'
        || '&geometry=-74.1270%2C4.6170%2C-74.1100%2C4.6312'
        || '&geometryType=esriGeometryEnvelope'
        || '&inSR=4326'
        || '&spatialRel=esriSpatialRelIntersects'
        || '&outFields=*'
        || '&returnGeometry=true'
        || '&outSR=4326'
        || '&orderByFields=OBJECTID'
        || '&resultOffset=0'
        || '&resultRecordCount=400'
        || '&f=json'
    ) AS r
)
INSERT INTO staging.andenes_respuestas (
    lote,
    codigo_http,
    contenido
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
    ) AS andenes_descargados,
    contenido ? 'error' AS error_servicio;

SELECT
    lote,
    codigo_http,
    jsonb_array_length(
        COALESCE(contenido -> 'features', '[]'::jsonb)
    ) AS registros,
    contenido ? 'error' AS error_servicio
FROM staging.andenes_respuestas
ORDER BY lote;


DO $$
DECLARE
    v_lote INTEGER;
    v_offset INTEGER;
    v_respuesta http_response;
BEGIN
    FOR v_lote IN 2..4 LOOP

        v_offset := (v_lote - 1) * 400;

        SELECT *
        INTO v_respuesta
        FROM http_get(
            'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/Mapa_Referencia/Mapa_Referencia/MapServer/16/query'
            || '?where=1%3D1'
            || '&geometry=-74.1270%2C4.6170%2C-74.1100%2C4.6312'
            || '&geometryType=esriGeometryEnvelope'
            || '&inSR=4326'
            || '&spatialRel=esriSpatialRelIntersects'
            || '&outFields=*'
            || '&returnGeometry=true'
            || '&outSR=4326'
            || '&orderByFields=OBJECTID'
            || '&resultOffset=' || v_offset
            || '&resultRecordCount=400'
            || '&f=json'
        );

        IF v_respuesta.status <> 200
           OR v_respuesta.content::jsonb ? 'error'
        THEN
            RAISE EXCEPTION
                'Error descargando lote %: HTTP %',
                v_lote, v_respuesta.status;
        END IF;

        INSERT INTO staging.andenes_respuestas (
            lote, codigo_http, contenido
        )
        VALUES (
            v_lote,
            v_respuesta.status,
            v_respuesta.content::jsonb
        )
        ON CONFLICT (lote)
        DO UPDATE SET
            codigo_http = EXCLUDED.codigo_http,
            contenido = EXCLUDED.contenido,
            fecha_descarga = CURRENT_TIMESTAMP;

        RAISE NOTICE 'Lote % descargado', v_lote;

    END LOOP;
END $$;


SELECT
    lote,
    codigo_http,
    jsonb_array_length(
        COALESCE(contenido -> 'features', '[]'::jsonb)
    ) AS registros,
    contenido ? 'error' AS error_servicio
FROM staging.andenes_respuestas
ORDER BY lote;


CREATE TABLE IF NOT EXISTS staging.andenes (
    objectid BIGINT PRIMARY KEY,
    atributos JSONB,
    geom geometry(MultiPolygon, 4326)
);


WITH elementos AS (
    SELECT
        jsonb_array_elements(
            contenido -> 'features'
        ) AS elemento
    FROM staging.andenes_respuestas
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
INSERT INTO staging.andenes (
    objectid,
    atributos,
    geom
)
SELECT
    objectid,
    atributos,
    geom
FROM poligonos
ON CONFLICT (objectid)
DO UPDATE SET
    atributos = EXCLUDED.atributos,
    geom = EXCLUDED.geom;


SELECT
    COUNT(*) AS total_andenes,
    COUNT(*) FILTER (
        WHERE geom IS NULL
    ) AS geometrias_nulas,
    COUNT(*) FILTER (
        WHERE ST_IsEmpty(geom)
    ) AS geometrias_vacias,
    COUNT(*) FILTER (
        WHERE NOT ST_IsValid(geom)
    ) AS geometrias_invalidas,
    COUNT(DISTINCT objectid) AS identificadores_unicos,
    MIN(ST_SRID(geom)) AS srid_minimo,
    MAX(ST_SRID(geom)) AS srid_maximo
FROM staging.andenes;


SELECT
    atributos ->> 'ANDMATERIA' AS codigo_material,
    COUNT(*) AS cantidad
FROM staging.andenes
GROUP BY atributos ->> 'ANDMATERIA'
ORDER BY cantidad DESC;


CREATE TABLE IF NOT EXISTS movilidad.andenes (
    objectid BIGINT PRIMARY KEY,
    codigo_anden TEXT,
    codigo_civ TEXT,
    codigo_material TEXT,
    geom geometry(MultiPolygon, 9377)
);

INSERT INTO movilidad.andenes (
    objectid,
    codigo_anden,
    codigo_civ,
    codigo_material,
    geom
)
SELECT
    objectid,
    atributos ->> 'ANDCODIGO',
    atributos ->> 'ANDCIV',
    atributos ->> 'ANDMATERIA',
    ST_Transform(geom, 9377)
FROM staging.andenes
ON CONFLICT (objectid)
DO UPDATE SET
    codigo_anden = EXCLUDED.codigo_anden,
    codigo_civ = EXCLUDED.codigo_civ,
    codigo_material = EXCLUDED.codigo_material,
    geom = EXCLUDED.geom;

CREATE INDEX IF NOT EXISTS idx_andenes_geom
ON movilidad.andenes
USING GIST (geom);



SELECT
    COUNT(*) FILTER (
        WHERE ST_Intersects(an.geom, a.geom)
    ) AS andenes_intersectados,
    COUNT(*) FILTER (
        WHERE ST_Within(an.geom, a.geom)
    ) AS andenes_contenidos,
    ROUND(
        (
            SUM(
                ST_Area(
                    ST_Intersection(an.geom, a.geom)
                )
            ) / 10000
        )::numeric,
        2
    ) AS superficie_intersectada_ha
FROM movilidad.andenes an
CROSS JOIN territorio.area_estudio a
WHERE ST_Intersects(an.geom, a.geom);



WITH capas AS (
    SELECT
        'territorio.localidad' AS capa,
        geom
    FROM territorio.localidad

    UNION ALL

    SELECT
        'territorio.manzana',
        geom
    FROM territorio.manzana

    UNION ALL

    SELECT
        'territorio.area_estudio',
        geom
    FROM territorio.area_estudio

    UNION ALL

    SELECT
        'movilidad.malla_vial',
        geom
    FROM movilidad.malla_vial

    UNION ALL

    SELECT
        'movilidad.andenes',
        geom
    FROM movilidad.andenes

    UNION ALL

    SELECT
        'alimentos.supermercados_osm',
        geom
    FROM alimentos.supermercados_osm

    UNION ALL

    SELECT
        'alimentos.otros_establecimientos_osm',
        geom
    FROM alimentos.otros_establecimientos_osm
)
SELECT
    capa,
    COUNT(*) AS registros,
    COUNT(*) FILTER (
        WHERE geom IS NULL
    ) AS nulos,
    COUNT(*) FILTER (
        WHERE ST_IsEmpty(geom)
    ) AS vacios,
    COUNT(*) FILTER (
        WHERE geom IS NOT NULL
          AND NOT ST_IsValid(geom)
    ) AS invalidos,
    MIN(ST_SRID(geom)) AS srid_min,
    MAX(ST_SRID(geom)) AS srid_max
FROM capas
GROUP BY capa
ORDER BY capa;



SELECT
    nombre,
    categoria,
    ST_Transform(geom, 4326) AS geom
FROM alimentos.v_oferta_alimentaria;

