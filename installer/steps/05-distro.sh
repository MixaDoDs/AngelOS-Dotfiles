# shellcheck shell=bash
# angelOS installer — sourced by install.sh in name order (see installer/README.md)

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

# #163: a fresh install on CachyOS with COSMIC was reported to wipe the home folder; until that is
# understood, refuse there before anything changes. Updates of an existing angelOS (a manifest) go on.
# shortcut: blocks every COSMIC system, lift once #163 is reproduced and fixed
if [[ "${ANGELOS_ALLOW_COSMIC:-0}" != 1 && ! -e "${XDG_STATE_HOME:-$HOME_DIR/.local/state}/angelos/installed-files.sha256" ]] &&
   { command -v cosmic-session >/dev/null 2>&1 || [[ "${XDG_CURRENT_DESKTOP:-}" == *COSMIC* ]]; }; then
  die "$(_ 'COSMIC is installed here: the installer does not run on it for now (an install there was reported to wipe the home folder, #163). Nothing was changed.' \
           'Здесь стоит COSMIC: установщик на нём пока не запускается (сообщили, что установка там стёрла домашнюю папку, #163). Ничего не изменено.')"
fi

[[ "$STAMP" =~ ^[0-9]{8}-[0-9]{6}(-[0-9]+)?$ ]] || die "DOTFILES_STAMP must look like 20260101-120000 (got: $STAMP)"
[[ "$VALIDATE_NIRI" == 0 || "$VALIDATE_NIRI" == 1 ]] || die "VALIDATE_NIRI must be 0 or 1"
[[ -z "${GITHUB_LOGIN:-}" || "$GITHUB_LOGIN" == 0 || "$GITHUB_LOGIN" == 1 ]] || die "GITHUB_LOGIN must be 0 or 1"
