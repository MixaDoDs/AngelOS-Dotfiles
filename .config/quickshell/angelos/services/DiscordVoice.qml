pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Who is in your Discord call, for the desktop widget «Discord» (modules/desktop/widgets/
// DiscordWidget): scripts/discord-voice.py talks to the Discord app on this machine (its local
// RPC, StreamKit's client — the first time Discord asks once to allow it) and for the little
// people of the call over the bar (modules/desktop/DiscordCrew). Runs only while one of them is on.
Singleton {
    id: root

    readonly property bool wanted: Config.ready && (Config.discord.crew || DesktopWidgets.widgets.some(w => w.type === "discord")) && Quickshell.env("ANGELOS_TEST") !== "1"
    // rpc-only: Vesktop & co. (arRPC: Rich Presence, no calls) without the opt-in DevTools bridge
    property string state: "no-discord"      // no-discord | auth | authorizing | idle | call | rpc-only
    property string channel: ""
    property var users: []                   // [{id, name, avatar, speaking, muted, deaf, me, quiet, volume}]
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
    // that person for you alone (Discord's own «mute» and volume of a user): the answer comes
    // back in `users` as quiet / volume
    function quiet(id, on) {
        if (proc.running && /^\d+$/.test(id))
            proc.write("quiet " + id + (on ? " 1\n" : " 0\n"));
    }
    function setVolume(id, percent) {
        if (proc.running && /^\d+$/.test(id))
            proc.write("volume " + id + " " + Math.round(percent) + "\n");
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

    // why Discord fell, as a notification (scripts/discord-crash-watch.py): sharing the screen
    // with sound it dies when an app's audio stream goes away (2026-10-21), and an update of
    // Discord or another app can bring that back
    Process {
        running: Config.ready && Quickshell.env("ANGELOS_TEST") !== "1" && !Shell.dev
        command: ["python3", Quickshell.shellDir + "/scripts/discord-crash-watch.py"]
        stdout: SplitParser {
            onRead: line => {
                let j;
                try {
                    j = JSON.parse(line);
                } catch (e) {
                    return;
                }
                const apps = j.apps || [];
                const title = apps.length ? I18n.t("Discord упал во время стрима со звуком", "Discord fell while sharing with sound") : I18n.t("Discord упал", "Discord fell");
                const body = apps.length ? I18n.t("Перед этим пропал звук: ", "Just before, this sound went away: ") + apps.join(", ") + I18n.t(". Discord падает, когда приложение закрывает свой звук посреди показа экрана.", ". Discord dies when an app closes its sound mid-share.") : I18n.t("Звук приложений тут ни при чём. Подробности: coredumpctl info ", "Not the apps' sound. Details: coredumpctl info ") + j.pid;
                Quickshell.execDetached(["notify-send", "-a", "angelOS", "-i", "dialog-warning", "--", title, body]);
            }
        }
    }
}
