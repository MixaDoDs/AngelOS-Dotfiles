// Captures the README / Marketplace screenshots straight from Spotify.
//
// 1. Start Spotify with a local debugging port (close it first):
//      Spotify.exe --remote-debugging-port=9222
// 2. node src/utils/screenshots/capture.js
// 3. python src/utils/screenshots/compose.py   (preview.png, preview.gif)
// 4. Restart Spotify normally so the port closes.
//
// The script saves the user's vantagraph-custom:* settings first and puts
// them back at the end. The library is switched to Artists and the profile
// picture hidden, so no private playlist names or photos end up in a shot.

const fs = require("fs");
const path = require("path");
const { connect, sleep } = require("./cdp");

const OUT = path.resolve(__dirname, "..", "..", "..", "design", "screenshots");
const RAW = path.join(OUT, "palettes");
const VIEW = { width: 1600, height: 900 };
const ALBUM = "/album/4m2880jivSbbyEGAKfITCa"; // a public album page, same for every shot

// the Share panel's example, used for the editor shots so the two match
const PLUM_NIGHT = {
  window: "#0F0B16", panel: "#171120", "panel-hover": "#221A2E", menu: "#261D33", player: "#0C0912",
  stroke: "#2E2340", text: "#EDE6F5", subtext: "#9C8FB0", accent: "#C79BFF", "btn-active": "#C79BFF",
  "play-btn": "#C79BFF", "play-btn-hover": "#DDBFFF", "play-icon": "#171120", "bar-fill": "#C79BFF",
  "bar-bg": "rgba(199, 155, 255, 0.2)", heart: "#FF5C8A", "row-hover": "rgba(199, 155, 255, 0.08)",
};

// showcase palettes: saturated enough panels to tell apart on a small card
const dark = (window, panel, hover, menu, player, stroke, text, subtext, accent, accentHover, heart, rgb) => ({
  window, panel, "panel-hover": hover, "tab-active": hover, menu, player, stroke, text, subtext,
  accent, "btn-active": accent, "play-btn": accent, "play-btn-hover": accentHover, "play-icon": panel,
  "bar-fill": accent, "bar-bg": `rgba(${rgb}, 0.22)`, heart, "row-hover": `rgba(${rgb}, 0.1)`,
});
const PALETTES = {
  vantagraphblack: {},
  plum: dark("#1B1030", "#2A1B45", "#36245A", "#3D2966", "#150C26", "#4A3378", "#F3ECFF", "#B7A6D6", "#C79BFF", "#DDBFFF", "#FF5C8A", "199, 155, 255"),
  ocean: dark("#06202B", "#0C3344", "#134457", "#16495D", "#051A23", "#1D5568", "#E6F7FA", "#8DB9C6", "#38D1C8", "#7AE6DF", "#FF6B6B", "56, 209, 200"),
  forest: dark("#0A2216", "#113522", "#18452D", "#1B4B31", "#081B11", "#22563A", "#E9F8EF", "#93BFA4", "#5EE39A", "#9BF0C0", "#FF6F91", "94, 227, 154"),
  ember: dark("#24100A", "#3A1A0F", "#4A2415", "#512818", "#1C0C07", "#5E301C", "#FFF0E6", "#D0A58C", "#FF8A3D", "#FFB27A", "#FF4D6D", "255, 138, 61"),
  paper: {
    window: "#E4E0D8", panel: "#F6F4EF", "panel-hover": "#ECE8E0", menu: "#FFFFFF", player: "#EFEBE4",
    stroke: "#DAD4C8", "tab-active": "#E4DED3", text: "#1D1B18", subtext: "#6F695F", accent: "#C4552D",
    "btn-active": "#C4552D", "play-btn": "#1D1B18", "play-btn-hover": "#C4552D", "play-icon": "#F6F4EF",
    "bar-fill": "#C4552D", "bar-bg": "rgba(29, 27, 24, 0.15)", heart: "#C4552D",
    "row-hover": "rgba(29, 27, 24, 0.05)", divider: "rgba(29, 27, 24, 0.08)", shine: "rgba(255, 255, 255, 0.6)",
    shadow: "#8C8272", "selected-row": "#1D1B18", misc: "#8A8478",
  },
};

(async () => {
  fs.mkdirSync(RAW, { recursive: true });
  const c = await connect();
  const js = expr => c.evaluate(expr);
  const shot = async name => {
    await sleep(700);
    fs.writeFileSync(path.join(name.startsWith("palette-") ? RAW : OUT, name + ".png"), await c.screenshot());
    console.log("saved", name);
  };

  // library filter chips are react-aria options: they need real pointer input,
  // element.click() does nothing. While a filter is on, the first chip is an
  // empty "clear" chip and the second is the active filter.
  const OPTIONS = `[...document.querySelectorAll('#Desktop_LeftSidebar_Id [role="option"]')]`;
  let libraryFilter = "";
  const activeFilter = () => js(`(() => { const o = ${OPTIONS}; return o.length && !o[0].textContent.trim() ? o[1].textContent.trim() : ""; })()`);
  const press = async index => {
    const r = await js(`(() => { const o = ${OPTIONS}[${index}]; if (!o) return null; const b = o.getBoundingClientRect(); return { x: b.x + b.width / 2, y: b.y + b.height / 2 }; })()`);
    if (!r) return false;
    for (const type of ["mousePressed", "mouseReleased"]) {
      await c.send("Input.dispatchMouseEvent", { type, x: r.x, y: r.y, button: "left", clickCount: 1 });
    }
    await sleep(800);
    return true;
  };
  const chip = async text => {
    if (!text) return;
    const i = await js(`${OPTIONS}.findIndex(o => o.textContent.trim() === ${JSON.stringify(text)})`);
    if (i >= 0) await press(i);
  };
  const clearFilter = async () => { if (await activeFilter()) await press(0); };

  // save what the user had
  const saved = await js(`(() => { const o = {}; for (let i = 0; i < localStorage.length; i++) { const k = localStorage.key(i); if (k.startsWith("vantagraph-custom:")) o[k] = localStorage.getItem(k); } return o; })()`);

  try {
    // wait for the theme, its settings button and the library chips
    for (let i = 0; ; i++) {
      const ready = await js(`!!(window.VantagraphCustomData && document.querySelector('button[aria-label="Vantagraph Custom"]') && ${OPTIONS}.length)`);
      if (ready) break;
      if (i > 60) throw new Error("Spotify UI did not finish loading");
      await sleep(500);
    }
    await c.send("Emulation.setDeviceMetricsOverride", { width: VIEW.width, height: VIEW.height, deviceScaleFactor: 1, mobile: false });

    // privacy: no avatar, library shows artists instead of personal playlists
    await js(`(() => {
      let s = document.getElementById("vgc-shot-style");
      if (!s) { s = document.createElement("style"); s.id = "vgc-shot-style"; document.head.appendChild(s); }
      s.textContent = '.main-userWidget-box, .vg-user-widget, [data-testid="user-widget-link"] { visibility: hidden !important; }';
      return true;
    })()`);
    libraryFilter = await activeFilter();
    await clearFilter();
    await chip("Artists");
    const shown = await activeFilter();
    if (shown !== "Artists") throw new Error("library filter did not switch to Artists (" + shown + "), refusing to capture personal playlists");

    await js(`Spicetify.Platform.History.push(${JSON.stringify(ALBUM)})`);
    await sleep(3000);

    const V = "window.VantagraphCustomData";
    const setPalette = p => js(`${V}.setColorOverrides(${JSON.stringify(p)})`);

    // one shot per palette, same page
    for (const [name, p] of Object.entries(PALETTES)) {
      await setPalette(p);
      await shot("palette-" + name);
    }

    // the editor: Colors tab with the Accent picker open
    await setPalette(PLUM_NIGHT);
    await js(`document.querySelector('button[aria-label="Vantagraph Custom"]').click()`);
    await sleep(500);
    await js(`(() => {
      const row = [...document.querySelectorAll(".vg-ce-row")].find(r => r.querySelector(".vg-ce-nm")?.firstChild?.textContent === "Accent");
      const grp = row.closest(".vg-ce-grp");
      if (!grp.classList.contains("open")) grp.querySelector(".vg-ce-gh").click();
      row.querySelector(".vg-ce-sw").click();
      const sc = document.querySelector(".vg-sc");
      sc.scrollTop = row.offsetTop - sc.offsetTop - 8;
      return true;
    })()`);
    await shot("editor-picker");

    // share panel with the example
    await js(`(() => {
      const open = document.querySelector(".vg-ce-row.open .vg-ce-sw"); if (open) open.click();
      const share = [...document.querySelectorAll(".vg-ce-b")].find(b => b.textContent.includes("Share"));
      if (document.querySelector(".vg-ce-io").style.display === "none") share.click(); // it toggles
      document.querySelector(".vg-sc").scrollTop = 0;
      return document.querySelector(".vg-ce-io").style.display === "";
    })()`).then(open => { if (!open) throw new Error("share panel did not open"); });
    await shot("editor-share");

    // background image mode: album cover behind glass panels
    await js(`document.querySelector('.vg-sp .vg-sh button[title="Close"]').click()`);
    await setPalette(PALETTES.ocean);
    await js(`${V}.applySetting("bg-blur", "0"); ${V}.applySetting("bg-use-album-cover", "true")`);
    await sleep(2500);
    await shot("background-glass");
    await js(`${V}.applySetting("bg-use-album-cover", "false")`);
    await sleep(800);
  } finally {
    // put the user's settings back exactly
    await js(`(() => {
      const saved = ${JSON.stringify(saved)};
      const now = []; for (let i = 0; i < localStorage.length; i++) { const k = localStorage.key(i); if (k.startsWith("vantagraph-custom:")) now.push(k); }
      now.forEach(k => { if (!(k in saved)) localStorage.removeItem(k); });
      Object.entries(saved).forEach(([k, v]) => localStorage.setItem(k, v));
      window.VantagraphCustomData.setColorOverrides(JSON.parse(saved["vantagraph-custom:colors"] || "{}"));
      const s = document.getElementById("vgc-shot-style"); if (s) s.remove();
      const panel = document.querySelector(".vg-sp.open"); if (panel) panel.classList.remove("open");
      return true;
    })()`).catch(e => console.error("restore failed:", e.message));
    // library filter back to what it was
    if ((await activeFilter().catch(() => libraryFilter)) !== libraryFilter) {
      await clearFilter().catch(() => {});
      await chip(libraryFilter).catch(() => {});
    }
    await c.send("Emulation.clearDeviceMetricsOverride").catch(() => {});
    c.close();
  }
})().catch(e => { console.error(e); process.exit(1); });
