SELECT
    estado_informacion,
    COUNT(*) AS cantidad
FROM territorio.v_uso_predominante
GROUP BY estado_informacion
ORDER BY estado_informacion;

SELECT
    grupo_uso_econ,
    COUNT(*) AS cantidad_manzanas
FROM territorio.v_uso_predominante
WHERE estado_informacion = 'Con informacion'
GROUP BY grupo_uso_econ
ORDER BY cantidad_manzanas DESC;


CREATE TABLE IF NOT EXISTS territorio.area_estudio (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(150),
    descripcion TEXT,
    geom geometry(Polygon, 9377),
    fecha_creacion TIMESTAMP
        DEFAULT CURRENT_TIMESTAMP
);


INSERT INTO territorio.area_estudio (
    nombre,
    descripcion,
    geom
)
VALUES (
    'Sector Puente Aranda - Calle 3 / Av. Américas / Cra 68 / Cra 56',
    'Polígono de estudio definido a partir de cuatro esquinas tomadas manualmente en cartografía base.',
    ST_Transform(
        ST_SetSRID(
            ST_MakePolygon(
                ST_GeomFromText(
                    'LINESTRING(
                        -74.1128301 4.6275506,
                        -74.1195656 4.6197381,
                        -74.1241125 4.6243581,
                        -74.1225112 4.6284361,
                        -74.1128301 4.6275506
                    )'
                )
            ),
            4326
        ),
        9377
    )
);

SELECT
    id,
    nombre,
    ST_IsValid(geom) AS valida,
    ST_SRID(geom) AS srid,
    ROUND((ST_Area(geom)/10000)::numeric, 2) AS area_ha
FROM territorio.area_estudio;


SELECT
    COUNT(*) AS manzanas_intersectadas
FROM territorio.manzana m
JOIN territorio.area_estudio a
    ON ST_Intersects(m.geom, a.geom);

SELECT
    m.objectid,
    m.mancodigo,
    m.seccodigo
FROM territorio.manzana m
JOIN territorio.area_estudio a
    ON ST_Intersects(m.geom, a.geom)
ORDER BY m.mancodigo;


CREATE OR REPLACE VIEW territorio.v_manzanas_estudio AS
SELECT
    m.objectid,
    m.mancodigo,
    m.seccodigo,
    u.grupo_uso_econ,
    u.fecha_dato,
    u.estado_informacion,
    m.geom
FROM territorio.manzana m
JOIN territorio.area_estudio a
    ON ST_Intersects(m.geom, a.geom)
LEFT JOIN territorio.v_uso_predominante u
    ON m.objectid = u.objectid;


SELECT
    COUNT(*) AS total_manzanas,
    COUNT(DISTINCT objectid) AS manzanas_unicas,
    COUNT(*) FILTER (
        WHERE grupo_uso_econ IS NULL
    ) AS sin_uso_predominante
FROM territorio.v_manzanas_estudio;


SELECT
    grupo_uso_econ,
    COUNT(*) AS cantidad_manzanas,
    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS porcentaje
FROM territorio.v_manzanas_estudio
GROUP BY grupo_uso_econ
ORDER BY cantidad_manzanas DESC;


SELECT COUNT(*) AS total_plazas
FROM staging.plaza_mercado;

SELECT
    f_geometry_column AS columna_geometrica,
    type AS tipo_geometria,
    srid
FROM geometry_columns
WHERE f_table_schema = 'staging'
  AND f_table_name = 'plaza_mercado';

SELECT
    COUNT(*) AS total_registros,
    COUNT(*) FILTER (
        WHERE geom IS NULL
    ) AS geometrias_nulas,
    COUNT(*) FILTER (
        WHERE ST_IsEmpty(geom)
    ) AS geometrias_vacias,
    COUNT(*) FILTER (
        WHERE NOT ST_IsValid(geom)
    ) AS geometrias_invalidas,
    COUNT(DISTINCT ST_AsEWKB(geom))
        AS geometrias_distintas
FROM staging.plaza_mercado;



INSERT INTO spatial_ref_sys (
    srid, auth_name, auth_srid, srtext
)
VALUES (
    990047,
    'LOCAL',
    990047,
    $wkt$
PROJCS["PCS_CarMAGBOG",
 GEOGCS["GCS_CarMAGBOG",
  DATUM["CGS_CarMAGBOG",
   SPHEROID["GRS80 Mod",6380687.0,298.257222101]],
  PRIMEM["Greenwich",0.0],
  UNIT["Degree",0.0174532925199433]],
 PROJECTION["Transverse_Mercator"],
 PARAMETER["False_Easting",92334.879],
 PARAMETER["False_Northing",109320.965],
 PARAMETER["Central_Meridian",-74.14659167],
 PARAMETER["Scale_Factor",1.0],
 PARAMETER["Latitude_Of_Origin",4.680486111],
 UNIT["Meter",1.0]]
$wkt$
)
ON CONFLICT (srid) DO NOTHING;


SELECT
    ROUND(ST_X(punto)::numeric, 6) AS longitud,
    ROUND(ST_Y(punto)::numeric, 6) AS latitud
FROM (
    SELECT ST_Transform(
        ST_SetSRID(
            ST_PointOnSurface(geom),
            990047
        ),
        4326
    ) AS punto
    FROM staging.plaza_mercado
    WHERE geom IS NOT NULL
    LIMIT 5
) AS prueba;


CREATE OR REPLACE VIEW alimentos.v_plazas_mercado AS
SELECT
    p.*,
    ST_Transform(
        ST_SetSRID(p.geom, 990047),
        9377
    ) AS geom_9377
FROM staging.plaza_mercado p;


SELECT COUNT(*) AS plazas_dentro
FROM alimentos.v_plazas_mercado p
JOIN territorio.area_estudio a
    ON ST_Intersects(p.geom_9377, a.geom);


SELECT
    p.*,
    ROUND(
        ST_Distance(p.geom_9377, a.geom)::numeric,
        2
    ) AS distancia_metros
FROM alimentos.v_plazas_mercado p
CROSS JOIN territorio.area_estudio a
WHERE ST_DWithin(
    p.geom_9377,
    a.geom,
    1000
)
ORDER BY distancia_metros;


SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'staging'
  AND table_name = 'plaza_mercado'
ORDER BY ordinal_position;



CREATE OR REPLACE VIEW alimentos.v_plazas_analisis AS
SELECT
    gid,
    codigo_pla,
    nombre,
    direccion,
    codigo_loc,
    area_predi,
    area_const,
    fecha_acto,
    fecha_capt,
    'Plaza de mercado'::text AS categoria,
    geom_9377 AS geom
FROM alimentos.v_plazas_mercado
WHERE geom_9377 IS NOT NULL;



SELECT
    MIN(fecha_acto) AS primera_actualizacion,
    MAX(fecha_acto) AS ultima_actualizacion,
    MIN(fecha_capt) AS primera_captura,
    MAX(fecha_capt) AS ultima_captura
FROM staging.plaza_mercado;


SELECT
    ST_YMin(ST_Transform(geom, 4326)) AS lat_sur,
    ST_XMin(ST_Transform(geom, 4326)) AS lon_oeste,
    ST_YMax(ST_Transform(geom, 4326)) AS lat_norte,
    ST_XMax(ST_Transform(geom, 4326)) AS lon_este
FROM territorio.area_estudio;


CREATE TABLE IF NOT EXISTS staging.osm_alimentos_respuesta (
    id BIGSERIAL PRIMARY KEY,
    fecha_consulta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    codigo_http INTEGER,
    contenido TEXT
);


SELECT http_set_curlopt(
    'CURLOPT_CONNECTTIMEOUT_MS', '15000'
);

SELECT http_set_curlopt(
    'CURLOPT_TIMEOUT_MS', '120000'
);



WITH consulta AS (
    SELECT $overpass$
        [out:json][timeout:90];
        nwr["shop"="supermarket"]
        (4.6170,-74.1270,4.6312,-74.1100);
        out center;
    $overpass$::text AS q
),
respuesta AS (
    SELECT http_post(
        'https://overpass-api.de/api/interpreter',
        q,
        'text/plain'
    ) AS r
    FROM consulta
)
INSERT INTO staging.osm_alimentos_respuesta (
    codigo_http,
    contenido
)
SELECT
    (r).status,
    (r).content
FROM respuesta
RETURNING
    id,
    codigo_http,
    LENGTH(contenido) AS caracteres_recibidos;



SELECT
    id,
    codigo_http,
    CASE
        WHEN contenido::jsonb ? 'elements'
        THEN jsonb_array_length(
            contenido::jsonb -> 'elements'
        )
        ELSE NULL
    END AS cantidad_establecimientos
FROM staging.osm_alimentos_respuesta
WHERE codigo_http = 200
ORDER BY id DESC
LIMIT 1;



CREATE TABLE IF NOT EXISTS alimentos.supermercados_osm (
    tipo_osm TEXT NOT NULL,
    id_osm BIGINT NOT NULL,
    nombre TEXT,
    categoria TEXT,
    direccion TEXT,
    etiquetas JSONB,
    geom geometry(Point, 9377),
    fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tipo_osm, id_osm)
);


WITH elementos AS (
    SELECT jsonb_array_elements(
        contenido::jsonb -> 'elements'
    ) AS e
    FROM staging.osm_alimentos_respuesta
    WHERE id = 2
      AND codigo_http = 200
),
datos AS (
    SELECT
        e ->> 'type' AS tipo_osm,
        (e ->> 'id')::bigint AS id_osm,
        e -> 'tags' ->> 'name' AS nombre,
        e -> 'tags' ->> 'shop' AS categoria,
        e -> 'tags' AS etiquetas,
        COALESCE(
            e ->> 'lon',
            e -> 'center' ->> 'lon'
        )::double precision AS longitud,
        COALESCE(
            e ->> 'lat',
            e -> 'center' ->> 'lat'
        )::double precision AS latitud
    FROM elementos
)
INSERT INTO alimentos.supermercados_osm (
    tipo_osm,
    id_osm,
    nombre,
    categoria,
    direccion,
    etiquetas,
    geom
)
SELECT
    tipo_osm,
    id_osm,
    nombre,
    categoria,
    NULLIF(
        CONCAT_WS(
            ' ',
            etiquetas ->> 'addr:street',
            etiquetas ->> 'addr:housenumber'
        ),
        ''
    ),
    etiquetas,
    ST_Transform(
        ST_SetSRID(
            ST_MakePoint(longitud, latitud),
            4326
        ),
        9377
    )
FROM datos
WHERE longitud IS NOT NULL
  AND latitud IS NOT NULL
ON CONFLICT (tipo_osm, id_osm)
DO UPDATE SET
    nombre = EXCLUDED.nombre,
    categoria = EXCLUDED.categoria,
    direccion = EXCLUDED.direccion,
    etiquetas = EXCLUDED.etiquetas,
    geom = EXCLUDED.geom;


SELECT
    COUNT(*) AS total_supermercados,
    COUNT(*) FILTER (
        WHERE nombre IS NULL
    ) AS sin_nombre,
    COUNT(*) FILTER (
        WHERE geom IS NULL
    ) AS sin_geometria,
    COUNT(*) FILTER (
        WHERE NOT ST_IsValid(geom)
    ) AS geometrias_invalidas
FROM alimentos.supermercados_osm;


SELECT
    COUNT(*) FILTER (
        WHERE ST_Intersects(s.geom, a.geom)
    ) AS dentro_poligono,
    COUNT(*) FILTER (
        WHERE ST_DWithin(s.geom, a.geom, 300)
          AND NOT ST_Intersects(s.geom, a.geom)
    ) AS fuera_hasta_300m
FROM alimentos.supermercados_osm s
CROSS JOIN territorio.area_estudio a;


WITH consulta AS (
    SELECT $overpass$
        [out:json][timeout:90];
        nwr["shop"~"^(convenience|grocery|greengrocer|bakery|butcher|deli)$"]
        (4.6170,-74.1270,4.6312,-74.1100);
        out center;
    $overpass$::text AS q
),
respuesta AS (
    SELECT http_post(
        'https://overpass-api.de/api/interpreter',
        q,
        'text/plain'
    ) AS r
    FROM consulta
)
INSERT INTO staging.osm_alimentos_respuesta (
    codigo_http,
    contenido
)
SELECT
    (r).status,
    (r).content
FROM respuesta
RETURNING
    id,
    codigo_http,
    LENGTH(contenido) AS caracteres_recibidos;



SELECT
    id,
    codigo_http,
    CASE
        WHEN contenido::jsonb ? 'elements'
        THEN jsonb_array_length(
            contenido::jsonb -> 'elements'
        )
        ELSE NULL
    END AS establecimientos_encontrados
FROM staging.osm_alimentos_respuesta
WHERE codigo_http = 200
ORDER BY id DESC
LIMIT 1;


CREATE TABLE IF NOT EXISTS alimentos.otros_establecimientos_osm (
    tipo_osm TEXT NOT NULL,
    id_osm BIGINT NOT NULL,
    nombre TEXT,
    categoria TEXT,
    direccion TEXT,
    etiquetas JSONB,
    geom geometry(Point, 9377),
    fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tipo_osm, id_osm)
);



WITH elementos AS (
    SELECT jsonb_array_elements(
        contenido::jsonb -> 'elements'
    ) AS e
    FROM staging.osm_alimentos_respuesta
    WHERE id = 3
      AND codigo_http = 200
),
datos AS (
    SELECT
        e ->> 'type' AS tipo_osm,
        (e ->> 'id')::bigint AS id_osm,
        e -> 'tags' ->> 'name' AS nombre,
        e -> 'tags' ->> 'shop' AS categoria,
        e -> 'tags' AS etiquetas,
        COALESCE(
            e ->> 'lon',
            e -> 'center' ->> 'lon'
        )::double precision AS longitud,
        COALESCE(
            e ->> 'lat',
            e -> 'center' ->> 'lat'
        )::double precision AS latitud
    FROM elementos
)
INSERT INTO alimentos.otros_establecimientos_osm (
    tipo_osm,
    id_osm,
    nombre,
    categoria,
    direccion,
    etiquetas,
    geom
)
SELECT
    tipo_osm,
    id_osm,
    nombre,
    categoria,
    NULLIF(
        CONCAT_WS(
            ' ',
            etiquetas ->> 'addr:street',
            etiquetas ->> 'addr:housenumber'
        ),
        ''
    ),
    etiquetas,
    ST_Transform(
        ST_SetSRID(
            ST_MakePoint(longitud, latitud),
            4326
        ),
        9377
    )
FROM datos
WHERE longitud IS NOT NULL
  AND latitud IS NOT NULL
ON CONFLICT (tipo_osm, id_osm)
DO UPDATE SET
    nombre = EXCLUDED.nombre,
    categoria = EXCLUDED.categoria,
    direccion = EXCLUDED.direccion,
    etiquetas = EXCLUDED.etiquetas,
    geom = EXCLUDED.geom;


SELECT
    categoria,
    COUNT(*) AS cantidad
FROM alimentos.otros_establecimientos_osm
GROUP BY categoria
ORDER BY cantidad DESC;



SELECT
    COUNT(*) AS total_cargados,
    COUNT(*) FILTER (
        WHERE ST_Intersects(e.geom, a.geom)
    ) AS dentro_poligono,
    COUNT(*) FILTER (
        WHERE ST_DWithin(e.geom, a.geom, 300)
          AND NOT ST_Intersects(e.geom, a.geom)
    ) AS fuera_hasta_300m,
    COUNT(*) FILTER (
        WHERE NOT ST_DWithin(e.geom, a.geom, 300)
    ) AS fuera_mas_300m
FROM alimentos.otros_establecimientos_osm e
CROSS JOIN territorio.area_estudio a;



CREATE OR REPLACE VIEW alimentos.v_oferta_alimentaria AS
WITH establecimientos AS (

    SELECT
        'osm_' || tipo_osm || '_' || id_osm::text AS id,
        COALESCE(nombre, 'Sin nombre') AS nombre,
        'Supermercado'::text AS categoria,
        'OpenStreetMap'::text AS fuente,
        geom
    FROM alimentos.supermercados_osm

    UNION ALL

    SELECT
        'osm_' || tipo_osm || '_' || id_osm::text AS id,
        COALESCE(nombre, 'Sin nombre') AS nombre,
        CASE categoria
            WHEN 'convenience' THEN 'Tienda de conveniencia'
            WHEN 'grocery' THEN 'Tienda de comestibles'
            WHEN 'bakery' THEN 'Panaderia'
            WHEN 'butcher' THEN 'Carniceria'
            WHEN 'greengrocer' THEN 'Fruteria y verduleria'
            WHEN 'deli' THEN 'Delicatessen'
            ELSE categoria
        END AS categoria,
        'OpenStreetMap'::text AS fuente,
        geom
    FROM alimentos.otros_establecimientos_osm

    UNION ALL

    SELECT
        'plaza_' || gid::text AS id,
        nombre,
        'Plaza de mercado'::text AS categoria,
        'Datos Abiertos Bogota'::text AS fuente,
        ST_PointOnSurface(geom)::geometry(Point, 9377)
    FROM alimentos.v_plazas_analisis
)
SELECT
    e.*,
    ST_Intersects(e.geom, a.geom) AS dentro_poligono,
    ROUND(
        ST_Distance(e.geom, a.geom)::numeric,
        2
    ) AS distancia_limite_m
FROM establecimientos e
CROSS JOIN territorio.area_estudio a
WHERE ST_DWithin(e.geom, a.geom, 300);


SELECT
    fuente,
    categoria,
    COUNT(*) AS total,
    COUNT(*) FILTER (
        WHERE dentro_poligono
    ) AS dentro_poligono,
    COUNT(*) FILTER (
        WHERE NOT dentro_poligono
    ) AS entorno_300m
FROM alimentos.v_oferta_alimentaria
GROUP BY fuente, categoria
ORDER BY fuente, total DESC;



CREATE OR REPLACE VIEW analisis.v_proximidad_alimentos AS
SELECT
    m.objectid,
    m.mancodigo,
    m.grupo_uso_econ,
    e.id AS id_establecimiento,
    e.nombre AS establecimiento_cercano,
    e.categoria,
    ROUND(
        ST_Distance(
            ST_PointOnSurface(m.geom),
            e.geom
        )::numeric,
        2
    ) AS distancia_m
FROM territorio.v_manzanas_estudio m
CROSS JOIN LATERAL (
    SELECT
        a.id,
        a.nombre,
        a.categoria,
        a.geom
    FROM alimentos.v_oferta_alimentaria a
    ORDER BY
        ST_Distance(
            ST_PointOnSurface(m.geom),
            a.geom
        )
    LIMIT 1
) e;



SELECT
    COUNT(*) AS total_manzanas,
    ROUND(AVG(distancia_m), 2) AS distancia_media_m,
    ROUND(MIN(distancia_m), 2) AS distancia_minima_m,
    ROUND(MAX(distancia_m), 2) AS distancia_maxima_m,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY distancia_m)::numeric,
        2
    ) AS distancia_mediana_m
FROM analisis.v_proximidad_alimentos;



SELECT
    CASE
        WHEN distancia_m <= 100 THEN '0-100 m'
        WHEN distancia_m <= 200 THEN '100-200 m'
        WHEN distancia_m <= 300 THEN '200-300 m'
        WHEN distancia_m <= 500 THEN '300-500 m'
        ELSE 'Mas de 500 m'
    END AS rango_distancia,
    COUNT(*) AS manzanas
FROM analisis.v_proximidad_alimentos
GROUP BY 1
ORDER BY MIN(distancia_m);



SELECT
    COUNT(*) AS manzanas_residenciales,
    ROUND(AVG(distancia_m), 2) AS distancia_media_m,
    ROUND(MIN(distancia_m), 2) AS distancia_minima_m,
    ROUND(MAX(distancia_m), 2) AS distancia_maxima_m,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY distancia_m)::numeric,
        2
    ) AS distancia_mediana_m
FROM analisis.v_proximidad_alimentos
WHERE grupo_uso_econ = 'RESIDENCIAL';




SELECT
    mancodigo,
    establecimiento_cercano,
    categoria,
    distancia_m
FROM analisis.v_proximidad_alimentos
WHERE grupo_uso_econ = 'RESIDENCIAL'
ORDER BY distancia_m DESC
LIMIT 10;


CREATE OR REPLACE VIEW analisis.v_proximidad_abastecimiento AS
SELECT
    m.objectid,
    m.mancodigo,
    m.grupo_uso_econ,
    e.id AS id_establecimiento,
    e.nombre AS establecimiento_cercano,
    e.categoria,
    ROUND(
        ST_Distance(
            ST_PointOnSurface(m.geom),
            e.geom
        )::numeric,
        2
    ) AS distancia_m
FROM territorio.v_manzanas_estudio m
CROSS JOIN LATERAL (
    SELECT
        a.id,
        a.nombre,
        a.categoria,
        a.geom
    FROM alimentos.v_oferta_alimentaria a
    WHERE a.categoria IN (
        'Supermercado',
        'Tienda de conveniencia',
        'Plaza de mercado'
    )
    ORDER BY
        ST_Distance(
            ST_PointOnSurface(m.geom),
            a.geom
        ),
        a.id
    LIMIT 1
) e
WHERE m.grupo_uso_econ = 'RESIDENCIAL';


SELECT
    COUNT(*) AS manzanas_residenciales,
    ROUND(AVG(distancia_m), 2) AS distancia_media_m,
    ROUND(MIN(distancia_m), 2) AS distancia_minima_m,
    ROUND(MAX(distancia_m), 2) AS distancia_maxima_m,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY distancia_m)::numeric,
        2
    ) AS distancia_mediana_m
FROM analisis.v_proximidad_abastecimiento;



SELECT
    mancodigo,
    establecimiento_cercano,
    categoria,
    distancia_m
FROM analisis.v_proximidad_abastecimiento
ORDER BY distancia_m DESC
LIMIT 10;


SELECT
    a.mancodigo,
    a.establecimiento_cercano AS cercano_general,
    a.distancia_m AS distancia_general_m,
    b.establecimiento_cercano AS cercano_abastecimiento,
    b.categoria AS categoria_abastecimiento,
    b.distancia_m AS distancia_abastecimiento_m,
    ROUND(
        b.distancia_m - a.distancia_m, 2
    ) AS diferencia_m
FROM analisis.v_proximidad_alimentos a
JOIN analisis.v_proximidad_abastecimiento b
    ON a.objectid = b.objectid
WHERE a.grupo_uso_econ = 'RESIDENCIAL'
ORDER BY diferencia_m DESC, a.mancodigo
LIMIT 10;


SELECT
    (respuesta.content::jsonb ->> 'count')::integer
        AS tramos_viales_disponibles,
    respuesta.status AS codigo_http
FROM http_get(
    'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/Mapa_Referencia/Mapa_Referencia/MapServer/13/query'
    || '?where=1%3D1'
    || '&geometry=-74.1270%2C4.6170%2C-74.1100%2C4.6312'
    || '&geometryType=esriGeometryEnvelope'
    || '&inSR=4326'
    || '&spatialRel=esriSpatialRelIntersects'
    || '&returnCountOnly=true'
    || '&f=json'
) AS respuesta;


CREATE TABLE IF NOT EXISTS staging.malla_vial_respuestas (
    id BIGSERIAL PRIMARY KEY,
    lote INTEGER UNIQUE,
    codigo_http INTEGER,
    contenido JSONB,
    fecha_descarga TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


WITH respuesta AS (
    SELECT http_get(
        'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/Mapa_Referencia/Mapa_Referencia/MapServer/13/query'
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
INSERT INTO staging.malla_vial_respuestas (
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
    ) AS tramos_descargados,
    contenido ? 'error' AS error_servicio;


WITH lotes AS (
    SELECT 2 AS lote, 400 AS offset_inicio
    UNION ALL
    SELECT 3 AS lote, 800 AS offset_inicio
),
respuestas AS (
    SELECT
        l.lote,
        http_get(
            'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/Mapa_Referencia/Mapa_Referencia/MapServer/13/query'
            || '?where=1%3D1'
            || '&geometry=-74.1270%2C4.6170%2C-74.1100%2C4.6312'
            || '&geometryType=esriGeometryEnvelope'
            || '&inSR=4326'
            || '&spatialRel=esriSpatialRelIntersects'
            || '&outFields=*'
            || '&returnGeometry=true'
            || '&outSR=4326'
            || '&orderByFields=OBJECTID'
            || '&resultOffset=' || l.offset_inicio
            || '&resultRecordCount=400'
            || '&f=json'
        ) AS r
    FROM lotes l
)
INSERT INTO staging.malla_vial_respuestas (
    lote,
    codigo_http,
    contenido
)
SELECT
    lote,
    (r).status,
    (r).content::jsonb
FROM respuestas
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
    ) AS tramos_descargados,
    contenido ? 'error' AS error_servicio;

SELECT
    COUNT(*) AS lotes_descargados,
    SUM(
        jsonb_array_length(
            COALESCE(contenido -> 'features', '[]'::jsonb)
        )
    ) AS total_tramos,
    COUNT(*) FILTER (
        WHERE codigo_http <> 200
           OR contenido ? 'error'
    ) AS lotes_con_error
FROM staging.malla_vial_respuestas;


CREATE TABLE IF NOT EXISTS staging.malla_vial (
    objectid BIGINT PRIMARY KEY,
    atributos JSONB,
    geom geometry(MultiLineString, 4326)
);


WITH elementos AS (
    SELECT
        jsonb_array_elements(
            r.contenido -> 'features'
        ) AS elemento
    FROM staging.malla_vial_respuestas r
    WHERE r.codigo_http = 200
      AND NOT (r.contenido ? 'error')
),
datos AS (
    SELECT
        (elemento -> 'attributes' ->> 'OBJECTID')::bigint
            AS objectid,
        elemento -> 'attributes' AS atributos,
        ST_SetSRID(
            ST_GeomFromGeoJSON(
                jsonb_build_object(
                    'type', 'MultiLineString',
                    'coordinates',
                    elemento -> 'geometry' -> 'paths'
                )::text
            ),
            4326
        )::geometry(MultiLineString, 4326) AS geom
    FROM elementos
    WHERE elemento -> 'geometry' -> 'paths' IS NOT NULL
)
INSERT INTO staging.malla_vial (
    objectid,
    atributos,
    geom
)
SELECT
    objectid,
    atributos,
    geom
FROM datos
ON CONFLICT (objectid)
DO UPDATE SET
    atributos = EXCLUDED.atributos,
    geom = EXCLUDED.geom;


SELECT
    COUNT(*) AS total_tramos,
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
FROM staging.malla_vial;


SELECT
    atributos ->> 'MVITCLA' AS clasificacion_vial,
    COUNT(*) AS cantidad_tramos
FROM staging.malla_vial
GROUP BY atributos ->> 'MVITCLA'
ORDER BY cantidad_tramos DESC;

