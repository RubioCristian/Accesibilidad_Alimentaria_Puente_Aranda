# Diccionario de indicadores y modelo multicriterio

Implementado en `analisis.ejecutar` (`Scripts/08_analisis.sql`). Dos índices separados, como pide el taller, para no ocultar la razón de una puntuación.

- **ICA (Índice de Condiciones de Acceso), 0-100: mayor = mejores condiciones.** Resume accesibilidad, cobertura y diversidad.
- **IPT (Índice de Prioridad Territorial), 0-100: mayor = mayor prioridad de atención.** Combina las barreras de acceso (1 − ICA) con la vulnerabilidad social. Solo se calcula para predios con uso de vivienda.

## Criterios
| Criterio | Índice | Definición | Dirección | Unidad | Normalización | Tipo de dato |
|---|---|---|---|---|---|---|
| Accesibilidad | ICA | Distancia por red peatonal al establecimiento más cercano dentro de la vecindad | costo | m | (max − x) / (max − min); sin establecimiento alcanzable = 0 | calculado |
| Cobertura | ICA | Establecimientos alcanzables a ≤ umbral (800 m en `base`) por red | beneficio | establecimientos | (x − min) / (max − min) | calculado |
| Diversidad | ICA | Categorías distintas alcanzables a ≤ umbral | beneficio | categorías | (x − min) / (max − min) | calculado |
| Vulnerabilidad | IPT | Estrato de la manzana (menor estrato, mayor prioridad) | costo | estrato | (max − x) / (max − min) | observado (aproximación) |

## Fórmulas
Sea *z* el valor normalizado, *w* el peso y los subíndices a, c, d, v los criterios anteriores.

- ICA = 100 · (w_a·z_a + w_c·z_c + w_d·z_d) / (w_a + w_c + w_d)
- IPT = 100 · [(w_a + w_c + w_d)·(1 − ICA/100) + w_v·z_v] / [(w_a + w_c + w_d) + w_v]. Si no hay estrato, se omite el término de vulnerabilidad y se reescala (no se usa 0).

## Reglas
- **max = min:** el valor normalizado es 0,5 (no hay variación que distinga a los predios).
- **Datos faltantes:** no se reemplazan por cero. Sin estrato (valor 0 o ausente) → el IPT se calcula sin vulnerabilidad. Sin vivienda → IPT no aplica. Sin establecimiento alcanzable → la accesibilidad toma su peor valor, y se anota en `nota_incertidumbre`.
- **Distancia:** red peatonal derivada de la malla vial; `pgr_drivingDistance`/Dijkstra sobre grafo no dirigido, alcance máximo 2 000 m. Sin ruta no se guarda fila.
- **Tiempo:** distancia / 1,25 m/s (supuesto de velocidad de caminata).
- **Vecindad:** la manzana del predio más sus 30 manzanas más cercanas.
- **Escenarios:** `base`; `con_obras` (retira las aristas intersectadas por obras en ejecución, buffer supuesto de 25 m); y los de sensibilidad (ver `sensibilidad.md`).

## Pesos y justificación
| Criterio | Peso del taller (didáctico) | Peso usado |
|---|---|---|
| Accesibilidad | 0,30 | **0,40** |
| Cobertura | 0,20 | **0,27** |
| Diversidad | 0,15 | **0,20** |
| Vulnerabilidad | 0,10 | **0,13** |
| Asequibilidad | 0,15 | no se calcula (sin datos de precios minoristas) |
| Calidad | 0,10 | no se calcula (sin medición defendible) |

Los pesos usados son los del taller **reescalados** a suma 1 tras retirar asequibilidad y calidad (0,30/0,75 = 0,40; 0,20/0,75 ≈ 0,27; 0,15/0,75 = 0,20; 0,10/0,75 ≈ 0,13). El taller los presenta como punto de partida didáctico; no se invocan fuentes de literatura que no se hayan consultado. Su robustez se evalúa con los escenarios `pesos_equitativos` y `acceso_dominante`.

## Qué es dato observado, indicador calculado e inferencia
| Tipo | Elementos |
|---|---|
| Observado | Lotes, predios, usos, estrato, obras, establecimientos, vías, paradas y rutas GTFS |
| Calculado | Distancias, cobertura, diversidad, ICA, IPT |
| Inferido o supuesto | Demanda por predio (`social.demanda_predio`, proporcional al área de vivienda, sin convertir a personas); buffer de 25 m de las obras; velocidad de 1,25 m/s; el estrato como aproximación a la vulnerabilidad |

**Interpretación prudente.** La accesibilidad espacial no demuestra por sí sola seguridad alimentaria, dieta saludable ni resultados de salud. ICA e IPT son relativos a la localidad (min-max sobre sus predios) y no son comparables con otra zona.
