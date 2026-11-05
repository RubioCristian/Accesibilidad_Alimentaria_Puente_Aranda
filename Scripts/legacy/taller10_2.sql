
CREATE TABLE IF NOT EXISTS territorio.localidad (
    objectid INTEGER PRIMARY KEY,
    loccodigo VARCHAR(2),
    locnombre VARCHAR(50),
    geom geometry(MultiPolygon, 9377)
);

INSERT INTO territorio.localidad (
    objectid,
    loccodigo,
    locnombre,
    geom
)
SELECT
    objectid,
    loccodigo,
    locnombre,
    ST_Transform(geom, 9377)
FROM staging.localidad
WHERE ST_IsValid(geom)
  AND NOT ST_IsEmpty(geom)
ON CONFLICT (objectid)
DO UPDATE SET
    loccodigo = EXCLUDED.loccodigo,
    locnombre = EXCLUDED.locnombre,
    geom = EXCLUDED.geom;

CREATE INDEX IF NOT EXISTS idx_territorio_localidad_geom
ON territorio.localidad
USING GIST (geom);


SELECT
    locnombre,
    ST_SRID(geom) AS srid,
    ST_IsValid(geom) AS valida,
    ROUND(
        (ST_Area(geom) / 10000)::numeric,
        2
    ) AS area_ha
FROM territorio.localidad;



WITH limites AS (
    SELECT
        ST_Transform(
            ST_Envelope(geom),
            4326
        ) AS geom
    FROM territorio.localidad
    WHERE loccodigo = '16'
),
consulta AS (
    SELECT
        'https://serviciosgis.catastrobogota.gov.co/'
        || 'arcgis/rest/services/catastro/manzana/'
        || 'MapServer/0/query'
        || '?where=1%3D1'
        || '&geometry='
        || ST_XMin(geom) || ','
        || ST_YMin(geom) || ','
        || ST_XMax(geom) || ','
        || ST_YMax(geom)
        || '&geometryType=esriGeometryEnvelope'
        || '&inSR=4326'
        || '&spatialRel=esriSpatialRelIntersects'
        || '&returnCountOnly=true'
        || '&f=json' AS url
    FROM limites
)
SELECT
    (content::jsonb ->> 'count')::integer
        AS manzanas_candidatas
FROM consulta
CROSS JOIN LATERAL http_get(url);


CREATE TABLE IF NOT EXISTS staging.manzana (
    objectid INTEGER PRIMARY KEY,
    mancodigo VARCHAR(9),
    seccodigo VARCHAR(6),
    geom geometry(MultiPolygon, 4326),
    fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_staging_manzana_geom
ON staging.manzana
USING GIST (geom);


DO $$
DECLARE
    base_url TEXT :=
        'https://serviciosgis.catastrobogota.gov.co/'
        || 'arcgis/rest/services/catastro/manzana/'
        || 'MapServer/0/query';

    envolvente geometry;
    url TEXT;
    respuesta JSONB;
    ids INTEGER[];
    lote TEXT;
    registro JSONB;
    posicion INTEGER;
    total INTEGER;
    importados INTEGER := 0;
BEGIN

    -- 1. Obtener el rectángulo de la localidad
    SELECT ST_Envelope(ST_Transform(geom, 4326))
    INTO envolvente
    FROM territorio.localidad
    WHERE loccodigo = '16';

    IF envolvente IS NULL THEN
        RAISE EXCEPTION 'No existe la localidad 16';
    END IF;

    -- 2. Solicitar los identificadores
    url := base_url
        || '?where=1%3D1'
        || '&geometry='
        || ST_XMin(envolvente) || ','
        || ST_YMin(envolvente) || ','
        || ST_XMax(envolvente) || ','
        || ST_YMax(envolvente)
        || '&geometryType=esriGeometryEnvelope'
        || '&inSR=4326'
        || '&spatialRel=esriSpatialRelIntersects'
        || '&returnIdsOnly=true'
        || '&f=json';

    SELECT content::jsonb
    INTO respuesta
    FROM http_get(url);

    IF respuesta ? 'error'
       OR jsonb_typeof(respuesta->'objectIds')
          IS DISTINCT FROM 'array'
    THEN
        RAISE EXCEPTION
            'Error al consultar IDs: %', respuesta;
    END IF;

    SELECT array_agg(valor::integer
                     ORDER BY valor::integer)
    INTO ids
    FROM jsonb_array_elements_text(
        respuesta->'objectIds'
    ) AS t(valor);

    total := COALESCE(array_length(ids, 1), 0);

    RAISE NOTICE 'Manzanas candidatas: %', total;

    -- 3. Descargar en lotes de 200
    FOR posicion IN 1..total BY 200 LOOP

        SELECT string_agg(id::text, ',')
        INTO lote
        FROM unnest(
            ids[posicion:LEAST(posicion + 199,total)]
        ) AS t(id);

        url := base_url
            || '?objectIds=' || lote
            || '&outFields=OBJECTID%2CMANCODIGO%2CSECCODIGO'
            || '&returnGeometry=true'
            || '&outSR=4326'
            || '&f=geojson';

        SELECT content::jsonb
        INTO respuesta
        FROM http_get(url);

        IF respuesta ? 'error'
           OR respuesta->>'type' <> 'FeatureCollection'
           OR jsonb_typeof(respuesta->'features')
              IS DISTINCT FROM 'array'
        THEN
            RAISE EXCEPTION
                'Error descargando lote %: %',
                posicion, respuesta;
        END IF;

        FOR registro IN
            SELECT value
            FROM jsonb_array_elements(
                respuesta->'features'
            )
        LOOP

            IF registro->'geometry' IS NOT NULL
               AND registro->'geometry' <> 'null'::jsonb
            THEN

                INSERT INTO staging.manzana (
                    objectid,
                    mancodigo,
                    seccodigo,
                    geom
                )
                VALUES (
                    (registro->'properties'->>'OBJECTID')::integer,
                    registro->'properties'->>'MANCODIGO',
                    registro->'properties'->>'SECCODIGO',
                    ST_Multi(
                        ST_SetSRID(
                            ST_GeomFromGeoJSON(
                                (registro->'geometry')::text
                            ),
                            4326
                        )
                    )
                )
                ON CONFLICT (objectid)
                DO UPDATE SET
                    mancodigo = EXCLUDED.mancodigo,
                    seccodigo = EXCLUDED.seccodigo,
                    geom = EXCLUDED.geom,
                    fecha_carga = CURRENT_TIMESTAMP;

                importados := importados + 1;

            END IF;

        END LOOP;

        RAISE NOTICE
            'Procesados hasta % de % registros',
            LEAST(posicion + 199,total), total;

    END LOOP;

    RAISE NOTICE
        'Registros procesados: %', importados;

END $$;


SELECT
    COUNT(*) AS total_manzanas,
    COUNT(*) FILTER (
        WHERE geom IS NULL
    ) AS geometria_nula,
    COUNT(*) FILTER (
        WHERE ST_IsEmpty(geom)
    ) AS geometria_vacia,
    COUNT(*) FILTER (
        WHERE NOT ST_IsValid(geom)
    ) AS geometria_invalida,
    COUNT(DISTINCT mancodigo) AS codigos_unicos,
    MIN(ST_SRID(geom)) AS srid_minimo,
    MAX(ST_SRID(geom)) AS srid_maximo
FROM staging.manzana;


CREATE TABLE IF NOT EXISTS territorio.manzana (
    objectid INTEGER PRIMARY KEY,
    mancodigo VARCHAR(9),
    seccodigo VARCHAR(6),
    geom geometry(MultiPolygon, 9377)
);

INSERT INTO territorio.manzana (
    objectid,
    mancodigo,
    seccodigo,
    geom
)
SELECT
    m.objectid,
    m.mancodigo,
    m.seccodigo,
    ST_Transform(m.geom, 9377)
FROM staging.manzana m
JOIN territorio.localidad l
    ON ST_Intersects(
        ST_Transform(m.geom,9377),
        l.geom
    )
WHERE l.loccodigo = '16'
  AND m.geom IS NOT NULL
  AND NOT ST_IsEmpty(m.geom)
  AND ST_IsValid(m.geom)
ON CONFLICT (objectid)
DO UPDATE SET
    mancodigo = EXCLUDED.mancodigo,
    seccodigo = EXCLUDED.seccodigo,
    geom = EXCLUDED.geom;

CREATE INDEX IF NOT EXISTS idx_territorio_manzana_geom
ON territorio.manzana
USING GIST (geom);


SELECT
    COUNT(*) AS total_manzanas_puente_aranda,
    COUNT(DISTINCT mancodigo) AS codigos_manzana,
    COUNT(DISTINCT seccodigo) AS sectores_catastrales,
    ROUND(
        (SUM(ST_Area(geom))/10000)::numeric,
        2
    ) AS area_total_manzanas_ha
FROM territorio.manzana;


SELECT
    datos->>'name' AS nombre_capa,
    datos->>'geometryType' AS geometria,
    datos->>'maxRecordCount' AS limite_registros,
    datos->>'supportedQueryFormats' AS formatos
FROM (
    SELECT content::jsonb AS datos
    FROM http_get(
        'https://serviciosgis.catastrobogota.gov.co/'
        || 'arcgis/rest/services/catastro/'
        || 'usopredominante/MapServer/0?f=pjson'
    )
) AS servicio;



