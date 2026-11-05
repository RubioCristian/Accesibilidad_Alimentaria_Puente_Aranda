-- 10: vistas de validacion, pruebas de calidad y limpieza de tablas intermedias.

-- Ultima ejecucion completada por escenario.
CREATE OR REPLACE VIEW analisis.v_ultima_ejecucion AS
SELECT DISTINCT ON (escenario_id) escenario_id, id AS ejecucion_id
FROM analisis.ejecucion_analisis WHERE estado = 'completada'
ORDER BY escenario_id, id DESC;

-- Indicadores por lote (promedio de sus predios) para el escenario indicado.
CREATE OR REPLACE VIEW analisis.v_indicador_lote AS
SELECT l.id AS lote_id, l.codigo, ex.escenario_id, e.nombre AS escenario,
       count(*) AS n_predios, round(avg(i.ica), 2) AS ica, round(avg(i.ipt), 2) AS ipt
FROM analisis.indicador_predio i
JOIN analisis.v_ultima_ejecucion ex ON ex.ejecucion_id = i.ejecucion_id
JOIN analisis.escenario e ON e.id = ex.escenario_id
JOIN territorio.predio p ON p.id = i.predio_id
JOIN territorio.lote l ON l.id = p.lote_id
GROUP BY l.id, l.codigo, ex.escenario_id, e.nombre;

-- Pruebas de calidad: cada fila debe tener "falla" = 0 para pasar.
CREATE OR REPLACE VIEW analisis.v_calidad AS
SELECT 'geometrias invalidas (lote)' AS prueba, count(*) AS falla FROM territorio.lote WHERE NOT ST_IsValid(geom)
UNION ALL SELECT 'geometrias invalidas (manzana)', count(*) FROM territorio.manzana WHERE NOT ST_IsValid(geom)
UNION ALL SELECT 'lotes sin predio', count(*) FROM territorio.lote l WHERE NOT EXISTS (SELECT 1 FROM territorio.predio p WHERE p.lote_id = l.id)
UNION ALL SELECT 'predios sin punto de acceso', count(*) FROM territorio.predio p JOIN territorio.lote l ON l.id = p.lote_id AND l.tipo = 'predial'
  WHERE NOT EXISTS (SELECT 1 FROM movilidad.punto_acceso a WHERE a.predio_id = p.id)
UNION ALL SELECT 'manzanas con lotes y sin estrato', count(*) FROM territorio.manzana m
  WHERE EXISTS (SELECT 1 FROM territorio.lote l WHERE l.manzana_id = m.id) AND NOT EXISTS (SELECT 1 FROM social.estrato e WHERE e.manzana_id = m.id)
UNION ALL SELECT 'establecimientos sin acceso a la red', count(*) FROM alimentos.establecimiento e WHERE NOT EXISTS (SELECT 1 FROM movilidad.acceso_establecimiento a WHERE a.establecimiento_id = e.id)
UNION ALL SELECT 'usos con area desconocida (dato faltante)', count(*) FROM territorio.uso_construccion WHERE area_uso IS NULL
UNION ALL SELECT 'aristas de malla vial sin via asociada', count(*) FROM movilidad.arista_red WHERE origen = 'malla vial' AND via_id IS NULL
UNION ALL SELECT 'predios con acceso a la red a mas de 100 m', count(*) FROM movilidad.punto_acceso WHERE distancia_acceso > 100
UNION ALL SELECT 'predios fuera del componente principal de la red', count(*) FROM movilidad.punto_acceso pa
  JOIN (SELECT node, component FROM pgr_connectedComponents('SELECT id, origen_id AS source, destino_id AS target, longitud AS cost FROM movilidad.arista_red')) c
    ON c.node = pa.nodo_id
  WHERE c.component <> (SELECT component FROM pgr_connectedComponents('SELECT id, origen_id AS source, destino_id AS target, longitud AS cost FROM movilidad.arista_red')
                        GROUP BY component ORDER BY count(*) DESC LIMIT 1)
UNION ALL SELECT 'lotes prediales que cruzan una via (>2 m)', count(DISTINCT l.id) FROM territorio.lote l
  JOIN movilidad.via v ON ST_Intersects(l.geom, v.geom) AND ST_Length(ST_Intersection(l.geom, v.geom)) > 2 WHERE l.tipo = 'predial'
UNION ALL SELECT 'lotes prediales fuera de su manzana (>1 m2)', count(*) FROM territorio.lote l
  JOIN territorio.manzana m ON m.id = l.manzana_id WHERE l.tipo = 'predial' AND ST_Area(ST_Difference(l.geom, m.geom)) > 1
UNION ALL SELECT 'extremos sueltos a <= 2 m de otra arista', count(*) FROM (
  SELECT n.id, n.geom FROM movilidad.nodo_red n JOIN movilidad.arista_red a ON a.origen_id = n.id OR a.destino_id = n.id
  GROUP BY n.id, n.geom HAVING count(*) = 1) g
  WHERE EXISTS (SELECT 1 FROM movilidad.arista_red a WHERE a.origen_id <> g.id AND a.destino_id <> g.id AND ST_DWithin(a.geom, g.geom, 2))
UNION ALL SELECT 'indicadores con ICA nulo', count(*) FROM analisis.indicador_predio WHERE ica IS NULL;

-- Limpieza: tablas intermedias de ruteo del trabajo anterior, regenerables con Scripts/legacy
-- y presentes en Backup/alimentos_puente_aranda_original.backup.
DROP TABLE IF EXISTS movilidad.puntos_ruteo, movilidad.red_aristas, movilidad.red_nodos, movilidad.red_tramos_base,
                     movilidad.correcciones_topologicas, movilidad.validacion_componentes, movilidad.validacion_cruces,
                     movilidad.conexion_componentes, movilidad.conexiones_adicionales,
                     movilidad.establecimientos_red_final, movilidad.accesos_lotes CASCADE;
