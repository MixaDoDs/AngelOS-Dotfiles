#!/usr/bin/env bash
# angelOS rescue: the shell could not start (a broken update, Quickshell built against another
# Qt, a file cut short). systemd tries five times in a minute and gives up — the desk stays
# bare, and nothing on it says why. `bin/angelos reap` opens this in a terminal after the last
# try (`angelos rescue` by hand): the reason from the log, another try, the way back to before
# the last update (the snapshot Settings → Updates takes), the log, a report.
#   rescue.sh [--why]        --why: only print the reason and leave
# Environment (tests): ANGELOS_UNIT, ANGELOS_RESCUE_LOG (a file read instead of the journal),
# ANGELOS_LANG (ru | en).
set -uo pipefail
SHELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/angelos"
RUN_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/angelos"
UNIT="${ANGELOS_UNIT:-angelos.service}"
ANGELOS="$SHELL_DIR/bin/angelos"

# the language of the shell (settings.json), of the system when it was never picked
lang="${ANGELOS_LANG:-}"
[[ -n "$lang" ]] || lang="$(sed -n 's/.*"language": *"\([a-z]*\)".*/\1/p' "$CONF_DIR/settings.json" 2>/dev/null | head -n 1)"
if [[ "$lang" != ru && "$lang" != en ]]; then
  case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in ru*) lang=ru ;; *) lang=en ;; esac
fi
_() { if [[ "$lang" == ru ]]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }
say() { printf '  %s\n' "$(_ "$1" "$2")"; }

log_tail() {
  if [[ -n "${ANGELOS_RESCUE_LOG:-}" ]]; then
    tail -n 400 -- "$ANGELOS_RESCUE_LOG" 2>/dev/null
  else
    journalctl --user -u "$UNIT" -n 400 -o cat --no-pager 2>/dev/null
  fi | sed 's/\x1b\[[0-9;]*m//g'
}
# the last start's errors: Quickshell's "Failed to load configuration" with its causes, a
# library the loader did not find, a crash
why() {
  log_tail | awk '
    /Launching config/ { n = 0 }
    /ERROR|caused by|error while loading shared libraries|symbol lookup error|cannot open shared object|Cannot mix incompatible Qt|was built against|Segmentation|core dumped|Failed to create wl_display/ {
      sub(/^[ \t]+/, ""); line[n++] = $0 }
    END { from = n > 8 ? n - 8 : 0; for (i = from; i < n; i++) print line[i] }' | cut -c1-300
}
# what the reason means and what helps, in a sentence
hint() {
  local w="$1" snap="$2"
  if grep -qE 'error while loading shared libraries|symbol lookup error|cannot open shared object|Cannot mix incompatible Qt|was built against' <<<"$w"; then
    say "Похоже, Quickshell и Qt разошлись версиями (так бывает после частичного обновления системы). Помогает: обновить систему целиком — sudo pacman -Syu в терминале, — затем «angelos updates update» и пункт 1." \
        "Quickshell and Qt look out of step (it happens after a partial system update). What helps: update the whole system — sudo pacman -Syu in a terminal — then 'angelos updates update' and item 1."
  elif grep -qE 'Failed to load configuration|caused by' <<<"$w"; then
    if [[ -n "$snap" ]]; then
      say "Оболочка не смогла прочитать собственные файлы: обновление прервалось или файл изменён. Помогает пункт 2 — вернуть как было до обновления." \
          "The shell could not read its own files: an update was cut short or a file was changed. Item 2 helps: put things back as they were before the update."
    else
      say "Оболочка не смогла прочитать собственные файлы: обновление прервалось или файл изменён. Помогает поставить их заново: «angelos updates update» в терминале, затем пункт 1." \
          "The shell could not read its own files: an update was cut short or a file was changed. Installing them again helps: 'angelos updates update' in a terminal, then item 1."
    fi
  elif [[ -z "$w" ]]; then
    say "В журнале нет явной ошибки. Попробуй запустить ещё раз (пункт 1)." \
        "The log names no error. Try starting it again (item 1)."
  fi
}

if [[ "${1:-}" == --why ]]; then why; exit 0; fi

# one rescue at a time (bin/angelos reap asks before it opens another)
mkdir -p "$RUN_DIR" 2>/dev/null && echo $$ >"$RUN_DIR/rescue.pid"
trap 'rm -f "$RUN_DIR/rescue.pid"' EXIT

active() { systemctl --user is-active --quiet "$UNIT" 2>/dev/null; }
# the snapshot of the last update: LAST <status> <stage> <dir> <old> <new>
snapshot() {
  local line dir
  line="$(bash "$SHELL_DIR/scripts/dotfiles-update.sh" --last 2>/dev/null | sed -n 's/^LAST //p' | head -n 1)"
  read -r snap_status _ dir _ <<<"$line"
  [[ -n "${dir:-}" && -f "$dir/meta.json" && "${snap_status:-}" != restored ]] && printf '%s' "$dir"
}
# PAGER may carry its options
# shellcheck disable=SC2086
show_log() { log_tail | ${PAGER:-less -R}; }
pause() { printf '\n'; read -r -p "  $(_ "Enter — дальше" "Enter to go on") " _ || true; }

try_start() {
  printf '\n'
  say "Запускаю…" "Starting…"
  "$ANGELOS" restart >/dev/null 2>&1
  # a start that fails does so within a second or two, five times over
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
    sleep 1
    if systemctl --user is-failed --quiet "$UNIT" 2>/dev/null; then
      say "Не запустилась: причина выше та же или новая — смотри ниже." "It did not start: the reason is below, the same or a new one."
      return 1
    fi
  done
  if active; then
    say "angelOS запустилась ♡ Это окно можно закрыть." "angelOS is up ♡ You can close this window."
    return 0
  fi
  say "Не запустилась." "It did not start."
  return 1
}

while :; do
  clear 2>/dev/null || true
  printf '\n'
  say "angelOS не запустилась" "angelOS did not start"
  say "──────────────────────" "──────────────────────"
  printf '\n'
  if active; then
    say "Сейчас она работает — похоже, уже всё хорошо." "It is running right now — things look fine again."
    printf '\n'
  fi
  reason="$(why)"
  if [[ -n "$reason" ]]; then
    say "Что сказано в журнале:" "What the log says:"
    printf '%s\n' "$reason" | sed 's/^/    /'
    printf '\n'
  fi
  snap="$(snapshot || true)"
  hint "$reason" "$snap"
  printf '\n'
  say "1) Попробовать запустить ещё раз" "1) Try to start it again"
  if [[ -n "$snap" ]]; then
    say "2) Вернуть как было до последнего обновления (${snap##*/})" "2) Put things back as they were before the last update (${snap##*/})"
  else
    say "2) (снимка последнего обновления нет — вернуть нечего)" "2) (no snapshot of the last update: nothing to put back)"
  fi
  say "3) Показать журнал целиком" "3) Show the whole log"
  say "4) Собрать отчёт для автора (файл в домашней папке)" "4) Make a report for the author (a file in your home folder)"
  say "q) Закрыть" "q) Close"
  printf '\n'
  say "Твои программы и файлы на месте: не работает только панель и меню. Терминал: Mod+T." \
      "Your apps and files are fine: only the bar and the menus are down. A terminal: Mod+T."
  printf '\n'
  read -r -p "  > " answer || exit 0
  case "$answer" in
    1) try_start && { pause; exit 0; }; pause ;;
    2)
      if [[ -z "$snap" ]]; then pause; continue; fi
      printf '\n'
      say "Вернутся файлы, которые изменило последнее обновление; то, что ты менял после него, останется как есть." \
          "The files the last update changed go back; whatever you changed after it stays as it is."
      read -r -p "  $(_ "Вернуть? [y/N]" "Put them back? [y/N]") " yes || exit 0
      case "$yes" in
        y|Y|д|Д|yes|да)
          if bash "$SHELL_DIR/scripts/dotfiles-update.sh" --restore "$snap" 2>&1 | sed 's/^/    /'; then
            try_start && { pause; exit 0; }
          fi
          pause ;;
      esac ;;
    3) show_log ;;
    4) printf '\n'; "$ANGELOS" report 2>&1 | sed 's/^/    /'; pause ;;
    q|Q|й|Й) exit 0 ;;
  esac
done
