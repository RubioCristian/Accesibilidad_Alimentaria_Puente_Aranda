# Cómo se hizo: metodología y reproducción

Resumen del flujo de trabajo, en el orden de las fases del taller. Los detalles de cada decisión están en la bitácora y en los documentos enlazados.

## 1. Problema y datos
- Pregunta: *¿cuál es el sistema de acceso a alimentos de la localidad y qué áreas presentan mayores barreras o prioridades de intervención?* Localidad 16, Puente Aranda (Bogotá).
- Modelos conceptual y entidad-relación en `taller10/diagramas` (Graphviz y PlantUML). Los esquemas del ER son los paquetes de la base.
- Inventario de fuentes: `docs/catalogo_datos.md` (generado de `staging.fuente_dato`) y `DATOS_NECESARIOS.md` (estado de cada dato).
- Limpieza espacial: `docs/limpieza_espacial.md`.

## 2. Base de datos (PostgreSQL 18 + PostGIS + pgRouting)
Esquemas: `staging` (copias de entrada), `territorio`, `social`, `alimentos`, `movilidad`, `analisis` e `interoperabilidad`. Scripts numerados y re-ejecutables:

| Script | Contenido |
|---|---|
| `00_extensiones_y_esquemas.sql` | Extensiones, esquemas, reubicación de las tablas heredadas (renombra `crudo` a `staging` si viene de un respaldo antiguo) |
| `01_staging.sql` | Tablas de entrada y catálogo `fuente_dato` |
| `02_territorio.sql` – `04_alimentos.sql` | Localidad, manzana, lote, predio, uso, estrato, demanda inferida, oferta |
| `05_movilidad_infraestructura.sql` – `07_movilidad_transporte.sql` | Vías, andenes, obras, red de ruteo, estaciones y rutas del GTFS |
| `08_analisis.sql` | Criterios, escenarios, ejecuciones, matriz origen-destino, ICA/IPT |
| `09_interoperabilidad.sql` | Correspondencias LADM-COL |
| `10_vistas_y_calidad.sql` | Vistas y pruebas de calidad (`analisis.v_calidad`) |
| `11_sensibilidad.sql` | Escenarios de sensibilidad |
| `12_completar_catalogo.sql` | Completa campos vacíos del catálogo sin afirmar licencias no confirmadas |

Reglas aplicadas: claves primarias y foráneas, CHECK de dominio, índices GiST, SRID 9377, fecha de observación y de carga, ejecuciones versionadas (`ejecucion_analisis.version_codigo`), datos fuente separados de los armonizados y derivados, sin datos personales. Detalle en `docs/diccionario_datos.md`.

## 3. Análisis
- Matriz origen-destino por red peatonal con pgRouting (`analisis.matriz_od`); no se usan buffers euclidianos como medida de accesibilidad.
- ICA e IPT por predio, con normalización min-max, pesos justificados y escenarios: `docs/indicadores.md`.
- Sensibilidad: `docs/sensibilidad.md`.

## 4. Cierre
- Interoperabilidad: `docs/interoperabilidad.md`.
- Código reproducible: cargador Python `Scripts/loader/` (ArcGIS REST, Overpass, GTFS) y `montar.ps1`.
- Atlas: `atlas/` (`python -m Scripts.loader.atlas`) y visor web `SIG/`.

## Reproducir
```bash
podman compose up -d db web                                       # restaura Backup/alimentos_puente_aranda_final.backup
export CODE_VERSION=$(git rev-parse --short HEAD)
podman compose --profile etl run --rm etl python -m Scripts.loader.run modelo analisis sensibilidad exportar
podman compose --profile etl run --rm etl python -m Scripts.loader.documentar     # catálogo y diccionario
podman compose --profile etl run --rm etl python -m Scripts.loader.sensibilidad   # docs/sensibilidad.md
podman compose --profile etl run --rm etl python -m Scripts.loader.atlas /app/atlas
```
El respaldo final trae la localidad completa ya descargada; `cargas` solo se ejecuta para actualizar datos (≈ 1 h). Cada escenario tarda ≈ 18 min.

## Uso de inteligencia artificial
El trabajo se apoyó en Claude (Anthropic) para estructurar los modelos, validar servicios, escribir scripts y documentación, como permite el taller. Las decisiones de alcance (localidad, unidad de análisis, vecindad de 30 manzanas, única barrera = obra, estrato por manzana) las tomó el equipo; los resultados se revisaron contra los servicios y la base.
