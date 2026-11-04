
CREATE TABLE IF NOT EXISTS movilidad.correcciones_topologicas (
    id BIGSERIAL PRIMARY KEY,
    nodo_1 BIGINT NOT NULL,
    nodo_2 BIGINT NOT NULL,
    distancia_m DOUBLE PRECISION,
    geom geometry(LineString, 9377),
    UNIQUE (nodo_1, nodo_2)
);



INSERT INTO movilidad.correcciones_topologicas (
    nodo_1,
    nodo_2,
    distancia_m,
    geom
)
SELECT
    p.nodo_1,
    p.nodo_2,
    ST_Distance(a.geom, b.geom),
    ST_MakeLine(a.geom, b.geom)
FROM (
    VALUES
        (946, 947),
        (1565, 1566),
        (1500, 1501),
        (1706, 1707),
        (2195, 2196),
        (2012, 2013),
        (2594, 2596)
) AS p(nodo_1, nodo_2)
JOIN movilidad.red_peatonal_nodos a
    ON a.id = p.nodo_1
JOIN movilidad.red_peatonal_nodos b
    ON b.id = p.nodo_2
ON CONFLICT (nodo_1, nodo_2) DO NOTHING;


SELECT
    nodo_1,
    nodo_2,
    ROUND(distancia_m::numeric, 5) AS distancia_m
FROM movilidad.correcciones_topologicas
ORDER BY distancia_m;


WITH ultimo_id AS (
    SELECT COALESCE(MAX(id), 0) AS max_id
    FROM movilidad.red_peatonal_aristas
),
nuevas_aristas AS (
    SELECT
        c.*,
        ROW_NUMBER() OVER (ORDER BY c.id) AS numero
    FROM movilidad.correcciones_topologicas c
    WHERE NOT EXISTS (
        SELECT 1
        FROM movilidad.red_peatonal_aristas a
        WHERE
            (a.source = c.nodo_1 AND a.target = c.nodo_2)
            OR
            (a.source = c.nodo_2 AND a.target = c.nodo_1)
    )
)
INSERT INTO movilidad.red_peatonal_aristas (
    id,
    geom,
    cost,
    reverse_cost,
    source,
    target
)
SELECT
    u.max_id + c.numero,
    c.geom,
    c.distancia_m,
    c.distancia_m,
    c.nodo_1,
    c.nodo_2
FROM nuevas_aristas c
CROSS JOIN ultimo_id u;



SELECT COUNT(*) AS total_aristas
FROM movilidad.red_peatonal_aristas;



WITH componentes AS (
    SELECT *
    FROM pgr_connectedComponents(
        'SELECT id, source, target, cost, reverse_cost
         FROM movilidad.red_peatonal_aristas'
    )
)
SELECT
    COUNT(DISTINCT component) AS componentes_totales,
    COUNT(*) AS nodos_evaluados
FROM componentes;





WITH componentes AS (
    SELECT component, node
    FROM pgr_connectedComponents(
        'SELECT id, source, target, cost, reverse_cost
         FROM movilidad.red_peatonal_aristas'
    )
),
resumen_nodos AS (
    SELECT
        component,
        COUNT(*) AS cantidad_nodos
    FROM componentes



WITH componentes AS (
    SELECT component, node
    FROM pgr_connectedComponents(
        'SELECT id, source, target, cost, reverse_cost
         FROM movilidad.red_peatonal_aristas'
    )
),
aristas_componentes AS (
    SELECT
        a.id,
        a.geom,
        c.component
    FROM movilidad.red_peatonal_aristas a
    JOIN componentes c
      ON a.source = c.node
)
SELECT
    c.component AS componente_red,
    COUNT(*) AS cantidad_lotes,
    ROUND(
        AVG(ST_Distance(l.punto_red, c.geom))::numeric,
        3
    ) AS distancia_promedio_m,
    ROUND(
        MAX(ST_Distance(l.punto_red, c.geom))::numeric,
        3
    ) AS distancia_maxima_m
FROM movilidad.accesos_lotes l
CROSS JOIN LATERAL (
    SELECT
        a.component,
        a.geom
    FROM aristas_componentes a
    ORDER BY a.geom <-> l.punto_red
    LIMIT 1
) c
GROUP BY c.component
ORDER BY cantidad_lotes DESC;

    GROUP BY component
),
resumen_aristas AS (
    SELECT
        c.component,
        COUNT(*) AS cantidad_aristas,
        ROUND(SUM(a.cost)::numeric / 1000, 3)
            AS longitud_km
    FROM movilidad.red_peatonal_aristas a
    JOIN componentes c
      ON a.source = c.node
    GROUP BY c.component
)
SELECT
    n.component AS id_componente,
    n.cantidad_nodos,
    a.cantidad_aristas,
    a.longitud_km
FROM resumen_nodos n
JOIN resumen_aristas a
  ON n.component = a.component
ORDER BY n.cantidad_nodos DESC;



DROP TABLE IF EXISTS movilidad.lotes_red_peatonal;

CREATE TABLE movilidad.lotes_red_peatonal AS
SELECT
    l.*,
    a.id AS arista_id,
    a.source,
    a.target,
    ST_LineLocatePoint(
        a.geom,
        ST_ClosestPoint(a.geom, l.punto_red)
    ) AS fraccion_arista,
    ST_Distance(l.punto_red, a.geom)
        AS distancia_ajuste_m
FROM movilidad.accesos_lotes l
CROSS JOIN LATERAL (
    SELECT
        id,
        source,
        target,
        geom
    FROM movilidad.red_peatonal_aristas
    ORDER BY geom <-> l.punto_red
    LIMIT 1
) a;




SELECT
    COUNT(*) AS lotes,
    COUNT(*) FILTER (
        WHERE arista_id IS NULL
    ) AS sin_arista,
    COUNT(*) FILTER (
        WHERE fraccion_arista < 0
           OR fraccion_arista > 1
    ) AS fracciones_invalidas,
    ROUND(MAX(distancia_ajuste_m)::numeric, 4)
        AS distancia_maxima_ajuste_m
FROM movilidad.lotes_red_peatonal;



SELECT
    column_name AS columna,
    data_type AS tipo_dato,
    udt_name AS tipo_postgresql
FROM information_schema.columns
WHERE table_schema = 'alimentos'
  AND table_name = 'v_oferta_alimentaria'
ORDER BY ordinal_position;


SELECT
    ST_GeometryType(geom) AS tipo_geometria,
    ST_SRID(geom) AS srid,
    COUNT(*) AS establecimientos
FROM alimentos.v_oferta_alimentaria
GROUP BY
    ST_GeometryType(geom),
    ST_SRID(geom);


DROP TABLE IF EXISTS movilidad.establecimientos_red_peatonal;

CREATE TABLE movilidad.establecimientos_red_peatonal AS
SELECT
    e.id AS establecimiento_id,
    e.nombre,
    e.categoria,
    e.fuente,
    e.geom AS punto_establecimiento,
    a.id AS arista_id,
    a.source,
    a.target,
    ST_ClosestPoint(a.geom, e.geom)::geometry(Point, 9377)
        AS punto_red,
    ST_LineLocatePoint(
        a.geom,
        ST_ClosestPoint(a.geom, e.geom)
    ) AS fraccion_arista,
    ST_Distance(e.geom, a.geom)
        AS distancia_conexion_m
FROM alimentos.v_oferta_alimentaria e
CROSS JOIN LATERAL (
    SELECT
        id,
        source,
        target,
        geom
    FROM movilidad.red_peatonal_aristas
    ORDER BY geom <-> e.geom
    LIMIT 1
) a;


SELECT
    COUNT(*) AS establecimientos,
    COUNT(*) FILTER (
        WHERE arista_id IS NULL
    ) AS sin_arista,
    ROUND(
        AVG(distancia_conexion_m)::numeric,
        2
    ) AS distancia_promedio_m,
    ROUND(
        MAX(distancia_conexion_m)::numeric,
        2
    ) AS distancia_maxima_m,
    COUNT(*) FILTER (
        WHERE distancia_conexion_m > 20
    ) AS establecimientos_mas_20m,
    COUNT(*) FILTER (
        WHERE distancia_conexion_m > 50
    ) AS establecimientos_mas_50m
FROM movilidad.establecimientos_red_peatonal;



DROP TABLE IF EXISTS movilidad.establecimientos_red_final;

CREATE TABLE movilidad.establecimientos_red_final AS
SELECT r.*
FROM movilidad.establecimientos_red_peatonal r
JOIN alimentos.v_oferta_alimentaria e
    ON e.id = r.establecimiento_id
WHERE e.dentro_poligono = TRUE;


SELECT
    COUNT(*) AS establecimientos_finales,
    ROUND(AVG(distancia_conexion_m)::numeric, 2)
        AS distancia_promedio_m,
    ROUND(MAX(distancia_conexion_m)::numeric, 2)
        AS distancia_maxima_m
FROM movilidad.establecimientos_red_final;


WITH componentes AS (
    SELECT component, node
    FROM pgr_connectedComponents(
        'SELECT id, source, target, cost, reverse_cost
         FROM movilidad.red_peatonal_aristas'
    )
)
SELECT
    c.component AS componente_red,
    COUNT(*) AS establecimientos,
    ROUND(
        AVG(e.distancia_conexion_m)::numeric,
        2
    ) AS distancia_promedio_m,
    ROUND(
        MAX(e.distancia_conexion_m)::numeric,
        2
    ) AS distancia_maxima_m
FROM movilidad.establecimientos_red_final e
JOIN componentes c
    ON c.node = e.source
GROUP BY c.component
ORDER BY establecimientos DESC;


SELECT
    column_name AS columna,
    data_type AS tipo_dato
FROM information_schema.columns
WHERE table_schema = 'movilidad'
  AND table_name = 'lotes_red_peatonal'
ORDER BY ordinal_position;


SELECT
    'Lotes' AS tipo,
    COUNT(*) AS cantidad,
    COUNT(*) FILTER (
        WHERE fraccion_arista = 0
           OR fraccion_arista = 1
    ) AS puntos_en_extremos,
    COUNT(DISTINCT arista_id) AS aristas_utilizadas
FROM movilidad.lotes_red_peatonal

UNION ALL

SELECT
    'Establecimientos',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE fraccion_arista = 0
           OR fraccion_arista = 1
    ),
    COUNT(DISTINCT arista_id)
FROM movilidad.establecimientos_red_final;



SELECT
    COUNT(*) AS cantidad_lotes,
    COUNT(DISTINCT objectid_lote) AS lotes_unicos,
    COUNT(*) FILTER (
        WHERE fraccion_arista = 0
           OR fraccion_arista = 1
    ) AS puntos_en_extremos,
    COUNT(DISTINCT arista_id) AS aristas_utilizadas,
    COUNT(*) FILTER (
        WHERE fraccion_arista IS NULL
    ) AS fracciones_nulas
FROM movilidad.lotes_red_peatonal;


DROP TABLE IF EXISTS movilidad.puntos_ruteo;

CREATE TABLE movilidad.puntos_ruteo AS
WITH puntos AS (
    SELECT
        'Lote'::TEXT AS tipo,
        objectid_lote::TEXT AS identificador,
        arista_id AS edge_id,
        source,
        target,
        fraccion_arista AS fraction
    FROM movilidad.lotes_red_peatonal

    UNION ALL

    SELECT
        'Establecimiento'::TEXT,
        establecimiento_id::TEXT,
        arista_id,
        source,
        target,
        fraccion_arista
    FROM movilidad.establecimientos_red_final
),
numerados AS (
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY tipo, identificador
        )::BIGINT AS pid,
        *
    FROM puntos
)
SELECT
    pid,
    tipo,
    identificador,
    edge_id,
    fraction,
    CASE
        WHEN fraction = 0 THEN source
        WHEN fraction = 1 THEN target
        ELSE NULL::BIGINT
    END AS vertice_id,
    CASE
        WHEN fraction = 0 THEN source
        WHEN fraction = 1 THEN target
        ELSE -pid
    END AS id_ruteo
FROM numerados;

ALTER TABLE movilidad.puntos_ruteo
ADD PRIMARY KEY (pid);


SELECT
    tipo,
    COUNT(*) AS cantidad,
    COUNT(*) FILTER (
        WHERE vertice_id IS NOT NULL
    ) AS puntos_en_nodos,
    COUNT(*) FILTER (
        WHERE vertice_id IS NULL
    ) AS puntos_interiores,
    COUNT(*) FILTER (
        WHERE id_ruteo IS NULL
    ) AS sin_id_ruteo
FROM movilidad.puntos_ruteo
GROUP BY tipo
ORDER BY tipo;


--PRUEBA 1--
WITH componentes AS (
    SELECT component, node
    FROM pgr_connectedComponents(
        'SELECT id, source, target, cost, reverse_cost
         FROM movilidad.red_peatonal_aristas'
    )
),
ejemplo AS (
    SELECT
        l.identificador AS lote,
        e.identificador AS establecimiento,
        l.id_ruteo AS origen,
        e.id_ruteo AS destino
    FROM movilidad.puntos_ruteo l
    JOIN movilidad.red_peatonal_aristas a
      ON a.id = l.edge_id
    JOIN componentes c
      ON c.node = a.source
     AND c.component = 1
    CROSS JOIN movilidad.puntos_ruteo e
    WHERE l.tipo = 'Lote'
      AND e.tipo = 'Establecimiento'
      AND l.id_ruteo <> e.id_ruteo
    ORDER BY l.pid, e.pid
    LIMIT 1
),
ruta AS (
    SELECT
        x.lote,
        x.establecimiento,
        r.path_seq,
        r.node,
        r.edge,
        r.cost,
        r.agg_cost
    FROM ejemplo x
    CROSS JOIN LATERAL pgr_withPoints(
        'SELECT id, source, target, cost, reverse_cost
         FROM movilidad.red_peatonal_aristas',
        'SELECT pid, edge_id, fraction
         FROM movilidad.puntos_ruteo
         WHERE vertice_id IS NULL',
        x.origen,
        x.destino,
        directed := false
    ) r
)
SELECT
    lote,
    establecimiento,
    COUNT(*) AS pasos_ruta,
    ROUND(MAX(agg_cost)::numeric, 2)
        AS distancia_red_m
FROM ruta
GROUP BY lote, establecimiento;

--PRUEBA 2--


WITH lote_prueba AS (
    SELECT
        p.identificador AS lote,
        p.id_ruteo AS origen,
        l.distancia_eje_m AS acceso_lote_m
    FROM movilidad.puntos_ruteo p
    JOIN movilidad.lotes_red_peatonal l
      ON l.objectid_lote::TEXT = p.identificador
    WHERE p.tipo = 'Lote'
      AND p.identificador = '22006230'
),
rutas AS (
    SELECT
        e.identificador AS establecimiento_id,
        MAX(r.agg_cost) AS distancia_red_m
    FROM lote_prueba l
    JOIN movilidad.puntos_ruteo e
      ON e.tipo = 'Establecimiento'
    CROSS JOIN LATERAL pgr_withPoints(
        'SELECT id, source, target, cost, reverse_cost
         FROM movilidad.red_peatonal_aristas',
        'SELECT pid, edge_id, fraction
         FROM movilidad.puntos_ruteo
         WHERE vertice_id IS NULL',
        l.origen,
        e.id_ruteo,
        directed := false
    ) r
    GROUP BY e.identificador
)
SELECT
    e.nombre,
    e.categoria,
    ROUND(r.distancia_red_m::numeric, 2)
        AS distancia_red_m,
    ROUND(
        (
            r.distancia_red_m
            + l.acceso_lote_m
            + e.distancia_conexion_m
        )::numeric, 2
    ) AS distancia_total_m
FROM rutas r
JOIN movilidad.establecimientos_red_final e
  ON e.establecimiento_id = r.establecimiento_id
CROSS JOIN lote_prueba l
ORDER BY distancia_total_m;

--PRUEBA VISUAL--

WITH parametros AS (
    SELECT
        l.id_ruteo AS origen,
        e.id_ruteo AS destino
    FROM movilidad.puntos_ruteo l
    CROSS JOIN movilidad.puntos_ruteo e
    JOIN movilidad.establecimientos_red_final f
      ON f.establecimiento_id = e.identificador
    WHERE l.tipo = 'Lote'
      AND l.identificador = '22006230'
      AND e.tipo = 'Establecimiento'
      AND f.nombre = 'La Gran Cosecha'
    LIMIT 1
),
ruta AS (
    SELECT
        r.path_seq,
        r.node,
        LEAD(r.node) OVER (
            ORDER BY r.path_seq
        ) AS nodo_siguiente,
        r.edge,
        r.agg_cost
    FROM parametros p
    CROSS JOIN LATERAL pgr_withPoints(
        'SELECT id, source, target, cost, reverse_cost
         FROM movilidad.red_peatonal_aristas',
        'SELECT pid, edge_id, fraction
         FROM movilidad.puntos_ruteo
         WHERE vertice_id IS NULL',
        p.origen,
        p.destino,
        directed := false
    ) r
),
tramos AS (
    SELECT
        r.path_seq,
        CASE
            WHEN r.node = a.source THEN 0.0
            WHEN r.node = a.target THEN 1.0
            ELSE p1.fraction
        END AS f_inicio,
        CASE
            WHEN r.nodo_siguiente = a.source THEN 0.0
            WHEN r.nodo_siguiente = a.target THEN 1.0
            ELSE p2.fraction
        END AS f_fin,
        a.geom
    FROM ruta r
    JOIN movilidad.red_peatonal_aristas a
      ON a.id = r.edge
    LEFT JOIN movilidad.puntos_ruteo p1
      ON p1.pid = -r.node
     AND p1.edge_id = a.id
    LEFT JOIN movilidad.puntos_ruteo p2
      ON p2.pid = -r.nodo_siguiente
     AND p2.edge_id = a.id
    WHERE r.edge >= 0
),
geometrias AS (
    SELECT
        ST_LineSubstring(
            geom,
            LEAST(f_inicio, f_fin),
            GREATEST(f_inicio, f_fin)
        ) AS geom
    FROM tramos
    WHERE f_inicio IS NOT NULL
      AND f_fin IS NOT NULL
      AND f_inicio <> f_fin
)
SELECT
    'Ruta a La Gran Cosecha' AS recorrido,
    ROUND(
        ST_Length(ST_Collect(geom))::numeric,
        2
    ) AS distancia_red_m,
    ST_Transform(
        ST_Collect(geom),
        4326
    ) AS geom
FROM geometrias;

--OTRA PRUEBA VISUAL--

WITH parametros AS (
    SELECT
        l.id_ruteo AS origen,
        e.id_ruteo AS destino
    FROM movilidad.puntos_ruteo l
    CROSS JOIN movilidad.puntos_ruteo e
    JOIN movilidad.establecimientos_red_final f
      ON f.establecimiento_id = e.identificador
    WHERE l.tipo = 'Lote'
      AND l.identificador = '22006230'
      AND e.tipo = 'Establecimiento'
      AND f.categoria = 'Plaza de mercado'
    LIMIT 1
),
ruta AS (
    SELECT
        r.path_seq,
        r.node,
        LEAD(r.node) OVER (
            ORDER BY r.path_seq
        ) AS nodo_siguiente,
        r.edge,
        r.agg_cost
    FROM parametros p
    CROSS JOIN LATERAL pgr_withPoints(
        'SELECT id, source, target, cost, reverse_cost
         FROM movilidad.red_peatonal_aristas',
        'SELECT pid, edge_id, fraction
         FROM movilidad.puntos_ruteo
         WHERE vertice_id IS NULL',
        p.origen,
        p.destino,
        directed := false
    ) r
),
tramos AS (
    SELECT
        r.path_seq,
        CASE
            WHEN r.node = a.source THEN 0.0
            WHEN r.node = a.target THEN 1.0
            ELSE p1.fraction
        END AS f_inicio,
        CASE
            WHEN r.nodo_siguiente = a.source THEN 0.0
            WHEN r.nodo_siguiente = a.target THEN 1.0
            ELSE p2.fraction
        END AS f_fin,
        a.geom
    FROM ruta r
    JOIN movilidad.red_peatonal_aristas a
      ON a.id = r.edge
    LEFT JOIN movilidad.puntos_ruteo p1
      ON p1.pid = -r.node
     AND p1.edge_id = a.id
    LEFT JOIN movilidad.puntos_ruteo p2
      ON p2.pid = -r.nodo_siguiente
     AND p2.edge_id = a.id
    WHERE r.edge >= 0
),
geometrias AS (
    SELECT
        ST_LineSubstring(
            geom,
            LEAST(f_inicio, f_fin),
            GREATEST(f_inicio, f_fin)
        ) AS geom
    FROM tramos
    WHERE f_inicio IS NOT NULL
      AND f_fin IS NOT NULL
      AND f_inicio <> f_fin
)
SELECT
    'Ruta hacia Plaza de Mercado Trinidad' AS recorrido,
    ROUND(
        ST_Length(ST_Collect(geom))::numeric, 2
    ) AS distancia_red_m,
    ST_Transform(
        ST_Collect(geom), 4326
    ) AS geom
FROM geometrias;

