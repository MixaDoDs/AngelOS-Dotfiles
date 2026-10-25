// The settings once in MonitorPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

CatPage {
    id: page
    heading: I18n.t("Экран", "Display")
    subtitle: I18n.t("Разрешение, масштаб, поворот и расположение экранов.", "Resolution, scale, rotation and layout of the screens.")
    property string selected: Object.keys(Outputs.draft)[0] || ""
    readonly property var d: Outputs.draft[selected] || null
    readonly property var o: Outputs.outputs[selected] || null
    function logicalSize(name) {
        const dd = Outputs.draft[name];
        if (!dd || !dd.mode)
            return [1920, 1080];
        const m = dd.mode.match(/(\d+)x(\d+)/);
        let w = parseInt(m[1]), h = parseInt(m[2]);
        if (/90|270/.test(dd.transform))
            [w, h] = [h, w];
        return [w / dd.scale, h / dd.scale];
    }
    // the main screen: where the desk lives (Shell.primaryScreen)
    readonly property int widgetsElsewhere: DesktopWidgets.widgets.filter(w => w.screen !== Shell.primaryName).length
    readonly property string angelOwn: Config.y2k.helperScreen && Config.y2k.helperScreen !== "focus" && Config.y2k.helperScreen !== Shell.primaryName ? Config.y2k.helperScreen : ""
    CatGroup {
        name: "arrangement"
        title: I18n.t("Расположение", "Arrangement")
        icon: "monitor"
        CatCustom {
            wide: true
            CatBox {
                PxBox {
                    id: canvas
                    width: parent.width
                    height: Theme.u * 110
                    sunken: true
                    color: Qt.alpha(Theme.tone("sunken", Theme.p5For(parent)), 0.8)

                    // through a string: a move replaces the draft, and a new array would rebuild the
                    // monitors (the one under the mouse with them, dropping the drag)
                    readonly property string nameKey: Object.keys(Outputs.draft).filter(n => !Outputs.draft[n].off).join("\n")
                    readonly property var names: nameKey ? nameKey.split("\n") : []
                    // the frame stays put while a monitor is dragged, or it would slide from under the mouse
                    property var held: null
                    readonly property var bounds: held || fit
                    readonly property var fit: {
                        let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
                        for (const n of names) {
                            const dd = Outputs.draft[n], s = page.logicalSize(n);
                            x0 = Math.min(x0, dd.x);
                            y0 = Math.min(y0, dd.y);
                            x1 = Math.max(x1, dd.x + s[0]);
                            y1 = Math.max(y1, dd.y + s[1]);
                        }
                        return names.length ? [x0, y0, x1, y1] : [0, 0, 1920, 1080];
                    }
                    readonly property real k: Math.min((width - Theme.u * 20) / (bounds[2] - bounds[0]), (height - Theme.u * 20) / (bounds[3] - bounds[1]))
                    readonly property real ox: (width - (bounds[2] - bounds[0]) * k) / 2
                    readonly property real oy: (height - (bounds[3] - bounds[1]) * k) / 2

                    Repeater {
                        model: canvas.names
                        Item {
                            id: mon
                            required property string modelData
                            readonly property var dd: Outputs.draft[modelData]
                            readonly property var sz: page.logicalSize(modelData)
                            x: canvas.ox + (dd.x - canvas.bounds[0]) * canvas.k
                            y: canvas.oy + (dd.y - canvas.bounds[1]) * canvas.k
                            width: sz[0] * canvas.k
                            height: sz[1] * canvas.k

                            PxBox {
                                anchors.fill: parent
                                color: page.selected === mon.modelData ? Theme.mix(Theme.tone("face", Theme.p5For(parent)), Theme.accent, 0.35) : Theme.tone("face", Theme.p5For(parent))
                                edgeColor: page.selected === mon.modelData ? Theme.accent : Theme.tone("edge", Theme.p5For(parent))
                                Column {
                                    anchors.centerIn: parent
                                    PxIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        name: "monitor"
                                    }
                                    PxText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: (Shell.primaryName === mon.modelData ? "★ " : "") + mon.modelData
                                        font.bold: true
                                    }
                                    PxText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: Math.round(mon.dd.x) + ", " + Math.round(mon.dd.y) + (mon.dd.transform !== "normal" ? "  ↻ " + Outputs.turnOf(mon.dd.transform) + "°" + (Outputs.mirroredOf(mon.dd.transform) ? I18n.t(" зерк.", " mirr.") : "") : "")
                                        kind: "tiny"
                                        dim: true
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.SizeAllCursor
                                preventStealing: true
                                property point start
                                property point orig
                                onPressed: m => {
                                    page.selected = mon.modelData;
                                    canvas.held = canvas.fit;
                                    start = mapToItem(canvas, m.x, m.y);
                                    orig = Qt.point(mon.dd.x, mon.dd.y);
                                }
                                onReleased: canvas.held = null
                                onCanceled: canvas.held = null
                                onPositionChanged: m => {
                                    if (!pressed)
                                        return;
                                    const p = mapToItem(canvas, m.x, m.y);
                                    let nx = orig.x + (p.x - start.x) / canvas.k;
                                    let ny = orig.y + (p.y - start.y) / canvas.k;
                                    // snap to other monitors' edges
                                    const snap = 40;
                                    for (const other of canvas.names) {
                                        if (other === mon.modelData)
                                            continue;
                                        const od = Outputs.draft[other], os = page.logicalSize(other);
                                        for (const [a, b] of [[nx, od.x + os[0]], [nx + mon.sz[0], od.x], [nx, od.x], [nx + mon.sz[0], od.x + os[0]]])
                                            if (Math.abs(a - b) < snap)
                                                nx += b - a;
                                        for (const [a, b] of [[ny, od.y + os[1]], [ny + mon.sz[1], od.y], [ny, od.y], [ny + mon.sz[1], od.y + os[1]]])
                                            if (Math.abs(a - b) < snap)
                                                ny += b - a;
                                    }
                                    Outputs.set(mon.modelData, "x", Math.round(nx));
                                    Outputs.set(mon.modelData, "y", Math.round(ny));
                                }
                            }
                        }
                    }
                }
            }
        }
        CatCustom {
            wide: true
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 3
                    Repeater {
                        model: Object.keys(Outputs.draft)
                        PxButton {
                            required property string modelData
                            text: modelData
                            icon: "monitor"
                            checked: page.selected === modelData
                            onClicked: page.selected = modelData
                        }
                    }
                }
            }
        }
    }
    CatGroup {
        name: "output"
        title: page.selected + (page.o ? "  ·  " + (page.o.make || "") + " " + (page.o.model || "") : "")
        icon: "gear"
        present: !!page.d
        CatToggle {
            label: I18n.t("Включён", "Enabled")
            checked: page.d ? !page.d.off : false
            onToggled: c => Outputs.set(page.selected, "off", !c)
        }
        CatChoice {
            label: I18n.t("Разрешение и частота", "Resolution and rate")
            combo: true
            model: page.o ? page.o.modes.map(m => ({
                        "label": Outputs.modeLabel(m),
                        "value": Outputs.modeString(m)
                    })) : []
            currentValue: page.d ? page.d.mode : ""
            onActivated: v => Outputs.set(page.selected, "mode", v)
        }
        CatSpin {
            label: I18n.t("Масштаб", "Scale")
            hint: page.d && Math.abs(page.d.scale - Math.round(page.d.scale)) > 0.001 ? I18n.t("дробный масштаб размывает пиксели. Лучше 1 или 2, а крупнее — в «Доступности» → «Размер интерфейса»", "A fractional scale blurs the pixels. Better 1 or 2; bigger in Accessibility → Interface size") : ""
            from: 0.5
            to: 3
            stepSize: 0.05
            decimals: 2
            value: page.d ? page.d.scale : 1
            onMoved: v => Outputs.set(page.selected, "scale", v)
        }
        // how it stands: applied at once, back in 15 s unless kept (the banner below)
        CatCustom {
            label: I18n.t("Ориентация", "Orientation")
            hint: I18n.t("Повернуть картинку. Если не нажать «Оставить», через 15 секунд вернётся как было.", "Turn the picture. It goes back in 15 seconds unless you keep it.")
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 2
                    Repeater {
                        model: Outputs.turns
                        PxButton {
                            required property var modelData
                            compact: true
                            icon: modelData.value === "0" ? "monitor" : "rotate"
                            text: modelData.label
                            checked: page.d ? Outputs.turnOf(page.d.transform) === modelData.value : false
                            enabled: !Outputs.busy && !!page.d && !page.d.off
                            onClicked: Outputs.turn(page.selected, Outputs.transformOf(modelData.value, Outputs.mirroredOf(page.d.transform)))
                        }
                    }
                }
            }
        }
        CatToggle {
            label: I18n.t("Зеркально", "Mirrored")
            hint: I18n.t("отразить слева направо — для проектора на просвет или телесуфлёра", "flip left to right: for a rear projector or a teleprompter")
            enabled: !Outputs.busy && !!page.d && !page.d.off
            checked: page.d ? Outputs.mirroredOf(page.d.transform) : false
            onToggled: c => Outputs.turn(page.selected, Outputs.transformOf(Outputs.turnOf(page.d.transform), c))
        }
        CatCustom {
            label: I18n.t("Позиция", "Position")
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 3
                    PxField {
                        width: Theme.u * 40
                        text: page.d ? String(Math.round(page.d.x)) : "0"
                        onAccepted: Outputs.set(page.selected, "x", parseInt(text) || 0)
                    }
                    PxField {
                        width: Theme.u * 40
                        text: page.d ? String(Math.round(page.d.y)) : "0"
                        onAccepted: Outputs.set(page.selected, "y", parseInt(text) || 0)
                    }
                }
            }
        }
        CatToggle {
            label: "VRR / FreeSync"
            hint: page.o && !page.o.vrr_supported ? I18n.t("монитор не поддерживает", "Not supported by the display") : ""
            enabled: page.o ? !!page.o.vrr_supported : false
            checked: page.d ? page.d.vrr : false
            onToggled: c => Outputs.set(page.selected, "vrr", c)
        }
    }
    CatGroup {
        name: "brightness-colour"
        title: I18n.t("Яркость и цвет", "Brightness and colour")
        icon: "sun"
        CatNote {
            textKind: "tiny"
            dim: true
            text: I18n.t("Программно, через гамму видеокарты: подсветку монитора не трогает, на стрим и скриншоты не попадает. Ночной свет работает вместе с яркостью.", "In software, through the GPU's gamma: the monitor's backlight stays as it is, nothing shows on stream or in screenshots. The night light works together with it.") + (ScreenTune.nvidia ? "" : I18n.t(" Насыщенность — только на видеокартах NVIDIA.", " Saturation needs an NVIDIA GPU."))
        }
        CatCustom {
            wide: true
            CatBox {
                Repeater {
                    model: Quickshell.screens.map(sc => sc.name)
                    delegate: Column {
                        id: tuneRow
                        required property string modelData
                        readonly property var info: Outputs.outputs[modelData] || null
                        width: parent.width
                        spacing: Theme.u * 2

                        PxText {
                            text: (Shell.primaryName === tuneRow.modelData ? "★ " : "") + tuneRow.modelData + (tuneRow.info ? "  ·  " + ((tuneRow.info.make || "") + " " + (tuneRow.info.model || "")).trim() : "")
                            font.bold: true
                        }
                        SettingRow {
                            label: I18n.t("Яркость", "Brightness")
                            hint: ScreenTune.stateOf(tuneRow.modelData) === "failed" ? I18n.t("гамму этого монитора держит другая программа (wlsunset, gammastep?) — закрой её", "Another program holds this monitor's gamma (wlsunset, gammastep?): close it") : ""
                            PxSlider {
                                width: parent.width
                                from: 30
                                to: 100
                                stepSize: 1
                                suffix: " %"
                                value: Math.round(ScreenTune.brightnessOf(tuneRow.modelData) * 100)
                                onMoved: v => ScreenTune.setTune(tuneRow.modelData, "brightness", v >= 100 ? null : Math.round(v) / 100)
                            }
                        }
                        SettingRow {
                            visible: ScreenTune.nvidia
                            label: I18n.t("Насыщенность", "Saturation")
                            hint: ScreenTune.vibranceError || I18n.t("NVIDIA Digital Vibrance: −100 % — серый, +100 % — вдвое ярче цвета", "NVIDIA Digital Vibrance: −100 % is grey, +100 % doubles the colour")
                            PxSlider {
                                width: parent.width
                                from: -100
                                to: 100
                                stepSize: 5
                                suffix: " %"
                                value: Math.round(ScreenTune.saturationOf(tuneRow.modelData) * 100)
                                onMoved: v => ScreenTune.setTune(tuneRow.modelData, "saturation", Math.round(v) === 0 ? null : Math.round(v) / 100)
                            }
                        }
                        // gamma, contrast and the channels: the same gamma tables as brightness
                        Repeater {
                            model: [
                                {
                                    "key": "gamma",
                                    "label": I18n.t("Гамма", "Gamma"),
                                    "hint": I18n.t("больше 1 — светлее полутона, тени видно лучше", "Above 1 lifts the mid-tones, shadows show more"),
                                    "decimals": 2,
                                    "suffix": ""
                                },
                                {
                                    "key": "contrast",
                                    "label": I18n.t("Контраст", "Contrast"),
                                    "hint": "",
                                    "decimals": 0,
                                    "suffix": " %"
                                },
                                {
                                    "key": "red",
                                    "label": I18n.t("Красный", "Red"),
                                    "hint": "",
                                    "decimals": 0,
                                    "suffix": " %"
                                },
                                {
                                    "key": "green",
                                    "label": I18n.t("Зелёный", "Green"),
                                    "hint": "",
                                    "decimals": 0,
                                    "suffix": " %"
                                },
                                {
                                    "key": "blue",
                                    "label": I18n.t("Синий", "Blue"),
                                    "hint": "",
                                    "decimals": 0,
                                    "suffix": " %"
                                }
                            ]
                            SettingRow {
                                id: curveRow
                                required property var modelData
                                readonly property var range: ScreenTune.curve[modelData.key]
                                // gamma as it is (1.00), the rest in per cent
                                readonly property real scale: modelData.decimals ? 1 : 100
                                width: parent.width
                                label: modelData.label
                                hint: modelData.hint
                                PxSlider {
                                    width: parent.width
                                    from: curveRow.range[1] * curveRow.scale
                                    to: curveRow.range[2] * curveRow.scale
                                    stepSize: curveRow.modelData.decimals ? 0.05 : 1
                                    decimals: curveRow.modelData.decimals
                                    suffix: curveRow.modelData.suffix
                                    value: ScreenTune.curveOf(tuneRow.modelData, curveRow.modelData.key) * curveRow.scale
                                    onMoved: v => {
                                        const x = Math.round(v / curveRow.scale * 100) / 100;
                                        ScreenTune.setTune(tuneRow.modelData, curveRow.modelData.key, x === curveRow.range[0] ? null : x);
                                    }
                                }
                            }
                        }
                        PxButton {
                            compact: true
                            icon: "refresh"
                            text: I18n.t("Как было", "As it was")
                            visible: ScreenTune.tuned(tuneRow.modelData)
                            onClicked: ScreenTune.reset(tuneRow.modelData)
                        }
                    }
                }
            }
        }
    }
    CatGroup {
        name: "main-screen"
        title: I18n.t("Главный экран", "Main screen")
        icon: "star"
        CatCustom {
            label: I18n.t("Главный экран", "Main screen")
            hint: Angel.hellShown ? I18n.t("здесь виджеты, ангел и её эффекты, заставка, пароль на замке. «Авто» — самый широкий экран", "The widgets, the angel and her effects, the idle screen and the lock's password live here. Auto: the widest screen") : I18n.t("здесь виджеты, ангел, заставка, пароль на замке. «Авто» — самый широкий экран", "The widgets, the angel, the idle screen and the lock's password live here. Auto: the widest screen")
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 2
                    Repeater {
                        model: [
                            {
                                "label": I18n.t("Авто (", "Auto (") + (Shell.widestScreen ? Shell.widestScreen.name : "—") + ")",
                                "value": ""
                            }
                        ].concat(Quickshell.screens.map(sc => ({
                                    "label": sc.name,
                                    "value": sc.name
                                })))
                        PxButton {
                            required property var modelData
                            compact: true
                            icon: modelData.value && modelData.value === Shell.primaryName ? "star" : ""
                            text: modelData.label
                            checked: (Config.system.primaryScreen || "") === modelData.value
                            enabled: !Outputs.busy
                            onClicked: Outputs.setPrimary(modelData.value)
                        }
                    }
                }
            }
        }
        CatButton {
            label: I18n.t("Экраны (как Win+P)", "Screens (like Win+P)")
            hint: I18n.t("только этот, повторить, расширить, только второй — Win+P", "This one only, duplicate, extend, the second only: Win+P")
            compact: true
            icon: "monitor"
            text: I18n.t("Открыть", "Open")
            onClicked: Shell.projectOpen = true
        }
        CatButton {
            present: page.widgetsElsewhere > 0
            label: I18n.t("Виджеты на других экранах: ", "Widgets on other screens: ") + page.widgetsElsewhere
            hint: I18n.t("перенести их все на главный (позиции сохранятся, лишнее прижмётся к краю)", "Move them all to the main screen (positions kept, anything off the edge snaps back)")
            compact: true
            icon: "layers"
            confirm: true
            text: confirming ? I18n.t("Точно? Ещё раз", "Sure? Again") : I18n.t("Перенести сюда", "Move here")
            onConfirmed: DesktopWidgets.moveAllTo(Shell.primaryName)
        }
        // her screen and the sidebar's are set on their own pages: links there
        CatLink {
            present: page.angelOwn !== ""
            label: I18n.t("У ангела свой экран: ", "The angel has her own screen: ") + page.angelOwn
            hint: I18n.t("«На каком экране»; пусто — главный, и её трещины и лучи тоже уйдут туда", "“Screen”; empty is the main one, and her cracks and rays move there too")
            page: "helper"
            group: "demon-corner"
        }
        CatLink {
            present: !!Config.sidebar.screen && Config.sidebar.screen !== Shell.primaryName
            label: I18n.t("У сайдбара свой экран: ", "The sidebar has its own screen: ") + Config.sidebar.screen
            page: "taskbar"
            group: "sidebar-experimental"
        }
        CatNote {
            textKind: "tiny"
            dim: !Outputs.primaryLog.startsWith("niri: ")
            text: Outputs.primaryLog || (Outputs.niriFocused.length ? I18n.t("niri при входе фокусирует: ", "niri focuses at login: ") + Outputs.niriFocused.join(", ") : I18n.t("niri при входе фокусирует первый экран (focus-at-startup не задан)", "niri focuses the first screen at login (no focus-at-startup)"))
        }
        CatNote {
            textKind: "tiny"
            dim: true
            present: StreamMode.active && Config.stream.hideAngel && StreamMode.onStream(Shell.primaryName)
            text: I18n.t("Сейчас идёт эфир: ангел и её эффекты ушли с этого экрана (Стрим → Стрим-режим)", "You're live: the angel and her effects have left this screen (Streaming → Stream mode)")
        }
    }
    // a turned / re-moded screen comes back by itself unless kept
    CatCustom {
        wide: true
        CatBox {
            // a turned / re-moded screen comes back by itself unless kept
            PxBox {
                visible: Outputs.undo !== null
                width: parent.width
                height: keepRow.implicitHeight + Theme.u * 8
                color: Theme.mix(Theme.tone("face", Theme.p5For(parent)), Theme.accent, 0.25)
                Row {
                    id: keepRow
                    x: Theme.u * 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.u * 8
                    spacing: Theme.u * 3
                    PxText {
                        width: parent.width - keepBtn.width - backBtn.width - parent.spacing * 2
                        anchors.verticalCenter: parent.verticalCenter
                        wrapMode: Text.Wrap
                        text: I18n.t("Оставить так? Через ", "Keep this? Going back in ") + Outputs.confirmLeft + I18n.t(" с вернётся как было.", " s.")
                    }
                    PxButton {
                        id: keepBtn
                        accent: true
                        icon: "check"
                        text: I18n.t("Оставить", "Keep")
                        anchors.verticalCenter: parent.verticalCenter
                        // kept = saved, as Windows does: «Keep» used to leave it live only, back as it was
                        // after a reboot (16.10)
                        onClicked: {
                            Outputs.keep();
                            Outputs.save();
                        }
                    }
                    PxButton {
                        id: backBtn
                        icon: "arrowLeft"
                        text: I18n.t("Вернуть", "Revert")
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: Outputs.revert()
                    }
                }
            }
        }
    }
    CatCustom {
        wide: true
        CatBox {
            Row {
                spacing: Theme.u * 4
                // «Apply» keeps it after a reboot too (a change that may leave the screen unreadable is
                // saved once «Keep» says so); «Just try» is live only, until the next start
                PxButton {
                    text: I18n.t("Применить", "Apply")
                    icon: "check"
                    accent: true
                    enabled: !Outputs.busy
                    onClicked: {
                        Outputs.apply();
                        if (!Outputs.undo)
                            Outputs.save();
                    }
                }
                PxButton {
                    text: I18n.t("Только попробовать", "Just try")
                    icon: "eye"
                    enabled: !Outputs.busy
                    onClicked: Outputs.apply()
                }
                PxButton {
                    text: I18n.t("Сбросить", "Reset")
                    icon: "refresh"
                    onClicked: Outputs.refresh()
                }
            }
        }
    }
    CatNote {
        text: Outputs.log
        dim: true
    }
}
