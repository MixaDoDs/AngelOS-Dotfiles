pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

PxPage {
    id: page

    heading: I18n.t("Экран", "Display")
    subtitle: I18n.t("«Применить» меняет сразу, «Сохранить» пишет ~/.config/niri/monitor.kdl (с бэкапом и проверкой niri validate).", "Apply changes the live layout. Save to config writes monitor.kdl with a backup and niri validation.")

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
    PxGroup {
        name: "main-screen"
        title: I18n.t("Главный экран", "Main screen")
        icon: "star"
        width: parent.width
        SettingRow {
            label: I18n.t("Главный экран", "Main screen")
            hint: Angel.hellShown ? I18n.t("здесь живут виджеты, ангел (и трещины демоницы, лучи, тряска), заставка и сайдбар; niri фокусирует его при входе. «Авто» — самый широкий экран", "Home of the widgets, the angel (and the demon's cracks, the rays, the quake), the idle screen and the sidebar; niri focuses it at login. “Auto” is the widest screen") : I18n.t("здесь живут виджеты, ангел (и её лучи, тряска), заставка и сайдбар; niri фокусирует его при входе. «Авто» — самый широкий экран", "Home of the widgets, the angel (and her rays, the quake), the idle screen and the sidebar; niri focuses it at login. “Auto” is the widest screen")
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
        SettingRow {
            visible: page.widgetsElsewhere > 0
            label: I18n.t("Виджеты на других экранах: ", "Widgets on other screens: ") + page.widgetsElsewhere
            hint: I18n.t("перенести их все на главный (позиции сохранятся, лишнее прижмётся к краю)", "Move them all to the main screen (positions kept, anything off the edge snaps back)")
            PxButton {
                compact: true
                icon: "layers"
                text: I18n.t("Перенести сюда", "Move here")
                onClicked: DesktopWidgets.moveAllTo(Shell.primaryName)
            }
        }
        // her screen and the sidebar's are set on their own pages: links there
        SettingLink {
            visible: page.angelOwn !== ""
            label: I18n.t("У ангела свой экран: ", "The angel has her own screen: ") + page.angelOwn
            hint: I18n.t("«На каком экране»; пусто — главный, и её трещины и лучи тоже уйдут туда", "“Screen”; empty is the main one, and her cracks and rays move there too")
            page: "helper"
            group: "demon-corner"
        }
        SettingLink {
            visible: !!Config.sidebar.screen && Config.sidebar.screen !== Shell.primaryName
            label: I18n.t("У сайдбара свой экран: ", "The sidebar has its own screen: ") + Config.sidebar.screen
            page: "taskbar"
            group: "sidebar-experimental"
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: !Outputs.primaryLog.startsWith("niri: ")
            color: Outputs.primaryLog.startsWith("niri: ") ? Theme.danger : Theme.textDim
            text: Outputs.primaryLog || (Outputs.niriFocused.length ? I18n.t("niri при входе фокусирует: ", "niri focuses at login: ") + Outputs.niriFocused.join(", ") : I18n.t("niri при входе фокусирует первый экран (focus-at-startup не задан)", "niri focuses the first screen at login (no focus-at-startup)"))
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            visible: StreamMode.active && Config.stream.hideAngel && StreamMode.onStream(Shell.primaryName)
            text: I18n.t("Сейчас идёт эфир: ангел и её эффекты ушли с этого экрана (Система → Стрим-режим)", "You're live: the angel and her effects have left this screen (System → Stream mode)")
        }
    }

    PxGroup {
        name: "brightness-colour"
        title: I18n.t("Яркость и цвет", "Brightness and colour")
        icon: "sun"
        width: parent.width

        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            text: I18n.t("Программно, через гамму видеокарты: подсветку монитора не трогает, на стрим и скриншоты не попадает. Ночной свет работает вместе с яркостью.", "In software, through the GPU's gamma: the monitor's backlight stays as it is, nothing shows on stream or in screenshots. The night light works together with it.") + (ScreenTune.nvidia ? "" : I18n.t(" Насыщенность — только на видеокартах NVIDIA.", " Saturation needs an NVIDIA GPU."))
        }
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
                PxButton {
                    compact: true
                    icon: "refresh"
                    text: I18n.t("Как было", "As it was")
                    visible: ScreenTune.brightnessOf(tuneRow.modelData) < 1 || ScreenTune.saturationOf(tuneRow.modelData) !== 0
                    onClicked: ScreenTune.reset(tuneRow.modelData)
                }
            }
        }
    }

    PxGroup {
        name: "arrangement"
        title: I18n.t("Расположение", "Arrangement")
        icon: "monitor"
        width: parent.width

        PxBox {
            id: canvas
            width: parent.width
            height: Theme.u * 110
            sunken: true
            color: Qt.alpha(Theme.sunken, 0.8)

            readonly property var names: Object.keys(Outputs.draft).filter(n => !Outputs.draft[n].off)
            readonly property var bounds: {
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
                        color: page.selected === mon.modelData ? Theme.mix(Theme.face, Theme.accent, 0.35) : Theme.face
                        edgeColor: page.selected === mon.modelData ? Theme.accent : Theme.edge
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
                                text: Math.round(mon.dd.x) + ", " + Math.round(mon.dd.y)
                                kind: "tiny"
                                dim: true
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor
                        property point start
                        property point orig
                        onPressed: m => {
                            page.selected = mon.modelData;
                            start = mapToItem(canvas, m.x, m.y);
                            orig = Qt.point(mon.dd.x, mon.dd.y);
                        }
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

    PxGroup {
        name: "output"
        visible: !!page.d
        title: page.selected + (page.o ? "  ·  " + (page.o.make || "") + " " + (page.o.model || "") : "")
        icon: "gear"
        width: parent.width

        SettingRow {
            label: I18n.t("Включён", "Enabled")
            PxToggle {
                checked: page.d ? !page.d.off : false
                onToggled: c => Outputs.set(page.selected, "off", !c)
            }
        }
        SettingRow {
            label: I18n.t("Режим", "Mode")
            PxCombo {
                width: parent.width
                model: page.o ? page.o.modes.map(m => ({
                            "label": Outputs.modeLabel(m),
                            "value": Outputs.modeString(m)
                        })) : []
                currentValue: page.d ? page.d.mode : ""
                onActivated: v => Outputs.set(page.selected, "mode", v)
            }
        }
        SettingRow {
            label: I18n.t("Масштаб", "Scale")
            hint: page.d && Math.abs(page.d.scale - Math.round(page.d.scale)) > 0.001 ? I18n.t("Дробный масштаб размывает пиксельные шрифты и рамки angelOS: их пиксели ложатся между пикселями экрана. Чётко — целый масштаб (1, 2), а крупнее — размером пикселя и масштабом шрифтов («Тема и цвета» → «Размер пикселя», «Шрифты» → «Масштаб шрифтов»).", "A fractional scale blurs angelOS's pixel fonts and frames: their pixels fall between the screen's. Crisp: a whole scale (1, 2), and bigger with the pixel size and the font scale (Theme and colours → Pixel size, Fonts → Font scale).") : ""
            PxSpin {
                from: 0.5
                to: 3
                stepSize: 0.05
                decimals: 2
                value: page.d ? page.d.scale : 1
                onMoved: v => Outputs.set(page.selected, "scale", v)
            }
        }
        SettingRow {
            label: I18n.t("Поворот", "Rotation")
            PxCombo {
                width: Theme.u * 100
                model: Outputs.transforms
                currentValue: page.d ? page.d.transform : "normal"
                onActivated: v => Outputs.set(page.selected, "transform", v)
            }
        }
        SettingRow {
            label: I18n.t("Позиция", "Position")
            Row {
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
        SettingRow {
            label: "VRR / FreeSync"
            hint: page.o && !page.o.vrr_supported ? I18n.t("монитор не поддерживает", "Not supported by the display") : ""
            PxToggle {
                enabled: page.o ? !!page.o.vrr_supported : false
                checked: page.d ? page.d.vrr : false
                onToggled: c => Outputs.set(page.selected, "vrr", c)
            }
        }
    }

    Row {
        spacing: Theme.u * 4
        PxButton {
            text: I18n.t("Применить", "Apply")
            icon: "check"
            accent: true
            enabled: !Outputs.busy
            onClicked: Outputs.apply()
        }
        PxButton {
            text: I18n.t("Сохранить в конфиг", "Save to config")
            icon: "package"
            enabled: !Outputs.busy
            onClicked: Outputs.save()
        }
        PxButton {
            text: I18n.t("Сбросить", "Reset")
            icon: "refresh"
            onClicked: Outputs.refresh()
        }
    }
    PxText {
        width: parent.width
        wrapMode: Text.Wrap
        text: Outputs.log
        dim: true
    }
}
