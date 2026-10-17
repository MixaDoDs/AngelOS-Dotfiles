// Smoke test: colour engine (theme.js) + colour editor (settings extension),
// plus color.ini against the COLOR_KEYS defaults.
// Runs in Node on a minimal fake DOM, so it proves the logic, not the look:
// Spotify's DOM and user.css are only checked inside Spotify.
//   node tests/integration/colors-smoke.js
const fs = require("fs");
const path = require("path");
const ROOT = process.argv[2] || path.resolve(__dirname, "..", "..");

let failures = 0;
const ok = (cond, msg) => { if (!cond) { failures++; console.log("FAIL", msg); } else console.log("ok  ", msg); };

// permissive stub for APIs we do not model
function anyProxy(name = "any") {
  const fn = function () { return anyProxy(name + "()"); };
  return new Proxy(fn, {
    get(t, p) {
      if (p === Symbol.toPrimitive) return () => "";
      if (p === "then") return undefined;
      if (p in t) return t[p];
      return anyProxy(name + "." + String(p));
    },
    apply() { return anyProxy(name + "()"); },
    construct() { return anyProxy("new " + name); },
  });
}

class Style {
  constructor() { this._p = {}; }
  setProperty(k, v) { this._p[k] = String(v); }
  removeProperty(k) { delete this._p[k]; }
  getPropertyValue(k) { return this._p[k] || ""; }
  get cssText() { return Object.entries(this._p).map(([k, v]) => `${k}: ${v};`).join(" "); }
  set cssText(v) {}
}
class ClassList {
  constructor() { this.s = new Set(); }
  add(...c) { c.forEach(x => this.s.add(x)); }
  remove(...c) { c.forEach(x => this.s.delete(x)); }
  toggle(c, f) { const on = f === undefined ? !this.s.has(c) : !!f; if (on) this.s.add(c); else this.s.delete(c); return on; }
  contains(c) { return this.s.has(c); }
}
let active = null;
class El {
  constructor(tag) {
    this.tagName = tag.toUpperCase();
    this.children = []; this.parentNode = null;
    this.style = new Style(); this.classList = new ClassList();
    this.dataset = {}; this._l = {}; this._text = "";
    this.value = ""; this.id = "";
  }
  set className(v) { this.classList = new ClassList(); String(v).split(/\s+/).filter(Boolean).forEach(c => this.classList.add(c)); }
  get className() { return [...this.classList.s].join(" "); }
  set textContent(v) { this.children = []; this._text = String(v); }
  get textContent() { return this._text + this.children.map(c => c.textContent).join(""); }
  set innerHTML(v) { this.children = []; this._html = String(v); }
  get innerHTML() { return this._html || ""; }
  appendChild(c) { if (c.parentNode) c.remove(); c.parentNode = this; this.children.push(c); return c; }
  append(...cs) { cs.forEach(c => this.appendChild(c)); }
  replaceChildren(...cs) { this.children = []; this._text = ""; this.append(...cs); }
  prepend(c) { if (c.parentNode) c.remove(); c.parentNode = this; this.children.unshift(c); }
  insertBefore(c, ref) { if (c.parentNode) c.remove(); c.parentNode = this; const i = this.children.indexOf(ref); this.children.splice(i < 0 ? this.children.length : i, 0, c); return c; }
  removeChild(c) { const i = this.children.indexOf(c); if (i >= 0) this.children.splice(i, 1); c.parentNode = null; return c; }
  remove() { if (this.parentNode) this.parentNode.removeChild(this); }
  get nextSibling() { const p = this.parentNode; if (!p) return null; return p.children[p.children.indexOf(this) + 1] || null; }
  addEventListener(t, f) { (this._l[t] = this._l[t] || []).push(f); }
  removeEventListener(t, f) { this._l[t] = (this._l[t] || []).filter(x => x !== f); }
  dispatch(t, ev = {}) {
    ev.type = t; ev.target = ev.target || this; ev.preventDefault = () => {}; ev.stopPropagation = () => {};
    (this._l[t] || []).slice().forEach(f => f(ev));
    if (typeof this["on" + t] === "function") this["on" + t](ev);
  }
  click() { this.dispatch("click"); }
  focus() { if (active && active !== this) active.blur(); active = this; }
  blur() { if (active === this) { active = null; this.dispatch("blur"); } }
  setPointerCapture() {}
  getBoundingClientRect() { return { left: 0, top: 0, width: 200, height: 100, right: 200, bottom: 100 }; }
  closest() { return null; }
  matches() { return false; }
  setAttribute(k, v) { this["attr_" + k] = v; }
  getAttribute(k) { return this["attr_" + k] ?? null; }
  _all() { return this.children.flatMap(c => [c, ...c._all()]); }
  querySelectorAll(sel) {
    if (/^\.[\w-]+$/.test(sel)) return this._all().filter(e => e.classList.contains(sel.slice(1)));
    if (/^[a-z]+$/.test(sel)) return this._all().filter(e => e.tagName === sel.toUpperCase());
    return [];
  }
  querySelector(sel) { return this.querySelectorAll(sel)[0] || null; }
}

const documentElement = new El("html");
const head = new El("head");
const body = new El("body");
documentElement.append(head, body);
const document = {
  documentElement, head, body,
  createElement: t => new El(t),
  createElementNS: (ns, t) => new El(t),
  createTextNode: s => { const e = new El("#text"); e.textContent = s; return e; },
  getElementById: id => documentElement._all().find(e => e.id === id) || null,
  querySelector: s => documentElement.querySelector(s),
  querySelectorAll: s => documentElement.querySelectorAll(s),
  addEventListener: (t, f) => documentElement.addEventListener(t, f),
  removeEventListener: (t, f) => documentElement.removeEventListener(t, f),
  get activeElement() { return active; },
};

const store = new Map();
let topbarButtons = [];
const notes = [];
const Spicetify = new Proxy({
  LocalStorage: {
    get: k => (store.has(k) ? store.get(k) : null),
    set: (k, v) => store.set(k, String(v)),
    remove: k => store.delete(k),
  },
  Player: new Proxy({ addEventListener() {}, removeEventListener() {}, data: null }, { get: (t, p) => (p in t ? t[p] : anyProxy("Player." + String(p))) }),
  Platform: new Proxy({ version: "1.3.0" }, { get: (t, p) => (p in t ? t[p] : anyProxy("Platform." + String(p))) }),
  Topbar: { Button: class { constructor(label, icon, onClick) { this.element = new El("button"); topbarButtons.push({ label, icon, onClick }); } } },
  showNotification: (m, err) => notes.push((err ? "ERR " : "") + m),
}, { get: (t, p) => (p in t ? t[p] : anyProxy("Spicetify." + String(p))) });

const g = globalThis;
Object.assign(g, {
  document, Spicetify,
  window: g,
  localStorage: { length: 0, key: () => null, getItem: () => null, setItem() {}, removeItem() {} },
  getComputedStyle: el => ({ getPropertyValue: k => el.style.getPropertyValue(k) }),
  requestAnimationFrame: cb => setTimeout(cb, 0),
  cancelAnimationFrame: id => clearTimeout(id),
  MutationObserver: class { observe() {} disconnect() {} },
  confirm: () => true,
  innerWidth: 1600, innerHeight: 900,
  Document: class { },
});
g.Document.prototype.querySelectorAll = document.querySelectorAll;
g.addEventListener = () => {}; g.removeEventListener = () => {};
// Node has its own read-only navigator; replace it so ceCopy reaches the fake clipboard
Object.defineProperty(g, "navigator", { configurable: true, value: { clipboard: { writeText: t => { g.__clip = t; return Promise.resolve(); } } } });

const run = f => { try { eval(fs.readFileSync(path.join(ROOT, f), "utf8")); } catch (e) { console.log("THROW in", f, e.stack); failures++; } };
const tick = (ms = 30) => new Promise(r => setTimeout(r, ms));
const rootVar = k => documentElement.style.getPropertyValue(k);

// color.ini must hold the same defaults as COLOR_KEYS (plain hex keys only)
function checkColorIni() {
  const ini = fs.readFileSync(path.join(ROOT, "color.ini"), "utf8").split("[VantagraphBlack]")[1] || "";
  const iniMap = {};
  ini.split(/\r?\n/).forEach(l => { const m = /^\s*([a-z-]+)\s*=\s*([0-9A-Fa-f]{6})\s*$/.exec(l); if (m) iniMap[m[1]] = "#" + m[2].toUpperCase(); });
  const hexKeys = g.VantagraphCustomData.COLOR_KEYS.filter(d => d.value && d.value[0] === "#");
  const bad = hexKeys.filter(d => iniMap[d.key] !== d.value).map(d => d.key)
    .concat(Object.keys(iniMap).filter(k => !hexKeys.some(d => d.key === k)));
  ok(!bad.length, `color.ini matches COLOR_KEYS (${hexKeys.length} hex keys)` + (bad.length ? " differs: " + bad.join(", ") : ""));
}

(async () => {
  store.set("vantagraph-custom:colors", JSON.stringify({ panel: "#101010", bogus: "#fff", text: "not a colour", "menu-text": "rgba(255,0,0,.5)" }));
  run("theme.js");
  await tick(400);
  const V = g.VantagraphCustomData;
  ok(!!V, "VantagraphCustomData exported");
  checkColorIni();
  const C = V.color;

  // colour math
  ok(C.format(C.parse("#abc")) === "#AABBCC", "parse #abc");
  ok(C.format(C.parse("80808080")) === "rgba(128, 128, 128, 0.502)", "parse 8-digit hex without #");
  ok(C.format(C.parse("rgb(255 0 0 / 50%)")) === "rgba(255, 0, 0, 0.5)", "parse rgb space syntax");
  ok(C.format(C.parse("rgba(0,0,0,.35)")) === "rgba(0, 0, 0, 0.35)", "parse rgba");
  ok(C.format(C.parse("hsl(120, 100%, 25%)")) === "#008000", "parse hsl");
  ok(C.parse("rgb(1,2)") === null && C.parse("red") === null && C.parse("") === null && C.parse("#12345") === null, "rejects bad input");
  ok(C.toHex(C.parse("rgba(255, 0, 0, 0.5)")) === "#FF000080", "toHex with alpha");
  ok(C.toHsl(C.parse("#008000")) === "hsl(120, 100%, 25%)", "toHsl");
  let rt = true;
  for (let i = 0; i < 2000; i++) {
    const c = { r: (i * 37) % 256, g: (i * 91) % 256, b: (i * 53) % 256, a: 1 };
    const h = C.rgbToHsv(c); const back = C.hsvToRgb(h.h, h.s, h.v);
    if (back.r !== c.r || back.g !== c.g || back.b !== c.b) { rt = false; console.log("  hsv roundtrip", c, back); break; }
  }
  ok(rt, "rgb -> hsv -> rgb round trip (2000 colours)");

  // engine: load + sanitise + apply
  ok(rootVar("--spice-panel") === "#101010" && rootVar("--spice-main") === "#101010", "stored panel applied to panel + main alias");
  ok(rootVar("--spice-rgb-main") === "16,16,16", "rgb alias written");
  ok(rootVar("--spice-text") === "#F0F5F2", "invalid stored text ignored, default used");
  ok(rootVar("--vg-menu-text") === "rgba(255, 0, 0, 0.5)", "linked key override applied");
  ok(rootVar("--vg-play-icon") === "#101010", "play-icon follows panel");
  ok(rootVar("--vg-ui-panel") === "#101010", "opaque ui copy written");
  ok(rootVar("--spice-progress-bg-alpha") === "rgba(1, 1, 1, 0.35)", "progress bg alpha derived");
  ok(rootVar("--spice-rgb-text") === "240,245,242" && rootVar("--spice-rgb-selected-row") === "255,255,255" && rootVar("--spice-rgb-shadow") === "0,0,0", "Spicetify rgb vars used by Spotify CSS");

  V.setColor("panel", "rgba(20, 30, 40, 0.5)");
  ok(rootVar("--spice-panel") === "rgba(20, 30, 40, 0.5)" && rootVar("--vg-play-icon") === "rgba(20, 30, 40, 0.5)", "setColor updates key + follower");
  ok(rootVar("--vg-ui-panel") === "#141E28", "ui copy stays opaque");
  V.setColor("accent", "#B0B5B0");
  ok(!("accent" in V.getColorOverrides()), "value equal to default drops the override");
  ok(V.setColor("accent", "nope") === false, "setColor rejects garbage");
  body.classList.add("vg-bg-active");
  documentElement.style.setProperty("--spice-main", "transparent");
  V.setColor("panel", "#222222");
  ok(rootVar("--spice-main") === "transparent" && rootVar("--spice-panel") === "#222222", "bg mode keeps --spice-main transparent");
  body.classList.remove("vg-bg-active");
  V.applyColors();
  ok(rootVar("--spice-main") === "#222222", "leaving bg mode restores main");
  await tick(300);
  ok(JSON.parse(store.get("vantagraph-custom:colors")).panel === "#222222", "overrides saved (debounced)");

  // settings panel + editor
  run("Extensions/vantagraph-custom-settings.js");
  await tick(300);
  const btn = topbarButtons.find(b => b.label === "Vantagraph Custom");
  ok(!!btn, "topbar button registered as 'Vantagraph Custom'");
  ok(/viewBox="0 0 32.02 31.55"/.test(btn.icon), "settings button uses embedded vantagraph-theme icon");
  btn.onClick();
  const panel = body.querySelector(".vg-sp");
  ok(panel && panel.classList.contains("open"), "panel opens");
  const rows = panel.querySelectorAll(".vg-ce-row");
  ok(rows.length === V.COLOR_KEYS.length, `editor lists every colour (${rows.length}/${V.COLOR_KEYS.length})`);
  ok(panel.querySelectorAll(".vg-ce-grp").length === V.COLOR_GROUPS.length, "one group per colour group");

  // open picker on "text"
  const rowOf = key => rows[V.COLOR_KEYS.findIndex(d => d.key === key)];
  rowOf("text").querySelector(".vg-ce-sw").click();
  const pk = panel.querySelector(".vg-ce-pk");
  ok(!!pk, "picker opens");
  const txt = pk.querySelector(".vg-ce-in");
  ok(txt.value === "#F0F5F2", "picker shows current value");

  // drag saturation/value to the bottom-left corner -> black
  const sv = pk.querySelector(".vg-ce-sv");
  sv.dispatch("pointerdown", { button: 0, clientX: 0, clientY: 100, pointerId: 1 });
  sv.dispatch("pointermove", { clientX: 0, clientY: 100 });
  sv.dispatch("pointerup", {});
  await tick();
  ok(rootVar("--spice-text") === "#000000", "SV drag applies colour");
  ok(rootVar("--vg-menu-text") === "rgba(255, 0, 0, 0.5)", "overridden follower keeps its own value");

  // alpha drag to half
  const al = pk.querySelector(".vg-ce-alpha");
  al.dispatch("pointerdown", { button: 0, clientX: 100, clientY: 5, pointerId: 1 });
  al.dispatch("pointerup", {});
  await tick();
  ok(rootVar("--spice-text") === "rgba(0, 0, 0, 0.5)", "alpha drag gives rgba");

  // typed value in any format
  txt.focus(); txt.value = "rgb(10, 20, 30)"; txt.dispatch("input"); txt.dispatch("keydown", { key: "Enter" });
  await tick();
  ok(rootVar("--spice-text") === "#0A141E", "typed rgb() applied on Enter");
  txt.focus(); txt.value = "#zzz"; txt.dispatch("input");
  ok(txt.classList.contains("bad"), "invalid typed value flagged");
  txt.blur();
  ok(rootVar("--spice-text") === "#0A141E", "invalid typed value not applied");

  // number fields
  const nums = pk.querySelectorAll("input").filter(i => i.type === "number");
  nums[0].focus(); nums[0].value = "255"; nums[0].dispatch("input"); nums[0].blur();
  await tick();
  ok(rootVar("--spice-text") === "#FF141E", "R field applied");
  nums[3].focus(); nums[3].value = "40"; nums[3].dispatch("input"); nums[3].blur();
  await tick();
  ok(rootVar("--spice-text") === "rgba(255, 20, 30, 0.4)", "A field applied");

  // undo / redo through the keyboard handler
  const undoCount = () => panel.querySelectorAll(".vg-ce-b").find(b => b.textContent.includes("Undo"));
  document.documentElement.dispatch("keydown", { key: "z", ctrlKey: true, target: body });
  await tick();
  ok(rootVar("--spice-text") === "#FF141E", "Ctrl+Z undoes last change");
  document.documentElement.dispatch("keydown", { key: "y", ctrlKey: true, target: body });
  await tick();
  ok(rootVar("--spice-text") === "rgba(255, 20, 30, 0.4)", "Ctrl+Y redoes it");
  ok(undoCount().disabled === false, "undo button enabled");

  // format switch
  pk.querySelectorAll("button").find(b => b.textContent === "HSL").click();
  ok(/^hsla\(/.test(pk.querySelector(".vg-ce-in").value), "HSL format shown");
  pk.querySelectorAll("button").find(b => b.textContent === "HEX").click();

  // reset one row, linked row re-links
  const menuRow = rowOf("menu-text");
  menuRow.querySelectorAll(".vg-ce-ib")[1].click();
  await tick();
  ok(rootVar("--vg-menu-text") === rootVar("--spice-text"), "reset re-links Menu Text to Text");
  ok(menuRow.querySelector(".vg-ce-val").textContent.includes("Text"), "row shows the link");

  // find (flash) restores afterwards
  const before = rootVar("--spice-accent");
  rowOf("accent").querySelectorAll(".vg-ce-ib")[0].click();
  await tick(200);
  ok(rootVar("--spice-accent") !== before, "find blinks the colour");
  await tick(1300);
  ok(rootVar("--spice-accent") === before, "find restores the colour");

  // export / import
  const share = panel.querySelectorAll(".vg-ce-b").find(b => b.textContent.includes("Share"));
  share.click();
  const ta = panel.querySelector("textarea");
  panel.querySelectorAll(".vg-ce-b").find(b => b.textContent === "Copy palette").click();
  await tick();
  const exported = JSON.parse(ta.value);
  ok(exported.colors.text === "rgba(255, 20, 30, 0.4)" && !("menu-text" in exported.colors), "export has values, skips linked keys");
  ta.value = "[MyScheme]\n; comment\npanel = 123456\naccent: #ff0000 ; red\nnope = 000000\nheart = zzz";
  panel.querySelectorAll(".vg-ce-b").find(b => b.textContent === "Load pasted palette").click();
  await tick();
  ok(rootVar("--spice-panel") === "#123456" && rootVar("--spice-accent") === "#FF0000", "color.ini style import");
  ok(rootVar("--spice-text") === "#F0F5F2", "import replaces the rest with defaults");
  ok(notes.some(n => /2 colours, 2 skipped/.test(n)), "import reports skipped lines");
  ta.value = JSON.stringify({ colors: { window: "rgba(1,2,3,0.4)" } });
  panel.querySelectorAll(".vg-ce-b").find(b => b.textContent === "Load pasted palette").click();
  await tick();
  ok(rootVar("--spice-window") === "rgba(1, 2, 3, 0.4)" && rootVar("--spice-sidebar") === "rgba(1, 2, 3, 0.4)", "JSON import incl. alias");
  document.documentElement.dispatch("keydown", { key: "z", ctrlKey: true, target: body });
  await tick();
  ok(rootVar("--spice-panel") === "#123456", "undo after import restores previous palette");

  // example palette in the share panel
  const btnText = t => panel.querySelectorAll(".vg-ce-b").find(b => b.textContent === t);
  ok(/panel\s+= #171120/.test(panel.querySelector(".vg-ce-ex-code").textContent), "example is shown");
  btnText("Copy example").click();
  await tick();
  ok(/bar-bg\s+= rgba\(199, 155, 255, 0\.2\)/.test(g.__clip || ""), "example copied to clipboard");
  btnText("Try it").click();
  await tick();
  ok(rootVar("--spice-panel") === "#171120" && rootVar("--spice-progress-bg") === "rgba(199, 155, 255, 0.2)", "Try it loads the example");
  ok(notes.some(n => /^Palette loaded: 17 colours$/.test(n)), "example loads 17 colours, none skipped");
  document.documentElement.dispatch("keydown", { key: "z", ctrlKey: true, target: body });
  await tick();
  ok(rootVar("--spice-panel") === "#123456", "undo after Try it");
  ok(rows[0].querySelector(".vg-ce-key").textContent === "window", "rows show their key");
  ok(V.FONT_PRESETS.map(p => p.name).join() === "Spotify Default,Inter,JetBrains Mono", "three font presets");

  // search filter
  const q = panel.querySelector(".vg-ce-q");
  q.value = "glass"; q.dispatch("input");
  const visible = rows.filter(r => r.parentNode.style.display !== "none").length;
  ok(visible === 6, `search 'glass' shows 6 rows (${visible})`);
  q.value = "zzzz"; q.dispatch("input");
  ok(panel.querySelector(".vg-ce-empty").style.display === "", "empty message on no match");
  q.value = ""; q.dispatch("input");

  // reset colours button
  panel.querySelectorAll(".vg-ce-b").find(b => b.textContent === "Reset colours").click();
  await tick();
  ok(Object.keys(V.getColorOverrides()).length === 0 && rootVar("--spice-panel") === "#080808", "reset colours -> VantagraphBlack");

  // full reset from the bottom button
  V.setColor("heart", "#00FF00");
  panel.querySelector(".vg-rb").click();
  await tick(300);
  ok(rootVar("--spice-heart") === "#FF1040" && rootVar("--vg-ui-panel") === "#080808", "Reset to Defaults rewrites default colours");

  // other tabs still render
  for (const label of ["Font", "Layout", "BG", "Snippets", "Colors"]) {
    const tab = panel.querySelectorAll(".vg-tab").find(b => b.textContent.includes(label));
    try { tab.click(); ok(true, "tab renders: " + label); } catch (e) { ok(false, "tab " + label + " threw " + e.message); }
  }
  ok(!panel.querySelectorAll(".vg-ri").some(r => /WARNING/.test(r.textContent)), "no BG warning");

  console.log(failures ? `\n${failures} FAILED` : "\nALL PASSED");
  process.exit(failures ? 1 : 0);
})();
