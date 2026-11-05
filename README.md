# Accesibilidad alimentaria en Puente Aranda (Bogotá, localidad 16)

Taller 10 de Bases de Datos Espaciales. Base PostGIS/pgRouting que calcula, para cada **predio**, qué tan bien puede llegar caminando a alimentos, con un visor web estático para validar la información.

## Inicio rápido

Requisito: **Podman** (probado con 6.1.4 y `podman-compose` 1.6.0). En Windows o macOS, la máquina debe estar iniciada (`podman machine start`).

```bash
podman compose up -d db web      # base en localhost:5433 y visor en http://localhost:8080
```

El primer arranque restaura `Backup/alimentos_puente_aranda_final.backup`, o el original si el final no existe (`docker/db/init/10_restaurar_backup.sh`). **El respaldo final (88 MB) trae toda la localidad ya descargada** (crudo, modelo, análisis e indicadores), así que no hace falta volver a bajar nada de las fuentes; se probó restaurándolo en una base vacía con conteos idénticos. Solo se descarga de nuevo para actualizar los datos (fases `cargas` en adelante). Si el volumen `pgdata` ya existe, no vuelve a restaurar; `podman compose down -v` lo borra.

Conexión: `psql -h localhost -p 5433 -U postgres alimentos_puente_aranda` (clave por defecto `postgres`; se cambia con `POSTGRES_PASSWORD`, `DB_PORT` y `WEB_PORT` en un `.env`). La clave por defecto es solo para desarrollo local.

### Regenerar todo desde el backup original

```bash
export CODE_VERSION=$(git rev-parse --short HEAD)       # queda guardado en analisis.ejecucion_analisis
podman compose --profile etl run --rm etl                # base, cargas, modelo, analisis y exportar
podman compose --profile etl run --rm etl python -m Scripts.loader.run modelo analisis exportar   # solo SQL + analisis + capas
```

Fases del cargador (`Scripts/loader/run.py`): `base` (SQL 00-01) → `cargas` (ArcGIS y GTFS) → `modelo` (SQL 02-10) → `analisis` (un `analisis.ejecutar` por escenario) → `exportar` (GeoJSON y `resumen.json` en `SIG/data`). Los SQL son re-ejecutables sobre la base restaurada de cualquiera de los dos respaldos ; el cargador descarga el GTFS (120 MB) a un volumen de caché y no lo versiona. La fase `cargas` baja la localidad completa (lotes por manzana, malla vial por caja, predios por CHIP, OSM por teselas) y es reanudable; tarda del orden de una hora. El análisis de los dos escenarios tarda ~36 min. Desde el backup original ya no basta con `modelo`: hay que correr antes `cargas`, porque el original solo trae una zona de 76 manzanas.

### Montar todo con un solo comando (PowerShell)

```powershell
.montar.ps1               # levanta base y visor desde el respaldo final
.montar.ps1 -Limpiar      # borra el volumen y restaura de nuevo
.montar.ps1 -Regenerar    # ademas descarga, modela, analiza y exporta (horas)
```

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

## Resultado actual (localidad completa)

1 810 manzanas · 39 731 lotes (38 675 prediales y 1 056 de vía/espacio público) · 81 133 predios (CHIP) · 136 128 usos · 418 establecimientos · red de 42 750 nodos y 47 286 aristas derivada de la malla vial · ~605 mil pares predio-establecimiento por escenario · 1 273 paradas, 587 rutas · 90 obras (8 en ejecución, 4 tocan la red). ICA medio base 57,6 (máx. 96); 1 320 predios no alcanzan ningún establecimiento a ≤ 2 km por red (su acceso queda como el peor). El escenario `con_obras` cambia el ICA de 1 735 predios (diferencia media 10,3 puntos).

Fechas de descarga de las fuentes (también en `crudo.fuente_dato`): Catastro localidad y manzana 2026-10-30; andén 2026-10-31; red POT 2026-11-03; lotes, malla vial, predios, estratificación, obras, OSM y GTFS 2026-11-05 (GTFS publicado 2026-04-29).

## Consulta desde un predio (visor)

La pestaña *Predio* tiene dos alcances: **toda la localidad** (todos los predios coloreados por ICA/IPT) y **desde un predio**. Se elige buscando por dirección, CHIP o código de lote, o con clic en un lote y «Analizar desde este predio»; también por enlace directo `http://localhost:8080/?chip=<CHIP>`. El visor atenúa lo que queda fuera de las 30 manzanas de vecindad del predio, resalta sus establecimientos alcanzables (≤ 800 m en verde) y lista cada distancia por la red y su tiempo a 1,25 m/s, para el escenario elegido. Los datos salen de `SIG/data/predios_indice.json` (buscador) y de un fragmento por manzana `SIG/data/mz/<manzana>.json` que se pide al elegir el predio (generados por `exportar` desde `analisis.matriz_od`, `indicador_predio` y `vecindad_manzana`). Las capas pesadas (malla vial, red, rutas y paraderos SITP) se descargan al activarlas. Las líneas dibujadas son rectas de referencia, no el trazado por la red.

## Limitaciones

- **Bordes:** se cargó la localidad completa y la malla vial 300 m alrededor, pero no los establecimientos de localidades vecinas; los predios del borde tienen menos oferta de la real.
- **Red:** la red peatonal se deriva de los **ejes de calzada** de la malla vial (no de andenes): camina por el eje y no modela cruces peatonales ni andenes. Los tramos se parten en los accesos de lotes y establecimientos redondeados a 1 m.
- **Población:** no hay población publicada a nivel manzana ni tamaño de hogar. La demanda por predio es **inferida** (proporcional al área de vivienda) y no se expresa en personas.
- **Sin fuente confirmada:** comedores comunitarios vigentes (el dataset de SDIS es de 2020), mercados campesinos, venta informal, precios minoristas, calidad nutricional y vulnerabilidad distinta del estrato. Los criterios de asequibilidad y calidad no se calculan; sus pesos se reescalaron, sin rellenar con cero.
- **Oferta:** OSM subestima las tiendas de barrio; el comercio de Catastro no distingue tiendas de alimentos del resto. Hay 418 establecimientos (plazas oficiales y OSM dentro de la localidad), con seis categorías fijas.
- **Obras:** vienen como puntos; el área de afectación de 25 m es un supuesto. Solo 4 de las 8 obras en ejecución tocan la red.
- **Modos:** solo se calcula caminar. El transporte público se muestra (estaciones, paraderos, rutas y orden desde el GTFS) pero no entra al índice. No se usó la bicicleta.
- **GTFS:** la licencia no viene en el archivo; se cita el publicador y la fecha. Solo se guardan las paradas dentro de la localidad y a ≤ ~900 m; el orden de parada es el menor `stop_sequence` observado.
- **Estrato:** por manzana; el valor 0 (sin estrato) se trata como dato faltante.
- **Relatividad:** ICA e IPT dependen de la normalización min-max de la localidad y no son comparables con otra zona.
- **Sensibilidad:** aún no se ejecutaron escenarios con otros pesos o umbrales (el modelo lo permite con nuevas filas en `analisis.escenario`).
- **Andenes:** `anden` se conserva como zona pero no entra a la red; `anden.ancho` sin dato.
- **Topología (validada en `analisis.v_calidad`):** Catastro entrega 1 056 «lotes» de vía y espacio público (sufijo 090–099 o >50 % fuera de su manzana); se marcan `territorio.lote.tipo = 'via_espacio_publico'` y no son predios del análisis ni salen en el visor. Los extremos sueltos de la red a ≤ 2 m de otra arista se unen en el script 06; quedan 57 por revisar. Persisten 190 lotes prediales cruzados por líneas de la malla vial (en su mayoría lotes industriales grandes), 2 lotes prediales fuera de su manzana, 155 lotes sin predio, 7 manzanas sin estrato, 1 predio a más de 100 m de la red y 2 152 usos sin área.
- **LADM-COL:** solo correspondencias propuestas, por verificar contra el catálogo oficial (Modelo Extendido Catastro-Registro v4.1; Modelo Núcleo v4.0.1).
- **API del buscador de rutas de TransMilenio:** responde 403; no se usa.
- **Tablas heredadas:** el backup original trae procedimientos que descargaban con la extensión `http`; el cargador nuevo usa Python.
