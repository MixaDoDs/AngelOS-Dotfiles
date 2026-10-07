pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Recovery: the game's progress and every setting on the user's own GitHub (a private repo,
// angelos-save) or in a file (scripts/recovery.py). With gh logged in it saves once a day by
// itself (Config.recovery.auto); the setup wizard's GitHub step offers to restore a save it
// finds, and so does Settings → Account → Recovery. gh keeps the login, angelOS no token.
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/recovery.py"
    // status (recovery.py status): gh there, who, the repo there, its last save
    property bool gh: false
    property string login: ""
    property bool exists: false
    property string last: ""
    property bool checked: false
    // a job: "" | push | pull | export | import; how the last one ended
    property string busy: ""
    property string message: ""
    property bool failed: false

    function refresh() {
        if (!probe.running)
            probe.running = true;
    }
    function push() {
        _run("push", ["push"]);
    }
    function pull() {
        _run("pull", ["pull", "--restart"]);
    }
    function exportTo(file) {
        _run("export", ["export", file]);
    }
    function importFrom(file) {
        _run("import", ["import", file, "--restart"]);
    }
    function _run(kind, args) {
        if (job.running)
            return;
        busy = kind;
        message = "";
        failed = false;
        job.command = ["python3", script].concat(args);
        job.running = true;
    }

    // a file to export into / import from (the desktop's own file chooser)
    readonly property string exportDir: Config.home + "/Documents"
    function pickImport() {
        if (!picker.running)
            picker.running = true;
    }
    function exportNow() {
        exportTo(exportDir + "/angelos-" + Qt.formatDateTime(new Date(), "yyyy-MM-dd-HHmm") + ".angelos.tar.gz");
    }

    Process {
        id: probe
        command: ["python3", root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text);
                    root.gh = !!s.login;
                    root.login = s.login || "";
                    root.exists = !!s.exists;
                    root.last = s.last || "";
                } catch (e) {
                    root.gh = false;
                }
                root.checked = true;
            }
        }
    }
    Process {
        id: job
        stdout: SplitParser {
            onRead: line => root.message = line.replace(/^» /, "")
        }
        stderr: SplitParser {
            onRead: line => {
                if (line.trim())
                    root.message = line.replace(/^✕ /, "");
            }
        }
        onExited: code => {
            root.failed = code !== 0;
            if (code === 0 && root.busy === "push")
                Config.recovery.lastPush = new Date().toISOString();
            root.busy = "";
            root.refresh();
        }
    }
    Process {
        id: picker
        command: ["sh", "-c", 'python3 "$1" "$2" "$3" "*.tar.gz" "*.angelos"', "sh", Quickshell.shellDir + "/scripts/pick-file.py", I18n.t("angelOS — восстановить из файла", "angelOS — restore from a file"), I18n.t("Сохранения angelOS", "angelOS saves")]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim();
                if (f)
                    root.importFrom(f);
            }
        }
    }

    // once a day by itself, with gh logged in (never in a test or a dev run)
    Timer {
        interval: 10 * 60 * 1000
        running: Config.ready && Config.recovery.auto && !Shell.dev && Quickshell.env("ANGELOS_TEST") !== "1"
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            const last = Date.parse(Config.recovery.lastPush || "") || 0;
            if (Date.now() - last > 23 * 3600 * 1000 && !job.running) {
                if (!root.checked)
                    root.refresh();
                else if (root.gh)
                    root.push();
            }
        }
    }
    Component.onCompleted: if (!Shell.dev && Quickshell.env("ANGELOS_TEST") !== "1")
        refresh()
}
