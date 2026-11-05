# Datos necesarios para completar la base de datos

Actualizado el 2026-11-05. Estado verificado consultando los servicios en vivo (no se consultó la base de datos). Requisitos: `Taller 10 - Bases de Datos Espaciales.pdf` y el ER en `taller10/diagramas`.

Para cada dato registrar en la bitácora: **organización, URL, licencia, fecha de descarga, cobertura, escala y limitaciones** (columnas de `crudo.fuente_dato`).

Leyenda: ✅ servicio verificado y con datos · ⚠️ parcial o por confirmar · ❌ sin fuente confirmada.

Base Catastro: `https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services/`

---

## 1. Territorio

| # | Dato | Estado | Fuente / capa | Notas |
|---|------|--------|---------------|-------|
| 1.1 | Localidad 16 | ✅ | `ordenamientoterritorial/localidad/MapServer/0` | Filtrar `LOCCODIGO='16'` |
| 1.2 | Manzanas | ✅ | `catastro/manzana/MapServer/0` | Campo `MANCODIGO`. ≈1 811 en la localidad (polígono real) |
| 1.3 | Lotes | ✅ | `catastro/lote/MapServer/0` | `LOTCODIGO`, `MANZCODIGO`, `LOTUPREDIA`. ≈39 697 en la localidad |
| 1.4 | **Predio con CHIP y uso por construcción** | ✅ | `catastro/lote/MapServer/3` (tabla sin geometría) | Une con el lote por `BARMANPRE = LOTCODIGO`. Una fila por unidad calificada: el mismo CHIP se repite con distinto `PRECUSO` y `PREAUSO`. Campos: `PRECHIP`, `PRECDESTIN`, `PRECUSO`, `PREAUSO`, `PRECLASE` (PH/NPH), `PREUVIVIEN`, `PREATERRE`, `PREACONST`. ≈158 000 filas en los 49 barrios de la localidad. Sin propietario ni datos personales |
| 1.5 | **Estrato** | ✅ | `ordenamientoterritorial/estratificacion/MapServer/1` | Es **por manzana** (`CODIGO_MANZANA`, `ESTRATO`) |
| 1.6 | Construcciones (geometría) | ✅ | `catastro/construccion/MapServer/0` | Solo pisos, altura y `LOTECODIGO`; **no trae uso**. Opcional |
| 1.7 | Placa domiciliaria | ✅ | `catastro/placadomiciliaria/MapServer/0` | Se une al lote por `PDOCLOTE`. Útil para geocodificar dirección. Opcional |
| 1.8 | Uso predominante histórico por manzana | ✅ | `catastro/usopredominante/MapServer/0` | Dato crudo de apoyo |

## 2. Social (población y vulnerabilidad)

| # | Dato | Estado | Dónde buscar | Notas |
|---|------|--------|--------------|-------|
| 2.1 | **Población y hogares por manzana** | ❌ | DANE, CNPV 2018 + Marco Geoestadístico Nacional (MGN): <https://microdatos.dane.gov.co/index.php/catalog/643/related-materials> | El DANE anonimiza: algunas variables **no se publican a nivel manzana** y quedan agregadas en el nivel siguiente. Confirmar en el catálogo 643 cuál es el nivel mínimo disponible para Bogotá |
| 2.2 | Población por localidad o UPZ (respaldo) | ⚠️ | Datos de desarrollo económico de Catastro (2017) | Solo 20 registros (por localidad). Sirve como contexto, no como demanda |
| 2.3 | **Vulnerabilidad social** | ❌ | DANE (Encuesta Multipropósito Bogotá, NBI), Secretaría Distrital de Planeación | Probablemente a nivel UPZ o localidad. Definir con qué variables |

## 3. Oferta alimentaria

| # | Dato | Estado | Fuente | Notas |
|---|------|--------|--------|-------|
| 3.1 | Supermercados | ✅ | OpenStreetMap, Overpass `https://overpass-api.de/api/interpreter` (`shop=supermarket`) | |
| 3.2 | Tiendas, panaderías, fruterías, carnicerías | ✅ | OSM (`shop=convenience/grocery/greengrocer/bakery/butcher/deli`) | OSM subestima las tiendas de barrio |
| 3.3 | Plazas de mercado | ✅ | Datos Abiertos Bogotá (CSV): <https://datosabiertos.bogota.gov.co/dataset/fd2a6046-5cc3-4acd-81ac-03fe5ef7d549/resource/910e4895-21c3-43b9-84c4-ed40f7e5409e/download/plazas-de-mercado.csv> | Hay versiones 2023 y 2024 |
| 3.4 | Restaurantes y bares | ⚠️ | Datos Abiertos Bogotá, "Establecimiento de gastronomía y bar" (GeoJSON 2023) | Decidir si cuentan como oferta alimentaria |
| 3.5 | Comercio como proxy | ✅ | Tabla de predio (1.4), usos 003/004/039/040 (comercio), 056/060 (restaurantes), 066 (plazas) | No distingue tiendas de alimentos de otro comercio |
| 3.6 | **Comedores comunitarios (SDIS)** | ⚠️ | Datos Abiertos Bogotá, dataset "Comedor Bogotá D.C." (GPKG y GeoJSON) | Última actualización registrada: dic-2020. Pedir versión vigente a SDIS |
| 3.7 | **Mercados campesinos / móviles** | ❌ | IPES (Instituto para la Economía Social), Secretaría de Desarrollo Económico | No se encontró dataset georreferenciado |
| 3.8 | **Oferta informal (venta ambulante)** | ❌ | IPES (registro de vendedores informales) | No se encontró dataset abierto |
| 3.9 | **Precios (asequibilidad)** | ❌ | DANE, SIPSA (precios mayoristas, Corabastos) | Es mayorista, no minorista. Para precio minorista habría que consultar DANE o Desarrollo Económico |
| 3.10 | Diversidad de la oferta | — | Se calcula de las categorías de 3.1 a 3.6 | Definir qué categorías cuentan |
| 3.11 | Calidad nutricional | ❌ | — | Solo si hay medición defendible; si no, límite documentado |

## 3b. Establecimientos comerciales
- Dataset "Commercial Establishments 2016" (copia en tumidata, GeoJSON). Es de 2016, verificar vigencia y licencia.
- Infocomercio (Servinformación) es de pago.
- No se encontró el registro mercantil de la Cámara de Comercio como dato abierto.

## 4. Movilidad

| # | Dato | Estado | Fuente / capa | Notas |
|---|------|--------|---------------|-------|
| 4.1 | Malla vial | ✅ | `Mapa_Referencia/Mapa_Referencia/MapServer/13` | 139 106 tramos en la ciudad |
| 4.2 | Andenes | ✅ | `Mapa_Referencia/Mapa_Referencia/MapServer/16` | Polígonos |
| 4.3 | Red peatonal de conexión (POT) | ✅ | `https://sinu.sdp.gov.co/serverp/rest/services/POT555/Sistema_del_Cuidado_y_Servicios_Sociales/MapServer/168` | Líneas, 46 065 en la ciudad |
| 4.4 | Red de biciusuarios / ciclorutas | ✅ | `Mapa_Referencia/Mapa_Referencia/MapServer/19` y `/18` | Para modo bicicleta |
| 4.5 | Estaciones troncales TransMilenio | ✅ | `https://gis.transmilenio.gov.co/arcgis/rest/services/Troncal/consulta_estaciones_troncales/MapServer/0` | 28 en la caja de la localidad |
| 4.6 | Rutas troncales | ✅ | `.../Troncal/consulta_rutas_troncales/MapServer/0` | |
| 4.7 | Paraderos SITP | ✅ | `.../Zonal/consulta_paraderos_zonales/MapServer/0` | |
| 4.8 | Rutas zonales SITP | ✅ | `.../Zonal/consulta_rutas_zonales/MapServer/0` | |
| 4.9 | **Relación ruta–estación/paradero y orden** | ❌ | GTFS estático de TransMilenio/SITP (paradas, rutas, viajes, horarios) | Hay copias en Tumi Data (2020–2022) y se publica en datos abiertos de Movilidad Bogotá y datos.gov.co. Buscar la versión más reciente y verificar licencia. Alternativa: derivar por cercanía espacial |
| 4.10 | Obras | ✅ | `gestionpublica/obraspublicas/MapServer/0` | Multipunto. `LOCALIDAD=16`: 90 obras. `ESTADO`: 1 en ejecución, 2 ejecutado, 3 lo que viene |
| 4.11 | Capas del visor de TransMilenio | ✅ | `https://services5.arcgis.com/9unqgkQ8KCOfnzoB/arcgis/rest/services/Mapa_GeoVisor_TransmiGIS/FeatureServer` | Biciestaciones (12), trazado troncal (5), metro (6, 8), cable (11, 14), zonas SITP (18). Solo se probaron las capas 6 y 8 |
| 4.12 | API interna del buscador de rutas | ⚠️ | `api.buscador-rutas.transmilenio.gov.co` | Responde 403 (no pública). No usar sin autorización |

## 5. Parámetros que debes decidir

| # | Parámetro |
|---|-----------|
| 5.1 | Fórmula de **ICA** (variables, dirección, normalización) |
| 5.2 | Fórmula de **IPT** (barreras + vulnerabilidad) |
| 5.3 | **Pesos** (PDF: accesibilidad 0,30; cobertura 0,20; diversidad 0,15; asequibilidad 0,15; vulnerabilidad 0,10; calidad 0,10) y su justificación |
| 5.4 | Regla si max(x) = min(x) |
| 5.5 | Datos faltantes: no reemplazar por cero; excluir, imputar con justificación o recalcular |
| 5.6 | Escenarios y sensibilidad (pesos, umbrales, `manzanas_vecindad` = 30, velocidad de caminata) |
| 5.7 | Qué cuenta como oferta alimentaria |
| 5.8 | Modos de desplazamiento a calcular |

## 6. Interoperabilidad LADM-COL

| # | Dato | Estado | Notas |
|---|------|--------|-------|
| 6.1 | Versión vigente | ⚠️ | Según el IGAC: Modelo Extendido Catastro-Registro **v4.1** (Resolución Conjunta IGAC 1456 / SNR 09844 de 2024) y Modelo Núcleo **v4.0.1** (Acuerdo 002 de 2023 de la CIIG-ICDE). Confirmar en <https://www.igac.gov.co/catastro-multiproposito/ladmcol> |
| 6.2 | Objetos, identificadores y dominios aplicables | ❌ | Identificar para lote y predio (el CHIP y el número predial) |
| 6.3 | Tabla de correspondencias | ❌ | Llenar `interoperabilidad.correspondencia_ladm`. No afirmar que el modelo propio es LADM-COL |

## 7. Entregables que dependen de estos datos
Catálogo de datos, diccionario de datos e indicadores, script reproducible en Python, atlas de mapas e informe de limitaciones.

---

## Prioridad sugerida
1. **Población por manzana** (2.1): es lo único que bloquea la demanda.
2. **GTFS o relación ruta–estación** (4.9).
3. **Oferta no cubierta**: comedores (3.6), mercados campesinos e informales (3.7, 3.8), precios (3.9).
4. **Vulnerabilidad** (2.3).
5. **Decisiones** de la sección 5 antes del modelo multicriterio.
6. **LADM-COL** (sección 6) al final.

Lo que no se consiga queda como **limitación** en la bitácora y el criterio se excluye o se recalcula con los disponibles.
