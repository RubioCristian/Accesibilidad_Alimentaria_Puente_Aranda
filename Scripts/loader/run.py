"""Flujo completo: SQL 00-01, cargas, SQL 02-09 y exportacion de capas para el visor.

Uso:  python -m Scripts.loader.run [sql|cargas|modelo|exportar ...]   (sin argumentos: todo)
"""
import os
import sys
from pathlib import Path

from .catastro import cargar_estrato, cargar_obras, cargar_predio
from .comun import conectar
from .exportar import exportar
from .gtfs import cargar_gtfs
from .localidad import cargar_lotes, cargar_malla_vial, cargar_osm, fijar_cobertura

RAIZ = Path(__file__).resolve().parents[1]


def aplicar_sql(con, desde, hasta):
    for ruta in sorted(RAIZ.glob("[0-9][0-9]_*.sql")):
        n = int(ruta.name[:2])
        if desde <= n <= hasta:
            print(f"-- {ruta.name}", flush=True)
            con.execute(ruta.read_text(encoding="utf-8"))
            con.commit()


def main(fases):
    con = conectar()
    if "base" in fases:
        aplicar_sql(con, 0, 1)
    if "cargas" in fases:
        fijar_cobertura(con)
        cargar_lotes(con)
        cargar_malla_vial(con)
        cargar_osm(con)
        cargar_predio(con)
        cargar_estrato(con)
        cargar_obras(con)
        cargar_gtfs(con)
    if "modelo" in fases:
        aplicar_sql(con, 2, 99)
    if "analisis" in fases:
        version = os.environ.get("CODE_VERSION", "sin-version")
        for (esc,) in con.execute("SELECT id FROM analisis.escenario ORDER BY id").fetchall():
            ejec = con.execute("SELECT analisis.ejecutar(%s, %s)", (esc, version)).fetchone()[0]
            con.commit()
            print(f"escenario {esc}: ejecucion {ejec}", flush=True)
    if "exportar" in fases:
        exportar(con)
    con.close()


if __name__ == "__main__":
    todas = ["base", "cargas", "modelo", "analisis", "exportar"]
    main(sys.argv[1:] or todas)
