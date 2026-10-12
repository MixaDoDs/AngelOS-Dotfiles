pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config

// The charge of the things on the desk: the mouse, the keyboard, the headphones, a gamepad
// (the bar's ampoules, modules/bar/parts/PeripheralsButton; Settings → Devices → Device charge).
// Two sources, merged: UPower (Bluetooth, Logitech's HID++, gamepads; by its own signals) and
// scripts/peripherals.py, which asks what UPower doesn't know (a 2.4 GHz mouse behind its
// dongle, USB headsets through headsetcontrol) every few minutes. A device that stops
// answering stays with its last charge: as it was for the first minutes (a mouse falls asleep
// whenever it lies still, and its charge is still true), then dimmed, then gone. Nothing is
// shown, asked or told where no device reports a charge.
Singleton {
    id: root

    readonly property var kinds: ["mouse", "keyboard", "headset", "gamepad", "phone", "pen", "speaker", "touchpad", "other"]
    readonly property var kindIcons: ({
            "mouse": "mouse",
            "keyboard": "keyboard",
            "headset": "headphones",
            "gamepad": "gamepad",
            "phone": "phone",
            "pen": "pen",
            "speaker": "speaker",
            "touchpad": "touchpad",
            "other": "plug"
        })
    function kindIcon(kind) {
        return kindIcons[kind] || "plug";
    }
    function kindLabel(kind) {
        switch (kind) {
        case "mouse":
            return I18n.t("Мышь", "Mouse");
        case "keyboard":
            return I18n.t("Клавиатура", "Keyboard");
        case "headset":
            return I18n.t("Наушники", "Headphones");
        case "gamepad":
            return I18n.t("Геймпад", "Gamepad");
        case "phone":
            return I18n.t("Телефон", "Phone");
        case "pen":
            return I18n.t("Перо", "Pen");
        case "speaker":
            return I18n.t("Колонка", "Speaker");
        case "touchpad":
            return I18n.t("Тачпад", "Touchpad");
        }
        return I18n.t("Устройство", "Device");
    }
    function slug(s) {
        return String(s || "").toLowerCase().replace(/[^a-z0-9а-яё]+/g, "-").replace(/^-+|-+$/g, "") || "device";
    }

    // ---- UPower: everything with a battery that is not the machine's own ----
    function upKind(t) {
        switch (t) {
        case UPowerDeviceType.Mouse:
            return "mouse";
        case UPowerDeviceType.Keyboard:
            return "keyboard";
        case UPowerDeviceType.Headset:
        case UPowerDeviceType.Headphones:
        case UPowerDeviceType.OtherAudio:
            return "headset";
        case UPowerDeviceType.Speakers:
            return "speaker";
        case UPowerDeviceType.GamingInput:
            return "gamepad";
        case UPowerDeviceType.Phone:
            return "phone";
        case UPowerDeviceType.Tablet:
        case UPowerDeviceType.Pen:
            return "pen";
        case UPowerDeviceType.Touchpad:
            return "touchpad";
        case UPowerDeviceType.LinePower:
        case UPowerDeviceType.Ups:
        case UPowerDeviceType.Monitor:
        case UPowerDeviceType.Computer:
            return "";
        }
        return "other";
    }
    readonly property var fromUPower: {
        if (!Config.ready || !Config.peripherals.upower)
            return [];
        const out = [];
        const taken = {};
        for (const d of UPower.devices.values) {
            if (!d || !d.ready || d.powerSupply || d.isLaptopBattery)
                continue;
            const kind = upKind(d.type);
            const percent = Math.max(0, Math.min(100, Math.round(d.percentage * 100)));
            // 0 % is what UPower says of a device whose charge it doesn't know
            if (!kind || percent <= 0)
                continue;
            const name = String(d.model || "").trim() || kindLabel(kind);
            let id = "upower:" + slug(name);
            // two of one model (a pair of gamepads): the second is "…#2"
            taken[id] = (taken[id] || 0) + 1;
            if (taken[id] > 1)
                id += "#" + taken[id];
            const charging = d.state === UPowerDeviceState.Charging || d.state === UPowerDeviceState.PendingCharge;
            out.push({
                "id": id,
                "name": name,
                "kind": kind,
                "percent": percent,
                "charging": charging,
                "full": d.state === UPowerDeviceState.FullyCharged,
                "source": "upower"
            });
        }
        return out;
    }

    // ---- scripts/peripherals.py: asked every few minutes, and at once on "poll" ----
    // the UI self-tests ask no real device (ANGELOS_TEST); a stand's and a test's devices are a
    // JSON file (ANGELOS_PERIPHERALS_FAKE)
    readonly property bool testing: Quickshell.env("ANGELOS_TEST") === "1"
    readonly property string fake: Quickshell.env("ANGELOS_PERIPHERALS_FAKE") || ""
    readonly property bool asking: Config.ready && (fake !== "" || (!testing && (Config.peripherals.vendor || Config.peripherals.headset) && (Config.peripherals.show || Config.peripherals.alerts)))
    readonly property var askCommand: ["python3", "-u", Quickshell.shellDir + "/scripts/peripherals.py", "--watch", String(Math.max(1, Config.peripherals.pollMinutes) * 60)].concat(Config.peripherals.vendor ? [] : ["--no-vendor"], Config.peripherals.headset ? [] : ["--no-headset"])
    property var probed: []
    property var tools: ({})
    // the makers' dongles this user may not open: the udev rule of extras/hid-access is missing
    // (the dotfiles' install.sh installs it; grant() does with the admin password)
    property int denied: 0
    property string grantLog: ""
    property real polledAt: 0
    onAskingChanged: restart.restart()
    Component.onCompleted: restart.restart()
    onAskCommandChanged: restart.restart()
    Timer {
        id: restart
        interval: 250
        onTriggered: {
            probe.running = false;
            if (root.asking) {
                probe.command = root.askCommand;
                probe.running = true;
            } else {
                root.probed = [];
            }
        }
    }
    Process {
        id: probe
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                let ev;
                try {
                    ev = JSON.parse(line);
                } catch (e) {
                    return;
                }
                // the same answer again (an asked-for poll): nothing to redraw
                const devices = Array.isArray(ev.devices) ? ev.devices : [];
                if (JSON.stringify(devices) !== JSON.stringify(root.probed))
                    root.probed = devices;
                root.tools = ev.tools || {};
                root.denied = ev.denied || 0;
                root.polledAt = Date.now();
            }
        }
    }
    // the udev rule that lets the user at the seat ask the dongles (extras/hid-access: only
    // the maker's interface without input, only through logind's ACL), then a poll
    function grant() {
        if (grantTool.running || testing)
            return;
        grantLog = "";
        grantTool.running = true;
    }
    Process {
        id: grantTool
        command: ["pkexec", "sh", Quickshell.shellDir + "/extras/hid-access/install.sh"]
        stderr: StdioCollector {
            onStreamFinished: root.grantLog = text.trim().split("\n").slice(-1)[0] || ""
        }
        onExited: code => {
            if (code === 0)
                root.grantLog = "";
            regrant.restart();
        }
    }
    Timer {
        id: regrant                 // udev needs a moment to hand the nodes over
        interval: 1500
        onTriggered: root.refresh()
    }
    // ask now (the panel's and the page's button); UPower's devices are always fresh
    function refresh() {
        if (probe.running)
            probe.write("poll\n");
        else
            restart.restart();
    }

    // ---- the two sources as one list; a device of both (a headset the kernel knows too) once ----
    readonly property var live: {
        const out = fromUPower.slice();
        const names = out.map(d => d.name.toLowerCase());
        for (const d of probed) {
            if (!d || !d.id || names.includes(String(d.name).toLowerCase()))
                continue;
            out.push(d);
        }
        return out;
    }
    // id -> the device as it was last seen, and when: what a sleeping one is drawn from
    property var memory: ({})
    property real now: Date.now()
    onLiveChanged: {
        const m = Object.assign({}, memory);
        const t = Date.now();
        for (const d of live)
            m[d.id] = Object.assign({}, d, {
                "at": t
            });
        memory = m;
        now = t;
        _phases = phases(t);
        silent = _phases !== "";
        check();
    }
    // silent for this long, a device still looks as it did: its charge has not gone anywhere
    readonly property int graceMs: 600000
    // some device known is not answering: the clock below runs for it
    property bool silent: false
    // where each silent one is at time t: "q" still as it was, "z" dimmed, "x" out of its time
    property string _phases: ""
    function phases(t) {
        const keep = Math.max(0, Config.peripherals.keepMinutes) * 60000;
        const liveIds = live.map(d => d.id);
        return Object.keys(memory).filter(id => !liveIds.includes(id)).map(id => id + (t - memory[id].at > keep ? ":x" : t - memory[id].at > graceMs ? ":z" : ":q")).join("|");
    }
    Timer {
        // the silent ones dim, then run out of their time (Config.peripherals.keepMinutes);
        // the list is put together anew only when one of them moves on, and the ones out of
        // their time are forgotten
        running: root.silent
        interval: 30000
        repeat: true
        onTriggered: {
            const t = Date.now();
            const p = root.phases(t);
            if (p === root._phases)
                return;
            root._phases = p;
            root.now = t;
            const gone = p.split("|").filter(x => x.endsWith(":x")).map(x => x.slice(0, -2));
            if (gone.length) {
                const m = Object.assign({}, root.memory);
                for (const id of gone)
                    delete m[id];
                root.memory = m;
                root._phases = root.phases(t);
            }
            root.silent = root._phases !== "";
        }
    }

    // every device known: the live ones, then the sleeping ones still kept
    //   {id, name (yours, else its own), ownName, kind, percent, charging, full, asleep,
    //    hidden, level: "ok" | "low" | "veryLow", source}
    readonly property var all: {
        if (!Config.ready)
            return [];
        const c = Config.peripherals;
        const keep = Math.max(0, c.keepMinutes) * 60000;
        const liveIds = live.map(d => d.id);
        const list = live.map(d => Object.assign({}, d, {
                "asleep": false
            }));
        for (const id in memory) {
            const d = memory[id];
            if (liveIds.includes(id) || now - d.at > keep)
                continue;
            const asleep = now - d.at > graceMs;
            list.push(Object.assign({}, d, {
                "asleep": asleep,
                "charging": !asleep && d.charging,
                "full": !asleep && d.full
            }));
        }
        const names = c.names || {}, kindOf = c.kinds || {}, hidden = c.hidden || [], seq = c.sequence || [];
        const out = list.map(d => {
            const kind = kinds.includes(kindOf[d.id]) ? kindOf[d.id] : kinds.includes(d.kind) ? d.kind : "other";
            return Object.assign({}, d, {
                "ownName": d.name,
                "name": String(names[d.id] || "").trim() || d.name,
                "kind": kind,
                "hidden": hidden.includes(d.id),
                "level": d.charging ? "ok" : d.percent <= c.veryLowAt ? "veryLow" : d.percent <= c.lowAt ? "low" : "ok"
            });
        });
        const at = d => {
            const i = seq.indexOf(d.id);
            return i < 0 ? 1000 + kinds.indexOf(d.kind) : i;
        };
        out.sort((a, b) => c.sort === "lowest" ? (a.percent - b.percent) || a.name.localeCompare(b.name) : (at(a) - at(b)) || a.name.localeCompare(b.name));
        return out;
    }
    readonly property var shown: all.filter(d => !d.hidden)
    // the bar's: the ones below the "only when low" line (a charging one too: you watch it
    // fill), at most `max`
    readonly property var onBar: {
        if (!Config.ready)
            return [];
        const c = Config.peripherals;
        const fit = shown.filter(d => c.showBelow >= 100 || d.percent <= c.showBelow || d.charging);
        const max = Math.max(1, c.max);
        // more than fit: the sleeping ones give their places to the ones that answer
        if (fit.length <= max)
            return fit;
        const awake = fit.filter(d => !d.asleep).slice(0, max);
        const rest = fit.filter(d => d.asleep).slice(0, max - awake.length);
        return fit.filter(d => awake.includes(d) || rest.includes(d));
    }
    readonly property bool any: shown.length > 0

    function statusText(d) {
        if (!d)
            return "";
        if (d.asleep)
            return I18n.t("не отвечает · столько было", "not answering · this is what it had");
        if (d.full)
            return I18n.t("заряжено", "charged");
        if (d.charging)
            return I18n.t("заряжается", "charging");
        return d.level === "veryLow" ? I18n.t("почти пусто", "almost empty") : d.level === "low" ? I18n.t("пора заряжать", "time to charge") : I18n.t("от батареи", "on battery");
    }

    // ---- settings of one device (Settings → Device charge → the list) ----
    function setHidden(id, hide) {
        const h = (Config.peripherals.hidden || []).filter(x => x !== id);
        if (hide)
            h.push(id);
        Config.peripherals.hidden = h;
    }
    function setName(id, name) {
        const m = Object.assign({}, Config.peripherals.names || {});
        if (String(name || "").trim())
            m[id] = String(name).trim();
        else
            delete m[id];
        Config.peripherals.names = m;
    }
    function setKind(id, kind) {
        const m = Object.assign({}, Config.peripherals.kinds || {});
        m[id] = kind;
        Config.peripherals.kinds = m;
    }
    // one place up or down in your order (and the order becomes yours)
    function move(id, by) {
        const ids = all.map(d => d.id);
        const i = ids.indexOf(id), j = i + by;
        if (i < 0 || j < 0 || j >= ids.length)
            return;
        ids.splice(j, 0, ids.splice(i, 1)[0]);
        Config.peripherals.sequence = ids;
        Config.peripherals.sort = "manual";
    }
    function forget(id) {
        const m = Object.assign({}, memory);
        delete m[id];
        memory = m;
        _phases = phases(Date.now());
        silent = _phases !== "";
    }

    // ---- the liquid's colours, from empty (the bottom) to full (Config.peripherals.palette) ----
    readonly property var palettes: ["realm", "traffic", "ice", "mono", "custom"]
    readonly property var stops: stopsOf(Config.ready ? Config.peripherals.palette : "realm", Theme.realm)
    function stopsOf(palette, realm) {
        const hell = realm === "hell";
        switch (palette) {
        case "traffic":
            return ["#e5484d", "#f5c542", "#3fb68b"];
        case "ice":
            return ["#3a4fd8", "#39c5e8", "#e8fbff"];
        case "mono":
            return [hell ? Theme.hellAccent : Theme.accent];
        case "custom":
            {
                const own = (Config.peripherals.colors || []).filter(c => /^#[0-9a-f]{6}$/i.test(String(c)));
                if (own.length)
                    return own;
            }
        }
        return hell ? [Theme.hellBlood, Theme.hellEmber, Theme.hellFlame, Theme.hellGold] : [Theme.danger, Theme.accent3, Theme.accent2, Theme.accent];
    }

    // ---- running low: a notification a step, once per discharge of a device ----
    signal lowReached(var device, string level)     // the angel listens (services/Angel)
    property var _told: ({})                         // id -> "ok" | "low" | "veryLow"
    property var _fullTold: ({})
    readonly property string iconDir: Quickshell.shellDir + "/data/icons/"
    function check() {
        if (!Config.ready)
            return;
        const c = Config.peripherals;
        const rank = {
            "ok": 0,
            "low": 1,
            "veryLow": 2
        };
        for (const d of all) {
            if (d.asleep || d.hidden)
                continue;
            if (d.charging || d.percent > c.lowAt + 3)
                _told[d.id] = "ok";
            else if (rank[d.level] > rank[_told[d.id] || "ok"]) {
                _told[d.id] = d.level;
                if (c.alerts && !Shell.locked)
                    Quickshell.execDetached(["notify-send", "-a", "angelOS", "-u", d.level === "low" ? "normal" : "critical", "-h", "string:x-angelos-sound:" + (d.level === "low" ? "notify" : "error"), "-i", iconDir + (d.level === "low" ? "battery-low.svg" : "battery-empty.svg"), d.name + ": " + d.percent + " %", d.level === "low" ? I18n.t("Пора на зарядку ♡", "Time to charge ♡") : I18n.t("Почти пусто. Заряди, пока не отключилось.", "Almost empty. Charge it before it goes off.")]);
                root.lowReached(d, d.level);
            }
            if (!d.full)
                _fullTold[d.id] = false;
            else if (!_fullTold[d.id]) {
                _fullTold[d.id] = true;
                if (c.fullAlert && !Shell.locked)
                    Quickshell.execDetached(["notify-send", "-a", "angelOS", "-h", "string:x-angelos-sound:notify", d.name + ": 100 %", I18n.t("Заряжено, можно снимать с провода.", "Charged, it can come off the cable.")]);
            }
        }
    }

    // three devices to look at where there are none (the Settings page's preview)
    function demo(percent) {
        const p = Math.max(1, Math.min(100, Math.round(percent)));
        const lv = v => v <= Config.peripherals.veryLowAt ? "veryLow" : v <= Config.peripherals.lowAt ? "low" : "ok";
        return [
            {
                "id": "demo:mouse",
                "name": I18n.t("Мышь", "Mouse"),
                "kind": "mouse",
                "percent": p,
                "charging": false,
                "full": false,
                "asleep": false,
                "level": lv(p)
            },
            {
                "id": "demo:keyboard",
                "name": I18n.t("Клавиатура", "Keyboard"),
                "kind": "keyboard",
                "percent": Math.max(1, Math.round(p * 0.55)),
                "charging": true,
                "full": false,
                "asleep": false,
                "level": "ok"
            },
            {
                "id": "demo:headset",
                "name": I18n.t("Наушники", "Headphones"),
                "kind": "headset",
                "percent": Math.max(1, Math.round(p * 0.12)),
                "charging": false,
                "full": false,
                "asleep": false,
                "level": lv(Math.max(1, Math.round(p * 0.12)))
            }
        ];
    }

    // `angelos peripherals list | refresh`
    function ipc(line) {
        const cmd = String(line || "").trim().split(/\s+/)[0] || "list";
        switch (cmd) {
        case "list":
            return JSON.stringify(all.map(d => ({
                        "id": d.id,
                        "name": d.name,
                        "kind": d.kind,
                        "percent": d.percent,
                        "charging": d.charging,
                        "asleep": d.asleep,
                        "hidden": d.hidden,
                        "source": d.source
                    })));
        case "refresh":
            refresh();
            return "ok";
        }
        return "peripherals list | refresh";
    }
}
