# shellcheck shell=bash
# angelOS installer — the show: pictures, the angel flapping, music and sounds (sourced by install.sh).
#
# Pictures go straight to the terminal (/dev/tty), never into a log: chafa when it is there
# (kitty graphics in kitty/ghostty/wezterm, sixel in foot/konsole, coloured blocks elsewhere), else
# the half-block .ans frames of installer/art (they work in the Linux console too). Sounds play
# through PipeWire (pw-play) or PulseAudio (paplay) when a sound server answers, else nothing.
#
#   NO_ANIM=1    pictures stand still (the first frame), no typing effect
#   NO_MUSIC=1   no music and no sounds (also off on the author's own machine: the stream hears it)
#   NO_TUI=1     no pictures either (plain text)

ART="$ROOT/installer/art"
SND="$ROOT/.config/quickshell/angelos/data/sounds"
SHOW=0 CHAFA=0 PLAYER=() MUSIC_PID=""

show_init() {
  SHOW=0 CHAFA=0 PLAYER=()
  ((INTERACTIVE && TTY_OUT)) && [[ "${NO_TUI:-0}" != 1 && "${TERM:-dumb}" != dumb ]] && [[ -w /dev/tty ]] || return 0
  SHOW=1
  command -v chafa >/dev/null 2>&1 && CHAFA=1
  [[ "${NO_MUSIC:-0}" == 1 || -d "$HOME_DIR/.config/quickshell/angelos/owner" || -n "${SSH_CONNECTION:-}" ]] && return 0
  if command -v pw-play >/dev/null 2>&1 && timeout 2 pw-cli info 0 >/dev/null 2>&1; then
    PLAYER=(pw-play --volume 0.35)
  elif command -v paplay >/dev/null 2>&1 && timeout 2 pactl info >/dev/null 2>&1; then
    PLAYER=(paplay --volume 22000)
  fi
  return 0
}

# sfx NAME: a sound of data/sounds (pc2k/startup, intro/choir-swell…), not waited for
sfx() {
  ((${#PLAYER[@]})) && [[ -f "$SND/$1.ogg" ]] || return 0
  ("${PLAYER[@]}" "$SND/$1.ogg" >/dev/null 2>&1 &)
  return 0
}

# the intro's quiet loop under the long steps; music_stop ends it (cleanup does too)
music_start() {
  ((${#PLAYER[@]})) && [[ -z "$MUSIC_PID" && -f "$SND/intro/music.ogg" ]] || return 0
  local -a play=("${PLAYER[@]}")
  [[ "${play[0]}" == pw-play ]] && play=(pw-play --volume 0.12) || play=(paplay --volume 8000)
  ( trap 'kill $! 2>/dev/null; exit 0' TERM
    while kill -0 "$$" 2>/dev/null; do "${play[@]}" "$SND/intro/music.ogg" >/dev/null 2>&1 & wait $! || break; done ) &
  MUSIC_PID=$!
  return 0
}
music_stop() {
  [[ -n "$MUSIC_PID" ]] || return 0
  kill "$MUSIC_PID" 2>/dev/null || true
  MUSIC_PID=""
  return 0
}

# pic FILE ROWS: a picture ROWS lines high (a .gif plays once with chafa, unless NO_ANIM)
pic() {
  ((SHOW)) || return 0
  local f="$1" rows="${2:-12}" cols ans="${1%.*}.ans"
  cols="$(tput cols 2>/dev/null || echo 80)"
  if ((CHAFA)); then
    local -a o=(--size "$((cols - 4))x$rows" --align left)
    ((CONSOLE)) && o+=(-f symbols --colors 16 --symbols block)
    [[ -n "${TMUX:-}" ]] && o+=(-f symbols)
    # on a terminal chafa plays a lone .gif forever unless told: the billboard before pacman
    # never ended, the install stood at 0% (issue #97). Once, and pacman waits 10 s at most
    if [[ "${NO_ANIM:-0}" == 1 ]]; then o+=(--animate off); else o+=(--duration 0); fi
    local rc=0
    timeout --foreground -s INT 10 chafa "${o[@]}" -- "$f" >/dev/tty 2>/dev/null || rc=$?
    ((rc == 0 || rc == 124)) && return 0
  fi
  [[ -f "$ans" ]] && cat -- "$ans" >/dev/tty
  return 0
}

# anim NAME SECONDS [once]: the angel (or the demon) flapping, from installer/art; once = the
# frames one time, ending on the last (the chest opening)
anim() {
  ((SHOW)) || return 0
  local name="$1" secs="${2:-2}" once="${3:-}" frames=() i=0 h end
  if [[ -z "$once" ]] && ((CHAFA && !CONSOLE)) && [[ -f "$ART/$name.gif" ]]; then
    local -a o=(--size "40x16" --align left --duration "$secs")
    [[ "${NO_ANIM:-0}" == 1 ]] && o=(--size "40x16" --align left --animate off)
    chafa "${o[@]}" -- "$ART/$name.gif" >/dev/tty 2>/dev/null && return 0
  fi
  mapfile -t frames < <(find "$ART" -maxdepth 1 -name "$name-*.ans" | sort -V)
  ((${#frames[@]})) || return 0
  if [[ "${NO_ANIM:-0}" == 1 ]]; then cat -- "${frames[-1]}" >/dev/tty; return 0; fi
  h="$(wc -l <"${frames[0]}")"
  end=$((SECONDS + secs))
  printf '\033[?25l' >/dev/tty
  while :; do
    cat -- "${frames[i % ${#frames[@]}]}" >/dev/tty
    i=$((i + 1))
    if [[ -n "$once" ]]; then ((i < ${#frames[@]})) || break; else ((SECONDS < end)) || break; fi
    sleep "$([[ -n "$once" ]] && echo 0.3 || echo 0.11)"
    printf '\033[%dA' "$h" >/dev/tty
  done
  printf '\033[?25h' >/dev/tty
}

# typed TEXT: letters one by one, the keyboard's clicks under them
typed() {
  ((SHOW)) && [[ "${NO_ANIM:-0}" != 1 ]] || { printf '%s\n' "$*"; return 0; }
  local s="$*" i
  for ((i = 0; i < ${#s}; i++)); do
    printf '%s' "${s:i:1}"
    ((i % 6 == 0)) && [[ "${s:i:1}" != ' ' ]] && sfx "pc2k/key$(((i / 6) % 3 == 0 ? 2 : 3))"
    sleep 0.025
  done
  printf '\n'
}

# while the packages download: what angelOS can do, as the billboards of an old Windows setup
billboard() {
  ((SHOW && CHAFA)) || return 0
  local -a gifs
  mapfile -t gifs < <(find "$ROOT/docs/demo" -maxdepth 1 -name '*.gif' ! -name 'installer.gif' 2>/dev/null)
  ((${#gifs[@]})) || return 0
  pic "${gifs[RANDOM % ${#gifs[@]}]}" 14
}

# the end: the chest opens (data/chest), the achievement sound — or the demon laughs at a failure
show_finale() {
  ((SHOW)) || return 0
  music_stop
  sfx pc2k/chestOpen
  anim chest 0 once
  sfx pc2k/chestPrize
  sleep 0.3
  sfx pc2k/achievement
}
show_failure() {
  ((SHOW)) || return 0
  music_stop
  sfx hell/src/fraud-laugh
  anim demon 2
}
