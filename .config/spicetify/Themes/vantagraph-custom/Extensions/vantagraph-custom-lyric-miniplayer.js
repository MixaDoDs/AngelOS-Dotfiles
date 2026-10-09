// Vantagraph Custom Lyric Miniplayer - PiP window: seekbar, word-sync karaoke, translations, rAF loop
//
// Inspired by the original Spictify Lyric Miniplayer extension by FO-SS.
// Original repository: https://github.com/FO-SS/Spictify-Lyric-Miniplayer
// Thank you, FO-SS, for the original floating PiP lyrics window concept.
//
// Vantagraph improvements: live --spice-* theming, rAF loop, VantagraphCustomData integration.
// v2: Spotify-like layout, gear icon, repeat, grouped settings, faded lyrics, theme refresh.
// v3: LoopyLoop PiP seekbar, karaoke, vinyl, compact mode, VG settings link.
// v4: Like flat in header, volume inline controls, font size in settings.
// v5: 8 animation presets, text case, alignment picker, enhanced karaoke glow.
// v6: Settings as separate popup window, like inside track-info, shorter vol bar.
// v7: Removed broken mini overlay, centered playback + vol, like beside artist, fixed faded/karaoke word-sync/effects.

(async function VantagraphLyricMiniplayer() {
  while (!Spicetify?.Player?.data || !Spicetify?.Platform || !Spicetify?.CosmosAsync || !Spicetify?.Topbar) {
    await new Promise(r => setTimeout(r, 100));
  }

  const CFG = { pipWidth: 380, pipHeight: 540, defaultFontSize: 14, maxFontSize: 28, minFontSize: 10 };

  const ls  = (k) => localStorage.getItem('vg-lyric-' + k);
  const lss = (k, v) => localStorage.setItem('vg-lyric-' + k, v);

  let pipWindow      = null;
  let settingsWindow = null;
  let currentLyrics  = null;
  let currentTrackUri = null;
  let rafId          = null;
  let lastActiveIdx  = -1;
  let lastFxKey      = '';

  let fontSize         = parseInt(ls('fontsize'))    || CFG.defaultFontSize;
  let showLyrics       = ls('showlyrics')  !== null ? ls('showlyrics')  === 'true' : true;
  let showVolumeSlider = ls('showvol')     !== null ? ls('showvol')     === 'true' : true;
  let showShuffleBtn   = ls('showshuffle') !== null ? ls('showshuffle') === 'true' : true;
  let showRepeatBtn    = ls('showrepeat')  !== null ? ls('showrepeat')  === 'true' : true;
  let showLikeBtn      = ls('showlike')    !== null ? ls('showlike')    === 'true' : true;
  let showCloseBtn     = ls('showclose')   !== null ? ls('showclose')   === 'true' : true;
  let showTranslations = ls('showtrans')   !== null ? ls('showtrans')   === 'true' : true;
  let fadedLyrics      = ls('faded')       !== null ? ls('faded')       === 'true' : true;
  let karaokeMode      = ls('karaoke')     !== null ? ls('karaoke')     === 'true' : false;
  let vinylEffect      = ls('vinyl')       !== null ? ls('vinyl')       === 'true' : false;
  let showLoopCtrl     = ls('loopctrl')    !== null ? ls('loopctrl')    === 'true' : true;

  // Lyric matching runs slightly ahead to offset rAF/getProgress lag (ms). Tunable.
  const LYRIC_LEAD = 150;
  // For line-synced (no syllable data) tracks we derive word timings. Cap per-word duration so
  // a long instrumental gap after a line doesn't inflate it and make karaoke crawl/lag.
  const MAX_WORD_MS = 600;

  const ANIM_OPTIONS  = ['none', 'pulse', 'bounce', 'shake', 'float', 'swing', 'glitch', 'wave'];
  const ANIM_LABELS   = ['Off',  'Pulse', 'Bounce', 'Shake', 'Float', 'Swing', 'Glitch', 'Wave'];
  const CASE_OPTIONS  = ['none', 'upper', 'lower'];
  const CASE_LABELS   = ['Normal', 'ALL CAPS', 'lowercase'];
  const ALIGN_OPTIONS = ['center', 'left', 'right'];
  const ALIGN_LABELS  = ['Center', 'Left', 'Right'];
  // What the active effect animates, and which line it plays on.
  const SCOPE_OPTIONS   = ['line', 'word', 'all'];
  const SCOPE_LABELS    = ['Whole line', 'Word by word', 'All lines'];
  const TRIGGER_OPTIONS = ['active', 'entrance', 'next'];
  const TRIGGER_LABELS  = ['Active line (loop)', 'On entrance (once)', 'Next line (preview)'];

  let activeAnimation = ls('anim')     || 'pulse';
  let textCase        = ls('textcase') || 'none';
  let alignLyrics     = ls('align')    || 'center';
  let effectScope     = ls('fxscope')  || 'line';
  let effectTrigger   = ls('fxtrigger')|| 'active';

  let pipLoopStart = null, pipLoopEnd = null, pipCtxPct = 0;
  const LOOP_PREFIX = 'loopy:';

  // 1. icons: standard SVG paths (this theme ships no custom icon set)
  function makeIconHtml(_file, path, size) {
    size = size || 16;
    return `<svg viewBox="0 0 16 16" width="${size}" height="${size}" fill="currentColor" style="flex-shrink:0;">${path}</svg>`;
  }

  // 2. SVG paths
  const P = {
    prev:      '<path d="M3.3 1a.7.7 0 0 1 .7.7v5.15l9.95-5.744a.7.7 0 0 1 1.05.606v12.575a.7.7 0 0 1-1.05.607L4 9.149V14.3a.7.7 0 0 1-.7.7H1.7a.7.7 0 0 1-.7-.7V1.7a.7.7 0 0 1 .7-.7h1.6z"/>',
    play:      '<path d="M3 1.713a.7.7 0 0 1 1.05-.607l10.89 6.288a.7.7 0 0 1 0 1.212L4.05 14.894A.7.7 0 0 1 3 14.288V1.713z"/>',
    pause:     '<path d="M2.7 1a.7.7 0 0 0-.7.7v12.6a.7.7 0 0 0 .7.7h2.6a.7.7 0 0 0 .7-.7V1.7a.7.7 0 0 0-.7-.7H2.7zm8 0a.7.7 0 0 0-.7.7v12.6a.7.7 0 0 0 .7.7h2.6a.7.7 0 0 0 .7-.7V1.7a.7.7 0 0 0-.7-.7h-2.6z"/>',
    next:      '<path d="M12.7 1a.7.7 0 0 0-.7.7v5.15L2.05 1.107A.7.7 0 0 0 1 1.712v12.575a.7.7 0 0 0 1.05.607L12 9.149V14.3a.7.7 0 0 0 .7.7h1.6a.7.7 0 0 0 .7-.7V1.7a.7.7 0 0 0-.7-.7h-1.6z"/>',
    shuffle:   '<path d="M13.151.922a.75.75 0 1 0-1.06 1.06L13.109 3H11.16a3.75 3.75 0 0 0-2.873 1.34l-6.173 7.356A2.25 2.25 0 0 1 .39 12.5H0V14h.391a3.75 3.75 0 0 0 2.873-1.34l6.173-7.356a2.25 2.25 0 0 1 1.724-.804h1.947l-1.017 1.018a.75.75 0 0 0 1.06 1.06l2.306-2.306a.75.75 0 0 0 0-1.06L13.15.922zM.391 3.5H0V2h.391c1.109 0 2.16.49 2.873 1.34L4.89 5.277l-.979 1.167-1.796-2.14A2.25 2.25 0 0 0 .39 3.5z"/><path d="m7.5 10.723.98-1.167 1.796 2.14a2.25 2.25 0 0 0 1.724.804h1.947l-1.017-1.018a.75.75 0 1 1 1.06-1.06l2.306 2.306a.75.75 0 0 1 0 1.06l-2.306 2.306a.75.75 0 1 1-1.06-1.06L14.109 14H12.16a3.75 3.75 0 0 1-2.873-1.34l-1.787-2.14z"/>',
    repeat:    '<path d="M0 4.75A3.75 3.75 0 0 1 3.75 1h8.5A3.75 3.75 0 0 1 16 4.75v5a3.75 3.75 0 0 1-3.75 3.75H9.81l1.018 1.018a.75.75 0 1 1-1.06 1.06L6.939 12.75l2.829-2.829a.75.75 0 1 1 1.06 1.061L9.811 12h2.439a2.25 2.25 0 0 0 2.25-2.25v-5a2.25 2.25 0 0 0-2.25-2.25h-8.5A2.25 2.25 0 0 0 2.25 4.75v5A2.25 2.25 0 0 0 4.5 12v1.5A3.75 3.75 0 0 1 0 9.75v-5z"/>',
    repeatOne: '<path d="M0 4.75A3.75 3.75 0 0 1 3.75 1h.75v1.5h-.75A2.25 2.25 0 0 0 1.5 4.75v5A2.25 2.25 0 0 0 3.75 12H4.5v1.5h-.75A3.75 3.75 0 0 1 0 9.75v-5zM12.25 2.5h-.75V1h.75A3.75 3.75 0 0 1 16 4.75v5a3.75 3.75 0 0 1-3.75 3.75H9.81l1.018 1.018a.75.75 0 1 1-1.06 1.06L6.939 12.75l2.829-2.829a.75.75 0 1 1 1.06 1.061L9.811 12h2.439a2.25 2.25 0 0 0 2.25-2.25v-5a2.25 2.25 0 0 0-2.25-2.25z"/><path d="M9.12 8V1H7.787c-.128.72-.76 1.293-1.787 1.313V3.36h1.57V8h1.55z"/>',
    heartOut:  '<path d="M1.69 2A4.582 4.582 0 0 1 8 2.023 4.583 4.583 0 0 1 11.88.817h.002a4.618 4.618 0 0 1 3.782 3.65v.003a4.543 4.543 0 0 1-1.011 3.84L9.35 14.629a1.765 1.765 0 0 1-2.093.464 1.762 1.762 0 0 1-.605-.463L1.348 8.309A4.582 4.582 0 0 1 1.689 2zm3.158.252A3.082 3.082 0 0 0 2.49 7.337l.005.005L7.8 13.664a.264.264 0 0 0 .311.069.262.262 0 0 0 .09-.069l5.312-6.33a3.043 3.043 0 0 0 .68-2.573 3.118 3.118 0 0 0-2.551-2.463 3.079 3.079 0 0 0-2.612.816l-.007.007a1.501 1.501 0 0 1-2.045 0l-.009-.008a3.082 3.082 0 0 0-2.121-.861z"/>',
    heartFill: '<path d="M15.724 4.22A4.313 4.313 0 0 0 12.192.814a4.269 4.269 0 0 0-3.622 1.13.837.837 0 0 1-1.14 0 4.272 4.272 0 0 0-6.21 5.855l5.916 7.05a1.128 1.128 0 0 0 1.727 0l5.916-7.05a4.228 4.228 0 0 0 .945-3.577z"/>',
    gear:      '<path d="M9.405 1.05c-.413-1.4-2.397-1.4-2.81 0l-.1.34a1.464 1.464 0 0 1-2.105.872l-.31-.17c-1.283-.698-2.686.705-1.987 1.987l.169.311c.446.82.023 1.841-.872 2.105l-.34.1c-1.4.413-1.4 2.397 0 2.81l.34.1a1.464 1.464 0 0 1 .872 2.105l-.17.31c-.698 1.283.705 2.686 1.987 1.987l.311-.169a1.464 1.464 0 0 1 2.105.872l.1.34c.413 1.4 2.397 1.4 2.81 0l.1-.34a1.464 1.464 0 0 1 2.105-.872l.31.17c1.283.698 2.686-.705 1.987-1.987l-.169-.311a1.464 1.464 0 0 1 .872-2.105l.34-.1c1.4-.413 1.4-2.397 0-2.81l-.34-.1a1.464 1.464 0 0 1-.872-2.105l.17-.31c.698-1.283-.705-2.686-1.987-1.987l-.311.169a1.464 1.464 0 0 1-2.105-.872l-.1-.34zM8 10.93a2.929 2.929 0 1 1 0-5.86 2.929 2.929 0 0 1 0 5.858z"/>',
    mini:      '<path d="M1.5 3A1.5 1.5 0 0 0 0 4.5v7A1.5 1.5 0 0 0 1.5 13h13a1.5 1.5 0 0 0 1.5-1.5v-7A1.5 1.5 0 0 0 14.5 3h-13zM1.5 9.5h13v2a.5.5 0 0 1-.5.5h-12a.5.5 0 0 1-.5-.5v-2z"/>',
    expand:    '<path d="M6 2H2v4h1.5V4.56l3.2 3.2 1.06-1.06-3.2-3.2H6V2zm4 12h4v-4h-1.5v2.44l-3.2-3.2-1.06 1.06 3.2 3.2H10V14z"/>',
    volHigh:   '<path d="M9.741.85a.75.75 0 0 1 .375.65v13a.75.75 0 0 1-1.125.65l-6.925-4a3.642 3.642 0 0 1-1.33-4.967 3.639 3.639 0 0 1 1.33-1.332l6.925-4a.75.75 0 0 1 .75 0zm-6.924 5.3a2.139 2.139 0 0 0 0 3.7l5.8 3.35V2.8l-5.8 3.35zm8.683 6.087a4.502 4.502 0 0 0 0-8.474v1.65a2.999 2.999 0 0 1 0 5.175v1.649z"/>',
    volLow:    '<path d="M9.741.85a.75.75 0 0 1 .375.65v13a.75.75 0 0 1-1.125.65l-6.925-4a3.642 3.642 0 0 1-1.33-4.967 3.639 3.639 0 0 1 1.33-1.332l6.925-4a.75.75 0 0 1 .75 0zm-6.924 5.3a2.139 2.139 0 0 0 0 3.7l5.8 3.35V2.8l-5.8 3.35zm8.683 4.29V5.56a2.75 2.75 0 0 1 0 4.88z"/>',
    volOff:    '<path d="M13.86 5.47a.75.75 0 0 0-1.061 0l-1.47 1.47-1.47-1.47A.75.75 0 0 0 8.8 6.53L10.269 8l-1.47 1.47a.75.75 0 1 0 1.06 1.06l1.47-1.47 1.47 1.47a.75.75 0 0 0 1.06-1.06L12.39 8l1.47-1.47a.75.75 0 0 0 0-1.06z"/><path d="M10.116 1.5A.75.75 0 0 0 8.991.85l-6.925 4a3.642 3.642 0 0 0-1.33 4.967 3.639 3.639 0 0 0 1.33 1.332l6.925 4a.75.75 0 0 0 1.125-.649v-1.906a4.73 4.73 0 0 1-1.5-.694v1.3L2.817 9.852a2.141 2.141 0 0 1-.781-2.92c.187-.324.456-.594.78-.782l5.8-3.35v1.3c.45-.313.956-.55 1.5-.694V1.5z"/>',
  };

  function makeVolIconHtml(vol, muted) {
    if (muted) return makeIconHtml('bottombar-VolumeOff.svg', P.volOff, 13);
    const path = vol < 1 ? P.volOff : vol < 50 ? P.volLow : P.volHigh;
    return `<svg viewBox="0 0 16 16" width="13" height="13" fill="currentColor" style="flex-shrink:0;">${path}</svg>`;
  }

  // 3. theme colors
  function getThemeColors() {
    const cs = getComputedStyle(document.documentElement);
    const g  = (v, fb) => cs.getPropertyValue(v).trim() || fb;
    return {
      player:    g('--spice-player',     '#1A1917'),
      text:      g('--spice-text',       '#F9F7F7'),
      subtext:   g('--spice-subtext',    '#7B7E83'),
      accent:    g('--spice-accent',     '#3F72AF'),
      btnActive: g('--spice-btn-active', g('--spice-button-active', '#DBE2EF')),
      sidebar:   g('--spice-window',     g('--spice-sidebar', '#1A1917')),
      highlight: g('--spice-stroke',     g('--spice-highlight', '#28507F')),
      main:      g('--spice-panel',      g('--spice-main', '#162333')),
    };
  }

  // 3b. Static CSS - color-INDEPENDENT animations. Injected once into each window as #staticStyles
  // and never rewritten by the theme observer, so per-song color updates can't restart a running
  // animation (this is what made vinyl/effects appear frozen or stop on song change).
  function generateStaticStyles() {
    return `
    /* Active-effect presets (transforms only - no colors) */
    .vgfx-none  { transform:scale(1.04); }
    @keyframes lyricPulse { 0%,100%{transform:scale(1.04)} 50%{transform:scale(1.11)} }
    .vgfx-pulse { animation:lyricPulse 1.8s ease-in-out infinite; }
    @keyframes lyricBounce { 0%,100%{transform:scale(1.04) translateY(0)} 30%{transform:scale(1.08) translateY(-8px)} 50%{transform:scale(1.04) translateY(0)} 70%{transform:scale(1.06) translateY(-4px)} 85%{transform:scale(1.04) translateY(0)} }
    .vgfx-bounce { animation:lyricBounce 1.3s cubic-bezier(.36,.07,.19,.97) infinite; }
    @keyframes lyricShake { 0%,100%{transform:scale(1.04) translateX(0)} 15%{transform:scale(1.04) translateX(-6px)} 35%{transform:scale(1.05) translateX(6px)} 55%{transform:scale(1.04) translateX(-4px)} 75%{transform:scale(1.04) translateX(4px)} 90%{transform:scale(1.04) translateX(-2px)} }
    .vgfx-shake { animation:lyricShake .65s ease infinite; }
    @keyframes lyricFloat { 0%,100%{transform:scale(1.04) translateY(0)} 50%{transform:scale(1.05) translateY(-9px)} }
    .vgfx-float { animation:lyricFloat 3s ease-in-out infinite; }
    @keyframes lyricSwing { 0%,100%{transform:scale(1.04) rotate(0)} 25%{transform:scale(1.05) rotate(1.4deg)} 75%{transform:scale(1.05) rotate(-1.4deg)} }
    .vgfx-swing { animation:lyricSwing 2.1s ease-in-out infinite; }
    @keyframes lyricGlitch { 0%,100%{transform:scale(1.04) skewX(0) translateX(0)} 20%{transform:scale(1.04) skewX(4deg) translateX(-3px)} 40%{transform:scale(1.06) skewX(-4deg) translateX(3px)} 60%{transform:scale(1.04) skewX(2deg) translateX(-1px)} 80%{transform:scale(1.06) skewX(-2deg) translateX(1px)} }
    .vgfx-glitch { animation:lyricGlitch .36s ease infinite; }
    @keyframes lyricWave { 0%,100%{transform:scale(1.04) scaleX(1) translateY(0)} 25%{transform:scale(1.07) scaleX(1.05) translateY(-4px)} 50%{transform:scale(1.04) scaleX(1) translateY(0)} 75%{transform:scale(1.06) scaleX(.96) translateY(4px)} }
    .vgfx-wave { animation:lyricWave 2.5s ease-in-out infinite; }
    .vgfx-once { animation-iteration-count:1 !important; animation-fill-mode:both !important; }
    .lyric-word.vgfx-pulse, .lyric-word.vgfx-bounce, .lyric-word.vgfx-shake,
    .lyric-word.vgfx-float, .lyric-word.vgfx-swing, .lyric-word.vgfx-glitch, .lyric-word.vgfx-wave { animation-delay:var(--wd,0ms); }

    /* Vinyl spin */
    @keyframes vinylSpin { to{transform:rotate(360deg)} }
    .vinyl .album-art { border-radius:50%; animation:vinylSpin 4s linear infinite; }
    .vinyl .album-art.spin-paused { animation-play-state:paused; }
    `;
  }

  // 4. PiP CSS
  function generateStyles() {
    const c = getThemeColors();
    return `
    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600&display=swap');
    *, *::before, *::after { margin:0; padding:0; box-sizing:border-box; }
    html, body { height:100%; overflow:hidden; }
    body { font-family:'DM Sans',-apple-system,sans-serif; background:${c.sidebar}; color:${c.text}; display:flex; flex-direction:column; }

    /* Header */
    .header { display:flex; align-items:center; gap:8px; padding:10px 12px; background:${c.player}; border-bottom:1px solid ${c.highlight}; flex-shrink:0; cursor:grab; user-select:none; -webkit-app-region:drag; app-region:drag; }
    .header:active { cursor:grabbing; }
    .album-art { width:38px; height:38px; border-radius:6px; object-fit:cover; box-shadow:0 2px 8px #000; flex-shrink:0; transition:border-radius .3s; -webkit-app-region:no-drag; app-region:no-drag; }
    .track-info { flex:1; min-width:0; }
    .track-title  { font-size:12px; font-weight:600; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; margin-bottom:2px; }
    .track-artist-row { display:flex; align-items:center; gap:5px; }
    .track-artist { font-size:10px; color:${c.subtext}; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; min-width:0; }
    .like-flat { background:none; border:none; color:${c.subtext}; cursor:pointer; padding:0; display:flex; align-items:center; transition:color .15s, transform .15s; -webkit-app-region:no-drag; app-region:no-drag; flex-shrink:0; }
    .like-flat:hover { color:${c.text}; transform:scale(1.2); }
    .like-flat.liked { color:${c.accent}; filter:drop-shadow(0 0 4px ${c.accent}80); }
    .like-flat.hidden { display:none; }
    .header-btns { display:flex; align-items:center; gap:1px; -webkit-app-region:no-drag; app-region:no-drag; flex-shrink:0; }
    .icon-btn { display:flex; align-items:center; justify-content:center; background:none; border:none; color:${c.subtext}; width:26px; height:26px; border-radius:6px; cursor:pointer; transition:color .15s, background .15s; }
    .icon-btn:hover { color:${c.text}; background:${c.highlight}; }
    .close-btn { background:none; border:none; color:${c.subtext}; font-size:18px; cursor:pointer; padding:3px 5px; transition:color .15s; line-height:1; }
    .close-btn:hover { color:${c.accent}; }
    .close-btn.hidden { display:none; }

    /* Karaoke hint */
    .karaoke-hint { text-align:center; padding:4px; font-size:10px; color:${c.subtext}; flex-shrink:0; letter-spacing:.5px; background:${c.player}; border-bottom:1px solid ${c.highlight}; }
    .karaoke-hint.hidden { display:none; }

    /* Lyrics */
    .lyrics-wrap { flex:1 1 auto; overflow-y:auto; overflow-x:hidden; padding:10px 14px; scroll-behavior:smooth; -webkit-app-region:no-drag; app-region:no-drag; min-height:0; scrollbar-width:none; }
    .lyrics-wrap::-webkit-scrollbar { display:none; }
    .lyrics-wrap.align-center { text-align:center; }
    .lyrics-wrap.align-right  { text-align:right; }
    .lyrics-wrap.case-upper .lyric { text-transform:uppercase; letter-spacing:.06em; }
    .lyrics-wrap.case-lower .lyric { text-transform:lowercase; }
    .lyrics-wrap.collapsed { display:none; }

    .lyric { padding:5px 0; opacity:.2; transition:opacity .3s, text-shadow .25s; cursor:pointer; line-height:1.4; }
    .lyrics-wrap.align-center .lyric { transform-origin:center center; }
    .lyrics-wrap.align-left   .lyric { transform-origin:left center; }
    .lyrics-wrap.align-right  .lyric { transform-origin:right center; }
    .lyric:hover { opacity:.7 !important; }
    .lyric.past { opacity:.35; }
    .lyric.active { opacity:1 !important; font-weight:500; text-shadow:0 0 24px ${c.accent}22; }

    /* NOTE: the 8 .vgfx-* effect keyframes + vinyl spin live in #staticStyles (generateStaticStyles),
       a stylesheet the theme observer never rewrites, so color updates can't restart them mid-play. */

    /* Word-sync (karaoke only - off karaoke the whole active line is highlighted) */
    .lyric-word { display:inline-block; transition:color .12s, text-shadow .12s; }
    .karaoke .lyric.active .lyric-word { color:${c.subtext}; }
    .karaoke .lyric.active .lyric-word.spoken { color:${c.accent}; }

    /* Karaoke: enhanced multi-layer glow */
    .karaoke .lyric.active { background:radial-gradient(ellipse at center, ${c.accent}1f 0%, transparent 72%); border-radius:8px; padding:5px 10px; margin:0 -10px; }
    .karaoke .lyric.active .lyric-word.spoken { text-shadow:0 0 10px ${c.accent}70; }
    .karaoke .lyric.active .lyric-word.current { animation:karaokeWord .5s ease-in-out infinite alternate; }
    @keyframes karaokeWord {
      from { text-shadow:0 0 8px ${c.accent}80, 0 0 18px ${c.accent}50; transform:scale(1); }
      to   { text-shadow:0 0 14px ${c.accent}, 0 0 30px ${c.accent}90, 0 0 55px ${c.accent}40; transform:scale(1.1); }
    }

    /* Lyric translation */
    .lyric-translation { font-size:.83em; color:${c.subtext}; opacity:.55; margin-top:2px; font-style:italic; line-height:1.3; }
    .lyric-translation.hidden { display:none; }

    /* Status */
    .status-msg { display:flex; flex-direction:column; align-items:center; justify-content:center; height:100%; text-align:center; padding:20px; opacity:.6; }
    .status-msg .icon { font-size:36px; margin-bottom:10px; }
    .status-msg .text { font-size:14px; font-weight:500; }
    .spinner { width:28px; height:28px; border:3px solid ${c.main}; border-top-color:${c.accent}; border-radius:50%; animation:spin .7s linear infinite; }
    @keyframes spin { to{transform:rotate(360deg)} }

    /* Vinyl - spin/border-radius live in #staticStyles; only the colored rings are theme-bound here */
    .vinyl .album-art { box-shadow:0 0 0 3px ${c.main}, 0 0 0 5px ${c.highlight}, 0 4px 20px #000; }

    /* Seekbar */
    .seekbar-wrap { display:flex; align-items:center; gap:6px; padding:4px 12px 5px; background:${c.player}; flex-shrink:0; -webkit-app-region:no-drag; app-region:no-drag; }
    .seek-time { font-size:9px; color:${c.subtext}; min-width:26px; font-variant-numeric:tabular-nums; user-select:none; }
    .seek-time.right { text-align:right; }
    .seekbar-rail { position:relative; flex:1; display:flex; align-items:center; }
    .seekbar { -webkit-appearance:none; width:100%; height:3px; border-radius:2px; outline:none; cursor:pointer; background:linear-gradient(to right, ${c.accent} 0%, ${c.accent} var(--progress,0%), ${c.main} var(--progress,0%), ${c.main} 100%); }
    .seekbar::-webkit-slider-thumb { -webkit-appearance:none; width:10px; height:10px; background:${c.accent}; border-radius:50%; cursor:pointer; transition:transform .1s; }
    .seekbar::-webkit-slider-thumb:hover { transform:scale(1.4); }

    /* LoopyLoop markers */
    .loop-mark { position:absolute; top:-11px; font-size:13px; font-weight:700; color:${c.accent}; text-shadow:0 0 8px ${c.accent}; pointer-events:none; transform:translateX(-50%); user-select:none; }
    .pip-ctx-menu { position:absolute; bottom:18px; background:${c.player}; border:1px solid ${c.highlight}; border-radius:8px; padding:3px 0; z-index:200; display:none; min-width:130px; box-shadow:0 6px 20px #000; }
    .pip-ctx-menu.open { display:block; }
    .pip-ctx-menu button { display:block; width:100%; padding:7px 12px; background:none; border:none; color:${c.text}; font-size:12px; font-family:inherit; text-align:left; cursor:pointer; }
    .pip-ctx-menu button:hover { background:${c.highlight}; color:${c.accent}; }

    /* Controls - buttons on top, volume on its own row directly below, bar spanning the
       same width as the button group (volume row inherits the group's width). */
    .controls { display:flex; align-items:center; justify-content:center; padding:7px 12px 9px; background:${c.player}; flex-shrink:0; -webkit-app-region:no-drag; app-region:no-drag; }
    .ctrl-wrap { display:flex; flex-direction:column; align-items:center; gap:8px; max-width:100%; }
    .ctrl-btns { display:flex; align-items:center; justify-content:center; gap:6px; flex-shrink:0; }
    .ctrl-btn { background:${c.main}; border:none; color:${c.text}; width:32px; height:32px; border-radius:50%; cursor:pointer; display:flex; align-items:center; justify-content:center; transition:all .15s; flex-shrink:0; }
    .ctrl-btn:hover { background:${c.highlight}; transform:scale(1.06); }
    .ctrl-btn:active { transform:scale(0.94); }
    .ctrl-btn.play-btn { width:38px; height:38px; background:${c.accent}; color:${c.sidebar}; }
    .ctrl-btn.play-btn:hover { filter:brightness(1.1); transform:scale(1.07); }
    .ctrl-btn.active-btn { color:${c.accent}; }
    .ctrl-btn.hidden { display:none; }
    .vol-inline { display:flex; align-items:center; gap:7px; width:100%; }
    .vol-inline.hidden { display:none; }
    .vol-icon-btn { background:none; border:none; color:${c.subtext}; cursor:pointer; display:flex; align-items:center; padding:2px; transition:color .15s; flex-shrink:0; }
    .vol-icon-btn:hover { color:${c.text}; }
    .vol-bar { -webkit-appearance:none; flex:1 1 auto; width:auto; min-width:0; height:3px; background:${c.main}; border-radius:2px; outline:none; cursor:pointer; }
    .vol-bar::-webkit-slider-thumb { -webkit-appearance:none; width:9px; height:9px; background:${c.accent}; border-radius:50%; cursor:pointer; transition:transform .1s; }
    .vol-bar::-webkit-slider-thumb:hover { transform:scale(1.3); }
    `;
  }

  // 5. Settings popup CSS
  function generateSettingsStyles() {
    const c = getThemeColors();
    return `
    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600&display=swap');
    *, *::before, *::after { margin:0; padding:0; box-sizing:border-box; }
    html, body { height:100%; overflow:hidden; }
    body { font-family:'DM Sans',-apple-system,sans-serif; background:${c.sidebar}; color:${c.text}; display:flex; flex-direction:column; }
    .s-header { padding:13px 15px 10px; border-bottom:1px solid ${c.highlight}; flex-shrink:0; -webkit-app-region:drag; app-region:drag; cursor:grab; }
    .s-title { font-size:14px; font-weight:600; display:block; pointer-events:none; }
    .s-sub   { font-size:9px; color:${c.subtext}; letter-spacing:.6px; text-transform:uppercase; pointer-events:none; }
    .s-content { flex:1; padding:10px 12px; overflow-y:auto; scrollbar-width:none; }
    .s-content::-webkit-scrollbar { display:none; }
    .s-group { margin-bottom:14px; }
    .s-group-title { font-size:9px; font-weight:600; color:${c.subtext}; text-transform:uppercase; letter-spacing:1px; margin-bottom:6px; padding-left:2px; }
    .s-item { display:flex; align-items:center; justify-content:space-between; padding:8px 10px; background:${c.main}; border-radius:8px; margin-bottom:4px; cursor:pointer; transition:background .1s; border:none; width:100%; font-family:inherit; color:inherit; text-align:left; }
    .s-item:hover { background:${c.highlight}; }
    .s-label { font-size:12px; color:${c.btnActive}; }
    .s-note  { font-size:9px; color:${c.subtext}; margin-top:1px; }
    .t { width:36px; height:20px; background:${c.highlight}; border-radius:10px; position:relative; transition:background .2s; flex-shrink:0; pointer-events:none; }
    .t.on { background:${c.accent}; }
    .t::after { content:''; position:absolute; top:2px; left:2px; width:16px; height:16px; background:#fff; border-radius:50%; transition:transform .2s; box-shadow:0 1px 3px #000; }
    .t.on::after { transform:translateX(16px); }
    .s-cycle { background:${c.highlight}; border:none; color:${c.btnActive}; font-size:11px; padding:4px 10px; border-radius:6px; cursor:pointer; font-family:inherit; transition:background .15s, color .15s; min-width:64px; text-align:center; }
    .s-cycle:hover { background:${c.accent}; color:${c.sidebar}; }
    .s-select { background:${c.highlight}; border:1px solid ${c.highlight}; color:${c.btnActive}; font-size:11px; padding:4px 8px; border-radius:6px; cursor:pointer; font-family:inherit; outline:none; max-width:150px; -webkit-app-region:no-drag; app-region:no-drag; }
    .s-select:hover { border-color:${c.accent}; }
    .s-select option { background:${c.player}; color:${c.text}; }
    .s-action { background:${c.highlight}; border:none; color:${c.btnActive}; font-size:11px; padding:4px 10px; border-radius:6px; cursor:pointer; font-family:inherit; transition:background .15s; }
    .s-action:hover { background:${c.accent}; color:${c.sidebar}; }
    .font-ctrl { display:flex; align-items:center; gap:5px; -webkit-app-region:no-drag; app-region:no-drag; }
    .font-ctrl input[type=range] { -webkit-appearance:none; width:76px; height:3px; background:${c.highlight}; border-radius:2px; outline:none; cursor:pointer; }
    .font-ctrl input[type=range]::-webkit-slider-thumb { -webkit-appearance:none; width:10px; height:10px; background:${c.accent}; border-radius:50%; }
    .font-val { font-size:10px; color:${c.subtext}; min-width:26px; text-align:right; }
    `;
  }

  // 6. helpers
  function formatTime(ms) { const s = Math.floor(ms / 1000); return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0'); }
  function escapeHtml(t) { const d = document.createElement('div'); d.textContent = t; return d.innerHTML; }
  function getCurLyricsAlignClass() { return 'align-' + alignLyrics; }

  // 7. lyrics fetch
  async function fetchLyrics(trackUri) {
    try {
      const trackId = trackUri.split(':').pop();
      try {
        const r = await Spicetify.CosmosAsync.get(`https://spclient.wg.spotify.com/color-lyrics/v2/track/${trackId}?format=json&market=from_token`);
        if (r?.lyrics?.lines) return {
          synced: r.lyrics.syncType === 'LINE_SYNCED', wordSync: r.lyrics.lines.some(l => l.syllables?.length > 0),
          lines: r.lyrics.lines.map(l => ({ startTime: parseInt(l.startTimeMs), endTime: parseInt(l.endTimeMs || 0), text: l.words || '', translation: l.translation || null, syllables: l.syllables?.map(s => ({ text: s.text || '', startTime: parseInt(s.startTimeMs || l.startTimeMs), endTime: parseInt(s.endTimeMs || 0) })) || null }))
        };
      } catch (e) {}
      if (Spicetify.Platform?.Lyrics) {
        try { const l = await Spicetify.Platform.Lyrics.getLyrics(trackUri); if (l?.lines) return { synced: true, wordSync: false, lines: l.lines.map(ln => ({ startTime: parseInt(ln.startTimeMs) || 0, endTime: 0, text: ln.words || ln.text || '', translation: null, syllables: null })) }; } catch (e) {}
      }
      try { const a = await Spicetify.CosmosAsync.get(`wg://lyrics/v1/track/${trackId}?format=json&market=from_token`); if (a?.lines) return { synced: true, wordSync: false, lines: a.lines.map(l => ({ startTime: parseInt(l.startTimeMs || l.time || 0), endTime: 0, text: l.words || l.text || '', translation: null, syllables: null })) }; } catch (e) {}
    } catch (e) {}
    return null;
  }

  // 8. LoopyLoop PiP helpers
  function loadPipLoop(uri) {
    if (!uri) { pipLoopStart = null; pipLoopEnd = null; return; }
    try { const raw = Spicetify.LocalStorage.get(LOOP_PREFIX + uri); if (!raw) { pipLoopStart = null; pipLoopEnd = null; return; } const p = JSON.parse(raw); pipLoopStart = p.start; pipLoopEnd = p.end; }
    catch (e) { pipLoopStart = null; pipLoopEnd = null; }
  }
  function savePipLoop(uri) { if (!uri || pipLoopStart === null || pipLoopEnd === null) return; Spicetify.LocalStorage.set(LOOP_PREFIX + uri, JSON.stringify({ start: pipLoopStart, end: pipLoopEnd })); }
  function drawPipLoop() {
    if (!pipWindow || pipWindow.closed) return;
    const doc = pipWindow.document;
    const sM  = doc.getElementById('pipLoopStart'), eM = doc.getElementById('pipLoopEnd');
    if (!sM || !eM) return;
    const active = pipLoopStart !== null && pipLoopEnd !== null;
    sM.style.display = eM.style.display = active ? 'block' : 'none';
    if (active) { sM.style.left = (pipLoopStart * 100) + '%'; eM.style.left = (pipLoopEnd * 100) + '%'; }
  }

  // 9. openPiP
  async function openPiP() {
    if (pipWindow && !pipWindow.closed) { pipWindow.close(); pipWindow = null; return; }
    currentTrackUri = null; lastActiveIdx = -1; lastFxKey = '';
    const savedW = parseInt(localStorage.getItem('vg-lyric-pipwidth'))  || CFG.pipWidth;
    const savedH = parseInt(localStorage.getItem('vg-lyric-pipheight')) || CFG.pipHeight;
    if ('documentPictureInPicture' in window) {
      try { pipWindow = await window.documentPictureInPicture.requestWindow({ width: savedW, height: savedH }); setupPiP(pipWindow); return; } catch (e) {}
    }
    try {
      pipWindow = window.open('about:blank', 'VGLyricsPiP', `width=${savedW},height=${savedH},left=${window.screen.width - savedW - 30},top=30,resizable=yes,scrollbars=no,toolbar=no,menubar=no,location=no,status=no`);
      if (pipWindow) setupPiP(pipWindow);
      else Spicetify.showNotification('Could not open lyrics window.', true);
    } catch (e) { Spicetify.showNotification('Could not open lyrics window', true); }
  }

  // 10. openSettingsWindow
  function openSettingsWindow() {
    if (settingsWindow && !settingsWindow.closed) { settingsWindow.focus(); return; }
    const sw = window.screen.availWidth, sh = window.screen.availHeight;
    try {
      settingsWindow = window.open('about:blank', 'VGLyricsSettings',
        `width=290,height=500,left=${Math.floor((sw - 290) / 2)},top=${Math.floor((sh - 500) / 2)},resizable=no,scrollbars=no,toolbar=no,menubar=no,location=no,status=no`
      );
      if (settingsWindow) setupSettingsWindow(settingsWindow);
      else Spicetify.showNotification('Could not open settings.', true);
    } catch (e) { Spicetify.showNotification('Could not open settings.', true); }
  }

  // 11. setupSettingsWindow
  function setupSettingsWindow(win) {
    const caseLabel  = CASE_LABELS[CASE_OPTIONS.indexOf(textCase)]         || 'Normal';
    const alignLabel = ALIGN_LABELS[ALIGN_OPTIONS.indexOf(alignLyrics)]    || 'Center';

    const tItem = (key, label, on, note) =>
      `<button class="s-item" onclick="var v=window.__vg.toggle('${key}');this.querySelector('.t').classList.toggle('on',v)">` +
      `<span class="s-label">${label}${note ? `<div class="s-note">${note}</div>` : ''}</span>` +
      `<div class="t${on ? ' on' : ''}"></div></button>`;

    // Dropdown list row. fn = bridge method name; opts/labels parallel arrays; cur = current value.
    const sItem = (label, fn, opts, labels, cur) => {
      const optsHtml = opts.map((o, i) => `<option value="${o}"${o === cur ? ' selected' : ''}>${labels[i]}</option>`).join('');
      return `<div class="s-item" style="cursor:default;-webkit-app-region:no-drag">` +
        `<span class="s-label">${label}</span>` +
        `<select class="s-select" onchange="window.__vg.${fn}(this.value)">${optsHtml}</select></div>`;
    };

    const doc = win.document;
    doc.write(`<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
    <title>Lyrics Settings</title>
    <style>${generateSettingsStyles()}</style></head>
    <body>
    <div class="s-header"><span class="s-title">Lyric Miniplayer</span><span class="s-sub">Settings</span></div>
    <div class="s-content">
      <div class="s-group">
        <div class="s-group-title">Display</div>
        ${tItem('lyrics', 'Show Lyrics', showLyrics)}
        ${tItem('trans',  'Translations', showTranslations)}
        ${tItem('faded',  'Faded Lyrics', fadedLyrics)}
        <div class="s-item" style="cursor:default;-webkit-app-region:no-drag">
          <span class="s-label">Font Size</span>
          <div class="font-ctrl"><input type="range" id="fontSlider" min="${CFG.minFontSize}" max="${CFG.maxFontSize}" value="${fontSize}"><span class="font-val" id="fontValue">${fontSize}px</span></div>
        </div>
      </div>
      <div class="s-group">
        <div class="s-group-title">Style</div>
        <div class="s-item" style="cursor:default">
          <span class="s-label">Alignment</span>
          <button class="s-cycle" onclick="var r=window.__vg.cycleAlign();this.textContent=r.label">${alignLabel}</button>
        </div>
        <div class="s-item" style="cursor:default">
          <span class="s-label">Text Case</span>
          <button class="s-cycle" onclick="var r=window.__vg.cycleCase();this.textContent=r.label">${caseLabel}</button>
        </div>
      </div>
      <div class="s-group">
        <div class="s-group-title">Active Effect</div>
        ${sItem('Effect',     'setAnim',    ANIM_OPTIONS,    ANIM_LABELS,    activeAnimation)}
        ${sItem('Applies to', 'setScope',   SCOPE_OPTIONS,   SCOPE_LABELS,   effectScope)}
        ${sItem('Plays on',   'setTrigger', TRIGGER_OPTIONS, TRIGGER_LABELS, effectTrigger)}
      </div>
      <div class="s-group">
        <div class="s-group-title">Visual</div>
        ${tItem('karaoke', 'Karaoke Mode',  karaokeMode)}
        ${tItem('vinyl',   'Vinyl Effect',   vinylEffect)}
      </div>
      <div class="s-group">
        <div class="s-group-title">Controls</div>
        ${tItem('shuffle', 'Shuffle Button',  showShuffleBtn)}
        ${tItem('repeat',  'Repeat Button',   showRepeatBtn)}
        ${tItem('like',    'Like Button',     showLikeBtn)}
        ${tItem('vol',     'Volume Slider',   showVolumeSlider)}
        ${tItem('close',   'Close Button',    showCloseBtn)}
      </div>
      <div class="s-group">
        <div class="s-group-title">Integrations</div>
        ${tItem('loopctrl', 'LoopyLoop Controls', showLoopCtrl)}
        <div class="s-item" style="cursor:default">
          <span class="s-label">Vantagraph Custom</span>
          <button class="s-action" onclick="window.__vg.openVgSettings()">Open</button>
        </div>
      </div>
    </div>
    <script>
    document.getElementById('fontSlider').addEventListener('input', function() {
      var v = parseInt(this.value);
      document.getElementById('fontValue').textContent = v + 'px';
      window.__vg.setFont(v);
    });
    <\/script>
    </body></html>`);
    doc.close();

    // Bridge - assign AFTER doc.close so document.open() can't wipe it.
    // Methods close over extension scope, so they mutate the real state + live PiP DOM.
    win.__vg = {
      toggle(key) {
        const pd = (pipWindow && !pipWindow.closed) ? pipWindow.document : null;
        const $  = id => pd?.getElementById(id);
        const map = {
          lyrics:   () => { showLyrics = !showLyrics;             $('lyricsContainer')?.classList.toggle('collapsed', !showLyrics);                                                lss('showlyrics',  showLyrics);       return showLyrics; },
          trans:    () => { showTranslations = !showTranslations;  pd?.querySelectorAll('.lyric-translation').forEach(e => e.classList.toggle('hidden', !showTranslations));        lss('showtrans',   showTranslations); return showTranslations; },
          faded:    () => { fadedLyrics = !fadedLyrics; lastActiveIdx = -1;                                                                                                         lss('faded',       fadedLyrics);      return fadedLyrics; },
          karaoke:  () => { karaokeMode = !karaokeMode;            pd?.body.classList.toggle('karaoke', karaokeMode); $('karaokeHint')?.classList.toggle('hidden', !karaokeMode);   lss('karaoke',     karaokeMode);      return karaokeMode; },
          vinyl:    () => { vinylEffect = !vinylEffect;            pd?.body.classList.toggle('vinyl',   vinylEffect);                                                               lss('vinyl',       vinylEffect);      return vinylEffect; },
          shuffle:  () => { showShuffleBtn = !showShuffleBtn;      $('shuffleBtn')?.classList.toggle('hidden', !showShuffleBtn);                                                   lss('showshuffle', showShuffleBtn);   return showShuffleBtn; },
          repeat:   () => { showRepeatBtn = !showRepeatBtn;        $('repeatBtn')?.classList.toggle('hidden', !showRepeatBtn);                                                     lss('showrepeat',  showRepeatBtn);    return showRepeatBtn; },
          like:     () => { showLikeBtn = !showLikeBtn;            $('likeBtn')?.classList.toggle('hidden', !showLikeBtn);                                                         lss('showlike',    showLikeBtn);      return showLikeBtn; },
          vol:      () => { showVolumeSlider = !showVolumeSlider;  $('volInline')?.classList.toggle('hidden', !showVolumeSlider);                                                  lss('showvol',     showVolumeSlider); return showVolumeSlider; },
          close:    () => { showCloseBtn = !showCloseBtn;          $('closeBtn')?.classList.toggle('hidden', !showCloseBtn);                                                       lss('showclose',   showCloseBtn);     return showCloseBtn; },
          loopctrl: () => { showLoopCtrl = !showLoopCtrl;                                                                                                                          lss('loopctrl',    showLoopCtrl);     return showLoopCtrl; },
        };
        return map[key]?.();
      },
      setAnim(v)    { activeAnimation = v; lss('anim',      v); lastFxKey = ''; },
      setScope(v)   { effectScope     = v; lss('fxscope',   v); lastFxKey = ''; },
      setTrigger(v) { effectTrigger   = v; lss('fxtrigger', v); lastFxKey = ''; },
      cycleCase() {
        const idx = (CASE_OPTIONS.indexOf(textCase) + 1) % CASE_OPTIONS.length;
        textCase = CASE_OPTIONS[idx]; lss('textcase', textCase);
        if (pipWindow && !pipWindow.closed) {
          const lw = pipWindow.document.getElementById('lyricsContainer');
          CASE_OPTIONS.forEach(c => lw?.classList.remove('case-' + c));
          if (textCase !== 'none') lw?.classList.add('case-' + textCase);
        }
        return { label: CASE_LABELS[idx] };
      },
      cycleAlign() {
        const idx = (ALIGN_OPTIONS.indexOf(alignLyrics) + 1) % ALIGN_OPTIONS.length;
        alignLyrics = ALIGN_OPTIONS[idx]; lss('align', alignLyrics);
        if (pipWindow && !pipWindow.closed) {
          const lw = pipWindow.document.getElementById('lyricsContainer');
          ALIGN_OPTIONS.forEach(a => lw?.classList.remove('align-' + a));
          lw?.classList.add('align-' + alignLyrics);
        }
        return { label: ALIGN_LABELS[idx] };
      },
      setFont(v) {
        fontSize = v; lss('fontsize', v);
        if (pipWindow && !pipWindow.closed) pipWindow.document.querySelectorAll('.lyric').forEach(el => el.style.fontSize = v + 'px');
      },
      openVgSettings() {
        if (typeof window.__vgOpenSettings === 'function') window.__vgOpenSettings();
        else Spicetify.showNotification('Open Profile Menu → Vantagraph to access settings');
      },
    };

    win.addEventListener('pagehide', () => { settingsWindow = null; });
  }

  // 12. setupPiP
  function setupPiP(win) {
    const doc     = win.document;
    const curVol  = Math.round((Spicetify.Player.getVolume() || 0) * 100);
    const isMuted = Spicetify.Player.getMute();
    const dur     = Spicetify.Player.getDuration() || 0;
    const prog    = Spicetify.Player.getProgress() || 0;
    const playing = Spicetify.Player.isPlaying();
    const liked   = !!Spicetify.Player.getHeart?.();

    const iPlay    = makeIconHtml('bottombar-play.svg',     P.play,    16);
    const iPrev    = makeIconHtml('bottombar-previous.svg', P.prev,    14);
    const iNext    = makeIconHtml('bottombar-nextsong.svg', P.next,    14);
    const iShuffle = makeIconHtml('bottombar-shuffle.svg',  P.shuffle, 14);
    const iRepeat  = makeIconHtml('bottombar-repeat.svg',   P.repeat,  14);
    const iVolInit = makeVolIconHtml(curVol, isMuted);
    const iGear    = `<svg viewBox="0 0 16 16" width="13" height="13" fill="currentColor">${P.gear}</svg>`;
    const iMini    = `<svg viewBox="0 0 16 16" width="13" height="13" fill="currentColor">${P.mini}</svg>`;

    const bodyClass   = [karaokeMode ? 'karaoke' : '', vinylEffect ? 'vinyl' : ''].filter(Boolean).join(' ');
    const lyricsClass = `lyrics-wrap ${showLyrics ? '' : 'collapsed'} ${getCurLyricsAlignClass()} ${textCase !== 'none' ? 'case-' + textCase : ''}`;

    doc.write(`<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
    <meta name="viewport" content="width=device-width,initial-scale=1.0">
    <title>♫ Vantagraph Lyrics</title>
    <style id="staticStyles">${generateStaticStyles()}</style>
    <style id="themeStyles">${generateStyles()}</style></head>
    <body class="${bodyClass}">

    <div class="karaoke-hint ${karaokeMode ? '' : 'hidden'}" id="karaokeHint">♪ Sing along!</div>

    <div class="header">
      <img class="album-art ${!playing ? 'spin-paused' : ''}" id="albumArt" src="" alt="">
      <div class="track-info">
        <div class="track-title" id="trackTitle">Loading...</div>
        <div class="track-artist-row">
          <div class="track-artist" id="trackArtist">-</div>
          <button class="like-flat ${liked ? 'liked' : ''} ${showLikeBtn ? '' : 'hidden'}" id="likeBtn" title="Like">
            <svg viewBox="0 0 16 16" width="13" height="13" fill="currentColor" id="likeIcon">${liked ? P.heartFill : P.heartOut}</svg>
          </button>
        </div>
      </div>
      <div class="header-btns">
        <button class="icon-btn" id="miniBtn" title="Mini bar mode">${iMini}</button>
        <button class="icon-btn" id="menuBtn" title="Settings">${iGear}</button>
        <button class="close-btn ${showCloseBtn ? '' : 'hidden'}" id="closeBtn" title="Close">×</button>
      </div>
    </div>

    <div class="${lyricsClass}" id="lyricsContainer"><div class="status-msg"><div class="spinner"></div></div></div>

    <div class="seekbar-wrap">
      <span class="seek-time" id="seekCurrent">${formatTime(prog)}</span>
      <div class="seekbar-rail" id="seekbarRail">
        <input type="range" class="seekbar" id="seekbar" min="0" max="${dur}" value="${prog}">
        <div class="loop-mark" id="pipLoopStart" style="display:none">[</div>
        <div class="loop-mark" id="pipLoopEnd"   style="display:none">]</div>
        <div class="pip-ctx-menu" id="pipCtxMenu">
          <button id="pipCtxSetStart">Set loop start</button>
          <button id="pipCtxSetEnd">Set loop end</button>
          <button id="pipCtxReset">Clear loop</button>
        </div>
      </div>
      <span class="seek-time right" id="seekTotal">${formatTime(dur)}</span>
    </div>

    <div class="controls">
      <div class="ctrl-wrap">
        <div class="ctrl-btns">
          <button class="ctrl-btn ${showShuffleBtn ? '' : 'hidden'}" id="shuffleBtn" title="Shuffle">${iShuffle}</button>
          <button class="ctrl-btn" id="prevBtn" title="Previous">${iPrev}</button>
          <button class="ctrl-btn play-btn" id="playBtn" title="Play/Pause">${iPlay}</button>
          <button class="ctrl-btn" id="nextBtn" title="Next">${iNext}</button>
          <button class="ctrl-btn ${showRepeatBtn ? '' : 'hidden'}" id="repeatBtn" title="Repeat">${iRepeat}</button>
        </div>
        <div class="vol-inline ${showVolumeSlider ? '' : 'hidden'}" id="volInline">
          <button class="vol-icon-btn" id="volumeIconWrap">${iVolInit}</button>
          <input type="range" class="vol-bar" id="volumeSlider" min="0" max="100" value="${isMuted ? 0 : curVol}">
        </div>
      </div>
    </div>
    </body></html>`);
    doc.close();

    const $ = (id) => doc.getElementById(id);

    // header
    $('closeBtn').onclick = () => win.close();
    $('menuBtn').onclick  = (e) => { e.stopPropagation(); openSettingsWindow(); };
    $('miniBtn').onclick  = (e) => { e.stopPropagation(); document.dispatchEvent(new CustomEvent('vg-toggle-taskbar')); };

    // like
    $('likeBtn').onclick = () => Spicetify.Player.toggleHeart();

    // playback
    $('prevBtn').onclick    = () => Spicetify.Player.back();
    $('playBtn').onclick    = () => Spicetify.Player.togglePlay();
    $('nextBtn').onclick    = () => Spicetify.Player.next();
    $('shuffleBtn').onclick = () => { Spicetify.Player.toggleShuffle(); $('shuffleBtn').classList.toggle('active-btn', !!Spicetify.Player.getShuffle?.()); };
    $('shuffleBtn').classList.toggle('active-btn', !!Spicetify.Player.getShuffle?.());

    const iRepeatLocal = iRepeat;
    function updateRepeatBtn() {
      const btn = $('repeatBtn'); if (!btn) return;
      const mode = Spicetify.Player.getRepeat?.() ?? 0;
      btn.classList.toggle('active-btn', mode > 0);
      btn.innerHTML = mode === 2 ? makeIconHtml('bottombar-repeat-once.svg', P.repeatOne, 14) : iRepeatLocal;
    }
    $('repeatBtn').onclick = () => { Spicetify.Player.setRepeat?.((Spicetify.Player.getRepeat?.() + 1) % 3); updateRepeatBtn(); };
    updateRepeatBtn();

    // seekbar
    let seeking = false;
    $('seekbar').addEventListener('input',  () => { seeking = true; $('seekCurrent').textContent = formatTime(parseInt($('seekbar').value)); });
    $('seekbar').addEventListener('change', () => { Spicetify.Player.seek(parseInt($('seekbar').value)); seeking = false; });

    // LoopyLoop right-click
    $('seekbarRail').addEventListener('contextmenu', (e) => {
      if (!showLoopCtrl) return;
      e.preventDefault(); e.stopPropagation();
      const { left, width } = $('seekbar').getBoundingClientRect();
      pipCtxPct = Math.max(0, Math.min(1, (e.clientX - left) / width));
      const menu = $('pipCtxMenu');
      menu.style.left = Math.max(5, Math.min(80, pipCtxPct * 100)) + '%';
      menu.classList.add('open');
    });
    const curUri = () => Spicetify.Player.data?.item?.uri;
    $('pipCtxSetStart').onclick = () => { pipLoopStart = pipCtxPct; if (pipLoopEnd === null || pipLoopStart >= pipLoopEnd) pipLoopEnd = 0.99; drawPipLoop(); savePipLoop(curUri()); $('pipCtxMenu').classList.remove('open'); };
    $('pipCtxSetEnd').onclick   = () => { pipLoopEnd = pipCtxPct; if (pipLoopStart === null || pipLoopEnd <= pipLoopStart) pipLoopStart = 0; drawPipLoop(); savePipLoop(curUri()); $('pipCtxMenu').classList.remove('open'); };
    $('pipCtxReset').onclick    = () => { pipLoopStart = null; pipLoopEnd = null; const u = curUri(); if (u) Spicetify.LocalStorage.remove(LOOP_PREFIX + u); drawPipLoop(); $('pipCtxMenu').classList.remove('open'); };
    doc.addEventListener('click', () => $('pipCtxMenu').classList.remove('open'));
    loadPipLoop(curUri()); drawPipLoop();

    // volume
    $('volumeSlider').oninput = (e) => {
      const v = parseInt(e.target.value);
      Spicetify.Player.setVolume(v / 100);
      if (Spicetify.Player.getMute()) Spicetify.Player.setMute(false);
      $('volumeIconWrap').innerHTML = makeVolIconHtml(v, false);
    };
    $('volumeSlider').addEventListener('wheel', (e) => {
      e.preventDefault();
      const v = Math.max(0, Math.min(1, Spicetify.Player.getVolume() + (e.deltaY < 0 ? 1 : -1) * 0.02));
      Spicetify.Player.setVolume(v);
      if (Spicetify.Player.getMute() && v > 0) Spicetify.Player.setMute(false);
    }, { passive: false });
    $('volumeIconWrap').onclick = () => Spicetify.Player.toggleMute();

    // lyric click → seek
    $('lyricsContainer').onclick = (e) => { const el = e.target.closest('.lyric'); if (el?.dataset.time) Spicetify.Player.seek(parseInt(el.dataset.time)); };

    // size persistence
    win.addEventListener('resize', () => { localStorage.setItem('vg-lyric-pipwidth', String(win.innerWidth)); localStorage.setItem('vg-lyric-pipheight', String(win.innerHeight)); });
    win._vgSeeking = () => seeking;
    win.addEventListener('pagehide', () => { pipWindow = null; lastActiveIdx = -1; if (settingsWindow && !settingsWindow.closed) { settingsWindow.close(); settingsWindow = null; } });

    async function initLoad() {
      const track = Spicetify.Player.data?.item;
      if (track?.uri) { currentTrackUri = track.uri; await loadLyrics(track.uri); }
      else setTimeout(initLoad, 200);
    }
    updatePipContent();
    initLoad();
    startUpdateLoop();
  }

  // 13. content updates
  function updatePipContent() {
    if (!pipWindow || pipWindow.closed) return;
    const doc   = pipWindow.document;
    const data  = Spicetify.Player.data;
    if (!data?.item) return;
    const track  = data.item;
    const title  = doc.getElementById('trackTitle');
    const artist = doc.getElementById('trackArtist');
    const art    = doc.getElementById('albumArt');
    if (title)  title.textContent  = track.name || 'Unknown';
    if (artist) artist.textContent = track.artists?.map(a => a.name).join(', ') || 'Unknown';
    if (art)    art.src = track.album?.images?.[0]?.url || track.metadata?.image_url || '';
    updatePipPlayButton();
    updatePipVolume();
    if (track.uri !== currentTrackUri) {
      currentTrackUri = track.uri; lastActiveIdx = -1; lastFxKey = '';
      loadLyrics(track.uri);
      loadPipLoop(track.uri); drawPipLoop();
      const liked = !!Spicetify.Player.getHeart?.();
      doc.getElementById('likeBtn')?.classList.toggle('liked', liked);
      const likeIcon = doc.getElementById('likeIcon');
      if (likeIcon) likeIcon.innerHTML = liked ? P.heartFill : P.heartOut;
      const seekbar = doc.getElementById('seekbar'), seekTotal = doc.getElementById('seekTotal');
      const d = Spicetify.Player.getDuration() || 0;
      if (seekbar) seekbar.max = d; if (seekTotal) seekTotal.textContent = formatTime(d);
      // Vinyl no longer needs a reflow on song change - the spin lives in #staticStyles which the
      // theme observer never rewrites, and an <img> src swap doesn't reset a CSS animation.
    }
  }

  function updatePipPlayButton() {
    if (!pipWindow || pipWindow.closed) return;
    const playBtn = pipWindow.document.getElementById('playBtn');
    const art     = pipWindow.document.getElementById('albumArt');
    const playing = Spicetify.Player.isPlaying();
    if (playBtn) playBtn.innerHTML = makeIconHtml(playing ? 'bottombar-pause.svg' : 'bottombar-play.svg', playing ? P.pause : P.play, 16);
    if (art) art.classList.toggle('spin-paused', !playing);
  }

  function updatePipVolume() {
    if (!pipWindow || pipWindow.closed) return;
    const doc    = pipWindow.document;
    const slider = doc.getElementById('volumeSlider'), wrap = doc.getElementById('volumeIconWrap');
    if (!slider || !wrap || doc.activeElement === slider) return;
    const isMuted = Spicetify.Player.getMute();
    const v = Math.round((Spicetify.Player.getVolume() || 0) * 100);
    slider.value = isMuted ? 0 : v;
    wrap.innerHTML = makeVolIconHtml(v, isMuted);
  }

  // 14. load lyrics
  async function loadLyrics(uri) {
    if (!pipWindow || pipWindow.closed) return;
    const loading = pipWindow.document.getElementById('lyricsContainer');
    if (loading) loading.innerHTML = '<div class="status-msg"><div class="spinner"></div></div>';

    currentLyrics = await fetchLyrics(uri);
    lastActiveIdx = -1; lastFxKey = '';

    const hasLines = !!currentLyrics?.lines?.some(l => l.text?.trim());

    if (!pipWindow || pipWindow.closed) return;
    const container = pipWindow.document.getElementById('lyricsContainer');
    if (!container) return;
    if (!hasLines) { container.innerHTML = '<div class="status-msg"><div class="icon">🎵</div><div class="text">No lyrics available</div></div>'; return; }

    const filtered = currentLyrics.lines.filter(l => l.text?.trim());
    let html = '';
    for (let i = 0; i < filtered.length; i++) {
      const l = filtered[i];
      let lineContent;
      if (l.syllables?.length) {
        // True per-syllable timestamps from the API
        lineContent = l.syllables.map(s => `<span class="lyric-word" data-start="${s.startTime}" data-end="${s.endTime}">${escapeHtml(s.text)}</span>`).join('');
      } else {
        // Derive word timings: distribute across line span. End is line end if present,
        // otherwise next line start, otherwise +3s - so karaoke advances word-by-word.
        const words   = l.text.split(/(\s+)/);
        const wordCnt = words.filter(w => w.trim()).length;
        const lineEnd = (l.endTime && l.endTime > l.startTime)
          ? l.endTime
          : (filtered[i + 1]?.startTime > l.startTime ? filtered[i + 1].startTime : l.startTime + 3000);
        const wDur = wordCnt > 0 ? Math.min((lineEnd - l.startTime) / wordCnt, MAX_WORD_MS) : 0;
        let wi = 0;
        lineContent = words.map(w => {
          if (!w.trim()) return w;
          const ws = l.startTime + wi * wDur; wi++;
          return `<span class="lyric-word" data-start="${Math.round(ws)}" data-end="${Math.round(ws + wDur)}">${escapeHtml(w)}</span>`;
        }).join('');
      }
      const trans = l.translation ? `<div class="lyric-translation ${showTranslations ? '' : 'hidden'}">${escapeHtml(l.translation)}</div>` : '';
      html += `<div class="lyric" data-time="${l.startTime}" style="font-size:${fontSize}px">${lineContent}${trans}</div>`;
    }
    container.innerHTML = html || '<div class="status-msg"><div class="icon">🎶</div><div class="text">Instrumental</div></div>';
  }

  // 15. rAF sync
  // Assign the active-effect animation classes to the right elements (scope) on the right
  // line (trigger). Only called when the resulting target changes, so running animations
  // are never restarted mid-play.
  function applyEffects(allLines, activeIdx) {
    const ANIM_CLS = ANIM_OPTIONS.map(a => 'vgfx-' + a);
    allLines.forEach(line => {
      line.classList.remove('vgfx-once', ...ANIM_CLS);
      line.querySelectorAll('.lyric-word').forEach(w => { w.classList.remove('vgfx-once', ...ANIM_CLS); w.style.removeProperty('--wd'); });
    });
    if (activeIdx < 0) return;

    let targets;
    if (effectScope === 'all')          targets = allLines.map((_, i) => i);
    else if (effectTrigger === 'next')  targets = [activeIdx + 1];
    else                                targets = [activeIdx]; // active / entrance

    const cls  = 'vgfx-' + activeAnimation;
    const once = effectTrigger === 'entrance';
    targets.forEach(i => {
      const line = allLines[i]; if (!line) return;
      if (effectScope === 'word') {
        line.querySelectorAll('.lyric-word').forEach((w, wi) => { w.classList.add(cls); if (once) w.classList.add('vgfx-once'); w.style.setProperty('--wd', (wi * 60) + 'ms'); });
      } else {
        line.classList.add(cls); if (once) line.classList.add('vgfx-once');
      }
    });
  }

  function updateCurrentLyric() {
    if (!pipWindow || pipWindow.closed || !currentLyrics?.synced) return;
    const doc     = pipWindow.document;
    const rawTime = Spicetify.Player.getProgress() || 0;
    const curTime = rawTime + LYRIC_LEAD;      // line detection runs slightly ahead
    const lines   = currentLyrics.lines.filter(l => l.text?.trim());
    let activeIdx = -1;
    for (let i = lines.length - 1; i >= 0; i--) { if (curTime >= lines[i].startTime) { activeIdx = i; break; } }
    const playing = Spicetify.Player.isPlaying();

    const allLines = [...doc.querySelectorAll('.lyric')];
    allLines.forEach((el, idx) => {
      const shouldActive = idx === activeIdx;
      const wasActive    = el.classList.contains('active');

      // active/past + autoscroll (on change only)
      if (shouldActive !== wasActive) {
        el.classList.remove('active', 'past');
        if (shouldActive) {
          el.classList.add('active');
          if (playing) el.scrollIntoView({ behavior: 'smooth', block: 'center' });
        } else if (idx < activeIdx) {
          el.classList.add('past');
        }
      } else if (!shouldActive) {
        el.classList.toggle('past', idx < activeIdx);
      }

      // Karaoke word fill - uses RAW time (no lead) so the first word lands on the beat,
      // not 150ms early. Current word glows, prior words stay lit. Karaoke mode only.
      const words = el.querySelectorAll('.lyric-word');
      if (karaokeMode && shouldActive) {
        let curWord = -1;
        words.forEach((w, wi) => { if (rawTime >= parseInt(w.dataset.start || 0)) curWord = wi; });
        words.forEach((w, wi) => { w.classList.toggle('spoken', wi <= curWord); w.classList.toggle('current', wi === curWord); });
      } else if (karaokeMode && idx < activeIdx) {
        words.forEach(w => { w.classList.add('spoken'); w.classList.remove('current'); });
      } else {
        words.forEach(w => { w.classList.remove('spoken', 'current'); });
      }

      // Distance-based fade: show only ±2 lines, rest hidden. Inline beats CSS; cleared when off.
      if (shouldActive) {
        el.style.opacity = '';
      } else if (fadedLyrics && activeIdx >= 0) {
        const dist = Math.abs(idx - activeIdx);
        el.style.opacity = dist === 1 ? '0.4' : dist === 2 ? '0.14' : '0';
      } else {
        el.style.opacity = '';
      }
    });

    // Effect classes - recompute only when the target actually changes (key-diffed),
    // so loops keep playing. 'all' scope omits the index so it applies once and never restarts.
    const fxKey = effectScope === 'all'
      ? `all|${activeAnimation}`
      : `${effectScope}|${effectTrigger}|${activeAnimation}|${effectTrigger === 'next' ? activeIdx + 1 : activeIdx}`;
    if (fxKey !== lastFxKey) { applyEffects(allLines, activeIdx); lastFxKey = fxKey; }

    lastActiveIdx = activeIdx;
  }

  function updateSeekbar() {
    if (!pipWindow || pipWindow.closed || pipWindow._vgSeeking?.()) return;
    const doc = pipWindow.document;
    const bar = doc.getElementById('seekbar'), cur = doc.getElementById('seekCurrent');
    if (!bar) return;
    const prog = Spicetify.Player.getProgress() || 0, dur = Spicetify.Player.getDuration() || 0;
    bar.max = dur; bar.value = prog;
    if (cur) cur.textContent = formatTime(prog);
    bar.style.setProperty('--progress', dur > 0 ? ((prog / dur) * 100).toFixed(2) + '%' : '0%');
  }

  function startUpdateLoop() {
    if (rafId) cancelAnimationFrame(rafId);
    function loop() {
      if (!pipWindow || pipWindow.closed) { rafId = null; return; }
      updateCurrentLyric(); updatePipPlayButton(); updateSeekbar();
      rafId = requestAnimationFrame(loop);
    }
    rafId = requestAnimationFrame(loop);
  }

  // 16. live theme refresh - ONLY when colors actually change.
  // Spotify mutates documentElement.style frequently (color extraction, vars). Rewriting the
  // PiP <style> on every mutation restarts all CSS animations from frame 0, so effects never
  // visibly play. Diffing the resolved theme colors avoids needless rewrites.
  let lastThemeKey = '';
  const themeObserver = new MutationObserver(() => {
    const key = JSON.stringify(getThemeColors());
    if (key === lastThemeKey) return;
    lastThemeKey = key;
    if (pipWindow && !pipWindow.closed) { const el = pipWindow.document.getElementById('themeStyles'); if (el) el.textContent = generateStyles(); }
    if (settingsWindow && !settingsWindow.closed) { const sEl = settingsWindow.document.querySelector('style'); if (sEl) sEl.textContent = generateSettingsStyles(); }
  });
  themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['style'] });

  // 17. topbar - single button
  // own button icon, embedded (source: src/assets/icons/vantagraph-miniplayer.svg)
  const LYRIC_ICON = '<svg data-encore-id="icon" role="img" aria-hidden="true" viewBox="0 0 32 31.1" fill="currentColor" style="--encore-icon-height: var(--encore-graphic-size-decorative-smaller); --encore-icon-width: var(--encore-graphic-size-decorative-smaller);"><path d="M13.6,12.93l.02,12.62c0,1.62-.46,3.12-1.71,4.2-1.72,1.6-4.37,1.8-6.3.47-1.56-1.08-2.43-2.82-2.28-4.71.13-1.58,1.02-2.98,2.22-3.8,1.44-.99,3.14-1.13,4.74-.59V4.87c.01-.91.67-1.49,1.48-1.66L26.68.03c.54-.11,1.06.12,1.42.42.4.33.54.8.54,1.35l.05,20.15c0,2.35-1.05,4.47-3.34,5.39-1.23.49-2.73.48-3.97-.06-2.82-1.24-3.99-4.52-2.58-7.24,1.24-2.35,4.04-3.4,6.56-2.43v-7.2s-11.75,2.52-11.75,2.52ZM25.34,7.03v-3.22s-11.74,2.53-11.74,2.53v3.22s11.74-2.53,11.74-2.53ZM25.35,22.48c0-1.05-.85-1.91-1.91-1.91s-1.91.85-1.91,1.91.85,1.91,1.91,1.91,1.91-.85,1.91-1.91ZM10.3,25.96c0-1.01-.82-1.84-1.84-1.84s-1.84.82-1.84,1.84.82,1.84,1.84,1.84,1.84-.82,1.84-1.84Z"/></svg>';
  const lyricBtn = new Spicetify.Topbar.Button('Lyric Miniplayer', LYRIC_ICON, openPiP, false, true);
  if (lyricBtn.element) lyricBtn.element.classList.add('vg-topbar-btn');

  // vantagraph-custom-taskbarplayer.js expand button signals us to open the full PiP
  document.addEventListener('vg-open-pip', () => openPiP());

  // 18. player listeners
  Spicetify.Player.addEventListener('songchange', () => { updatePipContent(); });
  Spicetify.Player.addEventListener('onplaypause', () => { updatePipPlayButton(); });
})();
