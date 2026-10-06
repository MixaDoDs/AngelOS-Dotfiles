#!/usr/bin/env bash
# Is every package the installer asks pacman for in Arch Linux's official repositories
# (core, extra, multilib) — not only in CachyOS's? Asks archlinux.org, so it needs the network;
# check.sh stays offline, run this one before changing packages/*.txt.
#
#   scripts/check-packages.sh        exit 0 = all official; the others are listed
set -uo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
missing=0 unknown=0
while read -r pkg; do
  if ! json=$(curl -fsS --max-time 20 --retry 3 --retry-all-errors "https://archlinux.org/packages/search/json/?name=$pkg" 2>/dev/null); then
    printf '  ? %-28s %s\n' "$pkg" "archlinux.org did not answer"
    unknown=$((unknown + 1))
    continue
  fi
  repos=$(python3 -c 'import json,sys; print(" ".join(sorted({r["repo"] for r in json.load(sys.stdin)["results"]})))' <<<"$json" 2>/dev/null)
  if [[ " $repos " =~ \ (core|extra|multilib)\  ]]; then
    printf '  ✓ %-28s %s\n' "$pkg" "$repos"
  else
    [[ -n "$repos" ]] || repos="not in the official repositories"
    printf '  ✕ %-28s %s\n' "$pkg" "$repos"
    missing=$((missing + 1))
  fi
done < <(cat "$ROOT/packages/pacman.txt" "$ROOT/packages/angelos.txt" "$ROOT/packages/sddm.txt" "$ROOT/packages/tools.txt" "$ROOT/packages/nvim.txt" | grep -Ev '^[[:space:]]*(#|$)' | sort -u)
((missing)) && { echo "» $missing package(s) not in Arch's official repositories"; exit 1; }
((unknown)) && { echo "» $unknown package(s) not checked: archlinux.org did not answer, run it again"; exit 2; }
echo "» every package is in Arch's official repositories"
