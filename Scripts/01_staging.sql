-- 01: catalogo de fuentes y tablas crudas que llena el cargador Python.
CREATE TABLE IF NOT EXISTS staging.fuente_dato (
  id             serial PRIMARY KEY,
  nombre         text NOT NULL UNIQUE,
  entidad        text,
  url            text,
  fecha_descarga date,
  licencia       text,
  cobertura      text,
  escala         text,
  limitaciones   text
);

-- Fuentes descargadas en el trabajo anterior; la fecha sale de lo guardado en la base.
INSERT INTO staging.fuente_dato (nombre, entidad, url, fecha_descarga, cobertura, limitaciones) VALUES
 ('Catastro - Localidad', 'UAECD Catastro Bogota',
  'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/ordenamientoterritorial/localidad/MapServer/0',
  (SELECT max(fecha_carga)::date FROM staging.localidad), 'Localidad 16', NULL),
 ('Catastro - Manzana', 'UAECD Catastro Bogota',
  'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/catastro/manzana/MapServer/0',
  (SELECT max(fecha_carga)::date FROM staging.manzana), 'Localidad 16 (1 811 manzanas)', NULL),
 ('Catastro - Lote', 'UAECD Catastro Bogota',
  'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/catastro/lote/MapServer/0',
  (SELECT max(fecha_descarga)::date FROM staging.lotes_respuestas), 'Solo zona cargada (76 manzanas, 2 394 lotes)',
  'No se descargaron los 39 697 lotes de la localidad'),
 ('Mapa de Referencia - Anden', 'IDECA / Mapa de Referencia',
  'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/Mapa_Referencia/Mapa_Referencia/MapServer/16',
  (SELECT max(fecha_descarga)::date FROM staging.andenes_respuestas), 'Zona cargada', NULL),
 ('Mapa de Referencia - Malla vial', 'IDECA / Mapa de Referencia',
  'https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/Mapa_Referencia/Mapa_Referencia/MapServer/13',
  (SELECT max(fecha_descarga)::date FROM staging.malla_vial_respuestas), 'Zona cargada', NULL),
 ('SINU - Red peatonal POT', 'Secretaria Distrital de Planeacion',
  'https://sinu.sdp.gov.co/serverp/rest/services/POT555/Sistema_del_Cuidado_y_Servicios_Sociales/MapServer/168',
  (SELECT max(fecha_descarga)::date FROM staging.red_peatonal_pot_respuestas), 'Zona cargada', 'Capa del POT, no es un levantamiento de andenes'),
 ('OpenStreetMap - Alimentos', 'OpenStreetMap contributors (ODbL)',
  'https://overpass-api.de/api/interpreter',
  (SELECT max(fecha_consulta)::date FROM staging.osm_alimentos_respuesta), 'Localidad', 'Subestima las tiendas de barrio'),
 ('Datos Abiertos - Plazas de mercado', 'Instituto para la Economia Social (IPES) / Datos Abiertos Bogota',
  'https://datosabiertos.bogota.gov.co/dataset/fd2a6046-5cc3-4acd-81ac-03fe5ef7d549', NULL, 'Bogota', 'Fecha de descarga no registrada; sistema de referencia local 990047')
ON CONFLICT (nombre) DO NOTHING;

-- Tablas crudas del cargador (se reemplazan completas en cada carga).
CREATE TABLE IF NOT EXISTS staging.predio_catastro (
  objectid   bigint, chip text, barmanpre text, nupre text, clase text, destino text,
  cod_uso text, area_uso numeric, area_terreno numeric, area_construida numeric,
  uso_vivienda text, unidad_calificada text, direccion text, vigencia_actual int,
  atributos jsonb
);
CREATE TABLE IF NOT EXISTS staging.estrato_poligono (
  objectid bigint, codigo_manzana text, estrato int, fecha_captura date, geom geometry(MultiPolygon, 9377)
);
CREATE TABLE IF NOT EXISTS staging.obra_publica (
  objectid bigint, cod_obra text, obra text, entidad int, localidad int, estado int,
  tipo_obra int, fecha_actualizacion date, upz text, geom geometry(MultiPoint, 9377)
);
CREATE TABLE IF NOT EXISTS staging.gtfs_parada (
  stop_id text PRIMARY KEY, stop_code text, stop_name text, zone_id text, geom geometry(Point, 9377)
);
CREATE TABLE IF NOT EXISTS staging.gtfs_ruta (
  route_id text PRIMARY KEY, route_short_name text, route_long_name text, route_type int,
  agency_id text, shape_id text, geom geometry(LineString, 9377)
);
CREATE TABLE IF NOT EXISTS staging.gtfs_ruta_parada (
  route_id text, stop_id text, orden int, PRIMARY KEY (route_id, stop_id)
);

-- Localidad completa: lotes y malla vial de Catastro / IDECA y comercio de alimentos de OpenStreetMap.
CREATE TABLE IF NOT EXISTS staging.lote_catastro (
  objectid       bigint PRIMARY KEY,
  codigo_lote    text NOT NULL,
  codigo_manzana text NOT NULL,
  geom           geometry(MultiPolygon, 9377) NOT NULL
);
CREATE INDEX IF NOT EXISTS lote_catastro_manzana ON staging.lote_catastro (codigo_manzana);

CREATE TABLE IF NOT EXISTS staging.malla_vial_catastro (
  objectid      bigint PRIMARY KEY,
  codigo_vial   text,
  nombre_via    text,
  clasificacion text,
  tipo          text,
  geom          geometry(MultiLineString, 9377) NOT NULL
);

CREATE TABLE IF NOT EXISTS staging.osm_elemento (
  id        serial PRIMARY KEY,
  tipo_osm  text NOT NULL,
  id_osm    bigint NOT NULL,
  nombre    text,
  categoria text NOT NULL,
  etiquetas jsonb,
  geom      geometry(Point, 9377) NOT NULL,
  UNIQUE (tipo_osm, id_osm)
);

CREATE UNIQUE INDEX IF NOT EXISTS predio_catastro_objectid ON staging.predio_catastro (objectid);
CREATE INDEX IF NOT EXISTS predio_catastro_barmanpre ON staging.predio_catastro (barmanpre);

-- Comedores comunitarios de la SDIS (los llena Scripts/loader/sdis.py).
CREATE TABLE IF NOT EXISTS staging.comedor_comunitario (
  objectid         int PRIMARY KEY,
  unidad_operativa text,
  direccion        text,
  horario_atencion text,
  localidad        text,
  geom             geometry(Point, 9377),
  fecha_carga      date DEFAULT current_date,
  atributos        jsonb
);
