# shellcheck shell=bash
# angelOS installer — the face of it: a pastel "stream" in the terminal (sourced by install.sh).
#
# Built on gum (charmbracelet/gum, in Arch's and CachyOS's repositories): the menus, the
# confirmations, the input fields and the framed boxes. The hearts progress bar, the boot
# animation and the colours are plain ANSI here. Without a terminal (Settings → Updates
# runs the installer into a log), with NO_TUI=1, or when gum is missing, every question falls
# back to a plain numbered prompt and the output stays plain text, as it always was.
#
#   NO_TUI=1     plain prompts even with gum installed
#   NO_ANIM=1    no boot animation, no typing effect
#
# Needs from install.sh: INTERACTIVE, UI (en|ru), _() and warn()/die().

# ── palette (truecolor; NEEDY-GIRL pastel) ───────────────────────────────────

P_PINK='#ff8fc7' P_HOT='#ff4fa3' P_LILAC='#c9a7ff' P_CREAM='#fff0f7' P_DIM='#b48aa6'

TUI=0
tui_detect() {
  TUI=0
  ((INTERACTIVE)) || return 0
  [[ "${NO_TUI:-0}" == 1 || "${TERM:-dumb}" == dumb ]] && return 0
  command -v gum >/dev/null 2>&1 && TUI=1
  return 0
}

# ANSI truecolor from #rrggbb, only on a terminal and without NO_COLOR
_rgb() {
  local hex="${1#\#}"
  printf '\033[38;2;%d;%d;%dm' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}
fg() { [[ -t 1 && -z "${NO_COLOR:-}" ]] && _rgb "$1"; return 0; }
off() { [[ -t 1 && -z "${NO_COLOR:-}" ]] && printf '\033[0m'; return 0; }

# a random line of the "stream chat" (en/ru)
# shellcheck disable=SC2034  # read through the nameref in chat_line
CHAT_EN=(
  "chat is going feral rn ♡"
  "don't close the stream, we're installing!!"
  "+1000 followers if this config validates"
  "brb, pacman is thinking. so am i"
  "the wallpapers are so cute i might cry"
  "like, subscribe and reboot ♡"
  "omg a pixel font in 2026?? iconic"
  "mods, pin the backup folder pls"
  "no thoughts, only niri"
  "this is the good part of the stream"
)
# shellcheck disable=SC2034  # read through the nameref in chat_line
CHAT_RU=(
  "чат, держитесь, ставим!! ♡"
  "не закрывайте стрим, идёт установка"
  "+1000 подписчиков, если конфиг пройдёт проверку"
  "pacman думает. я тоже"
  "обои такие милые, я сейчас заплачу"
  "лайк, подписка, перезагрузка ♡"
  "пиксельный шрифт в 2026?? легенда"
  "модеры, закрепите папку с бэкапами"
  "ни одной мысли, только niri"
  "самая сладкая часть стрима"
)
CHAT_NICKS=(angel_fan_02 pixel_kitty overdose_enjoyer niri_nyan pastel.exe internet_angel hearts4u tilde_chan)

chat_line() {
  local src=CHAT_EN
  [[ "$UI" == ru ]] && src=CHAT_RU
  local -n lines="$src"
  local line="${lines[RANDOM % ${#lines[@]}]}" nick="${CHAT_NICKS[RANDOM % ${#CHAT_NICKS[@]}]}"
  printf '%s%s%s %s%s%s\n' "$(fg "$P_LILAC")" "$nick:" "$(off)" "$(fg "$P_CREAM")" "$line" "$(off)"
}

# ── the banner ───────────────────────────────────────────────────────────────

BANNER=(
'   ▄▀▀▄▄▀▀▄      ▄▀█ █▄ █ █▀▀ █▀▀ █   █▀█ █▀▀'
'  █  ♥  ♥  █     █▀█ █ ▀█ █▄█ ██▄ █▄▄ █▄█ ▄▄█'
'   ▀▄    ▄▀'
'     ▀▄▄▀        ● LIVE   dotfiles installer ♡'
)

tui_banner() {
  local i line delay=0.04
  [[ "${NO_ANIM:-0}" == 1 ]] && delay=0
  echo
  for i in "${!BANNER[@]}"; do
    line="${BANNER[i]}"
    if ((i == 3)); then
      printf '%s%s%s%s%s%s\n' "$(fg "$P_PINK")" "${line%%●*}" "$(fg "$P_HOT")" "● LIVE" "$(fg "$P_CREAM")" "${line#*● LIVE}"
    else
      printf '%s%s%s\n' "$(fg "$P_PINK")" "$line" "$(off)"
    fi
    [[ "$delay" == 0 ]] || sleep "$delay"
  done
  off
  echo
}

# "connecting to the stream…" — a few frames, then the banner
tui_boot() {
  ((INTERACTIVE)) || return 0
  local frames=('▖' '▘' '▝' '▗') i msg
  msg="$(_ 'connecting to the stream' 'подключаюсь к стриму')"
  if [[ "${NO_ANIM:-0}" != 1 ]]; then
    for i in {0..11}; do
      printf '\r%s%s %s%s%s' "$(fg "$P_HOT")" "${frames[i % 4]}" "$(fg "$P_CREAM")" "$msg" "$(printf '%*s' $((i % 4)) '' | tr ' ' '.')   "
      sleep 0.07
    done
    printf '\r\033[K'
  fi
  off
  tui_banner
  chat_line
  echo
}

# ── boxes ────────────────────────────────────────────────────────────────────

# the box's width: the terminal's, 56…76 columns
box_width() {
  local cols
  cols="$(tput cols 2>/dev/null || echo 80)"
  ((cols > 80)) && cols=80
  ((cols < 60)) && cols=60
  echo $((cols - 4))
}

# tui_section TITLE [TEXT…]: a pixel frame (▛▀▜ ▌ ▙▄▟; gum wraps the text), or a plain heading
tui_section() {
  local title="$1"; shift
  if ((TUI)); then
    local w edge line
    w="$(box_width)"
    printf -v edge '%*s' "$w" ''
    echo
    printf '%s▛%s▜%s\n' "$(fg "$P_PINK")" "${edge// /▀}" "$(off)"
    printf '%s▌%s %s%s%s\n' "$(fg "$P_PINK")" "$(off)" "$(fg "$P_HOT")" "♡ $title" "$(off)"
    if (($#)); then
      while IFS= read -r line; do
        printf '%s▌%s %s%s%s\n' "$(fg "$P_PINK")" "$(off)" "$(fg "$P_CREAM")" "$line" "$(off)"
      done < <(gum style --width "$((w - 2))" -- "$*")
    fi
    printf '%s▙%s▟%s\n' "$(fg "$P_PINK")" "${edge// /▄}" "$(off)"
  else
    hr
    printf '%s\n' "$title"
    (($#)) && printf '%s\n' "$@"
  fi
  return 0
}

tui_note() { # a dim line under a question
  if ((TUI)); then gum style --foreground "$P_DIM" --italic "$*"; else printf '%s\n' "$*"; fi
}

# ── questions ────────────────────────────────────────────────────────────────

# ui_choose HEADER DEFAULT_INDEX LABEL… → prints the chosen index (1-based)
ui_choose() {
  local header="$1" def="$2"; shift 2
  local labels=("$@") pick i reply
  if ((TUI)); then
    pick="$(gum choose --header "$header" --cursor "♡ " --selected "${labels[def-1]}" \
              --header.foreground "$P_PINK" --cursor.foreground "$P_HOT" --selected.foreground "$P_HOT" \
              --item.foreground "$P_CREAM" -- "${labels[@]}")" || die "$(_ 'Cancelled — the stream is over' 'Отменено — стрим окончен')"
    for i in "${!labels[@]}"; do
      [[ "${labels[i]}" == "$pick" ]] && { echo $((i + 1)); return 0; }
    done
    echo "$def"; return 0
  fi
  printf '%s\n' "$header" >&2
  for i in "${!labels[@]}"; do printf '  %d) %s\n' $((i + 1)) "${labels[i]}" >&2; done
  while :; do
    read -r -p "> [$def]: " reply || true
    reply="${reply:-$def}"
    [[ "$reply" =~ ^[0-9]+$ ]] && ((reply >= 1 && reply <= ${#labels[@]})) && { echo "$reply"; return 0; }
    warn "$(_ 'Enter a number from the list' 'Введите номер из списка')"
  done
}

# ui_choose_many HEADER "1 3" LABEL… → prints the chosen indices (1-based, space separated;
# empty when none). The second argument preselects.
ui_choose_many() {
  local header="$1" pre="$2"; shift 2
  local labels=("$@") sel=() out=() line i n reply
  if ((TUI)); then
    for n in $pre; do sel+=("${labels[n-1]}"); done
    local IFS=,
    local picked
    picked="$(gum choose --no-limit --header "$header" --cursor "♡ " --selected "${sel[*]:-}" \
                --cursor-prefix "♡ " --selected-prefix "♥ " --unselected-prefix "· " \
                --header.foreground "$P_PINK" --cursor.foreground "$P_HOT" --selected.foreground "$P_HOT" \
                --item.foreground "$P_CREAM" -- "${labels[@]}")" || die "$(_ 'Cancelled — the stream is over' 'Отменено — стрим окончен')"
    unset IFS
    while IFS= read -r line; do
      for i in "${!labels[@]}"; do [[ "${labels[i]}" == "$line" ]] && out+=($((i + 1))); done
    done <<<"$picked"
    echo "${out[*]:-}"; return 0
  fi
  printf '%s\n' "$header" >&2
  for i in "${!labels[@]}"; do printf '  %d) %s\n' $((i + 1)) "${labels[i]}" >&2; done
  read -r -p "$(_ 'Numbers, e.g. 1 3 (a = all, n = none)' 'Номера, например 1 3 (a — все, n — ничего)') [${pre:-n}]: " reply || true
  reply="${reply:-${pre:-n}}"
  case "$reply" in
    a|A|all|все|а) for i in "${!labels[@]}"; do out+=($((i + 1))); done ;;
    n|N|none|нет|н|0) ;;
    *) for n in ${reply//,/ }; do [[ "$n" =~ ^[0-9]+$ ]] && ((n >= 1 && n <= ${#labels[@]})) && out+=("$n"); done ;;
  esac
  echo "${out[*]:-}"
}

# ui_confirm QUESTION y|n → 0 for yes; without a terminal the default wins
ui_confirm() {
  local question="$1" default="${2:-n}"
  if ((TUI)); then
    local d=false; [[ "$default" == y ]] && d=true
    # gum confirm doesn't wrap: a long question is wrapped here to the box's width
    question="$(gum style --width "$(box_width)" -- "$question" | sed 's/[[:space:]]*$//')"
    gum confirm --default="$d" --affirmative "$(_ 'Yes ♡' 'Да ♡')" --negative "$(_ 'No' 'Нет')" \
      --prompt.foreground "$P_CREAM" --selected.background "$P_HOT" --selected.foreground "$P_CREAM" \
      --unselected.foreground "$P_LILAC" -- "$question"
    local rc=$?
    ((rc == 130)) && die "$(_ 'Cancelled — the stream is over' 'Отменено — стрим окончен')"
    return "$rc"
  fi
  confirm "$question" "$default"
}

# ui_input PROMPT DEFAULT → the answer (DEFAULT when empty)
ui_input() {
  local prompt="$1" def="${2:-}" reply
  if ((TUI)); then
    reply="$(gum input --prompt "♡ $prompt › " --value "$def" --prompt.foreground "$P_PINK" \
               --cursor.foreground "$P_HOT")" || die "$(_ 'Cancelled — the stream is over' 'Отменено — стрим окончен')"
    printf '%s' "${reply:-$def}"; return 0
  fi
  read -r -p "$prompt [$def]: " reply || true
  printf '%s' "${reply:-$def}"
}

# ── progress ─────────────────────────────────────────────────────────────────

# ui_progress N TOTAL LABEL: ♥♥♥♥♡♡♡♡♡♡ 40%  label — on a terminal only (logs stay as they were)
ui_progress() {
  ((INTERACTIVE)) && [[ -t 1 ]] || return 0
  local n="$1" total="$2" label="$3" width=10 full bar="" i pct
  ((total > 0)) || total=1
  full=$((n * width / total)); pct=$((n * 100 / total))
  for ((i = 0; i < width; i++)); do
    if ((i < full)); then bar+="$(fg "$P_HOT")♥"; else bar+="$(fg "$P_LILAC")♡"; fi
  done
  printf '\n%s %s%3d%%%s  %s%s%s\n' "$bar" "$(fg "$P_CREAM")" "$pct" "$(off)" "$(fg "$P_PINK")" "$label" "$(off)"
  # every third step someone in chat says something
  ((n % 3 == 1)) && chat_line
  return 0
}
