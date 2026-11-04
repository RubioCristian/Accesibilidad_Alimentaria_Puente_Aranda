
SELECT
    COUNT(*) AS pares_de_vias_cruzadas,
    COUNT(*) FILTER (
        WHERE a.clasificacion = 1
           OR b.clasificacion = 1
    ) AS cruces_con_vias_arteriales
FROM movilidad.malla_vial a
JOIN movilidad.malla_vial b
    ON a.objectid < b.objectid
   AND a.geom && b.geom
   AND ST_Crosses(a.geom, b.geom);


SELECT
    a.objectid AS tramo_1,
    a.nombre_via AS via_1,
    a.clasificacion AS clase_1,
    b.objectid AS tramo_2,
    b.nombre_via AS via_2,
    b.clasificacion AS clase_2,
    ST_AsText(
        ST_Transform(
            ST_PointOnSurface(
                ST_Intersection(a.geom, b.geom)
            ),
            4326
        )
    ) AS ubicacion
FROM movilidad.malla_vial a
JOIN movilidad.malla_vial b
    ON a.objectid < b.objectid
   AND ST_Crosses(a.geom, b.geom)
ORDER BY a.clasificacion, b.clasificacion;


CREATE TABLE IF NOT EXISTS movilidad.red_tramos_base (
    id BIGSERIAL PRIMARY KEY,
    objectid_origen BIGINT NOT NULL,
    componente INTEGER NOT NULL,
    nombre_via TEXT,
    clasificacion INTEGER,
    longitud_m DOUBLE PRECISION,
    geom geometry(LineString, 9377),
    UNIQUE (objectid_origen, componente)
);

INSERT INTO movilidad.red_tramos_base (
    objectid_origen,
    componente,
    nombre_via,
    clasificacion,
    longitud_m,
    geom
)
SELECT
    m.objectid,
    d.path[1],
    m.nombre_via,
    m.clasificacion,
    ST_Length(d.geom),
    d.geom
FROM movilidad.malla_vial m
CROSS JOIN LATERAL ST_Dump(m.geom) AS d
ON CONFLICT (objectid_origen, componente)
DO UPDATE SET
    nombre_via = EXCLUDED.nombre_via,
    clasificacion = EXCLUDED.clasificacion,
    longitud_m = EXCLUDED.longitud_m,
    geom = EXCLUDED.geom;

CREATE INDEX IF NOT EXISTS idx_red_tramos_geom
ON movilidad.red_tramos_base
USING GIST (geom);


SELECT
    COUNT(*) AS componentes_lineales,
    COUNT(DISTINCT objectid_origen) AS tramos_originales,
    COUNT(*) FILTER (
        WHERE NOT ST_IsValid(geom)
    ) AS invalidos,
    ROUND(
        (SUM(longitud_m) / 1000)::numeric,
        2
    ) AS longitud_total_km
FROM movilidad.red_tramos_base;



CREATE TABLE movilidad.red_nodos AS
WITH extremos AS (
    SELECT ST_AsEWKB(ST_StartPoint(geom)) AS coordenada
    FROM movilidad.red_tramos_base

    UNION

    SELECT ST_AsEWKB(ST_EndPoint(geom))
    FROM movilidad.red_tramos_base
)
SELECT
    ROW_NUMBER() OVER (ORDER BY coordenada)::bigint AS id,
    ST_GeomFromEWKB(coordenada)::geometry(Point, 9377) AS geom
FROM extremos;

ALTER TABLE movilidad.red_nodos
ADD PRIMARY KEY (id);

CREATE INDEX idx_red_nodos_geom
ON movilidad.red_nodos USING GIST (geom);


CREATE TABLE movilidad.red_aristas AS
SELECT
    t.id,
    t.objectid_origen,
    t.nombre_via,
    t.clasificacion,
    ni.id AS source,
    nf.id AS target,
    t.longitud_m AS costo_m,
    t.geom
FROM movilidad.red_tramos_base t
LEFT JOIN movilidad.red_nodos ni
    ON ST_AsEWKB(ST_StartPoint(t.geom))
     = ST_AsEWKB(ni.geom)
LEFT JOIN movilidad.red_nodos nf
    ON ST_AsEWKB(ST_EndPoint(t.geom))
     = ST_AsEWKB(nf.geom);

ALTER TABLE movilidad.red_aristas
ADD PRIMARY KEY (id);

CREATE INDEX idx_red_aristas_source
ON movilidad.red_aristas (source);

CREATE INDEX idx_red_aristas_target
ON movilidad.red_aristas (target);



SELECT
    (SELECT COUNT(*)
     FROM movilidad.red_nodos) AS nodos,

    COUNT(*) AS aristas,

    COUNT(*) FILTER (
        WHERE source IS NULL OR target IS NULL
    ) AS conexiones_incompletas,

    COUNT(*) FILTER (
        WHERE source = target
    ) AS conexiones_cerradas,

    ROUND(
        (SUM(costo_m)/1000)::numeric,
        2
    ) AS longitud_km
FROM movilidad.red_aristas;


SELECT
    id,
    objectid_origen,
    nombre_via,
    clasificacion,
    source,
    target,
    ROUND(costo_m::numeric, 2) AS longitud_m
FROM movilidad.red_aristas
WHERE source = target;


SELECT
    name,
    default_version,
    installed_version
FROM pg_available_extensions
WHERE name = 'pgrouting';


CREATE EXTENSION IF NOT EXISTS pgrouting;

SELECT extname, extversion
FROM pg_extension
WHERE extname = 'pgrouting';



WITH componentes AS (
    SELECT *
    FROM pgr_connectedComponents(
        $sql$
        SELECT
            id,
            source,
            target,
            costo_m AS cost,
            costo_m AS reverse_cost
        FROM movilidad.red_aristas
        WHERE source <> target
          AND costo_m > 0
        $sql$
    )
),
resumen AS (
    SELECT
        component,
        COUNT(*) AS cantidad_nodos
    FROM componentes
    GROUP BY component
)
SELECT
    COUNT(*) AS componentes_conectados,
    SUM(cantidad_nodos) AS nodos_evaluados,
    MAX(cantidad_nodos) AS nodos_componente_principal,
    MIN(cantidad_nodos) AS nodos_componente_menor
FROM resumen;


WITH componentes AS (
    SELECT node, component
    FROM pgr_connectedComponents(
        $sql$
        SELECT
            id,
            source,
            target,
            costo_m AS cost,
            costo_m AS reverse_cost
        FROM movilidad.red_aristas
        WHERE source <> target
          AND costo_m > 0
        $sql$
    )
),
aristas_componentes AS (
    SELECT
        c.component,
        SUM(a.costo_m) AS longitud_m,
        COUNT(*) AS aristas
    FROM movilidad.red_aristas a
    JOIN componentes c ON a.source = c.node
    JOIN componentes t ON a.target = t.node
                       AND c.component = t.component
    WHERE a.source <> a.target
    GROUP BY c.component
)
SELECT
    c.component,
    COUNT(*) AS nodos,
    COALESCE(MAX(ac.aristas), 0) AS aristas,
    ROUND(
        COALESCE(MAX(ac.longitud_m), 0)::numeric / 1000,
        2
    ) AS longitud_km
FROM componentes c
LEFT JOIN aristas_componentes ac
    ON c.component = ac.component
GROUP BY c.component
ORDER BY nodos DESC;


WITH componentes AS (
    SELECT node, component
    FROM pgr_connectedComponents(
        $sql$
        SELECT id, source, target,
               costo_m AS cost,
               costo_m AS reverse_cost
        FROM movilidad.red_aristas
        WHERE source <> target
          AND costo_m > 0
        $sql$
    )
),
tramos_clasificados AS (
    SELECT
        a.id,
        c.component,
        a.geom
    FROM movilidad.red_aristas a
    JOIN componentes c
      ON a.source = c.node
    WHERE a.source <> a.target
),
resultado AS (
    SELECT
        t.component,
        COUNT(*) AS tramos_totales,
        COUNT(*) FILTER (
            WHERE ST_Intersects(t.geom, ae.geom)
        ) AS tramos_intersectados
    FROM tramos_clasificados t
    CROSS JOIN territorio.area_estudio ae
    GROUP BY t.component
)
SELECT *
FROM resultado
ORDER BY tramos_intersectados DESC,
         tramos_totales DESC;


WITH componentes AS (
    SELECT node, component
    FROM pgr_connectedComponents(
        $sql$
        SELECT id, source, target,
               costo_m AS cost,
               costo_m AS reverse_cost
        FROM movilidad.red_aristas
        WHERE source <> target
          AND costo_m > 0
        $sql$
    )
),
tramos AS (
    SELECT
        a.*,
        c.component
    FROM movilidad.red_aristas a
    JOIN componentes c
      ON a.source = c.node
    WHERE a.source <> a.target
)
SELECT
    i.id AS tramo_aislado,
    i.objectid_origen,
    i.nombre_via AS via_aislada,
    i.clasificacion,
    ROUND(i.costo_m::numeric, 2) AS longitud_m,
    p.id AS tramo_principal_cercano,
    p.nombre_via AS via_cercana,
    ROUND(
        ST_Distance(i.geom, p.geom)::numeric, 2
    ) AS separacion_m
FROM tramos i
CROSS JOIN LATERAL (
    SELECT id, nombre_via, geom
    FROM tramos
    WHERE component = 2
    ORDER BY ST_Distance(geom, i.geom)
    LIMIT 1
) p
WHERE i.component = 127;


SELECT
    ST_Intersects(a.geom, b.geom) AS se_intersectan,
    ST_Touches(a.geom, b.geom) AS se_tocan,
    ST_Crosses(a.geom, b.geom) AS se_cruzan,
    ST_Overlaps(a.geom, b.geom) AS se_superponen,
    ST_GeometryType(
        ST_Intersection(a.geom, b.geom)
    ) AS tipo_interseccion,
    ROUND(
        ST_Distance(a.geom, b.geom)::numeric, 6
    ) AS distancia_exacta_m,
    ROUND(
        LEAST(
            ST_Distance(ST_StartPoint(a.geom), b.geom),
            ST_Distance(ST_EndPoint(a.geom), b.geom)
        )::numeric, 3
    ) AS extremo_a_red_m
FROM movilidad.red_aristas a
JOIN movilidad.red_aristas b
    ON a.id = 101
   AND b.id = 397;


WITH tramos AS (
    SELECT
        a.geom AS geom_101,
        b.geom AS geom_397,
        ST_Intersection(a.geom, b.geom) AS punto
    FROM movilidad.red_aristas a
    JOIN movilidad.red_aristas b
        ON a.id = 101
       AND b.id = 397
)
SELECT
    ST_DWithin(
        punto,
        ST_StartPoint(geom_101),
        0.01
    ) AS inicio_101,

    ST_DWithin(
        punto,
        ST_EndPoint(geom_101),
        0.01
    ) AS fin_101,

    ST_DWithin(
        punto,
        ST_StartPoint(geom_397),
        0.01
    ) AS inicio_397,

    ST_DWithin(
        punto,
        ST_EndPoint(geom_397),
        0.01
    ) AS fin_397
FROM tramos;



SELECT
    ST_Y(
        ST_Transform(
            ST_Intersection(a.geom, b.geom),
            4326
        )
    ) AS latitud,
    ST_X(
        ST_Transform(
            ST_Intersection(a.geom, b.geom),
            4326
        )
    ) AS longitud,
    a.nombre_via AS via_101,
    b.nombre_via AS via_397
FROM movilidad.red_aristas a
JOIN movilidad.red_aristas b
    ON a.id = 101
   AND b.id = 397;

SELECT
    id,
    objectid_origen,
    nombre_via,
    clasificacion,
    ROUND(costo_m::numeric, 2) AS longitud_m
FROM movilidad.red_aristas
WHERE id IN (101, 397)
ORDER BY id;



WITH contacto AS (
    SELECT
        a.id AS tramo_101,
        b.id AS tramo_397,
        ST_Intersection(a.geom, b.geom) AS punto,
        b.geom AS linea
    FROM movilidad.red_aristas a
    JOIN movilidad.red_aristas b
        ON a.id = 101
       AND b.id = 397
)
SELECT
    tramo_101,
    tramo_397,
    ROUND(
        ST_LineLocatePoint(linea, punto)::numeric,
        6
    ) AS posicion_relativa,
    ROUND(
        ST_Length(
            ST_LineSubstring(
                linea,
                0,
                ST_LineLocatePoint(linea, punto)
            )
        )::numeric,
        2
    ) AS longitud_primera_parte_m,
    ROUND(
        ST_Length(
            ST_LineSubstring(
                linea,
                ST_LineLocatePoint(linea, punto),
                1
            )
        )::numeric,
        2
    ) AS longitud_segunda_parte_m
FROM contacto;


WITH puntos AS (
    SELECT
        'Manzana'::text AS tipo,
        objectid::text AS identificador,
        ST_PointOnSurface(geom) AS geom
    FROM territorio.v_manzanas_estudio

    UNION ALL

    SELECT
        'Establecimiento'::text AS tipo,
        id AS identificador,
        geom
    FROM alimentos.v_oferta_alimentaria
),
distancias AS (
    SELECT
        p.tipo,
        p.identificador,
        r.id AS arista_cercana,
        ST_Distance(p.geom, r.geom) AS distancia_m
    FROM puntos p
    CROSS JOIN LATERAL (
        SELECT id, geom
        FROM movilidad.red_aristas
        ORDER BY ST_Distance(p.geom, geom)
        LIMIT 1
    ) r
)
SELECT
    tipo,
    COUNT(*) AS total_puntos,
    ROUND(AVG(distancia_m)::numeric, 2)
        AS distancia_media_m,
    ROUND(MAX(distancia_m)::numeric, 2)
        AS distancia_maxima_m,
    COUNT(*) FILTER (
        WHERE distancia_m > 100
    ) AS puntos_mas_100m
FROM distancias
GROUP BY tipo
ORDER BY tipo;


WITH componentes AS (
    SELECT node, component
    FROM pgr_connectedComponents(
        $sql$
        SELECT
            id, source, target,
            costo_m AS cost,
            costo_m AS reverse_cost
        FROM movilidad.red_aristas
        WHERE source <> target
          AND costo_m > 0
        $sql$
    )
),
puntos AS (
    SELECT
        'Manzana'::text AS tipo,
        objectid::text AS identificador,
        ST_PointOnSurface(geom) AS geom
    FROM territorio.v_manzanas_estudio

    UNION ALL

    SELECT
        'Establecimiento'::text AS tipo,
        id AS identificador,
        geom
    FROM alimentos.v_oferta_alimentaria
),
asignacion AS (
    SELECT
        p.tipo,
        p.identificador,
        r.id AS arista_cercana,
        c.component,
        ST_Distance(p.geom, r.geom) AS distancia_m
    FROM puntos p
    CROSS JOIN LATERAL (
        SELECT id, source, geom
        FROM movilidad.red_aristas
        ORDER BY ST_Distance(p.geom, geom), id
        LIMIT 1
    ) r
    LEFT JOIN componentes c
        ON r.source = c.node
)
SELECT
    tipo,
    component AS componente,
    COUNT(*) AS puntos,
    ROUND(AVG(distancia_m)::numeric, 2)
        AS distancia_media_m,
    ROUND(MAX(distancia_m)::numeric, 2)
        AS distancia_maxima_m
FROM asignacion
GROUP BY tipo, component
ORDER BY tipo, puntos DESC;



CREATE OR REPLACE VIEW analisis.v_puntos_red AS
WITH puntos AS (
    SELECT
        'Manzana'::text AS tipo,
        objectid::text AS identificador,
        ST_PointOnSurface(geom) AS geom
    FROM territorio.v_manzanas_estudio

    UNION ALL

    SELECT
        'Establecimiento'::text AS tipo,
        id AS identificador,
        geom
    FROM alimentos.v_oferta_alimentaria
),
asignacion AS (
    SELECT
        p.tipo,
        p.identificador,
        p.geom AS punto_original,
        r.id AS edge_id,
        ST_LineLocatePoint(r.geom, p.geom)
            AS fraction,
        ST_ClosestPoint(r.geom, p.geom)
            AS punto_red,
        ST_Distance(p.geom, r.geom)
            AS distancia_conexion_m
    FROM puntos p
    CROSS JOIN LATERAL (
        SELECT id, geom
        FROM movilidad.red_aristas
        ORDER BY ST_Distance(geom, p.geom), id
        LIMIT 1
    ) r
)
SELECT
    ROW_NUMBER() OVER (
        ORDER BY tipo, identificador
    )::bigint AS pid,
    tipo,
    identificador,
    edge_id,
    fraction,
    'b'::char(1) AS side,
    distancia_conexion_m,
    punto_original,
    punto_red
FROM asignacion;


SELECT
    tipo,
    COUNT(*) AS puntos,
    COUNT(*) FILTER (
        WHERE fraction BETWEEN 0 AND 1
    ) AS fracciones_validas,
    COUNT(*) FILTER (
        WHERE fraction IN (0, 1)
    ) AS puntos_en_extremos,
    ROUND(
        AVG(distancia_conexion_m)::numeric, 2
    ) AS conexion_media_m,
    ROUND(
        MAX(distancia_conexion_m)::numeric, 2
    ) AS conexion_maxima_m
FROM analisis.v_puntos_red
GROUP BY tipo
ORDER BY tipo;



SELECT
    p.proname AS funcion,
    pg_get_function_arguments(p.oid) AS argumentos,
    pg_get_function_result(p.oid) AS resultado
FROM pg_proc p
WHERE LOWER(p.proname) = 'pgr_withpointscost'
ORDER BY argumentos;



WITH seleccion AS (
    SELECT
        MIN(pid) FILTER (
            WHERE tipo = 'Manzana'
        ) AS origen,
        MIN(pid) FILTER (
            WHERE tipo = 'Establecimiento'
        ) AS destino
    FROM analisis.v_puntos_red
)
SELECT
    s.origen AS pid_manzana,
    s.destino AS pid_establecimiento,
    ROUND(r.agg_cost::numeric, 2) AS distancia_red_m
FROM seleccion s
CROSS JOIN LATERAL pgr_withPointsCost(
    $edges$
        SELECT
            id, source, target,
            costo_m AS cost,
            costo_m AS reverse_cost
        FROM movilidad.red_aristas
        WHERE source <> target
          AND costo_m > 0
    $edges$,
    $points$
        SELECT pid, edge_id, fraction, side
        FROM analisis.v_puntos_red
    $points$,
    -s.origen,
    -s.destino,
    directed => false
) r;


SELECT
    m.identificador AS manzana,
    e.nombre_establecimiento,
    ROUND(
        ST_Distance(
            m.punto_original,
            e.punto_original
        )::numeric, 2
    ) AS distancia_euclidiana_m,
    ROUND(
        (m.distancia_conexion_m +
         e.distancia_conexion_m)::numeric, 2
    ) AS conexiones_m,
    1473.21 AS distancia_red_m
FROM (
    SELECT *
    FROM analisis.v_puntos_red
    WHERE pid = 71
) m
CROSS JOIN (
    SELECT
        p.*,
        a.nombre AS nombre_establecimiento
    FROM analisis.v_puntos_red p
    JOIN alimentos.v_oferta_alimentaria a
      ON p.identificador = a.id
    WHERE p.pid = 1
) e;


WITH destinos AS (
    SELECT
        ARRAY_AGG(-pid ORDER BY pid)::bigint[] AS ids
    FROM analisis.v_puntos_red
    WHERE tipo = 'Establecimiento'
),
rutas AS (
    SELECT r.*
    FROM destinos d
    CROSS JOIN LATERAL pgr_withPointsCost(
        $edges$
            SELECT
                id, source, target,
                costo_m AS cost,
                costo_m AS reverse_cost
            FROM movilidad.red_aristas
            WHERE source <> target
              AND costo_m > 0
        $edges$,
        $points$
            SELECT pid, edge_id, fraction, side
            FROM analisis.v_puntos_red
        $points$,
        -71::bigint,
        d.ids,
        directed => false
    ) r
)
SELECT
    e.identificador AS id_establecimiento,
    a.nombre,
    a.categoria,
    ROUND(r.agg_cost::numeric, 2)
        AS distancia_red_m,
    ROUND(
        (
            r.agg_cost
            + m.distancia_conexion_m
            + e.distancia_conexion_m
        )::numeric, 2
    ) AS distancia_total_estimada_m
FROM rutas r
JOIN analisis.v_puntos_red m
    ON m.pid = 71
JOIN analisis.v_puntos_red e
    ON e.pid = -r.end_vid
JOIN alimentos.v_oferta_alimentaria a
    ON a.id = e.identificador
ORDER BY distancia_total_estimada_m, a.id
LIMIT 5;


WITH puntos AS (
    SELECT
        ARRAY_AGG(-pid ORDER BY pid)
            FILTER (WHERE tipo = 'Manzana')::bigint[]
            AS origenes,
        ARRAY_AGG(-pid ORDER BY pid)
            FILTER (WHERE tipo = 'Establecimiento')::bigint[]
            AS destinos
    FROM analisis.v_puntos_red
),
rutas AS (
    SELECT r.*
    FROM puntos p
    CROSS JOIN LATERAL pgr_withPointsCost(
        $edges$
            SELECT
                id, source, target,
                costo_m AS cost,
                costo_m AS reverse_cost
            FROM movilidad.red_aristas
            WHERE source <> target
              AND costo_m > 0
        $edges$,
        $points$
            SELECT pid, edge_id, fraction, side
            FROM analisis.v_puntos_red
        $points$,
        p.origenes,
        p.destinos,
        directed => false
    ) r
),
distancias AS (
    SELECT
        m.identificador AS manzana,
        e.identificador AS id_establecimiento,
        a.nombre,
        a.categoria,
        r.agg_cost AS distancia_red_m,
        r.agg_cost
            + m.distancia_conexion_m
            + e.distancia_conexion_m
            AS distancia_total_m
    FROM rutas r
    JOIN analisis.v_puntos_red m
        ON m.pid = -r.start_vid
    JOIN analisis.v_puntos_red e
        ON e.pid = -r.end_vid
    JOIN alimentos.v_oferta_alimentaria a
        ON a.id = e.identificador
),
clasificacion AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY manzana
            ORDER BY distancia_total_m, id_establecimiento
        ) AS posicion
    FROM distancias
)
SELECT
    manzana,
    nombre AS establecimiento_cercano,
    categoria,
    ROUND(distancia_red_m::numeric, 2)
        AS distancia_red_m,
    ROUND(distancia_total_m::numeric, 2)
        AS distancia_total_estimada_m
FROM clasificacion
WHERE posicion = 1
ORDER BY manzana
LIMIT 10;


CREATE TABLE analisis.proximidad_red_resultados AS
WITH puntos AS (
    SELECT
        ARRAY_AGG(-pid ORDER BY pid)
            FILTER (WHERE tipo = 'Manzana')::bigint[]
            AS origenes,
        ARRAY_AGG(-pid ORDER BY pid)
            FILTER (WHERE tipo = 'Establecimiento')::bigint[]
            AS destinos
    FROM analisis.v_puntos_red
),
rutas AS (
    SELECT r.*
    FROM puntos p
    CROSS JOIN LATERAL pgr_withPointsCost(
        $edges$
            SELECT id, source, target,
                   costo_m AS cost,
                   costo_m AS reverse_cost
            FROM movilidad.red_aristas
            WHERE source <> target AND costo_m > 0
        $edges$,
        $points$
            SELECT pid, edge_id, fraction, side
            FROM analisis.v_puntos_red
        $points$,
        p.origenes,
        p.destinos,
        directed => false
    ) r
),
distancias AS (
    SELECT
        m.identificador AS manzana,
        e.identificador AS id_establecimiento,
        a.nombre AS establecimiento_cercano,
        a.categoria,
        r.agg_cost AS distancia_red_m,
        r.agg_cost
            + m.distancia_conexion_m
            + e.distancia_conexion_m
            AS distancia_total_m,
        ROW_NUMBER() OVER (
            PARTITION BY m.identificador
            ORDER BY
                r.agg_cost
                + m.distancia_conexion_m
                + e.distancia_conexion_m,
                e.identificador
        ) AS posicion
    FROM rutas r
    JOIN analisis.v_puntos_red m
        ON m.pid = -r.start_vid
    JOIN analisis.v_puntos_red e
        ON e.pid = -r.end_vid
    JOIN alimentos.v_oferta_alimentaria a
        ON a.id = e.identificador
)
SELECT
    manzana,
    id_establecimiento,
    establecimiento_cercano,
    categoria,
    ROUND(distancia_red_m::numeric, 2)
        AS distancia_red_m,
    ROUND(distancia_total_m::numeric, 2)
        AS distancia_total_m
FROM distancias
WHERE posicion = 1;



SELECT
    COUNT(*) AS manzanas_con_ruta,
    ROUND(AVG(distancia_total_m), 2)
        AS distancia_media_m,
    MIN(distancia_total_m)
        AS distancia_minima_m,
    MAX(distancia_total_m)
        AS distancia_maxima_m,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY distancia_total_m)::numeric,
        2
    ) AS distancia_mediana_m
FROM analisis.proximidad_red_resultados;


SELECT
    r.manzana,
    m.mancodigo,
    m.grupo_uso_econ,
    r.establecimiento_cercano,
    r.categoria,
    r.distancia_red_m,
    r.distancia_total_m
FROM analisis.proximidad_red_resultados r
JOIN territorio.v_manzanas_estudio m
    ON m.objectid::text = r.manzana
ORDER BY r.distancia_total_m DESC
LIMIT 10;


SELECT
    m.mancodigo,
    m.grupo_uso_econ,
    e.distancia_m AS distancia_euclidiana_m,
    r.distancia_total_m AS distancia_red_m,
    ROUND(
        r.distancia_total_m - e.distancia_m,
        2
    ) AS diferencia_m,
    ROUND(
        (r.distancia_total_m /
         NULLIF(e.distancia_m, 0))::numeric,
        2
    ) AS factor_recorrido
FROM analisis.proximidad_red_resultados r
JOIN territorio.v_manzanas_estudio m
    ON m.objectid::text = r.manzana
JOIN analisis.v_proximidad_alimentos e
    ON e.objectid = m.objectid
ORDER BY diferencia_m DESC
LIMIT 10;


CREATE TABLE analisis.abastecimiento_red_resultados AS
WITH puntos AS (
    SELECT
        ARRAY_AGG(-p.pid ORDER BY p.pid)
            FILTER (
                WHERE p.tipo = 'Manzana'
                  AND m.grupo_uso_econ = 'RESIDENCIAL'
            )::bigint[] AS origenes,

        ARRAY_AGG(-p.pid ORDER BY p.pid)
            FILTER (
                WHERE p.tipo = 'Establecimiento'
                  AND a.categoria IN (
                      'Supermercado',
                      'Tienda de conveniencia',
                      'Plaza de mercado'
                  )
            )::bigint[] AS destinos

    FROM analisis.v_puntos_red p

    LEFT JOIN territorio.v_manzanas_estudio m
        ON p.tipo = 'Manzana'
       AND p.identificador = m.objectid::text

    LEFT JOIN alimentos.v_oferta_alimentaria a
        ON p.tipo = 'Establecimiento'
       AND p.identificador = a.id
),
rutas AS (
    SELECT r.*
    FROM puntos p
    CROSS JOIN LATERAL pgr_withPointsCost(
        $edges$
            SELECT id, source, target,
                   costo_m AS cost,
                   costo_m AS reverse_cost
            FROM movilidad.red_aristas
            WHERE source <> target
              AND costo_m > 0
        $edges$,
        $points$
            SELECT pid, edge_id, fraction, side
            FROM analisis.v_puntos_red
        $points$,
        p.origenes,
        p.destinos,
        directed => false
    ) r
),
distancias AS (
    SELECT
        m.identificador AS manzana,
        e.identificador AS id_establecimiento,
        a.nombre AS establecimiento_cercano,
        a.categoria,
        r.agg_cost AS distancia_red_m,
        r.agg_cost
          + m.distancia_conexion_m
          + e.distancia_conexion_m AS distancia_total_m,
        ROW_NUMBER() OVER (
            PARTITION BY m.identificador
            ORDER BY
                r.agg_cost
                + m.distancia_conexion_m
                + e.distancia_conexion_m,
                e.identificador
        ) AS posicion
    FROM rutas r
    JOIN analisis.v_puntos_red m
        ON m.pid = -r.start_vid
    JOIN analisis.v_puntos_red e
        ON e.pid = -r.end_vid
    JOIN alimentos.v_oferta_alimentaria a
        ON a.id = e.identificador
)
SELECT
    manzana,
    id_establecimiento,
    establecimiento_cercano,
    categoria,
    ROUND(distancia_red_m::numeric, 2) AS distancia_red_m,
    ROUND(distancia_total_m::numeric, 2) AS distancia_total_m
FROM distancias
WHERE posicion = 1;


SELECT
    COUNT(*) AS manzanas_residenciales,
    ROUND(AVG(distancia_total_m), 2) AS media_m,
    MIN(distancia_total_m) AS minima_m,
    MAX(distancia_total_m) AS maxima_m,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY distancia_total_m)::numeric,
        2
    ) AS mediana_m
FROM analisis.abastecimiento_red_resultados;


SELECT
    COUNT(*) AS manzanas_residenciales,
    ROUND(AVG(r.distancia_total_m), 2) AS media_m,
    MIN(r.distancia_total_m) AS minima_m,
    MAX(r.distancia_total_m) AS maxima_m,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (
            ORDER BY r.distancia_total_m
        )::numeric, 2
    ) AS mediana_m
FROM analisis.proximidad_red_resultados r
JOIN territorio.v_manzanas_estudio m
    ON m.objectid::text = r.manzana
WHERE m.grupo_uso_econ = 'RESIDENCIAL';


SELECT
    COUNT(*) AS tramos_evaluados,
    COUNT(*) FILTER (
        WHERE EXISTS (
            SELECT 1
            FROM movilidad.andenes a
            WHERE ST_DWithin(r.geom, a.geom, 10)
        )
    ) AS tramos_con_anden_cercano,
    COUNT(*) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM movilidad.andenes a
            WHERE ST_DWithin(r.geom, a.geom, 10)
        )
    ) AS tramos_sin_anden_cercano
FROM movilidad.red_aristas r
JOIN territorio.area_estudio e
    ON ST_Intersects(r.geom, e.geom);



WITH tramos AS (
    SELECT r.id, r.geom
    FROM movilidad.red_aristas r
    JOIN territorio.area_estudio e
        ON ST_Intersects(r.geom, e.geom)
),
segmentos AS (
    SELECT
        t.id,
        ST_LineSubstring(
            t.geom,
            g.n::double precision / c.total,
            (g.n + 1)::double precision / c.total
        ) AS geom
    FROM tramos t
    CROSS JOIN LATERAL (
        SELECT GREATEST(
            CEIL(ST_Length(t.geom) / 5)::integer,
            1
        ) AS total
    ) c
    CROSS JOIN LATERAL generate_series(
        0, c.total - 1
    ) AS g(n)
),
evaluacion AS (
    SELECT
        s.id,
        ST_Length(s.geom) AS longitud_m,
        EXISTS (
            SELECT 1
            FROM movilidad.andenes a
            WHERE ST_DWithin(s.geom, a.geom, 10)
        ) AS tiene_anden
    FROM segmentos s
)
SELECT
    COUNT(DISTINCT id) AS tramos_evaluados,
    ROUND(SUM(longitud_m)::numeric, 2)
        AS longitud_evaluada_m,
    ROUND(
        COALESCE(
            SUM(longitud_m) FILTER (WHERE tiene_anden),
            0
        )::numeric, 2
    ) AS longitud_con_anden_cercano_m,
    ROUND(
        (
            100.0 *
            COALESCE(
                SUM(longitud_m) FILTER (WHERE tiene_anden),
                0
            ) /
            NULLIF(SUM(longitud_m), 0)
        )::numeric, 2
    ) AS porcentaje_proximidad
FROM evaluacion;



WITH tramos_recortados AS (
    SELECT
        r.id,
        ST_CollectionExtract(
            ST_Intersection(r.geom, a.geom), 2
        ) AS geom
    FROM movilidad.red_aristas r
    CROSS JOIN territorio.area_estudio a
    WHERE ST_Intersects(r.geom, a.geom)
),
lineas AS (
    SELECT
        t.id,
        (ST_Dump(t.geom)).geom AS geom
    FROM tramos_recortados t
    WHERE NOT ST_IsEmpty(t.geom)
),
segmentos AS (
    SELECT
        l.id,
        ST_LineSubstring(
            l.geom,
            g.n::double precision / c.total,
            (g.n + 1)::double precision / c.total
        ) AS geom
    FROM lineas l
    CROSS JOIN LATERAL (
        SELECT GREATEST(
            CEIL(ST_Length(l.geom) / 5)::integer,
            1
        ) AS total
    ) c
    CROSS JOIN LATERAL generate_series(
        0, c.total - 1
    ) AS g(n)
    WHERE ST_Length(l.geom) > 0
),
evaluacion AS (
    SELECT
        s.id,
        ST_Length(s.geom) AS longitud_m,
        EXISTS (
            SELECT 1
            FROM movilidad.andenes a
            WHERE ST_DWithin(s.geom, a.geom, 10)
        ) AS tiene_anden
    FROM segmentos s
)
SELECT
    COUNT(DISTINCT id) AS tramos_evaluados,
    ROUND(SUM(longitud_m)::numeric, 2)
        AS longitud_dentro_m,
    ROUND(
        COALESCE(
            SUM(longitud_m) FILTER (WHERE tiene_anden), 0
        )::numeric, 2
    ) AS longitud_con_anden_m,
    ROUND(
        COALESCE(
            SUM(longitud_m) FILTER (WHERE NOT tiene_anden), 0
        )::numeric, 2
    ) AS longitud_sin_anden_m,
    ROUND(
        (
            100.0 *
            COALESCE(
                SUM(longitud_m) FILTER (WHERE tiene_anden), 0
            ) /
            NULLIF(SUM(longitud_m), 0)
        )::numeric, 2
    ) AS porcentaje_proximidad
FROM evaluacion;



SELECT
    name,
    default_version,
    installed_version
FROM pg_available_extensions
WHERE name = 'postgis_sfcgal';



SELECT
    objectid,
    ST_GeometryType(geom) AS geometria_original,
    ST_GeometryType(
        CG_ApproximateMedialAxis(geom)
    ) AS geometria_resultante,
    ROUND(
        ST_Length(
            CG_ApproximateMedialAxis(geom)
        )::numeric, 2
    ) AS longitud_eje_m
FROM movilidad.andenes
WHERE ST_Intersects(
    geom,
    (SELECT geom FROM territorio.area_estudio LIMIT 1)
)
ORDER BY ST_Area(geom) DESC
LIMIT 1;


WITH eje AS (
    SELECT
        objectid,
        CG_ApproximateMedialAxis(geom) AS geom
    FROM movilidad.andenes
    WHERE objectid = 1152369
)
SELECT
    objectid,
    ST_NumGeometries(geom) AS componentes_lineales,
    ST_IsValid(geom) AS geometria_valida,
    ST_IsEmpty(geom) AS geometria_vacia,
    ROUND(ST_Length(geom)::numeric, 2)
        AS longitud_total_m
FROM eje;


WITH eje AS (
    SELECT CG_ApproximateMedialAxis(geom) AS geom
    FROM movilidad.andenes
    WHERE objectid = 1152369
),
ramas AS (
    SELECT (ST_Dump(geom)).geom AS geom
    FROM eje
),
extremos AS (
    SELECT ST_StartPoint(geom) AS punto FROM ramas
    UNION ALL
    SELECT ST_EndPoint(geom) AS punto FROM ramas
),
frecuencias AS (
    SELECT
        ST_AsEWKB(punto) AS coordenada,
        COUNT(*) AS frecuencia
    FROM extremos
    GROUP BY ST_AsEWKB(punto)
)
SELECT
    COUNT(*) AS posiciones_distintas,
    COUNT(*) FILTER (
        WHERE frecuencia = 1
    ) AS extremos_libres,
    COUNT(*) FILTER (
        WHERE frecuencia >= 2
    ) AS posiciones_compartidas
FROM frecuencias;


WITH ramas AS (
    SELECT
        ROW_NUMBER() OVER ()::bigint AS id,
        d.geom
    FROM movilidad.andenes a
    CROSS JOIN LATERAL ST_Dump(
        CG_ApproximateMedialAxis(a.geom)
    ) AS d
    WHERE a.objectid = 1152369
),
extremos AS (
    SELECT ST_AsEWKB(ST_StartPoint(geom)) AS coordenada
    FROM ramas
    UNION
    SELECT ST_AsEWKB(ST_EndPoint(geom))
    FROM ramas
),
nodos AS (
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY coordenada
        )::bigint AS id,
        coordenada
    FROM extremos
),
aristas AS (
    SELECT
        r.id,
        ni.id AS source,
        nf.id AS target,
        ST_Length(r.geom) AS cost
    FROM ramas r
    JOIN nodos ni
      ON ni.coordenada =
         ST_AsEWKB(ST_StartPoint(r.geom))
    JOIN nodos nf
      ON nf.coordenada =
         ST_AsEWKB(ST_EndPoint(r.geom))
),
componentes AS (
    SELECT *
    FROM pgr_connectedComponents(
        $sql$
        SELECT id, source, target,
               cost, cost AS reverse_cost
        FROM movilidad.red_aristas
        WHERE source <> target
        $sql$
    )
)
SELECT
    (SELECT COUNT(*) FROM ramas) AS ramas,
    (SELECT COUNT(*) FROM nodos) AS nodos,
    (SELECT COUNT(*) FROM aristas) AS aristas;


