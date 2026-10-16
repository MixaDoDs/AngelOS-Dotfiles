#!/bin/sh
# angelOS: compile every QML file of the shell before a restart, without running it.
#
#   scripts/qml-check.sh [shell dir]     exit 0 = all compile, 1 = errors (printed), 2 = could not check
#
# Why: one load error anywhere in shell.qml's tree leaves the desktop without a shell, and a page
# loaded by name (Settings → Drivers) fails only when opened. qmllint in PATH is Qt 5's and the Qt 6
# one misses a doubled handler (PxKeyTravel, 16.10); 16.10 09:00 a CircleCanvas error made the
# service fail 5 times in a row and hit systemd's start limit.
#
# How: a copy of the tree in a temp dir whose shell.qml has the same imports and only
# Qt.createComponent(file, Component.PreventCreation) for each file — compiled, never created,
# so no window opens and no service starts. It runs on the real compositor (PanelWindow files
# can't even compile offscreen) under a fake HOME and its own XDG_RUNTIME_DIR, so it can't touch
# settings.json or answer the live shell's IPC.
set -u
SRC="${1:-$HOME/.config/quickshell/angelos}"
P="$HOME/.local/opt/quickshell/usr"
QS="$P/bin/quickshell"
[ -x "$QS" ] || QS="$(command -v quickshell 2>/dev/null)"
[ -n "$QS" ] && [ -x "$QS" ] || { echo "qml-check: quickshell not found" >&2; exit 2; }
RT="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
WL="${WAYLAND_DISPLAY:-wayland-1}"
[ -S "$RT/$WL" ] || { echo "qml-check: no wayland socket $RT/$WL" >&2; exit 2; }

T="$(mktemp -d "${TMPDIR:-/tmp}/qmlchk.XXXXXX")" || exit 2
trap 'rm -rf "$T"' EXIT INT TERM
mkdir -p "$T/home" "$T/rt" "$T/shell"
chmod 700 "$T/rt"
ln -s "$RT/$WL" "$T/rt/$WL"
tar -C "$SRC" --exclude=./graphify-out --exclude=./tests --exclude=./extras --exclude=./.git --exclude='*.bak*' -cf - . | tar -C "$T/shell" -xf -
cd "$T/shell" || exit 2
mv shell.qml RealShell.qml

# every QML file, through the shell's own URL (qs.* imports resolve as in the shell) and, if that
# fails, as file:// — the way the shell's Loaders load plugins and pages, whose sibling files are
# types only then. Only a file that fails both ways is an error.
find . -name '*.qml' -not -name RealShell.qml | sed 's|^\./||' | sort >"$T/files"
{
  sed -n '/^\/\/@ pragma/p' RealShell.qml
  grep -E '^import ' RealShell.qml
  # every qs module the tree has, so a file's types resolve as in the real shell
  find . -name qmldir -not -path './plugins/*' | sed 's|^\./||; s|/qmldir$||; s|/|.|g' | sort -u |
    while read -r m; do echo "import qs.$m"; done
  echo 'ShellRoot {'
  echo '    Component.onCompleted: {'
  printf '        const files = ["RealShell.qml"'
  while read -r f; do printf ', "%s"' "$f"; done <"$T/files"
  echo '];'
  cat <<'EOF'
        let bad = 0;
        for (const f of files) {
            const a = Qt.createComponent(Quickshell.shellDir + "/" + f, Component.PreventCreation);
            if (a.status !== Component.Error)
                continue;
            const b = f === "RealShell.qml" ? a : Qt.createComponent("file://" + Quickshell.shellDir + "/" + f, Component.PreventCreation);
            if (b.status !== Component.Error)
                continue;
            bad++;
            console.log("QMLCHECK FAIL " + f + "\n" + a.errorString());
        }
        console.log("QMLCHECK DONE " + files.length + " " + bad);
        Qt.quit();
    }
}
EOF
} >shell.qml.new
grep -vE '^import qs\.$' shell.qml.new | awk '!(/^import / && seen[$0]++)' >shell.qml
rm -f shell.qml.new

OUT="$T/out"
env -i PATH="$PATH" HOME="$T/home" XDG_RUNTIME_DIR="$T/rt" WAYLAND_DISPLAY="$WL" \
  QT_QPA_PLATFORM=wayland LD_LIBRARY_PATH="$P/lib" QML_IMPORT_PATH="$P/lib/qt6/qml" \
  timeout 120 "$QS" -p "$T/shell" -n >"$OUT" 2>&1 &
pid=$!
# quickshell doesn't leave on Qt.quit(): stop it once the list is through
while kill -0 "$pid" 2>/dev/null && ! grep -q 'QMLCHECK DONE' "$OUT"; do sleep 0.3; done
kill "$pid" 2>/dev/null
wait "$pid" 2>/dev/null
if ! grep -q 'QMLCHECK DONE' "$OUT"; then
  # the shell's own singletons load before the list: one of them broken = the shell won't start
  if grep -q 'Failed to load configuration' "$OUT"; then
    grep -E 'ERROR' "$OUT" | sed 's/^.*ERROR[^:]*: *//; s|/tmp/qmlchk[^/]*/shell/||g' >&2
    echo "qml-check: the shell would not load" >&2
    exit 1
  fi
  echo "qml-check: the check did not finish:" >&2; tail -20 "$OUT" >&2; exit 2
fi
# a PanelWindow file may still say "No PanelWindow backend" — not an error of the file
awk '/QMLCHECK FAIL/{p=1} /QMLCHECK DONE/{p=0} p' "$OUT" | sed 's/^.*QMLCHECK FAIL /FAIL /; s/^ *[A-Z]* *[a-z.]*: *//'
set -- $(grep -o 'QMLCHECK DONE [0-9]* [0-9]*' "$OUT")
echo "qml-check: $3 files, $4 with errors"
[ "$4" = 0 ]
