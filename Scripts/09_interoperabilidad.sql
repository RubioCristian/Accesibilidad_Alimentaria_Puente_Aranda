-- 09: interoperabilidad. Correspondencias con LADM-COL "en la medida que sea aplicable".
-- El modelo propio NO es LADM-COL. Los destinos son una PROPUESTA pendiente de verificar contra el catalogo oficial.
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
 ('territorio.lote', 'geom / codigo', 'Terreno (geometria del predio)', 'El lote de Catastro se lee como la geometria del terreno; codigo = BARMANPRE',
  'Sin historia de versiones ni limites juridicos', 'Modelo Extendido Catastro-Registro v4.1'),
 ('territorio.predio', 'chip', 'Predio (identificador catastral)', 'CHIP como identificador de la unidad predial',
  'El CHIP no sustituye al numero predial nacional; se conserva tambien nupre', 'Modelo Extendido Catastro-Registro v4.1'),
 ('territorio.predio', 'nupre', 'Predio (numero predial nacional)', 'Copia directa de PRENUPRE', 'Por verificar el nombre exacto del atributo', 'Modelo Extendido Catastro-Registro v4.1'),
 ('territorio.predio', 'destino', 'Predio (destinacion economica)', 'Copia del codigo PRECDESTIN', 'Por verificar el dominio de codigos', 'Modelo Extendido Catastro-Registro v4.1'),
 ('territorio.uso_construccion', 'codigo_uso / area_uso', 'Unidad de construccion (uso y area)', 'Una fila por unidad calificada (PRECUSO, PREAUSO)',
  'No se modela la geometria de la construccion ni su calificacion', 'Modelo Extendido Catastro-Registro v4.1'),
 ('territorio.manzana', 'codigo', 'Sin correspondencia directa', 'No aplica', 'Se conserva como unidad de agregacion propia', 'Modelo Nucleo v4.0.1'),
 ('movilidad.*, alimentos.*, analisis.*', NULL, 'Fuera del alcance de LADM-COL', 'No aplica', 'Dominio de movilidad y accesibilidad', 'Modelo Nucleo v4.0.1');
