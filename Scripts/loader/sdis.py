"""Comedores comunitarios de la SDIS (capa 16 del servicio Oferta_de_Servicios_Sociales)."""
import json

from .comun import consulta_arcgis, registrar_fuente

URL_COMEDORES = "https://geovisor.sdis.gov.co/server/rest/services/Oferta_de_Servicios_Sociales/MapServer/16"


def cargar_comedores(con):
    """Comedores de Puente Aranda (el filtro por LocCodigo falla en el servicio; se usa LocNombre)."""
    cur = con.cursor()
    cur.execute("""CREATE TABLE IF NOT EXISTS staging.comedor_comunitario (
                     objectid int PRIMARY KEY, unidad_operativa text, direccion text, horario_atencion text,
                     localidad text, geom geometry(Point, 9377), fecha_carga date DEFAULT current_date, atributos jsonb)""")
    cur.execute("TRUNCATE staging.comedor_comunitario")
    n = 0
    for a in consulta_arcgis(URL_COMEDORES, "LocNombre='PUENTE ARANDA'"):
        cur.execute(
            """INSERT INTO staging.comedor_comunitario (objectid, unidad_operativa, direccion, horario_atencion, localidad, geom, atributos)
               VALUES (%s,%s,%s,%s,%s, ST_Transform(ST_SetSRID(ST_MakePoint(%s,%s),4326),9377), %s)""",
            (a["OBJECTID"], a["OSSUOpera"], a["OSSDirecc"], a["OSSHAtenc"], a["LocNombre"], a["OSSCoorX"], a["OSSCoorY"], json.dumps(a)))
        n += 1
    registrar_fuente(cur, "SDIS - Comedores comunitarios", "Secretaria Distrital de Integracion Social", URL_COMEDORES,
                     "No declarada en el servicio REST; dato publicado por SDIS (por confirmar)", "Localidad 16 (Puente Aranda); 142 comedores en la ciudad",
                     "Punto", "El servicio no declara fecha de actualizacion ni vigencia; atiende a poblacion en pobreza o vulnerabilidad por inseguridad "
                     "alimentaria, no es oferta abierta a todo publico")
    con.commit()
    print(f"comedores comunitarios: {n}", flush=True)
