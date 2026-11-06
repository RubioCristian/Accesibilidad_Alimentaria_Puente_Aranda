"""Atlas de mapas tematicos (PNG) desde la base. Uso:  python -m Scripts.loader.atlas [carpeta_salida]"""
import json
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import PatchCollection, LineCollection
from matplotlib.patches import Polygon

from .comun import conectar

PIE = "Fuentes: Catastro Bogota, OpenStreetMap, TransMilenio S.A. (GTFS 2026-04-29). SRID 9377. Elaboracion propia."
LOTES = """SELECT ST_AsGeoJSON(l.geom, 1), avg(i.ica), avg(i.ipt), avg(i.n_cobertura), avg(i.n_categorias), avg(i.acc_m)
             FROM territorio.lote l JOIN territorio.predio p ON p.lote_id = l.id
             JOIN analisis.indicador_predio i ON i.predio_id = p.id AND i.ejecucion_id = %s
            WHERE l.tipo IS DISTINCT FROM 'via_espacio_publico' GROUP BY l.id, l.geom"""


def anillos(gj):
    g = json.loads(gj)
    polis = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
    return [Polygon(p[0], closed=True) for p in polis]


def ejecucion(con, nombre):
    r = con.execute("""SELECT u.ejecucion_id FROM analisis.v_ultima_ejecucion u JOIN analisis.escenario e ON e.id = u.escenario_id
                        WHERE e.nombre = %s""", (nombre,)).fetchone()
    return r[0] if r else None


def mapa_lotes(datos, col, titulo, etiqueta, archivo, cmap, tipo, vmin=None, vmax=None, loc=None, extra=None):
    fig, ax = plt.subplots(figsize=(9, 10), dpi=150)
    parches, vals = [], []
    for fila in datos:
        v = fila[col]
        for p in anillos(fila[0]):
            parches.append(p); vals.append(v if v is not None else float("nan"))
    pc = PatchCollection(parches, cmap=cmap, linewidth=0)
    import numpy as np
    arr = np.array(vals, dtype=float)
    pc.set_array(np.ma.masked_invalid(arr)); pc.set_clim(vmin, vmax)
    ax.add_collection(pc)
    if loc:
        for p in loc:
            ax.plot(*zip(*p), color="black", lw=0.8)
    if extra:
        extra(ax)
    ax.autoscale_view(); ax.set_aspect("equal"); ax.set_axis_off()
    cb = fig.colorbar(pc, ax=ax, shrink=0.6); cb.set_label(etiqueta)
    ax.set_title(titulo, fontsize=13, fontweight="bold")
    fig.text(0.5, 0.04, f"Tipo de dato: {tipo}. Sin dato en gris/blanco. {PIE}", ha="center", fontsize=6.5, wrap=True)
    fig.savefig(archivo, bbox_inches="tight"); plt.close(fig)


def main(salida):
    out = Path(salida); out.mkdir(parents=True, exist_ok=True)
    con = conectar()
    ej = ejecucion(con, "base")
    datos = con.execute(LOTES, (ej,)).fetchall()
    l = con.execute("SELECT ST_AsGeoJSON(geom, 1) FROM territorio.localidad").fetchall()
    loc = []
    for (gj,) in l:
        g = json.loads(gj)
        for p in (g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]):
            loc.append(p[0])
    mapa_lotes(datos, 1, "ICA por lote (escenario base)", "ICA (0-100, mayor = mejor acceso)", out / "01_ica_base.png", "RdYlGn", "calculado", 0, 100, loc)
    mapa_lotes(datos, 2, "IPT por lote (escenario base)", "IPT (0-100, mayor = mas prioridad). Solo lotes con vivienda", out / "02_ipt_base.png", "YlOrRd", "calculado", 0, 100, loc)
    mapa_lotes(datos, 3, "Establecimientos alcanzables a pie (<= umbral) por lote", "N.o de establecimientos", out / "03_cobertura_base.png", "viridis", "calculado", 0, None, loc)
    mapa_lotes(datos, 4, "Diversidad: categorias de oferta alcanzables por lote", "N.o de categorias", out / "04_diversidad_base.png", "viridis", "calculado", 0, None, loc)
    mapa_lotes(datos, 5, "Distancia por red al establecimiento mas cercano", "Metros", out / "05_distancia_base.png", "magma_r", "calculado", 0, 1500, loc)

    # Oferta y obras sobre manzanas.
    fig, ax = plt.subplots(figsize=(9, 10), dpi=150)
    for (gj,) in con.execute("SELECT ST_AsGeoJSON(geom, 1) FROM territorio.manzana"):
        for p in anillos(gj):
            p.set_facecolor("#eeeeee"); p.set_edgecolor("#bbbbbb"); p.set_linewidth(0.2); ax.add_patch(p)
    cols = {}
    for cat, x, y in con.execute("""SELECT c.nombre, ST_X(e.geom), ST_Y(e.geom) FROM alimentos.establecimiento e
                                     JOIN alimentos.categoria c ON c.id = e.categoria_id"""):
        cols.setdefault(cat, ([], []))[0].append(x); cols[cat][1].append(y)
    for cat, (xs, ys) in cols.items():
        ax.scatter(xs, ys, s=7, label=f"{cat} ({len(xs)})")
    for (gj,) in con.execute("SELECT ST_AsGeoJSON(geom, 1) FROM movilidad.obra WHERE estado = 'en ejecucion'"):
        for p in anillos(gj):
            p.set_facecolor("none"); p.set_edgecolor("red"); p.set_linewidth(1); ax.add_patch(p)
    ax.plot([], [], color="red", label="Obras en ejecucion (buffer 25 m, supuesto)")
    ax.autoscale_view(); ax.set_aspect("equal"); ax.set_axis_off(); ax.legend(loc="lower right", fontsize=7)
    ax.set_title("Oferta alimentaria y obras en ejecucion", fontsize=13, fontweight="bold")
    fig.text(0.5, 0.04, f"Tipo de dato: observado (OSM y plazas de mercado); area de obras inferida. {PIE}", ha="center", fontsize=6.5)
    fig.savefig(out / "06_oferta_obras.png", bbox_inches="tight"); plt.close(fig)

    # Diferencias frente a base (obras y sensibilidad).
    base = {r[0]: r[1] for r in con.execute(
        "SELECT predio_id, ica FROM analisis.indicador_predio WHERE ejecucion_id = %s", (ej,))}
    n = 7
    for (nombre,) in con.execute("""SELECT e.nombre FROM analisis.escenario e WHERE e.nombre <> 'base' ORDER BY e.id""").fetchall():
        eid = ejecucion(con, nombre)
        if not eid:
            continue
        filas = con.execute("""SELECT ST_AsGeoJSON(l.geom, 1), avg(i.ica) FROM territorio.lote l JOIN territorio.predio p ON p.lote_id = l.id
                               JOIN analisis.indicador_predio i ON i.predio_id = p.id AND i.ejecucion_id = %s
                              WHERE l.tipo IS DISTINCT FROM 'via_espacio_publico' GROUP BY l.id, l.geom""", (eid,)).fetchall()
        bl = {g: v for g, v in con.execute("""SELECT ST_AsGeoJSON(l.geom, 1), avg(i.ica) FROM territorio.lote l JOIN territorio.predio p ON p.lote_id = l.id
                               JOIN analisis.indicador_predio i ON i.predio_id = p.id AND i.ejecucion_id = %s
                              WHERE l.tipo IS DISTINCT FROM 'via_espacio_publico' GROUP BY l.id, l.geom""", (ej,))}
        dif = [(g, None, (v - bl[g]) if (g in bl and v is not None and bl[g] is not None) else None) for g, v in filas]
        mapa_lotes(dif, 2, f"Cambio del ICA: {nombre} menos base", "Puntos de ICA (rojo = peor, azul = mejor)",
                   out / f"{n:02d}_dif_ica_{nombre}.png", "RdBu", "calculado", -30, 30, loc)
        n += 1
    con.close()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "atlas")
