#!/usr/bin/env bash
# angelOS's static checks: what can be seen in the files without running the shell — every window
# guards its corner pixel (RightClickGuard), full-screen overlays let input through (or say why
# not), Quickshell.Io types come with their import, the screenshot keys, no hard-coded ".exe",
# python compiles, the lens-live shader copy. A second or two.
#
#   scripts/static-checks.sh [angelOS dir]     exit 0 = all good, 1 = something to fix (✕ lines)
#
# Run by scripts/test-ui.sh (the publish check) and by scripts/qml-check.sh (before every
# `angelos restart`): one place, so a change that breaks them shows up at the restart already.
set -uo pipefail
DIR="$(cd "${1:-"$(dirname "$0")/.."}" && pwd)"
fail=0
ok()  { printf '  ✓ %s\n' "$*"; }
bad() { printf '  ✕ %s\n' "$*"; fail=1; }

# every top-level window guards its corner pixel against Qt's right-click crash
while IFS= read -r f; do
  grep -q 'RightClickGuard' "$f" || bad "no RightClickGuard in ${f#"$DIR"/} (a right click into its corner can crash Qt)"
done < <(grep -rlE '^\s*(PanelWindow|FloatingWindow|PopupWindow)\s*\{' --include='*.qml' "$DIR" | grep -v '/tests/')
((fail)) || ok "every window has a RightClickGuard"

# Quickshell.Io's types need their import: one file without it and the whole shell does not
# load (2026-10-15: PrivacyCast's FileView); the stands below leave top-level parts of
# shell.qml out, so only this sees it
io_fail=0
while IFS= read -r f; do
  grep -q '^import Quickshell\.Io' "$f" || { bad "${f#"$DIR"/} uses Quickshell.Io types without \`import Quickshell.Io\`"; io_fail=1; }
done < <(grep -rlE '^\s*(FileView|Process|StdioCollector|SplitParser|SocketServer|IpcHandler|Socket|JsonAdapter)\s*\{' --include='*.qml' "$DIR" | grep -v -e '/tests/' -e '\.bak')
((io_fail)) || ok "Quickshell.Io types come with their import"

# the screenshot keys in the key templates: Mod+Shift+S and Print → angelos capture (the old
# region tool when no shell answers), Mod+Shift+T bound nowhere (tests/keys)
if out=$(python3 "$DIR/tests/keys/test_capture_keys.py" "$DIR" 2>&1); then ok "${out#  ✓ }"; else while IFS= read -r l; do bad "${l#  ✕ }"; done <<<"$out"; fi

# a full-screen overlay takes every click under it unless it has an input mask: effects
# (the shake cursor, B3) must let input through; the ones that are meant to take it
# say why with a "// takes input:" line
while IFS= read -r f; do
  if (( $(grep -cE '^\s*(left|right|top|bottom): true' "$f") >= 4 )) && ! grep -qE '^\s*mask:' "$f" && ! grep -q '// takes input:' "$f"; then
    bad "${f#"$DIR"/}: a full-screen overlay without an input mask takes every click (add mask: Region {…}, or say why with // takes input:)"
  fi
done < <(grep -rlE 'WlrLayer\.Overlay' --include='*.qml' "$DIR" | grep -v '/tests/')
((fail)) || ok "full-screen overlays let input through (or say why they take it)"

# window titles and captions take the ending from Settings → Appearance (I18n.exe, C3): no
# string with a hard-coded ".exe" in QML, JS or a plugin manifest ("// suffix-ok" on the line
# or the one above lets one through: the setting's own three endings)
if out=$(python3 - "$DIR" <<'PY'
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
lit = re.compile(r'"(?:[^"\\\n]|\\.)*"')
bad = []
for p in sorted(list(root.rglob("*.qml")) + list(root.rglob("*.js")) + list(root.rglob("manifest.json"))):
    # the characters' lines (story, phone, angel) are speech, not titles: an .exe there is a joke
    if "tests" in p.relative_to(root).parts or p.name.endswith(("Lore.js", "Lines.js")):
        continue
    prev = ""
    for n, line in enumerate(p.read_text(errors="ignore").splitlines(), 1):
        s = line.strip()
        if not s.startswith(("//", "*", "/*")) and "suffix-ok" not in line and "suffix-ok" not in prev:
            for m in lit.finditer(line.split(" //")[0] if p.suffix != ".json" else line):
                if re.search(r"\.exe\b", m.group(0)):
                    bad.append("%s:%d %s" % (p.relative_to(root), n, m.group(0)[:60]))
        prev = line
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
); then ok "no hard-coded .exe: titles follow the ending setting"; else bad "hard-coded .exe (use I18n.exe):"; printf '%s\n' "$out" | head -20 | sed 's/^/      /'; fi

# python helpers at least compile (the bytecode out of the tree: check.sh copies it meanwhile)
pyc="$(mktemp -d)"
if out=$(PYTHONPYCACHEPREFIX="$pyc" python3 -m py_compile "$DIR"/scripts/*.py 2>&1); then ok "scripts/*.py compile"; else bad "python: $out"; fi
rm -rf "$pyc"

# the live lens runs as its own quickshell (extras/lens-live) and may not read outside its
# folder: its copy of the lens shader must be the shell's own
if cmp -s "$DIR/shaders/lens.frag.qsb" "$DIR/extras/lens-live/lens.frag.qsb"; then ok "lens-live shader copy is current"; else bad "extras/lens-live/lens.frag.qsb differs from shaders/lens.frag.qsb (copy it after rebuilding)"; fi

exit "$fail"
