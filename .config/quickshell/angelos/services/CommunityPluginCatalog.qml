pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Lives with the shell, not the Settings page: closing Settings cannot cancel
// an install halfway through replacing a plugin. Network work is only started
// when Settings → Plugins asks for it.
Singleton {
    id: root

    property var entries: []
    property string error: ""
    property string message: ""
    property string action: ""
    readonly property bool busy: fetcher.running || installer.running
    readonly property string script: Quickshell.shellDir + "/scripts/community-plugins.py"

    function refresh() {
        if (busy)
            return;
        error = "";
        message = "";
        action = "fetch";
        fetcher.command = ["python3", script, "list"];
        fetcher.running = true;
    }
    function install(entry, oldVersion) {
        if (busy || !entry)
            return;
        error = "";
        message = "";
        action = "install";
        const updating = oldVersion !== undefined && oldVersion !== null;
        installer.command = ["python3", script, updating ? "update" : "install", entry.id, entry.version];
        if (updating)
            installer.command = installer.command.concat([String(oldVersion)]);
        installer.running = true;
    }

    Process {
        id: fetcher
        stdout: StdioCollector { id: fetchOut }
        stderr: StdioCollector { id: fetchErr }
        onExited: code => {
            root.action = "";
            if (code !== 0) {
                root.entries = [];
                root.error = fetchErr.text.trim() || "Could not load the community catalog";
                return;
            }
            try {
                const payload = JSON.parse(fetchOut.text);
                if (!Array.isArray(payload.plugins))
                    throw new Error("Invalid catalog response");
                root.entries = payload.plugins.filter(p => p && p.status === "approved");
                root.error = "";
            } catch (e) {
                root.entries = [];
                root.error = String(e);
            }
        }
    }
    Process {
        id: installer
        stdout: StdioCollector { id: installOut }
        stderr: StdioCollector { id: installErr }
        onExited: code => {
            root.action = "";
            if (code !== 0) {
                root.error = installErr.text.trim() || "Could not install the plugin";
                return;
            }
            try {
                const installed = JSON.parse(installOut.text);
                root.message = installed.id;
                Plugins.reload();
            } catch (e) {
                root.error = String(e);
            }
        }
    }
}
