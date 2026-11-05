# Accesibilidad alimentaria en Puente Aranda (Bogotá, localidad 16)

Taller 10 de Bases de Datos Espaciales. Base PostGIS/pgRouting que calcula, para cada **predio**, qué tan bien puede llegar caminando a alimentos, con un visor web estático para validar la información.

## Inicio rápido

Requisito: **Podman** (probado con 6.1.4 y `podman-compose` 1.6.0). En Windows o macOS, la máquina debe estar iniciada (`podman machine start`).

```bash
podman compose up -d db web      # base en localhost:5433 y visor en http://localhost:8080
```

El primer arranque restaura `Backup/alimentos_puente_aranda_final.backup`, o el original si el final no existe (`docker/db/init/10_restaurar_backup.sh`). Si el volumen `pgdata` ya existe, no vuelve a restaurar; `podman compose down -v` lo borra.

Conexión: `psql -h localhost -p 5433 -U postgres alimentos_puente_aranda` (clave por defecto `postgres`; se cambia con `POSTGRES_PASSWORD`, `DB_PORT` y `WEB_PORT` en un `.env`). La clave por defecto es solo para desarrollo local.

### Regenerar todo desde el backup original

```bash
export CODE_VERSION=$(git rev-parse --short HEAD)       # queda guardado en analisis.ejecucion_analisis
podman compose --profile etl run --rm etl                # base, cargas, modelo, analisis y exportar
podman compose --profile etl run --rm etl python -m Scripts.loader.run modelo analisis exportar   # solo SQL + analisis + capas
```

Fases del cargador (`Scripts/loader/run.py`): `base` (SQL 00-01) → `cargas` (ArcGIS y GTFS) → `modelo` (SQL 02-10) → `analisis` (un `analisis.ejecutar` por escenario) → `exportar` (GeoJSON y `resumen.json` en `SIG/data`). Los SQL son re-ejecutables sobre la base restaurada de cualquiera de los dos respaldos (probado desde el original en una base vacía: mismos conteos e ICA que la base final); el cargador descarga el GTFS (120 MB) a un volumen de caché y no lo versiona.

## Estructura

```
compose.yaml            db (5433), web (8080, nginx) y etl (perfil "etl")
docker/db/              imagen pgrouting/pgrouting:18-3.6-4.0 + postgresql-18-http y restauración inicial
docker/etl/             imagen Python 3.13 del cargador
Scripts/00..10_*.sql    esquemas, crudo, territorio, social, alimentos, movilidad, analisis, interoperabilidad, vistas y calidad
Scripts/loader/         cargador Python (ArcGIS REST, GTFS) y exportación para el visor
Scripts/legacy/         los 9 SQL originales del taller, sin editar
SIG/                    visor web estático (MapLibre GL 4.7.1 incluido en vendor/) y SIG/data con las capas exportadas
Backup/                 respaldos: original (punto de partida) y final (resultado)
DATOS_NECESARIOS.md     inventario de datos, fuentes y estado
```

## Modelo

Cada esquema es un paquete del modelo entidad-relación (`taller10/diagramas/entidad_relacion.puml`):

| Esquema | Contenido |
|---|---|
| `crudo` | Descargas originales, tablas heredadas (`legado_*`) y `fuente_dato` (catálogo: entidad, URL, fecha, licencia, cobertura, escala, limitaciones) |
| `territorio` | `localidad`, `manzana`, `lote`, `predio` (un CHIP), `uso_construccion` |
| `social` | `estrato` (por manzana) y `demanda_predio` (inferida) |
| `alimentos` | `categoria`, `establecimiento` |
| `movilidad` | `via`, `anden`, `conexion_peatonal`, `nodo_red`, `arista_red`, `punto_acceso`, `acceso_establecimiento`, `obra`, `obra_arista`, estaciones y rutas de TransMilenio y SITP |
| `analisis` | `escenario`, `criterio_analitico`, `escenario_criterio`, `ejecucion_analisis`, `vecindad_manzana`, `matriz_od`, `indicador_predio`, vistas y `v_calidad` |
| `interoperabilidad` | `correspondencia_ladm` (propuesta de correspondencias; el modelo propio no es LADM-COL) |

Decisiones: unidad de análisis = **predio** (distinto del lote); vecindad = la manzana del predio y sus **30 manzanas** más cercanas; única barrera = **obra**; estrato por manzana. SRID 9377 (MAGNA-SIRGAS Origen Nacional); las plazas de mercado venían en el sistema local 990047.

### Cómo se calculan los indicadores (`analisis.ejecutar`)

1. **Matriz origen-destino:** distancia por la red peatonal (`pgr_dijkstraCost`, grafo no dirigido) desde el punto de acceso de cada predio a cada establecimiento de su vecindad; más la distancia euclidiana y el tiempo a 1,25 m/s. Sin ruta no se guarda fila (no se inventa distancia).
2. **Criterios por predio:** accesibilidad (distancia mínima), cobertura (establecimientos a ≤ 800 m por red), diversidad (categorías distintas a ≤ 800 m) y vulnerabilidad (estrato).
3. **Normalización min-max** sobre los predios de la ejecución; la dirección del criterio se invierte cuando menos es mejor; si max = min, el valor es 0,5.
4. **ICA** (0-100, mayor = mejor acceso) = promedio ponderado de accesibilidad, cobertura y diversidad. **IPT** (0-100, mayor = más prioridad) = combinación de `1 - ICA` con la vulnerabilidad; no aplica a predios sin uso de vivienda.
5. **Pesos:** accesibilidad 0,40, cobertura 0,27, diversidad 0,20, vulnerabilidad 0,13 (los del taller sin asequibilidad ni calidad, reescalados a 1). Son una propuesta pendiente de justificar.
6. **Escenarios:** `base` y `con_obras` (retira de la red los tramos intersectados por obras en ejecución). Cada ejecución guarda versión del código, parámetros y estado.

### Qué es observado, calculado e inferido

| Dato | Tipo |
|---|---|
| Lotes, predios, usos, estrato, obras, establecimientos, andenes, vías, paradas y rutas GTFS | Observado (fuente oficial o colaborativa) |
| Distancias, cobertura, diversidad, ICA, IPT | Calculado |
| Demanda por predio (`social.demanda_predio`), área de afectación de las obras (buffer de 25 m) | **Inferido / supuesto** |

## Datos utilizados

Detalle y estado en `DATOS_NECESARIOS.md`; el catálogo completo, con fechas y licencias, está en `crudo.fuente_dato` y en la pestaña *Fuentes* del visor.

| Dato | Fuente |
|---|---|
| Localidad, manzana, lote | Catastro Bogotá, `serviciosgis.catastrobogota.gov.co/arcgis/rest/services` (`ordenamientoterritorial/localidad/0`, `catastro/manzana/0`, `catastro/lote/0`) |
| Predio, CHIP y uso por construcción | `catastro/lote/MapServer/3`, unido por `BARMANPRE = LOTCODIGO` |
| Estrato | `ordenamientoterritorial/estratificacion/MapServer/1` (unido por intersección espacial) |
| Malla vial y andenes | `Mapa_Referencia/Mapa_Referencia/MapServer` capas 13 y 16 |
| Red peatonal del POT | SINU, `POT555/Sistema_del_Cuidado_y_Servicios_Sociales/MapServer/168` |
| Obras | `gestionpublica/obraspublicas/MapServer/0` (`LOCALIDAD=16`) |
| Tiendas y supermercados | OpenStreetMap vía Overpass |
| Plazas de mercado | Datos Abiertos Bogotá (CSV) |
| TransMilenio y SITP | GTFS estático de Transmilenio S.A., 2026-04-29 (`storage.googleapis.com/gtfs-estaticos/GTFS-2026-04-29.zip`) |

## Resultado actual (zona cargada)

76 manzanas · 2 394 lotes · 3 331 predios · 8 175 usos · 70 establecimientos · red de 9 580 nodos y 9 841 aristas · 83 938 pares predio-establecimiento por escenario · 2 estaciones de TransMilenio y 41 paraderos SITP conectados · 12 y 87 rutas que pasan por ellos. Todos los predios tienen punto de acceso y ICA; las pruebas de `analisis.v_calidad` pasan, salvo los 90 usos sin área en la fuente, que se informan como dato faltante.

## Limitaciones

- **Cobertura:** solo se cargó la zona de 76 manzanas que ya estaba en la base; la localidad tiene unos 39 697 lotes. Los scripts y el cargador funcionan por lote, de modo que ampliar la zona es repetir la descarga (la red peatonal de la localidad completa requiere reconstruir `legado_*`, que viene del trabajo anterior en `Scripts/legacy`).
- **Población:** no hay población publicada a nivel manzana ni tamaño de hogar. La demanda por predio es **inferida** (proporcional al área de vivienda) y no se expresa en personas.
- **Sin fuente confirmada:** comedores comunitarios vigentes (el dataset de SDIS es de 2020), mercados campesinos, venta informal, precios minoristas, calidad nutricional y vulnerabilidad distinta del estrato. Los criterios de asequibilidad y calidad no se calculan; sus pesos se reescalaron, sin rellenar con cero.
- **Oferta:** OSM subestima las tiendas de barrio; el comercio de Catastro no distingue tiendas de alimentos del resto. Solo hay 70 establecimientos conectados a la red.
- **Obras:** vienen como puntos; el área de afectación de 25 m es un supuesto. En la zona cargada no hay obras en ejecución, así que el escenario `con_obras` es idéntico a `base`.
- **Modos:** solo se calcula caminar. El transporte público se muestra (estaciones, paraderos, rutas y orden desde el GTFS) pero no entra al índice. No se usó la bicicleta.
- **GTFS:** la licencia no viene en el archivo; se cita el publicador y la fecha. Solo se guardan las paradas a ≤ 900 m de la zona; el orden de parada es el menor `stop_sequence` observado.
- **Estrato:** por manzana; el valor 0 (sin estrato) se trata como dato faltante.
- **Relatividad:** ICA e IPT dependen de la normalización min-max de la zona y no son comparables con otra zona.
- **Sensibilidad:** aún no se ejecutaron escenarios con otros pesos o umbrales (el modelo lo permite con nuevas filas en `analisis.escenario`).
- **Red:** el esquema trae `via_id` en `arista_red` sin llenar (la red sale de andenes y conexiones, no de la malla vial) y `anden.ancho` sin dato.
- **LADM-COL:** solo correspondencias propuestas, por verificar contra el catálogo oficial (Modelo Extendido Catastro-Registro v4.1; Modelo Núcleo v4.0.1).
- **API del buscador de rutas de TransMilenio:** responde 403; no se usa.
- **Tablas heredadas:** el backup original trae procedimientos que descargaban con la extensión `http`; el cargador nuevo usa Python.
