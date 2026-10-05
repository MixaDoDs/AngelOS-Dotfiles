pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// What the angelOS title bars (modules/decor) need from niri's config:
//   the drag   niri animates every move-floating-window it is sent (the window-movement
//              spring), so a window moved step by step from a title bar trailed behind the
//              pointer. While a bar is dragged, ~/.config/niri/cfg/angelos-drag.kdl turns
//              that one animation off (niri reloads its config when an included file
//              changes); the drag starts moving the window once the reload has landed.
//              config.kdl includes the file last — added once, checked with
//              `niri validate`, put back as it was if niri says no.
//   the ring   niri's focus ring is drawn around the window only; the bar draws the same
//              ring around itself — width from the config (`focus-ring { width N }`, 4 by
//              default, 0 when it is off), the colours angelOS gives niri (templates/niri.kdl).
Singleton {
    id: root

    readonly property string niriDir: Config.home + "/.config/niri"
    readonly property string file: niriDir + "/cfg/angelos-drag.kdl"
    readonly property string idleText: "// angelOS: window-movement animation off while an angelOS title bar is dragged (modules/decor) — idle\n"
    readonly property string holdText: "// angelOS: an angelOS title bar is being dragged — niri moves the window without its spring\nanimations {\n    window-movement {\n        off\n    }\n}\n"

    property bool installed: false           // config.kdl includes the file
    property bool holding: false
    property bool ready: false               // the reload with the animation off has landed
    property int ringWidth: 4

    function hold(on) {
        if (!installed || on === holding)
            return;
        holding = on;
        ready = false;
        writer.setText(on ? holdText : idleText);
        if (on)
            readyGuard.restart();
    }
    Connections {
        target: Niri
        function onConfigLoaded(failed) {
            if (root.holding)
                root.ready = true;
        }
    }
    // never wait long: a slow reload just means a few animated steps
    Timer {
        id: readyGuard
        interval: 120
        onTriggered: if (root.holding)
            root.ready = true
    }

    FileView {
        id: writer
        path: root.file
        blockLoading: false
        printErrors: false
        atomicWrites: true
    }

    // ---- set up once: the file, the include, the ring width ----
    Process {
        id: setup
        running: Config.ready && GoldenGate.titlebars && !Shell.dev
        command: ["sh", "-c", `
d="$1"; f="$d/cfg/angelos-drag.kdl"; c="$d/config.kdl"
[ -f "$c" ] || { echo "noconfig"; exit 0; }
mkdir -p "$d/cfg"
printf '%s' "$2" > "$f"
if ! grep -q 'angelos-drag.kdl' "$c"; then
    cp "$c" "$c.bak-angelos-drag"
    printf '\\n// angelOS: dragging a title bar turns the window-movement animation off for the drag\\ninclude "./cfg/angelos-drag.kdl"\\n' >> "$c"
    if ! niri validate -c "$c" >/dev/null 2>&1; then
        cp "$c.bak-angelos-drag" "$c"; echo "invalid"; exit 0
    fi
fi
echo "installed"
# the focus ring: off anywhere in layout → 0, else its width (4 when not set)
b=$(cat "$d"/cfg/layout.kdl "$d"/angelos.kdl 2>/dev/null | tr '\\n' ' ' | grep -o 'focus-ring *{[^}]*}')
if printf '%s' "$b" | grep -q '[{; ]off[ ;}]'; then echo "ring 0"
else n=$(printf '%s' "$b" | grep -o 'width *[0-9]*' | grep -o '[0-9]*' | tail -n1); echo "ring \${n:-4}"; fi
`, "sh", root.niriDir, root.idleText]
        stdout: SplitParser {
            onRead: line => {
                if (line === "installed")
                    root.installed = true;
                else if (line.startsWith("ring "))
                    root.ringWidth = Math.max(0, parseInt(line.slice(5)) || 0);
            }
        }
    }
    // the shell going away mid-drag must not leave the animation off
    Component.onDestruction: if (holding)
        writer.setText(idleText)
}
