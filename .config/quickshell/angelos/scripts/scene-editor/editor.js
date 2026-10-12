// angelOS scene editor — the page (scene-editor.py serves it). One picture at a time: its
// painted layers (one cell = one art pixel of live-wall.py's mask), effects, event places,
// rings, and requests to Claude. Saved through PUT /api/scene; a change made elsewhere
// (Claude over MCP) is picked up by polling /api/state.
"use strict";
const $ = s => document.querySelector(s);
const $$ = s => [...document.querySelectorAll(s)];
const api = async (path, opts = {}) => {
  const r = await fetch(path, Object.assign({ headers: { "Content-Type": "application/json" } }, opts));
  const ct = r.headers.get("Content-Type") || "";
  const body = ct.includes("json") ? await r.json() : await r.blob();
  if (!r.ok && !(r.status === 409)) throw new Error(body.error || r.statusText);
  return { status: r.status, body };
};
const b64ToGrid = s => { const b = atob(s); const a = new Int8Array(b.length); for (let i = 0; i < b.length; i++) a[i] = b.charCodeAt(i) - 1; return a; };
const gridToB64 = a => { let s = ""; const CH = 0x8000; const u = new Uint8Array(a.length); for (let i = 0; i < a.length; i++) u[i] = a[i] + 1; for (let i = 0; i < u.length; i += CH) s += String.fromCharCode.apply(null, u.subarray(i, i + CH)); return btoa(s); };
const clamp01 = v => Math.min(1, Math.max(0, v));

const S = {
  meta: null, pics: [], pic: "", W: 0, H: 0,
  paint: null, auto: null, colors: null, scene: {}, found: {}, info: {}, mtime: 0,
  tool: "brush", layer: 1, view: "final", opacity: 0.55, zoom: 1,
  pointKind: "eyes", regions: [], undo: [], redo: [], dirty: false, saving: false, saveTimer: 0,
  reqMtime: 0, reqs: [],
};

// ---------- startup ----------
async function boot() {
  S.meta = (await api("/api/meta")).body;
  buildLayers();
  buildEffects();
  buildPointKinds();
  bindUi();
  await loadList();
  const want = decodeURIComponent(location.hash.slice(1)) || S.meta.first || "";
  if (want) openPic(want);
  setInterval(() => api("/api/ping").catch(() => {}), 20000);
  setInterval(poll, 1500);
  refreshRequests();
}

async function loadList() {
  S.pics = (await api("/api/list")).body.pictures;
  renderList();
}

function renderList() {
  const q = $("#search").value.trim().toLowerCase();
  const box = $("#pics");
  box.innerHTML = "";
  for (const p of S.pics) {
    const name = p.path.split("/").pop();
    if (q && !(p.path.toLowerCase().includes(q) || p.where.toLowerCase().includes(q))) continue;
    const el = document.createElement("div");
    el.className = "pic" + (p.path === S.pic ? " on" : "");
    el.innerHTML = `<img loading="lazy"><div class="t"><div class="n"></div><div class="w"></div></div>`;
    el.querySelector("img").src = "/api/picture?pic=" + encodeURIComponent(p.path);
    el.querySelector(".n").textContent = name;
    el.querySelector(".w").innerHTML = (p.scene ? '<span class="s">✦ сцена</span> · ' : "") + escapeHtml(p.where);
    el.title = p.path;
    el.onclick = () => openPic(p.path);
    box.appendChild(el);
  }
}
const escapeHtml = s => String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

// ---------- one picture ----------
async function openPic(path) {
  if (S.dirty && S.pic && S.pic !== path) await save();
  status("смотрю на картинку…");
  let d;
  try {
    d = (await api("/api/scene?pic=" + encodeURIComponent(path))).body;
  } catch (e) {
    return status("✕ " + e.message);
  }
  S.pic = d.picture;
  location.hash = encodeURIComponent(S.pic);
  applyScene(d);
  S.undo = []; S.redo = [];
  $("#picName").textContent = S.pic.replace(/^\/home\/[^/]+/, "~");
  $("#empty").hidden = true;
  $("#stage").hidden = false;
  const img = $("#bg");
  img.onload = () => { sampleColors(); layout(); draw(); };
  img.src = "/api/picture?pic=" + encodeURIComponent(S.pic) + "&t=" + Date.now();
  renderList();
  status("");
}

function applyScene(d) {
  S.W = d.grid[0]; S.H = d.grid[1];
  S.paint = b64ToGrid(d.paint);
  S.auto = b64ToGrid(d.auto);
  S.scene = d.scene || {};
  S.found = d.found || {};
  S.info = d.info || {};
  S.mtime = d.mtime;
  S.dirty = false;
  $("#gridV").textContent = S.W + "×" + S.H + (S.info.pixelArt ? ", пиксель-арт" : ", фото");
  const c = $("#over");
  c.width = S.W; c.height = S.H;
  syncFxUi();
  saveState("");
  if ($("#bg").complete && $("#bg").naturalWidth) { sampleColors(); layout(); }
  draw();
}

// the picture's colour per cell, for the fill tool (drawn down to the grid)
function sampleColors() {
  if (!S.W) return;
  const c = document.createElement("canvas");
  c.width = S.W; c.height = S.H;
  const g = c.getContext("2d", { willReadFrequently: true });
  g.imageSmoothingQuality = "high";
  g.drawImage($("#bg"), 0, 0, S.W, S.H);
  S.colors = g.getImageData(0, 0, S.W, S.H).data;
}

function layout() {
  const wrap = $("#stageWrap");
  const img = $("#bg");
  const ar = (img.naturalWidth || S.W) / (img.naturalHeight || S.H);
  let w = wrap.clientWidth - 32, h = w / ar;
  if (h > wrap.clientHeight - 32) { h = wrap.clientHeight - 32; w = h * ar; }
  w *= S.zoom; h *= S.zoom;
  const st = $("#stage");
  st.style.width = Math.round(w) + "px";
  st.style.height = Math.round(h) + "px";
  $("#marks").setAttribute("viewBox", `0 0 ${Math.round(w)} ${Math.round(h)}`);
  drawMarks();
}
window.addEventListener("resize", () => S.pic && layout());

// ---------- drawing the layers ----------
function draw() {
  if (!S.W) return;
  const g = $("#over").getContext("2d");
  const im = g.createImageData(S.W, S.H);
  const px = im.data;
  const cols = {};
  for (const l of S.meta.layers) cols[l.id] = l.rgb;
  const op = S.opacity * 255;
  for (let i = 0; i < S.W * S.H; i++) {
    let v = -1, a = 0;
    const p = S.paint[i];
    if (S.view === "final") { if (p >= 0) { v = p; a = op; } else { v = S.auto[i]; a = op * 0.55; } }
    else if (S.view === "found") { v = S.auto[i]; a = op; }
    else if (S.view === "paint") { if (p >= 0) { v = p; a = op; } }
    if (v < 0) continue;
    if (v === 0 && S.view !== "paint" && p < 0) a *= 0.35;       // what was found still: barely
    const c = cols[v];
    px[i * 4] = c[0]; px[i * 4 + 1] = c[1]; px[i * 4 + 2] = c[2]; px[i * 4 + 3] = a;
  }
  g.putImageData(im, 0, 0);
  drawMarks();
}

// points, rings, the request's regions, a shape being drawn (SVG over the canvas)
let ghost = null;
function drawMarks() {
  const svg = $("#marks");
  const w = $("#stage").clientWidth, h = $("#stage").clientHeight;
  let s = "";
  const kinds = { rims: "#ffffff", eyes: "#ff5a5a", ponds: "#5affff", lights: "#ffff78" };
  for (const k of Object.keys(kinds)) {
    const own = Array.isArray(S.scene[k]);
    const pts = own ? S.scene[k] : (S.found[k] || []);
    const dim = !own;
    for (const [x, y] of pts)
      s += `<circle cx="${x * w}" cy="${y * h}" r="${k === "lights" ? 4 : 7}" fill="none" stroke="${kinds[k]}" stroke-width="2" opacity="${dim ? 0.35 : (S.pointKind === k ? 1 : 0.7)}"/>`;
  }
  for (const r of S.scene.rings || [])
    s += `<ellipse cx="${r[0] * w}" cy="${r[1] * h}" rx="${r[2] * w}" ry="${r[3] * h}" fill="none" stroke="#ffd24a" stroke-width="${Math.max(2, r[4] * r[2] * w)}" opacity=".45"/>` +
      `<ellipse cx="${r[0] * w}" cy="${r[1] * h}" rx="${r[2] * w}" ry="${r[3] * h}" fill="none" stroke="#ffd24a" stroke-width="1.5" stroke-dasharray="4 3"/>`;
  S.regions.forEach((r, i) => {
    s += `<rect x="${r.rect[0] * w}" y="${r.rect[1] * h}" width="${(r.rect[2] - r.rect[0]) * w}" height="${(r.rect[3] - r.rect[1]) * h}" fill="#ff8fb822" stroke="#ff8fb8" stroke-width="2"/>` +
      `<text x="${r.rect[0] * w + 5}" y="${r.rect[1] * h + 15}" fill="#ff8fb8" font-weight="700">${i + 1}</text>`;
  });
  if (ghost) {
    if (ghost.rect) { const [x0, y0, x1, y1] = ghost.rect; s += `<rect x="${Math.min(x0, x1) * w}" y="${Math.min(y0, y1) * h}" width="${Math.abs(x1 - x0) * w}" height="${Math.abs(y1 - y0) * h}" fill="#fff2" stroke="#fff" stroke-dasharray="4 3"/>`; }
    if (ghost.poly) s += `<polyline points="${ghost.poly.map(([x, y]) => x * w + "," + y * h).join(" ")}" fill="#fff2" stroke="#fff" stroke-dasharray="4 3"/>`;
    if (ghost.ring) { const [cx, cy, rx, ry] = ghost.ring; s += `<ellipse cx="${cx * w}" cy="${cy * h}" rx="${rx * w}" ry="${ry * h}" fill="none" stroke="#ffd24a" stroke-dasharray="4 3"/>`; }
    if (ghost.cursor) { const [x, y, r] = ghost.cursor; s += `<circle cx="${x * w}" cy="${y * h}" r="${r * w}" fill="none" stroke="#fff" opacity=".7"/>`; }
  }
  svg.innerHTML = s;
  $("#regionsV").textContent = S.regions.length ? "областей: " + S.regions.length : "";
  $("#ringsList").textContent = (S.scene.rings || []).length ? "колец: " + S.scene.rings.length + " (правый клик по кольцу — убрать)" : "колец нет";
}

// ---------- editing ----------
function snapshot() {
  S.undo.push({ paint: S.paint.slice(), scene: JSON.parse(JSON.stringify(S.scene)) });
  if (S.undo.length > 60) S.undo.shift();
  S.redo = [];
}
function restore(from, to) {
  const st = from.pop();
  if (!st) return;
  to.push({ paint: S.paint.slice(), scene: JSON.parse(JSON.stringify(S.scene)) });
  S.paint = st.paint; S.scene = st.scene;
  syncFxUi(); changed("шаг назад");
}
function changed(what) {
  S.dirty = true;
  S.lastWhat = what || "правка в редакторе";
  saveState("не сохранено");
  draw();
  clearTimeout(S.saveTimer);
  if ($("#autosave").checked) S.saveTimer = setTimeout(save, 1100);
}
const cell = (x, y) => [Math.min(S.W - 1, Math.max(0, Math.floor(x * S.W))), Math.min(S.H - 1, Math.max(0, Math.floor(y * S.H)))];

function stamp(x, y, r) {
  const [cx, cy] = cell(x, y);
  const rr = Math.max(0.5, r);
  const v = S.layer;
  for (let j = Math.floor(cy - rr); j <= Math.ceil(cy + rr); j++)
    for (let i = Math.floor(cx - rr); i <= Math.ceil(cx + rr); i++)
      if (i >= 0 && j >= 0 && i < S.W && j < S.H && (i - cx) ** 2 + (j - cy) ** 2 <= rr * rr) S.paint[j * S.W + i] = v;
}
function strokeTo(a, b, r) {
  const steps = Math.max(1, Math.ceil(Math.hypot((b[0] - a[0]) * S.W, (b[1] - a[1]) * S.H) / Math.max(1, r / 2)));
  for (let k = 0; k <= steps; k++) stamp(a[0] + (b[0] - a[0]) * k / steps, a[1] + (b[1] - a[1]) * k / steps, r);
}
function fillRect([x0, y0, x1, y1]) {
  const [a, b] = cell(Math.min(x0, x1), Math.min(y0, y1)), [c, d] = cell(Math.max(x0, x1), Math.max(y0, y1));
  for (let j = b; j <= d; j++) for (let i = a; i <= c; i++) S.paint[j * S.W + i] = S.layer;
}
function fillPoly(pts) {
  const P = pts.map(([x, y]) => [x * S.W, y * S.H]);
  for (let j = 0; j < S.H; j++) {
    const yy = j + 0.5, xs = [];
    for (let k = 0; k < P.length; k++) {
      const [x1, y1] = P[k], [x2, y2] = P[(k + 1) % P.length];
      if ((y1 <= yy && y2 > yy) || (y2 <= yy && y1 > yy)) xs.push(x1 + (yy - y1) / (y2 - y1) * (x2 - x1));
    }
    xs.sort((a, b) => a - b);
    for (let k = 0; k + 1 < xs.length; k += 2)
      for (let i = Math.max(0, Math.ceil(xs[k] - 0.5)); i <= Math.min(S.W - 1, Math.floor(xs[k + 1] - 0.5)); i++) S.paint[j * S.W + i] = S.layer;
  }
}
function flood(x, y) {
  if (!S.colors) return;
  const [sx, sy] = cell(x, y);
  const tol = +$("#tol").value / 100 * 255;
  const C = S.colors, i0 = (sy * S.W + sx) * 4;
  const r0 = C[i0], g0 = C[i0 + 1], b0 = C[i0 + 2];
  const seen = new Uint8Array(S.W * S.H);
  const stack = [sy * S.W + sx];
  seen[stack[0]] = 1;
  while (stack.length) {
    const k = stack.pop();
    S.paint[k] = S.layer;
    const i = k % S.W, j = (k - i) / S.W;
    for (const [di, dj] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const ni = i + di, nj = j + dj;
      if (ni < 0 || nj < 0 || ni >= S.W || nj >= S.H) continue;
      const n = nj * S.W + ni;
      if (seen[n]) continue;
      seen[n] = 1;
      const q = n * 4;
      if (Math.max(Math.abs(C[q] - r0), Math.abs(C[q + 1] - g0), Math.abs(C[q + 2] - b0)) <= tol) stack.push(n);
    }
  }
}

// ---------- pointer ----------
let drag = null;
function rel(e) {
  const r = $("#stage").getBoundingClientRect();
  return [clamp01((e.clientX - r.left) / r.width), clamp01((e.clientY - r.top) / r.height)];
}
function nearest(list, p) {
  let best = -1, bd = 1e9;
  (list || []).forEach((q, i) => { const d = Math.hypot(q[0] - p[0], (q[1] - p[1]) * S.H / S.W); if (d < bd) { bd = d; best = i; } });
  return bd < 0.03 ? best : -1;
}
function bindStage() {
  const st = $("#stage");
  st.addEventListener("contextmenu", e => e.preventDefault());
  st.addEventListener("pointerdown", e => {
    if (!S.pic) return;
    const p = rel(e);
    st.setPointerCapture(e.pointerId);
    if (e.button === 2) return rightClick(p);
    if (e.button !== 0) return;
    const t = S.tool;
    if (t === "brush") { snapshot(); drag = { last: p }; stamp(p[0], p[1], brushR()); draw(); }
    else if (t === "rect" || t === "region") drag = { start: p }, ghost = { rect: [p[0], p[1], p[0], p[1]] };
    else if (t === "ring") drag = { start: p }, ghost = { ring: [p[0], p[1], 0, 0] };
    else if (t === "lasso") { ghost = ghost && ghost.poly ? ghost : { poly: [] }; ghost.poly.push(p); drawMarks(); }
    else if (t === "fill") { snapshot(); flood(p[0], p[1]); changed("заливка"); }
    else if (t === "pick") { const [i, j] = cell(p[0], p[1]); const k = j * S.W + i; selectLayer(S.paint[k] >= 0 ? S.paint[k] : S.auto[k]); setTool("brush"); }
    else if (t === "points") {
      snapshot();
      const k = S.pointKind;
      if (!Array.isArray(S.scene[k])) S.scene[k] = [];
      S.scene[k].push([+p[0].toFixed(4), +p[1].toFixed(4)]);
      changed("место: " + k);
    }
  });
  st.addEventListener("pointermove", e => {
    if (!S.pic) return;
    const p = rel(e);
    if (S.tool === "brush") { ghost = Object.assign(ghost || {}, { cursor: [p[0], p[1], (brushR() + 0.5) / S.W] }); }
    if (drag && S.tool === "brush") { strokeTo(drag.last, p, brushR()); drag.last = p; draw(); return; }
    if (drag && ghost && ghost.rect) ghost.rect = [drag.start[0], drag.start[1], p[0], p[1]];
    if (drag && ghost && ghost.ring) ghost.ring = [drag.start[0], drag.start[1], Math.abs(p[0] - drag.start[0]), Math.abs(p[1] - drag.start[1])];
    drawMarks();
  });
  st.addEventListener("pointerleave", () => { if (ghost && ghost.cursor) { delete ghost.cursor; drawMarks(); } });
  st.addEventListener("pointerup", e => {
    if (!drag) return;
    const t = S.tool;
    if (t === "brush") changed("кисть");
    else if (t === "rect" && ghost) { snapshot(); fillRect(ghost.rect); changed("прямоугольник"); }
    else if (t === "region" && ghost) {
      const [x0, y0, x1, y1] = ghost.rect;
      if (Math.abs(x1 - x0) > 0.005 && Math.abs(y1 - y0) > 0.005)
        S.regions.push({ rect: [Math.min(x0, x1), Math.min(y0, y1), Math.max(x0, x1), Math.max(y0, y1)].map(v => +v.toFixed(4)) });
    } else if (t === "ring" && ghost) {
      const [cx, cy, rx, ry] = ghost.ring;
      if (rx > 0.01 && ry > 0.005) {
        snapshot();
        S.scene.rings = (S.scene.rings || []).concat([[cx, cy, rx, ry, +$("#ringT").value / 100].map(v => +v.toFixed(4))]);
        changed("кольцо");
      }
    }
    drag = null;
    ghost = null;
    drawMarks();
  });
  st.addEventListener("dblclick", () => closeLasso());
}
function closeLasso() {
  if (S.tool !== "lasso" || !ghost || !ghost.poly || ghost.poly.length < 3) return;
  snapshot();
  fillPoly(ghost.poly);
  ghost = null;
  changed("лассо");
}
function rightClick(p) {
  // right click: take away the nearest own point (of the chosen kind) or ring
  if (S.tool === "ring" || S.tool === "points") {
    const rings = S.scene.rings || [];
    const ri = nearest(rings.map(r => [r[0], r[1]]), p);
    if (S.tool === "ring" && ri >= 0) { snapshot(); rings.splice(ri, 1); changed("кольцо убрано"); return; }
    const list = S.scene[S.pointKind];
    const i = nearest(list, p);
    if (i >= 0) { snapshot(); list.splice(i, 1); changed("место убрано"); }
  } else if (S.tool === "region") {
    const i = S.regions.findIndex(r => p[0] >= r.rect[0] && p[0] <= r.rect[2] && p[1] >= r.rect[1] && p[1] <= r.rect[3]);
    if (i >= 0) { S.regions.splice(i, 1); drawMarks(); }
  }
}
const brushR = () => +$("#brush").value / 2;

// ---------- the panels ----------
function buildLayers() {
  const box = $("#layers");
  const all = [{ id: -1, key: "auto", name: "Как найдено", what: "стереть рисунок — решает автоматика", rgb: null }].concat(S.meta.layers);
  all.forEach((l, n) => {
    const el = document.createElement("div");
    el.className = "layer";
    el.dataset.id = l.id;
    const sw = l.rgb ? `background: rgb(${l.rgb.join(",")})` : "background: repeating-linear-gradient(45deg,#666 0 3px,#333 3px 6px)";
    el.innerHTML = `<span class="k">${l.id < 0 ? "E" : l.id}</span><span class="sw" style="${sw}"></span><span><b>${escapeHtml(l.name)}</b> <span class="w">${escapeHtml(l.what)}</span></span>`;
    el.onclick = () => selectLayer(l.id);
    box.appendChild(el);
  });
  const fl = $("#foundLayer");
  for (const l of S.meta.layers) fl.insertAdjacentHTML("beforeend", `<option value="${l.id}">${escapeHtml(l.name)}</option>`);
  selectLayer(1);
}
function selectLayer(id) {
  S.layer = id;
  $$(".layer").forEach(el => el.classList.toggle("on", +el.dataset.id === id));
  if (!["brush", "rect", "lasso", "fill"].includes(S.tool)) setTool("brush");
}
function setTool(t) {
  S.tool = t;
  ghost = null;
  $$("[data-tool]").forEach(b => b.classList.toggle("on", b.dataset.tool === t));
  $("#stage").className = "tool-" + t;
  drawMarks();
}
function buildEffects() {
  const box = $("#effects");
  for (const f of S.meta.effects) {
    box.insertAdjacentHTML("beforeend", `<label><input type="checkbox" data-fx="${f.key}"> ${escapeHtml(f.name)}</label>`);
  }
  box.addEventListener("change", e => {
    const k = e.target.dataset.fx;
    if (!k) return;
    snapshot();
    const fx = Object.assign({}, S.scene.effects || {});
    if (e.target.checked) delete fx[k]; else fx[k] = false;
    S.scene.effects = Object.keys(fx).length ? fx : undefined;
    changed("эффекты");
  });
}
function buildPointKinds() {
  const box = $("#pointKinds");
  for (const [k, name] of Object.entries(S.meta.points)) {
    const b = document.createElement("button");
    b.dataset.kind = k;
    b.textContent = { rims: "камешек", eyes: "глаз", ponds: "круги", lights: "огонёк" }[k] || k;
    b.title = name;
    b.onclick = () => { S.pointKind = k; setTool("points"); syncPointKinds(); };
    box.appendChild(b);
  }
  syncPointKinds();
}
function syncPointKinds() {
  $$("#pointKinds button").forEach(b => b.classList.toggle("on", b.dataset.kind === S.pointKind && S.tool === "points"));
  drawMarks();
}
function syncFxUi() {
  const fx = S.scene.effects || {};
  $$("[data-fx]").forEach(c => c.checked = fx[c.dataset.fx] !== false);
  const na = typeof S.scene.night !== "number";
  $("#nightAuto").checked = na;
  $("#night").disabled = na;
  $("#night").value = Math.round((na ? S.info.night || 0 : S.scene.night) * 100);
  $("#nightV").textContent = $("#night").value + "%";
  const aa = typeof S.scene.axis !== "number";
  $("#axisAuto").checked = aa;
  $("#axis").disabled = aa;
  $("#axis").value = Math.round((aa ? (S.info.water && S.info.water.axis) || 0.65 : S.scene.axis) * 100);
  $("#axisV").textContent = $("#axis").value + "%";
  $("#mirror").value = typeof S.scene.mirror === "boolean" ? (S.scene.mirror ? "on" : "off") : "auto";
}

function bindUi() {
  bindStage();
  $("#search").oninput = renderList;
  $$(".tabs button").forEach(b => b.onclick = () => {
    $$(".tabs button").forEach(x => x.classList.toggle("on", x === b));
    $$(".tab").forEach(t => t.hidden = t.id !== "tab-" + b.dataset.tab);
    if (b.dataset.tab === "points" && S.tool !== "ring") { setTool("points"); syncPointKinds(); }
    if (b.dataset.tab === "claude") setTool("region");
    if (b.dataset.tab === "paint" && !["brush", "rect", "lasso", "fill", "pick"].includes(S.tool)) setTool("brush");
  });
  $$("[data-tool]").forEach(b => b.onclick = () => setTool(b.dataset.tool));
  $("#brush").oninput = () => $("#brushV").textContent = $("#brush").value;
  $("#tol").oninput = () => $("#tolV").textContent = $("#tol").value;
  $("#view").onchange = () => { S.view = $("#view").value; draw(); };
  $("#opacity").oninput = () => { S.opacity = $("#opacity").value / 100; draw(); };
  $("#zoom").oninput = () => { S.zoom = $("#zoom").value / 100; $("#zoomV").textContent = $("#zoom").value + "%"; layout(); };
  $("#btnFoundTo").onclick = () => {
    const from = +$("#foundLayer").value;
    snapshot();
    let n = 0;
    for (let i = 0; i < S.W * S.H; i++) if (S.auto[i] === from) { S.paint[i] = S.layer; n++; }
    changed("найденное → слой");
    status(`перекрашено клеток: ${n}`);
  };
  $("#btnClearPaint").onclick = () => { if (!confirm("Стереть весь свой рисунок слоёв?")) return; snapshot(); S.paint.fill(-1); changed("рисунок стёрт"); };
  $("#nightAuto").onchange = () => { snapshot(); S.scene.night = $("#nightAuto").checked ? undefined : $("#night").value / 100; syncFxUi(); changed("ночь"); };
  $("#night").onchange = () => { snapshot(); S.scene.night = $("#night").value / 100; syncFxUi(); changed("ночь"); };
  $("#axisAuto").onchange = () => { snapshot(); S.scene.axis = $("#axisAuto").checked ? undefined : $("#axis").value / 100; syncFxUi(); changed("линия воды"); };
  $("#axis").onchange = () => { snapshot(); S.scene.axis = $("#axis").value / 100; syncFxUi(); changed("линия воды"); };
  $("#mirror").onchange = () => { snapshot(); const v = $("#mirror").value; S.scene.mirror = v === "auto" ? undefined : v === "on"; changed("отражение"); };
  $$("[data-poke]").forEach(b => b.onclick = () => api("/api/poke?kind=" + b.dataset.poke, { method: "POST" }));
  $("#btnPointsFound").onclick = () => { snapshot(); S.scene[S.pointKind] = (S.found[S.pointKind] || []).slice(); changed("места"); };
  $("#btnPointsClear").onclick = () => { snapshot(); S.scene[S.pointKind] = undefined; changed("места"); };
  $("#btnRegionsClear").onclick = () => { S.regions = []; drawMarks(); };
  $("#btnSend").onclick = sendRequest;
  $("#btnSave").onclick = () => save();
  $("#btnUndo").onclick = () => restore(S.undo, S.redo);
  $("#btnRedo").onclick = () => restore(S.redo, S.undo);
  $("#btnRevert").onclick = async () => {
    if (!S.pic || !confirm("Вернуть файл сцены к прошлому сохранению?")) return;
    await api("/api/undo?pic=" + encodeURIComponent(S.pic), { method: "POST" });
    reload("откатил файл");
  };
  $("#btnShow").onclick = async () => { const r = await api("/api/show?pic=" + encodeURIComponent(S.pic), { method: "POST" }); status(r.body.ok ? "поставил на " + r.body.screen : "✕ " + (r.body.out || r.body.error)); };
  $("#btnFolder").onclick = () => api("/api/open?pic=" + encodeURIComponent(S.pic), { method: "POST" });
  document.addEventListener("keydown", e => {
    if (e.target.matches("input[type=text], input:not([type]), textarea, select")) return;
    const k = e.key.toLowerCase();
    if ((e.ctrlKey || e.metaKey) && k === "s") { e.preventDefault(); save(); return; }
    if ((e.ctrlKey || e.metaKey) && k === "z") { e.preventDefault(); e.shiftKey ? restore(S.redo, S.undo) : restore(S.undo, S.redo); return; }
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    if (k === "enter") closeLasso();
    else if (k === "escape") { ghost = null; drawMarks(); }
    else if ({ b: 1, r: 1, l: 1, f: 1, i: 1 }[k]) setTool({ b: "brush", r: "rect", l: "lasso", f: "fill", i: "pick" }[k]);
    else if (k === "e") selectLayer(-1);
    else if (/^[0-6]$/.test(k)) selectLayer(+k);
    else if (k === "[" || k === "]") { $("#brush").value = +$("#brush").value + (k === "]" ? 1 : -1); $("#brush").oninput(); }
  });
}

// ---------- saving, and changes from elsewhere ----------
async function save(force) {
  if (!S.pic || !S.dirty || S.saving) return;
  clearTimeout(S.saveTimer);
  S.saving = true;
  saveState("сохраняю…");
  const body = { base: force ? null : S.mtime, force: !!force, what: S.lastWhat, paint: gridToB64(S.paint) };
  for (const k of ["effects", "rings", "night", "axis", "mirror", "rims", "eyes", "ponds", "lights"])
    body[k] = S.scene[k] === undefined ? null : S.scene[k];
  try {
    const r = await api("/api/scene?pic=" + encodeURIComponent(S.pic), { method: "PUT", body: JSON.stringify(body) });
    if (r.status === 409) {
      banner(`Сцену только что поменял ${r.body.who === "claude" ? "Claude" : r.body.who}, а у тебя несохранённые правки.`,
        [["Взять его версию", () => reload("взял чужую версию")], ["Оставить мою", () => save(true)]]);
      saveState("конфликт");
    } else {
      S.mtime = r.body.mtime;
      S.dirty = false;
      saveState("сохранено ✓ — рабочий стол подхватит");
      markListScene();
    }
  } catch (e) {
    saveState("✕ " + e.message);
  } finally {
    S.saving = false;
  }
}
function markListScene() {
  const p = S.pics.find(x => x.path === S.pic);
  if (p && !p.scene) { p.scene = true; renderList(); }
}
async function reload(why) {
  banner(null);
  const d = (await api("/api/scene?pic=" + encodeURIComponent(S.pic))).body;
  applyScene(d);
  if (why) status(why);
}
async function poll() {
  if (document.hidden) return;
  try {
    const st = (await api("/api/state?pic=" + encodeURIComponent(S.pic || ""))).body;
    if (S.pic && st.mtime !== S.mtime && !S.saving) {
      const who = st.last && st.last.picture === S.pic ? st.last.who : "?";
      if (!S.dirty) {
        await reload(who === "claude" ? "✦ Claude поменял сцену: " + (st.last.what || "") : "сцена изменилась снаружи — загрузил");
        if (who === "claude") flash();
      } else if (!$("#banner").textContent) {
        banner(`${who === "claude" ? "Claude" : "Кто-то"} поменял эту сцену, а у тебя несохранённые правки.`,
          [["Взять его версию", () => reload("взял чужую версию")], ["Оставить мою", () => save(true)]]);
      }
    }
    if (st.requests !== S.reqMtime) { S.reqMtime = st.requests; refreshRequests(); }
  } catch (e) { /* the server went away: the window is about to close */ }
}
function flash() {
  const st = $("#stage");
  st.animate([{ outline: "3px solid #c8a8ff" }, { outline: "3px solid transparent" }], { duration: 1200 });
}

// ---------- Claude ----------
async function sendRequest() {
  const note = $("#note").value.trim();
  if (!S.pic) return;
  if (!note && !S.regions.length) return status("напиши, что сделать, или обведи место");
  if (S.dirty) await save();
  await api("/api/requests", { method: "POST", body: JSON.stringify({ pic: S.pic, note, regions: S.regions }) });
  $("#note").value = "";
  S.regions = [];
  drawMarks();
  status("✓ отдано Claude — скажи ему в терминале «посмотри запросы сцены» (или он увидит их сам через MCP)");
  refreshRequests();
}
async function refreshRequests() {
  const r = (await api("/api/requests")).body.requests;
  S.reqs = r;
  const open = r.filter(q => q.status !== "done").length;
  $("#reqCount").textContent = open ? "· " + open : "";
  const box = $("#requests");
  box.innerHTML = r.length ? "" : '<div class="dim">пока ничего</div>';
  for (const q of r.slice(0, 20)) {
    const el = document.createElement("div");
    el.className = "req";
    const st = { new: "ждёт", working: "Claude работает", done: "готово" }[q.status] || q.status;
    el.innerHTML = `<div class="h"><span class="st ${q.status}">${st}</span><span>${escapeHtml(q.created)}</span><span class="grow"></span><a href="#" class="go">${escapeHtml(q.picture.split("/").pop())}</a></div>
      <div class="note"></div>${q.regions.length ? `<div class="dim">областей: ${q.regions.length}</div>` : ""}${q.reply ? '<div class="reply"></div>' : ""}`;
    el.querySelector(".note").textContent = q.note || "(без текста)";
    if (q.reply) el.querySelector(".reply").textContent = "✦ " + q.reply;
    el.querySelector(".go").onclick = e => { e.preventDefault(); openPic(q.picture).then(() => { S.regions = q.regions.slice(); drawMarks(); }); };
    if (q.status !== "done") {
      const b = document.createElement("button");
      b.textContent = "закрыть";
      b.onclick = () => api("/api/requests/" + q.id, { method: "POST", body: JSON.stringify({ status: "done" }) }).then(refreshRequests);
      el.appendChild(b);
    }
    box.appendChild(el);
  }
}

// ---------- small things ----------
function status(t) { $("#status").textContent = t; }
function saveState(t) { $("#saveState").textContent = t; }
function banner(text, actions) {
  const b = $("#banner");
  if (!text) { b.hidden = true; b.textContent = ""; layout(); return; }
  b.innerHTML = `<span class="grow"></span>`;
  b.firstChild.textContent = text;
  for (const [label, fn] of actions || []) {
    const btn = document.createElement("button");
    btn.textContent = label;
    btn.onclick = () => { banner(null); fn(); };
    b.appendChild(btn);
  }
  b.hidden = false;
  if (S.pic) layout();
}
window.addEventListener("beforeunload", () => { if (S.dirty) navigator.sendBeacon && save(); });
boot();
