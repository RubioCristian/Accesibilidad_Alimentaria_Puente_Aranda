-- 09: interoperabilidad. Correspondencias con LADM-COL "en la medida que sea aplicable".
-- El modelo propio NO es LADM-COL. Los destinos son correspondencias PROPUESTAS, con nombres de clase y atributo verificados
-- el 2026-11-05 en el archivo oficial Modelo_Extendido_LADMCOL_Cat_Reg_V4_1.ili del Repositorio Oficial de Modelos LADM de la ICDE
-- (https://www.icde.gov.co/Repositorio%20Oficial%20de%20Modelos%20LADM/catastro-registro-cr). Si el significado no es equivalente se dice en limitaciones.
DROP TABLE IF EXISTS interoperabilidad.correspondencia_ladm CASCADE;

CREATE TABLE interoperabilidad.correspondencia_ladm (
  id                   serial PRIMARY KEY,
  entidad_origen       text NOT NULL,
  atributo_origen      text,
  elemento_destino     text NOT NULL,
  regla_transformacion text,
  limitaciones         text,
  version_ladm         text NOT NULL
);

INSERT INTO interoperabilidad.correspondencia_ladm
  (entidad_origen, atributo_origen, elemento_destino, regla_transformacion, limitaciones, version_ladm) VALUES
 ('territorio.lote', 'geom', 'CR_Terreno.Geometria', 'El lote de Catastro se lee como la geometria poligonal del terreno; se exporta a MultiSurface',
  'Geometria plana en SRID 9377; el modelo oficial usa GM_MultiSurface3D. No se modelan limites juridicos ni historia de versiones', 'Modelo Extendido Catastro-Registro v4.1 (Nucleo v4.0.1)'),
 ('territorio.lote', 'codigo (BARMANPRE)', 'Sin correspondencia directa', 'No aplica',
  'Codigo barrio-manzana-predio propio de Catastro Bogota; no es el Numero_Predial_Nacional', 'Modelo Extendido Catastro-Registro v4.1 (Nucleo v4.0.1)'),
 ('territorio.predio', 'nupre (PRENUPRE)', 'CR_Predio.Numero_Predial_Nacional', 'Copia directa; todos los valores tienen 30 caracteres, como exige TEXT*30',
  'Se verifico la longitud, no el contenido digito a digito frente a la estructura del NPN', 'Modelo Extendido Catastro-Registro v4.1 (Nucleo v4.0.1)'),
 ('territorio.predio', 'chip (PRECHIP)', 'Sin correspondencia directa', 'Se conserva como identificador local; no se asigna a Codigo_Homologado ni a NUPRE',
  'El CHIP es un identificador de Catastro Bogota; el modelo oficial no lo define. Codigo_Homologado y NUPRE (TEXT*11) los asigna otra entidad', 'Modelo Extendido Catastro-Registro v4.1 (Nucleo v4.0.1)'),
 ('territorio.predio', 'destino (PRECDESTIN)', 'CR_Predio.Destinacion_Economica (dominio CR_DestinacionEconomicaTipo)', 'Requiere tabla de equivalencias entre los codigos de Catastro y los valores del dominio (Comercial, Educativo, ...); aun no construida',
  'Los dominios no son 1 a 1; no se convierten los codigos hasta tener la tabla oficial', 'Modelo Extendido Catastro-Registro v4.1 (Nucleo v4.0.1)'),
 ('territorio.predio', 'area_terreno (PREATERRE)', 'CR_Predio.Area_Catastral_Terreno', 'Copia directa en m2', 'Area de Catastro Bogota sin contrastar con el area registral', 'Modelo Extendido Catastro-Registro v4.1 (Nucleo v4.0.1)'),
 ('territorio.predio', 'direccion', 'CR_Predio.Direccion (ExtDireccion)', 'Texto libre a una direccion principal', 'No se normaliza la direccion segun la estructura ExtDireccion', 'Modelo Extendido Catastro-Registro v4.1 (Nucleo v4.0.1)'),
 ('territorio.uso_construccion', 'codigo_uso / area_uso', 'CR_CaracteristicasUnidadConstruccion.Uso (CR_UsoUConsTipo) y Area_Construida', 'Una fila por unidad calificada (PRECUSO, PREAUSO); requiere equivalencias de codigos de uso',
  'No se modela la geometria (CR_UnidadConstruccion), ni planta, anio ni estado de conservacion', 'Modelo Extendido Catastro-Registro v4.1 (Nucleo v4.0.1)'),
 ('territorio.manzana', 'codigo', 'Sin correspondencia directa', 'No aplica', 'Unidad de agregacion propia del analisis', 'Modelo Nucleo v4.0.1'),
 ('social.estrato', 'estrato', 'Sin correspondencia directa', 'No aplica', 'La estratificacion no hace parte del modelo catastro-registro', 'Modelo Nucleo v4.0.1'),
 ('movilidad.*, alimentos.*, analisis.*', NULL, 'Fuera del alcance de LADM-COL', 'No aplica', 'Dominio de movilidad, oferta alimentaria y accesibilidad', 'Modelo Nucleo v4.0.1');
