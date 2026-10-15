pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Quick Look (macOS's Space): a look at a file without opening it (modules/quicklook).
// Nautilus asks for it itself — Space on a file calls org.gnome.NautilusPreviewer, the name
// GNOME's sushi would hold; scripts/quicklook.py holds it while angelOS runs and passes the
// file here. Arrows go back to Nautilus, which moves its selection and asks again.
// Also: `angelos quicklook <file>`, Space on a file in the launcher's search.
Singleton {
    id: root

    property bool open: false
    property string path: ""
    property var info: null                 // scripts/quicklook.py info
    property bool loading: false
    property bool fromNautilus: false
    property bool nameOurs: false           // Nautilus's previewer name is ours (else sushi's)

    readonly property bool wanted: Config.quicklook.enabled && Quickshell.env("ANGELOS_TEST") !== "1" && (!Shell.dev || Quickshell.env("ANGELOS_QUICKLOOK") === "1")
    readonly property string script: Quickshell.shellPath("scripts/quicklook.py")

    function show(p, nautilus) {
        if (!p)
            return;
        fromNautilus = !!nautilus;
        path = p;
        info = null;
        loading = true;
        reader.command = ["python3", script, "info", p];
        reader.running = true;
        if (!open) {
            open = true;
            tell({
                "cmd": "visible",
                "v": true
            });
        }
    }
    function close() {
        if (!open)
            return;
        open = false;
        reader.running = false;
        tell({
            "cmd": "visible",
            "v": false
        });
    }
    // the arrows: Nautilus moves on and calls ShowFile again
    function step(dir) {
        if (fromNautilus)
            tell({
                "cmd": "select",
                "dir": dir
            });
    }
    function openIt() {
        Quickshell.execDetached(["xdg-open", path]);
        close();
    }
    function tell(obj) {
        if (daemon.running)
            daemon.write(JSON.stringify(obj) + "\n");
    }
    function size(n) {
        if (n === undefined || n < 0)
            return "";
        if (n < 1024)
            return n + " " + I18n.t("Б", "B");
        const u = I18n.t(["КБ", "МБ", "ГБ", "ТБ"], ["KB", "MB", "GB", "TB"]);
        let i = -1;
        do {
            n /= 1024;
            i++;
        } while (n >= 1024 && i < 3)
        return (n < 10 ? n.toFixed(1) : Math.round(n)) + " " + u[i];
    }
    function duration(s) {
        s = Math.round(s || 0);
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
        return (h ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(sec).padStart(2, "0");
    }

    Process {
        id: daemon
        running: root.wanted
        stdinEnabled: true
        command: ["python3", root.script, "serve"]
        stdout: SplitParser {
            onRead: line => {
                let ev;
                try {
                    ev = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (ev.ev === "ready")
                    root.nameOurs = true;
                else if (ev.ev === "taken")
                    root.nameOurs = false;
                else if (ev.ev === "close")
                    root.close();
                else if (ev.ev === "show") {
                    if (ev.toggle && root.open && ev.path === root.path)
                        root.close();
                    else
                        root.show(ev.path, true);
                }
            }
        }
        onExited: root.nameOurs = false
    }
    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const j = JSON.parse(text);
                    if (j.path === root.path || !j.path)
                        root.info = j;
                } catch (e) {
                    root.info = {
                        "error": "info"
                    };
                }
            }
        }
        onExited: root.loading = false
    }
}
