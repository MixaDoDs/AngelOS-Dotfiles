pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Who is in your Discord call, for the desktop widget «Discord» (modules/desktop/widgets/
// DiscordWidget): scripts/discord-voice.py talks to the Discord app on this machine (its local
// RPC, StreamKit's client — the first time Discord asks once to allow it). Runs only while such a
// widget is on a desktop.
Singleton {
    id: root

    readonly property bool wanted: Config.ready && DesktopWidgets.widgets.some(w => w.type === "discord") && Quickshell.env("ANGELOS_TEST") !== "1"
    property string state: "no-discord"      // no-discord | auth | authorizing | idle | call
    property string channel: ""
    property var users: []                   // [{id, name, avatar, speaking, muted, deaf}]
    property string error: ""

    // the widget's button: Discord shows its «allow» window
    function authorize() {
        if (proc.running)
            proc.write("auth\n");
    }
    function forget() {
        if (proc.running)
            proc.write("forget\n");
    }

    Process {
        id: proc
        running: root.wanted
        stdinEnabled: true
        command: ["python3", Quickshell.shellDir + "/scripts/discord-voice.py"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const j = JSON.parse(line);
                    root.state = j.state || "no-discord";
                    root.channel = j.channel || "";
                    root.users = j.users || [];
                    root.error = j.error || "";
                } catch (e) {}
            }
        }
        onRunningChanged: if (!running) {
            root.state = "no-discord";
            root.users = [];
        }
    }
}
