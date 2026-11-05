-- 08: analisis. Escenarios, criterios, ejecuciones, matriz origen-destino por red e indicadores ICA / IPT por predio.
-- Las ejecuciones se lanzan con analisis.ejecutar(escenario_id, version_codigo) (lo hace Scripts/loader/run.py).
DROP TABLE IF EXISTS analisis.indicador_predio, analisis.matriz_od, analisis.ejecucion_analisis,
                     analisis.escenario_criterio, analisis.criterio_analitico, analisis.vecindad_manzana,
                     analisis.escenario CASCADE;
-- Resultados del trabajo anterior (se pueden regenerar con los scripts de Scripts/legacy).
DROP TABLE IF EXISTS analisis.abastecimiento_red_resultados, analisis.proximidad_red_resultados;

CREATE TABLE analisis.escenario (
  id                  serial PRIMARY KEY,
  nombre              text NOT NULL UNIQUE,
  manzanas_vecindad   int  NOT NULL CHECK (manzanas_vecindad > 0),
  descripcion         text,
  umbral_cobertura_m  numeric NOT NULL DEFAULT 800 CHECK (umbral_cobertura_m > 0),
  velocidad_peaton_ms numeric NOT NULL DEFAULT 1.25 CHECK (velocidad_peaton_ms > 0),
  bloquea_obras       boolean NOT NULL DEFAULT false,
  distancia_maxima_m  numeric NOT NULL DEFAULT 2000 CHECK (distancia_maxima_m > 0)   -- alcance de busqueda por la red
);

CREATE TABLE analisis.criterio_analitico (
  id            serial PRIMARY KEY,
  nombre        text NOT NULL UNIQUE,
  definicion    text,
  indice        text NOT NULL CHECK (indice IN ('ICA', 'IPT')),
  direccion     text NOT NULL CHECK (direccion IN ('beneficio', 'costo')),
  unidad        text,
  normalizacion text,
  tipo_dato     text NOT NULL CHECK (tipo_dato IN ('observado', 'calculado', 'inferido'))
);

CREATE TABLE analisis.escenario_criterio (
  escenario_id int NOT NULL REFERENCES analisis.escenario(id),
  criterio_id  int NOT NULL REFERENCES analisis.criterio_analitico(id),
  peso         numeric NOT NULL CHECK (peso > 0 AND peso <= 1),
  PRIMARY KEY (escenario_id, criterio_id)
);

CREATE TABLE analisis.ejecucion_analisis (
  id             serial PRIMARY KEY,
  escenario_id   int NOT NULL REFERENCES analisis.escenario(id),
  version_codigo text NOT NULL,
  fecha          timestamp NOT NULL DEFAULT now(),
  parametros     jsonb,
  estado         text NOT NULL DEFAULT 'en curso' CHECK (estado IN ('en curso', 'completada', 'fallida'))
);

-- Vecindad: la manzana del predio mas las N manzanas mas cercanas (N = manzanas_vecindad).
CREATE TABLE analisis.vecindad_manzana (
  escenario_id int NOT NULL REFERENCES analisis.escenario(id),
  manzana_id   int NOT NULL REFERENCES territorio.manzana(id),
  vecina_id    int NOT NULL REFERENCES territorio.manzana(id),
  PRIMARY KEY (escenario_id, manzana_id, vecina_id)
);

CREATE TABLE analisis.matriz_od (
  ejecucion_id         int NOT NULL REFERENCES analisis.ejecucion_analisis(id) ON DELETE CASCADE,
  predio_id            int NOT NULL REFERENCES territorio.predio(id),
  establecimiento_id   int NOT NULL REFERENCES alimentos.establecimiento(id),
  modo                 text NOT NULL,
  metodo               text,
  distancia_red        numeric NOT NULL,
  distancia_euclidiana numeric,
  tiempo               numeric,   -- segundos
  PRIMARY KEY (ejecucion_id, predio_id, establecimiento_id, modo)
);

CREATE TABLE analisis.indicador_predio (
  ejecucion_id       int NOT NULL REFERENCES analisis.ejecucion_analisis(id) ON DELETE CASCADE,
  predio_id          int NOT NULL REFERENCES territorio.predio(id),
  ica                numeric CHECK (ica BETWEEN 0 AND 100),
  ipt                numeric CHECK (ipt BETWEEN 0 AND 100),
  nota_incertidumbre text,
  acc_m              numeric,
  n_cobertura        int,
  n_categorias       int,
  estrato            smallint,
  acc_norm           numeric,
  cob_norm           numeric,
  div_norm           numeric,
  vul_norm           numeric,
  PRIMARY KEY (ejecucion_id, predio_id)
);

INSERT INTO analisis.criterio_analitico (nombre, definicion, indice, direccion, unidad, normalizacion, tipo_dato) VALUES
 ('accesibilidad', 'Distancia por red peatonal al establecimiento mas cercano dentro de la vecindad', 'ICA', 'costo', 'm',
  'min-max invertido: (max - x) / (max - min); sin establecimiento alcanzable = 0; si max = min, 0,5', 'calculado'),
 ('cobertura', 'Numero de establecimientos alcanzables dentro del umbral de caminata', 'ICA', 'beneficio', 'establecimientos',
  'min-max: (x - min) / (max - min); si max = min, 0,5', 'calculado'),
 ('diversidad', 'Numero de categorias distintas alcanzables dentro del umbral de caminata', 'ICA', 'beneficio', 'categorias',
  'min-max: (x - min) / (max - min); si max = min, 0,5', 'calculado'),
 ('vulnerabilidad', 'Estrato de la manzana: menor estrato, mayor prioridad. Estrato 0 o sin dato se excluye (no se reemplaza por cero)',
  'IPT', 'costo', 'estrato', 'min-max invertido: (max - x) / (max - min); si max = min, 0,5', 'observado');

INSERT INTO analisis.escenario (nombre, manzanas_vecindad, descripcion, bloquea_obras) VALUES
 ('base', 30, 'Red peatonal completa, sin obras', false),
 ('con_obras', 30, 'Se bloquean los tramos intersectados por obras en ejecucion (buffer supuesto de 25 m)', true);

-- Pesos propuestos: los del taller sin asequibilidad ni calidad (sin datos), reescalados a 1.
-- 0,30 / 0,20 / 0,15 / 0,10 sobre 0,75 = 0,40 / 0,27 / 0,20 / 0,13.
INSERT INTO analisis.escenario_criterio (escenario_id, criterio_id, peso)
SELECT e.id, c.id, CASE c.nombre WHEN 'accesibilidad' THEN 0.40 WHEN 'cobertura' THEN 0.27
                                 WHEN 'diversidad' THEN 0.20 ELSE 0.13 END
FROM analisis.escenario e CROSS JOIN analisis.criterio_analitico c;

CREATE OR REPLACE FUNCTION analisis.ejecutar(p_escenario int, p_version text DEFAULT 'sin-version')
RETURNS int LANGUAGE plpgsql AS $$
DECLARE
  esc      analisis.escenario%ROWTYPE;
  v_ejec   int;
  v_aristas text;
  w_acc numeric; w_cob numeric; w_div numeric; w_vul numeric;
BEGIN
  SELECT * INTO esc FROM analisis.escenario WHERE id = p_escenario;
  IF NOT FOUND THEN RAISE EXCEPTION 'escenario % no existe', p_escenario; END IF;
  SELECT max(peso) FILTER (WHERE c.nombre = 'accesibilidad'), max(peso) FILTER (WHERE c.nombre = 'cobertura'),
         max(peso) FILTER (WHERE c.nombre = 'diversidad'),   max(peso) FILTER (WHERE c.nombre = 'vulnerabilidad')
    INTO w_acc, w_cob, w_div, w_vul
    FROM analisis.escenario_criterio ec JOIN analisis.criterio_analitico c ON c.id = ec.criterio_id
   WHERE ec.escenario_id = p_escenario;

  INSERT INTO analisis.ejecucion_analisis (escenario_id, version_codigo, parametros)
  VALUES (p_escenario, p_version, jsonb_build_object(
    'manzanas_vecindad', esc.manzanas_vecindad, 'umbral_cobertura_m', esc.umbral_cobertura_m,
    'velocidad_peaton_ms', esc.velocidad_peaton_ms, 'distancia_maxima_m', esc.distancia_maxima_m, 'bloquea_obras', esc.bloquea_obras,
    'pesos', jsonb_build_object('accesibilidad', w_acc, 'cobertura', w_cob, 'diversidad', w_div, 'vulnerabilidad', w_vul)))
  RETURNING id INTO v_ejec;

  -- Vecindad por escenario (se recalcula).
  DELETE FROM analisis.vecindad_manzana WHERE escenario_id = p_escenario;
  INSERT INTO analisis.vecindad_manzana (escenario_id, manzana_id, vecina_id)
  SELECT p_escenario, m.id, v.id
  FROM territorio.manzana m
  CROSS JOIN LATERAL (SELECT m2.id FROM territorio.manzana m2 ORDER BY m2.geom <-> m.geom
                       LIMIT esc.manzanas_vecindad + 1) v
  WHERE EXISTS (SELECT 1 FROM territorio.lote l WHERE l.manzana_id = m.id);

  -- Costos entre nodos con pgRouting (grafo no dirigido; en obras, se retiran los tramos bloqueados).
  v_aristas := 'SELECT id, origen_id AS source, destino_id AS target, longitud AS cost, longitud AS reverse_cost FROM movilidad.arista_red';
  IF esc.bloquea_obras THEN
    v_aristas := v_aristas || ' WHERE id NOT IN (SELECT oa.arista_id FROM movilidad.obra_arista oa '
                           || 'JOIN movilidad.obra o ON o.id = oa.obra_id WHERE o.estado = ''en ejecucion'')';
  END IF;
  DROP TABLE IF EXISTS _costo;
  -- Costos desde cada establecimiento hacia los nodos de la red dentro del alcance maximo (la red no es dirigida,
  -- asi que la distancia establecimiento -> nodo es la de nodo -> establecimiento).
  EXECUTE format(
    'CREATE TEMP TABLE _costo AS SELECT start_vid AS end_vid, node AS start_vid, agg_cost FROM pgr_drivingDistance(%L,
       (SELECT array_agg(DISTINCT nodo_id) FROM movilidad.acceso_establecimiento), %s, false, false)',
    v_aristas, esc.distancia_maxima_m);
  CREATE INDEX ON _costo (start_vid, end_vid);

  -- Manzana de cada establecimiento: la que lo contiene o, si cae en via, la mas cercana.
  DROP TABLE IF EXISTS _est_manzana;
  CREATE TEMP TABLE _est_manzana AS
  SELECT e.id AS establecimiento_id,
         (SELECT m.id FROM territorio.manzana m ORDER BY m.geom <-> e.geom LIMIT 1) AS manzana_id
  FROM alimentos.establecimiento e;

  INSERT INTO analisis.matriz_od (ejecucion_id, predio_id, establecimiento_id, modo, metodo,
                                  distancia_red, distancia_euclidiana, tiempo)
  SELECT v_ejec, pa.predio_id, ae.establecimiento_id, 'caminando', 'pgr_dijkstraCost',
         d.dist, ST_Distance(pa.geom, e.geom), d.dist / esc.velocidad_peaton_ms
  FROM movilidad.punto_acceso pa
  JOIN territorio.predio pr ON pr.id = pa.predio_id
  JOIN territorio.lote l ON l.id = pr.lote_id
  JOIN analisis.vecindad_manzana v ON v.escenario_id = p_escenario AND v.manzana_id = l.manzana_id
  JOIN _est_manzana em ON em.manzana_id = v.vecina_id
  JOIN movilidad.acceso_establecimiento ae ON ae.establecimiento_id = em.establecimiento_id
  JOIN alimentos.establecimiento e ON e.id = ae.establecimiento_id
  LEFT JOIN _costo c ON c.start_vid = pa.nodo_id AND c.end_vid = ae.nodo_id
  CROSS JOIN LATERAL (SELECT pa.distancia_acceso + ae.distancia_acceso
                             + CASE WHEN pa.nodo_id = ae.nodo_id THEN 0 ELSE c.agg_cost END AS dist) d
  WHERE pa.nodo_id = ae.nodo_id OR c.agg_cost IS NOT NULL;   -- sin ruta: no se inventa distancia

  WITH agg AS (
    SELECT m.predio_id, min(m.distancia_red) AS acc_m,
           count(*) FILTER (WHERE m.distancia_red <= esc.umbral_cobertura_m) AS n_cob,
           count(DISTINCT e.categoria_id) FILTER (WHERE m.distancia_red <= esc.umbral_cobertura_m) AS n_div
    FROM analisis.matriz_od m JOIN alimentos.establecimiento e ON e.id = m.establecimiento_id
    WHERE m.ejecucion_id = v_ejec GROUP BY m.predio_id
  ), base AS (
    SELECT pr.id AS predio_id, agg.acc_m, coalesce(agg.n_cob, 0) AS n_cob, coalesce(agg.n_div, 0) AS n_div,
           nullif(es.estrato, 0) AS estrato, d.peso_demanda
    FROM movilidad.punto_acceso pa
    JOIN territorio.predio pr ON pr.id = pa.predio_id
    JOIN territorio.lote l ON l.id = pr.lote_id
    LEFT JOIN social.estrato es ON es.manzana_id = l.manzana_id
    LEFT JOIN social.demanda_predio d ON d.predio_id = pr.id
    LEFT JOIN agg ON agg.predio_id = pr.id
  ), rango AS (
    SELECT min(acc_m) amin, max(acc_m) amax, min(n_cob) cmin, max(n_cob) cmax,
           min(n_div) dmin, max(n_div) dmax, min(estrato) emin, max(estrato) emax FROM base
  ), norm AS (
    SELECT b.*,
      CASE WHEN b.acc_m IS NULL THEN 0 WHEN r.amax = r.amin THEN 0.5 ELSE (r.amax - b.acc_m) / (r.amax - r.amin) END AS acc_n,
      CASE WHEN r.cmax = r.cmin THEN 0.5 ELSE (b.n_cob - r.cmin)::numeric / (r.cmax - r.cmin) END AS cob_n,
      CASE WHEN r.dmax = r.dmin THEN 0.5 ELSE (b.n_div - r.dmin)::numeric / (r.dmax - r.dmin) END AS div_n,
      CASE WHEN b.estrato IS NULL THEN NULL WHEN r.emax = r.emin THEN 0.5
           ELSE (r.emax - b.estrato)::numeric / (r.emax - r.emin) END AS vul_n
    FROM base b CROSS JOIN rango r
  ), ica AS (
    SELECT n.*, (w_acc * acc_n + w_cob * cob_n + w_div * div_n) / (w_acc + w_cob + w_div) AS ica01 FROM norm n
  )
  INSERT INTO analisis.indicador_predio (ejecucion_id, predio_id, ica, ipt, nota_incertidumbre, acc_m, n_cobertura,
                                         n_categorias, estrato, acc_norm, cob_norm, div_norm, vul_norm)
  SELECT v_ejec, predio_id, round(100 * ica01, 2),
         CASE WHEN coalesce(peso_demanda, 0) = 0 THEN NULL
              ELSE round(100 * ((w_acc + w_cob + w_div) * (1 - ica01) + CASE WHEN vul_n IS NULL THEN 0 ELSE w_vul * vul_n END)
                         / ((w_acc + w_cob + w_div) + CASE WHEN vul_n IS NULL THEN 0 ELSE w_vul END), 2) END,
         nullif(concat_ws('; ',
           CASE WHEN acc_m IS NULL THEN 'sin establecimiento alcanzable en la vecindad: accesibilidad = peor valor' END,
           CASE WHEN estrato IS NULL THEN 'sin estrato: IPT sin componente de vulnerabilidad' END,
           CASE WHEN coalesce(peso_demanda, 0) = 0 THEN 'sin uso de vivienda: IPT no aplica' END), ''),
         acc_m, n_cob, n_div, estrato, acc_n, cob_n, div_n, vul_n
  FROM ica;

  UPDATE analisis.ejecucion_analisis SET estado = 'completada' WHERE id = v_ejec;
  RETURN v_ejec;
END $$;
