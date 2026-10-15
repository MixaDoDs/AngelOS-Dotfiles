pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The devices' driver (Settings → Devices → Device driver): Hall-effect keyboards and mice
// set up from the shell. scripts/devices.py talks to the hardware and this service to it in
// JSON lines; nothing here ever blocks on a device.
//
// The helper runs only while somebody looks: a page takes the service with hold() and gives
// it back with release(). With nobody holding it there is no process, no claimed USB
// interface and no timer here.
//
// A device is drawn from its description (data/devices/…/*.json, ~/.config/angelos/devices):
// what it can do, its keys, its limits. A write goes through the helper, which backs the
// device up before its first write and reads every write back.
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
    // (ANGELOS_DEVICES_FAKE = wave | idle | press:3,17)
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
    // key travel, mm by the key's matrix number: a plain array changed in place, read by the
    // views on their own frames (no binding wakes per packet); `moving` says there is news
    property var depth: []
    property bool moving: false
    property int lines: 0           // travel lines since the device was opened (the page's counter)
    property bool streaming: false

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
        depth = [];
        lines = 0;
        currentId = id;
        loading = true;
        progress = 0;
        streaming = false;
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
        streaming = false;
        moving = false;
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
    function setRt(keys, values) {
        if (keys.length)
            ask({
                "cmd": "set",
                "what": "rt",
                "keys": keys,
                "values": values
            });
    }
    function setMode(mode, values) {
        ask({
            "cmd": "set",
            "what": "mode",
            "mode": mode,
            "values": values
        });
    }
    function setMouse(name, value) {
        ask({
            "cmd": "set",
            "what": "mouse",
            "name": name,
            "value": value
        });
    }
    function pair(a, b, rule, kind) {
        ask({
            "cmd": "pair",
            "a": a,
            "b": b,
            "rule": rule || "last",
            "kind": kind || "socd"
        });
    }
    function unpair(m) {
        ask({
            "cmd": "unpair",
            "m": m
        });
    }
    function restore() {
        ask({
            "cmd": "restore"
        });
    }
    // the layer of the current mode whose keys are shown and assigned: 0 the base, 1..3 Fn
    function setLayer(layer) {
        if (state && state.layer !== layer)
            ask({
                "cmd": "layer",
                "layer": layer
            });
    }
    // action: [type, code0, code1] (an item of state.catalog), "factory" or "off"
    function setKeys(keys, action) {
        if (keys.length)
            ask({
                "cmd": "keys",
                "keys": keys,
                "action": action
            });
    }
    function modTap(m, tap, hold, delay) {
        ask({
            "cmd": "modtap",
            "m": m,
            "tap": tap,
            "hold": hold,
            "delay": delay
        });
    }
    function toggleKey(m, action) {
        ask({
            "cmd": "toggle",
            "m": m,
            "action": action
        });
    }
    function setLight(mode, zone, values) {
        ask({
            "cmd": "light",
            "mode": mode,
            "zone": zone,
            "values": values
        });
    }
    function profile(what, arg) {
        // saving and deleting a profile only read the keyboard: a read-only one too
        if (what !== "load" && state) {
            failed = null;
            working = true;
            say({
                "cmd": "profile",
                "do": what,
                "name": what === "save" ? arg : "",
                "file": what === "save" ? "" : arg
            });
            return;
        }
        ask({
            "cmd": "profile",
            "do": what,
            "name": what === "save" ? arg : "",
            "file": what === "save" ? "" : arg
        });
    }

    // travel is streamed only while a picture of it is on the screen: a view takes it with
    // watch() and gives it back with unwatch()
    property int watchers: 0
    function watch() {
        watchers++;
    }
    function unwatch() {
        watchers = Math.max(0, watchers - 1);
    }
    readonly property bool wantStream: watchers > 0 && !!state
    onWantStreamChanged: {
        if (streaming === wantStream)
            return;
        streaming = wantStream;
        say({
            "cmd": "stream",
            "on": streaming
        });
        if (!streaming)
            moving = false;
    }
    // the first connected device opens by itself; one that was unplugged and came back, too
    function autoOpen() {
        if (!wanted || loading || state || lent)
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
        streaming = false;
        moving = false;
        scanned = false;
        working = false;
        depth = [];
    }

    // ---- access: the USB bridge (extras/usb-bridge) ----
    // A keyboard whose service interface has no hidraw node is reached through a small system
    // service that hands out that one interface and filters what goes to it; installing it
    // needs the admin password, once. What it opens and what stays closed: docs/devices.md.
    property string grantLog: ""
    readonly property bool granting: grantTool.running
    function grant() {
        if (grantTool.running || testing)
            return;
        grantLog = "";
        grantTool.running = true;
    }
    Process {
        id: grantTool
        command: ["pkexec", "sh", Quickshell.shellDir + "/extras/usb-bridge/install.sh"]
        stderr: StdioCollector {
            onStreamFinished: root.grantLog = text.trim().split("\n").slice(-1)[0] || ""
        }
        onExited: code => {
            if (code === 0) {
                root.grantLog = "";
                root.error = null;
            }
            regrant.restart();
        }
    }
    Timer {
        id: regrant                 // udev and systemd need a moment
        interval: 1500
        onTriggered: root.rescan()
    }

    // a mouse asleep behind its dongle: asked again every few seconds while somebody looks
    Timer {
        running: root.wanted && !!root.error && root.error.code === "asleep" && !root.loading && !root.lent
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
    Timer {
        id: still                   // no travel line for this long: the keys are at rest
        interval: 250
        onTriggered: root.moving = false
    }

    function take(line) {
        // travel lines come by the hundred a second: the short way first
        if (line.charCodeAt(6) === 100 && line.startsWith("{\"t\":\"d\"")) {
            let k;
            try {
                k = JSON.parse(line).k;
            } catch (e) {
                return;
            }
            const d = root.depth;
            for (let i = 0; i + 1 < k.length; i += 2)
                d[k[i]] = k[i + 1];
            root.lines++;
            if (!root.moving)
                root.moving = true;
            still.restart();
            return;
        }
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
            // a device that got its access (the rule was installed) or was plugged in
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
            if (ev.what === "light" && root.paintLeft > 0 && --root.paintLeft === 0)
                root.paintDone();
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
                root.streaming = false;
                root.moving = false;
                root.depth = [];
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
    function heldByKernel(id) {
        const d = devices.find(x => x.id === id);
        return !!d && d.access === "busy" && d.driver === "usbhid";
    }
    function errorText(e) {
        if (!e)
            return "";
        switch (e.code) {
        case "denied":
            return I18n.t("Система не даёт открыть служебный канал устройства.", "The system won't let the device's service channel be opened.");
        case "busy":
            if (root.heldByKernel(e.id))
                return I18n.t("Служебный канал клавиатуры занял драйвер ядра usbhid (так бывает после загрузки: он берёт его раньше, чем срабатывает правило angelOS). Нажми «Освободить» — понадобится пароль, один раз; глубина нажатия появится сразу.", "The kernel's usbhid driver took the keyboard's service channel (it happens at boot: it takes it before angelOS's rule runs). Press \"Free it\": a password, once; the key travel shows at once.");
            return I18n.t("Служебный интерфейс занят: его держит драйвер ядра или другая программа (например, `angelos devices` в терминале). Оболочка его не отнимает.", "The service interface is taken: a kernel driver or another program holds it (`angelos devices` in a terminal, say). The shell does not take it away.");
        case "gone":
            return I18n.t("Устройство отключено.", "The device is not connected.");
        case "deaf":
            return I18n.t("Клавиатура принимает команды, но ничего не отвечает: её служебный канал завис (ошибка шины −71). Вынь и вставь её кабель — страница подхватит клавиатуру сама. Канал виснет, если его долго никто не читает; мост angelOS читает его всё время, так что это бывает только когда мост не стоит или старый («Разрешить» обновит его).", "The keyboard takes commands and answers nothing: its service channel is stuck (bus error −71). Unplug and plug its cable: the page picks the keyboard up by itself. The channel sticks when nobody reads it for a while; angelOS's bridge reads it all the time, so this happens only when the bridge is missing or old (\"Allow\" updates it).");
        case "asleep":
            return I18n.t("Мышь спит: за неё отвечает один донгл. Пошевели её — настройки появятся сами.", "The mouse is asleep: its dongle alone answers. Move it and the settings show by themselves.");
        case "timeout":
            return I18n.t("Устройство не отвечает.", "The device does not answer.");
        }
        return I18n.t(e.ru || "Ошибка обмена с устройством.", e.en || "An I/O error talking to the device.");
    }

    signal pageAsk(var ask)

    // ---- the keyboard's lights in the system's colour (Config.peripherals.keyboardAccent) ----
    // A new wallpaper gives a new accent: the helper is taken for a moment, the keyboard opened,
    // its lights painted, and let go. An effect with colours of its own (noColor in the
    // description) is switched to the first one that shows a colour.
    property string paintColor: ""
    property int paintLeft: 0
    property bool painting: false
    function paintAccent() {
        if (!Config.peripherals.keyboardAccent || testing)
            return;
        paintColor = ledColor(Theme.accent);
        if (!painting) {
            painting = true;
            hold();
            paintGiveUp.restart();
        }
        paintNow();
    }
    // The screen's accent for LEDs: its saturation back (a dark theme mixes white into the
    // accent, and white on RGB LEDs shows bluish) and sRGB made linear (LEDs are linear).
    function ledColor(c) {
        const v = Qt.hsva(Math.max(0, c.hsvHue), Math.min(1, c.hsvSaturation * 1.6), 1, 1);
        const ch = x => ("0" + Math.round(Math.pow(x, 2.2) * 255).toString(16)).slice(-2);
        return "#" + ch(v.r) + ch(v.g) + ch(v.b);
    }
    function paintNow() {
        // (from `state` itself: in onStateChanged the canWrite binding is not updated yet)
        if (!paintColor || !state || state.readonly !== "" || state.kind !== "keyboard")
            return;
        const fx = current && current.capabilities ? current.capabilities.lighting || {} : {};
        const mode = state.mode;
        let n = 0;
        for (const zone of ["main", "side"]) {
            const list = fx[zone] || [];
            const now = state.modes[mode] ? state.modes[mode].light[zone] : null;
            if (!now || !list.length)
                continue;
            const values = {
                "color": paintColor,
                "rainbow": false
            };
            const own = list.find(e => e.id === now.effect);
            const plain = list.find(e => !e.noColor);
            if (own && own.noColor && plain)
                values.effect = plain.id;
            say({
                "cmd": "light",
                "mode": mode,
                "zone": zone,
                "values": values
            });
            n++;
        }
        paintColor = "";
        paintLeft += n;
        if (!paintLeft)
            paintDone();
    }
    function paintDone() {
        paintGiveUp.stop();
        if (painting) {
            painting = false;
            release();
        }
    }
    Connections {
        target: Theme
        function onAccentChanged() {
            root.paintAccent();
        }
    }
    onStateChanged: if (paintColor)
        paintNow()
    Timer {
        id: paintGiveUp             // the keyboard not there, or not answering: let go
        interval: 15000
        onTriggered: {
            root.paintColor = "";
            root.paintDone();
        }
    }

    // the device let go for a while: `angelos devices info` and the like need it to themselves
    // while a page here holds it (`angelos devices lend SECONDS`; the CLI asks by itself)
    property bool lent: false
    function lend(seconds) {
        lent = true;
        lendTimer.interval = Math.max(1, Math.min(600, seconds || 20)) * 1000;
        lendTimer.restart();
        if (state || loading)
            close();
    }
    Timer {
        id: lendTimer
        onTriggered: {
            root.lent = false;
            root.error = null;
            root.autoOpen();
        }
    }

    // ---- IPC: `angelos devices status` (the rest of `angelos devices …` is scripts/devices.py) ----
    function ipc(line) {
        const words = String(line || "status").trim().split(/\s+/);
        const cmd = words[0];
        if (cmd === "lend") {
            lend(parseInt(words[1]) || 20);
            return "lent for " + lendTimer.interval / 1000 + " s";
        }
        if (cmd === "back") {
            lendTimer.stop();
            lent = false;
            error = null;
            autoOpen();
            return "back";
        }
        // changes through the page's own open device (the page must be open):
        //   rt 29,31 actuation=0.5 trigger=rapid | mode 1 tickRate=2 | pair 29 31 [last|neutral|a|b] [socd|rs]
        //   unpair 29 | restore | failed
        const pairsOf = from => {
            const o = {};
            for (const w of words.slice(from)) {
                const [k, v] = w.split("=");
                if (v !== undefined)
                    o[k] = v === "true" ? true : v === "false" ? false : isNaN(Number(v)) ? v : Number(v);
            }
            return o;
        };
        if (["rt", "mode", "pair", "unpair", "restore", "mouse", "layer", "keys"].includes(cmd)) {
            if (!canWrite)
                return state ? "read-only: " + state.readonly : "the device is not open (open Settings → Devices → Device driver)";
            if (cmd === "rt")
                setRt(String(words[1] || "").split(",").map(Number).filter(n => !isNaN(n)), pairsOf(2));
            else if (cmd === "mode")
                setMode(parseInt(words[1]), pairsOf(2));
            else if (cmd === "pair")
                pair(parseInt(words[1]), parseInt(words[2]), words[3], words[4]);
            else if (cmd === "unpair")
                unpair(parseInt(words[1]));
            else if (cmd === "layer")
                setLayer(parseInt(words[1]) || 0);
            else if (cmd === "keys")        // keys 29,31 16,1,6 | keys 29 factory | keys 29 off
                setKeys(String(words[1] || "").split(",").map(Number).filter(n => !isNaN(n)), ["factory", "off"].includes(words[2]) ? words[2] : String(words[2] || "").split(",").map(Number));
            else if (cmd === "mouse") {
                // mouse pollingRate 4000 | mouse motionSync false | mouse dpiStages 400,800,1600
                const raw = words.slice(2).join(" ");
                const v = raw === "true" ? true : raw === "false" ? false : raw.includes(",") ? raw.split(",").map(Number) : Number(raw);
                setMouse(words[1], v);
            }
            else
                restore();
            return "asked";
        }
        // the page's own state, for scripts and the stands: `tab light`, `select 29,31`
        if (cmd === "tab" || cmd === "select") {
            pageAsk({
                "what": cmd,
                "value": cmd === "tab" ? String(words[1] || "") : String(words[1] || "").split(",").filter(w => w !== "").map(Number)
            });
            return "asked";
        }
        if (cmd === "failed")
            return failed ? JSON.stringify(failed) : "";
        if (cmd === "key")
            return state ? JSON.stringify(state.keys[String(parseInt(words[1]))] || null) : "";
        if (cmd === "state")
            return state ? JSON.stringify(Object.assign({}, state, {
                "keys": undefined,
                "actions": undefined
            })) : "";
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
        if (cmd === "pairs")
            return state ? JSON.stringify(state.pairs) : "";
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
                "upload": state ? state.upload : false,
                "backup": state ? state.backup : "",
                "working": working,
                "lent": lent,
                "streaming": streaming,
                "lines": lines,
                "error": error ? error.code : ""
            });
        return "angelos devices [list | info | dump | sniff | check FILE | status]";
    }
}
