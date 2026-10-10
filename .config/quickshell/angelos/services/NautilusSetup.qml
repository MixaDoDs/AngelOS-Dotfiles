pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// angelOS defaults for Nautilus (scripts/nautilus-setup.py): «Open in terminal»
// and mediafix in the context menu, plus the preference defaults. Applied once
// on the first run; Settings → Default apps can re-apply or remove them.
Singleton {
    id: root

    property var status: ({})
    property string log: ""
    readonly property bool busy: worker.running
    readonly property bool installed: !!status.extensions && Object.values(status.extensions).every(v => v)
    // Nautilus reads its extensions and the GTK 4 CSS once, at start, and keeps running in the
    // background: what changed since shows after a restart (Settings says so, with the button)
    property bool needsRestart: false
    readonly property bool running: !!status.running
    // the angelOS look changed (ThemeExport rendered the GTK 4 CSS anew) while Nautilus ran
    Connections {
        target: ThemeExport
        function onRenderedChanged() {
            root._themeCheck = true;
            root.refresh();
        }
    }
    property bool _themeCheck: false

    function refresh() {
        if (!reader.running)
            reader.running = true;
    }
    function apply() {
        run(["apply"]);
    }
    function remove() {
        run(["remove"]);
    }
    function mediafix(files) {
        Quickshell.execDetached(["python3", Quickshell.shellDir + "/scripts/nautilus-setup.py", "mediafix"].concat(files || []));
    }
    function restartNautilus() {
        needsRestart = false;
        run(["restart"]);
    }
    function run(args) {
        if (worker.running)
            return;
        worker.command = ["python3", Quickshell.shellDir + "/scripts/nautilus-setup.py"].concat(args);
        worker.running = true;
    }

    // first run: bake the defaults in (never in a dev instance)
    Timer {
        running: Config.ready && !Config.system.nautilusDefaults && !Shell.dev
        interval: 8000
        onTriggered: {
            root._firstApply = true;
            root.apply();
        }
    }
    // marked done only when it went through: a first start that failed (no Nautilus or gsettings
    // yet, a D-Bus hiccup) used to mark it anyway, and the defaults never came
    property bool _firstApply: false

    Process {
        id: reader
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/nautilus-setup.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.status = JSON.parse(text);
                    if (root._themeCheck && root.status.running)
                        root.needsRestart = true;
                } catch (e) {}
                root._themeCheck = false;
            }
        }
    }
    Process {
        id: worker
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    if (root._firstApply && !r.error && !(r.errors || []).length)
                        Config.system.nautilusDefaults = true;
                    root._firstApply = false;
                    if (r.status)
                        root.status = r.status;
                    if (r.restart)
                        root.needsRestart = true;
                    root.log = r.error ? r.error : (r.errors || []).concat(r.changes || r.removed || []).join("\n") || (r.quit !== undefined ? (r.quit ? I18n.t("Nautilus закрыт — следующее окно откроется уже с изменениями", "Nautilus quit — the next window opens with the changes") : I18n.t("Nautilus не был запущен", "Nautilus was not running")) : I18n.t("уже всё на месте", "everything is in place already"));
                } catch (e) {
                    root.log = text.trim();
                }
            }
        }
    }
}
