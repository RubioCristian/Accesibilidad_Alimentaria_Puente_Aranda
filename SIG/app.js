/* Visor estatico: lee SIG/data/*.geojson (exportados por Scripts/loader/exportar.py). */
const CENTRO = [-74.1185, 4.6240];
const ESTADO = { escenario: "base", modo: "ica", alcance: "zona", predio: null };
let PREDIOS = null, LOTES = null, MANZANAS = null;

const RAMPA_ICA = ["#b2182b", "#ef8a62", "#fddbc7", "#d9f0d3", "#7fbf7b", "#1b7837"];
const RAMPA_IPT = ["#f7f4f9", "#d4b9da", "#c994c7", "#df65b0", "#dd1c77", "#7a0177"];
const COLOR_ESTRATO = { 1: "#d73027", 2: "#fc8d59", 3: "#fee08b", 4: "#d9ef8b", 5: "#91cf60", 6: "#1a9850" };
const COLOR_USO = { vivienda: "#8fb8de", comercio: "#f2a541", otro: "#c9c3b6" };
const COLOR_CAT = {
  "Supermercado": "#c8553d", "Tienda de conveniencia": "#1e6f5c", "Panaderia": "#b8860b",
  "Fruteria y verduleria": "#5aa02c", "Carniceria": "#8e2a4f", "Plaza de mercado": "#3b4cc0",
};

const CAPAS = [
  { id: "cobertura", titulo: "Zona cargada", tipo: "line", color: "#1f2a2e", ancho: 1.5, visible: true, ancla: "zona" },
  { id: "manzanas", titulo: "Manzanas", tipo: "line", color: "#7d7869", ancho: 0.8, visible: true },
  { id: "vias", titulo: "Malla vial", tipo: "line", color: "#9aa5a8", ancho: 1.2, visible: false },
  { id: "red", titulo: "Red peatonal", tipo: "line", color: "#2b6cb0", ancho: 1, visible: false },
  { id: "rutas_tm", titulo: "Rutas TransMilenio (GTFS)", tipo: "line", color: "#d62728", ancho: 2.4, visible: false },
  { id: "rutas_sitp", titulo: "Rutas SITP (GTFS)", tipo: "line", color: "#ff7f0e", ancho: 1.4, visible: false, opacidad: 0.55 },
  { id: "obras", titulo: "Obras (area supuesta de 25 m)", tipo: "fill", color: "#e03131", visible: true, opacidad: 0.35 },
  { id: "estaciones_tm", titulo: "Estaciones TransMilenio", tipo: "circle", color: "#d62728", radio: 8, visible: true },
  { id: "paraderos_sitp", titulo: "Paraderos SITP", tipo: "circle", color: "#ff7f0e", radio: 4, visible: false },
  { id: "establecimientos", titulo: "Establecimientos de alimentos", tipo: "circle", color: COLOR_CAT, radio: 6, visible: true },
];

const mapa = new maplibregl.Map({
  container: "mapa", center: CENTRO, zoom: 15, minZoom: 11, maxZoom: 20, attributionControl: { compact: true },
  style: {
    version: 8,
    sources: { osm: { type: "raster", tileSize: 256, maxzoom: 19,
      tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"], attribution: "© OpenStreetMap contributors" } },
    layers: [{ id: "fondo", type: "background", paint: { "background-color": "#eceae3" } },
             { id: "osm", type: "raster", source: "osm", paint: { "raster-opacity": 0.55, "raster-saturation": -0.6 } }],
  },
});
mapa.addControl(new maplibregl.NavigationControl({ showCompass: false }), "top-right");
mapa.addControl(new maplibregl.ScaleControl({ unit: "metric" }), "bottom-right");

const esc = (t) => String(t ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const num = (v, d = 1) => (v === null || v === undefined ? "sin dato" : Number(v).toFixed(d));

function colorLotes() {
  const e = ESTADO.escenario === "obras" ? "obras" : "base";
  const m = ESTADO.modo;
  const sinDato = "#d6d2c6";
  if (m === "ica" || m === "ipt") {
    const rampa = m === "ica" ? RAMPA_ICA : RAMPA_IPT;
    const campo = ["get", `${m}_${e}`];
    const pasos = rampa.map((c, i) => [i * 20, c]);
    return ["case", ["==", ["typeof", campo], "number"],
      ["interpolate", ["linear"], campo, ...pasos.flat()], sinDato];
  }
  if (m === "uso") return ["match", ["get", "uso_clase"], "vivienda", COLOR_USO.vivienda, "comercio", COLOR_USO.comercio, COLOR_USO.otro];
  if (m === "estrato") {
    const f = ["match", ["get", "estrato"]];
    Object.entries(COLOR_ESTRATO).forEach(([k, c]) => f.push(Number(k), c));
    f.push(sinDato);
    return f;
  }
  return ["case", ["==", ["typeof", ["get", "demanda"]], "number"],
    ["interpolate", ["linear"], ["get", "demanda"], 0, "#f1eef6", 1, "#bdc9e1", 3, "#74a9cf", 8, "#0570b0"], sinDato];
}

function leyenda() {
  const el = document.getElementById("leyenda");
  const m = ESTADO.modo;
  const fila = (c, t) => `<div class="fila"><span class="sw" style="background:${c}"></span>${t}</div>`;
  const sinDato = fila("#d6d2c6", "sin dato / no aplica");
  if (m === "ica" || m === "ipt") {
    const rampa = m === "ica" ? RAMPA_ICA : RAMPA_IPT;
    const [a, b] = m === "ica" ? ["0 &middot; acceso deficiente", "100 &middot; acceso alto"] : ["0 &middot; baja prioridad", "100 &middot; alta prioridad"];
    el.innerHTML = `<div class="rampa" style="background:linear-gradient(90deg,${rampa.join(",")})"></div>
      <div class="extremos"><span>${a}</span><span>${b}</span></div>${sinDato}
      <div class="nota" style="margin-top:8px">Promedio de los predios del lote. ${m === "ipt" ? "Solo lotes con uso de vivienda." : ""}</div>`;
  } else if (m === "uso") {
    el.innerHTML = fila(COLOR_USO.vivienda, "Vivienda (001, 002, 037, 038)") + fila(COLOR_USO.comercio, "Comercio y servicios (003, 004, 039, 040, 056, 060, 066)") + fila(COLOR_USO.otro, "Otros usos")
      + `<div class="nota" style="margin-top:8px">Uso con mayor &aacute;rea en el lote; agrupaci&oacute;n propia de este visor.</div>`;
  } else if (m === "estrato") {
    el.innerHTML = Object.entries(COLOR_ESTRATO).map(([k, c]) => fila(c, `Estrato ${k}`)).join("") + sinDato
      + `<div class="nota" style="margin-top:8px">Estrato 0 (sin estrato) se muestra sin dato.</div>`;
  } else {
    el.innerHTML = `<div class="rampa" style="background:linear-gradient(90deg,#f1eef6,#bdc9e1,#74a9cf,#0570b0)"></div>
      <div class="extremos"><span>menor</span><span>mayor</span></div>${sinDato}
      <div class="nota" style="margin-top:8px"><b>Dato inferido</b>: proporcional al &aacute;rea de vivienda, sin tama&ntilde;o de hogar. No son personas.</div>`;
  }
}

function popup(titulo, filas) {
  return `<h3>${esc(titulo)}</h3><dl>${filas.map(([k, v]) => `<dt>${esc(k)}</dt><dd>${esc(v)}</dd>`).join("")}</dl>`;
}

const POPUPS = {
  lotes: (p) => {
    const e = ESTADO.escenario === "obras" ? "obras" : "base";
    return popup(`Lote ${p.codigo}`, [["Dirección", p.direccion || "sin dato"], ["Predios", p.predios], ["Uso predominante", p.uso || "sin dato"],
      ["Estrato", p.estrato || "sin dato"], ["ICA", num(p[`ica_${e}`])], ["IPT", num(p[`ipt_${e}`])], ["Demanda (inferida)", num(p.demanda, 2)]])
      + `<button class="ir" data-lote="${esc(p.codigo)}">Analizar desde este predio</button>`;
  },
  establecimientos: (p) => popup(p.nombre || "Sin nombre", [["Categoría", p.categoria], ["Fuente", p.fuente]]),
  estaciones_tm: (p) => popup(p.nombre, [["Código GTFS", p.codigo], ["Rutas que pasan", p.rutas]]),
  paraderos_sitp: (p) => popup(p.nombre, [["Código GTFS", p.codigo], ["Rutas que pasan", p.rutas]]),
  rutas_tm: (p) => popup(p.codigo, [["Sistema", p.sistema], ["Recorrido", p.nombre]]),
  rutas_sitp: (p) => popup(p.codigo, [["Sistema", p.sistema], ["Recorrido", p.nombre]]),
  obras: (p) => popup(p.nombre, [["Código", p.codigo], ["Estado", p.estado], ["Actualización", p.actualizacion || "sin dato"]]),
  manzanas: (p) => popup(`Manzana ${p.codigo}`, [["Estrato", p.estrato ?? "sin dato"]]),
  vias: (p) => popup(p.nombre || "Vía", [["Tipo", p.tipo]]),
};

async function cargar(nombre) {
  const r = await fetch(`data/${nombre}.geojson`);
  if (!r.ok) throw new Error(`${nombre}: ${r.status}`);
  return r.json();
}

function aviso(t) { const a = document.getElementById("aviso"); a.textContent = t; a.hidden = false; }

function agregarCapa(c, datos) {
  mapa.addSource(c.id, { type: "geojson", data: datos });
  const capa = { id: c.id, source: c.id, type: c.tipo, layout: { visibility: c.visible ? "visible" : "none" }, paint: {} };
  if (c.tipo === "line") {
    capa.paint = { "line-color": c.color, "line-width": c.ancho, "line-opacity": c.opacidad ?? 0.9 };
  } else if (c.tipo === "fill") {
    capa.paint = { "fill-color": c.color, "fill-opacity": c.opacidad ?? 0.5, "fill-outline-color": c.color };
  } else {
    const color = typeof c.color === "string" ? c.color
      : ["match", ["get", "categoria"], ...Object.entries(c.color).flat(), "#555"];
    capa.paint = { "circle-color": color, "circle-radius": ["interpolate", ["linear"], ["zoom"], 12, c.radio / 2, 17, c.radio],
      "circle-stroke-color": "#fff", "circle-stroke-width": 1.2 };
  }
  mapa.addLayer(capa);
}

function interaccion(id) {
  const f = POPUPS[id];
  if (!f) return;
  mapa.on("click", id, (ev) => {
    const feat = ev.features[0];
    new maplibregl.Popup({ closeButton: true }).setLngLat(ev.lngLat).setHTML(f(feat.properties)).addTo(mapa);
  });
  mapa.on("mouseenter", id, () => (mapa.getCanvas().style.cursor = "pointer"));
  mapa.on("mouseleave", id, () => (mapa.getCanvas().style.cursor = ""));
}

function listaCapas() {
  const cont = document.getElementById("lista-capas");
  const filas = [{ id: "lotes", titulo: "Lotes (indicadores)", visible: true, muestra: "#8fb8de", forma: "" }]
    .concat(CAPAS.map((c) => ({ id: c.id, titulo: c.titulo, visible: c.visible,
      muestra: typeof c.color === "string" ? c.color : "#c8553d", forma: c.tipo === "line" ? "linea" : c.tipo === "circle" ? "punto" : "" })));
  cont.innerHTML = filas.map((f) => `<label><input type="checkbox" data-capa="${f.id}" ${f.visible ? "checked" : ""}>
    <span class="sw ${f.forma}" style="background:${f.muestra}"></span>${f.titulo}</label>`).join("")
    + `<div class="nota" style="margin-top:6px">Establecimientos: ${Object.entries(COLOR_CAT).map(([k, c]) => `<span class="sw punto" style="display:inline-block;background:${c};margin:0 3px 0 6px"></span>${k}`).join("")}</div>`;
  cont.addEventListener("change", (e) => {
    const id = e.target.dataset.capa;
    if (id) mapa.setLayoutProperty(id, "visibility", e.target.checked ? "visible" : "none");
  });
}

async function resumen() {
  const r = await (await fetch("data/resumen.json")).json();
  document.getElementById("generado").textContent = `Datos exportados el ${r.generado.replace("T", " ")}`;
  document.getElementById("t-calidad").innerHTML = r.calidad.map((q) =>
    `<tr><td>${esc(q.prueba)}</td><td class="${q.falla === 0 ? "ok" : "mal"}">${q.falla}</td></tr>`).join("");
  document.getElementById("t-tablas").innerHTML = r.tablas.map((t) =>
    `<tr><td>${esc(t.tabla)}</td><td class="num">${t.filas.toLocaleString("es-CO")}</td></tr>`).join("");
  document.getElementById("t-ejec").innerHTML = "<tr><th>Escenario</th><th>C&oacute;digo</th></tr>" + r.ejecuciones.map((e) =>
    `<tr><td>${esc(e.escenario)}</td><td>${esc(e.version)}</td></tr>`).join("")
    + r.escenarios.slice(0, 1).map((s) => `<tr><td colspan="2" class="nota">Vecindad: ${s.manzanas_vecindad} manzanas &middot; umbral ${s.umbral_m} m &middot; pesos ${Object.entries(s.pesos).map(([k, v]) => `${k} ${v}`).join(", ")}</td></tr>`).join("");
  document.getElementById("fuentes").innerHTML = r.fuentes.map((f) =>
    `<div class="fuente"><b>${esc(f.nombre)}</b><small>${esc(f.entidad)} &middot; descargado: ${esc(f.fecha_descarga || "fecha no registrada")}</small>
     <small>${esc(f.cobertura || "")}${f.escala ? " &middot; escala: " + esc(f.escala) : ""}</small>
     ${f.licencia ? `<small>Licencia: ${esc(f.licencia)}</small>` : ""}
     ${f.limitaciones ? `<small>Limitaciones: ${esc(f.limitaciones)}</small>` : ""}
     ${f.url ? `<small><a href="${esc(f.url)}" target="_blank" rel="noopener">${esc(f.url)}</a></small>` : ""}</div>`).join("");
}

document.getElementById("limites").innerHTML = [
  "La zona cargada son 76 manzanas y 2 394 lotes; la localidad completa tiene unos 39 697 lotes.",
  "La poblaci&oacute;n no est&aacute; publicada a nivel manzana y no hay tama&ntilde;o de hogar: la demanda es <b>inferida</b> a partir del &aacute;rea de vivienda.",
  "Sin datos de comedores vigentes, mercados campesinos, venta informal, precios ni calidad: esos criterios no se calculan.",
  "Las tiendas de barrio est&aacute;n subestimadas en OpenStreetMap.",
  "Las obras vienen como puntos; el &aacute;rea de afectaci&oacute;n (25 m) es un supuesto. En esta zona no hay obras en ejecuci&oacute;n, por eso los dos escenarios coinciden.",
  "Solo se calcula el modo caminando (1,25 m/s). El transporte p&uacute;blico se muestra, pero no entra en el &iacute;ndice.",
  "El estrato es por manzana y el valor 0 (sin estrato) se trata como dato faltante.",
  "ICA e IPT son relativos a los predios de la zona (normalizaci&oacute;n min-max): no son comparables con otra zona.",
].map((t) => `<li>${t}</li>`).join("");

document.querySelectorAll("#pestanas button").forEach((b) => b.addEventListener("click", () => {
  document.querySelectorAll("#pestanas button, .tab").forEach((n) => n.classList.remove("activa"));
  b.classList.add("activa");
  document.getElementById(`tab-${b.dataset.tab}`).classList.add("activa");
}));
document.getElementById("escenarios").addEventListener("change", (e) => { ESTADO.escenario = e.target.value; actualizar(); });
document.getElementById("modos").addEventListener("change", (e) => { ESTADO.modo = e.target.value; actualizar(); });
document.getElementById("mapa-base").addEventListener("change", (e) =>
  mapa.setLayoutProperty("osm", "visibility", e.target.checked ? "visible" : "none"));

function actualizar() {
  if (mapa.getLayer("lotes")) mapa.setPaintProperty("lotes", "fill-color", colorLotes());
  leyenda();
  if (ESTADO.predio) fichaPredio();
}

/* ---- Consulta desde un predio ---- */
const clave = (t) => String(t ?? "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
const UMBRAL = 800;

function centroLote(codigo) {
  const f = LOTES.features.find((x) => x.properties.codigo === codigo);
  if (!f) return null;
  const pts = (f.geometry.type === "Polygon" ? f.geometry.coordinates[0] : f.geometry.coordinates[0][0]);
  const b = pts.reduce((r, p) => [Math.min(r[0], p[0]), Math.min(r[1], p[1]), Math.max(r[2], p[0]), Math.max(r[3], p[1])], [180, 90, -180, -90]);
  return [(b[0] + b[2]) / 2, (b[1] + b[3]) / 2];
}

function buscar(texto) {
  const q = clave(texto).trim();
  const ul = document.getElementById("resultados");
  if (q.length < 2) { ul.innerHTML = ""; return; }
  const hits = PREDIOS.predios.filter((p) => clave(`${p.dir} ${p.chip} ${p.lote}`).includes(q)).slice(0, 8);
  ul.innerHTML = hits.map((p) => `<li data-chip="${esc(p.chip)}">${esc(p.dir || "sin direccion")}<small>CHIP ${esc(p.chip)} &middot; lote ${esc(p.lote)}</small></li>`).join("")
    || `<li class="nota">Sin coincidencias</li>`;
}

function seleccionar(chip) {
  const p = PREDIOS.predios.find((x) => x.chip === chip);
  if (!p) return;
  ESTADO.predio = p;
  ESTADO.alcance = "predio";
  document.querySelector('input[name="alcance"][value="predio"]').checked = true;
  document.getElementById("buscador").hidden = false;
  document.querySelector('#pestanas [data-tab="predio"]').click();
  document.getElementById("resultados").innerHTML = "";
  dibujarSeleccion(true);
  fichaPredio();
}

function limpiarSeleccion() {
  ESTADO.predio = null;
  ["sel-od", "sel-est", "sel-lote", "sel-vecindad"].forEach((id) => mapa.getSource(id) && mapa.getSource(id).setData({ type: "FeatureCollection", features: [] }));
  mapa.setPaintProperty("lotes", "fill-opacity", 0.85);
  document.getElementById("ficha").innerHTML = "";
}

function odActual() {
  const p = ESTADO.predio;
  return ESTADO.escenario === "obras" ? (p.od_obras || p.od_base || []) : (p.od_base || []);
}

function dibujarSeleccion(ajustar) {
  const p = ESTADO.predio;
  const vec = PREDIOS.vecindad[p.mz] || [p.mz];
  mapa.setPaintProperty("lotes", "fill-opacity", ["case", ["in", ["get", "manzana"], ["literal", vec]], 0.9, 0.12]);
  const mz = MANZANAS.features.filter((f) => vec.includes(f.properties.codigo));
  mapa.getSource("sel-vecindad").setData({ type: "FeatureCollection", features: mz });
  mapa.getSource("sel-lote").setData({ type: "FeatureCollection", features: LOTES.features.filter((f) => f.properties.codigo === p.lote) });
  const origen = centroLote(p.lote);
  const od = odActual();
  const est = (i) => [PREDIOS.establecimientos[i].lon, PREDIOS.establecimientos[i].lat];
  mapa.getSource("sel-od").setData({ type: "FeatureCollection", features: od.map(([i, d]) => ({ type: "Feature",
    properties: { cerca: d <= UMBRAL ? 1 : 0 }, geometry: { type: "LineString", coordinates: [origen, est(i)] } })) });
  mapa.getSource("sel-est").setData({ type: "FeatureCollection", features: od.map(([i, d]) => ({ type: "Feature",
    properties: { cerca: d <= UMBRAL ? 1 : 0 }, geometry: { type: "Point", coordinates: est(i) } })) });
  if (ajustar) {
    const pts = mz.flatMap((f) => (f.geometry.type === "Polygon" ? f.geometry.coordinates[0] : f.geometry.coordinates.flatMap((q) => q[0])));
    const caja = pts.reduce((b, q) => b.extend(q), new maplibregl.LngLatBounds(origen, origen));
    mapa.fitBounds(caja, { padding: 50, duration: 600 });
  }
}

function fichaPredio() {
  const p = ESTADO.predio;
  const r = (ESTADO.escenario === "obras" ? p.obras : p.base) || {};
  const od = odActual();
  const cerca = od.filter(([, d]) => d <= UMBRAL).length;
  const fila = ([i, d]) => `<div class="est ${d > UMBRAL ? "lejos" : ""}" data-est="${i}"><span>${esc(PREDIOS.establecimientos[i].nombre || "Sin nombre")}
    <small class="nota">${esc(PREDIOS.establecimientos[i].categoria)}</small></span><i>${d} m &middot; ${Math.round(d / 1.25 / 60)} min</i></div>`;
  document.getElementById("ficha").innerHTML = `<h2>Predio seleccionado</h2>
    <b>${esc(p.dir || "Sin dirección")}</b>
    <div class="nota">CHIP ${esc(p.chip)} &middot; lote ${esc(p.lote)} &middot; manzana ${esc(p.mz)} &middot; estrato ${p.estrato || "sin dato"}</div>
    <div class="kpis"><div class="kpi"><b>${num(r.ica)}</b><span>ICA</span></div><div class="kpi"><b>${num(r.ipt)}</b><span>IPT</span></div>
      <div class="kpi"><b>${cerca}</b><span>a &le; ${UMBRAL} m</span></div></div>
    <div class="nota">Establecimiento más cercano: ${r.acc == null ? "ninguno alcanzable" : num(r.acc, 0) + " m"} &middot; ${r.cat ?? 0} categorías en el umbral.
      Distancia del lote a la red: ${num(p.acceso_m)} m. Las líneas del mapa son rectas de referencia; las distancias son por la red peatonal.</div>
    ${r.nota ? `<div class="nota"><b>Nota:</b> ${esc(r.nota)}</div>` : ""}
    <h2>Establecimientos en su vecindad (${od.length})</h2>${od.map(fila).join("") || '<div class="nota">Ninguno alcanzable por la red.</div>'}
    <p class="nota"><a href="#" id="volver-zona">Volver a toda la zona</a></p>`;
  dibujarSeleccion(false);
}

function iniciarSeleccion() {
  ["sel-vecindad", "sel-lote", "sel-od", "sel-est"].forEach((id) => mapa.addSource(id, { type: "geojson", data: { type: "FeatureCollection", features: [] } }));
  mapa.addLayer({ id: "sel-vecindad", type: "line", source: "sel-vecindad", paint: { "line-color": "#1e6f5c", "line-width": 2.2 } });
  mapa.addLayer({ id: "sel-od", type: "line", source: "sel-od", paint: { "line-color": ["case", ["==", ["get", "cerca"], 1], "#1e6f5c", "#9aa5a8"],
    "line-width": 1.4, "line-dasharray": [2, 2] } });
  mapa.addLayer({ id: "sel-est", type: "circle", source: "sel-est", paint: { "circle-radius": 9, "circle-color": "rgba(0,0,0,0)",
    "circle-stroke-width": 2.5, "circle-stroke-color": ["case", ["==", ["get", "cerca"], 1], "#1e6f5c", "#9aa5a8"] } });
  mapa.addLayer({ id: "sel-lote", type: "line", source: "sel-lote", paint: { "line-color": "#111", "line-width": 3 } });

  document.getElementById("alcance").addEventListener("change", (e) => {
    ESTADO.alcance = e.target.value;
    document.getElementById("buscador").hidden = ESTADO.alcance !== "predio";
    if (ESTADO.alcance === "zona") limpiarSeleccion();
  });
  document.getElementById("q").addEventListener("input", (e) => buscar(e.target.value));
  document.getElementById("resultados").addEventListener("click", (e) => { const li = e.target.closest("li[data-chip]"); if (li) seleccionar(li.dataset.chip); });
  document.getElementById("ficha").addEventListener("click", (e) => {
    if (e.target.id === "volver-zona") {
      e.preventDefault();
      document.querySelector('input[name="alcance"][value="zona"]').checked = true;
      ESTADO.alcance = "zona";
      document.getElementById("buscador").hidden = true;
      limpiarSeleccion();
      return;
    }
    const fila = e.target.closest(".est");
    if (fila) { const s = PREDIOS.establecimientos[fila.dataset.est]; mapa.flyTo({ center: [s.lon, s.lat], zoom: 18 }); }
  });
  document.body.addEventListener("click", (e) => {
    const b = e.target.closest("button.ir");
    if (!b) return;
    const ps = PREDIOS.predios.filter((x) => x.lote === b.dataset.lote);
    if (!ps.length) return;
    seleccionar(ps[0].chip);
    if (ps.length > 1) {                           // varios predios en el lote (propiedad horizontal): se listan para elegir otro
      document.getElementById("q").value = b.dataset.lote;
      buscar(b.dataset.lote);
    }
  });
}

mapa.on("load", async () => {
  if (new URLSearchParams(location.search).has("sinbase")) {
    mapa.setLayoutProperty("osm", "visibility", "none");
    document.getElementById("mapa-base").checked = false;
  }
  if (location.protocol === "file:") {
    aviso("Abra el visor desde un servidor (podman compose up -d db web, luego http://localhost:8080): el navegador bloquea la lectura de los datos desde file://.");
    return;
  }
  try {
    const [lotes, ...resto] = await Promise.all(["lotes", ...CAPAS.map((c) => c.id)].map(cargar));
    LOTES = lotes;
    MANZANAS = resto[CAPAS.findIndex((c) => c.id === "manzanas")];
    PREDIOS = await (await fetch("data/predios.json")).json();
    mapa.addSource("lotes", { type: "geojson", data: lotes });
    mapa.addLayer({ id: "lotes", type: "fill", source: "lotes", paint: { "fill-color": colorLotes(), "fill-opacity": 0.85, "fill-outline-color": "#ffffff" } });
    CAPAS.forEach((c, i) => agregarCapa(c, resto[i]));
    ["lotes", ...CAPAS.map((c) => c.id)].forEach(interaccion);
    iniciarSeleccion();
    listaCapas();
    leyenda();
    await resumen();
    const chip = new URLSearchParams(location.search).get("chip");   // enlace directo: ?chip=<CHIP>
    if (chip) seleccionar(chip);
    const zona = resto[0].features[0].geometry.coordinates[0];
    const caja = zona.reduce((b, p) => b.extend(p), new maplibregl.LngLatBounds(zona[0], zona[0]));
    mapa.fitBounds(caja, { padding: 40, duration: 0 });
  } catch (err) {
    aviso(`No se pudieron cargar los datos del visor (${err.message}). Ejecute: podman compose --profile etl run --rm etl python -m Scripts.loader.run exportar`);
  }
});
