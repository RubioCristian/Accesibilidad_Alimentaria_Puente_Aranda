# Borrador de entradas para la bitácora

`taller10/bitacora.md` no se modifica desde este repositorio. Estas entradas continúan la bitácora después del 04-11-2026; el equipo las revisa y pega. Los responsables y la revisión por pares los completa el equipo (campos marcados con ☐).

---

**Fecha:** 05-11-2026

---

1. **Fuentes y GTFS.** Se validaron los 30 servicios REST de la lista y se añadieron el predio con CHIP y uso por construcción (`catastro/lote/MapServer/3`) y el GTFS estático de TransMilenio (2026-04-29, vigente hasta 2026-12-31). Las 152 estaciones del GTFS coinciden con las del servicio ArcGIS. La API interna del buscador de rutas responde 403 y no se usa. Estado de cada dato: `DATOS_NECESARIOS.md`.
2. **Decisiones de alcance.** Sin `area_estudio` (= localidad 16); unidad de análisis = predio (distinto del lote); vecindad = manzana del predio y sus 30 manzanas más cercanas; única barrera = obra; estrato por manzana; transporte público desde el GTFS. Correcciones: las capas 13 (malla vial) y 16 (andén) estaban invertidas; se retiraron afirmaciones de equivalencia con LADM-COL.
3. **Reestructura de la base.** Esquemas `staging`, `territorio`, `social`, `alimentos`, `movilidad`, `analisis`, `interoperabilidad`; scripts numerados `00`–`12`, cargador Python y Podman Compose. Se sustituyó `crudo` por `staging`, nombre que sugiere el taller, en scripts, código y diagramas. Los 9 SQL originales quedan en `Scripts/legacy` sin editar.
4. **Datos sin fuente (limitaciones).** Población por manzana (el DANE la agrega a mayor nivel), comedores vigentes, mercados campesinos, venta informal, precios minoristas, calidad nutricional y vulnerabilidad distinta del estrato. No se rellenan con cero; la demanda por predio es **inferida**.
5. **Pesos.** Se reescalaron los del taller sin asequibilidad ni calidad: 0,40 / 0,27 / 0,20 / 0,13 (`docs/indicadores.md`).
6. **Carga de la localidad completa.** 1 810 manzanas, 39 731 lotes, 81 133 predios, 422 establecimientos, red de 42 750 nodos y 47 286 aristas. Respaldo final de 75 MB (sin la matriz origen-destino, regenerable) en `Backup/`.

---

**Fecha:** 05-11-2026 (continuación)

---

1. **Sensibilidad (actividad 12).** Cinco escenarios que cambian un supuesto de `base`: pesos equitativos, accesibilidad dominante, umbral de 500 m, umbral de 1 000 m y vecindad de 15 manzanas. Resultados: `docs/sensibilidad.md`.
2. **LADM-COL.** Se consultó el repositorio oficial de la ICDE: Modelo Extendido Catastro-Registro **v4.1** (Res. Conjunta IGAC 1456 / SNR 09844 de 2024) y Núcleo **v4.0.1**; los nombres de clase y atributo se leyeron del `.ili`. Resultado: `docs/interoperabilidad.md`.
3. **Documentación.** Catálogo de datos, diccionario de datos y reglas de integridad, diccionario de indicadores, informe de limpieza espacial y atlas (`atlas/`).
4. **Informe.** Se actualizó `Informe/main.tex` con el modelo final, resultados de la localidad completa, sensibilidad, interoperabilidad y limitaciones.

---

## Pendientes del equipo
- ☐ Revisión por pares: fecha, revisor, observaciones y respuesta.
- ☐ Responsable de cada decisión.
- ☐ Reflexión final sobre limitaciones y aprendizajes.
- ☐ Validación de plausibilidad con conocimiento local (¿los lotes con ICA bajo corresponden a zonas con poca oferta?).
