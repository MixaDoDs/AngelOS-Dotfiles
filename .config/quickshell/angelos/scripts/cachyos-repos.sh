#!/usr/bin/env bash
# The author's repositories on Arch Linux: [cachyos] and [multilib]. Without them the apps of the
# installer and the setup wizard are not all there: helium-browser-bin, qview, localsend and the
# fish look (fish-pure-prompt, cachyos-fish-config) are only in [cachyos], Steam is in [multilib].
#
#   cachyos-repos.sh            add what is missing (as root; asks sudo itself), then pacman -Sy
#   cachyos-repos.sh --check    exit 0 when both are there already (no root needed)
#
# [cachyos] goes in LAST, below Arch's own repositories: pacman takes a package from the first
# repository that has it, so the system stays Arch's (its pacman, glibc, mesa, kernel…) and only
# what Arch doesn't have comes from CachyOS. Earlier versions ran CachyOS's own script instead,
# which puts the CPU-tuned repositories (v3/v4/znver4) ABOVE Arch's and turns the next -Syu
# into a switch of the whole system to CachyOS's builds — a pacman replaced, zlib → zlib-ng,
# provider questions, mirrors behind Arch's ("local is newer"). Systems that got them keep them.
# CachyOS itself and other architectures are left as they are.
set -Eeuo pipefail

CONF="${PACMAN_CONF:-/etc/pacman.conf}"
KEY=F3B607488DB35A47   # CachyOS <admin@cachyos.org>, as CachyOS's own script signs it locally
SERVER='https://mirror.cachyos.org/repo/$arch/$repo'

has_cachyos() { grep -Eq '^\[cachyos(-[a-z0-9-]+)?\][[:space:]]*$' "$CONF"; }
has_multilib() { grep -Eq '^\[multilib\][[:space:]]*$' "$CONF"; }
case "${ANGELOS_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}" in ru*) RU=1 ;; *) RU=0 ;; esac
say() { if ((RU)); then printf '\033[1;35m»\033[0m %s\n' "$2"; else printf '\033[1;35m»\033[0m %s\n' "$1"; fi; }

if [[ "${1:-}" == --check ]]; then
  has_cachyos && has_multilib
  exit
fi
[[ "$(uname -m)" == x86_64 ]] || { say "$(uname -m): CachyOS has no repositories for it — skipped" "$(uname -m): у CachyOS нет репозиториев для этой архитектуры — пропускаю"; exit 0; }
if has_cachyos && has_multilib; then
  say "the CachyOS and multilib repositories are there already" "репозитории CachyOS и multilib уже подключены"
  exit 0
fi
((EUID == 0)) || exec sudo --preserve-env=ANGELOS_LANG -- bash "$0" "$@"

cp -- "$CONF" "$CONF.angelos-$(date +%Y%m%d-%H%M%S).bak"

if ! has_multilib; then
  say "enabling [multilib] (Steam and 32-bit libraries)" "включаю [multilib] (Steam и 32-битные библиотеки)"
  # Arch's pacman.conf has it commented out: "#[multilib]" and its "#Include" line
  sed -i '/^#[[:space:]]*\[multilib\][[:space:]]*$/{s/^#[[:space:]]*//;n;s/^#[[:space:]]*Include/Include/}' "$CONF"
  has_multilib || printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >>"$CONF"
fi

if ! has_cachyos; then
  say "adding [cachyos] below Arch's repositories (only what Arch doesn't have comes from it)" \
      "подключаю [cachyos] ниже репозиториев Arch (из него берётся только то, чего нет в Arch)"
  if ! pacman-key --list-keys "$KEY" >/dev/null 2>&1; then
    pacman-key --recv-keys "$KEY" --keyserver hkps://keyserver.ubuntu.com ||
      curl -fsSL --retry 3 "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x$KEY" | pacman-key --add - ||
      { say "could not fetch CachyOS's signing key (offline? a keyserver blocked?)" "не скачался ключ подписи CachyOS (нет сети? заблокирован keyserver?)"; exit 1; }
  fi
  pacman-key --lsign-key "$KEY" >/dev/null
  printf '\n# angelOS (scripts/cachyos-repos.sh): last, so Arch'"'"'s own packages win\n[cachyos]\nServer = %s\n' "$SERVER" >>"$CONF"
  pacman -Sy
  # its keyring and its mirror list, then the repository reads the list instead of one server
  pacman -S --needed --noconfirm cachyos-keyring cachyos-mirrorlist
  if [[ -s /etc/pacman.d/cachyos-mirrorlist ]]; then
    sed -i '/^\[cachyos\][[:space:]]*$/{n;s|^Server = .*|Include = /etc/pacman.d/cachyos-mirrorlist|}' "$CONF"
  fi
fi
pacman -Sy
say "done: $(grep -Eo '^\[(cachyos[a-z0-9-]*|multilib)\]' "$CONF" | paste -sd' ')" \
    "готово: $(grep -Eo '^\[(cachyos[a-z0-9-]*|multilib)\]' "$CONF" | paste -sd' ')"
