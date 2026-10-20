#!/usr/bin/env bash
# Installer for angelOS — the pastel Niri rice (CachyOS / Arch).
#
# Run it with no arguments for the interactive setup: a pastel "stream" in the terminal
# (gum menus, a hearts progress bar; gum is installed first when it is missing). Or drive it
# with environment variables (everything has a default, so it also works unattended):
#
#   DOTFILES_MODE=full|tech        full = styling + desktop shell + assets, tech = minimal
#   DESKTOP_SHELL=angelos|none
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
#   INSTALL_GAMING=0|1             the gaming edition: Steam, Proton (CachyOS's, umu, ProtonPlus), the
#                                  32-bit drivers, gamemode, MangoHud, gamescope, a 10 GB shader cache
#                                  and, on btrfs, a snapshot before every update (snapper, snap-pac,
#                                  in the boot menu). Asked interactively (default no), unattended 0.
#                                  Later: Settings → Maintenance → Games (scripts/game-setup.sh)
#   CACHYOS_REPOS=1|0              Arch Linux (x86_64): add the author's repositories before the
#                                  packages — [cachyos], LAST (Arch's own packages win, the system
#                                  stays Arch) and [multilib]. Without them Helium, qView, LocalSend,
#                                  the fish prompt and Steam can't install
#                                  (scripts/cachyos-repos.sh; default 1; CachyOS has them already)
#   NO_TUI=1                       plain numbered prompts instead of the gum interface
#   NO_ANIM=1                      no boot animation (the pictures stand still)
#   NO_MUSIC=1                     no music and no sounds (off by itself over SSH, without a sound
#                                  server and on the author's machine)
#   INTERACTIVE=0                  no questions even on a terminal
#   ANGELOS_GAME=1|0               angelOS is also a game played over the desktop (an angel, a demon,
#                                  a story that follows your choices); 0 = plain dotfiles without it.
#                                  Asked interactively; unattended runs leave the current choice alone.
#                                  Later: `angelos game on|off`, Mod+Ctrl+Shift+Escape leaves it at once
#   ANGELOS_SELF_UPDATE=1|0        a clone that is behind its remote is fast-forwarded first and the
#                                  installer starts over as the new version (default 1; never when
#                                  the clone has edits or commits of its own, or without git)
#   KB_LAYOUTS=us,ru               keyboard layouts, XKB codes, first one is the default
#   KB_TOGGLE=alt_shift            layout switch: alt_shift | ctrl_shift | caps | ralt | lalt | none
#                                  (or a raw XKB option such as grp:shifts_toggle)
#   KB_VARIANT=,phonetic           optional XKB variants, one per layout, comma separated
#   VOXTYPE_LANGUAGE=ru            dictation language (default: derived from KB_LAYOUTS)
#   INSTALL_SDDM=1|0               SDDM login screen with the angelOS theme
#                                  (default 1, or 0 together with SKIP_PACKAGES=1)
#   MAIN_SCREEN=DP-1               the main screen (a niri output): the login's password field and
#                                  the pointer, the lock (asked with two screens or more)
#   DEVICE_ACCESS=1|0              let the user at the seat read the charge of wireless mice from
#                                  their dongles: a udev rule that opens only the maker's interface
#                                  without input (extras/hid-access; default 1, or 0 together with
#                                  SKIP_PACKAGES=1)
#   SMOOTH_MEMORY=1|0              kernel memory settings that keep the picture from freezing when
#                                  RAM fills up (extras/smooth-memory, a sysctl file; default 1)
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
#   MINIMIZE_HOOK=1|0              the windows' own minimize buttons reach angelOS
#                                  (extras/minimize-hook: an LD_PRELOAD library, needs gcc)
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
ARGS=("$@")   # «Change the answers» starts over with them
HOME_DIR="${HOME:?HOME is not set}"
STAMP="${DOTFILES_STAMP:-$(date +%Y%m%d-%H%M%S)}"
VALIDATE_NIRI="${VALIDATE_NIRI:-1}"
VOXTYPE_VERSION="${VOXTYPE_VERSION:-1.1.0}"
VOXTYPE_FORCE="${VOXTYPE_FORCE:-0}"

# Remember which options were given explicitly, so the interactive setup only
# asks about the rest.
is_set() { [[ -n "${!1+x}" ]]; }
for v in DOTFILES_MODE DESKTOP_SHELL NOCTALIA KB_LAYOUTS KB_TOGGLE INSTALL_VOXTYPE DOWNLOAD_VOXTYPE_MODEL \
         INSTALL_WALLPAPERS WALLPAPER_PACKS INSTALL_SDDM DEVICE_ACCESS ANGELOS_GAME GITHUB_LOGIN \
         INSTALL_FLATPAK INSTALL_TOOLS ANGELOS_THEME MAC_KEYS FISH_DEFAULT INSTALL_APPS APPS MAIN_SCREEN \
         INSTALL_GAMING; do
  is_set "$v" && declare -r "GIVEN_$v=1"
done
given() { local n="GIVEN_$1"; [[ -n "${!n:-}" ]]; }

MODE="${DOTFILES_MODE:-full}"
# Noctalia is not part of these dotfiles any more (angelOS took its place). The old switch still
# means what it can: NOCTALIA=0 was "no desktop shell". Asking for Noctalia itself stops here,
# before anything is touched
if ! is_set DESKTOP_SHELL && [[ "${NOCTALIA:-}" == 0 ]]; then DESKTOP_SHELL=none; fi
if [[ "${DESKTOP_SHELL:-}" == noctalia ]] || { is_set NOCTALIA && [[ "$NOCTALIA" != 0 ]]; }; then
  printf '%s\n' \
    'Noctalia is no longer shipped with these dotfiles: DESKTOP_SHELL=angelos (the default) or none (plain niri).' \
    'Nothing was changed. A Noctalia you installed yourself and its config stay as they are.' \
    'Noctalia больше не входит в эти dotfiles: DESKTOP_SHELL=angelos (по умолчанию) или none (голый niri).' \
    'Ничего не изменено. Noctalia, которую ты поставил сам, и её конфиг остаются как есть.' >&2
  exit 1
fi
DESKTOP_SHELL="${DESKTOP_SHELL:-angelos}"
SKIP_PACKAGES="${SKIP_PACKAGES:-0}"
INSTALL_VOXTYPE="${INSTALL_VOXTYPE:-1}"
DOWNLOAD_VOXTYPE_MODEL="${DOWNLOAD_VOXTYPE_MODEL:-1}"
INSTALL_WALLPAPERS="${INSTALL_WALLPAPERS:-1}"
INTRO_SOUNDS="${INTRO_SOUNDS:-1}"
MINIMIZE_HOOK="${MINIMIZE_HOOK:-1}"
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
DEVICE_ACCESS="${DEVICE_ACCESS:-1}"
[[ "$SKIP_PACKAGES" == 1 ]] && ! given DEVICE_ACCESS && DEVICE_ACCESS=0
KB_LAYOUTS="${KB_LAYOUTS:-us,ru}"
KB_TOGGLE="${KB_TOGGLE:-alt_shift}"
KB_VARIANT="${KB_VARIANT:-}"
VOXTYPE_LANGUAGE="${VOXTYPE_LANGUAGE:-}"
ANGELOS_THEME="${ANGELOS_THEME:-pixel}"
MAC_KEYS="${MAC_KEYS:-1}"
FISH_DEFAULT="${FISH_DEFAULT:-1}"
INSTALL_APPS="${INSTALL_APPS:-0}"
INSTALL_GAMING="${INSTALL_GAMING:-0}"
CACHYOS_REPOS="${CACHYOS_REPOS:-1}"
APPS="${APPS:-all}"
# fish before this run: a login shell someone already has is never changed behind their back
FISH_WAS_INSTALLED=0
command -v fish >/dev/null 2>&1 && FISH_WAS_INSTALLED=1

# INTERACTIVE=0 from outside: no questions even on a terminal (the defaults and what is given)
if [[ -z "${INTERACTIVE:-}" ]]; then
  INTERACTIVE=0
  [[ -t 0 && -t 1 ]] && INTERACTIVE=1
fi
# a terminal SSH brought from elsewhere (xterm-kitty, foot, ghostty) has no terminfo on a fresh Arch
if [[ -t 1 ]] && ! tput longname >/dev/null 2>&1; then export TERM=xterm-256color; fi
# the Linux console (Ctrl+Alt+F3 on a fresh system): 16 colours and a small font — no Cyrillic in
# the kernel's own one, so cyr-sun16 from kbd comes first; plain glyphs instead of ♡ and frames
CONSOLE=0
[[ "${TERM:-}" == linux ]] && CONSOLE=1
if ((CONSOLE)) && [[ -t 1 ]] && ! grep -qs '^FONT=' /etc/vconsole.conf; then setfont cyr-sun16 2>/dev/null || true; fi
TTY_OUT=0
[[ -t 1 ]] && TTY_OUT=1
COLOR=0
((TTY_OUT)) && [[ -z "${NO_COLOR:-}" ]] && COLOR=1
G_HEART='♡' G_FULL='♥'
((CONSOLE)) && G_HEART='*' G_FULL='#'

# ── Output helpers (English, or Russian when the locale is ru_*) ─────────────

# ANGELOS_LANG: angelOS's own language, passed by Settings → Updates
case "${ANGELOS_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}" in ru*) UI=ru ;; *) UI=en ;; esac
# a fresh Arch Linux is en_US (or C) for most Russian speakers too: on a terminal the installer
# asks first, in both languages, unless ANGELOS_LANG says it. The pick goes on to angelOS
# (the setup wizard starts in it) and to the helpers (apps-install.py, cachyos-repos.sh).
LANG_ASKED=""
if [[ -z "${ANGELOS_LANG:-}" ]] && ((INTERACTIVE)); then
  # the first screen, as Windows XP's text-mode setup had it (blue, a bar, keys at the bottom)
  if ((COLOR)); then
    _w="$(tput cols 2>/dev/null || echo 80)"
    printf '\033[2J\033[H\033[44;97m%-*s\033[0m\n\n' "$_w" ' angelOS Setup'
    printf '\033[1;95m  Добро пожаловать. / Welcome.\033[0m\n\n  1) Русский\n  2) English\n\n'
    printf '\033[%s;1H\033[44;97m%-*s\033[0m\033[8;1H' "$(tput lines 2>/dev/null || echo 24)" "$_w" ' ENTER=Продолжить/Continue   Ctrl+C=Выход/Quit'
    unset _w
  else
    printf '\n  1) Русский\n  2) English\n\n'
  fi
  read -r -p "  Язык / Language [$([[ "$UI" == ru ]] && echo 1 || echo 2)]: " _lang || exit 130
  case "${_lang,,}" in 1|ru*|р*) UI=ru ;; 2|en*|e*) UI=en ;; esac
  LANG_ASKED=1
  unset _lang
fi
export ANGELOS_LANG="$UI"
_() { if [[ "$UI" == ru ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

# colours only on a terminal: Settings → Updates shows this output in its log
c1() { ((COLOR)) && printf '\033[%sm' "$1"; return 0; }
c2() { [[ -t 2 ]] && ((COLOR)) && printf '\033[%sm' "$1"; return 0; }
# pastel on a terminal (pink, lilac, a hot-pink warning); a log gets the plain [dotfiles] lines
if ((CONSOLE)); then
  C_SAY="$(c1 '1;95')" C_DIM="$(c1 '35')" C_OFF="$(c1 0)" C_WARN="$(c2 '1;93')" C_ERR="$(c2 '1;91')" C_OFF2="$(c2 0)"
else
  C_SAY="$(c1 '1;38;2;255;143;199')" C_DIM="$(c1 '38;2;201;167;255')" C_OFF="$(c1 0)"
  C_WARN="$(c2 '1;38;2;255;214;120')" C_ERR="$(c2 '1;38;2;255;79;163')" C_OFF2="$(c2 0)"
fi
# every line of the installer's own also goes to a log (pacman keeps its terminal: its bars)
# (from the start of a run on a terminal: a refused distribution, --help or an update from Settings
# leave nothing behind)
INSTALL_LOG="${XDG_STATE_HOME:-$HOME_DIR/.local/state}/angelos/install-$STAMP.log" LOG_ON=0
_log() { ((LOG_ON)) && printf '%s %s\n' "$(date +%T)" "$*" >>"$INSTALL_LOG" 2>/dev/null; return 0; }
log_start() { # the last five logs are kept; an update from Settings has a log of its own
  ((INTERACTIVE)) && mkdir -p -- "${INSTALL_LOG%/*}" 2>/dev/null || return 0
  LOG_ON=1
  ls -1t "${INSTALL_LOG%/*}"/install-*.log 2>/dev/null | tail -n +5 | xargs -r rm -f -- || true
}
if ((COLOR)); then
  say()  { _log "$*"; printf '%s%s%s %s\n' "$C_SAY" "$G_HEART" "$C_OFF" "$*"; }
else
  say()  { _log "$*"; printf '%s[dotfiles]%s %s\n' "$C_SAY" "$C_OFF" "$*"; }
fi
warn() { _log "WARNING: $*"; printf '%s[dotfiles] WARNING:%s %s\n' "$C_WARN" "$C_OFF2" "$*" >&2; }
die()  { DIED=1; _log "ERROR: $*"; printf '%s[dotfiles] ERROR:%s %s\n' "$C_ERR" "$C_OFF2" "$*" >&2; exit 1; }
hr()   { printf '%s%s %s %s%s\n' "$C_DIM" "$G_HEART" '───────────────────────────────────────────────────────' "$G_HEART" "$C_OFF"; }

# root's home would get angelOS (sudo ./install.sh, or logged in as root on a fresh system); a
# container without a terminal (the CI, a build) runs as root on purpose
((EUID != 0 || !INTERACTIVE)) || die "$(_ 'Run the installer as your own user, not root and not with sudo: it asks for the admin password itself' \
                          'Запускай установщик от своего пользователя, не от root и не через sudo: пароль администратора он спросит сам')"

# ── Self-update ──────────────────────────────────────────────────────────────
# A clone that fell behind installed an old angelOS, and Settings → Updates then still showed
# the update: it had to be installed twice. So before anything else the installer asks what the
# branch's newest commit is — GitHub's API, one small curl, no objects; `git ls-remote` for
# another host or without curl — and when the clone is behind and has nothing of its own (no
# commits, no edits), fast-forwards it and starts over as the new version.
# Never: ANGELOS_SELF_UPDATE=0; an update run by Settings → Updates (DOTFILES_STAMP: it pulled
# already); a copy without git (an archive). Offline, or a clone with changes of its own: it
# says so and installs what is here.
self_update() {
  [[ "${ANGELOS_SELF_UPDATE:-1}" == 1 && -z "${DOTFILES_STAMP:-}" && -z "${ANGELOS_SELF_UPDATED:-}" ]] || return 0
  command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || return 0
  local branch url slug head remote="" n
  branch="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)" || return 0
  [[ -n "$branch" && "$branch" != HEAD ]] || return 0
  url="$(git -C "$ROOT" remote get-url origin 2>/dev/null)" || return 0
  head="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null)" || return 0
  if [[ "$url" =~ ^(https://github\.com/|git@github\.com:)([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)$ ]] && command -v curl >/dev/null 2>&1; then
    slug="${BASH_REMATCH[2]%.git}"
    remote="$(curl -fsSL --max-time 8 -H 'Accept: application/vnd.github.sha' "https://api.github.com/repos/$slug/commits/$branch" 2>/dev/null || true)"
    [[ "$remote" =~ ^[0-9a-f]{40}$ ]] || remote=""
  fi
  [[ -n "$remote" ]] || remote="$(timeout 12 git -C "$ROOT" ls-remote --heads origin "$branch" 2>/dev/null | awk '{print $1; exit}' || true)"
  if [[ -z "$remote" ]]; then
    warn "$(_ 'Could not ask whether a newer angelOS is out (no network?): installing the version that is here' \
              'Не удалось узнать, вышла ли версия новее (нет сети?): ставлю ту, что здесь')"
    return 0
  fi
  [[ "$remote" != "$head" ]] || return 0
  # a commit this clone has already and stands on top of: the clone is ahead, not behind
  if git -C "$ROOT" cat-file -e "$remote^{commit}" 2>/dev/null && git -C "$ROOT" merge-base --is-ancestor "$remote" HEAD 2>/dev/null; then
    return 0
  fi
  if [[ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ]]; then
    warn "$(_ "A newer angelOS is out, but this folder has edits of its own: installing the version that is here. To get the new one: git -C \"$ROOT\" stash -u (or commit), then run the installer again" \
              "Вышла версия новее, но в этой папке есть свои правки: ставлю ту, что здесь. Чтобы получить новую: git -C \"$ROOT\" stash -u (или коммит), потом запусти установщик снова")"
    return 0
  fi
  say "$(_ 'A newer angelOS is out: updating this folder first' 'Вышла версия новее: сначала обновляю эту папку')"
  if ! timeout 180 git -C "$ROOT" fetch --quiet origin "$branch" 2>/dev/null; then
    warn "$(_ 'git fetch failed: installing the version that is here' 'git fetch не удался: ставлю ту версию, что здесь')"
    return 0
  fi
  if [[ "$(git -C "$ROOT" rev-list --count FETCH_HEAD..HEAD 2>/dev/null || echo 1)" != 0 ]]; then
    warn "$(_ "This folder has commits of its own, so it can't simply be moved to the new version: installing what is here (git -C \"$ROOT\" pull --rebase brings the new one in)" \
              "В этой папке есть свои коммиты, просто перемотать её на новую версию нельзя: ставлю то, что здесь (новую подтянет git -C \"$ROOT\" pull --rebase)")"
    return 0
  fi
  n="$(git -C "$ROOT" rev-list --count HEAD..FETCH_HEAD 2>/dev/null || echo '?')"
  if ! git -C "$ROOT" merge --ff-only --quiet FETCH_HEAD 2>/dev/null; then
    warn "$(_ 'The folder could not be moved to the new version: installing what is here' 'Перемотать папку на новую версию не вышло: ставлю то, что здесь')"
    return 0
  fi
  say "$(_ "Updated ($n new commits): starting over as the new version" "Обновлено (новых коммитов: $n): начинаю заново уже новой версией")"
  ANGELOS_SELF_UPDATED=1 exec bash "$ROOT/install.sh" "$@"
}
case " $* " in *" -h "*|*" --help "*) ;; *) self_update "$@" ;; esac
# ── /Self-update ─────────────────────────────────────────────────────────────

# the rest of the installer: installer/lib/*.sh, then installer/steps/*.sh in name order
for _f in "$ROOT"/installer/lib/*.sh "$ROOT"/installer/steps/*.sh; do
  # shellcheck source=/dev/null
  source "$_f"
done
unset _f

# ── Main ─────────────────────────────────────────────────────────────────────

log_start
show_init
((INTERACTIVE)) && tui_boot
preflight
bootstrap_tui
show_init
normalize_mode
ask_profile
[[ "$MODE" == tech ]] && ! given DESKTOP_SHELL && ! given NOCTALIA && DESKTOP_SHELL=none
[[ "$DESKTOP_SHELL" =~ ^(angelos|none)$ ]] || die "DESKTOP_SHELL must be angelos or none"
case "${ANGELOS_THEME,,}" in
  pixel|classic|angelos) ANGELOS_THEME=pixel ;;
  macos|mac|goldengate|golden-gate) ANGELOS_THEME=macos ;;
  *) die "$(_ "ANGELOS_THEME must be pixel or macos (got: $ANGELOS_THEME)" "ANGELOS_THEME должен быть pixel или macos (получено: $ANGELOS_THEME)")" ;;
esac
[[ "$FISH_DEFAULT" == 0 || "$FISH_DEFAULT" == 1 ]] || die "FISH_DEFAULT must be 0 or 1"
[[ "$MAC_KEYS" == 0 || "$MAC_KEYS" == 1 ]] || die "MAC_KEYS must be 0 or 1"
[[ "$INSTALL_APPS" == 0 || "$INSTALL_APPS" == 1 ]] || die "INSTALL_APPS must be 0 or 1"
[[ "$INSTALL_GAMING" == 0 || "$INSTALL_GAMING" == 1 ]] || die "INSTALL_GAMING must be 0 or 1"
[[ "$DEVICE_ACCESS" == 0 || "$DEVICE_ACCESS" == 1 ]] || die "DEVICE_ACCESS must be 0 or 1"
[[ "$CACHYOS_REPOS" == 0 || "$CACHYOS_REPOS" == 1 ]] || die "CACHYOS_REPOS must be 0 or 1"
# APPS given alone means "these ones, please"
given APPS && ! given INSTALL_APPS && [[ "${APPS,,}" != none ]] && INSTALL_APPS=1
choose_keyboard
review

mapfile -t STEPS < <(printf '%s\n' "${STEPS[@]}" | sort -t'|' -k1,1n)
# a step that fails says which one (die() has said why: its line stays the last one), the demon
# laughs, and the log is named; Ctrl+C is a stop, not a failure. Every step skips what is done
on_exit() {
  local rc=$?
  if ((rc)) && [[ -n "${CUR_STEP:-}" ]]; then
    show_failure
    if ((rc == 130)); then
      printf '\n%s\n' "$(_ "Stopped at «$CUR_STEP». Running ./install.sh again is safe: what is done is skipped" \
                            "Остановлено на шаге «$CUR_STEP». Запустить ./install.sh снова безопасно: сделанное пропустится")" >&2
    elif [[ -z "${DIED:-}" ]]; then
      printf "%s[dotfiles] ERROR:%s %s\n" "$C_ERR" "$C_OFF2" "$(_ "the step «$CUR_STEP» failed (exit $rc, see above); ./install.sh again goes on from where it stopped" "шаг «$CUR_STEP» упал (код $rc, см. выше); повторный ./install.sh продолжит с этого места")" >&2
    fi
    [[ -s "$INSTALL_LOG" ]] && printf '%s\n' "$(_ "The installer's log: $INSTALL_LOG" "Журнал установщика: $INSTALL_LOG")" >&2
  fi
  cleanup
}
trap on_exit EXIT
for i in "${!STEPS[@]}"; do
  IFS='|' read -r _ step en ru <<<"${STEPS[i]}"
  ui_progress "$i" "${#STEPS[@]}" "$(_ "$en" "$ru")"
  CUR_STEP="$(_ "$en" "$ru")"
  _log "── $CUR_STEP"
  [[ "$step" == pacman_install ]] && billboard
  "$step"
  # the music waits for the packages: a fresh system has no sound server before them
  [[ "$step" == pacman_install ]] && { show_init; music_start; }
done
CUR_STEP=""
ui_progress "${#STEPS[@]}" "${#STEPS[@]}" "$(_ "stream complete $G_HEART" "стрим завершён $G_HEART")"
show_finale
offer_author_tools
summary
((NIRI_INVALID == 0)) || die "$(_ 'Niri config failed validation; see: niri validate -c ~/.config/niri/config.kdl' \
                                   'Конфиг Niri не прошёл проверку; смотрите: niri validate -c ~/.config/niri/config.kdl')"
((SHOW)) && typed 'Close the world, open the nExt.'   # Serial Experiments Lain
restart_shell
