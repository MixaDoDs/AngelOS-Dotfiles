#!/bin/sh
# angelOS: let the user at the seat read the charge of wireless mice from their dongles
# (root: install.sh of the dotfiles through sudo, or pkexec from Settings → Devices → Device
# charge). A udev rule and the helper it asks; what the rule opens and to whom is written in
# the rule itself (70-angelos-peripherals.rules). Copies, never links: both must stay root's.
#   install.sh            install / update, and apply to the devices plugged in now
#   install.sh --remove   take it away again
#   install.sh --status   "ok" when what is installed is this version, else "missing" / "old"
# ANGELOS_SYSROOT=dir: under dir instead of /, udev left alone (tests).
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="${ANGELOS_SYSROOT:-}"
bin="$root/usr/local/libexec/angelos-hid-feature-only"
rule="$root/etc/udev/rules.d/70-angelos-peripherals.rules"
if [ "${1:-}" = --status ]; then
    [ -f "$bin" ] && [ -f "$rule" ] || { echo missing; exit 0; }
    cmp -s "$here/angelos-hid-feature-only" "$bin" && cmp -s "$here/70-angelos-peripherals.rules" "$rule" && [ -x "$bin" ] || { echo old; exit 0; }
    echo ok
    exit 0
fi
[ -n "$root" ] || [ "$(id -u)" = 0 ] || { echo "run as root (pkexec / sudo)" >&2; exit 1; }
reload() {
    [ -z "$root" ] && command -v udevadm >/dev/null 2>&1 || return 0
    udevadm control --reload 2>/dev/null || true
    # the devices plugged in now: asked again, so the charge shows without a replug
    udevadm trigger --subsystem-match=hidraw --action=change 2>/dev/null || true
}
if [ "${1:-}" = --remove ]; then
    rm -f "$bin" "$rule"
    reload
    echo "removed"
    exit 0
fi
own=""
[ -n "$root" ] || own="-o root -g root"
# the helper first: a rule must never name a program that is not there yet
# shellcheck disable=SC2086
install -D $own -m 0755 "$here/angelos-hid-feature-only" "$bin"
# shellcheck disable=SC2086
install -D $own -m 0644 "$here/70-angelos-peripherals.rules" "$rule"
reload
echo "installed: $rule"
