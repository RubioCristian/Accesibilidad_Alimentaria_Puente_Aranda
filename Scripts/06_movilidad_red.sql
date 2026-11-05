-- 06: movilidad - red peatonal derivada de la malla vial, accesos de predios y establecimientos, obras sobre la red.
-- La red camina por el eje de calzada (no hay andenes ni cruces para toda la localidad). Pasos:
--   1) los ejes se nodan en las intersecciones; 2) los extremos sueltos a <= 2 m de otra arista se unen;
--   3) cada lote y cada establecimiento se ancla a la arista mas cercana, que se parte en ese punto.
DROP TABLE IF EXISTS movilidad.acceso_establecimiento, movilidad.punto_acceso,
                     movilidad.arista_red, movilidad.nodo_red CASCADE;

CREATE TABLE movilidad.nodo_red (
  id   bigint PRIMARY KEY,
  geom geometry(Point, 9377) NOT NULL
);

CREATE TABLE movilidad.arista_red (
  id                bigint PRIMARY KEY,
  origen_id         bigint NOT NULL REFERENCES movilidad.nodo_red(id),
  destino_id        bigint NOT NULL REFERENCES movilidad.nodo_red(id),
  via_id            int REFERENCES movilidad.via(id),
  anden_id          int REFERENCES movilidad.anden(id),            -- sin uso: la red no se deriva de andenes
  conexion_id       int REFERENCES movilidad.conexion_peatonal(id), -- sin uso
  fuente_id         int REFERENCES crudo.fuente_dato(id),
  fecha_observacion date,
  fecha_carga       date,
  modo              text NOT NULL DEFAULT 'peatonal',
  origen            text NOT NULL DEFAULT 'malla vial',   -- malla vial | union topologica
  longitud          numeric NOT NULL CHECK (longitud >= 0),
  geom              geometry(LineString, 9377) NOT NULL
);

-- 1) Nodado de los ejes viales.
CREATE TEMP TABLE _seg AS
SELECT row_number() OVER ()::bigint AS id, (d).geom AS geom
FROM (SELECT ST_Dump(ST_Node(ST_UnaryUnion(ST_Collect(geom)))) AS d FROM movilidad.via) s;
DELETE FROM _seg WHERE ST_Length(geom) < 0.001;

INSERT INTO movilidad.nodo_red (id, geom)
SELECT row_number() OVER (), g FROM (
  SELECT DISTINCT ON (ST_AsBinary(g)) g
  FROM (SELECT ST_StartPoint(geom) AS g FROM _seg UNION ALL SELECT ST_EndPoint(geom) FROM _seg) p
  ORDER BY ST_AsBinary(g)) q;
CREATE INDEX ON movilidad.nodo_red USING gist (geom);
CREATE TEMP TABLE _nodo_clave AS SELECT id, ST_AsBinary(geom) AS k FROM movilidad.nodo_red;
CREATE INDEX ON _nodo_clave (k);

INSERT INTO movilidad.arista_red (id, origen_id, destino_id, via_id, fuente_id, fecha_carga, longitud, geom)
SELECT s.id, o.id, d.id, v.id, f.id, f.fecha_descarga, ST_Length(s.geom), s.geom
FROM _seg s
JOIN _nodo_clave o ON o.k = ST_AsBinary(ST_StartPoint(s.geom))
JOIN _nodo_clave d ON d.k = ST_AsBinary(ST_EndPoint(s.geom))
LEFT JOIN LATERAL (SELECT id FROM movilidad.via v WHERE ST_DWithin(v.geom, ST_LineInterpolatePoint(s.geom, 0.5), 0.01)
                   ORDER BY ST_Distance(v.geom, ST_LineInterpolatePoint(s.geom, 0.5)) LIMIT 1) v ON true
LEFT JOIN crudo.fuente_dato f ON f.nombre = 'Mapa de Referencia - Malla vial'
WHERE o.id <> d.id;
CREATE INDEX ON movilidad.arista_red USING gist (geom);
CREATE INDEX ON movilidad.arista_red (origen_id);
CREATE INDEX ON movilidad.arista_red (destino_id);

-- 2) Union topologica: los ejes dejan extremos sueltos (grado 1) a pocos centimetros de otra arista sin compartir
-- nodo, lo que parte la red. Cada extremo suelto a <= 2 m de otra arista se une a ella; si el punto mas cercano
-- cae en el interior de la arista, esta se divide con un nodo nuevo.
CREATE TEMP TABLE _union_log (extremo bigint, arista bigint, distancia numeric, dividio boolean);
DO $$
DECLARE
  s record; e record; q geometry; f double precision; destino bigint;
  nid bigint; aid bigint; d numeric; ng geometry;
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
      destino := e.origen_id;
      INSERT INTO _union_log VALUES (s.id, e.id, d, false);
    ELSIF ST_Distance(q, ST_EndPoint(e.geom)) < 0.01 THEN
      destino := e.destino_id;
      INSERT INTO _union_log VALUES (s.id, e.id, d, false);
    ELSE
      nid := nid + 1; aid := aid + 1; destino := nid;
      f := ST_LineLocatePoint(e.geom, q);
      INSERT INTO movilidad.nodo_red (id, geom) VALUES (nid, q);
      INSERT INTO movilidad.arista_red (id, origen_id, destino_id, via_id, fuente_id, fecha_carga, modo, longitud, geom)
      SELECT aid, nid, e.destino_id, e.via_id, e.fuente_id, e.fecha_carga, e.modo,
             ST_Length(ST_LineSubstring(e.geom, f, 1)), ST_LineSubstring(e.geom, f, 1);
      UPDATE movilidad.arista_red SET destino_id = nid, geom = ST_LineSubstring(e.geom, 0, f),
             longitud = ST_Length(ST_LineSubstring(e.geom, 0, f)) WHERE id = e.id;
      INSERT INTO _union_log VALUES (s.id, e.id, d, true);
    END IF;
    SELECT geom INTO ng FROM movilidad.nodo_red WHERE id = destino;
    IF ST_Distance(s.geom, ng) > 0 THEN
      aid := aid + 1;
      INSERT INTO movilidad.arista_red (id, origen_id, destino_id, fecha_carga, origen, longitud, geom)
      VALUES (aid, s.id, destino, current_date, 'union topologica', ST_Distance(s.geom, ng), ST_MakeLine(s.geom, ng));
    END IF;
  END LOOP;
END $$;

-- 3) Puntos de anclaje a la red: cada lote predial y cada establecimiento a su arista mas cercana.
-- La posicion se redondea al metro para que lotes vecinos compartan nodo; el predio hereda el anclaje de su lote.
CREATE TEMP TABLE _anc AS
SELECT 'lote'::text AS tipo, l.id AS ref, a.id AS arista_id, a.longitud, a.origen_id, a.destino_id,
       ST_Distance(a.geom, l.geom) AS dist,
       ST_LineLocatePoint(a.geom, ST_ClosestPoint(a.geom, l.geom)) * a.longitud AS pos
FROM territorio.lote l
CROSS JOIN LATERAL (SELECT * FROM movilidad.arista_red a ORDER BY a.geom <-> l.geom LIMIT 1) a
WHERE l.tipo = 'predial'
UNION ALL
SELECT 'establecimiento', e.id, a.id, a.longitud, a.origen_id, a.destino_id,
       ST_Distance(a.geom, e.geom), ST_LineLocatePoint(a.geom, ST_ClosestPoint(a.geom, e.geom)) * a.longitud
FROM alimentos.establecimiento e
CROSS JOIN LATERAL (SELECT * FROM movilidad.arista_red a ORDER BY a.geom <-> e.geom LIMIT 1) a;

ALTER TABLE _anc ADD COLUMN k int;
UPDATE _anc SET k = round(pos);

-- Cortes: posiciones interiores (0 < k < longitud) por arista.
CREATE TEMP TABLE _corte AS
SELECT DISTINCT arista_id, k FROM _anc WHERE k > 0 AND k < longitud;
CREATE TEMP TABLE _nodo_nuevo AS
SELECT (SELECT max(id) FROM movilidad.nodo_red) + row_number() OVER (ORDER BY c.arista_id, c.k) AS id,
       c.arista_id, c.k, ST_LineInterpolatePoint(a.geom, c.k / a.longitud) AS geom
FROM _corte c JOIN movilidad.arista_red a ON a.id = c.arista_id;
INSERT INTO movilidad.nodo_red (id, geom) SELECT id, geom FROM _nodo_nuevo;

CREATE TEMP TABLE _pieza AS
WITH afectadas AS (SELECT DISTINCT arista_id FROM _corte),
puntos AS (
  SELECT a.id AS arista_id, 0::numeric AS k, a.origen_id AS nodo FROM movilidad.arista_red a JOIN afectadas x ON x.arista_id = a.id
  UNION ALL SELECT arista_id, k, id FROM _nodo_nuevo
  UNION ALL SELECT a.id, a.longitud, a.destino_id FROM movilidad.arista_red a JOIN afectadas x ON x.arista_id = a.id),
orden AS (
  SELECT arista_id, k AS k1, nodo AS n1, lead(k) OVER w AS k2, lead(nodo) OVER w AS n2
  FROM puntos WINDOW w AS (PARTITION BY arista_id ORDER BY k))
SELECT row_number() OVER () + (SELECT max(id) FROM movilidad.arista_red) AS nuevo_id, * FROM orden WHERE k2 IS NOT NULL;

INSERT INTO movilidad.arista_red (id, origen_id, destino_id, via_id, fuente_id, fecha_carga, modo, origen, longitud, geom)
SELECT p.nuevo_id, p.n1, p.n2, a.via_id, a.fuente_id, a.fecha_carga, a.modo, a.origen,
       ST_Length(ST_LineSubstring(a.geom, (p.k1 / a.longitud)::float, (p.k2 / a.longitud)::float)),
       ST_LineSubstring(a.geom, (p.k1 / a.longitud)::float, (p.k2 / a.longitud)::float)
FROM _pieza p JOIN movilidad.arista_red a ON a.id = p.arista_id;
DELETE FROM movilidad.arista_red WHERE id IN (SELECT arista_id FROM _corte);

-- Nodo de cada anclaje: el nodo cortado en k o, en los extremos, el origen o destino de la arista.
ALTER TABLE _anc ADD COLUMN nodo_id bigint;
UPDATE _anc a SET nodo_id = n.id FROM _nodo_nuevo n WHERE n.arista_id = a.arista_id AND n.k = a.k;
UPDATE _anc SET nodo_id = origen_id WHERE nodo_id IS NULL AND k <= 0;
UPDATE _anc SET nodo_id = destino_id WHERE nodo_id IS NULL AND k >= longitud;

CREATE TABLE movilidad.punto_acceso (
  id               serial PRIMARY KEY,
  predio_id        int NOT NULL UNIQUE REFERENCES territorio.predio(id),
  nodo_id          bigint NOT NULL REFERENCES movilidad.nodo_red(id),
  distancia_acceso numeric NOT NULL CHECK (distancia_acceso >= 0),
  geom             geometry(Point, 9377) NOT NULL
);
INSERT INTO movilidad.punto_acceso (predio_id, nodo_id, distancia_acceso, geom)
SELECT p.id, a.nodo_id, a.dist + abs(a.pos - a.k), n.geom
FROM _anc a JOIN territorio.predio p ON p.lote_id = a.ref JOIN movilidad.nodo_red n ON n.id = a.nodo_id
WHERE a.tipo = 'lote';

-- Extension del ER: el establecimiento tambien se ancla a la red.
CREATE TABLE movilidad.acceso_establecimiento (
  establecimiento_id int PRIMARY KEY REFERENCES alimentos.establecimiento(id),
  nodo_id            bigint NOT NULL REFERENCES movilidad.nodo_red(id),
  distancia_acceso   numeric NOT NULL CHECK (distancia_acceso >= 0)
);
INSERT INTO movilidad.acceso_establecimiento (establecimiento_id, nodo_id, distancia_acceso)
SELECT ref, nodo_id, dist + abs(pos - k) FROM _anc WHERE tipo = 'establecimiento';

CREATE TABLE movilidad.obra_arista (
  obra_id   int    NOT NULL REFERENCES movilidad.obra(id),
  arista_id bigint NOT NULL REFERENCES movilidad.arista_red(id),
  PRIMARY KEY (obra_id, arista_id)
);
INSERT INTO movilidad.obra_arista (obra_id, arista_id)
SELECT o.id, a.id FROM movilidad.obra o JOIN movilidad.arista_red a ON ST_Intersects(o.geom, a.geom);

CREATE INDEX ON movilidad.punto_acceso (nodo_id);
CREATE INDEX ON movilidad.punto_acceso USING gist (geom);
