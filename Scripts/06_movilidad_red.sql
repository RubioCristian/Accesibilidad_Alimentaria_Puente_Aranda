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

-- Union topologica: los ejes de anden dejan extremos sueltos (grado 1) a pocos centimetros de otra arista sin
-- compartir nodo, lo que parte la red. Cada extremo suelto a <= 2 m de otra arista se une a ella; si el punto mas
-- cercano cae en el interior de la arista, esta se divide con un nodo nuevo.
CREATE TEMP TABLE _union_log (extremo bigint, arista bigint, distancia numeric, dividio boolean);
DO $$
DECLARE
  s record; e record; q geometry; f double precision; destino_id bigint;
  nid bigint; aid bigint; cid int; d numeric; ng geometry;
BEGIN
  SELECT max(id) INTO nid FROM movilidad.nodo_red;
  SELECT max(id) INTO aid FROM movilidad.arista_red;
  FOR s IN SELECT n.id, n.geom FROM movilidad.nodo_red n
           JOIN movilidad.arista_red a ON a.origen_id = n.id OR a.destino_id = n.id
           GROUP BY n.id, n.geom HAVING count(*) = 1 ORDER BY n.id
  LOOP
    SELECT a.* INTO e FROM movilidad.arista_red a
     WHERE a.origen_id <> s.id AND a.destino_id <> s.id AND ST_DWithin(a.geom, s.geom, 2)
     ORDER BY ST_Distance(a.geom, s.geom) LIMIT 1;
    CONTINUE WHEN NOT FOUND;
    q := ST_ClosestPoint(e.geom, s.geom);
    d := ST_Distance(q, s.geom);
    IF ST_Distance(q, ST_StartPoint(e.geom)) < 0.01 THEN
      destino_id := e.origen_id;
      INSERT INTO _union_log VALUES (s.id, e.id, d, false);
    ELSIF ST_Distance(q, ST_EndPoint(e.geom)) < 0.01 THEN
      destino_id := e.destino_id;
      INSERT INTO _union_log VALUES (s.id, e.id, d, false);
    ELSE
      nid := nid + 1; aid := aid + 1; destino_id := nid;
      f := ST_LineLocatePoint(e.geom, q);
      INSERT INTO movilidad.nodo_red (id, geom) VALUES (nid, q);
      INSERT INTO movilidad.arista_red (id, origen_id, destino_id, via_id, anden_id, conexion_id, fuente_id,
                                        fecha_carga, modo, longitud, geom)
      SELECT aid, nid, e.destino_id, e.via_id, e.anden_id, e.conexion_id, e.fuente_id, e.fecha_carga, e.modo,
             ST_Length(ST_LineSubstring(e.geom, f, 1)), ST_LineSubstring(e.geom, f, 1);
      UPDATE movilidad.arista_red SET destino_id = nid, geom = ST_LineSubstring(e.geom, 0, f),
             longitud = ST_Length(ST_LineSubstring(e.geom, 0, f)) WHERE id = e.id;
      INSERT INTO _union_log VALUES (s.id, e.id, d, true);
    END IF;
    SELECT geom INTO ng FROM movilidad.nodo_red WHERE id = destino_id;
    IF ST_Distance(s.geom, ng) > 0 THEN
      aid := aid + 1;
      INSERT INTO movilidad.conexion_peatonal (segmento_origen, tipo, geom)
      VALUES (NULL, 'Union topologica (<= 2 m)', ST_MakeLine(s.geom, ng)) RETURNING id INTO cid;
      INSERT INTO movilidad.arista_red (id, origen_id, destino_id, conexion_id, fecha_carga, longitud, geom)
      VALUES (aid, s.id, destino_id, cid, current_date, ST_Distance(s.geom, ng), ST_MakeLine(s.geom, ng));
    END IF;
  END LOOP;
END $$;

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
JOIN territorio.lote l ON l.codigo = r.codigo_lote AND l.tipo = 'predial'
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
