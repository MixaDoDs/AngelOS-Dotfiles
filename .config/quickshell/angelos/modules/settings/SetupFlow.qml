pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// The setup wizard's course (SetupWizard.qml covers the screens with it): the questions in
// order, where one is, how it ends — done, closed (opened again) or `angelos setup skip` —
// and when it opens by itself.
Scope {
    id: root

    property int step: 0
    property bool tipsAfter: true
    property bool offered: false
    property var assistant: null    // the questions on screen now (tests walk them)
    // GitHub's login lives here: it goes on while the steps change
    readonly property alias github: githubLogin
    SetupGitHub {
        id: githubLogin
    }
    // a touchpad here (the mouse step offers its scrolling direction then)
    property bool touchpad: false
    Process {
        id: touchpadProbe
        command: ["grep", "-qi", "touchpad", "/proc/bus/input/devices"]
        onExited: code => root.touchpad = code === 0
    }
    // Golden Gate switched on by "I come from a Mac": another answer takes it back
    property bool macByWizard: false
    // the screen the questions are on; the others say where they are
    property string hostName: ""
    readonly property var host: Shell.screenByName(hostName) || Shell.focusedScreen || Shell.screens[0] || null

    // The questions, in order (a laptop gets one more, "laptop"): ten for someone who has just come from another system — the
    // language, where they come from (the look and the keys follow), the game, the keys and
    // the pointer, how windows work here (niri's ribbon, the biggest difference), light or
    // dark, the wallpaper, fastfetch, motion, GitHub (the author's tools) and the keys to start with. `blocks`: the
    // groups of the settings tree (tree.json) a step shows as they are on their Settings page
    // — the page is found by the group, wherever the tree puts it. A step with `when: false`
    // is skipped. `attention`: where the pulsing outline points first — "answer" (until
    // something is picked, then Continue) or "next".
    readonly property var stepList: [
        {
            "id": "hello",
            "icon": "heart",
            "title": I18n.t("Привет ♡", "Hello ♡"),
            "text": I18n.t("Несколько коротких вопросов — и можно работать. Всё, что выберешь, потом меняется в Настройках.", "A few short questions and you're ready. Everything you pick here can be changed in Settings later.")
        },
        {
            "id": "from",
            "icon": "monitor",
            "title": I18n.t("Откуда ты пришёл?", "Where are you coming from?"),
            "text": I18n.t("Подстрою вид, кнопки окон и подсказки под то, к чему ты привык.", "The look, the window buttons and the hints will match what you're used to.")
        },
        {
            "id": "game",
            "icon": "sparkle",
            "title": I18n.t("Как пользоваться angelOS?", "How do you want angelOS?"),
            "text": I18n.t("angelOS — это ещё и игра поверх рабочего стола. Работать она не мешает.", "angelOS is also a game played over your desktop. It never gets in the way of work.")
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
            "blocks": ["keyboard/keyboard-layouts"]
        },
        {
            "id": "mouse",
            "icon": "mouse",
            "title": I18n.t("Мышь и тачпад", "Mouse and touchpad"),
            "text": I18n.t("Как быстро бегает курсор и куда крутится прокрутка.", "How fast the pointer moves, and which way scrolling goes.")
        },
        {
            "id": "windows",
            "icon": "window",
            "title": I18n.t("Как здесь живут окна", "How windows work here"),
            "text": I18n.t("Окна не лежат друг на друге, а встают в ленту слева направо — её листают, как страницы. Какой ширины открывать новые?", "Windows don't pile up: they line up in a ribbon, left to right, that you scroll like pages. How wide should new ones open?")
        },
        {
            "id": "look",
            "icon": "palette",
            "title": I18n.t("Светлая или тёмная?", "Light or dark?"),
            "text": I18n.t("Можно и по времени суток: днём светлая, вечером тёмная.", "Or by the time of day: light in the day, dark in the evening.")
        },
        {
            "id": "wallpaper",
            "icon": "image",
            "title": I18n.t("Обои", "Wallpaper"),
            "text": I18n.t("Что будет на рабочем столе. Первые — обои этого релиза angelOS, днём и ночью под твою тему.", "What goes on your desktop. The first ones are this angelOS release's wallpapers, day or night to match your theme."),
            "when": Wallpapers.images.length > 0
        },
        {
            "id": "fastfetch",
            "icon": "terminal",
            "title": I18n.t("Что покажет терминал?", "What should the terminal show?"),
            "text": I18n.t("Каждый новый терминал начинается с fastfetch: что за компьютер и сколько стоит твой сетап. Выбери, как он выглядит, — картинка рядом настоящая.", "Every new terminal starts with fastfetch: what the computer is and what your gear cost. Pick how it looks; the picture next to this is the real thing."),
            "when": FastfetchLogo.installed
        },
        {
            "id": "motion",
            "icon": "sparkle",
            "title": I18n.t("Сколько всего движется?", "How much should move?"),
            "text": I18n.t("В angelOS много анимаций, а в игре бывают вспышки и тряска экрана.", "angelOS has plenty of animation, and the game has flashes and screen shaking.")
        },
        {
            "id": "laptop",
            "icon": "battery",
            "title": I18n.t("Это ноутбук ♡", "This is a laptop ♡"),
            "text": I18n.t("Батарея — сердечки на панели. На батарее angelOS может стихать, чтобы её хватило надольше, а заряжать — бережно. Жесты тачпада и клавиши яркости уже работают.", "The battery shows as hearts on the bar. On battery angelOS can quiet down to make it last, and charge gently. The touchpad gestures and the brightness keys work already."),
            "blocks": ["battery/eco", "battery/charge-limit"],
            "attention": "next",
            "when": Laptop.isLaptop
        },
        {
            "id": "who",
            "icon": "heart",
            "title": I18n.t("Кто ты?", "Who are you?"),
            "text": I18n.t("Подберу программы под то, чем ты занимаешься. На следующем шаге можно поправить список.", "I'll pick apps for what you do. You can change the list on the next step.")
        },
        {
            "id": "apps",
            "icon": "package",
            "title": I18n.t("Какие программы поставить?", "Which apps should I install?"),
            "text": I18n.t("Отмеченные поставятся, когда закончишь: откроется терминал, спросит пароль и покажет, как идёт. Уже стоящие помечены ✓.", "The ticked ones get installed when you finish: a terminal opens, asks for your password and shows how it goes. The ones you have are marked ✓.")
        },
        {
            "id": "github",
            "icon": "plug",
            "title": I18n.t("GitHub — сохранение и восстановление", "GitHub: save and restore"),
            "text": I18n.t("Войди — и прогресс игры со всеми настройками будет храниться в твоём приватном репозитории. Уже играл на другом компьютере? Здесь же вернёшь всё одной кнопкой. Не хочешь — «Пропустить».", "Log in and your game progress with every setting is kept in a private repository of yours. Played on another computer before? Bring it all back right here with one button. Don't want to? Skip."),
            "attention": "next",
            "when": github.state !== "no-gh"
        },
        {
            "id": "ready",
            "icon": "check",
            "title": I18n.t("Всё готово ♡", "You're ready ♡"),
            "text": Config.setup.from === "mac" ? I18n.t("Самое нужное. Mod — это ⌘ Command (на обычной клавиатуре — клавиша Windows).", "The keys you'll need. Mod is ⌘ Command (the Windows key on a PC keyboard).") : I18n.t("Самое нужное. Mod — это клавиша Windows.", "The keys you'll need. Mod is the Windows key."),
            "attention": "next"
        }
    ]
    // ---- the apps (data/apps-catalog.json, scripts/apps-install.py) ----
    property var catalog: ({
            "apps": [],
            "personas": [],
            "browsers": []
        })
    property var appStatus: ({})        // id -> {installed, via}; empty until checked
    readonly property bool appsChecked: Object.keys(appStatus).length > 0
    FileView {
        path: Quickshell.shellDir + "/data/apps-catalog.json"
        printErrors: false
        onLoaded: {
            try {
                root.catalog = JSON.parse(text());
            } catch (e) {}
        }
    }
    Process {
        id: appProbe
        command: ["python3", Quickshell.shellDir + "/scripts/apps-install.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.appStatus = JSON.parse(text);
                } catch (e) {}
            }
        }
    }
    // a persona ticks its apps (and keeps the browser the user picked, Helium by default)
    function pickPersona(id) {
        const p = catalog.personas.find(x => x.id === id);
        Config.setup.persona = id;
        if (!p)
            return;
        const browsers = (Config.setup.apps || []).filter(a => catalog.browsers.includes(a));
        Config.setup.apps = (browsers.length ? browsers : ["helium"]).concat(p.apps.filter(a => !catalog.browsers.includes(a)));
    }
    function toggleApp(id, on) {
        const now = (Config.setup.apps || []).filter(a => a !== id);
        Config.setup.apps = on ? now.concat([id]) : now;
    }
    // what is left to install: ticked and not there yet
    readonly property var appsToInstall: (Config.setup.apps || []).filter(a => !(appStatus[a] || {}).installed && (!appsChecked || (appStatus[a] || {}).via))
    function installApps() {
        const ids = appsToInstall;
        if (ids.length === 0 || Shell.dev || Quickshell.env("ANGELOS_TEST") === "1")
            return;
        Shell.exec(Shell.terminalArgv(["python3", Quickshell.shellDir + "/scripts/apps-install.py", "install"].concat(ids), "angelos-apps"));
    }

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
        if (githubLogin.state === "waiting")
            githubLogin.cancel();
        Shell.setupOpen = false;
        Shell.setupFirstRun = false;
        step = 0;
    }
    function finish() {
        Config.setup.complete = true;
        // the tips start where the questions were answered, once the wizard's screens are gone
        tipsOn = tipsAfter ? (host ? host.name : "") || "-" : "";
        installApps();
        close();
        if (tipsOn)
            tipsTimer.start();
    }
    // `angelos setup skip`: done for now; Settings → Account has it again
    function later() {
        Config.setup.complete = true;
        close();
    }

    // not a fixed wait: the wizard's windows (Shell.setupCovers) are gone first, then one more
    // turn of the event loop; 3 s at the most
    property string tipsOn: ""
    Timer {
        id: tipsTimer
        interval: 50
        repeat: true
        property int waited: 0
        onRunningChanged: if (running)
            waited = 0
        onTriggered: {
            waited += interval;
            if (Shell.setupCovers > 0 && waited < 3000)
                return;
            stop();
            const where = root.tipsOn === "-" ? "" : root.tipsOn;
            root.tipsOn = "";
            Qt.callLater(() => Tour.start(where));
        }
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
            if (Shell.setupOpen) {
                githubLogin.refresh();
                touchpadProbe.running = true;
                appProbe.running = true;
            }
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
        running: Config.ready && !Config.setup.complete && !root.offered && !Shell.dev && root.marker !== 0 && !Shell.bootOpen && !Shell.bootCover
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
}
