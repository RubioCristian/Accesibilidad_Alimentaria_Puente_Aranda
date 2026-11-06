-- 03: social. Estrato por manzana (observado) y demanda asumida por predio (inferido).
DROP TABLE IF EXISTS social.demanda_predio, social.estrato CASCADE;

CREATE TABLE social.estrato (
  manzana_id    int PRIMARY KEY REFERENCES territorio.manzana(id),
  estrato       smallint NOT NULL CHECK (estrato BETWEEN 0 AND 6),
  fecha_captura date
);
-- La manzana toma el estrato del poligono con mayor area de interseccion. Estrato 0 = sin estrato.
INSERT INTO social.estrato (manzana_id, estrato, fecha_captura)
SELECT DISTINCT ON (m.id) m.id, e.estrato, e.fecha_captura
FROM territorio.manzana m
JOIN staging.estrato_poligono e ON ST_Intersects(m.geom, e.geom)
ORDER BY m.id, ST_Area(ST_Intersection(m.geom, e.geom)) DESC;

-- No hay poblacion publicada a nivel manzana ni tamano de hogar. La demanda de cada predio se asume
-- proporcional a su area de uso de vivienda. Es un dato INFERIDO, no una cantidad de personas.
CREATE TABLE social.demanda_predio (
  predio_id       int PRIMARY KEY REFERENCES territorio.predio(id),
  area_vivienda   numeric NOT NULL CHECK (area_vivienda >= 0),
  peso_demanda    numeric NOT NULL CHECK (peso_demanda >= 0),
  tipo_dato       text NOT NULL DEFAULT 'inferido',
  supuesto        text NOT NULL DEFAULT 'demanda proporcional al area de uso de vivienda (PREUVIVIEN = S); sin tamano de hogar'
);
INSERT INTO social.demanda_predio (predio_id, area_vivienda, peso_demanda)
SELECT p.id, coalesce(sum(u.area_uso) FILTER (WHERE u.es_vivienda), 0),
       coalesce(coalesce(sum(u.area_uso) FILTER (WHERE u.es_vivienda), 0)
         / nullif(sum(sum(u.area_uso) FILTER (WHERE u.es_vivienda)) OVER (), 0), 0)
FROM territorio.predio p LEFT JOIN territorio.uso_construccion u ON u.predio_id = p.id
GROUP BY p.id;

COMMENT ON TABLE social.demanda_predio IS 'Inferido: ver columna supuesto. peso_demanda suma 1 sobre la zona cargada';
