#!/usr/bin/env bash
# A small GIF from a recording: two-pass palette (ffmpeg), ordered dither that suits pixel art,
# only the changed rectangle per frame; gifsicle squeezes it further when it is installed.
#
#   scripts/demo/gif.sh IN.mp4 OUT.gif [WIDTH=960] [FPS=12] [START=0] [LENGTH=]
set -Eeuo pipefail
in="${1:?in.mp4}" out="${2:?out.gif}" width="${3:-960}" fps="${4:-12}" start="${5:-0}" length="${6:-}"
pal="$(mktemp --suffix=.png)"; trap 'rm -f "$pal"' EXIT
cut=(-ss "$start"); [[ -n "$length" ]] && cut+=(-t "$length")
ffmpeg -v error -y "${cut[@]}" -i "$in" \
  -vf "fps=$fps,scale=$width:-1:flags=lanczos,palettegen=max_colors=128:stats_mode=diff" "$pal"
ffmpeg -v error -y "${cut[@]}" -i "$in" -i "$pal" \
  -lavfi "fps=$fps,scale=$width:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" "$out"
command -v gifsicle >/dev/null 2>&1 && gifsicle -b -O3 --lossy=40 "$out" 2>/dev/null || true
printf '%s  %s\n' "$(du -h "$out" | cut -f1)" "$out"
