# Informe de limpieza espacial

Resultados de las pruebas de `analisis.v_calidad` (script `Scripts/10_vistas_y_calidad.sql`) sobre la localidad completa.

## Sistema de referencia
Todas las geometrías se transforman a **SRID 9377** (MAGNA-SIRGAS Origen Nacional, proyectado, en metros), adecuado para medir distancias. Las plazas de mercado venían en el sistema local **990047** y se transformaron. Las consultas a los servicios ArcGIS piden `outSR=4326` y se reproyectan al cargar.

## Pruebas y resultados
| Prueba | Fallas | Tratamiento |
|---|---|---|
| Geometrías inválidas (lote, manzana) | 0 | — |
| Lotes sin predio | 155 | Se conservan; no entran al análisis |
| Predios sin punto de acceso a la red | 0 | — |
| Manzanas con lotes y sin estrato | 7 | El estrato se trata como dato faltante (no 0); el IPT se calcula sin el componente de vulnerabilidad y se anota en `nota_incertidumbre` |
| Usos con área desconocida | 2 152 | Dato faltante; no se reemplaza por cero |
| Predios con acceso a la red a más de 100 m | 1 | Se conserva con la distancia real |
| Lotes prediales que cruzan una vía (> 2 m) | 190 | Lotes industriales grandes en su mayoría; se documenta |
| Lotes prediales fuera de su manzana (> 1 m²) | 2 | Se documenta |
| Extremos sueltos a ≤ 2 m de otra arista | 57 | Los de ≤ 2 m se unen en el script 06; quedan 57 por revisar |
| Predios fuera del componente principal de la red | 0 | — |
| Indicadores con ICA nulo | 0 | — |

## Correcciones de fondo
- **Lotes de vía y espacio público:** Catastro entrega 1 056 «lotes» con sufijo 090–099 o más del 50 % fuera de su manzana. Se marcan `territorio.lote.tipo = 'via_espacio_publico'` y no se tratan como predios.
- **Capas invertidas:** en las fuentes iniciales la capa 13 (malla vial) y la 16 (andén) estaban intercambiadas; se corrigió.
- **Código de manzana de estratificación:** no siempre coincide con el de la capa de manzanas; el estrato se une por intersección espacial.
- **Duplicados de oferta:** la unión OSM + plazas se revisó por coincidencia de nombre y proximidad.
- **Red:** se deriva de los ejes de calzada (malla vial), no de andenes; los tramos se parten en los accesos de lotes y establecimientos, redondeados a 1 m.
