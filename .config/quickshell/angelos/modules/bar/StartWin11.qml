pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Windows 11-like Start: search on top, pinned apps grid, "All apps" list,
// recommended row, user + power at the bottom. Right-click pins/unpins.
PxBox {
    id: root

    signal closeRequested
    property int current: -1
    property bool showAll: false
    property string query: ""
    // Settings → Bar → Start → Fine-tune (services/StartPrefs): width, the pinned grid,
    // icons, sections, colours, order
    readonly property var prefs: StartPrefs.of("win11")
    readonly property real sizeFactor: prefs.size
    readonly property int columns: prefs.columns > 0 ? Math.max(3, Math.min(10, prefs.columns)) : Math.max(4, Math.min(10, Math.round(6 * sizeFactor)))
    property real room: 0                       // StartOverlay: the screen's room for it
    // the pinned rows that fit in it (big fonts, a big art pixel, a small screen): the menu
    // gives up rows rather than run off the screen
    readonly property int fitRows: room > 0 ? Math.floor((room - footer.height - Theme.u * 10 - (field.visible ? field.height : 0) - head.implicitHeight - (recHead.visible ? recHead.implicitHeight + recFlow.implicitHeight : 0) - col.spacing * 4) / grid.cellHeight) : 6
    readonly property int rows: Math.max(1, Math.min(6, fitRows, prefs.rows > 0 ? prefs.rows : 3))
    readonly property color accentColor: prefs.accentColor
    readonly property var appList: StartPrefs.sorted("win11", StartApps.apps)
    // typing turns the grid into a Windows 11-like list: the calculator, apps and settings by relevance
    readonly property bool searching: query.trim() !== ""
    readonly property var results: searching ? StartApps.searchAll(query, 40) : []
    readonly property var shown: searching ? results : showAll || !prefs.pinned ? appList : StartApps.pinned.slice(0, columns * rows)
    readonly property var recommended: [
        {
            "text": I18n.t("Настройки", "Settings"),
            "hint": I18n.t("тема, обои, панель", "theme, wallpaper, bar"),
            "icon": "gear",
            "act": () => Shell.openSettings()
        },
        {
            "text": I18n.t("Обои", "Wallpaper"),
            "hint": I18n.t("выбрать картинку", "pick a picture"),
            "icon": "image",
            "act": () => Shell.openSettings("wallpaper")
        },
        {
            "text": I18n.t("Файлы", "Files"),
            "hint": I18n.t("домашняя папка", "home folder"),
            "icon": "folder",
            "act": () => Shell.exec([Config.system.fileManager || "xdg-open", Config.home])
        },
        {
            "text": I18n.t("Терминал", "Terminal"),
            "hint": Config.system.terminal || "kitty",
            "icon": "terminal",
            "act": () => Shell.terminal()
        }
    ]

    function setQuery(t) {
        field.text = t;
        query = t;
        current = t ? 0 : -1;
    }
    function reset() {
        current = -1;
        showAll = !prefs.pinned;
        query = "";
        field.text = "";
        if (prefs.typeSearch && prefs.search)
            Qt.callLater(() => field.focusField());
    }
    function run(app) {
        closeRequested();
        Qt.callLater(() => StartApps.launch(app));
    }
    // a search row: launch the app, open the setting, copy the sum
    function activate(row) {
        if (!row)
            return;
        if (!searching)
            run(row);
        else if (row.kind === "app")
            run(row.app);
        else if (row.kind === "setting")
            act(() => StartApps.openSetting(row.doc));
        else if (row.kind === "file")
            act(() => FileSearch.open(row.file));
        else if (row.kind === "calc") {
            Calc.copy(row.calc);
            if (row.calc.copy)
                closeRequested();
        }
    }
    function act(fn) {
        closeRequested();
        Qt.callLater(fn);
    }
    function move(dx, dy) {
        const n = shown.length;
        if (!n)
            return;
        if (current < 0) {
            current = 0;
            return;
        }
        const linear = (showAll && !query) || searching;
        const step = linear ? dy : dy * columns + dx;
        current = Math.max(0, Math.min(n - 1, current + (linear ? dy + dx : step)));
        if (showAll && !query)
            allList.positionViewAtIndex(current, ListView.Contain);
        if (searching)
            resultList.positionViewAtIndex(current, ListView.Contain);
    }
    // the overlay forwards the first key here; the search field takes the rest
    function key(e) {
        if (nav(e))
            return;
        if (e.text && e.text.trim() !== "" && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            field.text += e.text;
            query = field.text;
            field.focusField();
            e.accepted = true;
        }
    }
    function nav(e) {
        if (e.key === Qt.Key_Escape || e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R)
            closeRequested();
        else if (e.key === Qt.Key_Down)
            move(0, 1);
        else if (e.key === Qt.Key_Up)
            move(0, -1);
        else if (e.key === Qt.Key_Right && query === "")
            move(1, 0);
        else if (e.key === Qt.Key_Left && query === "")
            move(-1, 0);
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
            activate(shown[Math.max(0, current)]);
        else
            return false;
        e.accepted = true;
        return true;
    }

    width: Math.round(Theme.u * 250 * sizeFactor)
    height: col.implicitHeight + footer.height + Theme.u * 10
    color: Qt.alpha(Theme.menuSurface, prefs.alpha)
    edgeColor: Theme.menuBorder
    flat: true
    shadow: Config.appearance.shadows && prefs.shadow

    component Tile: Item {
        id: tile
        required property var modelData
        required property int index
        readonly property bool sel: root.current === index
        width: grid.cellWidth
        height: grid.cellHeight
        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.u
            color: tile.sel ? Qt.alpha(root.accentColor, 0.3) : tm.containsMouse ? Qt.alpha(root.accentColor, 0.14) : "transparent"
            border.width: tile.sel ? Math.max(1, Theme.u / 2) : 0
            border.color: root.accentColor
        }
        Column {
            anchors.centerIn: parent
            width: parent.width - Theme.u * 4
            spacing: Theme.u * 2
            AppIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                iconName: tile.modelData.icon || ""
                appId: tile.modelData.id || ""
                size: Math.round(Theme.u * 15 * root.prefs.icons)
                scale: tm.pressed ? 0.88 : 1
                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.ms(90)
                    }
                }
            }
            PxText {
                visible: root.prefs.labels
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: tile.modelData.name
                kind: "tiny"
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
        PxIcon {
            visible: StartApps.isPinned(tile.modelData) && !root.query
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.u * 2
            name: "pin"
            pixel: Math.max(1, Theme.u - 1)
        }
        MouseArea {
            id: tm
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onEntered: root.current = tile.index
            onClicked: m => m.button === Qt.RightButton ? StartApps.togglePin(tile.modelData) : root.run(tile.modelData)
        }
    }

    Column {
        id: col
        x: Theme.u * 6
        y: Theme.u * 6
        width: parent.width - Theme.u * 12
        spacing: Theme.u * 5

        PxField {
            id: field
            visible: root.prefs.search
            keepFocus: true
            width: parent.width
            icon: "search"
            placeholder: Config.launcher.settings !== false ? I18n.t("Приложения, настройки, 2+2…", "Apps, settings, 2+2…") : I18n.t("Поиск приложений…", "Search apps…")
            onEdited: {
                root.query = text;
                root.current = text ? 0 : -1;
            }
            onAccepted: if (root.shown.length)
                root.activate(root.shown[Math.max(0, root.current)])
            onKeyPressed: e => root.nav(e)
        }

        Item {
            width: parent.width
            height: head.implicitHeight
            PxText {
                id: head
                text: root.query ? (root.results.length ? I18n.t("Лучшие совпадения", "Best matches") : I18n.t("Ничего не нашлось", "Nothing found")) : root.showAll ? I18n.t("Все приложения", "All apps") : I18n.t("Закреплённые", "Pinned")
                kind: "title"
                anchors.verticalCenter: parent.verticalCenter
            }
            PxButton {
                visible: !root.query && root.prefs.pinned
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                compact: true
                text: root.showAll ? I18n.t("‹ Назад", "‹ Back") : I18n.t("Все приложения ›", "All apps ›")
                onClicked: {
                    root.showAll = !root.showAll;
                    root.current = -1;
                }
            }
        }

        // search results: one list, best first
        ListView {
            id: resultList
            visible: root.searching
            width: parent.width
            height: grid.cellHeight * root.rows + recHead.implicitHeight + Theme.u * 5
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: visible ? root.results : []
            delegate: Rectangle {
                id: hit
                required property var modelData
                required property int index
                readonly property bool sel: root.current === index
                readonly property bool isCalc: modelData.kind === "calc"
                readonly property bool isFile: modelData.kind === "file"
                width: resultList.width
                height: isCalc ? Theme.fit(22) : Theme.fit(16)
                color: sel ? Qt.alpha(root.accentColor, 0.3) : hm.containsMouse ? Qt.alpha(root.accentColor, 0.14) : "transparent"
                border.width: sel ? Math.max(1, Theme.u / 2) : 0
                border.color: root.accentColor
                Item {
                    id: hitIcon
                    x: Theme.u * 3
                    width: Theme.u * 12
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    AppIcon {
                        visible: hit.modelData.kind === "app"
                        anchors.centerIn: parent
                        iconName: visible ? hit.modelData.app.icon || "" : ""
                        appId: visible ? hit.modelData.app.id || "" : ""
                        size: Theme.u * 12
                    }
                    FileThumb {
                        id: hitThumb
                        visible: ok
                        anchors.fill: parent
                        hit: hit.isFile ? hit.modelData.file : null
                    }
                    PxIcon {
                        visible: hit.modelData.kind !== "app" && !hitThumb.ok
                        anchors.centerIn: parent
                        name: hit.isCalc ? "calc" : hit.modelData.kind === "setting" ? hit.modelData.doc.icon || "gear" : hit.isFile ? FileSearch.pixelIcon(hit.modelData.file) : "sparkle"
                    }
                }
                Column {
                    anchors.left: hitIcon.right
                    anchors.leftMargin: Theme.u * 5
                    anchors.right: hitKind.left
                    anchors.rightMargin: Theme.u * 3
                    anchors.verticalCenter: parent.verticalCenter
                    PxText {
                        width: parent.width
                        elide: Text.ElideRight
                        kind: hit.isCalc ? "title" : "body"
                        font.bold: hit.sel || hit.isCalc
                        text: hit.isCalc ? hit.modelData.calc.title : hit.modelData.kind === "app" ? hit.modelData.app.name : hit.isFile ? hit.modelData.file.name : hit.modelData.doc.title
                    }
                    PxText {
                        width: parent.width
                        visible: text !== ""
                        elide: Text.ElideRight
                        kind: "tiny"
                        dim: true
                        text: hit.isCalc ? hit.modelData.calc.subtitle : hit.modelData.kind === "app" ? (hit.modelData.app.genericName || hit.modelData.app.comment || "") : hit.isFile ? FileSearch.where(hit.modelData.file) : (hit.modelData.doc.crumb || hit.modelData.doc.hint || "")
                    }
                }
                PxText {
                    id: hitKind
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.u * 4
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "tiny"
                    dim: true
                    text: hit.isCalc ? (hit.modelData.calc.copy ? "⧉" : "") : hit.modelData.kind === "app" ? I18n.t("приложение", "app") : hit.isFile ? (hit.modelData.file.isDir ? I18n.t("папка", "folder") : I18n.t("файл", "file")) : I18n.t("настройка", "setting")
                }
                MouseArea {
                    id: hm
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.current = hit.index
                    onClicked: m => {
                        if (m.button === Qt.RightButton && hit.modelData.kind === "app")
                            StartApps.togglePin(hit.modelData.app);
                        else if (m.button === Qt.RightButton && hit.isFile)
                            root.act(() => FileSearch.reveal(hit.modelData.file));
                        else
                            root.activate(hit.modelData);
                    }
                }
            }
        }

        // pinned grid
        GridView {
            id: grid
            visible: !root.showAll && !root.searching
            width: parent.width
            height: cellHeight * Math.max(1, Math.min(root.rows, Math.ceil(count / root.columns)))
            cellWidth: width / root.columns
            cellHeight: Math.round(Theme.u * 22 * Math.max(0.8, root.prefs.icons)) + (root.prefs.labels ? Theme.fit(8) : 0)
            interactive: count > root.columns * root.rows
            clip: true
            model: grid.visible ? root.shown : []
            delegate: Tile {}
        }

        // all apps, alphabetical with letter headers
        ListView {
            id: allList
            visible: root.showAll && root.query === ""
            width: parent.width
            height: grid.cellHeight * root.rows + recHead.implicitHeight + recFlow.implicitHeight + Theme.u * 5
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: allList.visible ? root.shown : []
            delegate: Item {
                id: li
                required property var modelData
                required property int index
                readonly property string letter: String(modelData.name || "?").charAt(0).toUpperCase()
                readonly property bool first: index === 0 || letter !== String(root.shown[index - 1].name || "?").charAt(0).toUpperCase()
                width: allList.width
                height: row.height + (first ? letterText.implicitHeight + Theme.u * 2 : 0)
                PxText {
                    id: letterText
                    visible: li.first
                    text: li.letter
                    kind: "title"
                    color: root.accentColor
                    topPadding: Theme.u * 2
                }
            Rectangle {
                id: row
                y: li.first ? letterText.implicitHeight + Theme.u * 2 : 0
                width: allList.width
                height: Theme.fit(14)
                color: root.current === li.index ? Qt.alpha(root.accentColor, 0.3) : lm.containsMouse ? Qt.alpha(root.accentColor, 0.14) : "transparent"
                Row {
                    x: Theme.u * 3
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.u * 4
                    AppIcon {
                        iconName: li.modelData.icon || ""
                        appId: li.modelData.id || ""
                        size: Math.round(Theme.u * 10 * root.prefs.icons)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    PxText {
                        text: li.modelData.name
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: lm
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.current = li.index
                    onClicked: m => m.button === Qt.RightButton ? StartApps.togglePin(li.modelData) : root.run(li.modelData)
                }
            }
            }
        }

        PxText {
            id: recHead
            visible: !root.showAll && !root.query && root.prefs.recommended
            text: I18n.t("Рекомендуем", "Recommended")
            kind: "title"
        }
        Flow {
            id: recFlow
            visible: !root.showAll && !root.query && root.prefs.recommended
            width: parent.width
            spacing: Theme.u * 2
            Repeater {
                model: root.recommended
                Rectangle {
                    id: rec
                    required property var modelData
                    width: (recFlow.width - recFlow.spacing) / 2
                    height: Theme.fit(17)
                    color: rm.containsMouse ? Qt.alpha(root.accentColor, 0.14) : "transparent"
                    Row {
                        x: Theme.u * 3
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.u * 4
                        PxIcon {
                            name: rec.modelData.icon
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: rec.width - Theme.u * 20
                            PxText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: rec.modelData.text
                            }
                            PxText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: rec.modelData.hint
                                kind: "tiny"
                                dim: true
                            }
                        }
                    }
                    MouseArea {
                        id: rm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.act(rec.modelData.act)
                    }
                }
            }
        }
    }

    // user + power
    Rectangle {
        id: footer
        visible: root.prefs.user || root.prefs.power
        anchors.bottom: parent.bottom
        width: parent.width
        height: visible ? Theme.u * 20 : 0
        color: Qt.alpha(Theme.menuHeader, 0.55)
        Rectangle {
            width: parent.width
            height: Theme.u
            color: Theme.menuBorder
        }
        StartUser {
            visible: root.prefs.user
            x: Theme.u * 8
            anchors.verticalCenter: parent.verticalCenter
            frameColor: root.accentColor
            onOpened: root.closeRequested()
        }
        Row {
            visible: root.prefs.power
            anchors.right: parent.right
            anchors.rightMargin: Theme.u * 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.u * 3
            PxButton {
                compact: true
                icon: "download"
                accent: Updates.available
                onClicked: root.act(() => Shell.openSettings("updates"))
            }
            PxButton {
                compact: true
                icon: "lock"
                onClicked: root.act(() => Shell.lock())
            }
            PxButton {
                compact: true
                icon: "power"
                onClicked: root.act(() => Shell.sessionOpen = true)
            }
        }
    }
}
