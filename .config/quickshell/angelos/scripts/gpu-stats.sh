#!/bin/sh
# The GPU for the System monitor widget: one line "load %,temp °C,VRAM used MiB,VRAM total MiB",
# nothing when the card can't say (the widget shows "—").
#   NVIDIA: nvidia-smi.  AMD: amdgpu's sysfs (gpu_busy_percent, mem_info_vram_*, hwmon) —
#   the card with the most VRAM, so a laptop's dGPU wins over its APU.
#   Intel: its load needs root (intel_gpu_top), so it stays "—".
if command -v nvidia-smi >/dev/null 2>&1; then
  line="$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total \
          --format=csv,noheader,nounits 2>/dev/null | head -1)"
  [ -n "$line" ] && { echo "$line"; exit 0; }
fi
best="" bestvram=-1
for dev in /sys/class/drm/card[0-9]*/device; do
  [ -r "$dev/gpu_busy_percent" ] || continue
  vram="$(cat "$dev/mem_info_vram_total" 2>/dev/null || echo 0)"
  [ "$vram" -gt "$bestvram" ] && { best="$dev"; bestvram="$vram"; }
done
[ -n "$best" ] || exit 0
busy="$(cat "$best/gpu_busy_percent" 2>/dev/null)" || exit 0
temp=""
for t in "$best"/hwmon/hwmon*/temp1_input; do
  [ -r "$t" ] && { temp=$(( $(cat "$t") / 1000 )); break; }
done
used="$(cat "$best/mem_info_vram_used" 2>/dev/null || echo 0)"
echo "$busy, ${temp:--1}, $((used / 1048576)), $((bestvram / 1048576))"
