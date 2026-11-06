-- 04: alimentos. Categorias y establecimientos (ya conectados a la red en el trabajo anterior).
DROP TABLE IF EXISTS alimentos.establecimiento, alimentos.categoria CASCADE;

CREATE TABLE alimentos.categoria (
  id     serial PRIMARY KEY,
  nombre text NOT NULL UNIQUE
);
INSERT INTO alimentos.categoria (nombre) VALUES
 ('Carniceria'), ('Comedor comunitario'), ('Fruteria y verduleria'), ('Panaderia'), ('Plaza de mercado'), ('Supermercado'), ('Tienda de conveniencia');

CREATE TABLE alimentos.establecimiento (
  id                serial PRIMARY KEY,
  codigo_origen     text NOT NULL UNIQUE,
  nombre            text,
  categoria_id      int NOT NULL REFERENCES alimentos.categoria(id),
  predio_id         int REFERENCES territorio.predio(id),
  fuente_id         int REFERENCES staging.fuente_dato(id),
  fecha_observacion date,
  fecha_carga       date,
  geom              geometry(Point, 9377) NOT NULL
);
-- Plazas de mercado (Datos Abiertos, SRID 990047), comedores comunitarios de la SDIS y comercio de OpenStreetMap dentro de la localidad.
-- Una plaza de OSM a menos de 150 m de una plaza oficial se descarta por duplicada.
CREATE TEMP TABLE _plaza AS
SELECT p.gid::text AS codigo, p.nombre, ST_Centroid(ST_Transform(ST_SetSRID(p.geom, 990047), 9377)) AS geom
FROM staging.legado_plaza_mercado p
WHERE ST_Intersects(ST_Centroid(ST_Transform(ST_SetSRID(p.geom, 990047), 9377)), (SELECT geom FROM territorio.localidad LIMIT 1));

INSERT INTO alimentos.establecimiento (codigo_origen, nombre, categoria_id, predio_id, fuente_id, fecha_carga, geom)
SELECT x.codigo, x.nombre, c.id,
       (SELECT min(p.id) FROM territorio.lote l JOIN territorio.predio p ON p.lote_id = l.id
         WHERE ST_Intersects(l.geom, x.geom)),
       f.id, f.fecha_descarga, x.geom
FROM (SELECT 'plaza-' || codigo AS codigo, nombre, 'Plaza de mercado' AS categoria, geom,
             'Datos Abiertos - Plazas de mercado' AS fuente FROM _plaza
      UNION ALL
      SELECT 'comedor-' || c.objectid, c.unidad_operativa, 'Comedor comunitario', c.geom, 'SDIS - Comedores comunitarios'
      FROM staging.comedor_comunitario c
      WHERE ST_Intersects(c.geom, (SELECT geom FROM territorio.localidad LIMIT 1))
      UNION ALL
      SELECT 'osm-' || o.tipo_osm || '-' || o.id_osm, o.nombre, o.categoria, o.geom, 'OpenStreetMap - Alimentos'
      FROM staging.osm_elemento o
      WHERE ST_Intersects(o.geom, (SELECT geom FROM territorio.localidad LIMIT 1))
        AND NOT (o.categoria = 'Plaza de mercado' AND EXISTS (SELECT 1 FROM _plaza z WHERE ST_DWithin(z.geom, o.geom, 150)))
     ) x
JOIN alimentos.categoria c ON c.nombre = x.categoria
LEFT JOIN staging.fuente_dato f ON f.nombre = x.fuente;

CREATE INDEX ON alimentos.establecimiento USING gist (geom);
