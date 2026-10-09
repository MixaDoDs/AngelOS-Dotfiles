// Vantagraph Custom Volume+ - scroll wheel + middle-click mute + preset overlay + wide bar + tooltip
//
// Inspired by the original Volume+ extension by Aspecky.
// Original repository: https://github.com/Aspecky/spicetify-extensions/tree/main/volume-plus
// Thank you, Aspecky, for the original scroll wheel and tooltip concept.
//
// Vantagraph improvements: fully rewritten from scratch with middle-click mute, quick-preset overlay,
// enforced 250px bar width, Tippy fallback label, Vantagraph icon integration, and modern data-testid selectors.
// v2: startup volume restore, active preset gold-glow indicator, double-click preferred volume restore,
// first-run middle-click hint, mute visual state, all-public API (no _events / _volume private access).

(async function VantagraphVolumePlus() {

  // 0. wait for Spicetify APIs including public Player.getVolume
  while (!Spicetify?.React || !Spicetify?.ReactDOM || !Spicetify?.Platform || !Spicetify?.Player?.getVolume) {
    await new Promise(r => setTimeout(r, 100));
  }

  const { Platform, PopupModal, LocalStorage } = Spicetify;
  const playerAPI = Platform.PlaybackAPI;

  if (!playerAPI) {
    setTimeout(VantagraphVolumePlus, 250);
    return;
  }

  // --- Public API wrappers (no private _ access) ---
  function getVol()        { return Spicetify.Player.getVolume(); }
  function setVol(v)       { Spicetify.Player.setVolume(Math.max(0, Math.min(1, Math.round(v * 1000) / 1000))); }
  function getMuted()      { return Spicetify.Player.getMute(); }
  function setMuted(state) { Spicetify.Player.setMute(state); }

  // --- Settings (localStorage) ---
  const SK = "vg-volume-plus";
  function getSetting(key, def) {
    try {
      const raw = LocalStorage.get(SK + "." + key);
      if (raw) return JSON.parse(raw).value;
    } catch (e) {}
    return def;
  }
  function setSetting(key, val) {
    LocalStorage.set(SK + "." + key, JSON.stringify({ value: val }));
  }

  if (!getSetting("default-increment")) setSetting("default-increment", "1");
  if (!getSetting("shift-increment"))   setSetting("shift-increment",   "10");
  if (!getSetting("ctrl-increment"))    setSetting("ctrl-increment",    "0.5");
  if (!getSetting("startup-restore"))   setSetting("startup-restore",   "true");

  // Preferred volume (double-click restore) - set by user in settings modal
  function getPreferredVol() { return parseFloat(getSetting("preferred-vol", "100")); }
  function setPreferredVol(pct) { setSetting("preferred-vol", String(Math.round(pct))); }

  // 1. inject CSS
  if (!document.getElementById("vg-volume-plus-css")) {
    const s = document.createElement("style");
    s.id = "vg-volume-plus-css";
    s.textContent = `
      .vg-vol-preset-trigger { background:none; border:none; color:var(--vg-icon, var(--spice-subtext)); cursor:pointer; padding:4px; margin-left:2px; display:flex; align-items:center; justify-content:center; border-radius:50%; transition:color .15s; }
      .vg-vol-preset-trigger:hover { color:var(--spice-text); }
      .vg-vol-preset-trigger svg { width:16px; height:16px; fill:currentColor; }
      .vg-vol-preset-overlay { position:fixed; top:50%; left:50%; transform:translate(-50%,-50%); background:var(--spice-player); border:1px solid var(--spice-highlight); border-radius:14px; padding:16px 20px; z-index:10000; display:none; flex-direction:column; align-items:center; gap:12px; box-shadow:0 16px 48px color-mix(in srgb, var(--spice-shadow) 50%, transparent);    }
      .vg-vol-preset-overlay .vg-vol-preset-title { font-size:11px; font-weight:600; color:var(--spice-subtext); text-transform:uppercase; letter-spacing:1px; }
      .vg-vol-preset-overlay .vg-vol-preset-row { display:flex; gap:6px; }
      .vg-vol-preset-overlay.vg-visible { display:flex; }
      .vg-vol-preset-btn { background:var(--spice-tab-active); border:1px solid var(--spice-highlight); border-radius:8px; color:var(--spice-text); padding:8px 14px; font-size:13px; font-weight:600; font-family:inherit; cursor:pointer; transition:background .15s,color .15s,box-shadow .15s; min-width:44px; text-align:center; }
      .vg-vol-preset-btn:hover { background:var(--spice-accent); color:var(--spice-player); }
      .vg-vol-preset-btn.vg-preset-active { box-shadow:0 0 0 2px var(--spice-accent), 0 0 10px 3px color-mix(in srgb, var(--spice-accent) 40%, transparent); }
      .vg-vol-preset-hint { font-size:10px; color:var(--spice-subtext); text-align:center; opacity:0.75; }
      [data-vg-muted="true"] .volume-bar__slider-container { opacity:0.45; filter:grayscale(65%); transition:opacity .2s,filter .2s; }
    `;
    document.head.appendChild(s);
  }

  // 2. waitForEl helper
  function waitForEl(selector, parent) {
    parent = parent || document.body;
    return new Promise(resolve => {
      const el = parent.querySelector(selector);
      if (el) return resolve(el);
      const obs = new MutationObserver(() => {
        const found = parent.querySelector(selector);
        if (found) { obs.disconnect(); resolve(found); }
      });
      obs.observe(parent, { childList: true, subtree: true });
    });
  }

  // 3. locate volume bar via native testids
  const volumeBar = await waitForEl("[data-testid='volume-bar']");
  const sliderContainer = await waitForEl(".volume-bar__slider-container", volumeBar);

  // 4. enforce 250px width
  function enforceBarWidth() {
    volumeBar.style.setProperty("width", "250px", "important");
    volumeBar.style.setProperty("min-width", "250px", "important");
    volumeBar.style.setProperty("transition", "none", "important");
    sliderContainer.style.setProperty("width", "100%", "important");
    sliderContainer.style.setProperty("transition", "none", "important");
  }
  enforceBarWidth();
  const barObserver = new MutationObserver(enforceBarWidth);
  barObserver.observe(volumeBar,       { attributes: true, attributeFilter: ["style"] });
  barObserver.observe(sliderContainer, { attributes: true, attributeFilter: ["style"] });

  // 5. Tippy tooltip: editable % input
  const input = document.createElement("input");
  input.id   = "vg-volume-plus-input";
  input.type = "text";
  input.maxLength = 3;

  input.addEventListener("change", () => { setVol(Number(input.value) / 100); });
  input.addEventListener("keydown", (e) => {
    if (e.key.length === 1 && isNaN(Number(e.key))) e.preventDefault();
  });
  input.addEventListener("input", resizeInput);

  let presetBtns = [];

  function updateDisplay() {
    const vol   = getVol();
    const muted = getMuted();
    input.value = "" + Math.round(vol * 100);
    resizeInput();
    const pctLabel = document.getElementById("vg-vol-pct-label");
    if (pctLabel) pctLabel.textContent = input.value + "%";
    volumeBar.dataset.vgMuted = muted ? "true" : "false";
    refreshPresetGlow(vol);
  }

  function resizeInput() {
    input.style.maxWidth = input.value.length + "ch";
  }

  updateDisplay();

  // 6. volume polling: replaces private playerAPI._events.addListener("volume", ...)
  let lastVol  = getVol();
  let lastMute = getMuted();
  setInterval(() => {
    const v = getVol();
    const m = getMuted();
    if (v !== lastVol || m !== lastMute) {
      lastVol = v; lastMute = m;
      updateDisplay();
    }
  }, 200);

  // 7. Tippy tooltip
  let tooltipReady = false;
  try {
    if (Spicetify.Tippy && Spicetify.TippyProps) {
      const tippy = Spicetify.Tippy(sliderContainer, {
        ...Spicetify.TippyProps,
        delay: 0,
        interactive: true,
        hideOnClick: false,
        interactiveBorder: 20,
      });

      const styleEl = document.createElement("style");
      styleEl.id = "vg-volume-plus-style";
      styleEl.textContent = `
        #vg-volume-plus-input {
          background:none; padding:0; border:0; text-align:center;
          font-size:1em; min-width:1ch; max-width:3ch;
          color:var(--spice-text); font-family:inherit; font-weight:600;
        }
        #vg-volume-plus-input::-webkit-outer-spin-button,
        #vg-volume-plus-input::-webkit-inner-spin-button { -webkit-appearance:none; margin:0; }
      `;
      document.head.appendChild(styleEl);

      let tippyContent = tippy.popper.querySelector(".main-contextMenu-tippy")
                       || tippy.popper.querySelector(".tippy-content");
      if (!tippyContent) tippyContent = await waitForEl(".tippy-content", tippy.popper);

      const tippyBox = tippy.popper.querySelector(".tippy-box");
      if (tippyBox) {
        tippyBox.style.cssText = "background:var(--spice-player)!important;border:1px solid var(--spice-highlight)!important;border-radius:8px!important;color:var(--spice-text)!important;";
      }
      tippyContent.style.cssText = "display:flex;align-items:center;gap:0;background:var(--spice-player)!important;color:var(--spice-text)!important;";
      const tippyArrow = tippy.popper.querySelector(".tippy-arrow");
      if (tippyArrow) tippyArrow.style.setProperty("color", "var(--spice-player)", "important");

      tippyContent.appendChild(input);
      const pctSign = document.createElement("span");
      pctSign.style.cssText = "color:var(--spice-subtext);font-size:0.9em;";
      pctSign.textContent = "%";
      tippyContent.appendChild(pctSign);

      tooltipReady = true;
    }
  } catch (err) {}

  // fallback: inline % label
  if (!tooltipReady) {
    const pctLabel = document.createElement("span");
    pctLabel.id = "vg-vol-pct-label";
    pctLabel.textContent = Math.round(getVol() * 100) + "%";
    pctLabel.style.cssText = "color:var(--spice-subtext);font-size:12px;font-weight:600;min-width:32px;text-align:center;margin-left:4px;font-family:inherit;";
    if (volumeBar.parentNode) volumeBar.parentNode.insertBefore(pctLabel, volumeBar.nextSibling);
  }

  // 8. scroll wheel: throttled, modifier-aware
  let throttleTimer = null;
  function adjustVolume(delta) {
    if (getMuted()) setMuted(false);
    setVol(getVol() + delta);
  }

  volumeBar.addEventListener("wheel", (e) => {
    e.stopPropagation(); e.preventDefault();
    if (throttleTimer) return;
    throttleTimer = setTimeout(() => { throttleTimer = null; }, 30);
    let key;
    if (e.getModifierState("Shift"))   key = "shift-increment";
    else if (e.getModifierState("Control")) key = "ctrl-increment";
    else key = "default-increment";
    adjustVolume(-Math.sign(e.deltaY) * Number(getSetting(key, "1")) / 100);
  }, { passive: false });

  // 9. arrow keys when hovering bar
  document.addEventListener("keydown", (e) => {
    if (!volumeBar.matches(":hover")) return;
    if (!["ArrowLeft","ArrowRight","ArrowUp","ArrowDown"].includes(e.key)) return;
    e.stopPropagation(); e.preventDefault();
    let delta;
    if (e.key === "ArrowLeft" || e.key === "ArrowRight") {
      delta = Number(getSetting("default-increment", "1")) * (e.key === "ArrowRight" ? 1 : -1);
    } else {
      delta = Number(getSetting("shift-increment", "10")) * (e.key === "ArrowUp" ? 1 : -1);
    }
    adjustVolume(delta / 100);
  });

  // 10. middle-click mute (public toggleMute API)
  volumeBar.addEventListener("mousedown", (e) => {
    if (e.button !== 1) return;
    e.preventDefault(); e.stopPropagation();
    Spicetify.Player.toggleMute();
  });
  volumeBar.addEventListener("auxclick", (e) => {
    if (e.button === 1) { e.preventDefault(); e.stopPropagation(); }
  });

  // 11. double-click bar = restore preferred volume
  let lastClick = 0;
  volumeBar.addEventListener("click", (e) => {
    const now = Date.now();
    if (now - lastClick < 300) {
      e.stopPropagation();
      setVol(getPreferredVol() / 100);
      if (getMuted()) setMuted(false);
    }
    lastClick = now;
  });

  // 12. preset overlay with gold-glow active indicator
  const PRESETS = [0, 20, 40, 50, 60, 80, 100];
  let presetOverlay  = null;
  let presetTimeout  = null;

  function refreshPresetGlow(vol) {
    if (!presetBtns.length) return;
    const pct = Math.round(vol * 100);
    presetBtns.forEach(btn => {
      btn.classList.toggle("vg-preset-active", Math.abs(pct - parseInt(btn.dataset.preset, 10)) <= 2);
    });
  }

  // own button icon, embedded so it needs no icon extension
  // (source: src/assets/icons/bottombar-percentage.svg)
  const PRESET_ICON = '<svg viewBox="0 0 32.02 32" fill="currentColor" aria-hidden="true"><path d="M31.51,29.85c0,.98-.67,1.65-1.6,1.65H2.11c-.93,0-1.6-.68-1.6-1.59v-15.48c0-.89.71-1.52,1.6-1.52h27.79c.89,0,1.6.63,1.6,1.52v15.43ZM17.56,26.86l.02-3.09,3.21-.04c.9-.01,1.49-.85,1.42-1.67s-.77-1.42-1.67-1.42h-2.95s-.03-3.16-.03-3.16c0-.89-.78-1.51-1.59-1.48s-1.49.7-1.5,1.59l-.02,3.05-3.19.03c-.88,0-1.48.82-1.44,1.61.05.82.69,1.47,1.55,1.47l3.08.02.02,3.09c0,.9.75,1.56,1.59,1.54s1.5-.67,1.5-1.54Z"/><path d="M26.93,9.79H5.16c-.88.01-1.49-.69-1.54-1.45s.51-1.61,1.42-1.62l21.7-.02c.92,0,1.6.56,1.66,1.46.05.7-.48,1.63-1.47,1.63Z"/><path d="M23.76,3.59h-15.55c-.9,0-1.5-.79-1.49-1.56,0-.85.67-1.54,1.61-1.54h15.36c.9,0,1.55.63,1.61,1.42s-.53,1.67-1.54,1.67Z"/></svg>';
  const presetBtn = document.createElement("button");
  presetBtn.className = "vg-vol-preset-trigger";
  presetBtn.title = "Volume Presets";
  presetBtn.innerHTML = PRESET_ICON;
  if (volumeBar.parentNode) volumeBar.parentNode.insertBefore(presetBtn, volumeBar.nextSibling);

  function createPresetOverlay() {
    if (presetOverlay) return;
    presetOverlay = document.createElement("div");
    presetOverlay.className = "vg-vol-preset-overlay";
    const title = document.createElement("div");
    title.className = "vg-vol-preset-title";
    title.textContent = "Quick Volume";
    presetOverlay.appendChild(title);
    const hintTop = document.createElement("div");
    hintTop.className = "vg-vol-preset-hint";
    hintTop.textContent = "Double-click bar → restore preferred (" + getPreferredVol() + "%)";
    presetOverlay.appendChild(hintTop);
    const row = document.createElement("div");
    row.className = "vg-vol-preset-row";
    PRESETS.forEach(pct => {
      const btn = document.createElement("button");
      btn.className = "vg-vol-preset-btn";
      btn.textContent = pct + "%";
      btn.dataset.preset = String(pct);
      btn.addEventListener("click", (e) => { e.stopPropagation(); setVol(pct / 100); hidePresets(); });
      row.appendChild(btn);
      presetBtns.push(btn);
    });
    presetOverlay.appendChild(row);
    const hintBot = document.createElement("div");
    hintBot.className = "vg-vol-preset-hint";
    hintBot.textContent = "Middle-click bar → mute / unmute";
    presetOverlay.appendChild(hintBot);
    document.body.appendChild(presetOverlay);
  }

  function showPresets() {
    createPresetOverlay();
    refreshPresetGlow(getVol());
    // no fade: shown instantly, hidden with display:none (see vantagraph-custom-settings.js)
    presetOverlay.classList.add("vg-visible");
    if (presetTimeout) clearTimeout(presetTimeout);
    presetTimeout = setTimeout(hidePresets, 4000);
  }
  function hidePresets() {
    if (presetOverlay) presetOverlay.classList.remove("vg-visible");
    if (presetTimeout) { clearTimeout(presetTimeout); presetTimeout = null; }
  }

  presetBtn.addEventListener("click", (e) => {
    e.stopPropagation();
    if (presetOverlay && presetOverlay.classList.contains("vg-visible")) hidePresets();
    else showPresets();
  });
  document.addEventListener("click", (e) => {
    if (presetOverlay && !presetOverlay.contains(e.target) && e.target !== presetBtn) hidePresets();
  });
  document.addEventListener("keydown", (e) => { if (e.key === "Escape") hidePresets(); });

  // 13. startup volume restore (Spotify or Connect may reset volume on start)
  const SAVED_VOL_KEY = "vg-volume-plus.saved-vol";
  const savedStartVol = LocalStorage.get(SAVED_VOL_KEY);
  if (savedStartVol && getSetting("startup-restore", "true") === "true") {
    const saved = parseFloat(savedStartVol);
    if (!isNaN(saved)) {
      setTimeout(() => {
        if (Math.abs(getVol() - saved) > 0.02) setVol(saved);
      }, 2000);
    }
  }
  setInterval(() => {
    const v = getVol();
    if (v > 0) LocalStorage.set(SAVED_VOL_KEY, String(v));
  }, 5000);

  // 14. first-run middle-click hint (shows once, stored in LocalStorage)
  if (!LocalStorage.get("vg-volume-plus.hint-shown")) {
    LocalStorage.set("vg-volume-plus.hint-shown", "1");
    setTimeout(() => {
      Spicetify.showNotification("Volume+: Middle-click the volume bar to mute / unmute");
    }, 4000);
  }

  // 15. settings menu (increment config + preferred volume)
  if (Spicetify.Menu) {
    new Spicetify.Menu.Item("Volume+", false, () => {
      const content = document.createElement("div");
      const currentPref = getPreferredVol();
      content.innerHTML = `
        <div style="display:grid;gap:16px;padding:8px 0;">
          <div style="display:grid;gap:6px;">
            <label style="color:var(--spice-subtext);font-size:12px;">Preferred volume - double-click bar to restore</label>
            <div id="vg-vp-preferred-row" style="display:flex;gap:6px;flex-wrap:wrap;"></div>
          </div>
          <div style="display:flex;align-items:center;gap:10px;">
            <input type="checkbox" id="vg-vp-startup-restore" style="accent-color:var(--spice-accent);width:16px;height:16px;cursor:pointer;">
            <label for="vg-vp-startup-restore" style="color:var(--spice-text);font-size:13px;cursor:pointer;">Restore volume on Spotify launch</label>
          </div>
          <div style="display:grid;gap:6px;">
            <label style="color:var(--spice-subtext);font-size:12px;">Default scroll increment (%)</label>
            <input type="number" min="0.5" max="100" step="0.5"
              id="vg-vp-default" style="background:var(--spice-tab-active);border:1px solid var(--spice-highlight);border-radius:6px;color:var(--spice-text);padding:8px 12px;font-size:14px;width:100%;font-family:inherit;">
          </div>
          <div style="display:grid;gap:6px;">
            <label style="color:var(--spice-subtext);font-size:12px;">Shift + scroll increment (%)</label>
            <input type="number" min="0.5" max="100" step="0.5"
              id="vg-vp-shift" style="background:var(--spice-tab-active);border:1px solid var(--spice-highlight);border-radius:6px;color:var(--spice-text);padding:8px 12px;font-size:14px;width:100%;font-family:inherit;">
          </div>
          <div style="display:grid;gap:6px;">
            <label style="color:var(--spice-subtext);font-size:12px;">Ctrl + scroll increment (%) - fine control</label>
            <input type="number" min="0.1" max="10" step="0.1"
              id="vg-vp-ctrl" style="background:var(--spice-tab-active);border:1px solid var(--spice-highlight);border-radius:6px;color:var(--spice-text);padding:8px 12px;font-size:14px;width:100%;font-family:inherit;">
          </div>
        </div>
      `;
      // stored values go in as DOM properties, never through the HTML parser
      // (CodeQL js/xss-through-dom #1: they used to be interpolated into value="")
      content.querySelector("#vg-vp-startup-restore").checked = getSetting("startup-restore", "true") === "true";
      content.querySelector("#vg-vp-default").value = getSetting("default-increment", "1");
      content.querySelector("#vg-vp-shift").value = getSetting("shift-increment", "10");
      content.querySelector("#vg-vp-ctrl").value = getSetting("ctrl-increment", "0.5");

      const prefRow = content.querySelector("#vg-vp-preferred-row");
      [0, 20, 40, 50, 60, 80, 100].forEach(pct => {
        const btn = document.createElement("button");
        btn.className = "vg-vol-preset-btn";
        btn.textContent = pct + "%";
        if (pct === currentPref) btn.classList.add("vg-preset-active");
        btn.addEventListener("click", () => {
          setPreferredVol(pct);
          prefRow.querySelectorAll(".vg-vol-preset-btn").forEach(b => b.classList.remove("vg-preset-active"));
          btn.classList.add("vg-preset-active");
        });
        prefRow.appendChild(btn);
      });
      content.querySelector("#vg-vp-startup-restore").addEventListener("change", function() {
        setSetting("startup-restore", this.checked ? "true" : "false");
      });
      content.querySelector("#vg-vp-default").addEventListener("change", function() { setSetting("default-increment", this.value); });
      content.querySelector("#vg-vp-shift").addEventListener("change",   function() { setSetting("shift-increment",   this.value); });
      content.querySelector("#vg-vp-ctrl").addEventListener("change",    function() { setSetting("ctrl-increment",    this.value); });
      PopupModal.display({ title: "Volume+", content: content, isLarge: false });
    }, `<svg viewBox="0 0 16 16" fill="currentColor"><path d="M14.9,8c0-0.4-0.3-0.8-0.7-0.8h-2.1V5.2c0-0.4-0.4-0.7-0.8-0.7c-0.4,0-0.7,0.3-0.7,0.7v2.1H8.5C8.1,7.2,7.7,7.6,7.7,8c0,0.4,0.3,0.8,0.8,0.8h2.1v2.1c0,0.4,0.4,0.7,0.8,0.7c0.4,0,0.7-0.3,0.7-0.7V8.8h2.1C14.6,8.8,14.9,8.4,14.9,8z"/><path d="M10.1,1.5c0-0.4-0.3-0.8-0.7-0.8c-0.1,0-0.3,0-0.4,0.1l-6.9,4c-1.7,1-2.3,3.2-1.3,5c0.3,0.6,0.8,1,1.3,1.3l6.9,4c0.4,0.2,0.8,0.1,1-0.3c0.1-0.1,0.1-0.2,0.1-0.4v-1.9c-0.5-0.1-1-0.4-1.5-0.7v1.3L2.8,9.9C1.8,9.3,1.4,8,2,6.9c0.2-0.3,0.5-0.6,0.8-0.8l5.8-3.3v1.3c0.4-0.3,1-0.5,1.5-0.7V1.5z"/></svg>`).register();
  }

})();
