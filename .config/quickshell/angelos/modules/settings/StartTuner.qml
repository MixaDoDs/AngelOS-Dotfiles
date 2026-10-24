pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar

// Settings → Start → "Avatar and the look's settings". The avatar and the name every Start
// look shows (StartUser; the buttons along the bottom are further down the same page), then the
// deep settings of the look picked above (services/StartPrefs): size and grid,
// sections, look and animation, behaviour. Only what that look uses is offered.
Column {
    id: root

    readonly property string tune: StartPrefs.current
    readonly property var prefs: StartPrefs.of(tune)
    spacing: Theme.u * 4

    readonly property var styleNames: ({
            "classic": I18n.t("Классика", "Classic"),
            "win11": "Windows 11",
            "fullscreen": I18n.t("Как iPhone", "iPhone-like"),
            "xmb": "PSP XMB",
            "spotlight": "Spotlight"
        })
    // names and hints of the keys (StartPrefs.keys)
    readonly property var names: ({
            "width": [I18n.t("Ширина", "Width"), I18n.t("в % от обычной", "% of the usual")],
            "columns": [I18n.t("Колонок", "Columns"), I18n.t("0 — сколько влезет", "0: as many as fit")],
            "rows": [I18n.t("Рядов", "Rows"), I18n.t("0 — сколько влезет", "0: as many as fit")],
            "iconScale": [I18n.t("Значки", "Icons"), I18n.t("размер иконок приложений", "app icon size")],
            "labels": [I18n.t("Подписи", "Labels"), I18n.t("названия под значками", "names under the icons")],
            "scale": [I18n.t("Масштаб всего меню", "Scale of the whole menu"), ""],
            "user": [I18n.t("Аватарка и имя", "Avatar and name"), ""],
            "pinned": [I18n.t("Закреплённые", "Pinned"), I18n.t("средняя кнопка по приложению — закрепить", "middle-click an app to pin it")],
            "recommended": [I18n.t("«Рекомендуем»", "“Recommended”"), ""],
            "power": [I18n.t("Блокировка и питание", "Lock and power"), ""],
            "search": [I18n.t("Поиск", "Search"), ""],
            "clock": [I18n.t("Часы", "Clock"), ""],
            "extras": [I18n.t("Доп. пункты", "Extra entries"), I18n.t("обои, плагины, обновление, тема…", "wallpaper, plugins, update, theme…")],
            "opacity": [I18n.t("Непрозрачность", "Opacity"), I18n.t("0 — как у темы", "0: the theme's")],
            "accent": [I18n.t("Свой цвет", "Own colour"), I18n.t("подсветка и рамки этого стиля", "this look's highlights and frames")],
            "shadow": [I18n.t("Тень", "Shadow"), ""],
            "anim": [I18n.t("Анимация", "Animation"), ""],
            "animSpeed": [I18n.t("Скорость анимации", "Animation speed"), I18n.t("больше — быстрее", "higher is faster")],
            "animKind": [I18n.t("Как появляется", "How it appears"), ""],
            "sound": [I18n.t("Звук при открытии", "Sound on opening"), I18n.t("из «Звуков системы»", "from System sounds")],
            "sort": [I18n.t("Порядок приложений", "App order"), ""],
            "openOn": [I18n.t("Где открывать", "Open on"), I18n.t("по Meta и из `angelos`; кнопка «Пуск» — всегда на своём экране", "for a Meta tap and `angelos`; the Start button always opens on its screen")],
            "withBar": [I18n.t("Только где есть панель", "Only where the bar is"), I18n.t("на экране без панели «Пуск» откроется на главном экране с панелью", "on a screen without a bar Start opens on the main screen's bar")],
            "clickOutside": [I18n.t("Закрывать кликом мимо", "Close on a click outside"), I18n.t("выключено — экран под меню работает, закрывает Esc или «Пуск»", "off: the screen under it keeps working, Esc or Start close it")],
            "typeSearch": [I18n.t("Печать — сразу поиск", "Typing searches at once"), ""]
        })
    readonly property var choiceNames: ({
            "auto": I18n.t("Как задумано", "As designed"),
            "fade": I18n.t("Проявление", "Fade"),
            "slide": I18n.t("Выезд", "Slide"),
            "zoom": I18n.t("Зум", "Zoom"),
            "az": I18n.t("А–Я", "A–Z"),
            "frequent": I18n.t("Частые первыми", "Most used first"),
            "focused": I18n.t("Где фокус", "Where the focus is"),
            "pointer": I18n.t("Под курсором", "Under the pointer"),
            "primary": I18n.t("Главный экран", "Main screen")
        })
    readonly property var groups: [
        {
            "id": "size",
            "title": I18n.t("Размер и сетка", "Size and grid"),
            "icon": "grid"
        },
        {
            "id": "sections",
            "title": I18n.t("Разделы и блоки", "Sections and blocks"),
            "icon": "layers"
        },
        {
            "id": "look",
            "title": I18n.t("Вид и анимация", "Look and animation"),
            "icon": "palette"
        },
        {
            "id": "behavior",
            "title": I18n.t("Поведение", "Behaviour"),
            "icon": "gear"
        }
    ]
    readonly property var swatches: ["", "#ff5cad", "#e8307f", "#b36bff", "#57d5ff", "#2fbf7f", "#ffc93c", "#ff6a1a", "#ff4f6d", "#7b8cff"]

    // ---- the avatar ----
    Row {
        width: parent.width
        spacing: Theme.u * 6
        StartUser {
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.u * 30
            kind: "title"
            clickable: false
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.u * 110
            spacing: Theme.u * 3
            Flow {
                width: parent.width
                spacing: Theme.u * 2
                PxButton {
                    compact: true
                    accent: true
                    icon: "image"
                    enabled: !StartPrefs.picking
                    text: StartPrefs.picking ? I18n.t("выбираю…", "picking…") : I18n.t("Выбрать аватарку…", "Choose an avatar…")
                    onClicked: StartPrefs.pickAvatar()
                }
                PxButton {
                    compact: true
                    flat: true
                    icon: "trash"
                    visible: !!Config.bar.avatar
                    text: I18n.t("Убрать", "Remove")
                    onClicked: StartPrefs.clearAvatar()
                }
            }
            PxText {
                width: parent.width
                visible: text !== ""
                wrapMode: Text.Wrap
                kind: "tiny"
                color: Theme.danger
                text: StartPrefs.pickError
            }
            PxToggle {
                text: I18n.t("Пиксельная — крупными пикселями, как всё в angelOS", "Pixelated, in big pixels like the rest of angelOS")
                checked: Config.bar.avatarPixel
                onToggled: c => Config.bar.avatarPixel = c
            }
            PxField {
                width: Math.min(parent.width, Theme.u * 120)
                icon: "heart"
                placeholder: I18n.t("Имя (сейчас ", "Name (now ") + (Quickshell.env("USER") || "angel") + ")"
                text: Config.bar.userName
                onEdited: Config.bar.userName = text
            }
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                kind: "tiny"
                dim: true
                text: Config.bar.avatar ? I18n.t("копия лежит в ~/.local/share/angelos", "a copy is kept in ~/.local/share/angelos") : StartPrefs.systemAvatar ? I18n.t("сейчас — картинка системы: ", "now the system's picture: ") + StartPrefs.systemAvatar : I18n.t("пока сердечко; видна во всех стилях «Пуска»", "a heart for now; shown in every Start look")
            }
        }
    }

    // ---- the look picked above (Settings → Start → Menu look): its own values ----
    PxText {
        width: parent.width
        wrapMode: Text.Wrap
        text: I18n.t("Настройки вида «", "Settings of the “") + root.styleNames[root.tune] + I18n.t("» — у каждого вида свои:", "” look; each look keeps its own:")
        font.bold: true
    }

    // ---- the four groups of the look's keys ----
    Repeater {
        model: root.groups
        Column {
            id: grp
            required property var modelData
            readonly property var keys: Object.keys(StartPrefs.keys).filter(k => StartPrefs.keys[k].group === grp.modelData.id && StartPrefs.applies(root.tune, k))
            visible: keys.length > 0
            width: root.width
            spacing: Theme.u * 2
            Row {
                spacing: Theme.u * 3
                topPadding: Theme.u * 2
                PxIcon {
                    name: grp.modelData.icon
                    anchors.verticalCenter: parent.verticalCenter
                }
                PxText {
                    text: grp.modelData.title
                    kind: "title"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Repeater {
                model: grp.keys
                SettingRow {
                    id: row
                    required property string modelData
                    readonly property var spec: StartPrefs.keys[modelData]
                    readonly property var value: root.prefs[modelData]
                    width: grp.width
                    label: (root.names[modelData] || [modelData])[0]
                    hint: (root.names[modelData] || ["", ""])[1] || ""
                    // a number: a slider (percent) or a spin box (counts, 0 = auto)
                    PxSlider {
                        visible: typeof row.spec.def === "number" && row.spec.suffix === "%"
                        height: visible ? implicitHeight : 0
                        width: Math.min(parent.width, Theme.u * 130)
                        from: row.spec.min || 0
                        to: row.spec.max || 100
                        stepSize: row.spec.step || 1
                        value: typeof row.value === "number" ? row.value : 0
                        suffix: row.spec.suffix || ""
                        onReleased: v => StartPrefs.set(root.tune, row.modelData, Math.round(v))
                    }
                    PxSpin {
                        visible: typeof row.spec.def === "number" && row.spec.suffix !== "%"
                        height: visible ? implicitHeight : 0
                        from: row.spec.min || 0
                        to: row.spec.max || 10
                        stepSize: row.spec.step || 1
                        value: typeof row.value === "number" ? row.value : 0
                        onMoved: v => StartPrefs.set(root.tune, row.modelData, Math.round(v))
                    }
                    PxToggle {
                        visible: typeof row.spec.def === "boolean"
                        height: visible ? implicitHeight : 0
                        checked: row.value === true
                        onToggled: c => StartPrefs.set(root.tune, row.modelData, c)
                    }
                    PxSegmented {
                        visible: !!row.spec.choices
                        height: visible ? implicitHeight : 0
                        model: (row.spec.choices || []).map(c => ({
                                    "label": root.choiceNames[c] || c,
                                    "value": c
                                }))
                        currentValue: row.value
                        onActivated: v => StartPrefs.set(root.tune, row.modelData, v)
                    }
                    // the colour: the theme's, or one of a few
                    Flow {
                        visible: row.modelData === "accent"
                        width: parent.width
                        spacing: Theme.u * 2
                        Repeater {
                            model: row.modelData === "accent" ? root.swatches : []
                            Rectangle {
                                id: sw
                                required property string modelData
                                readonly property bool on: (row.value || "") === modelData
                                width: Theme.u * 12
                                height: width
                                color: modelData || Theme.accent
                                border.width: on ? Theme.u : Math.max(1, Theme.u / 2)
                                border.color: on ? Theme.text : Theme.edge
                                PxText {
                                    visible: sw.modelData === ""
                                    anchors.centerIn: parent
                                    kind: "tiny"
                                    color: Theme.selectText
                                    text: "T"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: StartPrefs.set(root.tune, "accent", sw.modelData || null)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Flow {
        width: parent.width
        spacing: Theme.u * 3
        PxButton {
            compact: true
            icon: "pill"
            text: I18n.t("Открыть «Пуск»", "Open Start")
            onClicked: Shell.openStart(Shell.focusedScreen ? Shell.focusedScreen.name : "")
        }
        PxButton {
            compact: true
            flat: true
            icon: "refresh"
            enabled: StartPrefs.changed(root.tune) > 0
            text: I18n.t("Сбросить этот стиль", "Reset this look")
            onClicked: StartPrefs.reset(root.tune)
        }
    }
}
