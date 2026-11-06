# Análisis de sensibilidad

Generado el 2026-11-06 (`Scripts/loader/sensibilidad.py`). Cada escenario cambia **un** supuesto de `base` para medir cuánto se mueve el resultado. ICA: mayor = mejor acceso. IPT: mayor = más prioridad.

## Escenarios ejecutados

| Escenario | Pesos | Umbral (m) | Vecindad (manzanas) | Bloquea obras |
|---|---|---|---|---|
| base | accesibilidad 0.40, cobertura 0.27, diversidad 0.20, vulnerabilidad 0.13 | 800 | 30 | no |
| con_obras | accesibilidad 0.40, cobertura 0.27, diversidad 0.20, vulnerabilidad 0.13 | 800 | 30 | sí |
| pesos_equitativos | accesibilidad 0.25, cobertura 0.25, diversidad 0.25, vulnerabilidad 0.25 | 800 | 30 | no |
| acceso_dominante | accesibilidad 0.60, cobertura 0.15, diversidad 0.12, vulnerabilidad 0.13 | 800 | 30 | no |
| umbral_500 | accesibilidad 0.40, cobertura 0.27, diversidad 0.20, vulnerabilidad 0.13 | 500 | 30 | no |
| umbral_1000 | accesibilidad 0.40, cobertura 0.27, diversidad 0.20, vulnerabilidad 0.13 | 1000 | 30 | no |
| vecindad_15 | accesibilidad 0.40, cobertura 0.27, diversidad 0.20, vulnerabilidad 0.13 | 800 | 15 | no |

## Resultados por escenario

| Escenario | Predios | ICA medio | IPT medio | Versión del código |
|---|---|---|---|---|
| base | 79479 | 56.27 | 36.26 | efb3881-comedores |
| con_obras | 79479 | 56.05 | 36.28 | efb3881-comedores |
| pesos_equitativos | 79479 | 50.46 | 36.24 | efb3881-comedores |
| acceso_dominante | 79479 | 68.88 | 25.22 | efb3881-comedores |
| umbral_500 | 79479 | 54.14 | 37.99 | efb3881-comedores |
| umbral_1000 | 79479 | 56.48 | 36.13 | efb3881-comedores |
| vecindad_15 | 79479 | 47.40 | 42.77 | efb3881-comedores |

## Comparación con `base`

| Escenario | Predios comparados | ρ de Spearman ICA | ρ de Spearman IPT | Dif. media ICA (pts) | % que cambia de decil ICA | Solape del 10 % con mayor IPT (%) |
|---|---|---|---|---|---|---|
| con_obras | 79479 | 0.9993 | 0.9999 | 0.22 | 2.2 | 97.6 |
| pesos_equitativos | 79479 | 0.9934 | 0.9845 | 5.81 | 19.7 | 68.5 |
| acceso_dominante | 79479 | 0.9795 | 0.9639 | 12.61 | 36.3 | 85.9 |
| umbral_500 | 79479 | 0.9686 | 0.9575 | 2.12 | 40.7 | 69.8 |
| umbral_1000 | 79479 | 0.9951 | 0.9955 | 0.21 | 10.6 | 99.0 |
| vecindad_15 | 79479 | 0.8987 | 0.8672 | 9.58 | 67.5 | 72.1 |

## Lectura

El orden de los predios es robusto; el nivel y los deciles lo son menos.

- **Obras** (`con_obras`): ρ ≈ 0,999. Solo 1 735 predios cambian de ICA (2,2 % cambia de decil); el efecto de las obras es local.
- **Umbral de cobertura** (`umbral_1000`, `umbral_500`): 1 000 m casi no altera nada (ρ = 0,995); 500 m cambia el decil del 40,7 % de los predios porque la cobertura pasa a ser escasa.
- **Pesos** (`pesos_equitativos`, `acceso_dominante`): el ranking se mantiene (ρ > 0,96), pero el ICA medio varía entre 50,5 y 68,9. Cambiar los pesos mueve el nivel más que el orden.
- **Vecindad** (`vecindad_15`): es el supuesto más influyente (ρ = 0,90 en ICA y 0,87 en IPT; 67,5 % cambia de decil). Con 15 manzanas se pierde oferta cercana en predios de borde y de manzanas grandes.
- El 10 % de predios con mayor IPT se conserva en al menos el 68 % de los casos en todos los escenarios: las conclusiones de priorización son más estables que los valores absolutos.
