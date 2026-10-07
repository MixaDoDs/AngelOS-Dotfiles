pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import "../../../widgets/Logos.js" as Logos

PxPage {
    id: systemPage
    heading: "System"

    PxGroup {
        name: "rendering"
        title: I18n.t("Движок отрисовки", "Renderer")
        advanced: true
        icon: "monitor"
        width: parent.width
        Component.onCompleted: Renderer.refresh()
        SettingRow {
            label: I18n.t("Движок", "Renderer")
            hint: Renderer.mode === "vulkan" ? I18n.t("Vulkan: плавно на NVIDIA без сборки, но менее обкатан в Quickshell", "Vulkan: smooth on NVIDIA without building anything, but less tested in Quickshell") : Renderer.mode === "opengl" ? I18n.t("обычный Qt; на NVIDIA анимации упираются в ~60 кадров и дёргаются", "stock Qt; on NVIDIA animations are capped near 60 fps and stutter") : I18n.t("OpenGL + исправленный плагин Qt (если он собран) — рекомендуется", "OpenGL + the fixed Qt plugin (when built) — recommended")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Авто", "Auto"),
                        "value": "auto"
                    },
                    {
                        "label": "Vulkan",
                        "value": "vulkan"
                    },
                    {
                        "label": I18n.t("Обычный", "Stock"),
                        "value": "opengl"
                    }
                ]
                currentValue: Renderer.mode
                onActivated: v => Renderer.setMode(v)
            }
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Сейчас: ", "Now: ") + ({
                    "patched": I18n.t("OpenGL, многопоточная отрисовка (исправленный плагин)", "OpenGL, threaded rendering (fixed plugin)"),
                    "vulkan": "Vulkan",
                    "stock": I18n.t("стандартный OpenGL", "stock OpenGL")
                })[Renderer.active] + I18n.t(". Новый режим включится после перезапуска оболочки.", ". A new mode applies after the shell restarts.")
        }
        SettingRow {
            visible: !!Renderer.fix.qt
            label: I18n.t("Исправление Qt для NVIDIA", "Qt fix for NVIDIA")
            hint: "Qt " + (Renderer.fix.qt || "?") + " · " + (!Renderer.fix.needed ? I18n.t("не нужно: в этой версии Qt уже исправлено", "not needed: this Qt already has it") : Renderer.fix.built ? I18n.t("собрано ♡", "built ♡") : I18n.t("не собрано", "not built")) + (Renderer.fix.nvidia ? "" : I18n.t(" · видеокарта не NVIDIA", " · not an NVIDIA GPU"))
            Row {
                spacing: Theme.u * 3
                PxButton {
                    visible: !!Renderer.fix.needed
                    icon: "gear"
                    enabled: !Renderer.building
                    text: Renderer.building ? I18n.t("собираю…", "building…") : Renderer.fix.built ? I18n.t("Пересобрать", "Rebuild") : I18n.t("Собрать", "Build")
                    onClicked: Renderer.build()
                }
                PxButton {
                    icon: "power"
                    text: I18n.t("Перезапустить оболочку", "Restart the shell")
                    onClicked: Quickshell.execDetached([Quickshell.shellDir + "/bin/angelos", "restart"])
                }
            }
        }
        PxText {
            visible: Renderer.log.length > 0
            width: parent.width
            wrapMode: Text.WrapAnywhere
            kind: "tiny"
            dim: true
            text: Renderer.log.join("\n")
        }
    }

    PxGroup {
        name: "power"
        visible: SystemInfo.powerProfile !== ""
        title: I18n.t("Питание", "Power")
        icon: "power"
        width: parent.width
        SettingRow {
            label: I18n.t("Профиль", "Profile")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Экономия", "Power saver"),
                        "value": "power-saver"
                    },
                    {
                        "label": I18n.t("Баланс", "Balanced"),
                        "value": "balanced"
                    },
                    {
                        "label": I18n.t("Мощность", "Performance"),
                        "value": "performance"
                    }
                ]
                currentValue: SystemInfo.powerProfile
                onActivated: v => SystemInfo.setPowerProfile(v)
            }
        }
    }

    PxGroup {
        name: "this-computer"
        title: I18n.t("Этот компьютер", "This computer")
        icon: "chip"
        width: parent.width

        Row {
            spacing: Theme.u * 8
            width: parent.width
            PxIcon {
                name: "ghost"
                pixel: Theme.u * 5
            }
            Grid {
                columns: 2
                columnSpacing: Theme.u * 8
                rowSpacing: Theme.u * 2
                Repeater {
                    model: [[I18n.t("Система", "System"), "os"], [I18n.t("Ядро", "Kernel"), "kernel"], [I18n.t("Хост", "Host"), "host"], [I18n.t("Процессор", "CPU"), "cpu"], [I18n.t("Видеокарта", "GPU"), "gpu"], [I18n.t("Память", "Memory"), "mem"], ["Работает", "uptime"], ["niri", "niri"], ["Quickshell", "qs"], [I18n.t("Шелл", "Shell"), "shell"]].reduce((a, r) => a.concat([
                            {
                                "t": r[0],
                                "dim": true
                            },
                            {
                                "t": SystemInfo.info[r[1]] || "—",
                                "dim": false
                            }
                        ]), [])
                    PxText {
                        required property var modelData
                        text: modelData.t
                        dim: modelData.dim
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        SystemInfo.refresh();
        DesktopActions.refresh();
    }

    // the expensive toys: shown only when a popular model over $100 is plugged in
    PxGroup {
        name: "your-setup"
        visible: SystemInfo.gear.length > 0
        title: I18n.t("Твой сетап ✧", "Your setup ✧")
        icon: "star"
        width: parent.width
        Repeater {
            model: SystemInfo.gear
            Row {
                id: gearRow
                required property var modelData
                spacing: Theme.u * 4
                PxIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: ({
                            "keyboard": "keyboard",
                            "mouse": "mouse",
                            "mic": "mic"
                        })[gearRow.modelData.kind] || "star"
                    pixel: Theme.u * 2
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    PxText {
                        text: gearRow.modelData.name
                        font.bold: true
                    }
                    PxText {
                        text: ({
                                "keyboard": I18n.t("Клавиатура", "Keyboard"),
                                "mouse": I18n.t("Мышь", "Mouse"),
                                "mic": I18n.t("Микрофон", "Microphone")
                            })[gearRow.modelData.kind] + " · ~$" + Math.round(gearRow.modelData.usd)
                        kind: "tiny"
                        dim: true
                    }
                }
            }
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            text: I18n.t("Популярные клавиатуры, мыши и микрофоны дороже $", "Popular keyboards, mice and microphones over $") + Math.round(SystemInfo.gearThreshold) + I18n.t(" (примерная цена на старте продаж). Их же показывает fastfetch.", " (roughly their launch price). fastfetch shows them too.")
        }
        PxButton {
            compact: true
            icon: "refresh"
            text: I18n.t("Проверить снова", "Check again")
            onClicked: SystemInfo.refresh()
        }
    }

    // fastfetch in angelOS's styles (scripts/fastfetch_style.py, services/FastfetchLogo):
    // a card each, the picked one run for real below — in heaven or in any circle of hell
    PxGroup {
        id: ffGroup
        name: "fastfetch"
        title: "fastfetch"
        icon: "monitor"
        width: parent.width
        property string pick: FastfetchLogo.style
        property string realm: Angel.demon ? (HellLook.circle || "base") : "heaven"
        readonly property var styles: FastfetchLogo.styles
        readonly property var circles: ["base", "limbo", "lust", "gluttony", "greed", "wrath", "heresy", "violence", "fraud", "treachery"]
        // what ThemeExport.fastfetchHell gives terminal-hell.py, for any circle
        function hellOf(c) {
            const look = HellLook.merged(HellLook.fallback, HellLook.looks.base, c !== "base" ? HellLook.looks[c] : null);
            const p = look.palette, n = look.n || 0;
            const h = x => Theme.hex(Qt.color(x));
            const lab = id => look.labels && look.labels[id] ? I18n.label(look.labels[id]) : "";
            return {
                "circle": c,
                "number": n,
                "roman": n > 0 ? Theme.roman(n) : "",
                "name": I18n.label(look.name || {}),
                "where": I18n.label(look.where || {}),
                "circleWord": I18n.t("Круг", "Circle"),
                "labels": {
                    "cpu": lab("cpu"),
                    "gpu": lab("gpu"),
                    "ram": lab("ram")
                },
                "keys": h(p.accent),
                "title": h(p.text),
                "dim": h(p.textDim),
                "palette": {
                    "#": h(Theme.mix(Qt.color(p.accent), Qt.color(p.edge), 0.55)),
                    "o": h(p.accent),
                    "x": h(p.blood),
                    "y": h(p.flame),
                    "w": h(p.text),
                    "f": h(p.textDim),
                    "r": h(p.accent),
                    "p": h(Theme.mix(Qt.color(p.accent), Qt.color(p.text), 0.45))
                }
            };
        }
        function refresh() {
            if (ffPreview.running) {
                ffPreview.again = true;
                return;
            }
            const st = pick === "own" ? "compact" : pick;
            let cmd = FastfetchLogo.args("preview", st);
            if (realm !== "heaven") {
                cmd = cmd.concat(["--hell", JSON.stringify(hellOf(realm))]);
                // before any circle: the emblem with horns
                cmd[cmd.indexOf("--emblem-rows") + 1] = JSON.stringify(Logos.emblem(FastfetchLogo.emblem, true));
            }
            ffPreview.command = cmd;
            ffPreview.running = true;
        }
        onPickChanged: refresh()
        onRealmChanged: refresh()
        Component.onCompleted: refresh()
        Process {
            id: ffPreview
            property bool again: false
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const r = JSON.parse(text);
                        if (r.lines)
                            ffScreen.screen = r;
                    } catch (e) {}
                }
            }
            onExited: if (again) {
                again = false;
                ffGroup.refresh();
            }
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Что печатает fastfetch в новом терминале. Цвета и значок — из темы и «Пуска»; в аду у каждого круга своя печать, свои цвета и слова.", "What fastfetch prints in a new terminal. The colours and emblem come from the theme and Start; in hell each circle has its own sigil, colours and words.")
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 4
            Repeater {
                model: ffGroup.styles
                Item {
                    id: ffCard
                    required property var modelData
                    readonly property bool picked: ffGroup.pick === modelData.id
                    width: Math.floor((parent.width - Theme.u * 8) / 3)
                    height: ffCol.implicitHeight + Theme.u * 10
                    PxBox {
                        anchors.fill: parent
                        sunken: ffCard.picked
                        color: ffCard.picked ? Theme.mix(Theme.face, Theme.accent, 0.22) : ffm.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.1) : Theme.face
                        edgeColor: ffCard.picked ? Theme.accent : Theme.edge
                    }
                    Column {
                        id: ffCol
                        x: Theme.u * 5
                        y: Theme.u * 5
                        width: parent.width - Theme.u * 10
                        spacing: Theme.u * 2
                        PxText {
                            text: (ffCard.picked ? "♡ " : "") + ffCard.modelData.name
                            font.bold: true
                        }
                        PxText {
                            width: parent.width
                            text: ffCard.modelData.hint
                            kind: "tiny"
                            dim: true
                            wrapMode: Text.Wrap
                        }
                    }
                    MouseArea {
                        id: ffm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ffGroup.pick = ffCard.modelData.id;
                            Config.bar.fastfetchStyle = ffCard.modelData.id;
                        }
                    }
                }
            }
        }
        SettingRow {
            label: I18n.t("Анимация", "Animation")
            hint: I18n.t("картинка оживает в новом терминале: машет крыльями, блестит, искрится; любая клавиша — сразу к делу", "the picture comes alive in a new terminal: wings flap, it shines and sparkles; any key gets you straight to work")
            PxCombo {
                width: Theme.u * 110
                model: [
                    {
                        "label": I18n.t("Выключена", "Off"),
                        "value": "off"
                    },
                    {
                        "label": I18n.t("Коротко — 2,5 с", "Short: 2.5 s"),
                        "value": "short"
                    },
                    {
                        "label": I18n.t("Подольше — 6 с", "Longer: 6 s"),
                        "value": "long"
                    }
                ]
                currentValue: Config.bar.fastfetchAnim || "short"
                onActivated: v => Config.bar.fastfetchAnim = v
            }
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            visible: Motion.still && Config.bar.fastfetchAnim !== "off"
            text: I18n.t("Сейчас картинка стоит: анимации выключены (Оформление → Анимации).", "The picture stays still for now: animations are off (Appearance → Animations).")
        }
        SettingRow {
            label: I18n.t("Показать", "Show")
            hint: I18n.t("рай — как сейчас; круги — как будет в аду (там fastfetch меняется сам)", "heaven is how it is now; the circles are how hell shows it (it changes there by itself)")
            PxCombo {
                width: Theme.u * 110
                model: [
                    {
                        "label": I18n.t("Рай", "Heaven"),
                        "value": "heaven"
                    }
                ].concat(ffGroup.circles.map(c => {
                    const look = c === "base" ? null : HellLook.looks[c];
                    return {
                        "label": c === "base" ? I18n.t("Ад (до кругов)", "Hell (before the circles)") : (look && look.n ? Theme.roman(look.n) + " · " : "") + I18n.label(look ? look.name || {} : {}),
                        "value": c
                    };
                }))
                currentValue: ffGroup.realm
                onActivated: v => ffGroup.realm = v
            }
        }
        PxBox {
            width: parent.width
            height: ffScreen.height * ffScreen.scale + Theme.u * 4
            sunken: true
            color: ffScreen.background
            clip: true
            FastfetchPreview {
                id: ffScreen
                animate: Config.bar.fastfetchAnim !== "off"
                x: Theme.u * 2
                y: Theme.u * 2
                width: implicitWidth
                height: implicitHeight
                transformOrigin: Item.TopLeft
                scale: Math.min(1, (parent.width - Theme.u * 4) / Math.max(1, implicitWidth))
            }
            PxText {
                anchors.centerIn: parent
                visible: !(ffScreen.screen.lines || []).length
                text: ffPreview.running ? I18n.t("запускаю fastfetch…", "running fastfetch…") : I18n.t("fastfetch не установлен?", "is fastfetch installed?")
                dim: true
            }
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            visible: ffGroup.pick === "own"
            text: I18n.t("Выше — «Компакт» для сравнения. Свой config.jsonc angelOS не меняет; значок в logo.txt рисует, если включено «fastfetch рисует этот значок» (Панель → Логотип).", "Above: Compact, to compare. angelOS leaves your config.jsonc alone; it draws the emblem into logo.txt if “fastfetch draws this emblem” is on (Bar → Logo).")
        }
    }

    PxGroup {
        name: "angelos"
        title: "angelOS"
        icon: "heart"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            text: I18n.t("angelOS — пиксельная оболочка на Quickshell для niri. Конфиг: ", "angelOS is a pixel shell built with Quickshell for niri. Config: ") + Quickshell.shellDir + I18n.t(", настройки: ", ", settings: ") + Config.dir
            dim: true
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 4
            PxButton {
                text: I18n.t("Перезапустить оболочку", "Restart shell")
                icon: "refresh"
                onClicked: Quickshell.reload(true)
            }
            PxButton {
                text: I18n.t("Перечитать niri", "Reload niri")
                icon: "refresh"
                onClicked: Niri.action("LoadConfigFile", {})
            }
            PxButton {
                text: I18n.t("Папка настроек", "Settings folder")
                icon: "folder"
                onClicked: Shell.openPath(Config.dir)
            }
            PxButton {
                text: I18n.t("Бэкапы", "Backups")
                icon: "package"
                onClicked: Shell.openPath(Config.stateDir + "/backups")
            }
        }
    }

    PxGroup {
        name: "report-problem"
        id: reportGroup
        title: I18n.t("Сообщить о проблеме", "Report a problem")
        advanced: true
        icon: "warn"
        width: parent.width
        property var result: null
        property bool busy: false
        SettingRow {
            label: I18n.t("Отчёт для issue", "A report for an issue")
            hint: reportGroup.result ? I18n.t("готово: ", "done: ") + reportGroup.result.archive.replace(Config.home, "~") + I18n.t(" — прикрепи его к issue на GitHub", " — attach it to a GitHub issue") : I18n.t("версии, лог оболочки, краш-отчёты и настройки в одном архиве; путь к дому и имя заменены, личное (история запусков, имена столов, данные плагинов) не попадает. То же в терминале: angelos report", "Versions, the shell log, crash reports and settings in one archive; your home path and name are replaced, personal bits (launch history, workspace names, plugin data) stay out. Same in a terminal: angelos report")
            PxButton {
                enabled: !reportGroup.busy
                icon: "package"
                text: reportGroup.busy ? I18n.t("Собираю…", "Packing…") : I18n.t("Собрать отчёт", "Make a report")
                onClicked: {
                    reportGroup.busy = true;
                    reportProc.running = true;
                }
            }
        }
        Row {
            visible: !!reportGroup.result
            spacing: Theme.u * 4
            PxButton {
                icon: "folder"
                text: I18n.t("Показать архив", "Show the archive")
                onClicked: Shell.openPath(reportGroup.result.archive.replace(/\/[^\/]*$/, ""))
            }
            PxButton {
                accent: true
                icon: "bell"
                text: I18n.t("Открыть форму issue", "Open the issue form")
                onClicked: Shell.exec(["xdg-open", reportGroup.result.issue])
            }
        }
        Process {
            id: reportProc
            command: ["python3", Quickshell.shellDir + "/scripts/report.py", "--json"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        reportGroup.result = JSON.parse(text);
                    } catch (e) {
                        reportGroup.result = null;
                    }
                }
            }
            onExited: reportGroup.busy = false
        }
    }

    PxGroup {
        name: "development"
        title: I18n.t("Разработка", "Development")
        advanced: true
        icon: "sparkle"
        width: parent.width
        SettingRow {
            label: I18n.t("Режим разработчика", "Developer mode")
            hint: I18n.t("Добавляет мастер плагинов в настройки и меню «Пуск». Установленные плагины работают и без этого режима.", "Adds Plugin Studio to Settings and Start. Installed plugins keep working when this mode is off.")
            PxToggle {
                checked: Config.developer.enabled
                onToggled: c => Config.developer.enabled = c
            }
        }
        PxButton {
            visible: Config.developer.enabled
            text: I18n.t("Открыть мастер плагинов", "Open Plugin Studio")
            icon: "sparkle"
            onClicked: Shell.settingsGo(systemPage, "studio")
        }
    }

    // ---- developer mode: see and steer the story — the game's debug panel (GameDebug) ----
    PxGroup {
        name: "game-developer-tools"
        title: I18n.t("Игра: инструменты разработчика", "The game: developer tools")
        advanced: true
        shown: Config.developer.enabled
        icon: "chip"
        width: parent.width
        SettingRow {
            label: I18n.t("Панель отладки игры", "The game's debug panel")
            hint: I18n.t("Всё состояние игры и любая переменная, любой круг и сцена, эффекты, облики и звуки, снимок сохранения — в отдельном окне. Или `angelos debug`.", "The whole state of the game and every variable, any circle and scene, the effects, looks and sounds, a snapshot of the save — in a window of its own. Or `angelos debug`.")
            PxButton {
                icon: "chip"
                text: I18n.t("Открыть", "Open")
                onClicked: GameDebug.open = true
            }
        }
    }

    PxGroup {
        name: "task-manager"
        title: I18n.t("Диспетчер задач", "Task Manager")
        advanced: true
        icon: "chip"
        width: parent.width
        SettingRow {
            label: I18n.t("Системный монитор", "System monitor")
            hint: I18n.t("Запускается также через ПКМ по свободному месту панели", "Also available by right-clicking empty taskbar space")
            PxCombo {
                model: [{value: "auto", label: I18n.t("Автоматически", "Automatic")}].concat(DesktopActions.monitors, [{value: "custom", label: I18n.t("Другая программа…", "Custom application…")}])
                currentValue: Config.system.monitor
                onActivated: v => Config.system.monitor = v
            }
        }
        SettingRow {
            visible: Config.system.monitor === "custom"
            label: I18n.t("Программа", "Executable")
            hint: I18n.t("Имя программы или полный путь, без аргументов", "Program name or full path, without arguments")
            PxField {
                width: Theme.u * 100
                text: Config.system.monitorProgram
                placeholder: "missioncenter"
                onEdited: Config.system.monitorProgram = text
            }
        }
        SettingRow {
            visible: Config.system.monitor === "custom"
            label: I18n.t("Запускать в терминале", "Run in terminal")
            PxToggle {
                checked: Config.system.monitorInTerminal
                onToggled: c => Config.system.monitorInTerminal = c
            }
        }
        SettingRow {
            label: I18n.t("Всегда плавающее окно", "Always a floating window")
            hint: I18n.t("правило niri для окна диспетчера: не встаёт в колонки, открывается поверх", "A niri rule: the task manager never joins the columns, it opens on top")
            PxToggle {
                checked: Config.system.monitorFloat
                onToggled: c => Config.system.monitorFloat = c
            }
        }
        SettingRow {
            visible: Config.system.monitorFloat
            label: I18n.t("Размер окна", "Window size")
            hint: ({
                    "compact": "900 × 560",
                    "medium": "1200 × 760",
                    "large": "1500 × 950",
                    "tall": I18n.t("40% ширины × 90% высоты экрана — колонка сбоку", "40% of the width × 90% of the height — a side column"),
                    "custom": I18n.t("свои значения ниже", "your values below")
                })[Config.system.monitorSize] || ""
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Компактный", "Compact"),
                        "value": "compact"
                    },
                    {
                        "label": I18n.t("Средний", "Medium"),
                        "value": "medium"
                    },
                    {
                        "label": I18n.t("Большой", "Large"),
                        "value": "large"
                    },
                    {
                        "label": I18n.t("Высокий", "Tall"),
                        "value": "tall"
                    },
                    {
                        "label": I18n.t("Свой", "Custom"),
                        "value": "custom"
                    }
                ]
                currentValue: Config.system.monitorSize
                onActivated: v => Config.system.monitorSize = v
            }
        }
        SettingRow {
            visible: Config.system.monitorFloat && Config.system.monitorSize === "custom"
            label: I18n.t("Ширина × высота", "Width × height")
            hint: I18n.t("логические пиксели", "logical pixels")
            Row {
                spacing: Theme.u * 3
                PxSpin {
                    from: 320
                    to: 7680
                    stepSize: 20
                    value: Config.system.monitorWidth
                    onMoved: v => Config.system.monitorWidth = v
                }
                PxText {
                    text: "×"
                    anchors.verticalCenter: parent.verticalCenter
                }
                PxSpin {
                    from: 240
                    to: 4320
                    stepSize: 20
                    value: Config.system.monitorHeight
                    onMoved: v => Config.system.monitorHeight = v
                }
            }
        }
        SettingRow {
            visible: Config.system.monitorFloat
            label: I18n.t("Где открывать", "Where it opens")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("По центру", "Centre"),
                        "value": "center"
                    },
                    {
                        "label": I18n.t("У трея (справа внизу)", "By the tray (bottom right)"),
                        "value": "corner"
                    }
                ]
                currentValue: Config.system.monitorPlace
                onActivated: v => Config.system.monitorPlace = v
            }
        }
        PxText {
            visible: Config.system.monitorFloat && WindowConfig.log !== ""
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            text: WindowConfig.log
        }
        PxButton {
            text: I18n.t("Открыть диспетчер задач", "Open Task Manager")
            icon: "chip"
            enabled: DesktopActions.available
            onClicked: DesktopActions.launchMonitor()
        }
    }

    PxGroup {
        name: "programs"
        title: I18n.t("Программы", "Programs")
        advanced: true
        icon: "terminal"
        width: parent.width
        PxButton {
            text: I18n.t("Блокировка и заставка →", "Lock and idle screen →")
            icon: "lock"
            onClicked: Shell.settingsGo(systemPage, "lock")
        }
        SettingRow {
            label: I18n.t("Терминал", "Terminal")
            PxField {
                width: Theme.u * 80
                text: Config.system.terminal
                onEdited: Config.system.terminal = text
            }
        }
        SettingRow {
            label: I18n.t("Файловый менеджер", "File manager")
            PxField {
                width: Theme.u * 80
                text: Config.system.fileManager
                onEdited: Config.system.fileManager = text
            }
        }
    }

    // ---- the game (services/Story): accessibility, and the way back in once it was switched off ----
    PxGroup {
        name: "game"
        title: I18n.t("Игра", "The game")
        icon: "heart"
        width: parent.width
        // the calm mode is one of the three motion levels now (config/Motion, C4): one place
        SettingRow {
            label: I18n.t("Спокойный режим", "Calm mode")
            hint: I18n.t("теперь в «Тема и цвета → Движение»: полное, спокойное (без вспышек, тряски и резких звуков) или выключено. Сейчас: ", "Now in Theme and colours → Motion: full, calm (no flashes, shaking or sudden loud sounds) or off. Now: ") + ({
                    "full": I18n.t("полное", "full"),
                    "calm": I18n.t("спокойное", "calm"),
                    "off": I18n.t("выключено", "off")
                })[Motion.level]
            PxButton {
                icon: "sparkle"
                text: I18n.t("Открыть", "Open")
                onClicked: Shell.settingsGo(systemPage, "appearance")
            }
        }
        SettingRow {
            visible: !Config.game.enabled
            label: I18n.t("Игра выключена", "The game is off")
            hint: I18n.t("angelOS работает как обычные дотфайлы: без ангела, демоницы, новеллы и ада. Включить — и в углу снова появится ангел.", "angelOS works as plain dotfiles: no angel, demon, novel or hell. Switch it on and the angel is back in the corner.")
            PxButton {
                icon: "heart"
                accent: true
                text: I18n.t("Включить игру", "Turn the game on")
                onClicked: Story.setEnabled(true)
            }
        }
    }
}
