"""Compara cada escenario con 'base' y escribe docs/sensibilidad.md.

Medidas por escenario (sobre los predios con ICA en ambas ejecuciones):
  - correlacion de rangos (Spearman) del ICA y del IPT con 'base';
  - diferencia media absoluta del ICA (puntos);
  - % de predios que cambian de decil del ICA;
  - solape del 10 % de predios con mayor IPT (prioridad) respecto de 'base'.
Uso:  python -m Scripts.loader.sensibilidad [archivo_salida]
"""
import sys
from datetime import date
from pathlib import Path

from .comun import conectar

SQL = """
WITH ult AS (SELECT * FROM analisis.v_ultima_ejecucion),
b AS (SELECT i.predio_id, i.ica, i.ipt FROM analisis.indicador_predio i
        JOIN ult ON ult.ejecucion_id = i.ejecucion_id JOIN analisis.escenario e ON e.id = ult.escenario_id WHERE e.nombre = 'base'),
s AS (SELECT e.id, e.nombre, e.descripcion, i.predio_id, i.ica, i.ipt FROM analisis.indicador_predio i
        JOIN ult ON ult.ejecucion_id = i.ejecucion_id JOIN analisis.escenario e ON e.id = ult.escenario_id WHERE e.nombre <> 'base'),
j AS (SELECT s.id, s.nombre, s.descripcion, s.predio_id, b.ica ica_b, s.ica ica_s, b.ipt ipt_b, s.ipt ipt_s FROM s JOIN b USING (predio_id)),
r AS (SELECT *,
        rank() OVER (PARTITION BY id ORDER BY ica_b) ra_b, rank() OVER (PARTITION BY id ORDER BY ica_s) ra_s,
        ntile(10) OVER (PARTITION BY id ORDER BY ica_b) de_b, ntile(10) OVER (PARTITION BY id ORDER BY ica_s) de_s,
        CASE WHEN ipt_b IS NOT NULL AND ipt_s IS NOT NULL THEN rank() OVER (PARTITION BY id, (ipt_b IS NOT NULL AND ipt_s IS NOT NULL) ORDER BY ipt_b) END ri_b,
        CASE WHEN ipt_b IS NOT NULL AND ipt_s IS NOT NULL THEN rank() OVER (PARTITION BY id, (ipt_b IS NOT NULL AND ipt_s IS NOT NULL) ORDER BY ipt_s) END ri_s,
        CASE WHEN ipt_b IS NOT NULL AND ipt_s IS NOT NULL THEN ntile(10) OVER (PARTITION BY id, (ipt_b IS NOT NULL AND ipt_s IS NOT NULL) ORDER BY ipt_b) END ti_b,
        CASE WHEN ipt_b IS NOT NULL AND ipt_s IS NOT NULL THEN ntile(10) OVER (PARTITION BY id, (ipt_b IS NOT NULL AND ipt_s IS NOT NULL) ORDER BY ipt_s) END ti_s
      FROM j WHERE ica_b IS NOT NULL AND ica_s IS NOT NULL)
SELECT nombre, max(descripcion), count(*) n,
       round(corr(ra_b, ra_s)::numeric, 4) rho_ica,
       round(corr(ri_b, ri_s)::numeric, 4) rho_ipt,
       round(avg(abs(ica_b - ica_s)), 2) dif_media,
       round(100.0 * avg((de_b <> de_s)::int), 1) pct_cambia_decil,
       round(100.0 * count(*) FILTER (WHERE ti_b = 10 AND ti_s = 10) / nullif(count(*) FILTER (WHERE ti_b = 10), 0), 1) solape_top10_ipt
FROM r GROUP BY id, nombre ORDER BY id
"""


def main(salida):
    con = conectar()
    filas = con.execute(SQL).fetchall()
    pesos = con.execute("""SELECT e.nombre, string_agg(c.nombre || ' ' || ec.peso, ', ' ORDER BY c.id), e.umbral_cobertura_m, e.manzanas_vecindad, e.bloquea_obras
                             FROM analisis.escenario e JOIN analisis.escenario_criterio ec ON ec.escenario_id = e.id
                             JOIN analisis.criterio_analitico c ON c.id = ec.criterio_id GROUP BY e.id ORDER BY e.id""").fetchall()
    resumen = con.execute("""SELECT e.nombre, count(*), round(avg(i.ica), 2), round(avg(i.ipt), 2), x.version_codigo
                               FROM analisis.v_ultima_ejecucion u JOIN analisis.ejecucion_analisis x ON x.id = u.ejecucion_id
                               JOIN analisis.escenario e ON e.id = u.escenario_id JOIN analisis.indicador_predio i ON i.ejecucion_id = x.id
                              GROUP BY e.id, e.nombre, x.version_codigo ORDER BY e.id""").fetchall()
    con.close()
    t = [f"# Análisis de sensibilidad\n\nGenerado el {date.today()} (`Scripts/loader/sensibilidad.py`). Cada escenario cambia **un** supuesto de `base` "
         "para medir cuánto se mueve el resultado. ICA: mayor = mejor acceso. IPT: mayor = más prioridad.\n",
         "## Escenarios ejecutados\n", "| Escenario | Pesos | Umbral (m) | Vecindad (manzanas) | Bloquea obras |", "|---|---|---|---|---|"]
    t += [f"| {a} | {b} | {c} | {d} | {'sí' if e else 'no'} |" for a, b, c, d, e in pesos]
    t += ["\n## Resultados por escenario\n", "| Escenario | Predios | ICA medio | IPT medio | Versión del código |", "|---|---|---|---|---|"]
    t += [f"| {a} | {b} | {c} | {d} | {e} |" for a, b, c, d, e in resumen]
    t += ["\n## Comparación con `base`\n",
          "| Escenario | Predios comparados | ρ de Spearman ICA | ρ de Spearman IPT | Dif. media ICA (pts) | % que cambia de decil ICA | Solape del 10 % con mayor IPT (%) |",
          "|---|---|---|---|---|---|---|"]
    t += [f"| {f[0]} | {f[2]} | {f[3]} | {f[4]} | {f[5]} | {f[6]} | {f[7]} |" for f in filas]
    t += ["\n## Lectura\n", "_Ver la interpretación en el informe; los valores anteriores salen directamente de la base._\n"]
    Path(salida).write_text("\n".join(t) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/app/docs/sensibilidad.md")
