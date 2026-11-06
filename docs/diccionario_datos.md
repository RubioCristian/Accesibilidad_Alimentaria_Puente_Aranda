# Diccionario de datos y reglas de integridad

Generado el 2026-11-06 desde `information_schema` y `pg_constraint` (`Scripts/loader/documentar.py`). Todas las geometrías están en
SRID 9377 (MAGNA-SIRGAS Origen Nacional, proyectado, en metros) salvo que se indique otro. Cada esquema corresponde a un paquete del
modelo entidad-relación. Las fechas `fecha_observacion` y `fecha_carga` registran cuándo se observó y cuándo se cargó cada dato.

## Resumen de reglas de integridad
- **Claves primarias** estables en todas las tablas y **llaves foráneas** declaradas entre esquemas.
- **CHECK** de dominio (por ejemplo `ica` y `ipt` entre 0 y 100, pesos en (0, 1], umbrales positivos, estados válidos).
- **Geometrías:** columnas con tipo y SRID declarados (ver tabla de geometrías) y validación en `analisis.v_calidad`.
- **Índices espaciales GiST** sobre las columnas geométricas.
- **Datos personales:** no se almacena propietario ni documento; el CHIP es un identificador catastral del predio.

## Geometrías
| Esquema | Tabla | Columna | Tipo | SRID |
|---|---|---|---|---|
| alimentos | establecimiento | geom | POINT | 9377 |
| alimentos | v_oferta_alimentaria | geom | POINT | 9377 |
| alimentos | v_plazas_analisis | geom | GEOMETRY | 0 |
| alimentos | v_plazas_mercado | geom | MULTIPOLYGON | 4686 |
| alimentos | v_plazas_mercado | geom_9377 | GEOMETRY | 0 |
| movilidad | anden | geom | MULTIPOLYGON | 9377 |
| movilidad | arista_red | geom | LINESTRING | 9377 |
| movilidad | conexion_peatonal | geom | LINESTRING | 9377 |
| movilidad | estacion_sitp | geom | POINT | 9377 |
| movilidad | estacion_transmilenio | geom | POINT | 9377 |
| movilidad | nodo_red | geom | POINT | 9377 |
| movilidad | obra | geom | MULTIPOLYGON | 9377 |
| movilidad | obra | geom_punto | MULTIPOINT | 9377 |
| movilidad | punto_acceso | geom | POINT | 9377 |
| movilidad | ruta_sitp | geom | LINESTRING | 9377 |
| movilidad | ruta_transmilenio | geom | LINESTRING | 9377 |
| movilidad | via | geom | MULTILINESTRING | 9377 |
| staging | andenes | geom | MULTIPOLYGON | 4326 |
| staging | cobertura_cargada | geom | POLYGON | 9377 |
| staging | estrato_poligono | geom | MULTIPOLYGON | 9377 |
| staging | gtfs_parada | geom | POINT | 9377 |
| staging | gtfs_ruta | geom | LINESTRING | 9377 |
| staging | legado_andenes | geom | MULTIPOLYGON | 9377 |
| staging | legado_conexiones_andenes | geom | LINESTRING | 9377 |
| staging | legado_ejes_andenes | geom | MULTILINESTRING | 9377 |
| staging | legado_establecimientos_red_peatonal | punto_red | POINT | 9377 |
| staging | legado_establecimientos_red_peatonal | punto_establecimiento | POINT | 9377 |
| staging | legado_localidad | geom | MULTIPOLYGON | 9377 |
| staging | legado_lotes | geom | MULTIPOLYGON | 9377 |
| staging | legado_lotes_red_peatonal | punto_acceso | POINT | 9377 |
| staging | legado_lotes_red_peatonal | punto_red | POINT | 9377 |
| staging | legado_malla_vial | geom | MULTILINESTRING | 9377 |
| staging | legado_manzana | geom | MULTIPOLYGON | 9377 |
| staging | legado_otros_establecimientos_osm | geom | POINT | 9377 |
| staging | legado_plaza_mercado | geom | MULTIPOLYGON | 0 |
| staging | legado_red_peatonal_aristas | geom | LINESTRING | 9377 |
| staging | legado_red_peatonal_nodos | geom | POINT | 9377 |
| staging | legado_red_peatonal_pot | geom | MULTILINESTRING | 9377 |
| staging | legado_red_peatonal_segmentos | geom | LINESTRING | 9377 |
| staging | legado_supermercados_osm | geom | POINT | 9377 |
| staging | localidad | geom | MULTIPOLYGON | 4326 |
| staging | lote_catastro | geom | MULTIPOLYGON | 9377 |
| staging | lotes | geom | MULTIPOLYGON | 4326 |
| staging | malla_vial | geom | MULTILINESTRING | 4326 |
| staging | malla_vial_catastro | geom | MULTILINESTRING | 9377 |
| staging | manzana | geom | MULTIPOLYGON | 4326 |
| staging | obra_publica | geom | MULTIPOINT | 9377 |
| staging | osm_elemento | geom | POINT | 9377 |
| staging | plaza_mercado | geom | MULTIPOLYGON | 4686 |
| staging | uso_predominante | geom | MULTIPOLYGON | 4326 |
| territorio | localidad | geom | MULTIPOLYGON | 9377 |
| territorio | lote | geom | MULTIPOLYGON | 9377 |
| territorio | manzana | geom | MULTIPOLYGON | 9377 |
| territorio | v_manzanas_estudio | geom | MULTIPOLYGON | 9377 |
| territorio | v_uso_predominante | geom | MULTIPOLYGON | 9377 |

## Índices espaciales (GiST)
| Esquema | Tabla | Índice |
|---|---|---|
| alimentos | establecimiento | establecimiento_geom_idx |
| movilidad | anden | anden_geom_idx |
| movilidad | arista_red | arista_red_geom_idx |
| movilidad | conexion_peatonal | conexion_peatonal_geom_idx |
| movilidad | estacion_sitp | estacion_sitp_geom_idx |
| movilidad | estacion_transmilenio | estacion_transmilenio_geom_idx |
| movilidad | nodo_red | nodo_red_geom_idx |
| movilidad | obra | obra_geom_idx |
| movilidad | punto_acceso | punto_acceso_geom_idx |
| movilidad | ruta_sitp | ruta_sitp_geom_idx |
| movilidad | ruta_transmilenio | ruta_transmilenio_geom_idx |
| movilidad | via | via_geom_idx |
| staging | legado_andenes | legado_idx_andenes_geom |
| staging | legado_localidad | legado_idx_territorio_localidad_geom |
| staging | legado_lotes | legado_idx_lotes_geom |
| staging | legado_malla_vial | legado_idx_malla_vial_geom |
| staging | legado_manzana | legado_idx_territorio_manzana_geom |
| staging | legado_plaza_mercado | plaza_mercado_20211229_geom_idx |
| staging | legado_red_peatonal_aristas | legado_idx_red_peatonal_aristas_geom |
| staging | legado_red_peatonal_nodos | legado_idx_red_peatonal_nodos_geom |
| staging | legado_red_peatonal_pot | legado_idx_red_peatonal_pot_geom |
| staging | localidad | idx_staging_localidad_geom |
| staging | manzana | idx_staging_manzana_geom |
| staging | plaza_mercado | plaza_mercado_geom_idx |
| staging | uso_predominante | idx_staging_uso_geom |
| territorio | lote | lote_geom_idx |
| territorio | manzana | manzana_geom_idx |


## Esquema `alimentos`

### `alimentos.categoria`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('alimentos.categoria_id_seq'::regclass) |  |
| nombre | text | no |  |  |

Restricciones: **n** `NOT NULL id`; **n** `NOT NULL nombre`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (nombre)`

### `alimentos.establecimiento`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('alimentos.establecimiento_id_seq'::regclass) |  |
| codigo_origen | text | no |  |  |
| nombre | text | sí |  |  |
| categoria_id | integer | no |  |  |
| predio_id | integer | sí |  |  |
| fuente_id | integer | sí |  |  |
| fecha_observacion | date | sí |  |  |
| fecha_carga | date | sí |  |  |
| geom | USER-DEFINED | no |  |  |

Restricciones: **FK** `FOREIGN KEY (categoria_id) REFERENCES alimentos.categoria(id)`; **FK** `FOREIGN KEY (fuente_id) REFERENCES staging.fuente_dato(id)`; **FK** `FOREIGN KEY (predio_id) REFERENCES territorio.predio(id)`; **n** `NOT NULL categoria_id`; **n** `NOT NULL codigo_origen`; **n** `NOT NULL geom`; **n** `NOT NULL id`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (codigo_origen)`

## Esquema `analisis`

### `analisis.criterio_analitico`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('analisis.criterio_analitico_id_seq'::regclass) |  |
| nombre | text | no |  |  |
| definicion | text | sí |  |  |
| indice | text | no |  |  |
| direccion | text | no |  |  |
| unidad | text | sí |  |  |
| normalizacion | text | sí |  |  |
| tipo_dato | text | no |  |  |

Restricciones: **CHECK** `CHECK ((direccion = ANY (ARRAY['beneficio'::text, 'costo'::text])))`; **CHECK** `CHECK ((indice = ANY (ARRAY['ICA'::text, 'IPT'::text])))`; **CHECK** `CHECK ((tipo_dato = ANY (ARRAY['observado'::text, 'calculado'::text, 'inferido'::text])))`; **n** `NOT NULL direccion`; **n** `NOT NULL id`; **n** `NOT NULL indice`; **n** `NOT NULL nombre`; **n** `NOT NULL tipo_dato`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (nombre)`

### `analisis.ejecucion_analisis`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('analisis.ejecucion_analisis_id_seq'::regclass) |  |
| escenario_id | integer | no |  |  |
| version_codigo | text | no |  |  |
| fecha | timestamp without time zone | no | now() |  |
| parametros | jsonb | sí |  |  |
| estado | text | no | 'en curso'::text |  |

Restricciones: **CHECK** `CHECK ((estado = ANY (ARRAY['en curso'::text, 'completada'::text, 'fallida'::text])))`; **FK** `FOREIGN KEY (escenario_id) REFERENCES analisis.escenario(id)`; **n** `NOT NULL escenario_id`; **n** `NOT NULL estado`; **n** `NOT NULL fecha`; **n** `NOT NULL id`; **n** `NOT NULL version_codigo`; **PK** `PRIMARY KEY (id)`

### `analisis.escenario`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('analisis.escenario_id_seq'::regclass) |  |
| nombre | text | no |  |  |
| manzanas_vecindad | integer | no |  |  |
| descripcion | text | sí |  |  |
| umbral_cobertura_m | numeric | no | 800 |  |
| velocidad_peaton_ms | numeric | no | 1.25 |  |
| bloquea_obras | boolean | no | false |  |
| distancia_maxima_m | numeric | no | 2000 |  |

Restricciones: **CHECK** `CHECK ((distancia_maxima_m > (0)::numeric))`; **CHECK** `CHECK ((manzanas_vecindad > 0))`; **CHECK** `CHECK ((umbral_cobertura_m > (0)::numeric))`; **CHECK** `CHECK ((velocidad_peaton_ms > (0)::numeric))`; **n** `NOT NULL bloquea_obras`; **n** `NOT NULL distancia_maxima_m`; **n** `NOT NULL id`; **n** `NOT NULL manzanas_vecindad`; **n** `NOT NULL nombre`; **n** `NOT NULL umbral_cobertura_m`; **n** `NOT NULL velocidad_peaton_ms`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (nombre)`

### `analisis.escenario_criterio`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| escenario_id | integer | no |  |  |
| criterio_id | integer | no |  |  |
| peso | numeric | no |  |  |

Restricciones: **CHECK** `CHECK (((peso > (0)::numeric) AND (peso <= (1)::numeric)))`; **FK** `FOREIGN KEY (criterio_id) REFERENCES analisis.criterio_analitico(id)`; **FK** `FOREIGN KEY (escenario_id) REFERENCES analisis.escenario(id)`; **n** `NOT NULL criterio_id`; **n** `NOT NULL escenario_id`; **n** `NOT NULL peso`; **PK** `PRIMARY KEY (escenario_id, criterio_id)`

### `analisis.indicador_predio`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| ejecucion_id | integer | no |  |  |
| predio_id | integer | no |  |  |
| ica | numeric | sí |  |  |
| ipt | numeric | sí |  |  |
| nota_incertidumbre | text | sí |  |  |
| acc_m | numeric | sí |  |  |
| n_cobertura | integer | sí |  |  |
| n_categorias | integer | sí |  |  |
| estrato | smallint | sí |  |  |
| acc_norm | numeric | sí |  |  |
| cob_norm | numeric | sí |  |  |
| div_norm | numeric | sí |  |  |
| vul_norm | numeric | sí |  |  |

Restricciones: **CHECK** `CHECK (((ica >= (0)::numeric) AND (ica <= (100)::numeric)))`; **CHECK** `CHECK (((ipt >= (0)::numeric) AND (ipt <= (100)::numeric)))`; **FK** `FOREIGN KEY (ejecucion_id) REFERENCES analisis.ejecucion_analisis(id) ON DELETE CASCADE`; **FK** `FOREIGN KEY (predio_id) REFERENCES territorio.predio(id)`; **n** `NOT NULL ejecucion_id`; **n** `NOT NULL predio_id`; **PK** `PRIMARY KEY (ejecucion_id, predio_id)`

### `analisis.matriz_od`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| ejecucion_id | integer | no |  |  |
| predio_id | integer | no |  |  |
| establecimiento_id | integer | no |  |  |
| modo | text | no |  |  |
| metodo | text | sí |  |  |
| distancia_red | numeric | no |  |  |
| distancia_euclidiana | numeric | sí |  |  |
| tiempo | numeric | sí |  |  |

Restricciones: **FK** `FOREIGN KEY (ejecucion_id) REFERENCES analisis.ejecucion_analisis(id) ON DELETE CASCADE`; **FK** `FOREIGN KEY (establecimiento_id) REFERENCES alimentos.establecimiento(id)`; **FK** `FOREIGN KEY (predio_id) REFERENCES territorio.predio(id)`; **n** `NOT NULL distancia_red`; **n** `NOT NULL ejecucion_id`; **n** `NOT NULL establecimiento_id`; **n** `NOT NULL modo`; **n** `NOT NULL predio_id`; **PK** `PRIMARY KEY (ejecucion_id, predio_id, establecimiento_id, modo)`

### `analisis.vecindad_manzana`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| escenario_id | integer | no |  |  |
| manzana_id | integer | no |  |  |
| vecina_id | integer | no |  |  |

Restricciones: **FK** `FOREIGN KEY (escenario_id) REFERENCES analisis.escenario(id)`; **FK** `FOREIGN KEY (manzana_id) REFERENCES territorio.manzana(id)`; **FK** `FOREIGN KEY (vecina_id) REFERENCES territorio.manzana(id)`; **n** `NOT NULL escenario_id`; **n** `NOT NULL manzana_id`; **n** `NOT NULL vecina_id`; **PK** `PRIMARY KEY (escenario_id, manzana_id, vecina_id)`

## Esquema `interoperabilidad`

### `interoperabilidad.correspondencia_ladm`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('interoperabilidad.correspondencia_ladm_id_seq'::regclass) |  |
| entidad_origen | text | no |  |  |
| atributo_origen | text | sí |  |  |
| elemento_destino | text | no |  |  |
| regla_transformacion | text | sí |  |  |
| limitaciones | text | sí |  |  |
| version_ladm | text | no |  |  |

Restricciones: **n** `NOT NULL elemento_destino`; **n** `NOT NULL entidad_origen`; **n** `NOT NULL id`; **n** `NOT NULL version_ladm`; **PK** `PRIMARY KEY (id)`

## Esquema `movilidad`

### `movilidad.acceso_establecimiento`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| establecimiento_id | integer | no |  |  |
| nodo_id | bigint | no |  |  |
| distancia_acceso | numeric | no |  |  |

Restricciones: **CHECK** `CHECK ((distancia_acceso >= (0)::numeric))`; **FK** `FOREIGN KEY (establecimiento_id) REFERENCES alimentos.establecimiento(id)`; **FK** `FOREIGN KEY (nodo_id) REFERENCES movilidad.nodo_red(id)`; **n** `NOT NULL distancia_acceso`; **n** `NOT NULL establecimiento_id`; **n** `NOT NULL nodo_id`; **PK** `PRIMARY KEY (establecimiento_id)`

### `movilidad.anden`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('movilidad.anden_id_seq'::regclass) |  |
| objectid_orig | bigint | sí |  |  |
| codigo | text | sí |  |  |
| ancho | numeric | sí |  |  |
| geom | USER-DEFINED | no |  |  |

Restricciones: **CHECK** `CHECK (st_isvalid(geom))`; **n** `NOT NULL geom`; **n** `NOT NULL id`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (objectid_orig)`

### `movilidad.arista_red`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | bigint | no |  |  |
| origen_id | bigint | no |  |  |
| destino_id | bigint | no |  |  |
| via_id | integer | sí |  |  |
| anden_id | integer | sí |  |  |
| conexion_id | integer | sí |  |  |
| fuente_id | integer | sí |  |  |
| fecha_observacion | date | sí |  |  |
| fecha_carga | date | sí |  |  |
| modo | text | no | 'peatonal'::text |  |
| origen | text | no | 'malla vial'::text |  |
| longitud | numeric | no |  |  |
| geom | USER-DEFINED | no |  |  |

Restricciones: **CHECK** `CHECK ((longitud >= (0)::numeric))`; **FK** `FOREIGN KEY (anden_id) REFERENCES movilidad.anden(id)`; **FK** `FOREIGN KEY (conexion_id) REFERENCES movilidad.conexion_peatonal(id)`; **FK** `FOREIGN KEY (destino_id) REFERENCES movilidad.nodo_red(id)`; **FK** `FOREIGN KEY (fuente_id) REFERENCES staging.fuente_dato(id)`; **FK** `FOREIGN KEY (origen_id) REFERENCES movilidad.nodo_red(id)`; **FK** `FOREIGN KEY (via_id) REFERENCES movilidad.via(id)`; **n** `NOT NULL destino_id`; **n** `NOT NULL geom`; **n** `NOT NULL id`; **n** `NOT NULL longitud`; **n** `NOT NULL modo`; **n** `NOT NULL origen_id`; **n** `NOT NULL origen`; **PK** `PRIMARY KEY (id)`

### `movilidad.conexion_peatonal`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('movilidad.conexion_peatonal_id_seq'::regclass) |  |
| segmento_origen | integer | sí |  |  |
| tipo | text | no |  |  |
| geom | USER-DEFINED | no |  |  |

Restricciones: **n** `NOT NULL geom`; **n** `NOT NULL id`; **n** `NOT NULL tipo`; **PK** `PRIMARY KEY (id)`

### `movilidad.estacion_sitp`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('movilidad.estacion_transmilenio_id_seq'::regclass) |  |
| codigo | text | no |  |  |
| nodo_id | bigint | no |  |  |
| nombre | text | sí |  |  |
| distancia_acceso | numeric | sí |  |  |
| geom | USER-DEFINED | no |  |  |

Restricciones: **FK** `FOREIGN KEY (nodo_id) REFERENCES movilidad.nodo_red(id)`; **n** `NOT NULL codigo`; **n** `NOT NULL geom`; **n** `NOT NULL id`; **n** `NOT NULL nodo_id`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (codigo)`

### `movilidad.estacion_transmilenio`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('movilidad.estacion_transmilenio_id_seq'::regclass) |  |
| codigo | text | no |  |  |
| nodo_id | bigint | no |  |  |
| nombre | text | sí |  |  |
| distancia_acceso | numeric | sí |  |  |
| geom | USER-DEFINED | no |  |  |

Restricciones: **FK** `FOREIGN KEY (nodo_id) REFERENCES movilidad.nodo_red(id)`; **n** `NOT NULL codigo`; **n** `NOT NULL geom`; **n** `NOT NULL id`; **n** `NOT NULL nodo_id`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (codigo)`

### `movilidad.nodo_red`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | bigint | no |  |  |
| geom | USER-DEFINED | no |  |  |

Restricciones: **n** `NOT NULL geom`; **n** `NOT NULL id`; **PK** `PRIMARY KEY (id)`

### `movilidad.obra`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('movilidad.obra_id_seq'::regclass) |  |
| codigo | text | sí |  |  |
| nombre | text | sí |  |  |
| entidad | integer | sí |  |  |
| estado | text | no |  |  |
| fecha_actualizacion | date | sí |  |  |
| fuente_id | integer | sí |  |  |
| radio_afectacion_m | numeric | no | 25 |  |
| geom_punto | USER-DEFINED | no |  |  |
| geom | USER-DEFINED | no |  |  |

Restricciones: **CHECK** `CHECK ((estado = ANY (ARRAY['en ejecucion'::text, 'ejecutada'::text, 'proxima'::text])))`; **FK** `FOREIGN KEY (fuente_id) REFERENCES staging.fuente_dato(id)`; **n** `NOT NULL estado`; **n** `NOT NULL geom`; **n** `NOT NULL geom_punto`; **n** `NOT NULL id`; **n** `NOT NULL radio_afectacion_m`; **PK** `PRIMARY KEY (id)`

### `movilidad.obra_arista`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| obra_id | integer | no |  |  |
| arista_id | bigint | no |  |  |

Restricciones: **FK** `FOREIGN KEY (arista_id) REFERENCES movilidad.arista_red(id)`; **FK** `FOREIGN KEY (obra_id) REFERENCES movilidad.obra(id)`; **n** `NOT NULL arista_id`; **n** `NOT NULL obra_id`; **PK** `PRIMARY KEY (obra_id, arista_id)`

### `movilidad.punto_acceso`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('movilidad.punto_acceso_id_seq'::regclass) |  |
| predio_id | integer | no |  |  |
| nodo_id | bigint | no |  |  |
| distancia_acceso | numeric | no |  |  |
| geom | USER-DEFINED | no |  |  |

Restricciones: **CHECK** `CHECK ((distancia_acceso >= (0)::numeric))`; **FK** `FOREIGN KEY (nodo_id) REFERENCES movilidad.nodo_red(id)`; **FK** `FOREIGN KEY (predio_id) REFERENCES territorio.predio(id)`; **n** `NOT NULL distancia_acceso`; **n** `NOT NULL geom`; **n** `NOT NULL id`; **n** `NOT NULL nodo_id`; **n** `NOT NULL predio_id`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (predio_id)`

### `movilidad.ruta_estacion_sitp`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| ruta_id | integer | no |  |  |
| estacion_id | integer | no |  |  |
| orden | integer | sí |  |  |

Restricciones: **FK** `FOREIGN KEY (estacion_id) REFERENCES movilidad.estacion_sitp(id)`; **FK** `FOREIGN KEY (ruta_id) REFERENCES movilidad.ruta_sitp(id)`; **n** `NOT NULL estacion_id`; **n** `NOT NULL ruta_id`; **PK** `PRIMARY KEY (ruta_id, estacion_id)`

### `movilidad.ruta_estacion_tm`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| ruta_id | integer | no |  |  |
| estacion_id | integer | no |  |  |
| orden | integer | sí |  |  |

Restricciones: **FK** `FOREIGN KEY (estacion_id) REFERENCES movilidad.estacion_transmilenio(id)`; **FK** `FOREIGN KEY (ruta_id) REFERENCES movilidad.ruta_transmilenio(id)`; **n** `NOT NULL estacion_id`; **n** `NOT NULL ruta_id`; **PK** `PRIMARY KEY (ruta_id, estacion_id)`

### `movilidad.ruta_sitp`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('movilidad.ruta_transmilenio_id_seq'::regclass) |  |
| codigo | text | no |  |  |
| nombre | text | sí |  |  |
| route_id | text | sí |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL codigo`; **n** `NOT NULL id`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (codigo)`

### `movilidad.ruta_transmilenio`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('movilidad.ruta_transmilenio_id_seq'::regclass) |  |
| codigo | text | no |  |  |
| nombre | text | sí |  |  |
| route_id | text | sí |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL codigo`; **n** `NOT NULL id`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (codigo)`

### `movilidad.via`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('movilidad.via_id_seq'::regclass) |  |
| codigo | text | sí |  |  |
| tipo | text | sí |  |  |
| nombre | text | sí |  |  |
| geom | USER-DEFINED | no |  |  |

Restricciones: **CHECK** `CHECK (st_isvalid(geom))`; **n** `NOT NULL geom`; **n** `NOT NULL id`; **PK** `PRIMARY KEY (id)`

## Esquema `social`

### `social.demanda_predio`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| predio_id | integer | no |  |  |
| area_vivienda | numeric | no |  |  |
| peso_demanda | numeric | no |  |  |
| tipo_dato | text | no | 'inferido'::text |  |
| supuesto | text | no | 'demanda proporcional al area de uso de vivienda (PREUVIVIEN = S); sin tamano de hogar'::text |  |

Restricciones: **CHECK** `CHECK ((area_vivienda >= (0)::numeric))`; **CHECK** `CHECK ((peso_demanda >= (0)::numeric))`; **FK** `FOREIGN KEY (predio_id) REFERENCES territorio.predio(id)`; **n** `NOT NULL area_vivienda`; **n** `NOT NULL peso_demanda`; **n** `NOT NULL predio_id`; **n** `NOT NULL supuesto`; **n** `NOT NULL tipo_dato`; **PK** `PRIMARY KEY (predio_id)`

### `social.estrato`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| manzana_id | integer | no |  |  |
| estrato | smallint | no |  |  |
| fecha_captura | date | sí |  |  |

Restricciones: **CHECK** `CHECK (((estrato >= 0) AND (estrato <= 6)))`; **FK** `FOREIGN KEY (manzana_id) REFERENCES territorio.manzana(id)`; **n** `NOT NULL estrato`; **n** `NOT NULL manzana_id`; **PK** `PRIMARY KEY (manzana_id)`

## Esquema `staging`

### `staging.andenes`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | bigint | no |  |  |
| atributos | jsonb | sí |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL objectid`; **PK** `PRIMARY KEY (objectid)`

### `staging.andenes_respuestas`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | bigint | no | nextval('staging.andenes_respuestas_id_seq'::regclass) |  |
| lote | integer | sí |  |  |
| codigo_http | integer | sí |  |  |
| contenido | jsonb | sí |  |  |
| fecha_descarga | timestamp without time zone | sí | CURRENT_TIMESTAMP |  |

Restricciones: **n** `NOT NULL id`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (lote)`

### `staging.cobertura_cargada`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('staging.area_estudio_id_seq'::regclass) |  |
| nombre | character varying | sí |  |  |
| descripcion | text | sí |  |  |
| geom | USER-DEFINED | sí |  |  |
| fecha_creacion | timestamp without time zone | sí | CURRENT_TIMESTAMP |  |

Restricciones: **n** `NOT NULL id`; **PK** `PRIMARY KEY (id)`

### `staging.control_lotes_uso`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| lote | integer | no |  |  |
| codigos | ARRAY | no |  |  |
| estado | text | no | 'pendiente'::text |  |
| registros | integer | sí | 0 |  |
| ultimo_error | text | sí |  |  |
| actualizado | timestamp with time zone | sí |  |  |

Restricciones: **n** `NOT NULL codigos`; **n** `NOT NULL estado`; **n** `NOT NULL lote`; **PK** `PRIMARY KEY (lote)`

### `staging.estrato_poligono`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | bigint | sí |  |  |
| codigo_manzana | text | sí |  |  |
| estrato | integer | sí |  |  |
| fecha_captura | date | sí |  |  |
| geom | USER-DEFINED | sí |  |  |

### `staging.fuente_dato`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('staging.fuente_dato_id_seq'::regclass) |  |
| nombre | text | no |  |  |
| entidad | text | sí |  |  |
| url | text | sí |  |  |
| fecha_descarga | date | sí |  |  |
| licencia | text | sí |  |  |
| cobertura | text | sí |  |  |
| escala | text | sí |  |  |
| limitaciones | text | sí |  |  |

Restricciones: **n** `NOT NULL id`; **n** `NOT NULL nombre`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (nombre)`

### `staging.gtfs_parada`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| stop_id | text | no |  |  |
| stop_code | text | sí |  |  |
| stop_name | text | sí |  |  |
| zone_id | text | sí |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL stop_id`; **PK** `PRIMARY KEY (stop_id)`

### `staging.gtfs_ruta`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| route_id | text | no |  |  |
| route_short_name | text | sí |  |  |
| route_long_name | text | sí |  |  |
| route_type | integer | sí |  |  |
| agency_id | text | sí |  |  |
| shape_id | text | sí |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL route_id`; **PK** `PRIMARY KEY (route_id)`

### `staging.gtfs_ruta_parada`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| route_id | text | no |  |  |
| stop_id | text | no |  |  |
| orden | integer | sí |  |  |

Restricciones: **n** `NOT NULL route_id`; **n** `NOT NULL stop_id`; **PK** `PRIMARY KEY (route_id, stop_id)`

### `staging.legado_andenes`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | bigint | no |  |  |
| codigo_anden | text | sí |  |  |
| codigo_civ | text | sí |  |  |
| codigo_material | text | sí |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL objectid`; **PK** `PRIMARY KEY (objectid)`

### `staging.legado_conexiones_andenes`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| anden_1 | bigint | no |  |  |
| anden_2 | bigint | no |  |  |
| tipo_conexion | text | sí |  |  |
| distancia_m | double precision | sí |  |  |
| geom | USER-DEFINED | sí |  |  |
| validada | boolean | sí | false |  |

Restricciones: **n** `NOT NULL anden_1`; **n** `NOT NULL anden_2`; **PK** `PRIMARY KEY (anden_1, anden_2)`

### `staging.legado_ejes_andenes`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid_anden | bigint | no |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL objectid_anden`; **PK** `PRIMARY KEY (objectid_anden)`

### `staging.legado_establecimientos_red_peatonal`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| establecimiento_id | text | sí |  |  |
| nombre | text | sí |  |  |
| categoria | text | sí |  |  |
| fuente | text | sí |  |  |
| punto_establecimiento | USER-DEFINED | sí |  |  |
| arista_id | bigint | sí |  |  |
| source | bigint | sí |  |  |
| target | bigint | sí |  |  |
| punto_red | USER-DEFINED | sí |  |  |
| fraccion_arista | double precision | sí |  |  |
| distancia_conexion_m | double precision | sí |  |  |

### `staging.legado_localidad`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | integer | no |  |  |
| loccodigo | character varying | sí |  |  |
| locnombre | character varying | sí |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL objectid`; **PK** `PRIMARY KEY (objectid)`

### `staging.legado_lotes`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | bigint | no |  |  |
| codigo_lote | text | sí |  |  |
| codigo_manzana | text | sí |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL objectid`; **PK** `PRIMARY KEY (objectid)`

### `staging.legado_lotes_red_peatonal`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid_lote | bigint | sí |  |  |
| codigo_lote | text | sí |  |  |
| codigo_manzana | text | sí |  |  |
| objectid_anden | bigint | sí |  |  |
| distancia_eje_m | double precision | sí |  |  |
| punto_acceso | USER-DEFINED | sí |  |  |
| punto_red | USER-DEFINED | sí |  |  |
| arista_id | bigint | sí |  |  |
| source | bigint | sí |  |  |
| target | bigint | sí |  |  |
| fraccion_arista | double precision | sí |  |  |
| distancia_ajuste_m | double precision | sí |  |  |

### `staging.legado_malla_vial`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | bigint | no |  |  |
| codigo_vial | text | sí |  |  |
| nombre_via | text | sí |  |  |
| clasificacion | integer | sí |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL objectid`; **PK** `PRIMARY KEY (objectid)`

### `staging.legado_manzana`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | integer | no |  |  |
| mancodigo | character varying | sí |  |  |
| seccodigo | character varying | sí |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL objectid`; **PK** `PRIMARY KEY (objectid)`

### `staging.legado_otros_establecimientos_osm`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| tipo_osm | text | no |  |  |
| id_osm | bigint | no |  |  |
| nombre | text | sí |  |  |
| categoria | text | sí |  |  |
| direccion | text | sí |  |  |
| etiquetas | jsonb | sí |  |  |
| geom | USER-DEFINED | sí |  |  |
| fecha_carga | timestamp without time zone | sí | CURRENT_TIMESTAMP |  |

Restricciones: **n** `NOT NULL id_osm`; **n** `NOT NULL tipo_osm`; **PK** `PRIMARY KEY (tipo_osm, id_osm)`

### `staging.legado_plaza_mercado`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| gid | integer | no | nextval('staging.plaza_mercado_20211229_gid_seq'::regclass) |  |
| codigo_pla | character varying | sí |  |  |
| numero_pre | integer | sí |  |  |
| numero_equ | integer | sí |  |  |
| identifica | character varying | sí |  |  |
| suelo | character varying | sí |  |  |
| codigo_equ | character varying | sí |  |  |
| rupi | character varying | sí |  |  |
| codigo_pi_ | character varying | sí |  |  |
| nombre | character varying | sí |  |  |
| direccion | character varying | sí |  |  |
| telefono | character varying | sí |  |  |
| servicio_s | integer | sí |  |  |
| chip | character varying | sí |  |  |
| codigo_upz | double precision | sí |  |  |
| codigo_loc | character varying | sí |  |  |
| codigo_upr | double precision | sí |  |  |
| area_predi | numeric | sí |  |  |
| area_const | numeric | sí |  |  |
| homologado | character varying | sí |  |  |
| tipo | integer | sí |  |  |
| escala_pot | double precision | sí |  |  |
| area_ocupa | numeric | sí |  |  |
| caracter | character varying | sí |  |  |
| funcion | integer | sí |  |  |
| acto_admin | character varying | sí |  |  |
| numero_act | character varying | sí |  |  |
| fecha_acto | date | sí |  |  |
| normativa | character varying | sí |  |  |
| observacio | character varying | sí |  |  |
| escala_cap | character varying | sí |  |  |
| fecha_capt | date | sí |  |  |
| responsabl | character varying | sí |  |  |
| shape_leng | numeric | sí |  |  |
| shape_area | numeric | sí |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL gid`; **PK** `PRIMARY KEY (gid)`

### `staging.legado_red_peatonal_aristas`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | bigint | no |  |  |
| geom | USER-DEFINED | sí |  |  |
| cost | double precision | sí |  |  |
| reverse_cost | double precision | sí |  |  |
| source | bigint | sí |  |  |
| target | bigint | sí |  |  |

Restricciones: **n** `NOT NULL id`; **PK** `PRIMARY KEY (id)`

### `staging.legado_red_peatonal_nodos`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | bigint | no |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL id`; **PK** `PRIMARY KEY (id)`

### `staging.legado_red_peatonal_pot`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | bigint | no |  |  |
| nombre_via | text | sí |  |  |
| tipo_clasificacion | integer | sí |  |  |
| atributos | jsonb | sí |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL objectid`; **PK** `PRIMARY KEY (objectid)`

### `staging.legado_red_peatonal_segmentos`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | bigint | no | nextval('staging.legado_red_peatonal_segmentos_id_seq'::regclass) |  |
| objectid_anden | bigint | sí |  |  |
| tipo | text | no |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL id`; **n** `NOT NULL tipo`; **PK** `PRIMARY KEY (id)`

### `staging.legado_supermercados_osm`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| tipo_osm | text | no |  |  |
| id_osm | bigint | no |  |  |
| nombre | text | sí |  |  |
| categoria | text | sí |  |  |
| direccion | text | sí |  |  |
| etiquetas | jsonb | sí |  |  |
| geom | USER-DEFINED | sí |  |  |
| fecha_carga | timestamp without time zone | sí | CURRENT_TIMESTAMP |  |

Restricciones: **n** `NOT NULL id_osm`; **n** `NOT NULL tipo_osm`; **PK** `PRIMARY KEY (tipo_osm, id_osm)`

### `staging.localidad`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | integer | no |  |  |
| loccodigo | character varying | sí |  |  |
| locnombre | character varying | sí |  |  |
| locaadmini | character varying | sí |  |  |
| locarea | double precision | sí |  |  |
| geom | USER-DEFINED | sí |  |  |
| fecha_carga | timestamp without time zone | sí | CURRENT_TIMESTAMP |  |
| fuente_url | text | sí |  |  |

Restricciones: **n** `NOT NULL objectid`; **PK** `PRIMARY KEY (objectid)`

### `staging.lote_catastro`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | bigint | no |  |  |
| codigo_lote | text | no |  |  |
| codigo_manzana | text | no |  |  |
| geom | USER-DEFINED | no |  |  |

Restricciones: **n** `NOT NULL codigo_lote`; **n** `NOT NULL codigo_manzana`; **n** `NOT NULL geom`; **n** `NOT NULL objectid`; **PK** `PRIMARY KEY (objectid)`

### `staging.lotes`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | bigint | no |  |  |
| atributos | jsonb | sí |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL objectid`; **PK** `PRIMARY KEY (objectid)`

### `staging.lotes_ids`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | bigint | no |  |  |

Restricciones: **n** `NOT NULL objectid`; **PK** `PRIMARY KEY (objectid)`

### `staging.lotes_respuestas`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| lote | integer | no |  |  |
| codigo_http | integer | sí |  |  |
| contenido | jsonb | sí |  |  |
| fecha_descarga | timestamp without time zone | sí | CURRENT_TIMESTAMP |  |

Restricciones: **n** `NOT NULL lote`; **PK** `PRIMARY KEY (lote)`

### `staging.malla_vial`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | bigint | no |  |  |
| atributos | jsonb | sí |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL objectid`; **PK** `PRIMARY KEY (objectid)`

### `staging.malla_vial_catastro`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | bigint | no |  |  |
| codigo_vial | text | sí |  |  |
| nombre_via | text | sí |  |  |
| clasificacion | text | sí |  |  |
| tipo | text | sí |  |  |
| geom | USER-DEFINED | no |  |  |

Restricciones: **n** `NOT NULL geom`; **n** `NOT NULL objectid`; **PK** `PRIMARY KEY (objectid)`

### `staging.malla_vial_respuestas`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | bigint | no | nextval('staging.malla_vial_respuestas_id_seq'::regclass) |  |
| lote | integer | sí |  |  |
| codigo_http | integer | sí |  |  |
| contenido | jsonb | sí |  |  |
| fecha_descarga | timestamp without time zone | sí | CURRENT_TIMESTAMP |  |

Restricciones: **n** `NOT NULL id`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (lote)`

### `staging.manzana`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | integer | no |  |  |
| mancodigo | character varying | sí |  |  |
| seccodigo | character varying | sí |  |  |
| geom | USER-DEFINED | sí |  |  |
| fecha_carga | timestamp without time zone | sí | CURRENT_TIMESTAMP |  |

Restricciones: **n** `NOT NULL objectid`; **PK** `PRIMARY KEY (objectid)`

### `staging.obra_publica`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | bigint | sí |  |  |
| cod_obra | text | sí |  |  |
| obra | text | sí |  |  |
| entidad | integer | sí |  |  |
| localidad | integer | sí |  |  |
| estado | integer | sí |  |  |
| tipo_obra | integer | sí |  |  |
| fecha_actualizacion | date | sí |  |  |
| upz | text | sí |  |  |
| geom | USER-DEFINED | sí |  |  |

### `staging.osm_alimentos_respuesta`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | bigint | no | nextval('staging.osm_alimentos_respuesta_id_seq'::regclass) |  |
| fecha_consulta | timestamp without time zone | sí | CURRENT_TIMESTAMP |  |
| codigo_http | integer | sí |  |  |
| contenido | text | sí |  |  |

Restricciones: **n** `NOT NULL id`; **PK** `PRIMARY KEY (id)`

### `staging.osm_elemento`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('staging.osm_elemento_id_seq'::regclass) |  |
| tipo_osm | text | no |  |  |
| id_osm | bigint | no |  |  |
| nombre | text | sí |  |  |
| categoria | text | no |  |  |
| etiquetas | jsonb | sí |  |  |
| geom | USER-DEFINED | no |  |  |

Restricciones: **n** `NOT NULL categoria`; **n** `NOT NULL geom`; **n** `NOT NULL id`; **n** `NOT NULL id_osm`; **n** `NOT NULL tipo_osm`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (tipo_osm, id_osm)`

### `staging.plaza_mercado`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| gid | integer | no | nextval('staging.plaza_mercado_gid_seq'::regclass) |  |
| codigo_pla | character varying | sí |  |  |
| numero_pre | integer | sí |  |  |
| numero_equ | integer | sí |  |  |
| identifica | character varying | sí |  |  |
| suelo | character varying | sí |  |  |
| codigo_equ | character varying | sí |  |  |
| rupi | character varying | sí |  |  |
| codigo_pi_ | character varying | sí |  |  |
| nombre | character varying | sí |  |  |
| direccion | character varying | sí |  |  |
| telefono | character varying | sí |  |  |
| servicio_s | integer | sí |  |  |
| chip | character varying | sí |  |  |
| codigo_upz | double precision | sí |  |  |
| codigo_loc | character varying | sí |  |  |
| codigo_upr | double precision | sí |  |  |
| area_predi | numeric | sí |  |  |
| area_const | numeric | sí |  |  |
| homologado | character varying | sí |  |  |
| tipo | integer | sí |  |  |
| escala_pot | double precision | sí |  |  |
| area_ocupa | numeric | sí |  |  |
| caracter | character varying | sí |  |  |
| funcion | integer | sí |  |  |
| acto_admin | character varying | sí |  |  |
| numero_act | character varying | sí |  |  |
| fecha_acto | date | sí |  |  |
| normativa | character varying | sí |  |  |
| observacio | character varying | sí |  |  |
| escala_cap | character varying | sí |  |  |
| fecha_capt | date | sí |  |  |
| responsabl | character varying | sí |  |  |
| shape_leng | numeric | sí |  |  |
| shape_area | numeric | sí |  |  |
| geom | USER-DEFINED | sí |  |  |

Restricciones: **n** `NOT NULL gid`; **PK** `PRIMARY KEY (gid)`

### `staging.predio_catastro`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | bigint | sí |  |  |
| chip | text | sí |  |  |
| barmanpre | text | sí |  |  |
| nupre | text | sí |  |  |
| clase | text | sí |  |  |
| destino | text | sí |  |  |
| cod_uso | text | sí |  |  |
| area_uso | numeric | sí |  |  |
| area_terreno | numeric | sí |  |  |
| area_construida | numeric | sí |  |  |
| uso_vivienda | text | sí |  |  |
| unidad_calificada | text | sí |  |  |
| direccion | text | sí |  |  |
| vigencia_actual | integer | sí |  |  |
| atributos | jsonb | sí |  |  |

### `staging.red_peatonal_pot_respuestas`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| lote | integer | no |  |  |
| codigo_http | integer | sí |  |  |
| contenido | jsonb | sí |  |  |
| fecha_descarga | timestamp without time zone | sí | CURRENT_TIMESTAMP |  |

Restricciones: **n** `NOT NULL lote`; **PK** `PRIMARY KEY (lote)`

### `staging.uso_predominante`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | integer | no |  |  |
| mancodigo | character varying | sí |  |  |
| grupo_uso_econ | character varying | sí |  |  |
| ano | bigint | sí |  |  |
| geom | USER-DEFINED | sí |  |  |
| fecha_carga | timestamp without time zone | sí | CURRENT_TIMESTAMP |  |

Restricciones: **n** `NOT NULL objectid`; **PK** `PRIMARY KEY (objectid)`

### `staging.uso_predominante_historico`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| objectid | integer | no |  |  |
| mancodigo | character varying | sí |  |  |
| grupo_uso_econ | text | sí |  |  |
| ano | bigint | sí |  |  |
| fecha_carga | timestamp without time zone | sí | CURRENT_TIMESTAMP |  |

Restricciones: **n** `NOT NULL objectid`; **PK** `PRIMARY KEY (objectid)`

## Esquema `territorio`

### `territorio.localidad`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('territorio.localidad_id_seq'::regclass) |  |
| codigo | text | no |  |  |
| nombre | text | no |  |  |
| geom | USER-DEFINED | no |  |  |

Restricciones: **CHECK** `CHECK (st_isvalid(geom))`; **n** `NOT NULL codigo`; **n** `NOT NULL geom`; **n** `NOT NULL id`; **n** `NOT NULL nombre`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (codigo)`

### `territorio.lote`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('territorio.lote_id_seq'::regclass) |  |
| codigo | text | no |  |  |
| manzana_id | integer | no |  |  |
| fuente_id | integer | sí |  |  |
| fecha_observacion | date | sí |  |  |
| fecha_carga | date | sí |  |  |
| tipo | text | no | 'predial'::text |  |
| geom | USER-DEFINED | no |  |  |

Restricciones: **CHECK** `CHECK (st_isvalid(geom))`; **CHECK** `CHECK ((tipo = ANY (ARRAY['predial'::text, 'via_espacio_publico'::text])))`; **FK** `FOREIGN KEY (fuente_id) REFERENCES staging.fuente_dato(id)`; **FK** `FOREIGN KEY (manzana_id) REFERENCES territorio.manzana(id)`; **n** `NOT NULL codigo`; **n** `NOT NULL geom`; **n** `NOT NULL id`; **n** `NOT NULL manzana_id`; **n** `NOT NULL tipo`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (codigo)`

### `territorio.manzana`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('territorio.manzana_id_seq'::regclass) |  |
| codigo | text | no |  |  |
| localidad_id | integer | no |  |  |
| geom | USER-DEFINED | no |  |  |

Restricciones: **CHECK** `CHECK (st_isvalid(geom))`; **FK** `FOREIGN KEY (localidad_id) REFERENCES territorio.localidad(id)`; **n** `NOT NULL codigo`; **n** `NOT NULL geom`; **n** `NOT NULL id`; **n** `NOT NULL localidad_id`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (codigo)`

### `territorio.predio`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('territorio.predio_id_seq'::regclass) |  |
| chip | text | no |  |  |
| lote_id | integer | no |  |  |
| nupre | text | sí |  |  |
| clase | text | sí |  |  |
| destino | text | sí |  |  |
| direccion | text | sí |  |  |
| area_terreno | numeric | sí |  |  |
| area_construida | numeric | sí |  |  |

Restricciones: **FK** `FOREIGN KEY (lote_id) REFERENCES territorio.lote(id)`; **n** `NOT NULL chip`; **n** `NOT NULL id`; **n** `NOT NULL lote_id`; **PK** `PRIMARY KEY (id)`; **UNIQUE** `UNIQUE (chip)`

### `territorio.uso_construccion`

| Columna | Tipo | Nulo | Por defecto | Descripción |
|---|---|---|---|---|
| id | integer | no | nextval('territorio.uso_construccion_id_seq'::regclass) |  |
| predio_id | integer | no |  |  |
| codigo_uso | text | sí |  |  |
| area_uso | numeric | sí |  |  |
| es_vivienda | boolean | sí |  | PREUVIVIEN de Catastro = S |

Restricciones: **CHECK** `CHECK (((area_uso IS NULL) OR (area_uso >= (0)::numeric)))`; **FK** `FOREIGN KEY (predio_id) REFERENCES territorio.predio(id)`; **n** `NOT NULL id`; **n** `NOT NULL predio_id`; **PK** `PRIMARY KEY (id)`
