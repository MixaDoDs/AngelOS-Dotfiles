#!/usr/bin/env bash
# The author's repositories on Arch Linux: CachyOS's (as the author's system has them) and
# [multilib]. Without them the apps of the installer and the setup wizard are not all there:
# helium-browser-bin, qview and localsend are only in [cachyos], Steam is in [multilib].
#
#   cachyos-repos.sh            add what is missing (as root; asks sudo itself), then pacman -Syu
#   cachyos-repos.sh --check    exit 0 when both are there already (no root needed)
#
# CachyOS's own script (mirror.cachyos.org/cachyos-repo.tar.xz, fetched each time, so its
# keyring and mirrorlist versions stay CachyOS's) adds the repositories the CPU runs:
# znver4, x86-64-v4 or x86-64-v3, above Arch's — the next -Syu takes CachyOS's builds, pacman
# among them. On a CPU without x86-64-v3 it adds nothing; then plain [cachyos] goes in.
# CachyOS itself and other architectures are left as they are.
set -Eeuo pipefail

CONF="${PACMAN_CONF:-/etc/pacman.conf}"
URL="${CACHYOS_REPO_URL:-https://mirror.cachyos.org/cachyos-repo.tar.xz}"

has_cachyos() { grep -Eq '^\[cachyos(-[a-z0-9-]+)?\][[:space:]]*$' "$CONF"; }
has_multilib() { grep -Eq '^\[multilib\][[:space:]]*$' "$CONF"; }
say() { printf '\033[1;35m»\033[0m %s\n' "$*"; }

if [[ "${1:-}" == --check ]]; then
  has_cachyos && has_multilib
  exit
fi
[[ "$(uname -m)" == x86_64 ]] || { say "$(uname -m): у CachyOS нет репозиториев для этой архитектуры — пропускаю"; exit 0; }
if has_cachyos && has_multilib; then
  say "репозитории CachyOS и multilib уже подключены"
  exit 0
fi
((EUID == 0)) || exec sudo -- bash "$0" "$@"

cp -- "$CONF" "$CONF.angelos-$(date +%Y%m%d-%H%M%S).bak"

if ! has_multilib; then
  say "включаю [multilib] (Steam и 32-битные библиотеки)"
  # Arch's pacman.conf has it commented out: "#[multilib]" and its "#Include" line
  sed -i '/^#[[:space:]]*\[multilib\][[:space:]]*$/{s/^#[[:space:]]*//;n;s/^#[[:space:]]*Include/Include/}' "$CONF"
  has_multilib || printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >>"$CONF"
fi

if ! has_cachyos; then
  say "подключаю репозитории CachyOS (как у автора angelOS)"
  command -v gawk >/dev/null 2>&1 || pacman -S --needed --noconfirm gawk
  tmp="$(mktemp -d)"
  trap 'rm -rf -- "$tmp"' EXIT
  curl -fsSL --retry 3 "$URL" | tar -xJ -C "$tmp"
  # its last step is pacman -Syu
  (cd "$tmp/cachyos-repo" && bash ./cachyos-repo.sh --install)
  if ! has_cachyos; then
    say "процессор без x86-64-v3: подключаю общий [cachyos]"
    # (its keyring and mirrorlist packages went in before it looked at the CPU)
    [[ -f /etc/pacman.d/cachyos-mirrorlist ]] || { say "нет /etc/pacman.d/cachyos-mirrorlist — скрипт CachyOS не доработал"; exit 1; }
    awk '!done && /^\[(core|core-testing)\][[:space:]]*$/ { print "[cachyos]\nInclude = /etc/pacman.d/cachyos-mirrorlist\n"; done = 1 } { print }' \
      "$CONF" >"$CONF.new" && mv -- "$CONF.new" "$CONF"
    pacman -Syu
  fi
else
  pacman -Syu
fi
say "готово: $(grep -Eo '^\[(cachyos[a-z0-9-]*|multilib)\]' "$CONF" | paste -sd' ')"
