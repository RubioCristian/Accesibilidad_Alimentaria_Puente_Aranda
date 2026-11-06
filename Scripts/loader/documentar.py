"""Genera docs/catalogo_datos.md y docs/diccionario_datos.md desde la base (fuente_dato, information_schema y restricciones).

Uso:  python -m Scripts.loader.documentar [carpeta_salida]   (por defecto /app/docs en el contenedor etl)
"""
import sys
from datetime import date
from pathlib import Path

from .comun import conectar

ESQUEMAS = ("staging", "territorio", "social", "alimentos", "movilidad", "analisis", "interoperabilidad")


def celda(v):
    return "" if v is None else str(v).replace("|", "/").replace("\n", " ")


def tabla(cabeza, filas):
    out = ["| " + " | ".join(cabeza) + " |", "|" + "---|" * len(cabeza)]
    out += ["| " + " | ".join(celda(c) for c in f) + " |" for f in filas]
    return "\n".join(out)


def catalogo(con):
    filas = con.execute("""SELECT id, nombre, entidad, url, fecha_descarga, licencia, cobertura, escala, limitaciones
                             FROM staging.fuente_dato ORDER BY id""").fetchall()
    texto = f"""# Catálogo de datos

Generado el {date.today()} desde `staging.fuente_dato` (`Scripts/loader/documentar.py`). Cada fila registra organización, URL, licencia,
fecha de descarga, cobertura, escala y limitaciones, como pide el taller. Un campo vacío significa que **no se pudo confirmar**; no se inventa.

"""
    texto += tabla(["id", "Fuente", "Organización", "URL", "Descarga", "Licencia", "Cobertura", "Escala", "Limitaciones"], filas)
    return texto + "\n"


def diccionario(con):
    cols = con.execute("""
        SELECT c.table_schema, c.table_name, c.column_name, c.data_type, c.is_nullable, c.column_default,
               col_description((quote_ident(c.table_schema) || '.' || quote_ident(c.table_name))::regclass, c.ordinal_position)
          FROM information_schema.columns c
          JOIN information_schema.tables t USING (table_schema, table_name)
         WHERE c.table_schema = ANY(%s) AND t.table_type = 'BASE TABLE'
         ORDER BY c.table_schema, c.table_name, c.ordinal_position""", (list(ESQUEMAS),)).fetchall()
    restr = con.execute("""
        SELECT n.nspname, cl.relname, co.conname, co.contype, pg_get_constraintdef(co.oid)
          FROM pg_constraint co JOIN pg_class cl ON cl.oid = co.conrelid JOIN pg_namespace n ON n.oid = cl.relnamespace
         WHERE n.nspname = ANY(%s) ORDER BY 1, 2, 4, 3""", (list(ESQUEMAS),)).fetchall()
    indices = con.execute("""
        SELECT schemaname, tablename, indexname, indexdef FROM pg_indexes
         WHERE schemaname = ANY(%s) AND indexdef ILIKE '%%gist%%' ORDER BY 1, 2""", (list(ESQUEMAS),)).fetchall()
    geoms = con.execute("""SELECT f_table_schema, f_table_name, f_geometry_column, type, srid FROM geometry_columns
                            WHERE f_table_schema = ANY(%s) ORDER BY 1, 2""", (list(ESQUEMAS),)).fetchall()

    por_tabla = {}
    for e, t, c, tipo, nulo, dflt, desc in cols:
        por_tabla.setdefault((e, t), []).append((c, tipo, "no" if nulo == "NO" else "sí", dflt, desc))
    tipos = {"p": "PK", "f": "FK", "u": "UNIQUE", "c": "CHECK", "x": "EXCLUDE"}
    rpt = {}
    for e, t, nombre, tipo, defin in restr:
        rpt.setdefault((e, t), []).append((tipos.get(tipo, tipo), nombre, defin))

    texto = f"""# Diccionario de datos y reglas de integridad

Generado el {date.today()} desde `information_schema` y `pg_constraint` (`Scripts/loader/documentar.py`). Todas las geometrías están en
SRID 9377 (MAGNA-SIRGAS Origen Nacional, proyectado, en metros) salvo que se indique otro. Cada esquema corresponde a un paquete del
modelo entidad-relación. Las fechas `fecha_observacion` y `fecha_carga` registran cuándo se observó y cuándo se cargó cada dato.

## Resumen de reglas de integridad
- **Claves primarias** estables en todas las tablas y **llaves foráneas** declaradas entre esquemas.
- **CHECK** de dominio (por ejemplo `ica` y `ipt` entre 0 y 100, pesos en (0, 1], umbrales positivos, estados válidos).
- **Geometrías:** columnas con tipo y SRID declarados (ver tabla de geometrías) y validación en `analisis.v_calidad`.
- **Índices espaciales GiST** sobre las columnas geométricas.
- **Datos personales:** no se almacena propietario ni documento; el CHIP es un identificador catastral del predio.

## Geometrías
{tabla(["Esquema", "Tabla", "Columna", "Tipo", "SRID"], geoms)}

## Índices espaciales (GiST)
{tabla(["Esquema", "Tabla", "Índice"], [(a, b, c) for a, b, c, _ in indices])}

"""
    actual = None
    for (e, t), lista in por_tabla.items():
        if e != actual:
            texto += f"\n## Esquema `{e}`\n"
            actual = e
        texto += f"\n### `{e}.{t}`\n\n" + tabla(["Columna", "Tipo", "Nulo", "Por defecto", "Descripción"], lista) + "\n"
        if (e, t) in rpt:
            texto += "\nRestricciones: " + "; ".join(f"**{k}** `{d}`" for k, _, d in rpt[(e, t)]) + "\n"
    return texto


def main(salida):
    salida.mkdir(parents=True, exist_ok=True)
    con = conectar()
    (salida / "catalogo_datos.md").write_text(catalogo(con), encoding="utf-8")
    (salida / "diccionario_datos.md").write_text(diccionario(con), encoding="utf-8")
    con.close()


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else "/app/docs"))
