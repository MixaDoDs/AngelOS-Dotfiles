#!/usr/bin/env bash
# The demo stand: a clean angelOS in a nested niri — nothing of yours gets into the frame.
# A throw-away home made by ./install.sh (SKIP_PACKAGES=1), the user "angel" on the host "angelos",
# generated wallpapers (scripts/demo/wallpaper.py), a private D-Bus (no service activation from the
# host), its own XDG_RUNTIME_DIR (no PipeWire: no sound plays; no systemd --user: nothing of the live
# session starts or stops), and the stand's shell never registers a polkit agent.
#
# By default niri runs inside a headless labwc: nothing shows up on your screens. DEMO_VISIBLE=1
# opens the nested niri as a window of your session instead, for the few shots that need a real
# pointer (move it to the test screen; it records only itself).
#
#   scripts/demo/rig.sh start pixel|macos [dark|light]   build the home, start niri and angelOS
#   scripts/demo/rig.sh ipc FUNCTION [ARGS…]             angelOS's IPC in the stand
#   scripts/demo/rig.sh niri ARGS…                       `niri msg` in the stand
#   scripts/demo/rig.sh run COMMAND…                     a program inside the nested niri
#   scripts/demo/rig.sh shot FILE.png                    a screenshot of the stand (grim)
#   scripts/demo/rig.sh rec FILE.mp4 SECONDS             a recording of the stand (wf-recorder)
#   scripts/demo/rig.sh stop                             everything down, the home removed
#
#   LABWC=/path/to/labwc  WLR_RANDR=/path/to/wlr-randr  (LABWC_LIB for a local build)
#   DEMO_SIZE=1920x1080  DEMO_LANG=en|ru  DEMO_VISIBLE=1
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
RUN="/run/user/$(id -u)/angelos-demo"
STATE="$RUN/state"
LABWC="${LABWC:-labwc}" WLR_RANDR="${WLR_RANDR:-wlr-randr}" LABWC_LIB="${LABWC_LIB:-}"
SIZE="${DEMO_SIZE:-1920x1080}"

die() { printf 'rig: %s\n' "$*" >&2; exit 1; }
home() { cat "$STATE/home" 2>/dev/null || die "not started"; }

# quickshell: the system one, else the local copy angelOS installs into ~/.local/opt
qs_env() {
  QS="$(command -v quickshell || true)" QS_LIB="" QS_QML=""
  local real="${REAL_HOME:-$HOME}"
  if [[ ! -x /usr/bin/quickshell && -x "$real/.local/opt/quickshell/usr/bin/quickshell" ]]; then
    QS="$real/.local/opt/quickshell/usr/bin/quickshell"
    QS_LIB="$real/.local/opt/quickshell/usr/lib" QS_QML="$real/.local/opt/quickshell/usr/lib/qt6/qml"
  fi
  [[ -x "$QS" ]] || die "quickshell not found"
}

# the stand's environment for anything started in it
stand_env() {
  local h; h="$(home)"
  export REAL_HOME="${REAL_HOME:-$HOME}"
  export HOME="$h" USER=angel LOGNAME=angel HOSTNAME=angelos XDG_RUNTIME_DIR="$RUN"
  export XDG_CONFIG_HOME="$h/.config" XDG_CACHE_HOME="$h/.cache" XDG_DATA_HOME="$h/.local/share" XDG_STATE_HOME="$h/.local/state"
  DBUS_SESSION_BUS_ADDRESS="$(cat "$STATE/bus")"; export DBUS_SESSION_BUS_ADDRESS
  WAYLAND_DISPLAY="$(cat "$STATE/wayland")"; NIRI_SOCKET="$(cat "$STATE/niri")"; export WAYLAND_DISPLAY NIRI_SOCKET
  export XDG_CURRENT_DESKTOP=niri XDG_SESSION_TYPE=wayland QT_QPA_PLATFORM=wayland GDK_BACKEND=wayland
  export PATH="$h/.local/bin:$PATH"
  SHELL="$(command -v fish || echo /bin/bash)"; export SHELL
  unset DISPLAY SWAYSOCK LD_PRELOAD
}

seed_home() { # home theme palette
  local h="$1" theme="$2" palette="$3"
  env -i HOME="$h" PATH="$PATH" LANG=en_US.UTF-8 SKIP_PACKAGES=1 INSTALL_VOXTYPE=0 DOWNLOAD_VOXTYPE_MODEL=0 \
    ENABLE_SERVICES=0 WALLPAPER_PACKS=none INSTALL_SDDM=0 GITHUB_LOGIN=0 FISH_DEFAULT=0 \
    ANGELOS_THEME="$theme" MAC_KEYS=1 ANGELOS_GAME=1 KB_LAYOUTS=us,ru \
    "$ROOT/install.sh" </dev/null >"$STATE/install.log" 2>&1 || { tail -20 "$STATE/install.log" >&2; die "install failed"; }
  # no systemd --user for the stand's shell, nothing autostarted by niri (the stand starts it)
  printf 'off\n' >"$h/.config/angelos/service"
  printf '// demo stand: angelOS is started by scripts/demo/rig.sh\n' >"$h/.config/niri/cfg/autostart.kdl"
  # the stand's shell never registers a polkit agent (it would answer for your real session)
  sed -i 's/^        active: true$/        active: Quickshell.env("ANGELOS_DEMO") !== "1"/' \
    "$h/.config/quickshell/angelos/modules/polkit/PolkitDialog.qml"
  grep -q 'ANGELOS_DEMO' "$h/.config/quickshell/angelos/modules/polkit/PolkitDialog.qml" ||
    die "could not switch off the stand's polkit agent (modules/polkit/PolkitDialog.qml changed?)"
  # Settings → About says «angelos», not the machine's hostname (/etc/hostname is the right
  # source for everyone else)
  # (the script sits in a JS template literal: no `${…}` in it)
  sed -i 's#host=$(cat /etc/hostname 2>/dev/null || uname -n)#host=$([ -n "$HOSTNAME" ] \&\& echo "$HOSTNAME" || cat /etc/hostname 2>/dev/null || uname -n)#' \
    "$h/.config/quickshell/angelos/services/SystemInfo.qml"
  grep -q 'host=$(\[ -n "$HOSTNAME" \]' "$h/.config/quickshell/angelos/services/SystemInfo.qml" ||
    die "could not hide the hostname in the stand (services/SystemInfo.qml changed?)"
  # `angelos intro` in the stand plays at once: nothing can click its «continue?» question
  python3 - "$h/.config/quickshell/angelos/modules/settings/SetupIntro.qml" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = 'askIn = 0;\n            phase = "ask";\n            askFade.restart();\n            return;'
if old in s:
    open(p, "w").write(s.replace(old, "go();\n            return;", 1))
PY
  # fastfetch in the frame: angelOS's own style (the shell writes it through
  # scripts/fastfetch_style.py a moment after it starts, and again on every theme change), with
  # nothing about your machine that is yours — angel@angelos, no board, no local IP, no disk, no
  # gear list (scripts/gear.py: your keyboard, mouse and mic). The filter sits inside the stand's
  # copy of the style script, so every config it writes goes through it and the «written by
  # angelOS» mark stays (a config without the mark counts as the user's own and is left alone,
  # and fastfetch then falls back to the distro's logo).
  python3 - "$h/.config/quickshell/angelos/scripts/fastfetch_style.py" "$h/.config/fastfetch/config.jsonc" <<'PY'
import json, re, sys
script, conf = sys.argv[1], sys.argv[2]
FILTER = '''
# demo stand (scripts/demo/rig.sh): nothing of the machine's in the frame
_write_real = write


def _demo_filter(text):
    lines = text.splitlines()
    head = [l for l in lines if l.lstrip().startswith("//")]
    body = "\\n".join(l for l in lines if not l.lstrip().startswith("//"))
    d = json.loads(re.sub(r",(\\s*[}\\]])", r"\\1", body))
    keep = []
    for m in d.get("modules", []):
        kind = m if isinstance(m, str) else m.get("type")
        if kind in ("host", "disk", "localip", "publicip", "command", "battery", "board", "bios", "users", "wifi"):
            continue
        if kind == "custom" and re.search("супер|super", json.dumps(m, ensure_ascii=False), re.I):
            continue                                    # the gear's header, without the gear
        if isinstance(m, dict):
            m = json.loads(json.dumps(m).replace("{user-name}", "angel").replace("{host-name}", "angelos"))
        keep.append(m)
    d["modules"] = keep
    return "\\n".join(head) + "\\n" + json.dumps(d, ensure_ascii=False, indent=2) + "\\n"


def write(path, text):
    if Path(path) == CONFIG:
        text = _demo_filter(text)
    return _write_real(path, text)

'''
s = open(script).read()
at = s.index('if __name__ == "__main__":')
open(script, "w").write(s[:at] + FILTER + s[at:])
# the shipped config too, until the shell writes its own (same filter, the mark kept)
sys.path.insert(0, str(__import__("pathlib").Path(script).parent))
import importlib.util
spec = importlib.util.spec_from_file_location("ffs", script); ffs = importlib.util.module_from_spec(spec); spec.loader.exec_module(ffs)
shipped = open(conf).read()
open(conf, "w").write(ffs._demo_filter(shipped))
PY
  # the stand's own wallpapers and the usual folders; the shipped pictures stay out of the frame
  mkdir -p "$h/Pictures" "$h/Desktop" "$h/Documents" "$h/Downloads" "$h/Music" "$h/Videos"
  rm -rf "$h/Pictures/wallpapers" "$h/Pictures/Pixel"
  python3 "$ROOT/scripts/demo/wallpaper.py" "$h/Pictures/angelos-demo-light.png" --size "$SIZE"
  python3 "$ROOT/scripts/demo/wallpaper.py" "$h/Pictures/angelos-demo-dark.png" --dark --size "$SIZE"
  # Golden Gate's downloads (MacTahoe for the Dock, Inter, the macOS cursor — public, GPL/OFL)
  # come from your own copies when you have them, instead of being fetched again
  if [[ "$theme" == macos ]]; then
    local real="${REAL_HOME:-$HOME_REAL}" d
    for d in .local/share/angelos/icons/MacTahoe .local/share/fonts/angelos/inter .local/share/icons/macOS; do
      [[ -d "$real/$d" ]] && { mkdir -p "$h/$(dirname "$d")"; cp -r "$real/$d" "$h/$d"; }
    done
  fi
  python3 - "$h/.config/angelos/settings.json" "$palette" "$h" <<'PY'
import json, os, sys
path, palette, home = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(path)) if os.path.exists(path) else {}
d.setdefault("setup", {})["complete"] = True          # no wizard, no tips: a desktop in use
d["setup"]["introSeen"] = 99                           # the update's intro never asks here
d.setdefault("wallpaper", {})["releaseSeen"] = 99      # no «new wallpapers» news in the frame
y = d.setdefault("y2k", {}); y["raysSeen"] = True
y["seenTips"] = ["wallpaper", "fonts", "sound", "cursor", "appearance", "widgets", "bar", "workspaces", "y2k",
                 "monitor", "shortcuts", "plugins", "updates", "lock", "capture", "lyrics", "deskmenu", "sfx",
                 "system", "keyboard", "windows", "studio", "notifications", "gamepad", "display", "theme",
                 "taskbar", "about", "helper"]
d.setdefault("bar", {})["userName"] = "angel"
a = d.setdefault("appearance", {}); a["mode"] = palette; a["language"] = os.environ.get("DEMO_LANG", "en")
d.setdefault("wallpaper", {})["fallback"] = os.path.join(home, "Pictures", f"angelos-demo-{palette}.png")
json.dump(d, open(path, "w"), ensure_ascii=False, indent=4)
# the game's save: every achievement already earned, so no «achievement earned» toast pops into
# a picture when the stand clicks something for the first time (the save fills the rest itself)
import time
ach = json.load(open(os.path.join(home, ".config/quickshell/angelos/story/achievements.json")))
ach = ach if isinstance(ach, list) else ach.get("achievements", ach)
now = int(time.time() * 1000) - 60000
save = os.path.join(os.path.dirname(path), "save.json")
s = json.load(open(save)) if os.path.exists(save) else {}
s.setdefault("achievements", {})["got"] = {a["id"]: now for a in ach if isinstance(a, dict) and a.get("id")}
json.dump(s, open(save, "w"), ensure_ascii=False, indent=4)
PY
}

start() {
  local theme="${1:-pixel}" palette="${2:-dark}" h i live
  [[ "$theme" == pixel || "$theme" == macos ]] || die "theme: pixel or macos"
  [[ -e "$STATE/home" ]] && die "already running (rig.sh stop)"
  live="${WAYLAND_DISPLAY:-}"; [[ -n "$live" && "$live" != /* ]] && live="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/$live"
  mkdir -p "$STATE"; chmod 700 "$RUN"
  h="$(mktemp -d "${TMPDIR:-/tmp}/angelos-demo-home.XXXXXX")"
  echo "$h" >"$STATE/home"
  HOME_REAL="$HOME" HOME="$h" seed_home "$h" "$theme" "$palette"
  cat >"$STATE/bus.conf" <<EOF
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig><type>session</type><keep_umask/><listen>unix:dir=$RUN</listen>
<policy context="default"><allow send_destination="*" eavesdrop="true"/><allow eavesdrop="true"/><allow own="*"/></policy></busconfig>
EOF
  # labwc (headless): the nested niri fills its screen
  mkdir -p "$STATE/labwc"
  cat >"$STATE/labwc/rc.xml" <<'EOF'
<?xml version="1.0"?>
<labwc_config><core><decoration>client</decoration></core>
<windowRules><windowRule identifier="*" serverDecoration="no"><action name="Maximize"/></windowRule></windowRules></labwc_config>
EOF
  (
    export HOME="$h" USER=angel LOGNAME=angel XDG_RUNTIME_DIR="$RUN" XDG_CONFIG_HOME="$h/.config"
    export XDG_CACHE_HOME="$h/.cache" XDG_DATA_HOME="$h/.local/share" XDG_STATE_HOME="$h/.local/state"
    unset WAYLAND_DISPLAY NIRI_SOCKET DISPLAY SWAYSOCK LD_PRELOAD DBUS_SESSION_BUS_ADDRESS
    if [[ "${DEMO_VISIBLE:-0}" == 1 ]]; then
      [[ -n "$live" ]] || die "DEMO_VISIBLE=1 needs a Wayland session"
      setsid dbus-run-session --config-file "$STATE/bus.conf" -- bash -c '
        echo "$DBUS_SESSION_BUS_ADDRESS" >"$1/bus"
        WAYLAND_DISPLAY="$2" niri -c "$3/.config/niri/config.kdl" >"$1/niri.log" 2>&1
      ' _ "$STATE" "$live" "$h" </dev/null >"$STATE/session.log" 2>&1 &
    else
      setsid dbus-run-session --config-file "$STATE/bus.conf" -- bash -c '
        echo "$DBUS_SESSION_BUS_ADDRESS" >"$1/bus"
        WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=1 WLR_RENDERER=gles2 LD_LIBRARY_PATH="$2" \
          "$3" -C "$1/labwc" -s "niri -c $4/.config/niri/config.kdl" >"$1/labwc.log" 2>&1
      ' _ "$STATE" "$LABWC_LIB" "$LABWC" "$h" </dev/null >"$STATE/session.log" 2>&1 &
    fi
  )
  for i in $(seq 60); do compgen -G "$RUN/niri.*.sock" >/dev/null && break; sleep 0.5; done
  compgen -G "$RUN/niri.*.sock" >/dev/null || die "niri did not start (see $STATE/*.log)"
  ls "$RUN"/niri.*.sock | head -1 >"$STATE/niri"
  basename "$(ls "$RUN"/niri.*.sock | head -1)" | sed 's/^niri\.\(wayland-[0-9]*\)\..*/\1/' >"$STATE/wayland"
  if [[ "${DEMO_VISIBLE:-0}" != 1 ]]; then
    XDG_RUNTIME_DIR="$RUN" WAYLAND_DISPLAY=wayland-0 LD_LIBRARY_PATH="$LABWC_LIB" \
      "$WLR_RANDR" --output HEADLESS-1 --custom-mode "${SIZE}@60Hz" >/dev/null 2>&1 || true
  fi
  sleep 1.5
  qs_env
  (
    stand_env
    export ANGELOS_DEMO=1 QT_QPA_PLATFORMTHEME=qt6ct QT_WAYLAND_DISABLE_WINDOWDECORATION=1
    [[ -n "$QS_LIB" ]] && export LD_LIBRARY_PATH="$QS_LIB" QML_IMPORT_PATH="$QS_QML"
    setsid "$QS" -p "$HOME/.config/quickshell/angelos/shell.qml" -n >"$STATE/qs.log" 2>&1 </dev/null &
    echo $! >"$STATE/qs.pid"
  )
  sleep 8
  # the pixel look gets the demo sky; Golden Gate draws its own wallpaper
  [[ "$theme" == pixel ]] && { ipc wallpaper "$h/Pictures/angelos-demo-$palette.png" >/dev/null 2>&1 || true; }
  sleep 2
  echo "stand up: theme=$theme palette=$palette home=$h niri=$(cat "$STATE/niri")"
}

ipc() {
  qs_env; stand_env
  [[ -n "$QS_LIB" ]] && export LD_LIBRARY_PATH="$QS_LIB"
  timeout 10 "$QS" ipc --pid "$(cat "$STATE/qs.pid")" call angelos "$@"
}

stop() {
  local h
  h="$(cat "$STATE/home" 2>/dev/null || true)"
  [[ -f "$STATE/qs.pid" ]] && kill "$(cat "$STATE/qs.pid")" 2>/dev/null || true
  # only what runs from the stand's own home or with its bus: never anything of the live session
  if [[ -n "$h" && "$h" == */angelos-demo-home.* ]]; then
    pkill -f -- "$h/" 2>/dev/null || true
  fi
  pkill -f -- "--config-file $STATE/bus.conf" 2>/dev/null || true
  sleep 1
  [[ -n "$h" && "$h" == */angelos-demo-home.* ]] && rm -rf -- "$h"
  rm -rf -- "$STATE"
  echo "stand down"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  start) start "$@" ;;
  ipc) ipc "$@" ;;
  niri) stand_env; niri msg "$@" ;;
  # programs start in the stand's home: a terminal's prompt shows ~, never a path of yours
  run) stand_env; cd "$HOME"; setsid "$@" </dev/null >/dev/null 2>&1 & ;;
  shot) stand_env; grim "$1" ;;
  rec) stand_env; timeout --signal=INT "$2" wf-recorder -y -r 30 -f "$1" >/dev/null 2>&1 || true ;;
  stop) stop ;;
  *) sed -n '2,24p' "$0"; exit 2 ;;
esac
