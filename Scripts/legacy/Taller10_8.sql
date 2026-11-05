
WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
      ON v.anden_1 = c.anden_1
     AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY c.interseccion_id,
             c.longitud_m
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;


UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1014178, 1148608),
    (1039952, 1079550),
    (1097158, 1120872),
    (1155261, 1155292),
    (1046350, 1164097),
    (1015073, 1105872),
    (1059759, 1108238),
    (1026723, 1160800),
    (1070786, 1075936),
    (1072130, 1138231)
)
RETURNING anden_1, anden_2, estado;


WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;



UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1028981, 1092540),
    (1072130, 1134250),
    (1093474, 1130353),
    (1028294, 1048999),
    (1030905, 1124069),
    (1043777, 1095283),
    (1012152, 1081096),
    (1071355, 1088922),
    (1099039, 1101701),
    (1117873, 1155223)
)
RETURNING anden_1, anden_2, estado;



WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;


UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1028981, 1035103),
    (1039952, 1134250),
    (1120872, 1153113),
    (1058865, 1105872),
    (1108238, 1124069),
    (1075119, 1160800),
    (1081096, 1142202),
    (1072130, 1088922),
    (1051784, 1104789),
    (1155115, 1155162)
)
RETURNING anden_1, anden_2, estado;


WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;


UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1013055, 1113776),
    (1072130, 1079550),
    (1015073, 1028294),
    (1059759, 1113698),
    (1026723, 1095283),
    (1012662, 1015833),
    (1075046, 1134250),
    (1097672, 1136030),
    (1075026, 1097465),
    (1087447, 1139858)
)
RETURNING anden_1, anden_2, estado;


WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;


UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1051784, 1136030),
    (1075026, 1096453),
    (1095782, 1107917),
    (1139671, 1154146),
    (1064542, 1081211),
    (1065431, 1117873),
    (1108238, 1164621),
    (1128957, 1135802),
    (1045850, 1164097),
    (1020646, 1163872)
)
RETURNING anden_1, anden_2, estado;


WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;


UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1097672, 1104789),
    (1071547, 1097465),
    (1107917, 1139858),
    (1096416, 1119673),
    (1021552, 1154146),
    (1101701, 1155552),
    (1059759, 1154965),
    (1023818, 1128957),
    (1074177, 1127611),
    (1070640, 1097158)
)
RETURNING anden_1, anden_2, estado;


WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;


UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1087447, 1095782),
    (1119673, 1139671),
    (1081211, 1154146),
    (1099039, 1117873),
    (1154965, 1155305),
    (1127611, 1150976),
    (1065823, 1092540),
    (1104881, 1122233),
    (1009468, 1137563),
    (1017682, 1038065)
)
RETURNING anden_1, anden_2, estado;


WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;


UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1072265, 1154146),
    (1064542, 1139671),
    (1065431, 1101701),
    (1059759, 1129410),
    (1044667, 1161220),
    (1130076, 1139858),
    (1094972, 1152936),
    (1090569, 1147867),
    (1081259, 1163811),
    (1036227, 1086403)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;


WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;



UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1108238, 1154965),
    (1044667, 1150976),
    (1070640, 1139858),
    (1094972, 1122233),
    (1038065, 1147867),
    (1026588, 1035178),
    (1034013, 1036227),
    (1075119, 1095283),
    (1020540, 1157342),
    (1134096, 1154778)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;


WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;


UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1059759, 1155305),
    (1127611, 1161220),
    (1092540, 1139858),
    (1086403, 1104881),
    (1017682, 1135455),
    (1026588, 1113776),
    (1044137, 1057652),
    (1119809, 1150608),
    (1130308, 1148256),
    (1015828, 1093950)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;


WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;



UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1065823, 1087447),
    (1010484, 1028981),
    (1068599, 1123053),
    (1095586, 1165065),
    (1095586, 1118001),
    (1128014, 1142289),
    (1113698, 1124069),
    (1075046, 1088922),
    (1044137, 1078797),
    (1030315, 1074971)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;


WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;


UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1041866, 1119809),
    (1118001, 1130308),
    (1015828, 1053156),
    (1036323, 1055501),
    (1045980, 1113613),
    (1034013, 1075046),
    (1079425, 1124715),
    (1025952, 1131311),
    (1117276, 1158430),
    (1113469, 1119238)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;



WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;


UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1041866, 1157342),
    (1095586, 1148256),
    (1118001, 1124646),
    (1026393, 1049183),
    (1076107, 1113698),
    (1083687, 1088922),
    (1079425, 1081096),
    (1082026, 1123053),
    (1017598, 1141533),
    (1152194, 1155728)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;



WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;



UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1020540, 1103466),
    (1053156, 1095586),
    (1045980, 1124069),
    (1015833, 1031510),
    (1020270, 1082026),
    (1119238, 1141533),
    (1020646, 1156849),
    (1055501, 1058080),
    (1152021, 1154944),
    (1154476, 1155434)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;



WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;



UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1025952, 1039952),
    (1113469, 1144205),
    (1071181, 1105872),
    (1028294, 1061696),
    (1016076, 1024787),
    (1053319, 1099754),
    (1026723, 1145362),
    (1059582, 1129410),
    (1090029, 1099754),
    (1120755, 1155106)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;


WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;



UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1079550, 1082026),
    (1015073, 1020646),
    (1028294, 1058865),
    (1152021, 1154511),
    (1099754, 1154476),
    (1133670, 1134301),
    (1059582, 1102414),
    (1089293, 1127611),
    (1053319, 1104789),
    (1072265, 1119673)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;


WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;



UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1039952, 1131311),
    (1105872, 1156849),
    (1058080, 1061696),
    (1016076, 1154944),
    (1090029, 1155434),
    (1076664, 1134096),
    (1102414, 1129410),
    (1099754, 1127611),
    (1051784, 1120755),
    (1037541, 1083687)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;


WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;


UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1028294, 1058080),
    (1026723, 1133670),
    (1090029, 1150976),
    (1104789, 1155106),
    (1133745, 1137563),
    (1020270, 1025952),
    (1152194, 1154965),
    (1082026, 1131311),
    (1067967, 1154793),
    (1016076, 1154511)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;



WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;



UPDATE movilidad.validacion_cruces
SET
    estado = CASE
        WHEN anden_1 = 1094626
         AND anden_2 = 1143210
        THEN 'Descartado'
        ELSE 'Validado'
    END,
    observacion = CASE
        WHEN anden_1 = 1094626
         AND anden_2 = 1143210
        THEN 'Conexion descartada por revision cartografica'
        ELSE 'Cruce confirmado mediante revision cartografica'
    END
WHERE (anden_1, anden_2) IN (
    (1058865, 1065136),
    (1076664, 1160800),
    (1064542, 1126843),
    (1076052, 1125479),
    (1012662, 1163811),
    (1062698, 1128014),
    (1060535, 1105967),
    (1070037, 1094146),
    (1110462, 1152424),
    (1094626, 1143210)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;


WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;


UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1026723, 1134096),
    (1093823, 1117276),
    (1037302, 1076052),
    (1012662, 1071547),
    (1128014, 1154511),
    (1009757, 1105967),
    (1075377, 1136030),
    (1038530, 1121029),
    (1039684, 1094626),
    (1029651, 1056855)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;


WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;



UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1081211, 1158430),
    (1125479, 1163669),
    (1075026, 1142202),
    (1016076, 1142289),
    (1029651, 1097672),
    (1053858, 1079425),
    (1138074, 1143210),
    (1047725, 1130076),
    (1012152, 1066778),
    (1053156, 1124646)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;



WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;



UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1064542, 1093823),
    (1056855, 1094146),
    (1031510, 1040286),
    (1035178, 1060414),
    (1020540, 1026588),
    (1016170, 1061696),
    (1053752, 1102414),
    (1094626, 1135802),
    (1055790, 1152010),
    (1093823, 1126843)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;



WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;



UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1081211, 1126843),
    (1075377, 1097672),
    (1017682, 1060414),
    (1010484, 1163669),
    (1093950, 1124175),
    (1119952, 1148256),
    (1045980, 1076107),
    (1113469, 1119952),
    (1074276, 1121029),
    (1041866, 1103466)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;


WITH seleccion AS (
    SELECT DISTINCT ON (c.interseccion_id)
        c.interseccion_id,
        c.anden_1,
        c.anden_2,
        c.longitud_m,
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON v.anden_1 = c.anden_1
       AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Pendiente'
    ORDER BY
        c.interseccion_id,
        c.longitud_m,
        c.anden_1,
        c.anden_2
)
SELECT
    interseccion_id,
    anden_1,
    anden_2,
    longitud_m,
    ST_Transform(geom, 4326) AS geom
FROM seleccion
ORDER BY interseccion_id
LIMIT 10;



UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1094146, 1136030),
    (1017682, 1047725),
    (1026588, 1076052),
    (1141533, 1144205),
    (1102414, 1148256),
    (1039684, 1076107),
    (1113469, 1152010),
    (1103566, 1125479),
    (1122233, 1166312),
    (1123714, 1144153)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;


SELECT
    c.interseccion_id,
    c.anden_1,
    c.anden_2,
    c.longitud_m,
    ST_Transform(c.geom, 4326) AS geom
FROM movilidad.v_cruces_candidatos c
JOIN movilidad.validacion_cruces v
    ON v.anden_1 = c.anden_1
   AND v.anden_2 = c.anden_2
WHERE v.estado = 'Pendiente'
ORDER BY
    c.interseccion_id,
    c.longitud_m,
    c.anden_1,
    c.anden_2;



UPDATE movilidad.validacion_cruces
SET
    estado = 'Validado',
    observacion = 'Cruce confirmado mediante revision cartografica'
WHERE (anden_1, anden_2) IN (
    (1017682, 1035178),
    (1038065, 1060414),
    (1061696, 1124175),
    (1095734, 1144205),
    (1124175, 1141533),
    (1053752, 1130308),
    (1039684, 1128957),
    (1045980, 1094626),
    (1055790, 1119238),
    (1037302, 1074276),
    (1041866, 1122233),
    (1103466, 1104881),
    (1015370, 1026393)
)
AND estado = 'Pendiente'
RETURNING anden_1, anden_2, estado;


SELECT
    estado,
    COUNT(*) AS cantidad
FROM movilidad.validacion_cruces
GROUP BY estado
ORDER BY estado;


WITH RECURSIVE
nodos AS (
    SELECT objectid_anden AS id
    FROM movilidad.ejes_andenes
),
enlaces_base AS (
    SELECT anden_1, anden_2
    FROM movilidad.conexiones_andenes

    UNION

    SELECT anden_1, anden_2
    FROM movilidad.conexiones_adicionales

    UNION

    SELECT
        c.anden_1,
        c.anden_2
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
      ON c.anden_1 = v.anden_1
     AND c.anden_2 = v.anden_2
    WHERE v.estado = 'Validado'
),
enlaces AS (
    SELECT anden_1 AS origen,
           anden_2 AS destino
    FROM enlaces_base

    UNION ALL

    SELECT anden_2, anden_1
    FROM enlaces_base
),
alcance(origen, alcanzado) AS (
    SELECT id, id
    FROM nodos

    UNION

    SELECT a.origen, e.destino
    FROM alcance a
    JOIN enlaces e
      ON a.alcanzado = e.origen
),
grupos AS (
    SELECT
        alcanzado AS anden,
        MIN(origen) AS componente
    FROM alcance
    GROUP BY alcanzado
),
tamanos AS (
    SELECT
        componente,
        COUNT(*) AS cantidad
    FROM grupos
    GROUP BY componente
)
SELECT
    COUNT(*) AS componentes_totales,
    MAX(cantidad) AS andenes_componente_principal,
    COUNT(*) FILTER (
        WHERE cantidad = 1
    ) AS componentes_aislados,
    (SELECT COUNT(*) FROM enlaces_base)
        AS conexiones_consideradas,
    SUM(cantidad) AS andenes_evaluados
FROM tamanos;


WITH RECURSIVE
nodos AS (
    SELECT objectid_anden AS id
    FROM movilidad.ejes_andenes
),
enlaces_base AS (
    SELECT anden_1, anden_2
    FROM movilidad.conexiones_andenes

    UNION

    SELECT anden_1, anden_2
    FROM movilidad.conexiones_adicionales

    UNION

    SELECT c.anden_1, c.anden_2
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
      ON c.anden_1 = v.anden_1
     AND c.anden_2 = v.anden_2
    WHERE v.estado = 'Validado'
),
enlaces AS (
    SELECT anden_1 AS origen, anden_2 AS destino
    FROM enlaces_base

    UNION ALL

    SELECT anden_2, anden_1
    FROM enlaces_base
),
alcance(origen, alcanzado) AS (
    SELECT id, id FROM nodos

    UNION

    SELECT a.origen, e.destino
    FROM alcance a
    JOIN enlaces e ON a.alcanzado = e.origen
),
grupos AS (
    SELECT
        alcanzado AS objectid_anden,
        MIN(origen) AS componente
    FROM alcance
    GROUP BY alcanzado
)
SELECT
    g.componente,
    COUNT(*) AS cantidad_andenes,
    ROUND(
        SUM(ST_Length(a.geom))::numeric / 1000,
        2
    ) AS longitud_ejes_km
FROM grupos g
JOIN movilidad.ejes_andenes a
  ON a.objectid_anden = g.objectid_anden
GROUP BY g.componente
ORDER BY cantidad_andenes DESC;



WITH RECURSIVE
nodos AS (
    SELECT objectid_anden AS id
    FROM movilidad.ejes_andenes
),
enlaces_base AS (
    SELECT anden_1, anden_2
    FROM movilidad.conexiones_andenes

    UNION

    SELECT anden_1, anden_2
    FROM movilidad.conexiones_adicionales

    UNION

    SELECT c.anden_1, c.anden_2
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
      ON v.anden_1 = c.anden_1
     AND v.anden_2 = c.anden_2
    WHERE v.estado = 'Validado'
),
enlaces AS (
    SELECT anden_1 AS origen, anden_2 AS destino
    FROM enlaces_base

    UNION ALL

    SELECT anden_2, anden_1
    FROM enlaces_base
),
alcance(origen, alcanzado) AS (
    SELECT id, id FROM nodos

    UNION

    SELECT a.origen, e.destino
    FROM alcance a
    JOIN enlaces e
      ON a.alcanzado = e.origen
),
grupos AS (
    SELECT
        alcanzado AS objectid_anden,
        MIN(origen) AS componente
    FROM alcance
    GROUP BY alcanzado
),
geometrias AS (
    SELECT
        g.componente,
        ST_Collect(a.geom) AS geom
    FROM grupos g
    JOIN movilidad.ejes_andenes a
      ON a.objectid_anden = g.objectid_anden
    GROUP BY g.componente
)
SELECT
    a.componente AS componente_1,
    b.componente AS componente_2,
    ROUND(
        ST_Distance(a.geom, b.geom)::numeric,
        2
    ) AS separacion_minima_m,
    ST_Transform(
        ST_ShortestLine(a.geom, b.geom),
        4326
    ) AS conexion_candidata
FROM geometrias a
JOIN geometrias b
    ON a.componente < b.componente
ORDER BY separacion_minima_m;


CREATE TABLE IF NOT EXISTS movilidad.validacion_componentes (
    componente_1 BIGINT NOT NULL,
    componente_2 BIGINT NOT NULL,
    estado TEXT NOT NULL,
    observacion TEXT,
    PRIMARY KEY (componente_1, componente_2),
    CHECK (estado IN ('Validado', 'Descartado'))
);

INSERT INTO movilidad.validacion_componentes (
    componente_1,
    componente_2,
    estado,
    observacion
)
VALUES
(
    1005914, 1152369,
    'Descartado',
    'Conexion no coherente segun revision cartografica'
),
(
    1005914, 1010653,
    'Validado',
    'Cruce coherente segun revision cartografica'
),
(
    1010653, 1152369,
    'Descartado',
    'Conexion no coherente segun revision cartografica'
)
ON CONFLICT (componente_1, componente_2)
DO UPDATE SET
    estado = EXCLUDED.estado,
    observacion = EXCLUDED.observacion;

SELECT
    componente_1,
    componente_2,
    estado
FROM movilidad.validacion_componentes
ORDER BY componente_1, componente_2;


CREATE TABLE IF NOT EXISTS movilidad.conexion_componentes (
    componente_1 BIGINT,
    componente_2 BIGINT,
    anden_1 BIGINT,
    anden_2 BIGINT,
    longitud_m DOUBLE PRECISION,
    geom geometry(LineString, 9377),
    PRIMARY KEY (componente_1, componente_2)
);

WITH RECURSIVE
nodos AS (
    SELECT objectid_anden AS id
    FROM movilidad.ejes_andenes
),
enlaces_base AS (
    SELECT anden_1, anden_2
    FROM movilidad.conexiones_andenes

    UNION

    SELECT anden_1, anden_2
    FROM movilidad.conexiones_adicionales

    UNION

    SELECT c.anden_1, c.anden_2
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
      ON c.anden_1 = v.anden_1
     AND c.anden_2 = v.anden_2
    WHERE v.estado = 'Validado'
),
enlaces AS (
    SELECT anden_1 AS origen, anden_2 AS destino
    FROM enlaces_base

    UNION ALL

    SELECT anden_2, anden_1
    FROM enlaces_base
),
alcance(origen, alcanzado) AS (
    SELECT id, id FROM nodos

    UNION

    SELECT a.origen, e.destino
    FROM alcance a
    JOIN enlaces e ON a.alcanzado = e.origen
),
grupos AS (
    SELECT
        alcanzado AS objectid_anden,
        MIN(origen) AS componente
    FROM alcance
    GROUP BY alcanzado
),
pares AS (
    SELECT
        a.objectid_anden AS anden_1,
        b.objectid_anden AS anden_2,
        ST_ShortestLine(a.geom, b.geom) AS geom
    FROM grupos ga
    JOIN movilidad.ejes_andenes a
      ON a.objectid_anden = ga.objectid_anden
    CROSS JOIN grupos gb
    JOIN movilidad.ejes_andenes b
      ON b.objectid_anden = gb.objectid_anden
    WHERE ga.componente = 1005914
      AND gb.componente = 1010653
    ORDER BY ST_Distance(a.geom, b.geom)
    LIMIT 1
)
INSERT INTO movilidad.conexion_componentes (
    componente_1,
    componente_2,
    anden_1,
    anden_2,
    longitud_m,
    geom
)
SELECT
    1005914,
    1010653,
    anden_1,
    anden_2,
    ST_Length(geom),
    geom
FROM pares
ON CONFLICT (componente_1, componente_2)
DO UPDATE SET
    anden_1 = EXCLUDED.anden_1,
    anden_2 = EXCLUDED.anden_2,
    longitud_m = EXCLUDED.longitud_m,
    geom = EXCLUDED.geom;



WITH RECURSIVE
nodos AS (
    SELECT objectid_anden AS id
    FROM movilidad.ejes_andenes
),
enlaces_base AS (
    SELECT anden_1, anden_2
    FROM movilidad.conexiones_andenes

    UNION

    SELECT anden_1, anden_2
    FROM movilidad.conexiones_adicionales

    UNION

    SELECT c.anden_1, c.anden_2
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
        ON c.anden_1 = v.anden_1
       AND c.anden_2 = v.anden_2
    WHERE v.estado = 'Validado'

    UNION

    SELECT anden_1, anden_2
    FROM movilidad.conexion_componentes
),
enlaces AS (
    SELECT anden_1 AS origen, anden_2 AS destino
    FROM enlaces_base

    UNION ALL

    SELECT anden_2, anden_1
    FROM enlaces_base
),
alcance(origen, alcanzado) AS (
    SELECT id, id FROM nodos

    UNION

    SELECT a.origen, e.destino
    FROM alcance a
    JOIN enlaces e
        ON a.alcanzado = e.origen
),
grupos AS (
    SELECT
        alcanzado,
        MIN(origen) AS componente
    FROM alcance
    GROUP BY alcanzado
)
SELECT
    COUNT(DISTINCT componente) AS componentes_totales,
    COUNT(*) AS andenes_evaluados
FROM grupos;


CREATE TABLE IF NOT EXISTS movilidad.red_peatonal_segmentos (
    id BIGSERIAL PRIMARY KEY,
    objectid_anden BIGINT,
    tipo TEXT NOT NULL,
    geom geometry(LineString, 9377)
);

INSERT INTO movilidad.red_peatonal_segmentos (
    objectid_anden,
    tipo,
    geom
)
SELECT
    a.objectid_anden,
    'Eje de anden',
    d.geom::geometry(LineString, 9377)
FROM movilidad.ejes_andenes a
CROSS JOIN LATERAL ST_Dump(a.geom) AS d
WHERE ST_Length(d.geom) > 0;


SELECT
    COUNT(*) AS segmentos,
    COUNT(DISTINCT objectid_anden) AS andenes_representados,
    COUNT(*) FILTER (
        WHERE NOT ST_IsValid(geom)
    ) AS invalidos,
    ROUND(
        (SUM(ST_Length(geom)) / 1000)::numeric,
        2
    ) AS longitud_km
FROM movilidad.red_peatonal_segmentos;


WITH conexiones AS (
    SELECT
        'Originales' AS tipo,
        geom
    FROM movilidad.conexiones_andenes

    UNION ALL

    SELECT
        'Adicionales',
        geom
    FROM movilidad.conexiones_adicionales

    UNION ALL

    SELECT
        'Cruces validados',
        c.geom
    FROM movilidad.v_cruces_candidatos c
    JOIN movilidad.validacion_cruces v
      ON c.anden_1 = v.anden_1
     AND c.anden_2 = v.anden_2
    WHERE v.estado = 'Validado'

    UNION ALL

    SELECT
        'Entre componentes',
        geom
    FROM movilidad.conexion_componentes
)
SELECT
    tipo,
    COUNT(*) AS cantidad,
    COUNT(*) FILTER (
        WHERE geom IS NULL
    ) AS geometrias_nulas,
    COUNT(*) FILTER (
        WHERE NOT ST_IsValid(geom)
    ) AS geometrias_invalidas,
    COUNT(*) FILTER (
        WHERE ST_Length(geom) = 0
    ) AS longitud_cero,
    ROUND(
        SUM(ST_Length(geom))::numeric,
        2
    ) AS longitud_total_m
FROM conexiones
GROUP BY tipo
ORDER BY tipo;


INSERT INTO movilidad.red_peatonal_segmentos (
    objectid_anden,
    tipo,
    geom
)
SELECT
    NULL::BIGINT,
    'Conexion original',
    geom
FROM movilidad.conexiones_andenes

UNION ALL

SELECT
    NULL::BIGINT,
    'Conexion adicional',
    geom
FROM movilidad.conexiones_adicionales

UNION ALL

SELECT
    NULL::BIGINT,
    'Cruce validado',
    c.geom
FROM movilidad.v_cruces_candidatos c
JOIN movilidad.validacion_cruces v
    ON c.anden_1 = v.anden_1
   AND c.anden_2 = v.anden_2
WHERE v.estado = 'Validado'

UNION ALL

SELECT
    NULL::BIGINT,
    'Conexion entre componentes',
    geom
FROM movilidad.conexion_componentes;



SELECT
    tipo,
    COUNT(*) AS cantidad
FROM movilidad.red_peatonal_segmentos
GROUP BY tipo
ORDER BY tipo;


DROP TABLE IF EXISTS movilidad.red_peatonal_aristas;

CREATE TABLE movilidad.red_peatonal_aristas AS
WITH red_unificada AS (
    SELECT ST_UnaryUnion(
        ST_Collect(geom)
    ) AS geom
    FROM movilidad.red_peatonal_segmentos
),
segmentos AS (
    SELECT
        (ST_Dump(geom)).geom AS geom
    FROM red_unificada
)
SELECT
    ROW_NUMBER() OVER ()::BIGINT AS id,
    geom::geometry(LineString, 9377) AS geom,
    ST_Length(geom) AS cost,
    ST_Length(geom) AS reverse_cost
FROM segmentos
WHERE ST_Length(geom) > 0;

ALTER TABLE movilidad.red_peatonal_aristas
ADD PRIMARY KEY (id);

CREATE INDEX idx_red_peatonal_aristas_geom
ON movilidad.red_peatonal_aristas
USING GIST (geom);


SELECT
    COUNT(*) AS aristas,
    COUNT(*) FILTER (
        WHERE NOT ST_IsValid(geom)
    ) AS geometrias_invalidas,
    COUNT(*) FILTER (
        WHERE ST_Length(geom) = 0
    ) AS longitud_cero,
    ROUND(
        SUM(ST_Length(geom))::numeric / 1000,
        3
    ) AS longitud_total_km
FROM movilidad.red_peatonal_aristas;


-- 1. Crear tabla de nodos
DROP TABLE IF EXISTS movilidad.red_peatonal_nodos;

CREATE TABLE movilidad.red_peatonal_nodos AS
WITH extremos AS (
    SELECT ST_StartPoint(geom) AS geom
    FROM movilidad.red_peatonal_aristas

    UNION

    SELECT ST_EndPoint(geom) AS geom
    FROM movilidad.red_peatonal_aristas
)
SELECT
    ROW_NUMBER() OVER (ORDER BY ST_X(geom), ST_Y(geom))::BIGINT AS id,
    geom::geometry(Point, 9377) AS geom
FROM extremos;

ALTER TABLE movilidad.red_peatonal_nodos
ADD PRIMARY KEY (id);

CREATE INDEX idx_red_peatonal_nodos_geom
ON movilidad.red_peatonal_nodos
USING GIST (geom);

-- 2. Agregar columnas de topologia
ALTER TABLE movilidad.red_peatonal_aristas
ADD COLUMN IF NOT EXISTS source BIGINT;

ALTER TABLE movilidad.red_peatonal_aristas
ADD COLUMN IF NOT EXISTS target BIGINT;

-- 3. Asociar extremos de cada arista a sus nodos
UPDATE movilidad.red_peatonal_aristas a
SET
    source = n.id
FROM movilidad.red_peatonal_nodos n
WHERE ST_StartPoint(a.geom) = n.geom;

UPDATE movilidad.red_peatonal_aristas a
SET
    target = n.id
FROM movilidad.red_peatonal_nodos n
WHERE ST_EndPoint(a.geom) = n.geom;

-- 4. Indices para pgRouting
CREATE INDEX IF NOT EXISTS idx_red_peatonal_source
ON movilidad.red_peatonal_aristas (source);

CREATE INDEX IF NOT EXISTS idx_red_peatonal_target
ON movilidad.red_peatonal_aristas (target);


SELECT
    (SELECT COUNT(*)
     FROM movilidad.red_peatonal_nodos) AS nodos,

    COUNT(*) AS aristas,

    COUNT(*) FILTER (
        WHERE source IS NULL OR target IS NULL
    ) AS aristas_sin_nodos,

    COUNT(*) FILTER (
        WHERE source = target
    ) AS aristas_cerradas
FROM movilidad.red_peatonal_aristas;


WITH componentes AS (
    SELECT *
    FROM pgr_connectedComponents(
        'SELECT
            id,
            source,
            target,
            cost,
            reverse_cost
         FROM movilidad.red_peatonal_aristas'
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
    COUNT(*) AS componentes_totales,
    MAX(cantidad_nodos) AS nodos_componente_principal,
    COUNT(*) FILTER (
        WHERE cantidad_nodos = 1
    ) AS componentes_aislados,
    SUM(cantidad_nodos) AS nodos_evaluados
FROM resumen;


WITH componentes AS (
    SELECT
        component,
        node
    FROM pgr_connectedComponents(
        'SELECT
            id,
            source,
            target,
            cost,
            reverse_cost
         FROM movilidad.red_peatonal_aristas'
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
    ROW_NUMBER() OVER (
        ORDER BY cantidad_nodos DESC
    ) AS numero_componente,
    component AS id_componente,
    cantidad_nodos,
    ROUND(
        cantidad_nodos * 100.0 /
        SUM(cantidad_nodos) OVER (),
        2
    ) AS porcentaje_nodos
FROM resumen
ORDER BY cantidad_nodos DESC;


WITH componentes AS (
    SELECT component, node
    FROM pgr_connectedComponents(
        'SELECT id, source, target, cost, reverse_cost
         FROM movilidad.red_peatonal_aristas'
    )
),
geometrias AS (
    SELECT
        c.component,
        ST_Collect(n.geom) AS geom,
        COUNT(*) AS cantidad_nodos
    FROM componentes c
    JOIN movilidad.red_peatonal_nodos n
      ON c.node = n.id
    GROUP BY c.component
)
SELECT
    a.component AS componente_1,
    b.component AS componente_2,
    ROUND(
        ST_Distance(a.geom, b.geom)::numeric,
        2
    ) AS distancia_minima_m,
    ST_Transform(
        ST_ShortestLine(a.geom, b.geom),
        4326
    ) AS conexion_candidata
FROM geometrias a
JOIN geometrias b
  ON a.component < b.component
ORDER BY ST_Distance(a.geom, b.geom)
LIMIT 15;


WITH componentes AS (
    SELECT component, node
    FROM pgr_connectedComponents(
        'SELECT id, source, target, cost, reverse_cost
         FROM movilidad.red_peatonal_aristas'
    )
),
pares AS (
    SELECT
        a.component AS componente_1,
        b.component AS componente_2,
        a.node AS nodo_1,
        b.node AS nodo_2,
        ST_Distance(na.geom, nb.geom) AS distancia_m
    FROM componentes a
    JOIN movilidad.red_peatonal_nodos na
      ON na.id = a.node
    JOIN movilidad.red_peatonal_nodos nb
      ON ST_DWithin(na.geom, nb.geom, 0.10)
     AND na.id < nb.id
    JOIN componentes b
      ON b.node = nb.id
     AND a.component <> b.component
)
SELECT
    LEAST(componente_1, componente_2) AS componente_1,
    GREATEST(componente_1, componente_2) AS componente_2,
    COUNT(*) AS pares_cercanos,
    ROUND(MIN(distancia_m)::numeric, 5) AS distancia_minima_m,
    ROUND(MAX(distancia_m)::numeric, 5) AS distancia_maxima_m
FROM pares
GROUP BY
    LEAST(componente_1, componente_2),
    GREATEST(componente_1, componente_2)
ORDER BY distancia_minima_m;


