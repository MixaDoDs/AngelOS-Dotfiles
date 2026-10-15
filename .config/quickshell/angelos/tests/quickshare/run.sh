#!/usr/bin/env bash
# Quick Share (scripts/quickshare.py): two daemons send each other a text, a file and a folder,
# a refusal and a closed receive — in a network namespace of their own (only loopback, multicast on it), so
# their announcements never reach the live daemon or the phones on the LAN.
#
#   tests/quickshare/run.sh [angelOS dir]      exit 0 = all good, 77 = no user namespaces
set -uo pipefail
DIR="$(cd "${1:-"$(dirname "$0")/../.."}" && pwd)"
[[ -f "$DIR/scripts/quickshare.py" ]] || { echo "no angelOS in $DIR"; exit 2; }
unshare -rn true 2>/dev/null || { echo "unshare -rn unavailable: skipped"; exit 77; }
exec unshare -rn sh -c 'ip link set lo up multicast on && ip route add 224.0.0.0/4 dev lo && exec python3 -I "$1" "$2"' sh "$DIR/tests/quickshare/test_quickshare.py" "$DIR"
