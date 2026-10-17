# shellcheck shell=bash
# angelOS installer — sourced by install.sh in name order (see installer/README.md)

# ── SDDM login screen ────────────────────────────────────────────────────────

SDDM_THEME=angelos
SDDM_STATUS=skipped
# Test hook for scripts/check.sh: put the system files under this directory
# instead of /, without sudo and without touching systemd.
SYSROOT="${SYSROOT:-}"

as_root() {
  if [[ -n "$SYSROOT" || "$EUID" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

# The theme uses QtQuick. Only reachable with SKIP_PACKAGES=1 or a broken install.
sddm_check_modules() {
  local qml=/usr/lib/qt6/qml missing=()
  [[ -d "$qml/QtQuick" ]] || missing+=(qt6-declarative)
  ((${#missing[@]})) || return 0
  warn "$(_ "The SDDM theme needs: ${missing[*]}  →  sudo pacman -S ${missing[*]}" \
           "Теме SDDM не хватает: ${missing[*]}  →  sudo pacman -S ${missing[*]}")"
}

# Make SDDM the display manager that starts at boot.
sddm_enable() {
  local current
  command -v systemctl >/dev/null 2>&1 || { warn "$(_ 'systemctl not found; SDDM not enabled' 'systemctl не найден; SDDM не включён')"; return 0; }

  # Another display manager (gdm, lightdm, ly, greetd, …) owns
  # display-manager.service; enabling SDDM on top of it fails.
  local name units=()
  current="$(readlink /etc/systemd/system/display-manager.service 2>/dev/null || true)"
  current="${current##*/}"
  if [[ -n "$current" && "$current" != sddm.service ]]; then
    name="${current%.service}"; name="${name%@}"
    if [[ "$current" == *@.service ]]; then
      # Template units (ly@tty2.service): disable the enabled instances.
      mapfile -t units < <(find /etc/systemd/system -name "$name@?*.service" -printf '%f\n' 2>/dev/null | sort -u)
    else
      units=("$current")
    fi
    if { ((INTERACTIVE)) && confirm "$(_ "Login manager $name is enabled. Switch to SDDM?" \
                                         "Сейчас включён менеджер входа $name. Переключить на SDDM?")" y; } ||
       { ! ((INTERACTIVE)) && given INSTALL_SDDM; }; then
      ((${#units[@]} == 0)) || as_root systemctl disable "${units[@]}" || true
    else
      warn "$(_ "Keeping $name; SDDM is installed but not enabled (sudo systemctl enable --force sddm)" \
               "Оставлен $name; SDDM установлен, но не включён (sudo systemctl enable --force sddm)")"
      SDDM_STATUS="installed, not enabled"
      return 0
    fi
  fi
  # --force replaces a dangling display-manager.service alias left by a
  # removed display manager.
  if ! as_root systemctl enable --force sddm.service; then
    warn "$(_ 'Could not enable SDDM; see: systemctl status sddm' 'Не удалось включить SDDM; смотрите: systemctl status sddm')"
    SDDM_STATUS="installed, not enabled"
    return 0
  fi

  # display-manager.service is pulled in by graphical.target only.
  if [[ "$(systemctl get-default 2>/dev/null || true)" != graphical.target ]]; then
    as_root systemctl set-default graphical.target
    say "$(_ 'Boot target set to graphical.target' 'Цель загрузки: graphical.target')"
  fi
}

install_sddm() {
  [[ "$INSTALL_SDDM" == 1 ]] || { say "$(_ 'SDDM skipped' 'SDDM пропущен')"; return 0; }
  local py="$ROOT/.config/quickshell/angelos/scripts/sddm-theme.py"
  local src="$ROOT/.config/quickshell/angelos/extras/sddm/angelos"
  local themes="$SYSROOT/usr/share/sddm/themes"
  local dst="$themes/angelos"

  if [[ -z "$SYSROOT" ]] && ! command -v sddm >/dev/null 2>&1; then
    warn "$(_ 'SDDM is not installed (SKIP_PACKAGES=1?); login screen not configured' \
             'SDDM не установлен (SKIP_PACKAGES=1?); экран входа не настроен')"
    return 0
  fi
  if [[ ! -f "$src/Main.qml" ]]; then
    warn "$(_ 'No angelOS login screen in the repository; not configured' \
             'Экрана входа angelOS нет в репозитории; не настроен')"
    return 0
  fi
  say "$(_ 'Installing the angelOS login screen…' 'Установка экрана входа angelOS…')"

  # What is already installed and current is left as the user has it (look, colours, walls);
  # a different theme they picked, or nothing yet, gets the author's screen.
  local look="" pal="" args=()
  if [[ -f "$dst/Main.qml" && -r "$dst/theme.conf.user" ]]; then
    while IFS='=' read -r k v; do
      case "$k" in look) look="$v";; palette) pal="$v";; esac
    done <"$dst/theme.conf.user"
  fi
  [[ -n "$look" ]] && args+=(--look "$look")
  [[ -n "$pal" ]] && args+=(--palette "$pal")

  local built
  built="$(mktemp -d)" || return 1
  TMP_DIRS+=("$built")
  if ! python3 "$py" build "${args[@]}" --out "$built/angelos" >/dev/null 2>&1; then
    warn "$(_ 'The angelOS login screen did not build (scripts/sddm-theme.py build); not configured' \
             'Экран входа angelOS не собрался (scripts/sddm-theme.py build); не настроен')"
    return 0
  fi

  # One root call: the theme folder, our drop-in, and the other Current= lines that could win
  # over it (SDDM reads the drop-ins in alphabetical order; /etc/sddm.conf after them).
  local root_script
  root_script="$(python3 -c 'import importlib.util as u, sys; s = u.spec_from_file_location("t", sys.argv[1]); m = u.module_from_spec(s); s.loader.exec_module(m); print(m.ROOT_SCRIPT)' "$py")"
  if ! as_root sh -c '
    # root script variables
    set -eu
    sh -c "$1" sh "$2" "$3" "$4" "$5" "$6" </dev/null' sh "$root_script" "$built/angelos" \
      "$themes/angelos" "$SYSROOT/etc/sddm.conf.d/zz-angelos.conf" "$(id -u)" "$SYSROOT"; then
    warn "$(_ 'The angelOS login screen could not be installed (see above)' \
             'Экран входа angelOS не поставился (см. выше)')"
    return 0
  fi
  rm -rf -- "$built"
  SDDM_STATUS=enabled

  [[ -z "$SYSROOT" ]] || return 0
  sddm_check_modules
  sddm_enable
}

# the steps of this file, in the order of the run (see step() in installer/lib/core.sh)
step 55 install_sddm "the login screen" "экран входа"
