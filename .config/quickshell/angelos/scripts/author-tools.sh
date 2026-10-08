#!/bin/sh
# angelOS author's tools (E): the chapter editor and the owner's Dotfiles tools live in the
# shell's owner/ folder, which is never published. They come from the author's private
# repository — only to a GitHub account that can see it. GitHub decides: the repository is
# private, `gh api` gets a 404 for anyone else, so nothing here can be edited into access.
# angelOS keeps no token: gh keeps its own login (`gh auth login`, its usual permissions).
#
#   author-tools.sh status    one line: "here|partial|absent access|no-access|no-login|no-gh <login>"
#                             (partial: owner/ is there but not all of it — the game's debug
#                             panel owner/debug/ came later; `fetch` adds what is missing)
#   author-tools.sh fetch     download owner/ into the shell (only files not there yet;
#                             --force: a copy of the old folder first, then all of it)
#   author-tools.sh login     gh auth login (in this terminal), then fetch
#
# Tests: ANGELOS_AUTHOR_REPO / ANGELOS_AUTHOR_BRANCH / ANGELOS_SHELL_DIR / a fake gh in PATH.
set -u
REPO="${ANGELOS_AUTHOR_REPO:-MixaDoDs/AngelOS-Dotfiles-Admin}"
BRANCH="${ANGELOS_AUTHOR_BRANCH:-admin}"
PUBLIC="https://github.com/MixaDoDs/AngelOS-Dotfiles"
PREFIX=".config/quickshell/angelos/owner/"
SHELL_DIR="${ANGELOS_SHELL_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/angelos}"
OWNER="$SHELL_DIR/owner"
MARKER="${XDG_CONFIG_HOME:-$HOME/.config}/angelos/owner"

login() { gh api user --jq .login 2>/dev/null; }

# access: GitHub answers about the private repository for the account logged in here
access() {
  command -v gh >/dev/null 2>&1 || { echo no-gh; return; }
  who=$(login)
  [ -n "$who" ] || { echo no-login; return; }
  if gh api "repos/$REPO" --jq .full_name >/dev/null 2>&1; then echo "access $who"; else echo "no-access $who"; fi
}

status() {
  here=absent
  if [ -f "$OWNER/novel-editor/nov-editor.py" ]; then
    here=here
    [ -f "$OWNER/debug/GameDebugCore.qml" ] || here=partial
  fi
  echo "$here $(access)"
}

fetch() {
  force=0
  [ "${1:-}" = --force ] && force=1
  a=$(access)
  case "$a" in
    access\ *) ;;
    no-gh) echo "gh не установлен — инструменты автора не нужны для angelOS, пропускаю" >&2; return 2 ;;
    no-login) echo "gh: вход не выполнен — нечего проверять, пропускаю (angelos author login)" >&2; return 2 ;;
    *) echo "у аккаунта ${a#no-access } нет доступа к инструментам автора — для angelOS это ничего не меняет" >&2; return 3 ;;
  esac
  tmp=$(mktemp -d) || return 1
  trap 'rm -rf "$tmp"' EXIT
  # the files under owner/ in the private branch: "<mode> <sha> <path>"
  if ! gh api "repos/$REPO/git/trees/$BRANCH?recursive=1" \
       --jq ".tree[] | select(.type == \"blob\" and (.path | startswith(\"$PREFIX\"))) | \"\(.mode) \(.sha) \(.path)\"" > "$tmp/list" 2>"$tmp/err"; then
    echo "не удалось прочитать $REPO: $(head -c 200 "$tmp/err")" >&2
    return 1
  fi
  [ -s "$tmp/list" ] || { echo "в $REPO ($BRANCH) нет $PREFIX" >&2; return 1; }
  n=0
  while read -r mode sha path; do
    rel=${path#"$PREFIX"}
    case "$rel" in ''|/*|*../*) continue ;; esac      # only inside owner/
    mkdir -p "$tmp/owner/$(dirname "$rel")"
    gh api "repos/$REPO/git/blobs/$sha" --jq .content | base64 -d > "$tmp/owner/$rel" || { echo "не скачался $rel" >&2; return 1; }
    [ "$mode" = 100755 ] && chmod +x "$tmp/owner/$rel"
    n=$((n + 1))
  done < "$tmp/list"
  if [ -d "$OWNER" ] && [ "$force" = 1 ]; then
    # never into an old copy: a new folder each time
    keep="$SHELL_DIR/owner.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$OWNER" "$keep" && echo "старая папка: $keep"
  fi
  mkdir -p "$OWNER"
  (cd "$tmp/owner" && find . -type f) > "$tmp/files"
  added=0
  while read -r f; do
    [ -e "$OWNER/$f" ] && continue                     # the author's own, newer copy wins
    mkdir -p "$OWNER/$(dirname "$f")" && cp -p "$tmp/owner/$f" "$OWNER/$f" && added=$((added + 1))
  done < "$tmp/files"
  # the marker owner features need (services/Owner): which repos; admin rights are still
  # GitHub's answer (scripts/owner-check.sh), the marker alone opens nothing
  if [ ! -f "$MARKER" ]; then
    mkdir -p "$(dirname "$MARKER")"
    printf 'remote=%s\nadmin=https://github.com/%s\n' "$PUBLIC" "$REPO" > "$MARKER"
  fi
  echo "инструменты автора: $REPO → $OWNER — новых файлов $added из $n (что уже было, не тронуто)"
}

case "${1:-status}" in
  status) status ;;
  fetch) shift; fetch "$@" ;;
  login)
    command -v gh >/dev/null 2>&1 || { echo "нужен gh (пакет github-cli)" >&2; exit 2; }
    [ -n "$(login)" ] || gh auth login --hostname github.com --git-protocol https --web || exit 1
    fetch ;;
  *) sed -n 2,14p "$0"; exit 1 ;;
esac
