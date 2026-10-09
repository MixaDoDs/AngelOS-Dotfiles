pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// What laptop hardware there is (scripts/laptop.py probe): the battery's sysfs extras UPower
// doesn't carry (cycles, the charge limit), the backlights, the touchpad, the lid, a
// convertible's switch and accelerometer. Everything laptop-ish hides where it finds nothing:
// a desktop shows none of it. ANGELOS_SYSFS / ANGELOS_PROC (the laptop stand) fake the machine.
Singleton {
    id: root

    property var info: ({})
    readonly property bool probed: info.chassis !== undefined
    readonly property bool isLaptop: !!info.laptop
    readonly property var batteries: info.batteries || []
    readonly property var battery: batteries.length ? batteries[0] : null
    readonly property bool hasTouchpad: (info.touchpad || []).length > 0
    readonly property bool hasTouchscreen: (info.touchscreen || []).length > 0
    readonly property bool hasLid: !!info.lid
    readonly property bool convertible: !!info.tabletSwitch || info.chassis === "convertible" || info.chassis === "detachable"
    readonly property bool canHibernate: !!info.hibernate
    // the charge limit: the battery has one; it can be set directly or through the helper
    readonly property bool limitSupported: !!battery && battery.limit !== null && battery.limit !== undefined
    readonly property bool limitSettable: limitSupported && (battery.limitWritable || !!info.chargeHelper)
    readonly property int limitNow: limitSupported ? battery.limit : 100
    property string limitStatus: ""        // "", "nohelper", "error …" — the last attempt
    signal flag(string icon, string text)  // a switch key's result for the OSD (touchpad, airplane…)

    // the hardware a page or a group is about: the settings tree's "needs" (SettingsTree.shown),
    // a group's `visible: Laptop.has("…")` (the search leaves it out too, scripts/settings-index.py).
    // A desktop sees none of it, unless developer mode asks to show them (System → Development →
    // "Show the laptop's settings", 2026-10-09). Only the settings ask this: what really runs on
    // a laptop goes by isLaptop, hasLid… themselves.
    readonly property bool preview: Config.developer.enabled && Config.developer.showLaptop
    function has(what) {
        if (preview)
            return true;
        switch (what) {
        case "battery":
            return Power.hasBattery || batteries.length > 0;
        case "touchpad":
            return hasTouchpad;
        case "laptop":
            return isLaptop;
        case "lid":
            return hasLid;
        case "backlight":
            return Backlight.available || Backlight.kbdAvailable;
        case "tablet":
            return convertible;
        case "fingerprint":       // a reader (a USB one on a desktop too), or a laptop's fprintd
            return fprintReader || (isLaptop && !!info.fprintTool);
        }
        return true;
    }

    readonly property var env: {
        const e = {};
        for (const k of ["ANGELOS_SYSFS", "ANGELOS_PROC", "ANGELOS_CHARGE_HELPER"])
            if (Quickshell.env(k))
                e[k] = Quickshell.env(k);
        return e;
    }
    readonly property string script: Quickshell.shellDir + "/scripts/laptop.py"

    function refresh() {
        prober.running = true;
    }
    // the battery's own numbers (cycles, health, the limit) change slowly: on each plug and
    // every ten minutes is plenty
    function refreshBattery() {
        if (isLaptop)
            batt.running = true;
    }

    Process {
        id: prober
        running: true
        command: ["python3", root.script, "probe"]
        environment: root.env
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.info = JSON.parse(text);
                    keysDebounce.restart();
                } catch (e) {}
            }
        }
    }
    Process {
        id: batt
        command: ["python3", root.script, "battery"]
        environment: root.env
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const b = JSON.parse(text);
                    root.info = Object.assign({}, root.info, {
                        "batteries": b
                    });
                } catch (e) {}
            }
        }
    }
    Timer {
        running: root.isLaptop
        repeat: true
        interval: 600000
        onTriggered: root.refreshBattery()
    }

    // ---- the fingerprint reader (fprintd): asked once a laptop with the tools is seen ----
    property int fprintEnrolled: 0
    property bool fprintReader: false
    function refreshFingers() {
        if (info.fprintTool)
            fingers.running = true;
    }
    onProbedChanged: if (probed)
        refreshFingers()
    Process {
        id: fingers
        command: ["python3", root.script, "fprint"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.fprintReader = !!j.reader;
                    root.fprintEnrolled = j.enrolled || 0;
                } catch (e) {}
            }
        }
    }

    // ---- the charge limit (Settings → Battery): set at every login, the firmware forgets it ----
    readonly property int limitWanted: Math.max(50, Math.min(100, Config.power.chargeLimit || 100))
    function applyLimit() {
        if (!Config.ready || !limitSupported || Shell.dev && !Quickshell.env("ANGELOS_SYSFS"))
            return;
        if (limitNow === limitWanted)
            return;
        limiter.command = ["python3", root.script, "limit", String(limitWanted)];
        limiter.running = true;
    }
    onLimitWantedChanged: applyLimit()
    onLimitSupportedChanged: applyLimit()
    Process {
        id: limiter
        environment: root.env
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                root.limitStatus = t.startsWith("ok") ? "" : t;
                root.refreshBattery();
            }
        }
    }

    // ---- the keys and switches in niri (cfg/angelos-laptop.kdl, scripts/laptop-config.py) ----
    // written once the probe knows the machine: the keys wherever asked (Mod+P is a desktop's
    // with two screens too), the lid and tablet switches only on a laptop
    property var keysSkipped: []
    property string keysLog: ""
    readonly property string keysWanted: JSON.stringify({
        "keys": !!Config.laptop.keys,
        "switches": isLaptop
    })
    function writeKeys() {
        if (!Config.ready || !probed || Shell.dev && Quickshell.env("ANGELOS_LAPTOP_STAND") !== "1")
            return;
        keysWriter.command = ["python3", Quickshell.shellDir + "/scripts/laptop-config.py", keysWanted];
        keysWriter.running = true;
    }
    onKeysWantedChanged: keysDebounce.restart()
    Timer {
        id: keysDebounce
        interval: 1500
        onTriggered: root.writeKeys()
    }
    Process {
        id: keysWriter
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.keysSkipped = j.skipped || [];
                    root.keysLog = "";
                } catch (e) {}
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                root.keysLog = text.trim().split("\n").slice(-1)[0]
        }
    }

    // ---- the lid (niri's switch-events → `angelos laptop lid close|open`) ----
    // logind suspends on its own (HandleLidSwitch=suspend, not when docked): left to it while
    // that is what is asked; anything else and angelOS holds the lid's inhibitor and acts itself
    property bool lidClosed: false
    readonly property string lidAction: Power.discharging || !Power.hasBattery ? Config.power.lidAction : Config.power.lidActionAc
    readonly property bool lidOurs: Config.ready && hasLid && (Config.power.lidAction !== "suspend" || Config.power.lidActionAc !== "suspend")
    // a second screen: the lid does nothing (niri turns the panel off by itself). Counted from
    // niri's connected outputs, the panel switched off included (Quickshell's screens lose it)
    readonly property bool docked: Object.keys(Outputs.outputs || {}).length > 1
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.isLaptop)
                Outputs.refresh();
        }
    }
    onIsLaptopChanged: if (isLaptop)
        Outputs.refresh()
    function lid(closed) {
        lidClosed = closed;
        if (!closed || !lidOurs || docked)
            return;
        switch (lidAction) {
        case "lock":
            Shell.lock();
            break;
        case "hibernate":
            Power.sleep(canHibernate ? "hibernate" : "suspend");
            break;
        case "suspend":
            Power.sleep("suspend");
            break;
        }
    }
    Process {
        id: lidHold
        running: root.lidOurs && (!Shell.dev || Quickshell.env("ANGELOS_LAPTOP_STAND") === "1")
        stdinEnabled: true           // `cat` exits with the pipe: a shell gone leaves no inhibitor behind
        command: ["systemd-inhibit", "--what=handle-lid-switch", "--who=angelOS", "--why=" + I18n.t("крышку обрабатывает angelOS (Настройки → Питание)", "angelOS handles the lid (Settings → Power)"), "--mode=block", "cat"]
    }

    // ---- the touchpad on / off (its key; niri's `touchpad { off }`, InputConfig) ----
    function setTouchpad(on) {
        InputConfig.save({
            "touchpadOff": !on
        });
        flag("touchpad", on ? I18n.t("тачпад вкл", "touchpad on") : I18n.t("тачпад выкл", "touchpad off"));
    }

    // ---- airplane mode (rfkill): the key may have been handled by the firmware already ----
    property bool airplane: info.rfkill ? !!info.rfkill.airplane : false
    property bool _airBefore: false
    function airplaneKey() {
        _airBefore = airplane;
        airRead.command = ["python3", root.script, "rfkill"];
        airRead.running = true;
        airWait.restart();
    }
    Timer {
        id: airWait
        interval: 450
        onTriggered: {
            airRead.command = ["python3", root.script, "rfkill"];
            airRead.after = true;
            airRead.running = true;
        }
    }
    function setAirplane(on) {
        airRead.command = ["python3", root.script, "rfkill", on ? "on" : "off"];
        airRead.after = false;
        airRead.running = true;
        flag("plane", on ? I18n.t("режим полёта", "airplane mode") : I18n.t("радио вкл", "radios on"));
    }
    Process {
        id: airRead
        property bool after: false
        environment: root.env
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.airplane = !!j.airplane;
                    if (airRead.after) {
                        airRead.after = false;
                        // the firmware flipped it: only say so; else flip it ourselves
                        if (root.airplane !== root._airBefore)
                            root.flag("plane", root.airplane ? I18n.t("режим полёта", "airplane mode") : I18n.t("радио вкл", "radios on"));
                        else
                            root.setAirplane(!root._airBefore);
                    }
                } catch (e) {}
            }
        }
    }

    // ---- a convertible: tablet mode, the screen turning with it, the on-screen keyboard ----
    property bool tablet: info.chassis === "tablet"
    readonly property string panel: {
        const names = Object.keys(Outputs.outputs || {});
        return names.find(n => /^(eDP|LVDS|DSI)/i.test(n)) || "";
    }
    readonly property bool rotating: Config.ready && Config.laptop.autoRotate && !Config.laptop.rotationLock && !!info.accel && !!info.rotateTool && panel !== "" && (tablet || info.chassis === "tablet" || info.chassis === "detachable")
    property string orientation: "normal"
    Process {
        id: sensor
        running: root.rotating
        command: ["monitor-sensor", "--accel"]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/orientation(?: changed)?:\s*([a-z-]+)/i) || line.match(/\(orientation:\s*([a-z-]+)\)/i);
                if (m)
                    root.turn(m[1]);
            }
        }
    }
    // the accelerometer's side that is up → niri's transform (counter-clockwise)
    function turn(o) {
        const t = ({
                "normal": "normal",
                "left-up": "90",
                "bottom-up": "180",
                "right-up": "270"
            })[o];
        if (!t || !panel || t === orientation)
            return;
        orientation = t;
        Quickshell.execDetached(["niri", "msg", "output", panel, "transform", t]);
    }
    onRotatingChanged: if (!rotating && orientation !== "normal" && panel) {
        orientation = "normal";
        Quickshell.execDetached(["niri", "msg", "output", panel, "transform", "normal"]);
    }
    function setRotationLock(on) {
        Config.laptop.rotationLock = on;
        flag("rotate", on ? I18n.t("поворот закреплён", "rotation locked") : I18n.t("поворот авто", "auto-rotate"));
    }
    Process {
        id: osk
        running: root.tablet && Config.ready && Config.laptop.tabletKeyboard && !!root.info.osk && !Shell.locked
        command: [root.info.osk || "true"].concat(root.info.osk === "wvkbd-mobintl" ? ["-L", "260"] : [])
    }
    function setTablet(on) {
        tablet = on;
        flag("laptop", on ? I18n.t("режим планшета", "tablet mode") : I18n.t("режим ноутбука", "laptop mode"));
    }

    // ---- `angelos laptop …` (modules/Ipc) ----
    function ipc(line) {
        const a = String(line || "").trim().split(/\s+/);
        switch (a[0]) {
        case "info":
            return JSON.stringify(info);
        case "refresh":
            refresh();
            return "ok";
        case "eco":
            if (a[1] === "on" || a[1] === "off" || a[1] === "auto")
                Config.power.eco = a[1];
            return "eco " + (Power.eco ? "on" : "off") + " (" + Config.power.eco + ")";
        case "battery":
            return Power.hasBattery ? Power.percent + "% " + (Power.discharging ? "discharging" : Power.charging ? "charging" : "plugged") + " level=" + Power.level + " eco=" + Power.eco + (Power.criticalArmed ? " critical-armed" : "") : "no battery";
        case "lid":
            lid(a[1] === "close" || a[1] === "closed");
            return "lid " + (lidClosed ? "closed" : "open") + (lidOurs ? " (angelOS: " + lidAction + (docked ? ", docked" : "") + ")" : " (logind)");
        case "touchpad":
            {
                const on = a[1] === "on" ? true : a[1] === "off" ? false : InputConfig.touchpadOff;
                setTouchpad(on);
                return "touchpad " + (on ? "on" : "off");
            }
        case "airplane":
            if (a[1] === "on" || a[1] === "off")
                setAirplane(a[1] === "on");
            else
                airplaneKey();
            return "ok";
        case "project":
            if (Shell.projectOpen)
                Shell.projectNext();
            else
                Shell.projectOpen = true;
            return "open";
        case "tablet":
            setTablet(a[1] !== "off");
            return "tablet " + (tablet ? "on" : "off");
        case "rotate":
            if (a[1] === "lock" || a[1] === "unlock")
                setRotationLock(a[1] === "lock");
            else if (a[1])
                turn(a[1]);
            return "rotation " + orientation + (Config.laptop.rotationLock ? " (locked)" : "");
        case "keys":
            writeKeys();
            return "keys: writing";
        case "gesture":
            if (!Gestures.gestures.includes(a[1]))
                return "gesture " + Gestures.gestures.join("|");
            Gestures.run(a[1]);
            return a[1] + " → " + Gestures.actionOf(a[1]);
        default:
            return "laptop info | refresh | battery | eco [on|off|auto] | lid close|open | touchpad [on|off] | airplane [on|off] | project | tablet on|off | rotate [lock|unlock|normal|left-up|right-up|bottom-up] | keys | gesture NAME";
        }
    }
}
