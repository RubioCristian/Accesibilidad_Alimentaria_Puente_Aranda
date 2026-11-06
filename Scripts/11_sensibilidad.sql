-- 11: escenarios de sensibilidad (actividad 12). Cada uno cambia UN supuesto respecto de 'base' para medir su efecto.
-- Se ejecutan con:  python -m Scripts.loader.run sensibilidad   (solo corre los escenarios sin ejecucion completada).
INSERT INTO analisis.escenario (nombre, manzanas_vecindad, descripcion, umbral_cobertura_m, velocidad_peaton_ms, bloquea_obras) VALUES
 ('pesos_equitativos',  30, 'Sensibilidad de pesos: los cuatro criterios pesan igual (0,25)', 800, 1.25, false),
 ('acceso_dominante',   30, 'Sensibilidad de pesos: accesibilidad pesa 0,60', 800, 1.25, false),
 ('umbral_500',         30, 'Sensibilidad del umbral: cobertura y diversidad a 500 m', 500, 1.25, false),
 ('umbral_1000',        30, 'Sensibilidad del umbral: cobertura y diversidad a 1 000 m', 1000, 1.25, false),
 ('vecindad_15',        15, 'Sensibilidad de la vecindad: 15 manzanas en vez de 30', 800, 1.25, false)
ON CONFLICT (nombre) DO NOTHING;

-- Pesos: accesibilidad, cobertura, diversidad, vulnerabilidad. Los escenarios de umbral y vecindad conservan los de 'base'.
INSERT INTO analisis.escenario_criterio (escenario_id, criterio_id, peso)
SELECT e.id, c.id,
       CASE e.nombre
         WHEN 'pesos_equitativos' THEN 0.25
         WHEN 'acceso_dominante'  THEN CASE c.nombre WHEN 'accesibilidad' THEN 0.60 WHEN 'cobertura' THEN 0.15
                                                      WHEN 'diversidad' THEN 0.12 ELSE 0.13 END
         ELSE CASE c.nombre WHEN 'accesibilidad' THEN 0.40 WHEN 'cobertura' THEN 0.27 WHEN 'diversidad' THEN 0.20 ELSE 0.13 END
       END
FROM analisis.escenario e CROSS JOIN analisis.criterio_analitico c
WHERE e.nombre IN ('pesos_equitativos','acceso_dominante','umbral_500','umbral_1000','vecindad_15')
ON CONFLICT DO NOTHING;

-- Los pesos de cada escenario deben sumar 1.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM analisis.escenario_criterio GROUP BY escenario_id HAVING abs(sum(peso) - 1) > 0.001) THEN
    RAISE EXCEPTION 'hay escenarios cuyos pesos no suman 1';
  END IF;
END $$;
