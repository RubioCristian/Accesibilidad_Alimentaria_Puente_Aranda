-- 05: movilidad - infraestructura (via, anden, conexion peatonal, obra).
DROP TABLE IF EXISTS movilidad.obra_arista, movilidad.obra, movilidad.conexion_peatonal,
                     movilidad.anden, movilidad.via CASCADE;

CREATE TABLE movilidad.via (
  id     serial PRIMARY KEY,
  codigo text,
  tipo   text,
  nombre text,
  geom   geometry(MultiLineString, 9377) NOT NULL CHECK (ST_IsValid(geom))
);
INSERT INTO movilidad.via (codigo, tipo, nombre, geom)
SELECT codigo_vial, 'clasificacion ' || clasificacion, nombre_via, ST_Multi(ST_MakeValid(geom))
FROM crudo.legado_malla_vial;

CREATE TABLE movilidad.anden (
  id            serial PRIMARY KEY,
  objectid_orig bigint UNIQUE,
  codigo        text,
  ancho         numeric,            -- sin dato en la fuente
  geom          geometry(MultiPolygon, 9377) NOT NULL CHECK (ST_IsValid(geom))
);
INSERT INTO movilidad.anden (objectid_orig, codigo, geom)
SELECT objectid, codigo_anden, ST_Multi(ST_MakeValid(geom)) FROM crudo.legado_andenes;

-- Conexiones entre andenes: contactos, cruces validados y conexiones adicionales (todo lo que no es eje).
CREATE TABLE movilidad.conexion_peatonal (
  id              serial PRIMARY KEY,
  segmento_origen int,
  tipo            text NOT NULL,
  geom            geometry(LineString, 9377) NOT NULL
);
INSERT INTO movilidad.conexion_peatonal (segmento_origen, tipo, geom)
SELECT id, tipo, geom FROM crudo.legado_red_peatonal_segmentos WHERE tipo <> 'Eje de anden';

-- Obra: unica barrera modelada. La fuente trae puntos; el area de afectacion es un SUPUESTO (buffer de 25 m).
CREATE TABLE movilidad.obra (
  id                  serial PRIMARY KEY,
  codigo              text,
  nombre              text,
  entidad             int,
  estado              text NOT NULL CHECK (estado IN ('en ejecucion', 'ejecutada', 'proxima')),
  fecha_actualizacion date,
  fuente_id           int REFERENCES crudo.fuente_dato(id),
  radio_afectacion_m  numeric NOT NULL DEFAULT 25,
  geom_punto          geometry(MultiPoint, 9377) NOT NULL,
  geom                geometry(MultiPolygon, 9377) NOT NULL
);
INSERT INTO movilidad.obra (codigo, nombre, entidad, estado, fecha_actualizacion, fuente_id, geom_punto, geom)
SELECT o.cod_obra, o.obra, o.entidad,
       CASE o.estado WHEN 1 THEN 'en ejecucion' WHEN 2 THEN 'ejecutada' ELSE 'proxima' END,
       o.fecha_actualizacion, (SELECT id FROM crudo.fuente_dato WHERE nombre = 'Obras publicas'),
       o.geom, ST_Multi(ST_Buffer(o.geom, 25))
FROM crudo.obra_publica o;

CREATE INDEX ON movilidad.via USING gist (geom);
CREATE INDEX ON movilidad.anden USING gist (geom);
CREATE INDEX ON movilidad.conexion_peatonal USING gist (geom);
CREATE INDEX ON movilidad.obra USING gist (geom);

COMMENT ON TABLE movilidad.obra IS 'Barrera de acceso. geom = buffer supuesto alrededor del punto publicado';
