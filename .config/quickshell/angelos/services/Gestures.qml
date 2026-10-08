pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "AngelLines.js" as Lines

// angelOS's own touchpad gestures (Settings → Devices → Touchpad → Gestures): scripts/gesture-watch.py
// tells which (four-finger pinches and swipes, edge swipes, taps, a hold) — niri keeps its own
// three-finger swipes and the four-finger one up/down. Each gesture runs an action of `actions`
// (Config.gestures.map, `defaults` where it says nothing). Needs the `input` group, like the
// Meta tap; a desktop without a touchpad runs nothing.
Singleton {
    id: root

    property string status: "off"          // off | starting | ready | noperm | notouchpad | error
    property string last: ""                // the last gesture seen (Settings shows it while you try)
    signal seen(string gesture)

    readonly property var gestures: ["pinchIn", "pinchOut", "swipe4Left", "swipe4Right", "swipe4Down", "edgeLeft", "edgeRight", "tap3", "tap4", "hold3"]
    readonly property var defaults: ({
            "pinchIn": "launcher",
            "pinchOut": "desktop",
            "swipe4Left": "windowBack",
            "swipe4Right": "windowForward",
            "swipe4Down": "notifications",
            "edgeLeft": "none",
            "edgeRight": "sidebar",
            "tap3": "none",
            "tap4": "angel",
            "hold3": "none"
        })
    function label(g) {
        return ({
                "pinchIn": I18n.t("Щипок 4 пальцами", "Four-finger pinch"),
                "pinchOut": I18n.t("Развести 4 пальца", "Four-finger spread"),
                "swipe4Left": I18n.t("4 пальца влево", "Four fingers left"),
                "swipe4Right": I18n.t("4 пальца вправо", "Four fingers right"),
                "swipe4Down": I18n.t("4 пальца вниз", "Four fingers down"),
                "edgeLeft": I18n.t("От левого края", "From the left edge"),
                "edgeRight": I18n.t("От правого края", "From the right edge"),
                "tap3": I18n.t("Касание 3 пальцами", "Three-finger tap"),
                "tap4": I18n.t("Касание 4 пальцами", "Four-finger tap"),
                "hold3": I18n.t("Удержать 3 пальца", "Three-finger hold")
            })[g] || g;
    }
    readonly property var actions: [
        {
            "label": I18n.t("ничего", "Nothing"),
            "value": "none"
        },
        {
            "label": I18n.t("лаунчер", "Launcher"),
            "value": "launcher"
        },
        {
            "label": I18n.t("«Пуск»", "Start"),
            "value": "start"
        },
        {
            "label": I18n.t("рабочий стол (и обратно)", "Desktop (and back)"),
            "value": "desktop"
        },
        {
            "label": I18n.t("предыдущее окно", "Previous window"),
            "value": "windowBack"
        },
        {
            "label": I18n.t("самое давнее окно", "Oldest window"),
            "value": "windowForward"
        },
        {
            "label": I18n.t("уведомления и календарь", "Notifications and calendar"),
            "value": "notifications"
        },
        {
            "label": I18n.t("сайдбар", "Sidebar"),
            "value": "sidebar"
        },
        {
            "label": I18n.t("обзор niri", "niri's overview"),
            "value": "overview"
        },
        {
            "label": I18n.t("стол выше", "Workspace up"),
            "value": "workspaceUp"
        },
        {
            "label": I18n.t("стол ниже", "Workspace down"),
            "value": "workspaceDown"
        },
        {
            "label": I18n.t("музыка: пауза / играть", "Music: play / pause"),
            "value": "media"
        },
        {
            "label": I18n.t("заблокировать", "Lock"),
            "value": "lock"
        },
        {
            "label": I18n.t("ангел ♡", "the angel ♡"),
            "value": "angel"
        }
    ]
    function actionOf(g) {
        const m = Config.gestures.map || {};
        return m[g] !== undefined ? m[g] : defaults[g] || "none";
    }
    function setAction(g, a) {
        Config.setIn(Config.gestures, "map", g, a === defaults[g] ? undefined : a);
    }

    readonly property bool wanted: Config.ready && Config.gestures.enabled && (Laptop.hasTouchpad || Quickshell.env("ANGELOS_LAPTOP_STAND") === "1") && (!Shell.dev || Quickshell.env("ANGELOS_LAPTOP_STAND") === "1")

    function run(g) {
        last = g;
        seen(g);
        if (Shell.locked || Shell.setupLocked)
            return;
        const a = actionOf(g);
        const out = Niri.focusedOutput;
        switch (a) {
        case "launcher":
            if (Skin.mac)
                Shell.toggleStart(out);
            else
                Shell.launcherOpen = !Shell.launcherOpen;
            break;
        case "start":
            Shell.toggleStart(out);
            break;
        case "desktop":
            desktop();
            break;
        case "windowBack":
        case "windowForward":
            {
                const list = AltTab.candidates().filter(w => w.id !== Niri.focusedWindowId);
                if (list.length)
                    Niri.focusWindow((a === "windowBack" ? list[0] : list[list.length - 1]).id);
                break;
            }
        case "notifications":
            if (Skin.mac)
                GoldenGate.togglePanel("nc", out);
            else
                PopupManager.showPanel("calendar", out) || PopupManager.showPanel("calendar", "");
            break;
        case "sidebar":
            if (Sidebar.enabled)
                Sidebar.toggle();
            else if (Skin.mac)
                GoldenGate.togglePanel("cc", out);
            else
                PopupManager.showPanel("calendar", out) || PopupManager.showPanel("calendar", "");
            break;
        case "overview":
            Niri.toggleOverview();
            break;
        case "workspaceUp":
            Niri.action("focus-workspace-up");
            break;
        case "workspaceDown":
            Niri.action("focus-workspace-down");
            break;
        case "media":
            if (Lyrics.player)
                Lyrics.player.togglePlaying();
            break;
        case "lock":
            Shell.lock();
            break;
        case "angel":
            if (Angel.shown && !Angel.transition)
                Angel.say(Angel.line(Angel.demon ? Lines.demon.hello : [Lines.angel.hello, ["♡ ♡ ♡", "♡ ♡ ♡"], ["Щекотно! ♡", "That tickles! ♡"]], "gesture"), null, 3000);
            break;
        }
    }

    // "desktop": the empty workspace niri keeps at the end of the screen's, and back again
    property int _deskFrom: -1
    function desktop() {
        const out = Niri.focusedOutput;
        const here = Niri.activeWorkspace(out);
        if (here && _deskFrom >= 0 && Niri.windowsOn(here.id).length === 0) {
            Niri.focusWorkspace(_deskFrom);
            _deskFrom = -1;
            return;
        }
        const empty = Niri.workspacesOn(out).filter(w => Niri.windowsOn(w.id).length === 0);
        const to = empty[empty.length - 1];
        if (!to || !here || to.id === here.id)
            return;
        _deskFrom = here.id;
        Niri.focusWorkspace(to.id);
    }

    Process {
        id: daemon
        running: root.wanted
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/gesture-watch.py", "--sensitivity", ["low", "normal", "high"].includes(Config.gestures.sensitivity) ? Config.gestures.sensitivity : "normal"]
        onRunningChanged: {
            if (running)
                root.status = "starting";
            else if (root.status === "starting" || root.status === "ready")
                root.status = root.wanted ? "error" : "off";
        }
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("gesture "))
                    root.run(line.slice(8));
                else if (["ready", "noperm", "notouchpad"].includes(line))
                    root.status = line;
            }
        }
        stderr: StdioCollector {}
        onExited: if (root.wanted && root.status !== "noperm" && root.status !== "notouchpad")
            again.start()
    }
    // a detachable's keyboard comes back, a crash: once more after a while
    Timer {
        id: again
        interval: 5000
        onTriggered: if (root.wanted)
            daemon.running = true
    }
    onWantedChanged: if (!wanted)
        status = "off"
}
