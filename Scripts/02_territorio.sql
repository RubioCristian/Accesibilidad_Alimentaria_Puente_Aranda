-- 02: territorio (localidad, manzana, lote, predio, uso_construccion). Se reconstruye desde crudo.
DROP TABLE IF EXISTS territorio.uso_construccion, territorio.predio, territorio.lote,
                     territorio.manzana, territorio.localidad CASCADE;

CREATE TABLE territorio.localidad (
  id     serial PRIMARY KEY,
  codigo text NOT NULL UNIQUE,
  nombre text NOT NULL,
  geom   geometry(MultiPolygon, 9377) NOT NULL CHECK (ST_IsValid(geom))
);
INSERT INTO territorio.localidad (codigo, nombre, geom)
SELECT loccodigo, locnombre, ST_Multi(ST_MakeValid(geom)) FROM crudo.legado_localidad;

CREATE TABLE territorio.manzana (
  id           serial PRIMARY KEY,
  codigo       text NOT NULL UNIQUE,
  localidad_id int NOT NULL REFERENCES territorio.localidad(id),
  geom         geometry(MultiPolygon, 9377) NOT NULL CHECK (ST_IsValid(geom))
);
INSERT INTO territorio.manzana (codigo, localidad_id, geom)
-- Se omite 1 manzana sin codigo y, de un codigo repetido, se conserva el poligono de mayor area.
SELECT DISTINCT ON (m.mancodigo) m.mancodigo, (SELECT id FROM territorio.localidad LIMIT 1), ST_Multi(ST_MakeValid(m.geom))
FROM crudo.legado_manzana m
WHERE m.mancodigo IS NOT NULL
ORDER BY m.mancodigo, ST_Area(m.geom) DESC;

CREATE TABLE territorio.lote (
  id                serial PRIMARY KEY,
  codigo            text NOT NULL UNIQUE,
  manzana_id        int NOT NULL REFERENCES territorio.manzana(id),
  fuente_id         int REFERENCES crudo.fuente_dato(id),
  fecha_observacion date,
  fecha_carga       date,
  tipo              text NOT NULL DEFAULT 'predial' CHECK (tipo IN ('predial', 'via_espacio_publico')),
  geom              geometry(MultiPolygon, 9377) NOT NULL CHECK (ST_IsValid(geom))
);
INSERT INTO territorio.lote (codigo, manzana_id, fuente_id, fecha_carga, geom)
SELECT l.codigo_lote, m.id, (SELECT id FROM crudo.fuente_dato WHERE nombre = 'Catastro - Lote'),
       (SELECT fecha_descarga FROM crudo.fuente_dato WHERE nombre = 'Catastro - Lote'),
       ST_Multi(ST_MakeValid(l.geom))
FROM crudo.lote_catastro l JOIN territorio.manzana m ON m.codigo = l.codigo_manzana;

-- Lotes que no son predios: Catastro entrega "lotes" de via y espacio publico (codigo 09x, destino 65, sin
-- construccion). Se detectan porque quedan fuera de su manzana (mas de la mitad de su area) o, en las esquinas
-- que si quedan dentro, por el sufijo 090-099 del codigo. Regla empirica verificada (zona piloto, 76 manzanas):
-- los 39 lotes 09x tienen destino 65 y ninguna construccion. No entran al analisis.
UPDATE territorio.lote l SET tipo = 'via_espacio_publico'
FROM territorio.manzana m
WHERE m.id = l.manzana_id
  AND (ST_Area(ST_Difference(l.geom, m.geom)) > 0.5 * ST_Area(l.geom)
       OR substr(l.codigo, 10, 3) BETWEEN '090' AND '099');

-- Predio = CHIP. La tabla de Catastro trae una fila por unidad calificada, asi que se agrupa.
CREATE TABLE territorio.predio (
  id              serial PRIMARY KEY,
  chip            text NOT NULL UNIQUE,
  lote_id         int NOT NULL REFERENCES territorio.lote(id),
  nupre           text,
  clase           text,
  destino         text,
  direccion       text,
  area_terreno    numeric,
  area_construida numeric
);
INSERT INTO territorio.predio (chip, lote_id, nupre, clase, destino, direccion, area_terreno, area_construida)
SELECT p.chip, l.id, max(p.nupre), max(p.clase), max(p.destino), max(p.direccion),
       max(p.area_terreno), max(p.area_construida)
FROM crudo.predio_catastro p JOIN territorio.lote l ON l.codigo = p.barmanpre
WHERE p.chip IS NOT NULL
GROUP BY p.chip, l.id;

CREATE TABLE territorio.uso_construccion (
  id          serial PRIMARY KEY,
  predio_id   int NOT NULL REFERENCES territorio.predio(id),
  codigo_uso  text,
  area_uso    numeric CHECK (area_uso IS NULL OR area_uso >= 0),
  es_vivienda boolean
);
INSERT INTO territorio.uso_construccion (predio_id, codigo_uso, area_uso, es_vivienda)
-- Catastro usa -1 para area desconocida: se guarda como NULL (dato faltante, no cero).
SELECT pr.id, p.cod_uso, CASE WHEN p.area_uso >= 0 THEN p.area_uso END, p.uso_vivienda = 'S'
FROM crudo.predio_catastro p JOIN territorio.predio pr ON pr.chip = p.chip;

CREATE INDEX ON territorio.manzana USING gist (geom);
CREATE INDEX ON territorio.lote USING gist (geom);
CREATE INDEX ON territorio.lote (manzana_id);
CREATE INDEX ON territorio.predio (lote_id);
CREATE INDEX ON territorio.uso_construccion (predio_id);

COMMENT ON TABLE territorio.predio IS 'Unidad de analisis. CHIP unico; el lote es la geometria que lo contiene (varios predios por lote en PH)';
COMMENT ON COLUMN territorio.uso_construccion.es_vivienda IS 'PREUVIVIEN de Catastro = S';
