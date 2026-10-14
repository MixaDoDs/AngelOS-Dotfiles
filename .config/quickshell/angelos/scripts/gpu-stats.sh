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
# A laptop's NVIDIA card that sleeps when unused (runtime power management, hybrid graphics) is
# never woken for the widget: nvidia-smi powers it up, and its loop keeps it up for good — a
# card meant to be off ran all day and heated the laptop (#60). While it sleeps the line says
# 0 % and no temperature (no nvidia-smi at all); while something else keeps it awake (a game)
# it is asked every 10 s by a nvidia-smi that exits, so it can go back to sleep afterwards.
every=""
[ "${1:-}" = --watch ] && every="${2:-2}"
if command -v nvidia-smi >/dev/null 2>&1; then
  q="--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total"
  # the card nvidia-smi calls 0 is the first on the bus; its power state from sysfs (reading
  # it doesn't wake the card). Only a card that may sleep and isn't the one the computer
  # started on (boot_vga 0: the laptop's screen hangs off the other GPU) — a desktop's card
  # with the monitors on it says "auto" too, but it is always awake and keeps the 2 s loop
  pm=""
  for d in /sys/bus/pci/drivers/nvidia/0000:*; do
    [ -r "$d/power/runtime_status" ] || continue
    ctl="" boot=""
    read -r ctl <"$d/power/control" 2>/dev/null
    read -r boot <"$d/boot_vga" 2>/dev/null
    [ "$ctl" = auto ] && [ "$boot" != 1 ] && pm="$d/power/runtime_status"
    break
  done
  if [ -z "$pm" ]; then
    line="$(nvidia-smi "$q" --format=csv,noheader,nounits -i 0 2>/dev/null)"
    if [ -n "$line" ]; then
      [ -n "$every" ] && exec nvidia-smi "$q" --format=csv,noheader,nounits -i 0 -lms "$((every * 1000))"
      echo "$line"
      exit 0
    fi
  else
    total=0 tick=0
    ask=$(( (10 + ${every:-10} - 1) / ${every:-10} ))   # ticks between questions: ~10 s
    while :; do
      st=""
      read -r st <"$pm" 2>/dev/null
      if [ "$st" = active ]; then
        if [ "$tick" -eq 0 ]; then
          line="$(nvidia-smi "$q" --format=csv,noheader,nounits -i 0 2>/dev/null)"
          if [ -n "$line" ]; then
            echo "$line"
            total="${line##*,}"
            total="${total# }"
          fi
        fi
        tick=$(( (tick + 1) % ask ))
      else
        echo "0, -1, 0, $total"
        tick=0
      fi
      [ -n "$every" ] || exit 0
      sleep "$every"
    done
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
