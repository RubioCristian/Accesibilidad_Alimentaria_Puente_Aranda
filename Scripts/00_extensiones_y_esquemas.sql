-- 00: extensiones, esquemas (paquetes del ER) y reubicacion de las tablas heredadas.
-- Se aplica sobre la base restaurada de Backup/alimentos_puente_aranda_original.backup.
-- Es re-ejecutable: cada paso comprueba si ya se hizo.
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgrouting;
CREATE EXTENSION IF NOT EXISTS postgis_sfcgal;
CREATE EXTENSION IF NOT EXISTS http;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'staging')
     AND NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'crudo') THEN
    ALTER SCHEMA staging RENAME TO crudo;
  END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS crudo;
CREATE SCHEMA IF NOT EXISTS territorio;
CREATE SCHEMA IF NOT EXISTS social;
CREATE SCHEMA IF NOT EXISTS alimentos;
CREATE SCHEMA IF NOT EXISTS movilidad;
CREATE SCHEMA IF NOT EXISTS analisis;
CREATE SCHEMA IF NOT EXISTS interoperabilidad;

-- Las tablas del trabajo anterior pasan a crudo con prefijo legado_ y alimentan el modelo nuevo.
-- Las tablas con el mismo nombre en el esquema nuevo se reconstruyen en los scripts 02 a 06.
DO $$
DECLARE r record; o record;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('territorio','localidad'), ('territorio','manzana'), ('territorio','lotes'),
      ('movilidad','andenes'), ('movilidad','malla_vial'), ('movilidad','ejes_andenes'),
      ('movilidad','conexiones_andenes'), ('movilidad','red_peatonal_nodos'),
      ('movilidad','red_peatonal_aristas'), ('movilidad','red_peatonal_segmentos'),
      ('movilidad','red_peatonal_pot'), ('movilidad','lotes_red_peatonal'),
      ('movilidad','establecimientos_red_peatonal'),
      ('alimentos','supermercados_osm'), ('alimentos','otros_establecimientos_osm')
    ) AS t(esquema, tabla)
  LOOP
    IF to_regclass(format('%I.%I', r.esquema, r.tabla)) IS NOT NULL
       AND to_regclass(format('crudo.legado_%s', r.tabla)) IS NULL THEN   -- ya movida: no se repite
      EXECUTE format('ALTER TABLE %I.%I RENAME TO %I', r.esquema, r.tabla, 'legado_' || r.tabla);
      -- los indices y secuencias propios tambien se renombran para no chocar con los de crudo
      FOR o IN SELECT indexname AS nombre, 'INDEX' AS tipo FROM pg_indexes
               WHERE schemaname = r.esquema AND tablename = 'legado_' || r.tabla
               UNION ALL
               SELECT c.relname, 'SEQUENCE' FROM pg_class c JOIN pg_depend d ON d.objid = c.oid
               WHERE c.relkind = 'S' AND d.refobjid = format('%I.%I', r.esquema, 'legado_' || r.tabla)::regclass
      LOOP
        EXECUTE format('ALTER %s %I.%I RENAME TO %I', o.tipo, r.esquema, o.nombre, 'legado_' || o.nombre);
      END LOOP;
      EXECUTE format('ALTER TABLE %I.%I SET SCHEMA crudo', r.esquema, 'legado_' || r.tabla);
    END IF;
  END LOOP;

  IF to_regclass('territorio.area_estudio') IS NOT NULL THEN
    ALTER TABLE territorio.area_estudio RENAME TO cobertura_cargada;
    ALTER TABLE territorio.cobertura_cargada SET SCHEMA crudo;
  END IF;
  IF to_regclass('public.plaza_mercado_20211229') IS NOT NULL THEN
    ALTER TABLE public.plaza_mercado_20211229 RENAME TO legado_plaza_mercado;
    ALTER TABLE public.legado_plaza_mercado SET SCHEMA crudo;
  END IF;
END $$;

COMMENT ON SCHEMA crudo IS 'Descargas originales, tablas heredadas (legado_*) y catalogo de fuentes';
COMMENT ON SCHEMA territorio IS 'Localidad, manzana, lote, predio y uso por construccion';
COMMENT ON SCHEMA social IS 'Estrato (por manzana) y demanda asumida por predio';
COMMENT ON SCHEMA alimentos IS 'Categorias y establecimientos de alimentos';
COMMENT ON SCHEMA movilidad IS 'Vias, andenes, red peatonal, obras, TransMilenio y SITP';
COMMENT ON SCHEMA analisis IS 'Escenarios, criterios, ejecuciones, matriz origen-destino e indicadores';
COMMENT ON SCHEMA interoperabilidad IS 'Correspondencias con LADM-COL';
