pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// The setup wizard's course (SetupWizard.qml covers the screens with it on the first run):
// the questions in order, where one is, how it ends — done, or "set up later" — and when it
// opens by itself. Opened again from Settings or `angelos setup` it is the window below,
// holding nothing.
Scope {
    id: root

    property int step: 0
    property bool tipsAfter: true
    property bool offered: false
    property var assistant: null    // the questions on screen now (tests walk them)
    // the screen the questions are on (first run); the others say where they are
    property string hostName: ""
    readonly property var host: Shell.screenByName(hostName) || Shell.focusedScreen || Shell.screens[0] || null

    // The questions, in order. `blocks`: the groups of the settings tree (tree.json) a step
    // shows as they are on their Settings page — the page is found by the group, wherever
    // the tree puts it. A step with `when: false` is skipped.
    readonly property var stepList: [
        {
            "id": "hello",
            "icon": "heart",
            "title": I18n.t("Привет ♡", "Hello ♡"),
            "text": I18n.t("Несколько вопросов — и можно работать. Всё, что выберешь, потом меняется в Настройках.", "A few questions and you're ready. Everything you pick here can be changed in Settings later.")
        },
        {
            "id": "game",
            "icon": "sparkle",
            "title": I18n.t("Как пользоваться angelOS?", "How do you want angelOS?"),
            "text": I18n.t("angelOS — это ещё и игра поверх рабочего стола. Работать она не мешает.", "angelOS is also a game played over your desktop. It never gets in the way of work."),
            // the installer asked it already (ANGELOS_GAME): not again on the first run
            "when": !(Shell.setupFirstRun && Config.setup.gameAsked)
        },
        {
            "id": "screens",
            "icon": "monitor",
            "title": I18n.t("Какой экран главный?", "Which screen is the main one?"),
            "text": I18n.t("На нём будут виджеты, ангел и заставка, на него niri ставит фокус при входе.", "It gets the widgets, the angel and the screensaver; niri focuses it at login."),
            "when": Shell.screens.length > 1
        },
        {
            "id": "keyboard",
            "icon": "keyboard",
            "title": I18n.t("Раскладки клавиатуры", "Keyboard layouts"),
            "text": I18n.t("На каких языках печатаешь и как между ними переключаться.", "The languages you type in, and how to switch between them."),
            "blocks": ["keyboard/keyboard-layouts"],
            // the installer asked it already (KB_LAYOUTS): not again on the first run
            "when": !(Shell.setupFirstRun && Config.setup.keyboardAsked)
        },
        {
            "id": "look",
            "icon": "palette",
            "title": I18n.t("Светлая или тёмная?", "Light or dark?"),
            "text": I18n.t("Можно и по времени суток: днём светлая, вечером тёмная.", "Or by the time of day: light in the day, dark in the evening.")
        },
        {
            "id": "motion",
            "icon": "sparkle",
            "title": I18n.t("Сколько всего движется?", "How much should move?"),
            "text": I18n.t("В angelOS много анимаций, а в игре бывают вспышки и тряска экрана.", "angelOS has plenty of animation, and the game has flashes and screen shaking.")
        },
        {
            "id": "ready",
            "icon": "check",
            "title": I18n.t("Всё готово ♡", "You're ready ♡"),
            "text": I18n.t("Три клавиши, чтобы начать. Mod — это клавиша Windows.", "Three keys to start with. Mod is the Windows key.")
        }
    ]
    readonly property var steps: stepList.filter(s => s.when === undefined || s.when)
    readonly property int last: steps.length - 1
    readonly property var cur: steps[Math.min(step, last)] || steps[0]
    onLastChanged: step = Math.min(step, last)

    function go(i) {
        step = Math.max(0, Math.min(last, i));
    }
    function next() {
        if (step < last)
            step++;
        else
            finish();
    }
    function back() {
        if (step > 0)
            step--;
    }
    function close() {
        Shell.setupOpen = false;
        Shell.setupFirstRun = false;
        step = 0;
    }
    function finish() {
        Config.setup.complete = true;
        const tour = tipsAfter;
        close();
        if (tour)
            tipsTimer.start();
    }
    // "Set up later", Esc, `angelos setup skip`: done for now; Settings → Account has it again
    function later() {
        Config.setup.complete = true;
        close();
    }

    Timer {
        id: tipsTimer
        interval: 700
        onTriggered: Tour.start()
    }
    Connections {
        target: Shell
        function onSetupStepRequested(step) {
            root.go(step);
        }
        function onSetupSkipRequested() {
            root.marker = 1;
            if (Shell.setupOpen || !Config.setup.complete)
                root.later();
        }
        function onSetupOpenChanged() {
            if (Shell.setupOpen && root.hostName === "")
                root.hostName = Shell.focusedScreen ? Shell.focusedScreen.name : "";
            else if (!Shell.setupOpen)
                root.hostName = "";
        }
    }

    // ~/.config/angelos/setup-skipped, left by `angelos setup skip` (scripts/setup-cli.py):
    // the way out that works even when this shell never answered
    property int marker: 0          // 0: not known yet, 1: there, 2: not
    FileView {
        path: Config.dir + "/setup-skipped"
        printErrors: false
        onLoaded: root.marker = 1
        onLoadFailed: root.marker = 2
    }

    // the first run: once the settings are read, the skip marker looked for and the loading
    // screen gone (dev runs sit next to a live session: never by themselves)
    Timer {
        interval: 1200
        running: Config.ready && !Config.setup.complete && !root.offered && !Shell.dev && root.marker !== 0 && !Shell.bootOpen
        onTriggered: {
            root.offered = true;
            if (root.marker === 1) {
                Config.setup.complete = true;
                return;
            }
            Shell.setupFirstRun = true;
            Shell.setupOpen = true;
        }
    }

    // ---- again from Settings or `angelos setup`: a window, nothing held ----
    FloatingWindow {
        id: again
        title: Shell.appTitle + " · " + I18n.t("Мастер настройки", "Setup wizard")
        visible: Shell.setupOpen && !Shell.setupFirstRun
        color: "transparent"
        implicitWidth: 860
        implicitHeight: 660
        minimumSize: Qt.size(560, 460)
        onClosed: root.close()
        onVisibleChanged: if (!visible && Shell.setupOpen && !Shell.setupFirstRun)
            root.close()

        PxWindow {
            anchors.fill: parent
            anchors.rightMargin: Theme.u * 2
            anchors.bottomMargin: Theme.u * 2
            title: again.title
            icon: "heart"
            bodyPadding: 0
            onCloseClicked: root.close()
            onTitlePressed: again.startSystemMove()
            Loader {
                anchors.fill: parent
                active: again.visible
                source: "SetupAssistant.qml"
                onLoaded: {
                    item.wizard = root;
                    root.assistant = item;
                }
            }
        }
        RightClickGuard {}
    }
}
