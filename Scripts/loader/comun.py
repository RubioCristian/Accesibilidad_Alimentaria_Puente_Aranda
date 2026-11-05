"""Utilidades compartidas: conexion, consultas ArcGIS REST y registro de fuentes."""
import os
import time
from datetime import date, datetime, timezone

import psycopg
import requests

BASE_CATASTRO = "https://serviciosgis.catastrobogota.gov.co/arcgis/rest/services"
CACHE = os.environ.get("CACHE_DIR", "/cache")


def conectar():
    return psycopg.connect(
        host=os.environ.get("PGHOST", "localhost"),
        port=os.environ.get("PGPORT", "5433"),
        user=os.environ.get("PGUSER", "postgres"),
        password=os.environ.get("PGPASSWORD", "postgres"),
        dbname=os.environ.get("PGDATABASE", "alimentos_puente_aranda"),
    )


def consulta_arcgis(url, where="1=1", campos="*", geometria=False, extra=None, pagina=1000):
    """Itera por todas las paginas de una capa. Devuelve features GeoJSON o, sin geometria, los atributos."""
    desplazamiento = 0
    while True:
        datos = {
            "where": where, "outFields": campos, "returnGeometry": "true" if geometria else "false",
            "f": "geojson" if geometria else "json", "outSR": 4326,
            "resultOffset": desplazamiento, "resultRecordCount": pagina,
        }
        datos.update(extra or {})
        for intento in range(4):
            r = requests.post(url + "/query", data=datos, timeout=120)
            if r.status_code == 200 and '"error"' not in r.text[:200]:
                break
            time.sleep(2 * (intento + 1))
        else:
            raise RuntimeError(f"Fallo consultando {url}: {r.status_code} {r.text[:200]}")
        js = r.json()
        feats = js.get("features", [])
        for f in feats:
            yield f if geometria else f["attributes"]
        if not feats or (len(feats) < pagina and not js.get("exceededTransferLimit")):
            return
        desplazamiento += len(feats)


def fecha_ms(valor):
    if valor in (None, ""):
        return None
    return datetime.fromtimestamp(valor / 1000, tz=timezone.utc).date()


def registrar_fuente(cur, nombre, entidad, url, licencia, cobertura, escala, limitaciones):
    cur.execute(
        """INSERT INTO crudo.fuente_dato (nombre, entidad, url, fecha_descarga, licencia, cobertura, escala, limitaciones)
           VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
           ON CONFLICT (nombre) DO UPDATE SET entidad=EXCLUDED.entidad, url=EXCLUDED.url,
             fecha_descarga=EXCLUDED.fecha_descarga, licencia=EXCLUDED.licencia,
             cobertura=EXCLUDED.cobertura, escala=EXCLUDED.escala, limitaciones=EXCLUDED.limitaciones""",
        (nombre, entidad, url, date.today(), licencia, cobertura, escala, limitaciones),
    )
