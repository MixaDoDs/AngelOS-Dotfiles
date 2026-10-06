#!/usr/bin/env bash
# Read every screenshot and GIF of the README back with OCR and look for what must never be
# in a frame: the author's login or host, an e-mail address, a home path, a key or a token.
#
#   scripts/demo/check-frames.sh [FILES…]     default: docs/screenshots/*.png docs/demo/*.gif
#   DEMO_FORBID='extra|words'                 more to look for (a regular expression)
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
command -v tesseract >/dev/null 2>&1 || { echo "tesseract is needed"; exit 2; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
me="$(id -un)" host="$(cat /etc/hostname 2>/dev/null || hostname)"
forbid="$me|$host|@gmail|@yandex|@mail\.|/home/[a-z]|sk-[A-Za-z0-9]{6}|ghp_|token|api[_ -]?key|password"
[[ -n "${DEMO_FORBID:-}" ]] && forbid+="|$DEMO_FORBID"
files=("$@")
((${#files[@]})) || files=("$ROOT"/docs/screenshots/*.png "$ROOT"/docs/demo/*.gif)
bad=0
for f in "${files[@]}"; do
  rm -f "$WORK"/*.png
  case "$f" in
    *.gif) ffmpeg -v error -i "$f" -vf "fps=2,scale=iw*2:-1:flags=neighbor" "$WORK/f%04d.png" ;;
    *) ffmpeg -v error -i "$f" -vf "scale=iw*2:-1:flags=neighbor" "$WORK/f0001.png" ;;
  esac
  hits=""
  for frame in "$WORK"/*.png; do
    text="$(tesseract "$frame" - -l eng+rus 2>/dev/null || true)"
    h="$(grep -oiE -- "$forbid" <<<"$text" | sort -u | paste -sd, - || true)"
    [[ -n "$h" ]] && hits+="${hits:+; }$(basename "$frame"): $h"
  done
  if [[ -n "$hits" ]]; then
    printf '✕ %s — %s\n' "${f#"$ROOT"/}" "$hits"; bad=1
  else
    printf '✓ %s\n' "${f#"$ROOT"/}"
  fi
done
exit "$bad"
