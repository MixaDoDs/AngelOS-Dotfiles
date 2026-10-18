#!/usr/bin/env bash
# «Позвать помощника» (Settings → Maintenance → Helper): something broke → an AI agent the user
# picked (Claude Code, Codex or opencode, settings.json system.helpAgent) opens in a terminal with
# this machine's logs already gathered and angelOS's rules for it: plain words, a snapshot first,
# a question before every change, the user's own files left alone. The user logs in to their own
# account in the agent; angelOS ships no keys.
#
#   help-agent.sh [--context FILE] [TEXT…]
#       TEXT     what happened, in the user's words (none: the agent asks)
#       FILE     more context to put next to the logs (a game's notes, say)
#
# Without a terminal (from the shell) it opens one itself (settings.json system.terminal).
# The agent works in ~/.local/state/angelos/help/<time>/: AGENTS.md (CLAUDE.md links to it),
# context/*.txt; the last five such folders are kept. No CLI: it offers to install it with pacman.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/angelos/settings.json"
setting() { # section key → the value in settings.json, or nothing
  python3 - "$SETTINGS" "$1" "$2" <<'PY' 2>/dev/null || true
import json, sys
try:
    v = (json.load(open(sys.argv[1])).get(sys.argv[2]) or {}).get(sys.argv[3])
except Exception:
    v = None
print(v if isinstance(v, str) else "")
PY
}

if [[ ! -t 0 || ! -t 1 ]]; then
  t="$(setting system terminal)"; t="${t:-kitty}"
  case "${t##*/}" in
    kitty|foot) exec "$t" bash "$0" "$@" ;;
    wezterm) exec "$t" start -- bash "$0" "$@" ;;
    *) exec "$t" -e bash "$0" "$@" ;;
  esac
fi

CONTEXT=""
if [[ "${1:-}" == --context ]]; then CONTEXT="${2:-}"; shift 2 || shift; fi
TASK="$*"
LANG_UI="${ANGELOS_LANG:-$(setting appearance language)}"
case "${LANG_UI:-${LANG:-}}" in en*) RU=0 ;; *) RU=1 ;; esac
_() { if ((RU)); then printf '%s' "$2"; else printf '%s' "$1"; fi; }
say() { printf '\033[1;35m»\033[0m %s\n' "$(_ "$1" "$2")"; }
pause() { read -r -p "$(_ 'Enter — close' 'Enter — закрыть') " _ || true; }

# id → the command and its package (all three are in CachyOS's repositories)
declare -A BIN=([claude]=claude [codex]=codex [opencode]=opencode)
declare -A PKG=([claude]=claude-code [codex]=openai-codex [opencode]=opencode)
AGENT="${ANGELOS_HELP_AGENT:-$(setting system helpAgent)}"
if [[ -z "$AGENT" || -z "${BIN[$AGENT]+x}" ]]; then
  AGENT=claude
  for a in claude codex opencode; do command -v "${BIN[$a]}" >/dev/null 2>&1 && { AGENT=$a; break; }; done
fi
if ! command -v "${BIN[$AGENT]}" >/dev/null 2>&1; then
  say "${BIN[$AGENT]} is not installed. It comes from the repositories: sudo pacman -S ${PKG[$AGENT]}" \
      "${BIN[$AGENT]} не установлен. Он есть в репозиториях: sudo pacman -S ${PKG[$AGENT]}"
  read -r -p "$(_ 'Install it now? [Y/n] ' 'Поставить сейчас? [Д/н] ')" a || a=n
  if [[ ! "${a:-y}" =~ ^[yYдД] ]] || ! sudo pacman -S --needed "${PKG[$AGENT]}" || ! command -v "${BIN[$AGENT]}" >/dev/null 2>&1; then
    say 'Not installed: nothing to open.' 'Не поставился: открывать нечего.'
    pause; exit 1
  fi
fi

BASE="${XDG_STATE_HOME:-$HOME/.local/state}/angelos/help"
DIR="$BASE/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DIR/context"
ls -1dt "$BASE"/*/ 2>/dev/null | tail -n +6 | xargs -r rm -rf --
say 'Gathering the logs…' 'Собираю журналы…'
c() { local f="$DIR/context/$1"; shift; timeout 20 "$@" >"$f" 2>&1 || true; }
c system-journal.txt journalctl -b -p warning -n 300 --no-pager
c angelos-journal.txt journalctl --user -u angelos.service -b -n 300 --no-pager
c pacman-log.txt tail -n 200 /var/log/pacman.log
c games.json python3 "$HERE/game-doctor.py" scan
c hardware.txt sh -c 'uname -srm; grep -h PRETTY_NAME /etc/os-release; echo; lspci -nnk 2>/dev/null | grep -A3 -E "VGA|3D|Display"; echo;
  command -v nvidia-smi >/dev/null && nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv; echo;
  findmnt -no SOURCE,FSTYPE /; df -h / "$HOME"; free -h'
[[ -n "$CONTEXT" && -r "$CONTEXT" ]] && cp -- "$CONTEXT" "$DIR/context/extra-$(basename -- "$CONTEXT")"
printf '%s\n' "${TASK:-$(_ '(not said: ask)' '(не сказал: спроси)')}" >"$DIR/context/task.txt"

if [[ -f /etc/snapper/configs/root ]]; then
  SNAP="Before the first change to the system take a snapshot and say so: \`sudo snapper -c root create -c number --userdata important=yes -d 'angelOS helper: before <what>'\`. It is undone with \`sudo snapper -c root undochange <n>..0\` or by booting the snapshot from the boot menu."
else
  SNAP="This system has no snapshots (snapper is not set up). Before changing a file, copy it to ~/backups/<what>-<date-time>/ (a new folder each time) and say where."
fi
cat >"$DIR/AGENTS.md" <<EOF
# You are the angelOS helper

The user pressed «Позвать помощника» in angelOS (Settings → Maintenance) because something broke.
angelOS is a desktop for the niri compositor on Arch Linux / CachyOS: a Quickshell (QML) shell.

## How to talk
- Speak $(_ English Russian), in plain words, short. No jargon without a word of explanation.
- What happened is in context/task.txt. If it is empty or unclear, ask one question first.

## What is already gathered (read it before asking)
- context/system-journal.txt: this boot's warnings and errors (journalctl -b -p warning)
- context/angelos-journal.txt: the shell's log (journalctl --user -u angelos.service)
- context/pacman-log.txt: the last package transactions (a fresh update is a usual cause)
- context/games.json: the games doctor (Steam, Proton, the 32-bit drivers, Vulkan, snapshots)
- context/hardware.txt: kernel, video card and driver, disks, memory
- context/extra-*: more from the button that called you, if any

## Rules: fix it, asking
1. Find the cause first, tell the user what it is and what you want to do, then wait for "yes".
2. Ask before every change: a file edit, a package installed or removed, a service restarted.
   One change at a time; check after each one.
3. $SNAP
4. sudo: your shell can't ask the password. Give the user the command and ask them to type it
   after \`!\` in this window (or in another terminal); then read the result.
5. Leave the user's own things alone: documents, pictures, music, browser profiles, game saves,
   messengers, ~/.ssh, ~/.gnupg, keys and tokens. Never delete: move aside to a backup.
6. Don't close or restart the user's apps (Steam, the browser, Discord…) without asking.
7. angelOS's own code (~/.config/quickshell/angelos, ~/.local/bin) comes with its updates: don't edit
   it. A bug there: tell the user and offer an issue text for https://github.com/MixaDoDs/AngelOS-Dotfiles/issues
8. At the end: what you changed, and how to undo it.

## angelOS, where things are
- settings: ~/.config/angelos/settings.json (the shell writes it; change it through Settings when you can)
- restart the shell: \`angelos restart\`; its log: \`journalctl --user -u angelos.service -b\`
- niri: ~/.config/niri/config.kdl (+ cfg/*.kdl); check with \`niri validate\`
- updates of angelOS: Settings → Updates; the system: \`sudo pacman -Syu\`
- games: \`python3 ~/.config/quickshell/angelos/scripts/game-doctor.py scan | reset-prefix ID | clear-shaders ID|all | ge-proton\`
  (a prefix reset moves it aside, never deletes). A game's Proton and launch options are the user's pick in Steam.
EOF
ln -sf AGENTS.md "$DIR/CLAUDE.md"
# opencode lets the agent edit and run by itself unless told: ask for each
printf '{"$schema": "https://opencode.ai/config.json", "permission": {"edit": "ask", "bash": "ask", "webfetch": "ask"}}\n' >"$DIR/opencode.json"

PROMPT="$(_ 'Read AGENTS.md and the files in context/, then help me' 'Прочитай AGENTS.md и файлы в context/, потом помоги мне'): ${TASK:-$(_ 'ask me what happened' 'спроси меня, что случилось')}"
cd "$DIR"
say "Opening ${BIN[$AGENT]} (log in to your account if it asks)…" "Открываю ${BIN[$AGENT]} (если спросит — войди в свой аккаунт)…"
case "$AGENT" in
  claude) exec claude --permission-mode default "$PROMPT" ;;
  codex) exec codex -a on-request -s workspace-write "$PROMPT" ;;
  opencode) exec opencode --prompt "$PROMPT" ;;
esac
