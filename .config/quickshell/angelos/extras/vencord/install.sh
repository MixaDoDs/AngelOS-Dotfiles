#!/bin/sh
# angelOS: Discord always with Vencord — the system's part (root: install.sh of the dotfiles
# through sudo, or by hand). CachyOS only: elsewhere it does nothing. The guard itself is
# angelos-vencord (what it patches and how is written there); here it is copied for root and
# started whenever Discord can come back clean: pacman's hook after an update of its Discord,
# a path unit on the Flatpak's deploy folder, a timer for the rest. Copies, never links: all
# of it must stay root's. The user's part (their Vencord, their Flatpak) is the user's units,
# ~/.config/systemd/user/angelos-vencord.*.
#   install.sh            install / update, and patch the Discords there are now
#   install.sh --remove   take it away again (the Discords stay as they are)
#   install.sh --status   "ok" when what is installed is this version, else "missing" / "old";
#                         "ok" on another system than CachyOS (nothing is wanted there)
# ANGELOS_SYSROOT=dir: under dir instead of /, systemd left alone (tests).
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="${ANGELOS_SYSROOT:-}"
bin="$root/usr/local/libexec/angelos-vencord"
units="$root/etc/systemd/system"
hooks="$root/etc/pacman.d/hooks"
cachyos() { grep -Eqx 'ID="?cachyos"?' "$root/etc/os-release" 2>/dev/null; }
if [ "${1:-}" = --status ]; then
    cachyos || { echo ok; exit 0; }
    [ -f "$bin" ] || { echo missing; exit 0; }
    for f in angelos-vencord.service angelos-vencord.path angelos-vencord.timer; do
        cmp -s "$here/system/$f" "$units/$f" || { echo old; exit 0; }
    done
    for f in angelos-vencord.hook angelos-vencord-remove.hook; do
        cmp -s "$here/system/$f" "$hooks/$f" || { echo old; exit 0; }
    done
    cmp -s "$here/angelos-vencord" "$bin" && [ -x "$bin" ] || { echo old; exit 0; }
    echo ok
    exit 0
fi
[ -n "$root" ] || [ "$(id -u)" = 0 ] || { echo "run as root (pkexec / sudo)" >&2; exit 1; }
systemd() { [ -z "$root" ] && command -v systemctl >/dev/null 2>&1; }
if [ "${1:-}" = --remove ]; then
    if systemd; then systemctl disable --now angelos-vencord.path angelos-vencord.timer 2>/dev/null || true; fi
    rm -f "$hooks/angelos-vencord.hook" "$hooks/angelos-vencord-remove.hook" \
          "$units/angelos-vencord.service" "$units/angelos-vencord.path" "$units/angelos-vencord.timer" "$bin"
    if systemd; then systemctl daemon-reload || true; fi
    echo "removed"
    exit 0
fi
cachyos || { echo "not CachyOS: nothing to do"; exit 0; }
own=""
[ -n "$root" ] || own="-o root -g root"
# the guard first: a hook or a unit must never name a program that is not there yet
# shellcheck disable=SC2086
install -D $own -m 0755 "$here/angelos-vencord" "$bin"
for f in angelos-vencord.service angelos-vencord.path angelos-vencord.timer; do
    # shellcheck disable=SC2086
    install -D $own -m 0644 "$here/system/$f" "$units/$f"
done
for f in angelos-vencord.hook angelos-vencord-remove.hook; do
    # shellcheck disable=SC2086
    install -D $own -m 0644 "$here/system/$f" "$hooks/$f"
done
if systemd; then
    systemctl daemon-reload || true
    systemctl enable --now angelos-vencord.path angelos-vencord.timer || true
fi
ANGELOS_SYSROOT="$root" "$bin" patch || true
echo "installed: $bin"
