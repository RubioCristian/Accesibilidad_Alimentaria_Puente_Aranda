# Interoperabilidad con LADM-COL

**Alcance.** El modelo del taller es un modelo temático propio. LADM-COL se aplica "en la medida que sea aplicable": solo a lote, predio y unidad de construcción. El modelo propio **no es** un modelo LADM-COL y no se afirma equivalencia donde no la hay.

## Versión consultada (2026-11-05)
| Elemento | Versión | Fuente |
|---|---|---|
| Modelo Extendido Catastro-Registro | **v4.1**, aprobado por la Resolución Conjunta IGAC 1456 / SNR 09844 del 12-sep-2024 | [IGAC, LADM-COL](https://www.igac.gov.co/catastro-multiproposito/ladmcol) |
| Modelo Núcleo | **v4.0.1** (Acuerdo 002 de diciembre de 2023 de la ICDE) | cabecera del `.ili` oficial |
| Archivo revisado | `Modelo_Extendido_LADMCOL_Cat_Reg_V4_1.ili` (INTERLIS 2.3) | [Repositorio Oficial de Modelos LADM, ICDE](https://www.icde.gov.co/Repositorio%20Oficial%20de%20Modelos%20LADM/catastro-registro-cr) |

Los nombres de clase y atributo de la tabla siguiente se leyeron directamente del `.ili` (por ejemplo `CR_Predio.Numero_Predial_Nacional : TEXT*30`).

## Correspondencias
Tabla `interoperabilidad.correspondencia_ladm` (script `Scripts/09_interoperabilidad.sql`).

| Origen (modelo propio) | Destino LADM-COL v4.1 | Regla | Limitación |
|---|---|---|---|
| `territorio.lote.geom` | `CR_Terreno.Geometria` | El lote se lee como geometría del terreno | Geometría plana en SRID 9377; el modelo oficial usa `GM_MultiSurface3D`. Sin límites jurídicos ni historia |
| `territorio.lote.codigo` (BARMANPRE) | Sin correspondencia | — | No es el número predial nacional |
| `territorio.predio.nupre` (PRENUPRE) | `CR_Predio.Numero_Predial_Nacional` | Copia directa | Los 81 133 valores tienen 30 caracteres, como exige `TEXT*30`; no se validó dígito a dígito |
| `territorio.predio.chip` | Sin correspondencia | Se conserva como identificador local | El CHIP no está definido en el modelo oficial; no se asigna a `Codigo_Homologado` ni `NUPRE` |
| `territorio.predio.destino` | `CR_Predio.Destinacion_Economica` (dominio `CR_DestinacionEconomicaTipo`) | Requiere tabla de equivalencias de códigos | Los dominios no son 1 a 1; la tabla no está construida |
| `territorio.predio.area_terreno` | `CR_Predio.Area_Catastral_Terreno` | Copia en m² | No se contrasta con el área registral |
| `territorio.predio.direccion` | `CR_Predio.Direccion` (`ExtDireccion`) | Texto libre | No se normaliza a la estructura oficial |
| `territorio.uso_construccion` | `CR_CaracteristicasUnidadConstruccion.Uso` y `Area_Construida` | Una fila por unidad calificada | Sin geometría de la construcción, planta, año ni estado de conservación |
| `territorio.manzana`, `social.estrato` | Sin correspondencia | — | Unidad de agregación propia; la estratificación no pertenece al modelo catastro-registro |
| `movilidad.*`, `alimentos.*`, `analisis.*` | Fuera del alcance | — | Dominio de movilidad y accesibilidad |

## Qué no se hizo
- No hay tabla de equivalencias entre los códigos de destino y uso de Catastro Bogotá y los dominios `CR_DestinacionEconomicaTipo` y `CR_UsoUConsTipo`; quedan como trabajo pendiente.
- No se propone ninguna extensión al modelo oficial.
