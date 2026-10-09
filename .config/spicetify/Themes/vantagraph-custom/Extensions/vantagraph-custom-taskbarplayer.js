// Vantagraph Custom Taskbar Player
// Borderless always-on-top floating bar via documentPictureInPicture.
// Bulletproof against Spotify's SPA navigation wipes:
//   - MutationObserver on PiP <html> rebuilds head+body when wiped
//   - rAF sentinel check as backup (per-frame)
//   - All rAF/timer logic runs in MAIN document context, so PiP doc death
//     never kills our update loop.

(async function VantagraphTaskbarPlayer() {
  while (!Spicetify?.Player?.data || !Spicetify?.Platform || !Spicetify?.CosmosAsync || !Spicetify?.Topbar) {
    await new Promise(r => setTimeout(r, 100));
  }

  // ── STATE ──────────────────────────────────────────────────────────────────
  const ls  = k => localStorage.getItem('vg-tbp-' + k);
  const lss = (k, v) => localStorage.setItem('vg-tbp-' + k, v);

  let pipWin        = null;
  let currentLyrics = null;
  let currentUri    = null;
  let rafId         = null;
  let rebuildPending = false;
  const LYRIC_LEAD  = 150;
  const BAR_W       = Math.min((window.screen?.availWidth || 1200) - 80, 1040);
  const BAR_W_NOLYRIC = 660;
  const BAR_H       = 110;
  let _seeking      = false;
  let _lastResizeWidth = null;

  // ── ICONS: standard SVG paths (this theme ships no custom icon set) ──────
  function icon(_file, svgPath, size = 16) {
    return `<svg viewBox="0 0 16 16" width="${size}" height="${size}" fill="currentColor" style="flex-shrink:0;">${svgPath}</svg>`;
  }

  const P = {
    prev:      '<path d="M3.3 1a.7.7 0 0 1 .7.7v5.15l9.95-5.744a.7.7 0 0 1 1.05.606v12.575a.7.7 0 0 1-1.05.607L4 9.149V14.3a.7.7 0 0 1-.7.7H1.7a.7.7 0 0 1-.7-.7V1.7a.7.7 0 0 1 .7-.7h1.6z"/>',
    play:      '<path d="M3 1.713a.7.7 0 0 1 1.05-.607l10.89 6.288a.7.7 0 0 1 0 1.212L4.05 14.894A.7.7 0 0 1 3 14.288V1.713z"/>',
    pause:     '<path d="M2.7 1a.7.7 0 0 0-.7.7v12.6a.7.7 0 0 0 .7.7h2.6a.7.7 0 0 0 .7-.7V1.7a.7.7 0 0 0-.7-.7H2.7zm8 0a.7.7 0 0 0-.7.7v12.6a.7.7 0 0 0 .7.7h2.6a.7.7 0 0 0 .7-.7V1.7a.7.7 0 0 0-.7-.7h-2.6z"/>',
    next:      '<path d="M12.7 1a.7.7 0 0 0-.7.7v5.15L2.05 1.107A.7.7 0 0 0 1 1.712v12.575a.7.7 0 0 0 1.05.607L12 9.149V14.3a.7.7 0 0 0 .7.7h1.6a.7.7 0 0 0 .7-.7V1.7a.7.7 0 0 0-.7-.7h-1.6z"/>',
    shuffle:   '<path d="M13.151.922a.75.75 0 1 0-1.06 1.06L13.109 3H11.16a3.75 3.75 0 0 0-2.873 1.34l-6.173 7.356A2.25 2.25 0 0 1 .39 12.5H0V14h.391a3.75 3.75 0 0 0 2.873-1.34l6.173-7.356a2.25 2.25 0 0 1 1.724-.804h1.947l-1.017 1.018a.75.75 0 0 0 1.06 1.06l2.306-2.306a.75.75 0 0 0 0-1.06L13.15.922zM.391 3.5H0V2h.391c1.109 0 2.16.49 2.873 1.34L4.89 5.277l-.979 1.167-1.796-2.14A2.25 2.25 0 0 0 .39 3.5z"/><path d="m7.5 10.723.98-1.167 1.796 2.14a2.25 2.25 0 0 0 1.724.804h1.947l-1.017-1.018a.75.75 0 1 1 1.06-1.06l2.306 2.306a.75.75 0 0 1 0 1.06l-2.306 2.306a.75.75 0 1 1-1.06-1.06L14.109 14H12.16a3.75 3.75 0 0 1-2.873-1.34l-1.787-2.14z"/>',
    repeat:    '<path d="M0 4.75A3.75 3.75 0 0 1 3.75 1h8.5A3.75 3.75 0 0 1 16 4.75v5a3.75 3.75 0 0 1-3.75 3.75H9.81l1.018 1.018a.75.75 0 1 1-1.06 1.06L6.939 12.75l2.829-2.829a.75.75 0 1 1 1.06 1.061L9.811 12h2.439a2.25 2.25 0 0 0 2.25-2.25v-5a2.25 2.25 0 0 0-2.25-2.25h-8.5A2.25 2.25 0 0 0 2.25 4.75v5A2.25 2.25 0 0 0 4.5 12v1.5A3.75 3.75 0 0 1 0 9.75v-5z"/>',
    repeatOne: '<path d="M0 4.75A3.75 3.75 0 0 1 3.75 1h.75v1.5h-.75A2.25 2.25 0 0 0 1.5 4.75v5A2.25 2.25 0 0 0 3.75 12H4.5v1.5h-.75A3.75 3.75 0 0 1 0 9.75v-5zM12.25 2.5h-.75V1h.75A3.75 3.75 0 0 1 16 4.75v5a3.75 3.75 0 0 1-3.75 3.75H9.81l1.018 1.018a.75.75 0 1 1-1.06 1.06L6.939 12.75l2.829-2.829a.75.75 0 1 1 1.06 1.061L9.811 12h2.439a2.25 2.25 0 0 0 2.25-2.25v-5a2.25 2.25 0 0 0-2.25-2.25z"/><path d="M9.12 8V1H7.787c-.128.72-.76 1.293-1.787 1.313V3.36h1.57V8h1.55z"/>',
    expand:    '<path d="M6 2H2v4h1.5V4.56l3.2 3.2 1.06-1.06-3.2-3.2H6V2zm4 12h4v-4h-1.5v2.44l-3.2-3.2-1.06 1.06 3.2 3.2H10V14z"/>',
    close:     '<path d="M2.47 2.47a.75.75 0 0 1 1.06 0L8 6.94l4.47-4.47a.75.75 0 1 1 1.06 1.06L9.06 8l4.47 4.47a.75.75 0 1 1-1.06 1.06L8 9.06l-4.47 4.47a.75.75 0 0 1-1.06-1.06L6.94 8 2.47 3.53a.75.75 0 0 1 0-1.06z"/>',
    heartOut:  '<path d="M1.69 2A4.582 4.582 0 0 1 8 2.023 4.583 4.583 0 0 1 11.88.817h.002a4.618 4.618 0 0 1 3.782 3.65v.003a4.543 4.543 0 0 1-1.011 3.84L9.35 14.629a1.765 1.765 0 0 1-2.093.464 1.762 1.762 0 0 1-.605-.463L1.348 8.309A4.582 4.582 0 0 1 1.689 2zm3.158.252A3.082 3.082 0 0 0 2.49 7.337l.005.005L7.8 13.664a.264.264 0 0 0 .311.069.262.262 0 0 0 .09-.069l5.312-6.33a3.043 3.043 0 0 0 .68-2.573 3.118 3.118 0 0 0-2.551-2.463 3.079 3.079 0 0 0-2.612.816l-.007.007a1.501 1.501 0 0 1-2.045 0l-.009-.008a3.082 3.082 0 0 0-2.121-.861z"/>',
    heartFill: '<path d="M15.724 4.22A4.313 4.313 0 0 0 12.192.814a4.269 4.269 0 0 0-3.622 1.13.837.837 0 0 1-1.14 0 4.272 4.272 0 0 0-6.21 5.855l5.916 7.05a1.128 1.128 0 0 0 1.727 0l5.916-7.05a4.228 4.228 0 0 0 .945-3.577z"/>',
    volHigh:   '<path d="M9.741.85a.75.75 0 0 1 .375.65v13a.75.75 0 0 1-1.125.65l-6.925-4a3.642 3.642 0 0 1-1.33-4.967 3.639 3.639 0 0 1 1.33-1.332l6.925-4a.75.75 0 0 1 .75 0zm-6.924 5.3a2.139 2.139 0 0 0 0 3.7l5.8 3.35V2.8l-5.8 3.35zm8.683 6.087a4.502 4.502 0 0 0 0-8.474v1.65a2.999 2.999 0 0 1 0 5.175v1.649z"/>',
    volLow:    '<path d="M9.741.85a.75.75 0 0 1 .375.65v13a.75.75 0 0 1-1.125.65l-6.925-4a3.642 3.642 0 0 1-1.33-4.967 3.639 3.639 0 0 1 1.33-1.332l6.925-4a.75.75 0 0 1 .75 0zm-6.924 5.3a2.139 2.139 0 0 0 0 3.7l5.8 3.35V2.8l-5.8 3.35zm8.683 4.29V5.56a2.75 2.75 0 0 1 0 4.88z"/>',
    volOff:    '<path d="M13.86 5.47a.75.75 0 0 0-1.061 0l-1.47 1.47-1.47-1.47A.75.75 0 0 0 8.8 6.53L10.269 8l-1.47 1.47a.75.75 0 1 0 1.06 1.06l1.47-1.47 1.47 1.47a.75.75 0 0 0 1.06-1.06L12.39 8l1.47-1.47a.75.75 0 0 0 0-1.06z"/><path d="M10.116 1.5A.75.75 0 0 0 8.991.85l-6.925 4a3.642 3.642 0 0 0-1.33 4.967 3.639 3.639 0 0 0 1.33 1.332l6.925 4a.75.75 0 0 0 1.125-.649v-1.906a4.73 4.73 0 0 1-1.5-.694v1.3L2.817 9.852a2.141 2.141 0 0 1-.781-2.92c.187-.324.456-.594.78-.782l5.8-3.35v1.3c.45-.313.956-.55 1.5-.694V1.5z"/>',
  };

  function volIcon(vol, muted) {
    if (muted || vol < 1) return icon('bottombar-VolumeOff.svg', P.volOff, 13);
    return icon('bottombar-VolumeOn.svg', vol < 50 ? P.volLow : P.volHigh, 13);
  }

  // ── THEME COLORS ──────────────────────────────────────────────────────────
  // Extract --spice-* values from MAIN doc so they survive PiP doc wipes.
  function getColors() {
    const cs = getComputedStyle(document.documentElement);
    const g  = (v, fb) => cs.getPropertyValue(v).trim() || fb;
    return {
      player:    g('--spice-player',        '#1a1917'),
      text:      g('--spice-text',          '#f9f7f7'),
      subtext:   g('--spice-subtext',       '#7b7e83'),
      accent:    g('--spice-accent',        '#3f72af'),
      btnActive: g('--spice-button-active', g('--spice-btn-active', '#dbe2ef')),
      stroke:    g('--spice-stroke',        'rgba(255,255,255,.12)'),
    };
  }

  function colorVarsCss() {
    const c = getColors();
    return `:root{--c-player:${c.player};--c-text:${c.text};--c-subtext:${c.subtext};--c-accent:${c.accent};--c-btn:${c.btnActive};--c-stroke:${c.stroke};}`;
  }

  // ── STATIC CSS (structural, color-independent via --c-* vars) ─────────────
  // !important on layout-critical props beats Spotify's pip-mini-player injection
  const STATIC_CSS = `
    *,*::before,*::after { margin:0!important; padding:0!important; box-sizing:border-box!important; }
    html,body { height:100%!important; overflow:hidden!important; width:100%!important; }
    body {
      display:flex!important;
      flex-direction:column!important;
      background:var(--c-player)!important;
      color:var(--c-text);
      font-family:-apple-system,'Segoe UI',sans-serif;
      user-select:none; cursor:grab;
      -webkit-app-region:drag; app-region:drag;
    }
    body:active { cursor:grabbing; }
    button,input,.tp-art { -webkit-app-region:no-drag; app-region:no-drag; }
    /* ── Seek row ── */
    #tp-seekrow {
      display:flex!important; align-items:center; gap:10px;
      padding:9px 22px 3px!important; flex-shrink:0; width:100%;
    }
    #tp-seek-cur, #tp-seek-tot {
      font-size:10px; color:var(--c-subtext); font-variant-numeric:tabular-nums;
      flex-shrink:0; min-width:30px;
    }
    #tp-seek-tot { text-align:right; }
    #tp-close {
      background:none; border:none; color:var(--c-subtext);
      cursor:pointer; padding:3px 6px; border-radius:5px; flex-shrink:0;
      display:flex; align-items:center; justify-content:center;
      transition:color .15s, background .15s;
      -webkit-app-region:no-drag; app-region:no-drag;
    }
    #tp-close:hover { color:#ff5c5c; background:rgba(255,90,90,.12); }
    #tp-seek {
      -webkit-appearance:none; flex:1 1 auto; height:3px;
      border-radius:2px; outline:none; cursor:pointer;
      background:linear-gradient(to right, var(--c-accent) 0%, var(--c-accent) var(--prog,0%), rgba(255,255,255,.18) var(--prog,0%), rgba(255,255,255,.18) 100%);
    }
    #tp-seek::-webkit-slider-thumb {
      -webkit-appearance:none; width:11px; height:11px; border-radius:50%;
      background:var(--c-text); cursor:pointer; opacity:0; transition:opacity .15s;
    }
    #tp-seekrow:hover #tp-seek::-webkit-slider-thumb { opacity:1; }
    /* ── Main row (existing bar) ── */
    #tp-mainrow {
      display:flex!important; flex-direction:row!important; align-items:center;
      gap:14px!important; padding:0 16px!important;
      flex:1 1 auto; min-height:0; width:100%;
    }
    .tp-art { width:50px; height:50px; border-radius:8px; object-fit:cover; flex-shrink:0; box-shadow:0 2px 8px rgba(0,0,0,.5); }
    .tp-meta { display:flex; flex-direction:column; justify-content:center; width:130px; flex-shrink:0; min-width:0; }
    .tp-title { font-size:13px; font-weight:600; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .tp-artist-row { display:flex; align-items:center; gap:6px; min-width:0; }
    .tp-artist { font-size:11px; color:var(--c-subtext); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; min-width:0; }
    #tp-like {
      background:none; border:none; color:var(--c-subtext);
      cursor:pointer; padding:0; display:flex; align-items:center;
      flex-shrink:0; transition:color .15s, transform .15s;
      -webkit-app-region:no-drag; app-region:no-drag;
    }
    #tp-like:hover { color:var(--c-text); transform:scale(1.18); }
    #tp-like.liked { color:var(--c-accent); filter:drop-shadow(0 0 4px var(--c-accent)); }
    .tp-sep { width:1px; height:36px; background:var(--c-stroke); flex-shrink:0; }
    .tp-lyric {
      flex:1 1 auto; min-width:0;
      font-size:20px; font-weight:700; letter-spacing:.3px;
      white-space:nowrap; overflow:hidden; text-overflow:ellipsis;
      color:var(--c-subtext);
      transition:color .25s, text-shadow .25s;
      text-align:center;
    }
    .tp-lyric.active { color:var(--c-accent); text-shadow:0 0 18px var(--c-accent); }
    /* Marquee fallback when even min font can't fit. One-way slide:
       anchor first word → slide left to reveal end → anchor last word.
       Never returns to start (that caused karaoke-out-of-sync on long lines).
       Animation runs ONCE per lyric line; next line restarts via JS rebuild.
       Easing pulls speed toward the END of the slide phase so last words breathe. */
    .tp-lyric.marquee { text-overflow:clip; text-align:left; }
    .tp-lyric.marquee .tp-lyric-inner {
      display:inline-block;
      animation:tp-marquee var(--mq-dur, 14s) cubic-bezier(.25,.1,.25,1) 1 forwards;
      will-change:transform;
    }
    @keyframes tp-marquee {
      0%, 18%   { transform:translateX(0); }                       /* hold start (read first words) */
      78%, 100% { transform:translateX(var(--mq-shift, 0)); }       /* hold end (read last words) */
    }
    body.no-lyric .tp-lyric, body.no-lyric .tp-lyric-sep { display:none!important; }
    body.no-lyric .tp-ctrls { margin-left:auto!important; }
    .tp-ctrls { display:flex; align-items:center; gap:7px; flex-shrink:0; }
    .tp-btn {
      background:none; border:none; color:var(--c-text);
      cursor:pointer; display:flex; align-items:center; justify-content:center;
      width:30px; height:30px; border-radius:50%; flex-shrink:0;
      transition:background .15s, color .15s, transform .1s;
    }
    .tp-btn:hover { background:rgba(255,255,255,.1); }
    .tp-btn:active { transform:scale(.92); }
    .tp-btn.tp-play { background:var(--c-btn); color:var(--c-player); width:34px; height:34px; }
    .tp-btn.tp-play:hover { filter:brightness(1.1); }
    .tp-btn.tp-active { color:var(--c-accent); }
    .tp-vol { display:flex; align-items:center; gap:6px; flex-shrink:0; }
    .tp-vol-icon { background:none; border:none; color:var(--c-subtext); cursor:pointer; display:flex; align-items:center; padding:2px; flex-shrink:0; transition:color .15s; }
    .tp-vol-icon:hover { color:var(--c-text); }
    .tp-vol-range {
      -webkit-appearance:none; width:84px; height:3px;
      border-radius:2px; outline:none; cursor:pointer;
      background:linear-gradient(to right, var(--c-accent) 0%, var(--c-accent) var(--vol,100%), rgba(255,255,255,.18) var(--vol,100%), rgba(255,255,255,.18) 100%);
    }
    .tp-vol-range::-webkit-slider-thumb { -webkit-appearance:none; width:11px; height:11px; border-radius:50%; background:var(--c-text); cursor:pointer; }
    .tp-icon-btn { background:none; border:none; color:var(--c-subtext); cursor:pointer; flex-shrink:0; display:flex; align-items:center; padding:5px; border-radius:6px; transition:color .15s, background .15s; }
    .tp-icon-btn:hover { color:var(--c-accent); background:rgba(255,255,255,.07); }
  `;

  // ── BUILD BODY HTML ───────────────────────────────────────────────────────
  function bodyHTML() {
    const playing    = Spicetify.Player.isPlaying();
    const vol        = Math.round((Spicetify.Player.getVolume() || 0) * 100);
    const muted      = Spicetify.Player.getMute();
    const shown      = muted ? 0 : vol;
    const repeatMode = Spicetify.Player.getRepeat?.() ?? 0;
    const shuffled   = !!Spicetify.Player.getShuffle?.();
    const track      = Spicetify.Player.data?.item;
    const title      = track?.name || 'Loading…';
    const artist     = track?.artists?.map(x => x.name).join(', ') || '';
    const artSrc     = track?.album?.images?.[0]?.url || track?.metadata?.image_url || '';
    const prog       = Spicetify.Player.getProgress() || 0;
    const dur        = Spicetify.Player.getDuration() || 0;
    const progPct    = dur > 0 ? ((prog / dur) * 100).toFixed(2) : '0';

    return `
      <div id="tp-seekrow">
        <span id="tp-seek-cur">${fmtTime(prog)}</span>
        <input type="range" id="tp-seek" min="0" max="${dur}" value="${prog}" style="--prog:${progPct}%">
        <span id="tp-seek-tot">${fmtTime(dur)}</span>
        <button id="tp-close" title="Close"><svg viewBox="0 0 16 16" width="11" height="11" fill="currentColor">${P.close}</svg></button>
      </div>
      <div id="tp-mainrow">
        <img id="tp-art" class="tp-art" src="${artSrc}" alt="">
        <div class="tp-meta">
          <div id="tp-title" class="tp-title">${escapeHtml(title)}</div>
          <div class="tp-artist-row">
            <div id="tp-artist" class="tp-artist">${escapeHtml(artist)}</div>
            <button id="tp-like" title="Like"><svg viewBox="0 0 16 16" width="12" height="12" fill="currentColor">${P.heartOut}</svg></button>
          </div>
        </div>
        <div class="tp-sep tp-lyric-sep"></div>
        <div id="tp-lyric" class="tp-lyric"><span class="tp-lyric-inner">♪</span></div>
        <div class="tp-sep"></div>
        <div class="tp-ctrls">
          <button class="tp-btn${shuffled ? ' tp-active' : ''}" id="tp-shuffle" title="Shuffle">${icon('bottombar-shuffle.svg', P.shuffle, 13)}</button>
          <button class="tp-btn" id="tp-prev" title="Previous">${icon('bottombar-previous.svg', P.prev, 14)}</button>
          <button class="tp-btn tp-play" id="tp-play" title="Play/Pause">${icon(playing ? 'bottombar-pause.svg' : 'bottombar-play.svg', playing ? P.pause : P.play, 15)}</button>
          <button class="tp-btn" id="tp-next" title="Next">${icon('bottombar-nextsong.svg', P.next, 14)}</button>
          <button class="tp-btn${repeatMode > 0 ? ' tp-active' : ''}" id="tp-repeat" title="Repeat">${repeatMode === 2 ? icon('bottombar-repeat-once.svg', P.repeatOne, 13) : icon('bottombar-repeat.svg', P.repeat, 13)}</button>
        </div>
        <div class="tp-vol">
          <button class="tp-vol-icon" id="tp-vol-icon">${volIcon(vol, muted)}</button>
          <input type="range" class="tp-vol-range" id="tp-vol" min="0" max="100" value="${shown}" style="--vol:${shown}%">
        </div>
        <button class="tp-icon-btn" id="tp-expand" title="Open full lyrics"><svg viewBox="0 0 16 16" width="14" height="14" fill="currentColor">${P.expand}</svg></button>
      </div>`;
  }

  function escapeHtml(t) { const d = document.createElement('div'); d.textContent = t; return d.innerHTML; }
  function fmtTime(ms) { const s = Math.floor((ms || 0) / 1000); return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0'); }

  // Set of IDs we own - anything else in body is foreign and must be removed
  const OUR_IDS = new Set(['tp-art', 'tp-title', 'tp-artist', 'tp-lyric', 'tp-shuffle', 'tp-prev', 'tp-play', 'tp-next', 'tp-repeat', 'tp-vol-icon', 'tp-vol', 'tp-expand', 'tp-seekrow', 'tp-mainrow', 'tp-seek', 'tp-seek-cur', 'tp-seek-tot', 'tp-close', 'tp-like']);
  const OUR_HEAD_IDS = new Set(['tp-colors', 'tp-static']);

  // Defense: pin body inline styles with !important, remove foreign content
  function pinBodyStyles(body) {
    if (!body) return;
    body.style.setProperty('display', 'flex', 'important');
    body.style.setProperty('flex-direction', 'column', 'important');
    body.style.setProperty('height', '100%', 'important');
    body.style.setProperty('width', '100%', 'important');
    body.style.setProperty('margin', '0', 'important');
    body.style.setProperty('padding', '0', 'important');
    body.style.setProperty('overflow', 'hidden', 'important');
  }

  const OUR_BODY_CLASSES = ['tp-sep', 'tp-meta', 'tp-ctrls', 'tp-vol'];
  function isOurBodyChild(n) {
    if (n.nodeType !== 1) return false;
    if (n.id && OUR_IDS.has(n.id)) return true;
    if (n.classList) for (const c of OUR_BODY_CLASSES) if (n.classList.contains(c)) return true;
    return false;
  }

  function cleanForeignNodes(win) {
    if (!win || win.closed) return;
    const doc = win.document;
    const body = doc.body;
    if (body) {
      [...body.children].forEach(n => { if (!isOurBodyChild(n)) n.remove(); });
      // Body class must stay empty or our 'no-lyric' - anything else is foreign
      const cls = body.className;
      const hasSynced = currentLyrics?.synced && currentLyrics.lines?.some(l => l.text?.trim());
      const want = hasSynced ? '' : 'no-lyric';
      if (cls !== want) { body.className = want; refreshLyricStateClass(); }
      pinBodyStyles(body);
    }
    const head = doc.head;
    if (head) {
      [...head.children].forEach(n => {
        // Keep our styles + meta + title; remove Spotify-injected <link>/<style>/<script>
        const tag = n.tagName;
        if (n.id && OUR_HEAD_IDS.has(n.id)) return;
        if (tag === 'META' || tag === 'TITLE') return;
        if (tag === 'LINK' || tag === 'SCRIPT') { n.remove(); return; }
        if (tag === 'STYLE' && !OUR_HEAD_IDS.has(n.id)) { n.remove(); return; }
      });
    }
  }

  // ── PiP DOC BUILD/REBUILD ─────────────────────────────────────────────────
  function buildPipDoc(win) {
    const doc = win.document;
    doc.documentElement.innerHTML = `<head>
        <meta charset="UTF-8">
        <title>♫ Vantagraph</title>
        <style id="tp-colors">${colorVarsCss()}</style>
        <style id="tp-static">${STATIC_CSS}</style>
      </head>
      <body class="">${bodyHTML()}</body>`;

    pinBodyStyles(doc.body);
    wireListeners(win);
    refreshLyricStateClass();
  }

  // ── EVENT WIRING (called every (re)build) ─────────────────────────────────
  function wireListeners(win) {
    const doc = win.document;
    const $   = id => doc.getElementById(id);

    $('tp-prev').onclick = () => Spicetify.Player.back();
    $('tp-play').onclick = () => Spicetify.Player.togglePlay();
    $('tp-next').onclick = () => Spicetify.Player.next();

    $('tp-shuffle').onclick = () => {
      Spicetify.Player.toggleShuffle();
      $('tp-shuffle').classList.toggle('tp-active', !!Spicetify.Player.getShuffle?.());
    };

    $('tp-repeat').onclick = () => {
      Spicetify.Player.setRepeat?.(((Spicetify.Player.getRepeat?.() ?? 0) + 1) % 3);
      const mode = Spicetify.Player.getRepeat?.() ?? 0;
      const btn  = $('tp-repeat');
      btn.classList.toggle('tp-active', mode > 0);
      btn.innerHTML = mode === 2 ? icon('bottombar-repeat-once.svg', P.repeatOne, 13) : icon('bottombar-repeat.svg', P.repeat, 13);
    };

    const volEl = $('tp-vol');
    volEl.oninput = e => {
      const v = parseInt(e.target.value);
      Spicetify.Player.setVolume(v / 100);
      if (Spicetify.Player.getMute()) Spicetify.Player.setMute(false);
      $('tp-vol-icon').innerHTML = volIcon(v, false);
      e.target.style.setProperty('--vol', v + '%');
    };
    volEl.addEventListener('wheel', e => {
      e.preventDefault();
      const v = Math.max(0, Math.min(1, Spicetify.Player.getVolume() + (e.deltaY < 0 ? 0.02 : -0.02)));
      Spicetify.Player.setVolume(v);
      if (Spicetify.Player.getMute() && v > 0) Spicetify.Player.setMute(false);
    }, { passive: false });
    $('tp-vol-icon').onclick = () => Spicetify.Player.toggleMute();

    // Seek bar
    const seekEl = $('tp-seek');
    if (seekEl) {
      seekEl.oninput = e => {
        _seeking = true;
        const v = parseInt(e.target.value);
        const max = parseInt(e.target.max) || 1;
        const pct = Math.max(0, Math.min(100, (v / max) * 100));
        e.target.style.setProperty('--prog', pct + '%');
        const cur = $('tp-seek-cur'); if (cur) cur.textContent = fmtTime(v);
      };
      seekEl.onchange = e => {
        Spicetify.Player.seek(parseInt(e.target.value));
        _seeking = false;
      };
    }

    $('tp-expand').onclick = () => document.dispatchEvent(new CustomEvent('vg-open-pip'));
    const closeBtn = $('tp-close');
    if (closeBtn) closeBtn.onclick = () => closePip();

    const likeBtn = $('tp-like');
    if (likeBtn) likeBtn.onclick = () => { try { Spicetify.Player.toggleHeart(); } catch (e) {} };
    refreshLikeState();

    // Force update sentinels to re-render after rebuild
    _lastPlaying = null; _lastVol = -1; _lastMuted = null; _lastDur = -1;
  }

  // ── WIPE DETECTION + REBUILD ──────────────────────────────────────────────
  // Triggered whenever PiP doc loses our root content. setTimeout(0) defers the
  // rebuild outside any rAF/observer callback to avoid re-entrancy.
  function scheduleRebuild() {
    if (rebuildPending || !pipWin || pipWin.closed) return;
    rebuildPending = true;
    setTimeout(() => {
      rebuildPending = false;
      if (!pipWin || pipWin.closed) return;
      try { buildPipDoc(pipWin); } catch (e) {}
    }, 0);
  }

  function attachWipeObserver(win) {
    try {
      let cleanScheduled = false;
      const obs = new MutationObserver((muts) => {
        if (!pipWin || pipWin.closed) return;
        // Full wipe? rebuild
        if (!pipWin.document.getElementById('tp-art')) { scheduleRebuild(); return; }

        // Detect foreign injection: any node added directly to <body> or <head>
        // whose ID/class isn't ours - Spotify's pip-mini-player injects here.
        let foreign = false;
        for (const m of muts) {
          if (m.type !== 'childList') continue;
          const parentTag = m.target.nodeName;
          if (parentTag !== 'BODY' && parentTag !== 'HEAD') continue;
          for (const n of m.addedNodes) {
            if (n.nodeType !== 1) continue;
            if (parentTag === 'BODY') {
              if (!isOurBodyChild(n)) { foreign = true; break; }
            } else {
              const tag = n.tagName;
              if ((tag === 'STYLE' || tag === 'LINK' || tag === 'SCRIPT') && !OUR_HEAD_IDS.has(n.id)) { foreign = true; break; }
            }
          }
          if (foreign) break;
          // Body class changed by Spotify?
          if (m.target.nodeName === 'BODY' && m.type === 'attributes' && m.attributeName === 'class') foreign = true;
        }
        if (foreign && !cleanScheduled) {
          cleanScheduled = true;
          setTimeout(() => {
            cleanScheduled = false;
            cleanForeignNodes(pipWin);
          }, 0);
        }
      });
      obs.observe(win.document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ['class', 'style'] });
      win.__vgObs = obs;
    } catch (e) {}
  }

  // ── COLORS REFRESH ────────────────────────────────────────────────────────
  function applyColors() {
    if (!pipWin || pipWin.closed) return;
    const el = pipWin.document.getElementById('tp-colors');
    if (el) el.textContent = colorVarsCss();
  }

  let lastThemeKey = '';
  const themeObs = new MutationObserver(() => {
    const key = JSON.stringify(getColors());
    if (key === lastThemeKey) return;
    lastThemeKey = key;
    applyColors();
  });
  themeObs.observe(document.documentElement, { attributes: true, attributeFilter: ['style'] });

  // ── UPDATE FUNCTIONS (run from MAIN doc rAF) ──────────────────────────────
  let _lastPlaying = null, _lastVol = -1, _lastMuted = null, _lastDur = -1, _currentLineDurMs = 0;

  function updateSeek() {
    if (!pipWin || pipWin.closed || _seeking) return;
    const doc = pipWin.document;
    const seekEl = doc.getElementById('tp-seek');
    if (!seekEl || doc.activeElement === seekEl) return;
    const prog = Spicetify.Player.getProgress() || 0;
    const dur  = Spicetify.Player.getDuration() || 0;
    if (_lastDur !== dur) {
      _lastDur = dur;
      seekEl.max = dur;
      const tot = doc.getElementById('tp-seek-tot');
      if (tot) tot.textContent = fmtTime(dur);
    }
    seekEl.value = prog;
    const pct = dur > 0 ? ((prog / dur) * 100).toFixed(2) : '0';
    seekEl.style.setProperty('--prog', pct + '%');
    const cur = doc.getElementById('tp-seek-cur');
    if (cur) cur.textContent = fmtTime(prog);
  }

  function updatePlayState() {
    if (!pipWin || pipWin.closed) return;
    const doc = pipWin.document;
    const playing = Spicetify.Player.isPlaying();
    if (_lastPlaying !== playing) {
      _lastPlaying = playing;
      const btn = doc.getElementById('tp-play');
      if (btn) btn.innerHTML = icon(playing ? 'bottombar-pause.svg' : 'bottombar-play.svg', playing ? P.pause : P.play, 15);
    }
    const volEl = doc.getElementById('tp-vol');
    if (volEl && doc.activeElement !== volEl) {
      const muted = Spicetify.Player.getMute();
      const v     = Math.round((Spicetify.Player.getVolume() || 0) * 100);
      const shown = muted ? 0 : v;
      if (_lastVol !== shown || _lastMuted !== muted) {
        _lastVol = shown; _lastMuted = muted;
        volEl.value = shown;
        volEl.style.setProperty('--vol', shown + '%');
        const vi = doc.getElementById('tp-vol-icon');
        if (vi) vi.innerHTML = volIcon(v, muted);
      }
    }
  }

  function updateMeta() {
    if (!pipWin || pipWin.closed) return;
    const doc = pipWin.document;
    const track = Spicetify.Player.data?.item;
    if (!track) return;
    const t = doc.getElementById('tp-title'), a = doc.getElementById('tp-artist'), art = doc.getElementById('tp-art');
    if (t)   t.textContent = track.name || 'Unknown';
    if (a)   a.textContent = track.artists?.map(x => x.name).join(', ') || '';
    if (art) art.src = track.album?.images?.[0]?.url || track.metadata?.image_url || '';
    refreshLikeState();
  }

  function refreshLikeState() {
    if (!pipWin || pipWin.closed) return;
    const btn = pipWin.document.getElementById('tp-like');
    if (!btn) return;
    let liked = false;
    try { liked = !!Spicetify.Player.getHeart?.(); } catch (e) {}
    btn.classList.toggle('liked', liked);
    btn.innerHTML = `<svg viewBox="0 0 16 16" width="12" height="12" fill="currentColor">${liked ? P.heartFill : P.heartOut}</svg>`;
  }

  function refreshLyricStateClass() {
    if (!pipWin || pipWin.closed) return;
    const doc = pipWin.document;
    const body = doc.body;
    if (!body) return;
    const hasSynced = currentLyrics?.synced && currentLyrics.lines?.some(l => l.text?.trim());
    body.classList.toggle('no-lyric', !hasSynced);
    // Inline-style fallback for display:none (in case Spotify CSS overrides ours)
    const lyric    = doc.getElementById('tp-lyric');
    const lyricSep = doc.querySelector('.tp-lyric-sep');
    if (!hasSynced) {
      if (lyric)    lyric.style.setProperty('display', 'none', 'important');
      if (lyricSep) lyricSep.style.setProperty('display', 'none', 'important');
    } else {
      if (lyric)    lyric.style.removeProperty('display');
      if (lyricSep) lyricSep.style.removeProperty('display');
    }
    // Resize window to compact (no-lyric) or full (lyric) width
    resizePipForLyricState(hasSynced);
  }

  function resizePipForLyricState(hasSynced) {
    if (!pipWin || pipWin.closed) return;
    const targetW = hasSynced ? BAR_W : BAR_W_NOLYRIC;
    if (_lastResizeWidth === targetW) return;
    _lastResizeWidth = targetW;
    try { pipWin.resizeTo(targetW, BAR_H); } catch (e) {}
  }

  function updateLyric() {
    if (!pipWin || pipWin.closed) return;
    const el = pipWin.document.getElementById('tp-lyric');
    if (!el) return;
    const inner = el.querySelector('.tp-lyric-inner');
    if (!inner) return;
    if (!currentLyrics?.synced || !currentLyrics.lines?.length) {
      if (inner.textContent !== '♪') { inner.textContent = '♪'; fitLyric(el, inner, 0); }
      el.classList.remove('active');
      return;
    }
    const t     = (Spicetify.Player.getProgress() || 0) + LYRIC_LEAD;
    const lines = currentLyrics.lines.filter(l => l.text?.trim());
    let idx = -1;
    for (let i = lines.length - 1; i >= 0; i--) { if (t >= lines[i].startTime) { idx = i; break; } }
    const text = idx >= 0 ? lines[idx].text : '♪';
    if (inner.textContent !== text) {
      // Compute line duration so marquee can finish before the next line arrives
      let lineDurMs = 0;
      if (idx >= 0) {
        const line = lines[idx];
        const next = lines[idx + 1];
        if (line.endTime && line.endTime > line.startTime) lineDurMs = line.endTime - line.startTime;
        else if (next) lineDurMs = next.startTime - line.startTime;
        else lineDurMs = 4000; // last line fallback
      }
      _currentLineDurMs = lineDurMs;
      inner.textContent = text;
      fitLyric(el, inner, lineDurMs);
    }
    el.classList.toggle('active', idx >= 0);
  }

  // Two-stage fit:
  //   1. Shrink font from MAX→MIN until line fits
  //   2. If even at MIN it overflows → enable marquee (CSS scroll animation),
  //      duration scaled by text length so long lines aren't blazingly fast.
  // Measurements use el.scrollWidth - container with white-space:nowrap +
  // overflow:hidden reflects total content width including overflow (reliable).
  // inner.scrollWidth on an inline span returns inconsistent values across
  // engines, so don't trust it.
  const LYRIC_FONT_MAX = 20, LYRIC_FONT_MIN = 8;
  function fitLyric(el, inner, lineDurMs) {
    if (!el) return;
    inner = inner || el.querySelector('.tp-lyric-inner');
    if (!inner) return;
    // Reset to clean state (marquee OFF) so measurement is accurate
    el.classList.remove('marquee');
    el.style.fontSize = LYRIC_FONT_MAX + 'px';
    inner.style.removeProperty('--mq-dur');
    inner.style.removeProperty('--mq-shift');
    const txt = inner.textContent;
    if (!txt || txt === '♪') return;

    const containerW = el.clientWidth;
    if (containerW < 10) return;
    let naturalW = el.scrollWidth;
    if (naturalW <= containerW) return;

    // Stage 1: shrink font - ratio estimate then fine-tune
    const ratio = containerW / naturalW;
    let size = Math.max(LYRIC_FONT_MIN, Math.floor(LYRIC_FONT_MAX * ratio));
    el.style.fontSize = size + 'px';
    let guard = 10;
    while (el.scrollWidth > containerW && size > LYRIC_FONT_MIN && guard-- > 0) {
      size -= 1;
      el.style.fontSize = size + 'px';
    }
    // Stage 2: still overflowing at MIN → bounce marquee.
    // First word anchored at left, slides left only as much as needed to expose
    // the end (no full-sweep, no off-screen - wave envelope 0→1→0, never 0→2).
    if (el.scrollWidth > containerW) {
      // Shift = negative of how much text overflows past the right edge.
      // Add small breathing room so the last char isn't flush with the edge.
      const overflow = el.scrollWidth - containerW + 8;
      inner.style.setProperty('--mq-shift', '-' + overflow + 'px');
      let dur;
      if (lineDurMs && lineDurMs >= 1500 && lineDurMs <= 30000) {
        // One full bounce cycle per line - anchor→slide→anchor→return within line time
        dur = lineDurMs / 1000;
      } else {
        // Fallback: scale by overflow distance so longer text gets more time
        dur = Math.max(5, Math.min(16, (overflow + containerW) / 90));
      }
      inner.style.setProperty('--mq-dur', dur.toFixed(2) + 's');
      el.classList.add('marquee');
    }
  }

  // ── RAF LOOP (in MAIN doc - survives PiP doc wipes) ───────────────────────
  function startLoop() {
    if (rafId) cancelAnimationFrame(rafId);
    function loop() {
      if (!pipWin || pipWin.closed) { rafId = null; return; }
      // Sentinel check: if doc was wiped and observer hasn't fired yet, force rebuild now
      if (!pipWin.document.getElementById('tp-art')) {
        scheduleRebuild();
      } else {
        updatePlayState();
        updateSeek();
        updateLyric();
      }
      rafId = requestAnimationFrame(loop);
    }
    rafId = requestAnimationFrame(loop);
  }

  // ── LYRICS ─────────────────────────────────────────────────────────────────
  async function fetchLyrics(trackUri) {
    try {
      const id = trackUri.split(':').pop();
      try {
        const r = await Spicetify.CosmosAsync.get(`https://spclient.wg.spotify.com/color-lyrics/v2/track/${id}?format=json&market=from_token`);
        if (r?.lyrics?.lines) return {
          synced: r.lyrics.syncType === 'LINE_SYNCED',
          lines: r.lyrics.lines.map(l => ({ startTime: parseInt(l.startTimeMs), text: l.words || '' }))
        };
      } catch (e) {}
      if (Spicetify.Platform?.Lyrics) {
        try {
          const l = await Spicetify.Platform.Lyrics.getLyrics(trackUri);
          if (l?.lines) return { synced: true, lines: l.lines.map(ln => ({ startTime: ln.startTimeMs || 0, text: ln.words || ln.text || '' })) };
        } catch (e) {}
      }
    } catch (e) {}
    return null;
  }

  async function loadLyrics(uri) {
    currentLyrics = await fetchLyrics(uri);
    refreshLyricStateClass();
  }

  // ── OPEN / CLOSE ──────────────────────────────────────────────────────────
  async function openPip() {
    if (pipWin && !pipWin.closed) { pipWin.focus(); return; }
    if (!('documentPictureInPicture' in window)) {
      Spicetify.showNotification('Taskbar Player requires Picture-in-Picture support.', true);
      return;
    }
    try {
      pipWin = await window.documentPictureInPicture.requestWindow({ width: BAR_W, height: BAR_H });
    } catch (e) {
      Spicetify.showNotification('Could not open Taskbar Player.', true);
      return;
    }

    buildPipDoc(pipWin);
    attachWipeObserver(pipWin);

    pipWin.addEventListener('pagehide', () => {
      try { pipWin.__vgObs?.disconnect(); } catch (e) {}
      pipWin = null;
      _lastResizeWidth = null;
      if (rafId) { cancelAnimationFrame(rafId); rafId = null; }
      lss('visible', 'false');
    });

    // Refit lyric when user resizes the bar manually
    let _resizeRaf = 0;
    pipWin.addEventListener('resize', () => {
      if (_resizeRaf) cancelAnimationFrame(_resizeRaf);
      _resizeRaf = requestAnimationFrame(() => {
        if (pipWin && !pipWin.closed) {
          const el = pipWin.document.getElementById('tp-lyric');
          if (el) fitLyric(el, null, _currentLineDurMs);
        }
      });
    });

    const initUri = Spicetify.Player.data?.item?.uri;
    if (initUri) { currentUri = initUri; loadLyrics(initUri); }

    startLoop();
    lss('visible', 'true');
  }

  function closePip() {
    if (pipWin && !pipWin.closed) { try { pipWin.close(); } catch (e) {} }
    pipWin = null;
    _lastResizeWidth = null;
    if (rafId) { cancelAnimationFrame(rafId); rafId = null; }
    lss('visible', 'false');
  }

  function toggle() {
    if (pipWin && !pipWin.closed) closePip();
    else openPip();
  }

  // ── PLAYER LISTENERS ──────────────────────────────────────────────────────
  Spicetify.Player.addEventListener('songchange', () => {
    updateMeta();
    _lastPlaying = null; _lastDur = -1;
    const uri = Spicetify.Player.data?.item?.uri;
    if (uri && uri !== currentUri) { currentUri = uri; loadLyrics(uri); }
    // Spotify's pip-mini-player injects content here - sweep at multiple ticks
    // because injection can be async.
    if (pipWin && !pipWin.closed) {
      cleanForeignNodes(pipWin);
      setTimeout(() => cleanForeignNodes(pipWin), 50);
      setTimeout(() => cleanForeignNodes(pipWin), 200);
      setTimeout(() => cleanForeignNodes(pipWin), 600);
    }
  });
  Spicetify.Player.addEventListener('onplaypause', () => { _lastPlaying = null; });
  // Heart state can change from outside (other UI) - refresh when Spotify announces
  try {
    Spicetify.Platform?.PlayerAPI?._events?.addListener?.('update', refreshLikeState);
  } catch (e) {}

  // vantagraph-custom-lyric-miniplayer.js miniBtn dispatches this
  document.addEventListener('vg-toggle-taskbar', toggle);

  // ── PLAYBAR BUTTON (injected into Spotify's extraControls, after fullscreen) ──
  // Match Spotify's own button DOM/classes so it aligns naturally with siblings
  // (queue, connect, fullscreen). This avoids Spicetify.Playbar.Button which
  // puts it in a different container and breaks alignment when other VG
  // extensions (settings) touch the playbar.
  const MINI_ICON_SVG = `<svg data-encore-id="icon" role="img" aria-hidden="true" viewBox="0 0 16 16" fill="currentColor"><path d="M1.5 3A1.5 1.5 0 0 0 0 4.5v7A1.5 1.5 0 0 0 1.5 13h13a1.5 1.5 0 0 0 1.5-1.5v-7A1.5 1.5 0 0 0 14.5 3h-13zM1.5 9.5h13v2a.5.5 0 0 1-.5.5h-12a.5.5 0 0 1-.5-.5v-2z"/></svg>`;

  function makeLaunchBtn(refBtn) {
    const b = document.createElement('button');
    b.id = 'vg-tbp-launch-btn';
    b.className = refBtn.className;
    b.setAttribute('aria-label', 'Taskbar Player');
    b.setAttribute('title', 'Taskbar Player');
    b.setAttribute('data-vg-tbp-launch', '1');
    b.innerHTML = MINI_ICON_SVG;
    b.onclick = (e) => { e.stopPropagation(); toggle(); };
    return b;
  }

  function injectLaunchBtn() {
    if (document.getElementById('vg-tbp-launch-btn')) return true;
    // Anchor on fullscreen button - most stable selector across Spotify versions
    const ref = document.querySelector('[data-testid="fullscreen-mode-button"]')
             || document.querySelector('button[aria-label*="Full" i]')
             || document.querySelector('button[aria-label*="Tam" i]');
    if (!ref || !ref.parentNode) return false;
    ref.parentNode.insertBefore(makeLaunchBtn(ref), ref.nextSibling);
    return true;
  }

  // Initial try + observer for Spotify re-renders (player bar can rebuild on layout change)
  if (!injectLaunchBtn()) {
    const obs = new MutationObserver(() => { if (injectLaunchBtn()) {/* keep observing for re-renders */} });
    obs.observe(document.body, { childList: true, subtree: true });
  } else {
    // Even when initial succeeds, watch for re-renders so we re-inject after Spotify wipes
    const obs = new MutationObserver(() => { injectLaunchBtn(); });
    obs.observe(document.body, { childList: true, subtree: true });
  }

  // ── AUTO-OPEN IF WAS VISIBLE ─────────────────────────────────────────────
  if (ls('visible') === 'true') {
    // Small delay so Spotify finishes loading
    setTimeout(() => { openPip().catch(() => {}); }, 800);
  }

})();
