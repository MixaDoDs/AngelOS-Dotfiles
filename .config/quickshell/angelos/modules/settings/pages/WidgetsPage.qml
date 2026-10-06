pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

PxPage {
    id: page

    heading: I18n.t("Виджеты", "Widgets")
    subtitle: DesktopWidgets.macLook ? I18n.t("Карточки на рабочем столе. Двойной клик по карточке — режим правки: в нём карточку таскают за любое место, «−» убирает её. Ещё их можно добавить через ПКМ → Вид.", "Cards on the desktop. Double-click a card for edit mode: there you drag it anywhere, “−” removes it. You can also add them via right-click → View.") : I18n.t("Окошки на рабочем столе. Таскаются за заголовок; двойной клик по заголовку — режим правки с крестиками. Ещё их можно добавить через ПКМ → Вид.", "Little windows on the desktop. Drag them by the title; double-click the title for edit mode. You can also add them via right-click → View.")

    property string newType: DesktopWidgets.types.length ? DesktopWidgets.types[0].type : ""
    property string newScreen: Shell.primaryName || (Quickshell.screens[0] ? Quickshell.screens[0].name : "")
    readonly property var screenModel: Quickshell.screens.map(s => ({
                "label": s.name,
                "value": s.name
            }))

    // what the cava widget can listen to: outputs, whole multichannel interfaces,
    // their labelled channel pairs, and (marked) inputs — scripts/audio-tap.py list
    property var tap: ({
            "auto": "",
            "nodes": []
        })
    readonly property var tapModel: {
        const out = [
            {
                "label": I18n.t("Авто: весь звук ПК", "Auto: all computer sound") + (tap.auto ? " · " + tap.auto : ""),
                "value": ""
            }
        ];
        const outs = tap.nodes.filter(n => n.kind === "output");
        const ins = tap.nodes.filter(n => n.kind === "input");
        for (const n of outs) {
            out.push({
                "label": "♪ " + n.description,
                "value": "monitor:" + n.name
            });
            if (n.pairs.length) {
                out.push({
                    "label": "♪ " + n.description + I18n.t(" — все каналы (", " — all channels (") + n.channels.length + ")",
                    "value": "all:" + n.name
                });
                for (const pr of n.pairs)
                    out.push({
                        "label": "   ↳ " + (pr.label ? pr.label + " · " : "") + pr.channels.join("/"),
                        "value": "pair:" + n.name + ":" + pr.channels.join(",")
                    });
            }
        }
        for (const n of ins) {
            out.push({
                "label": "🎤 " + n.description + I18n.t(" (вход)", " (input)"),
                "value": "input:" + n.name
            });
            for (const pr of n.pairs)
                out.push({
                    "label": "   ↳ 🎤 " + (pr.label ? pr.label + " · " : "") + pr.channels.join("/"),
                    "value": "pair:" + n.name + ":" + pr.channels.join(",")
                });
        }
        return out;
    }
    function tapValue(v) {
        // older settings stored a bare sink name
        return v && !/^(monitor|all|pair|input):/.test(v) ? "monitor:" + v : (v || "");
    }
    function tapIsInput(v) {
        v = tapValue(v);
        if (v.startsWith("input:"))
            return true;
        if (!v.startsWith("pair:"))
            return false;
        const name = v.slice(5, v.lastIndexOf(":"));
        return tap.nodes.some(n => n.name === name && n.kind === "input");
    }
    Process {
        id: tapList
        running: DesktopWidgets.widgets.some(w => w.type === "cava")
        command: ["python3", Quickshell.shellDir + "/scripts/audio-tap.py", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.tap = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    PxGroup {
        name: "add"
        title: I18n.t("Добавить", "Add")
        icon: "plus"
        width: parent.width
        Row {
            spacing: Theme.u * 3
            PxCombo {
                width: Theme.u * 100
                model: DesktopWidgets.types.map(t => ({
                            "label": t.label,
                            "value": t.type,
                            "icon": t.icon
                        }))
                currentValue: page.newType
                onActivated: v => page.newType = v
            }
            PxCombo {
                width: Theme.u * 60
                model: page.screenModel
                currentValue: page.newScreen
                onActivated: v => page.newScreen = v
            }
            PxButton {
                text: I18n.t("Добавить", "Add")
                icon: "plus"
                accent: true
                enabled: page.newType !== "" && page.newScreen !== ""
                onClicked: DesktopWidgets.add(page.newType, page.newScreen)
            }
        }
    }

    PxGroup {
        name: "on-desktop"
        title: I18n.t("На рабочем столе", "On the desktop") + " (" + DesktopWidgets.widgets.length + ")"
        icon: "layers"
        width: parent.width

        PxText {
            visible: DesktopWidgets.widgets.length === 0
            text: I18n.t("пока пусто ♡", "nothing yet ♡")
            dim: true
        }

        Repeater {
            model: DesktopWidgets.widgets.map(w => w.uid)
            PxBox {
                id: card
                required property string modelData
                readonly property var w: DesktopWidgets.byUid(modelData)
                readonly property var info: w ? DesktopWidgets.typeInfo(w.type) : null
                readonly property var st: w && w.settings ? w.settings : ({})
                width: parent.width
                height: cardCol.implicitHeight + Theme.u * 8
                color: Theme.faceAlt

                Column {
                    id: cardCol
                    x: Theme.u * 4
                    y: Theme.u * 4
                    width: parent.width - Theme.u * 8
                    spacing: Theme.u * 3

                    Row {
                        width: parent.width
                        spacing: Theme.u * 4
                        PxIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: card.info ? card.info.icon : "heart"
                        }
                        PxText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.u * 170
                            text: (card.info ? DesktopWidgets.titleOf(card.info) : "?") + "  ·  " + (card.info ? card.info.label : "")
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        PxCombo {
                            width: Theme.u * 60
                            model: page.screenModel
                            currentValue: card.w ? card.w.screen : ""
                            onActivated: v => DesktopWidgets.setScreen(card.modelData, v)
                        }
                        PxButton {
                            compact: true
                            icon: "refresh"
                            onClicked: DesktopWidgets.resetPosition(card.modelData)
                        }
                        PxButton {
                            compact: true
                            icon: "trash"
                            danger: true
                            onClicked: DesktopWidgets.remove(card.modelData)
                        }
                    }

                    SettingRow {
                        label: I18n.t("Размер", "Size")
                        hint: I18n.t("70–130 %; ещё — колёсико над виджетом в режиме правки или с Ctrl", "70–130 %; also the wheel over the widget in edit mode or with Ctrl")
                        PxSlider {
                            width: parent.width
                            from: 70
                            to: 130
                            stepSize: 5
                            suffix: " %"
                            value: Math.round(DesktopWidgets.scaleOf(card.w) * 100)
                            live: false
                            onReleased: v => DesktopWidgets.setScale(card.modelData, v / 100)
                        }
                    }
                    // per-type options
                    SettingRow {
                        visible: !!card.w && card.w.type === "clock"
                        label: I18n.t("Секунды", "Seconds")
                        PxToggle {
                            checked: !!card.st.seconds
                            onToggled: c => DesktopWidgets.setSetting(card.modelData, "seconds", c)
                        }
                    }
                    SettingRow {
                        visible: !!card.w && card.w.type === "cava"
                        label: I18n.t("Столбиков", "Bars")
                        PxSpin {
                            from: 8
                            to: 64
                            stepSize: 4
                            value: card.st.bars || 32
                            onMoved: v => DesktopWidgets.setSetting(card.modelData, "bars", v)
                        }
                    }
                    SettingRow {
                        visible: !!card.w && card.w.type === "cava"
                        label: I18n.t("Что слушать", "Listen to")
                        hint: page.tapIsInput(card.st.source) ? I18n.t("⚠ это вход: визуализатор будет рисовать микрофон", "⚠ this is an input: the visualizer will draw your microphone") : I18n.t("выход, всё устройство или пара каналов (только чтение, маршрутизация не меняется)", "an output, a whole interface or one channel pair (read-only, routing is untouched)")
                        Row {
                            width: parent.width
                            spacing: Theme.u * 2
                            PxCombo {
                                width: parent.width - refreshTap.width - Theme.u * 2
                                model: page.tapModel
                                currentValue: page.tapValue(card.st.source)
                                onActivated: v => DesktopWidgets.setSetting(card.modelData, "source", v)
                            }
                            PxButton {
                                id: refreshTap
                                compact: true
                                icon: "refresh"
                                onClicked: tapList.running = true
                            }
                        }
                    }
                    PxButton {
                        visible: !!card.info && !!card.info.plugin && !!card.info.plugin.settings
                        compact: true
                        text: I18n.t("Настройки плагина", "Plugin settings")
                        icon: "gear"
                        onClicked: page.nav.settingsPage = "plugin:" + card.info.plugin.id
                    }
                }
            }
        }
    }

    PxGroup {
        name: "behavior"
        title: I18n.t("Поведение", "Behavior")
        icon: "gear"
        width: parent.width
        SettingRow {
            label: I18n.t("Стиль виджетов", "Widget style")
            hint: I18n.t("«Авто»: карточки macOS со скином Golden Gate, пиксельные окна с остальными. В аду — всегда адские", "Auto: macOS cards with the Golden Gate skin, pixel windows with the others. In hell always hell's own")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Авто", "Auto"),
                        "value": "auto"
                    },
                    {
                        "label": I18n.t("Пиксельный", "Pixel"),
                        "value": "pixel"
                    },
                    {
                        "label": "macOS",
                        "value": "mac"
                    }
                ]
                currentValue: DesktopWidgets.style
                onActivated: v => Config.desktop.widgetStyle = v
            }
        }
        SettingRow {
            label: I18n.t("Режим правки", "Edit mode")
            hint: DesktopWidgets.macLook ? I18n.t("«−» на карточках, их можно таскать за любое место, видны скрытые", "“−” on the cards, drag them anywhere, hidden ones shown") : I18n.t("крестики на виджетах и видны скрытые", "close buttons on widgets, hidden ones shown")
            PxToggle {
                checked: DesktopWidgets.editMode
                onToggled: c => DesktopWidgets.editMode = c
            }
        }
        SettingRow {
            label: I18n.t("Прилипать к сетке", "Snap to grid")
            PxToggle {
                checked: Config.desktop.snap
                onToggled: c => Config.desktop.snap = c
            }
        }
        Row {
            spacing: Theme.u * 3
            Repeater {
                model: Quickshell.screens
                PxButton {
                    required property var modelData
                    compact: true
                    icon: "trash"
                    text: I18n.t("Убрать все с ", "Clear ") + modelData.name
                    onClicked: DesktopWidgets.removeAll(modelData.name)
                }
            }
        }
    }
}
