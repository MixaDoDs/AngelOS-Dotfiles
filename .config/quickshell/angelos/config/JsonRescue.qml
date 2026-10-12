import QtQuick
import Quickshell
import Quickshell.Io

// A JSON store that is written in place (settings.json, save.json: an atomic write waits for
// fdatasync on the main thread, #52) can be cut short by a crash, a power cut or a full disk.
// A file that no longer parsed was read as "everything at its default" and written back a
// moment later: every setting gone and the first-run wizard again, for no reason the user
// could see. This keeps a last good copy beside the file (<file>.last-good, refreshed after
// the shell's own writes) and, when the file doesn't parse, puts the broken one aside
// (<file>.broken-<time>, the last three) and brings the copy back before anything is written.
//   valid(text)   does the store parse (a JSON object)?
//   keepNow()     the file is good right now: copy it (a start, after a load)
//   keepLater()   it was just written: copy it within five minutes (a file that has no copy
//                 yet — a first start — in a few seconds)
//   rescue()      it doesn't parse: aside with it, the copy back → rescued(restored)
Scope {
    id: root

    required property string path
    // "" · "restored" (the last good copy is back) · "lost" (there was none: defaults again)
    property string outcome: ""
    readonly property bool busy: rescuer.running
    property bool kept: false
    signal rescued(bool restored)

    function valid(text) {
        try {
            const o = JSON.parse(text);
            return o !== null && typeof o === "object" && !Array.isArray(o);
        } catch (e) {
            return false;
        }
    }
    function keepNow() {
        if (busy)
            return;
        kept = true;
        keeper.running = true;
    }
    function keepLater() {
        if (later.running)
            return;
        later.interval = kept ? 300000 : 5000;
        later.start();
    }
    function rescue() {
        later.stop();
        rescuer.running = true;
    }

    Timer {
        id: later
        onTriggered: root.keepNow()
    }
    // the copy is checked before it replaces the last one: the shell may be writing the file
    // again while cp reads it
    Process {
        id: keeper
        command: ["sh", "-c", 'f="$1"; [ -s "$f" ] || exit 0; cp -f -- "$f" "$f.keep" && python3 -c \'import json, sys\nsys.exit(0 if isinstance(json.load(open(sys.argv[1])), dict) else 1)\' "$f.keep" 2>/dev/null && mv -f -- "$f.keep" "$f.last-good" || rm -f -- "$f.keep"', "sh", root.path]
    }
    Process {
        id: rescuer
        command: ["sh", "-c", 'f="$1"; [ -e "$f" ] && cp -f -- "$f" "$f.broken-$(date +%Y%m%d-%H%M%S)"; ls -1t -- "$f".broken-* 2>/dev/null | tail -n +4 | while IFS= read -r old; do rm -f -- "$old"; done; if [ -s "$f.last-good" ] && python3 -c \'import json, sys\nsys.exit(0 if isinstance(json.load(open(sys.argv[1])), dict) else 1)\' "$f.last-good" 2>/dev/null && cp -f -- "$f.last-good" "$f.restore" && mv -f -- "$f.restore" "$f"; then echo restored; else rm -f -- "$f.restore"; echo lost; fi', "sh", root.path]
        stdout: StdioCollector {
            id: said
        }
        onExited: {
            const restored = said.text.trim() === "restored";
            root.outcome = restored ? "restored" : "lost";
            console.warn(root.path + " did not parse: " + (restored ? "the last good copy is back" : "no good copy, starting from the defaults") + " (the broken file is kept as " + root.path + ".broken-…)");
            root.rescued(restored);
        }
    }
}
