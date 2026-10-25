// The settings once in WindowsPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import qs.modules.cobweb
import qs.modules.settings.kit

CatPage {
    id: page
    // niri sends a window update on every step of a resize or a move: the rows are built again
    // only when the set of apps changes (a string that stays equal doesn't notify)
    readonly property string openAppIds: {
        const seen = {};
        for (const w of Niri.windows)
            if (w.app_id)
                seen[w.app_id] = true;
        return Object.keys(seen).sort().join("\n");
    }
    readonly property var openApps: openAppIds ? openAppIds.split("\n").map(id => ({
                "app_id": id
            })) : []
    property string customPreset: ""
    heading: I18n.t("Окна", "Windows")
    // angel-niri's Desktop: the columns' settings, the throw and focus-follows-mouse do nothing there
    readonly property bool desk: Niri.nativeMinimize && WindowConfig.floatAll
    subtitle: desk ? I18n.t("Окна поверх друг друга, как в обычной системе.", "Windows over each other, as on a usual system.") : I18n.t("Окна встают в колонки, которые прокручиваются вбок.", "Windows stand in columns that scroll sideways.")
    CatGroup {
        name: "closing-windows"
        title: I18n.t("Кнопки окон на панели", "Window buttons on the bar")
        advanced: true
        icon: "close"
        CatChoice {
            id: rightRow
            preview: "TaskClose"
            label: I18n.t("ПКМ по кнопке окна на панели", "Right-click a window button")
            hint: ({
                    "menu": I18n.t("меню: во весь экран, плавающее, на другой стол или монитор, закрыть, завершить процесс", "A menu: fullscreen, floating, another desk or monitor, close, end task"),
                    "close": I18n.t("закрывает окно сразу, без вопросов", "Closes the window at once"),
                    "none": I18n.t("ничего не делает", "Does nothing")
                })[Config.bar.taskRightClick] || ""
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
        CatToggle {
            id: middleRow
            preview: "TaskClose"
            label: I18n.t("Средняя кнопка закрывает", "Middle click closes")
            hint: I18n.t("колёсиком по кнопке окна на панели, как в браузере по вкладке", "Click the wheel on a window button, like on a browser tab")
            checked: Config.bar.taskMiddleClose
            onToggled: c => {
                Config.bar.taskMiddleClose = c;
                middleRow.show(c ? "middle-on" : "middle-off", c ? I18n.t("закрывает", "closes") : I18n.t("не закрывает", "does not close"));
            }
        }
        CatToggle {
            id: hoverRow
            preview: "TaskClose"
            label: I18n.t("Крестик при наведении", "× on hover")
            hint: I18n.t("на кнопке окна под курсором появляется крестик", "A close button appears on the hovered window button")
            checked: Config.bar.taskHoverClose
            onToggled: c => {
                Config.bar.taskHoverClose = c;
                hoverRow.show(c ? "hover-on" : "hover-off", c ? I18n.t("крестик есть", "with ×") : I18n.t("без крестика", "no ×"));
            }
        }
    }
    CatGroup {
        name: "alt-tab"
        title: "Alt+Tab"
        advanced: true
        icon: "layers"
        CatNote {
            dim: true
            text: I18n.t("Держи Alt и жми Tab, отпусти — переключится. Shift+Tab — назад, Esc — отмена, Delete — закрыть окно.", "Hold Alt and press Tab, let go to switch. Shift+Tab: back, Esc: cancel, Delete: close the window.")
        }
        CatCustom {
            wide: true
            CatBox {
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
                            color: current ? Theme.mix(Theme.tone("face", Theme.p5For(parent)), Theme.accent, 0.3) : atMouse.containsMouse ? Theme.mix(Theme.tone("face", Theme.p5For(parent)), Theme.accent, 0.1) : Theme.tone("face", Theme.p5For(parent))
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
            }
        }
        CatChoice {
            present: AltTab.ours
            label: I18n.t("Какие окна", "Which windows")
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
        CatToggle {
            present: AltTab.ours
            label: I18n.t("Подписи", "Titles")
            checked: Config.alttab.titles
            onToggled: c => Config.alttab.titles = c
        }
        CatSlider {
            present: AltTab.ours
            label: I18n.t("Показывать через", "Show after")
            hint: I18n.t("пока Alt держится дольше — иначе просто переключает, без окошка", "only while Alt is held longer, otherwise it just switches")
            from: 0
            to: 500
            stepSize: 10
            suffix: I18n.t(" мс", " ms")
            value: Config.alttab.delayMs
            onReleased: v => Config.alttab.delayMs = v
        }
        CatCustom {
            wide: true
            CatBox {
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
                        color: AltTab.watcherStatus === "noperm" ? Theme.danger : Theme.tone("textDim", Theme.p5For(parent))
                        text: AltTab.watcherStatus === "noperm" ? I18n.t("нет доступа к клавиатуре (группа input): отпускание Alt ловится только самим окошком — если оно не успело открыться, выбери окно Enter или кликом", "No keyboard access (the input group): only the switcher itself sees Alt being let go — if it was not open yet, pick with Enter or a click") : AltTab.log
                    }
                }
            }
        }
    }
    CatGroup {
        name: "window-animations"
        title: I18n.t("Анимации окон", "Window animations")
        advanced: true
        icon: "sparkle"
        Component.onCompleted: WindowAnim.refresh()
        // the motion off in Accessibility (config/Motion) stills these too: say so here
        CatButton {
            present: Motion.still
            label: I18n.t("Движение выключено", "Motion is off")
            hint: I18n.t("в «Доступности» — анимации сейчас не играют", "In Accessibility: animations don't play now")
            compact: true
            icon: "sparkle"
            text: I18n.t("Включить", "Switch on")
            onClicked: Motion.set("full")
        }
        CatCustom {
            wide: true
            CatBox {
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
                            hint: I18n.t("×2 — вдвое быстрее, ×0.5 — вдвое медленнее", "×2: twice as fast, ×0.5: twice as slow")
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
            }
        }
        CatCustom {
            wide: true
            CatBox {
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
        }
    }
    CatGroup {
        name: "floating"
        title: I18n.t("Desktop или Лента", "Desktop or Strip")
        icon: "window"
        CatToggle {
            label: I18n.t("Desktop: окна как в обычной системе", "Desktop: windows as on a usual system")
            hint: GoldenGate.on ? I18n.t("в Golden Gate всегда Desktop; на пиксельном скине вернётся то, что выбрано здесь", "Golden Gate is always Desktop; the pixel skins get back what is picked here") : Niri.nativeMinimize ? I18n.t("окна поверх друг друга, с заголовком и кнопками _ □ X, как в Windows: тащи за заголовок, к краю — половина экрана, в угол — четверть, вверх — во весь; потряс окно — остальные свернулись. Выключишь — Лента: колонки вернутся как были. Mod+Ctrl+Shift+M или значок на панели", "Windows over each other with a title bar and _ □ X, as in Windows: drag by the title, to an edge for half the screen, a corner for a quarter, the top for all of it; shake one and the rest minimize. Off, the Strip: the columns come back as they were. Mod+Ctrl+Shift+M or the bar's button") : I18n.t("окна открываются поверх друг друга и двигаются мышью, как в Windows. Выключишь — Лента: окна встанут в колонки", "Windows open over each other and move with the mouse, as in Windows. Off, the Strip: windows stand in columns")
            enabled: !GoldenGate.on
            checked: WindowConfig.floatAll
            onToggled: c => WindowConfig.setFloatAll(c)
        }
        CatChoice {
            present: Niri.nativeMinimize && WindowConfig.floatAll
            label: I18n.t("Кнопки окна", "Window buttons")
            hint: I18n.t("красная, жёлтая и зелёная на заголовках окон", "The red, yellow and green buttons on the title bars")
            model: [
                {
                    "label": I18n.t("Слева, как Mac", "Left, like a Mac"),
                    "value": "left"
                },
                {
                    "label": I18n.t("Справа, как Windows", "Right, like Windows"),
                    "value": "right"
                }
            ]
            currentValue: Config.windows.titleButtons
            onActivated: v => Config.windows.titleButtons = v
        }
        CatChoice {
            present: Niri.nativeMinimize && WindowConfig.floatAll
            label: I18n.t("Зелёная кнопка", "The green button")
            hint: Config.windows.green === "fullscreen" ? I18n.t("окно уходит в полный экран на свой рабочий стол, как в macOS; выйдешь — вернётся на место. Задержи мышь на зелёной — меню: полный экран, развернуть, половина экрана, другой монитор", "The window goes full screen on a desk of its own, as in macOS, and comes back when it leaves. Rest the pointer on the green button for a menu: full screen, maximize, half the screen, another monitor") : I18n.t("разворачивает окно на весь экран (двойной клик по заголовку — тоже). Задержи мышь на зелёной — меню: полный экран, развернуть, половина экрана, другой монитор", "Maximizes the window (so does a double click on the title). Rest the pointer on the green button for a menu: full screen, maximize, half the screen, another monitor")
            model: [
                {
                    "label": I18n.t("Развернуть", "Maximize"),
                    "value": "maximize"
                },
                {
                    "label": I18n.t("Полный экран", "Full screen"),
                    "value": "fullscreen"
                }
            ]
            currentValue: Config.windows.green
            onActivated: v => Config.windows.green = v
        }
        CatToggle {
            present: Niri.nativeMinimize && !page.desk
            label: I18n.t("Бросок окна", "Throwing windows")
            hint: I18n.t("отпустил плавающее окно на ходу — оно летит дальше, отскакивает от краёв монитора и сплющивается о них; пока тащишь, отстаёт и колышется, как желе", "Let go of a floating window mid-drag and it flies on, bouncing off the monitor's edges and squashing against them; while dragged it lags and sways like jelly")
            checked: Config.windows.throwOn
            onToggled: c => Config.windows.throwOn = c
        }
        CatSlider {
            present: Niri.nativeMinimize && !page.desk && Config.windows.throwOn
            label: I18n.t("Сила броска", "Throw strength")
            hint: I18n.t("насколько далеко улетает окно: чуть скользит … через весь экран", "How far a window flies: barely slides … across the screen")
            from: 10
            to: 200
            stepSize: 10
            suffix: "%"
            value: Math.round(Config.windows.throwStrength * 100)
            onReleased: v => Config.windows.throwStrength = v / 100
        }
        CatSlider {
            present: Niri.nativeMinimize && !page.desk && Config.windows.throwOn
            label: I18n.t("Отскок от краёв", "Bounce off edges")
            hint: I18n.t("0 — окно упирается в край и останавливается", "0: the window stops at the edge")
            from: 0
            to: 95
            stepSize: 5
            suffix: "%"
            value: Math.round(Config.windows.throwBounce * 100)
            onReleased: v => Config.windows.throwBounce = v / 100
        }
        CatSlider {
            present: Niri.nativeMinimize && !page.desk && Config.windows.throwOn
            label: I18n.t("Сплющивание при ударе", "Squash on impact")
            hint: I18n.t("0 — без сплющивания", "0: no squash")
            from: 0
            to: 200
            stepSize: 10
            suffix: "%"
            value: Math.round(Config.windows.throwSquash * 100)
            onReleased: v => Config.windows.throwSquash = v / 100
        }
        CatSlider {
            present: Niri.nativeMinimize && !page.desk && Config.windows.throwOn
            label: I18n.t("Колыхание при перетаскивании", "Sway while dragging")
            hint: I18n.t("0 — окно идёт ровно за мышью", "0: the window follows the mouse exactly")
            from: 0
            to: 200
            stepSize: 10
            suffix: "%"
            value: Math.round(Config.windows.throwWobble * 100)
            onReleased: v => Config.windows.throwWobble = v / 100
        }
    }
    // the windows' frame (niri's focus ring or border, scripts/window-config.py) and, under
    // angel-niri, their pixel corners (services/WindowConfig)
    CatGroup {
        name: "frames"
        title: I18n.t("Рамки и углы", "Frames and corners")
        icon: "window"
        enabled: !WindowConfig.busy
        CatChoice {
            label: I18n.t("Рамка", "Frame")
            hint: I18n.t("«У активного» — рамка вокруг окна, в котором работаешь; «У всех» — пиксельная рамка у каждого, у активного цветом акцента", "Focused: a frame around the window you work in; Every window: a pixel border on each, the focused one in the accent")
            model: [
                {"label": I18n.t("У активного", "Focused"), "value": "focus"},
                {"label": I18n.t("У всех", "Every window"), "value": "all"},
                {"label": I18n.t("Нет", "None"), "value": "none"}
            ]
            currentValue: WindowConfig.frame
            onActivated: v => WindowConfig.save({
                    frame: v
                })
        }
        CatToggle {
            present: Niri.nativeMinimize && !GoldenGate.on
            label: I18n.t("Пиксельные углы", "Pixel corners")
            hint: I18n.t("углы окон лесенкой из двух ступенек — как у кнопок и полей тем GTK и Qt; свои окна angelOS остаются прямоугольными", "Window corners as a two-step staircase, like the GTK and Qt themes' buttons and fields; angelOS's own windows stay square")
            checked: Config.windows.pixelCorners
            onToggled: c => Config.windows.pixelCorners = c
        }
        CatToggle {
            present: Niri.nativeMinimize && !GoldenGate.on
            label: I18n.t("Пиксельные тени", "Pixel shadows")
            hint: I18n.t("тень под окнами из точек, редеющих к краю; у активного окна — свечение цветом акцента", "Shadows of dots thinning out at the edge; the focused window glows in the accent")
            checked: Config.windows.pixelShadow
            onToggled: c => Config.windows.pixelShadow = c
        }
        CatToggle {
            present: Niri.nativeMinimize && !GoldenGate.on
            label: I18n.t("Пиксельный обзор", "Pixel overview")
            hint: I18n.t("обзор всех столов (Win+Tab): чёткие миниатюры без размытия, пиксельная рамка и номер у каждого стола", "The overview of all desks (Win+Tab): sharp thumbnails without blur, a pixel frame and a number by each desk")
            checked: Config.windows.pixelOverview
            onToggled: c => Config.windows.pixelOverview = c
        }
        CatToggle {
            present: Niri.nativeMinimize && !GoldenGate.on
            label: I18n.t("Тусклые неактивные окна", "Dim inactive windows")
            hint: I18n.t("поверх окон, в которых ты сейчас не работаешь, — редкая сетка тёмных точек", "A sparse grid of dark dots over the windows you aren't working in")
            checked: Config.windows.inactiveDim
            onToggled: c => Config.windows.inactiveDim = c
        }
        CatCustom {
            present: Niri.nativeMinimize && !GoldenGate.on && Config.windows.inactiveDim
            label: I18n.t("На мониторах", "On the monitors")
            hint: I18n.t("ни один не выбран — на всех; на рабочих мониторах точки лучше выключить", "none picked: on all of them; better off on the monitors you work on")
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 2
                    Repeater {
                        model: {
                            const seen = {};
                            for (const ws of Niri.workspaces)
                                seen[ws.output] = true;
                            for (const o of Config.windows.dimOutputs || [])
                                seen[o] = true;
                            return Object.keys(seen).sort();
                        }
                        PxButton {
                            required property string modelData
                            compact: true
                            text: modelData
                            checked: (Config.windows.dimOutputs || []).includes(modelData)
                            onClicked: {
                                const l = (Config.windows.dimOutputs || []).filter(o => o !== modelData);
                                Config.windows.dimOutputs = checked ? l : l.concat([modelData]);
                            }
                        }
                    }
                }
            }
        }
    }
    // angel-niri: programs pinned by hand open on their monitor and desk (services/WindowConfig)
    CatGroup {
        name: "window-places"
        title: I18n.t("Места программ", "Program places")
        icon: "pin"
        present: Niri.nativeMinimize
        CatToggle {
            label: I18n.t("Программы на своих местах", "Programs in their places")
            hint: I18n.t("закреплённая программа открывает первое окно на своём мониторе и столе, и ты переходишь туда же. Закрепить — ПКМ по окну на панели → «Всегда открывать здесь» или ниже. Выключено — места не забываются, просто не действуют", "A pinned program opens its first window on its monitor and desk, and you go there with it. Pin one: right-click its window on the taskbar → Always open here, or below. Off, the places are kept but do nothing")
            checked: Config.windows.remember
            onToggled: c => Config.windows.remember = c
        }
        CatRepeat {
            model: Config.windows.remember ? Object.keys(WindowConfig.places).sort() : []
            delegate: Component {
                CatCustom {
                    id: placeRow
                    required property string modelData
                    readonly property var pin: WindowConfig.placeFor(modelData)
                    readonly property var outputs: {
                        const seen = {};
                        for (const ws of Niri.workspaces)
                            seen[ws.output] = true;
                        if (pin)
                            seen[pin.output] = true;
                        return Object.keys(seen).sort();
                    }
                    // the desks of its monitor, one more for a new one, its own even if gone
                    readonly property var desks: {
                        const n = pin ? Math.max(Niri.workspacesOn(pin.output).length, pin.idx) : 1;
                        const out = [];
                        for (let i = 1; i <= n; i++)
                            out.push({
                                "label": I18n.t("стол ", "desk ") + i,
                                "value": i
                            });
                        return out;
                    }
                    function change(o) {
                        WindowConfig.setPlace(modelData, Object.assign({}, pin, o));
                    }
                    label: DesktopEntries.heuristicLookup(modelData) ? DesktopEntries.heuristicLookup(modelData).name : modelData
                    hint: modelData
                    CatBox {
                        Flow {
                            width: parent.width
                            spacing: Theme.u * 2
                            AppIcon {
                                appId: placeRow.modelData
                                size: Theme.u * 10
                            }
                            PxCombo {
                                width: Theme.u * 40
                                model: placeRow.outputs
                                currentValue: placeRow.pin ? placeRow.pin.output : ""
                                onActivated: v => placeRow.change({
                                        "output": v,
                                        "name": ""
                                    })
                            }
                            PxCombo {
                                width: Theme.u * 34
                                model: placeRow.desks
                                currentValue: placeRow.pin ? placeRow.pin.idx : 1
                                onActivated: v => placeRow.change({
                                        "idx": v,
                                        "name": ""
                                    })
                            }
                            PxButton {
                                compact: true
                                text: I18n.t("плавающее", "floating")
                                checked: !!placeRow.pin && placeRow.pin.floating
                                onClicked: placeRow.change({
                                    "floating": !placeRow.pin.floating
                                })
                            }
                            PxButton {
                                compact: true
                                text: I18n.t("забыть ✕", "forget ✕")
                                onClicked: WindowConfig.setPlace(placeRow.modelData, null)
                            }
                        }
                    }
                }
            }
        }
        CatCustom {
            present: Config.windows.remember
            label: I18n.t("Закрепить открытую", "Pin an open one")
            hint: I18n.t("программа встанет туда, где её окно сейчас", "the program's place becomes where its window is now")
            CatBox {
                PxCombo {
                    width: Theme.u * 70
                    placeholder: I18n.t("+ программа", "+ program")
                    model: page.openApps.filter(a => !WindowConfig.places[a.app_id]).map(a => ({
                                "label": DesktopEntries.heuristicLookup(a.app_id) ? DesktopEntries.heuristicLookup(a.app_id).name : a.app_id,
                                "value": a.app_id
                            }))
                    onActivated: v => {
                        const w = Niri.windows.find(x => x.app_id === v && WindowConfig.placeOf(x));
                        if (w)
                            WindowConfig.setPlace(v, WindowConfig.placeOf(w));
                    }
                }
            }
        }
    }
    CatGroup {
        name: "layout"
        title: I18n.t("Колонки и отступы", "Columns and gaps")
        present: !page.desk
        advanced: true
        icon: "window"
        enabled: !WindowConfig.busy
        CatChoice {
            label: I18n.t("Центрировать активную колонку", "Center the focused column")
            combo: true
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
        CatSlider {
            label: I18n.t("Отступ между окнами", "Window gap")
            from: 0
            to: 64
            stepSize: 1
            value: WindowConfig.gaps
            suffix: " px"
            onReleased: v => WindowConfig.save({
                    gaps: v
                })
        }
        CatToggle {
            label: I18n.t("Фокус следует за мышью", "Focus follows the mouse")
            checked: InputConfig.focusFollowsMouse
            onToggled: c => InputConfig.save({
                    focusFollowsMouse: c
                })
        }
    }
    CatGroup {
        name: "window-widths"
        title: I18n.t("Ширина окон", "Window widths")
        present: !page.desk
        advanced: true
        icon: "layers"
        enabled: !WindowConfig.busy
        CatCustom {
            label: I18n.t("Новые окна", "New windows")
            hint: I18n.t("ширина колонки при открытии; уже открытое окно — ПКМ по нему на панели → Ширина", "column width when a window opens; an open one: right-click it on the taskbar → Width")
            CatBox {
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
                        onEditingFinished: if (parseInt(text) > 100)
                            WindowConfig.save({
                                "defaultWidth": "fixed " + parseInt(text)
                            })
                    }
                }
            }
        }
        CatCustom {
            label: I18n.t("Пресеты Win+R", "Win+R presets")
            hint: I18n.t("по ним переключается ширина колонки; ✕ — убрать", "Win+R cycles through these; ✕ removes one")
            CatBox {
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
        }
        CatNote {
            text: I18n.t("Открытые приложения — своя ширина для каждого. Применяется сразу к открытым окнам и запоминается для новых.", "Open apps — a width of their own. Applies to open windows right away and is remembered for new ones.")
            dim: true
        }
        CatRepeat {
            model: page.openApps
            delegate: Component {
                CatCustom {
                    id: appRow
                    required property var modelData
                    readonly property string appId: modelData.app_id
                    label: DesktopEntries.heuristicLookup(appId) ? DesktopEntries.heuristicLookup(appId).name : appId
                    hint: appId
                    CatBox {
                        Row {
                            width: parent.width
                            spacing: Theme.u * 3
                            AppIcon {
                                id: appIcon
                                anchors.verticalCenter: parent.verticalCenter
                                appId: appRow.appId
                                size: Theme.u * 10
                            }
                            PxCombo {
                                width: Math.max(Theme.u * 30, Math.min(Theme.u * 80, parent.width - appIcon.width - pxField.width - parent.spacing * 2))
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
                                id: pxField
                                width: Theme.u * 34
                                placeholder: "px"
                                onEditingFinished: if (parseInt(text) > 100)
                                    WindowConfig.setAppWidth(appRow.appId, "fixed " + parseInt(text))
                            }
                        }
                    }
                }
            }
        }
    }
    // window decorations: the apps' own (client-side) — GTK's buttons (scripts/gtk-live.py), browsers
    CatGroup {
        name: "window-decorations"
        id: decorGroup
        title: I18n.t("Заголовки окон", "Title bars")
        icon: "window"
        CatToggle {
            label: I18n.t("Кнопки GTK-окон как в angelOS", "GTK window buttons like angelOS's")
            hint: (Angel.hellShown ? I18n.t("пиксельные «развернуть» и «закрыть», шапка цвета меню; в аду — обсидиан и кровь. ", "Pixel maximize and close, the header in the menu colour; obsidian and blood in hell. ") : I18n.t("пиксельные «развернуть» и «закрыть», шапка цвета меню. ", "Pixel maximize and close, the header in the menu colour. ")) + I18n.t("GTK 3 и Helium в режиме «GTK» меняются сразу (своя тема angelOS поверх adw-gtk3), GTK 4 — при следующем запуске программы", "GTK 3 and Helium in its GTK mode change at once (angelOS's own theme over adw-gtk3), GTK 4 the next time an app starts")
            checked: Config.decor.gtkButtons
            onToggled: c => Config.decor.gtkButtons = c
        }
        CatChoice {
            // Desktop on a pixel skin: always _ □ X (services/ThemeExport)
            present: Config.decor.gtkButtons && !(WindowConfig.floatAll && !GoldenGate.on)
            label: I18n.t("Кнопки в заголовке", "Title bar buttons")
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
    // other apps in the theme's colours (Settings → Theme → More): the browser, Telegram, Steam,
    // Discord — each follows the theme by itself once it is set up
    CatGroup {
        name: "app-themes"
        title: I18n.t("Программы в цветах темы", "Apps in the theme's colours")
        icon: "palette"
        // the browsers' bar (templates/gtk3.css, palette key browserBar): Helium on its "GTK" theme
        // paints the tab strip, the open tab and the toolbar in one colour — this one
        CatCustom {
            id: barRow
            readonly property color shown: /^#[0-9a-f]{6}$/i.test(Config.decor.browserBar) ? Config.decor.browserBar : ThemeExport.browserBarAuto
            function step(towards) {
                Config.decor.browserBar = Theme.hex(Theme.mix(shown, towards, 0.12));
            }
            present: !Angel.hellShown
            label: I18n.t("Цвет панели браузера", "The browser's bar colour")
            hint: I18n.t("панель Helium и Chromium и открытая вкладка. В режиме «GTK» меняется сразу; в теме с заметной вкладкой — при следующем запуске браузера. «Авто» — чуть ярче заголовков окон", "The bar of Helium and Chromium and the open tab. On the “GTK” theme it changes at once; in the theme with a visible tab, at the browser's next start. “Auto”: a step brighter than the title bars")
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 3
                    // a Flow can't centre by anchors: the swatch sits in a box as tall as the buttons
                    Item {
                        width: Theme.u * 12
                        height: lighterButton.height
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: Theme.u * 8
                            color: barRow.shown
                            border.width: Math.max(1, Theme.u / 2)
                            border.color: Theme.tone("edge", Theme.p5For(parent))
                        }
                    }
                    PxButton {
                        id: lighterButton
                        compact: true
                        icon: "sun"
                        text: I18n.t("Светлее", "Lighter")
                        onClicked: barRow.step("#ffffff")
                    }
                    PxButton {
                        compact: true
                        icon: "moon"
                        text: I18n.t("Темнее", "Darker")
                        onClicked: barRow.step("#000000")
                    }
                    PxField {
                        width: Theme.u * 34
                        kind: "mono"
                        text: Config.decor.browserBar
                        placeholder: Theme.hex(ThemeExport.browserBarAuto)
                        onEdited: if (/^#[0-9a-f]{6}$/i.test(text) || text === "")
                            Config.decor.browserBar = text
                    }
                    PxButton {
                        visible: Config.decor.browserBar !== ""
                        compact: true
                        flat: true
                        icon: "refresh"
                        text: I18n.t("Авто", "Auto")
                        onClicked: Config.decor.browserBar = ""
                    }
                }
            }
        }
        // browsers (scripts/browser-theme.py): Helium and Chromium follow GTK live (their theme
        // "GTK") or read a theme extension at start; Firefox follows GTK by itself and gets the
        // palette from userChrome.css. Profiles change only by these buttons, with a copy and undo
        CatRepeat {
            model: browserStatus.list
            delegate: Component {
                CatCustom {
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
                        else if (b.tabs)
                            s = I18n.t("тема angelOS с заметной вкладкой: открытая вкладка светлая, остальные тёмные. Цвета " + n + " читает при запуске" + (b.stale ? " — тема сменилась, " + n + " ещё в старых цветах: новые будут, когда закроешь и откроешь его (или «Перезапустить сейчас»)" : "") + "; цвет — строкой выше. «Следовать теме angelOS» вернёт смену на лету, но без выделения вкладки", "angelOS's theme with a visible tab: the open tab is light, the others dark. " + n + " reads the colours when it starts" + (b.stale ? " — the theme changed, " + n + " still has the old colours: the new ones come when you close and open it (or “Restart now”)" : "") + "; the colour is the row above. “Follow angelOS's theme” brings back live switching, without the tab standing out");
                        else if (b.live)
                            s = Angel.hellShown ? I18n.t("в режиме «GTK»: цвета и кнопки окна angelOS, рай и ад — сразу", "In GTK mode: angelOS colours and window buttons, heaven and hell at once") : I18n.t("в режиме «GTK»: цвета и кнопки окна angelOS — сразу", "In GTK mode: angelOS colours and window buttons at once");
                        else if (b.pending)
                            s = I18n.t("включу, как закроешь " + n + ". Или «Перезапустить сейчас» — вкладки вернутся", "On as soon as you close " + n + ". Or “Restart now”: the tabs come back");
                        else if (b.static)
                            s = I18n.t("тема-расширение angelOS загружена: цвета подхватываются при каждом запуске." + (b.stale ? " Тема сменилась — перезапусти " + n + ", чтобы увидеть." : "") + " Чтобы рай и ад менялись на лету — «Следовать теме angelOS»", "The angelOS theme extension is loaded: its colours apply each time it starts." + (b.stale ? " The theme changed: restart " + n + " to see it." : "") + " For heaven and hell to switch live: “Follow angelOS's theme”");
                        else
                            s = I18n.t("«Следовать теме angelOS» — " + n + " меняет цвета вместе с системой (его тема «GTK»; профиль правлю только по кнопке, с копией и откатом). Или тема-расширение: " + (b.id === "helium" ? "helium" : "chrome") + "://extensions → Режим разработчика → «Загрузить распакованное» → папка ниже (цвета обновляются при запуске)", "“Follow angelOS's theme”: " + n + " changes colours with the system (its “GTK” theme; I edit the profile only by this button, with a copy and undo). Or the theme extension: " + (b.id === "helium" ? "helium" : "chrome") + "://extensions → Developer mode → “Load unpacked” → the folder below (colours refresh at start)");
                        return failed ? s + I18n.t(". Не вышло: ", ". Didn't work: ") + failed : s;
                    }
                    CatBox {
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
                                // Helium on the GTK theme can't show which tab is open: the theme extension
                                // can, loaded by a line in its flags file (browser-theme.py tabs)
                                PxButton {
                                    visible: browserRow.chromium && !browserRow.asking && !browserRow.b.tabs
                                    compact: true
                                    accent: browserRow.b.live
                                    icon: "eye"
                                    text: I18n.t("Заметная открытая вкладка", "Make the open tab stand out")
                                    onClicked: browserAct.go(browserRow.b.id, "tabs", "")
                                }
                                PxButton {
                                    // also the look "tabs" with old colours (b.stale): the restart takes the new ones
                                    visible: browserRow.asking || (browserRow.chromium && (browserRow.b.pending || (browserRow.b.tabs && browserRow.b.stale)))
                                    compact: true
                                    accent: true
                                    icon: "refresh"
                                    text: I18n.t("Перезапустить сейчас", "Restart now")
                                    onClicked: browserAct.go(browserRow.b.id, browserRow.asking ? browserAct.askVerb : browserRow.b.pending ? "apply" : "tabs", "restart")
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
                                    visible: !browserRow.asking && (browserRow.b.undo || browserRow.b.tabs || (!browserRow.chromium && browserRow.b.static))
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
            }
        }
        // a theme switch rewrites the theme files: ask again whether an open browser has old colours
        // a theme switch rewrites the theme files: ask again whether an open browser has old colours
        Connections {
            target: ThemeExport
            function onRenderedChanged() {
                browserStatus.running = true;
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
        CatCustom {
            id: telegramRow
            property bool copied: false
            present: telegramStatus.info.installed === true
            label: "Telegram"
            hint: I18n.t("тема angelOS для Telegram, меняется вместе с темой. Один раз: «Скопировать путь» → Telegram → Настройки чатов → ⋮ → «Выбрать из файла». Авто-ночной режим Telegram лучше выключить.", "angelOS's theme for Telegram, follows the theme. Once: Copy path → Telegram → Chat settings → ⋮ → Choose from file. Better switch Telegram's auto night mode off.")
            CatBox {
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
        }
        // Steam (scripts/steam-theme.py): a Millennium theme that follows on its own; only
        // with Millennium there (angelOS installs neither Steam nor Millennium)
        CatCustom {
            id: steamRow
            property string said: ""
            present: steamStatus.info.millennium === true
            label: "Steam"
            hint: I18n.t("тема angelOS для Steam через Millennium, меняется вместе с темой. Один раз: Steam → Millennium → Темы → angelOS или «Сделать активной» при закрытом Steam.", "angelOS's theme for Steam through Millennium, follows the theme. Once: Steam → Millennium → Themes → angelOS, or Make it active with Steam closed.")
            CatBox {
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
        // Discord and Vesktop (scripts/discord-theme.py): a Vencord theme that follows on its
        // own; Discord without Vencord only through angelOS's launcher (a debugging port)
        CatCustom {
            id: discordRow
            property string said: ""
            property bool askPort: false
            readonly property var info: discordStatus.info
            readonly property bool launcherOn: info.launcher === true
            present: info.found === true
            label: "Discord / Vesktop"
            hint: I18n.t("тема angelOS для Discord и Vesktop, меняется вместе с темой. С Vencord: Vencord → Темы → angelOS или «Сделать активной» при закрытом Discord. Без Vencord — только если запускать Discord из angelOS.", "angelOS's theme for Discord and Vesktop, follows the theme. With Vencord: Vencord → Themes → angelOS, or Make it active with Discord closed. Without Vencord: only when angelOS starts Discord.")
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 2
                    PxButton {
                        compact: true
                        visible: discordRow.info.vencord === true
                        accent: !discordRow.info.active
                        icon: "sparkle"
                        text: discordRow.info.active ? I18n.t("Активна ♡", "Active ♡") : discordRow.said || I18n.t("Сделать активной", "Make it active")
                        onClicked: if (!discordRow.info.active)
                            discordApply.running = true
                    }
                    PxButton {
                        compact: true
                        maxWidth: parent.width
                        visible: !!discordRow.info.discord
                        checked: discordRow.launcherOn
                        icon: "play"
                        text: discordRow.launcherOn ? I18n.t("Без Vencord: через angelOS ✓", "Without Vencord: through angelOS ✓") : I18n.t("Без Vencord: запускать через angelOS", "Without Vencord: start it through angelOS")
                        onClicked: {
                            if (discordRow.launcherOn) {
                                discordLauncher.command = ["python3", Quickshell.shellDir + "/scripts/discord-theme.py", "launcher", "off"];
                                discordLauncher.running = true;
                            } else {
                                discordRow.askPort = true;
                            }
                        }
                    }
                    PxButton {
                        compact: true
                        icon: "folder"
                        text: I18n.t("Папка темы", "Theme folder")
                        onClicked: Quickshell.execDetached(["xdg-open", String(discordRow.info.theme || "").replace(/\/[^\/]*$/, "")])
                    }
                }
                // the port is a door: said plainly before it is opened
                Column {
                    visible: discordRow.askPort
                    width: parent.width
                    spacing: Theme.u * 2
                    PxText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        color: Theme.danger
                        text: I18n.t("Discord будет запускаться с портом отладки: пока он открыт, любая программа на этом компьютере может управлять Discord и читать переписку. С Vencord это не нужно.", "Discord will start with a debugging port: while it is open, any program on this computer can control Discord and read your messages. Not needed with Vencord.")
                    }
                    Flow {
                        width: parent.width
                        spacing: Theme.u * 2
                        PxButton {
                            compact: true
                            danger: true
                            text: I18n.t("Понятно, включить", "Understood, switch it on")
                            onClicked: {
                                discordRow.askPort = false;
                                discordLauncher.command = ["python3", Quickshell.shellDir + "/scripts/discord-theme.py", "launcher", "on"];
                                discordLauncher.running = true;
                            }
                        }
                        PxButton {
                            compact: true
                            text: I18n.t("Отмена", "Cancel")
                            onClicked: discordRow.askPort = false
                        }
                    }
                }
                Process {
                    id: discordApply
                    command: ["python3", Quickshell.shellDir + "/scripts/discord-theme.py", "apply"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            try {
                                const r = JSON.parse(text);
                                discordRow.said = (r.running || []).length && !(r.done || []).length ? I18n.t("Закрой Discord или включи в Vencord → Темы", "Close Discord, or switch it on in Vencord → Themes") : r.ok ? "" : I18n.t("Не вышло — включи в Vencord → Темы", "Didn't work — switch it on in Vencord → Themes");
                            } catch (e) {}
                            discordStatus.running = true;
                        }
                    }
                }
                Process {
                    id: discordLauncher
                    onExited: discordStatus.running = true
                }
                Process {
                    id: discordStatus
                    property var info: ({})
                    running: true
                    command: ["python3", Quickshell.shellDir + "/scripts/discord-theme.py", "status"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            try {
                                discordStatus.info = JSON.parse(text);
                            } catch (e) {}
                        }
                    }
                }
            }
        }
    }
    // cobwebs (services/Cobweb): a window left where it is gathers a spider
    CatGroup {
        name: "cobweb"
        title: I18n.t("Паутина", "Cobwebs")
        icon: "spider"
        CatNote {
            dim: true
            text: I18n.t("Окно, которое давно не двигали, затягивает паутиной. Перетащи или потряси окно — паутина осыплется.", "A window nobody has moved for a while gets cobwebs. Drag or shake it and they fall off.")
        }
        CatToggle {
            label: I18n.t("Паутина на окнах", "Cobwebs on windows")
            checked: Config.windows.cobweb
            onToggled: c => Config.windows.cobweb = c
        }
        CatToggle {
            present: Config.windows.cobweb
            label: I18n.t("Поверх самого окна", "Over the window itself")
            hint: I18n.t("курсор ловится только на нитях, между ними клики идут в программу; в играх и во весь экран паутины нет", "The pointer is caught only on the threads, clicks between them go to the app; none in games or fullscreen")
            checked: Config.windows.cobwebInside
            onToggled: c => Config.windows.cobwebInside = c
        }
        CatToggle {
            present: Config.windows.cobweb
            label: I18n.t("На кнопке окна", "On the window's button")
            hint: I18n.t("маленькая паутинка и паучок на панели и в Dock", "A small web and a spider in the bar and the Dock")
            checked: Config.windows.cobwebBar
            onToggled: c => Config.windows.cobwebBar = c
        }
        CatChoice {
            present: Config.windows.cobweb
            label: I18n.t("Как быстро растёт", "How fast it grows")
            model: [
                {
                    "label": I18n.t("10 мин → 1 ч", "10 min → 1 h"),
                    "value": "fast"
                },
                {
                    "label": I18n.t("30 мин → 4 ч", "30 min → 4 h"),
                    "value": "normal"
                },
                {
                    "label": I18n.t("2 ч → сутки", "2 h → a day"),
                    "value": "slow"
                }
            ]
            currentValue: Config.windows.cobwebSpeed
            onActivated: v => Config.windows.cobwebSpeed = v
        }
        CatChoice {
            present: Config.windows.cobweb
            label: I18n.t("Вид кокона", "Cocoon look")
            hint: I18n.t("стандартный — точечная сетка, как было; шёлк — провисающие нити с перемычками. Окна возьмут новый вид после «Показать сейчас» или перезапуска", "Classic is the dotted grid it always was; silk is sagging strands with ties. Windows take the new look with «Show me now» or after a restart")
            model: [
                {
                    "label": I18n.t("Стандартный", "Classic"),
                    "value": "classic"
                },
                {
                    "label": I18n.t("Шёлк", "Silk"),
                    "value": "silk"
                }
            ]
            currentValue: cocoonPreview.effectiveStyle
            onActivated: v => cocoonPreview.commit("style", v)
        }
        CatCustom {
            wide: true
            CatBox {
                CobwebPreview {
                    id: cocoonPreview
                    visible: Config.windows.cobweb
                    width: parent.width
                }
            }
        }
        CatSlider {
            present: Config.windows.cobweb && cocoonPreview.effectiveStyle === "silk"
            label: I18n.t("Густота", "Density")
            hint: I18n.t("слои нитей: больше слоёв только доплетает новое", "Strand layers: more layers only append")
            from: Cobweb.tunerRange.density[0]
            to: Cobweb.tunerRange.density[1]
            stepSize: 0.1
            decimals: 1
            suffix: "×"
            value: Config.windows.cobwebDensity
            onMoved: v => cocoonPreview.setLive("density", v)
            onReleased: v => cocoonPreview.commit("density", v)
        }
        CatSlider {
            present: Config.windows.cobweb && cocoonPreview.effectiveStyle === "silk"
            label: I18n.t("Длинные пучки", "Long bands")
            hint: I18n.t("пучки нитей от края до края", "Bands of strands, edge to edge")
            from: Cobweb.tunerRange.bundles[0]
            to: Cobweb.tunerRange.bundles[1]
            stepSize: 0.35
            decimals: 2
            suffix: "×"
            value: Config.windows.cobwebBundles
            onMoved: v => cocoonPreview.setLive("bundles", v)
            onReleased: v => cocoonPreview.commit("bundles", v)
        }
        CatSlider {
            present: Config.windows.cobweb && cocoonPreview.effectiveStyle === "silk"
            label: I18n.t("Перемычки", "Bridges")
            hint: I18n.t("короткие связи между соседними нитями", "Short ties between neighbouring strands")
            from: Cobweb.tunerRange.bridges[0]
            to: Cobweb.tunerRange.bridges[1]
            stepSize: 0.05
            decimals: 2
            suffix: "×"
            value: Config.windows.cobwebBridges
            onMoved: v => cocoonPreview.setLive("bridges", v)
            onReleased: v => cocoonPreview.commit("bridges", v)
        }
        CatSlider {
            present: Config.windows.cobweb && cocoonPreview.effectiveStyle === "silk"
            label: I18n.t("Провисание", "Sag")
            hint: I18n.t("насколько нити висят под своим весом", "How much the threads hang")
            from: Cobweb.tunerRange.gravity[0]
            to: Cobweb.tunerRange.gravity[1]
            stepSize: 0.05
            decimals: 2
            suffix: "×"
            value: Config.windows.cobwebGravity
            onMoved: v => cocoonPreview.setLive("gravity", v)
            onReleased: v => cocoonPreview.commit("gravity", v)
        }
        CatCustom {
            wide: true
            CatBox {
                Row {
                    visible: Config.windows.cobweb
                    spacing: Theme.u * 3
                    PxButton {
                        compact: true
                        icon: "play"
                        text: I18n.t("Показать сейчас", "Show me now")
                        enabled: Cobweb.enabled
                        onClicked: {
                            // the visible windows' webs are built anew, one by one, in the saved
                            // look and tuning (anything still held by the preview is saved first)
                            cocoonPreview.commitLive();
                            Cobweb.demo();
                        }
                    }
                    PxButton {
                        compact: true
                        icon: "close"
                        text: I18n.t("Смахнуть всю", "Sweep it all")
                        enabled: Cobweb.enabled
                        onClicked: Cobweb.clearAll()
                    }
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.u * 200
                        wrapMode: Text.Wrap
                        kind: "tiny"
                        color: Cobweb.shakeStatus === "noperm" ? Theme.danger : Theme.tone("textDim", Theme.p5For(parent))
                        text: Cobweb.shakeStatus === "noperm" ? I18n.t("нет доступа к мыши (группа input): тряску окна не видно — смахнуть паутину можно из меню кнопки окна (ПКМ)", "No access to the mouse (the input group): shaking a window can't be seen — sweep the web from the window button's menu (right click)") : Cobweb.webCount > 0 ? I18n.t("паутина на окнах: ", "webs on windows: ") + Cobweb.webCount : ""
                    }
                }
            }
        }
    }
    CatNote {
        text: WindowConfig.log
        dim: true
    }
}
