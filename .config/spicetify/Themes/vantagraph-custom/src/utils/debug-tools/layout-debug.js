// VANTAGRAPH - LAYOUT DIAGNOSTIC v4
// Paste into Spotify DevTools Console (F12)
// v4: Density state, bar overflow detection, vertical gap analysis,

(() => {
  const C = {
    h:   "color:#00ff88;font-weight:bold;font-size:14px",
    s:   "color:#00bfff;font-weight:bold;font-size:12px",
    w:   "color:#ffaa00;font-weight:bold",
    e:   "color:#ff4444;font-weight:bold",
    g:   "color:#888;font-style:italic",
    n:   "color:#ccc",
    k:   "color:#aaa",
    v:   "color:#fff;font-weight:bold",
    ok:  "color:#00ff88;font-weight:bold",
    bad: "color:#ff4444;font-weight:bold",
    snap:"color:#ffe066;font-weight:bold;font-size:13px",
  };

  const cs   = (el) => el ? getComputedStyle(el) : null;
  const rect = (el) => el ? el.getBoundingClientRect() : null;
  const px   = (v)  => parseFloat(v) || 0;
  const r2   = (n)  => Math.round(n * 100) / 100;

  //- Element finder -
  const topBarEl    = document.querySelector(".Root__globalNav")
                   || document.querySelector(".Root__top-bar");
  const topContEl   = document.querySelector(".Root__top-container");
  const leftEl      = document.querySelector("#Desktop_LeftSidebar_Id");
  const mainEl      = document.querySelector(".Root__main-view")
                   || document.querySelector(".vg-main");
  const rightEl     = document.querySelector(".Root__right-sidebar")
                   || document.querySelector(".vg-right");
  const playerEl    = document.querySelector(".Root__now-playing-bar");
  const ntCardEl    = document.getElementById("vg-next-track-card");
  const bodyClasses = [...document.body.classList].join(" ");

  //- Density state -
  const densityEl   = document.getElementById("vantagraph-density");
  const densityMode = (() => {
    try { return localStorage.getItem("vantagraph-custom:density") || "default"; }
    catch { return "unknown"; }
  })();

  //- Viewport -
  const vw = window.innerWidth;
  const vh = window.innerHeight;

  //- Shorthand rect + computed together -
  function snap(el) {
    if (!el) return null;
    const r = rect(el);
    const s = cs(el);
    return {
      top:    r2(r.top),    bottom: r2(r.bottom),
      left:   r2(r.left),  right:  r2(r.right),
      width:  r2(r.width), height: r2(r.height),
      marginTop:    s.marginTop,    marginBottom: s.marginBottom,
      marginLeft:   s.marginLeft,   marginRight:  s.marginRight,
      paddingTop:   s.paddingTop,   paddingBottom:s.paddingBottom,
      paddingLeft:  s.paddingLeft,  paddingRight: s.paddingRight,
      gap: s.gap, rowGap: s.rowGap, columnGap: s.columnGap,
      position: s.position,
      display:  s.display,
      overflow: s.overflow,
      contain:  s.contain,
      zIndex:   s.zIndex,
      borderRadius:   s.borderRadius,
      backdropFilter: s.backdropFilter || s.webkitBackdropFilter || "none",
      backgroundColor:s.backgroundColor,
    };
  }

  const TB  = snap(topBarEl);
  const TC  = snap(topContEl);
  const L   = snap(leftEl);
  const M   = snap(mainEl);
  const R   = snap(rightEl);
  const PB  = snap(playerEl);
  const NT  = snap(ntCardEl);

  //- Gap & overflow calculations -
  //Vertical: space between top bar bottom and panel top
  const gapTopToPanel    = TB && L  ? r2(L.top  - TB.bottom)  : null;
  //Vertical: space between panel bottom and player bar top
  const gapPanelToPlayer = L  && PB ? r2(PB.top - L.bottom)   : null;
  //Horizontal gaps between panels
  const gapLM = L && M  ? r2(M.left  - L.right)  : null;
  const gapMR = M && R  ? r2(R.left  - M.right)  : null;

  //Overflow checks (negative = panel bleeds INTO bar)
  const overflowTop    = gapTopToPanel    !== null && gapTopToPanel    < 0;
  const overflowBottom = gapPanelToPlayer !== null && gapPanelToPlayer < 0;

  //Panel alignment
  const panelTopsMatch    = L && M && R ? (L.top === M.top && M.top === R.top) : null;
  const panelBottomsMatch = L && M && R ? (L.bottom === M.bottom && M.bottom === R.bottom) : null;

  //
  console.log("%c VANTAGRAPH LAYOUT SNAPSHOT", C.snap);

  const fmt = (label, val, bad) => {
    const style = bad ? C.bad : C.ok;
    console.log(`%c  ${label.padEnd(34)} %c${val}`, C.k, style);
  };

  fmt("Viewport",                  `${vw} × ${vh} px`,              false);
  fmt("Density mode (localStorage)",densityMode,                     densityMode === "default");
  fmt("Density style injected",     densityEl ? "YES" : "NO",        !densityEl);
  fmt("BG-Active",                  document.body.classList.contains("vg-bg-active") ? "YES" : "NO", false);

  console.log("%c  -", C.k);

  //TopBar
  if (TB) {
    fmt("TopBar  rect top→bottom",  `${TB.top} → ${TB.bottom}  (h:${TB.height})`, false);
    fmt("TopBar  margin",           `T:${TB.marginTop}  R:${TB.marginRight}  B:${TB.marginBottom}  L:${TB.marginLeft}`,
        TB.marginTop !== "-8px" || TB.marginRight !== "-8px" || TB.marginLeft !== "-8px");
    fmt("TopBar  padding",          `T:${TB.paddingTop}  R:${TB.paddingRight}  B:${TB.paddingBottom}  L:${TB.paddingLeft}`, false);
  } else {
    fmt("TopBar", "NOT FOUND", true);
  }

  console.log("%c  -", C.k);

  //Panel gaps (vertical)
  if (gapTopToPanel !== null) {
    const label = overflowTop
      ? `⚠ PANELS OVERLAP TOP BAR by ${Math.abs(gapTopToPanel)}px!`
      : `gap TopBar→Panels: ${gapTopToPanel}px`;
    fmt("Vertical (TopBar bottom ↓ Panel top)", label, overflowTop);
  }

  //Panels
  if (L)  fmt("LEFT   rect top→bottom", `${L.top} → ${L.bottom}  (h:${L.height})`,  false);
  if (M)  fmt("MAIN   rect top→bottom", `${M.top} → ${M.bottom}  (h:${M.height})`,  false);
  if (R)  fmt("RIGHT  rect top→bottom", `${R.top} → ${R.bottom}  (h:${R.height})`,  false);

  //Panel alignment
  if (panelTopsMatch !== null)    fmt("Panel tops aligned",    panelTopsMatch    ? "✓" : `✗  L:${L?.top}  M:${M?.top}  R:${R?.top}`,    !panelTopsMatch);
  if (panelBottomsMatch !== null) fmt("Panel bottoms aligned", panelBottomsMatch ? "✓" : `✗  L:${L?.bottom}  M:${M?.bottom}  R:${R?.bottom}`, !panelBottomsMatch);

  //Horizontal gaps
  if (gapLM !== null) fmt("Horiz gap  Left→Main",  `${gapLM}px`, gapLM < 0);
  if (gapMR !== null) fmt("Horiz gap  Main→Right", `${gapMR}px`, gapMR < 0);
  if (gapLM !== null && gapMR !== null) {
    const diff = Math.abs(gapLM - gapMR);
    fmt("Horiz gaps equal?", diff === 0 ? `✓ both ${gapLM}px` : `✗ diff ${diff}px  (LM:${gapLM}  MR:${gapMR})`, diff > 2);
  }
  if (TC) fmt("Root__top-container gap CSS", `${TC.gap}`, false);

  console.log("%c  -", C.k);

  //Panel gaps (vertical, to player bar)
  if (gapPanelToPlayer !== null) {
    const label = overflowBottom
      ? `⚠ PANELS OVERLAP PLAYER BAR by ${Math.abs(gapPanelToPlayer)}px!`
      : `gap Panels→PlayerBar: ${gapPanelToPlayer}px`;
    fmt("Vertical (Panel bottom ↑ PlayerBar top)", label, overflowBottom);
  }

  //PlayerBar
  if (PB) {
    fmt("PlayerBar rect top→bottom", `${PB.top} → ${PB.bottom}  (h:${PB.height})`, false);
    fmt("PlayerBar margin",          `T:${PB.marginTop}  R:${PB.marginRight}  B:${PB.marginBottom}  L:${PB.marginLeft}`,
        PB.marginBottom !== "-8px" || PB.marginRight !== "-8px" || PB.marginLeft !== "-8px");
    fmt("PlayerBar padding",         `T:${PB.paddingTop}  R:${PB.paddingRight}  B:${PB.paddingBottom}  L:${PB.paddingLeft}`, false);
  } else {
    fmt("PlayerBar", "NOT FOUND", true);
  }

  //NextTrack card
  if (NT) {
    fmt("NextTrack card rect",       `top:${NT.top}  bottom:${NT.bottom}  (h:${NT.height})`, false);
    const ntOverPB = PB && NT.top < PB.top;
    fmt("NextTrack above PlayerBar", ntOverPB ? "YES ✓" : "NO ✗", !ntOverPB);
  }

  console.log("%c  -", C.k);

  //Overall verdict
  const issues = [
    overflowTop    ? "PANEL→TOP BAR OVERFLOW"    : null,
    overflowBottom ? "PANEL→PLAYER BAR OVERFLOW" : null,
    (gapLM !== null && gapMR !== null && Math.abs(gapLM - gapMR) > 2) ? "UNEQUAL HORIZ GAPS" : null,
    (gapLM !== null && gapLM < 0) ? "LEFT↔MAIN OVERLAP" : null,
    (gapMR !== null && gapMR < 0) ? "MAIN↔RIGHT OVERLAP" : null,
    !panelTopsMatch    ? "PANEL TOPS MISALIGNED"    : null,
    !panelBottomsMatch ? "PANEL BOTTOMS MISALIGNED" : null,
  ].filter(Boolean);

  if (issues.length === 0) {
    console.log("%c  VERDICT: ✅  All layout checks passed!", C.ok);
  } else {
    console.log(`%c  VERDICT: ❌  ${issues.length} issue(s):`, C.bad);
    issues.forEach(i => console.log(`%c    • ${i}`, C.bad));
  }

  //
  // DENSITY CSS DUMP - injected style content
  //
  console.log("%c\n- DENSITY CSS (injected style) -", C.s);
  if (densityEl) {
    //Print first 2000 chars to avoid console spam
    const css = densityEl.textContent?.trim() || "(empty)";
    console.log(`%c${css.slice(0, 2000)}${css.length > 2000 ? "\n...(truncated)" : ""}`, C.g);
  } else {
    console.log("%c  No vantagraph-density style element found (density = default)", C.g);
  }

  // 3-PANEL ALIGNMENT TABLE
  console.log("%c\n- PANEL ALIGNMENT TABLE -", C.s);
  if (L && M) {
    const compare = (label, l, m, r) => {
      const match = l === m && (R ? m === r : true);
      console.log(
        `%c  ${label.padEnd(17)} │ %c${String(l ?? "-").padEnd(10)}%c│ %c${String(m ?? "-").padEnd(10)}%c│ %c${String(r ?? "-").padEnd(10)}%c${match ? "✓" : "✗"}`,
        C.k, match ? C.ok : C.bad, C.k, C.ok, C.k, match ? C.ok : C.bad, C.k
      );
    };
    console.log("%c  Property          │ LEFT       │ MAIN       │ RIGHT      │", C.w);
    compare("rectTop",       L.top,    M.top,    R?.top);
    compare("rectBottom",    L.bottom, M.bottom, R?.bottom);
    compare("height",        L.height, M.height, R?.height);
    compare("margin-top",    L.marginTop,    M.marginTop,    R?.marginTop);
    compare("margin-bottom", L.marginBottom, M.marginBottom, R?.marginBottom);
    compare("padding-top",   L.paddingTop,   M.paddingTop,   R?.paddingTop);
    compare("padding-bot",   L.paddingBottom,M.paddingBottom,R?.paddingBottom);
    compare("overflow",      L.overflow,     M.overflow,     R?.overflow);
    compare("contain",       L.contain,      M.contain,      R?.contain);
    console.log(`%c  Horiz gap L↔M: %c${gapLM}px   %cM↔R: %c${gapMR}px`, C.k, gapLM === gapMR ? C.ok : C.bad, C.k, gapLM === gapMR ? C.ok : C.bad);
  } else {
    console.log("%c  Panel elements not found", C.e);
  }

  // TOP BAR / PLAYER BAR DETAIL
  console.log("%c\n- TOP BAR DETAIL -", C.s);
  if (TB) {
    const inner = topBarEl.querySelector(".main-topBar-container");
    const innerSnap = snap(inner);
    console.log(`%c  Container: margin T:${TB.marginTop} R:${TB.marginRight} B:${TB.marginBottom} L:${TB.marginLeft}`, C.v);
    console.log(`%c  Container: padding T:${TB.paddingTop} R:${TB.paddingRight} B:${TB.paddingBottom} L:${TB.paddingLeft}`, C.v);
    console.log(`%c  Container: rect top:${TB.top} bottom:${TB.bottom} left:${TB.left} right:${TB.right}`, C.v);
    if (innerSnap) {
      console.log(`%c  .main-topBar-container: padding L:${innerSnap.paddingLeft} R:${innerSnap.paddingRight} gap:${innerSnap.gap}`, C.n);
      console.log(`%c  .main-topBar-container: rect left:${innerSnap.left} right:${innerSnap.right}`, C.n);
    }
    //Direct children of topBar
    const children = [...topBarEl.children];
    if (children.length > 0) {
      console.log(`%c  TopBar children (${children.length}):`, C.k);
      children.forEach((c, i) => {
        const cr = rect(c);
        console.log(`%c    [${i}] ${c.tagName}.${(c.className?.toString?.() || "").slice(0,50)}  rect: ${Math.round(cr.top)}→${Math.round(cr.bottom)} left:${Math.round(cr.left)} right:${Math.round(cr.right)}`, C.g);
      });
    }
  }

  console.log("%c\n- PLAYER BAR DETAIL -", C.s);
  if (PB) {
    const innerBar = playerEl.querySelector(".main-nowPlayingBar-nowPlayingBar")
                  || playerEl.querySelector(".main-nowPlayingBar-container");
    const innerSnap = snap(innerBar);
    console.log(`%c  Container: margin T:${PB.marginTop} R:${PB.marginRight} B:${PB.marginBottom} L:${PB.marginLeft}`, C.v);
    console.log(`%c  Container: padding T:${PB.paddingTop} R:${PB.paddingRight} B:${PB.paddingBottom} L:${PB.paddingLeft}`, C.v);
    console.log(`%c  Container: rect top:${PB.top} bottom:${PB.bottom} left:${PB.left} right:${PB.right}`, C.v);
    if (innerSnap) {
      console.log(`%c  .main-nowPlayingBar-*: padding T:${innerSnap.paddingTop} L:${innerSnap.paddingLeft} R:${innerSnap.paddingRight} gap:${innerSnap.gap}`, C.n);
      console.log(`%c  .main-nowPlayingBar-*: rect top:${innerSnap.top} height:${innerSnap.height}`, C.n);
    }
    //Left/Center/Right sections
    [
      [".main-nowPlayingBar-left",          "Left"],
      [".main-nowPlayingBar-center",         "Center"],
      [".main-nowPlayingBar-right",          "Right"],
      [".main-nowPlayingBar-extraControls",  "ExtraControls"],
    ].forEach(([sel, name]) => {
      const el2 = playerEl.querySelector(sel);
      if (el2) {
        const s2 = cs(el2);
        const r2el = rect(el2);
        console.log(`%c    ${name.padEnd(14)} pL:${s2.paddingLeft} pR:${s2.paddingRight} pT:${s2.paddingTop} gap:${s2.gap} → w:${Math.round(r2el.width)}`, C.g);
      }
    });
  }

  // OVERLAP DETECTION (all major elements)
  console.log("%c\n- OVERLAP / COLLISION -", C.s);
  const boxes = [
    { el: topBarEl,  name: "TopBar" },
    { el: leftEl,    name: "Left" },
    { el: mainEl,    name: "Main" },
    { el: rightEl,   name: "Right" },
    { el: playerEl,  name: "PlayerBar" },
    { el: ntCardEl,  name: "NextTrackCard" },
  ].filter(b => b.el);

  let collisions = 0;
  for (let i = 0; i < boxes.length; i++) {
    for (let j = i + 1; j < boxes.length; j++) {
      const a = rect(boxes[i].el);
      const b = rect(boxes[j].el);
      const overlapX = a.left < b.right && a.right > b.left;
      const overlapY = a.top < b.bottom && a.bottom > b.top;
      if (overlapX && overlapY) {
        const ow = r2(Math.min(a.right, b.right) - Math.max(a.left, b.left));
        const oh = r2(Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top));
        console.log(`%c  ⚠ OVERLAP: %c${boxes[i].name} ↔ ${boxes[j].name}%c  area: ${ow}×${oh}px`, C.e, C.bad, C.e);
        collisions++;
      }
    }
  }
  if (collisions === 0) console.log("%c  ✓ No overlaps detected", C.ok);

  // CSS VARIABLE DUMP
  console.log("%c\n- CSS VARIABLES -", C.s);
  const rootCS = cs(document.documentElement);
  [
    "-panel-gap", "-content-spacing", "-section-padding", "-section-gap",
    "-vg-radius-sm", "-vg-radius-md", "-vg-radius-lg", "-vg-radius-xl", "-vg-radius-2xl",
    "-encore-border-radius-rounded", "-vg-icon-size",
    "-spice-sidebar", "-spice-main", "-spice-playbar",
  ].forEach(v => {
    const val = rootCS.getPropertyValue(v).trim() || "(not set)";
    console.log(`%c  ${v.padEnd(36)} %c${val}`, C.k, C.v);
  });

  //- Done -
  console.log("%c  DIAGNOSTIC v4 COMPLETE", C.h);
})();
