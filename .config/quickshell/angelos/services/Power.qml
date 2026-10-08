pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs.config

// The laptop's battery (UPower's display device) and what runs on it (Settings → System →
// Battery, Power): the bar's hearts (modules/bar/parts/BatteryButton), the notifications at
// low / very low / critical (once per discharge), the critical action after a minute's warning,
// the charger's sound, the eco mode, and the idle timers that differ on battery (lock, the
// screens off, sleep). The angel notices it too (services/Angel: levelReached, plugged).
// Nothing here acts without a laptop battery; sleeping goes through logind (busctl), never
// systemctl, so the laptop stand's fake bus (tests/laptop) gets it instead of the machine.
Singleton {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: !!dev && dev.ready && dev.isLaptopBattery && dev.isPresent
    readonly property int percent: hasBattery ? Math.max(0, Math.min(100, Math.round(dev.percentage * 100))) : 100
    readonly property bool plugged: !hasBattery || !UPower.onBattery
    readonly property bool discharging: hasBattery && UPower.onBattery
    readonly property bool charging: hasBattery && !UPower.onBattery && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: hasBattery && !UPower.onBattery && (dev.state === UPowerDeviceState.FullyCharged || percent >= 99)
    // plugged in, not charging, below full: the charge limit holds it (or the firmware waits)
    readonly property bool holding: hasBattery && !UPower.onBattery && !charging && !full
    readonly property real secondsLeft: !hasBattery ? 0 : discharging ? dev.timeToEmpty : charging ? dev.timeToFull : 0
    readonly property real watts: hasBattery ? Math.abs(dev.changeRate) : 0
    readonly property int health: hasBattery && dev.healthSupported && dev.healthPercentage > 0 ? Math.round(dev.healthPercentage) : Laptop.battery && Laptop.battery.health ? Laptop.battery.health : 0
    readonly property int cycles: Laptop.battery && Laptop.battery.cycles ? Laptop.battery.cycles : 0

    // "ok" | "low" | "veryLow" | "critical": only while on battery
    readonly property string level: !discharging ? "ok" : percent <= Config.power.criticalAt ? "critical" : percent <= Config.power.veryLowAt ? "veryLow" : percent <= Config.power.lowAt ? "low" : "ok"
    signal levelReached(string level)       // a new step down in this discharge (the angel listens)
    signal pluggedIn()
    signal unplugged()

    // "3 ч 10 мин" / "40 мин"; "" when UPower doesn't know yet
    function duration(s) {
        if (!(s > 0))
            return "";
        const m = Math.round(s / 60);
        const h = Math.floor(m / 60);
        return h > 0 ? (m % 60 ? I18n.t(h + " ч " + (m % 60) + " мин", h + " h " + (m % 60) + " min") : I18n.t(h + " ч", h + " h")) : I18n.t(m + " мин", m + " min");
    }
    readonly property string statusText: {
        if (!hasBattery)
            return "";
        const t = duration(secondsLeft);
        if (discharging)
            return t ? I18n.t("от батареи · ещё ", "on battery · ") + t + I18n.t("", " left") : I18n.t("от батареи", "on battery");
        if (full)
            return I18n.t("заряжена", "fully charged");
        if (charging)
            return t ? I18n.t("заряжается · до полной ", "charging · full in ") + t : I18n.t("заряжается", "charging");
        return Laptop.limitSupported && Laptop.limitNow < 100 && percent >= Laptop.limitNow - 3 ? I18n.t("подключена · держу " + Laptop.limitNow + " %", "plugged in · held at " + Laptop.limitNow + "%") : I18n.t("подключена, не заряжается", "plugged in, not charging");
    }

    // ---- the power profile (power-profiles-daemon / tuned-ppd) ----
    readonly property bool profilesAvailable: SystemInfo.powerProfile !== ""
    readonly property string profile: PowerProfiles.profile === PowerProfile.PowerSaver ? "power-saver" : PowerProfiles.profile === PowerProfile.Performance ? "performance" : "balanced"
    function setProfile(p) {
        PowerProfiles.profile = p === "power-saver" ? PowerProfile.PowerSaver : p === "performance" ? PowerProfile.Performance : PowerProfile.Balanced;
        SystemInfo.powerProfile = p;
    }

    // ---- notifications: low / very low / critical, each once per discharge ----
    // the lowest step already told this discharge (101 = none); a few seconds' grace at
    // startup, while UPower fills in (it says 0 % before it knows)
    property int _told: 101
    property bool _settled: false
    Timer {
        running: true
        interval: 4000
        onTriggered: {
            root._settled = true;
            root.check();
        }
    }
    onPercentChanged: check()
    onDischargingChanged: {
        if (!discharging)
            _told = 101;
        check();
    }
    function check() {
        if (!_settled || !discharging)
            return;
        const steps = [["critical", Config.power.criticalAt], ["veryLow", Config.power.veryLowAt], ["low", Config.power.lowAt]];
        for (const [name, at] of steps) {
            if (percent <= at && at < _told) {
                _told = at;
                levelReached(name);
                // UPower sends the percentage before the time left: tell it once both are in
                _pending = name;
                tell.restart();
                break;
            }
        }
    }
    property string _pending: ""
    Timer {
        id: tell
        interval: 1500
        onTriggered: {
            if (!root.discharging)
                return;
            // the critical step: one notification, the countdown's (or the plain one with no action)
            if (root.level === "critical" && root.criticalAction !== "nothing")
                root.armCritical();
            else if (root._pending && Config.power.alerts && !Shell.locked)
                root.alert(root._pending);
            root._pending = "";
        }
    }
    readonly property string iconDir: Quickshell.shellDir + "/data/icons/"
    function alert(name) {
        const left = duration(secondsLeft);
        const what = name === "critical" ? I18n.t("Батарея почти пуста", "Battery almost empty") : name === "veryLow" ? I18n.t("Батарея садится", "Battery very low") : I18n.t("Батарея разряжается", "Battery low");
        const body = I18n.t("Осталось " + percent + " %", percent + "% left") + (left ? I18n.t(", примерно " + left, ", about " + left) : "") + I18n.t(". Подключи зарядку ♡", ". Plug in the charger ♡");
        notify.exec(["notify-send", "-a", "angelOS", "-u", name === "low" ? "normal" : "critical", "-h", "string:x-angelos-sound:" + (name === "low" ? "notify" : "error"), "-i", iconDir + (name === "low" ? "battery-low.svg" : "battery-empty.svg"), what, body]);
    }
    Process {
        id: notify
    }

    // ---- the critical action: a minute's warning, then sleep / hibernate / power off ----
    readonly property string criticalAction: {
        const a = Config.power.criticalAction;
        return a === "hibernate" && !Laptop.canHibernate ? "suspend" : ["suspend", "hibernate", "poweroff", "nothing"].includes(a) ? a : "suspend";
    }
    readonly property bool criticalArmed: critical.running
    property real _holdUntil: 0              // "not now" in the warning: ten minutes' peace
    function armCritical() {
        if (criticalAction === "nothing" || critical.running || Date.now() < _holdUntil)
            return;
        critical.restart();
        const verb = criticalAction === "hibernate" ? I18n.t("гибернация", "hibernating") : criticalAction === "poweroff" ? I18n.t("выключаюсь", "powering off") : I18n.t("ухожу в сон", "going to sleep");
        warner.command = ["notify-send", "-a", "angelOS", "-u", "critical", "--wait", "-h", "string:x-angelos-sound:error", "-i", iconDir + "battery-empty.svg", "-A", "hold=" + I18n.t("Не сейчас (10 мин)", "Not now (10 min)"), I18n.t("Через минуту: ", "In a minute: ") + verb, I18n.t("Батарея " + percent + " %. Подключи зарядку, и ничего не случится.", "Battery at " + percent + "%. Plug in the charger and nothing happens.")];
        warner.running = true;
    }
    Process {
        id: warner
        stdout: SplitParser {
            onRead: line => {
                if (line.trim() === "hold") {
                    root._holdUntil = Date.now() + 600000;
                    critical.stop();
                }
            }
        }
    }
    Timer {
        id: critical
        interval: 60000
        onTriggered: if (root.discharging && root.level === "critical")
            root.sleep(root.criticalAction)
    }
    onPluggedChanged: {
        if (!hasBattery)
            return;
        critical.stop();
        warner.running = false;
        _holdUntil = 0;
        if (plugged)
            pluggedIn();
        else
            unplugged();
        Laptop.refreshBattery();
    }

    // logind straight away: suspend | hibernate | poweroff (the stand's fake bus gets it there)
    function sleep(kind) {
        const m = kind === "hibernate" ? "Hibernate" : kind === "poweroff" ? "PowerOff" : "Suspend";
        Quickshell.execDetached(["busctl", "call", "--system", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", m, "b", "true"]);
    }

    // ---- the charger's sound: USB in / out (Golden Gate plays its own "power", services/Sounds) ----
    Connections {
        target: root
        function onPluggedIn() {
            if (Config.power.plugSound && !Skin.mac && root._settled)
                Sounds.play("usbIn");
        }
        function onUnplugged() {
            if (Config.power.plugSound && !Skin.mac && root._settled)
                Sounds.play("usbOut");
        }
    }

    // ---- the eco mode: Motion "off" + no blur and no animations in niri (niri-game-mode) ----
    // auto: on battery at or below ecoAt, or while the profile is power-saver (not the one eco
    // itself set). It may put the profile on power-saver and gives the old one back after.
    property bool _savedByEco: false
    property string _profileBefore: ""
    readonly property bool ecoAuto: Config.ready && Config.power.eco === "auto" && hasBattery && (discharging && percent <= Config.power.ecoAt || Config.power.ecoWithSaver && profile === "power-saver" && !_savedByEco)
    readonly property bool eco: Config.ready && (Config.power.eco === "on" || ecoAuto)
    readonly property string ecoWhy: !eco ? "" : Config.power.eco === "on" ? I18n.t("включён вручную", "on by hand") : discharging && percent <= Config.power.ecoAt ? I18n.t("батарея ≤ " + Config.power.ecoAt + " %", "battery ≤ " + Config.power.ecoAt + "%") : I18n.t("профиль «Экономия»", "the power-saver profile")
    function toggleEco() {
        Config.power.eco = eco ? "off" : "on";
    }
    onEcoChanged: applyEco()
    // at startup too: a flag left by a shell that went down mid-eco must not keep niri still
    Component.onCompleted: applyEco()
    function applyEco() {
        Motion.eco = eco;
        ecoFlag.running = false;
        ecoFlag.command = ["sh", "-c", 'd="${XDG_RUNTIME_DIR:-/tmp}/angelos"; mkdir -p "$d"; if [ "$1" = 1 ]; then : > "$d/eco"; else rm -f "$d/eco"; fi; command -v niri-game-mode >/dev/null && niri-game-mode >/dev/null 2>&1; exit 0', "sh", eco ? "1" : "0"];
        ecoFlag.running = true;
        syncEcoProfile();
    }
    // the profile follows eco, also once ppd answered (the probe comes after eco at startup)
    onProfilesAvailableChanged: syncEcoProfile()
    function syncEcoProfile() {
        if (eco && Config.power.ecoSaverProfile && profilesAvailable && profile !== "power-saver") {
            _profileBefore = profile;
            _savedByEco = true;
            ecoProfile.setText(profile);
            setProfile("power-saver");
        } else if (!eco && _savedByEco) {
            _savedByEco = false;
            if (_profileBefore && profile === "power-saver")
                setProfile(_profileBefore);
            ecoProfile.setText("");
        }
    }
    // the profile eco replaced, kept over a restart of the shell (it would take the
    // power-saver eco left behind for one the user chose, and never let go)
    FileView {
        id: ecoProfile
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos/eco-profile"
        printErrors: false
        onLoaded: {
            const p = text().trim();
            if (p && !root._savedByEco) {
                root._profileBefore = p;
                root._savedByEco = true;
            }
        }
    }
    Process {
        id: ecoFlag
    }

    // ---- idle on battery: lock, the screens off, sleep (on mains: lock.idleMinutes and ours) ----
    readonly property int lockMinutes: discharging && Config.power.batteryLockMinutes >= 0 ? Config.power.batteryLockMinutes : Config.lock.idleMinutes
    readonly property int screenOffMinutes: discharging ? Config.power.batteryScreenOffMinutes : Config.power.screenOffMinutes
    readonly property int sleepMinutes: discharging ? Config.power.batterySleepMinutes : Config.power.sleepMinutes
    // the first of the three: the backlight dims 30 s before it (services/Backlight)
    readonly property int firstIdleMinutes: Math.min(...[lockMinutes, screenOffMinutes, sleepMinutes].filter(m => m > 0).concat([0x7fffffff]))
    readonly property bool idleWatch: Config.ready && !Shell.dev || Quickshell.env("ANGELOS_LAPTOP_STAND") === "1"

    IdleWatch {
        enabled: root.idleWatch && root.screenOffMinutes > 0
        timeout: Math.max(1, root.screenOffMinutes) * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle)
            Niri.powerOffMonitors()
    }
    IdleWatch {
        enabled: root.idleWatch && root.sleepMinutes > 0
        timeout: Math.max(1, root.sleepMinutes) * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle)
            root.sleep("suspend")
    }
}
