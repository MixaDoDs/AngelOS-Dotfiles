pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Win98-like Start menu contents: arrow keys move, Enter runs, typing searches.
PxBox {
    id: root

    signal closeRequested
    property int current: -1
    // Settings → Bar → Start → Fine-tune (services/StartPrefs)
    readonly property var prefs: StartPrefs.of("classic")

    readonly property var entries: [
        {
            "text": I18n.t("Программы…", "Applications…"),
            "icon": "search",
            "hint": "Mod+Space",
            "act": () => Shell.launcherOpen = true
        },
        {
            "text": I18n.t("Терминал", "Terminal"),
            "icon": "terminal",
            "act": () => Shell.terminal()
        },
        {
            "text": I18n.t("Файлы", "Files"),
            "icon": "folder",
            "act": () => Shell.exec([Config.system.fileManager || "xdg-open", Config.home])
        },
        {
            "separator": true
        },
        {
            "text": I18n.t("Обои", "Wallpaper"),
            "extra": true,
            "icon": "image",
            "act": () => Shell.openSettings("wallpaper")
        },
        {
            "text": I18n.t("Настройки", "Settings"),
            "icon": "gear",
            "act": () => Shell.openSettings()
        },
        {
            "text": I18n.t("Плагины", "Plugins"),
            "extra": true,
            "icon": "plug",
            "act": () => Shell.openSettings("plugins")
        },
        {
            "text": I18n.t("Мастер плагинов…", "Plugin Studio…"),
            "extra": true,
            "icon": "sparkle",
            "show": Config.developer.enabled,
            "act": () => Shell.openSettings("studio")
        },
        {
            "text": I18n.t("Отладка игры…", "Game debug…"),
            "extra": true,
            "icon": "chip",
            "show": GameDebug.allowed,
            "act": () => GameDebug.open = true
        },
        {
            "text": I18n.t("Сундуки ✦", "Chests ✦") + (Chests.count > 0 ? " · " + Chests.count : ""),
            "extra": true,
            "icon": "sparkleStar",
            "show": Story.enabled && (Chests.freeReady || HeavenStars.stars >= Chests.cost),
            "act": () => Chests.openOne()
        },
        {
            "text": "Dotfiles",
            "extra": true,
            "icon": "package",
            "show": Owner.enabled,
            "act": () => Shell.openSettings("dotfiles")
        },
        // always there: users looked for it before the daily check found anything
        {
            "text": Updates.available ? I18n.t("Обновление готово ♡", "Update available ♡") : I18n.t("Обновление", "Update"),
            "extra": true,
            "icon": "download",
            "act": () => Shell.openSettings("updates")
        },
        {
            "text": I18n.t("Мини-игра osu!", "osu! mini game"),
            "extra": true,
            "icon": "heart",
            "show": Plugins.enabledPlugins.some(p => p.id === "osu-mini"),
            "act": () => Shell.gameOpen = true
        },
        {
            "text": Theme.dark ? I18n.t("Светлая тема", "Light theme") : I18n.t("Тёмная тема", "Dark theme"),
            "extra": true,
            "icon": Theme.dark ? "sun" : "moon",
            "act": () => Config.appearance.mode = Theme.dark ? "light" : "dark"
        },
        {
            "separator": true
        },
        {
            "text": I18n.t("Заблокировать", "Lock"),
            "power": true,
            "icon": "lock",
            "hint": "Mod+Alt+L",
            "act": () => Shell.lock()
        },
        {
            "text": I18n.t("Заставка", "Idle screen"),
            "power": true,
            "icon": "moon",
            "act": () => Idle.start()
        },
        {
            "text": I18n.t("Выключение…", "Power…"),
            "power": true,
            "icon": "power",
            "act": () => Shell.sessionOpen = true
        }
    ].filter(e => (e.show === undefined || e.show) && (prefs.extras || !e.extra) && (prefs.power || !e.power)).filter((e, i, a) => !e.separator || (i > 0 && i < a.length - 1 && !a[i - 1].separator))
    readonly property var actionable: entries.map((e, i) => e.separator ? -1 : i).filter(i => i >= 0)

    function run(index) {
        const e = entries[index];
        if (!e || e.separator)
            return;
        closeRequested();
        // after the overlay released the keyboard, so launcher/dialogs get focus
        Qt.callLater(e.act);
    }
    function move(step) {
        const list = actionable;
        if (!list.length)
            return;
        const at = list.indexOf(current);
        current = at < 0 ? (step > 0 ? list[0] : list[list.length - 1]) : list[(at + step + list.length) % list.length];
    }
    function key(e) {
        if (e.key === Qt.Key_Escape || e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R)
            closeRequested();
        else if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier)))
            move(1);
        else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab)
            move(-1);
        else if (e.key === Qt.Key_Home)
            current = actionable[0];
        else if (e.key === Qt.Key_End)
            current = actionable[actionable.length - 1];
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
            run(current >= 0 ? current : actionable[0]);
        else if (e.text && e.text.trim() !== "" && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            // Windows-style: start typing to search
            Shell.launcherPrefill = e.text;
            closeRequested();
            Qt.callLater(() => Shell.launcherOpen = true);
        } else
            return;
        e.accepted = true;
    }

    property real room: 0                       // StartOverlay: the screen's room for it
    width: Math.round(Theme.u * 160 * prefs.size)
    height: brand.height + userRow.height + Theme.u * 4 + colView.height + footer.height + inset * 2
    // the selected entry stays in view when the list scrolls
    onCurrentChanged: if (current >= 0 && col.children[current]) {
        const it = col.children[current];
        colView.contentY = Math.max(0, Math.min(colView.contentHeight - colView.height, it.y < colView.contentY ? it.y : it.y + it.height > colView.contentY + colView.height ? it.y + it.height - colView.height : colView.contentY));
    }
    color: Qt.alpha(Theme.menuSurface, prefs.alpha)
    edgeColor: Theme.menuBorder
    flat: true
    shadow: Config.appearance.shadows && prefs.shadow

    Rectangle {
        id: brand
        width: parent.width
        height: Theme.fit(27)
        color: root.prefs.accent ? Theme.mix(Theme.menuHeader, root.prefs.accentColor, 0.45) : Theme.menuHeader
        AngelLogo {
            anchors.centerIn: parent
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Theme.u
            color: Theme.menuBorder
        }
    }

    // the user: avatar and name under the logo (Fine-tune → Sections → User)
    Item {
        id: userRow
        y: brand.height
        width: parent.width
        height: root.prefs.user ? user.height + Theme.u * 6 : 0
        visible: root.prefs.user
        StartUser {
            id: user
            x: Theme.u * 6
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.u * 15
            frameColor: root.prefs.accentColor
            onOpened: root.closeRequested()
        }
        Rectangle {
            anchors.bottom: parent.bottom
            x: Theme.u * 4
            width: parent.width - Theme.u * 8
            height: Math.max(1, Theme.u / 2)
            color: Theme.menuBorder
        }
    }

    // the entries; on a screen too short for all of them (big fonts, a big art pixel) they scroll
    Flickable {
        id: colView
        y: brand.height + userRow.height + Theme.u * 2
        width: parent.width
        height: root.room > 0 ? Math.max(Theme.fit(14), Math.min(col.implicitHeight, root.room - brand.height - userRow.height - Theme.u * 4 - footer.height - root.inset * 2)) : col.implicitHeight
        contentHeight: col.implicitHeight
        interactive: contentHeight > height
        clip: interactive
        boundsBehavior: Flickable.StopAtBounds
    Column {
        id: col
        width: parent.width
        Repeater {
            model: root.entries
            PxMenuItem {
                required property var modelData
                required property int index
                separator: !!modelData.separator
                text: modelData.text || ""
                icon: modelData.icon || ""
                hint: modelData.hint || ""
                highlighted: root.current === index
                iconScale: root.prefs.icons
                onHoveredChanged: if (hovered)
                    root.current = index
                onTriggered: root.run(index)
            }
        }
    }
    }

    PxText {
        id: footer
        anchors.bottom: parent.bottom
        width: parent.width
        height: implicitHeight + Theme.u * 4
        horizontalAlignment: Text.AlignHCenter
        kind: "tiny"
        dim: true
        text: I18n.t("печатай — поиск ♡", "type to search ♡")
    }
}
