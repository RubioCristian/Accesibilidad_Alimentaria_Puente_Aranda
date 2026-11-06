"""Cargas desde servicios ArcGIS de Catastro: predio con uso, estrato y obras."""
import json

from .comun import BASE_CATASTRO, consulta_arcgis, fecha_ms, registrar_fuente

URL_PREDIO = f"{BASE_CATASTRO}/catastro/lote/MapServer/3"
URL_ESTRATO = f"{BASE_CATASTRO}/ordenamientoterritorial/estratificacion/MapServer/1"
URL_OBRAS = f"{BASE_CATASTRO}/gestionpublica/obraspublicas/MapServer/0"
CAMPOS_PREDIO = ("OBJECTID,PRECHIP,BARMANPRE,PRENUPRE,PRECLASE,PRECDESTIN,PRECUSO,PREAUSO,PREATERRE,"
                 "PREACONST,PREUVIVIEN,PREUCALIF,PREDIRECC,PREVACTUAL")
CAJA_ZONA = ("SELECT st_xmin(e),st_ymin(e),st_xmax(e),st_ymax(e) FROM "
             "(SELECT st_envelope(st_transform(geom,4326)) e FROM staging.cobertura_cargada) s")


def cargar_predio(con):
    """Incremental y reanudable: solo pide los lotes que aun no tienen filas (para recargar todo, TRUNCATE staging.predio_catastro)."""
    cur = con.cursor()
    cur.execute("""SELECT l.codigo_lote FROM staging.lote_catastro l
                   WHERE NOT EXISTS (SELECT 1 FROM staging.predio_catastro p WHERE p.barmanpre = l.codigo_lote) ORDER BY 1""")
    codigos = [f[0] for f in cur.fetchall()]
    total = 0
    for i in range(0, len(codigos), 100):
        lista = ",".join(f"'{c}'" for c in codigos[i:i + 100])
        for a in consulta_arcgis(URL_PREDIO, f"BARMANPRE IN ({lista})", CAMPOS_PREDIO):
            cur.execute(
                """INSERT INTO staging.predio_catastro (objectid, chip, barmanpre, nupre, clase, destino, cod_uso,
                     area_uso, area_terreno, area_construida, uso_vivienda, unidad_calificada, direccion,
                     vigencia_actual, atributos) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                   ON CONFLICT (objectid) DO NOTHING""",
                (a["OBJECTID"], a["PRECHIP"], a["BARMANPRE"], a["PRENUPRE"], a["PRECLASE"], a["PRECDESTIN"],
                 a["PRECUSO"], a["PREAUSO"], a["PREATERRE"], a["PREACONST"], a["PREUVIVIEN"], a["PREUCALIF"],
                 a["PREDIRECC"], a["PREVACTUAL"], json.dumps(a)),
            )
            total += 1
        con.commit()
        if (i // 100) % 20 == 0:
            print(f"  predio: {min(i + 100, len(codigos))}/{len(codigos)} lotes ({total} filas)", flush=True)
    registrar_fuente(cur, "Catastro - Predio con uso por construccion", "UAECD Catastro Bogota", URL_PREDIO,
                     "Datos abiertos Bogota (sin propietario ni datos personales)",
                     "Lotes de la localidad", "Predial",
                     "Una fila por unidad calificada: el CHIP se repite. No distingue tiendas de alimentos del resto del comercio")
    con.commit()
    print(f"predio: {total} filas", flush=True)


def cargar_estrato(con):
    cur = con.cursor()
    cur.execute(CAJA_ZONA)
    caja = ",".join(str(v) for v in cur.fetchone())
    cur.execute("TRUNCATE staging.estrato_poligono")
    total = 0
    extra = {"geometry": caja, "geometryType": "esriGeometryEnvelope", "inSR": 4326,
             "spatialRel": "esriSpatialRelIntersects"}
    for f in consulta_arcgis(URL_ESTRATO, "1=1", "OBJECTID,CODIGO_MANZANA,ESTRATO,FECHA_CAPTURA", True, extra):
        p = f["properties"]
        cur.execute(
            """INSERT INTO staging.estrato_poligono VALUES (%s,%s,%s,%s,
               ST_Multi(ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON(%s),4326),9377)))""",
            (p["OBJECTID"], p["CODIGO_MANZANA"], p["ESTRATO"], fecha_ms(p["FECHA_CAPTURA"]), json.dumps(f["geometry"])),
        )
        total += 1
    registrar_fuente(cur, "Catastro - Estratificacion", "UAECD Catastro / Secretaria Distrital de Planeacion", URL_ESTRATO,
                     "Datos abiertos Bogota", "Caja de la localidad", "Manzana",
                     "El codigo de manzana de esta capa no coincide con MANCODIGO; se une por interseccion espacial. Estrato 0 = sin estrato")
    con.commit()
    print(f"estrato: {total} poligonos", flush=True)


def cargar_obras(con):
    cur = con.cursor()
    cur.execute("TRUNCATE staging.obra_publica")
    total = 0
    for f in consulta_arcgis(URL_OBRAS, "LOCALIDAD=16", "*", True):
        p = f["properties"]
        cur.execute(
            """INSERT INTO staging.obra_publica VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,
               ST_Multi(ST_Transform(ST_SetSRID(ST_GeomFromGeoJSON(%s),4326),9377)))""",
            (p["OBJECTID"], p["COD_OBRA"], p["OBRA"], p["ENTIDAD"], p["LOCALIDAD"], p["ESTADO"], p["TIPO_OBRA"],
             fecha_ms(p["FECHA_ACTUALIZACION"]), p["UPZ"], json.dumps(f["geometry"])),
        )
        total += 1
    registrar_fuente(cur, "Obras publicas", "Secretaria Distrital de Gobierno / Gestion publica", URL_OBRAS,
                     "Datos abiertos Bogota", "Localidad 16", "Punto",
                     "Geometria de punto: el area de afectacion es un supuesto (buffer). Estado 1 en ejecucion, 2 ejecutada, 3 proxima")
    con.commit()
    print(f"obras: {total}", flush=True)
