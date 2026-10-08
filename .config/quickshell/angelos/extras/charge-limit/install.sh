#!/bin/sh
# angelOS: install the charge-limit helper (root: pkexec from Settings → Battery, or install.sh
# through sudo). Copies, never links: the helper must stay root's.
#   install.sh            install / update
#   install.sh --remove   take it away again
set -eu
[ "$(id -u)" = 0 ] || { echo "run as root (pkexec / sudo)" >&2; exit 1; }
here="$(cd "$(dirname "$0")" && pwd)"
bin=/usr/local/libexec/angelos-charge-limit
policy=/usr/share/polkit-1/actions/org.angelos.charge-limit.policy
if [ "${1:-}" = --remove ]; then
    rm -f "$bin" "$policy"
    echo "removed"
    exit 0
fi
install -D -o root -g root -m 0755 "$here/angelos-charge-limit" "$bin"
install -D -o root -g root -m 0644 "$here/org.angelos.charge-limit.policy" "$policy"
echo "installed: $bin"
