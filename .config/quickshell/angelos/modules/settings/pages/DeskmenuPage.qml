pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// The right-click menu on the wallpaper (services/DeskMenu): the ring or the list,
// what it holds, in which order, and the user's own entries.
PxPage {
    id: page

    heading: I18n.t("ПКМ-меню", "Right-click menu")
    subtitle: I18n.t("Меню по правой кнопке на пустых обоях: кольцо вокруг курсора или список как в Windows 11. Здесь — что в нём, в каком порядке и как оно выглядит.", "The menu a right click on the bare wallpaper opens: a ring around the pointer or a Windows 11-like list. What it holds, in which order and how it looks.")

    readonly property var quick: Config.desktop.menuQuick || []
    readonly property var entryIds: Config.desktop.menuItems || []
    function label(id) {
        const e = DeskMenu.entry(id);
        return e ? e.label : id;
    }
    function options(exclude, allowSep) {
        return DeskMenu.catalog.concat(DeskMenu.custom.map(c => c.id)).filter(id => (allowSep && id === "sep") || !exclude.includes(id)).filter(id => allowSep || id !== "sep").map(id => ({
                    "label": page.label(id),
                    "value": id,
                    "icon": (DeskMenu.entry(id) || {}).icon
                }));
    }
    function openMenu() {
        const s = Shell.focusedScreen;
        const m = s ? Shell.desktopMenus[s.name] : null;
        if (m)
            Qt.callLater(() => m.openAt(Math.round(s.width / 2), Math.round(s.height / 2)));
    }

    PxGroup {
        name: "look"
        title: I18n.t("Вид", "Look")
        icon: "palette"
        width: parent.width
        SettingRow {
            label: I18n.t("Стиль", "Style")
            hint: DeskMenu.hellish ? I18n.t("сейчас правит демоница — её «", "the demon rules now — her “") + DeskMenu.styleLabel(DeskMenu.style) + I18n.t("» («Помощница» → «Ангел или демон»)", "” (Helper → Angel or demon)") : ({
                    "list": I18n.t("список как в Windows 11: быстрые кнопки сверху, подменю сбоку", "a Windows 11-like list: quick buttons on top, flyouts at the side"),
                    "radial": I18n.t("кольцо вокруг курсора, подменю веером снаружи; 1–9 и стрелки", "a ring around the pointer, flyouts fan out outside; 1–9 and the arrows"),
                    "y2k": I18n.t("глянцевый хромовый пузырь с радугой и блёстками", "a glossy chrome bubble with a rainbow and sparkles"),
                    "tiles": I18n.t("матовая панель с плитками, как центр управления; переключатели светятся", "a frosted panel of tiles like a Control Center; toggles light up"),
                    "wings": I18n.t("райское: под нимбом раскрываются крылья, пункты — перья; ←/→ — на другое крыло, ↑/↓ — вдоль крыла", "heaven's own: wings unfold under a halo, the entries are feathers; ←/→ to the other wing, ↑/↓ along one"),
                    "harp": I18n.t("райское: арфа на облаке, пункты — струны; наведи — струна звенит, проведи поперёк — глиссандо", "heaven's own: a harp on a cloud, the entries are strings; hover plucks one, a sweep across is a glissando"),
                    "pentagram": I18n.t("пентаграмма ада: 5 главных на лучах, остальное — руны", "hell's pentagram: the main five on its points, the rest as runes")
                })[DeskMenu.chosen] || ""
            Flow {
                width: parent.width
                spacing: Theme.u * 4
                Repeater {
                    // the pentagram is hell's own: offered only while the demon rules
                    // (or while it is the one in use — the portal lets it stay in heaven)
                    model: DeskMenu.styles.filter(s => s !== "pentagram" || Angel.hellShown || DeskMenu.chosen === s)
                    PxButton {
                        id: styleCard
                        required property string modelData
                        width: thumb.implicitWidth + Theme.u * 8
                        height: thumb.implicitHeight + styleName.implicitHeight + Theme.u * 10
                        checked: DeskMenu.chosen === modelData
                        onClicked: Config.desktop.menuStyle = modelData
                        MenuStyleThumb {
                            id: thumb
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Theme.u * 4
                            style: styleCard.modelData
                        }
                        PxText {
                            id: styleName
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Theme.u * 3
                            kind: "tiny"
                            font.bold: styleCard.checked
                            text: (styleCard.checked ? "♡ " : "") + DeskMenu.styleLabel(styleCard.modelData)
                        }
                    }
                }
            }
        }
        SettingRow {
            label: I18n.t("Размер", "Size")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Компактно", "Compact"),
                        "value": "compact"
                    },
                    {
                        "label": I18n.t("Обычно", "Normal"),
                        "value": "normal"
                    },
                    {
                        "label": I18n.t("Крупно", "Large"),
                        "value": "large"
                    }
                ]
                currentValue: Config.desktop.menuSize || "normal"
                onActivated: v => Config.desktop.menuSize = v
            }
        }
        SettingRow {
            visible: ["radial", "wings", "harp", "pentagram"].includes(DeskMenu.chosen)
            label: DeskMenu.heavenly.includes(DeskMenu.chosen) ? I18n.t("Подписи у значков", "Names by the icons") : I18n.t("Подписи в кольце", "Names in the ring")
            hint: DeskMenu.heavenly.includes(DeskMenu.chosen) ? I18n.t("короткие названия у перьев и струн; полное — у середины", "short names by the feathers and strings; the full one by the middle") : I18n.t("короткие названия под значками; полное — над серединой", "short names under the icons; the full one above the middle")
            PxToggle {
                checked: Config.desktop.menuLabels !== false
                onToggled: c => Config.desktop.menuLabels = c
            }
        }
        SettingRow {
            visible: DeskMenu.chosen === "list" || DeskMenu.chosen === "y2k"
            label: I18n.t("Значки в списке", "Icons in the list")
            PxToggle {
                checked: Config.desktop.menuIcons !== false
                onToggled: c => Config.desktop.menuIcons = c
            }
        }
        SettingRow {
            label: I18n.t("Анимация", "Animation")
            hint: I18n.t("кольцо вылетает из центра, список чуть «выпрыгивает»", "the ring flies out of the middle, the list pops")
            PxToggle {
                checked: Config.desktop.menuAnim !== false
                onToggled: c => Config.desktop.menuAnim = c
            }
        }
        PxButton {
            compact: true
            icon: "sparkle"
            text: I18n.t("Открыть меню", "Open the menu")
            onClicked: page.openMenu()
        }
    }

    PxGroup {
        name: "quick-buttons"
        title: I18n.t("Быстрые кнопки", "Quick buttons")
        icon: "star"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Верхний ряд списка и первые места в кольце — до 6.", "The list's top row and the ring's first places — up to 6.")
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            Repeater {
                model: page.quick
                PxBox {
                    id: chip
                    required property string modelData
                    required property int index
                    width: chipRow.implicitWidth + Theme.u * 6
                    height: chipRow.implicitHeight + Theme.u * 4
                    color: Theme.mix(Theme.face, Theme.accent, 0.12)
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: Theme.u * 2
                        PxIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: (DeskMenu.entry(chip.modelData) || {}).icon || "heart"
                        }
                        PxText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.label(chip.modelData)
                        }
                        PxButton {
                            compact: true
                            icon: "arrowLeft"
                            enabled: chip.index > 0
                            onClicked: Config.desktop.menuQuick = DeskMenu.moved(page.quick, chip.modelData, -1)
                        }
                        PxButton {
                            compact: true
                            icon: "arrowRight"
                            enabled: chip.index < page.quick.length - 1
                            onClicked: Config.desktop.menuQuick = DeskMenu.moved(page.quick, chip.modelData, 1)
                        }
                        PxButton {
                            compact: true
                            icon: "close"
                            onClicked: Config.desktop.menuQuick = page.quick.filter(x => x !== chip.modelData)
                        }
                    }
                }
            }
        }
        PxCombo {
            visible: page.quick.length < 6
            width: Math.min(parent.width, Theme.u * 140)
            placeholder: I18n.t("+ добавить кнопку…", "+ add a button…")
            model: page.options(page.quick, false)
            currentValue: ""
            onActivated: v => Config.desktop.menuQuick = page.quick.concat([v]).slice(0, 6)
        }
    }

    PxGroup {
        name: "entries"
        title: I18n.t("Пункты", "Entries")
        icon: "layers"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Остальное меню по порядку. В кольце разделители не видны, а быстрые кнопки не повторяются. «Показать больше» появляется, когда плагины что-то туда добавили.", "The rest of the menu in order. The ring skips separators and does not repeat quick buttons. “Show more options” shows up when plugins add something there.")
        }
        Column {
            width: parent.width
            spacing: Theme.u * 2
            Repeater {
                model: page.entryIds
                PxBox {
                    id: row
                    required property string modelData
                    required property int index
                    width: parent.width
                    height: Theme.u * 16
                    sunken: true
                    color: Qt.alpha(Theme.sunken, 0.5)
                    PxIcon {
                        id: rowIcon
                        x: Theme.u * 4
                        anchors.verticalCenter: parent.verticalCenter
                        name: (DeskMenu.entry(row.modelData) || {}).icon || "heart"
                    }
                    PxText {
                        anchors.left: rowIcon.right
                        anchors.leftMargin: Theme.u * 4
                        anchors.right: rowButtons.left
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: page.label(row.modelData) + ((DeskMenu.entry(row.modelData) || {}).flyout ? "  ▸" : "")
                        dim: row.modelData === "sep"
                    }
                    Row {
                        id: rowButtons
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.u * 2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.u * 2
                        PxButton {
                            compact: true
                            icon: "arrowUp"
                            enabled: row.index > 0
                            onClicked: {
                                const l = page.entryIds.slice();
                                l.splice(row.index, 1);
                                l.splice(row.index - 1, 0, row.modelData);
                                Config.desktop.menuItems = l;
                            }
                        }
                        PxButton {
                            compact: true
                            icon: "arrowDown"
                            enabled: row.index < page.entryIds.length - 1
                            onClicked: {
                                const l = page.entryIds.slice();
                                l.splice(row.index, 1);
                                l.splice(row.index + 1, 0, row.modelData);
                                Config.desktop.menuItems = l;
                            }
                        }
                        PxButton {
                            compact: true
                            icon: "close"
                            onClicked: {
                                const l = page.entryIds.slice();
                                l.splice(row.index, 1);
                                Config.desktop.menuItems = l;
                            }
                        }
                    }
                }
            }
        }
        PxCombo {
            width: Math.min(parent.width, Theme.u * 140)
            placeholder: I18n.t("+ добавить пункт…", "+ add an entry…")
            model: page.options(page.entryIds, true)
            currentValue: ""
            onActivated: v => Config.desktop.menuItems = page.entryIds.concat([v])
        }
    }

    PxGroup {
        name: "your-own-entries"
        title: I18n.t("Свои пункты", "Your own entries")
        advanced: true
        icon: "plus"
        width: parent.width
        property string kind: "app"
        id: customGroup
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Программа, команда, папка или ссылка — появится в конце пунктов, дальше её можно передвинуть или сделать быстрой кнопкой.", "An app, a command, a folder or a link — it lands at the end of the entries; move it or make it a quick button from there.")
        }
        Repeater {
            model: DeskMenu.custom
            Row {
                id: own
                required property var modelData
                spacing: Theme.u * 3
                PxIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: own.modelData.icon || "heart"
                }
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: own.modelData.label + "  ·  " + ({
                            "app": I18n.t("программа", "app"),
                            "command": I18n.t("команда", "command"),
                            "path": I18n.t("папка", "folder"),
                            "url": I18n.t("ссылка", "link")
                        })[own.modelData.kind] + ": " + own.modelData.target
                    dim: true
                }
                PxButton {
                    compact: true
                    icon: "trash"
                    onClicked: DeskMenu.removeCustom(own.modelData.id)
                }
            }
        }
        SettingRow {
            label: I18n.t("Что делает", "What it does")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Программа", "App"),
                        "value": "app"
                    },
                    {
                        "label": I18n.t("Команда", "Command"),
                        "value": "command"
                    },
                    {
                        "label": I18n.t("Папка", "Folder"),
                        "value": "path"
                    },
                    {
                        "label": I18n.t("Ссылка", "Link"),
                        "value": "url"
                    }
                ]
                currentValue: customGroup.kind
                onActivated: v => customGroup.kind = v
            }
        }
        SettingRow {
            visible: customGroup.kind === "app"
            label: I18n.t("Программа", "App")
            PxCombo {
                id: appPick
                width: parent.width
                placeholder: I18n.t("выбери…", "pick one…")
                model: StartApps.apps.map(a => ({
                            "label": a.name,
                            "value": a.id
                        }))
                currentValue: ""
                onActivated: v => {
                    currentValue = v;
                    const a = StartApps.apps.find(x => x.id === v);
                    if (a && !customName.text)
                        customName.text = a.name;
                }
            }
        }
        SettingRow {
            visible: customGroup.kind !== "app"
            label: customGroup.kind === "command" ? I18n.t("Команда", "Command") : customGroup.kind === "path" ? I18n.t("Папка", "Folder") : I18n.t("Адрес", "Address")
            PxField {
                id: customTarget
                width: parent.width
                placeholder: customGroup.kind === "command" ? "kitty -e btop" : customGroup.kind === "path" ? "~/Projects" : "https://…"
            }
        }
        SettingRow {
            label: I18n.t("Название", "Name")
            PxField {
                id: customName
                width: parent.width
                placeholder: I18n.t("как назвать пункт", "what to call it")
            }
        }
        SettingRow {
            label: I18n.t("Значок", "Icon")
            PxCombo {
                id: customIcon
                width: Math.min(parent.width, Theme.u * 100)
                model: ["heart", "star", "sparkle", "terminal", "folder", "image", "music", "play", "gear", "monitor", "chip", "document", "search", "download", "gamepad", "bot", "ghost", "pill", "cd", "calendar", "lock", "power", "wifi", "bell"].map(n => ({
                            "label": n,
                            "value": n,
                            "icon": n
                        }))
                currentValue: "heart"
                onActivated: v => currentValue = v
            }
        }
        PxButton {
            text: I18n.t("Добавить в меню", "Add to the menu")
            icon: "plus"
            accent: true
            readonly property string target: customGroup.kind === "app" ? (appPick.currentValue || "") : customTarget.text.trim()
            enabled: target !== "" && customName.text.trim() !== ""
            onClicked: {
                DeskMenu.addCustom(customName.text.trim(), customIcon.currentValue, customGroup.kind, target);
                customName.text = "";
                customTarget.text = "";
                appPick.currentValue = "";
            }
        }
    }
}
