#!/usr/bin/env bash
# scripts/author-tools.sh against a stand-in gh (E): the author's tools come only to an account
# GitHub lets into the private repository; nothing for anyone else, nothing outside owner/.
# The stand-in answers like `gh api … --jq …` would (already filtered); FAKE_GH_* steer it.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../scripts/author-tools.sh"
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
fail=0
ok()  { printf '  ✓ %s\n' "$*"; }
bad() { printf '  ✕ %s\n' "$*"; fail=1; }

mkdir -p "$W/bin" "$W/nogh"
for tool in sh dash bash mkdir mktemp dirname cp mv find wc date rm cat base64 head printf sed chmod; do
  p="$(command -v "$tool" 2>/dev/null)" && ln -sf "$p" "$W/nogh/$tool"
done
cat > "$W/bin/gh" <<'GH'
#!/usr/bin/env bash
# stand-in gh: FAKE_GH_LOGIN (empty: not logged in), FAKE_GH_ACCESS=1|0, FAKE_GH_EVIL=1 (a path out of owner/),
# FAKE_GH_DEBUG=0 (an older admin branch, without the game's debug panel owner/debug/)
[[ "$1" == api ]] || exit 1
case "$2" in
  user) [[ -n "${FAKE_GH_LOGIN:-}" ]] && echo "$FAKE_GH_LOGIN" && exit 0; echo "HTTP 401" >&2; exit 1 ;;
  repos/*/git/trees/*)
    [[ "${FAKE_GH_ACCESS:-0}" == 1 ]] || { echo "HTTP 404" >&2; exit 1; }
    echo "100755 sha-editor .config/quickshell/angelos/owner/novel-editor/nov-editor.py"
    echo "100644 sha-page .config/quickshell/angelos/owner/novel-editor/index.html"
    echo "100644 sha-list .config/quickshell/angelos/owner/publish.list"
    if [[ "${FAKE_GH_DEBUG:-1}" == 1 ]]; then
      echo "100644 sha-dbgcore .config/quickshell/angelos/owner/debug/GameDebugCore.qml"
      echo "100644 sha-dbgwin .config/quickshell/angelos/owner/debug/GameDebugWindow.qml"
    fi
    [[ "${FAKE_GH_EVIL:-0}" == 1 ]] && echo "100644 sha-evil .config/quickshell/angelos/owner/../../evil.sh"
    exit 0 ;;
  repos/*/git/blobs/*) printf 'content of %s\n' "${2##*/}" | base64 ;;
  repos/*) [[ "${FAKE_GH_ACCESS:-0}" == 1 ]] && { echo "x/y"; exit 0; }; echo "HTTP 404: Not Found" >&2; exit 1 ;;
  *) exit 1 ;;
esac
GH
chmod +x "$W/bin/gh"

run() {  # run CASE ARGS… — a fresh shell dir per case
  local c="$1"; shift
  mkdir -p "$W/$c/shell" "$W/$c/cfg"
  env ANGELOS_SHELL_DIR="$W/$c/shell" XDG_CONFIG_HOME="$W/$c/cfg" "$@"
}

echo "» author tools (stand-in gh)"
out=$(run nogh env PATH="$W/nogh" sh "$SCRIPT" fetch 2>&1); rc=$?
[[ $rc == 2 && ! -e "$W/nogh/shell/owner" ]] && ok "no gh: nothing fetched ($rc)" || bad "no gh: rc $rc, $out"
out=$(run nolog env PATH="$W/bin:$PATH" FAKE_GH_LOGIN= sh "$SCRIPT" fetch 2>&1); rc=$?
[[ $rc == 2 && ! -e "$W/nolog/shell/owner" ]] && ok "no login: nothing fetched" || bad "no login: rc $rc, $out"
out=$(run noacc env PATH="$W/bin:$PATH" FAKE_GH_LOGIN=someone FAKE_GH_ACCESS=0 sh "$SCRIPT" fetch 2>&1); rc=$?
[[ $rc == 3 && ! -e "$W/noacc/shell/owner" && ! -e "$W/noacc/cfg/angelos/owner" ]] && ok "no access (404): nothing fetched, no owner/debug, no marker" || bad "no access: rc $rc, $out"
st=$(run noacc env PATH="$W/bin:$PATH" FAKE_GH_LOGIN=someone FAKE_GH_ACCESS=0 sh "$SCRIPT" status)
[[ "$st" == "absent no-access someone" ]] && ok "status without access: $st" || bad "status: $st"

E=(env PATH="$W/bin:$PATH" FAKE_GH_LOGIN=MixaDoDs FAKE_GH_ACCESS=1)
out=$(run acc "${E[@]}" sh "$SCRIPT" fetch 2>&1); rc=$?
f="$W/acc/shell/owner/novel-editor/nov-editor.py"
if [[ $rc == 0 && -x "$f" && -f "$W/acc/shell/owner/publish.list" && "$(cat "$f")" == "content of sha-editor" &&
      "$(cat "$W/acc/shell/owner/debug/GameDebugCore.qml")" == "content of sha-dbgcore" ]] &&
   grep -q '^admin=https://github.com/' "$W/acc/cfg/angelos/owner"; then
  ok "access: owner/ fetched with the debug panel (modes kept), marker written"
else bad "access: rc $rc, $out"; fi
st=$(run acc "${E[@]}" sh "$SCRIPT" status)
[[ "$st" == "here access MixaDoDs" ]] && ok "status with access: $st" || bad "status: $st"
echo "the author's newer copy" > "$f"
out=$(run acc "${E[@]}" sh "$SCRIPT" fetch 2>&1)
[[ "$(cat "$f")" == "the author's newer copy" && "$out" == *"новых файлов 0 из 5"* ]] && ok "again: nothing overwritten" || bad "again: $out"
out=$(run acc "${E[@]}" sh "$SCRIPT" fetch --force 2>&1)
bak=$(find "$W/acc/shell" -maxdepth 1 -name 'owner.bak.*' | head -1)
[[ -n "$bak" && "$(cat "$bak/novel-editor/nov-editor.py")" == "the author's newer copy" && "$(cat "$f")" == "content of sha-editor" ]] &&
  ok "--force: the old folder kept aside, then replaced" || bad "--force: $out"
# owner/ from before the debug panel moved there: status says so, a fetch adds only owner/debug/
out=$(run old "${E[@]}" FAKE_GH_DEBUG=0 sh "$SCRIPT" fetch 2>&1)
st=$(run old "${E[@]}" sh "$SCRIPT" status)
[[ ! -e "$W/old/shell/owner/debug" && "$st" == "partial access MixaDoDs" ]] && ok "an older owner/: status $st" || bad "older owner/: $st, $out"
echo "the author's newer copy" > "$W/old/shell/owner/publish.list"
out=$(run old "${E[@]}" sh "$SCRIPT" fetch 2>&1)
st=$(run old "${E[@]}" sh "$SCRIPT" status)
[[ -f "$W/old/shell/owner/debug/GameDebugCore.qml" && -f "$W/old/shell/owner/debug/GameDebugWindow.qml" && "$out" == *"новых файлов 2 из 5"* &&
   "$(cat "$W/old/shell/owner/publish.list")" == "the author's newer copy" && "$st" == "here access MixaDoDs" ]] &&
  ok "fetch into the older owner/: owner/debug/ added, the rest untouched, status $st" || bad "debug into older owner/: $st, $out"
out=$(run evil "${E[@]}" FAKE_GH_EVIL=1 sh "$SCRIPT" fetch 2>&1)
[[ ! -e "$W/evil/evil.sh" && ! -e "$W/evil/shell/evil.sh" && -f "$W/evil/shell/owner/publish.list" ]] && ok "a path out of owner/ is skipped" || bad "evil path: $out"

((fail)) && { echo "» author tools: FAILED"; exit 1; }
echo "» author tools passed"
