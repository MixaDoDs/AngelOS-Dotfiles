pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The eyedropper (Mod+Shift+C, Settings → Appearance): niri's own picker (`niri msg pick-color`,
// a click anywhere on any screen, Escape cancels) → "#rrggbb" in the clipboard, a notification,
// and the colour on top of `recent` (the last 12, kept in stateDir/picked-colors.json).
Singleton {
    id: root

    property var recent: []           // "#rrggbb", newest first
    property string last: ""
    readonly property bool busy: picker.running
    signal picked(string hex)

    function pick() {
        if (picker.running || Shell.setupLocked)
            return;
        picker.running = true;
    }
    function copy(hex) {
        Quickshell.execDetached(["wl-copy", "--", hex]);
    }
    function forget() {
        recent = [];
        store.write("[]");
    }
    readonly property string iconDir: Quickshell.env("XDG_RUNTIME_DIR") + "/angelos-picked-colors"
    // a pixel swatch of `hex` for the notification (12×12, like data/icons): a square with cut
    // corners, an outline that stands out from the colour, a highlight and a shade inside
    function swatch(hex) {
        const v = i => parseInt(hex.substr(1 + 2 * i, 2), 16);
        const lum = (0.299 * v(0) + 0.587 * v(1) + 0.114 * v(2)) / 255;
        const line = lum < 0.35 ? "#e8e4dc" : "#1c1820";
        const mix = (t, k) => "#" + [0, 1, 2].map(i => Math.round(v(i) + (t - v(i)) * k).toString(16).padStart(2, "0")).join("");
        const light = mix(255, 0.45), shade = mix(0, 0.3);
        const px = [];
        const r = (x, y, w, h, c, o) => px.push('<rect x="' + x + '" y="' + y + '" width="' + w + '" height="' + h + '" fill="' + c + (o ? '" fill-opacity="' + o : "") + '"/>');
        r(2, 1, 8, 1, line); r(2, 10, 8, 1, line); r(1, 2, 1, 8, line); r(10, 2, 1, 8, line);
        r(2, 2, 8, 8, hex);
        r(3, 3, 2, 1, light); r(3, 4, 1, 1, light);
        r(8, 9, 2, 1, shade); r(9, 8, 1, 1, shade);
        r(3, 11, 8, 1, "#000000", 0.3); r(11, 3, 1, 8, "#000000", 0.3);
        return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 12" width="144" height="144" shape-rendering="crispEdges">' + px.join("") + '</svg>';
    }
    // {"rgb": [r, g, b]} (0…1) from --json; the plain text has "#rrggbb" in it
    function parse(text) {
        try {
            const j = JSON.parse(text);
            if (j && j.rgb && j.rgb.length === 3)
                return "#" + j.rgb.map(c => Math.round(Math.max(0, Math.min(1, c)) * 255).toString(16).padStart(2, "0")).join("");
        } catch (e) {}
        const m = /#[0-9a-f]{6}/i.exec(text);
        return m ? m[0].toLowerCase() : "";
    }

    Process {
        id: picker
        command: ["niri", "msg", "--json", "pick-color"]
        stdout: StdioCollector {
            onStreamFinished: {
                const hex = root.parse(text);
                if (!hex)
                    return;       // Escape
                root.last = hex;
                root.recent = [hex].concat(root.recent.filter(c => c !== hex)).slice(0, 12);
                store.write(JSON.stringify(root.recent));
                root.copy(hex);
                // the icon is the colour itself (no theme has a "color-select"): a file per colour, so
                // the popup never shows the last one from a cache; written before the notification goes
                const icon = root.iconDir + "/" + hex.slice(1) + ".svg";
                Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf %s "$2" > "$3"; exec notify-send -a angelOS -i "$3" -h string:x-canonical-private-synchronous:angelos-pick-color "$4" "$5"', "sh", root.iconDir, root.swatch(hex), icon, I18n.t("Пипетка: ", "Eyedropper: ") + hex, I18n.t("скопировано в буфер обмена", "copied to the clipboard")]);
                root.picked(hex);
            }
        }
    }

    AsyncFile {
        id: store
        path: Config.stateDir + "/picked-colors.json"
        printErrors: false
        onLoaded: {
            try {
                const list = JSON.parse(text());
                if (Array.isArray(list))
                    root.recent = list.filter(c => /^#[0-9a-f]{6}$/i.test(c)).slice(0, 12);
            } catch (e) {}
        }
    }
}
