pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var info: ({})
    property string powerProfile: ""
    // popular keyboards / mice / microphones worth over $100 that are plugged in
    // (scripts/gear.py, data/premium-gear.json) — Settings → System, fastfetch
    property var gear: []
    property real gearThreshold: 100
    // what can be picked for an interface's inputs / headphone jacks and the rest of the desk
    property var gearCatalog: []
    // the user's own additions (kept by gear.py in ~/.config/angelos/gear.json, never published)
    readonly property var gearMine: gear.filter(d => d.mine)

    // rows: [{kind, name, usd, on?, port?}] — the whole list, as Settings → System edits it
    function saveGear(rows) {
        gear = gear.filter(d => !d.mine).concat(rows.map(r => Object.assign({
                "mine": true
            }, r)));
        gearSave.command = ["python3", Quickshell.shellDir + "/scripts/gear.py", "--save-mine", JSON.stringify(rows)];
        gearSave.running = true;
    }

    function refresh() {
        probe.running = true;
        gearProbe.running = true;
    }

    Process {
        id: gearProbe
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/gear.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.gear = r.devices || [];
                    root.gearThreshold = r.threshold || 100;
                    root.gearCatalog = r.catalog || [];
                } catch (e) {}
            }
        }
    }
    Process {
        id: gearSave
        onExited: gearProbe.running = true
    }
    Process {
        id: probe
        running: true
        command: ["sh", "-c", `
. /etc/os-release 2>/dev/null
echo "os=$PRETTY_NAME"
echo "kernel=$(uname -r)"
echo "host=$(cat /etc/hostname 2>/dev/null || uname -n)"
echo "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')"
echo "gpu=$( (nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || lspci 2>/dev/null | grep -iE 'vga|3d' | head -1 | cut -d: -f3) | head -1 | sed 's/^ *//')"
echo "mem=$(awk '/MemTotal/{printf "%.1f ГБ", $2/1048576}' /proc/meminfo)"
echo "uptime=$(uptime -p 2>/dev/null | sed 's/^up //')"
echo "niri=$(niri --version 2>/dev/null)"
echo "qs=$(qs --version 2>/dev/null | head -1)"
echo "shell=$(basename "$SHELL")"
echo "power=$(powerprofilesctl get 2>/dev/null)"
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n")) {
                    const i = l.indexOf("=");
                    if (i > 0)
                        o[l.slice(0, i)] = l.slice(i + 1);
                }
                root.info = o;
                root.powerProfile = o.power || "";
            }
        }
    }
}
