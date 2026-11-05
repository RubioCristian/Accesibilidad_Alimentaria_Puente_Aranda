-- 04: alimentos. Categorias y establecimientos (ya conectados a la red en el trabajo anterior).
DROP TABLE IF EXISTS alimentos.establecimiento, alimentos.categoria CASCADE;

CREATE TABLE alimentos.categoria (
  id     serial PRIMARY KEY,
  nombre text NOT NULL UNIQUE
);
INSERT INTO alimentos.categoria (nombre)
SELECT DISTINCT categoria FROM crudo.legado_establecimientos_red_peatonal ORDER BY 1;

CREATE TABLE alimentos.establecimiento (
  id                serial PRIMARY KEY,
  codigo_origen     text NOT NULL UNIQUE,
  nombre            text,
  categoria_id      int NOT NULL REFERENCES alimentos.categoria(id),
  predio_id         int REFERENCES territorio.predio(id),
  fuente_id         int REFERENCES crudo.fuente_dato(id),
  fecha_observacion date,
  fecha_carga       date,
  geom              geometry(Point, 9377) NOT NULL
);
INSERT INTO alimentos.establecimiento (codigo_origen, nombre, categoria_id, predio_id, fuente_id, fecha_carga, geom)
SELECT e.establecimiento_id, e.nombre, c.id,
       (SELECT min(p.id) FROM territorio.lote l JOIN territorio.predio p ON p.lote_id = l.id
         WHERE ST_Intersects(l.geom, e.punto_establecimiento)),
       f.id, f.fecha_descarga, e.punto_establecimiento
FROM crudo.legado_establecimientos_red_peatonal e
JOIN alimentos.categoria c ON c.nombre = e.categoria
LEFT JOIN crudo.fuente_dato f ON f.nombre = CASE WHEN e.fuente LIKE 'Datos%' THEN 'Datos Abiertos - Plazas de mercado'
                                                  ELSE 'OpenStreetMap - Alimentos' END;

CREATE INDEX ON alimentos.establecimiento USING gist (geom);
