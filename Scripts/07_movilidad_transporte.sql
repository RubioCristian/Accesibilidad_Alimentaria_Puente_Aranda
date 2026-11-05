-- 07: movilidad - estaciones y rutas de TransMilenio y SITP (desde el GTFS cargado en crudo).
-- Solo entran las paradas a menos de 200 m de un nodo de la red peatonal cargada.
-- TransMilenio = agencias GTFS 1, 2, 6 y 7 (troncal, alimentadores, dual y cable); SITP = zonales 3, 4 y 5.
DROP TABLE IF EXISTS movilidad.ruta_estacion_sitp, movilidad.ruta_estacion_tm,
                     movilidad.ruta_sitp, movilidad.ruta_transmilenio,
                     movilidad.estacion_sitp, movilidad.estacion_transmilenio CASCADE;

CREATE TABLE movilidad.estacion_transmilenio (
  id               serial PRIMARY KEY,
  codigo           text NOT NULL UNIQUE,
  nodo_id          bigint NOT NULL REFERENCES movilidad.nodo_red(id),
  nombre           text,
  distancia_acceso numeric,
  geom             geometry(Point, 9377) NOT NULL
);
CREATE TABLE movilidad.estacion_sitp (LIKE movilidad.estacion_transmilenio INCLUDING ALL);
ALTER TABLE movilidad.estacion_sitp ADD FOREIGN KEY (nodo_id) REFERENCES movilidad.nodo_red(id);

CREATE TEMP TABLE _parada_tipo AS
SELECT DISTINCT rp.stop_id, r.agency_id IN ('1', '2', '6', '7') AS es_tm
FROM crudo.gtfs_ruta_parada rp JOIN crudo.gtfs_ruta r USING (route_id);

INSERT INTO movilidad.estacion_transmilenio (codigo, nodo_id, nombre, distancia_acceso, geom)
SELECT p.stop_id, n.id, p.stop_name, n.d, p.geom
FROM crudo.gtfs_parada p
JOIN LATERAL (SELECT nr.id, ST_Distance(nr.geom, p.geom) AS d FROM movilidad.nodo_red nr
              ORDER BY nr.geom <-> p.geom LIMIT 1) n ON n.d <= 200
WHERE p.stop_id IN (SELECT stop_id FROM _parada_tipo WHERE es_tm);

INSERT INTO movilidad.estacion_sitp (codigo, nodo_id, nombre, distancia_acceso, geom)
SELECT p.stop_id, n.id, p.stop_name, n.d, p.geom
FROM crudo.gtfs_parada p
JOIN LATERAL (SELECT nr.id, ST_Distance(nr.geom, p.geom) AS d FROM movilidad.nodo_red nr
              ORDER BY nr.geom <-> p.geom LIMIT 1) n ON n.d <= 200
WHERE p.stop_id IN (SELECT stop_id FROM _parada_tipo WHERE NOT es_tm);

CREATE TABLE movilidad.ruta_transmilenio (
  id       serial PRIMARY KEY,
  codigo   text NOT NULL UNIQUE,
  nombre   text,
  route_id text,
  geom     geometry(LineString, 9377)
);
CREATE TABLE movilidad.ruta_sitp (LIKE movilidad.ruta_transmilenio INCLUDING ALL);

CREATE TABLE movilidad.ruta_estacion_tm (
  ruta_id     int NOT NULL REFERENCES movilidad.ruta_transmilenio(id),
  estacion_id int NOT NULL REFERENCES movilidad.estacion_transmilenio(id),
  orden       int,
  PRIMARY KEY (ruta_id, estacion_id)
);
CREATE TABLE movilidad.ruta_estacion_sitp (
  ruta_id     int NOT NULL REFERENCES movilidad.ruta_sitp(id),
  estacion_id int NOT NULL REFERENCES movilidad.estacion_sitp(id),
  orden       int,
  PRIMARY KEY (ruta_id, estacion_id)
);

-- El nombre corto puede repetirse entre agencias; el codigo lleva el route_id.
INSERT INTO movilidad.ruta_transmilenio (codigo, nombre, route_id, geom)
SELECT r.route_short_name || '#' || r.route_id, r.route_long_name, r.route_id, r.geom
FROM crudo.gtfs_ruta r
WHERE r.agency_id IN ('1', '2', '6', '7')
  AND EXISTS (SELECT 1 FROM crudo.gtfs_ruta_parada rp JOIN movilidad.estacion_transmilenio e ON e.codigo = rp.stop_id
              WHERE rp.route_id = r.route_id);
INSERT INTO movilidad.ruta_sitp (codigo, nombre, route_id, geom)
SELECT r.route_short_name || '#' || r.route_id, r.route_long_name, r.route_id, r.geom
FROM crudo.gtfs_ruta r
WHERE r.agency_id NOT IN ('1', '2', '6', '7')
  AND EXISTS (SELECT 1 FROM crudo.gtfs_ruta_parada rp JOIN movilidad.estacion_sitp e ON e.codigo = rp.stop_id
              WHERE rp.route_id = r.route_id);

INSERT INTO movilidad.ruta_estacion_tm
SELECT rt.id, e.id, rp.orden FROM crudo.gtfs_ruta_parada rp
JOIN movilidad.ruta_transmilenio rt ON rt.route_id = rp.route_id
JOIN movilidad.estacion_transmilenio e ON e.codigo = rp.stop_id;
INSERT INTO movilidad.ruta_estacion_sitp
SELECT rt.id, e.id, rp.orden FROM crudo.gtfs_ruta_parada rp
JOIN movilidad.ruta_sitp rt ON rt.route_id = rp.route_id
JOIN movilidad.estacion_sitp e ON e.codigo = rp.stop_id;

CREATE INDEX ON movilidad.estacion_transmilenio USING gist (geom);
CREATE INDEX ON movilidad.estacion_sitp USING gist (geom);
CREATE INDEX ON movilidad.ruta_transmilenio USING gist (geom);
CREATE INDEX ON movilidad.ruta_sitp USING gist (geom);
