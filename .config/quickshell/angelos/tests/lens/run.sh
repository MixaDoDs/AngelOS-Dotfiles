#!/usr/bin/env bash
# Google Lens in angelOS's own window, offline: scripts/lens/page.js reads two pages made after
# the spec (handoff 2026-10-20-lens-spec: roles, heading levels, href shapes — no Google page is
# stored) in a hidden QtWebEngine view with the network off; then offscreen the window
# (modules/lenssearch) through every state services/LensSearch can be in. Google is never asked.
#
#   tests/lens/run.sh [angelOS dir]      exit 0 = all good, 77 = no quickshell / qml6
#   ANGELOS_LENS_SHOTS=dir …             a picture of each state of the window
set -uo pipefail
DIR="$(cd "${1:-"$(dirname "$0")/../.."}" && pwd)"
[[ -f "$DIR/shell.qml" ]] || { echo "no angelOS in $DIR"; exit 2; }
fail=0
T="$(mktemp -d /tmp/aos-lens.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# ── the page reader ──────────────────────────────────────────────────────────
if command -v qml6 >/dev/null 2>&1; then
  # a proxy that isn't there: nothing leaves the machine (the preview's https address included)
  env -i PATH="$PATH" HOME="$T/home" LANG=C.UTF-8 XDG_RUNTIME_DIR="$T" QT_QPA_PLATFORM=offscreen \
    QML_XHR_ALLOW_FILE_READ=1 QT_FORCE_STDERR_LOGGING=1 \
    QTWEBENGINE_CHROMIUM_FLAGS="--proxy-server=127.0.0.1:9 --proxy-bypass-list=<-loopback> --no-sandbox" \
    timeout 60 qml6 "$DIR/tests/lens/PageTest.qml" >"$T/page.log" 2>&1
  if grep -q 'module "QtWebEngine" is not installed' "$T/page.log"; then
    echo "  – Lens page reader: skipped here (no QtWebEngine)"
  elif out=$(python3 - "$T/page.log" <<'PY'
import json, re, sys
pages = {}
for line in open(sys.argv[1], errors="ignore"):
    m = re.search(r"PAGE (\{.*\})", line)
    if m:
        p = json.loads(m.group(1))
        pages[p["page"]] = p["out"]
bad = []
def check(name, ok, detail=""):
    if not ok:
        bad.append(f"{name} {detail}"[:300])
v, e = pages.get("visual"), pages.get("exact")
check("page-ran", v is not None and e is not None, "no answer from the page (QtWebEngine?)")
if v and e:
    cards = v["visual"]
    check("visual-cards", [c["title"] for c in cards] == ["Flag of Germany - Wikipedia", "Deutschland Fahne 90x150"], json.dumps([c["title"] for c in cards]))
    if len(cards) == 2:
        a, b = cards
        check("visual-goto-opaque", a["url"] == "https://www.google.com/goto?url=OPAQUE1" and a["site"] == "Wikipedia", json.dumps(a)[:200])
        check("visual-pictures", a["thumb"].startswith("data:image/png") and a["favicon"].startswith("data:image/png") and b["favicon"] == "", "")
        check("visual-shop", b["price"] == "92 €*" and b["extra"] == "Auf Lager" and b["site"] == "Shop.example" and b["url"] == "https://shop.example/flag", json.dumps(b)[:200])
    check("words-rows", v["words"] == ["Hello world", "second"], json.dumps(v["words"]))
    check("entity", v["entity"]["name"] == "Flag of Germany" and v["entity"]["description"].startswith("The image shows the national flag"), json.dumps(v["entity"]))
    check("tabs", all(k in v["tabs"] for k in ("44", "48", "50")) and "udm=48" in v["tabs"]["48"], json.dumps(v["tabs"]))
    check("translate-button", v["translate"] is True)
    check("counts", v["counts"]["cards"] == 2 and v["counts"]["goto"] == 2 and v["counts"]["ext"] == 1, json.dumps(v["counts"]))
    ex = e["exact"]
    check("exact-cards", [c["title"] for c in ex] == ["Black red gold flag", "Flag icon"], json.dumps([c["title"] for c in ex]))
    if len(ex) == 2:
        check("exact-first", ex[0]["site"] == "example.org" and ex[0]["extra"].startswith("1.280 x 1.280") and ex[0]["thumb"].startswith("data:") and ex[0]["favicon"].startswith("data:"), json.dumps(ex[0])[:200])
        check("exact-no-borrowed-picture", ex[1]["thumb"] == "" and ex[1]["extra"] == "512×512", json.dumps(ex[1])[:200])
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
  ); then
    echo "  ✓ Lens page reader: cards, pictures beside the link, prices, words in rows, the name, tabs, exact matches (no network)"
  else
    printf '  ✕ %s\n' "$out" | sed 's/\n/\n  ✕ /g'
    grep -vE '^qml: PAGE' "$T/page.log" | tail -5 | sed 's/^/      /'
    fail=1
  fi
else
  echo "  – Lens page reader: skipped here (no qml6)"
fi

# ── the window ───────────────────────────────────────────────────────────────
QS="$(command -v quickshell || true)"
LIB="${LD_LIBRARY_PATH:-}" QML="${QML_IMPORT_PATH:-}"
if [[ ! -x /usr/bin/quickshell && -x "$HOME/.local/opt/quickshell/usr/bin/quickshell" ]]; then
  QS="$HOME/.local/opt/quickshell/usr/bin/quickshell"
  LIB="$HOME/.local/opt/quickshell/usr/lib${LIB:+:$LIB}"
  QML="$HOME/.local/opt/quickshell/usr/lib/qt6/qml${QML:+:$QML}"
fi
[[ -x "$QS" ]] || { echo "quickshell not found"; ((fail)) && exit 1; exit 77; }

H="$T/home"
mkdir -p "$H/.config/angelos" "$T/rt" "$T/root" "$T/bin" && chmod 700 "$T/rt"
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
cat >"$T/root/shell.qml" <<'QML'
//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.tests.lens
ShellRoot {
    LensDriver {}
}
QML
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "appearance": {"language": "ru"}}
JSON
# no browser, no clipboard, no worker of the real kind
for t in xdg-open wl-copy qml6 notify-send; do printf '#!/bin/sh\nexit 0\n' >"$T/bin/$t"; done
chmod +x "$T/bin/"*
[[ -n "${ANGELOS_LENS_SHOTS:-}" ]] && mkdir -p "$ANGELOS_LENS_SHOTS"
log="${ANGELOS_TEST_LOG:-$T/qs.log}"
env -i PATH="$T/bin:$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  ANGELOS_TEST=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 NIRI_SOCKET="$T/no-niri" \
  ANGELOS_LENS_SHOTS="${ANGELOS_LENS_SHOTS:-}" \
  timeout 60 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

n=0 qfail=0
while read -r _ name res detail; do
  n=$((n + 1))
  if [[ "$res" == PASS ]]; then [[ -n "${ANGELOS_TEST_VERBOSE:-}" ]] && printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; qfail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the window test did not finish (exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-400)"; qfail=1; }
errs=$(grep -E 'LensWindow|LensSearch|LensDriver' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|not a function' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -8)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; qfail=1; }
((qfail)) || echo "  ✓ Lens window: $n checks (sending, consent and its resend, captcha and the pause, results, exact matches, text, nothing found, unreadable page, closed)"
((qfail)) && fail=1
exit $fail
