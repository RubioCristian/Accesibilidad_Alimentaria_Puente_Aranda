"""GTFS estatico de TransMilenio/SITP: paradas, rutas, trazados y relacion ruta-parada cerca de la zona."""
import csv
import io
import os
import zipfile
from collections import Counter, defaultdict

import requests

from .catastro import CAJA_ZONA
from .comun import CACHE, registrar_fuente

URL = "https://storage.googleapis.com/gtfs-estaticos/GTFS-2026-04-29.zip"
MARGEN_GRADOS = 0.008  # ~900 m alrededor de la zona cargada


def _zip():
    os.makedirs(CACHE, exist_ok=True)
    ruta = os.path.join(CACHE, "GTFS-2026-04-29.zip")
    if not os.path.exists(ruta):
        print("descargando GTFS ...", flush=True)
        with requests.get(URL, stream=True, timeout=300) as r:
            r.raise_for_status()
            with open(ruta, "wb") as f:
                for trozo in r.iter_content(1 << 20):
                    f.write(trozo)
    return zipfile.ZipFile(ruta)


def _filas(z, nombre):
    with z.open(nombre) as f:
        yield from csv.DictReader(io.TextIOWrapper(f, encoding="utf-8-sig"))


def cargar_gtfs(con):
    cur = con.cursor()
    cur.execute(CAJA_ZONA)
    x0, y0, x1, y1 = cur.fetchone()
    x0, y0, x1, y1 = x0 - MARGEN_GRADOS, y0 - MARGEN_GRADOS, x1 + MARGEN_GRADOS, y1 + MARGEN_GRADOS
    z = _zip()

    paradas = {s["stop_id"]: s for s in _filas(z, "stops.txt")}
    efectiva = {i: (s["parent_station"] or i) for i, s in paradas.items()}
    cercanas = {i for i, s in paradas.items()
                if x0 < float(s["stop_lon"]) < x1 and y0 < float(s["stop_lat"]) < y1}
    objetivo = {i for i in paradas if efectiva[i] in cercanas or i in cercanas}

    viaje_ruta, formas_ruta = {}, defaultdict(Counter)
    for t in _filas(z, "trips.txt"):
        viaje_ruta[t["trip_id"]] = t["route_id"]
        formas_ruta[t["route_id"]][t["shape_id"]] += 1

    print("leyendo stop_times ...", flush=True)
    pares = {}
    with z.open("stop_times.txt") as f:
        lector = csv.reader(io.TextIOWrapper(f, encoding="utf-8-sig"))
        cab = next(lector)
        i_viaje, i_parada, i_sec = cab.index("trip_id"), cab.index("stop_id"), cab.index("stop_sequence")
        for fila in lector:
            if fila[i_parada] in objetivo:
                ruta = viaje_ruta.get(fila[i_viaje])
                if ruta is None:
                    continue
                clave = (ruta, efectiva[fila[i_parada]])
                sec = int(fila[i_sec])
                if clave not in pares or sec < pares[clave]:
                    pares[clave] = sec

    rutas = {r["route_id"]: r for r in _filas(z, "routes.txt")}
    ids_ruta = {r for r, _ in pares}
    forma_de = {r: formas_ruta[r].most_common(1)[0][0] for r in ids_ruta if formas_ruta[r]}
    formas = set(forma_de.values())
    puntos = defaultdict(list)
    for p in _filas(z, "shapes.txt"):
        if p["shape_id"] in formas:
            puntos[p["shape_id"]].append((int(p["shape_pt_sequence"]), p["shape_pt_lon"], p["shape_pt_lat"]))

    for t in ("crudo.gtfs_ruta_parada", "crudo.gtfs_ruta", "crudo.gtfs_parada"):
        cur.execute(f"TRUNCATE {t}")
    usadas = {p for _, p in pares}
    for i in usadas:
        s = paradas[i]
        cur.execute(
            """INSERT INTO crudo.gtfs_parada VALUES (%s,%s,%s,%s,
               ST_Transform(ST_SetSRID(ST_MakePoint(%s,%s),4326),9377))""",
            (i, s["stop_code"] or None, s["stop_name"], s["zone_id"] or None, s["stop_lon"], s["stop_lat"]),
        )
    for r in ids_ruta:
        info = rutas[r]
        pts = sorted(puntos.get(forma_de.get(r), []))
        wkt = "LINESTRING(" + ",".join(f"{x} {y}" for _, x, y in pts) + ")" if len(pts) > 1 else None
        cur.execute(
            """INSERT INTO crudo.gtfs_ruta VALUES (%s,%s,%s,%s,%s,%s,
               ST_Transform(ST_SetSRID(ST_GeomFromText(%s),4326),9377))""",
            (r, info["route_short_name"], info["route_long_name"], int(info["route_type"]),
             info["agency_id"], forma_de.get(r), wkt),
        )
    for (r, p), sec in pares.items():
        cur.execute("INSERT INTO crudo.gtfs_ruta_parada VALUES (%s,%s,%s)", (r, p, sec))

    registrar_fuente(cur, "GTFS TransMilenio/SITP 2026-04-29", "TransMilenio S.A.", URL,
                     "Datos abiertos (verificar terminos de uso del publicador)",
                     "Paradas dentro de la localidad + ~900 m", "Parada",
                     "Se guardan solo paradas y rutas cercanas; orden = menor stop_sequence observado; "
                     "estacion troncal = parada con location_type 1; el ZIP no se versiona")
    con.commit()
    print(f"gtfs: {len(usadas)} paradas, {len(ids_ruta)} rutas, {len(pares)} pares ruta-parada", flush=True)
