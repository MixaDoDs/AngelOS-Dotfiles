#!/bin/sh
# angelOS: the USB bridge — a keyboard's service interface for the settings page, and nothing
# else of the keyboard (root: pkexec from Settings → Devices → Device driver, or sudo).
# What it gives to whom, and what it keeps closed, is written in bridge.py and in
# docs/devices.md, «Доступ». Copies, never links: everything installed stays root's.
#   install.sh            install / update, start the service, apply to the devices plugged in
#   install.sh --remove   take it away again (the system user stays: it owns nothing)
#   install.sh --status   "ok" when what is installed is this version, else "missing" / "old"
# ANGELOS_SYSROOT=dir: under dir instead of /, systemd and udev left alone (tests).
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
shell="$(cd "$here/../.." && pwd)"
root="${ANGELOS_SYSROOT:-}"
lib="$root/usr/local/libexec/angelos-usb"
allow="$root/etc/angelos/usb-bridge.json"
rule="$root/etc/udev/rules.d/70-angelos-usb-bridge.rules"
units="$root/etc/systemd/system"
users="$root/etc/sysusers.d/angelos-usb.conf"
py() { python3 -I "$here/gen.py" "$shell/data/devices" "$1"; }

same() {
    cmp -s "$here/bridge.py" "$lib/bridge.py" &&
    cmp -s "$shell/scripts/devlib/usbfs.py" "$lib/devlib/usbfs.py" &&
    cmp -s "$shell/scripts/devlib/nuphy_io.py" "$lib/devlib/nuphy_io.py" &&
    cmp -s "$here/angelos-usb-bridge.socket" "$units/angelos-usb-bridge.socket" &&
    cmp -s "$here/angelos-usb-bridge.service" "$units/angelos-usb-bridge.service" &&
    [ ! -e "$units/angelos-usb-bridge@.service" ] &&
    cmp -s "$here/angelos-usb.sysusers" "$users" &&
    py allow | cmp -s - "$allow" && py rule | cmp -s - "$rule"
}
if [ "${1:-}" = --status ]; then
    [ -f "$lib/bridge.py" ] && [ -f "$rule" ] && [ -f "$allow" ] || { echo missing; exit 0; }
    same || { echo old; exit 0; }
    echo ok
    exit 0
fi
[ -n "$root" ] || [ "$(id -u)" = 0 ] || { echo "run as root (pkexec / sudo)" >&2; exit 1; }
live() { [ -z "$root" ]; }
apply() {
    live || return 0
    command -v systemctl >/dev/null 2>&1 && systemctl daemon-reload 2>/dev/null || true
    if command -v udevadm >/dev/null 2>&1; then
        udevadm control --reload 2>/dev/null || true
        # the devices plugged in now get their group without a replug
        udevadm trigger --subsystem-match=usb --action=change 2>/dev/null || true
    fi
}
if [ "${1:-}" = --remove ]; then
    if live && command -v systemctl >/dev/null 2>&1; then
        systemctl disable --now angelos-usb-bridge.service angelos-usb-bridge.socket 2>/dev/null || true
    fi
    rm -f "$units/angelos-usb-bridge.socket" "$units/angelos-usb-bridge.service" "$units/angelos-usb-bridge@.service" "$rule" "$allow" "$users"
    rm -rf "$lib"
    apply
    echo "removed"
    exit 0
fi
own=""
live && own="-o root -g root"
# the user first: the rule names its group, the service runs as it
# shellcheck disable=SC2086
install -D $own -m 0644 "$here/angelos-usb.sysusers" "$users"
if live; then
    systemd-sysusers "$users"
fi
# shellcheck disable=SC2086
install -D $own -m 0755 "$here/bridge.py" "$lib/bridge.py"
# shellcheck disable=SC2086
install -D $own -m 0644 "$shell/scripts/devlib/usbfs.py" "$lib/devlib/usbfs.py"
# shellcheck disable=SC2086
install -D $own -m 0644 "$shell/scripts/devlib/nuphy_io.py" "$lib/devlib/nuphy_io.py"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
py allow > "$tmp"
# shellcheck disable=SC2086
install -D $own -m 0644 "$tmp" "$allow"
py rule > "$tmp"
# shellcheck disable=SC2086
install -D $own -m 0644 "$tmp" "$rule"
# shellcheck disable=SC2086
install -D $own -m 0644 "$here/angelos-usb-bridge.socket" "$units/angelos-usb-bridge.socket"
# shellcheck disable=SC2086
install -D $own -m 0644 "$here/angelos-usb-bridge.service" "$units/angelos-usb-bridge.service"
# (before 2026-10-12 evening: one service per connection; now one service from boot on)
rm -f "$units/angelos-usb-bridge@.service"
apply
if live && command -v systemctl >/dev/null 2>&1; then
    # a socket of an older version (Accept=yes) keeps its settings until it is started anew
    systemctl stop angelos-usb-bridge.socket 2>/dev/null || true
    systemctl enable angelos-usb-bridge.socket angelos-usb-bridge.service
    systemctl start angelos-usb-bridge.socket
    systemctl restart angelos-usb-bridge.service
fi
echo "installed: the USB bridge ($allow)"
