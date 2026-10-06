#!/usr/bin/env bash
# The README's screenshots and GIFs, shot in the demo stand (scripts/demo/rig.sh) — see SHOTLIST.md.
#
#   scripts/demo/shots.sh                 every automatic shot
#   scripts/demo/shots.sh ID…             some of them (pixel-dark, macos-dock, installer, …)
#   scripts/demo/shots.sh --list
#
# Raw recordings land in $DEMO_RAW (default /tmp/angelos-demo-raw), the results in docs/.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
RIG="$ROOT/scripts/demo/rig.sh" GIF="$ROOT/scripts/demo/gif.sh"
RAW="${DEMO_RAW:-/tmp/angelos-demo-raw}"; mkdir -p "$RAW"
SHOTS="$ROOT/docs/screenshots" DEMO="$ROOT/docs/demo"
CURRENT=""

say() { printf '♡ %s\n' "$*"; }
ipc() { "$RIG" ipc "$@" >/dev/null 2>&1 || true; }
act() { "$RIG" niri action "$@" >/dev/null 2>&1 || true; }
screen() { "$RIG" niri -j focused-output 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["name"])'; }

# a fresh stand for every shot (nothing left over from the one before)
stand() { # theme palette
  "$RIG" stop >/dev/null 2>&1 || true
  "$RIG" start "$1" "$2" >/dev/null
  CURRENT="$1/$2"
  sleep 3
  # the plugins' own default widgets (Codex/Claude limits) say "not found" on a machine without
  # them: off for the pictures, the README shows them in the plugin table
  ipc widget plugin:codex-companion ""
  sleep 1
}

# record SECONDS NAME, while the scene (a function) runs; then the GIF
record() { # seconds name scene [width]
  local secs="$1" name="$2" scene="$3" width="${4:-960}"
  "$RIG" rec "$RAW/$name.mp4" "$secs" &
  local rec=$!
  sleep 1
  "$scene"
  wait "$rec" || true
  "$GIF" "$RAW/$name.mp4" "$DEMO/$name.gif" "$width" 12
}

widgets_on() { # the desktop widgets of the README's desktop
  local s; s="$(screen)"
  for w in "$@"; do ipc widget "$w" "$s"; done
}

terminal() { # a kitty with fastfetch, floating in the lower right (the widgets stay in sight)
  "$RIG" run kitty -o update_check_interval=0 --title angel -e fish -c 'fastfetch; read -P ""'
  sleep 3
  act toggle-window-floating; act set-window-width 980; act set-window-height 560
  act move-floating-window -x 820 -y 380
  sleep 1.5
}

# ── screenshots ───────────────────────────────────────────────────────────────

shot_pixel_dark() {
  stand pixel dark; ipc flavor overdose; widgets_on clock sysmon nowplaying; terminal
  "$RIG" shot "$SHOTS/pixel-dark.png"
}
shot_pixel_light() {
  stand pixel light; ipc flavor bubblegum; widgets_on clock sysmon nowplaying; terminal
  ipc startMenu ""; sleep 1.5
  "$RIG" shot "$SHOTS/pixel-light.png"; ipc startMenu ""
}
shot_macos_light() {
  stand macos light; widgets_on clock sysmon; "$RIG" run nautilus; sleep 3
  "$RIG" shot "$SHOTS/macos-light.png"
}
shot_macos_dark() {
  stand macos dark; "$RIG" run nautilus; sleep 3
  ipc macPanel cc; sleep 1.5
  "$RIG" shot "$SHOTS/macos-dark.png"; ipc macPanel ""
}
shot_sddm_login() {
  stand pixel dark
  # the greeter lists the machine's users and remembers the last one: here it sees only "angel"
  local fake; fake="$(mktemp -d)"
  printf 'root:x:0:0::/root:/bin/bash\nangel:x:%s:%s:angel:/home/angel:/bin/bash\n' "$(id -u)" "$(id -g)" >"$fake/passwd"
  printf '[Last]\nUser=angel\nSession=niri.desktop\n' >"$fake/state.conf"
  "$RIG" run bwrap --dev-bind / / --ro-bind "$fake/passwd" /etc/passwd --tmpfs /var/lib/sddm \
    --ro-bind "$fake/state.conf" /var/lib/sddm/state.conf \
    sddm-greeter-qt6 --test-mode --theme "$ROOT/sddm/themes/pixel-cyberpunk"
  sleep 8; act focus-window-down; act maximize-column; act fullscreen-window; sleep 3
  "$RIG" shot "$SHOTS/sddm-login.png"
  act close-window; rm -rf "$fake"
}

# ── GIFs ──────────────────────────────────────────────────────────────────────

scene_pixel_desktop() {
  terminal; ipc ws 2; sleep 1; terminal; ipc ws 3; sleep 1; ipc ws 1; sleep 1
  ipc theme toggle; sleep 2; ipc theme toggle; sleep 2
  for f in bubblegum cyberangel overdose; do ipc flavor "$f"; sleep 1.5; done
}
gif_pixel_desktop() { stand pixel dark; widgets_on clock sysmon nowplaying; record 16 pixel-desktop scene_pixel_desktop; }

scene_wallpaper() {
  local h; h="$(cat "/run/user/$(id -u)/angelos-demo/state/home")"
  ipc wallpaper "$h/Pictures/angelos-demo-light.png"; sleep 3
  ipc wallpaper "$h/Pictures/angelos-demo-dark.png"; sleep 3
}
gif_wallpaper() { stand pixel dark; record 8 wallpaper scene_wallpaper; }

scene_menu() {
  local s; s="$(screen)"
  ipc desktopMenu "$s" 700 400 ""; sleep 2
  ipc desktopMenu "$s" 700 400 view; sleep 3
}
gif_menu() { stand pixel dark; record 7 menu scene_menu; }

scene_launcher() {
  ipc launcherText "kit"; sleep 2; ipc launcherText "web niri"; sleep 2.5; ipc launcherText "> uname -a"; sleep 2.5
  ipc launcher; sleep 1
}
gif_launcher() { stand pixel dark; record 10 launcher scene_launcher; }

scene_settings() {
  for p in appearance bar widgets windows defaults; do ipc settings "$p"; sleep 2.5; done
}
gif_settings() { stand pixel dark; record 15 settings scene_settings; }

scene_tips() { ipc tour; sleep 2.5; for _ in 1 2 3 4 5; do ipc tourNext; sleep 2.2; done; ipc tourStop; }
gif_tips() { stand pixel dark; record 16 tips scene_tips; }

scene_tiling() {
  for _ in 1 2 3; do "$RIG" run kitty -o update_check_interval=0; sleep 1.2; done
  act focus-column-left; sleep 1; act focus-column-left; sleep 1
  act switch-preset-column-width; sleep 1; act center-column; sleep 1
  act consume-or-expel-window-right; sleep 1; act toggle-column-tabbed-display; sleep 1.5
  act toggle-column-tabbed-display; act toggle-window-floating; sleep 1.5; act toggle-window-floating
}
gif_tiling() { stand pixel dark; record 15 tiling scene_tiling 800; }

scene_overview() { "$RIG" run kitty -o update_check_interval=0; sleep 1; ipc ws 2; "$RIG" run kitty -o update_check_interval=0; sleep 1; ipc ws 1; act toggle-overview; sleep 3; act toggle-overview; }
gif_overview() { stand pixel dark; record 9 overview scene_overview; }

scene_hotkeys() { act show-hotkey-overlay; sleep 4; act show-hotkey-overlay; }
gif_hotkeys() { stand pixel dark; record 6 hotkeys scene_hotkeys; }

scene_menubar() {
  "$RIG" run nautilus; sleep 3
  for i in 1 2 3 4; do ipc macMenu "$i"; sleep 1.5; done
  ipc macPanel cc; sleep 2.5; ipc macPanel nc; sleep 2.5; ipc macPanel ""
}
gif_macos_menubar() { stand macos light; record 16 macos-menubar scene_menubar; }

# the Dock: an app's menu, a window minimized into the Dock and back (the magnification under a
# real pointer is the one part done by hand: SHOTLIST.md)
scene_dock() {
  "$RIG" run nautilus; sleep 3
  ipc macDockMenu 0; sleep 2.5; ipc macDockMenu 0; sleep 1
  ipc macMinimize; sleep 3
  local id
  id="$("$RIG" ipc macMinimized 2>/dev/null | python3 -c 'import json,sys; w=json.load(sys.stdin); print(w[0]["id"] if w else "")')"
  [[ -n "$id" ]] && ipc macRestore "$id"
  sleep 3
}
gif_macos_dock() { stand macos light; record 14 macos-dock scene_dock; }

# Settings → Plugins: the Community catalog next to what is installed (it asks the registry)
scene_plugins() { ipc settings plugins; sleep 6; ipc settings plugins; sleep 3; }
gif_plugins() { stand pixel dark; record 11 plugins scene_plugins; }

scene_spotlight() { ipc startMenu ""; sleep 1; ipc startText "term"; sleep 2.5; ipc startText "files"; sleep 2; ipc startMenu ""; }
gif_macos_spotlight() { stand macos light; record 8 macos-spotlight scene_spotlight; }

# the installer itself, in a kitty inside the stand: the pty driver presses the keys (gum from
# the system, or DEMO_GUM_DIR=/dir/with/gum)
scene_installer() {
  "$RIG" run kitty --title installer -o update_check_interval=0 -o font_size=13 -e bash -c \
    "H=\$(mktemp -d); cd '$ROOT' && env HOME=\$H PATH='${DEMO_GUM_DIR:+$DEMO_GUM_DIR:}'\$PATH NO_ANIM=0 SKIP_PACKAGES=1 INSTALL_VOXTYPE=0 DOWNLOAD_VOXTYPE_MODEL=0 INSTALL_SDDM=0 ENABLE_SERVICES=0 WALLPAPER_PACKS=none INSTALL_FLATPAK=0 GITHUB_LOGIN=0 \
     DRIVE_PAUSE=2.2 python3 '$ROOT/scripts/demo/drive.py' '[\"\\r\",\"\\r\",\"\\u001b[B\\r\",\"\\r\",\"\\r\",\"\\r\",\"\\r\",\"\\r\"]' bash ./install.sh; sleep 8; rm -rf \$H"
  sleep 1; act maximize-column
  sleep 36
}
gif_installer() { stand pixel dark; record 40 installer scene_installer 900; }

ALL=(shot_pixel_dark shot_pixel_light shot_macos_light shot_macos_dark shot_sddm_login
     gif_pixel_desktop gif_wallpaper gif_menu gif_launcher gif_settings gif_tips gif_tiling gif_overview
     gif_hotkeys gif_macos_menubar gif_macos_dock gif_macos_spotlight gif_plugins gif_installer)

if [[ "${1:-}" == --list ]]; then printf '%s\n' "${ALL[@]}" | sed 's/^\(shot\|gif\)_//; s/_/-/g'; exit 0; fi
want=("$@")
((${#want[@]})) || want=("${ALL[@]}")
trap '"$RIG" stop >/dev/null 2>&1 || true' EXIT
for w in "${want[@]}"; do
  fn="$w"; [[ "$fn" == shot_* || "$fn" == gif_* ]] || { fn="${w//-/_}"; declare -F "shot_$fn" >/dev/null && fn="shot_$fn" || fn="gif_$fn"; }
  declare -F "$fn" >/dev/null || { echo "unknown shot: $w"; continue; }
  say "$fn"
  "$fn"
done
say "done — now: scripts/demo/check-frames.sh"
