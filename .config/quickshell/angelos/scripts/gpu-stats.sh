#!/bin/sh
# The GPU for the System monitor widget: one line "load %,temp °C,VRAM used MiB,VRAM total MiB",
# nothing when the card can't say (the widget shows "—").
#   NVIDIA: nvidia-smi.  AMD: amdgpu's sysfs (gpu_busy_percent, mem_info_vram_*, hwmon) —
#   the card with the most VRAM, so a laptop's dGPU wins over its APU.
#   Intel: its load needs root (intel_gpu_top), so it stays "—".
#   gpu-stats.sh              one line
#   gpu-stats.sh --watch SEC  a line every SEC seconds from one process, for as long as it runs
#                             (nvidia-smi's own loop; sysfs read by the shell's builtins): the
#                             widget no longer starts a shell and nvidia-smi every 2 s
every=""
[ "${1:-}" = --watch ] && every="${2:-2}"
if command -v nvidia-smi >/dev/null 2>&1; then
  q="--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total"
  line="$(nvidia-smi "$q" --format=csv,noheader,nounits -i 0 2>/dev/null)"
  if [ -n "$line" ]; then
    [ -n "$every" ] && exec nvidia-smi "$q" --format=csv,noheader,nounits -i 0 -lms "$((every * 1000))"
    echo "$line"
    exit 0
  fi
fi
best="" bestvram=-1
for dev in /sys/class/drm/card[0-9]*/device; do
  [ -r "$dev/gpu_busy_percent" ] || continue
  vram=0
  read -r vram <"$dev/mem_info_vram_total" 2>/dev/null
  [ "${vram:-0}" -gt "$bestvram" ] && { best="$dev"; bestvram="$vram"; }
done
[ -n "$best" ] || exit 0
tempfile=""
for t in "$best"/hwmon/hwmon*/temp1_input; do
  [ -r "$t" ] && { tempfile="$t"; break; }
done
while :; do
  read -r busy <"$best/gpu_busy_percent" 2>/dev/null || exit 0
  temp=-1
  [ -n "$tempfile" ] && read -r temp <"$tempfile" 2>/dev/null && temp=$((temp / 1000))
  used=0
  read -r used <"$best/mem_info_vram_used" 2>/dev/null
  echo "$busy, $temp, $((used / 1048576)), $((bestvram / 1048576))"
  [ -n "$every" ] || exit 0
  sleep "$every"
done
