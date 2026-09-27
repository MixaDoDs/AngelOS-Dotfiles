#!/usr/bin/env bash
# Installer for the PixelStreetArt Niri rice (CachyOS / Arch).
#
# Run it with no arguments for the interactive setup, or drive it with
# environment variables (everything has a default, so it also works unattended):
#
#   DOTFILES_MODE=full|tech        full = styling + Noctalia + assets, tech = minimal
#   NOCTALIA=1|0                   install/use Noctalia Shell (default 1)
#   NOCTALIA_RESET_SETTINGS=0|1    move aside Noctalia GUI settings saved by an earlier
#                                  run, so the preconfigured shell setup applies (default 0)
#   KB_LAYOUTS=us,ru               keyboard layouts, XKB codes, first one is the default
#   KB_TOGGLE=alt_shift            layout switch: alt_shift | ctrl_shift | caps | ralt | lalt | none
#                                  (or a raw XKB option such as grp:shifts_toggle)
#   KB_VARIANT=,phonetic           optional XKB variants, one per layout, comma separated
#   VOXTYPE_LANGUAGE=ru            dictation language (default: derived from KB_LAYOUTS)
#   INSTALL_SDDM=1|0               SDDM login screen with the pixel-cyberpunk theme
#                                  (default 1, or 0 together with SKIP_PACKAGES=1)
#   SKIP_PACKAGES=0|1              skip `pacman -Syu`
#   INSTALL_VOXTYPE=0|1            voice input binary (checksum-verified download)
#   DOWNLOAD_VOXTYPE_MODEL=0|1     Whisper large-v3-turbo model (~1.6 GB)
#   INSTALL_WALLPAPERS=0|1         copy the wallpaper collection (~880 MB, full mode)
#   ENABLE_SERVICES=0|1            enable the systemd user services
#   INSTALL_FLATPAK=0|1            install packages/flatpak-apps.txt
#
# Every file that gets replaced is first moved to  name.bak.YYYYMMDD-HHMMSS.
# Re-running the installer is safe: unchanged files are left alone.
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
HOME_DIR="${HOME:?HOME is not set}"
STAMP="$(date +%Y%m%d-%H%M%S)"
VOXTYPE_VERSION="${VOXTYPE_VERSION:-1.1.0}"
VOXTYPE_FORCE="${VOXTYPE_FORCE:-0}"

# Remember which options were given explicitly, so the interactive setup only
# asks about the rest.
is_set() { [[ -n "${!1+x}" ]]; }
for v in DOTFILES_MODE NOCTALIA KB_LAYOUTS KB_TOGGLE INSTALL_VOXTYPE DOWNLOAD_VOXTYPE_MODEL \
         INSTALL_WALLPAPERS INSTALL_SDDM NOCTALIA_RESET_SETTINGS; do
  is_set "$v" && declare -r "GIVEN_$v=1"
done
given() { local n="GIVEN_$1"; [[ -n "${!n:-}" ]]; }

MODE="${DOTFILES_MODE:-full}"
NOCTALIA="${NOCTALIA:-1}"
NOCTALIA_RESET_SETTINGS="${NOCTALIA_RESET_SETTINGS:-0}"
SKIP_PACKAGES="${SKIP_PACKAGES:-0}"
INSTALL_VOXTYPE="${INSTALL_VOXTYPE:-1}"
DOWNLOAD_VOXTYPE_MODEL="${DOWNLOAD_VOXTYPE_MODEL:-1}"
INSTALL_WALLPAPERS="${INSTALL_WALLPAPERS:-1}"
ENABLE_SERVICES="${ENABLE_SERVICES:-1}"
INSTALL_FLATPAK="${INSTALL_FLATPAK:-0}"
INSTALL_SDDM="${INSTALL_SDDM:-1}"
# A config-only run (SKIP_PACKAGES=1) leaves the system alone unless asked to.
[[ "$SKIP_PACKAGES" == 1 ]] && ! given INSTALL_SDDM && INSTALL_SDDM=0
KB_LAYOUTS="${KB_LAYOUTS:-us,ru}"
KB_TOGGLE="${KB_TOGGLE:-alt_shift}"
KB_VARIANT="${KB_VARIANT:-}"
VOXTYPE_LANGUAGE="${VOXTYPE_LANGUAGE:-}"

INTERACTIVE=0
[[ -t 0 && -t 1 ]] && INTERACTIVE=1

# ── Output helpers (English, or Russian when the locale is ru_*) ─────────────

case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in ru*) UI=ru ;; *) UI=en ;; esac
_() { if [[ "$UI" == ru ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

say()  { printf '\033[1;36m[dotfiles]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[dotfiles] WARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[dotfiles] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }
hr()   { printf '\033[2m%s\033[0m\n' '──────────────────────────────────────────────────────────'; }

TMP_FILES=()
cleanup() { ((${#TMP_FILES[@]})) && rm -f -- "${TMP_FILES[@]}"; return 0; }
trap cleanup EXIT

usage() { sed -n '2,/^set -E/p' "${BASH_SOURCE[0]}" | sed -e '$d' -e 's/^# \{0,1\}//'; }

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    *) die "$(_ "Unknown argument: $arg (try --help)" "Неизвестный аргумент: $arg (см. --help)")" ;;
  esac
done

# confirm "question" y|n   → returns 0 for yes. Without a terminal the default wins.
confirm() {
  local question="$1" default="${2:-n}" hint answer
  [[ "$default" == y ]] && hint='[Y/n]' || hint='[y/N]'
  ((INTERACTIVE)) || { [[ "$default" == y ]]; return; }
  read -r -p "$question $hint " answer || true
  answer="${answer:-$default}"
  [[ "$answer" =~ ^([yYдД]|yes|да|Да)$ ]]
}

# ── Keyboard layouts ─────────────────────────────────────────────────────────

KB_MENU=(us ru ua by kz de fr es pl cz it pt tr gb)
declare -A KB_NAME=(
  [us]="English (US)"      [ru]="Русский / Russian" [ua]="Українська / Ukrainian"
  [by]="Беларуская / Belarusian" [kz]="Қазақша / Kazakh" [de]="Deutsch / German"
  [fr]="Français / French" [es]="Español / Spanish" [pl]="Polski / Polish"
  [cz]="Čeština / Czech"   [it]="Italiano / Italian" [pt]="Português / Portuguese"
  [tr]="Türkçe / Turkish"  [gb]="English (UK)"
)
# XKB layout code → Whisper language / Tesseract language pack.
declare -A KB_WHISPER=(
  [us]=en [gb]=en [ru]=ru [ua]=uk [by]=be [kz]=kk [de]=de [fr]=fr
  [es]=es [pl]=pl [cz]=cs [it]=it [pt]=pt [tr]=tr
)
declare -A KB_TESS=(
  [ru]=rus [ua]=ukr [by]=bel [kz]=kaz [de]=deu [fr]=fra
  [es]=spa [pl]=pol [cz]=ces [it]=ita [pt]=por [tr]=tur
)

# id|label|XKB option. Win+Space is not offered: Mod+Space opens the launcher.
KB_TOGGLES=(
  "alt_shift|Alt + Shift|grp:alt_shift_toggle"
  "ctrl_shift|Ctrl + Shift|grp:ctrl_shift_toggle"
  "caps|Caps Lock (Caps Lock itself stops working)|grp:caps_toggle"
  "ralt|Right Alt|grp:ralt_toggle"
  "lalt|Left Alt|grp:lalt_toggle"
)

kb_valid_code() {
  local code="$1" lst=/usr/share/X11/xkb/rules/evdev.lst
  [[ "$code" =~ ^[a-z][a-z0-9_]{1,15}$ ]] || return 1
  [[ -r "$lst" ]] || return 0   # cannot verify against the XKB database
  awk '/^! layout/{f=1;next} /^!/{f=0} f{print $1}' "$lst" | grep -qx -- "$code"
}

# Turn "1 2 de" / "us,ru" into a clean comma list. Prints it, returns 1 on error.
kb_parse_layouts() {
  local input="${1//,/ }" tok code out=() seen=" "
  for tok in $input; do
    if [[ "$tok" =~ ^[0-9]+$ ]] && ((tok >= 1 && tok <= ${#KB_MENU[@]})); then
      code="${KB_MENU[tok-1]}"
    else
      code="${tok,,}"
    fi
    kb_valid_code "$code" || { printf '%s' "$tok"; return 1; }
    [[ "$seen" == *" $code "* ]] && continue
    seen+="$code "
    out+=("$code")
  done
  ((${#out[@]})) || { printf '%s' "$1"; return 1; }
  local IFS=,
  printf '%s' "${out[*]}"
}

# Resolve KB_TOGGLE (id or raw grp:… option) to an XKB option string.
kb_toggle_option() {
  local entry id label opt
  case "$1" in
    none|"") return 0 ;;
    grp:*)   printf '%s' "$1"; return 0 ;;
  esac
  for entry in "${KB_TOGGLES[@]}"; do
    IFS='|' read -r id label opt <<<"$entry"
    [[ "$id" == "$1" ]] && { printf '%s' "$opt"; return 0; }
  done
  return 1
}

choose_keyboard() {
  local reply bad n code i entry id label opt

  if ((INTERACTIVE)) && ! given KB_LAYOUTS; then
    hr
    _ "Keyboard layouts" "Раскладки клавиатуры"; echo
    _ "Pick the layouts you type in, in order. The first one is active after login." \
      "Выберите раскладки, на которых печатаете. Первая будет активна после входа."; echo
    for i in "${!KB_MENU[@]}"; do
      code="${KB_MENU[i]}"
      printf '  %2d) %-3s %s\n' $((i + 1)) "$code" "${KB_NAME[$code]}"
    done
    _ "  Or type any XKB code yourself (e.g. \"se\", \"jp\"). Examples: \"1 2\"  \"us de\"  \"1,3\"" \
      "  Или введите любой XKB-код (например \"se\", \"jp\"). Примеры: \"1 2\"  \"us de\"  \"1,3\""; echo
    while :; do
      read -r -p "$(_ 'Layouts' 'Раскладки') [1 2 = us,ru]: " reply || true
      reply="${reply:-1 2}"
      if KB_LAYOUTS="$(kb_parse_layouts "$reply")"; then break; fi
      bad="$KB_LAYOUTS"
      warn "$(_ "Unknown layout: $bad" "Неизвестная раскладка: $bad")"
      KB_LAYOUTS=us,ru
    done
  else
    KB_LAYOUTS="$(kb_parse_layouts "$KB_LAYOUTS")" ||
      die "$(_ "Unknown keyboard layout in KB_LAYOUTS: $KB_LAYOUTS" "Неизвестная раскладка в KB_LAYOUTS: $KB_LAYOUTS")"
  fi

  IFS=, read -r -a KB_LIST <<<"$KB_LAYOUTS"

  if ((${#KB_LIST[@]} > 1)); then
    if ((INTERACTIVE)) && ! given KB_TOGGLE; then
      hr
      _ "Shortcut to switch between layouts" "Сочетание для переключения раскладки"; echo
      for i in "${!KB_TOGGLES[@]}"; do
        IFS='|' read -r id label opt <<<"${KB_TOGGLES[i]}"
        printf '  %d) %s\n' $((i + 1)) "$label"
      done
      _ "  (Win+Space is skipped on purpose: it opens the launcher.)" \
        "  (Win+Space намеренно не предлагается: это запуск лаунчера.)"; echo
      while :; do
        read -r -p "$(_ 'Shortcut' 'Сочетание') [1]: " reply || true
        reply="${reply:-1}"
        if [[ "$reply" =~ ^[0-9]+$ ]] && ((reply >= 1 && reply <= ${#KB_TOGGLES[@]})); then
          IFS='|' read -r KB_TOGGLE label opt <<<"${KB_TOGGLES[reply-1]}"
          break
        fi
        warn "$(_ "Enter a number from the list" "Введите номер из списка")"
      done
    fi
    KB_OPTIONS="$(kb_toggle_option "$KB_TOGGLE")" ||
      die "$(_ "Unknown KB_TOGGLE: $KB_TOGGLE (use alt_shift, ctrl_shift, caps, ralt, lalt, none or grp:…)" \
               "Неизвестный KB_TOGGLE: $KB_TOGGLE (alt_shift, ctrl_shift, caps, ralt, lalt, none или grp:…)")"
  else
    KB_OPTIONS=""
  fi

  # Dictation language: first non-English layout, otherwise English.
  if [[ -z "$VOXTYPE_LANGUAGE" ]]; then
    VOXTYPE_LANGUAGE=en
    for code in "${KB_LIST[@]}"; do
      n="${KB_WHISPER[$code]:-en}"
      if [[ "$n" != en ]]; then
        VOXTYPE_LANGUAGE="$n"
        break
      fi
    done
  fi
}

# ── Interactive questions ────────────────────────────────────────────────────

ask_profile() {
  local answer
  ((INTERACTIVE)) || return 0
  if ! given DOTFILES_MODE; then
    hr
    _ "Profile" "Профиль"; echo
    _ "  1) full  – desktop styling, Noctalia shell, pixel fonts and icons, wallpapers" \
      "  1) full  – оформление, Noctalia, пиксельные шрифты и иконки, обои"; echo
    _ "  2) tech  – minimal: Niri config and helper tools only" \
      "  2) tech  – минимум: конфиг Niri и утилиты"; echo
    read -r -p "$(_ 'Profile' 'Профиль') [1]: " answer || true
    MODE="${answer:-1}"
  fi
  if [[ "$MODE" == 1 || "$MODE" == full ]] && ! given INSTALL_WALLPAPERS; then
    confirm "$(_ 'Copy the wallpaper collection to ~/Pictures (~880 MB)?' \
                 'Скопировать коллекцию обоев в ~/Pictures (~880 МБ)?')" y \
      && INSTALL_WALLPAPERS=1 || INSTALL_WALLPAPERS=0
  fi
  if ! given INSTALL_VOXTYPE; then
    confirm "$(_ 'Install offline voice input (Voxtype + ~1.6 GB Whisper model)?' \
                 'Поставить голосовой ввод (Voxtype + модель Whisper ~1.6 ГБ)?')" y \
      && { INSTALL_VOXTYPE=1; DOWNLOAD_VOXTYPE_MODEL=1; } || { INSTALL_VOXTYPE=0; DOWNLOAD_VOXTYPE_MODEL=0; }
  fi
  if ! given INSTALL_SDDM; then
    confirm "$(_ 'Install the SDDM login screen with the pixel-cyberpunk theme?' \
                 'Поставить экран входа SDDM с темой pixel-cyberpunk?')" "$( ((INSTALL_SDDM)) && echo y || echo n)" \
      && INSTALL_SDDM=1 || INSTALL_SDDM=0
  fi
}

normalize_mode() {
  case "$MODE" in
    1|full) MODE=full ;;
    2|tech) MODE=tech ;;
    *) die "$(_ "DOTFILES_MODE must be full or tech (got: $MODE)" "DOTFILES_MODE должен быть full или tech (получено: $MODE)")" ;;
  esac
}

# ── Packages ─────────────────────────────────────────────────────────────────

pacman_install() {
  local list="$ROOT/packages/pacman.txt" pkg code
  command -v pacman >/dev/null 2>&1 || { warn "$(_ 'pacman not found; skipping system packages' 'pacman не найден; системные пакеты пропущены')"; return 0; }
  [[ "$SKIP_PACKAGES" == 1 ]] && { say "$(_ 'SKIP_PACKAGES=1: packages skipped' 'SKIP_PACKAGES=1: пакеты пропущены')"; return 0; }
  command -v sudo >/dev/null 2>&1 || die "$(_ 'sudo is required to install packages' 'Для установки пакетов нужен sudo')"

  mapfile -t packages < <(grep -Ev '^[[:space:]]*(#|$)' "$list")
  [[ "$NOCTALIA" == 0 ]] && mapfile -t packages < <(printf '%s\n' "${packages[@]}" | grep -Ev '^noctalia$')
  if [[ "$INSTALL_SDDM" == 1 ]]; then
    mapfile -t -O "${#packages[@]}" packages < <(grep -Ev '^[[:space:]]*(#|$)' "$ROOT/packages/sddm.txt")
  fi

  # OCR language packs follow the chosen keyboard layouts.
  for code in "${KB_LIST[@]}"; do
    pkg="${KB_TESS[$code]:-}"
    [[ -n "$pkg" ]] || continue
    if pacman -Si "tesseract-data-$pkg" >/dev/null 2>&1; then
      packages+=("tesseract-data-$pkg")
    else
      warn "$(_ "No OCR language pack for '$code' (tesseract-data-$pkg)" "Нет языкового пакета OCR для '$code' (tesseract-data-$pkg)")"
    fi
  done

  # -Syu, not -S: Arch does not support partial upgrades, and with a stale
  # package database a plain -S fails with 404s halfway through.
  say "$(_ 'Updating the system and installing packages (pacman -Syu)…' \
           'Обновление системы и установка пакетов (pacman -Syu)…')"
  sudo pacman -Syu --needed "${packages[@]}"
}

install_noctalia() {
  [[ "$NOCTALIA" == 0 ]] && return 0
  if command -v noctalia >/dev/null 2>&1 || command -v noctalia-shell >/dev/null 2>&1 ||
     (command -v pacman >/dev/null 2>&1 && pacman -Q cachyos-niri-noctalia >/dev/null 2>&1); then
    return 0
  fi
  [[ "$SKIP_PACKAGES" == 1 ]] && { warn "$(_ 'Noctalia is not installed (SKIP_PACKAGES=1)' 'Noctalia не установлена (SKIP_PACKAGES=1)')"; return 0; }
  command -v pacman >/dev/null 2>&1 || die "$(_ 'Noctalia needs pacman' 'Для Noctalia нужен pacman')"
  sudo pacman -S --needed noctalia || sudo pacman -S --needed cachyos-niri-noctalia
}

# ── Voxtype ──────────────────────────────────────────────────────────────────

install_voxtype() {
  [[ "$INSTALL_VOXTYPE" == 1 ]] || { say "$(_ 'Voxtype skipped' 'Voxtype пропущен')"; return 0; }
  local bin="$HOME_DIR/.local/bin/voxtype" arch variant url sha actual tmp
  mkdir -p -- "$HOME_DIR/.local/bin"

  arch="$(uname -m)"
  [[ "$arch" == x86_64 ]] || { warn "$(_ 'Voxtype auto-download supports x86_64 only' 'Автозагрузка Voxtype поддерживает только x86_64')"; return 0; }

  if [[ -x "$bin" && "$VOXTYPE_FORCE" != 1 && "$("$bin" --version 2>/dev/null || true)" == *"voxtype ${VOXTYPE_VERSION}"* ]]; then
    say "$(_ 'Voxtype already installed:' 'Voxtype уже установлен:') $("$bin" --version 2>/dev/null)"
    return 0
  fi

  variant=baseline
  if grep -qE '(^|[[:space:]])avx512f([[:space:]]|$)' /proc/cpuinfo 2>/dev/null; then variant=avx512
  elif grep -qE '(^|[[:space:]])avx2([[:space:]]|$)' /proc/cpuinfo 2>/dev/null; then variant=avx2; fi

  case "$variant" in
    baseline) sha=1c9d78b4f6805e4f12ba3670949d3c22788269bdbc54215afffa42cafd0b4a7a ;;
    avx2)     sha=e7d5de68cc8fc610c3c961c47f879451db9bee4a2df152e9a66f1078072e7f28 ;;
    avx512)   sha=bb2da45c7676bc128da998da928cb239ab6eef9fe53c31c9b4a77e819e521715 ;;
  esac
  url="https://github.com/peteonrails/voxtype/releases/download/v${VOXTYPE_VERSION}/voxtype-${VOXTYPE_VERSION}-linux-x86_64-${variant}"

  command -v curl >/dev/null 2>&1 || die "$(_ 'curl is required to download Voxtype' 'Для загрузки Voxtype нужен curl')"
  tmp="$(mktemp)"; TMP_FILES+=("$tmp")
  say "$(_ "Downloading Voxtype ${VOXTYPE_VERSION} (${variant})" "Загрузка Voxtype ${VOXTYPE_VERSION} (${variant})")"
  curl --fail --location --retry 3 --output "$tmp" "$url"
  actual="$(sha256sum "$tmp" | awk '{print $1}')"
  [[ "$actual" == "$sha" ]] || die "$(_ "Voxtype SHA256 mismatch: expected $sha, got $actual" "SHA256 Voxtype не совпал: ожидался $sha, получен $actual")"
  install -m 0755 "$tmp" "$bin"
}

install_voxtype_model() {
  [[ "$DOWNLOAD_VOXTYPE_MODEL" == 1 ]] || { say "$(_ 'Voxtype model skipped' 'Модель Voxtype пропущена')"; return 0; }
  [[ -x "$HOME_DIR/.local/bin/voxtype" ]] || { warn "$(_ 'Model skipped: Voxtype is not installed' 'Модель пропущена: Voxtype не установлен')"; return 0; }
  if "$HOME_DIR/.local/bin/voxtype" setup --download --model large-v3-turbo --activate --no-post-install; then
    say "$(_ 'Voxtype model large-v3-turbo is ready' 'Модель Voxtype large-v3-turbo готова')"
  else
    warn "$(_ 'Model download failed; retry later with:' 'Не удалось скачать модель; повторите позже командой:')"
    warn "voxtype setup --download --model large-v3-turbo --activate --no-post-install"
  fi
}

# ── Config files ─────────────────────────────────────────────────────────────

N_INSTALLED=0 N_UNCHANGED=0 N_KEPT=0

sed_escape() { printf '%s' "$1" | sed -e 's/[\/&|\\]/\\&/g'; }

# Files that hold @PLACEHOLDERS@ are rendered; everything else is copied as is.
PLACEHOLDERS='@(HOME|KB_LAYOUT|KB_OPTIONS|KB_VARIANT|VOXTYPE_LANG)@'

render() {
  local src="$1" dst="$2"
  if grep -IqE "$PLACEHOLDERS" "$src"; then
    sed -e "s|@HOME@|$(sed_escape "$HOME_DIR")|g" \
        -e "s|@KB_LAYOUT@|$(sed_escape "$KB_LAYOUTS")|g" \
        -e "s|@KB_OPTIONS@|$(sed_escape "$KB_OPTIONS")|g" \
        -e "s|@KB_VARIANT@|$(sed_escape "$KB_VARIANT")|g" \
        -e "s|@VOXTYPE_LANG@|$(sed_escape "$VOXTYPE_LANGUAGE")|g" \
        "$src" >"$dst"
  else
    cp -- "$src" "$dst"
  fi
  chmod --reference="$src" "$dst"
}

backup() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    mv -- "$target" "$target.bak.$STAMP"
    say "backup: ${target/#$HOME_DIR/\~}.bak.$STAMP"
  fi
}

# Files that belong to the user (or are rewritten by the system itself): seeded
# on the first install, never overwritten afterwards.
keep_existing() {
  case "$1" in
    .config/niri/monitor.kdl|.config/user-dirs.dirs|.config/user-dirs.locale) return 0 ;;
  esac
  return 1
}

install_file() {
  local src="$1" rel="$2" dst="$HOME_DIR/$2" tmp
  if keep_existing "$rel" && [[ -e "$dst" ]]; then
    N_KEPT=$((N_KEPT + 1)); return 0
  fi
  tmp="$(mktemp)"; TMP_FILES+=("$tmp")
  render "$src" "$tmp"
  if [[ -e "$dst" ]] && cmp -s -- "$tmp" "$dst"; then
    N_UNCHANGED=$((N_UNCHANGED + 1)); return 0
  fi
  mkdir -p -- "$(dirname -- "$dst")"
  backup "$dst"
  cp -p -- "$tmp" "$dst"
  chmod --reference="$src" "$dst"
  N_INSTALLED=$((N_INSTALLED + 1))
}

# Where does repo file $1 go for the chosen options? Prints nothing to skip it.
destination() {
  local rel="$1"
  case "$rel" in
    # Niri: the Noctalia and the plain variants share one destination.
    .config/niri/config.kdl|.config/niri/cfg/autostart.kdl|.config/niri/cfg/keybinds.kdl)
      [[ "$NOCTALIA" == 1 ]] || return 0 ;;
    *-no-noctalia.kdl)
      [[ "$NOCTALIA" == 0 ]] || return 0
      rel="${rel/-no-noctalia/}" ;;
    .config/niri/noctalia.kdl|.config/noctalia/*)
      [[ "$NOCTALIA" == 1 ]] || return 0 ;;
    .config/systemd/user/*)
      [[ "$ENABLE_SERVICES" == 1 ]] || return 0 ;;
    .config/voxtype/*)
      [[ "$INSTALL_VOXTYPE" == 1 || -x "$HOME_DIR/.local/bin/voxtype" ]] || return 0 ;;
    # Helper scripts: tech uses the light GTK variants, full the overlay ones.
    .local/bin/*-simple)
      [[ "$MODE" == tech ]] || return 0 ;;
    .local/bin/niri-record-region|.local/bin/niri-screenshot-region|.local/bin/niri-record-overlay)
      [[ "$MODE" == full ]] || return 0 ;;
  esac
  printf '%s' "$rel"
}

install_configs() {
  local src rel dest
  mkdir -p -- "$HOME_DIR/.config" "$HOME_DIR/.local/bin"
  say "$(_ 'Installing configuration…' 'Установка конфигурации…')"

  while IFS= read -r -d '' src; do
    rel="${src#"$ROOT/"}"
    dest="$(destination "$rel")"
    [[ -n "$dest" ]] && install_file "$src" "$dest"
  done < <(find "$ROOT/.config" "$ROOT/.local/bin" -type f -print0 | sort -z)

  # The light variants also answer to the regular command names.
  if [[ "$MODE" == tech ]]; then
    install_file "$ROOT/.local/bin/niri-screenshot-region-simple" ".local/bin/niri-screenshot-region"
    install_file "$ROOT/.local/bin/niri-record-region-simple" ".local/bin/niri-record-region"
  fi
}

install_assets() {
  [[ "$MODE" == full ]] || return 0
  say "$(_ 'Installing fonts and icons…' 'Установка шрифтов и иконок…')"
  if [[ -d "$ROOT/.local/share" ]]; then
    mkdir -p -- "$HOME_DIR/.local/share"
    cp -au -- "$ROOT/.local/share/." "$HOME_DIR/.local/share/"
  fi
  if [[ "$INSTALL_WALLPAPERS" == 1 && -d "$ROOT/Pictures" ]]; then
    say "$(_ 'Copying wallpapers…' 'Копирование обоев…')"
    mkdir -p -- "$HOME_DIR/Pictures"
    cp -au -- "$ROOT/Pictures/." "$HOME_DIR/Pictures/"
  fi
  command -v fc-cache >/dev/null 2>&1 && { fc-cache -f "$HOME_DIR/.local/share/fonts" >/dev/null 2>&1 || true; }
  command -v xdg-user-dirs-update >/dev/null 2>&1 && { xdg-user-dirs-update || true; }
  return 0
}

# Noctalia takes its colours from the wallpaper, so the default one is installed
# even when the collection is skipped (or in the tech profile).
install_noctalia_defaults() {
  [[ "$NOCTALIA" == 1 ]] || return 0
  local rel overrides
  rel="$(sed -n 's|^path = "@HOME@/\(.*\)"$|\1|p' "$ROOT/.config/noctalia/config.toml" | head -n 1)"
  if [[ -n "$rel" && -f "$ROOT/$rel" && ! -e "$HOME_DIR/$rel" ]]; then
    mkdir -p -- "$(dirname -- "$HOME_DIR/$rel")"
    cp -p -- "$ROOT/$rel" "$HOME_DIR/$rel"
  fi

  # Settings saved from Noctalia's GUI (or its first-run wizard) override
  # ~/.config/noctalia/config.toml, so an earlier run would hide the rice setup.
  overrides="${NOCTALIA_STATE_HOME:-${XDG_STATE_HOME:-$HOME_DIR/.local/state}}/noctalia/settings.toml"
  [[ -f "$overrides" ]] || return 0
  if [[ "$NOCTALIA_RESET_SETTINGS" == 1 ]] ||
     { ((INTERACTIVE)) && ! given NOCTALIA_RESET_SETTINGS &&
       confirm "$(_ "Noctalia settings saved earlier (${overrides/#$HOME_DIR/\~}) override the rice config. Reset them (a backup is kept)?" \
                    "Сохранённые ранее настройки Noctalia (${overrides/#$HOME_DIR/\~}) перекрывают конфиг rice. Сбросить их (с бэкапом)?")" n; }; then
    mv -- "$overrides" "$overrides.bak.$STAMP"
    say "backup: ${overrides/#$HOME_DIR/\~}.bak.$STAMP"
  fi
}

# ── SDDM login screen ────────────────────────────────────────────────────────

SDDM_THEME=pixel-cyberpunk
SDDM_CONF=zz-pixelstreetart.conf
SDDM_STATUS=skipped
# Test hook for scripts/check.sh: put the system files under this directory
# instead of /, without sudo and without touching systemd.
SYSROOT="${SYSROOT:-}"

as_root() {
  if [[ -n "$SYSROOT" || "$EUID" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

# The theme fails to load without Qt5Compat, and shows no video without the
# multimedia backend. Only reachable with SKIP_PACKAGES=1 or a broken install.
sddm_check_modules() {
  local qml=/usr/lib/qt6/qml missing=()
  [[ -d "$qml/Qt5Compat/GraphicalEffects" ]] || missing+=(qt6-5compat)
  [[ -d "$qml/QtMultimedia" ]] || missing+=(qt6-multimedia)
  compgen -G '/usr/lib/qt6/plugins/multimedia/*ffmpeg*' >/dev/null || missing+=(qt6-multimedia-ffmpeg)
  ((${#missing[@]})) || return 0
  warn "$(_ "The SDDM theme needs: ${missing[*]}  →  sudo pacman -S ${missing[*]}" \
           "Теме SDDM не хватает: ${missing[*]}  →  sudo pacman -S ${missing[*]}")"
}

# /etc/sddm.conf is read after /etc/sddm.conf.d/, so a Current= there would
# silently win over our drop-in. Comment it out, keeping a backup.
sddm_unpin_main_conf() {
  local main="$SYSROOT/etc/sddm.conf"
  [[ -f "$main" ]] || return 0
  awk '/^[[:space:]]*\[/{s=$0} s ~ /^[[:space:]]*\[Theme\]/ && /^[[:space:]]*Current[[:space:]]*=/{f=1} END{exit !f}' "$main" ||
    return 0
  as_root cp -p -- "$main" "$main.bak.$STAMP"
  as_root sed -i '/^[[:space:]]*\[Theme\]/,/^[[:space:]]*\[/ s/^\([[:space:]]*Current[[:space:]]*=\)/# \1/' "$main"
  say "$(_ "Commented out the theme set in /etc/sddm.conf (backup: sddm.conf.bak.$STAMP)" \
           "Закомментирована тема в /etc/sddm.conf (бэкап: sddm.conf.bak.$STAMP)")"
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
  local src="$ROOT/sddm/themes/$SDDM_THEME" themes="$SYSROOT/usr/share/sddm/themes"
  local confd="$SYSROOT/etc/sddm.conf.d"
  local dst="$themes/$SDDM_THEME"

  if [[ -z "$SYSROOT" ]] && ! command -v sddm >/dev/null 2>&1; then
    warn "$(_ 'SDDM is not installed (SKIP_PACKAGES=1?); login screen not configured' \
             'SDDM не установлен (SKIP_PACKAGES=1?); экран входа не настроен')"
    return 0
  fi
  if ! as_root true; then
    warn "$(_ 'No root access; SDDM login screen not configured' 'Нет прав root; экран входа SDDM не настроен')"
    return 0
  fi
  say "$(_ "Installing the SDDM theme $SDDM_THEME…" "Установка темы SDDM $SDDM_THEME…")"

  if ! diff -rq -- "$src" "$dst" >/dev/null 2>&1; then
    as_root mkdir -p -- "$themes"
    if [[ -e "$dst" ]]; then
      # Hidden, so SDDM does not list the backup as a second theme.
      as_root mv -- "$dst" "$themes/.$SDDM_THEME.bak.$STAMP"
      say "backup: $themes/.$SDDM_THEME.bak.$STAMP"
    fi
    as_root cp -r --no-preserve=mode,ownership -- "$src" "$dst"
    # The greeter runs as the sddm user and must be able to read everything.
    as_root chmod -R u=rwX,go=rX -- "$dst"
  fi

  as_root mkdir -p -- "$confd"
  if ! cmp -s -- "$ROOT/sddm/$SDDM_CONF" "$confd/$SDDM_CONF"; then
    as_root install -m 0644 -- "$ROOT/sddm/$SDDM_CONF" "$confd/$SDDM_CONF"
  fi
  sddm_unpin_main_conf
  SDDM_STATUS=enabled

  [[ -z "$SYSROOT" ]] || return 0
  sddm_check_modules
  sddm_enable
}

enable_services() {
  [[ "$ENABLE_SERVICES" == 1 ]] || return 0
  command -v systemctl >/dev/null 2>&1 || { warn "$(_ 'systemctl not found; user services not enabled' 'systemctl не найден; user-сервисы не включены')"; return 0; }
  systemctl --user daemon-reload || true
  systemctl --user enable niri-game-mode.service || true
  if [[ -x "$HOME_DIR/.local/bin/voxtype" ]]; then
    systemctl --user enable voxtype.service voxtype-indicator.service || true
  fi
}

install_flatpak() {
  [[ "$INSTALL_FLATPAK" == 1 ]] || return 0
  command -v flatpak >/dev/null 2>&1 || { warn "$(_ 'flatpak not found' 'flatpak не найден')"; return 0; }
  [[ -f "$ROOT/packages/flatpak-apps.txt" ]] || return 0
  mapfile -t apps < <(grep -Ev '^[[:space:]]*(#|$)' "$ROOT/packages/flatpak-apps.txt")
  ((${#apps[@]})) && flatpak install -y flathub "${apps[@]}"
  return 0
}

validate() {
  command -v niri >/dev/null 2>&1 || return 0
  if niri validate -c "$HOME_DIR/.config/niri/config.kdl" >/dev/null 2>&1; then
    say "$(_ 'Niri config is valid' 'Конфиг Niri валиден')"
  else
    warn "$(_ 'Niri config failed validation; see: niri validate -c ~/.config/niri/config.kdl' \
               'Конфиг Niri не прошёл проверку; смотрите: niri validate -c ~/.config/niri/config.kdl')"
  fi
}

summary() {
  hr
  say "$(_ 'Done.' 'Готово.')  profile=${MODE}  noctalia=${NOCTALIA}  home=${HOME_DIR}"
  say "$(_ "Files: $N_INSTALLED installed, $N_UNCHANGED unchanged, $N_KEPT kept" \
           "Файлы: $N_INSTALLED установлено, $N_UNCHANGED без изменений, $N_KEPT сохранено")"
  say "$(_ 'Keyboard' 'Клавиатура'): ${KB_LAYOUTS}${KB_OPTIONS:+  ($KB_OPTIONS)}"
  say "$(_ '  change later in' '  изменить позже в') ~/.config/niri/cfg/input.kdl"
  say "$(_ 'Monitors: run nwg-displays, or edit ~/.config/niri/monitor.kdl' \
           'Мониторы: запустите nwg-displays или правьте ~/.config/niri/monitor.kdl')"
  if [[ "$SDDM_STATUS" != skipped ]]; then
    say "$(_ "Login screen: SDDM + $SDDM_THEME ($SDDM_STATUS); it appears after a reboot" \
             "Экран входа: SDDM + $SDDM_THEME ($SDDM_STATUS); появится после перезагрузки")"
    say "$(_ '  preview it now:' '  посмотреть сейчас:') sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/$SDDM_THEME"
  fi
  say "$(_ 'Cheat sheet: Mod+Shift+Esc  (Mod = Super/Windows key)' \
           'Шпаргалка по клавишам: Mod+Shift+Esc  (Mod = клавиша Super/Windows)')"
}

# ── Main ─────────────────────────────────────────────────────────────────────

ask_profile
normalize_mode
[[ "$MODE" == tech && ! -v GIVEN_NOCTALIA ]] && NOCTALIA=0
[[ "$NOCTALIA" =~ ^[01]$ ]] || die "NOCTALIA must be 0 or 1"
choose_keyboard

pacman_install
install_noctalia
install_configs
install_assets
install_noctalia_defaults
install_voxtype
install_voxtype_model
install_flatpak
install_sddm
enable_services
validate
summary
