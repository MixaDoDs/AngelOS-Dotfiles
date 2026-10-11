import QtQuick
import Quickshell
import Quickshell.Io
import "."

// IPC endpoint for hooks and the MCP shim:  qs -c angelos ipc call claude <fn> …
Item {
    id: root
    property var plugin

    // hookless discovery of running sessions + plan limits, picked up on their own (Pulse's
    // scanner watches by itself; this only brings it back if it ended)
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: Pulse.scan()
    }
    // give the disk cache a moment, so a shell reload doesn't hit the API
    Timer {
        running: true
        interval: 4000
        onTriggered: Usage.refresh(false)
    }

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
}
