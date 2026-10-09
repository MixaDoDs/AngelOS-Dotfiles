// Vantagraph Custom - Core Engine
// Modified 2026-10-03 by MixaDoDs for angelOS (github.com/MixaDoDs/AngelOS-Dotfiles): waveLoop draws
// at ~30 fps instead of the monitor rate (Spotify sat at ~150 % CPU). Not Miabeyefendi's code.

(function vantagraph() {
  // waitForElement: poll until match or max retries
  function waitForElement(selector, callback, maxAttempts = 50, useQueryAll = false) {
    const el = useQueryAll
      ? document.querySelectorAll(selector)
      : document.querySelector(selector);
    const found = useQueryAll ? (el && el.length > 0) : !!el;
    if (found) {
      callback(el);
      return;
    }
    if (maxAttempts > 0) {
      setTimeout(() => waitForElement(selector, callback, maxAttempts - 1, useQueryAll), 200);
    }
  }

  // waitForSpicetify: wait until core APIs ready
  function waitForSpicetify(callback) {
    if (
      Spicetify &&
      Spicetify.Player &&
      Spicetify.Platform &&
      Spicetify.LocalStorage
    ) {
      callback();
    } else {
      setTimeout(() => waitForSpicetify(callback), 100);
    }
  }

  // getSetting: localStorage w/ fallback
  function getSetting(key, fallback) {
    const v = Spicetify.LocalStorage.get(`vantagraph-custom:${key}`);
    return (v !== null && v !== "null" && v !== "") ? v : fallback;
  }


  // CLASS MAP
  const VG_CLASS_MAP = [
    // topbar
    { className: "vg-root", selectors: [".Root__top-container", "[data-testid='top-container']", "[data-testid='root']"] },

    { className: "vg-global-nav", selectors: [".Root__globalNav"] },
    { className: "vg-top-bar", selectors: [".Root__top-bar"] },
    { className: "vg-topbar", selectors: [".main-topBar-container", "[data-testid='topbar']", "header[role='banner']"] },
    { className: "vg-topbar-bg", selectors: [".main-topBar-background", "[data-testid='topbar-background']"] },
    { className: "vg-topbar-overlay", selectors: [".main-topBar-overlay", "[data-testid='topbar-overlay']"] },
    { className: "vg-topbar-right", selectors: [".main-topBar-topbarContentRight", "[data-testid='topbar-right']"] },
    { className: "vg-global-nav-link", selectors: [".main-globalNav-navLink"] },
    { className: "vg-actionbar-bg", selectors: [".main-actionBarBackground-background"] },
    { className: "vg-home-header", selectors: [".main-home-homeHeader", "[data-testid='home-header']"] },
    { className: "vg-entity-header-overlay", selectors: [".main-entityHeader-overlay"] },
    { className: "vg-home-filter-chips", selectors: [".main-home-filterChipsSection", "[data-testid='home-filter-chips']"] },
    { className: "vg-user-widget", selectors: [".main-userWidget-box"] },
    { className: "vg-search-category", selectors: [".search-searchCategory-SearchCategory", ".search-searchCategory-contentArea"] },
    { className: "vg-search-input", selectors: [".x-searchInput-searchInputInput"] },

    // sidebar
    { className: "vg-nav", selectors: [".Root__nav-bar", "[data-testid='left-sidebar']", "nav[aria-label='Main']"] },
    { className: "vg-left-sidebar-id", selectors: ["#Desktop_LeftSidebar_Id"] },
    { className: "vg-nav-bar", selectors: [".main-navBar-navBar"] },
    { className: "vg-library-rootlist", selectors: [".main-yourLibraryX-libraryRootlist"] },
    { className: "vg-rootlist-wrapper", selectors: [".main-rootlist-wrapper"] },
    { className: "vg-library-entrypoints", selectors: [".main-yourLibraryX-entryPoints"] },
    { className: "vg-library-nav-link", selectors: [".main-yourLibraryX-navLink"] },
    { className: "vg-your-library", selectors: [".YourLibraryX", ".main-yourLibraryX-library"] },
    { className: "vg-your-library-filter", selectors: [".main-yourLibraryX-filterArea"] },
    { className: "vg-your-library-header", selectors: [".main-yourLibraryX-header", ".main-yourLibraryX-headerContent"] },
    { className: "vg-your-library-container", selectors: [".main-yourLibraryX-libraryContainer"] },
    { className: "vg-your-library-nav-items", selectors: [".main-yourLibraryX-navItems"] },
    { className: "vg-rootlist-divider", selectors: [".main-rootlist-rootlistDivider", ".main-rootlist-rootlistDividerContainer"] },

    // main
    { className: "vg-main", selectors: [".Root__main-view", "[data-testid='main-view']", "main[role='main']"] },
    { className: "vg-main-view-container", selectors: [".main-view-container", "[data-testid='main-view-container']"] },
    { className: "vg-main-view-scroll", selectors: [".main-view-container__scroll-node-child"] },
    { className: "vg-main-view-overlay", selectors: [".Root__main-view-overlay"] },
    { className: "vg-content-spacing", selectors: [".contentSpacing"] },
    { className: "vg-shelf", selectors: [".main-shelf-shelf"] },
    { className: "vg-card", selectors: [".main-card-card", "[data-testid='card']"] },
    // Spotify 1.3 big cards (More like ..., Made for you): the box whose footer holds the play button
    { className: "vg-big-card", selectors: ["[data-encore-id='box']:has(> footer .main-playButton-PlayButton)"] },
    { className: "vg-card-image-wrap", selectors: [".main-cardImage-imageWrapper", "[data-testid='card-image']"] },
    { className: "vg-card-play", selectors: [".main-card-PlayButtonContainer"] },
    { className: "vg-card-image", selectors: [".main-cardImage-image"] },
    { className: "vg-card-image-circular", selectors: [".main-cardImage-circular"] },
    { className: "vg-track-row", selectors: [".main-trackList-trackListRow", "[data-testid='tracklist-row']"] },
    { className: "vg-track-row-title", selectors: [".main-trackList-rowTitle"] },
    { className: "vg-track-row-image", selectors: [".main-trackList-rowImage"] },
    { className: "vg-track-header", selectors: [".main-trackList-trackListHeaderRow"] },
    { className: "vg-entity-header-bg-color", selectors: [".main-entityHeader-backgroundColor"] },
    { className: "vg-entity-header-background", selectors: [".main-entityHeader-background"] },
    { className: "vg-entity-header-image-container", selectors: [".main-entityHeader-imageContainer", ".main-entityHeader-imageContainerNew"] },
    { className: "vg-entity-header-gradient", selectors: [".main-entityHeader-gradient"] },
    { className: "vg-entity-header-shadow", selectors: [".main-entityHeader-shadow"] },
    { className: "vg-entity-image-circle", selectors: [".x-entityImage-circle"] },
    { className: "vg-entity-image-placeholder", selectors: [".main-entityHeader-imagePlaceholder"] },
    { className: "vg-entity-header-circle", selectors: [".main-entityHeader-circle"] },
    { className: "vg-main-image", selectors: [".main-image-image"] },
    { className: "vg-category-card-image", selectors: [".x-categoryCard-image"] },
    { className: "vg-home-shortcut", selectors: [".view-homeShortcutsGrid-shortcut"] },
    { className: "vg-home-shortcut-image", selectors: [".view-homeShortcutsGrid-image"] },
    { className: "vg-home-shortcut-image-wrapper", selectors: [".view-homeShortcutsGrid-imageWrapper"] },
    { className: "vg-artist-overview-image", selectors: [".artist-artistOverview-sideBlock > div > section > div:nth-child(3) > section:nth-child(2) > div > img"] },
    { className: "vg-artist-overview-section", selectors: [".artist-artistOverview-sideBlock > div > section"] },

    // right panel
    { className: "vg-right", selectors: [".Root__right-sidebar", "[data-testid='right-sidebar']", "aside[aria-label*='Right']"] },
    { className: "vg-panel-container-id", selectors: ["#Desktop_PanelContainer_Id"] },
    { className: "vg-now-playing-view", selectors: [".main-nowPlayingView-section"] },
    { className: "vg-now-playing-view-content", selectors: [".main-nowPlayingView-content", ".main-nowPlayingView-gradient"] },
    { className: "vg-now-playing-view-lyrics", selectors: [".main-nowPlayingView-lyricsContent", ".main-nowPlayingView-lyricsGradient"] },

    // player bar
    { className: "vg-now-playing", selectors: [".Root__now-playing-bar", "[data-testid='now-playing-bar']", "footer[role='contentinfo']"] },
    { className: "vg-now-playing-bar", selectors: [".Root__now-playing-bar"] },
    { className: "vg-now-playing-bar-container", selectors: [".now-playing-bar-container"] },
    { className: "vg-np-container", selectors: [".main-nowPlayingBar-container", "[data-testid='now-playing-bar'] .main-nowPlayingBar-container"] },
    { className: "vg-np-bar", selectors: [".main-nowPlayingBar-nowPlayingBar"] },
    { className: "vg-np-center", selectors: [".main-nowPlayingBar-center"] },
    { className: "vg-np-left", selectors: [".main-nowPlayingBar-left"] },
    { className: "vg-np-right", selectors: [".main-nowPlayingBar-right"] },
    { className: "vg-np-extra-controls", selectors: [".main-nowPlayingBar-extraControls"] },
    { className: "vg-np-cover", selectors: [".main-nowPlayingWidget-coverArt", "[data-testid='cover-art']"] },
    { className: "vg-np-cover-collapsed", selectors: [".main-coverSlotCollapsed-container"] },
    { className: "vg-np-nowplaying", selectors: [".main-nowPlayingWidget-nowPlaying"] },
    { className: "vg-np-widget-trackinfo", selectors: [".main-nowPlayingWidget-trackInfo"] },
    { className: "vg-track-info-name", selectors: [".main-trackInfo-name"] },
    { className: "vg-track-info-artists", selectors: [".main-trackInfo-artists"] },
    { className: "vg-cover-art", selectors: [".cover-art"] },
    { className: "vg-cover-art-image", selectors: [".cover-art-image"] },
    { className: "vg-player-controls", selectors: [".player-controls__buttons", "[data-testid='player-controls']"] },
    { className: "vg-control-playpause", selectors: ["[data-testid='control-button-playpause']"] },
    { className: "vg-control-skip-fwd", selectors: ["[data-testid='control-button-skip-forward']"] },
    { className: "vg-control-skip-back", selectors: ["[data-testid='control-button-skip-back']"] },
    { className: "vg-control-shuffle", selectors: [".main-shuffleButton-button"] },
    { className: "vg-control-repeat", selectors: [".main-repeatButton-button"] },
    { className: "vg-add-button-active", selectors: [".main-addButton-active"] },
    { className: "vg-control-heart", selectors: [".control-button-heart"] },
    { className: "vg-playback-bar", selectors: [".playback-bar", "[data-testid='playback-bar']"] },
    { className: "vg-playback-progress", selectors: [".playback-progressbar-container", "[data-testid='playback-progressbar']"] },
    { className: "vg-progress-bar", selectors: [".progress-bar"] },
    { className: "vg-progress-bar-bg", selectors: [".progress-bar__bg"] },
    { className: "vg-progressbar-interactive", selectors: [".playback-progressbar-isInteractive"] },
    { className: "vg-progressbar-dragging", selectors: [".progress-bar--isDragging"] },
    { className: "vg-x-progressbar-slider", selectors: [".x-progressBar-sliderArea"] },
    { className: "vg-x-progressbar-bg", selectors: [".x-progressBar-progressBarBg"] },
    { className: "vg-volume-bar", selectors: [".volume-bar", "[data-testid='volume-bar']"] },
    { className: "vg-volume-slider", selectors: [".volume-bar__slider-container"] },
    { className: "vg-volume-icon", selectors: [".volume-bar__icon-button", "[data-testid='volume-bar'] button"] },
    { className: "vg-connect-device", selectors: [".connect-device-list-container"] },

    // lyrics
    { className: "vg-lyrics-highlight", selectors: [".lyrics-lyricsContent-highlight"] },
    { className: "vg-lyrics-bg", selectors: [".lyrics-lyrics-background"] },
    { className: "vg-lyrics-content", selectors: [".lyrics-lyricsContent-lyric", ".lyrics-lyricsContent-text"] },
    { className: "vg-lyrics-active", selectors: [".lyrics-lyricsContent-active"] },
    { className: "vg-lyrics-cinema", selectors: [".Root__lyrics-cinema"] },

    // context menu
    { className: "vg-context-menu", selectors: [".main-contextMenu-menu", "#context-menu ul", "[role='menu']"] },
    { className: "vg-context-menu-item", selectors: [".main-contextMenu-menuItemButton", "[role='menuitem']"] },

    // misc
    { className: "vg-layout-resizer", selectors: [".LayoutResizer__resize-bar"] },
    { className: "vg-layout-resizer-start", selectors: [".LayoutResizer__inline-start"] },
    { className: "vg-layout-resizer-end", selectors: [".LayoutResizer__inline-end"] },
    { className: "vg-encore-dark", selectors: [".encore-dark-theme"] },
  ];

  let vgClassObserver = null;
  let vgClassRaf = null;

  // Classes that follow a state flip on an element that already exists; they
  // get a cheap global pass on every flush. Everything else is structural and
  // is only looked up inside newly added subtrees.
  const VG_STATE_CLASSES = new Set([
    "vg-add-button-active", "vg-progressbar-interactive", "vg-progressbar-dragging",
    "vg-lyrics-highlight", "vg-lyrics-active", "vg-encore-dark",
  ]);
  const validSelector = (sel) => {
    try { document.createDocumentFragment().querySelector(sel); return true; } catch (e) { return false; }
  };
  const VG_COMPILED = VG_CLASS_MAP.map(({ className, selectors }) => {
    const ok = selectors.filter(validSelector);
    return { className, sel: ok.join(","), has: ok.some(x => x.includes(":has(")) };
  }).filter(e => e.sel);
  const VG_STRUCT = VG_COMPILED.filter(e => !VG_STATE_CLASSES.has(e.className));
  const VG_STATE = VG_COMPILED.filter(e => VG_STATE_CLASSES.has(e.className));
  const VG_STRUCT_NAMES = new Set(VG_STRUCT.map(e => e.className));

  function classifySubtree(root) {
    for (const { className, sel, has } of VG_STRUCT) {
      if (root.matches(sel)) root.classList.add(className);
      root.querySelectorAll(sel).forEach(el => el.classList.add(className));
      // :has() entries match an ancestor once its descendants arrive
      if (has && root.parentElement) root.parentElement.closest(sel)?.classList.add(className);
    }
  }

  function applyStateClasses() {
    for (const { className, sel } of VG_STATE) {
      document.querySelectorAll(sel).forEach(el => el.classList.add(className));
    }

    document.querySelectorAll(".vg-track-row").forEach((row) => {
      const isActive = row.classList.contains("main-trackList-active") ||
        row.getAttribute("aria-selected") === "true";
      row.classList.toggle("vg-track-row-active", !!isActive);
    });

    document.querySelectorAll(".vg-nav-bar").forEach((nav) => {
      const third = nav.children && nav.children[2];
      if (third) third.classList.add("vg-nav-third");
    });
  }

  // full pass: init, and callers outside theme.js (VantagraphCustomData)
  function applyDynamicClasses() {
    classifySubtree(document.documentElement);
    applyStateClasses();
  }

  // The old observer re-ran all selectors over the whole document on every
  // DOM change (5-9 ms per frame on scrolling lists). Now added subtrees are
  // classified once per frame, and when React rewrites a className the
  // stripped structural vg-* classes are put back in the same microtask.
  const vgPendingRoots = new Set();
  function flushDynamicClasses() {
    vgClassRaf = null;
    const roots = [...vgPendingRoots];
    vgPendingRoots.clear();
    if (roots.length > 150) {
      applyDynamicClasses();
      return;
    }
    const set = new Set(roots);
    for (const root of roots) {
      if (!root.isConnected) continue;
      let covered = false;
      for (let a = root.parentElement; a; a = a.parentElement) {
        if (set.has(a)) { covered = true; break; }
      }
      if (!covered) classifySubtree(root);
    }
    applyStateClasses();
  }

  function startDynamicClassObserver() {
    applyDynamicClasses();
    if (vgClassObserver) return;
    vgClassObserver = new MutationObserver((mutations) => {
      for (const m of mutations) {
        if (m.type === "attributes") {
          const old = m.oldValue;
          if (!old || !old.includes("vg-")) continue;
          const el = m.target;
          for (const token of old.split(" ")) {
            if (VG_STRUCT_NAMES.has(token) && !el.classList.contains(token)) el.classList.add(token);
          }
          continue;
        }
        for (const n of m.addedNodes) if (n.nodeType === 1) vgPendingRoots.add(n);
      }
      if (vgPendingRoots.size && !vgClassRaf) vgClassRaf = requestAnimationFrame(flushDynamicClasses);
    });
    if (document.body) {
      vgClassObserver.observe(document.body, {
        childList: true, subtree: true,
        attributes: true, attributeFilter: ["class"], attributeOldValue: true,
      });
    }
  }


  // COLORS
  // The editor owns every colour. Each key has a VantagraphBlack default (keep
  // color.ini in sync) or a `link` to another key, which it follows until the
  // user gives it a value of its own. Overrides are one JSON object stored
  // under vantagraph-custom:colors.
  //   spice: extra Spicetify names written together with --spice-<key>
  //   vg:    theme-only colour, written as --vg-<key>
  const COLOR_GROUPS = [
    { id: "surfaces", label: "Surfaces" },
    { id: "text",     label: "Text & Icons" },
    { id: "controls", label: "Buttons & Accent" },
    { id: "bars",     label: "Progress Bars" },
    { id: "details",  label: "Lines, Hover & Shadow" },
    { id: "glass",    label: "Background Image Glass" },
    { id: "spotify",  label: "Spotify Extras" },
  ];

  const COLOR_KEYS = [
    { key: "window",      group: "surfaces", label: "Window",       value: "#0E0E0E", spice: ["sidebar"],                              desc: "Backmost app background, seen between the panels" },
    { key: "panel",       group: "surfaces", label: "Panel",        value: "#131313", spice: ["main"],                                 desc: "Left, main and right panel background" },
    { key: "panel-hover", group: "surfaces", label: "Panel Hover",  value: "#2A2A2A", spice: ["main-elevated", "highlight-elevated"], desc: "Hovered rows and buttons, right panel cards" },
    { key: "menu",        group: "surfaces", label: "Menu & Cards", value: "#20201F", spice: ["card"],                                 desc: "Right-click menu and card background" },
    { key: "player",      group: "surfaces", label: "Player Bar",   value: "#0E0E0E", spice: ["playbar"],                              desc: "Bottom player bar and the Next Track card" },
    { key: "stroke",      group: "surfaces", label: "Stroke",       value: "#2A2A2A", spice: ["highlight"],                            desc: "Borders and the player bar top edge" },
    { key: "tab-active",  group: "surfaces", label: "Active Tab",   value: "#2B3231",                                                  desc: "Selected tab and filter chip background" },

    { key: "text",       group: "text", label: "Text",       value: "#E5E2E1",          desc: "Titles, song names, links and body text" },
    { key: "subtext",    group: "text", label: "Subtext",    value: "#8D9291",          desc: "Artists, descriptions, captions, timestamps" },
    { key: "menu-text",  group: "text", label: "Menu Text",  link: "text",    vg: true, desc: "Right-click menu items and their icons" },
    { key: "icon",       group: "text", label: "Icons",      link: "subtext", vg: true, desc: "Player, topbar and volume area icons" },
    { key: "icon-hover", group: "text", label: "Icon Hover", link: "accent",  vg: true, desc: "Icon colour and glow on hover" },

    { key: "accent",         group: "controls", label: "Accent",            value: "#C2C8C7",                                desc: "Wave, Next Track card, playing track, focus rings" },
    { key: "btn-active",     group: "controls", label: "Active Button",     value: "#C6C7C6", spice: ["button-active"],      desc: "Shuffle, repeat and other switched-on buttons" },
    { key: "play-btn",       group: "controls", label: "Play Button",       value: "#C2C8C7", spice: ["play-button"],        desc: "Fill of every play button" },
    { key: "play-btn-hover", group: "controls", label: "Play Button Hover", value: "#E5E2E1", spice: ["play-button-active"], desc: "Play button fill on hover" },
    { key: "play-icon",      group: "controls", label: "Play Icon",         link: "panel", vg: true,                         desc: "Play and pause symbol drawn on play buttons" },
    { key: "heart",          group: "controls", label: "Heart",             value: "#FFB4AB",                                desc: "Liked-song heart" },

    { key: "bar-fill", group: "bars", label: "Bar Fill",  value: "#C2C8C7", spice: ["progress-fg"], desc: "Filled part of the playback and volume bars" },
    { key: "bar-bg",   group: "bars", label: "Bar Track", value: "#434847", spice: ["progress-bg"], desc: "Empty part of the playback and volume bars" },

    { key: "row-hover", group: "details", label: "Row Hover", value: "rgba(255, 255, 255, 0.06)", vg: true, desc: "Track row and menu item hover tint" },
    { key: "divider",   group: "details", label: "Divider",   value: "rgba(255, 255, 255, 0.06)", vg: true, desc: "Track list header line, menu border, progress bar line" },
    { key: "shine",     group: "details", label: "Shine",     value: "rgba(255, 255, 255, 0.25)", vg: true, desc: "Light line along the top of the player bar" },
    { key: "shadow",    group: "details", label: "Shadow",    value: "#000000",                              desc: "Every shadow, the theme's and Spotify's own" },

    { key: "glass-topbar",  group: "glass", label: "Topbar Glass",      value: "rgba(0, 0, 0, 0.35)",       vg: true, desc: "Topbar tint over a background image" },
    { key: "glass-sidebar", group: "glass", label: "Left Panel Glass",  value: "rgba(0, 0, 0, 0.35)",       vg: true, desc: "Left panel tint over a background image" },
    { key: "glass-main",    group: "glass", label: "Main View Glass",   value: "rgba(0, 0, 0, 0.25)",       vg: true, desc: "Main view tint over a background image" },
    { key: "glass-right",   group: "glass", label: "Right Panel Glass", value: "rgba(0, 0, 0, 0.3)",        vg: true, desc: "Right panel tint over a background image" },
    { key: "glass-player",  group: "glass", label: "Player Bar Glass",  value: "rgba(0, 0, 0, 0.4)",        vg: true, desc: "Player bar and Next Track tint over a background image" },
    { key: "glass-edge",    group: "glass", label: "Glass Edge",        value: "rgba(255, 255, 255, 0.08)", vg: true, desc: "Edge light and inner glow of the glass panels" },

    { key: "selected-row",       group: "spotify", label: "Selected Row",    value: "#FFFFFF", desc: "Spotify's own hover and selection tint, drawn faintly" },
    { key: "button",             group: "spotify", label: "Button",          value: "#C2C8C7", desc: "Spotify's primary buttons" },
    { key: "button-disabled",    group: "spotify", label: "Disabled Button", value: "#434847", desc: "Buttons that cannot be clicked" },
    { key: "notification",       group: "spotify", label: "Notification",    value: "#C7C6CD", desc: "Info toasts and banners" },
    { key: "notification-error", group: "spotify", label: "Error",           value: "#FFB4AB", desc: "Error toasts and warnings" },
    { key: "misc",               group: "spotify", label: "Misc",            value: "#8D9291", desc: "Leftover greys Spotify draws in a few places" },
  ];

  const COLOR_BY_KEY = {};
  COLOR_KEYS.forEach(d => { COLOR_BY_KEY[d.key] = d; });

  // COLOR MATH (shared with the settings editor via VantagraphCustomData.color)
  const round3 = n => Math.round(n * 1000) / 1000;
  const clampNum = (n, lo, hi) => Math.min(hi, Math.max(lo, n));
  const hex2 = n => n.toString(16).padStart(2, "0").toUpperCase();
  const NUM_RE = /^[+-]?(\d+\.?\d*|\.\d+)(%|deg)?$/;

  // parseNum: plain number, or a percentage mapped onto `scale`
  function parseNum(s, scale) {
    const m = NUM_RE.exec(s);
    if (!m) return null;
    const n = parseFloat(s);
    return m[2] === "%" ? n / 100 * scale : n;
  }

  function hslToRgb(h, s, l) {
    h = ((h % 360) + 360) % 360; s = clampNum(s, 0, 1); l = clampNum(l, 0, 1);
    const c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = l - c / 2;
    const [r, g, b] = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
    return { r: Math.round((r + m) * 255), g: Math.round((g + m) * 255), b: Math.round((b + m) * 255) };
  }

  function rgbToHsl({ r, g, b }) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min, l = (max + min) / 2;
    let h = 0;
    if (d) h = max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
    return { h: (h * 60 + 360) % 360, s: d ? d / (1 - Math.abs(2 * l - 1)) : 0, l };
  }

  function rgbToHsv({ r, g, b }) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), d = max - Math.min(r, g, b);
    let h = 0;
    if (d) h = max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
    return { h: (h * 60 + 360) % 360, s: max ? d / max : 0, v: max };
  }

  function hsvToRgb(h, s, v) {
    const l = v * (1 - s / 2);
    return hslToRgb(h, (l === 0 || l === 1) ? 0 : (v - l) / Math.min(l, 1 - l), l);
  }

  // parseColor: #rgb #rgba #rrggbb #rrggbbaa (# optional), rgb()/rgba(), hsl()/hsla().
  // Returns {r,g,b,a} or null; anything else is rejected.
  function parseColor(input) {
    const s = String(input == null ? "" : input).trim().toLowerCase();
    let m = /^#?([0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$/.exec(s);
    if (m) {
      let h = m[1];
      if (h.length < 6) h = h.replace(/./g, ch => ch + ch);
      const n = i => parseInt(h.slice(i, i + 2), 16);
      return { r: n(0), g: n(2), b: n(4), a: h.length === 8 ? round3(n(6) / 255) : 1 };
    }
    m = /^(rgba?|hsla?)\(([^()]*)\)$/.exec(s);
    if (!m) return null;
    const p = m[2].trim().split(/\s*[,/]\s*|\s+/);
    if (p.length !== 3 && p.length !== 4) return null;
    const a = p.length === 4 ? parseNum(p[3], 1) : 1;
    if (a === null) return null;
    let rgb;
    if (m[1][0] === "r") {
      const ch = p.slice(0, 3).map(x => parseNum(x, 255));
      if (ch.some(x => x === null)) return null;
      rgb = { r: ch[0], g: ch[1], b: ch[2] };
    } else {
      // bare hsl numbers read as percentages, like CSS
      const h = parseNum(p[0], 360), sat = parseNum(p[1], 100), lig = parseNum(p[2], 100);
      if (h === null || sat === null || lig === null) return null;
      rgb = hslToRgb(h, sat / 100, lig / 100);
    }
    return {
      r: Math.round(clampNum(rgb.r, 0, 255)),
      g: Math.round(clampNum(rgb.g, 0, 255)),
      b: Math.round(clampNum(rgb.b, 0, 255)),
      a: round3(clampNum(a, 0, 1)),
    };
  }

  // canonical form: stored, written to CSS, shown by default
  function formatColor(c) {
    return c.a < 1 ? `rgba(${c.r}, ${c.g}, ${c.b}, ${c.a})` : "#" + hex2(c.r) + hex2(c.g) + hex2(c.b);
  }
  function toHex(c) {
    return "#" + hex2(c.r) + hex2(c.g) + hex2(c.b) + (c.a < 1 ? hex2(Math.round(c.a * 255)) : "");
  }
  function toRgb(c) {
    return c.a < 1 ? `rgba(${c.r}, ${c.g}, ${c.b}, ${c.a})` : `rgb(${c.r}, ${c.g}, ${c.b})`;
  }
  function toHsl(c) {
    const { h, s, l } = rgbToHsl(c);
    const hsl = `${Math.round(h)}, ${Math.round(s * 100)}%, ${Math.round(l * 100)}%`;
    return c.a < 1 ? `hsla(${hsl}, ${c.a})` : `hsl(${hsl})`;
  }

  // FONT PRESETS
  // three on purpose: Spotify's own, a plain sans that reads everywhere, and a
  // monospace that looks nothing like either. Anything else is a custom font.
  const FONT_PRESETS = [
    { name: "Spotify Default", family: "" },
    { name: "Inter", family: "Inter", url: "https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" },
    { name: "JetBrains Mono", family: "JetBrains Mono", url: "https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@300;400;500;600;700&display=swap" }
  ];

  // COLOR ENGINE
  let colorOverrides = {};
  let colorSaveTimer = null;

  function sanitizeOverrides(obj) {
    const out = {};
    if (!obj || typeof obj !== "object") return out;
    Object.keys(obj).forEach(k => {
      if (!COLOR_BY_KEY[k]) return;
      const c = parseColor(obj[k]);
      if (c) out[k] = formatColor(c);
    });
    return out;
  }

  function loadColorOverrides() {
    let raw = {};
    try { raw = JSON.parse(Spicetify.LocalStorage.get("vantagraph-custom:colors") || "{}"); } catch (e) {}
    colorOverrides = sanitizeOverrides(raw);
  }

  // debounced: a picker drag changes the colour every frame
  function saveColorOverrides() {
    clearTimeout(colorSaveTimer);
    colorSaveTimer = setTimeout(() => {
      Spicetify.LocalStorage.set("vantagraph-custom:colors", JSON.stringify(colorOverrides));
    }, 200);
  }

  function resolveColor(key, depth = 0) {
    const def = COLOR_BY_KEY[key];
    if (colorOverrides[key]) return parseColor(colorOverrides[key]);
    if (def.link && depth < 4) return resolveColor(def.link, depth + 1);
    return parseColor(def.value);
  }

  // settings panel chrome reads opaque copies, so it stays readable
  // even when the user makes a surface see-through
  const UI_COLORS = ["panel", "panel-hover", "stroke", "text", "subtext", "accent"];

  function writeColorVars(def, c, withUi = true) {
    const st = document.documentElement.style;
    const css = formatColor(c);
    if (def.vg) {
      st.setProperty(`--vg-${def.key}`, css);
    } else {
      const rgb = `${c.r},${c.g},${c.b}`;
      [def.key].concat(def.spice || []).forEach(n => {
        // background image mode keeps --spice-main transparent (applySetting bg-url)
        if (n === "main" && document.body.classList.contains("vg-bg-active")) return;
        st.setProperty(`--spice-${n}`, css);
        st.setProperty(`--spice-rgb-${n}`, rgb);
      });
    }
    if (withUi && UI_COLORS.includes(def.key)) st.setProperty(`--vg-ui-${def.key}`, formatColor({ ...c, a: 1 }));
    if (def.key === "bar-bg") st.setProperty("--spice-progress-bg-alpha", formatColor({ ...c, a: round3(c.a * 0.35) }));
    if (def.key === "heart") scheduleHeartColor();
  }

  function applyColors() {
    COLOR_KEYS.forEach(def => writeColorVars(def, resolveColor(def.key)));
  }

  // one key plus every key that follows it
  function applyColorKey(key) {
    COLOR_KEYS.forEach(def => {
      if (def.key === key || def.link === key) writeColorVars(def, resolveColor(def.key));
    });
  }

  function setColor(key, value) {
    const def = COLOR_BY_KEY[key];
    const c = def && parseColor(value);
    if (!c) return false;
    stopFlash();
    const css = formatColor(c);
    // same as a plain default: drop the override. Linked keys keep it, it unlinks them.
    if (!def.link && css === formatColor(parseColor(def.value))) delete colorOverrides[key];
    else colorOverrides[key] = css;
    applyColorKey(key);
    saveColorOverrides();
    return true;
  }

  function resetColor(key) {
    if (!COLOR_BY_KEY[key]) return;
    stopFlash();
    delete colorOverrides[key];
    applyColorKey(key);
    saveColorOverrides();
  }

  // replace the whole set (undo, import, reset all)
  function setColorOverrides(obj) {
    stopFlash();
    colorOverrides = sanitizeOverrides(obj);
    applyColors();
    saveColorOverrides();
  }

  function getColorOverrides() {
    return { ...colorOverrides };
  }

  function getColorState(key) {
    const def = COLOR_BY_KEY[key];
    if (!def) return null;
    const color = resolveColor(key);
    const custom = !!colorOverrides[key];
    return { color, value: formatColor(color), custom, link: def.link && !custom ? def.link : null };
  }

  // flashColor: blink one colour (and what follows it) so the user sees where it paints
  let flashTimer = null;
  let flashDefs = [];
  function flashColor(key) {
    if (!COLOR_BY_KEY[key]) return;
    stopFlash();
    flashDefs = COLOR_KEYS.filter(d => d.key === key || (d.link === key && !colorOverrides[d.key]));
    const hot = [{ r: 255, g: 0, b: 200, a: 1 }, { r: 0, g: 230, b: 255, a: 1 }];
    let n = 0;
    flashTimer = setInterval(() => {
      if (n === 6) { stopFlash(); return; }
      flashDefs.forEach(d => writeColorVars(d, hot[n % 2], false));
      n++;
    }, 170);
  }
  function stopFlash() {
    if (!flashTimer) return;
    clearInterval(flashTimer);
    flashTimer = null;
    flashDefs.forEach(d => writeColorVars(d, resolveColor(d.key)));
    flashDefs = [];
  }

  let heartRaf = 0;
  function scheduleHeartColor() {
    if (heartRaf) return;
    heartRaf = requestAnimationFrame(() => { heartRaf = 0; applyHeartColor(); });
  }

  // applyHeartColor - Spotify forces inline fill:transparent on like/save SVGs; JS must overwrite.
  let _heartObserver = null;
  let _heartDebounce = null;

  function applyHeartColor() {
    const heartColor = getComputedStyle(document.documentElement)
      .getPropertyValue("--spice-heart").trim();
    if (!heartColor) return;

    // like/save/heart button selectors (multi-locale)
    const selectors = [
      'button[data-testid="add-button"]',
      'button[data-testid="add-to-liked-songs-button"]',
      'button[aria-label*="Save"]',
      'button[aria-label*="Saved"]',
      'button[aria-label*="save"]',
      'button[aria-label*="Kaydet"]',
      'button[aria-label*="Kaydedildi"]',
      'button[aria-label*="Beğen"]',
      'button[aria-label*="beğen"]',
      'button[aria-label*="Like"]',
      'button[aria-label*="like"]',
      'button[aria-label*="Remove"]',
    ];

    const defaultColor = getComputedStyle(document.documentElement)
      .getPropertyValue("--spice-subtext").trim() || "";

    function fixHeartPaths() {
      selectors.forEach(sel => {
        document.querySelectorAll(sel).forEach(btn => {
          const liked = btn.getAttribute("aria-checked") === "true";
          const color = liked ? heartColor : defaultColor;
          // overwrite inline fill/stroke (React would re-apply if removed)
          btn.querySelectorAll("svg path, svg circle").forEach(el => {
            if (el.style.fill) el.style.setProperty("fill", color, "important");
            if (el.style.stroke && el.style.stroke.includes("transparent")) {
              el.style.setProperty("stroke", color, "important");
            }
          });
          // currentColor inherit on svg+btn
          const svg = btn.querySelector("svg");
          if (svg) {
            svg.style.setProperty("color", color, "important");
            svg.style.setProperty("fill", color, "important");
          }
          btn.style.setProperty("color", color, "important");
        });
      });
    }

    fixHeartPaths();

    // debounced observer (avoid mutation loops)
    if (_heartObserver) _heartObserver.disconnect();
    _heartObserver = new MutationObserver(() => {
      if (_heartDebounce) clearTimeout(_heartDebounce);
      _heartDebounce = setTimeout(fixHeartPaths, 100);
    });

    // watch player bar + main view for new like buttons
    const targets = [
      document.querySelector(".Root__now-playing-bar"),
      document.querySelector(".Root__main-view"),
      document.querySelector("[data-testid='now-playing-widget']"),
      document.querySelector(".Root__right-sidebar"),
    ].filter(Boolean);

    targets.forEach(t => {
      _heartObserver.observe(t, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ["style", "aria-label", "aria-checked"],
      });
    });
  }

  // applyFont
  // Font name goes into a <style> string and font URL into <link href>, both
  // from a free-text field (CodeQL js/xss-through-dom #2). Name: characters that
  // can break out of the CSS string are stripped. URL: absolute http(s) only,
  // anything else (javascript:, data:, relative) is dropped.
  function safeFontFamily(name) {
    return String(name || "").replace(/["'\\{}<>;@]|[\u0000-\u001f\u007f]/g, "").trim().slice(0, 100);
  }
  function safeFontUrl(url) {
    try {
      const u = new URL(String(url || ""));
      return (u.protocol === "https:" || u.protocol === "http:") ? u.href : "";
    } catch (e) { return ""; }
  }

  function applyFont(fontFamily, fontUrl) {
    fontFamily = safeFontFamily(fontFamily);
    fontUrl = safeFontUrl(fontUrl);
    const styleId = "vantagraph-font";
    let styleEl = document.getElementById(styleId);
    if (!styleEl) {
      styleEl = document.createElement("style");
      styleEl.id = styleId;
      document.head.appendChild(styleEl);
    }

    // load Google Font if URL given
    if (fontUrl) {
      const linkId = "vantagraph-font-link";
      let linkEl = document.getElementById(linkId);
      if (!linkEl) {
        linkEl = document.createElement("link");
        linkEl.id = linkId;
        linkEl.rel = "stylesheet";
        document.head.appendChild(linkEl);
      }
      linkEl.href = fontUrl;
    }

    if (!fontFamily || fontFamily === "" || fontFamily === "Spotify Default") {
      styleEl.textContent = "";
      Spicetify.LocalStorage.set("vantagraph-custom:font", "");
      Spicetify.LocalStorage.set("vantagraph-custom:font-url", "");
      return;
    }

    // universal font apply (covers encore + dynamic classes)
    styleEl.textContent = `
      *,
      *::before,
      *::after,
      body,
      button,
      input,
      select,
      textarea,
      [class*="Type__TypeElement"],
      [class*="encore-"],
      [data-encore-id] {
        font-family: "${fontFamily}", -apple-system, BlinkMacSystemFont, system-ui, sans-serif !important;
      }
    `;

    Spicetify.LocalStorage.set("vantagraph-custom:font", fontFamily);
    Spicetify.LocalStorage.set("vantagraph-custom:font-url", fontUrl || "");
  }



  // applySetting
  // bg filter string shared by the bg element and the panel glass layers
  function bgFilterValue() {
    const blur = getSetting("bg-blur", "0");
    const bright = getSetting("bg-brightness", "100");
    const cont = getSetting("bg-contrast", "100");
    const sat = getSetting("bg-saturation", "100");
    return `blur(${blur}px) brightness(${bright}%) contrast(${cont}%) saturate(${sat}%)`;
  }

  // user.css paints a pre-blurred copy of the bg behind each panel from these
  function syncBgVars(url) {
    const root = document.documentElement.style;
    if (url) {
      root.setProperty("--vg-bg-image", `url("${url}")`);
      root.setProperty("--vg-bg-filter", bgFilterValue());
    } else {
      root.removeProperty("--vg-bg-image");
      root.removeProperty("--vg-bg-filter");
    }
  }

  function applySetting(key, value) {
    const root = document.documentElement;
    Spicetify.LocalStorage.set(`vantagraph-custom:${key}`, String(value));

    switch (key) {
      // font-size: scaled type ramp
      case "font-size": {
        const styleId = "vantagraph-fontsize";
        let el = document.getElementById(styleId);
        if (!el) { el = document.createElement("style"); el.id = styleId; document.head.appendChild(el); }
        el.textContent = `*, *::before, *::after { font-size: ${value}px !important; }
          h1 { font-size: ${value * 2}px !important; }
          h2 { font-size: ${value * 1.5}px !important; }
          h3 { font-size: ${value * 1.2}px !important; }
          .vg-track-row-title { font-size: ${value}px !important; }
          .vg-playback-bar > div:not(.vg-playback-progress) { font-size: ${Math.max(value - 3, 9)}px !important; }`;
        break;
      }
      // icon-size: 5 tiers (T1=player, T2=topbar/card, T3=secondary, T4=sidebar, T5=mini)
      case "icon-size": {
        const styleId = "vantagraph-iconsize";
        const root = document.documentElement;

        // default: clear overrides + inline JS-set sizes
        if (value === "default" || !value) {
          const el = document.getElementById(styleId);
          if (el) el.remove();
          ["--vg-icon-t1","--vg-icon-t2","--vg-icon-t3","--vg-icon-t4","--vg-icon-t5"].forEach(p => root.style.removeProperty(p));
          document.querySelectorAll('.vg-topbar-btn svg, button[aria-label="Vantagraph Custom"] svg, button[aria-label="Lyric Miniplayer"] svg, button[aria-label="vg-vol-preset-trigger"] svg').forEach(svg => {
            svg.style.removeProperty("width"); svg.style.removeProperty("height");
          });
          Spicetify.LocalStorage.set("vantagraph-custom:icon-size", "default");
          break;
        }

        const v = parseFloat(value);
        const t2 = Math.max(6, v - 2);
        const t3 = Math.max(6, v - 4);
        const t4 = Math.max(5, v - 6);
        const t5 = Math.max(4, v - 10);

        root.style.setProperty("--vg-icon-t1", v + "px");
        root.style.setProperty("--vg-icon-t2", t2 + "px");
        root.style.setProperty("--vg-icon-t3", t3 + "px");
        root.style.setProperty("--vg-icon-t4", t4 + "px");
        root.style.setProperty("--vg-icon-t5", t5 + "px");

        let el = document.getElementById(styleId);
        if (!el) {
          el = document.createElement("style"); el.id = styleId; document.head.appendChild(el);
          el.textContent = `
          .vg-icon-t1 { --encore-icon-height: var(--vg-icon-t1) !important; --encore-icon-width: var(--vg-icon-t1) !important; width: var(--vg-icon-t1) !important; height: var(--vg-icon-t1) !important; }
          .vg-icon-t2 { --encore-icon-height: var(--vg-icon-t2) !important; --encore-icon-width: var(--vg-icon-t2) !important; width: var(--vg-icon-t2) !important; height: var(--vg-icon-t2) !important; }
          .vg-icon-t3 { --encore-icon-height: var(--vg-icon-t3) !important; --encore-icon-width: var(--vg-icon-t3) !important; width: var(--vg-icon-t3) !important; height: var(--vg-icon-t3) !important; }
          .vg-icon-t4 { --encore-icon-height: var(--vg-icon-t4) !important; --encore-icon-width: var(--vg-icon-t4) !important; width: var(--vg-icon-t4) !important; height: var(--vg-icon-t4) !important; }
          .vg-icon-t5 { --encore-icon-height: var(--vg-icon-t5) !important; --encore-icon-width: var(--vg-icon-t5) !important; width: var(--vg-icon-t5) !important; height: var(--vg-icon-t5) !important; }

          /* T1: player controls */
          .vg-player-controls button svg:not([preserveAspectRatio]),
          footer button svg:not([preserveAspectRatio]),
          .Root__now-playing-bar button svg:not([preserveAspectRatio]),
          [data-testid="now-playing-bar"] button svg:not([preserveAspectRatio]),
          [data-testid="control-button-playpause"] svg,
          [data-testid="control-button-playpause"] [data-encore-id="icon"],
          [data-testid="control-button-skip-forward"] svg,
          [data-testid="control-button-skip-forward"] [data-encore-id="icon"],
          [data-testid="control-button-skip-back"] svg,
          [data-testid="control-button-skip-back"] [data-encore-id="icon"],
          [data-testid="control-button-shuffle"] svg,
          [data-testid="control-button-shuffle"] [data-encore-id="icon"],
          [data-testid="control-button-repeat"] svg,
          [data-testid="control-button-repeat"] [data-encore-id="icon"],
          footer [data-encore-id="icon"],
          .Root__now-playing-bar [data-encore-id="icon"]
          { width: var(--vg-icon-t1) !important; height: var(--vg-icon-t1) !important;
            --encore-icon-height: var(--vg-icon-t1) !important; --encore-icon-width: var(--vg-icon-t1) !important; }

          /* T2: topbar, card play */
          .vg-global-nav button svg,
          .vg-top-bar button svg,
          .Root__globalNav button svg,
          .Root__top-bar button svg,
          .Root__globalNav [data-encore-id="icon"],
          .Root__top-bar [data-encore-id="icon"],
          .vg-global-nav-link svg,
          [aria-label="Go back"] svg, [aria-label="Go back"] [data-encore-id="icon"],
          [aria-label="Go forward"] svg, [aria-label="Go forward"] [data-encore-id="icon"],
          [aria-label="Search"] svg,
          [aria-label="Browse"] svg,
          [aria-label="Home"] svg, [aria-label="Home"] [data-encore-id="icon"],
          [aria-label="Marketplace"] svg, [aria-label="Marketplace"] [data-encore-id="icon"],
          [aria-label="Clear search field"] svg,
          [aria-label="Hide notification"] svg,
          [aria-label="Go to settings"] svg,
          [aria-label="Share"] svg,
          [aria-label="Save to Your Library"] svg,
          [aria-label="Download"] svg,
          [aria-label="More"] svg,
          [aria-label*="Add to Your Episodes"] svg,
          [aria-label*="Copy link"] svg,
          [aria-label*="Enable Shuffle"] svg,
          [aria-label*="Invite collaborators"] svg,
          [aria-label*="Invite collaborators"] [data-encore-id="icon"],
          .vg-card-play button svg,
          .main-card-PlayButtonContainer button svg,
          .main-playButton-PlayButton svg,
          .main-playButton-PlayButton [data-encore-id="icon"]
          { width: var(--vg-icon-t2) !important; height: var(--vg-icon-t2) !important;
            --encore-icon-height: var(--vg-icon-t2) !important; --encore-icon-width: var(--vg-icon-t2) !important; }

          /* T3: secondary controls */
          .vg-np-extra-controls button svg,
          [data-testid="volume-bar"] button svg,
          [data-testid="volume-bar-toggle-mute-button"] svg,
          [data-testid="volume-bar-toggle-mute-button"] [data-encore-id="icon"],
          [data-testid="lyrics-button"] svg,
          [data-testid="lyrics-button"] [data-encore-id="icon"],
          [data-testid="control-button-queue"] svg,
          [data-testid="control-button-queue"] [data-encore-id="icon"],
          [data-testid="pip-toggle-button"] svg,
          [data-testid="pip-toggle-button"] [data-encore-id="icon"],
          [data-testid="fullscreen-mode-button"] svg,
          [data-testid="fullscreen-mode-button"] [data-encore-id="icon"],
          [data-testid="big-card-toggle-preview-button"] svg,
          [data-testid="overflow-button-start"] svg,
          [data-testid="overflow-button-end"] svg,
          [data-testid="x-sortBox-sortDropdown"] svg,
          [aria-label="Connect to a device"] svg,
          [aria-label="Connect to a device"] [data-encore-id="icon"],
          [aria-label="What's New"] svg,
          [aria-label="Friend Activity"] svg,
          [aria-label*="More options"] svg,
          [aria-label*="More options"] [data-encore-id="icon"],
          [aria-label="Expand Now Playing view"] svg,
          [aria-label="Hide Now Playing view"] svg,
          [aria-label="Show Now Playing view"] svg,
          [aria-label="Add to playlist"] svg,
          [aria-label="Add to Liked Songs"] svg,
          [aria-label="Remove"] svg,
          [aria-label="Close"] svg,
          [aria-label="Close"] [data-encore-id="icon"],
          [aria-label="Search in playlist"] svg,
          [aria-label="Find a playlist"] svg,
          [aria-label="Change visible columns"] svg,
          [aria-label="Duration"] svg,
          [class*="contextMenu"] svg,
          [data-encore-id="buttonTertiary"] [data-encore-id="icon"],
          [data-encore-id="buttonSecondary"] [data-encore-id="icon"],
          .vg-topbar-btn button svg,
          .vg-topbar-btn [data-encore-id="icon"],
          .vg-topbar-btn svg,
          .main-topBar-topbarContentRight button svg,
          button[aria-label="Vantagraph Custom"] svg,
          button[aria-label="Lyric Miniplayer"] svg,
          button[aria-label="vg-vol-preset-trigger"] svg,
          .vg-library-icon svg
          { width: var(--vg-icon-t3) !important; height: var(--vg-icon-t3) !important;
            --encore-icon-height: var(--vg-icon-t3) !important; --encore-icon-width: var(--vg-icon-t3) !important; }

          /* T4: sidebar library */
          .vg-your-library button svg,
          .vg-your-library-header button svg,
          .vg-your-library-filter button svg,
          [aria-label="Collapse Your Library"] svg,
          [aria-label="Expand Your Library"] svg,
          [aria-label="Open Your Library"] svg,
          [aria-label="Create"] svg,
          [aria-label*="Search in Your Library"] svg,
          [aria-label*="Custom order"] svg,
          [aria-label*="Recents"] svg
          { width: var(--vg-icon-t4) !important; height: var(--vg-icon-t4) !important; }

          /* T5: mini player */
          [data-testid="cover-art-button"] svg,
          .vg-np-left button svg,
          .vg-np-cover button svg
          { width: var(--vg-icon-t5) !important; height: var(--vg-icon-t5) !important; }`;
        }

        // topbar buttons: CSS blocked, set inline
        document.querySelectorAll('.vg-topbar-btn svg, button[aria-label="Vantagraph Custom"] svg, button[aria-label="Lyric Miniplayer"] svg, button[aria-label="vg-vol-preset-trigger"] svg').forEach(svg => {
          svg.style.setProperty("width", t3 + "px", "important");
          svg.style.setProperty("height", t3 + "px", "important");
        });

        Spicetify.LocalStorage.set("vantagraph-custom:icon-size", value);
        break;
      }
      // density: compact|comfortable|default (margin/padding/gap only, sizes locked)
      case "density": {
        const styleId = "vantagraph-density";
        let el = document.getElementById(styleId);
        // default: native spacing
        if (value === "default" || !value) {
          if (el) el.remove();
          if (typeof ntSyncBottom === "function") {
            setTimeout(ntSyncBottom, 100);
            setTimeout(ntSyncBottom, 600);
            setTimeout(ntSyncBottom, 1500);
          }
          break;
        }
        if (!el) { el = document.createElement("style"); el.id = styleId; document.head.appendChild(el); }
        // Spatial Compression v2 - delta from default (Apr 2026)
        const config = {
          compact: {
            panelGap: "8px",
            panelPad: "2px",
            mainMargin: "7px",
            playerMinH: "",
            navGap: "4px",
            navInnerPadX: "0px",
            searchPadX: "0px",
            contentSpacing: "8px",
            sectionPad: "8px",
            sectionGap: "4px",
            rowPad: "0px 4px",
            rowMinH: "32px",
            cardPad: "6px",
            gridGap: "8px",
            listRowHGap: "8px",
            playerTopPad: "15px",
            playerInnerPadX: "",
            playerControlsGap: "",
            playerLeftGap: "",
            playerRightGap: "",
            playerCenterGap: "",
            progressBarPadX: "",
            volMarginR: "",
            playerAlignBottom: false,
            wavePadL: "10px",
            wavePadR: "10px",
          },
          comfortable: {
            panelGap: "10px",
            panelPad: "6px",
            mainMargin: "11px",
            playerMinH: "120px",
            navGap: "10px",
            navInnerPadX: "0px",
            searchPadX: "4px",
            contentSpacing: "20px",
            sectionPad: "16px",
            sectionGap: "10px",
            rowPad: "4px 10px",
            rowMinH: "44px",
            cardPad: "10px",
            gridGap: "16px",
            listRowHGap: "12px",
            playerTopPad: "4px",
            playerInnerPadX: "6px",
            playerControlsGap: "10px",
            playerLeftGap: "",
            playerRightGap: "",
            playerCenterGap: "",
            progressBarPadX: "8px",
            volMarginR: "10px",
            playerAlignBottom: true,
            wavePadL: "20px",
            wavePadR: "0px",
          }
        };

        const d = config[value] || config.comfortable;

        el.textContent = `
          /* panel frame */
          :root .Root__top-container {
            --panel-gap: ${d.panelGap} !important;
            column-gap: ${d.panelGap} !important;
          }
          :root .Root__nav-bar,
          :root #Desktop_LeftSidebar_Id {
            padding-top: ${d.panelPad} !important;
            padding-bottom: ${d.panelPad} !important;
          }
          :root .Root__right-sidebar,
          :root aside[class*="Panel"] {
            padding-top: ${d.panelPad} !important;
            padding-bottom: ${d.panelPad} !important;
          }
          #main-view#main-view {
            margin: ${d.mainMargin} 0 !important;
          }

          /* topbar */
          :root .main-topBar-container {
            padding-left: ${d.navInnerPadX} !important;
            padding-right: ${d.navInnerPadX} !important;
            gap: ${d.navGap} !important;
          }
          :root .Root__globalNav > .Root__top-bar {
            gap: ${d.navGap} !important;
          }
          :root .main-globalNav-searchContainer {
            padding: 0 ${d.searchPadX} !important;
          }
          :root .main-topBar-topbarContentRight,
          :root [data-testid="topbar-right"] {
            gap: ${d.navGap} !important;
          }
          :root .main-globalNav-historyButtons {
            gap: ${d.navGap} !important;
          }

          /* main content */
          :root {
            --content-spacing: ${d.contentSpacing} !important;
            --section-padding: ${d.sectionPad} !important;
            --section-gap: ${d.sectionGap} !important;
          }
          :root .contentSpacing {
            padding: 0 ${d.contentSpacing} !important;
          }
          :root .main-view-container [data-testid="tracklist-row"],
          :root .main-view-container [role="row"][aria-rowindex],
          :root .main-view-container [class*="TrackListRow"],
          :root [class*="main-view"] [data-testid="tracklist-row"],
          :root [class*="main-view"] [role="row"][aria-rowindex] {
            min-height: ${d.rowMinH} !important;
            padding: ${d.rowPad} !important;
          }
          :root .main-view-container [data-testid="card"],
          :root .main-view-container [class*="CardButton"],
          :root [class*="main-view"] [data-testid="card"] {
            padding: ${d.cardPad} !important;
          }
          :root .main-view-container [class*="Shelf"] > div,
          :root [class*="main-view"] [class*="Shelf"] > div {
            gap: ${d.gridGap} !important;
          }
          :root {
            --encore-legacy-list-row-horizontal-gap: ${d.listRowHGap} !important;
          }

          /* player bar */
          :root footer,
          :root .Root__now-playing-bar,
          :root [data-testid="now-playing-bar"] {
            margin: -8px !important;
            padding: 8px !important;
            ${d.playerMinH ? `min-height: ${d.playerMinH} !important;` : ""}
          }
          ${(d.playerTopPad || d.playerControlsGap || d.playerAlignBottom) ? `
          :root .main-nowPlayingBar-nowPlayingBar,
          :root .main-nowPlayingBar-container {
            ${d.playerAlignBottom ? "margin-top: auto !important;" : ""}
            ${d.playerTopPad ? `padding-top: ${d.playerTopPad} !important;` : ""}
            ${d.playerControlsGap ? `gap: ${d.playerControlsGap} !important;` : ""}
          }` : ""}
          ${(d.playerInnerPadX || d.playerLeftGap) ? `
          :root .main-nowPlayingBar-left,
          :root .main-nowPlayingWidget-nowPlaying {
            ${d.playerInnerPadX ? `padding-left: ${d.playerInnerPadX} !important;` : ""}
            ${d.playerLeftGap ? `gap: ${d.playerLeftGap} !important;` : ""}
          }` : ""}
          ${d.playerCenterGap ? `
          :root .main-nowPlayingBar-center {
            gap: ${d.playerCenterGap} !important;
          }` : ""}
          ${d.playerControlsGap ? `
          :root .player-controls__buttons,
          :root [data-testid="player-controls"] {
            gap: ${d.playerControlsGap} !important;
          }` : ""}
          ${d.progressBarPadX ? `
          :root .playback-bar,
          :root [data-testid="playback-bar"] {
            padding: 0 ${d.progressBarPadX} !important;
          }` : ""}
          ${(d.playerInnerPadX || d.playerRightGap) ? `
          :root .main-nowPlayingBar-right,
          :root .main-nowPlayingBar-extraControls {
            ${d.playerInnerPadX ? `padding-right: ${d.playerInnerPadX} !important;` : ""}
            ${d.playerRightGap ? `gap: ${d.playerRightGap} !important;` : ""}
          }` : ""}
          ${d.volMarginR ? `
          :root [data-testid="volume-bar"] {
            margin-right: ${d.volMarginR} !important;
          }` : ""}
          :root .vg-wave-container {
            padding-left: ${d.wavePadL} !important;
            padding-right: ${d.wavePadR} !important;
          }
        `;
        if (typeof ntSyncBottom === "function") {
          setTimeout(ntSyncBottom, 100);
          setTimeout(ntSyncBottom, 600);
          setTimeout(ntSyncBottom, 1500);
        }
        break;
      }
      // border-radius: scaled tiers + bg-active glass boxes
      case "border-radius": {
        // default: clear all
        if (value === "default" || value === "") {
          const brEl = document.getElementById("vantagraph-border-radius");
          if (brEl) brEl.remove();
          ["--vg-radius-sm","--vg-radius-md","--vg-radius-lg","--vg-radius-xl","--vg-radius-2xl","--encore-border-radius-rounded"].forEach(p => root.style.removeProperty(p));
          Spicetify.LocalStorage.set("vantagraph-custom:border-radius", "default");
          break;
        }

        root.style.setProperty("--vg-radius-sm", `${value}px`);
        root.style.setProperty("--vg-radius-md", `${Math.round(value * 1.5)}px`);
        root.style.setProperty("--vg-radius-lg", `${value * 2}px`);
        root.style.setProperty("--vg-radius-xl", `${Math.round(value * 2.5)}px`);
        root.style.setProperty("--vg-radius-2xl", `${value * 3}px`);
        root.style.setProperty("--encore-border-radius-rounded", `${value}px`);

        const brId = "vantagraph-border-radius";
        let brEl = document.getElementById(brId);
        if (!brEl) { brEl = document.createElement("style"); brEl.id = brId; document.head.appendChild(brEl); }
        const r = Math.round(value * 1.5);
        brEl.textContent = `
          /* right panel outer */
          body .Root__right-sidebar > div,
          body .Root__right-sidebar > div[class] {
            border-radius: ${r}px !important;
            overflow: hidden !important;
          }

          #Desktop_PanelContainer_Id#Desktop_PanelContainer_Id {
            border-radius: ${r}px !important;
            overflow: hidden !important;
          }
          #Desktop_PanelContainer_Id#Desktop_PanelContainer_Id > div {
            border-radius: ${r}px !important;
            overflow: hidden !important;
          }

          body .Root__right-sidebar aside {
            border-radius: ${r}px !important;
            overflow: hidden !important;
          }

          .main-nowPlayingView-section,
          .main-nowPlayingView-content,
          .main-nowPlayingView-lyricsContent,
          .main-nowPlayingView-gradient {
            border-radius: ${r}px !important;
          }

          [aria-label="Home"],
          .main-globalNav-homeIcon,
          a[href="/"] > span,
          .main-globalNav-navLinkActive {
            border-radius: ${value}px !important;
          }

          .vg-bg-active #Desktop_LeftSidebar_Id {
            border-radius: ${r}px !important;
          }

          .vg-bg-active .Root__main-view,
          .vg-bg-active .vg-main {
            border-radius: ${r}px !important;
          }

          .vg-bg-active .Root__right-sidebar,
          .vg-bg-active .vg-right {
            border-radius: ${r}px !important;
          }

          .Root__now-playing-bar,
          .vg-now-playing-bar,
          .vg-now-playing {
            border-radius: ${r}px !important;
          }
        `;
        break;
      }

      // bg-url: custom image bg; panels turn to glass tinted by the glass-* colours
      case "bg-url":
        const bgId = "vantagraph-bg-element";
        let bgEl = document.getElementById(bgId);
        if (!bgEl) {
          bgEl = document.createElement("div");
          bgEl.id = bgId;
          bgEl.style.cssText = `
            position: fixed; inset: 0; z-index: -1;
            background-size: cover; background-position: center;
            transition: all 0.5s ease;
            pointer-events: none;
          `;
          document.body.prepend(bgEl);
        }
        
        if (value) {
          bgEl.style.backgroundImage = `url("${value}")`;
          bgEl.style.filter = bgFilterValue();
          syncBgVars(value);
          document.documentElement.style.setProperty("--spice-main", "transparent");
          waitForElement(".vg-root", (el) => { el.style.background = "transparent"; });
          document.body.style.background = "transparent";
          document.body.classList.add("vg-bg-active");
        } else {
          bgEl.style.backgroundImage = "none";
          syncBgVars(null);
          document.body.style.background = "";
          document.body.classList.remove("vg-bg-active");
          applyColorKey("panel");
          const vgRoot = document.querySelector(".vg-root");
          if (vgRoot) vgRoot.style.removeProperty("background");
        }
        break;
      // bg-use-album-cover: live update bg from now-playing cover
      case "bg-use-album-cover":
        Spicetify.LocalStorage.set(`vantagraph-custom:${key}`, value);
        if (value === "true" || value === true) {
          waitForElement(".vg-root", (el) => {
            el.style.background = "transparent";
          });
          document.body.style.background = "transparent";
          document.body.classList.add("vg-bg-active");
          updateAlbumCoverBackground();
        } else {
          const customUrl = getSetting("bg-url", "");
          if (customUrl) {
            applySetting("bg-url", customUrl);
          } else {
            syncBgVars(null);
            document.body.style.background = "";
            document.body.classList.remove("vg-bg-active");
            applyColorKey("panel");
            const vgRoot2 = document.querySelector(".vg-root");
            if (vgRoot2) vgRoot2.style.removeProperty("background");
          }
        }
        break;

      // bg image filters: live update existing bg element
      case "bg-blur":
      case "bg-brightness":
      case "bg-contrast":
      case "bg-saturation": {
        const bgEl = document.getElementById("vantagraph-bg-element");
        if (bgEl) {
          bgEl.style.filter = bgFilterValue();
          if (document.body.classList.contains("vg-bg-active")) {
            document.documentElement.style.setProperty("--vg-bg-filter", bgFilterValue());
          }
        }
        break;
      }

      // snippet toggles: CSS lives in user.css; OFF state injects revert
      case "snippet-rounded-images": {
        const sid = "vantagraph-snippet-rounded-images-off";
        let sel = document.getElementById(sid);
        if (value === "false" || value === false) {
          if (!sel) { sel = document.createElement("style"); sel.id = sid; document.head.appendChild(sel); }
          sel.textContent = `.vg-nav-third,
            .vg-cover-art-image,
            .vg-home-shortcut-image,
            .vg-entity-header-shadow,
            .vg-category-card-image,
            .vg-entity-image-circle,
            .vg-main-image,
            .vg-card-image,
            .vg-card-image-wrap,
            .vg-entity-image-placeholder > div,
            .vg-track-row-image,
            .vg-home-shortcut-image-wrapper,
            .vg-special-rounded,
            .vg-artist-overview-image,
            .vg-artist-overview-section
            { border-radius: revert !important; }
            .vg-card-image-circular,
            .vg-entity-image-placeholder,
            .vg-entity-header-circle { border-radius: revert !important; }
            .vg-np-cover img, .vg-np-cover-collapsed img { border-radius: 50% !important; }`;
        } else { if (sel) sel.remove(); }
        break;
      }
      case "snippet-vinyl-stop": {
        const sid = "vantagraph-snippet-vinyl-stop";
        let sel = document.getElementById(sid);
        if (value === "true" || value === true) {
          if (!sel) { sel = document.createElement("style"); sel.id = sid; document.head.appendChild(sel); }
          sel.textContent = `.vg-np-cover img, .vg-np-cover-collapsed img { animation: none !important; animation-play-state: paused !important; }`;
        } else { if (sel) sel.remove(); }
        break;
      }
      // reduced motion: every Spotify transition collapses to 1ms (transitionend
      // still fires, so components waiting on it do not hang), delays dropped,
      // programmatic scrolling instant. Keyframe animations (spinners, skeleton
      // shimmer) are left alone. Theme-driven live elements are excluded.
      case "snippet-reduced-motion": {
        const sid = "vantagraph-snippet-reduced-motion";
        let sel = document.getElementById(sid);
        if (value === "true" || value === true) {
          if (!sel) { sel = document.createElement("style"); sel.id = sid; document.head.appendChild(sel); }
          sel.textContent = `*:not(.vg-wave-bar):not(.vg-ntc-text):not(.vg-next-track-card), *::before, *::after { transition-duration: 1ms !important; transition-delay: 0s !important; }
html, body, * { scroll-behavior: auto !important; }`;
        } else { if (sel) sel.remove(); }
        break;
      }
      case "snippet-modern-scrollbar": {
        const sid = "vantagraph-snippet-modern-scrollbar";
        let sel = document.getElementById(sid);
        if (value === "true" || value === true || (value !== "false" && value !== false)) {
          if (!sel) { sel = document.createElement("style"); sel.id = sid; document.head.appendChild(sel); }
          sel.textContent = `.os-scrollbar-handle { width: 0.25rem !important; border-radius: 10rem !important; transition: width 300ms ease-in-out !important; }
            .os-scrollbar-handle:focus, .os-scrollbar-handle:focus-within, .os-scrollbar-handle:hover { width: 0.35rem !important; }`;
        } else { if (sel) sel.remove(); }
        break;
      }

      // hide buttons (topbar + player bar)
      case "snippet-hide-friend-activity":
      case "snippet-hide-whats-new":
      case "snippet-hide-fullscreen":
      case "snippet-hide-lyrics-btn":
      case "snippet-hide-miniplayer":
      case "snippet-hide-queue-btn":
      case "snippet-hide-shuffle":
      case "snippet-hide-repeat":
      case "snippet-hide-connect":
      case "snippet-hide-volume":
      case "snippet-hide-np-widget":
      case "snippet-hide-next-track": {
        const btnCss = {
          "snippet-hide-friend-activity": ".main-actionButtons button[aria-label='Listening activity'],.main-actionButtons button[aria-label='Friend Activity']{display:none !important}",
          "snippet-hide-whats-new": ".main-actionButtons button[aria-label=\"What's New\"]{display:none !important}",
          "snippet-hide-fullscreen": ".Root__now-playing-bar button[data-testid='fullscreen-mode-button'],.Root__now-playing-bar button[aria-label='Enter Full screen']{display:none !important;width:0 !important;height:0 !important;overflow:hidden !important;padding:0 !important;margin:0 !important;border:0 !important}",
          "snippet-hide-lyrics-btn": ".Root__now-playing-bar button[data-testid='lyrics-button'],.Root__now-playing-bar .main-nowPlayingBar-lyricsButton,.main-nowPlayingBar-lyricsButton{display:none !important;width:0 !important;height:0 !important;overflow:hidden !important;padding:0 !important;margin:0 !important;border:0 !important}",
          "snippet-hide-miniplayer": ".Root__now-playing-bar button[data-testid='pip-toggle-button'],.Root__now-playing-bar button[aria-label='Open Miniplayer']{display:none !important;width:0 !important;height:0 !important;overflow:hidden !important;padding:0 !important;margin:0 !important;border:0 !important}",
          "snippet-hide-queue-btn": ".Root__now-playing-bar button[data-testid='control-button-queue'],.Root__now-playing-bar button[aria-label='Queue'],.main-useDropTarget-base:has(button[data-testid='control-button-queue']){display:none !important;width:0 !important;height:0 !important;overflow:hidden !important;padding:0 !important;margin:0 !important;border:0 !important}",
          "snippet-hide-shuffle": ".Root__now-playing-bar button[data-testid='control-button-shuffle'],.Root__now-playing-bar .main-shuffleButton-button,.Root__now-playing-bar button[aria-label*='shuffle' i]{display:none !important;width:0 !important;height:0 !important;overflow:hidden !important;padding:0 !important;margin:0 !important;border:0 !important}",
          "snippet-hide-repeat": ".Root__now-playing-bar button[data-testid='control-button-repeat'],.Root__now-playing-bar button[aria-label*='repeat'],.Root__now-playing-bar button[aria-label*='Repeat']{display:none !important;width:0 !important;height:0 !important;overflow:hidden !important;padding:0 !important;margin:0 !important;border:0 !important}",
          "snippet-hide-connect": ".Root__now-playing-bar button[aria-label='Connect to a device'],.Root__now-playing-bar button[aria-label*='Connect to']{display:none !important;width:0 !important;height:0 !important;overflow:hidden !important;padding:0 !important;margin:0 !important;border:0 !important}",
          "snippet-hide-volume": ".Root__now-playing-bar [data-testid='volume-bar'],.Root__now-playing-bar button[data-testid='volume-bar-toggle-mute-button']{display:none !important;width:0 !important;height:0 !important;overflow:hidden !important;padding:0 !important;margin:0 !important;border:0 !important}",
          "snippet-hide-np-widget": ".Root__now-playing-bar [data-testid='now-playing-widget'],.Root__now-playing-bar [data-testid='cover-art-button']{display:none !important;width:0 !important;height:0 !important;overflow:hidden !important;padding:0 !important;margin:0 !important;border:0 !important}",
          "snippet-hide-next-track": ".vg-next-track-card{display:none !important}",
        };
        const sid = "vantagraph-" + key;
        let sel = document.getElementById(sid);
        if (value === "true" || value === true) {
          if (!sel) { sel = document.createElement("style"); sel.id = sid; document.head.appendChild(sel); }
          sel.textContent = btnCss[key] || "";
        } else { if (sel) sel.remove(); }
        break;
      }

      // hide elements (home sections, layout, dev CSS)
      case "snippet-hide-ads-banner":
      case "snippet-hide-podcasts":
      case "snippet-hide-promo-card":
      case "snippet-hide-mood-recs":
      case "snippet-hide-made-for-you":
      case "snippet-hide-recents":
      case "snippet-hide-top-mixes":
      case "snippet-hide-jump-back":
      case "snippet-hide-rec-stations":
      case "snippet-hide-new-releases":
      case "snippet-hide-best-artists":
      case "snippet-hide-fav-artists":
      case "snippet-hide-rec-today":
      case "snippet-hide-home-shortcuts":
      case "snippet-thin-library":
      case "snippet-auto-hide-sidebar":
      case "debug-labels":
      case "snippet-dev-layout-grid":
      case "snippet-dev-highlighter": {
        const cssMap = {
          "snippet-hide-podcasts": "button[aria-label='Podcasts']{display:none !important}",
          "snippet-hide-ads-banner": `[data-testid="home-ads-container"],[data-testid="home-ad-card"],[data-testid="embedded-ad"],[data-testid="embedded-ad-carousel"],.main-topBar-UpgradeButton{display:none !important}`,
          "snippet-hide-promo-card": "[data-testid='home-page'] section:not([aria-label]):not([data-testid]){display:none !important}",
          "snippet-hide-mood-recs": "section[aria-label*='Soundtrack your'],section[aria-label*='Start your'],section[aria-label*='late night' i],section[aria-label*='your Monday'],section[aria-label*='your Tuesday'],section[aria-label*='your Wednesday'],section[aria-label*='your Thursday'],section[aria-label*='your Friday'],section[aria-label*='your Saturday'],section[aria-label*='your Sunday']{display:none !important}",
          "snippet-hide-made-for-you": "section[aria-label^='Made For'],.Root__main-view div[aria-label^='Made For']{display:none !important}",
          "snippet-hide-recents": "section[aria-label='Recents'],.Root__main-view div[aria-label='Recents']{display:none !important}",
          "snippet-hide-top-mixes": "section[aria-label='Your top mixes'],.Root__main-view div[aria-label='Your top mixes']{display:none !important}",
          "snippet-hide-jump-back": "section[aria-label='Jump back in'],.Root__main-view div[aria-label='Jump back in']{display:none !important}",
          "snippet-hide-rec-stations": "section[aria-label*='Recommended Stations'],.Root__main-view div[aria-label*='Recommended Stations']{display:none !important}",
          "snippet-hide-new-releases": "section[aria-label*='New releases'],.Root__main-view div[aria-label*='New releases'],.Root__main-view div[aria-label*='New Releases']{display:none !important}",
          "snippet-hide-best-artists": "section[aria-label*='Best of artists' i]{display:none !important}",
          "snippet-hide-fav-artists": "section[aria-label*='favorite artists' i]{display:none !important}",
          "snippet-hide-rec-today": "section[aria-label*='Recommended for today' i]{display:none !important}",
          "snippet-hide-home-shortcuts": "[data-testid='home-page'] section:has([data-testid='shortcut-background']),.view-homeShortcutsGrid-shortcuts{display:none !important}",
          "snippet-thin-library": "#Desktop_LeftSidebar_Id [role='row'] [role='group']{padding-block:2px !important;min-block-size:0 !important}#Desktop_LeftSidebar_Id [role='row'] [role='group'] > *{min-block-size:0 !important;padding-block:0 !important}#Desktop_LeftSidebar_Id [role='row'] .x-entityImage-imageContainer{width:2em !important;height:2em !important;min-width:2em !important;flex-shrink:0 !important}",
          "snippet-auto-hide-sidebar": "@media(max-width:1200px){#Desktop_LeftSidebar_Id{width:0 !important;overflow:hidden}.LayoutResizer__resize-bar{display:none}}",
          "snippet-dev-layout-grid": ".Root__nav-bar{outline:2px dashed #ff6b6b !important}.Root__main-view{outline:2px dashed #4ecdc4 !important}.Root__right-sidebar{outline:2px dashed #ffe66d !important}.Root__now-playing-bar{outline:2px dashed #a8e6cf !important}.Root__globalNav{outline:2px dashed #dda0dd !important}#Desktop_LeftSidebar_Id{outline:2px dashed #ff9f43 !important}",
          "snippet-dev-highlighter": "*:hover{outline:1px solid rgba(29,185,84,0.5) !important;outline-offset:-1px}",
          "debug-labels": `
            body.vg-debug .Root__nav-bar,
            body.vg-debug .Root__main-view,
            body.vg-debug .Root__right-sidebar,
            body.vg-debug .Root__now-playing-bar,
            body.vg-debug footer,
            body.vg-debug .Root__globalNav { position: relative; }

            body.vg-debug .Root__nav-bar::before,
            body.vg-debug .Root__main-view::before,
            body.vg-debug .Root__right-sidebar::before,
            body.vg-debug .Root__now-playing-bar::before,
            body.vg-debug footer::before,
            body.vg-debug .Root__globalNav::before {
              position: absolute; z-index: 9999; top: 4px; left: 4px;
              padding: 2px 8px; border-radius: 4px;
              font-size: 10px; font-weight: 700; letter-spacing: 1px;
              background: rgba(0,0,0,0.85); color: #00ff88;
              font-family: 'JetBrains Mono', monospace;
              pointer-events: none; text-transform: uppercase;
              border: 1px solid rgba(0,255,136,0.3);
              backdrop-filter: blur(4px);
            }
            body.vg-debug .Root__globalNav::before { content: 'TOPBAR - .Root__globalNav'; }
            body.vg-debug .Root__nav-bar::before { content: 'LEFT SIDEBAR - #Desktop_LeftSidebar_Id'; }
            body.vg-debug .Root__main-view::before { content: 'MAIN VIEW - .Root__main-view'; }
            body.vg-debug .Root__right-sidebar::before { content: 'RIGHT PANEL - .Root__right-sidebar'; }
            body.vg-debug .Root__now-playing-bar::before { content: 'NOW PLAYING - .Root__now-playing-bar'; }
            body.vg-debug footer::before { content: 'PLAYER BAR - footer'; }

            body.vg-debug .Root__nav-bar::after,
            body.vg-debug .Root__main-view::after,
            body.vg-debug .Root__right-sidebar::after,
            body.vg-debug .Root__now-playing-bar::after,
            body.vg-debug footer::after,
            body.vg-debug .Root__globalNav::after {
              position: absolute; z-index: 9999; bottom: 4px; left: 4px;
              padding: 2px 6px; border-radius: 3px;
              font-size: 9px; font-weight: 400;
              background: rgba(0,0,0,0.7); color: #888;
              font-family: 'JetBrains Mono', monospace;
              pointer-events: none;
              border: 1px solid rgba(255,255,255,0.1);
            }
            body.vg-debug .Root__globalNav::after { content: 'Safe Zone: TOP BAR (Min Risk)'; color: #4ecdc4; }
            body.vg-debug .Root__nav-bar::after { content: 'Risk: HIGH - Dynamic filtering/resize'; color: #ff6b6b; }
            body.vg-debug .Root__main-view::after { content: 'Risk: EXTREME - React unmount on route'; color: #ff4444; }
            body.vg-debug .Root__right-sidebar::after { content: 'Risk: SEVERE - Contextual re-render'; color: #ff9f43; }
            body.vg-debug .Root__now-playing-bar::after { content: 'Risk: MEDIUM - Horizontal overflow'; color: #ffe66d; }
            body.vg-debug footer::after { content: 'footer element'; color: #666; }
          `,
        };
        const sid = "vantagraph-" + key;
        let sel = document.getElementById(sid);
        if (value === "true" || value === true) {
          if (!sel) { sel = document.createElement("style"); sel.id = sid; document.head.appendChild(sel); }
          sel.textContent = cssMap[key] || "";
          if (key === "debug-labels") document.body.classList.add("vg-debug");
        } else {
          if (sel) sel.remove();
          if (key === "debug-labels") document.body.classList.remove("vg-debug");
        }
        break;
      }

      // dev: spacing visualizer w/ tooltip on hover
      case "snippet-dev-spacing-viz": {
        const styleId = "vantagraph-snippet-dev-spacing-viz";
        const tooltipId = "vg-spacing-tooltip";
        if (value === "true" || value === true) {
          if (!document.getElementById(styleId)) {
            const s = document.createElement("style"); s.id = styleId;
            s.textContent = `#${tooltipId}{position:fixed;z-index:999999;pointer-events:none;font:10px 'JetBrains Mono',monospace;background:rgba(0,0,0,0.9);color:#0f0;padding:5px 10px;border-radius:5px;border:1px solid rgba(0,255,0,0.3);backdrop-filter:blur(6px);white-space:nowrap;opacity:0;transition:opacity 0.15s;box-shadow:0 2px 12px rgba(0,0,0,0.5)}`;
            document.head.appendChild(s);
          }

          if (!document.getElementById(tooltipId)) {
            const tip = document.createElement("div"); tip.id = tooltipId;
            document.body.appendChild(tip);
          }

          window._vgSpacingHandler = function(e) {
            const tip = document.getElementById(tooltipId);
            if (!tip) return;
            const el = e.target;
            if (!el || el === document.body || el === document.documentElement || el.id === tooltipId) { tip.style.opacity = "0"; return; }
            const cs = getComputedStyle(el);
            const parts = [];
            const pT = parseFloat(cs.paddingTop), pR = parseFloat(cs.paddingRight), pB = parseFloat(cs.paddingBottom), pL = parseFloat(cs.paddingLeft);
            const mT = parseFloat(cs.marginTop), mR = parseFloat(cs.marginRight), mB = parseFloat(cs.marginBottom), mL = parseFloat(cs.marginLeft);
            const gap = cs.gap && cs.gap !== "normal" ? cs.gap : null;
            const box = el.getBoundingClientRect();
            const w = Math.round(box.width), h = Math.round(box.height);
            parts.push(w + "×" + h + "px");
            if (pT || pR || pB || pL) parts.push("pad " + pT + "/" + pR + "/" + pB + "/" + pL);
            if (mT || mR || mB || mL) parts.push("mar " + mT + "/" + mR + "/" + mB + "/" + mL);
            if (gap) parts.push("gap " + gap);
            tip.textContent = parts.join(" │ ");
            const rect = el.getBoundingClientRect();
            tip.style.left = Math.min(rect.left, window.innerWidth - 280) + "px";
            tip.style.top = Math.max(0, rect.top - 24) + "px";
            tip.style.opacity = "1";
            el.style.outline = "1px dashed rgba(0,255,0,0.5)";
            el.style.outlineOffset = "-1px";
          };
          window._vgSpacingLeave = function(e) {
            const tip = document.getElementById(tooltipId);
            if (tip) tip.style.opacity = "0";
            if (e.target && e.target.style) { e.target.style.outline = ""; e.target.style.outlineOffset = ""; }
          };
          document.addEventListener("mouseover", window._vgSpacingHandler, true);
          document.addEventListener("mouseout", window._vgSpacingLeave, true);
          Spicetify.showNotification("Spacing Visualizer active ✓");
        } else {
          const s = document.getElementById(styleId); if (s) s.remove();
          const tip = document.getElementById(tooltipId); if (tip) tip.remove();
          if (window._vgSpacingHandler) { document.removeEventListener("mouseover", window._vgSpacingHandler, true); window._vgSpacingHandler = null; }
          if (window._vgSpacingLeave) { document.removeEventListener("mouseout", window._vgSpacingLeave, true); window._vgSpacingLeave = null; }
        }
        break;
      }

      // dev: live CSS variable monitor panel
      case "snippet-dev-var-monitor": {
        const panelId = "vg-var-monitor";
        if (value === "true" || value === true) {
          if (!document.getElementById(panelId)) {
            Spicetify.showNotification("⏳ CSS Variable Monitor loading...");
            const p = document.createElement("div"); p.id = panelId;
            p.style.cssText = "position:fixed;top:60px;left:50%;transform:translateX(-50%);z-index:99999;background:rgba(0,0,0,0.92);color:#0f0;font:11px 'JetBrains Mono',monospace;padding:14px 18px;border-radius:12px;max-height:70vh;min-width:340px;overflow-y:auto;pointer-events:none;backdrop-filter:blur(12px);border:1px solid rgba(0,255,136,0.25);box-shadow:0 8px 32px rgba(0,0,0,0.6);";
            document.body.appendChild(p);
            const tid = setInterval(() => {
              const el = document.getElementById(panelId);
              if (!el) { clearInterval(tid); return; }
              const cs = getComputedStyle(document.documentElement);
              const vars = [
                "--spice-window","--spice-panel","--spice-panel-hover",
                "--spice-menu","--spice-player","--spice-stroke",
                "--spice-text","--spice-subtext","--spice-accent",
                "--spice-btn-active","--spice-tab-active",
                "--spice-play-btn","--spice-play-btn-hover",
                "--spice-bar-fill","--spice-bar-bg","--spice-heart",
                "--spice-main","--spice-sidebar","--spice-card","--spice-play-button","--spice-progress-fg",
                "--vg-icon-t1","--vg-icon-t3","--vg-radius-sm","--vg-radius-md","--vg-radius-lg",
                "--encore-border-radius-rounded","--encore-graphic-size-decorative-smaller",
                "--encore-graphic-size-decorative-base","--encore-text-body-medium-font-size",
              ];
              el.innerHTML = "<b style='color:#00ff88;font-size:12px'>🎨 CSS Variables (" + vars.filter(v=>cs.getPropertyValue(v).trim()).length + "/" + vars.length + ")</b><hr style='border-color:rgba(0,255,136,0.15);margin:6px 0'>" + vars.map(v => {
                const val = cs.getPropertyValue(v).trim();
                if (!val) return "";
                const isColor = val.startsWith("#") || val.startsWith("rgb");
                const swatch = isColor ? `<span style="display:inline-block;width:10px;height:10px;background:${val};border-radius:2px;margin-right:4px;border:1px solid rgba(255,255,255,0.2)"></span>` : "";
                const shortName = v.replace("--spice-","").replace("--vg-","vg:").replace("--encore-","enc:");
                return `<span style="color:#555">${shortName}</span> ${swatch}<span style="color:${isColor ? '#aaa' : '#666'}">${val}</span>`;
              }).filter(Boolean).join("<br>");
            }, 1500);
            p.dataset.tid = tid;
            setTimeout(() => Spicetify.showNotification("CSS Variable Monitor active ✓"), 1600);
          }
        } else {
          const el = document.getElementById(panelId);
          if (el) { clearInterval(parseInt(el.dataset.tid)); el.remove(); }
        }
        break;
      }

      // dev: DOM mutation logger -> console
      case "snippet-dev-dom-logger": {
        if (value === "true" || value === true) {
          if (!window._vgMutObs) {
            window._vgMutObs = new MutationObserver(muts => {
              muts.forEach(m => {
                if (m.type === "childList") {
                  m.addedNodes.forEach(n => { if (n.nodeType === 1) console.log("%c[VG:DOM+]", "color:#0f0;font-weight:bold", n.tagName, n.id ? "#"+n.id : "", n.className ? "."+String(n.className).substring(0,60) : "", n.getAttribute && n.getAttribute("data-testid") ? "[testid="+n.getAttribute("data-testid")+"]" : ""); });
                  m.removedNodes.forEach(n => { if (n.nodeType === 1) console.log("%c[VG:DOM-]", "color:#f44;font-weight:bold", n.tagName, n.id ? "#"+n.id : "", n.className ? "."+String(n.className).substring(0,60) : ""); });
                } else if (m.type === "attributes") {
                  console.log("%c[VG:ATTR]", "color:#ff0;font-weight:bold", m.target.tagName, m.attributeName + "=" + (m.target.getAttribute(m.attributeName) || "").substring(0,50));
                }
              });
            });
            window._vgMutObs.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ["class","style","data-testid","aria-label"] });
            console.log("%c[VG] DOM Mutation Logger started - watching childList + attributes", "color:#0f0;font-weight:bold");
            Spicetify.showNotification("DOM Logger active → check DevTools console");
          }
        } else {
          if (window._vgMutObs) { window._vgMutObs.disconnect(); window._vgMutObs = null; console.log("%c[VG] DOM Mutation Logger stopped", "color:#f44;font-weight:bold"); Spicetify.showNotification("DOM Logger stopped"); }
        }
        break;
      }

      // dev: encore/testid/aria audit -> downloads .txt
      case "snippet-dev-encore-audit": {
        if (value === "true" || value === true) {
          // self-disable to prevent re-trigger loop
          Spicetify.LocalStorage.set("vantagraph-custom:snippet-dev-encore-audit", "false");
          try {
            const lines = [];
            lines.push("═══ VANTAGRAPH ENCORE AUDIT ═══");
            lines.push("Date: " + new Date().toISOString());
            lines.push("Page: " + location.pathname);
            lines.push("");

            const icons = document.querySelectorAll('[data-encore-id="icon"]');
            const stats = {};
            icons.forEach(ic => { try { const cs = getComputedStyle(ic); stats[cs.width + " × " + cs.height] = (stats[cs.width + " × " + cs.height] || 0) + 1; } catch(e){} });
            lines.push("── ENCORE ICONS (" + icons.length + ") ──");
            Object.entries(stats).forEach(([k,v]) => lines.push("  " + k + " → " + v + "x"));

            lines.push("");
            const btns = document.querySelectorAll('[data-encore-id]');
            const btnStats = {};
            btns.forEach(b => { const t = b.getAttribute("data-encore-id"); btnStats[t] = (btnStats[t] || 0) + 1; });
            lines.push("── ENCORE COMPONENTS (" + btns.length + ") ──");
            Object.entries(btnStats).sort((a,b) => b[1]-a[1]).forEach(([k,v]) => lines.push("  " + k + " → " + v + "x"));

            lines.push("");
            const testIds = new Set();
            document.querySelectorAll("[data-testid]").forEach(el => testIds.add(el.getAttribute("data-testid")));
            lines.push("── DATA-TESTID ELEMENTS (" + testIds.size + ") ──");
            [...testIds].sort().forEach(id => lines.push("  " + id));

            lines.push("");
            const ariaSet = new Set();
            document.querySelectorAll("button[aria-label],a[aria-label],[role='button'][aria-label]").forEach(el => {
              ariaSet.add(el.tagName + " | " + el.getAttribute("aria-label"));
            });
            lines.push("── ARIA-LABEL BUTTONS (" + ariaSet.size + ") ──");
            [...ariaSet].sort().forEach(a => lines.push("  " + a));

            lines.push("");
            lines.push("── CSS VARIABLES ──");
            const cs = getComputedStyle(document.documentElement);
            const allProps = Array.from(document.styleSheets).reduce((acc, sheet) => {
              try { Array.from(sheet.cssRules).forEach(r => { if (r.style) { for (let i = 0; i < r.style.length; i++) { const p = r.style[i]; if (p.startsWith("--")) acc.add(p); } } }); } catch(e) {}
              return acc;
            }, new Set());
            [...allProps].sort().forEach(v => {
              const val = cs.getPropertyValue(v).trim();
              if (val) lines.push("  " + v + ": " + val);
            });

            lines.push("");
            lines.push("── ACTIVE STYLE TAGS ──");
            document.querySelectorAll("style[id]").forEach(s => lines.push("  #" + s.id + " (" + s.textContent.length + " chars)"));

            const blob = new Blob([lines.join("\n")], { type: "text/plain" });
            const url = URL.createObjectURL(blob);
            const a = document.createElement("a"); a.href = url; a.download = "vantagraph-encore-audit.txt";
            document.body.appendChild(a); a.click(); document.body.removeChild(a);
            URL.revokeObjectURL(url);
            Spicetify.showNotification("Encore audit → txt downloaded ✓");
          } catch(e) {
            Spicetify.showNotification("Audit error: " + e.message);
          }
        }
        break;
      }
    }
  }

  // ALBUM COVER BG
  // try metadata paths first, fall back to DOM cover img
  function getAlbumCoverUrl() {
    let url = Spicetify?.Player?.data?.item?.metadata?.image_url
           || Spicetify?.Player?.data?.item?.metadata?.image_xlarge_url
           || Spicetify?.Player?.data?.item?.metadata?.image_large_url
           || Spicetify?.Player?.data?.track?.metadata?.image_url
           || Spicetify?.Player?.data?.track?.metadata?.image_xlarge_url;
    if (!url) {
      const coverImg = document.querySelector('[data-testid="cover-art-image"]')
                    || document.querySelector('.main-nowPlayingWidget-coverArt img')
                    || document.querySelector('.cover-art img');
      if (coverImg?.src) url = coverImg.src;
    }
    if (!url) return null;
    url = url.replace("spotify:image:", "https://i.scdn.co/image/");
    return url;
  }

  let _bgRetryCount = 0;
  function updateAlbumCoverBackground() {
    const useAlbum = getSetting("bg-use-album-cover", "false");
    if (useAlbum !== "true") return;

    const albumUrl = getAlbumCoverUrl();
    // retry up to 5x: metadata may not be ready
    if (!albumUrl) {
      if (_bgRetryCount < 5) {
        _bgRetryCount++;
        setTimeout(updateAlbumCoverBackground, 300);
      }
      return;
    }
    _bgRetryCount = 0;

    const bgId = "vantagraph-bg-element";
    let bgEl = document.getElementById(bgId);
    if (!bgEl) {
      bgEl = document.createElement("div");
      bgEl.id = bgId;
      bgEl.style.cssText = `
        position: fixed; inset: 0; z-index: -1;
        background-size: cover; background-position: center;
        transition: all 0.5s ease;
        pointer-events: none;
      `;
      document.body.prepend(bgEl);
    }

    bgEl.style.backgroundImage = `url("${albumUrl}")`;
    bgEl.style.filter = bgFilterValue();
    syncBgVars(albumUrl);
    document.documentElement.style.setProperty("--spice-main", "transparent");
    waitForElement(".vg-root", (el) => { el.style.background = "transparent"; });
    document.body.style.background = "transparent";
    document.body.classList.add("vg-bg-active");
  }

  function onSongChangeBackground() {
    const useAlbum = getSetting("bg-use-album-cover", "false");
    if (useAlbum !== "true") return;
    if (Spicetify?.Player?.data?.item?.provider === "ad") return;
    if (!Spicetify?.Player?.data?.item) {
      setTimeout(onSongChangeBackground, 200);
      return;
    }
    updateAlbumCoverBackground();
  }

  // VINYL SPIN
  function setupVinylSpin() {
    function updateSpin() {
      waitForElement(".vg-np-cover img, .vg-np-cover-collapsed img", (img) => {
        let isPlaying = false; try { isPlaying = Spicetify.Player.isPlaying(); } catch(e) {}
        if (!img.style.animationName) {
          img.style.animation = "vg-vinyl-spin 8s linear infinite";
          img.style.borderRadius = "50%";
        }
        // only flip the play state; re-assigning `animation` restarted the
        // rotation and repainted the cover on every resume
        img.style.animationPlayState = isPlaying ? "running" : "paused";
      });
    }

    Spicetify.Player.addEventListener("onplaypause", updateSpin);
    Spicetify.Player.addEventListener("songchange", () => {
      setTimeout(updateSpin, 300);
    });
    updateSpin();
  }

  // NEXT TRACK CARD
  function injectNextTrackCSS() {
    if (document.getElementById("vg-next-track-css")) return;
    const s = document.createElement("style");
    s.id = "vg-next-track-css";
    s.textContent = `
.vg-next-track-card{position:fixed;bottom:72px;left:50%;transform:translateX(-50%);z-index:2;min-width:260px;max-width:460px;height:48px;pointer-events:auto;background:var(--spice-player, var(--spice-playbar));border:1px solid var(--spice-stroke, var(--spice-highlight));border-bottom:none;border-radius:16px 16px 0 0;opacity:0;visibility:hidden;transition:opacity .4s cubic-bezier(.4,0,.2,1),visibility .4s cubic-bezier(.4,0,.2,1),transform .4s cubic-bezier(.4,0,.2,1);transform:translateX(-50%) translateY(5px);box-shadow:0 -4px 16px color-mix(in srgb,var(--spice-shadow) 25%,transparent),inset 0 1px 0 color-mix(in srgb,var(--vg-shine) 24%,transparent);overflow:hidden;}
.vg-next-track-card.vg-ntc-visible{opacity:1;visibility:visible;transform:translateX(-50%) translateY(0);}
.vg-ntc-inner{display:flex;align-items:center;gap:10px;padding:6px 18px 6px 6px;height:100%;position:relative;white-space:nowrap;overflow:hidden;}
.vg-ntc-inner::after{content:"";position:absolute;top:0;left:14px;right:14px;height:2px;background:linear-gradient(90deg,transparent 0%,var(--spice-accent) 50%,transparent 100%);opacity:.7;pointer-events:none;z-index:1;}
.vg-next-track-card::before{content:"";position:absolute;top:0;left:0;right:0;height:1px;background:linear-gradient(90deg,transparent 0%,color-mix(in srgb,var(--vg-shine) 48%,transparent) 30%,color-mix(in srgb,var(--vg-shine) 48%,transparent) 70%,transparent 100%);pointer-events:none;z-index:2;}
.vg-next-track-card::after{display:none;}
.vg-ntc-cover{width:34px;height:34px;min-width:34px;border-radius:8px;object-fit:cover;background:var(--spice-panel, var(--spice-main));margin-left:3px;}
.vg-ntc-label{font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:1.2px;color:var(--spice-accent);opacity:.9;flex-shrink:0;}
.vg-ntc-sep{font-size:12px;color:var(--spice-subtext);opacity:.4;flex-shrink:0;}
.vg-ntc-text{font-size:13px;color:var(--spice-text);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;min-width:0;}
.vg-ntc-artist-text{color:var(--spice-subtext);font-weight:400;}
.vg-ntc-title-text{color:var(--spice-text);font-weight:500;}
.vg-ntc-sep-text{color:var(--spice-subtext);font-weight:400;}
.vg-ntc-text.vg-ntc-fade-out{opacity:0;transition:opacity .2s ease;}
.vg-ntc-text.vg-ntc-fade-in{opacity:1;transition:opacity .3s ease;}
@media(max-width:900px){.vg-next-track-card{max-width:320px;min-width:180px;}}
@media(max-width:600px){.vg-next-track-card{display:none !important;}}`;
    document.head.appendChild(s);
  }

  // resolve cover img: images[] first, then metadata fallback
  function ntGetImageUrl(item) {
    if (!item) return null;
    const imgs = item.images;
    if (imgs && imgs.length > 0) {
      return (imgs[3] && imgs[3].url) || (imgs[2] && imgs[2].url) || (imgs[1] && imgs[1].url) || (imgs[0] && imgs[0].url) || null;
    }
    const meta = item.metadata;
    if (meta) {
      const metaImg = meta.image_url || meta.image_xlarge_url || meta.image_large_url || meta.image_small_url || null;
      if (metaImg) return metaImg.replace("spotify:image:", "https://i.scdn.co/image/");
    }
    return null;
  }

  // pull next track from nextItems, fall back to queue
  function getNextTrackData() {
    try {
      const data = Spicetify.Player.data;
      if (!data) return null;
      const nextItems = data.nextItems;
      if (nextItems && nextItems.length > 0) {
        const next = nextItems[0];
        if (!next) return null;
        const meta = next.metadata || {};
        const title = meta.title || next.name || "";
        let artist = meta.artist_name || "";
        if (!artist && next.artists && next.artists.length > 0) {
          artist = next.artists.map(a => a.name).join(", ");
        }
        if (!title) return null;
        return { title, artist, img: ntGetImageUrl(next) };
      }
      if (data.queue && data.queue.nextTracks && data.queue.nextTracks.length > 0) {
        const qNext = data.queue.nextTracks[0];
        const qMeta = qNext.metadata || {};
        const qTitle = qMeta.title || qNext.name || "";
        const qArtist = qMeta.artist_name || "";
        if (!qTitle) return null;
        return { title: qTitle, artist: qArtist, img: ntGetImageUrl(qNext) };
      }
      return null;
    } catch (e) { return null; }
  }

  let ntCard = null, ntCover = null, ntText = null, ntArtist = null, ntSep = null, ntTitle = null;
  let ntLastTitle = "", ntLastArtist = "";

  function ntUpdateCard() {
    if (!ntCard) return;
    const data = getNextTrackData();
    if (!data) { ntCard.classList.remove("vg-ntc-visible"); return; }
    const changed = (data.title !== ntLastTitle || data.artist !== ntLastArtist);
    ntLastTitle = data.title; ntLastArtist = data.artist;
    if (data.img && ntCover) { if (ntCover.src !== data.img) ntCover.src = data.img; ntCover.style.display = ""; }
    else if (ntCover) { ntCover.style.display = "none"; }
    if (changed && ntText) {
      ntText.classList.add("vg-ntc-fade-out");
      setTimeout(() => {
        if (data.artist) { ntArtist.textContent = data.artist; ntSep.textContent = " - "; ntTitle.textContent = data.title; ntArtist.style.display = ""; ntSep.style.display = ""; }
        else { ntArtist.textContent = ""; ntSep.textContent = ""; ntTitle.textContent = data.title; ntArtist.style.display = "none"; ntSep.style.display = "none"; }
        ntText.classList.remove("vg-ntc-fade-out"); ntText.classList.add("vg-ntc-fade-in");
        setTimeout(() => ntText.classList.remove("vg-ntc-fade-in"), 300);
      }, 200);
    } else if (ntText) {
      if (data.artist) { ntArtist.textContent = data.artist; ntSep.textContent = " - "; ntTitle.textContent = data.title; ntArtist.style.display = ""; ntSep.style.display = ""; }
      else { ntArtist.textContent = ""; ntSep.textContent = ""; ntTitle.textContent = data.title; ntArtist.style.display = "none"; ntSep.style.display = "none"; }
    }
    ntCard.classList.add("vg-ntc-visible");
  }

  // keep card as immediate sibling after player bar
  function ntEnsurePosition(card) {
    const playerBar = document.querySelector(".Root__now-playing-bar") || document.querySelector(".vg-now-playing-bar");
    if (playerBar) {
      if (card.previousElementSibling !== playerBar) {
        playerBar.after(card);
      }
    }
  }

  function ntInjectCard() {
    if (document.getElementById("vg-next-track-card")) {
      ntCard = document.getElementById("vg-next-track-card");
      ntCover = ntCard.querySelector(".vg-ntc-cover"); ntText = ntCard.querySelector(".vg-ntc-text");
      ntArtist = ntCard.querySelector(".vg-ntc-artist-text"); ntSep = ntCard.querySelector(".vg-ntc-sep-text"); ntTitle = ntCard.querySelector(".vg-ntc-title-text");
      ntEnsurePosition(ntCard);
      ntSyncBottom();
      ntUpdateCard(); return;
    }
    ntCard = document.createElement("div"); ntCard.id = "vg-next-track-card"; ntCard.className = "vg-next-track-card";
    const inner = document.createElement("div"); inner.className = "vg-ntc-inner";
    ntCover = document.createElement("img"); ntCover.className = "vg-ntc-cover"; ntCover.alt = ""; ntCover.draggable = false;
    const label = document.createElement("span"); label.className = "vg-ntc-label"; label.textContent = "NEXT";
    const sep = document.createElement("span"); sep.className = "vg-ntc-sep"; sep.textContent = "›";
    ntText = document.createElement("span"); ntText.className = "vg-ntc-text";
    ntArtist = document.createElement("span"); ntArtist.className = "vg-ntc-artist-text";
    ntSep = document.createElement("span"); ntSep.className = "vg-ntc-sep-text";
    ntTitle = document.createElement("span"); ntTitle.className = "vg-ntc-title-text";
    ntText.appendChild(ntArtist); ntText.appendChild(ntSep); ntText.appendChild(ntTitle);
    inner.appendChild(ntCover); inner.appendChild(label); inner.appendChild(sep); inner.appendChild(ntText);
    ntCard.appendChild(inner);
    // insert after player bar; body fallback if not yet rendered
    const playerBar = document.querySelector(".Root__now-playing-bar") || document.querySelector(".vg-now-playing-bar");
    if (playerBar) {
      playerBar.after(ntCard);
    } else {
      document.body.appendChild(ntCard);
    }
    ntSyncBottom();
    setTimeout(ntUpdateCard, 500);
    // retry positioning: player bar may load late
    setTimeout(() => ntEnsurePosition(ntCard), 1000);
    setTimeout(() => ntEnsurePosition(ntCard), 3000);
    setTimeout(() => ntEnsurePosition(ntCard), 6000);
  }

  // anchor card to player bar's top edge
  function ntSyncBottom() {
    if (!ntCard) return;
    const bar = document.querySelector(".Root__now-playing-bar") ||
                document.querySelector("footer");
    if (!bar) { ntCard.style.bottom = "72px"; return; }
    const sync = () => {
      const top = bar.getBoundingClientRect().top;
      ntCard.style.bottom = Math.ceil(window.innerHeight - top) + "px";
    };
    sync();
    requestAnimationFrame(sync);
  }

  // re-inject card if React unmounts it
  let ntObserver = null, ntDebounce = null;
  function ntSetupObserver() {
    if (ntObserver) return;
    ntObserver = new MutationObserver(() => {
      if (ntDebounce) clearTimeout(ntDebounce);
      ntDebounce = setTimeout(() => { if (!document.getElementById("vg-next-track-card")) ntInjectCard(); }, 500);
    });
    const target = document.querySelector(".vg-now-playing");
    if (target) ntObserver.observe(target, { childList: true });
  }

  function initNextTrack() {
    injectNextTrackCSS();
    ntInjectCard();
    Spicetify.Player.addEventListener("songchange", () => { ntSyncBottom(); setTimeout(ntUpdateCard, 400); if (!document.getElementById("vg-next-track-card")) ntInjectCard(); });
    Spicetify.Player.addEventListener("onplaypause", () => setTimeout(ntUpdateCard, 300));
    try {
      const pAPI = Spicetify.Platform.PlayerAPI;
      if (pAPI && pAPI._queue && pAPI._queue._events && pAPI._queue._events.addListener) {
        pAPI._queue._events.addListener("queue_update", () => setTimeout(ntUpdateCard, 400));
      }
    } catch (e) {}
    try { Spicetify.Platform.History.listen(() => { setTimeout(() => { if (!document.getElementById("vg-next-track-card")) ntInjectCard(); else ntUpdateCard(); }, 600); }); } catch (e) {}
    ntSetupObserver();
    // progressive re-syncs for slow startup
    setTimeout(ntSyncBottom, 1000);
    setTimeout(ntSyncBottom, 3000);
    setTimeout(ntSyncBottom, 6000);
    setTimeout(ntSyncBottom, 10000);
    window.addEventListener("resize", () => ntSyncBottom());
  }

  // WAVE ANIMATION
  function injectWaveCSS() {
    if (document.getElementById("vg-wave-css")) return;
    const s = document.createElement("style"); s.id = "vg-wave-css";
    s.textContent = `.vg-wave-container{display:flex !important;align-items:flex-end !important;justify-content:center !important;gap:2px !important;height:25px !important;padding-top:0px !important;padding-bottom:0px !important;padding-left:0px !important;padding-right:20px !important;flex-shrink:0 !important;transition:opacity 2s ease;overflow:hidden !important;clip-path:inset(0) !important;contain:layout paint !important;box-sizing:border-box !important;width:75px !important;margin-right:auto !important;}
.vg-wave-bar{width:3px;height:100%;border-radius:1.5px 1.5px 0 0;background:var(--spice-accent);transform-origin:bottom;transform:scaleY(.03);will-change:transform;transition:transform .15s cubic-bezier(.4,0,.2,1);flex-shrink:0;}`;
    document.head.appendChild(s);
  }

  const WAVE_BARS = 13, WAVE_MID = Math.floor(WAVE_BARS / 2), WAVE_MIN_H = 3;
  const WAVE_MAX_H = [];
  for (let i = 0; i < WAVE_BARS; i++) { WAVE_MAX_H[i] = 100 - (Math.abs(i - WAVE_MID) / WAVE_MID) * 40; }

  // zone: bass 0-3, mid 4-8, treble 9-12
  const WAVE_BAR_ZONE = [];
  for (let i = 0; i < WAVE_BARS; i++) {
    if (i <= 3) WAVE_BAR_ZONE[i] = "bass";
    else if (i <= 8) WAVE_BAR_ZONE[i] = "mid";
    else WAVE_BAR_ZONE[i] = "treble";
  }

  let waveEl = null, waveBars = [], waveInjected = false, waveRafId = null;
  let waveAmplitude = 1, waveFadeTimer = null, waveFadingOut = false;
  let waveProgressPoller = null, waveListenersRegistered = false;

  // audio analysis state (loudness + timbre per segment)
  let waveSegments = null;
  let waveFallbackMode = false;

  const waveBarTargets = new Array(WAVE_BARS).fill(WAVE_MIN_H);
  const waveBarSpeeds = [];
  for (let i = 0; i < WAVE_BARS; i++) { waveBarSpeeds[i] = 150 + Math.random() * 300; }
  const waveBarTimers = new Array(WAVE_BARS).fill(0);

  function waveGetVolume() { try { const v = Spicetify.Player.getVolume(); return typeof v === "number" ? v : 1; } catch (e) { return 1; } }

  // fetch audio analysis: loudness + timbre
  async function waveFetchAnalysis() {
    waveSegments = null;
    waveFallbackMode = false;
    try {
      const uri = Spicetify.Player.data?.item?.uri;
      if (!uri) { waveFallbackMode = true; return; }
      const id = uri.split(":").pop();
      const analysis = await Spicetify.CosmosAsync.get(
        `https://spclient.wg.spotify.com/audio-attributes/v1/audio-analysis/${id}?format=json`
      );
      if (analysis?.segments?.length > 0) {
        const s0 = analysis.segments[0];
        if (typeof s0.start === "number" && typeof s0.loudness_max === "number") {
          waveSegments = analysis.segments;
        } else {
          waveFallbackMode = true;
        }
      } else {
        waveFallbackMode = true;
      }
    } catch (e) {
      waveFallbackMode = true;
    }
  }

  // binary-search current segment, interp loudness curve, derive bass/mid/treble from timbre
  function waveGetSegmentAtProgress() {
    if (!waveSegments || waveSegments.length === 0) return null;
    try {
      const progressSec = Spicetify.Player.getProgress() / 1000;
      let lo = 0, hi = waveSegments.length - 1, seg = waveSegments[0];
      while (lo <= hi) {
        const mid = (lo + hi) >> 1;
        if (waveSegments[mid].start <= progressSec) { seg = waveSegments[mid]; lo = mid + 1; }
        else { hi = mid - 1; }
      }
      const lStart = typeof seg.loudness_start === "number" ? seg.loudness_start : -20;
      const lMax = typeof seg.loudness_max === "number" ? seg.loudness_max : -10;
      const lEnd = typeof seg.loudness_end === "number" ? seg.loudness_end : lStart;
      const dur = seg.duration || 0.5;
      const maxTime = seg.loudness_max_time || (dur * 0.3);

      const elapsed = progressSec - seg.start;
      let loudnessDb;
      if (elapsed < maxTime) {
        const t = maxTime > 0 ? elapsed / maxTime : 0;
        loudnessDb = lStart + t * (lMax - lStart);
      } else {
        const remaining = dur - maxTime;
        const t = remaining > 0 ? (elapsed - maxTime) / remaining : 1;
        loudnessDb = lMax + t * (lEnd - lMax);
      }

      if (isNaN(loudnessDb)) loudnessDb = -15;
      const amplitude = Math.max(0, Math.min(1, Math.pow(10, loudnessDb / 20)));
      if (isNaN(amplitude)) return null;

      const timbre = seg.timbre || [];
      const brightness = timbre.length > 1 ? timbre[1] : 0;
      const normBright = Math.max(-1, Math.min(1, brightness / 150));

      const bass = amplitude * Math.max(0.2, 1 - normBright * 0.8);
      const treble = amplitude * Math.max(0.2, 1 + normBright * 0.8);
      const mid = amplitude * (1 - Math.abs(normBright) * 0.5);

      return { amplitude, bass, mid, treble };
    } catch (e) { return null; }
  }

  // RAF loop: real audio data when available, randomized fallback otherwise
  let waveLastFrame = 0;
  function waveLoop(ts) {
    if (!waveLastFrame) waveLastFrame = ts;
    // ~30 fps is plenty for 13 bars; redrawing at the monitor's 144-200 Hz kept Spotify at ~150 % CPU
    if (ts - waveLastFrame < 33) { waveRafId = requestAnimationFrame(waveLoop); return; }
    const dt = ts - waveLastFrame; waveLastFrame = ts;
    const vol = waveGetVolume(), amp = waveAmplitude * vol;

    const segData = (!waveFallbackMode) ? waveGetSegmentAtProgress() : null;
    const useReal = segData !== null;

    for (let i = 0; i < WAVE_BARS; i++) {
      waveBarTimers[i] += dt;
      if (waveBarTimers[i] >= waveBarSpeeds[i]) {
        waveBarTimers[i] = 0;
        const bellCurve = WAVE_MAX_H[i] / 100;
        let barHeight;
        if (useReal) {
          const zone = WAVE_BAR_ZONE[i];
          const energy = zone === "bass" ? segData.bass : zone === "treble" ? segData.treble : segData.mid;
          const variation = 0.75 + Math.random() * 0.5;
          barHeight = WAVE_MIN_H + energy * bellCurve * variation * amp * (100 - WAVE_MIN_H);
        } else {
          const maxH = WAVE_MAX_H[i] * amp;
          barHeight = maxH <= WAVE_MIN_H ? WAVE_MIN_H : WAVE_MIN_H + Math.random() * (maxH - WAVE_MIN_H);
        }
        waveBarTargets[i] = Math.max(WAVE_MIN_H, Math.min(100, barHeight));
        waveBarSpeeds[i] = useReal ? (80 + Math.random() * 120) : (150 + Math.random() * 300);
      }
      if (waveBars[i]) waveSetBar(i, waveBarTargets[i]);
    }
    waveRafId = requestAnimationFrame(waveLoop);
  }

  // bars animate transform (compositor) instead of height (layout every frame);
  // a bar is only written when its target changes
  const waveBarShown = new Array(WAVE_BARS).fill(-1);
  function waveSetBar(i, pct) {
    if (waveBarShown[i] === pct) return;
    waveBarShown[i] = pct;
    waveBars[i].style.transform = "scaleY(" + (pct / 100).toFixed(3) + ")";
  }
  function waveStart() { waveStop(); waveLastFrame = 0; waveRafId = requestAnimationFrame(waveLoop); }
  function waveStop() { if (waveRafId) { cancelAnimationFrame(waveRafId); waveRafId = null; } }
  function waveShow() { if (waveEl) waveEl.style.opacity = "1"; }
  function waveHide() { if (waveEl) waveEl.style.opacity = "0"; }
  function waveResetBars() {
    for (let i = 0; i < WAVE_BARS; i++) { waveBarTargets[i] = WAVE_MIN_H; waveBarTimers[i] = 0; if (waveBars[i]) waveSetBar(i, WAVE_MIN_H); }
  }
  function waveInstantStart() { waveAmplitude = 1; waveShow(); waveStart(); }
  function waveInstantStop() { waveStop(); if (waveFadeTimer) { clearInterval(waveFadeTimer); waveFadeTimer = null; } waveResetBars(); waveHide(); }
  function waveFadeIn() {
    if (waveFadeTimer) clearInterval(waveFadeTimer);
    waveAmplitude = 0.05; waveShow(); waveStart();
    waveFadeTimer = setInterval(() => { waveAmplitude = Math.min(1, waveAmplitude + (1 / 30)); if (waveAmplitude >= 1) { clearInterval(waveFadeTimer); waveFadeTimer = null; } }, 100);
  }
  function waveFadeOut() {
    if (waveFadeTimer) clearInterval(waveFadeTimer);
    waveFadeTimer = setInterval(() => { waveAmplitude = Math.max(0, waveAmplitude - 0.05); if (waveAmplitude <= 0) { clearInterval(waveFadeTimer); waveFadeTimer = null; waveResetBars(); waveHide(); waveStop(); } }, 100);
  }
  // poll progress: trigger fade-out near end of track (97%)
  function waveStartProgressPoll() {
    if (waveProgressPoller) clearInterval(waveProgressPoller);
    waveFadingOut = false;
    waveProgressPoller = setInterval(() => {
      try {
        if (!Spicetify.Player.isPlaying()) return;
        const pct = Spicetify.Player.getProgress() / Spicetify.Player.getDuration();
        if (pct >= 0.97 && !waveFadingOut) { waveFadingOut = true; waveFadeOut(); }
      } catch (e) {}
    }, 500);
  }
  function waveStopProgressPoll() { if (waveProgressPoller) { clearInterval(waveProgressPoller); waveProgressPoller = null; } }

  // played-tracks set: fade-in only on first play, instant on replay (capped at 200)
  const wavePlayedTracks = new Set();

  function waveOnPlayPause() {
    if (Spicetify.Player.isPlaying()) { waveInstantStart(); waveStartProgressPoll(); }
    else { waveInstantStop(); waveStopProgressPoll(); }
  }
  function waveOnSongChange() {
    waveStop(); waveStopProgressPoll();
    if (waveFadeTimer) { clearInterval(waveFadeTimer); waveFadeTimer = null; }
    waveFadingOut = false; waveAmplitude = 0; waveResetBars(); waveHide();
    waveFetchAnalysis();
    let trackUri = ""; try { trackUri = Spicetify.Player.data?.item?.uri || ""; } catch (e) {}
    setTimeout(() => {
      if (!Spicetify.Player.isPlaying()) return;
      if (trackUri && !wavePlayedTracks.has(trackUri)) {
        if (wavePlayedTracks.size >= 200) wavePlayedTracks.clear();
        wavePlayedTracks.add(trackUri); waveFadeIn();
      } else { waveInstantStart(); }
      waveStartProgressPoll();
    }, 300);
  }

  // build bars + insert into playback-bar (idempotent on re-injection)
  function injectWaveAnimation() {
    waitForElement(".vg-playback-bar", (playbackBar) => {
      if (waveInjected && waveEl && waveEl.parentNode) {
        if (Spicetify.Player.isPlaying()) { waveInstantStart(); waveStartProgressPoll(); }
        return;
      }
      waveEl = document.createElement("div"); waveEl.className = "vg-wave-container";
      waveBars = [];
      for (let i = 0; i < WAVE_BARS; i++) {
        const bar = document.createElement("div"); bar.className = "vg-wave-bar";
        waveEl.appendChild(bar); waveBars.push(bar); waveBarShown[i] = -1; waveSetBar(i, WAVE_MIN_H);
      }
      playbackBar.insertBefore(waveEl, playbackBar.firstChild); waveInjected = true;
      let _isPlaying = false; try { _isPlaying = Spicetify.Player.isPlaying(); } catch(e) {}
      if (_isPlaying) { waveFetchAnalysis(); waveAmplitude = 1; waveShow(); waveStart(); waveStartProgressPoll(); }
      else { waveHide(); }
      if (!waveListenersRegistered) {
        Spicetify.Player.addEventListener("onplaypause", waveOnPlayPause);
        Spicetify.Player.addEventListener("songchange", waveOnSongChange);
        waveListenersRegistered = true;
      }
    });
  }

  // re-inject on route change (React unmounts playback-bar)
  function initWave() {
    injectWaveCSS();
    injectWaveAnimation();
    if (Spicetify.Platform && Spicetify.Platform.History) {
      Spicetify.Platform.History.listen(() => { setTimeout(() => { if (!waveEl || !waveEl.parentNode) { waveInjected = false; injectWaveAnimation(); } }, 500); });
    }
  }

  // EXPORTS (consumed by extensions via window.VantagraphCustomData)
  window.VantagraphCustomData = {
    COLOR_GROUPS,
    COLOR_KEYS,
    color: { parse: parseColor, format: formatColor, toHex, toRgb, toHsl, rgbToHsv, hsvToRgb },
    getColorState,
    getColorOverrides,
    setColor,
    resetColor,
    setColorOverrides,
    applyColors,
    flashColor,
    FONT_PRESETS,
    applyFont,
    applySetting,
    getSetting,
    waitForElement,
    applyDynamicClasses,
    startDynamicClassObserver
  };

  // INIT
  // Spicetify 2.45.x wrapper bug: its scroll optimizer (meant for Spotify <= 1.2.56)
  // guards with `minor >= 2 && patch >= 57`, which fails on 1.3.x since patch resets
  // to 0, so it runs getComputedStyle over every element on every DOM mutation.
  // That optimizer is the only caller of this exact selector; answer it with nothing.
  // Inert once upstream fixes the guard (the selector is never queried).
  // Opt out: Spicetify.LocalStorage.set("vantagraph-custom:wrapper-guard", "false")
  function installWrapperScrollGuard(attempts = 100) {
    if (getSetting("wrapper-guard", "true") === "false") return;
    // Platform.version lands a bit after Platform itself
    if (!Spicetify.Platform?.version) {
      if (attempts > 0) setTimeout(() => installWrapperScrollGuard(attempts - 1), 50);
      return;
    }
    const v = Spicetify.Platform.version.split(".").map(n => parseInt(n, 10));
    if (!(v[0] > 1 || (v[0] === 1 && v[1] >= 3))) return;
    const SCROLL_FIX_SELECTOR = "*:not([data-scroll-optimized])";
    const nativeQSA = Document.prototype.querySelectorAll;
    document.querySelectorAll = function (selector, ...rest) {
      if (selector === SCROLL_FIX_SELECTOR) return [];
      return nativeQSA.call(this, selector, ...rest);
    };
    // undo the layer promotion it already applied before theme.js ran
    nativeQSA.call(document, "[data-scroll-optimized]").forEach((el) => {
      el.style.willChange = "";
      el.style.transform = "";
    });
  }

  function init() {
    // 0. wrapper guard, then dynamic class mapping
    installWrapperScrollGuard();
    startDynamicClassObserver();

    // 1. colours: stored overrides on top of the VantagraphBlack defaults
    loadColorOverrides();
    applyColors();

    // 2. font (preset > custom > saved)
    const savedFont = Spicetify.LocalStorage.get("vantagraph-custom:font");
    const savedFontUrl = Spicetify.LocalStorage.get("vantagraph-custom:font-url");
    const savedCustomFont = Spicetify.LocalStorage.get("vantagraph-custom:custom-font");
    const savedCustomFontUrl = Spicetify.LocalStorage.get("vantagraph-custom:custom-font-url");

    if (savedFont && savedFont !== "null") {
      const preset = FONT_PRESETS.find(p => p.family === savedFont);
      if (preset && preset.url) {
        applyFont(preset.family, preset.url);
      } else if (savedFont === savedCustomFont) {
        applyFont(savedFont, savedCustomFontUrl || "");
      } else {
        applyFont(savedFont, savedFontUrl || "");
      }
    }

    // 3. settings
    const savedFontSize = getSetting("font-size", "");
    if (savedFontSize) applySetting("font-size", savedFontSize);
    const savedIconSize = getSetting("icon-size", "");
    if (savedIconSize) applySetting("icon-size", savedIconSize);
    const savedDensity = getSetting("density", "default");
    applySetting("density", savedDensity);
    const savedRadius = getSetting("border-radius", "");
    if (savedRadius) applySetting("border-radius", savedRadius);
    
    // album cover BG takes priority over custom URL; both apply vg-bg-active
    const savedBgUrl = getSetting("bg-url", "");
    const savedAlbumCover = getSetting("bg-use-album-cover", "false");
    if (savedAlbumCover === "true") {
      applySetting("bg-use-album-cover", "true");
    } else if (savedBgUrl) {
      applySetting("bg-url", savedBgUrl);
    }

    // 4. vinyl spin
    setupVinylSpin();

    // 5. next track card + wave
    initNextTrack();
    initWave();

    // 6. snippets: rounded-images & scrollbar default ON; rest default OFF
    const riState = getSetting("snippet-rounded-images", "true");
    if (riState === "false") applySetting("snippet-rounded-images", "false");
    const msState = getSetting("snippet-modern-scrollbar", "true");
    applySetting("snippet-modern-scrollbar", msState);
    const defaultOffSnippets = [
      "snippet-hide-ads-banner",
      "snippet-hide-friend-activity", "snippet-hide-whats-new", "snippet-hide-fullscreen",
      "snippet-hide-lyrics-btn", "snippet-hide-miniplayer", "snippet-hide-queue-btn",
      "snippet-hide-shuffle", "snippet-hide-repeat", "snippet-hide-connect",
      "snippet-hide-volume", "snippet-hide-np-widget", "snippet-hide-next-track", "snippet-hide-podcasts",
      "snippet-hide-promo-card", "snippet-hide-mood-recs",
      "snippet-hide-made-for-you", "snippet-hide-recents", "snippet-hide-top-mixes",
      "snippet-hide-jump-back", "snippet-hide-rec-stations", "snippet-hide-new-releases",
      "snippet-hide-best-artists", "snippet-hide-fav-artists", "snippet-hide-rec-today",
      "snippet-hide-home-shortcuts", "snippet-thin-library", "snippet-auto-hide-sidebar",
      "debug-labels", "snippet-dev-layout-grid", "snippet-dev-highlighter",
      "snippet-dev-spacing-viz", "snippet-dev-var-monitor", "snippet-dev-dom-logger",
      "snippet-vinyl-stop", "snippet-reduced-motion",
    ];
    defaultOffSnippets.forEach(s => {
      const state = getSetting(s, "false");
      if (state === "true") applySetting(s, "true");
    });

    // 7. album cover bg
    Spicetify.Player.addEventListener("songchange", onSongChangeBackground);
  }

  waitForSpicetify(init);
})();
