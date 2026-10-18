# shellcheck shell=bash
# angelOS installer — sourced by install.sh in name order (see installer/README.md)

# The system as the author has it, with one admin password, when something is missing — an
# update from Settings runs this too (the installer there is always the new version):
#   - the base packages the author added since (packages/*.txt), fish among them
#   - fish as the login shell instead of bash/sh (installs from before fish came with angelOS);
#     asked once: a user who goes back to bash later stays on bash
#   - the angelOS login screen (extras/sddm/angelos, as the author has it) instead of an older
#     theme the user's install had (pixel-cyberpunk, which angelOS no longer ships); again when
#     the author changes it, with the user's own look and colours (Settings → Lock screen).
#     Another theme the user picked stays
#   - the gaming edition's packages (data/gaming-packages.txt), when it was set up here
#   - the udev rule for the devices' charge (device_access above), missing or changed by the
#     author; DEVICE_ACCESS=0 leaves it out
# Only for the real home of this user (never a test's or a chroot's) and never on the author's
# own machine. FOLLOW_SYSTEM=0 skips it.
FOLLOW_SYSTEM="${FOLLOW_SYSTEM:-1}"
fish_asked() { # remembered: fish is offered once
  mkdir -p -- "$STATE_DIR"
  python3 - "$STATE_DIR/apps.json" <<'PY' || true
import json, sys
p = sys.argv[1]
try:
    st = json.load(open(p))
except (OSError, ValueError):
    st = {}
st["fishAsked"] = True
json.dump(st, open(p, "w"), indent=1)
PY
}
follow_system() {
  [[ "$FOLLOW_SYSTEM" == 1 && -z "$SYSROOT" && "$OWNER_HOME" == 0 && "$DESKTOP_SHELL" == angelos ]] || return 0
  [[ "$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6)" == "$HOME_DIR" ]] || return 0
  command -v pacman >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 || return 0
  local sddm_py="$ROOT/.config/quickshell/angelos/scripts/sddm-theme.py" sddm_src="$ROOT/.config/quickshell/angelos/extras/sddm/angelos"
  local pkgs=() fish="" theme="" applied="" built="" root_sddm="" stamp="$STATE_DIR/sddm-theme.sha256" hash cur look="" pal="" hid=""
  # what the user said no to stays out (an unattended update keeps the defaults: yes)
  local -a lists=(pacman.txt angelos.txt)
  [[ "$INSTALL_TOOLS" == 1 ]] && lists+=(tools.txt)
  [[ "$FISH_DEFAULT" == 1 ]] && lists+=(fish.txt)
  command -v sddm >/dev/null 2>&1 && [[ "$INSTALL_SDDM" == 1 ]] && lists+=(sddm.txt)
  # the gaming edition, once it was set up here (scripts/game-setup.sh): its list is the shell's
  [[ -f "$STATE_DIR/gaming" ]] && lists+=(../.config/quickshell/angelos/data/gaming-packages.txt)
  # base packages missing here that the repositories have
  mapfile -t pkgs < <(cd "$ROOT/packages" && cat "${lists[@]}" 2>/dev/null | sed 's/#.*//' | tr -s ' \t' '\n' | grep -v '^$' | sort -u | not_removed |
                        xargs -r pacman -T 2>/dev/null | xargs -r -n1 sh -c 'pacman -Si "$0" >/dev/null 2>&1 && echo "$0"')
  # fish: bash or sh as the login shell, not asked before
  [[ "$FISH_DEFAULT" == 1 ]] && case "$(basename "$(getent passwd "$(id -un)" | cut -d: -f7)")" in
    bash|sh) python3 - "$STATE_DIR/apps.json" <<'PY' && fish=1 ;;
import json, sys
try:
    sys.exit(1 if json.load(open(sys.argv[1])).get("fishAsked") else 0)
except (OSError, ValueError):
    sys.exit(0)
PY
  esac
  [[ "$FISH_DEFAULT" == 0 ]] && given FISH_DEFAULT && fish_asked
  # the login screen: the installer's old theme (or none) → the author's; the author's changed → again
  if [[ "$INSTALL_SDDM" == 1 ]] && command -v sddm >/dev/null 2>&1 && [[ -f "$sddm_src/Main.qml" ]]; then
    hash="$(python3 "$sddm_py" fingerprint)"
    cur="$(python3 "$sddm_py" status 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print("|".join((d.get("current",""), d.get("look",""), d.get("palette",""))))' 2>/dev/null || true)"
    IFS='|' read -r cur look pal <<<"$cur"   # an empty look must not shift the palette into its place
    if [[ -z "$cur" || "$cur" == pixel-cyberpunk || ( "$cur" == angelos && "$(cat "$stamp" 2>/dev/null)" != "$hash" ) ]]; then
      theme=1
    fi
  fi
  # the devices' charge: the udev rule (device_access above) missing or older than the author's
  if ! { given DEVICE_ACCESS && [[ "$DEVICE_ACCESS" == 0 ]]; }; then
    case "$(hid_access_state)" in missing|old) hid="$HID_ACCESS" ;; esac
  fi
  ((${#pkgs[@]})) || [[ -n "$fish$theme$hid" ]] || return 0

  if [[ -n "$theme" ]]; then
    local -a opts=()
    [[ -n "$look" ]] && opts+=(--look "$look")
    [[ -n "$pal" ]] && opts+=(--palette "$pal")
    built="$(mktemp -d)"; TMP_DIRS+=("$built")
    if python3 "$sddm_py" build "${opts[@]}" --out "$built/angelos" >/dev/null 2>&1; then
      root_sddm="$(python3 -c 'import importlib.util as u, sys; s = u.spec_from_file_location("t", sys.argv[1]); m = u.module_from_spec(s); s.loader.exec_module(m); print(m.ROOT_SCRIPT)' "$sddm_py")"
    else
      warn "$(_ "the angelOS login screen did not build (scripts/sddm-theme.py build)" "экран входа angelOS не собрался (scripts/sddm-theme.py build)")"
      theme=""
    fi
  fi
  ((${#pkgs[@]})) || [[ -n "$fish$theme$hid" ]] || return 0
  say "$(_ "As the author has it:" "Как у автора:")${pkgs[*]:+ $(_ "packages" "пакеты") ${pkgs[*]};}${fish:+ $(_ "fish instead of bash;" "fish вместо bash;")}${theme:+ $(_ "the angelOS login screen;" "экран входа angelOS;")}${hid:+ $(_ "the devices' charge (a mouse's dongle: its service interface only)" "заряд устройств (донгл мыши: только служебный интерфейс)")} — $(_ "the admin password" "пароль администратора")"

  local -a root=()
  if ((EUID == 0)); then root=()
  elif [[ -t 0 ]] && command -v sudo >/dev/null 2>&1; then root=(sudo)
  elif sudo -n true 2>/dev/null; then root=(sudo -n)
  elif command -v pkexec >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then root=(env SHELL=/bin/sh pkexec)
  else
    warn "$(_ "no way to ask for the admin password here: the system part waits for the next update" "здесь не спросить пароль администратора: системная часть подождёт следующего обновления")"
    return 0
  fi
  # shellcheck disable=SC2016  # the root script's own variables
  if "${root[@]}" sh -c '
    pkgs="$1"; user="$2"; fish="$3"; src="$4"; sddm="$5"; uid="$6"; hid="$7"; rc=0
    if [ -n "$pkgs" ]; then
      # shellcheck disable=SC2086
      pacman -Syu --needed --noconfirm $pkgs || rc=1
    fi
    if [ -n "$fish" ] && f="$(command -v fish)"; then
      grep -qx "$f" /etc/shells || echo "$f" >>/etc/shells
      chsh -s "$f" "$user" || rc=1
    fi
    if [ -n "$src" ]; then
      sh -c "$sddm" sh "$src" /usr/share/sddm/themes/angelos /etc/sddm.conf.d/zz-angelos.conf "$uid" >/dev/null || rc=1
    fi
    if [ -n "$hid" ]; then
      sh "$hid" >/dev/null || rc=1
    fi
    exit $rc' sh "${pkgs[*]}" "$(id -un)" "$fish" "${theme:+$built/angelos}" "$root_sddm" "$(id -u)" "$hid" </dev/null; then
    applied=1
    say "$(_ "the system is as the author has it ♡" "система как у автора ♡")${fish:+ $(_ "(fish from the next login)" "(fish — со следующего входа)")}"
  else
    warn "$(_ "the system part did not finish (no password, or see above) — the next update tries again" "системная часть не закончилась (нет пароля или см. выше) — следующее обновление попробует снова")"
  fi
  # what is done is remembered: fish is asked once, the theme is redone only when the author changes it
  if [[ -n "$fish" ]] && [[ "$(basename "$(getent passwd "$(id -un)" | cut -d: -f7)")" == fish ]]; then
    fish_asked
  fi
  if [[ -n "$theme" && -n "$applied" ]] &&
     [[ "$(python3 "$sddm_py" status 2>/dev/null)" == *'"current": "angelos"'* ]]; then
    mkdir -p -- "$STATE_DIR" && printf '%s\n' "$hash" >"$stamp"
  fi
  return 0
}

# the steps of this file, in the order of the run (see step() in installer/lib/core.sh)
step 70 follow_system "as the author has it: packages, fish, the login screen" "как у автора: пакеты, fish, экран входа"
