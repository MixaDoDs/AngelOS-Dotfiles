pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config

// The laptop panel's backlight and the keyboard's light (/sys/class/backlight, …/leds/*kbd_backlight),
// set through logind (Session.SetBrightness: the session's owner may, no root, no brightnessctl).
// The brightness keys (cfg/angelos-laptop.kdl → `angelos brightness up|down`), the OSD, the
// sliders (Settings → Display, the battery panel), and the dimming 30 s before the screens go
// off, lock or sleep (Settings → Power). Levels are perceived ones (the square root of the raw
// value): the keys' steps feel even, finer at the dark end. A desktop has none of it (`available`).
Singleton {
    id: root

    readonly property var dev: (Laptop.info.backlights || [])[0] || null
    readonly property bool available: !!dev
    readonly property var kbdDev: (Laptop.info.kbd || [])[0] || null
    readonly property bool kbdAvailable: !!kbdDev
    readonly property string sys: Quickshell.env("ANGELOS_SYSFS") || "/sys"

    property int raw: dev ? dev.value : 0
    readonly property int max: dev ? dev.max : 1
    // 0…1 as the eye sees it
    readonly property real level: max > 0 ? Math.sqrt(Math.max(0, raw) / max) : 0
    property int kbd: kbdDev ? kbdDev.value : 0
    readonly property int kbdMax: kbdDev ? kbdDev.max : 1
    signal changed(string kind)              // "brightness" | "kbd": the OSD shows it

    function toRaw(l) {
        const floor = Math.max(1, Math.round((Config.laptop.minBrightness || 0.02) * max));
        return Math.max(floor, Math.min(max, Math.round(l * l * max)));
    }
    function set(l, quiet) {
        if (!dev)
            return;
        raw = toRaw(Math.max(0, Math.min(1, l)));
        _want = raw;
        push.restart();
        if (!quiet)
            changed("brightness");
    }
    function step(d) {
        const s = Math.max(1, Config.laptop.brightnessStep || 5) / 100;
        // land on the grid of steps, so up then down comes back to the same place
        set(Math.round(level / s + d) * s);
    }
    function up() {
        step(1);
    }
    function down() {
        step(-1);
    }
    function setKbd(v, quiet) {
        if (!kbdDev)
            return;
        kbd = Math.max(0, Math.min(kbdMax, Math.round(v)));
        logind(["leds", kbdDev.name, kbd]);
        if (!quiet)
            changed("kbd");
    }
    function kbdCycle() {
        setKbd(kbd >= kbdMax ? 0 : kbd + 1);
    }

    // one SetBrightness per frame at most while a slider is dragged
    property int _want: -1
    Timer {
        id: push
        interval: 16
        onTriggered: if (root.dev && root._want >= 0)
            root.logind(["backlight", root.dev.name, root._want])
    }
    function logind(args) {
        Quickshell.execDetached(["busctl", "call", "--system", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session", "SetBrightness", "ssu", String(args[0]), String(args[1]), String(args[2])]);
    }

    // the firmware may move it too (a key handled by the EC, an ambient sensor): look now and then
    FileView {
        id: now
        path: root.dev ? root.sys + "/class/backlight/" + root.dev.name + "/brightness" : ""
        onLoaded: {
            const v = parseInt(text());
            if (!isNaN(v) && !push.running && !dimmer.dimmed)
                root.raw = v;
        }
    }
    FileView {
        id: kbdNow
        path: root.kbdDev ? root.sys + "/class/leds/" + root.kbdDev.name + "/brightness" : ""
        onLoaded: {
            const v = parseInt(text());
            if (!isNaN(v) && !dimmer.dimmed)
                root.kbd = v;
        }
    }
    Timer {
        running: root.available || root.kbdAvailable
        repeat: true
        interval: 4000
        onTriggered: {
            if (root.available)
                now.reload();
            if (root.kbdAvailable)
                kbdNow.reload();
        }
    }

    // ---- dim before the first idle step (Power.firstIdleMinutes), back on any input ----
    QtObject {
        id: dimmer
        property bool dimmed: false
        property int raw: -1
        property int kbd: -1
    }
    IdleMonitor {
        enabled: Power.idleWatch && Config.power.dim && (root.available || root.kbdAvailable && Config.laptop.kbdAuto) && Power.firstIdleMinutes < 0x7fffffff
        timeout: Math.max(15, Power.firstIdleMinutes * 60 - 30)
        respectInhibitors: true
        onIsIdleChanged: isIdle ? root.dim() : root.undim()
    }
    function dim() {
        if (dimmer.dimmed || Shell.locked)
            return;
        dimmer.dimmed = true;
        dimmer.raw = raw;
        dimmer.kbd = kbd;
        if (available)
            set(level / Math.sqrt(3), true);
        if (kbdAvailable && Config.laptop.kbdAuto && kbd > 0)
            setKbd(0, true);
    }
    function undim() {
        if (!dimmer.dimmed)
            return;
        dimmer.dimmed = false;
        if (available && dimmer.raw > 0) {
            raw = dimmer.raw;
            _want = raw;
            push.restart();
        }
        if (kbdAvailable && dimmer.kbd > 0)
            setKbd(dimmer.kbd, true);
    }
}
