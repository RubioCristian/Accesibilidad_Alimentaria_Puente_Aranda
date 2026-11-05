
CREATE TABLE IF NOT EXISTS staging.uso_predominante (
    objectid INTEGER PRIMARY KEY,
    mancodigo VARCHAR(10),
    grupo_uso_econ VARCHAR(255),
    ano BIGINT,
    geom geometry(MultiPolygon, 4326),
    fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_staging_uso_geom
ON staging.uso_predominante
USING GIST (geom);


SELECT http_set_curlopt(
    'CURLOPT_TIMEOUT_MS',
    '120000'
);


SELECT
    status,
    content_type,
    LEFT(content, 300) AS respuesta
FROM http_get(
    'https://serviciosgis.catastrobogota.gov.co/'
    || 'arcgis/rest/services/catastro/'
    || 'usopredominante/MapServer/0'
    || '?f=json'
);






SELECT
    COUNT(*) AS total_manzanas,
    COUNT(DISTINCT mancodigo) AS codigos_distintos,
    COUNT(*) FILTER (
        WHERE mancodigo IS NULL
    ) AS codigos_nulos
FROM territorio.manzana;


SELECT http_set_curlopt(
    'CURLOPT_CONNECTTIMEOUT_MS',
    '15000'
);

SELECT http_set_curlopt(
    'CURLOPT_TIMEOUT_MS',
    '60000'
);



WITH muestra AS (
    SELECT DISTINCT mancodigo
    FROM territorio.manzana
    WHERE mancodigo IS NOT NULL
    ORDER BY mancodigo
    LIMIT 20
),
consulta AS (
    SELECT
        'https://serviciosgis.catastrobogota.gov.co/'
        || 'arcgis/rest/services/catastro/'
        || 'usopredominante/MapServer/0/query'
        || '?where=MANCODIGO%20IN%20(%27'
        || string_agg(mancodigo, '%27%2C%27')
        || '%27)'
        || '&outFields=*'
        || '&returnGeometry=false'
        || '&f=json' AS url
    FROM muestra
),
respuesta AS (
    SELECT
        r.status,
        r.content::jsonb AS datos
    FROM consulta c
    CROSS JOIN LATERAL http_get(c.url) r
)
SELECT
    status,
    datos->'error' AS error_servicio,
    jsonb_array_length(
        COALESCE(datos->'features', '[]'::jsonb)
    ) AS registros_recibidos,
    datos->'features'->0->'attributes'
        AS ejemplo_atributos
FROM respuesta;


CREATE TABLE IF NOT EXISTS staging.uso_predominante_historico (
    objectid INTEGER PRIMARY KEY,
    mancodigo VARCHAR(9),
    grupo_uso_econ TEXT,
    ano BIGINT,
    fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_uso_hist_mancodigo
ON staging.uso_predominante_historico (mancodigo);



-- Configurar tiempos de conexión
SELECT http_set_curlopt(
    'CURLOPT_CONNECTTIMEOUT_MS', '15000'
);

SELECT http_set_curlopt(
    'CURLOPT_TIMEOUT_MS', '60000'
);

DO $$
DECLARE
    desplazamiento INTEGER := 0;
    cantidad_lote INTEGER := 20;
    url TEXT;
    respuesta JSONB;
    estado INTEGER;
    recibidos INTEGER;
    guardados INTEGER;
BEGIN

    -- Seleccionar un lote de códigos
    SELECT
        'https://serviciosgis.catastrobogota.gov.co/'
        || 'arcgis/rest/services/catastro/'
        || 'usopredominante/MapServer/0/query'
        || '?where=MANCODIGO%20IN%20(%27'
        || string_agg(mancodigo, '%27%2C%27')
        || '%27)'
        || '&outFields=OBJECTID%2CMANCODIGO%2CGRUPOUSOECON%2CANO'
        || '&returnGeometry=false'
        || '&f=json'
    INTO url
    FROM (
        SELECT DISTINCT mancodigo
        FROM territorio.manzana
        WHERE mancodigo IS NOT NULL
        ORDER BY mancodigo
        LIMIT cantidad_lote
        OFFSET desplazamiento
    ) AS codigos;

    IF url IS NULL THEN
        RAISE NOTICE 'No hay más manzanas en este lote';
        RETURN;
    END IF;

    -- Consultar servicio REST
    SELECT status, content::jsonb
    INTO estado, respuesta
    FROM http_get(url);

    IF estado <> 200
       OR respuesta ? 'error'
       OR jsonb_typeof(respuesta->'features')
          IS DISTINCT FROM 'array'
       OR COALESCE(
           (respuesta->>'exceededTransferLimit')::boolean,
           false
       )
    THEN
        RAISE EXCEPTION
            'Respuesta REST incorrecta: %', respuesta;
    END IF;

    recibidos := jsonb_array_length(
        respuesta->'features'
    );

    -- Insertar registros históricos
    INSERT INTO staging.uso_predominante_historico (
        objectid,
        mancodigo,
        grupo_uso_econ,
        ano
    )
    SELECT
        (f->'attributes'->>'OBJECTID')::integer,
        f->'attributes'->>'MANCODIGO',
        f->'attributes'->>'GRUPOUSOECON',
        (f->'attributes'->>'ANO')::bigint
    FROM jsonb_array_elements(
        respuesta->'features'
    ) AS f
    ON CONFLICT (objectid)
    DO UPDATE SET
        mancodigo = EXCLUDED.mancodigo,
        grupo_uso_econ = EXCLUDED.grupo_uso_econ,
        ano = EXCLUDED.ano,
        fecha_carga = CURRENT_TIMESTAMP;

    GET DIAGNOSTICS guardados = ROW_COUNT;

    RAISE NOTICE
        'Registros recibidos: %', recibidos;

    RAISE NOTICE
        'Registros insertados o actualizados: %',
        guardados;

END $$;



SELECT
    COUNT(*) AS total_registros,
    COUNT(DISTINCT mancodigo) AS manzanas,
    COUNT(DISTINCT ano) AS periodos,
    MIN(
        (TO_TIMESTAMP(ano / 1000.0)
        AT TIME ZONE 'UTC')::date
    ) AS fecha_minima,
    MAX(
        (TO_TIMESTAMP(ano / 1000.0)
        AT TIME ZONE 'UTC')::date
    ) AS fecha_maxima
FROM staging.uso_predominante_historico;




CREATE TABLE IF NOT EXISTS staging.control_lotes_uso (
    lote INTEGER PRIMARY KEY,
    codigos TEXT[] NOT NULL,
    estado TEXT NOT NULL DEFAULT 'pendiente',
    registros INTEGER DEFAULT 0,
    ultimo_error TEXT,
    actualizado TIMESTAMPTZ
);

WITH codigos AS (
    SELECT
        mancodigo,
        ROW_NUMBER() OVER (
            ORDER BY mancodigo
        ) AS numero
    FROM (
        SELECT DISTINCT mancodigo
        FROM territorio.manzana
        WHERE mancodigo IS NOT NULL
    ) AS m
),
grupos AS (
    SELECT
        ((numero - 1) / 20)::integer AS lote,
        ARRAY_AGG(mancodigo ORDER BY mancodigo) AS codigos
    FROM codigos
    GROUP BY ((numero - 1) / 20)::integer
)
INSERT INTO staging.control_lotes_uso (
    lote,
    codigos
)
SELECT lote, codigos
FROM grupos
ON CONFLICT (lote) DO NOTHING;


CREATE OR REPLACE PROCEDURE staging.descargar_usos(
    cantidad_lotes INTEGER DEFAULT 10
)
LANGUAGE plpgsql
AS $$
DECLARE
    b RECORD;
    url TEXT;
    respuesta JSONB;
    codigo_http INTEGER;
    cantidad INTEGER;
    mensaje_error TEXT;
BEGIN

    -- Configurar los tiempos de espera
    PERFORM http_set_curlopt(
        'CURLOPT_CONNECTTIMEOUT_MS', '15000'
    );

    PERFORM http_set_curlopt(
        'CURLOPT_TIMEOUT_MS', '60000'
    );

    FOR b IN
        SELECT lote, codigos
        FROM staging.control_lotes_uso
        WHERE estado IN ('pendiente', 'error')
        ORDER BY
            CASE WHEN estado = 'pendiente'
                 THEN 0 ELSE 1 END,
            lote
        LIMIT cantidad_lotes
    LOOP

        mensaje_error := NULL;
        cantidad := 0;

        BEGIN

            -- Construir la consulta REST
            url :=
                'https://serviciosgis.catastrobogota.gov.co/'
                || 'arcgis/rest/services/catastro/'
                || 'usopredominante/MapServer/0/query'
                || '?where=MANCODIGO%20IN%20(%27'
                || array_to_string(
                    b.codigos, '%27%2C%27'
                )
                || '%27)'
                || '&outFields=OBJECTID%2CMANCODIGO%2C'
                || 'GRUPOUSOECON%2CANO'
                || '&returnGeometry=false'
                || '&f=json';

            -- Consultar el servicio
            SELECT status, content::jsonb
            INTO codigo_http, respuesta
            FROM http_get(url);

            -- Validar la respuesta
            IF codigo_http <> 200
               OR respuesta ? 'error'
               OR jsonb_typeof(
                    respuesta->'features'
               ) IS DISTINCT FROM 'array'
               OR COALESCE(
                    (respuesta->>'exceededTransferLimit')::boolean,
                    false
               )
            THEN
                RAISE EXCEPTION
                    'Respuesta REST incorrecta';
            END IF;

            cantidad := jsonb_array_length(
                respuesta->'features'
            );

            -- Almacenar los datos históricos
            INSERT INTO staging.uso_predominante_historico (
                objectid,
                mancodigo,
                grupo_uso_econ,
                ano
            )
            SELECT
                (f->'attributes'->>'OBJECTID')::integer,
                f->'attributes'->>'MANCODIGO',
                f->'attributes'->>'GRUPOUSOECON',
                (f->'attributes'->>'ANO')::bigint
            FROM jsonb_array_elements(
                respuesta->'features'
            ) AS f
            ON CONFLICT (objectid)
            DO UPDATE SET
                mancodigo = EXCLUDED.mancodigo,
                grupo_uso_econ = EXCLUDED.grupo_uso_econ,
                ano = EXCLUDED.ano,
                fecha_carga = CURRENT_TIMESTAMP;

        EXCEPTION WHEN OTHERS THEN
            mensaje_error := SQLERRM;
        END;

        -- Registrar el resultado del lote
        IF mensaje_error IS NULL THEN

            UPDATE staging.control_lotes_uso
            SET estado = 'completado',
                registros = cantidad,
                ultimo_error = NULL,
                actualizado = CURRENT_TIMESTAMP
            WHERE lote = b.lote;

            RAISE NOTICE
                'Lote % completado: % registros',
                b.lote, cantidad;

        ELSE

            UPDATE staging.control_lotes_uso
            SET estado = 'error',
                ultimo_error = mensaje_error,
                actualizado = CURRENT_TIMESTAMP
            WHERE lote = b.lote;

            RAISE NOTICE
                'Lote % falló: %',
                b.lote, mensaje_error;

        END IF;

        -- Confirmar cada lote de manera independiente
        COMMIT;

    END LOOP;

END;
$$;



SELECT
    estado,
    COUNT(*) AS lotes,
    SUM(registros) AS registros
FROM staging.control_lotes_uso
GROUP BY estado
ORDER BY estado;



CALL staging.descargar_usos(10);


SELECT
    estado,
    COUNT(*) AS lotes,
    COALESCE(SUM(registros), 0) AS registros
FROM staging.control_lotes_uso
GROUP BY estado
ORDER BY estado;



SELECT
    mancodigo,
    COUNT(DISTINCT ano) AS periodos_disponibles
FROM staging.uso_predominante_historico
GROUP BY mancodigo
HAVING COUNT(DISTINCT ano) < 10
ORDER BY periodos_disponibles, mancodigo;


WITH periodos AS (
    SELECT
        mancodigo,
        COUNT(DISTINCT ano) AS cantidad_periodos
    FROM staging.uso_predominante_historico
    GROUP BY mancodigo
)
SELECT
    cantidad_periodos,
    COUNT(*) AS cantidad_manzanas
FROM periodos
GROUP BY cantidad_periodos
ORDER BY cantidad_periodos;


WITH ultimo_periodo AS (
    SELECT MAX(ano) AS ano
    FROM staging.uso_predominante_historico
)
SELECT
    COUNT(DISTINCT m.mancodigo)
        AS total_manzanas,
    COUNT(DISTINCT u.mancodigo)
        AS con_dato_reciente,
    COUNT(DISTINCT m.mancodigo)
        - COUNT(DISTINCT u.mancodigo)
        AS sin_dato_reciente
FROM territorio.manzana m
CROSS JOIN ultimo_periodo p
LEFT JOIN staging.uso_predominante_historico u
    ON m.mancodigo = u.mancodigo
   AND u.ano = p.ano
WHERE m.mancodigo IS NOT NULL;


SELECT
    mancodigo,
    ano,
    COUNT(*) AS cantidad
FROM staging.uso_predominante_historico
GROUP BY mancodigo, ano
HAVING COUNT(*) > 1
ORDER BY cantidad DESC, mancodigo;



CREATE OR REPLACE VIEW territorio.v_uso_predominante AS

WITH ultimo_periodo AS (
    SELECT MAX(ano) AS ano
    FROM staging.uso_predominante_historico
)

SELECT
    m.objectid,
    m.mancodigo,
    m.seccodigo,
    u.grupo_uso_econ,

    (
        TO_TIMESTAMP(u.ano / 1000.0)
        AT TIME ZONE 'UTC'
    )::date AS fecha_dato,

    CASE
        WHEN m.mancodigo IS NULL
            THEN 'Codigo de manzana nulo'
        WHEN u.objectid IS NULL
            THEN 'Sin informacion reciente'
        ELSE 'Con informacion'
    END AS estado_informacion,

    m.geom

FROM territorio.manzana m

CROSS JOIN ultimo_periodo p

LEFT JOIN staging.uso_predominante_historico u
    ON m.mancodigo = u.mancodigo
    AND u.ano = p.ano;


SELECT
    estado_informacion,
    COUNT(*) AS cantidad_manzanas
FROM territorio.v_uso_predominante
GROUP BY estado_informacion
ORDER BY estado_informacion;


SELECT
    grupo_uso_econ,
    COUNT(*) AS cantidad_manzanas
FROM territorio.v_uso_predominante
WHERE estado_informacion = 'Con informacion'
GROUP BY grupo_uso_econ
ORDER BY cantidad_manzanas DESC;






