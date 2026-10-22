#!/usr/bin/env bash
# The NVIDIA card at full speed while a game runs (Settings → System → Games): the graphics clock
# can't drop below 60 % of its maximum, so a light game (CS2) doesn't stutter while the card
# slows down and speeds up again. Run as root (game-setup.sh does it): puts a root-owned helper
# in /usr/local/lib/angelos/gpu-clocks and lets the user sudo ran this for run its two fixed
# commands without a password (/etc/sudoers.d/angelos-gpu-clocks). niri-game-mode calls it:
#
#   sudo -n /usr/local/lib/angelos/gpu-clocks game     lock the clock to [60 % of max, max]
#   sudo -n /usr/local/lib/angelos/gpu-clocks reset    the driver's own clocks again
#
#   sudo gpu-clocks-setup.sh [install]   install or update both
#   sudo gpu-clocks-setup.sh remove      take both away
set -euo pipefail

HELPER=/usr/local/lib/angelos/gpu-clocks
RULE=/etc/sudoers.d/angelos-gpu-clocks

[[ $EUID -eq 0 ]] || { echo "gpu-clocks-setup.sh: run it with sudo" >&2; exit 1; }

if [[ "${1:-install}" == remove ]]; then
  [[ -x "$HELPER" ]] && "$HELPER" reset >/dev/null 2>&1 || true
  rm -f -- "$HELPER" "$RULE"
  exit 0
fi

command -v nvidia-smi >/dev/null 2>&1 || { echo "gpu-clocks-setup.sh: no nvidia-smi, nothing to do" >&2; exit 0; }
[[ -n "${SUDO_USER:-}" && "$SUDO_USER" != root ]] || { echo "gpu-clocks-setup.sh: run it with sudo from the desktop user" >&2; exit 1; }

install -d -m 0755 "$(dirname "$HELPER")"
tmp="$(mktemp)"
trap 'rm -f -- "$tmp"' EXIT
cat >"$tmp" <<'EOF'
#!/bin/sh
# angelOS (scripts/gpu-clocks-setup.sh): the NVIDIA graphics clock locked while a game runs
PATH=/usr/bin:/bin
case "$1" in
  game)
    max=$(nvidia-smi --query-gpu=clocks.max.graphics --format=csv,noheader,nounits | head -n1 | tr -dc 0-9)
    [ -n "$max" ] || exit 1
    exec nvidia-smi --lock-gpu-clocks=$((max * 6 / 10)),"$max" ;;
  reset)
    exec nvidia-smi --reset-gpu-clocks ;;
  *)
    echo "usage: gpu-clocks game|reset" >&2; exit 2 ;;
esac
EOF
install -m 0755 -o root -g root "$tmp" "$HELPER"
cat >"$tmp" <<EOF
# angelOS (scripts/gpu-clocks-setup.sh): the game boost locks the video card's clocks
$SUDO_USER ALL=(root) NOPASSWD: $HELPER game, $HELPER reset
EOF
visudo -cqf "$tmp"
install -m 0440 -o root -g root "$tmp" "$RULE"
echo "gpu-clocks: $HELPER, $RULE"
