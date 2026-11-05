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
UNION ALL SELECT 'predios sin punto de acceso', count(*) FROM territorio.predio p WHERE NOT EXISTS (SELECT 1 FROM movilidad.punto_acceso a WHERE a.predio_id = p.id)
UNION ALL SELECT 'manzanas con lotes y sin estrato', count(*) FROM territorio.manzana m
  WHERE EXISTS (SELECT 1 FROM territorio.lote l WHERE l.manzana_id = m.id) AND NOT EXISTS (SELECT 1 FROM social.estrato e WHERE e.manzana_id = m.id)
UNION ALL SELECT 'establecimientos sin acceso a la red', count(*) FROM alimentos.establecimiento e WHERE NOT EXISTS (SELECT 1 FROM movilidad.acceso_establecimiento a WHERE a.establecimiento_id = e.id)
UNION ALL SELECT 'usos con area desconocida (dato faltante)', count(*) FROM territorio.uso_construccion WHERE area_uso IS NULL
UNION ALL SELECT 'aristas sin anden ni conexion', count(*) FROM movilidad.arista_red WHERE anden_id IS NULL AND conexion_id IS NULL
UNION ALL SELECT 'indicadores con ICA nulo', count(*) FROM analisis.indicador_predio WHERE ica IS NULL;

-- Limpieza: tablas intermedias de ruteo del trabajo anterior, regenerables con Scripts/legacy
-- y presentes en Backup/alimentos_puente_aranda_original.backup.
DROP TABLE IF EXISTS movilidad.puntos_ruteo, movilidad.red_aristas, movilidad.red_nodos, movilidad.red_tramos_base,
                     movilidad.correcciones_topologicas, movilidad.validacion_componentes, movilidad.validacion_cruces,
                     movilidad.conexion_componentes, movilidad.conexiones_adicionales,
                     movilidad.establecimientos_red_final, movilidad.accesos_lotes CASCADE;
