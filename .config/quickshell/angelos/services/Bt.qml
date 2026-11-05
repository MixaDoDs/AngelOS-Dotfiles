pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.config

// Bluetooth through BlueZ (Quickshell.Bluetooth) plus a small pairing agent
// (scripts/bt-agent.py) so phones and keyboards can confirm a PIN/passkey.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: !!adapter
    readonly property bool enabled: !!adapter && adapter.enabled
    // rfkill: a soft block (another desktop's applet, `rfkill block`) we lift ourselves;
    // only a hard one (a laptop key/switch) really keeps Bluetooth off — that is `blocked`
    readonly property bool rfBlocked: !!adapter && adapter.state === BluetoothAdapterState.Blocked
    property bool hardBlocked: false
    readonly property bool blocked: rfBlocked && hardBlocked
    property bool wantOn: false
    Component.onCompleted: if (rfBlocked)
        hardCheck.running = true
    onRfBlockedChanged: {
        if (rfBlocked)
            hardCheck.running = true;
        else if (wantOn && adapter) {
            wantOn = false;
            adapter.enabled = true;
        }
    }
    readonly property bool discovering: !!adapter && adapter.discovering
    readonly property var devices: adapter && adapter.devices ? adapter.devices.values : []
    readonly property var paired: devices.filter(d => d.paired || d.bonded).sort((a, b) => (b.connected - a.connected) || String(a.name).localeCompare(String(b.name)))
    readonly property var nearby: devices.filter(d => !d.paired && !d.bonded && (d.name || d.deviceName)).sort((a, b) => String(a.name).localeCompare(String(b.name)))
    readonly property var connectedDevices: devices.filter(d => d.connected)
    // bluez installed but its service is off: offer to start it (polkit asks)
    property bool serviceInstalled: false
    property bool serviceActive: false

    property int users: 0              // pages that want discovery + the agent
    property var request: null         // pairing question from the agent: {id, kind, device, passkey}
    property string lastError: ""

    function setEnabled(on) {
        if (!adapter)
            return;
        if (on && rfBlocked && !hardBlocked) {
            wantOn = true;      // the adapter is powered once rfkill lets go (onRfBlockedChanged)
            Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]);
            return;
        }
        adapter.enabled = on;
    }
    function scan(on) {
        if (adapter && adapter.enabled)
            adapter.discovering = on;
    }
    function pair(d) {
        lastError = "";
        if (!d)
            return;
        pairingDevice = d;
        d.pair();
    }
    // trusted (auto-reconnect) only once the pairing really succeeded
    property var pairingDevice: null
    Connections {
        target: root.pairingDevice
        ignoreUnknownSignals: true
        function onPairedChanged() {
            const d = root.pairingDevice;
            if (d && d.paired) {
                d.trusted = true;
                root.pairingDevice = null;
            }
        }
        function onPairingChanged() {
            const d = root.pairingDevice;
            if (d && !d.pairing && !d.paired) {
                root.lastError = (d.name || d.address) + I18n.t(": сопряжение не удалось", ": pairing failed");
                root.pairingDevice = null;
            }
        }
    }
    function toggleConnect(d) {
        if (!d)
            return;
        if (d.connected)
            d.disconnect();
        else
            d.connect();
    }
    function forget(d) {
        if (d)
            d.forget();
    }
    function answer(ok, pin) {
        if (!request)
            return;
        agent.write(JSON.stringify({
            "id": request.id,
            "ok": ok,
            "pin": pin || ""
        }) + "\n");
        request = null;
    }
    function iconFor(d) {
        const i = String(d && d.icon || "");
        return i.includes("audio") || i.includes("headset") || i.includes("headphone") ? "music" : i.includes("phone") ? "monitor" : i.includes("keyboard") ? "keyboard" : i.includes("mouse") ? "mouse" : i.includes("joystick") || i.includes("gaming") ? "gamepad" : "bluetooth";
    }
    function startService() {
        Quickshell.execDetached(["pkexec", "systemctl", "enable", "--now", "bluetooth.service"]);
        serviceCheck.running = true;
        recheck.restart();
    }

    onUsersChanged: {
        if (users > 0)
            serviceCheck.running = true;
        else
            scan(false);
    }

    Process {
        id: serviceCheck
        command: ["sh", "-c", "[ -e /usr/lib/systemd/system/bluetooth.service ] || [ -e /lib/systemd/system/bluetooth.service ] && echo installed; systemctl is-active --quiet bluetooth.service && echo active; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.serviceInstalled = text.includes("installed");
                root.serviceActive = text.includes("active");
            }
        }
    }
    Process {
        id: hardCheck
        command: ["sh", "-c", "for d in /sys/class/rfkill/rfkill*; do [ \"$(cat \"$d/type\")\" = bluetooth ] && cat \"$d/hard\"; done; true"]
        stdout: StdioCollector {
            onStreamFinished: root.hardBlocked = text.includes("1")
        }
    }
    Timer {
        id: recheck
        interval: 3000
        onTriggered: serviceCheck.running = true
    }

    // pairing agent: only while Bluetooth settings are open and an adapter exists
    Process {
        id: agent
        running: root.users > 0 && root.enabled
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/bt-agent.py"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                let ev;
                try {
                    ev = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (ev.event === "request")
                    root.request = ev;
                else if (ev.event === "cancel")
                    root.request = null;
                else if (ev.event === "error")
                    root.lastError = ev.message || "";
            }
        }
        onExited: root.request = null
    }
}
