-- 12: completa los campos del catalogo (staging.fuente_dato) que el cargador no llena. Solo rellena lo que esta vacio
-- y nunca afirma una licencia que no se haya podido confirmar.
UPDATE staging.fuente_dato SET
  licencia     = coalesce(licencia, 'No declarada en el servicio REST; dato publicado por entidad distrital (por confirmar)'),
  escala       = coalesce(escala, CASE nombre
                   WHEN 'Catastro - Localidad' THEN 'Localidad (poligono)'
                   WHEN 'Catastro - Manzana' THEN 'Manzana'
                   WHEN 'Mapa de Referencia - Anden' THEN 'Poligono de anden'
                   WHEN 'SINU - Red peatonal POT' THEN 'Tramo de linea'
                   WHEN 'Datos Abiertos - Plazas de mercado' THEN 'Punto' END),
  limitaciones = coalesce(limitaciones, CASE nombre
                   WHEN 'Catastro - Localidad' THEN 'Limite oficial de Catastro; sin escala cartografica declarada'
                   WHEN 'Catastro - Manzana' THEN 'Sin estrato ni poblacion; su codigo no siempre coincide con el de la capa de estratificacion'
                   WHEN 'Mapa de Referencia - Anden' THEN 'Se conserva como zona pero no entra a la red; el campo de ancho no tiene dato'
                   WHEN 'Datos Abiertos - Plazas de mercado' THEN 'Pocas plazas en la localidad; coordenadas en el sistema local 990047 transformadas a 9377' END)
WHERE licencia IS NULL OR escala IS NULL OR limitaciones IS NULL;

-- Comedores comunitarios (SDIS): fuente validada el 2026-11-05, no incorporada al modelo.
INSERT INTO staging.fuente_dato (nombre, entidad, url, fecha_descarga, licencia, cobertura, escala, limitaciones)
VALUES ('SDIS - Comedores comunitarios (validada, no incorporada)', 'Secretaria Distrital de Integracion Social',
        'https://geovisor.sdis.gov.co/server/rest/services/Oferta_de_Servicios_Sociales/MapServer/16', NULL,
        'No declarada en el servicio (por confirmar)', 'Bogota: 142 comedores; Puente Aranda: 4', 'Punto',
        'La capa no declara fecha de actualizacion. Se valido su consulta pero no se cargo a alimentos.establecimiento; el ICA no incluye comedores')
ON CONFLICT (nombre) DO NOTHING;
