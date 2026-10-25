// The settings once in DeskmenuPage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings
import qs.modules.settings.kit

// Settings → Personalization → Right-click menu (services/DeskMenu): what each target's menu
// holds — the desktop, the bar, a window's button, a widget — its row of icons and its short
// list, with a picture of it; the middle button's ring; the plugins' entries; the desktop
// menu's look and the user's own entries. (Start's buttons are a group here, shown on Start.)
CatPage {
    id: page
    heading: I18n.t("Меню ПКМ", "Right-click menu")
    subtitle: I18n.t("Что в меню по правой кнопке. Средняя кнопка на столе — кольцо из восьми действий.", "What the right-click menus hold. The middle button on the desktop opens a ring of eight.")
    readonly property string target: DeskMenu.targets.includes(DeskMenu.editTarget) ? DeskMenu.editTarget : "desktop"
    readonly property var layout: DeskMenu.layout(target)
    function label(id) {
        const e = DeskMenu.entry(id);
        return e ? e.label : id;
    }
    // what may be added: the target's entries not there yet (a line as often as wanted)
    function options(target, exclude, allowSep) {
        return DeskMenu.catalog(target).filter(id => id === "sep" ? allowSep : !exclude.includes(id)).map(id => ({
                    "label": page.label(id),
                    "value": id,
                    "icon": (DeskMenu.entry(id) || {}).icon
                }));
    }
    // the picture: the menu's own rows, nothing runs
    function shown(id) {
        if (id === "sep")
            return {
                "separator": true
            };
        const e = DeskMenu.entry(id) || {};
        return {
            "label": e.label || id,
            "short": e.short || e.label || id,
            "icon": e.icon || "heart"
        };
    }
    function openMenu() {
        const s = Shell.focusedScreen;
        const m = s ? Shell.desktopMenus[s.name] : null;
        if (m)
            Qt.callLater(() => m.openAt(Math.round(s.width / 2), Math.round(s.height / 2)));
    }
    CatGroup {
        name: "targets"
        title: I18n.t("Что в меню", "What the menu holds")
        icon: "grid"
        CatChoice {
            label: I18n.t("Меню", "Menu")
            hint: I18n.t("Какое меню правишь: по столу, по файлу, по окну…", "Which menu you are editing: the desk's, a file's, a window's…")
            model: DeskMenu.targets.map(t => ({
                        "label": DeskMenu.targetLabel(t),
                        "value": t
                    }))
            currentValue: page.target
            onActivated: v => DeskMenu.editTarget = v
        }
        // how it looks now
        CatCustom {
            wide: true
            CatBox {
                // how it looks now
                PxMenuList {
                    focus: false
                    anchors.horizontalCenter: parent.horizontalCenter
                    quick: page.layout.quick.map(page.shown)
                    items: page.layout.items.map(page.shown).concat([
                        {
                            "separator": true
                        },
                        {
                            "label": I18n.t("Настроить меню…", "Customize the menu…"),
                            "icon": "gear"
                        }
                    ])
                    minWidth: MenuLook.minWidth
                    // a picture: its rows don't take the click or the hover
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
        }
        CatNote {
            dim: true
            text: I18n.t("Значки сверху — до %1, список — до %2 пунктов. Пункт, которому нечего делать (один монитор, окно без процесса), в меню не показывается.", "Icons on top: up to %1; the list: up to %2 entries. An entry with nothing to do there (one monitor, a window without a process) is left out.").arg(DeskMenu.quickMax).arg(DeskMenu.itemsMax)
        }
        // the row of icons
        CatNote {
            text: I18n.t("Значки сверху", "Icons on top")
        }
        CatCustom {
            wide: true
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 3
                    Repeater {
                        model: page.layout.quick
                        PxBox {
                            id: chip
                            required property string modelData
                            required property int index
                            width: chipRow.implicitWidth + Theme.u * 6
                            height: chipRow.implicitHeight + Theme.u * 4
                            color: Theme.mix(Theme.tone("face", Theme.p5For(parent)), Theme.accent, 0.12)
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
                                    onClicked: DeskMenu.setLayout(page.target, "quick", DeskMenu.moved(page.layout.quick, chip.modelData, -1))
                                }
                                PxButton {
                                    compact: true
                                    icon: "arrowRight"
                                    enabled: chip.index < page.layout.quick.length - 1
                                    onClicked: DeskMenu.setLayout(page.target, "quick", DeskMenu.moved(page.layout.quick, chip.modelData, 1))
                                }
                                PxButton {
                                    compact: true
                                    icon: "close"
                                    onClicked: DeskMenu.setLayout(page.target, "quick", page.layout.quick.filter(x => x !== chip.modelData))
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
                PxCombo {
                    visible: page.layout.quick.length < DeskMenu.quickMax
                    width: Math.min(parent.width, Theme.u * 140)
                    placeholder: I18n.t("+ добавить значок…", "+ add an icon…")
                    model: page.options(page.target, page.layout.quick, false)
                    currentValue: ""
                    onActivated: v => DeskMenu.setLayout(page.target, "quick", page.layout.quick.concat([v]))
                }
            }
        }
        // the list
        CatNote {
            text: I18n.t("Список", "The list")
        }
        CatCustom {
            wide: true
            CatBox {
                Column {
                    width: parent.width
                    spacing: Theme.u * 2
                    Repeater {
                        model: page.layout.items
                        PxBox {
                            id: row
                            required property string modelData
                            required property int index
                            width: parent.width
                            height: Theme.u * 16
                            sunken: true
                            color: Qt.alpha(Theme.tone("sunken", Theme.p5For(parent)), 0.5)
                            function moveTo(j) {
                                const l = page.layout.items.slice();
                                l.splice(row.index, 1);
                                if (j >= 0)
                                    l.splice(j, 0, row.modelData);
                                DeskMenu.setLayout(page.target, "items", l);
                            }
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
                                text: page.label(row.modelData)
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
                                    onClicked: row.moveTo(row.index - 1)
                                }
                                PxButton {
                                    compact: true
                                    icon: "arrowDown"
                                    enabled: row.index < page.layout.items.length - 1
                                    onClicked: row.moveTo(row.index + 1)
                                }
                                PxButton {
                                    compact: true
                                    icon: "close"
                                    onClicked: row.moveTo(-1)
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
                PxCombo {
                    visible: page.layout.items.length < DeskMenu.itemsMax
                    width: Math.min(parent.width, Theme.u * 140)
                    placeholder: I18n.t("+ добавить пункт…", "+ add an entry…")
                    model: page.options(page.target, page.layout.items, true)
                    currentValue: ""
                    onActivated: v => DeskMenu.setLayout(page.target, "items", page.layout.items.concat([v]))
                }
            }
        }
        CatCustom {
            wide: true
            CatBox {
                Row {
                    spacing: Theme.u * 4
                    PxButton {
                        compact: true
                        icon: "refresh"
                        text: I18n.t("Как было", "Reset")
                        onClicked: DeskMenu.resetLayout(page.target)
                    }
                    PxButton {
                        visible: page.target === "desktop"
                        compact: true
                        icon: "sparkle"
                        text: I18n.t("Открыть меню", "Open the menu")
                        onClicked: page.openMenu()
                    }
                }
            }
        }
    }
    CatGroup {
        name: "ring"
        title: I18n.t("Кольцо на средней кнопке", "The ring on the middle button")
        icon: "sparkle"
        CatNote {
            dim: true
            text: I18n.t("Зажми среднюю кнопку, махни в сторону и отпусти. Отпустишь на месте — кольцо останется.", "Hold the middle button, flick and let go. Let go in place and the ring stays.")
        }
        CatRepeat {
            model: 8
            delegate: Component {
                CatCustom {
                    id: dir
                    required property int index
                    label: ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"][index] + "  " + [I18n.t("вверх", "up"), I18n.t("вверх-вправо", "up-right"), I18n.t("вправо", "right"), I18n.t("вниз-вправо", "down-right"), I18n.t("вниз", "down"), I18n.t("вниз-влево", "down-left"), I18n.t("влево", "left"), I18n.t("вверх-влево", "up-left")][index]
                    CatBox {
                        PxCombo {
                            width: Math.min(parent.width, Theme.u * 120)
                            model: page.options("ring", [], false)
                            currentValue: DeskMenu.ring[dir.index]
                            onActivated: v => DeskMenu.setRing(dir.index, v)
                        }
                    }
                }
            }
        }
        CatButton {
            compact: true
            icon: "refresh"
            text: I18n.t("Как было", "Reset")
            onClicked: Config.menus.ring = []
        }
    }
    CatGroup {
        id: pluginGroup
        name: "plugins"
        title: I18n.t("Пункты плагинов", "Plugins' entries")
        icon: "plug"
        readonly property var comps: Plugins.menuComponents.map(p => ({
                    "key": p.id + ":menu",
                    "label": p.name || p.id,
                    "hint": p.id
                }))
        readonly property var rows: DeskMenu.pluginEntries.map(e => ({
                    "key": e.key,
                    "label": I18n.label(e.label || "?"),
                    "hint": e.plugin
                })).concat(comps)
        CatNote {
            dim: true
            text: pluginGroup.rows.length ? I18n.t("Плагины могут добавить пункты в меню стола. Сами они не появляются — включи нужные.", "Plugins can add entries to the desktop menu. They don't show up by themselves: switch on the ones you want.") : I18n.t("Включённые плагины ничего в меню не добавляют.", "No enabled plugin adds anything to the menu.")
        }
        CatRepeat {
            model: pluginGroup.rows
            delegate: Component {
                CatCustom {
                    id: pr
                    required property var modelData
                    label: modelData.label
                    hint: modelData.hint
                    CatBox {
                        PxToggle {
                            checked: DeskMenu.pluginOn(pr.modelData.key)
                            onToggled: c => DeskMenu.setPluginOn(pr.modelData.key, c)
                        }
                    }
                }
            }
        }
    }
    CatGroup {
        name: "look"
        title: I18n.t("Облик меню стола", "The desktop menu's look")
        icon: "palette"
        CatCustom {
            label: I18n.t("Стиль", "Style")
            hint: !Heaven.menuOk(Config.desktop.menuStyle) ? DeskMenu.styleLabel(Config.desktop.menuStyle) + I18n.t(" выбрано, но ещё закрыто: ", " is picked but still locked: ") + Heaven.lockHint(Heaven.menuItem(Config.desktop.menuStyle)) + I18n.t(". Пока — обычный список", ". The usual list until then") : ["wings", "harp"].some(s => !Heaven.menuOk(s)) && !DeskMenu.hellish ? ["wings", "harp"].filter(s => !Heaven.menuOk(s)).map(s => DeskMenu.styleLabel(s) + " — " + Heaven.lockHint(Heaven.menuItem(s))).join("; ") : DeskMenu.hellish ? I18n.t("сейчас правит демоница — её «", "the demon rules now — her “") + DeskMenu.styleLabel(DeskMenu.style) + I18n.t("» («Ангелочек» → «Игра»)", "” (Angel → The game)") : ({
                    "list": I18n.t("как все меню: ряд значков сверху, короткий список под ним", "like every menu: a row of icons on top, a short list under it"),
                    "wings": I18n.t("райское: под нимбом раскрываются крылья, пункты — перья; ←/→ — на другое крыло, ↑/↓ — вдоль крыла", "heaven's own: wings unfold under a halo, the entries are feathers; ←/→ to the other wing, ↑/↓ along one"),
                    "harp": I18n.t("райское: арфа на облаке, пункты — струны; наведи — струна звенит, проведи поперёк — глиссандо", "heaven's own: a harp on a cloud, the entries are strings; hover plucks one, a sweep across is a glissando"),
                    "pentagram": I18n.t("пентаграмма ада: 5 главных на лучах, остальное — руны", "hell's pentagram: the main five on its points, the rest as runes")
                })[DeskMenu.chosen] || ""
            CatBox {
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
                            // heaven's own are earned (services/Heaven): locked, they can't be picked
                            readonly property bool locked: !Heaven.menuOk(modelData)
                            width: thumb.implicitWidth + Theme.u * 8
                            height: thumb.implicitHeight + styleName.implicitHeight + Theme.u * 10
                            checked: DeskMenu.chosen === modelData
                            enabled: !locked
                            onClicked: Config.desktop.menuStyle = modelData
                            PxIcon {
                                visible: styleCard.locked
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Theme.u * 2
                                name: "lock"
                                pixel: Math.max(1, Theme.u)
                            }
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
        }
        CatChoice {
            label: I18n.t("Размер меню", "Menu size")
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
        CatToggle {
            label: I18n.t("Подписи в кольце", "Names in the ring")
            hint: I18n.t("короткие названия под значками кольца (и у перьев и струн райских меню); полное — над серединой", "short names under the ring's icons (and by heaven's feathers and strings); the full one above the middle")
            checked: Config.desktop.menuLabels !== false
            onToggled: c => Config.desktop.menuLabels = c
        }
        CatToggle {
            label: I18n.t("Значки в списке", "Icons in the list")
            checked: Config.desktop.menuIcons !== false
            onToggled: c => Config.desktop.menuIcons = c
        }
        CatToggle {
            label: I18n.t("Игрушки в меню ада", "Toys in hell's menus")
            hint: I18n.t("С меню ада можно поиграть: крутить колесо, зажигать свечи… Пункты работают как обычно.", "Hell's menus can be played with: spin the wheel, light candles… The entries work as usual.")
            checked: Config.desktop.menuToys !== false
            onToggled: c => Config.desktop.menuToys = c
        }
        CatToggle {
            label: I18n.t("Анимация", "Animation")
            hint: I18n.t("кольцо вылетает из центра, меню чуть «выпрыгивает»", "the ring flies out of the middle, the menu pops")
            checked: Config.desktop.menuAnim !== false
            onToggled: c => Config.desktop.menuAnim = c
        }
        CatButton {
            compact: true
            icon: "sparkle"
            text: I18n.t("Открыть меню", "Open the menu")
            onClicked: page.openMenu()
        }
    }
    CatGroup {
        name: "start-buttons"
        title: I18n.t("Кнопки «Пуска»", "Start buttons")
        icon: "power"
        CatCustom {
            wide: true
            CatBox {
                StartButtonsEditor {
                    width: parent.width
                }
            }
        }
    }
    CatGroup {
        name: "your-own-entries"
        title: I18n.t("Свои пункты", "Your own entries")
        advanced: true
        icon: "plus"
        property string kind: "app"
        id: customGroup
        CatNote {
            dim: true
            text: I18n.t("Программа, команда, папка или ссылка. Встанет в конец списка, потом её можно передвинуть.", "An app, a command, a folder or a link. It goes to the end of the list; move it later.")
        }
        CatCustom {
            wide: true
            CatBox {
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
            }
        }
        CatChoice {
            label: I18n.t("Что делает", "What it does")
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
        CatChoice {
            present: customGroup.kind === "app"
            label: I18n.t("Программа", "App")
            combo: true
            id: appPick
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
        CatField {
            present: customGroup.kind !== "app"
            label: customGroup.kind === "command" ? I18n.t("Команда", "Command") : customGroup.kind === "path" ? I18n.t("Папка", "Folder") : I18n.t("Адрес", "Address")
            id: customTarget
            placeholder: customGroup.kind === "command" ? "kitty -e btop" : customGroup.kind === "path" ? "~/Projects" : "https://…"
        }
        CatField {
            label: I18n.t("Название", "Name")
            id: customName
            placeholder: I18n.t("как назвать пункт", "what to call it")
        }
        CatChoice {
            label: I18n.t("Значок", "Icon")
            combo: true
            id: customIcon
            model: ["heart", "star", "sparkle", "terminal", "folder", "image", "music", "play", "gear", "monitor", "chip", "document", "search", "download", "gamepad", "bot", "ghost", "pill", "cd", "calendar", "lock", "power", "wifi", "bell"].map(n => ({
                        "label": n,
                        "value": n,
                        "icon": n
                    }))
            currentValue: "heart"
            onActivated: v => currentValue = v
        }
        CatCustom {
            wide: true
            CatBox {
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
    }
}
