-- 06: movilidad - red peatonal (nodo_red, arista_red), accesos de predios y establecimientos, obras sobre la red.
DROP TABLE IF EXISTS movilidad.acceso_establecimiento, movilidad.punto_acceso,
                     movilidad.arista_red, movilidad.nodo_red CASCADE;

CREATE TABLE movilidad.nodo_red (
  id   bigint PRIMARY KEY,
  geom geometry(Point, 9377) NOT NULL
);
INSERT INTO movilidad.nodo_red (id, geom) SELECT id, geom FROM crudo.legado_red_peatonal_nodos;

CREATE TABLE movilidad.arista_red (
  id                bigint PRIMARY KEY,
  origen_id         bigint NOT NULL REFERENCES movilidad.nodo_red(id),
  destino_id        bigint NOT NULL REFERENCES movilidad.nodo_red(id),
  via_id            int REFERENCES movilidad.via(id),
  anden_id          int REFERENCES movilidad.anden(id),
  conexion_id       int REFERENCES movilidad.conexion_peatonal(id),
  fuente_id         int REFERENCES crudo.fuente_dato(id),
  fecha_observacion date,
  fecha_carga       date,
  modo              text NOT NULL DEFAULT 'peatonal',
  longitud          numeric NOT NULL CHECK (longitud >= 0),
  geom              geometry(LineString, 9377) NOT NULL
);
INSERT INTO movilidad.arista_red (id, origen_id, destino_id, anden_id, conexion_id, fuente_id, fecha_carga, longitud, geom)
SELECT a.id, a.source, a.target, an.id, cx.id, f.id, f.fecha_descarga, ST_Length(a.geom), a.geom
FROM crudo.legado_red_peatonal_aristas a
LEFT JOIN crudo.fuente_dato f ON f.nombre = 'Mapa de Referencia - Anden'
LEFT JOIN LATERAL (
   SELECT s.id, s.tipo, s.objectid_anden FROM crudo.legado_red_peatonal_segmentos s
   WHERE ST_DWithin(s.geom, ST_LineInterpolatePoint(a.geom, 0.5), 0.01)
   ORDER BY ST_Distance(s.geom, ST_LineInterpolatePoint(a.geom, 0.5)) LIMIT 1) seg ON true
LEFT JOIN movilidad.anden an ON an.objectid_orig = seg.objectid_anden AND seg.tipo = 'Eje de anden'
LEFT JOIN movilidad.conexion_peatonal cx ON cx.segmento_origen = seg.id AND seg.tipo <> 'Eje de anden';

-- Punto de acceso: el predio hereda el acceso a la red de su lote. Se ancla al nodo extremo mas cercano
-- y distancia_acceso suma lote-red + tramo hasta ese nodo.
CREATE TABLE movilidad.punto_acceso (
  id               serial PRIMARY KEY,
  predio_id        int NOT NULL UNIQUE REFERENCES territorio.predio(id),
  nodo_id          bigint NOT NULL REFERENCES movilidad.nodo_red(id),
  distancia_acceso numeric NOT NULL CHECK (distancia_acceso >= 0),
  geom             geometry(Point, 9377) NOT NULL
);
INSERT INTO movilidad.punto_acceso (predio_id, nodo_id, distancia_acceso, geom)
SELECT p.id,
       CASE WHEN r.fraccion_arista < 0.5 THEN a.origen_id ELSE a.destino_id END,
       r.distancia_eje_m + a.longitud * CASE WHEN r.fraccion_arista < 0.5 THEN r.fraccion_arista ELSE 1 - r.fraccion_arista END,
       r.punto_red
FROM crudo.legado_lotes_red_peatonal r
JOIN territorio.lote l ON l.codigo = r.codigo_lote
JOIN territorio.predio p ON p.lote_id = l.id
JOIN movilidad.arista_red a ON a.id = r.arista_id
WHERE r.arista_id IS NOT NULL;

-- Extension del ER: el establecimiento tambien se ancla a la red.
CREATE TABLE movilidad.acceso_establecimiento (
  establecimiento_id int PRIMARY KEY REFERENCES alimentos.establecimiento(id),
  nodo_id            bigint NOT NULL REFERENCES movilidad.nodo_red(id),
  distancia_acceso   numeric NOT NULL CHECK (distancia_acceso >= 0)
);
INSERT INTO movilidad.acceso_establecimiento (establecimiento_id, nodo_id, distancia_acceso)
SELECT e.id,
       CASE WHEN r.fraccion_arista < 0.5 THEN a.origen_id ELSE a.destino_id END,
       r.distancia_conexion_m + a.longitud * CASE WHEN r.fraccion_arista < 0.5 THEN r.fraccion_arista ELSE 1 - r.fraccion_arista END
FROM crudo.legado_establecimientos_red_peatonal r
JOIN alimentos.establecimiento e ON e.codigo_origen = r.establecimiento_id
JOIN movilidad.arista_red a ON a.id = r.arista_id;

CREATE TABLE movilidad.obra_arista (
  obra_id   int    NOT NULL REFERENCES movilidad.obra(id),
  arista_id bigint NOT NULL REFERENCES movilidad.arista_red(id),
  PRIMARY KEY (obra_id, arista_id)
);
INSERT INTO movilidad.obra_arista (obra_id, arista_id)
SELECT o.id, a.id FROM movilidad.obra o JOIN movilidad.arista_red a ON ST_Intersects(o.geom, a.geom);

CREATE INDEX ON movilidad.nodo_red USING gist (geom);
CREATE INDEX ON movilidad.arista_red USING gist (geom);
CREATE INDEX ON movilidad.arista_red (origen_id);
CREATE INDEX ON movilidad.arista_red (destino_id);
CREATE INDEX ON movilidad.punto_acceso (nodo_id);
CREATE INDEX ON movilidad.punto_acceso USING gist (geom);
