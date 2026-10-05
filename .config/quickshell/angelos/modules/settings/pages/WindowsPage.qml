import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

PxPage {
    id: page
    readonly property var openApps: {
        const seen = {};
        for (const w of Niri.windows)
            if (w.app_id && !seen[w.app_id])
                seen[w.app_id] = w;
        return Object.keys(seen).sort().map(k => seen[k]);
    }
    property string customPreset: ""

    heading: I18n.t("Окна", "Windows")
    subtitle: I18n.t("niri располагает окна в прокручиваемых колонках. Изменения сохраняются с бэкапом и проверкой.", "niri arranges windows in scrolling columns. Changes are backed up and validated.")
    PxGroup {
        name: "closing-windows"
        width: parent.width
        title: I18n.t("Закрытие окон", "Closing windows")
        advanced: true
        icon: "close"
        SettingRow {
            id: rightRow
            preview: "TaskClose"
            label: I18n.t("ПКМ по кнопке окна на панели", "Right-click a window button")
            hint: ({
                    "menu": I18n.t("меню: во весь экран, плавающее, на другой стол или монитор, закрыть, завершить процесс", "A menu: fullscreen, floating, another desk or monitor, close, end task"),
                    "close": I18n.t("закрывает окно сразу, без вопросов", "Closes the window at once"),
                    "none": I18n.t("ничего не делает", "Does nothing")
                })[Config.bar.taskRightClick] || ""
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Меню", "Menu"),
                        "value": "menu"
                    },
                    {
                        "label": I18n.t("Закрыть", "Close"),
                        "value": "close"
                    },
                    {
                        "label": I18n.t("Ничего", "Nothing"),
                        "value": "none"
                    }
                ]
                currentValue: Config.bar.taskRightClick || "menu"
                onActivated: v => {
                    Config.bar.taskRightClick = v;
                    rightRow.show(v, ({
                            "menu": I18n.t("меню", "menu"),
                            "close": I18n.t("закрыть сразу", "close at once"),
                            "none": I18n.t("ничего", "nothing")
                        })[v]);
                }
            }
        }
        SettingRow {
            id: middleRow
            preview: "TaskClose"
            label: I18n.t("Средняя кнопка закрывает", "Middle click closes")
            hint: I18n.t("колёсиком по кнопке окна на панели, как в браузере по вкладке", "Click the wheel on a window button, like on a browser tab")
            PxToggle {
                checked: Config.bar.taskMiddleClose
                onToggled: c => {
                    Config.bar.taskMiddleClose = c;
                    middleRow.show(c ? "middle-on" : "middle-off", c ? I18n.t("закрывает", "closes") : I18n.t("не закрывает", "does not close"));
                }
            }
        }
        SettingRow {
            id: hoverRow
            preview: "TaskClose"
            label: I18n.t("Крестик при наведении", "× on hover")
            hint: I18n.t("на кнопке окна под курсором появляется крестик", "A close button appears on the hovered window button")
            PxToggle {
                checked: Config.bar.taskHoverClose
                onToggled: c => {
                    Config.bar.taskHoverClose = c;
                    hoverRow.show(c ? "hover-on" : "hover-off", c ? I18n.t("крестик есть", "with ×") : I18n.t("без крестика", "no ×"));
                }
            }
        }
    }

    // window decorations: angelOS title bars (modules/decor), GTK's buttons (scripts/gtk-live.py), browsers
    PxGroup {
        name: "window-decorations"
        id: decorGroup
        width: parent.width
        title: I18n.t("Декорации окон", "Window decorations")
        icon: "window"
        readonly property var floatingApps: {
            const seen = {};
            for (const w of Niri.windows)
                if (w.is_floating && w.app_id && !seen[w.app_id])
                    seen[w.app_id] = w;
            return Object.keys(seen).sort();
        }
        function skipped(id) {
            const low = String(id).toLowerCase();
            return GoldenGate.decorSkip.some(k => {
                const s = String(k).toLowerCase();
                return s.endsWith("*") ? low.startsWith(s.slice(0, -1)) : low === s;
            });
        }
        SettingRow {
            label: I18n.t("Заголовки angelOS", "angelOS title bars")
            hint: I18n.t("над плавающими окнами без своей рамки (niri её не рисует): значок, название, «развернуть» и «закрыть», как у настроек. Тяни — окно едет, двойной клик — развернуть, средняя кнопка — закрыть. В аду — обсидиан и пламя", "Over floating windows without a frame of their own (niri draws none): icon, title, maximize and close, like Settings. Drag to move, double-click to maximize, middle-click to close. In hell: obsidian and flames")
            PxToggle {
                checked: GoldenGate.titlebars
                onToggled: c => GoldenGate.setTitlebars(c)
            }
        }
        SettingRow {
            visible: GoldenGate.titlebars
            label: I18n.t("Плавающие окна сейчас", "Floating windows now")
            hint: I18n.t("галочка — заголовок angelOS; сними у программ, что рисуют свой (браузеры, GTK4, Steam уже сняты)", "Checked: an angelOS title bar; uncheck apps that draw their own (browsers, GTK4, Steam already are)")
            Column {
                width: parent.width
                spacing: Theme.u * 2
                PxText {
                    visible: decorGroup.floatingApps.length === 0
                    text: I18n.t("нет плавающих окон", "no floating windows")
                    dim: true
                }
                Flow {
                    width: parent.width
                    spacing: Theme.u * 4
                    Repeater {
                        model: decorGroup.floatingApps
                        PxCheck {
                            required property string modelData
                            text: modelData
                            checked: !decorGroup.skipped(modelData)
                            onToggled: c => {
                                const low = modelData.toLowerCase();
                                const list = GoldenGate.decorSkip.filter(k => String(k).toLowerCase() !== low);
                                if (!c)
                                    list.push(modelData);
                                GoldenGate.setDecorSkip(list);
                            }
                        }
                    }
                }
            }
        }
        SettingRow {
            label: I18n.t("Кнопки GTK-окон как в angelOS", "GTK window buttons like angelOS's")
            hint: (Angel.hellShown ? I18n.t("пиксельные «развернуть» и «закрыть», шапка цвета меню; в аду — обсидиан и кровь. ", "Pixel maximize and close, the header in the menu colour; obsidian and blood in hell. ") : I18n.t("пиксельные «развернуть» и «закрыть», шапка цвета меню. ", "Pixel maximize and close, the header in the menu colour. ")) + I18n.t("GTK 3 и Helium в режиме «GTK» меняются сразу (своя тема angelOS поверх adw-gtk3), GTK 4 — при следующем запуске программы", "GTK 3 and Helium in its GTK mode change at once (angelOS's own theme over adw-gtk3), GTK 4 the next time an app starts")
            PxToggle {
                checked: Config.decor.gtkButtons
                onToggled: c => Config.decor.gtkButtons = c
            }
        }
        SettingRow {
            visible: Config.decor.gtkButtons
            label: I18n.t("Кнопки в заголовке", "Title bar buttons")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Развернуть, закрыть", "Maximize, close"),
                        "value": "maximize,close"
                    },
                    {
                        "label": I18n.t("+ свернуть", "+ minimize"),
                        "value": "minimize,maximize,close"
                    },
                    {
                        "label": I18n.t("Только закрыть", "Close only"),
                        "value": "close"
                    }
                ]
                currentValue: Config.decor.gtkLayout
                onActivated: v => Config.decor.gtkLayout = v
            }
        }
        // browsers (scripts/browser-theme.py): Helium and Chromium follow GTK live (their theme
        // "GTK") or read a theme extension at start; Firefox follows GTK by itself and gets the
        // palette from userChrome.css. Profiles change only by these buttons, with a copy and undo
        Repeater {
            model: browserStatus.list
            SettingRow {
                id: browserRow
                required property var modelData
                readonly property var b: modelData
                readonly property bool chromium: b.kind === "chromium"
                readonly property bool asking: browserAct.ask === b.id
                readonly property string failed: browserAct.errorFor === b.id ? browserAct.error : ""
                property bool copied: false
                label: b.name
                hint: {
                    const n = b.name;
                    let s;
                    if (asking)
                        s = I18n.t(n + " открыт, а тему он читает только при запуске. «Перезапустить сейчас» — закрою и открою снова, вкладки вернутся. «Когда закрою» — переключу сама, как только закроешь", n + " is open, and it reads its theme only at start. “Restart now”: I close it and open it again, the tabs come back. “When I close it”: I switch it myself as soon as you do");
                    else if (!b.profile)
                        s = I18n.t("запусти " + n + " один раз — профиля ещё нет", "Start " + n + " once: there's no profile yet");
                    else if (!chromium)
                        s = (b.static ? I18n.t("тема angelOS включена (userChrome.css): панели и вкладки в цветах рая или ада, Firefox читает их при запуске." + (b.running ? " Перезапусти Firefox, чтобы увидеть" : ""), "angelOS's theme is on (userChrome.css): toolbars and tabs in heaven's or hell's colours, read when Firefox starts." + (b.running ? " Restart Firefox to see it" : "")) : I18n.t("«Включить тему angelOS» — панели и вкладки Firefox в цветах рая или ада (userChrome.css в профиле, с копией и откатом; читается при запуске). Меню и кнопки окна и так следуют GTK на лету", "“Turn on angelOS's theme”: Firefox's toolbars and tabs in heaven's or hell's colours (userChrome.css in the profile, with a copy and undo; read at start). Menus and window buttons follow GTK live anyway")) + (b.live ? "" : I18n.t(". Сейчас у Firefox своя тема: чтобы он следовал GTK — about:addons → Темы → «Системная тема — авто»", ". Firefox has a theme of its own now: to follow GTK, about:addons → Themes → “System theme — auto”"));
                    else if (b.live)
                        s = Angel.hellShown ? I18n.t("в режиме «GTK»: цвета и кнопки окна angelOS, рай и ад — сразу", "In GTK mode: angelOS colours and window buttons, heaven and hell at once") : I18n.t("в режиме «GTK»: цвета и кнопки окна angelOS — сразу", "In GTK mode: angelOS colours and window buttons at once");
                    else if (b.pending)
                        s = I18n.t("включу, как закроешь " + n + ". Или «Перезапустить сейчас» — вкладки вернутся", "On as soon as you close " + n + ". Or “Restart now”: the tabs come back");
                    else if (b.static)
                        s = I18n.t("тема-расширение angelOS загружена: цвета подхватываются при каждом запуске. Чтобы рай и ад менялись на лету — «Следовать теме angelOS»", "The angelOS theme extension is loaded: its colours apply each time it starts. For heaven and hell to switch live: “Follow angelOS's theme”");
                    else
                        s = I18n.t("«Следовать теме angelOS» — " + n + " меняет цвета вместе с системой (его тема «GTK»; профиль правлю только по кнопке, с копией и откатом). Или тема-расширение: " + (b.id === "helium" ? "helium" : "chrome") + "://extensions → Режим разработчика → «Загрузить распакованное» → папка ниже (цвета обновляются при запуске)", "“Follow angelOS's theme”: " + n + " changes colours with the system (its “GTK” theme; I edit the profile only by this button, with a copy and undo). Or the theme extension: " + (b.id === "helium" ? "helium" : "chrome") + "://extensions → Developer mode → “Load unpacked” → the folder below (colours refresh at start)");
                    return failed ? s + I18n.t(". Не вышло: ", ". Didn't work: ") + failed : s;
                }
                Column {
                    width: parent.width
                    spacing: Theme.u * 2
                    PxText {
                        visible: browserRow.chromium
                        width: parent.width
                        elide: Text.ElideMiddle
                        text: browserRow.b.theme || ""
                        kind: "tiny"
                        dim: true
                    }
                    Flow {
                        width: parent.width
                        spacing: Theme.u * 2
                        PxButton {
                            visible: !browserRow.asking && !!browserRow.b.profile && (browserRow.chromium ? !browserRow.b.live && !browserRow.b.pending : !browserRow.b.static)
                            compact: true
                            accent: true
                            icon: "sparkle"
                            text: browserRow.chromium ? I18n.t("Следовать теме angelOS", "Follow angelOS's theme") : I18n.t("Включить тему angelOS", "Turn on angelOS's theme")
                            onClicked: browserAct.go(browserRow.b.id, "apply", "")
                        }
                        PxButton {
                            visible: browserRow.asking || (browserRow.chromium && browserRow.b.pending)
                            compact: true
                            accent: true
                            icon: "refresh"
                            text: I18n.t("Перезапустить сейчас", "Restart now")
                            onClicked: browserAct.go(browserRow.b.id, browserRow.asking ? browserAct.askVerb : "apply", "restart")
                        }
                        PxButton {
                            visible: browserRow.asking
                            compact: true
                            icon: "check"
                            text: I18n.t("Когда закрою", "When I close it")
                            onClicked: browserAct.go(browserRow.b.id, browserAct.askVerb, "wait")
                        }
                        PxButton {
                            visible: browserRow.asking
                            compact: true
                            flat: true
                            icon: "close"
                            text: I18n.t("Отмена", "Cancel")
                            onClicked: browserAct.ask = ""
                        }
                        PxButton {
                            visible: !browserRow.asking && (browserRow.b.undo || (!browserRow.chromium && browserRow.b.static))
                            compact: true
                            flat: true
                            icon: "arrowLeft"
                            text: I18n.t("Вернуть как было", "Put it back")
                            onClicked: browserAct.go(browserRow.b.id, "revert", "")
                        }
                        PxButton {
                            visible: browserRow.chromium && !browserRow.asking
                            compact: true
                            icon: "folder"
                            text: I18n.t("Папка темы", "Theme folder")
                            onClicked: Quickshell.execDetached(["xdg-open", browserRow.b.theme || ""])
                        }
                        PxButton {
                            visible: browserRow.chromium && !browserRow.asking
                            compact: true
                            icon: "document"
                            text: browserRow.copied ? I18n.t("Скопировано ♡", "Copied ♡") : I18n.t("Копировать путь", "Copy path")
                            onClicked: {
                                Quickshell.execDetached(["wl-copy", browserRow.b.theme || ""]);
                                browserRow.copied = true;
                            }
                        }
                        PxButton {
                            visible: !browserRow.asking
                            compact: true
                            flat: true
                            icon: "refresh"
                            text: I18n.t("Проверить", "Check")
                            onClicked: browserStatus.running = true
                        }
                    }
                }
            }
        }
        Process {
            id: browserStatus
            property var list: []
            running: true
            command: ["python3", Quickshell.shellDir + "/scripts/browser-theme.py", "status"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        browserStatus.list = JSON.parse(text).browsers || [];
                    } catch (e) {}
                }
            }
        }
        Process {
            id: browserAct
            property string ask: ""         // an open browser: restart it now, or wait until it closes?
            property string askVerb: ""
            property string lastId: ""
            property string lastVerb: ""
            property string error: ""
            property string errorFor: ""
            function go(id, verb, mode) {
                if (running)
                    return;
                ask = "";
                error = "";
                lastId = id;
                lastVerb = verb;
                command = ["python3", Quickshell.shellDir + "/scripts/browser-theme.py", verb, id].concat(mode ? ["--" + mode] : []);
                running = true;
            }
            stdout: StdioCollector {
                onStreamFinished: {
                    let r = {};
                    try {
                        r = JSON.parse(text);
                    } catch (e) {}
                    if (r.ok && r.running && !r.done && !r.pending) {
                        browserAct.ask = browserAct.lastId;
                        browserAct.askVerb = browserAct.lastVerb;
                    }
                    browserAct.error = r.ok === false ? String(r.error || "") : "";
                    browserAct.errorFor = browserAct.lastId;
                    browserStatus.running = true;
                }
            }
        }
        // Telegram (scripts/telegram-theme.py): applied once, then it follows the file on its own
        SettingRow {
            id: telegramRow
            property bool copied: false
            visible: telegramStatus.info.installed === true
            label: "Telegram"
            hint: I18n.t("тема angelOS для Telegram: рай, ад, светлая и тёмная — на лету. Один раз: «Скопировать путь» → в Telegram Настройки → Настройки чатов → ⋮ → «Выбрать из файла» → Ctrl+L, Ctrl+V, Enter → «Оставить». Дальше Telegram сам подхватывает каждую смену темы. Авто-ночной режим в Telegram лучше выключить — иначе он перескочит на свою ночную тему", "angelOS's theme for Telegram: heaven, hell, light and dark — on the fly. Once: “Copy the path” → in Telegram Settings → Chat Settings → ⋮ → “Choose from file” → Ctrl+L, Ctrl+V, Enter → “Keep changes”. After that Telegram picks up every theme change by itself. Better switch Telegram's auto-night mode off, or it jumps to its own night theme")
            Flow {
                width: parent.width
                spacing: Theme.u * 2
                PxButton {
                    compact: true
                    accent: !telegramStatus.info.asked
                    icon: "sparkle"
                    text: telegramRow.copied ? I18n.t("Путь скопирован ♡", "Path copied ♡") : I18n.t("Скопировать путь темы", "Copy the theme's path")
                    onClicked: {
                        telegramApply.running = true;
                        telegramRow.copied = true;
                    }
                }
                PxButton {
                    compact: true
                    icon: "folder"
                    text: I18n.t("Папка темы", "Theme folder")
                    onClicked: Quickshell.execDetached(["xdg-open", String(telegramStatus.info.theme || "").replace(/\/[^\/]*$/, "")])
                }
            }
            Process {
                id: telegramApply
                command: ["python3", Quickshell.shellDir + "/scripts/telegram-theme.py", "apply"]
                onExited: telegramStatus.running = true
            }
            Process {
                id: telegramStatus
                property var info: ({})
                running: true
                command: ["python3", Quickshell.shellDir + "/scripts/telegram-theme.py", "status"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            telegramStatus.info = JSON.parse(text);
                        } catch (e) {}
                    }
                }
            }
        }
        // Steam (scripts/steam-theme.py): a Millennium theme that follows on its own; only
        // with Millennium there (angelOS installs neither Steam nor Millennium)
        SettingRow {
            id: steamRow
            property string said: ""
            visible: steamStatus.info.millennium === true
            label: "Steam"
            hint: I18n.t("тема angelOS для Steam через Millennium: рай, ад и каждый круг, светлая и тёмная — на лету, в открытом Steam тоже. Один раз выбери её: Steam → Millennium → Темы → angelOS, или закрой Steam и нажми «Сделать активной». Магазин и сообщество — чужие сайты: у них только рамка и выделение в цветах темы", "angelOS's theme for Steam through Millennium: heaven, hell and every circle, light and dark — on the fly, in an open Steam too. Pick it once: Steam → Millennium → Themes → angelOS, or close Steam and press “Make it active”. The store and the community are other sites: only their frame and selection take the theme's colours")
            Flow {
                width: parent.width
                spacing: Theme.u * 2
                PxButton {
                    compact: true
                    accent: !steamStatus.info.active
                    icon: "sparkle"
                    text: steamStatus.info.active ? I18n.t("Активна ♡", "Active ♡") : steamRow.said || I18n.t("Сделать активной", "Make it active")
                    onClicked: if (!steamStatus.info.active)
                        steamApply.running = true
                }
                PxButton {
                    compact: true
                    icon: "folder"
                    text: I18n.t("Папка темы", "Theme folder")
                    onClicked: Quickshell.execDetached(["xdg-open", String((steamStatus.info.installed || [])[0] || steamStatus.info.theme || "")])
                }
            }
            Process {
                id: steamApply
                command: ["python3", Quickshell.shellDir + "/scripts/steam-theme.py", "apply"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            const r = JSON.parse(text);
                            steamRow.said = r.ok ? "" : r.error === "steam running" ? I18n.t("Сначала закрой Steam", "Close Steam first") : I18n.t("Не вышло — выбери в Steam", "Didn't work — pick it in Steam");
                        } catch (e) {}
                        steamStatus.running = true;
                    }
                }
            }
            Process {
                id: steamStatus
                property var info: ({})
                running: true
                command: ["python3", Quickshell.shellDir + "/scripts/steam-theme.py", "status"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            steamStatus.info = JSON.parse(text);
                        } catch (e) {}
                    }
                }
            }
        }
    }
    PxGroup {
        name: "alt-tab"
        width: parent.width
        title: "Alt+Tab"
        advanced: true
        icon: "layers"
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Держи Alt и жми Tab — окна по порядку недавнего использования; отпусти Alt, чтобы переключиться. Shift+Tab и стрелки — назад, Esc — отмена, Delete — закрыть окно. Быстрое Alt+Tab просто прыгает на прошлое окно.", "Hold Alt and press Tab: windows in most-recently-used order; let go of Alt to switch. Shift+Tab and the arrows go back, Esc cancels, Delete closes a window. A quick Alt+Tab just jumps to the previous window.")
        }
        Grid {
            width: parent.width
            columns: Math.max(1, Math.floor(width / (Theme.u * 110)))
            spacing: Theme.u * 3
            Repeater {
                model: AltTab.styles
                PxBox {
                    id: atCard
                    required property var modelData
                    readonly property bool current: AltTab.style === modelData.id
                    width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                    height: atCol.implicitHeight + Theme.u * 8
                    sunken: current
                    color: current ? Theme.mix(Theme.face, Theme.accent, 0.3) : atMouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.1) : Theme.face
                    Column {
                        id: atCol
                        x: Theme.u * 4
                        y: Theme.u * 4
                        width: parent.width - Theme.u * 8
                        spacing: Theme.u
                        PxText {
                            text: (atCard.current ? "♡ " : "") + atCard.modelData.label
                            font.bold: true
                        }
                        PxText {
                            width: parent.width
                            text: atCard.modelData.hint
                            kind: "tiny"
                            dim: true
                            wrapMode: Text.Wrap
                        }
                    }
                    MouseArea {
                        id: atMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Config.alttab.style = atCard.modelData.id;
                            if (atCard.modelData.id !== "niri")
                                AltTab.tryIt();
                        }
                    }
                }
            }
        }
        SettingRow {
            visible: AltTab.ours
            label: I18n.t("Какие окна", "Which windows")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Все", "All"),
                        "value": "all"
                    },
                    {
                        "label": I18n.t("Этот монитор", "This monitor"),
                        "value": "output"
                    },
                    {
                        "label": I18n.t("Этот стол", "This desk"),
                        "value": "workspace"
                    }
                ]
                currentValue: Config.alttab.scope
                onActivated: v => Config.alttab.scope = v
            }
        }
        SettingRow {
            visible: AltTab.ours
            label: I18n.t("Подписи", "Titles")
            PxToggle {
                checked: Config.alttab.titles
                onToggled: c => Config.alttab.titles = c
            }
        }
        SettingRow {
            visible: AltTab.ours
            label: I18n.t("Показывать через", "Show after")
            hint: I18n.t("пока Alt держится дольше — иначе просто переключает, без окошка", "only while Alt is held longer, otherwise it just switches")
            PxSlider {
                width: parent.width
                from: 0
                to: 500
                stepSize: 10
                suffix: I18n.t(" мс", " ms")
                value: Config.alttab.delayMs
                onReleased: v => Config.alttab.delayMs = v
            }
        }
        Row {
            spacing: Theme.u * 3
            visible: AltTab.ours
            PxButton {
                compact: true
                icon: "play"
                text: I18n.t("Показать", "Try it")
                onClicked: AltTab.tryIt()
            }
            PxText {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.u * 200
                wrapMode: Text.Wrap
                kind: "tiny"
                color: AltTab.watcherStatus === "noperm" ? Theme.danger : Theme.textDim
                text: AltTab.watcherStatus === "noperm" ? I18n.t("нет доступа к клавиатуре (группа input): отпускание Alt ловится только самим окошком — если оно не успело открыться, выбери окно Enter или кликом", "No keyboard access (the input group): only the switcher itself sees Alt being let go — if it was not open yet, pick with Enter or a click") : AltTab.log
            }
        }
    }
    PxGroup {
        name: "window-animations"
        width: parent.width
        title: I18n.t("Анимации окон", "Window animations")
        advanced: true
        icon: "sparkle"
        Component.onCompleted: WindowAnim.refresh()
        Repeater {
            model: [
                {
                    "kind": "open",
                    "label": I18n.t("Анимация открытия", "Open animation"),
                    "speed": I18n.t("Скорость открытия", "Open speed"),
                    "preview": "OpenFx"
                },
                {
                    "kind": "close",
                    "label": I18n.t("Анимация закрытия", "Close animation"),
                    "speed": I18n.t("Скорость закрытия", "Close speed"),
                    "preview": "CloseFx"
                }
            ]
            Column {
                id: animBlock
                required property var modelData
                readonly property string kind: modelData.kind
                readonly property string currentId: animBlock.kind === "open" ? WindowAnim.open : WindowAnim.close
                width: parent.width
                spacing: Theme.u * 2
                SettingRow {
                    id: animRow
                    preview: animBlock.modelData.preview
                    label: animBlock.modelData.label
                    hint: {
                        const s = WindowAnim.styleOf(animBlock.kind, animBlock.currentId);
                        return s ? s.hint : animBlock.currentId === "custom" ? I18n.t("свой шейдер в cfg/animation.kdl — выбери вариант, чтобы заменить", "A hand-written shader in cfg/animation.kdl — pick one to replace it") : "";
                    }
                    PxCombo {
                        width: parent.width
                        enabled: !WindowAnim.busy
                        model: WindowAnim.styles(animBlock.kind).map(s => ({
                                    "label": s.label,
                                    "value": s.id
                                }))
                        currentValue: animBlock.currentId
                        placeholder: animBlock.currentId === "custom" ? I18n.t("свой шейдер", "custom shader") : "—"
                        onActivated: v => {
                            WindowAnim.pick(animBlock.kind, v);
                            const s = WindowAnim.styleOf(animBlock.kind, v);
                            animRow.show(v, s ? s.label : v);
                        }
                    }
                }
                SettingRow {
                    label: animBlock.modelData.speed
                    hint: I18n.t("×2 — вдвое быстрее, ×0.5 — вдвое медленнее; niri ещё умножает всё на свой slowdown", "×2 is twice as fast, ×0.5 half as fast; niri also stretches everything by its slowdown")
                    enabled: !WindowAnim.busy && animBlock.currentId !== "off" && animBlock.currentId !== "custom" && animBlock.currentId !== ""
                    opacity: enabled ? 1 : 0.5
                    PxSlider {
                        width: parent.width
                        from: 25
                        to: 300
                        stepSize: 5
                        valueScale: 0.01
                        decimals: 2
                        suffix: "×"
                        value: Math.round((animBlock.kind === "open" ? WindowAnim.openSpeed : WindowAnim.closeSpeed) * 100)
                        onReleased: v => WindowAnim.setSpeed(animBlock.kind, v / 100)
                    }
                }
            }
        }
        Row {
            spacing: Theme.u * 3
            PxButton {
                compact: true
                icon: "play"
                text: I18n.t("На настоящем окне", "On a real window")
                onClicked: WindowAnim.preview()
            }
            PxText {
                anchors.verticalCenter: parent.verticalCenter
                text: WindowAnim.log
                kind: "tiny"
                dim: true
                width: Theme.u * 200
                elide: Text.ElideMiddle
            }
        }
    }
    PxGroup {
        name: "layout"
        width: parent.width
        title: I18n.t("Размещение", "Layout")
        advanced: true
        icon: "window"
        enabled: !WindowConfig.busy
        SettingRow {
            label: I18n.t("Центрировать активную колонку", "Center the focused column")
            PxCombo {
                model: [
                    {
                        label: I18n.t("Никогда", "Never"),
                        value: "never"
                    },
                    {
                        label: I18n.t("Всегда", "Always"),
                        value: "always"
                    },
                    {
                        label: I18n.t("При переполнении", "On overflow"),
                        value: "on-overflow"
                    }
                ]
                currentValue: WindowConfig.center
                onActivated: v => WindowConfig.save({
                        center: v
                    })
            }
        }
        SettingRow {
            label: I18n.t("Отступ между окнами", "Window gap")
            PxSlider {
                width: parent.width
                from: 0
                to: 64
                stepSize: 1
                value: WindowConfig.gaps
                suffix: " px"
                onReleased: v => WindowConfig.save({
                        gaps: v
                    })
            }
        }
        SettingRow {
            label: I18n.t("Фокус следует за мышью", "Focus follows the mouse")
            PxToggle {
                checked: InputConfig.focusFollowsMouse
                onToggled: c => InputConfig.save({
                        focusFollowsMouse: c
                    })
            }
        }
    }
    PxGroup {
        name: "window-widths"
        width: parent.width
        title: I18n.t("Ширина окон", "Window widths")
        advanced: true
        icon: "layers"
        enabled: !WindowConfig.busy

        SettingRow {
            label: I18n.t("Новые окна", "New windows")
            hint: I18n.t("ширина колонки при открытии", "column width when a window opens")
            Flow {
                width: parent.width
                spacing: Theme.u * 2
                Repeater {
                    model: WindowConfig.choices
                    PxButton {
                        required property var modelData
                        compact: true
                        text: modelData.label
                        checked: WindowConfig.defaultWidth === modelData.value
                        onClicked: WindowConfig.save({
                            "defaultWidth": modelData.value
                        })
                    }
                }
                PxField {
                    width: Theme.u * 40
                    placeholder: "px"
                    onAccepted: if (parseInt(text) > 100)
                        WindowConfig.save({
                            "defaultWidth": "fixed " + parseInt(text)
                        })
                }
            }
        }
        SettingRow {
            label: I18n.t("Пресеты Mod+R", "Mod+R presets")
            hint: I18n.t("по ним переключается ширина колонки; ✕ — убрать", "Mod+R cycles through these; ✕ removes one")
            Flow {
                width: parent.width
                spacing: Theme.u * 2
                Repeater {
                    model: WindowConfig.presets
                    PxButton {
                        required property string modelData
                        required property int index
                        compact: true
                        text: WindowConfig.label(modelData) + "  ✕"
                        enabled: WindowConfig.presets.length > 1
                        onClicked: WindowConfig.save({
                            "presets": WindowConfig.presets.filter((p, i) => i !== index)
                        })
                    }
                }
                PxCombo {
                    width: Theme.u * 60
                    placeholder: I18n.t("+ добавить", "+ add")
                    model: WindowConfig.choices.filter(c => !WindowConfig.presets.includes(c.value))
                    onActivated: v => {
                        const order = w => w.startsWith("fixed") ? 10 + parseFloat(w.split(" ")[1]) / 10000 : parseFloat(w.split(" ")[1]);
                        WindowConfig.save({
                            "presets": WindowConfig.presets.concat([v]).sort((a, b) => order(a) - order(b))
                        });
                    }
                }
            }
        }

        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            text: I18n.t("Открытые приложения — своя ширина для каждого. Применяется сразу к открытым окнам и запоминается для новых.", "Open apps — a width of their own. Applies to open windows right away and is remembered for new ones.")
            dim: true
        }
        Repeater {
            model: page.openApps
            SettingRow {
                id: appRow
                required property var modelData
                readonly property string appId: modelData.app_id
                label: DesktopEntries.heuristicLookup(appId) ? DesktopEntries.heuristicLookup(appId).name : appId
                hint: appId
                Row {
                    spacing: Theme.u * 3
                    AppIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        appId: appRow.appId
                        size: Theme.u * 10
                    }
                    PxCombo {
                        width: Theme.u * 80
                        model: [
                            {
                                "label": I18n.t("по умолчанию", "default"),
                                "value": ""
                            }
                        ].concat(WindowConfig.choices)
                        currentValue: WindowConfig.apps[appRow.appId] || ""
                        onActivated: v => WindowConfig.setAppWidth(appRow.appId, v)
                    }
                    PxField {
                        width: Theme.u * 34
                        placeholder: "px"
                        onAccepted: if (parseInt(text) > 100)
                            WindowConfig.setAppWidth(appRow.appId, "fixed " + parseInt(text))
                    }
                }
            }
        }
    }

    PxGroup {
        name: "window-menu-experimental"
        title: I18n.t("Меню окна (эксперимент)", "Window menu (experimental)")
        advanced: true
        icon: "layers"
        width: parent.width
        SettingRow {
            label: I18n.t("Кнопки плавающего/развёртывания", "Float and maximize buttons")
            hint: I18n.t("в правом клике по окну в трее добавить «Сделать плавающим / Вернуть в сетку» и «Развернуть до краёв». По умолчанию выключено — большинству хватает полноэкранного режима и перетаскивания в плавающее из тайла", "Add “Make floating / Back to tiling” and “Maximize to edges” to the right-click window menu in the tray. Off by default — most people only need fullscreen and dragging a tile into floating mode")
            PxToggle {
                checked: Config.windows && Config.windows.floatButtons === true
                onToggled: c => Config.windows.floatButtons = c
            }
        }
    }

    PxText {
        width: parent.width
        wrapMode: Text.Wrap
        text: WindowConfig.log
        dim: true
    }
}
