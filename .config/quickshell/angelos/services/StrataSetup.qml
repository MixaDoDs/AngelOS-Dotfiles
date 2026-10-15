pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// angelOS for Strata, the file manager angelOS installs (scripts/strata-setup.py): «Open in
// terminal», mediafix and «Send nearby» in its menu, and the angelOS theme (heaven, hell, on the
// fly: scripts/strata-theme.py). Applied once, when Strata is there; Settings → Default apps
// → Files · Strata re-applies or removes them, and turns its Open/Save dialogs on for every app.
Singleton {
    id: root

    property var status: ({})
    property string log: ""
    readonly property bool busy: worker.running
    readonly property bool installed: !!status.installed
    readonly property bool applied: !!status.actions && Object.values(status.actions).every(v => v) && !!status.themeSelected
    // Strata reads settings.toml at start and writes its own back: the theme is picked only while
    // no Strata runs — until then this waits (a look every 20 s, only while it waits)
    property bool themePending: false

    function refresh() {
        if (!reader.running)
            reader.running = true;
    }
    function apply() {
        run(["apply"]);
    }
    function remove() {
        themePending = false;
        run(["remove"]);
    }
    function portal(on) {
        run(["portal", on ? "on" : "off"]);
    }
    function run(args) {
        if (worker.running)
            return;
        worker.command = ["python3", Quickshell.shellDir + "/scripts/strata-setup.py"].concat(args);
        worker.running = true;
    }

    // the Start menu's «Files» follows Strata once it is the default (install.sh and the wizard set
    // it from outside the shell: a system from before still says "nautilus")
    onStatusChanged: if (status.default && status.bin && (Config.system.fileManager === "nautilus" || Config.system.fileManager === ""))
        Config.system.fileManager = status.bin
    // a new default picked in Settings (the «Files» combo): what Strata's group shows follows
    Connections {
        target: DefaultApps
        function onDataChanged() {
            root.refresh();
        }
    }

    // first run with Strata there (never in a dev instance): bake the defaults in
    Timer {
        running: Config.ready && !Config.system.strataDefaults && root.installed && !Shell.dev
        interval: 9000
        onTriggered: {
            root._firstApply = true;
            root.apply();
        }
    }
    property bool _firstApply: false

    Timer {
        running: root.themePending && !worker.running
        interval: 20000
        repeat: true
        onTriggered: if (!reader.running)
            reader.running = true
    }

    Process {
        id: reader
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/strata-setup.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.status = JSON.parse(text);
                    if (root.themePending && !root.status.running)
                        root.run(["theme"]);
                } catch (e) {}
            }
        }
    }
    Process {
        id: worker
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    if (root._firstApply && !(r.errors || []).length)
                        Config.system.strataDefaults = true;
                    root._firstApply = false;
                    if (r.status)
                        root.status = r.status;
                    if (r.themePending !== undefined)
                        root.themePending = !!r.themePending;
                    const lines = (r.errors || []).concat(r.done || []);
                    if (r.log)
                        lines.push(r.log);
                    if (r.error)
                        lines.push(r.error);
                    if (root.themePending)
                        lines.push(I18n.t("Тема angelOS включится, когда Strata закроется (он помнит свою тему, пока открыт).", "The angelOS theme switches on once Strata closes (it keeps its own theme while it is open)."));
                    root.log = lines.join("\n") || I18n.t("уже всё на месте", "everything is in place already");
                } catch (e) {
                    root.log = text.trim();
                }
            }
        }
    }
}
