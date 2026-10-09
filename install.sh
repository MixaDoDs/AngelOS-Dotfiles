#!/usr/bin/env bash
# Installer for angelOS — the pastel Niri rice (CachyOS / Arch).
#
# Run it with no arguments for the interactive setup: a pastel "stream" in the terminal
# (gum menus, a hearts progress bar; gum is installed first when it is missing). Or drive it
# with environment variables (everything has a default, so it also works unattended):
#
#   DOTFILES_MODE=full|tech        full = styling + desktop shell + assets, tech = minimal
#   DESKTOP_SHELL=angelos|noctalia|none
#                                  desktop shell (default angelos; tech defaults to none).
#                                  angelOS = the pixel Quickshell shell shipped in .config/quickshell/angelos
#   ANGELOS_THEME=pixel|macos      angelOS's look: pixel = the pink pixel desktop, macos = Golden Gate
#                                  (Dock, menu bar, Liquid Glass, Mac sounds and Mac keys). Asked
#                                  interactively (default pixel); unattended runs leave the current
#                                  one alone unless it is given. Later: Settings → Appearance
#   MAC_KEYS=1|0                   with ANGELOS_THEME=macos: the Mac shortcuts (⌘Q ⌘W ⌘M ⌘Space ⌘Tab…,
#                                  Super = ⌘, tiling on Super+Alt) in front of niri's keys. Asked with
#                                  the theme (default yes); later: Settings → Appearance → Golden Gate
#   FISH_DEFAULT=1|0               fish as the login shell. When fish is not installed yet it is
#                                  installed, added to /etc/shells and made the login shell (chsh);
#                                  asked interactively (default yes), unattended default 1. When fish
#                                  is there already nothing changes, unless FISH_DEFAULT=1 is given.
#                                  fish's look comes with it: the pure prompt, fastfetch, eza, fzf…
#                                  (packages/fish.txt)
#   INSTALL_APPS=0|1               the author's apps (full profile): APPS picks them. Asked
#   APPS=all|games,chat,helium,…   interactively in groups (all ticked = as the author has it);
#                                  unattended default 0. all = the ticked groups; group ids
#                                  (games media chat browsers music graphics dev utils extra) or
#                                  app ids (.config/quickshell/angelos/data/apps-catalog.json).
#                                  pacman first, the AUR through paru, else Flathub
#                                  (scripts/apps-install.py, which remembers the pick: Settings →
#                                  Updates later brings what the author adds to those groups)
#   CACHYOS_REPOS=1|0              Arch Linux (x86_64): add the author's repositories before the
#                                  packages — CachyOS's (for the CPU: v3/v4/znver4, above Arch's;
#                                  the next -Syu takes CachyOS's builds) and [multilib]. Without them
#                                  Helium, qView, LocalSend and Steam can't install
#                                  (scripts/cachyos-repos.sh; default 1; CachyOS has them already)
#   NO_TUI=1                       plain numbered prompts instead of the gum interface
#   NO_ANIM=1                      no boot animation
#   ANGELOS_GAME=1|0               angelOS is also a game played over the desktop (an angel, a demon,
#                                  a story that follows your choices); 0 = plain dotfiles without it.
#                                  Asked interactively; unattended runs leave the current choice alone.
#                                  Later: `angelos game on|off`, Mod+Ctrl+Shift+Escape leaves it at once
#   NOCTALIA=1|0                   legacy switch: NOCTALIA=1 means DESKTOP_SHELL=noctalia
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
#   WALLPAPER_PACKS=all|none|Lain,Pixel,…
#                                  wallpaper packs to download (full mode, default all):
#                                  Lain (~410 MB), Pixel (~187 MB), pixel-art-green-wallpapers (~275 MB),
#                                  Hell (~0.4 MB, the angelOS demon's wallpapers).
#                                  They live in WALLPAPERS_REPO; only the chosen folders are fetched.
#   WALLPAPERS_REPO=<git url>      default https://github.com/MixaDoDs/PixelStreetArt_Wallpapers
#   INSTALL_WALLPAPERS=0|1         older switch: 0 = no packs, 1 = all packs
#   ENABLE_SERVICES=0|1            enable the systemd user services
#   INTRO_SOUNDS=1|0               mix the first run's intro sound now, in the background
#   INSTALL_FLATPAK=0|1            (older switch, ignored: OBS and Blender are in the apps' catalog)
#   INSTALL_TOOLS=1|0              small everyday tools from packages/tools.txt (fish, btop,
#                                  ripgrep, yt-dlp, pavucontrol…; asked interactively, default 1;
#                                  0 together with SKIP_PACKAGES=1)
#   OVERWRITE_CONFIGS=0|1          1 = replace config files you changed too (backed up);
#                                  default 0 keeps them (see below)
#   VALIDATE_NIRI=1|0              check the installed config with `niri validate` (default 1;
#                                  a failure ends the run with an error). Settings → Updates
#                                  passes 0 and validates itself, after wiring the shell
#   DOTFILES_STAMP=YYYYMMDD-HHMMSS suffix of this run's *.bak.<stamp> backups (default: now);
#                                  Settings → Updates passes the stamp of its snapshot
#   DOTFILES_FORCE_DISTRO=0|1      run on a distribution other than Arch Linux or CachyOS anyway
#                                  (refused by default: the packages come from Arch's repositories;
#                                  a config-only run, SKIP_PACKAGES=1 — Settings → Updates — goes on
#                                  with a warning, since it installs no packages)
#   ANGELOS_LANG=ru|en             the language of the messages (default: the locale's)
#   GITHUB_LOGIN=0|1               angelOS: log in to GitHub (gh) and fetch the author's tools
#                                  (the chapter editor) if this account can see the author's
#                                  private repository. Only the author has use for it; for
#                                  everyone else nothing changes. Asked interactively (default
#                                  no), unattended: 0. Later: `angelos author login`
#
# Every file that gets replaced is first moved to  name.bak.YYYYMMDD-HHMMSS.
# Re-running the installer is safe: unchanged files are left alone.
# Updating keeps your settings: a config file you (or angelOS's settings) changed
# since the installer wrote it stays as it is, and its new version is parked in
# ~/.local/state/angelos/kept-updates/ to compare. The installer remembers what it
# wrote in ~/.local/state/angelos/installed-files.sha256; for older installs the
# file is compared with the earlier versions in the repository's history.
# The shell's own code (.config/quickshell/angelos, .local/bin) is always updated.
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
HOME_DIR="${HOME:?HOME is not set}"
STAMP="${DOTFILES_STAMP:-$(date +%Y%m%d-%H%M%S)}"
VALIDATE_NIRI="${VALIDATE_NIRI:-1}"
VOXTYPE_VERSION="${VOXTYPE_VERSION:-1.1.0}"
VOXTYPE_FORCE="${VOXTYPE_FORCE:-0}"

# Remember which options were given explicitly, so the interactive setup only
# asks about the rest.
is_set() { [[ -n "${!1+x}" ]]; }
for v in DOTFILES_MODE DESKTOP_SHELL NOCTALIA KB_LAYOUTS KB_TOGGLE INSTALL_VOXTYPE DOWNLOAD_VOXTYPE_MODEL \
         INSTALL_WALLPAPERS WALLPAPER_PACKS INSTALL_SDDM NOCTALIA_RESET_SETTINGS ANGELOS_GAME GITHUB_LOGIN \
         INSTALL_FLATPAK INSTALL_TOOLS ANGELOS_THEME MAC_KEYS FISH_DEFAULT INSTALL_APPS APPS; do
  is_set "$v" && declare -r "GIVEN_$v=1"
done
given() { local n="GIVEN_$1"; [[ -n "${!n:-}" ]]; }

MODE="${DOTFILES_MODE:-full}"
# NOCTALIA=1/0 given explicitly keeps working as before
if is_set NOCTALIA && [[ "${NOCTALIA}" != 0 && "${NOCTALIA}" != 1 ]]; then
  printf 'NOCTALIA must be 0 or 1\n' >&2
  exit 1
fi
if ! is_set DESKTOP_SHELL && is_set NOCTALIA; then
  [[ "$NOCTALIA" == 1 ]] && DESKTOP_SHELL=noctalia || DESKTOP_SHELL=none
fi
DESKTOP_SHELL="${DESKTOP_SHELL:-angelos}"
NOCTALIA=0
NOCTALIA_RESET_SETTINGS="${NOCTALIA_RESET_SETTINGS:-0}"
SKIP_PACKAGES="${SKIP_PACKAGES:-0}"
INSTALL_VOXTYPE="${INSTALL_VOXTYPE:-1}"
DOWNLOAD_VOXTYPE_MODEL="${DOWNLOAD_VOXTYPE_MODEL:-1}"
INSTALL_WALLPAPERS="${INSTALL_WALLPAPERS:-1}"
INTRO_SOUNDS="${INTRO_SOUNDS:-1}"
WALLPAPERS_REPO="${WALLPAPERS_REPO:-https://github.com/MixaDoDs/PixelStreetArt_Wallpapers}"
# folder|pictures|MB|English|Russian — folders of WALLPAPERS_REPO, copied to ~/Pictures/<folder>
WALLPAPER_LIST=(
  "Lain|136|410|Serial Experiments Lain|Serial Experiments Lain"
  "Pixel|100|187|pixel street art, games, cities|пиксельный стрит-арт, игры, города"
  "pixel-art-green-wallpapers|200|275|green pixel art|зелёный пиксель-арт"
  "Hell|7|1|pixel hell for the angelOS demon (public-domain paintings)|пиксельный ад для демоницы angelOS (картины в общественном достоянии)"
)
if ! is_set WALLPAPER_PACKS; then
  [[ "$INSTALL_WALLPAPERS" == 0 ]] && WALLPAPER_PACKS=none || WALLPAPER_PACKS=all
fi
ENABLE_SERVICES="${ENABLE_SERVICES:-1}"
INSTALL_FLATPAK="${INSTALL_FLATPAK:-0}"
INSTALL_TOOLS="${INSTALL_TOOLS:-1}"
INSTALL_SDDM="${INSTALL_SDDM:-1}"
# A config-only run (SKIP_PACKAGES=1) leaves the system alone unless asked to.
[[ "$SKIP_PACKAGES" == 1 ]] && ! given INSTALL_SDDM && INSTALL_SDDM=0
[[ "$SKIP_PACKAGES" == 1 ]] && ! given INSTALL_TOOLS && INSTALL_TOOLS=0
KB_LAYOUTS="${KB_LAYOUTS:-us,ru}"
KB_TOGGLE="${KB_TOGGLE:-alt_shift}"
KB_VARIANT="${KB_VARIANT:-}"
VOXTYPE_LANGUAGE="${VOXTYPE_LANGUAGE:-}"
ANGELOS_THEME="${ANGELOS_THEME:-pixel}"
MAC_KEYS="${MAC_KEYS:-1}"
FISH_DEFAULT="${FISH_DEFAULT:-1}"
INSTALL_APPS="${INSTALL_APPS:-0}"
CACHYOS_REPOS="${CACHYOS_REPOS:-1}"
APPS="${APPS:-all}"
# fish before this run: a login shell someone already has is never changed behind their back
FISH_WAS_INSTALLED=0
command -v fish >/dev/null 2>&1 && FISH_WAS_INSTALLED=1

INTERACTIVE=0
[[ -t 0 && -t 1 ]] && INTERACTIVE=1

# ── Output helpers (English, or Russian when the locale is ru_*) ─────────────

# ANGELOS_LANG: angelOS's own language, passed by Settings → Updates
case "${ANGELOS_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}" in ru*) UI=ru ;; *) UI=en ;; esac
_() { if [[ "$UI" == ru ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

# colours only on a terminal: Settings → Updates shows this output in its log
c1() { [[ -t 1 && -z "${NO_COLOR:-}" ]] && printf '\033[%sm' "$1"; return 0; }
c2() { [[ -t 2 && -z "${NO_COLOR:-}" ]] && printf '\033[%sm' "$1"; return 0; }
# pastel on a terminal (pink, lilac, a hot-pink warning); a log gets the plain [dotfiles] lines
C_SAY="$(c1 '1;38;2;255;143;199')" C_DIM="$(c1 '38;2;201;167;255')" C_OFF="$(c1 0)"
C_WARN="$(c2 '1;38;2;255;214;120')" C_ERR="$(c2 '1;38;2;255;79;163')" C_OFF2="$(c2 0)"
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  say()  { printf '%s♡%s %s\n' "$C_SAY" "$C_OFF" "$*"; }
else
  say()  { printf '%s[dotfiles]%s %s\n' "$C_SAY" "$C_OFF" "$*"; }
fi
warn() { printf '%s[dotfiles] WARNING:%s %s\n' "$C_WARN" "$C_OFF2" "$*" >&2; }
die()  { printf '%s[dotfiles] ERROR:%s %s\n' "$C_ERR" "$C_OFF2" "$*" >&2; exit 1; }
hr()   { printf '%s%s%s\n' "$C_DIM" '♡ ─────────────────────────────────────────────────────── ♡' "$C_OFF"; }

# the interface (gum menus, hearts, the "stream chat"); plain prompts without a terminal
# shellcheck source=installer/tui.sh
source "$ROOT/installer/tui.sh"

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

# ── The distribution ─────────────────────────────────────────────────────────

# Arch Linux and CachyOS only: every package comes from Arch's official repositories (CachyOS
# uses them too), the AUR is not needed. Others — even Arch-based ones with repositories of
# their own — are refused before anything changes. DOTFILES_OS_RELEASE: another file, for tests.
DISTRO_ID=""
check_distro() {
  local file="${DOTFILES_OS_RELEASE:-/etc/os-release}" id="" like="" name=""
  [[ -r "$file" ]] && { id=$(sed -n 's/^ID=//p' "$file" | tr -d '"'); like=$(sed -n 's/^ID_LIKE=//p' "$file" | tr -d '"');
                        name=$(sed -n 's/^PRETTY_NAME=//p' "$file" | tr -d '"'); }
  DISTRO_ID="$id"
  case "$id" in arch|cachyos) return 0 ;; esac
  # configs only (SKIP_PACKAGES=1, as Settings → Updates runs it): nothing comes from the
  # distribution's repositories, so its own repositories don't matter. Updates of a system
  # installed with DOTFILES_FORCE_DISTRO=1 (Arch Linux ARM, EndeavourOS…) get here
  if [[ "$SKIP_PACKAGES" == 1 ]]; then
    warn "$(_ "${name:-This system} is not Arch Linux or CachyOS; going on: SKIP_PACKAGES=1 installs no packages, only the configs" \
             "${name:-Эта система} — не Arch Linux и не CachyOS; продолжаю: SKIP_PACKAGES=1 ставит только конфиги, без пакетов")"
    return 0
  fi
  [[ "${DOTFILES_FORCE_DISTRO:-0}" == 1 ]] && { warn "$(_ "${name:-This system} is not supported; going on because DOTFILES_FORCE_DISTRO=1" \
                                                        "${name:-Эта система} не поддерживается; продолжаю, потому что DOTFILES_FORCE_DISTRO=1")"; return 0; }
  if [[ " $like " == *" arch "* ]]; then
    die "$(_ "${name:-This system} is based on Arch, but only Arch Linux and CachyOS are supported: its own repositories may differ. DOTFILES_FORCE_DISTRO=1 runs it anyway, at your own risk." \
             "${name:-Эта система} основана на Arch, но поддерживаются только Arch Linux и CachyOS: её репозитории могут отличаться. DOTFILES_FORCE_DISTRO=1 — запустить всё равно, на свой риск.")"
  fi
  die "$(_ "Only Arch Linux and CachyOS are supported (this is ${name:-${id:-an unknown system}}). Nothing was changed." \
           "Поддерживаются только Arch Linux и CachyOS (а здесь ${name:-${id:-неизвестная система}}). Ничего не изменено.")"
}
check_distro

[[ "$STAMP" =~ ^[0-9]{8}-[0-9]{6}(-[0-9]+)?$ ]] || die "DOTFILES_STAMP must look like 20260101-120000 (got: $STAMP)"
[[ "$VALIDATE_NIRI" == 0 || "$VALIDATE_NIRI" == 1 ]] || die "VALIDATE_NIRI must be 0 or 1"
[[ -z "${GITHUB_LOGIN:-}" || "$GITHUB_LOGIN" == 0 || "$GITHUB_LOGIN" == 1 ]] || die "GITHUB_LOGIN must be 0 or 1"

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

  # asked here or given: the setup wizard won't ask again (apply_setup_answers)
  if ((INTERACTIVE)) || given KB_LAYOUTS; then KB_ASKED=1; fi
  if ((INTERACTIVE)) && ! given KB_LAYOUTS && ((TUI)); then
    tui_section "$(_ 'Keyboard layouts' 'Раскладки клавиатуры')" \
      "$(_ 'Tick the ones you type in (space ticks, enter goes on).' 'Отметь те, на которых печатаешь (пробел — отметить, Enter — дальше).')"
    local labels=() picked first other
    for code in "${KB_MENU[@]}"; do labels+=("$(printf '%-3s %s' "$code" "${KB_NAME[$code]}")"); done
    labels+=("$(_ '✎ another XKB code…' '✎ другой XKB-код…')")
    while :; do
      picked="$(ui_choose_many "$(_ 'Layouts' 'Раскладки')" "1 2" "${labels[@]}")"
      reply=""
      for n in $picked; do
        if ((n == ${#labels[@]})); then
          other="$(ui_input "$(_ 'XKB codes, e.g. se jp' 'XKB-коды, например se jp')" "")"
          reply+=" $other"
        else
          reply+=" ${KB_MENU[n-1]}"
        fi
      done
      reply="${reply# }"
      [[ -n "$reply" ]] || reply="us ru"
      if KB_LAYOUTS="$(kb_parse_layouts "$reply")"; then break; fi
      bad="$KB_LAYOUTS"
      warn "$(_ "Unknown layout: $bad" "Неизвестная раскладка: $bad")"
      KB_LAYOUTS=us,ru
    done
    # the first one is active after login
    IFS=, read -r -a picked <<<"$KB_LAYOUTS"
    if ((${#picked[@]} > 1)); then
      labels=()
      for code in "${picked[@]}"; do labels+=("$code  ${KB_NAME[$code]:-}"); done
      first="$(ui_choose "$(_ 'Which one is on after login?' 'Какая включена после входа?')" 1 "${labels[@]}")"
      KB_LAYOUTS="${picked[first-1]}"
      for i in "${!picked[@]}"; do ((i == first - 1)) || KB_LAYOUTS+=",${picked[i]}"; done
    fi
  elif ((INTERACTIVE)) && ! given KB_LAYOUTS; then
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
    if ((INTERACTIVE)) && ! given KB_TOGGLE && ((TUI)); then
      local toggles=()
      for entry in "${KB_TOGGLES[@]}"; do IFS='|' read -r id label opt <<<"$entry"; toggles+=("$label"); done
      tui_note "$(_ '(Win+Space is skipped on purpose: it opens the launcher.)' '(Win+Space намеренно не предлагается: это запуск лаунчера.)')"
      reply="$(ui_choose "$(_ 'Shortcut to switch layouts' 'Сочетание для переключения раскладки')" 1 "${toggles[@]}")"
      IFS='|' read -r KB_TOGGLE label opt <<<"${KB_TOGGLES[reply-1]}"
    elif ((INTERACTIVE)) && ! given KB_TOGGLE; then
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
  tui_boot
  if ! given DOTFILES_MODE; then
    answer="$(ui_choose "$(_ 'Profile' 'Профиль')" 1 \
      "$(_ 'full  – the whole look: angelOS, fonts, icons, wallpapers, the apps' 'full  – весь образ: angelOS, шрифты, значки, обои, программы')" \
      "$(_ 'tech  – minimal: the Niri config and helper tools only' 'tech  – минимум: конфиг Niri и утилиты')")"
    MODE="$answer"
  fi
  if [[ "$MODE" == 1 || "$MODE" == full ]] && ! given DESKTOP_SHELL && ! given NOCTALIA; then
    answer="$(ui_choose "$(_ 'Desktop shell' 'Оболочка рабочего стола')" 1 \
      "$(_ 'angelOS  – the pastel Quickshell shell: bar, Dock, widgets, settings (recommended)' 'angelOS  – пастельная оболочка на Quickshell: панель, Dock, виджеты, настройки (рекомендуется)')" \
      "$(_ 'Noctalia – the previous shell' 'Noctalia – прежняя оболочка')" \
      "$(_ 'none     – plain niri' 'нет      – голый niri')")"
    case "$answer" in
      2) DESKTOP_SHELL=noctalia ;;
      3) DESKTOP_SHELL=none ;;
      *) DESKTOP_SHELL=angelos ;;
    esac
  fi
  if [[ "${DESKTOP_SHELL:-angelos}" == angelos && ("$MODE" == 1 || "$MODE" == full) ]] && ! given ANGELOS_THEME; then
    tui_section "$(_ 'Theme' 'Тема')" \
      "$(_ 'Pixel: the pink pixel desktop — Start, lyrics, the angel. macOS (Golden Gate): Dock, menu bar,' 'Pixel: розовый пиксельный стол — «Пуск», лирика, ангел. macOS (Golden Gate): Dock, строка меню,')" \
      "$(_ 'Liquid Glass, Mac sounds and ⌘ keys. Switch any time: Settings → Appearance.' 'Liquid Glass, маковские звуки и клавиши ⌘. Сменить можно когда угодно: Настройки → Оформление.')"
    answer="$(ui_choose "$(_ 'Which look?' 'Какой образ?')" 1 \
      "$(_ 'Pixel  – angelOS, pink pixels ♡' 'Pixel  – angelOS, розовые пиксели ♡')" \
      "$(_ 'macOS  – Golden Gate: Dock, Liquid Glass, Mac keys' 'macOS  – Golden Gate: Dock, Liquid Glass, клавиши Mac')")"
    [[ "$answer" == 2 ]] && ANGELOS_THEME=macos || ANGELOS_THEME=pixel
    # shellcheck disable=SC2034  # read through given()
    GIVEN_ANGELOS_THEME=1
    if [[ "$ANGELOS_THEME" == macos ]] && ! given MAC_KEYS; then
      ui_confirm "$(_ 'Mac shortcuts too? ⌘Q quits, ⌘W closes, ⌘M minimizes to the Dock, ⌘Space is Spotlight, ⌘Tab switches apps (⌘ = the Super key; tiling moves to Super+Alt)' \
                      'И маковские сочетания? ⌘Q — завершить, ⌘W — закрыть, ⌘M — свернуть в Dock, ⌘Пробел — Spotlight, ⌘Tab — программы (⌘ — клавиша Super; тайлинг уходит на Super+Alt)')" y \
        && MAC_KEYS=1 || MAC_KEYS=0
      # shellcheck disable=SC2034  # read through given()
      GIVEN_MAC_KEYS=1
    fi
  fi
  if [[ "${DESKTOP_SHELL:-angelos}" == angelos && ("$MODE" == 1 || "$MODE" == full) ]] && ! given ANGELOS_GAME; then
    ui_confirm "$(_ 'angelOS is also a game played over your desktop: an angel in the corner, and a story that follows your choices. Play it? (No = plain dotfiles; `angelos game on|off` changes it later)' \
                    'angelOS — это ещё и игра поверх рабочего стола: ангел в углу и история, которая идёт за твоими выборами. Играть? (Нет — обычные дотфайлы; потом: `angelos game on|off`)')" y \
      && ANGELOS_GAME=1 || ANGELOS_GAME=0
    # shellcheck disable=SC2034  # read through given()
    GIVEN_ANGELOS_GAME=1
  fi
  if [[ "$MODE" == 1 || "$MODE" == full ]] && ! given INSTALL_WALLPAPERS && ! given WALLPAPER_PACKS; then
    choose_wallpapers
  fi
  if ! given FISH_DEFAULT && ((FISH_WAS_INSTALLED == 0)) && [[ "$SKIP_PACKAGES" != 1 ]]; then
    ui_confirm "$(_ 'fish is not installed. Install it with the pure prompt, fastfetch, eza and fzf, and make it your login shell?' \
                    'fish не установлен. Поставить его (prompt pure, fastfetch, eza, fzf) и сделать оболочкой входа?')" y \
      && FISH_DEFAULT=1 || FISH_DEFAULT=0
    # shellcheck disable=SC2034  # read through given()
    GIVEN_FISH_DEFAULT=1
  fi
  if [[ "$MODE" == 1 || "$MODE" == full ]] && ! given INSTALL_APPS && ! given APPS && [[ "$SKIP_PACKAGES" != 1 ]]; then
    choose_apps
  fi
  if ! given INSTALL_VOXTYPE; then
    ui_confirm "$(_ 'Install offline voice input (Voxtype + ~1.6 GB Whisper model)?' \
                    'Поставить голосовой ввод (Voxtype + модель Whisper ~1.6 ГБ)?')" y \
      && { INSTALL_VOXTYPE=1; DOWNLOAD_VOXTYPE_MODEL=1; } || { INSTALL_VOXTYPE=0; DOWNLOAD_VOXTYPE_MODEL=0; }
  fi
  if ! given INSTALL_SDDM; then
    ui_confirm "$(_ 'Install the SDDM login screen with the pixel-cyberpunk theme?' \
                    'Поставить экран входа SDDM с темой pixel-cyberpunk?')" "$( ((INSTALL_SDDM)) && echo y || echo n)" \
      && INSTALL_SDDM=1 || INSTALL_SDDM=0
  fi
  if ! given INSTALL_TOOLS && [[ "$SKIP_PACKAGES" != 1 && -s "$ROOT/packages/tools.txt" ]]; then
    local tools
    tools="$(grep -Ev '^[[:space:]]*(#|$)' "$ROOT/packages/tools.txt" | head -8 | paste -sd',' - | sed 's/,/, /g')…"
    ui_confirm "$(_ "Also install small everyday tools ($tools, packages/tools.txt)?" \
                    "Поставить ещё мелкие утилиты на каждый день ($tools, packages/tools.txt)?")" "$( ((INSTALL_TOOLS)) && echo y || echo n)" \
      && INSTALL_TOOLS=1 || INSTALL_TOOLS=0
  fi
  local m="$MODE"; [[ "$m" == 1 ]] && m=full; [[ "$m" == 2 ]] && m=tech
  tui_section "$(_ 'Ready to go live' 'Готовы к эфиру')" \
    "$(_ "profile $m · shell ${DESKTOP_SHELL} · theme ${ANGELOS_THEME} · the layouts come next" \
         "профиль $m · оболочка ${DESKTOP_SHELL} · тема ${ANGELOS_THEME} · дальше — раскладки")"
}

# ── The author's apps (full profile) ─────────────────────────────────────────

# The catalog .config/quickshell/angelos/data/apps-catalog.json (the setup wizard's too): what the
# author has, in groups. scripts/apps-install.py installs the picked ones (pacman, the AUR through
# paru, Flathub) and remembers the pick, so Settings → Updates later brings the apps the author
# adds to the groups taken here (nothing is ever removed).
APPS_PY="$ROOT/.config/quickshell/angelos/scripts/apps-install.py"
declare -A APP_EN=() APP_RU=() APP_HINT_EN=() APP_HINT_RU=()
APP_GROUPS=()   # id|default|English|Russian|app,ids
load_apps() {
  ((${#APP_GROUPS[@]})) && return 0
  local kind id a b c d
  while IFS=$'\t' read -r kind id a b c d; do
    if [[ "$kind" == G ]]; then
      APP_GROUPS+=("$id|$a|$b|$c|$d")
    elif [[ "$kind" == A ]]; then
      APP_EN["$id"]="$a" APP_RU["$id"]="$b" APP_HINT_EN["$id"]="$c" APP_HINT_RU["$id"]="$d"
    fi
  done < <(python3 "$APPS_PY" tsv 2>/dev/null)
}

# the catalog is read with python3 — a bare Arch Linux may not have it before its packages
need_python() {
  command -v python3 >/dev/null 2>&1 && return 0
  [[ "$SKIP_PACKAGES" != 1 ]] && command -v pacman >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1 || return 1
  say "$(_ 'The list of apps needs python (from the official repositories)' 'Списку программ нужен python (из официальных репозиториев)')"
  sudo pacman -S --needed --noconfirm python >/dev/null && command -v python3 >/dev/null 2>&1
}

APPS_ASKED=0
choose_apps() {
  local entry gid def en ru ids labels=() pre="" picked n i g_ids=() app_ids=() apps_of=() id
  need_python || { warn "$(_ 'python3 is missing: the apps are skipped (later: Settings → Updates)' 'нет python3: программы пропущены (потом: Настройки → Обновления)')"; return 0; }
  load_apps
  ((${#APP_GROUPS[@]})) || return 0
  for entry in "${APP_GROUPS[@]}"; do
    IFS='|' read -r gid def en ru ids <<<"$entry"
    local names=() ; for id in ${ids//,/ }; do names+=("$(_ "${APP_EN[$id]}" "${APP_RU[$id]}")"); done
    local list; list="$(printf '%s, ' "${names[@]}")"
    labels+=("$(_ "$en" "$ru") — ${list%, }")
    [[ "$def" == 1 ]] && pre+="${#labels[@]} "
  done
  tui_section "$(_ "The author's apps" 'Программы автора')" \
    "$(_ "Everything angelOS's author has, in groups. Ticked = as the author has it; untick what you don't want. Updates later bring what the author adds to the groups you take." \
         'Всё, что стоит у автора angelOS, по группам. Отмечено — как у автора; сними лишнее. Потом обновления доставят то, что автор добавит в выбранные группы.')"
  picked="$(ui_choose_many "$(_ 'Groups' 'Группы')" "$pre" "${labels[@]}")"
  for n in $picked; do g_ids+=("${APP_GROUPS[n-1]}"); done
  APPS_ASKED=1
  if ((${#g_ids[@]})) && ui_confirm "$(_ 'Open the groups and untick single apps?' 'Раскрыть группы и снять отдельные программы?')" n; then
    for entry in "${g_ids[@]}"; do
      IFS='|' read -r gid def en ru ids <<<"$entry"
      IFS=, read -ra apps_of <<<"$ids"; labels=() pre=""
      for id in "${apps_of[@]}"; do
        labels+=("$(_ "${APP_EN[$id]} — ${APP_HINT_EN[$id]}" "${APP_RU[$id]} — ${APP_HINT_RU[$id]}")")
        pre+="${#labels[@]} "
      done
      picked="$(ui_choose_many "$(_ "$en" "$ru")" "$pre" "${labels[@]}")"
      for n in $picked; do app_ids+=("${apps_of[n-1]}"); done
    done
  else
    for entry in "${g_ids[@]}"; do
      IFS='|' read -r gid def en ru ids <<<"$entry"
      IFS=, read -ra apps_of <<<"$ids"; app_ids+=("${apps_of[@]}")
    done
  fi
  APPS="$(IFS=,; echo "${app_ids[*]:-}")"
  if [[ -n "$APPS" ]]; then INSTALL_APPS=1; else INSTALL_APPS=0; APPS=none; fi
}

# APPS → app ids, one per line: all = the default groups (as the author has it); a group id
# stands for its apps; none/0/no = nothing
chosen_apps() {
  local entry gid def en ru ids want
  case "${APPS,,}" in ""|none|0|no) return 0 ;; esac
  load_apps
  for want in ${APPS//,/ }; do
    want="${want,,}"
    if [[ -n "${APP_EN[$want]:-}" ]]; then echo "$want"; continue; fi
    for entry in "${APP_GROUPS[@]}"; do
      IFS='|' read -r gid def en ru ids <<<"$entry"
      if [[ "$want" == "$gid" || ( "$want" == all && "$def" == 1 ) ]]; then printf '%s\n' ${ids//,/ }; fi
    done
  done | awk '!seen[$0]++'
}

# ── Wallpaper packs ──────────────────────────────────────────────────────────

choose_wallpapers() {
  local i entry id count mb en ru answer total=0 picked=()
  if ((TUI)); then
    local labels=() all="" n
    for i in "${!WALLPAPER_LIST[@]}"; do
      IFS='|' read -r id count mb en ru <<<"${WALLPAPER_LIST[i]}"
      labels+=("$(printf '%-27s %s' "$id" "$(_ "$count pictures, ~$mb MB — $en" "$count картинок, ~$mb МБ — $ru")")")
      all+="$((i + 1)) "
    done
    tui_section "$(_ 'Wallpaper packs' 'Паки обоев')" "$(_ "downloaded from $WALLPAPERS_REPO; none = only the 3 default pictures" \
                                                          "скачиваются из $WALLPAPERS_REPO; ничего — только 3 картинки по умолчанию")"
    for n in $(ui_choose_many "$(_ 'Packs' 'Паки')" "$all" "${labels[@]}"); do picked+=("${WALLPAPER_LIST[n-1]%%|*}"); done
    if ((${#picked[@]})); then WALLPAPER_PACKS="$(IFS=,; echo "${picked[*]}")"; else WALLPAPER_PACKS=none; fi
    return 0
  fi
  _ "Wallpaper packs (downloaded from $WALLPAPERS_REPO)" "Паки обоев (скачиваются из $WALLPAPERS_REPO)"; echo
  for i in "${!WALLPAPER_LIST[@]}"; do
    IFS='|' read -r id count mb en ru <<<"${WALLPAPER_LIST[i]}"
    total=$((total + mb))
    printf '  %d) %-28s %s\n' "$((i + 1))" "$id" "$(_ "$count pictures, ~$mb MB — $en" "$count картинок, ~$mb МБ — $ru")"
  done
  _ "  a) all (~$total MB)    n) none (only the 3 default pictures)" \
    "  a) все (~$total МБ)    n) никаких (только 3 картинки по умолчанию)"; echo
  read -r -p "$(_ 'Packs, e.g. 1 3' 'Паки, например 1 3') [a]: " answer || true
  case "${answer:-a}" in
    a|A|all|все|а|А) WALLPAPER_PACKS=all ;;
    n|N|none|0|нет|н|Н) WALLPAPER_PACKS=none ;;
    *)
      for i in ${answer//,/ }; do
        [[ "$i" =~ ^[0-9]+$ ]] && ((i >= 1 && i <= ${#WALLPAPER_LIST[@]})) || continue
        picked+=("${WALLPAPER_LIST[i-1]%%|*}")
      done
      if ((${#picked[@]})); then WALLPAPER_PACKS="$(IFS=,; echo "${picked[*]}")"; else WALLPAPER_PACKS=none; fi
      ;;
  esac
}

# WALLPAPER_PACKS → folder names, one per line: exact names (any case) or a part of
# one name ("lain", "green"); unknown or ambiguous ones are skipped with a warning
wallpaper_folders() {
  local want entry name id hits
  case "${WALLPAPER_PACKS,,}" in
    ""|none|0|no) return 0 ;;
    all|1|yes) for entry in "${WALLPAPER_LIST[@]}"; do echo "${entry%%|*}"; done; return 0 ;;
  esac
  for want in ${WALLPAPER_PACKS//,/ }; do
    id="" hits=0
    for entry in "${WALLPAPER_LIST[@]}"; do
      name="${entry%%|*}"
      [[ "${name,,}" == "${want,,}" ]] && { id="$name"; hits=1; break; }
      [[ "${name,,}" == *"${want,,}"* ]] && { id="$name"; hits=$((hits + 1)); }
    done
    if ((hits == 1)); then echo "$id"
    else warn "$(_ "Unknown wallpaper pack: $want" "Неизвестный пак обоев: $want")"; fi
  done | awk '!seen[$0]++'
}

# Only the chosen folders are fetched (partial clone + sparse checkout).
install_wallpaper_packs() {
  local folders tmp
  mapfile -t folders < <(wallpaper_folders)
  ((${#folders[@]})) || return 0
  if ! command -v git >/dev/null 2>&1; then
    warn "$(_ 'git is missing: wallpaper packs skipped' 'Нет git: паки обоев пропущены')"
    return 0
  fi
  say "$(_ "Downloading wallpapers: ${folders[*]}…" "Скачиваю обои: ${folders[*]}…")"
  tmp="$(mktemp -d)"
  if git clone --quiet --depth 1 --filter=blob:none --sparse -- "$WALLPAPERS_REPO" "$tmp/w" &&
     git -C "$tmp/w" sparse-checkout set -- "${folders[@]}"; then
    mkdir -p -- "$HOME_DIR/Pictures"
    for f in "${folders[@]}"; do
      [[ -d "$tmp/w/$f" ]] && cp -au -- "$tmp/w/$f" "$HOME_DIR/Pictures/"
    done
    say "$(_ 'Wallpapers are in ~/Pictures' 'Обои лежат в ~/Pictures')"
  else
    warn "$(_ "Could not download wallpapers from $WALLPAPERS_REPO; run the installer again later" \
               "Не удалось скачать обои из $WALLPAPERS_REPO; запустите установщик позже ещё раз")"
  fi
  rm -rf -- "$tmp"
  return 0
}

normalize_mode() {
  case "$MODE" in
    1|full) MODE=full ;;
    2|tech) MODE=tech ;;
    *) die "$(_ "DOTFILES_MODE must be full or tech (got: $MODE)" "DOTFILES_MODE должен быть full или tech (получено: $MODE)")" ;;
  esac
}

# ── Packages ─────────────────────────────────────────────────────────────────

# names on stdin → the ones the configured repositories have; the rest are skipped with a word
# (a few live only in CachyOS's repositories: on Arch Linux they are the AUR's, which we don't use)
available_only() {
  local pkg
  while IFS= read -r pkg; do
    if pacman -Si -- "$pkg" >/dev/null 2>&1 || pacman -Q -- "$pkg" >/dev/null 2>&1; then
      echo "$pkg"
    else
      warn "$(_ "$pkg is not in your repositories (CachyOS has it): skipped" "$pkg нет в ваших репозиториях (он есть в CachyOS): пропущен")"
    fi
  done
}

# Will ~/.config/nvim be the LazyVim config of this repository? (as install_configs decides)
nvim_will_be_ours() {
  [[ ! -e "$HOME_DIR/.config/nvim" ]] && return 0
  [[ -f "$MANIFEST" ]] && grep -q '  \.config/nvim/init\.lua$' "$MANIFEST"
}

# The author's repositories (CACHYOS_REPOS): on Arch Linux every package and app of the
# installer comes from pacman as on the author's CachyOS — without [cachyos] Helium, qView and
# LocalSend were "not in your repositories", without [multilib] Steam. Before the package list:
# available_only asks the repositories as they will be.
cachyos_repos() {
  local script="$ROOT/.config/quickshell/angelos/scripts/cachyos-repos.sh"
  [[ "$CACHYOS_REPOS" == 1 && "$DISTRO_ID" == arch && "$(uname -m)" == x86_64 ]] || return 0
  bash "$script" --check && return 0
  say "$(_ "Adding the author's repositories: CachyOS's (for your CPU) and [multilib] — so every app installs with pacman" \
           'Подключаю репозитории автора: CachyOS (под твой процессор) и [multilib] — чтобы все программы ставились через pacman')"
  sudo bash "$script" ||
    warn "$(_ "The CachyOS repositories were not added (scripts/cachyos-repos.sh): Helium, qView, LocalSend and Steam may be skipped" \
              'Репозитории CachyOS не подключились (scripts/cachyos-repos.sh): Helium, qView, LocalSend и Steam могут не поставиться')"
}

pacman_install() {
  local list="$ROOT/packages/pacman.txt" pkg code
  command -v pacman >/dev/null 2>&1 || { warn "$(_ 'pacman not found; skipping system packages' 'pacman не найден; системные пакеты пропущены')"; return 0; }
  [[ "$SKIP_PACKAGES" == 1 ]] && { say "$(_ 'SKIP_PACKAGES=1: packages skipped' 'SKIP_PACKAGES=1: пакеты пропущены')"; return 0; }
  command -v sudo >/dev/null 2>&1 || die "$(_ 'sudo is required to install packages' 'Для установки пакетов нужен sudo')"
  cachyos_repos

  mapfile -t packages < <(grep -Ev '^[[:space:]]*(#|$)' "$list")
  [[ "$NOCTALIA" == 0 ]] && mapfile -t packages < <(printf '%s\n' "${packages[@]}" | grep -Ev '^noctalia$')
  if [[ "$DESKTOP_SHELL" == angelos && -f "$ROOT/packages/angelos.txt" ]]; then
    mapfile -t -O "${#packages[@]}" packages < <(grep -Ev '^[[:space:]]*(#|$)' "$ROOT/packages/angelos.txt")
  fi
  if [[ "$INSTALL_SDDM" == 1 ]]; then
    mapfile -t -O "${#packages[@]}" packages < <(grep -Ev '^[[:space:]]*(#|$)' "$ROOT/packages/sddm.txt")
  fi
  if [[ "$INSTALL_TOOLS" == 1 && -f "$ROOT/packages/tools.txt" ]]; then
    mapfile -t -O "${#packages[@]}" packages < <(grep -Ev '^[[:space:]]*(#|$)' "$ROOT/packages/tools.txt")
  fi
  # fish and its look (pure, fastfetch, eza, fzf…); CachyOS's own config package is skipped on Arch
  if [[ "$INSTALL_TOOLS" == 1 || "$FISH_DEFAULT" == 1 ]] && [[ -f "$ROOT/packages/fish.txt" ]]; then
    mapfile -t -O "${#packages[@]}" packages < <(grep -Ev '^[[:space:]]*(#|$)' "$ROOT/packages/fish.txt" | available_only)
  fi
  # what LazyVim needs (it installs its plugins itself on the first start) — only with our config
  if nvim_will_be_ours && [[ -f "$ROOT/packages/nvim.txt" ]]; then
    mapfile -t -O "${#packages[@]}" packages < <(grep -Ev '^[[:space:]]*(#|$)' "$ROOT/packages/nvim.txt")
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
  # angelOS Meta tap reads the keyboards via evdev (issue #6); the group applies after re-login
  [[ "$DESKTOP_SHELL" == angelos ]] && ! id -nG "$USER" | grep -qw input && sudo usermod -aG input "$USER" || true
}

# angelOS is tested on Quickshell 0.3.2: an older one (a stale mirror, a pinned package)
# runs without its crash fixes, older than 0.3.0 not at all. The shell's own
# scripts/qs-version.sh decides, the shell asks it too (Settings → System).
QS_STATE=""
quickshell_check() {
  [[ "$DESKTOP_SHELL" == angelos ]] || return 0
  local script="$ROOT/.config/quickshell/angelos/scripts/qs-version.sh" state found want
  [[ -f "$script" ]] || return 0
  read -r state found want < <(sh "$script" 2>/dev/null || true) || true
  QS_STATE="$state"
  case "$state" in
    old) warn "$(_ "Quickshell $found is older than $want: angelOS runs, but without its crash fixes — update the quickshell package" \
                   "Quickshell $found старее $want: angelOS запустится, но без исправлений падений — обнови пакет quickshell")" ;;
    too-old) warn "$(_ "Quickshell $found is too old for angelOS (needs $want): update the quickshell package, then log in again" \
                       "Quickshell $found слишком старый для angelOS (нужен $want): обнови пакет quickshell и перезайди")" ;;
    missing) warn "$(_ 'Quickshell is not installed: angelOS needs the quickshell package' \
                       'Quickshell не установлен: angelOS нужен пакет quickshell')" ;;
  esac
  return 0
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

N_INSTALLED=0 N_UNCHANGED=0 N_KEPT=0 N_PARKED=0 N_MERGED=0
MERGED=()     # configs the user had changed that took the author's changes (merge_config)
OVERWRITE_CONFIGS="${OVERWRITE_CONFIGS:-0}"
STATE_DIR="${XDG_STATE_HOME:-$HOME_DIR/.local/state}/angelos"
MANIFEST="$STATE_DIR/installed-files.sha256"
PARKED_DIR="$STATE_DIR/kept-updates"
BASES_DIR="$STATE_DIR/key-profile-bases"   # the repository versions merges start from (key profiles, configs)
declare -A PREV_SUM=() NEW_SUM=()
# filled once per run by install_configs (one grep, two sha256sum runs instead of a few
# processes per file): repo files holding a placeholder, checksums of repo and installed files
declare -A HAS_PH=() SRC_SUM=() DST_SUM=() MADE_DIR=()
NVIM_OURS=0
NIRI_FOREIGN=0

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
# on the first install, never overwritten afterwards. mimeapps.list holds the
# default apps (browser, file manager…) that apps and angelOS's settings set.
keep_existing() {
  case "$1" in
    .config/niri/monitor.kdl|.config/user-dirs.dirs|.config/user-dirs.locale|.config/mimeapps.list) return 0 ;;
    # the terminal Settings → Default apps picked; the file manager's places
    .config/xdg-terminals.list|.config/gtk-3.0/bookmarks|.config/gtk-4.0/bookmarks) return 0 ;;
  esac
  return 1
}

# Two layers: the author's configs are the base, the user's changes go on top. A config the user
# never changed simply follows the author on every update. One they changed (by hand, or through
# angelOS's settings) is merged three ways (merge_config: git merge-file): base = the version the
# installer put there last time, ours = the file as it is, theirs = the repository's now. What the
# author changed comes in; where both changed the same lines, the user's lines win — the author's
# are the backup. The key profiles merge by key instead (merge_key_profile). Files angelOS
# generates (the palette's theme files, GTK's, fastfetch's style; Noctalia's and Voxtype's own)
# are not merged: the user's stay, the new version is parked. So is anything without a known base
# (an install older than the manifest), and everything on the author's own machine (owner/).
# One's own lines can also go in files the repository never ships, read last:
# ~/.config/fish/user.fish and ~/.config/niri/cfg/user.kdl (its binds and rules win).
generated() {
  case "$1" in
    .config/niri/angelos.kdl|.config/kitty/themes/*|.config/foot/themes/*|.config/alacritty/themes/*) return 0 ;;
    .config/btop/themes/*|.config/gtk-3.0/*|.config/gtk-4.0/*|.config/fastfetch/*) return 0 ;;
    .config/noctalia/*|.config/voxtype/*|.config/nvim/lazy-lock.json) return 0 ;;
  esac
  return 1
}
mergeable() { # a text config of the author's (not the shell's code, a font or an icon)
  [[ "$1" == .config/* ]] && ! is_program "$1" && ! generated "$1" || return 1
  case "$1" in *.png|*.svg|*.ttf|*.otf|*.otb|*.cache) return 1 ;; esac
  return 0
}
OWNER_HOME=0
[[ -d "$HOME_DIR/.config/quickshell/angelos/owner" ]] && OWNER_HOME=1

# niri's config.kdl replaced: the includes angelOS's services added to it (cfg/angelos-windows.kdl,
# -laptop, -minimize; CachyOS's cfg/display.kdl) go into the new one too, before user.kdl
carry_includes() { # old-file new-file
  local line missing=()
  while IFS= read -r line; do
    grep -qxF -- "$line" "$2" || missing+=("$line")
  done < <(grep -E '^include "\./cfg/(angelos-[a-z0-9-]+|display)\.kdl"$' "$1" 2>/dev/null)
  ((${#missing[@]})) || return 0
  python3 - "$2" "${missing[@]}" <<'PY' 2>/dev/null || printf '%s\n' "${missing[@]}" >>"$2"
import sys
path, lines = sys.argv[1], sys.argv[2:]
text = open(path).read()
anchor = "\n// yours, read last"
add = "".join(l + "\n" for l in lines)
text = text.replace(anchor, "\n" + add + anchor, 1) if anchor in text else text.rstrip("\n") + "\n" + add
open(path, "w").write(text)
PY
}

sum_of() { sha256sum -- "$1" | cut -d' ' -f1; }

# sums_into MAP FILE… : MAP[file]=sha256 for every FILE that exists, in one sha256sum run
sums_into() {
  local -n into="$1"; shift
  local line
  (($#)) || return 0
  while IFS= read -r -d '' line; do
    # shellcheck disable=SC2034  # a nameref: the caller's map
    into["${line#*  }"]="${line%%  *}"
  done < <(printf '%s\0' "$@" | xargs -0 -r sha256sum -z -- 2>/dev/null)
}

# CUR = the installed file's checksum: from the run's first look, unless it changed since
dst_sum() { CUR="${DST_SUM[$1]:-}"; [[ -n "$CUR" ]] || CUR="$(sum_of "$1")"; }

mkdir_for() { # the folder of file $1, made once per run
  local dir="${1%/*}"
  [[ -n "${MADE_DIR[$dir]:-}" ]] || { mkdir -p -- "$dir"; MADE_DIR["$dir"]=1; }
}

load_manifest() {
  local sum rel
  [[ -f "$MANIFEST" ]] || return 0
  while read -r sum rel; do
    [[ -n "$rel" ]] && PREV_SUM["$rel"]="$sum"
  done <"$MANIFEST"
}

save_manifest() {
  local rel
  mkdir -p -- "$STATE_DIR"
  for rel in "${!NEW_SUM[@]}"; do
    printf '%s  %s\n' "${NEW_SUM[$rel]}" "$rel"
  done | sort -k2 >"$MANIFEST.tmp" && mv -f -- "$MANIFEST.tmp" "$MANIFEST"
}

# Files the installer itself changed after installing them (rewiring): record
# them as they are now, so the next update does not take them for the user's.
remember() {
  local rel
  for rel in "$@"; do
    [[ -f "$HOME_DIR/$rel" ]] && NEW_SUM["$rel"]="$(sum_of "$HOME_DIR/$rel")"
  done
  save_manifest
}

# A niri config angelOS never wrote — the one niri makes on its first start, CachyOS's own
# (cfg/keybinds.kdl with Noctalia's keys)… Kept as "the user's changes", it left angelOS's
# keys, rules and theme unplugged while Settings → Shortcuts listed them. The whole of it is
# replaced instead (each file backed up); outputs from CachyOS's cfg/display.kdl move to
# monitor.kdl. Ours = known to the manifest, or wired like angelOS's config.kdl.
niri_foreign_check() {
  local cfg="$HOME_DIR/.config/niri/config.kdl" old="$HOME_DIR/.config/niri/cfg/display.kdl"
  NIRI_FOREIGN=0
  [[ -f "$cfg" && -z "${PREV_SUM[.config/niri/config.kdl]:-}" ]] || return 0
  grep -Eq '^[[:space:]]*include "(angelos|noctalia)\.kdl"|^[[:space:]]*include "(\./)?cfg/(game-mode|privacy-block)\.kdl"' "$cfg" && return 0
  NIRI_FOREIGN=1
  if [[ -f "$old" && ! -e "$HOME_DIR/.config/niri/monitor.kdl" ]] && grep -Eq '^[[:space:]]*output[[:space:]]' "$old"; then
    cp -- "$old" "$HOME_DIR/.config/niri/monitor.kdl"
  fi
}
niri_foreign() { [[ "$NIRI_FOREIGN" == 1 && "$1" == .config/niri/* ]]; }

# The shell's own code: always brought up to date (the old copy is backed up).
is_program() {
  case "$1" in
    .config/quickshell/angelos/*|.local/bin/*) return 0 ;;
  esac
  return 1
}

# Is the file at $2 still what the installer put there? The manifest says so for
# installs that have one; before it existed, any earlier version of the repo
# file $3 (rendered like now) counts as untouched.
untouched() {
  local rel="$1" dst="$2" srel="$3" cur h raw tmp CUR
  dst_sum "$dst"; cur="$CUR"
  if [[ -n "${PREV_SUM[$rel]:-}" ]]; then
    [[ "$cur" == "${PREV_SUM[$rel]}" ]]
    return
  fi
  git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || return 1
  raw="$(mktemp)" tmp="$(mktemp)"; TMP_FILES+=("$raw" "$tmp")
  while read -r h; do
    git -C "$ROOT" show "$h:$srel" >"$raw" 2>/dev/null || continue
    render "$raw" "$tmp"
    [[ "$(sum_of "$tmp")" == "$cur" ]] && return 0
  done < <(git -C "$ROOT" log --format=%H -n 80 -- "$srel" 2>/dev/null)
  return 1
}

install_file() {
  local src="$1" rel="$2" dst="$HOME_DIR/$2" new sum CUR srel="${1#"$ROOT/"}"
  if keep_existing "$rel" && [[ -e "$dst" ]]; then
    N_KEPT=$((N_KEPT + 1)); return 0
  fi
  # $new: the repository's version as it lands here — the repo file itself, or rendered
  # (placeholders filled, the theme's key profile picked) into a temporary file
  if [[ -n "${HAS_PH[$src]:-}" || -z "${SRC_SUM[$src]:-}" || "$rel" == .config/niri/cfg/keybinds.kdl ]]; then
    new="$(mktemp)"; TMP_FILES+=("$new")
    render "$src" "$new"
    [[ "$rel" == .config/niri/cfg/keybinds.kdl ]] && key_profile_into "$new" "$dst"
    sum="$(sum_of "$new")"
  else
    new="$src" sum="${SRC_SUM[$src]}"
  fi
  if [[ -e "$dst" ]] && dst_sum "$dst" && [[ "$CUR" == "$sum" ]]; then
    NEW_SUM["$rel"]="$sum"
    save_base "$rel" "$new"
    N_UNCHANGED=$((N_UNCHANGED + 1)); return 0
  fi
  # changed since the installer wrote it (by hand, or by angelOS's settings:
  # hotkeys, animations, the default browser…): the user's version stays —
  # a theme's key profile gets the repository's new keys merged in around the user's
  # changed since the installer wrote it: merged (the user's lines win), else the user's stays
  # and the new version is parked
  if [[ -e "$dst" && "$OVERWRITE_CONFIGS" != 1 ]] && ! is_program "$rel" && ! niri_foreign "$rel" \
     && ! untouched "$rel" "$dst" "$srel"; then
    if ((OWNER_HOME == 0)); then
      merge_key_profile "$rel" "$dst" "$srel" "$new" "$src" && return 0
      merge_config "$rel" "$dst" "$srel" "$new" "$src" && return 0
    fi
    mkdir -p -- "$(dirname -- "$PARKED_DIR/$rel")"
    cp -- "$new" "$PARKED_DIR/$rel"
    chmod --reference="$src" "$PARKED_DIR/$rel"
    [[ -n "${PREV_SUM[$rel]:-}" ]] && NEW_SUM["$rel"]="${PREV_SUM[$rel]}"
    N_PARKED=$((N_PARKED + 1)); return 0
  fi
  mkdir_for "$dst"
  backup "$dst"
  unset 'DST_SUM[$dst]'
  cp -- "$new" "$dst"
  chmod --reference="$src" "$dst"
  NEW_SUM["$rel"]="$sum"
  if [[ "$rel" == .config/niri/config.kdl && -e "$dst.bak.$STAMP" ]]; then
    carry_includes "$dst.bak.$STAMP" "$dst"
    NEW_SUM["$rel"]="$(sum_of "$dst")"   # as it is now: the next update takes it for untouched
  fi
  save_base "$rel" "$new"
  N_INSTALLED=$((N_INSTALLED + 1))
}

# The themes' niri key profiles (cfg/keybinds-{common,pixel,macos}.kdl) are edited by
# Settings → Shortcuts, so they are the user's — and still have to receive the keys
# angelOS adds or changes. An update merges them three ways (scripts/keyprofile.py merge):
# base = the repository's version the installer put there last time (a copy in
# $BASES_DIR, else found in git history by the manifest's checksum), ours = the file as it
# is, new = the repository's now. Keys the user left as they came follow the repository,
# new keys come in unless the user binds that key or took it out, the user's own stay.
# The manifest keeps the repository version's checksum, not the merged file's: the next
# update sees the user's edits again and merges again. No base, or a file it can't merge
# (multi-line binds): parked like any other config.
is_key_profile() { [[ "$1" =~ ^\.config/niri/cfg/keybinds-(common|pixel|macos)\.kdl$ ]]; }

save_base() { # rel rendered-repo-file
  is_key_profile "$1" || mergeable "$1" || return 0
  mkdir -p -- "$(dirname -- "$BASES_DIR/$1")" && cp -- "$2" "$BASES_DIR/$1" || true
}

base_of() { # rel repo-file dest: the repository's version the installer put at rel last time
  local rel="$1" srel="$2" dest="$3" want="${PREV_SUM[$1]:-}" h raw
  [[ -n "$want" ]] || return 1
  if [[ -f "$BASES_DIR/$rel" && "$(sum_of "$BASES_DIR/$rel")" == "$want" ]]; then
    cp -- "$BASES_DIR/$rel" "$dest"; return 0
  fi
  git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || return 1
  raw="$(mktemp)"; TMP_FILES+=("$raw")
  while read -r h; do
    git -C "$ROOT" show "$h:$srel" >"$raw" 2>/dev/null || continue
    render "$raw" "$dest"
    [[ "$(sum_of "$dest")" == "$want" ]] && return 0
  done < <(git -C "$ROOT" log --format=%H -n 200 -- "$srel" 2>/dev/null)
  return 1
}

merge_key_profile() { # rel installed-file repo-file rendered-new src
  local rel="$1" dst="$2" srel="$3" tmp="$4" src="$5" base merged
  is_key_profile "$rel" && command -v python3 >/dev/null 2>&1 || return 1
  base="$(mktemp)" merged="$(mktemp)"; TMP_FILES+=("$base" "$merged")
  base_of "$rel" "$srel" "$base" || return 1
  python3 "$ROOT/.config/quickshell/angelos/scripts/keyprofile.py" merge "$base" "$dst" "$tmp" >"$merged" 2>/dev/null \
    && [[ -s "$merged" ]] || return 1
  NEW_SUM["$rel"]="$(sum_of "$tmp")"
  save_base "$rel" "$tmp"
  if cmp -s -- "$merged" "$dst"; then
    N_UNCHANGED=$((N_UNCHANGED + 1)); return 0
  fi
  backup "$dst"
  cp -- "$merged" "$dst"
  chmod --reference="$src" "$dst"
  N_MERGED=$((N_MERGED + 1))
}

# git merge-file --diff3's output on stdin → resolved (see merge_config)
MERGE_RESOLVE='
import sys
out, part, ours, base, theirs = [], None, [], [], []
for line in sys.stdin.read().splitlines(keepends=True):
    if line.startswith("<<<<<<< ") and part is None:
        part, ours, base, theirs = "ours", [], [], []
    elif line.startswith("||||||| ") and part == "ours":
        part = "base"
    elif line.startswith("=======") and part == "base":
        part = "theirs"
    elif line.startswith(">>>>>>> ") and part == "theirs":
        out += ours
        if not "".join(base).strip():
            out += [l for l in theirs if l not in ours]
        part = None
    elif part == "ours":
        ours.append(line)
    elif part == "base":
        base.append(line)
    elif part == "theirs":
        theirs.append(line)
    else:
        out.append(line)
if part is not None:
    sys.exit(1)
sys.stdout.write("".join(out))
'

merge_config() { # rel installed-file repo-file rendered-new src — see generated()
  local rel="$1" dst="$2" srel="$3" new="$4" src="$5" base merged
  mergeable "$rel" && command -v git >/dev/null 2>&1 || return 1
  grep -Iq . "$dst" 2>/dev/null || [[ ! -s "$dst" ]] || return 1   # text only
  base="$(mktemp)" merged="$(mktemp)"; TMP_FILES+=("$base" "$merged")
  base_of "$rel" "$srel" "$base" || return 1
  # conflicts: both added lines at one place → both stay (the user's first); both changed the
  # same lines → the user's stay
  if command -v python3 >/dev/null 2>&1; then
    { git merge-file -p --diff3 -- "$dst" "$base" "$new" 2>/dev/null; [[ $? -lt 128 ]]; } |
      python3 -c "$MERGE_RESOLVE" >"$merged" && [[ "${PIPESTATUS[0]}" == 0 ]] || return 1
  else
    git merge-file -p --ours -- "$dst" "$base" "$new" >"$merged" 2>/dev/null || return 1
  fi
  # the manifest keeps the repository version's checksum: the next update merges again
  NEW_SUM["$rel"]="$(sum_of "$new")"
  save_base "$rel" "$new"
  if cmp -s -- "$merged" "$dst"; then
    N_UNCHANGED=$((N_UNCHANGED + 1)); return 0
  fi
  backup "$dst"
  unset 'DST_SUM[$dst]'
  cp -- "$merged" "$dst"
  chmod --reference="$src" "$dst"
  MERGED+=("$rel")
  N_MERGED=$((N_MERGED + 1))
}

# A merged niri file that niri refuses (two edits that only made sense apart): the user's own
# version goes back and the author's new one is parked — never a desktop that doesn't start
niri_merge_guard() {
  local rel bad=() cfg="$HOME_DIR/.config/niri/config.kdl"
  ((${#MERGED[@]})) && command -v niri >/dev/null 2>&1 && [[ -f "$cfg" ]] || return 0
  niri validate -c "$cfg" >/dev/null 2>&1 && return 0
  for rel in "${MERGED[@]}"; do
    [[ "$rel" == .config/niri/* && -e "$HOME_DIR/$rel.bak.$STAMP" ]] || continue
    mkdir -p -- "$(dirname -- "$PARKED_DIR/$rel")"
    cp -- "$HOME_DIR/$rel" "$PARKED_DIR/$rel"
    mv -f -- "$HOME_DIR/$rel.bak.$STAMP" "$HOME_DIR/$rel"
    bad+=("$rel"); N_PARKED=$((N_PARKED + 1)); N_MERGED=$((N_MERGED - 1))
  done
  ((${#bad[@]})) && warn "$(_ "niri refused the merged ${bad[*]}: yours kept, the author's new version parked" \
                               "niri не принял слитые ${bad[*]}: оставлены твои, новая версия автора отложена")"
  local keep=() m b
  for m in "${MERGED[@]}"; do
    for b in "${bad[@]}"; do [[ "$m" == "$b" ]] && continue 2; done
    keep+=("$m")
  done
  MERGED=("${keep[@]}")
}

# The theme's niri keys: cfg/keybinds.kdl picks the pixel or the Mac profile (angelOS's
# scripts/keyprofile.py switches it when the theme changes later). The installed copy of the
# selector already says the chosen one: ANGELOS_THEME when asked or given, else the profile
# the installed selector has now — an update never flips someone's Mac keys back.
key_profile_into() { # rendered-file installed-file
  local want=pixel
  if given ANGELOS_THEME; then
    [[ "$DESKTOP_SHELL" == angelos && "$ANGELOS_THEME" == macos && "$MAC_KEYS" == 1 ]] && want=macos
  elif [[ -f "$2" ]] && grep -Eq '^[[:space:]]*include "(\./)?keybinds-macos\.kdl"' "$2"; then
    want=macos
  fi
  [[ "$want" == macos ]] && sed -i 's/keybinds-pixel\.kdl/keybinds-macos.kdl/' "$1"
  return 0
}

# Where does repo file $1 go for the chosen options? Sets DEST, empty to skip it.
destination() {
  local rel="$1"
  DEST=""
  case "$rel" in
    */__pycache__/*|*.pyc|*.bak.*|.config/quickshell/angelos/owner/*) return 0 ;;
    # Niri: the Noctalia and the plain variants share one destination.
    # Niri: the shell-wired files (angelOS in the repo; rewired for Noctalia after install)
    # and the plain variants share one destination.
    .config/niri/config.kdl|.config/niri/cfg/autostart.kdl|.config/niri/cfg/keybinds.kdl)
      [[ "$DESKTOP_SHELL" != none ]] || return 0 ;;
    *-no-noctalia.kdl)
      [[ "$DESKTOP_SHELL" == none ]] || return 0
      rel="${rel/-no-noctalia/}" ;;
    .config/niri/noctalia.kdl|.config/noctalia/*)
      [[ "$NOCTALIA" == 1 ]] || return 0 ;;
    .config/quickshell/angelos/*)
      [[ "$DESKTOP_SHELL" != none ]] || return 0 ;;
    .config/systemd/user/*)
      [[ "$ENABLE_SERVICES" == 1 ]] || return 0 ;;
    .config/voxtype/*)
      [[ "$INSTALL_VOXTYPE" == 1 || -x "$HOME_DIR/.local/bin/voxtype" ]] || return 0 ;;
    # Neovim with LazyVim: a whole config or nothing — never mixed into someone's own
    .config/nvim/*)
      [[ "$NVIM_OURS" == 1 ]] || return 0 ;;
    # Helper scripts: tech uses the light GTK variants, full the overlay ones.
    .local/bin/*-simple)
      [[ "$MODE" == tech ]] || return 0 ;;
    .local/bin/niri-record-region|.local/bin/niri-screenshot-region|.local/bin/niri-record-overlay)
      [[ "$MODE" == full ]] || return 0 ;;
  esac
  DEST="$rel"
}

install_configs() {
  local src i
  mkdir -p -- "$HOME_DIR/.config" "$HOME_DIR/.local/bin"
  say "$(_ 'Installing configuration…' 'Установка конфигурации…')"
  load_manifest
  rm -rf -- "$PARKED_DIR"
  niri_foreign_check
  # the Neovim config goes in only where there is none yet, or where it is the one we put there
  if [[ ! -e "$HOME_DIR/.config/nvim" || -n "${PREV_SUM[.config/nvim/init.lua]:-}" ]]; then
    NVIM_OURS=1
  else
    NVIM_OURS=0
    say "$(_ 'The LazyVim config is not installed: ~/.config/nvim is your own' \
             'Конфиг LazyVim не ставится: ~/.config/nvim — ваш')"
  fi

  local -a srcs=() rels=() dsts=()
  while IFS= read -r -d '' src; do
    destination "${src#"$ROOT/"}"
    [[ -n "$DEST" ]] || continue
    srcs+=("$src"); rels+=("$DEST"); dsts+=("$HOME_DIR/$DEST")
  done < <(find "$ROOT/.config" "$ROOT/.local/bin" -type f -print0 | sort -z)
  HAS_PH=() SRC_SUM=() DST_SUM=() MADE_DIR=()
  while IFS= read -r -d '' src; do HAS_PH["$src"]=1; done \
    < <(printf '%s\0' "${srcs[@]}" | xargs -0 -r grep -lIZE -- "$PLACEHOLDERS" 2>/dev/null)
  sums_into SRC_SUM "${srcs[@]}"
  sums_into DST_SUM "${dsts[@]}"
  for i in "${!srcs[@]}"; do
    install_file "${srcs[i]}" "${rels[i]}"
  done

  user_layer
  niri_merge_guard

  # The light variants also answer to the regular command names.
  if [[ "$MODE" == tech ]]; then
    install_file "$ROOT/.local/bin/niri-screenshot-region-simple" ".local/bin/niri-screenshot-region"
    install_file "$ROOT/.local/bin/niri-record-region-simple" ".local/bin/niri-record-region"
  fi
  save_manifest
}

# The user's own layer (see generated()): made once with a word on what it is, never touched again
user_layer() {
  local kdl="$HOME_DIR/.config/niri/cfg/user.kdl" fish="$HOME_DIR/.config/fish/user.fish"
  if [[ -f "$HOME_DIR/.config/niri/config.kdl" && ! -e "$kdl" ]]; then
    mkdir -p -- "${kdl%/*}"
    cat >"$kdl" <<'KDL'
// Yours: niri reads this file last, so a bind or a rule here wins over angelOS's.
// Updates bring the author's changes into the rest of ~/.config/niri; this file is never touched.
// For example:
// binds {
//     Mod+Shift+T { spawn "foot"; }
// }
KDL
  fi
  if [[ -d "$HOME_DIR/.config/fish" && ! -e "$fish" ]]; then
    cat >"$fish" <<'FISH'
# Yours: config.fish reads this file last, so what you set here wins. Updates bring the
# author's changes into config.fish; this file is never touched. For example:
# alias ll 'eza -l'
FISH
  fi
  return 0
}

install_assets() {
  [[ "$MODE" == full ]] || return 0
  say "$(_ 'Installing fonts and icons…' 'Установка шрифтов и иконок…')"
  if [[ -d "$ROOT/.local/share" ]]; then
    mkdir -p -- "$HOME_DIR/.local/share"
    cp -au -- "$ROOT/.local/share/." "$HOME_DIR/.local/share/"
  fi
  # the few default pictures ship with the dotfiles; the packs come from WALLPAPERS_REPO
  if [[ -d "$ROOT/Pictures" ]]; then
    mkdir -p -- "$HOME_DIR/Pictures"
    cp -au -- "$ROOT/Pictures/." "$HOME_DIR/Pictures/"
  fi
  install_wallpaper_packs
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
  # a password dialog even when the shell's own polkit agent is not up (hyprpolkitagent as the fallback)
  [[ -f "$HOME_DIR/.config/systemd/user/polkit-agent-guard.service" ]] &&
    { systemctl --user enable polkit-agent-guard.service || true; }
  if [[ -x "$HOME_DIR/.local/bin/voxtype" ]]; then
    systemctl --user enable voxtype.service voxtype-indicator.service || true
  fi
}

# angelOS: CLI on PATH, theme files for kitty/foot/gtk/niri, shell wiring.
# On the first login angelOS opens its setup wizard and then the interface tips.
# What was asked here is not asked again by angelOS's setup wizard: the game on or off
# (ANGELOS_GAME, when asked or given) → settings.json game.enabled and setup.gameAsked; the
# keyboard layouts (asked or KB_LAYOUTS given) → setup.keyboardAsked. The rest of the file
# stays as it is; the player's save (save.json) is never touched.
apply_setup_answers() {
  local game=""
  if given ANGELOS_GAME; then
    [[ "$ANGELOS_GAME" == 0 || "$ANGELOS_GAME" == 1 ]] || die "ANGELOS_GAME must be 0 or 1"
    game="$ANGELOS_GAME"
  fi
  local theme=""
  given ANGELOS_THEME && theme="$ANGELOS_THEME"
  [[ -n "$game" || -n "${KB_ASKED:-}" || -n "$theme" ]] || return 0
  local f="$HOME_DIR/.config/angelos/settings.json"
  mkdir -p -- "${f%/*}"
  python3 - "$f" "$game" "${KB_ASKED:-}" "$theme" "$MAC_KEYS" <<'PY' || warn "$(_ 'Could not write the answers into settings.json' 'Не удалось записать ответы в settings.json')"
import json, os, sys, tempfile
path, game, kb, theme, mac_keys = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4], sys.argv[5] == "1"
d = {}
if os.path.exists(path):
    with open(path) as f:
        d = json.load(f)
before = json.dumps(d, sort_keys=True)
if game:
    d.setdefault("game", {})["enabled"] = game == "1"
    d.setdefault("setup", {})["gameAsked"] = True
# only before the wizard is done (an update passes the layouts on too: nothing to write then)
if kb and not d.get("setup", {}).get("complete"):
    d.setdefault("setup", {})["keyboardAsked"] = True
# the look: pixel = angelOS's classic skin, macos = Golden Gate; picked = the wizard won't ask
if theme:
    ui = d.setdefault("settingsUi", {})
    ui["skin"] = "goldengate" if theme == "macos" else "classic"
    ui["skinChosen"] = True
    if theme == "macos":
        d.setdefault("mac", {})["keys"] = mac_keys
if json.dumps(d, sort_keys=True) == before:
    sys.exit(0)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".settings-")
with os.fdopen(fd, "w") as f:
    json.dump(d, f, ensure_ascii=False, indent=4)
os.replace(tmp, path)
PY
}

install_shell() {
  local shell_dir="$HOME_DIR/.config/quickshell/angelos"
  [[ "$DESKTOP_SHELL" != none && -d "$shell_dir" ]] || return 0
  if [[ "$DESKTOP_SHELL" == angelos ]]; then
    say "$(_ 'Setting up angelOS…' 'Настройка angelOS…')"
    apply_setup_answers
    ln -sfn "$shell_dir/bin/angelos" "$HOME_DIR/.local/bin/angelos"
    mkdir -p -- "$HOME_DIR/.config/angelos"
    printf 'angelos\n' > "$HOME_DIR/.config/angelos/active"
    # where Settings → Updates pulls from
    printf 'repo=%s\nremote=%s\n' "$ROOT" "$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)" \
      > "$HOME_DIR/.config/angelos/dotfiles-source"
    # the first run's intro: its minute of sound is mixed now (~20 s, in the background), not
    # while the wizard waits for it (scripts/intro-sounds.py; INTRO_SOUNDS=0: never)
    if [[ "$INTRO_SOUNDS" == 1 ]] && command -v python3 >/dev/null 2>&1 && command -v ffmpeg >/dev/null 2>&1; then
      (setsid python3 "$shell_dir/scripts/intro-sounds.py" "$HOME_DIR/.local/share/angelos/sounds/intro" >/dev/null 2>&1 &)
    fi
    # Fresh installs have no owner marker. Preserve an existing owner's marker
    # so updating the dotfiles does not disable their publishing controls.
    # The generated theme files are shipped with the repository and are
    # installed by install_configs. Do not regenerate them here: doing so
    # would overwrite the shipped palette and make a second install dirty.
  else
    # Noctalia: the repo ships angelOS wiring; rewrite it for Noctalia in place
    python3 "$shell_dir/scripts/switch.py" noctalia-forward >/dev/null 2>&1 \
      || warn "$(_ 'Could not wire niri for Noctalia' 'Не удалось переключить niri на Noctalia')"
    # the rewired files are the installer's own work, not the user's changes
    remember .config/niri/config.kdl .config/niri/cfg/autostart.kdl .config/niri/cfg/keybinds.kdl
  fi
}

# fish as the login shell (FISH_DEFAULT): fish installed by this run is added to /etc/shells
# and made the login shell; one that was there before is left as it is unless asked for.
# SYSROOT (tests): /etc/shells under it and a log line instead of chsh.
setup_fish_shell() {
  [[ "$FISH_DEFAULT" == 1 ]] || return 0
  if ((FISH_WAS_INSTALLED)) || [[ "$SKIP_PACKAGES" == 1 ]]; then given FISH_DEFAULT || return 0; fi
  local fish shells="$SYSROOT/etc/shells" user current
  fish="$(command -v fish 2>/dev/null || true)"
  if [[ -z "$fish" ]]; then
    warn "$(_ 'fish is not installed: the login shell stays as it is' 'fish не установлен: оболочка входа остаётся прежней')"
    return 0
  fi
  user="$(id -un)"
  if ! grep -qx -- "$fish" "$shells" 2>/dev/null; then
    as_root mkdir -p -- "${shells%/*}"
    printf '%s\n' "$fish" | as_root tee -a -- "$shells" >/dev/null
    say "$(_ "$fish added to /etc/shells" "$fish добавлен в /etc/shells")"
  fi
  if [[ -n "$SYSROOT" ]]; then
    printf '%s %s\n' "$user" "$fish" >>"$SYSROOT/chsh.log"
  else
    current="$(getent passwd "$user" | cut -d: -f7)"
    if [[ "$current" == "$fish" ]]; then
      say "$(_ 'fish is your login shell already' 'fish уже оболочка входа')"; return 0
    fi
    as_root chsh -s "$fish" "$user" ||
      { warn "$(_ "Could not change the login shell: chsh -s $fish" "Не удалось сменить оболочку входа: chsh -s $fish")"; return 0; }
  fi
  say "$(_ 'fish is your login shell from the next login ♡' 'fish — оболочка входа со следующего входа ♡')"
  fish_prompt_fallback
}

# Arch Linux has no fish-pure-prompt package: fisher fetches the same prompt (and done) instead
fish_prompt_fallback() {
  [[ -n "$SYSROOT" ]] && return 0
  [[ -d /usr/share/fish/vendor_functions.d && -f /usr/share/fish/vendor_functions.d/fish_prompt.fish ]] && return 0
  command -v fish >/dev/null 2>&1 && fish -c 'type -q fisher' 2>/dev/null || return 0
  fish -c 'fisher install pure-fish/pure franciscolourenco/done jorgebucaran/autopair.fish' >/dev/null 2>&1 &&
    say "$(_ 'fish: the pure prompt installed with fisher' 'fish: prompt pure поставлен через fisher')" ||
    warn "$(_ 'fisher could not fetch the pure prompt (offline?): fish keeps its own prompt' 'fisher не скачал prompt pure (нет сети?): у fish останется свой prompt')"
}

# the author's apps: scripts/apps-install.py installs them (pacman, the AUR, Flathub) and remembers
# the pick; "none" picked in the menu is remembered too (updates then offer only new groups' apps… none)
install_apps() {
  [[ "$SKIP_PACKAGES" != 1 ]] || return 0
  local ids=()
  [[ "$INSTALL_APPS" == 1 ]] && mapfile -t ids < <(chosen_apps)
  if ((${#ids[@]} == 0)); then
    ((APPS_ASKED)) && command -v python3 >/dev/null 2>&1 && python3 "$APPS_PY" pick >/dev/null 2>&1
    return 0
  fi
  need_python || { warn "$(_ 'python3 is missing: the apps are skipped' 'нет python3: программы пропущены')"; return 0; }
  ANGELOS_LANG="$UI" python3 "$APPS_PY" install --no-wait "${ids[@]}" ||
    warn "$(_ 'Not every app installed (see above); again: Settings → Updates → the apps' \
              'Не все программы поставились (смотри выше); ещё раз: Настройки → Обновления → программы')"
  return 0
}

# gum draws the interface; it is installed before the first question (or plain prompts stay)
bootstrap_tui() {
  ((INTERACTIVE)) || return 0
  if [[ "${NO_TUI:-0}" != 1 ]] && ! command -v gum >/dev/null 2>&1 && [[ "$SKIP_PACKAGES" != 1 ]] &&
     command -v pacman >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
    say "$(_ "The installer's interface is drawn with gum (a small tool from the official repositories)." \
             'Интерфейс установщика рисует gum (маленькая утилита из официальных репозиториев).')"
    if confirm "$(_ 'Install gum now? (No = plain text prompts)' 'Поставить gum сейчас? (Нет — обычные текстовые вопросы)')" y; then
      sudo pacman -S --needed gum || warn "$(_ 'gum did not install: plain prompts it is' 'gum не установился: будут обычные вопросы')"
    fi
  fi
  tui_detect
}

# A config niri refuses would leave the next login without a desktop: the run
# ends with an error (after the summary) instead of "Done".
NIRI_INVALID=0
validate() {
  local out
  [[ "$VALIDATE_NIRI" == 1 ]] || return 0
  if ! command -v niri >/dev/null 2>&1; then
    warn "$(_ 'niri is not installed: the Niri config was NOT validated' 'niri не установлен: конфиг Niri НЕ проверен')"
    return 0
  fi
  if out="$(niri validate -c "$HOME_DIR/.config/niri/config.kdl" 2>&1)"; then
    say "$(_ 'Niri config is valid' 'Конфиг Niri валиден')"
  else
    printf '%s\n' "$out" | tail -n 20 >&2
    NIRI_INVALID=1
  fi
}

summary() {
  hr
  say "$(_ 'Done.' 'Готово.')  profile=${MODE}  shell=${DESKTOP_SHELL}  home=${HOME_DIR}"
  if [[ "$DESKTOP_SHELL" == angelos ]] && given ANGELOS_THEME; then
    say "$(_ "Theme: $ANGELOS_THEME (later: Settings → Appearance)" "Тема: $ANGELOS_THEME (потом: Настройки → Оформление)")"
  fi
  if [[ "$INSTALL_APPS" == 1 ]]; then
    say "$(_ "Apps: $APPS" "Программы: $APPS")"
  fi
  if [[ "$DESKTOP_SHELL" == angelos ]]; then
    say "$(_ 'angelOS: on the first login a setup wizard and interface tips open by themselves;' \
             'angelOS: при первом входе сами откроются мастер настройки и подсказки по интерфейсу;')"
    say "$(_ '  later: Mod+S — settings, `angelos help` — CLI' '  потом: Mod+S — настройки, `angelos help` — CLI')"
    say "$(_ '  next updates: Settings → Updates' '  следующие обновления: Настройки → Обновления')"
    [[ -z "$QS_STATE" || "$QS_STATE" == ok ]] ||
      warn "$(_ 'angelOS: Quickshell needs an update (see the warning above)' 'angelOS: Quickshell нужно обновить (см. предупреждение выше)')"
  fi
  say "$(_ "Files: $N_INSTALLED installed, $N_UNCHANGED unchanged, $N_KEPT kept" \
           "Файлы: $N_INSTALLED установлено, $N_UNCHANGED без изменений, $N_KEPT сохранено")"
  if ((N_MERGED - ${#MERGED[@]} > 0)); then
    say "$(_ "Shortcuts: angelOS's new keys merged into $((N_MERGED - ${#MERGED[@]})) key profile(s), yours kept (backup: *.bak.$STAMP)" \
             "Горячие клавиши: новые клавиши angelOS добавлены в $((N_MERGED - ${#MERGED[@]})) профил(я/ей), твои сохранены (бэкап: *.bak.$STAMP)")"
  fi
  if [[ "$NIRI_FOREIGN" == 1 ]]; then
    say "$(_ "Niri: the config that was there was not angelOS's — replaced, so angelOS's keys work (the old one: ~/.config/niri/*.bak.$STAMP)" \
             "Niri: прежний конфиг был не от angelOS — заменён, чтобы работали клавиши angelOS (старый: ~/.config/niri/*.bak.$STAMP)")"
  fi
  if ((${#MERGED[@]})); then
    say "$(_ "The author's changes merged into ${#MERGED[@]} config file(s) you had changed — where you both changed the same lines, yours stay (before: *.bak.$STAMP):" \
             "Изменения автора влиты в ${#MERGED[@]} конфиг(ов), которые ты менял — где вы оба меняли одни строки, остались твои (как было: *.bak.$STAMP):")"
    printf '   ~/%s\n' "${MERGED[@]}"
  fi
  if ((N_PARKED)); then
    say "$(_ "Your changes kept in $N_PARKED config file(s); their new versions: ${PARKED_DIR/#$HOME_DIR/\~}/ (OVERWRITE_CONFIGS=1 replaces them, with a backup)" \
             "Твои изменения сохранены в $N_PARKED файл(ах) конфигов; их новые версии: ${PARKED_DIR/#$HOME_DIR/\~}/ (OVERWRITE_CONFIGS=1 заменит их, с бэкапом)")"
  fi
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
  if ((TUI)); then
    tui_section "$(_ 'thanks for watching ♡' 'спасибо, что смотрели ♡')" \
      "$(_ 'log out and pick niri in the login screen — see you on the desktop' 'выйди из сеанса и выбери niri на экране входа — увидимся на рабочем столе')"
    chat_line
  fi
}

# Settings → Updates of shells older than their own restart prompt runs the
# installer without a terminal: ask in a notification, its buttons answer.
restart_notify() {
  command -v notify-send >/dev/null 2>&1 && command -v setsid >/dev/null 2>&1 || return 1
  setsid -f bash -c '[[ "$(notify-send -a angelOS -i system-software-update -u critical --wait \
      -A restart="$2" -A later="$3" "$4" "$5" 2>/dev/null)" == restart ]] && exec "$1" restart' _ "$1" \
    "$(_ 'Restart the shell' 'Перезагрузить оболочку')" "$(_ 'Later' 'Позже')" \
    "$(_ 'angelOS is updated ♡' 'angelOS обновлён ♡')" \
    "$(_ 'The previous version is still running. Restart the shell now? Windows and apps stay open.' \
         'Работает ещё прошлая версия. Перезагрузить оболочку сейчас? Окна и программы останутся открытыми.')" \
    </dev/null >/dev/null 2>&1
}

# A running angelOS keeps the old version in memory (it only watches its files in
# dev mode), so an update — new settings pages included — shows up after a restart.
restart_shell() {
  [[ "$DESKTOP_SHELL" == angelos ]] || return 0
  # Settings → Updates: the shell asks itself once the update is done
  [[ "${ANGELOS_RESTART:-}" == shell ]] && return 0
  local bin="$HOME_DIR/.local/bin/angelos" qs
  qs="$(command -v qs || echo "$HOME_DIR/.local/bin/qs")"
  [[ -x "$bin" && -x "$qs" ]] || return 0
  [[ "$("$qs" -c angelos list 2>/dev/null)" == *Instance* ]] || return 0
  if ((INTERACTIVE)) && [[ -n "${WAYLAND_DISPLAY:-}" ]] &&
     confirm "$(_ 'angelOS is still running the previous version. Restart it now?' \
                  'angelOS ещё работает на прошлой версии. Перезапустить его сейчас?')" y; then
    if "$bin" restart; then say "$(_ 'angelOS restarted' 'angelOS перезапущен')"
    else warn "$(_ 'Could not restart angelOS: run `angelos restart`' 'Не удалось перезапустить angelOS: выполните `angelos restart`')"; fi
  elif ((!INTERACTIVE)) && [[ -n "${WAYLAND_DISPLAY:-}" ]] && restart_notify "$bin"; then
    say "$(_ 'angelOS asks in a notification whether to restart it now' 'angelOS спросит в уведомлении, перезапустить ли его сейчас')"
  else
    warn "$(_ 'angelOS is still running the previous version: run `angelos restart` or log in again' \
              'angelOS ещё работает на прошлой версии: выполните `angelos restart` или перезайдите в систему')"
  fi
}

# ── The author's tools (optional) ───────────────────────────────────────────

# Only the author of angelOS has use for this: when the GitHub account logged in through gh
# can see the author's private repository, the chapter editor (and the owner's Dotfiles
# tools) are fetched into the shell's owner/ folder (scripts/author-tools.sh). GitHub
# decides — the repository is private; for everyone else nothing is fetched and nothing
# changes. angelOS keeps no token: gh keeps its own login, with its usual permissions.
offer_author_tools() {
  [[ "$DESKTOP_SHELL" == angelos ]] || return 0
  local script="$HOME_DIR/.config/quickshell/angelos/scripts/author-tools.sh" want="${GITHUB_LOGIN:-}"
  [[ -f "$script" ]] || return 0
  if [[ -z "$want" ]]; then
    ((INTERACTIVE)) || return 0
    hr
    say "$(_ 'Optional: log in to GitHub.' 'Необязательно: войти в GitHub.')"
    say "$(_ '  It is only for the author of angelOS: their own tools (the chapter editor) live in a' \
             '  Это нужно только автору angelOS: его инструменты (редактор глав) лежат в закрытом')"
    say "$(_ '  private repository and are fetched only for an account GitHub lets in. For anyone' \
             '  репозитории и скачиваются, только если GitHub пускает туда этот аккаунт. Для всех')"
    say "$(_ '  else nothing changes — skipping loses nothing. angelOS stores no token: gh does.' \
             '  остальных ничего не меняется — пропустив, вы ничего не теряете. Токен хранит gh, не angelOS.')"
    if confirm "$(_ 'Log in to GitHub now?' 'Войти в GitHub сейчас?')" n; then want=1; else want=0; fi
  fi
  [[ "$want" == 1 ]] || return 0
  if ! command -v gh >/dev/null 2>&1; then
    warn "$(_ 'gh (github-cli) is not installed: install it, then run `angelos author login`' \
              'gh (github-cli) не установлен: поставьте его и выполните `angelos author login`')"
    return 0
  fi
  if ! gh auth status >/dev/null 2>&1; then
    if ! ((INTERACTIVE)); then
      warn "$(_ 'No gh login, and no terminal to log in: `angelos author login` later' \
                'gh не залогинен, а войти без терминала нельзя: позже `angelos author login`')"
      return 0
    fi
    gh auth login --hostname github.com --git-protocol https --web ||
      { warn "$(_ 'GitHub login did not finish' 'Вход в GitHub не завершился')"; return 0; }
  fi
  sh "$script" fetch || true
}

# ── Main ─────────────────────────────────────────────────────────────────────

bootstrap_tui
ask_profile
normalize_mode
[[ "$MODE" == tech ]] && ! given DESKTOP_SHELL && ! given NOCTALIA && DESKTOP_SHELL=none
[[ "$DESKTOP_SHELL" =~ ^(angelos|noctalia|none)$ ]] || die "DESKTOP_SHELL must be angelos, noctalia or none"
[[ "$DESKTOP_SHELL" == noctalia ]] && NOCTALIA=1 || NOCTALIA=0
case "${ANGELOS_THEME,,}" in
  pixel|classic|angelos) ANGELOS_THEME=pixel ;;
  macos|mac|goldengate|golden-gate) ANGELOS_THEME=macos ;;
  *) die "$(_ "ANGELOS_THEME must be pixel or macos (got: $ANGELOS_THEME)" "ANGELOS_THEME должен быть pixel или macos (получено: $ANGELOS_THEME)")" ;;
esac
[[ "$FISH_DEFAULT" == 0 || "$FISH_DEFAULT" == 1 ]] || die "FISH_DEFAULT must be 0 or 1"
[[ "$MAC_KEYS" == 0 || "$MAC_KEYS" == 1 ]] || die "MAC_KEYS must be 0 or 1"
[[ "$INSTALL_APPS" == 0 || "$INSTALL_APPS" == 1 ]] || die "INSTALL_APPS must be 0 or 1"
[[ "$CACHYOS_REPOS" == 0 || "$CACHYOS_REPOS" == 1 ]] || die "CACHYOS_REPOS must be 0 or 1"
# APPS given alone means "these ones, please"
given APPS && ! given INSTALL_APPS && [[ "${APPS,,}" != none ]] && INSTALL_APPS=1
choose_keyboard

# step|English|Russian — the hearts bar counts them (on a terminal; a log stays as it was)
STEPS=(
  "pacman_install|packages (pacman -Syu)|пакеты (pacman -Syu)"
  "quickshell_check|Quickshell version|версия Quickshell"
  "install_noctalia|Noctalia|Noctalia"
  "install_configs|configs|конфиги"
  "install_shell|angelOS|angelOS"
  "install_assets|fonts, icons, wallpapers|шрифты, значки, обои"
  "install_noctalia_defaults|Noctalia defaults|настройки Noctalia"
  "install_voxtype|Voxtype|Voxtype"
  "install_voxtype_model|the Whisper model|модель Whisper"
  "install_apps|the apps|программы"
  "setup_fish_shell|fish|fish"
  "install_sddm|the login screen|экран входа"
  "enable_services|user services|user-сервисы"
  "validate|niri validate|niri validate"
)
for i in "${!STEPS[@]}"; do
  IFS='|' read -r step en ru <<<"${STEPS[i]}"
  ui_progress "$i" "${#STEPS[@]}" "$(_ "$en" "$ru")"
  "$step"
done
ui_progress "${#STEPS[@]}" "${#STEPS[@]}" "$(_ 'stream complete ♡' 'стрим завершён ♡')"
offer_author_tools
summary
((NIRI_INVALID == 0)) || die "$(_ 'Niri config failed validation; see: niri validate -c ~/.config/niri/config.kdl' \
                                   'Конфиг Niri не прошёл проверку; смотрите: niri validate -c ~/.config/niri/config.kdl')"
restart_shell
