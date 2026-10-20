#!/usr/bin/env bash
# osu!mini's rhythm mode (plugins/osu-mini/Rhythm.qml, RhythmCore.js), offline, no player touched:
#   1. scripts/osu-beats.py's tracker on made-up drums (tests/rhythm/beats.py: even, with jitter, a
#      tempo change, rubato), its guesses through RhythmCore's beat lock — locked on the grid,
#      following the change, turning rubato and silence down; the words' notes, the verdicts, the
#      player's clock, the best of a track (node)
#   2. offscreen: Lyrics keeps the words' times of a TTML, then three rounds side by side — one on a
#      song's words, one on a beat alone, one with neither (turned down); the best is written to
#      its file, the achievements asked for (RhythmDriver.qml; MPRIS and the beat are stand-ins)
#
#   tests/rhythm/run.sh [angelOS dir]     exit 0 = all good, 77 = no node / quickshell
#   ANGELOS_RHYTHM_SHOTS=dir …            a picture of each screen
set -uo pipefail
DIR="$(cd "${1:-"$(dirname "$0")/../.."}" && pwd)"
[[ -f "$DIR/shell.qml" ]] || { echo "no angelOS in $DIR"; exit 2; }
command -v node >/dev/null || { echo "no node"; exit 77; }
fail=0
T="$(mktemp -d /tmp/aos-rhythm.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# ── the rules ────────────────────────────────────────────────────────────────
if python3 -c 'import numpy' 2>/dev/null; then
  python3 -I "$DIR/tests/rhythm/beats.py" "$DIR" >"$T/beats.json" || { echo "  ✕ beats.py failed"; fail=1; }
else
  echo "  – the tracker on made-up drums: skipped here (no numpy)"
  echo '{}' >"$T/beats.json"
fi
if out=$(node - "$DIR/plugins/osu-mini/RhythmCore.js" "$T/beats.json" 2>&1 <<'JS'
const fs = require("fs"), assert = require("assert");
const C = new Function(fs.readFileSync(process.argv[2], "utf8").replace(".pragma library", "") +
    "; return {judge, points, accuracy, voiceNotes, newClock, clockFeed, median, newBeat, beatFeed, beatHopeless, beatsBetween, record, GIVEUP};")();
const cases = JSON.parse(fs.readFileSync(process.argv[3], "utf8"));
let checks = 0;
const ok = (c, m) => { assert.ok(c, m); checks++; };

// the beat lock over the tracker's guesses; `truth(t)` → [a beat, period] of the real grid at t
function play(name, truth, after) {
    const b = C.newBeat(), errs = [];
    let lockedAt = null;
    for (const e of cases[name]) {
        C.beatFeed(b, e, e.at);
        if (b.locked && lockedAt === null) lockedAt = e.at;
        if (!b.locked || e.at < after) continue;
        // the beats a second and a bit ahead, as the notes are given
        for (const t of C.beatsBetween(b, e.at + 1000, e.at + 1250)) {
            const [s, P] = truth(t), x = (t - s) / P;
            errs.push(Math.abs(x - Math.round(x)) * P);
        }
    }
    return {b, errs, lockedAt};
}
if (cases.even) {
    for (const [name, P] of [["even", 500], ["jitter", 60000 / 128]]) {
        const r = play(name, () => [500, P], 0);
        ok(r.lockedAt !== null && r.lockedAt < 8000, name + ": locked by 8 s, " + r.lockedAt);
        ok(r.errs.length > 10 && Math.max(...r.errs) < 20, name + ": beats a second ahead within 20 ms, " + Math.max(...r.errs));
        ok(Math.abs(r.b.P - P) < 3, name + ": tempo " + 60000 / r.b.P);
    }
    // 100 → 130 BPM at 8 s: the new tempo taken, its beats right
    const ch = play("change", t => t < 8000 ? [500, 600] : [8000, 60000 / 130], 14000);
    ok(Math.abs(60000 / ch.b.P - 130) < 2, "change: 130 BPM taken, " + 60000 / ch.b.P);
    ok(ch.errs.length >= 3 && Math.max(...ch.errs) < 20, "change: new beats within 20 ms, " + Math.max(...ch.errs));
    // free time: never held long enough to play, turned down
    const ru = C.newBeat();
    let rubatoLocked = 0, rubatoDown = null;
    for (const e of cases.rubato) {
        C.beatFeed(ru, e, e.at);
        if (ru.locked) rubatoLocked++;
        if (rubatoDown === null && C.beatHopeless(ru, e.at, 0)) rubatoDown = e.at;
    }
    ok(rubatoDown !== null && rubatoDown <= 16000, "rubato: turned down, " + rubatoDown);
    ok(rubatoLocked <= 2, "rubato: hardly ever locked, " + rubatoLocked);
}
// silence: osu-beats.py sends only {idle}; nothing to hold → turned down GIVEUP after the start
const si = C.newBeat();
ok(!C.beatHopeless(si, 11000, 0) && C.beatHopeless(si, C.GIVEUP, 0) && !si.locked, "silence: turned down after GIVEUP");

// the words: a note a word when the lyrics have them, a line's start otherwise; pauses unsung
const v = C.voiceNotes([
    {t: 1, text: "Hello world", w: [1, 1.5]},
    {t: 2, text: "♪"},
    {t: 3, text: "line"},
    {t: 3.1, text: "too close"},
    {t: 4, text: "", w: [4]}
], 250);
ok(JSON.stringify(v) === "[1000,1500,3000]", "voice notes " + JSON.stringify(v));

// the verdicts
ok(C.judge(0) === "perfect" && C.judge(-45) === "perfect" && C.judge(60) === "good" && C.judge(-140) === "miss" && C.judge(200) === "", "judge windows");
ok(C.points("perfect", 0) === 300 && C.points("good", 50) === 200 && C.points("miss", 5) === 0, "points");
ok(C.accuracy({perfect: 2, good: 2, miss: 0}) === 0.75, "accuracy");

// the player's clock: settles on three alike, a browser's wobble kept, a seek starts over
const c = C.newClock();
C.clockFeed(c, 10.0, 1000);
C.clockFeed(c, 10.27, 1250);
ok(!c.settled, "clock: two samples aren't enough");
C.clockFeed(c, 10.48, 1500);
ok(c.settled && Math.abs(c.off - 9000) < 30, "clock: settled at " + c.off);
C.clockFeed(c, 40, 1750);
ok(c.jumps === 1 && !c.settled && c.off === 38250, "clock: a seek starts over");

// the best of a track
let r = C.record({}, "a\u0001b", {score: 1000, acc: 0.9, combo: 12, title: "b", artist: "a"});
ok(r.best && r.first && r.tracks["a\u0001b"].score === 1000 && r.tracks["a\u0001b"].acc === 90, "record: the first round");
r = C.record(r.tracks, "a\u0001b", {score: 900, acc: 1, combo: 5});
ok(!r.best && !r.first && r.tracks["a\u0001b"].score === 1000, "record: a lower score kept out");
r = C.record(r.tracks, "a\u0001b", {score: 1200, acc: 1, combo: 30});
ok(r.best && !r.first && r.tracks["a\u0001b"].score === 1200, "record: beaten");
console.log("checks " + checks);
JS
); then
  echo "  ✓ rhythm rules: $(sed -n 's/^checks //p' <<<"$out") checks (beat lock on even, jittered, changing drums; rubato and silence turned down; words, verdicts, clock, best)"
else
  printf '  ✕ %s\n' "$(grep -m1 -E 'AssertionError|Error' <<<"$out")"
  fail=1
fi

# ── the window ───────────────────────────────────────────────────────────────
QS="$(command -v quickshell || true)"
LIB="${LD_LIBRARY_PATH:-}" QML="${QML_IMPORT_PATH:-}"
if [[ ! -x /usr/bin/quickshell && -x "$HOME/.local/opt/quickshell/usr/bin/quickshell" ]]; then
  QS="$HOME/.local/opt/quickshell/usr/bin/quickshell"
  LIB="$HOME/.local/opt/quickshell/usr/lib${LIB:+:$LIB}"
  QML="$HOME/.local/opt/quickshell/usr/lib/qt6/qml${QML:+:$QML}"
fi
[[ -x "$QS" ]] || { echo "  – the window: skipped here (no quickshell)"; exit $fail; }

H="$T/home"
mkdir -p "$H/.config/angelos" "$T/rt" "$T/root" "$T/bin" && chmod 700 "$T/rt"
for f in "$DIR"/*; do [[ "${f##*/}" == shell.qml ]] || ln -s "$f" "$T/root/"; done
cat >"$T/root/shell.qml" <<'QML'
//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.tests.rhythm
ShellRoot {
    RhythmDriver {}
}
QML
cat >"$H/.config/angelos/settings.json" <<'JSON'
{"setup": {"complete": true}, "appearance": {"language": "ru"}}
JSON
for t in xdg-open notify-send playerctl; do printf '#!/bin/sh\nexit 0\n' >"$T/bin/$t"; done
chmod +x "$T/bin/"*
[[ -n "${ANGELOS_RHYTHM_SHOTS:-}" ]] && mkdir -p "$ANGELOS_RHYTHM_SHOTS"
log="${ANGELOS_TEST_LOG:-$T/qs.log}"
env -i PATH="$T/bin:$PATH" LANG=C.UTF-8 HOME="$H" USER="${USER:-angel}" \
  XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
  XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" XDG_RUNTIME_DIR="$T/rt" \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= LD_LIBRARY_PATH="$LIB" QML_IMPORT_PATH="$QML" \
  QML_XHR_ALLOW_FILE_READ=1 ANGELOS_TEST=1 QS_NO_RELOAD_POPUP=1 QS_DISABLE_CRASH_HANDLER=1 NIRI_SOCKET="$T/no-niri" \
  ANGELOS_RHYTHM_SHOTS="${ANGELOS_RHYTHM_SHOTS:-}" ANGELOS_RHYTHM_STATE="$T/state" \
  timeout 60 "$QS" -p "$T/root" >"$log" 2>&1
code=$?

n=0 qfail=0
while read -r _ name res detail; do
  n=$((n + 1))
  if [[ "$res" == PASS ]]; then [[ -n "${ANGELOS_TEST_VERBOSE:-}" ]] && printf '  ✓ %s %s\n' "$name" "$detail"; else printf '  ✕ %s %s\n' "$name" "$detail"; qfail=1; fi
done < <(sed -n 's/.*\(TEST [^ ]* \(PASS\|FAIL\).*\)/\1/p' "$log")
grep -q 'TEST DONE' "$log" || { echo "  ✕ the window test did not finish (exit $code): $(tail -3 "$log" | tr '\n' ' ' | cut -c1-400)"; qfail=1; }
errs=$(grep -E 'Rhythm|RhythmDriver|osu-mini|Lyrics' "$log" | grep -E 'TypeError|ReferenceError|Unable to assign|is not defined|Cannot read property|Binding loop|is not a type|Cannot assign|not a function' | sed 's/\x1b\[[0-9;]*m//g' | sort -u | head -8)
[[ -z "$errs" ]] || { echo "  ✕ QML errors:"; printf '%s\n' "$errs" | sed 's/^/      /'; qfail=1; }
((qfail)) || echo "  ✓ rhythm window: $n checks (TTML words kept, a round on the words, one on the beat, one turned down, the best written)"
((qfail)) && fail=1
exit $fail
