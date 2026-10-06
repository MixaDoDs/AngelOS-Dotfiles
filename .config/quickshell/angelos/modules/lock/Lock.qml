pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.config
import qs.services
import qs.widgets

// ext-session-lock screen with PAM auth, plus a preview that shows the same
// screen in an ordinary overlay (no session lock, password is not checked).
Scope {
    id: root

    property string status: ""
    property bool busy: pam.active || unlocking
    property int fails: 0
    property string buffer: ""
    property bool unlocking: false         // PAM said yes; the goodbye animation plays
    property real lockedAt: 0
    property bool caps: false
    readonly property bool previewing: Shell.lockPreview && !Shell.locked
    readonly property bool shown: Shell.locked || previewing
    // Settings → Lock → Look; the unlock picked there ("auto": the look's own)
    readonly property string look: Config.lock.style === "heaven" ? "heaven" : "ngo"
    readonly property var fxStyles: ["heart", "pixels", "crt", "gate", "glitch"]
    readonly property string fx: !Config.lock.reactions || Config.lock.unlockFx === "none" ? "none" : fxStyles.includes(Config.lock.unlockFx) ? Config.lock.unlockFx : look === "heaven" ? "gate" : "heart"

    signal shake
    signal success
    signal typed(int length, bool added)
    signal demo(string text)               // the preview types this in by itself
    signal captureNow                      // every screen: a picture of yourself, please

    function submit(pw) {
        if (busy)
            return;
        if (previewing) {
            // preview only: nothing is checked, an empty field shows the failure
            if (pw === "")
                fail();
            else
                succeed();
            return;
        }
        buffer = pw;
        status = I18n.t("проверяю…", "Checking…");
        pam.start();
    }
    function fail() {
        fails++;
        status = fails > 2 ? I18n.t("ну пожааалуйста, вспомни пароль…", "Try your password again…") : I18n.t("неправильный пароль ✕", "Incorrect password ✕");
        shake();
    }

    // ---- the unlock ----
    // 1. the lock plays its own part (a sticker, the gate swinging open)
    // 2. every screen grabs a picture of itself
    // 3. an overlay over the desktop puts those pictures up (still under the lock)
    // 4. the lock goes; the overlay plays the pictures away (UnlockReveal)
    property var shots: ({})               // screen name -> grab result
    property var origins: ({})             // screen name -> where the heart grows from
    property bool revealing: false         // the overlay is up
    property bool revealGo: false          // …and playing
    // a look that plays something longer at the unlock (the stream's highlights, heaven's
    // prayer) asks for the time from its success handler; any key or click hurries it
    property int hold: 0
    // what this unlock brought (both looks show it): the day's login reward (LockStream.claim)
    // and the prayer (HeavenStars.pull) — the preview prays for show, nothing counted
    property var claimed: null
    property var wished: null
    function succeed() {
        status = "";
        unlocking = true;
        hold = 0;
        claimed = null;
        wished = null;
        if (Config.lock.reactions && !Motion.still) {
            if (!previewing && Config.lock.dailyReward)
                claimed = LockStream.claim();
            if (previewing ? Config.lock.wish : HeavenStars.canWish && HeavenStars.payWish(true))
                wished = HeavenStars.pull(previewing);
        }
        success();
        if (!previewing)
            HeavenStars.unlocked(fails);
        fails = 0;
        if (fx === "none" && hold === 0) {
            leave();
            return;
        }
        ownPart.interval = Motion.still ? 0 : Math.max(hold, look === "heaven" ? 700 : fx === "crt" ? 650 : 420);
        ownPart.restart();
    }
    function hurry() {
        if (ownPart.running) {
            ownPart.stop();
            ownPartDone();
        }
    }
    function ownPartDone() {
        if (fx === "none") {
            leave();
            return;
        }
        shots = {};
        origins = {};
        captureNow();
        captureWait.restart();
    }
    function captured(name, result, origin) {
        if (!unlocking || revealing)
            return;
        const s = Object.assign({}, shots);
        s[name] = result;
        shots = s;
        const o = Object.assign({}, origins);
        o[name] = origin;
        origins = o;
        if (Object.keys(s).length >= (previewing ? Shell.screens.length : Quickshell.screens.length))
            startReveal();
    }
    function startReveal() {
        if (!unlocking || revealing)
            return;
        captureWait.stop();
        revealing = true;
        revealUp.restart();
    }
    function leave() {
        unlocking = false;
        if (previewing)
            Shell.lockPreview = false;
        else
            Shell.locked = false;
    }
    Timer {
        id: ownPart
        onTriggered: root.ownPartDone()
    }
    // a screen that does not answer is covered by plain colour
    Timer {
        id: captureWait
        interval: 800
        onTriggered: root.startReveal()
    }
    // the overlay maps and shows its pictures before the lock lets go
    Timer {
        id: revealUp
        interval: 180
        onTriggered: {
            root.leave();
            root.revealGo = true;
            revealEnd.restart();
        }
    }
    Timer {
        id: revealEnd
        interval: 1400
        onTriggered: {
            root.revealGo = false;
            root.revealing = false;
            root.shots = {};
            root.origins = {};
        }
    }

    // heaven's stars count the minutes at the computer from the start, not from the first lock
    readonly property bool starsReady: HeavenStars.loaded
    Component.onCompleted: Shell.lockPreviewTry = text => {
        if (!root.previewing)
            return;
        root.demo(text);
    }
    Connections {
        target: Shell
        function onLockedChanged() {
            if (Shell.locked) {
                root.lockedAt = Date.now();
                root.status = "";
                root.unlocking = false;
                root.revealing = false;
                root.revealGo = false;
                Shell.lockPreview = false;
            }
        }
        function onLockPreviewChanged() {
            if (Shell.lockPreview) {
                root.lockedAt = Date.now();
                root.status = "";
                root.fails = 0;
                root.unlocking = false;
                if (Shell.lockPreviewDemo !== "")
                    demoSoon.restart();
            }
        }
    }
    // Settings → Lock → Show the unlock: the preview types the word in by itself
    Timer {
        id: demoSoon
        interval: 1600
        onTriggered: {
            const text = Shell.lockPreviewDemo;
            Shell.lockPreviewDemo = "";
            if (root.previewing && text !== "")
                root.demo(text);
        }
    }

    PamContext {
        id: pam
        configDirectory: Quickshell.shellDir + "/pam"
        config: "angelos-lock"
        onResponseRequiredChanged: {
            if (responseRequired) {
                respond(root.buffer);
                root.buffer = "";
            }
        }
        onCompleted: result => {
            root.buffer = "";
            if (result === PamResult.Success)
                root.succeed();
            else
                root.fail();
        }
        onError: e => {
            root.buffer = "";
            root.status = I18n.t("ошибка PAM: ", "PAM error: ") + e;
        }
    }

    // Caps Lock from the keyboard LEDs (a lock screen has no other way to know)
    Process {
        running: root.shown && Config.lock.indicators
        command: ["sh", "-c", "while :; do cat /sys/class/leds/*::capslock/brightness 2>/dev/null | tr -d '\\n'; echo; sleep 0.3; done"]
        stdout: SplitParser {
            onRead: line => root.caps = /[1-9]/.test(line)
        }
    }

    // ---- lock before sleep, and on `loginctl lock-session` ----
    // logind waits for a "delay" inhibitor before suspending, so the lock surface
    // is up and confirmed by niri before the machine sleeps; waking up never
    // shows the desktop. The inhibitor is released once the lock is secure and
    // taken again after resume.
    readonly property bool sleepLock: Config.lock.onSleep && !Shell.dev
    property bool sleeping: false
    // logind object path of this session (sd_bus_path_encode: "3" -> "_33")
    readonly property string sessionPath: {
        const id = Quickshell.env("XDG_SESSION_ID") || "";
        if (!id)
            return "";
        let out = "";
        for (let i = 0; i < id.length; i++) {
            const c = id[i];
            if (/[A-Za-z0-9]/.test(c) && !(i === 0 && /[0-9]/.test(c)))
                out += c;
            else
                out += "_" + ("0" + c.charCodeAt(0).toString(16)).slice(-2);
        }
        return "/org/freedesktop/login1/session/" + out;
    }
    // if the lock cannot come up, sleep must still happen (logind waits at most
    // InhibitDelayMaxSec anyway); this lets go a little earlier
    property bool sleepTimedOut: false
    onSleepingChanged: {
        sleepTimedOut = false;
        if (sleeping)
            sleepGrace.restart();
    }
    Timer {
        id: sleepGrace
        interval: 4000
        onTriggered: root.sleepTimedOut = true
    }
    Process {
        id: inhibitor
        // held while awake; let go once the lock is confirmed (or after 4 s)
        running: root.sleepLock && !(root.sleeping && (lock.secure || root.sleepTimedOut))
        stdinEnabled: true           // `cat` exits with the pipe, so nothing is left behind
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=angelOS", "--why=Lock the screen before sleep", "cat"]
    }
    Process {
        id: logind
        running: root.sleepLock
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        stdout: SplitParser {
            onRead: line => {
                const sleep = line.match(/\.Manager\.PrepareForSleep \((true|false)/);
                if (sleep) {
                    if (sleep[1] === "true") {
                        root.sleeping = true;
                        Shell.lock();
                    } else {
                        root.sleeping = false;
                        Shell.resumed();
                        // in case the lock could not come up before sleeping
                        if (!Shell.locked)
                            Shell.lock();
                    }
                } else if (root.sessionPath && line.startsWith(root.sessionPath + ":") && /\.Session\.Lock \(\)/.test(line)) {
                    Shell.lock();
                }
            }
        }
        onExited: if (root.sleepLock)
            logindRestart.start()
    }
    Timer {
        id: logindRestart
        interval: 2000
        onTriggered: logind.running = root.sleepLock
    }

    // idle auto-lock
    IdleMonitor {
        enabled: Config.lock.idleMinutes > 0
        timeout: Math.max(1, Config.lock.idleMinutes) * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle)
            Shell.lock()
    }

    WlSessionLock {
        id: lock
        locked: Shell.locked

        WlSessionLockSurface {
            id: surface
            color: Theme.desk

            LockScreen {
                anchors.fill: parent
                screenName: surface.screen ? surface.screen.name : ""
                primary: surface.screen === Shell.focusedScreen || Quickshell.screens.length === 1
                lockScope: root
            }

            RightClickGuard {}
        }
    }

    // preview: Settings → Lock screen, or `angelos lockPreview`
    Variants {
        model: root.previewing ? Shell.screens : []
        PanelWindow {
            id: previewWin
            required property var modelData
            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Theme.desk
            WlrLayershell.namespace: "angelos-lock-preview"
            WlrLayershell.layer: WlrLayer.Overlay
            // takes input: the lock screen
            WlrLayershell.keyboardFocus: Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive

            LockScreen {
                anchors.fill: parent
                screenName: previewWin.modelData.name
                primary: previewWin.modelData === Shell.focusedScreen || Shell.screens.length === 1
                lockScope: root
                preview: true
            }

            RightClickGuard {}
        }
    }

    // the unlock's second half, over the desktop (input passes through)
    Variants {
        model: root.revealing ? Shell.screens : []
        PanelWindow {
            id: revealWin
            required property var modelData
            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.namespace: "angelos-unlock"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            UnlockReveal {
                anchors.fill: parent
                readonly property var grab: root.shots[revealWin.modelData.name] || null
                shot: grab ? grab.url : ""
                style: root.fx
                origin: root.origins[revealWin.modelData.name] || Qt.point(0.5, 0.5)
                primary: revealWin.modelData === Shell.focusedScreen || Shell.screens.length === 1
                go: root.revealGo
            }

            RightClickGuard {}
        }
    }
}
