// Vantagraph Custom LoopyLoop - right-click progress bar to set loop start/end
//
// Based on the original Loopy Loop extension by khanhas.
// Original repository: https://github.com/spicetify/cli/tree/main/Extensions
// Thank you, khanhas, for the original concept and implementation.
//
// Vantagraph improvements: modernized selectors to use the VG class system,
// replaced the deprecated _HTMLContextMenuItem API with native createElement,
// and added Vantagraph theme-aware colors (--spice-accent, --spice-player, --spice-highlight).
// v2: per-song loop persistence (localStorage by track URI), proximity-based scroll-to-nudge.

(function LoopyLoop() {

  // 0. DOM lookup: progress bar inside player bar
  if (window.VantagraphCustomData?.applyDynamicClasses) {
    window.VantagraphCustomData.applyDynamicClasses();
  }
  const playbackBar = document.querySelector(".vg-playback-bar");
  const progressContainer = playbackBar?.querySelector(".vg-playback-progress");
  const rangeInput = progressContainer?.querySelector('input[type="range"]');
  const bar = rangeInput?.closest("label")?.nextElementSibling;
  if (!(bar && Spicetify.Player)) {
    setTimeout(LoopyLoop, 100);
    return;
  }

  // 1. theme-aware CSS
  const style = document.createElement("style");
  style.innerHTML = `
#loopy-loop-start, #loopy-loop-end {
  position: absolute;
  font-weight: bolder;
  font-size: 14px;
  top: -8px;
  color: var(--spice-accent);
  text-shadow: 0 0 6px var(--spice-accent);
  z-index: 20;
  pointer-events: none;
  transition: left 0.15s ease;
  user-select: none;
}
#loopy-context-menu {
  z-index: 9999;
}
#loopy-context-menu ul {
  background: var(--spice-player);
  border: 1px solid var(--spice-highlight);
  border-radius: 8px;
  padding: 4px 0;
  box-shadow: 0 8px 24px var(--spice-shadow);
  list-style: none;
  min-width: 140px;
}
#loopy-context-menu li {
  list-style: none;
}
#loopy-context-menu button {
  display: block;
  width: 100%;
  padding: 8px 14px;
  background: none;
  border: none;
  color: var(--spice-text);
  font-size: 13px;
  font-family: inherit;
  text-align: left;
  cursor: pointer;
  transition: background 0.15s ease;
}
#loopy-context-menu button:hover {
  background: var(--spice-highlight);
  color: var(--spice-accent);
}
`;

  // 2. markers
  const startMark = document.createElement("div");
  startMark.id = "loopy-loop-start";
  startMark.innerText = "[";
  const endMark = document.createElement("div");
  endMark.id = "loopy-loop-end";
  endMark.innerText = "]";
  startMark.hidden = endMark.hidden = true;

  bar.append(style, startMark, endMark);

  // 3. loop state
  let start = null;
  let end = null;
  let mouseOnBarPercent = 0.0;

  function getDurationSec() {
    return (Spicetify.Player.getDuration?.() ?? 0) / 1000;
  }

  function drawOnBar() {
    if (start === null && end === null) {
      startMark.hidden = endMark.hidden = true;
      return;
    }
    startMark.hidden = endMark.hidden = false;
    startMark.style.left = `${start * 100}%`;
    endMark.style.left   = `${end   * 100}%`;
  }

  // 5. persistence (per track URI)
  const LS_PREFIX = "loopy:";
  function currentUri() { return Spicetify.Player.data?.item?.uri ?? null; }

  function saveLoop() {
    const uri = currentUri();
    if (uri && start !== null && end !== null)
      Spicetify.LocalStorage.set(LS_PREFIX + uri, JSON.stringify({ start, end }));
  }
  function loadLoop(uri) {
    if (!uri) return;
    try {
      const raw = Spicetify.LocalStorage.get(LS_PREFIX + uri);
      if (!raw) { start = null; end = null; drawOnBar(); return; }
      const parsed = JSON.parse(raw);
      start = parsed.start;
      end   = parsed.end;
      drawOnBar();
    } catch (_) { start = null; end = null; drawOnBar(); }
  }
  function reset() {
    const uri = currentUri();
    if (uri) Spicetify.LocalStorage.remove(LS_PREFIX + uri);
    start = null; end = null;
    drawOnBar();
  }

  // 6. scroll-to-nudge: wheel anywhere on bar, nudges closest marker (±0.5s per tick)
  const NUDGE_STEP = 0.5;
  function nudge(which, dir) {
    const dur = getDurationSec();
    if (dur <= 0 || start === null || end === null) return;
    const delta  = (NUDGE_STEP / dur) * dir;
    const minGap =  NUDGE_STEP / dur;
    if (which === "start") {
      start = Math.max(0, Math.min(start + delta, end - minGap));
    } else {
      end = Math.min(1, Math.max(end + delta, start + minGap));
    }
    drawOnBar();
    saveLoop();
  }
  progressContainer.addEventListener("wheel", (e) => {
    if (start === null || end === null) return;
    e.preventDefault(); e.stopPropagation();
    const { x, width } = bar.getBoundingClientRect();
    const cursorPct = Math.max(0, Math.min(1, (e.clientX - x) / width));
    const which = Math.abs(cursorPct - start) <= Math.abs(cursorPct - end) ? "start" : "end";
    nudge(which, e.deltaY < 0 ? 1 : -1);
  }, { passive: false });

  // 7. progress seek-back (debounced)
  let debouncing = 0;
  Spicetify.Player.addEventListener("onprogress", (event) => {
    if (start != null && end != null) {
      if (debouncing) {
        if (event.timeStamp - debouncing > 1000) debouncing = 0;
        return;
      }
      const percent = Spicetify.Player.getProgressPercent();
      if (percent > end || percent < start) {
        debouncing = event.timeStamp;
        Spicetify.Player.seek(start);
      }
    }
  });

  Spicetify.Player.addEventListener("songchange", () => loadLoop(currentUri()));

  // 9. right-click context menu
  function createMenuItem(title, cb) {
    const li = document.createElement("li");
    li.setAttribute("role", "menuitem");
    const btn = document.createElement("button");
    btn.textContent = title;
    btn.onclick = () => { contextMenu.hidden = true; cb?.(); };
    li.append(btn);
    return li;
  }

  const startBtn = createMenuItem("Set start", () => {
    start = mouseOnBarPercent;
    if (end === null || start > end) end = 0.99;
    drawOnBar(); saveLoop();
  });
  const endBtn = createMenuItem("Set end", () => {
    end = mouseOnBarPercent;
    if (start === null || end < start) start = 0;
    drawOnBar(); saveLoop();
  });
  const resetBtn = createMenuItem("Reset", reset);

  const contextMenu = document.createElement("div");
  contextMenu.id = "loopy-context-menu";
  contextMenu.innerHTML = `<ul tabindex="0"></ul>`;
  contextMenu.style.position = "absolute";
  contextMenu.firstElementChild.append(startBtn, endBtn, resetBtn);
  document.body.append(contextMenu);
  const { height: contextMenuHeight } = contextMenu.getBoundingClientRect();
  contextMenu.hidden = true;

  window.addEventListener("click", () => { contextMenu.hidden = true; });

  progressContainer.oncontextmenu = (event) => {
    const { x, width } = bar.getBoundingClientRect();
    mouseOnBarPercent = Math.max(0, Math.min(1, (event.clientX - x) / width));
    contextMenu.style.transform = `translate(${event.clientX}px,${event.clientY - contextMenuHeight}px)`;
    contextMenu.hidden = false;
    event.preventDefault();
  };

  // 10. restore loop for currently playing song on load
  loadLoop(currentUri());

})();
