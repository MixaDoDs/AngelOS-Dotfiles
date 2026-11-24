import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "."

// qs -c angelos ipc call celestia <fn> … : the mood and the words, from Claude and the hooks.
Item {
    id: root
    property var plugin
    Component.onCompleted: Brain.pluginRef = plugin

    Connections {
        target: Notifs
        function onArrived(info) {
            Brain.glance();
        }
    }

    // hookless discovery of running sessions + plan limits
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: Pulse.scan()
    }
    Timer {
        running: true
        interval: 4000
        onTriggered: Usage.refresh(false)
    }

    // the companion's IPC: Claude Code's hooks and the MCP shim keep calling it by this name
    IpcHandler {
        target: "claude"

        function event(name: string, payload: string): void {
            Pulse.event(name, payload);
        }
        function presence(): void {
            Pulse.readPresence();
        }
        function ask(question: string): void {
            Pulse.ask(question);
        }
        function continueSession(): void {
            Pulse.launch(["--continue"], root.plugin ? root.plugin.get("mcp", true) : true);
        }
        function launch(task: string): void {
            Pulse.launch([task], root.plugin ? root.plugin.get("mcp", true) : true);
        }
        function status(): string {
            return JSON.stringify({
                "state": Pulse.state,
                "sessions": Pulse.list,
                "presence": Pulse.presence,
                "limits": {
                    "status": Usage.status,
                    "five_left": Usage.fiveLeft,
                    "week_left": Usage.weekLeft,
                    "five_resets": Usage.five ? Usage.untilText(Usage.five.resetsAt) : ""
                }
            });
        }
        function refreshLimits(): void {
            Usage.refresh(true);
        }
    }

    IpcHandler {
        target: "celestia"

        function mood(name: string, power: real, text: string, seconds: real): void {
            Brain.setMood(name, power, text, seconds);
        }
        function say(text: string): void {
            Brain.say(text, 0);
        }
        function talk(text: string): void {
            Brain.startChat(text);
        }
        function hush(): void {
            Brain.stopChat("");
        }
        function poke(): void {
            Brain.poke();
        }
        function shock(): void {
            Brain.shock();
        }
        function pause(on: bool): void {
            Brain.paused = on;
        }
        function look(name: string): void {
            Brain.forceLook = name;
        }
        function sleep(): void {
            Brain.sleeping = true;
        }
        function status(): string {
            return JSON.stringify({ "mood": Brain.mood, "shown": Brain.shown, "line": Brain.line, "sleeping": Brain.sleeping, "viewers": Brain.viewers });
        }
    }
}
