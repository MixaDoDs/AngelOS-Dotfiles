pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Is the Quickshell under angelOS new enough (scripts/qs-version.sh, the installer asks the
// same)? Older than 0.3.2 runs, but without its crash fixes: one notification per version
// found, and Settings → System → This computer says it next to the version.
Singleton {
    id: root

    property string state: ""                // ok | old | too-old | missing; "" = not asked yet
    property string found: ""
    property string want: ""
    readonly property bool outdated: state === "old" || state === "too-old"
    readonly property string advice: !outdated ? "" : I18n.t("Quickshell %1 старее %2: обнови пакет quickshell — в %2 исправлены падения блокировки, перезагрузки и звука", "Quickshell %1 is older than %2: update the quickshell package — %2 fixes crashes of the lock, reloads and sound").arg(found).arg(want)

    function check() {
        probe.running = true;
    }

    Process {
        id: probe
        command: ["sh", Quickshell.shellDir + "/scripts/qs-version.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/);
                root.found = p[1] && p[1] !== "-" ? p[1] : "";
                root.want = p[2] || "";
                root.state = p[0] || "";
                root.warnOnce();
            }
        }
    }

    function warnOnce() {
        if (!outdated || !Config.ready || Quickshell.env("ANGELOS_TEST") === "1" || Config.system.qsWarned === found)
            return;
        Config.system.qsWarned = found;
        Quickshell.execDetached(["notify-send", "-a", "angelOS", "-i", "dialog-warning", I18n.t("Устаревший Quickshell", "Quickshell is outdated"), advice]);
    }
    // settings.json may come after the answer
    Connections {
        target: Config
        function onReadyChanged() {
            root.warnOnce();
        }
    }
    Component.onCompleted: check()
}
