#!/bin/sh
# angelOS: memory settings that keep the picture from freezing when RAM fills up (the sysctl
# file beside this one says what each does). Root: install.sh of the dotfiles through sudo.
#   install.sh            install / update, and apply now
#   install.sh --remove   take it away (the kernel's values come back at the next boot)
#   install.sh --status   "ok" when what is installed is this version, else "missing" / "old"
# ANGELOS_SYSROOT=dir: under dir instead of /, nothing applied (tests).
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="${ANGELOS_SYSROOT:-}"
conf="$root/etc/sysctl.d/99-angelos-smooth-memory.conf"
if [ "${1:-}" = --status ]; then
    [ -f "$conf" ] || { echo missing; exit 0; }
    cmp -s "$here/99-angelos-smooth-memory.conf" "$conf" || { echo old; exit 0; }
    echo ok
    exit 0
fi
[ -n "$root" ] || [ "$(id -u)" = 0 ] || { echo "run as root (sudo)" >&2; exit 1; }
if [ "${1:-}" = --remove ]; then
    rm -f "$conf"
    echo "removed"
    exit 0
fi
own=""
[ -n "$root" ] || own="-o root -g root"
# shellcheck disable=SC2086
install -D $own -m 0644 "$here/99-angelos-smooth-memory.conf" "$conf"
[ -n "$root" ] || sysctl -q -p "$conf" || true
echo "installed: $conf"
