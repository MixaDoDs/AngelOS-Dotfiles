pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The devices' driver (Settings → Devices → Device driver): mice set up from the shell.
// scripts/devices.py talks to the hardware and this service to it in JSON lines; nothing
// here ever blocks on a device.
//
// The helper runs only while somebody looks: a page takes the service with hold() and gives
// it back with release(). With nobody holding it there is no process, no open device and no
// timer here.
//
// A device is drawn from its description (data/devices/…/*.json, ~/.config/angelos/devices):
// what it can do, its limits. A write goes through the helper, which backs the device up
// before its first write and reads every write back.
Singleton {
    id: root

    // ---- who looks ----
    property int holders: 0
    function hold() {
        holders++;
    }
    function release() {
        holders = Math.max(0, holders - 1);
    }
    // the UI self-tests ask no real device; a stand's and a test's devices are emulators
    // (ANGELOS_DEVICES_FAKE = idle | asleep)
    readonly property bool testing: Quickshell.env("ANGELOS_TEST") === "1"
    readonly property string fake: Quickshell.env("ANGELOS_DEVICES_FAKE") || ""
    readonly property bool wanted: holders > 0 && (!testing || fake !== "")

    // ---- what the helper told ----
    property var devices: []        // the connected ones a description knows
    property var known: []          // every description: the honest list of what is supported how
    property var broken: []         // description files with problems: [{file, origin, problems}]
    property bool scanned: false
    property string currentId: ""
    readonly property var current: devices.find(d => d.id === currentId) || null
    property var state: null        // the open device's settings, as read
    property var error: null        // {id, code, ru, en, detail}
    property bool loading: false
    property real progress: 0

    function say(obj) {
        if (helper.running)
            helper.write(JSON.stringify(obj) + "\n");
    }
    function rescan() {
        say({
            "cmd": "scan"
        });
    }
    function open(id) {
        if (!wanted)
            return;
        error = null;
        state = null;
        currentId = id;
        loading = true;
        progress = 0;
        say({
            "cmd": "open",
            "id": id
        });
    }
    function close() {
        say({
            "cmd": "close"
        });
        state = null;
        loading = false;
    }
    // ---- changing settings ----
    // Every change is one line to the helper; it writes, reads back and answers with the new
    // state ("done") or with why not ("failed": shown on the page, the device stays open).
    // A device opened for reading only (st.readonly) takes none of these.
    property bool working: false        // a change is on its way
    property var failed: null           // {what, code, ru, en, detail} of the last change that was not made
    property string backingUp: ""       // "backup" while the first snapshot is being taken
    readonly property bool canWrite: !!state && state.readonly === ""
    function ask(obj) {
        if (!canWrite)
            return;
        failed = null;
        working = true;
        say(obj);
    }
    function setMouse(name, value) {
        ask({
            "cmd": "set",
            "what": "mouse",
            "name": name,
            "value": value
        });
    }
    function restore() {
        ask({
            "cmd": "restore"
        });
    }

    // the first connected device opens by itself; one that was unplugged and came back, too
    function autoOpen() {
        if (!wanted || loading || state)
            return;
        const pickId = devices.find(d => d.id === currentId) ? currentId : devices.length ? devices[0].id : "";
        if (pickId === "")
            return;
        const d = devices.find(x => x.id === pickId);
        currentId = pickId;
        if (d.access === "ok")
            open(pickId);
        else
            error = {
                "id": pickId,
                "code": d.access
            };
    }

    onWantedChanged: {
        if (wanted) {
            crashes = 0;
            helper.running = true;
        } else {
            helper.running = false;
            reset();
        }
    }
    function reset() {
        devices = [];
        state = null;
        error = null;
        loading = false;
        scanned = false;
        working = false;
    }

    // a mouse asleep behind its dongle: asked again every few seconds while somebody looks
    Timer {
        running: root.wanted && !!root.error && root.error.code === "asleep" && !root.loading
        interval: 3000
        repeat: true
        onTriggered: {
            const id = root.currentId;
            if (root.devices.find(d => d.id === id))
                root.open(id);
        }
    }

    property int crashes: 0
    Process {
        id: helper
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/devices.py", "serve"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.take(line)
        }
        onExited: code => {
            root.reset();
            // it fell while somebody looks: back in a moment, a few times
            if (root.wanted && root.crashes < 3) {
                root.crashes++;
                again.restart();
            }
        }
    }
    Timer {
        id: again
        interval: 1500
        onTriggered: if (root.wanted)
            helper.running = true
    }

    function take(line) {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }
        switch (ev.t) {
        case "devices":
            root.devices = ev.devices || [];
            root.known = ev.known || [];
            root.broken = ev.broken || [];
            root.scanned = true;
            // a device that got its access or was plugged in
            if (!root.state && !root.loading) {
                root.error = null;
                root.autoOpen();
            }
            break;
        case "progress":
            if (ev.id === root.currentId) {
                root.progress = ev.of > 0 ? ev.n / ev.of : 0;
                root.backingUp = ev.what === "backup" && ev.n < ev.of ? "backup" : "";
            }
            break;
        case "done":
        case "failed":
            root.working = false;
            if (ev.t === "failed")
                root.failed = ev;
            break;
        case "state":
            if (ev.id !== root.currentId)
                break;
            root.state = ev;
            root.loading = false;
            root.backingUp = "";
            root.error = null;
            break;
        case "error":
            root.error = ev;
            root.loading = false;
            root.working = false;
            root.state = null;
            break;
        case "gone":
            if (ev.id === root.currentId) {
                root.state = null;
                root.loading = false;
                // back by itself once it is there again (a replug, a new polling rate, a
                // suspend): the device list may not change at all in between
                reopen.restart();
            }
            break;
        }
    }
    Timer {
        id: reopen
        interval: 1500
        onTriggered: {
            if (root.wanted && !root.state && !root.loading)
                root.rescan();
        }
    }

    // ---- words ----
    function supportLabel(s) {
        return s === "verified" ? I18n.t("проверено на железе", "checked on hardware") : s === "readonly" ? I18n.t("только чтение", "read-only") : I18n.t("по описанию, не проверено", "by the description, not checked");
    }
    function errorText(e) {
        if (!e)
            return "";
        switch (e.code) {
        case "denied":
            return I18n.t("Система не даёт открыть служебный канал устройства.", "The system won't let the device's service channel be opened.");
        case "gone":
            return I18n.t("Устройство отключено.", "The device is not connected.");
        case "asleep":
            return I18n.t("Мышь спит: за неё отвечает один донгл. Пошевели её — настройки появятся сами.", "The mouse is asleep: its dongle alone answers. Move it and the settings show by themselves.");
        case "timeout":
            return I18n.t("Устройство не отвечает.", "The device does not answer.");
        }
        return I18n.t(e.ru || "Ошибка обмена с устройством.", e.en || "An I/O error talking to the device.");
    }

    // ---- IPC: `angelos devices status` (the rest of `angelos devices …` is scripts/devices.py) ----
    function ipc(line) {
        const words = String(line || "status").trim().split(/\s+/);
        const cmd = words[0];
        // changes through the page's own open device (the page must be open):
        //   mouse pollingRate 4000 | mouse motionSync false | mouse dpiStages 400,800,1600 | restore
        if (cmd === "mouse" || cmd === "restore") {
            if (!canWrite)
                return state ? "read-only: " + state.readonly : "the device is not open (open Settings → Devices → Device driver)";
            if (cmd === "mouse") {
                const raw = words.slice(2).join(" ");
                const v = raw === "true" ? true : raw === "false" ? false : raw.includes(",") ? raw.split(",").map(Number) : Number(raw);
                setMouse(words[1], v);
            } else
                restore();
            return "asked";
        }
        if (cmd === "failed")
            return failed ? JSON.stringify(failed) : "";
        if (cmd === "state")
            return state ? JSON.stringify(state) : "";
        if (cmd === "open") {
            if (!wanted)
                return "the page is not open";
            close();
            const id = words[1] || currentId || (devices.length ? devices[0].id : "");
            if (id === "")
                return "no device";
            open(id);
            return "opening";
        }
        if (cmd === "status")
            return JSON.stringify({
                "holders": holders,
                "running": helper.running,
                "devices": devices.map(d => ({
                            "id": d.id,
                            "access": d.access
                        })),
                "current": currentId,
                "open": !!state,
                "readonly": state ? state.readonly : "",
                "firmware": state ? state.firmware.version : "",
                "backup": state ? state.backup : "",
                "working": working,
                "error": error ? error.code : ""
            });
        return "angelos devices [list | info | check FILE | status]";
    }
}
