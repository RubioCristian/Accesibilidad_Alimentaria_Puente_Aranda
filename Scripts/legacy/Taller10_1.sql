
-- Habilitar extensión espacial
CREATE EXTENSION IF NOT EXISTS postgis;

-- Separar datos originales y procesados
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS territorio;
CREATE SCHEMA IF NOT EXISTS alimentos;
CREATE SCHEMA IF NOT EXISTS movilidad;
CREATE SCHEMA IF NOT EXISTS analisis;
CREATE SCHEMA IF NOT EXISTS interoperabilidad;

-- Verificar instalación
SELECT PostGIS_Full_Version();


CREATE TABLE IF NOT EXISTS staging.localidad (
    objectid INTEGER PRIMARY KEY,
    loccodigo VARCHAR(2),
    locnombre VARCHAR(50),
    locaadmini VARCHAR(50),
    locarea DOUBLE PRECISION,
    geom geometry(MultiPolygon, 4326),
    fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fuente_url TEXT
);

CREATE INDEX IF NOT EXISTS idx_staging_localidad_geom
ON staging.localidad
USING GIST (geom);



SELECT
    name,
    default_version,
    installed_version
FROM pg_available_extensions
WHERE name = 'http';


CREATE EXTENSION IF NOT EXISTS http;


SELECT
    extname,
    extversion
FROM pg_extension
WHERE extname = 'http';



SELECT
    status,
    content_type,
    LEFT(content, 200) AS respuesta
FROM http_get(
    'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/ordenamientoterritorial/localidad/MapServer?f=json'
);



SELECT
    content::jsonb -> 'features' AS registros
FROM http_get(
    'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/ordenamientoterritorial/localidad/MapServer/0/query'
    || '?where=LOCCODIGO%3D%2716%27'
    || '&outFields=*'
    || '&returnGeometry=true'
    || '&outSR=4326'
    || '&f=geojson'
);


SELECT
    locnombre,
    ST_SRID(geom),
    ST_IsValid(geom),
    ST_Area(ST_Transform(geom, 9377)) / 10000
FROM staging.localidad;

CREATE TABLE IF NOT EXISTS staging.localidad (
    objectid INTEGER PRIMARY KEY,
    loccodigo VARCHAR(2),
    locnombre VARCHAR(50),
    locaadmini VARCHAR(50),
    locarea DOUBLE PRECISION,
    geom geometry(MultiPolygon, 4326),
    fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


WITH respuesta AS (
    SELECT
        content::jsonb AS datos
    FROM http_get(
        'https://serviciosgis.catastrobogota.gov.co/'
        || 'arcgis/rest/services/'
        || 'ordenamientoterritorial/localidad/'
        || 'MapServer/0/query'
        || '?where=LOCCODIGO%3D%2716%27'
        || '&outFields=*'
        || '&returnGeometry=true'
        || '&outSR=4326'
        || '&f=geojson'
    )
),
registros AS (
    SELECT
        jsonb_array_elements(
            datos->'features'
        ) AS feature
    FROM respuesta
    WHERE jsonb_typeof(datos->'features') = 'array'
)
INSERT INTO staging.localidad (
    objectid,
    loccodigo,
    locnombre,
    locaadmini,
    locarea,
    geom
)
SELECT
    (feature->'properties'->>'OBJECTID')::integer,
    feature->'properties'->>'LOCCODIGO',
    feature->'properties'->>'LOCNOMBRE',
    feature->'properties'->>'LOCAADMINI',
    NULLIF(
        feature->'properties'->>'LOCAREA', ''
    )::double precision,
    ST_Multi(
        ST_SetSRID(
            ST_GeomFromGeoJSON(
                (feature->'geometry')::text
            ),
            4326
        )
    )
FROM registros
WHERE feature->'properties'->>'LOCCODIGO' = '16'
  AND feature->'geometry' IS NOT NULL
ON CONFLICT (objectid)
DO NOTHING;


SELECT
    objectid,
    loccodigo,
    locnombre,
    ST_GeometryType(geom) AS geometria,
    ST_SRID(geom) AS srid,
    ST_IsValid(geom) AS valida,
    ST_IsEmpty(geom) AS vacia,
    ROUND(
        (
            ST_Area(
                ST_Transform(geom, 9377)
            ) / 10000
        )::numeric, 2
    ) AS area_ha
FROM staging.localidad;


SELECT
    srid,
    auth_name,
    auth_srid,
    LEFT(srtext, 80) AS descripcion
FROM spatial_ref_sys
WHERE srid IN (4326, 4686, 3116, 9377);



INSERT INTO spatial_ref_sys (
    srid,
    auth_name,
    auth_srid,
    proj4text,
    srtext
)
VALUES (
    9377,
    'EPSG',
    9377,
    '+proj=tmerc +lat_0=4 +lon_0=-73 +k=0.9992 +x_0=5000000 +y_0=2000000 +ellps=GRS80 +units=m +no_defs +type=crs',
    'PROJCS["MAGNA-SIRGAS 2018 / Origen-Nacional",
      GEOGCS["MAGNA-SIRGAS 2018",
        DATUM["Marco_Geocentrico_Nacional_de_Referencia_2018",
          SPHEROID["GRS 1980",6378137,298.257222101]],
        PRIMEM["Greenwich",0],
        UNIT["degree",0.0174532925199433]],
      PROJECTION["Transverse_Mercator"],
      PARAMETER["latitude_of_origin",4],
      PARAMETER["central_meridian",-73],
      PARAMETER["scale_factor",0.9992],
      PARAMETER["false_easting",5000000],
      PARAMETER["false_northing",2000000],
      UNIT["metre",1],
      AUTHORITY["EPSG","9377"]]'
)
ON CONFLICT (srid) DO NOTHING;


SELECT
    srid,
    auth_name,
    auth_srid
FROM spatial_ref_sys
WHERE srid = 9377;


SELECT ST_AsText(
    ST_Transform(
        ST_SetSRID(
            ST_MakePoint(-74.1, 4.63),
            4326
        ),
        9377
    )
) AS coordenadas_transformadas;







