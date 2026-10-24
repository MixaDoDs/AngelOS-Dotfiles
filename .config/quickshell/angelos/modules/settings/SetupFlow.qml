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
            "title": I18n.t("Какой вид?", "Which look?"),
            "text": I18n.t("Пиксельный angelOS или Golden Gate — как на Mac. Поменять можно в Настройках.", "The pixel angelOS or Golden Gate, like a Mac. Settings change it later.")
        },
        {
            "id": "game",
            "icon": "sparkle",
            "title": I18n.t("Ангел и сюжет?", "The angel and the story?"),
            "text": I18n.t("angelOS — это ещё и игра поверх рабочего стола. Работать она не мешает.", "angelOS is also a game played over your desktop. It never gets in the way of work.")
        },
        {
            "id": "screens",
            "icon": "monitor",
            // which one is the main (with more than one) and how each stands: turned on its side,
            // upside down (SetupAssistant: screens)
            "title": Shell.screens.length > 1 ? I18n.t("Экраны: какой главный и как стоят?", "Screens: which is the main one, and how do they stand?") : I18n.t("Как стоит монитор?", "How does the monitor stand?"),
            "text": (Shell.screens.length > 1 ? I18n.t("На главном будут виджеты, ангел и заставка, на него niri ставит фокус при входе. ", "The main one gets the widgets, the angel and the screensaver; niri focuses it at login. ") : "") + I18n.t("Стоит вертикально или вверх ногами — поверни картинку. Частота: у монитора на 144 Гц и выше выбери самую большую — всё станет плавнее.", "Standing on its side or upside down? Turn the picture. Refresh rate: on a 144 Hz monitor or faster pick the highest, and everything gets smoother."),
            "when": Shell.screens.length > 0
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
            "title": I18n.t("Как будут жить окна?", "How should windows work?"),
            "text": I18n.t("Desktop — как в обычной системе: окна поверх друг друга, с заголовком и кнопками. Лента — окна встают слева направо, её листают, как страницы.", "Desktop, as on a usual system: windows over each other, with a title bar and buttons. The Strip: windows line up left to right, scrolled like pages."),
            // Golden Gate is always Desktop (WindowConfig)
            "when": Config.settingsUi.skin !== "goldengate"
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
            "id": "widgets",
            "icon": "layers",
            "title": I18n.t("Что поставить на рабочий стол?", "What goes on the desktop?"),
            "text": I18n.t("Виджеты живут прямо на обоях. Потом их можно двигать, менять размер и рамку — ПКМ по виджету.", "Widgets live right on the wallpaper. Later you can move them and change their size and frame: right-click a widget.")
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
            "id": "browser",
            "icon": "search",
            "title": I18n.t("Какой браузер?", "Which browser?"),
            "text": I18n.t("Он откроется по Mod+B и по ссылкам из программ. Не стоит — поставлю вместе с остальными программами. Потом поменять: Настройки → Приложения → По умолчанию.", "It opens on Mod+B and for links from apps. Not installed yet? It comes with the other apps. To change it later: Settings → Default applications.")
        },
        {
            "id": "apps",
            "icon": "package",
            "title": I18n.t("Какие программы поставить?", "Which apps should I install?"),
            "text": I18n.t("Отмеченные поставятся прямо здесь, когда закончишь: пароль администратора спросят один раз, а полоска покажет, как идёт. Уже стоящие помечены ✓.", "The ticked ones get installed right here when you finish: the admin password is asked once, and a bar shows how it goes. The ones you have are marked ✓.")
        },
        {
            "id": "scripts",
            "icon": "terminal",
            "title": I18n.t("Что ещё умеет angelOS", "What else angelOS can do"),
            "text": I18n.t("Маленькие программы, которые идут с angelOS: что-то работает само, что-то — по клавишам. Включи то, что нужно.", "Little programs that come with angelOS: some work by themselves, some on a key. Switch on what you need.")
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
            // services/Telemetry: a straight yes or no; Continue with neither picked = no
            "id": "telemetry",
            "icon": "chip",
            "title": I18n.t("Помочь автору телеметрией?", "Help the author with telemetry?"),
            "text": I18n.t("Раз в неделю автору angelOS уходят версии и железо: процессор, видеокарта, память, экраны, версии Quickshell и системы. Так видно, на чём angelOS живёт и что чинить первым. Имён, файлов и IP — нет. Передумаешь — Настройки → Спонсор.", "Once a week angelOS's author gets the versions and the hardware: CPU, graphics, memory, screens, the Quickshell and system versions. That shows what angelOS runs on and what to fix first. No names, files or IP. Changed your mind? Settings → Sponsor.")
        },
        {
            "id": "ready",
            "icon": "check",
            "title": I18n.t("Всё готово ♡", "You're ready ♡"),
            "text": Config.setup.from === "mac" ? I18n.t("Самое нужное. Mod — это ⌘ Command (на обычной клавиатуре — клавиша Windows).", "The keys you'll need. Mod is ⌘ Command (the Windows key on a PC keyboard).") : I18n.t("Самое нужное. Mod — это клавиша Windows.", "The keys you'll need. Mod is the Windows key."),
            "attention": "next"
        },
        {
            "id": "install",
            "icon": "package",
            "title": setupInstall.done ? (setupInstall.failed.length || setupInstall.auth ? I18n.t("Почти всё ♡", "Almost there ♡") : I18n.t("Программы стоят ♡", "The apps are in ♡")) : I18n.t("Ставлю программы…", "Installing the apps…"),
            "text": setupInstall.done ? (setupInstall.auth ? I18n.t("Без пароля администратора программы не поставить. Попробуй ещё раз или пропусти — потом: Настройки → Обновления.", "The apps can't go in without the admin password. Try again or skip: later, Settings → Updates.") : setupInstall.failed.length ? I18n.t("Не все поставились — можно повторить, а можно идти дальше.", "Not all of them made it: try again, or go on.") : I18n.t("Всё на месте. Можно начинать.", "Everything is in place. Let's start.")) : I18n.t("Пароль спросят один раз. Рабочий стол откроется, когда всё встанет.", "The password is asked once. The desktop opens when everything is in."),
            "attention": setupInstall.done ? "next" : "",
            "when": setupInstall.active
        }
    ]
    // ---- the apps (data/apps-catalog.json, scripts/apps-install.py) ----
    property var catalog: ({
            "apps": [],
            "groups": [],
            "personas": [],
            "browsers": []
        })
    property var appStatus: ({})        // id -> {installed, via}; empty until checked
    readonly property bool appsChecked: Object.keys(appStatus).length > 0
    // «Which browser?»: the catalog's browsers and the ones installed some other way
    // (scripts/apps-install.py browsers); current = the default browser now
    property var browserList: []
    property string browserNow: ""
    // the one Mod+B and links will open: the pick, else what is the default now, else Helium
    readonly property string browser: Config.setup.browser || browserNow || "helium"
    function isCatalogBrowser(id) {
        return (catalog.browsers || []).includes(id);
    }
    Process {
        id: browserProbe
        command: ["python3", Quickshell.shellDir + "/scripts/apps-install.py", "browsers"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.browserList = d.list || [];
                    root.browserNow = d.current || "";
                } catch (e) {}
                root.keepBrowser();
            }
        }
    }
    // a replacement: the new one is ticked, the one picked before (a catalog browser) is not
    function pickBrowser(id) {
        const old = browser;
        let list = (Config.setup.apps || []).filter(a => a !== old && a !== id);
        if (isCatalogBrowser(id))
            list.push(id);
        Config.setup.browser = id;
        Config.setup.apps = list;
    }
    // the main browser is always among the apps to install
    function keepBrowser() {
        if (isCatalogBrowser(browser) && !(Config.setup.apps || []).includes(browser))
            Config.setup.apps = (Config.setup.apps || []).concat([browser]);
    }
    FileView {
        path: Quickshell.shellDir + "/data/apps-catalog.json"
        printErrors: false
        onLoaded: {
            try {
                root.catalog = JSON.parse(text());
            } catch (e) {}
            root.seedApps();
        }
    }
    // what the installer's menu picked (scripts/apps-install.py remembers it)
    property var installerPick: null
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/angelos/apps.json"
        printErrors: false
        onLoaded: {
            try {
                root.installerPick = JSON.parse(text()).apps || [];
            } catch (e) {}
            root.seedApps();
        }
    }
    // nothing picked yet: the installer's pick, else «Как у автора» (everything the author has)
    function seedApps() {
        if (Config.setup.persona || (Config.setup.apps || []).length || !catalog.groups.length)
            return;
        if (installerPick && installerPick.length) {
            Config.setup.apps = installerPick.slice();
            return;
        }
        pickPersona("author");
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
    function groupApps(gid) {
        const g = (catalog.groups || []).find(x => x.id === gid);
        return g ? g.apps : [];
    }
    // all of a group on or off
    function toggleGroup(gid, on) {
        const ids = groupApps(gid);
        const rest = (Config.setup.apps || []).filter(a => !ids.includes(a));
        Config.setup.apps = on ? rest.concat(ids) : rest;
        keepBrowser();
    }
    // a persona ticks its apps and keeps the browsers ticked so far (the main one always: the
    // «Which browser?» step); one with groups («Как у автора») ticks whole groups
    function pickPersona(id) {
        const p = catalog.personas.find(x => x.id === id);
        Config.setup.persona = id;
        if (!p)
            return;
        if (p.groups) {
            let ids = [];
            for (const g of p.groups)
                ids = ids.concat(groupApps(g));
            Config.setup.apps = ids;
        } else {
            const browsers = (Config.setup.apps || []).filter(a => isCatalogBrowser(a));
            Config.setup.apps = browsers.concat(p.apps.filter(a => !isCatalogBrowser(a)));
        }
        keepBrowser();
    }
    // the main browser stays ticked: «Which browser?» changes it
    function toggleApp(id, on) {
        if (!on && id === browser)
            return;
        const now = (Config.setup.apps || []).filter(a => a !== id);
        Config.setup.apps = on ? now.concat([id]) : now;
    }
    // ---- the install, inside the wizard: the admin password once (pkexec → the shell's polkit
    // dialog), progress per app, the desktop held until it is over (scripts/apps-install.py --events)
    QtObject {
        id: setupInstall
        property bool active: false     // the «install» step is in the list
        property bool running: false
        property bool done: false
        property var items: []          // [{id, ru, en, icon, installed, via, state: wait|run|done|fail}]
        property string current: ""
        property string status: ""      // what it does right now (the last line of the output)
        property int n: 0
        property int of: 0
        property var failed: []
        property string auth: ""        // why it never started (the password was not given…)
        property bool authWait: false   // pkexec is up: the password is being asked right now
        property var log: []
        property real sub: 0            // how far the app now going is (pacman's "(3/12) installing …")
    }
    readonly property alias installState: setupInstall
    function onInstallEvent(e) {
        setupInstall.authWait = e.ev === "auth";
        if (e.ev === "plan") {
            setupInstall.items = e.items.map(x => Object.assign({}, x, {
                    "state": x.installed ? "done" : "wait"
                }));
        } else if (e.ev === "auth") {
            setupInstall.status = I18n.t("введи пароль администратора", "enter the admin password");
        } else if (e.ev === "step") {
            setupInstall.status = e.text;
        } else if (e.ev === "item") {
            setupInstall.items = setupInstall.items.map(x => x.id !== e.id ? x : Object.assign({}, x, {
                    "state": e.state === "start" ? "run" : e.state
                }));
            setupInstall.n = e.n;
            setupInstall.of = e.of;
            setupInstall.current = e.state === "start" ? e.id : "";
            setupInstall.sub = 0;
        } else if (e.ev === "done") {
            setupInstall.failed = (e.failed || []).concat(e.skipped || []);
            setupInstall.auth = e.auth || "";
            setupInstall.done = true;
            setupInstall.running = false;
            setupInstall.current = "";
            appProbe.running = true;
        }
    }
    Process {
        id: installProc
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("EV ")) {
                    try {
                        root.onInstallEvent(JSON.parse(line.slice(3)));
                    } catch (e) {}
                    return;
                }
                // eslint-disable-next-line no-control-regex
                const clean = line.replace(/\x1b\[[0-9;]*[A-Za-z]/g, "").replace(/\r/g, "").trim();
                if (!clean)
                    return;
                setupInstall.log = setupInstall.log.concat([clean]).slice(-120);
                if (setupInstall.running && !clean.startsWith("»"))
                    setupInstall.status = clean;
                const part = Shell.stepOf(clean, setupInstall.sub);
                if (part >= 0)
                    setupInstall.sub = part;
            }
        }
        onExited: (code, status) => {
            setupInstall.authWait = false;
            if (!setupInstall.done) {
                setupInstall.done = true;
                setupInstall.running = false;
                setupInstall.failed = setupInstall.items.filter(x => x.state !== "done").map(x => x.id);
            }
        }
    }
    function startInstall(ids) {
        setupInstall.active = true;
        setupInstall.running = true;
        setupInstall.done = false;
        setupInstall.failed = [];
        setupInstall.auth = "";
        setupInstall.n = 0;
        setupInstall.sub = 0;
        setupInstall.of = ids.length;
        setupInstall.status = I18n.t("начинаю…", "starting…");
        setupInstall.items = ids.map(i => {
            const a = (catalog.apps || []).find(x => x.id === i) || {};
            return {
                "id": i,
                "ru": a.ru || i,
                "en": a.en || i,
                "icon": a.icon || "package",
                "installed": false,
                "via": "",
                "state": "wait"
            };
        });
        // the shell's own password dialog, if it lost the session's slot to nobody (an agent that
        // was there at login and quit since): asked for again before pkexec looks for one (#62)
        if (!Shell.polkitRegistered && Shell.polkitReregister)
            Shell.polkitReregister();
        installProc.command = ["python3", Quickshell.shellDir + "/scripts/apps-install.py", "install", "--events", "--no-wait", "--browser", browser].concat(ids);
        installProc.running = true;
    }
    // the UI self-test (tests/ui/Driver.qml): the install step fed with events, no process
    function simulateInstall(evs) {
        setupInstall.active = true;
        setupInstall.running = true;
        setupInstall.done = false;
        for (const e of evs)
            onInstallEvent(e);
        step = steps.findIndex(s => s.id === "install");
    }
    // «Ещё раз»: only what didn't make it
    function retryInstall() {
        const again = setupInstall.auth ? appsToInstall : setupInstall.failed.filter(i => (appStatus[i] || {}).via !== "");
        startInstall(again.length ? again : appsToInstall);
    }
    // ---- «What else angelOS can do» (scripts/features.py): game mode, the mouse in games, voice
    // input (installed with the apps: catalog id "voxtype"), and the keys of the rest ----
    property var features: ({})
    Process {
        id: featureProbe
        command: ["python3", Quickshell.shellDir + "/scripts/features.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.features = JSON.parse(text);
                } catch (e) {}
            }
        }
    }
    function refreshFeatures() {
        featureProbe.running = true;
    }
    function setFeature(what, on) {
        if (Shell.dev || Quickshell.env("ANGELOS_TEST") === "1")
            return;
        Quickshell.execDetached(["sh", "-c", 'python3 "$1" set "$2" "$3" >/dev/null; exit 0', "sh", Quickshell.shellDir + "/scripts/features.py", what, on ? "on" : "off"]);
        featureTimer.restart();
    }
    Timer {
        id: featureTimer
        interval: 1500
        onTriggered: root.refreshFeatures()
    }
    // the mouse in games: the rate (0 = as it is) and which mouse; its service runs when it is on
    function setMouseRate(rate) {
        Config.gaming.mouseRate = rate;
        if (rate > 0 && !((features.mouse || {}).enabled))
            setFeature("mouse", true);
    }
    // voice input is a download (1.6 GB): it goes with the apps
    readonly property bool voiceWanted: (Config.setup.apps || []).includes("voxtype")
    function setVoice(on) {
        toggleApp("voxtype", on);
        if (!on && (features.voice || {}).installed)
            setFeature("voice", false);
        else if (on && (features.voice || {}).installed)
            setFeature("voice", true);
    }

    // what is left to install: ticked and not there yet
    readonly property var appsToInstall: (Config.setup.apps || []).filter(a => !(appStatus[a] || {}).installed && (!appsChecked || (appStatus[a] || {}).via))
    function installApps() {
        const ids = appsToInstall;
        if (Shell.dev || Quickshell.env("ANGELOS_TEST") === "1")
            return;
        // the pick is remembered either way (install remembers all it is given, skips what is
        // there): updates bring what the author adds to its groups
        // the browser: made the default once it is there (now, when it is installed already)
        const pick = ["--browser", browser].concat(Config.setup.apps || []);
        if (ids.length === 0) {
            Quickshell.execDetached(["python3", Quickshell.shellDir + "/scripts/apps-install.py", "pick"].concat(pick));
            return false;
        }
        // remembered as picked (updates bring what the author adds to these groups) …
        Quickshell.execDetached(["python3", Quickshell.shellDir + "/scripts/apps-install.py", "pick"].concat(Config.setup.apps || []));
        // … and installed right here, the wizard's last step
        startInstall(ids);
        return true;
    }

    readonly property var steps: stepList.filter(s => s.when === undefined || s.when)
    readonly property int last: steps.length - 1
    readonly property var cur: steps[Math.min(step, last)] || steps[0]
    onLastChanged: step = Math.min(step, last)

    function go(i) {
        step = Math.max(0, Math.min(last, i));
    }
    function next() {
        // the install runs: nothing goes on until it is over
        if (setupInstall.running)
            return;
        if (cur && cur.id === "ready" && !setupInstall.active && installApps()) {
            step = steps.findIndex(s => s.id === "install");
            return;
        }
        if (step < last)
            step++;
        else
            finish();
    }
    function back() {
        if (setupInstall.running || (cur && cur.id === "install"))
            return;
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
    // the first run's «Skip setup»: a plain desktop as it comes — no game, nothing installed, no
    // telemetry; the wizard stays in Settings → Account (16.10: the first run could only be left
    // from a text console)
    function skipAll() {
        if (setupInstall.running)
            return;
        Config.game.enabled = false;
        Config.setup.complete = true;
        if (!Config.setup.telemetry)
            Telemetry.setConsent("no");
        setupInstall.active = false;
        close();
    }
    function finish() {
        if (setupInstall.running)
            return;
        Config.setup.complete = true;
        // the telemetry step passed with neither card picked: that is a no
        if (!Config.setup.telemetry)
            Telemetry.setConsent("no");
        // the tips start where the questions were answered, once the wizard's screens are gone
        tipsOn = tipsAfter ? (host ? host.name : "") || "-" : "";
        if (!setupInstall.active)
            installApps();
        setupInstall.active = false;
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
            Shell.introOpen = false;
            if (Shell.setupOpen || !Config.setup.complete)
                root.later();
        }
        function onSetupOpenChanged() {
            if (Shell.setupOpen) {
                githubLogin.refresh();
                touchpadProbe.running = true;
                appProbe.running = true;
                browserProbe.running = true;
                featureProbe.running = true;
            }
            root.pickHost();
        }
        function onIntroOpenChanged() {
            root.pickHost();
        }
    }

    // the questions (and the update's intro) on the screen in use when they open
    function pickHost() {
        if (Shell.setupLocked && hostName === "")
            hostName = Shell.focusedScreen ? Shell.focusedScreen.name : "";
        else if (!Shell.setupLocked)
            hostName = "";
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
