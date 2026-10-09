// Vantagraph Custom Debug - colour override inspector (console copy of the extension)
// Paste into DevTools console OR load as extension.
// Output: Spotify (Encore) default -> Spicetify --spice-* -> colour editor inline override

(function VantagraphDebug() {

  const cs      = getComputedStyle(document.documentElement);
  const rootEl  = document.documentElement;

  // --- Collect all CSS custom property definitions from every stylesheet ---
  const allDefs = []; // { prop, value, selector, href }
  for (const sheet of document.styleSheets) {
    let rules;
    try { rules = sheet.cssRules; } catch(e) { continue; }
    for (const rule of rules) {
      if (!rule.style) continue;
      for (let i = 0; i < rule.style.length; i++) {
        const prop = rule.style[i];
        if (!prop.startsWith("--")) continue;
        allDefs.push({
          prop,
          value:    rule.style.getPropertyValue(prop).trim(),
          selector: rule.selectorText || "",
          href:     sheet.href || (sheet.ownerNode?.id ? `#${sheet.ownerNode.id}` : "inline"),
        });
      }
    }
  }

  // --- Layer 1: Spotify / Encore dark theme defaults ---
  // These live in rules that target `.encore-dark-theme` or `.encore-base-set`
  const encoreDefMap = {};
  for (const d of allDefs) {
    if (d.selector.includes("encore-dark-theme") || d.selector.includes("encore-base-set")) {
      // first definition wins (closest to native)
      if (!encoreDefMap[d.prop]) encoreDefMap[d.prop] = d.value;
    }
  }

  // --- Layer 2: Spicetify --spice-* from stylesheets (color.ini compiled output) ---
  // These are set on :root or html by Spicetify's injected stylesheet, NOT inline.
  const spiceSheetMap = {};
  for (const d of allDefs) {
    if (!d.prop.startsWith("--spice-")) continue;
    const sel = d.selector;
    if (sel === ":root" || sel === "html" || sel === ":root, html") {
      if (!spiceSheetMap[d.prop]) spiceSheetMap[d.prop] = { value: d.value, href: d.href };
    }
  }

  // --- Layer 3: colour editor inline overrides (theme.js writeColorVars) ---
  const vgInlineMap = {};
  for (let i = 0; i < rootEl.style.length; i++) {
    const prop = rootEl.style[i];
    vgInlineMap[prop] = rootEl.style.getPropertyValue(prop).trim();
  }

  function live(prop) {
    return cs.getPropertyValue(prop).trim() || "(unset)";
  }

  const changedColors = (() => {
    try { return Object.keys(JSON.parse(Spicetify.LocalStorage.get("vantagraph-custom:colors") || "{}")).length; } catch(e) { return "?"; }
  })();

  // -----------------------------------------------------------------------
  console.group(`%cVantagraph Custom Color Debug  [changed colours: ${changedColors}]`, "font-size:14px;font-weight:bold;color:#1ed760;background:#111;padding:2px 6px;border-radius:4px");

  // BLOCK A: Encore tokens - what Spotify sets vs what's computed now
  const ENCORE_TOKENS = [
    "--background-base",
    "--background-highlight",
    "--background-press",
    "--background-elevated-base",
    "--background-elevated-highlight",
    "--background-elevated-press",
    "--background-tinted-base",
    "--background-tinted-highlight",
    "--background-tinted-press",
    "--text-base",
    "--text-subdued",
    "--text-bright-accent",
    "--text-negative",
    "--text-warning",
    "--text-positive",
    "--text-announcement",
    "--essential-base",
    "--essential-subdued",
    "--essential-bright-accent",
    "--essential-negative",
    "--essential-warning",
    "--essential-positive",
    "--essential-announcement",
    "--decorative-base",
    "--decorative-subdued",
  ];

  console.group("%c[A] Encore Tokens  - Spotify default → computed (final)", "color:#f0a030;font-weight:bold");
  const encoreRows = ENCORE_TOKENS.map(token => {
    const spotifyDefault = encoreDefMap[token] || "(not found in sheet)";
    const computed       = live(token);
    const isPatched      = spotifyDefault.includes("var(--spice");
    const changed        = spotifyDefault !== computed;
    return {
      token,
      "Spotify default":   spotifyDefault,
      "Computed (final)":  computed,
      "Patched by Spice?": isPatched ? "YES (var ref)" : (changed ? "overridden" : "same"),
    };
  });
  console.table(encoreRows);
  console.groupEnd();

  // BLOCK B: --spice-* - Spicetify sheet value vs Vantagraph inline override
  const allSpiceProps = new Set([
    ...Object.keys(spiceSheetMap),
    ...Object.keys(vgInlineMap).filter(p => p.startsWith("--spice-")),
  ]);

  console.group("%c[B] --spice-* vars  - Spicetify (color.ini) → Vantagraph override → computed", "color:#4488ff;font-weight:bold");
  const spiceRows = [...allSpiceProps].sort().map(prop => {
    const spiceVal = spiceSheetMap[prop]?.value || "(not in sheet)";
    const vgVal    = vgInlineMap[prop]          || "(not overridden)";
    const final    = live(prop);
    const src      = spiceSheetMap[prop]?.href  || "";
    return {
      variable:                prop,
      "Spicetify (sheet)":     spiceVal,
      "Vantagraph (inline)":   vgVal,
      "Computed (final)":      final,
      "Sheet source":          src.split("/").pop(),
    };
  });
  console.table(spiceRows);
  console.groupEnd();

  // BLOCK C: ALL Vantagraph inline overrides (full list, not just --spice-*)
  console.group("%c[C] All inline overrides on :root  (colour editor output)", "color:#1ed760;font-weight:bold");
  const vgRows = Object.entries(vgInlineMap).sort(([a],[b]) => a.localeCompare(b)).map(([prop, val]) => ({
    variable: prop,
    value:    val,
  }));
  console.table(vgRows);
  console.groupEnd();

  // BLOCK D: Mismatches - Vantagraph inline != computed (something else winning)
  console.group("%c[D] Anomalies - inline set but computed differs (higher-specificity rule winning?)", "color:#ff6060;font-weight:bold");
  let anomalyCount = 0;
  for (const [prop, val] of Object.entries(vgInlineMap)) {
    const computed = live(prop);
    if (computed !== val && computed !== "(unset)") {
      console.warn(`  ${prop}: inline="${val}"  but computed="${computed}"`);
      anomalyCount++;
    }
  }
  if (anomalyCount === 0) console.log("  No anomalies found.");
  console.groupEnd();

  console.groupEnd(); // root

  // expose for re-run
  window._vgDebug = VantagraphDebug;
  console.log("%cRe-run: _vgDebug()", "color:#888");

})();
