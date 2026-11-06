"""Cargas de la localidad completa: cobertura, lotes, malla vial (Catastro / IDECA) y establecimientos (OpenStreetMap)."""
import json
import time
import xml.etree.ElementTree as ET

import requests

from .comun import BASE_CATASTRO, consulta_arcgis, registrar_fuente

URL_LOTE = f"{BASE_CATASTRO}/catastro/lote/MapServer/0"
URL_MALLA = f"{BASE_CATASTRO}/Mapa_Referencia/Mapa_Referencia/MapServer/13"
URL_OSM = "https://api.openstreetmap.org/api/0.6/map"
CAJA_LOCALIDAD = ("SELECT st_xmin(e),st_ymin(e),st_xmax(e),st_ymax(e) FROM "
                  "(SELECT st_envelope(st_transform(st_buffer(geom, 300), 4326)) e FROM staging.legado_localidad) s")

# Etiqueta OSM -> categoria del modelo.
CATEGORIA_OSM = {
    "shop=supermarket": "Supermercado", "shop=convenience": "Tienda de conveniencia", "shop=grocery": "Tienda de conveniencia",
    "shop=deli": "Tienda de conveniencia", "shop=bakery": "Panaderia", "shop=greengrocer": "Fruteria y verduleria",
    "shop=butcher": "Carniceria", "amenity=marketplace": "Plaza de mercado",
}


def fijar_cobertura(con):
    """La cobertura cargada es la localidad completa (la usan estrato, GTFS y la exportacion)."""
    cur = con.cursor()
    cur.execute("DELETE FROM staging.cobertura_cargada")
    cur.execute("""INSERT INTO staging.cobertura_cargada (nombre, descripcion, geom)
                   SELECT 'Localidad 16 - Puente Aranda', 'Localidad completa',
                          (SELECT d.geom FROM ST_Dump(ST_MakeValid(l.geom)) d ORDER BY ST_Area(d.geom) DESC LIMIT 1)
                   FROM staging.legado_localidad l""")
    con.commit()


def cargar_lotes(con):
    cur = con.cursor()
    cur.execute("SELECT mancodigo FROM staging.legado_manzana WHERE mancodigo IS NOT NULL ORDER BY 1")
    manzanas = [f[0] for f in cur.fetchall()]
    cur.execute("TRUNCATE staging.lote_catastro")
    total = 0
    for i in range(0, len(manzanas), 40):
        lista = ",".join(f"'{m}'" for m in manzanas[i:i + 40])
        for f in consulta_arcgis(URL_LOTE, f"MANZCODIGO IN ({lista})", "OBJECTID,LOTCODIGO,MANZCODIGO", True):
            p = f["properties"]
            cur.execute(
                """INSERT INTO staging.lote_catastro (objectid, codigo_lote, codigo_manzana, geom)
                   VALUES (%s,%s,%s, ST_Multi(ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON(%s),4326),9377)))
                   ON CONFLICT (objectid) DO NOTHING""",
                (p["OBJECTID"], p["LOTCODIGO"], p["MANZCODIGO"], json.dumps(f["geometry"])))
            total += 1
        con.commit()
        print(f"  lotes: manzanas {min(i + 40, len(manzanas))}/{len(manzanas)}  ({total} lotes)", flush=True)
    registrar_fuente(cur, "Catastro - Lote", "UAECD Catastro Bogota", URL_LOTE, "Datos abiertos Bogota",
                     "Localidad 16", "Lote", "Incluye lotes de via y espacio publico (sufijo 090-099), que el modelo separa de los predios")
    con.commit()
    print(f"lotes: {total}", flush=True)


def cargar_malla_vial(con):
    cur = con.cursor()
    cur.execute(CAJA_LOCALIDAD)
    caja = ",".join(str(v) for v in cur.fetchone())
    cur.execute("TRUNCATE staging.malla_vial_catastro")
    total = 0
    extra = {"geometry": caja, "geometryType": "esriGeometryEnvelope", "inSR": 4326, "spatialRel": "esriSpatialRelIntersects"}
    for f in consulta_arcgis(URL_MALLA, "1=1", "OBJECTID,MVICODIGO,MVINOMBRE,MVITCLA,MVITIPO", True, extra):
        p = f["properties"]
        cur.execute(
            """INSERT INTO staging.malla_vial_catastro (objectid, codigo_vial, nombre_via, clasificacion, tipo, geom)
               VALUES (%s,%s,%s,%s,%s, ST_Multi(ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON(%s),4326),9377)))
               ON CONFLICT (objectid) DO NOTHING""",
            (p["OBJECTID"], p["MVICODIGO"], p["MVINOMBRE"], p["MVITCLA"], p["MVITIPO"], json.dumps(f["geometry"])))
        total += 1
    registrar_fuente(cur, "Mapa de Referencia - Malla vial", "IDECA / Mapa de Referencia", URL_MALLA,
                     "Datos abiertos Bogota", "Localidad 16 y 300 m alrededor", "Eje de calzada",
                     "Son ejes de calzada: la red peatonal derivada camina por el eje, no por el anden, y no modela cruces peatonales")
    con.commit()
    print(f"malla vial: {total} tramos", flush=True)


def _teselas(x0, y0, x1, y1, n):
    for i in range(n):
        for j in range(n):
            yield (x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * j / n, x0 + (x1 - x0) * (i + 1) / n, y0 + (y1 - y0) * (j + 1) / n)


def cargar_osm(con):
    """Comercio de alimentos de OpenStreetMap. Usa la API de mapa 0.6 por teselas (Overpass no siempre responde)."""
    cur = con.cursor()
    cur.execute(CAJA_LOCALIDAD)
    x0, y0, x1, y1 = cur.fetchone()
    vistos = {}
    for k, (a, b, c, d) in enumerate(_teselas(x0, y0, x1, y1, 5), 1):
        for intento in range(5):
            r = requests.get(URL_OSM, params={"bbox": f"{a},{b},{c},{d}"}, headers={"User-Agent": "taller10-bde-udistrital/1.0"}, timeout=180)
            if r.status_code == 200:
                break
            time.sleep(10 * (intento + 1))
        else:
            raise RuntimeError(f"OSM tesela {k}: {r.status_code} {r.text[:120]}")
        raiz = ET.fromstring(r.content)
        coords = {n.get("id"): (float(n.get("lon")), float(n.get("lat"))) for n in raiz.iter("node")}
        for el in list(raiz.iter("node")) + list(raiz.iter("way")):
            tags = {t.get("k"): t.get("v") for t in el.findall("tag")}
            cat = next((CATEGORIA_OSM[f"{k2}={v}"] for k2, v in tags.items() if f"{k2}={v}" in CATEGORIA_OSM), None)
            if not cat:
                continue
            if el.tag == "node":
                lon, lat = float(el.get("lon")), float(el.get("lat"))
            else:
                pts = [coords[n.get("ref")] for n in el.findall("nd") if n.get("ref") in coords]
                if not pts:
                    continue
                lon, lat = sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)
            vistos[(el.tag, el.get("id"))] = (el.tag, int(el.get("id")), tags.get("name"), cat, json.dumps(tags), lon, lat)
        print(f"  osm: tesela {k}/25 ({len(vistos)} elementos)", flush=True)
        time.sleep(1)
    cur.execute("TRUNCATE staging.osm_elemento")
    for v in vistos.values():
        cur.execute("""INSERT INTO staging.osm_elemento (tipo_osm, id_osm, nombre, categoria, etiquetas, geom)
                       VALUES (%s,%s,%s,%s,%s, ST_Transform(ST_SetSRID(ST_MakePoint(%s,%s),4326),9377))""", v)
    registrar_fuente(cur, "OpenStreetMap - Alimentos", "OpenStreetMap contributors", URL_OSM, "ODbL 1.0",
                     "Localidad 16 (caja + 300 m); filtrado a la localidad al construir el modelo", "Punto",
                     "Subestima las tiendas de barrio. Etiquetas shop=supermarket|convenience|grocery|deli|bakery|greengrocer|butcher y "
                     "amenity=marketplace. Relaciones OSM no incluidas. Descarga por la API de mapa 0.6 (no Overpass)")
    con.commit()
    print(f"osm: {len(vistos)} establecimientos", flush=True)
