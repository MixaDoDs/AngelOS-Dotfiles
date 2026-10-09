#!/bin/sh
# Screenshots of the Golden Gate skin's Mac keys (services/ThemeExport → niri binds, the ⇧⌘5 menu):
#   mac-screenshot.sh screen   ⇧⌘3  the focused screen (grim)
#   mac-screenshot.sh region   ⇧⌘4  a part of it: the dotfiles' selector (niri-screenshot-region)
#   mac-screenshot.sh window         the focused window (niri: just the window, nothing over it)
#   mac-screenshot.sh record         a part of the screen as a video (niri-record-region)
# Pictures go where the selector puts them (~/Pictures/Screenshots/<App>/<MM.YYYY> by screenshot-sort,
# "Screenshot from <date>.png"; niri's own shots are moved there by `screenshot-sort watch`),
# onto the clipboard too, with a notification; niri's own screenshot UI when a tool is missing.
dir="$HOME/Pictures/Screenshots"
tools="$HOME/.local/bin"

say() {
  command -v notify-send >/dev/null 2>&1 && notify-send -a Screenshot "$@"
}
pling() {
  # the shell plays Golden Gate's shutter from the notification below (services/Sounds)
  [ -e "${XDG_RUNTIME_DIR:-/tmp}/angelos/shutter" ] && return 0
  f="$HOME/.local/share/sounds/screenshot-pling.ogg"
  [ -f "$f" ] && command -v pw-play >/dev/null 2>&1 && pw-play --volume 0.75 "$f" >/dev/null 2>&1 &
}

case "${1:-screen}" in
  screen)
    command -v grim >/dev/null 2>&1 || exec niri msg action screenshot-screen
    sorted="$("$tools/screenshot-sort" dir 2>/dev/null)"
    [ -d "$sorted" ] && dir="$sorted"
    mkdir -p "$dir"
    file="$dir/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png"
    out="$(niri msg -j focused-output 2>/dev/null | python3 -c 'import json, sys
try:
    print((json.load(sys.stdin) or {}).get("name") or "")
except Exception:
    pass' 2>/dev/null)"
    if [ -n "$out" ]; then
      grim -o "$out" "$file"
    else
      grim "$file"
    fi || { say "Ошибка скриншота" "grim не смог снять экран"; exit 1; }
    pling
    command -v wl-copy >/dev/null 2>&1 && wl-copy --type image/png < "$file"
    say "Скриншот сохранён" "$file"
    ;;
  region)
    [ -x "$tools/niri-screenshot-region" ] && exec "$tools/niri-screenshot-region"
    exec niri msg action screenshot
    ;;
  window)
    # niri saves it by its screenshot-path (the same folder and names) and copies it
    niri msg action screenshot-window || exit 1
    pling
    say "Снимок окна сохранён" "$dir"
    ;;
  record)
    [ -x "$tools/niri-record-region" ] && exec "$tools/niri-record-region"
    say "Запись экрана" "niri-record-region не найден"
    exit 1
    ;;
  *)
    echo "usage: mac-screenshot.sh screen|region|window|record" >&2
    exit 2
    ;;
esac
