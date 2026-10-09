// Vantagraph Custom Settings - center modal with the colour editor
// (CSS injected here, deps: window.VantagraphCustomData)
//
// Written by Miabeyefendi - part of the Vantagraph Custom Spicetify theme.
// Repository: https://github.com/Miabeyefendi/Vantagraph-Custom

(function vantagraphSettings() {

  // wait for theme.js + Spicetify APIs
  function waitForVantagraphCustomData(cb) {
    if (window.VantagraphCustomData && Spicetify && Spicetify.Player && Spicetify.Platform && Spicetify.LocalStorage && Spicetify.Topbar) cb();
    else setTimeout(() => waitForVantagraphCustomData(cb), 100);
  }

  let panelEl = null;
  let activeTab = "colors";
  const TABS = [
    { id: "colors",     label: "🎨 Colors" },
    { id: "typography", label: "✏️ Font" },
    { id: "layout",     label: "📐 Layout" },
    { id: "background", label: "🖼️ BG" },
    { id: "snippets",   label: "✂️ Snippets" },
  ];

  // inject panel CSS once
  function ensureStyles() {
    if (document.getElementById("vg-settings-css")) return;
    const s = document.createElement("style");
    s.id = "vg-settings-css";
    s.textContent = `
.vg-sp{overflow:clip;position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);z-index:9999;width:clamp(440px, 35vw, 720px);max-height:85vh;background:var(--vg-ui-panel,#121212);border:1px solid var(--vg-ui-stroke,#1A1A1A);border-radius:14px;display:none;flex-direction:column;box-shadow:0 20px 60px rgba(0,0,0,.7)}
.vg-sp.open{display:flex}
.vg-sh{display:flex;flex-shrink:0;align-items:center;justify-content:space-between;padding:12px 16px;background:var(--vg-ui-panel,#121212);border-bottom:1px solid var(--vg-ui-stroke,#1A1A1A)}
.vg-sh span{font-size:15px;font-weight:600;color:var(--vg-ui-text,#FFF);letter-spacing:.5px}
.vg-sh button{width:24px;height:24px;border-radius:50%;border:none;background:var(--vg-ui-stroke,#1A1A1A);color:var(--vg-ui-subtext,#A7A7A7);cursor:pointer;display:flex;align-items:center;justify-content:center;font-size:13px;transition:all .15s}
.vg-sh button:hover{background:#E22134;color:var(--vg-ui-text,#FFF)}
.vg-tabs{display:flex;flex-shrink:0;border-bottom:1px solid var(--vg-ui-stroke,#1A1A1A);background:var(--vg-ui-panel,#121212);overflow-x:auto;scrollbar-width:none}
.vg-tabs::-webkit-scrollbar{display:none}
.vg-tab{padding:10px 14px;font-size:12px;font-weight:500;color:var(--vg-ui-subtext,#A7A7A7);cursor:pointer;border:none;background:none;border-bottom:2px solid transparent;transition:all .15s;white-space:nowrap;flex-shrink:0}
.vg-tab:hover{color:var(--vg-ui-accent,#1ED760);background:var(--vg-ui-panel-hover,#242424)}
.vg-tab.on{color:var(--vg-ui-accent,#1ED760);border-bottom-color:var(--vg-ui-accent,#1DB954)}
.vg-sc{flex:1;padding:12px 16px;overflow-y:auto;min-height:0;scrollbar-width:thin;scrollbar-color:var(--vg-ui-stroke,#1A1A1A) transparent}
.vg-sc::-webkit-scrollbar{width:4px}
.vg-sc::-webkit-scrollbar-thumb{background:var(--vg-ui-stroke,#1A1A1A);border-radius:4px}
.vg-acc{margin-bottom:8px;border:1px solid var(--vg-ui-stroke,#1A1A1A);border-radius:8px;overflow:hidden}
.vg-ach{display:flex;align-items:center;justify-content:space-between;padding:10px 14px;background:var(--vg-ui-panel,#121212);cursor:pointer;user-select:none;transition:background .15s}
.vg-ach:hover{background:var(--vg-ui-panel-hover,#242424)}
.vg-ach span:first-child{font-size:13px;font-weight:600;color:var(--vg-ui-text,#FFF)}
.vg-ach span:last-child{font-size:11px;color:var(--vg-ui-subtext,#A7A7A7);transition:transform .2s}
.vg-acc.open .vg-ach span:last-child{transform:rotate(180deg)}
.vg-ab{max-height:0;overflow:hidden;transition:max-height .25s ease}
.vg-acc.open .vg-ab{max-height:600px}
.vg-ai{padding:10px 14px}
.vg-rl{display:flex;flex-direction:column;gap:4px}
.vg-ri{display:flex;align-items:center;gap:10px;padding:8px 10px;border-radius:6px;cursor:pointer;background:var(--vg-ui-panel,#121212);transition:background .12s}
.vg-ri:hover{background:var(--vg-ui-panel-hover,#242424)}
.vg-ri.on{background:var(--vg-ui-stroke,#1A1A1A)}
.vg-rd{width:14px;height:14px;border-radius:50%;border:2px solid var(--vg-ui-subtext,#A7A7A7);flex-shrink:0;position:relative}
.vg-ri.on .vg-rd{border-color:var(--vg-ui-accent,#1DB954)}
.vg-ri.on .vg-rd::after{content:'';position:absolute;top:2px;left:2px;width:6px;height:6px;background:var(--vg-ui-accent,#1DB954);border-radius:50%}
.vg-rc{flex:1;min-width:0}
.vg-rc .nm{font-size:13px;font-weight:500;color:var(--vg-ui-text,#FFF)}
.vg-sw{display:inline-flex;gap:3px;margin-left:8px;vertical-align:middle}
.vg-sw i{width:12px;height:12px;border-radius:50%;border:1px solid var(--vg-ui-stroke,#1A1A1A);display:inline-block}
.vg-tr{display:flex;align-items:center;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--vg-ui-panel,#121212)}
.vg-tl{font-size:13px;font-weight:500;color:var(--vg-ui-text,#FFF);flex:1}
.vg-ts{width:36px;height:20px;border-radius:10px;border:none;cursor:pointer;position:relative;transition:background .2s;background:var(--vg-ui-stroke,#1A1A1A);flex-shrink:0;margin-left:8px}
.vg-ts.on{background:var(--vg-ui-accent,#1DB954)}
.vg-tk{position:absolute;top:2px;left:2px;width:16px;height:16px;background:var(--vg-ui-text,#FFF);border-radius:50%;transition:left .2s}
.vg-ts.on .vg-tk{left:18px}
.vg-sr{display:flex;align-items:center;gap:8px;padding:6px 0}
.vg-sr .lb{font-size:12px;color:var(--vg-ui-subtext,#A7A7A7);min-width:60px}
.vg-sr input[type=range]{-webkit-appearance:none;appearance:none;flex:1;height:4px;background:var(--vg-ui-stroke,#1A1A1A);border-radius:2px;outline:none}
.vg-sr input[type=range]::-webkit-slider-thumb{-webkit-appearance:none;width:12px;height:12px;background:var(--vg-ui-accent,#1DB954);border-radius:50%;cursor:pointer}
.vg-sr .vl{font-size:11px;color:var(--vg-ui-subtext,#A7A7A7);min-width:30px;text-align:right}
.vg-fi{width:100%;padding:8px 10px;background:var(--vg-ui-panel,#121212);border:1px solid var(--vg-ui-stroke,#1A1A1A);border-radius:6px;color:var(--vg-ui-text,#FFF);font-size:13px;margin-top:4px;font-family:inherit;outline:none;transition:border-color .15s}
.vg-fi:focus{border-color:var(--vg-ui-accent,#1DB954)}
.vg-fi::placeholder{color:var(--vg-ui-subtext,#A7A7A7)}
.vg-di{display:inline-flex;cursor:pointer;color:var(--vg-ui-subtext,#A7A7A7);font-size:14px;margin-left:4px;transition:color .15s}
.vg-di:hover{color:#E22134}
.vg-dr{display:flex;gap:4px}
.vg-dr button{flex:1;padding:7px;background:var(--vg-ui-panel,#121212);border:1px solid var(--vg-ui-stroke,#1A1A1A);border-radius:6px;color:var(--vg-ui-subtext,#A7A7A7);cursor:pointer;font-size:12px;font-family:inherit;transition:all .15s;text-align:center}
.vg-dr button:hover{background:var(--vg-ui-panel-hover,#242424)}
.vg-dr button.on{background:var(--vg-ui-stroke,#1A1A1A);color:var(--vg-ui-text,#FFF);border-color:var(--vg-ui-accent,#1DB954)}
.vg-rb{display:flex;align-items:center;justify-content:center;gap:6px;width:100%;margin-top:12px;padding:8px;border:1px solid #E22134;border-radius:6px;background:var(--vg-ui-panel,#121212);color:#E22134;cursor:pointer;font-size:12px;font-weight:500;font-family:inherit;transition:all .15s}
.vg-rb:hover{background:#E22134;color:var(--vg-ui-text,#FFF)}
.vg-cr{text-align:center;font-size:10px;color:var(--vg-ui-subtext,#A7A7A7);opacity:.3;padding:8px;border-top:1px solid var(--vg-ui-stroke,#1A1A1A);flex-shrink:0}
.vg-sh{cursor:grab;user-select:none}
.vg-sh-btns{display:flex;gap:6px}
.vg-sh .vg-peek-b:hover{background:var(--vg-ui-panel-hover,#242424)}
.vg-sp.vg-peek{opacity:.07}
.vg-ce-bar{display:flex;gap:6px;align-items:center;margin-bottom:10px;flex-wrap:wrap}
.vg-ce-q{flex:1;min-width:120px;padding:7px 10px;background:var(--vg-ui-panel,#121212);border:1px solid var(--vg-ui-stroke,#1A1A1A);border-radius:6px;color:var(--vg-ui-text,#FFF);font-size:12px;font-family:inherit;outline:none}
.vg-ce-q:focus{border-color:var(--vg-ui-accent,#1DB954)}
.vg-ce-q::placeholder{color:var(--vg-ui-subtext,#A7A7A7)}
.vg-ce-b{padding:6px 10px;background:var(--vg-ui-panel,#121212);border:1px solid var(--vg-ui-stroke,#1A1A1A);border-radius:6px;color:var(--vg-ui-subtext,#A7A7A7);font-size:11px;font-family:inherit;cursor:pointer;transition:background .15s,color .15s;white-space:nowrap}
.vg-ce-b:hover:not(:disabled){background:var(--vg-ui-panel-hover,#242424);color:var(--vg-ui-text,#FFF)}
.vg-ce-b:disabled{opacity:.35;cursor:default}
.vg-ce-b.on{border-color:var(--vg-ui-accent,#1DB954);color:var(--vg-ui-text,#FFF)}
.vg-ce-b.warn{color:#E22134;border-color:#E22134}
.vg-ce-b.warn:hover{background:#E22134;color:#FFF}
.vg-ce-io{display:flex;flex-direction:column;gap:6px;margin-bottom:10px;padding:10px;border:1px solid var(--vg-ui-stroke,#1A1A1A);border-radius:8px}
.vg-ce-io textarea{width:100%;height:110px;resize:vertical;padding:8px;background:var(--vg-ui-panel,#121212);border:1px solid var(--vg-ui-stroke,#1A1A1A);border-radius:6px;color:var(--vg-ui-text,#FFF);font:11px/1.4 ui-monospace,Consolas,monospace;outline:none}
.vg-ce-io textarea:focus{border-color:var(--vg-ui-accent,#1DB954)}
.vg-ce-grp{margin-bottom:8px;border:1px solid var(--vg-ui-stroke,#1A1A1A);border-radius:8px;overflow:hidden}
.vg-ce-gh{display:flex;align-items:center;justify-content:space-between;padding:9px 12px;cursor:pointer;user-select:none;font-size:13px;font-weight:600;color:var(--vg-ui-text,#FFF)}
.vg-ce-gh:hover{background:var(--vg-ui-panel-hover,#242424)}
.vg-ce-gh small{font-size:10px;font-weight:500;color:var(--vg-ui-accent,#1DB954);margin-left:6px}
.vg-ce-gh span:last-child{font-size:11px;color:var(--vg-ui-subtext,#A7A7A7);transition:transform .2s}
.vg-ce-grp.open .vg-ce-gh span:last-child{transform:rotate(180deg)}
.vg-ce-gb{display:none;padding:2px 6px 6px}
.vg-ce-grp.open .vg-ce-gb{display:block}
.vg-ce-row{display:flex;align-items:center;gap:10px;padding:6px;border-radius:6px}
.vg-ce-row:hover,.vg-ce-row.open{background:var(--vg-ui-panel-hover,#242424)}
.vg-ce-sw,.vg-ce-sws button,.vg-ce-pv{background:repeating-conic-gradient(#8A8A8A 0 25%,#D6D6D6 0 50%) 0 0/8px 8px}
.vg-ce-sw{position:relative;width:30px;height:30px;flex-shrink:0;padding:0;border-radius:7px;border:1px solid var(--vg-ui-stroke,#1A1A1A);cursor:pointer;overflow:hidden}
.vg-ce-sw i,.vg-ce-sws button i{position:absolute;inset:0}
.vg-ce-info{flex:1;min-width:0;cursor:pointer}
.vg-ce-nm{font-size:12.5px;font-weight:500;color:var(--vg-ui-text,#FFF)}
.vg-ce-row.custom .vg-ce-nm::after{content:"";display:inline-block;width:6px;height:6px;margin-left:6px;border-radius:50%;background:var(--vg-ui-accent,#1DB954);vertical-align:middle}
.vg-ce-ds{font-size:10.5px;color:var(--vg-ui-subtext,#A7A7A7);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.vg-ce-val{max-width:150px;font:11px/1.2 ui-monospace,Consolas,monospace;color:var(--vg-ui-subtext,#A7A7A7);text-align:right;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.vg-ce-ib{width:24px;height:24px;flex-shrink:0;padding:0;border:none;border-radius:6px;background:none;color:var(--vg-ui-subtext,#A7A7A7);font-size:13px;cursor:pointer}
.vg-ce-ib:hover:not(:disabled){background:var(--vg-ui-stroke,#1A1A1A);color:var(--vg-ui-text,#FFF)}
.vg-ce-ib:disabled{opacity:.25;cursor:default}
.vg-ce-pk{display:flex;flex-direction:column;gap:9px;margin:4px 6px 10px;padding:10px;border:1px solid var(--vg-ui-stroke,#1A1A1A);border-radius:8px}
.vg-ce-sv{position:relative;height:150px;border-radius:6px;cursor:crosshair;touch-action:none;background-image:linear-gradient(to top,#000,rgba(0,0,0,0)),linear-gradient(to right,#FFF,rgba(255,255,255,0))}
.vg-ce-hue,.vg-ce-alpha{position:relative;height:12px;border-radius:6px;cursor:pointer;touch-action:none}
.vg-ce-hue{background:linear-gradient(to right,#F00 0%,#FF0 17%,#0F0 33%,#0FF 50%,#00F 67%,#F0F 83%,#F00 100%)}
.vg-ce-alpha{background:repeating-conic-gradient(#8A8A8A 0 25%,#D6D6D6 0 50%) 0 0/8px 8px}
.vg-ce-alpha b{position:absolute;inset:0;border-radius:6px}
.vg-ce-knob{position:absolute;width:14px;height:14px;border:2px solid #FFF;border-radius:50%;box-shadow:0 0 0 1px rgba(0,0,0,.45),0 1px 4px rgba(0,0,0,.5);transform:translate(-50%,-50%);pointer-events:none}
.vg-ce-hue .vg-ce-knob,.vg-ce-alpha .vg-ce-knob{top:50%}
.vg-ce-sv:focus-visible,.vg-ce-hue:focus-visible,.vg-ce-alpha:focus-visible{outline:2px solid var(--vg-ui-accent,#1DB954);outline-offset:2px}
.vg-ce-line{display:flex;align-items:center;gap:6px}
.vg-ce-pv{display:flex;width:44px;height:28px;flex-shrink:0;border-radius:6px;overflow:hidden;border:1px solid var(--vg-ui-stroke,#1A1A1A)}
.vg-ce-pv i{flex:1}
.vg-ce-pv i:first-child{cursor:pointer}
.vg-ce-in{flex:1;min-width:0;padding:6px 8px;background:var(--vg-ui-panel,#121212);border:1px solid var(--vg-ui-stroke,#1A1A1A);border-radius:6px;color:var(--vg-ui-text,#FFF);font:12px ui-monospace,Consolas,monospace;outline:none}
.vg-ce-in:focus{border-color:var(--vg-ui-accent,#1DB954)}
.vg-ce-in.bad{border-color:#E22134}
.vg-ce-fmt{display:flex;border:1px solid var(--vg-ui-stroke,#1A1A1A);border-radius:6px;overflow:hidden;flex-shrink:0}
.vg-ce-fmt button{padding:6px 7px;border:none;background:none;color:var(--vg-ui-subtext,#A7A7A7);font-size:10px;font-weight:600;cursor:pointer}
.vg-ce-fmt button.on{background:var(--vg-ui-stroke,#1A1A1A);color:var(--vg-ui-text,#FFF)}
.vg-ce-nums{display:grid;grid-template-columns:repeat(4,1fr);gap:6px}
.vg-ce-nums label{display:flex;flex-direction:column;gap:2px;font-size:9.5px;font-weight:600;letter-spacing:.5px;color:var(--vg-ui-subtext,#A7A7A7);text-align:center}
.vg-ce-nums input{width:100%;padding:5px 4px;background:var(--vg-ui-panel,#121212);border:1px solid var(--vg-ui-stroke,#1A1A1A);border-radius:6px;color:var(--vg-ui-text,#FFF);font:12px ui-monospace,Consolas,monospace;text-align:center;outline:none}
.vg-ce-nums input:focus{border-color:var(--vg-ui-accent,#1DB954)}
.vg-ce-sws{display:flex;flex-wrap:wrap;gap:5px;align-items:center}
.vg-ce-sws span{width:48px;font-size:9.5px;font-weight:600;letter-spacing:.5px;color:var(--vg-ui-subtext,#A7A7A7)}
.vg-ce-sws button{position:relative;width:18px;height:18px;padding:0;border-radius:4px;border:1px solid var(--vg-ui-stroke,#1A1A1A);cursor:pointer;overflow:hidden}
.vg-ce-sws button:hover{transform:scale(1.15)}
.vg-ce-note{font-size:10.5px;line-height:1.45;color:var(--vg-ui-subtext,#A7A7A7)}
.vg-ce-empty{padding:16px;text-align:center;font-size:12px;color:var(--vg-ui-subtext,#A7A7A7)}
.vg-ce-ico{width:14px;height:14px;flex-shrink:0;fill:none;stroke:currentColor;stroke-width:2;stroke-linecap:round;stroke-linejoin:round}
.vg-ce-b{display:inline-flex;align-items:center;gap:5px}
.vg-ce-ib{display:inline-flex;align-items:center;justify-content:center}
.vg-ce-val{display:inline-flex;align-items:center;gap:4px;justify-content:flex-end}
.vg-ce-val .vg-ce-ico{width:12px;height:12px}
.vg-sh .vg-ce-ico{width:13px;height:13px}
.vg-ce-key{margin-left:7px;font:10px ui-monospace,Consolas,monospace;font-weight:400;color:var(--vg-ui-subtext,#A7A7A7);opacity:.75}
.vg-ce-ex{display:flex;flex-direction:column;gap:6px;padding-bottom:10px;margin-bottom:4px;border-bottom:1px solid var(--vg-ui-stroke,#1A1A1A)}
.vg-ce-ex-h{display:flex;align-items:center;gap:6px}
.vg-ce-ex-h span{flex:1;font-size:9.5px;font-weight:600;letter-spacing:.5px;color:var(--vg-ui-subtext,#A7A7A7)}
.vg-ce-ex-code{margin:0;padding:8px 10px;max-height:170px;overflow:auto;background:var(--vg-ui-panel,#121212);border:1px solid var(--vg-ui-stroke,#1A1A1A);border-radius:6px;color:var(--vg-ui-text,#FFF);font:11px/1.45 ui-monospace,Consolas,monospace;white-space:pre;user-select:text;-webkit-user-select:text;cursor:text}`;
    document.head.appendChild(s);
  }

  // open/close modal (toggles)
  // panel is built once and kept in the DOM; open/close only flips display.
  // No enter/exit animation: the 200ms fade over glass panels dropped frames.
  // Content is rebuilt on reopen only when a setting it shows changed elsewhere.
  let renderedState = "";
  function externalState() {
    const g = window.VantagraphCustomData.getSetting;
    return [g("bg-url", ""), g("bg-use-album-cover", "")].join("|");
  }
  function toggle() {
    if (panelEl) {
      if (panelEl.classList.contains("open")) { close(); return; }
      if (externalState() !== renderedState) render(panelEl.querySelector(".vg-sc"));
      panelEl.classList.add("open");
      document.addEventListener("keydown", esc);
      return;
    }
    ensureStyles();
    const V = window.VantagraphCustomData;

    const p = document.createElement("div"); p.className = "vg-sp";

    // Header
    const h = document.createElement("div"); h.className = "vg-sh";
    const t = document.createElement("span"); t.textContent = "Vantagraph Custom";
    const hb = document.createElement("div"); hb.className = "vg-sh-btns";
    // hold to look through the window at the colours behind it
    const pb = document.createElement("button"); pb.className = "vg-peek-b"; pb.appendChild(ico("eye")); pb.title = "Hold to see through this window";
    pb.onpointerdown = () => p.classList.add("vg-peek");
    pb.onpointerup = pb.onpointerleave = pb.onpointercancel = () => p.classList.remove("vg-peek");
    const cb = document.createElement("button"); cb.textContent = "✕"; cb.title = "Close"; cb.onclick = close;
    hb.appendChild(pb); hb.appendChild(cb);
    h.appendChild(t); h.appendChild(hb);
    dragPanel(p, h);

    // Tabs
    const tabs = document.createElement("div"); tabs.className = "vg-tabs";
    TABS.forEach(c => {
      const b = document.createElement("button");
      b.className = "vg-tab" + (c.id === activeTab ? " on" : "");
      b.textContent = c.label;
      b.onclick = () => { activeTab = c.id; tabs.querySelectorAll(".vg-tab").forEach(x => x.classList.remove("on")); b.classList.add("on"); render(sc); };
      tabs.appendChild(b);
    });

    // Content
    const sc = document.createElement("div"); sc.className = "vg-sc";

    // Credits
    const cr = document.createElement("div"); cr.className = "vg-cr"; cr.textContent = "Vantagraph Custom v1.0.0";

    p.appendChild(h); p.appendChild(tabs); p.appendChild(sc); p.appendChild(cr);
    document.body.appendChild(p);
    panelEl = p;
    render(sc);
    document.addEventListener("keydown", esc);
    p.classList.add("open");
  }

  function close() {
    if (!panelEl) return;
    document.removeEventListener("keydown", esc);
    panelEl.classList.remove("open");
  }
  function esc(e) {
    if (e.key === "Escape") { close(); return; }
    if (activeTab === "colors") ceKeys(e);
  }

  // helpers: accordion / slider / toggle builders
  function acc(title, open, fn) {
    const d = document.createElement("div"); d.className = "vg-acc" + (open ? " open" : "");
    const h = document.createElement("div"); h.className = "vg-ach";
    const s1 = document.createElement("span"); s1.textContent = title;
    const s2 = document.createElement("span"); s2.textContent = "▼";
    h.appendChild(s1); h.appendChild(s2);
    const b = document.createElement("div"); b.className = "vg-ab";
    const i = document.createElement("div"); i.className = "vg-ai";
    fn(i); b.appendChild(i);
    h.onclick = () => d.classList.toggle("open");
    d.appendChild(h); d.appendChild(b); return d;
  }
  function slider(label, min, max, step, val, unit, cb, centerVal) {
    const isDef = val === "default";
    const r = document.createElement("div"); r.className = "vg-sr";
    const l = document.createElement("span"); l.className = "lb"; l.textContent = label;
    const s = document.createElement("input"); s.type = "range"; s.min = min; s.max = max; s.step = step; s.value = isDef ? centerVal : val;
    const v = document.createElement("span"); v.className = "vl"; v.textContent = isDef ? "DEFAULT" : val + unit;
    if (isDef) s.style.opacity = "0.35";
    let db = null;
    s.oninput = () => {
      s.style.opacity = "1";
      v.textContent = s.value + unit;
      v.style.color = "";
      cb(s.value);
      if (db) db.style.opacity = "1";
    };
    r.appendChild(l); r.appendChild(s); r.appendChild(v);
    if (centerVal !== undefined) {
      db = document.createElement("button"); db.className = "vg-sd"; db.textContent = "DEF";
      db.title = "Restore native Spotify defaults";
      db.style.cssText = "background:none;border:1px solid rgba(255,255,255,0.2);color:#A7A7A7;font-size:9px;font-weight:bold;letter-spacing:0.5px;padding:2px 6px;border-radius:4px;cursor:pointer;margin-left:6px;opacity:" + (isDef ? "0.3" : "1") + ";transition:opacity .2s,color .2s;";
      db.onclick = () => {
        s.value = centerVal;
        s.style.opacity = "0.35";
        v.textContent = "DEFAULT";
        v.style.color = "#666";
        cb("default");
        db.style.opacity = "0.3";
      };
      r.appendChild(db);
    }
    return r;
  }
  function tog(label, on, cb) {
    const r = document.createElement("div"); r.className = "vg-tr";
    const l = document.createElement("span"); l.className = "vg-tl"; l.textContent = label;
    const t = document.createElement("button"); t.className = "vg-ts" + (on ? " on" : "");
    const k = document.createElement("span"); k.className = "vg-tk"; t.appendChild(k);
    t.onclick = () => { const n = !t.classList.contains("on"); t.classList.toggle("on", n); cb(n); };
    r.appendChild(l); r.appendChild(t); return r;
  }

  // COLORS TAB
  // UI only: parsing, storage and painting live in theme.js (VantagraphCustomData).
  const ce = {
    open: null,                    // key whose picker is expanded
    groupsOpen: { surfaces: true },
    format: "hex",                 // text field and row values: hex | rgb | hsl
    query: "",
    undo: [],
    redo: [],
    gesture: false,
    rows: {},                      // key -> row parts
    groups: [],                    // { id, el, count, defs }
    ui: null,                      // toolbar parts
    pk: null,                      // open picker parts
    hsv: null,                     // picker state; keeps hue while saturation or value is 0
  };

  function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  const clamp01 = n => Math.min(1, Math.max(0, n));

  // stroke icons: Spotify's font has no glyphs for arrows like undo/redo,
  // so text symbols rendered as tofu. Constant markup only, never user data.
  const CE_ICONS = {
    undo: '<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>',
    redo: '<path d="m15 14 5-5-5-5"/><path d="M20 9H9.5a5.5 5.5 0 0 0 0 11H13"/>',
    share: '<path d="M7 16V4"/><path d="m3 8 4-4 4 4"/><path d="M17 8v12"/><path d="m21 16-4 4-4-4"/>',
    find: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3"/>',
    reset: '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/>',
    copy: '<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V5a2 2 0 0 1 2-2h10"/>',
    drop: '<path d="M14 4l6 6"/><path d="M17 3a2.8 2.8 0 0 1 4 4l-3 3-4-4z"/><path d="M14 7 5 16v3h3l9-9"/>',
    eye: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    link: '<path d="M10 14a4.5 4.5 0 0 0 6.4 0l3-3a4.5 4.5 0 0 0-6.4-6.4l-1 1"/><path d="M14 10a4.5 4.5 0 0 0-6.4 0l-3 3a4.5 4.5 0 0 0 6.4 6.4l1-1"/>',
  };
  function ico(name) {
    const s = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    s.setAttribute("viewBox", "0 0 24 24");
    s.setAttribute("class", "vg-ce-ico");
    s.setAttribute("aria-hidden", "true");
    s.innerHTML = CE_ICONS[name];
    return s;
  }
  // button with an icon and an optional text label
  function ibtn(cls, icon, label) {
    const b = el("button", cls);
    b.appendChild(ico(icon));
    if (label) b.appendChild(el("span", null, label));
    return b;
  }
  const ceV = () => window.VantagraphCustomData;
  const ceLabel = k => (ceV().COLOR_KEYS.find(d => d.key === k) || {}).label || k;

  function ceText(c) {
    const C = ceV().color;
    return ce.format === "rgb" ? C.toRgb(c) : ce.format === "hsl" ? C.toHsl(c) : C.toHex(c);
  }

  function ceCopy(text, msg) {
    const done = () => Spicetify.showNotification(msg || "Copied " + text);
    if (navigator.clipboard) navigator.clipboard.writeText(text).then(done, () => {});
    else if (Spicetify.Platform?.ClipboardAPI) { Spicetify.Platform.ClipboardAPI.copy(text); done(); }
  }

  // history: one snapshot per gesture (a drag, a typed value, a reset)
  function ceBegin() {
    if (ce.gesture) return;
    ce.gesture = true;
    ce.undo.push(ceV().getColorOverrides());
    if (ce.undo.length > 100) ce.undo.shift();
    ce.redo = [];
  }
  function ceEnd(remember) {
    if (!ce.gesture) return;
    ce.gesture = false;
    ceFlush();
    if (remember) ceRemember();
    ceRefreshAll();
  }
  function ceHistory(from, to) {
    if (!from.length) return;
    ceFlush();
    to.push(ceV().getColorOverrides());
    ceV().setColorOverrides(from.pop());
    ceRefreshAll();
    ceReloadPicker();
  }
  const ceUndo = () => ceHistory(ce.undo, ce.redo);
  const ceRedo = () => ceHistory(ce.redo, ce.undo);

  // Ctrl+Z / Ctrl+Y while the Colors tab is open (text fields keep their own undo)
  function ceKeys(e) {
    if (!(e.ctrlKey || e.metaKey) || /^(INPUT|TEXTAREA)$/.test(e.target.tagName)) return;
    const k = e.key.toLowerCase();
    if (k === "z" && !e.shiftKey) { e.preventDefault(); ceUndo(); }
    else if (k === "y" || (k === "z" && e.shiftKey)) { e.preventDefault(); ceRedo(); }
  }

  // live apply, one engine write per frame while dragging
  let ceRaf = 0;
  let cePending = null;
  function ceSet(key, c) {
    cePending = { key, c };
    if (!ceRaf) ceRaf = requestAnimationFrame(ceFlush);
  }
  function ceFlush() {
    if (ceRaf) { cancelAnimationFrame(ceRaf); ceRaf = 0; }
    if (!cePending) return;
    const { key, c } = cePending;
    cePending = null;
    const V = ceV();
    V.setColor(key, V.color.format(c));
    V.COLOR_KEYS.forEach(d => { if (d.key === key || d.link === key) ceRefreshRow(d.key); });
  }

  function ceRecent() {
    try {
      const list = JSON.parse(Spicetify.LocalStorage.get("vantagraph-custom:recent-colors") || "[]");
      return Array.isArray(list) ? list.filter(v => ceV().color.parse(v)).slice(0, 12) : [];
    } catch (e) { return []; }
  }
  function ceRemember() {
    if (!ce.pk) return;
    const v = ceV().getColorState(ce.pk.key).value;
    const list = [v].concat(ceRecent().filter(x => x !== v)).slice(0, 12);
    Spicetify.LocalStorage.set("vantagraph-custom:recent-colors", JSON.stringify(list));
  }

  // rows
  function ceRow(def) {
    const V = ceV();
    const wrap = el("div");
    const row = el("div", "vg-ce-row");
    const sw = el("button", "vg-ce-sw"); sw.title = "Edit colour";
    const swc = el("i"); sw.appendChild(swc);
    const info = el("div", "vg-ce-info");
    const nm = el("div", "vg-ce-nm", def.label);
    nm.appendChild(el("span", "vg-ce-key", def.key));
    info.append(nm, el("div", "vg-ce-ds", def.desc));
    const val = el("div", "vg-ce-val");
    const find = ibtn("vg-ce-ib", "find"); find.title = "Find: blink this colour inside Spotify";
    const rst = ibtn("vg-ce-ib", "reset");
    rst.title = def.link ? "Follow " + ceLabel(def.link) + " again" : "Back to default";
    row.append(sw, info, val, find, rst);
    wrap.appendChild(row);
    sw.onclick = info.onclick = () => ceToggle(def.key);
    find.onclick = () => V.flashColor(def.key);
    rst.onclick = () => {
      if (!V.getColorState(def.key).custom) return;
      ceBegin(); V.resetColor(def.key); ceEnd();
      if (ce.pk && ce.pk.key === def.key) ceReloadPicker();
    };
    ce.rows[def.key] = { wrap, row, swc, val, rst };
    return wrap;
  }

  function ceRefreshRow(key) {
    const r = ce.rows[key];
    if (!r) return;
    const st = ceV().getColorState(key);
    r.swc.style.background = st.value;
    if (st.link) r.val.replaceChildren(ico("link"), document.createTextNode(ceLabel(st.link)));
    else r.val.textContent = ceText(st.color);
    r.val.title = st.link ? "Follows " + ceLabel(st.link) + " until you pick a colour" : ceText(st.color);
    r.row.classList.toggle("custom", st.custom);
    r.rst.disabled = !st.custom;
  }

  function ceRefreshAll() {
    const over = ceV().getColorOverrides();
    Object.keys(ce.rows).forEach(ceRefreshRow);
    ce.groups.forEach(g => {
      const n = g.defs.filter(d => over[d.key]).length;
      g.count.textContent = n ? n + " changed" : "";
    });
    if (ce.ui) {
      ce.ui.undo.disabled = !ce.undo.length;
      ce.ui.redo.disabled = !ce.redo.length;
    }
  }

  function ceFilter() {
    const q = ce.query.trim().toLowerCase();
    let shown = 0;
    ce.groups.forEach(g => {
      let n = 0;
      g.defs.forEach(d => {
        const hit = !q || (d.label + " " + d.desc + " " + d.key).toLowerCase().includes(q);
        ce.rows[d.key].wrap.style.display = hit ? "" : "none";
        if (hit) n++;
      });
      g.el.style.display = n ? "" : "none";
      g.el.classList.toggle("open", q ? true : !!ce.groupsOpen[g.id]);
      shown += n;
    });
    ce.ui.empty.style.display = shown ? "none" : "";
  }

  // picker
  function ceCurrent() {
    const h = ce.hsv;
    return { ...ceV().color.hsvToRgb(h.h, h.s, h.v), a: h.a };
  }
  function ceSyncHsv(c) {
    const h = ceV().color.rgbToHsv(c);
    const prev = ce.hsv || h;
    ce.hsv = {
      h: h.s === 0 || h.v === 0 ? prev.h : h.h,
      s: h.v === 0 ? prev.s : h.s,
      v: h.v,
      a: c.a,
    };
  }
  function ceFromHsv() {
    const c = ceCurrent();
    ceSet(ce.pk.key, c);
    ceSyncPicker(c);
  }
  function ceReloadPicker() {
    if (!ce.pk) return;
    ceSyncHsv(ceV().getColorState(ce.pk.key).color);
    ceSyncPicker();
  }
  function ceSyncPicker(c) {
    const p = ce.pk;
    if (!p) return;
    const h = ce.hsv;
    c = c || ceCurrent();
    p.sv.style.backgroundColor = `hsl(${h.h}, 100%, 50%)`;
    p.svK.style.left = h.s * 100 + "%";
    p.svK.style.top = (1 - h.v) * 100 + "%";
    p.hueK.style.left = h.h / 360 * 100 + "%";
    p.alphaFill.style.background = `linear-gradient(to right, rgba(${c.r}, ${c.g}, ${c.b}, 0), rgb(${c.r}, ${c.g}, ${c.b}))`;
    p.alphaK.style.left = c.a * 100 + "%";
    p.pvNew.style.background = ceV().color.format(c);
    if (document.activeElement !== p.txt) { p.txt.value = ceText(c); p.txt.classList.remove("bad"); }
    ["r", "g", "b"].forEach(k => { if (document.activeElement !== p.nums[k]) p.nums[k].value = c[k]; });
    if (document.activeElement !== p.nums.a) p.nums.a.value = Math.round(c.a * 100);
  }

  function ceDrag(area, onMove) {
    area.addEventListener("pointerdown", e => {
      if (e.button !== 0) return;
      e.preventDefault();
      area.focus();
      area.setPointerCapture(e.pointerId);
      ceBegin();
      const move = ev => {
        const rc = area.getBoundingClientRect();
        onMove(clamp01((ev.clientX - rc.left) / rc.width), clamp01((ev.clientY - rc.top) / rc.height));
        ceFromHsv();
      };
      const up = () => {
        area.removeEventListener("pointermove", move);
        area.removeEventListener("pointerup", up);
        area.removeEventListener("pointercancel", up);
        ceEnd(true);
      };
      area.addEventListener("pointermove", move);
      area.addEventListener("pointerup", up);
      area.addEventListener("pointercancel", up);
      move(e);
    });
  }

  // arrow keys nudge 1%, shift 10%
  function ceNudge(area, fn) {
    area.addEventListener("keydown", e => {
      const s = e.shiftKey ? 0.1 : 0.01;
      const d = { ArrowLeft: [-s, 0], ArrowRight: [s, 0], ArrowUp: [0, -s], ArrowDown: [0, s] }[e.key];
      if (!d) return;
      e.preventDefault();
      ceBegin(); fn(d[0], d[1]); ceFromHsv(); ceEnd();
    });
  }

  function ceToggle(key) {
    ce.open = ce.open === key ? null : key;
    ceBuildPicker();
  }

  function ceBuildPicker() {
    const V = ceV();
    if (ce.pk) { ce.pk.root.remove(); ce.pk = null; }
    Object.values(ce.rows).forEach(r => r.row.classList.remove("open"));
    const r = ce.open && ce.rows[ce.open];
    if (!r) return;
    const key = ce.open;
    const def = V.COLOR_KEYS.find(d => d.key === key);
    const start = V.getColorState(key).color;
    r.row.classList.add("open");

    const root = el("div", "vg-ce-pk");
    const sv = el("div", "vg-ce-sv"); const svK = el("i", "vg-ce-knob"); sv.appendChild(svK);
    const hue = el("div", "vg-ce-hue"); const hueK = el("i", "vg-ce-knob"); hue.appendChild(hueK);
    const alpha = el("div", "vg-ce-alpha"); const alphaFill = el("b"); const alphaK = el("i", "vg-ce-knob");
    alpha.append(alphaFill, alphaK);
    sv.title = "Saturation and brightness"; hue.title = "Hue"; alpha.title = "Opacity";
    [sv, hue, alpha].forEach(a => { a.tabIndex = 0; });

    // preview (old | new), value field, format, copy, eyedropper
    const line = el("div", "vg-ce-line");
    const pv = el("div", "vg-ce-pv"); const pvOld = el("i"); const pvNew = el("i"); pv.append(pvOld, pvNew);
    pvOld.style.background = V.color.format(start);
    pvOld.title = "Back to " + ceText(start);
    const txt = el("input", "vg-ce-in");
    txt.spellcheck = false;
    txt.placeholder = "#RRGGBB, #RRGGBBAA, rgb(), rgba(), hsl()";
    const fmt = el("div", "vg-ce-fmt");
    ["hex", "rgb", "hsl"].forEach(f => {
      const b = el("button", ce.format === f ? "on" : "", f.toUpperCase());
      b.title = "Show values as " + f.toUpperCase();
      b.onclick = () => {
        ce.format = f;
        fmt.querySelectorAll("button").forEach(x => x.classList.toggle("on", x === b));
        ceRefreshAll();
        ceSyncPicker();
      };
      fmt.appendChild(b);
    });
    const copy = ibtn("vg-ce-ib", "copy"); copy.title = "Copy value";
    copy.onclick = () => ceCopy(txt.value);
    line.append(pv, txt, fmt, copy);
    if (window.EyeDropper) {
      const drop = ibtn("vg-ce-ib", "drop"); drop.title = "Pick a colour from the screen";
      drop.onclick = () => {
        new window.EyeDropper().open().then(res => {
          const c = V.color.parse(res.sRGBHex);
          if (!c) return;
          const next = { ...c, a: ce.hsv.a };
          ceBegin(); ceSyncHsv(next); ceSet(key, next); ceSyncPicker(next); ceEnd(true);
        }).catch(() => {});
      };
      line.appendChild(drop);
    }

    // R G B A fields
    const nums = el("div", "vg-ce-nums");
    const numIn = {};
    [["r", "R", 255], ["g", "G", 255], ["b", "B", 255], ["a", "A %", 100]].forEach(([k, lab, max]) => {
      const l = el("label", null, lab);
      const i = el("input");
      i.type = "number"; i.min = 0; i.max = max; i.step = 1;
      i.oninput = () => {
        const v = parseFloat(i.value);
        if (!isFinite(v)) return;
        const n = Math.round(Math.min(max, Math.max(0, v)));
        const next = { ...ceCurrent(), [k]: k === "a" ? n / 100 : n };
        ceBegin(); ceSyncHsv(next); ceSet(key, next); ceSyncPicker(next);
      };
      i.onblur = () => { ceEnd(true); ceSyncPicker(); };
      l.appendChild(i);
      nums.appendChild(l);
      numIn[k] = i;
    });

    root.append(sv, hue, alpha, line, nums);

    // swatches: colours already in the palette, then recent picks
    const swatches = (label, list) => {
      if (!list.length) return;
      const row = el("div", "vg-ce-sws");
      row.appendChild(el("span", null, label));
      list.forEach(v => {
        const c = V.color.parse(v);
        if (!c) return;
        const b = el("button"); b.title = ceText(c);
        const i = el("i"); i.style.background = V.color.format(c); b.appendChild(i);
        b.onclick = () => { ceBegin(); ceSyncHsv(c); ceSet(key, c); ceSyncPicker(c); ceEnd(true); };
        row.appendChild(b);
      });
      root.appendChild(row);
    };
    swatches("PALETTE", [...new Set(V.COLOR_KEYS.map(d => V.getColorState(d.key).value))].slice(0, 20));
    swatches("RECENT", ceRecent());
    if (def.link) {
      root.appendChild(el("div", "vg-ce-note",
        "Follows " + ceLabel(def.link) + " until you pick a colour here. The reset arrow on the row makes it follow again."));
    }

    // value field: any format, applied on Enter or when leaving the field
    const commitTxt = () => {
      const c = V.color.parse(txt.value);
      if (!c) { txt.classList.add("bad"); return; }
      txt.classList.remove("bad");
      if (V.color.format(c) !== V.getColorState(key).value) {
        ceBegin(); ceSyncHsv(c); ceSet(key, c); ceEnd(true);
      }
      txt.value = ceText(c);
      ceSyncPicker(c);
    };
    txt.oninput = () => txt.classList.toggle("bad", !V.color.parse(txt.value));
    txt.onkeydown = e => { if (e.key === "Enter") txt.blur(); };
    txt.onblur = commitTxt;
    pvOld.onclick = () => { ceBegin(); ceSyncHsv(start); ceSet(key, start); ceSyncPicker(start); ceEnd(); };

    ceDrag(sv, (x, y) => { ce.hsv.s = x; ce.hsv.v = 1 - y; });
    ceDrag(hue, x => { ce.hsv.h = Math.min(359.9, x * 360); });
    ceDrag(alpha, x => { ce.hsv.a = Math.round(x * 100) / 100; });
    ceNudge(sv, (dx, dy) => { ce.hsv.s = clamp01(ce.hsv.s + dx); ce.hsv.v = clamp01(ce.hsv.v - dy); });
    ceNudge(hue, (dx, dy) => { ce.hsv.h = Math.min(359.9, Math.max(0, ce.hsv.h + (dx || -dy) * 360)); });
    ceNudge(alpha, (dx, dy) => { ce.hsv.a = Math.round(clamp01(ce.hsv.a + (dx || -dy)) * 100) / 100; });

    r.wrap.appendChild(root);
    ce.pk = { root, key, sv, svK, hue, hueK, alpha, alphaFill, alphaK, pvNew, txt, nums: numIn };
    ce.hsv = null;
    ceSyncHsv(start);
    ceSyncPicker(start);
  }

  // share: the whole palette as text, back in from that text or color.ini lines
  const CE_EXAMPLE = [
    "; Plum Night: one colour per line, key = value",
    "; any format works, colours left out go back to default",
    "window         = #0F0B16",
    "panel          = #171120",
    "panel-hover    = #221A2E",
    "menu           = #261D33",
    "player         = #0C0912",
    "stroke         = #2E2340",
    "text           = #EDE6F5",
    "subtext        = #9C8FB0",
    "accent         = #C79BFF",
    "btn-active     = #C79BFF",
    "play-btn       = #C79BFF",
    "play-btn-hover = #DDBFFF",
    "play-icon      = #171120",
    "bar-fill       = #C79BFF",
    "bar-bg         = rgba(199, 155, 255, 0.2)",
    "heart          = #FF5C8A",
    "row-hover      = rgba(199, 155, 255, 0.08)",
  ].join("\n");

  function ceExport() {
    const V = ceV();
    const colors = {};
    V.COLOR_KEYS.forEach(d => {
      const st = V.getColorState(d.key);
      if (!st.link) colors[d.key] = st.value;
    });
    return JSON.stringify({ theme: "Vantagraph Custom", colors }, null, 2);
  }

  function ceImport(text) {
    const V = ceV();
    let src = null;
    try {
      const j = JSON.parse(text);
      if (j && typeof j === "object") src = j.colors && typeof j.colors === "object" ? j.colors : j;
    } catch (e) {
      // color.ini style: key = value; [Sections] and ; comments are skipped
      src = {};
      String(text).split(/\r?\n/).forEach(line => {
        const m = /^\s*([a-z][a-z-]*)\s*[=:]\s*([^;\s][^;]*?)\s*(;.*)?$/i.exec(line);
        if (m) src[m[1].toLowerCase()] = m[2];
      });
    }
    const known = {};
    let skipped = 0;
    Object.keys(src || {}).forEach(k => {
      if (V.COLOR_KEYS.some(d => d.key === k) && V.color.parse(src[k])) known[k] = src[k];
      else skipped++;
    });
    const n = Object.keys(known).length;
    if (!n) { Spicetify.showNotification("No colours found in that text", true); return; }
    ceBegin(); V.setColorOverrides(known); ceEnd();
    ceReloadPicker();
    Spicetify.showNotification(`Palette loaded: ${n} colours` + (skipped ? `, ${skipped} skipped` : ""));
  }

  function renderColors(c) {
    const V = ceV();
    ce.rows = {};
    ce.groups = [];
    ce.pk = null;

    // toolbar
    const bar = el("div", "vg-ce-bar");
    const q = el("input", "vg-ce-q");
    q.placeholder = "Search colours"; q.value = ce.query; q.spellcheck = false;
    const undo = ibtn("vg-ce-b", "undo", "Undo"); undo.title = "Undo (Ctrl+Z)"; undo.onclick = ceUndo;
    const redo = ibtn("vg-ce-b", "redo", "Redo"); redo.title = "Redo (Ctrl+Y)"; redo.onclick = ceRedo;
    const share = ibtn("vg-ce-b", "share", "Share"); share.title = "Copy or load a whole palette";
    const reset = el("button", "vg-ce-b warn", "Reset colours"); reset.title = "Every colour back to VantagraphBlack";
    bar.append(q, undo, redo, share, reset);
    c.appendChild(bar);

    // share panel
    const io = el("div", "vg-ce-io");
    io.style.display = "none";
    const ex = el("div", "vg-ce-ex");
    const exHead = el("div", "vg-ce-ex-h");
    const exCopy = ibtn("vg-ce-b", "copy", "Copy example");
    const exTry = el("button", "vg-ce-b", "Try it");
    exTry.title = "Load the example palette now. Undo brings yours back.";
    exHead.append(el("span", null, "EXAMPLE"), exCopy, exTry);
    const exCode = el("pre", "vg-ce-ex-code", CE_EXAMPLE);
    ex.append(exHead, exCode, el("div", "vg-ce-note",
      "The small grey word next to each colour's name is its key. " +
      "Share with Copy palette, or write lines like these by hand."));
    io.appendChild(ex);
    exCopy.onclick = () => ceCopy(CE_EXAMPLE, "Example copied");
    exTry.onclick = () => ceImport(CE_EXAMPLE);
    const ta = el("textarea");
    ta.spellcheck = false;
    ta.placeholder = "Paste a palette here: the text from Copy palette, or color.ini lines such as  panel = 101010";
    const ioBar = el("div", "vg-ce-bar");
    ioBar.style.margin = "0";
    const exp = ibtn("vg-ce-b", "copy", "Copy palette");
    const imp = el("button", "vg-ce-b", "Load pasted palette");
    ioBar.append(exp, imp);
    io.append(ta, ioBar, el("div", "vg-ce-note", "Loading replaces every colour. Undo brings the previous palette back."));
    c.appendChild(io);
    share.onclick = () => {
      const on = io.style.display === "none";
      io.style.display = on ? "" : "none";
      share.classList.toggle("on", on);
    };
    exp.onclick = () => { ta.value = ceExport(); ceCopy(ta.value, "Palette copied"); };
    imp.onclick = () => ceImport(ta.value);
    reset.onclick = () => {
      if (!Object.keys(V.getColorOverrides()).length) return;
      if (!confirm("Put every colour back to VantagraphBlack? Undo can bring them back.")) return;
      ceBegin(); V.setColorOverrides({}); ceEnd();
      ceReloadPicker();
    };

    // groups
    V.COLOR_GROUPS.forEach(g => {
      const defs = V.COLOR_KEYS.filter(d => d.group === g.id);
      const box = el("div", "vg-ce-grp");
      const head = el("div", "vg-ce-gh");
      const title = el("span", null, g.label);
      const count = el("small");
      title.appendChild(count);
      head.append(title, el("span", null, "▼"));
      const body = el("div", "vg-ce-gb");
      defs.forEach(d => body.appendChild(ceRow(d)));
      box.append(head, body);
      head.onclick = () => {
        ce.groupsOpen[g.id] = !box.classList.contains("open");
        box.classList.toggle("open", ce.groupsOpen[g.id]);
      };
      c.appendChild(box);
      ce.groups.push({ id: g.id, el: box, count, defs });
    });

    const empty = el("div", "vg-ce-empty", "No colour matches that search.");
    c.appendChild(empty);
    c.appendChild(el("div", "vg-ce-note",
      "Changes apply while you edit. The target icon blinks a colour so you can see where it paints. " +
      "Drag the title bar to move this window, hold the eye to look through it."));

    ce.ui = { undo, redo, empty };
    q.oninput = () => { ce.query = q.value; ceFilter(); };
    ceRefreshAll();
    ceFilter();
    if (ce.open) ceBuildPicker();
  }

  // drag the panel by its title bar; double-click puts it back in the centre
  function dragPanel(p, handle) {
    handle.addEventListener("pointerdown", e => {
      if (e.button !== 0 || e.target.closest("button")) return;
      const rc = p.getBoundingClientRect();
      const dx = e.clientX - rc.left;
      const dy = e.clientY - rc.top;
      p.style.transform = "none";
      p.style.left = rc.left + "px";
      p.style.top = rc.top + "px";
      handle.setPointerCapture(e.pointerId);
      const move = ev => {
        p.style.left = Math.min(window.innerWidth - 80, Math.max(80 - rc.width, ev.clientX - dx)) + "px";
        p.style.top = Math.min(window.innerHeight - 40, Math.max(0, ev.clientY - dy)) + "px";
      };
      const up = () => {
        handle.removeEventListener("pointermove", move);
        handle.removeEventListener("pointerup", up);
        handle.removeEventListener("pointercancel", up);
      };
      handle.addEventListener("pointermove", move);
      handle.addEventListener("pointerup", up);
      handle.addEventListener("pointercancel", up);
    });
    handle.addEventListener("dblclick", e => {
      if (e.target.closest("button")) return;
      p.style.transform = p.style.left = p.style.top = "";
    });
  }

  // render active tab into container c
  function render(c) {
    renderedState = externalState();
    c.innerHTML = "";
    const V = window.VantagraphCustomData;
    const { FONT_PRESETS, applyFont, applySetting, getSetting } = V;

    if (activeTab === "colors") {
      renderColors(c);

    } else if (activeTab === "typography") {
      // tab: typography - font family + size
      c.appendChild(acc("Font Family", true, inner => {
        const cur = getSetting("font", "");
        const list = document.createElement("div"); list.className = "vg-rl";
        FONT_PRESETS.forEach(p => {
          const it = document.createElement("div"); it.className = "vg-ri" + (p.family === cur || (!cur && !p.family) ? " on" : "");
          const dot = document.createElement("div"); dot.className = "vg-rd";
          const rc = document.createElement("div"); rc.className = "vg-rc";
          const nm = document.createElement("div"); nm.className = "nm"; nm.textContent = p.name;
          if (p.url && !document.getElementById("vgfp-" + p.family.replace(/\s/g, ""))) { const lk = document.createElement("link"); lk.id = "vgfp-" + p.family.replace(/\s/g, ""); lk.rel = "stylesheet"; lk.href = p.url; document.head.appendChild(lk); }
          nm.style.fontFamily = p.family || "inherit";
          rc.appendChild(nm); it.appendChild(dot); it.appendChild(rc);
          it.onclick = () => { applyFont(p.family, p.url || ""); list.querySelectorAll(".vg-ri").forEach(x => x.classList.remove("on")); it.classList.add("on"); ci.style.display = cu.style.display = "none"; };
          list.appendChild(it);
        });
        // custom font input (auto-falls-back to Google Fonts URL)
        const isC = cur && !FONT_PRESETS.find(p => p.family === cur);
        const ci = document.createElement("input"); ci.className = "vg-fi"; ci.placeholder = "Font name"; ci.value = getSetting("custom-font", ""); ci.style.display = isC ? "block" : "none";
        const cu = document.createElement("input"); cu.className = "vg-fi"; cu.placeholder = "Google Fonts URL (optional)"; cu.value = getSetting("custom-font-url", ""); cu.style.display = isC ? "block" : "none";
        const cit = document.createElement("div"); cit.className = "vg-ri" + (isC ? " on" : "");
        const cd = document.createElement("div"); cd.className = "vg-rd";
        const crc = document.createElement("div"); crc.className = "vg-rc"; crc.style.cssText = "display:flex;align-items:center;";
        const cnm = document.createElement("div"); cnm.className = "nm"; cnm.textContent = "Custom...";
        const di = document.createElement("span"); di.className = "vg-di"; di.textContent = "✖"; di.title = "Clear";
        di.onclick = e => { e.stopPropagation(); clrFont(); };
        crc.appendChild(cnm); crc.appendChild(di); cit.appendChild(cd); cit.appendChild(crc);
        cit.onclick = () => { list.querySelectorAll(".vg-ri").forEach(x => x.classList.remove("on")); cit.classList.add("on"); ci.style.display = cu.style.display = "block"; ci.focus(); };
        list.appendChild(cit);
        inner.appendChild(list); inner.appendChild(ci); inner.appendChild(cu);

        function applyC() { const n = ci.value.trim(); if (!n) { clrFont(); return; } Spicetify.LocalStorage.set("vantagraph-custom:custom-font", n); Spicetify.LocalStorage.set("vantagraph-custom:custom-font-url", cu.value.trim()); let url = cu.value.trim(); if (!url && n) url = `https://fonts.googleapis.com/css2?family=${encodeURIComponent(n)}&display=swap`; applyFont(n, url); }
        function clrFont() { ["font","font-url","custom-font","custom-font-url"].forEach(k => Spicetify.LocalStorage.remove("vantagraph-custom:" + k)); applyFont("", ""); ci.value = cu.value = ""; ci.style.display = cu.style.display = "none"; list.querySelectorAll(".vg-ri").forEach(x => x.classList.remove("on")); list.querySelector(".vg-ri")?.classList.add("on"); }
        ci.addEventListener("keyup", () => { if (!ci.value.trim()) clrFont(); });
        ci.addEventListener("keydown", e => { if (e.key === "Enter") applyC(); });
        ci.addEventListener("blur", applyC);
        cu.addEventListener("keydown", e => { if (e.key === "Enter") applyC(); });
        cu.addEventListener("blur", applyC);
      }));
      c.appendChild(acc("Font Size", true, inner => {
        inner.appendChild(slider("Size", 10, 20, 1, getSetting("font-size", "14"), "px", v => applySetting("font-size", v)));
      }));

    } else if (activeTab === "layout") {
      // tab: layout - icon size, density, corners
      c.appendChild(acc("Layout", true, inner => {
        inner.appendChild(slider("Icon Size", 12, 34, 0.5, getSetting("icon-size", "default"), "px", v => applySetting("icon-size", v), "23"));
        const dl = document.createElement("div"); dl.style.cssText = "font-size:10px;color:#A7A7A7;margin:8px 0 4px;"; dl.textContent = "Density"; inner.appendChild(dl);
        const dr = document.createElement("div"); dr.className = "vg-dr";
        const cd = getSetting("density", "default");
        ["compact", "default", "comfortable"].forEach(d => {
          const b = document.createElement("button"); b.className = d === cd ? "on" : ""; b.textContent = d.charAt(0).toUpperCase() + d.slice(1);
          b.onclick = () => { applySetting("density", d); dr.querySelectorAll("button").forEach(x => x.classList.remove("on")); b.classList.add("on"); };
          dr.appendChild(b);
        });
        inner.appendChild(dr);
        inner.appendChild(slider("Corners", 0, 24, 1, getSetting("border-radius", "default"), "px", v => applySetting("border-radius", v), "12"));
      }));

    } else if (activeTab === "background") {
      // tab: background - custom URL, album cover, filters
      c.appendChild(acc("Background Image", true, inner => {
        const bi = document.createElement("input"); bi.className = "vg-fi"; bi.placeholder = "Image URL (empty = solid)"; bi.value = getSetting("bg-url", ""); bi.style.marginTop = "0";
        function upd() { const u = bi.value.trim(); Spicetify.LocalStorage.set("vantagraph-custom:bg-url", u); applySetting("bg-url", u); }
        bi.addEventListener("keyup", () => { if (!bi.value.trim()) { Spicetify.LocalStorage.set("vantagraph-custom:bg-url", ""); applySetting("bg-url", ""); } });
        bi.addEventListener("keydown", e => { if (e.key === "Enter") upd(); });
        bi.addEventListener("blur", upd);
        inner.appendChild(bi);
        inner.appendChild(tog("Album Cover as BG", getSetting("bg-use-album-cover", "false") === "true", v => applySetting("bg-use-album-cover", String(v))));
      }));
      c.appendChild(acc("Image Filters", false, inner => {
        inner.appendChild(slider("Blur", 0, 50, 1, getSetting("bg-blur", "0"), "px", v => applySetting("bg-blur", v)));
        inner.appendChild(slider("Brightness", 0, 200, 5, getSetting("bg-brightness", "100"), "%", v => applySetting("bg-brightness", v)));
        inner.appendChild(slider("Contrast", 0, 200, 5, getSetting("bg-contrast", "100"), "%", v => applySetting("bg-contrast", v)));
        inner.appendChild(slider("Saturation", 0, 200, 5, getSetting("bg-saturation", "100"), "%", v => applySetting("bg-saturation", v)));
      }));

    } else if (activeTab === "snippets") {
      // tab: snippets - visual / hide buttons / hide elements / layout / dev tools
      c.appendChild(acc("Visual", true, inner => {
        [
          { k: "snippet-rounded-images", l: "Rounded Images", def: "true" },
          { k: "snippet-modern-scrollbar", l: "Modern ScrollBar", def: "true" },
        ].forEach(s => {
          inner.appendChild(tog(s.l, getSetting(s.k, s.def) !== "false", v => applySetting(s.k, String(v))));
        });
        // vinyl stop: default OFF
        inner.appendChild(tog("Stop Vinyl Animation", getSetting("snippet-vinyl-stop", "false") === "true", v => applySetting("snippet-vinyl-stop", String(v))));
        // reduced motion: default OFF, collapses Spotify's transitions to 1ms
        inner.appendChild(tog("Reduced Motion", getSetting("snippet-reduced-motion", "false") === "true", v => applySetting("snippet-reduced-motion", String(v))));
      }));

      // hide buttons (player bar + topbar controls)
      c.appendChild(acc("Hide Buttons", false, inner => {
        [
          { k: "snippet-hide-friend-activity", l: "Friend Activity Button" },
          { k: "snippet-hide-whats-new",       l: "What's New Button" },
          { k: "snippet-hide-fullscreen",      l: "Fullscreen Button" },
          { k: "snippet-hide-lyrics-btn",      l: "Lyrics Button" },
          { k: "snippet-hide-miniplayer",      l: "Mini Player Button" },
          { k: "snippet-hide-queue-btn",       l: "Queue Button" },
          { k: "snippet-hide-shuffle",         l: "Shuffle Button" },
          { k: "snippet-hide-repeat",          l: "Repeat Button" },
          { k: "snippet-hide-connect",         l: "Connect Device Button" },
          { k: "snippet-hide-volume",          l: "Volume Bar" },
          { k: "snippet-hide-np-widget",       l: "Now Playing Widget" },
          { k: "snippet-hide-next-track",      l: "Next Track Widget" },
        ].forEach(s => {
          inner.appendChild(tog(s.l, getSetting(s.k, "false") === "true", v => applySetting(s.k, String(v))));
        });
      }));

      // hide elements (home sections + interface)
      c.appendChild(acc("Hide Elements", false, inner => {
        [
          { k: "snippet-hide-podcasts",        l: "Podcasts Filter" },
          { k: "snippet-hide-ads-banner",      l: "Ads Banner" },
          { k: "snippet-hide-promo-card",     l: "New Release Promo Card" },
          { k: "snippet-hide-mood-recs",      l: "Mood / Time Recommendations" },
          { k: "snippet-hide-home-shortcuts",  l: "Home Shortcuts Grid" },
          { k: "snippet-hide-made-for-you",    l: "Made For You" },
          { k: "snippet-hide-recents",         l: "Recents" },
          { k: "snippet-hide-top-mixes",       l: "Top Mixes" },
          { k: "snippet-hide-jump-back",       l: "Jump Back In" },
          { k: "snippet-hide-rec-stations",    l: "Recommended Stations" },
          { k: "snippet-hide-new-releases",    l: "New Releases" },
          { k: "snippet-hide-best-artists",    l: "Best of Artists" },
          { k: "snippet-hide-fav-artists",     l: "Favorite Artists" },
          { k: "snippet-hide-rec-today",       l: "Recommended for Today" },
        ].forEach(s => {
          inner.appendChild(tog(s.l, getSetting(s.k, "false") === "true", v => applySetting(s.k, String(v))));
        });
      }));

      // layout
      c.appendChild(acc("Layout", false, inner => {
        [
          { k: "snippet-thin-library",       l: "Thin Library Rows" },
          { k: "snippet-auto-hide-sidebar",  l: "Auto-hide Sidebar (<1200px)" },
        ].forEach(s => {
          inner.appendChild(tog(s.l, getSetting(s.k, "false") === "true", v => applySetting(s.k, String(v))));
        });
      }));

      // dev tools
      c.appendChild(acc("🛠️ Developer Tools", false, inner => {
        [
          { k: "debug-labels",                l: "Panel Labels" },
          { k: "snippet-dev-layout-grid",      l: "Layout Grid Visualizer" },
          { k: "snippet-dev-highlighter",      l: "Element Highlighter" },
          { k: "snippet-dev-spacing-viz",      l: "Spacing Visualizer" },
          { k: "snippet-dev-var-monitor",      l: "CSS Variable Monitor" },
          { k: "snippet-dev-dom-logger",       l: "DOM Mutation Logger" },
        ].forEach(s => {
          inner.appendChild(tog(s.l, getSetting(s.k, "false") === "true", v => applySetting(s.k, String(v))));
        });
        const auditBtn = document.createElement("button");
        auditBtn.style.cssText = "width:100%;padding:8px;background:#2a2a2a;color:#dda0dd;border:1px solid #444;border-radius:6px;font-size:11px;cursor:pointer;margin-top:6px;transition:background 0.2s;";
        auditBtn.textContent = "▶ Run Encore Audit";
        auditBtn.onmouseenter = () => auditBtn.style.background = "#3a3a3a";
        auditBtn.onmouseleave = () => auditBtn.style.background = "#2a2a2a";
        auditBtn.onclick = () => { applySetting("snippet-dev-encore-audit", "true"); };
        inner.appendChild(auditBtn);
      }));
    }

    // reset button: full wipe (storage + injected styles + inline vars + classes)
    const rb = ibtn("vg-rb", "reset", "Reset to Defaults");
    rb.onclick = () => {
      if (!confirm("Reset all Vantagraph Custom settings? Colours go back to VantagraphBlack.")) return;

      // 1. clear all vantagraph-custom:* localStorage keys
      const keysToRemove = [];
      for (let i = 0; i < localStorage.length; i++) {
        const k = localStorage.key(i);
        if (k?.startsWith("vantagraph-custom:")) keysToRemove.push(k);
      }
      keysToRemove.forEach(k => Spicetify.LocalStorage.remove(k));

      // 1b. extension keys (lyric / volume+)
      ["fontsize", "showfont", "showvol", "showlyrics", "showshuffle",
       "showlike", "showclose", "centerlyrics", "showtranslations"
      ].forEach(k => localStorage.removeItem("vg-lyric-" + k));
      ["default-increment", "shift-increment", "ctrl-increment"
      ].forEach(k => Spicetify.LocalStorage.remove("vg-volume-plus." + k));

      // 2. remove injected <style>/<link> elements
      const injectedIds = [
        // core engine
        "vantagraph-font", "vantagraph-font-link",
        "vantagraph-fontsize", "vantagraph-iconsize",
        "vantagraph-density", "vantagraph-border-radius",
        "vantagraph-bg-element",
        "vantagraph-debug-labels",
        // visual snippets
        "vantagraph-snippet-modern-scrollbar",
        "vantagraph-snippet-rounded-images-off",
        "vantagraph-snippet-dark-context-menu",
        "vantagraph-snippet-vinyl-stop",
        "vantagraph-snippet-reduced-motion",
        // hide buttons (topbar + player bar)
        "vantagraph-snippet-hide-friend-activity",
        "vantagraph-snippet-hide-whats-new",
        "vantagraph-snippet-hide-fullscreen",
        "vantagraph-snippet-hide-lyrics-btn",
        "vantagraph-snippet-hide-miniplayer",
        "vantagraph-snippet-hide-queue-btn",
        "vantagraph-snippet-hide-shuffle",
        "vantagraph-snippet-hide-repeat",
        "vantagraph-snippet-hide-connect",
        "vantagraph-snippet-hide-volume",
        "vantagraph-snippet-hide-np-widget",
        "vantagraph-snippet-hide-next-track",
        // hide elements (ads + home sections)
        "vantagraph-snippet-hide-ads-banner",
        "vantagraph-snippet-hide-podcasts",
        "vantagraph-snippet-hide-promo-card",
        "vantagraph-snippet-hide-mood-recs",
        "vantagraph-snippet-hide-made-for-you",
        "vantagraph-snippet-hide-recents",
        "vantagraph-snippet-hide-top-mixes",
        "vantagraph-snippet-hide-jump-back",
        "vantagraph-snippet-hide-rec-stations",
        "vantagraph-snippet-hide-new-releases",
        "vantagraph-snippet-hide-best-artists",
        "vantagraph-snippet-hide-fav-artists",
        "vantagraph-snippet-hide-rec-today",
        "vantagraph-snippet-hide-home-shortcuts",
        // layout
        "vantagraph-snippet-thin-library",
        "vantagraph-snippet-auto-hide-sidebar",
        // dev tools
        "vantagraph-snippet-dev-layout-grid",
        "vantagraph-snippet-dev-highlighter",
        "vantagraph-snippet-dev-spacing-viz",
        // extensions
        "vg-volume-plus-css", "vg-volume-plus-style",
      ];
      injectedIds.forEach(id => { const el = document.getElementById(id); if (el) el.remove(); });

      // 3. clear inline --spice-* / --vg-* from :root
      const root = document.documentElement;
      const allProps = root.style.cssText.match(/--(?:spice|vg)-[^:]+/g) || [];
      allProps.forEach(prop => root.style.removeProperty(prop.trim()));

      // 4. remove body classes
      document.body.classList.remove("vg-bg-active", "vg-debug");
      document.body.style.background = "";

      // 4a. dev tool cleanup (var monitor, dom logger, spacing viz overlays)
      const varMon = document.getElementById("vg-var-monitor");
      if (varMon) { clearInterval(parseInt(varMon.dataset.tid)); varMon.remove(); }
      if (window._vgMutObs) { window._vgMutObs.disconnect(); window._vgMutObs = null; }
      document.querySelectorAll("[id^='vg-spacing-']").forEach(el => el.remove());

      // 4b. clear inline bg styles set by BG engine
      const vgRoot = document.querySelector(".vg-root");
      if (vgRoot) vgRoot.style.removeProperty("background");
      const topContainer = document.querySelector(".Root__top-container");
      if (topContainer) topContainer.style.removeProperty("background");

      // 4c. volume+ cleanup (label + width overrides)
      const volLabel = document.getElementById("vg-vol-pct-label");
      if (volLabel) volLabel.remove();
      const volBar = document.querySelector("[data-testid='volume-bar']");
      if (volBar) { volBar.style.removeProperty("width"); volBar.style.removeProperty("min-width"); volBar.style.removeProperty("transition"); }
      const volSlider = volBar?.querySelector(".volume-bar__slider-container");
      if (volSlider) { volSlider.style.removeProperty("width"); volSlider.style.removeProperty("transition"); }

      // 5. default colours (undoable from the Colors tab) + font
      ceBegin(); V.setColorOverrides({}); ceEnd();
      applyFont("", "");

      // 6. re-init modern scrollbar (default ON)
      applySetting("snippet-modern-scrollbar", "true");

      Spicetify.showNotification("Settings reset ✓");
      render(c);
    };
    c.appendChild(rb);
  }

  // topbar button: right side via Spicetify.Topbar.Button (update-safe, never unmounts)
  function init() {
    // own button icon, embedded (source: src/assets/icons/vantagraph-theme.svg)
    const SETTINGS_ICON = '<svg data-encore-id="icon" role="img" aria-hidden="true" viewBox="0 0 32.02 31.55" fill="currentColor" style="--encore-icon-height: var(--encore-graphic-size-decorative-smaller); --encore-icon-width: var(--encore-graphic-size-decorative-smaller);"><path d="M25.06,23.39v-7.58c.01-.86.7-1.51,1.52-1.5s1.49.64,1.49,1.5v7.53c0,4.07-3.29,7.48-7.38,7.48h-12.24c-4.06,0-7.42-3.35-7.42-7.41v-12.24c0-4.09,3.42-7.39,7.49-7.39h7.53c.86,0,1.5.7,1.5,1.49s-.64,1.51-1.5,1.51h-7.39c-2.61,0-4.64,2.01-4.64,4.61v11.86c0,2.49,1.94,4.57,4.46,4.57h12.06c2.45,0,4.52-1.93,4.52-4.43Z"/><path d="M7.98,24.26c-1.14-1.32-1.09-3.18-.7-4.77.43-1.74,1.19-3.34,2.24-4.79,1.17-1.62,3.06-2.52,5.04-2.37.12-1.16.52-2.39,1.49-3.15L25.92,1.39c1.32-1.04,3.22-.73,4.3.45s1.14,2.99.11,4.3l-7.72,9.73c-.68.85-1.75,1.19-2.79,1.4.24,1.86-.29,3.69-1.58,5.02s-3,1.89-4.79,1.73c-1.28-.11-2.5.15-3.65.67-.65.29-1.34.13-1.81-.42ZM20.38,13.83l7.65-9.63c.09-.12,0-.31-.07-.35-.06-.03-.2-.11-.3-.03l-9.62,7.63c-.72.57-.59,1.73,0,2.33.55.56,1.75.78,2.34.04ZM13.48,21.04c.97.1,1.89-.12,2.56-.8,1.05-1.06,1.12-2.73.19-3.89-1.03-1.29-2.91-1.36-4.04-.15-1.19,1.47-1.96,3.2-2.17,5.18,1.15-.24,2.25-.45,3.46-.33Z"/></svg>';

    const settingsBtn = new Spicetify.Topbar.Button(
      "Vantagraph Custom",
      SETTINGS_ICON,
      toggle,
      false,
      true
    );
    // custom class: stable CSS targeting hook
    if (settingsBtn.element) settingsBtn.element.classList.add("vg-topbar-btn");
  }

  waitForVantagraphCustomData(init);
})();
