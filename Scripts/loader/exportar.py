"""Exporta las capas del modelo a GeoJSON (EPSG:4326) y un resumen de calidad para el visor SIG."""
import json
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path

DESTINO = Path(__file__).resolve().parents[2] / "SIG" / "data"
ZONA = "(SELECT geom FROM crudo.cobertura_cargada LIMIT 1)"
G = "ST_Transform({}, 4326)"

CAPAS = {
    "cobertura": f"""SELECT jsonb_build_object('nombre', 'Zona cargada'), {G.format('geom')} FROM crudo.cobertura_cargada""",
    "localidad": f"""SELECT jsonb_build_object('codigo', codigo, 'nombre', nombre),
                            {G.format('ST_SimplifyPreserveTopology(geom, 8)')} FROM territorio.localidad""",
    "manzanas": f"""SELECT jsonb_build_object('codigo', m.codigo, 'estrato', e.estrato),
                           {G.format('ST_SimplifyPreserveTopology(m.geom, 0.5)')}
                    FROM territorio.manzana m LEFT JOIN social.estrato e ON e.manzana_id = m.id
                    WHERE EXISTS (SELECT 1 FROM territorio.lote l WHERE l.manzana_id = m.id)""",
    "lotes": f"""
        WITH uso AS (
          SELECT DISTINCT ON (lote_id) lote_id, codigo_uso FROM (
            SELECT p.lote_id, u.codigo_uso, sum(coalesce(u.area_uso, 0)) a
            FROM territorio.predio p JOIN territorio.uso_construccion u ON u.predio_id = p.id
            GROUP BY 1, 2) s ORDER BY lote_id, a DESC),
        res AS (SELECT p.lote_id, count(*) n, min(p.direccion) dir, sum(d.peso_demanda) dem
                FROM territorio.predio p LEFT JOIN social.demanda_predio d ON d.predio_id = p.id GROUP BY 1)
        SELECT jsonb_build_object('codigo', l.codigo, 'manzana', m.codigo, 'predios', res.n, 'direccion', res.dir,
               'uso', uso.codigo_uso,
               'uso_clase', CASE WHEN uso.codigo_uso IN ('001','002','037','038') THEN 'vivienda'
                                 WHEN uso.codigo_uso IN ('003','004','039','040','056','060','066') THEN 'comercio'
                                 ELSE 'otro' END,
               'estrato', es.estrato, 'demanda', round(res.dem * 1000, 3),
               'ica_base', b.ica, 'ipt_base', b.ipt, 'ica_obras', o.ica, 'ipt_obras', o.ipt),
               {G.format('ST_SimplifyPreserveTopology(l.geom, 0.3)')}
        FROM territorio.lote l
        JOIN territorio.manzana m ON m.id = l.manzana_id AND l.tipo = 'predial'
        LEFT JOIN res ON res.lote_id = l.id
        LEFT JOIN uso ON uso.lote_id = l.id
        LEFT JOIN social.estrato es ON es.manzana_id = m.id
        LEFT JOIN analisis.v_indicador_lote b ON b.lote_id = l.id AND b.escenario = 'base'
        LEFT JOIN analisis.v_indicador_lote o ON o.lote_id = l.id AND o.escenario = 'con_obras'""",
    "establecimientos": f"""SELECT jsonb_build_object('nombre', e.nombre, 'categoria', c.nombre, 'fuente', f.nombre),
                                   {G.format('e.geom')}
                            FROM alimentos.establecimiento e JOIN alimentos.categoria c ON c.id = e.categoria_id
                            LEFT JOIN crudo.fuente_dato f ON f.id = e.fuente_id""",
    "red": f"""SELECT jsonb_build_object('tipo', CASE WHEN conexion_id IS NOT NULL THEN 'conexion' ELSE 'anden' END,
                                         'longitud', round(longitud, 1)),
                      {G.format('geom')}
               FROM movilidad.arista_red""",
    "vias": f"""SELECT jsonb_build_object('nombre', nombre, 'tipo', tipo), {G.format('geom')} FROM movilidad.via""",
    "estaciones_tm": f"""SELECT jsonb_build_object('nombre', nombre, 'codigo', codigo,
                           'rutas', (SELECT count(*) FROM movilidad.ruta_estacion_tm r WHERE r.estacion_id = e.id)),
                                {G.format('geom')} FROM movilidad.estacion_transmilenio e""",
    "paraderos_sitp": f"""SELECT jsonb_build_object('nombre', nombre, 'codigo', codigo,
                            'rutas', (SELECT count(*) FROM movilidad.ruta_estacion_sitp r WHERE r.estacion_id = e.id)),
                                 {G.format('geom')} FROM movilidad.estacion_sitp e""",
    "rutas_tm": f"""SELECT jsonb_build_object('codigo', split_part(codigo, '#', 1), 'nombre', nombre, 'sistema', 'TransMilenio'),
                           {G.format(f'ST_Intersection(geom, ST_Buffer({ZONA}, 1500))')}
                    FROM movilidad.ruta_transmilenio WHERE geom IS NOT NULL AND ST_Intersects(geom, ST_Buffer({ZONA}, 1500))""",
    "rutas_sitp": f"""SELECT jsonb_build_object('codigo', split_part(codigo, '#', 1), 'nombre', nombre, 'sistema', 'SITP'),
                            {G.format(f'ST_Intersection(geom, ST_Buffer({ZONA}, 1500))')}
                     FROM movilidad.ruta_sitp WHERE geom IS NOT NULL AND ST_Intersects(geom, ST_Buffer({ZONA}, 1500))""",
    "obras": f"""SELECT jsonb_build_object('codigo', codigo, 'nombre', nombre, 'estado', estado,
                                           'actualizacion', fecha_actualizacion), {G.format('geom')}
                 FROM movilidad.obra WHERE ST_DWithin(geom, {ZONA}, 600)""",
}


def _json(o):
    if isinstance(o, (date, datetime)):
        return o.isoformat()
    if isinstance(o, Decimal):
        return float(o)
    raise TypeError(type(o))


def exportar(con):
    DESTINO.mkdir(parents=True, exist_ok=True)
    cur = con.cursor()
    for nombre, interno in CAPAS.items():
        cur.execute(f"""SELECT jsonb_build_object('type', 'FeatureCollection', 'features', coalesce(jsonb_agg(
                          jsonb_build_object('type', 'Feature', 'properties', props, 'geometry', ST_AsGeoJSON(g, 6)::jsonb)
                          ), '[]'::jsonb)) FROM ({interno}) t(props, g)""")
        coleccion = cur.fetchone()[0]
        (DESTINO / f"{nombre}.geojson").write_text(json.dumps(coleccion, separators=(",", ":"), default=_json), encoding="utf-8")
        print(f"exportado {nombre}: {len(coleccion['features'])} elementos", flush=True)

    _exportar_predios(cur)

    resumen = {"generado": datetime.now().isoformat(timespec="seconds")}
    cur.execute("""SELECT t.table_schema || '.' || t.table_name,
                          (xpath('/row/c/text()', query_to_xml(format('SELECT count(*) AS c FROM %I.%I',
                             t.table_schema, t.table_name), false, true, '')))[1]::text::int
                   FROM information_schema.tables t
                   WHERE t.table_type = 'BASE TABLE'
                     AND t.table_schema IN ('territorio','social','alimentos','movilidad','analisis','interoperabilidad','crudo')
                     AND t.table_name NOT LIKE 'legado\\_%'
                   ORDER BY 1""")
    resumen["tablas"] = [{"tabla": a, "filas": b} for a, b in cur.fetchall()]
    cur.execute("SELECT prueba, falla FROM analisis.v_calidad ORDER BY 1")
    resumen["calidad"] = [{"prueba": a, "falla": b} for a, b in cur.fetchall()]
    cur.execute("""SELECT nombre, entidad, url, fecha_descarga, licencia, cobertura, escala, limitaciones
                   FROM crudo.fuente_dato ORDER BY id""")
    cols = [d.name for d in cur.description]
    resumen["fuentes"] = [dict(zip(cols, f)) for f in cur.fetchall()]
    cur.execute("""SELECT e.nombre, e.manzanas_vecindad, e.umbral_cobertura_m, e.velocidad_peaton_ms, e.bloquea_obras, e.descripcion,
                          jsonb_object_agg(c.nombre, ec.peso)
                   FROM analisis.escenario e JOIN analisis.escenario_criterio ec ON ec.escenario_id = e.id
                   JOIN analisis.criterio_analitico c ON c.id = ec.criterio_id GROUP BY e.id ORDER BY e.id""")
    resumen["escenarios"] = [dict(zip(["nombre", "manzanas_vecindad", "umbral_m", "velocidad_ms", "bloquea_obras",
                                        "descripcion", "pesos"], f)) for f in cur.fetchall()]
    cur.execute("""SELECT ea.version_codigo, ea.fecha, e.nombre FROM analisis.v_ultima_ejecucion u
                   JOIN analisis.ejecucion_analisis ea ON ea.id = u.ejecucion_id
                   JOIN analisis.escenario e ON e.id = u.escenario_id ORDER BY e.id""")
    resumen["ejecuciones"] = [{"version": a, "fecha": b, "escenario": c} for a, b, c in cur.fetchall()]
    (DESTINO / "resumen.json").write_text(json.dumps(resumen, ensure_ascii=False, default=_json), encoding="utf-8")
    print("exportado resumen.json", flush=True)


def _exportar_predios(cur):
    """predios.json: por predio, sus indicadores y los establecimientos alcanzables (matriz_od); por manzana, su vecindad.
    Permite que el visor responda "desde este predio" sin servidor de consultas."""
    cur.execute("""SELECT e.id, e.nombre, c.nombre, ST_X(ST_Transform(e.geom, 4326)), ST_Y(ST_Transform(e.geom, 4326))
                   FROM alimentos.establecimiento e JOIN alimentos.categoria c ON c.id = e.categoria_id ORDER BY e.id""")
    ests = cur.fetchall()
    indice = {f[0]: i for i, f in enumerate(ests)}
    establecimientos = [{"nombre": n, "categoria": c, "lon": round(x, 6), "lat": round(y, 6)} for _, n, c, x, y in ests]

    cur.execute("""SELECT m.codigo, array_agg(v.codigo ORDER BY v.codigo)
                   FROM analisis.vecindad_manzana vm JOIN analisis.escenario es ON es.id = vm.escenario_id AND es.nombre = 'base'
                   JOIN territorio.manzana m ON m.id = vm.manzana_id JOIN territorio.manzana v ON v.id = vm.vecina_id
                   GROUP BY m.codigo""")
    vecindad = {m: v for m, v in cur.fetchall()}

    predios = {}
    cur.execute("""SELECT p.id, p.chip, p.direccion, l.codigo, m.codigo, es.nombre, i.ica, i.ipt, i.acc_m, i.n_cobertura,
                          i.n_categorias, i.estrato, i.nota_incertidumbre, d.peso_demanda, pa.distancia_acceso
                   FROM analisis.indicador_predio i
                   JOIN analisis.v_ultima_ejecucion ex ON ex.ejecucion_id = i.ejecucion_id
                   JOIN analisis.escenario es ON es.id = ex.escenario_id
                   JOIN territorio.predio p ON p.id = i.predio_id
                   JOIN territorio.lote l ON l.id = p.lote_id
                   JOIN territorio.manzana m ON m.id = l.manzana_id
                   LEFT JOIN social.demanda_predio d ON d.predio_id = p.id
                   LEFT JOIN movilidad.punto_acceso pa ON pa.predio_id = p.id
                   ORDER BY p.chip, es.id""")
    for (pid, chip, dire, lote, mz, esc, ica, ipt, acc, ncob, ncat, estr, nota, dem, dacc) in cur.fetchall():
        r = predios.setdefault(pid, {"chip": chip, "dir": dire, "lote": lote, "mz": mz, "estrato": estr,
                                     "dem": None if dem is None else round(float(dem) * 1000, 3),
                                     "acceso_m": None if dacc is None else round(float(dacc), 1)})
        k = "obras" if esc == "con_obras" else "base"
        r[k] = {"ica": ica, "ipt": ipt, "acc": acc, "cob": ncob, "cat": ncat, "nota": nota}
    cur.execute("""SELECT od.predio_id, es.nombre, od.establecimiento_id, round(od.distancia_red, 0)
                   FROM analisis.matriz_od od JOIN analisis.v_ultima_ejecucion ex ON ex.ejecucion_id = od.ejecucion_id
                   JOIN analisis.escenario es ON es.id = ex.escenario_id
                   ORDER BY od.predio_id, od.distancia_red""")
    for pid, esc, eid, dist in cur.fetchall():
        if pid in predios:
            predios[pid].setdefault("od_obras" if esc == "con_obras" else "od_base", []).append([indice[eid], int(dist)])
    lista = list(predios.values())
    for r in lista:
        if r.get("od_obras") == r.get("od_base"):
            r.pop("od_obras", None)       # el visor usa od_base cuando no hay diferencia entre escenarios
    salida = {"establecimientos": establecimientos, "vecindad": vecindad, "predios": lista}
    (DESTINO / "predios.json").write_text(json.dumps(salida, ensure_ascii=False, separators=(",", ":"), default=_json),
                                          encoding="utf-8")
    print(f"exportado predios.json: {len(lista)} predios", flush=True)
