pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.serp
import "../../../widgets/MacIcons.js" as MacIcons

// serp skin (after frostpix's pc-kit): Settings view "serp" — angelOS's System Settings in the shape of
// Serpantinum's Guide (the skin's own small window, modules/serp/SerpSettings). MacView's
// contract (view, searchSlot, resultsSlot, pageSlot, sidebarVisible, navKey), the skin's look:
// a rounded card of Serp.solid; on the left a Guide sidebar — the title, the search, your
// account, the categories, the current one's pages as indented sub-rows, ONE accent plate that
// slides to the row in view; on the right a header (‹ › the crumbs, undo, a new window, the
// window's buttons) and the page, which slides in softly on each change. The pages' controls
// keep settingsSkin "goldengate" (Px* widgets) — GoldenGate's tokens wear Serp's colours while
// the skin is on (hunks/settings.py).
Item {
    id: root

    required property var view              // SettingsView
    readonly property alias searchSlot: searchSlot
    readonly property alias resultsSlot: resultsSlot
    readonly property alias pageSlot: pageSlot
    readonly property bool sidebarVisible: true
    readonly property real sideW: Math.min(Serp.px(232), width * 0.34)
    readonly property real headerH: Serp.px(52)
    // as SerpSettings' card (SettingsWindow's blur region rounds the same, hunks/settings.py)
    readonly property real cardRadius: Math.min(Serp.px(24), Serp.radius * 1.4)

    // ---- the sidebar's rows: you, every category, the pages of the current one ----
    readonly property string curSec: view.sectionOf(view.currentId)
    readonly property var rows: {
        const out = [
            {
                "kind": "account",
                "id": SettingsTree.accountPage
            }
        ];
        for (const s of view.visibleSections) {
            out.push({
                "kind": "sec",
                "id": s.id,
                "sec": s
            });
            if (s.pages.length > 1)
                for (const p of s.pages)
                    out.push({
                        "kind": "page",
                        "id": p,
                        "sec": s
                    });
        }
        return out;
    }
    function rowShown(r) {
        return r.kind !== "page" || r.sec.id === curSec;
    }
    // the row under the plate: the page itself, else its category, else you
    readonly property int activeRow: {
        const id = view.currentId;
        let sec = -1;
        for (let i = 0; i < rows.length; i++) {
            const r = rows[i];
            if (r.kind === "account" && curSec === "account")
                return i;
            if (r.kind === "page" && r.id === id)
                return i;
            if (r.kind === "sec" && r.id === curSec)
                sec = i;
        }
        return sec;
    }
    function openRow(r, mouse) {
        if (!r)
            return;
        const target = r.kind === "sec" ? view.sectionTarget(r.sec) : r.id;
        if (mouse && view.clickedNew(mouse, target))
            return;
        view.settingsNav.settingsPage = target;
        view.settingsNav.settingsSub = "";
    }
    function iconOf(id) {
        const p = view.pageEntry(id);
        return MacIcons.fromPixel(p ? p.icon : "") || "settings";
    }

    // ↑↓ walk the rows shown, Home/End, ← up a level, → / Enter into a category's first page
    function navKey(e) {
        const shown = [];
        for (let i = 0; i < rows.length; i++)
            if (rowShown(rows[i]))
                shown.push(i);
        if (!shown.length)
            return false;
        if (e.key === Qt.Key_Down || e.key === Qt.Key_Up) {
            const at = shown.indexOf(activeRow);
            const n = Math.max(0, Math.min(shown.length - 1, (at < 0 ? 0 : at) + (e.key === Qt.Key_Down ? 1 : -1)));
            openRow(rows[shown[n]], null);
            return true;
        }
        if (e.key === Qt.Key_Home || e.key === Qt.Key_End) {
            openRow(rows[e.key === Qt.Key_Home ? shown[0] : shown[shown.length - 1]], null);
            return true;
        }
        if (e.key === Qt.Key_Left) {
            view.goUp();
            return true;
        }
        if ((e.key === Qt.Key_Right || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && String(view.currentId).startsWith("cat:")) {
            const s = view.navSectionOf(view.currentId);
            if (s && s.pages.length) {
                view.settingsNav.settingsPage = s.pages[0];
                view.settingsNav.settingsSub = "";
            }
            return true;
        }
        return false;
    }
    // this window in niri (for the minimize hook): by its title, -1 if niri doesn't list it
    function nativeId() {
        const t = view.hostWindow ? String(view.hostWindow.title) : "";
        const same = Niri.windows.filter(x => x.app_id === "org.quickshell" && x.title === t);
        const w = same.find(x => x.is_focused) || same[0];
        return w ? w.id : -1;
    }
    function moveWindow() {
        if (view.hostWindow)
            view.hostWindow.startSystemMove();
    }
    function zoomWindow() {
        if (view.hostWindow)
            view.hostWindow.maximized = !view.hostWindow.maximized;
    }

    // ---- where this window stands on its screen: niri knows (its layout), Wayland doesn't tell
    // the window — for the liquid glass to refract the right part of the wallpaper ----
    readonly property var nwin: {
        const t = view.hostWindow ? String(view.hostWindow.title) : "";
        const same = Niri.windows.filter(x => x.app_id === "org.quickshell" && x.title === t);
        return same.find(x => x.is_focused) || same[0] || null;
    }
    readonly property var nws: nwin ? Niri.workspaceById(nwin.workspace_id) : null
    readonly property bool located: !!(nwin && nwin.layout && nwin.layout.tile_pos_in_workspace_view && nws)
    // the card's own corner inside the window (the frames around it), re-read when the layout moves
    property point inWindow: Qt.point(0, 0)
    function measure() {
        const p = root.mapToItem(null, 0, 0);
        inWindow = Qt.point(p.x, p.y);
    }
    onWidthChanged: Qt.callLater(measure)
    onHeightChanged: Qt.callLater(measure)
    Component.onCompleted: Qt.callLater(measure)
    readonly property point screenOrigin: located ? Qt.point(nwin.layout.tile_pos_in_workspace_view[0] + (nwin.layout.window_offset_in_tile ? nwin.layout.window_offset_in_tile[0] : 0) + inWindow.x, nwin.layout.tile_pos_in_workspace_view[1] + (nwin.layout.window_offset_in_tile ? nwin.layout.window_offset_in_tile[1] : 0) + inWindow.y) : Qt.point(0, 0)
    SerpBackdrop {
        id: glassBack
        active: Serp.glassOn && root.located
        screenName: root.nws ? root.nws.output : ""
        origin: root.screenOrigin
    }

    // ---- the card: the liquid glass where we know where we are, else a solid plate ----
    Rectangle {
        anchors.fill: parent
        radius: root.cardRadius
        color: Serp.solid
        border.width: 1
        border.color: Serp.line
        visible: !card.visible
    }
    SGlass {
        id: card
        visible: Serp.glassOn && root.located
        anchors.fill: parent
        radius: root.cardRadius
        backdrop: glassBack
        tintAmount: Math.max(Serp.cfg.glassTint, 0.75)  // text everywhere: readable over any wallpaper
        frost: 6
    }

    // ---- the Guide sidebar ----
    Rectangle {
        id: side
        x: Serp.px(10)
        y: Serp.px(10)
        width: root.sideW
        height: parent.height - Serp.px(20)
        radius: Serp.radius
        color: Qt.alpha(Serp.surface0, 0.4)
        clip: true

        // the title; the empty part moves the window
        Item {
            id: head
            x: Serp.px(12)
            y: Serp.px(12)
            width: parent.width - Serp.px(24)
            height: Serp.px(34)
            MouseArea {
                anchors.fill: parent
                onPressed: root.moveWindow()
                onDoubleClicked: root.zoomWindow()
            }
            SText {
                x: Serp.px(6)
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x
                text: I18n.t("Настройки", "Settings")
                size: Serp.px(15)
                bold: true
            }
        }
        // the search (SettingsView puts its field here)
        Item {
            id: searchSlot
            x: head.x
            y: head.y + head.height + Serp.px(8)
            width: head.width
            height: root.view.searchFieldHeight
        }

        Flickable {
            id: list
            visible: !root.view.searching
            anchors.fill: parent
            anchors.topMargin: searchSlot.y + searchSlot.height + Serp.px(10)
            anchors.bottomMargin: Serp.px(8)
            contentHeight: nav.height + Serp.px(4)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            function ensure(it) {
                if (!it)
                    return;
                if (it.y < contentY)
                    contentY = it.y;
                else if (it.y + it.height > contentY + height)
                    contentY = Math.max(0, it.y + it.height - height);
            }

            Item {
                x: Serp.px(12)
                width: side.width - Serp.px(24)
                height: nav.height

                // ONE accent plate, sliding to the row in view
                Rectangle {
                    id: plate
                    readonly property Item cur: root.activeRow >= 0 && rep.count > root.activeRow ? rep.itemAt(root.activeRow) : null
                    visible: cur !== null && cur.height > 0
                    width: parent.width
                    y: cur ? cur.y : 0
                    height: cur ? cur.height : 0
                    radius: Serp.radiusSmall
                    color: Qt.alpha(Serp.accent, 0.16)
                    onCurChanged: Qt.callLater(() => list.ensure(plate.cur))
                    Behavior on y {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutQuint
                        }
                    }
                    Behavior on height {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutQuint
                        }
                    }
                }

                Column {
                    id: nav
                    width: parent.width
                    spacing: 0
                    Repeater {
                        id: rep
                        model: root.rows
                        delegate: Item {
                            id: nr
                            required property var modelData
                            required property int index
                            readonly property string kind: modelData.kind
                            readonly property bool sub: kind === "page"
                            readonly property bool active: index === root.activeRow
                            readonly property bool shown: root.rowShown(modelData)
                            readonly property bool fresh: kind === "sec" ? SettingsNews.sectionNew(modelData.sec) : SettingsNews.pageNew(modelData.id)
                            readonly property color ink: active ? Serp.accent : nma.containsMouse ? Serp.text : Serp.subtext1
                            readonly property real fullH: kind === "account" ? Serp.px(54) : sub ? Serp.px(34) : Serp.px(40)
                            width: nav.width
                            height: shown ? fullH + (kind === "account" ? Serp.px(6) : Serp.px(2)) : 0
                            clip: true
                            Behavior on height {
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutQuint
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: nr.fullH
                                radius: Serp.radiusSmall
                                color: nma.containsMouse && !nr.active ? Qt.alpha(Serp.text, 0.06) : "transparent"
                                Behavior on color {
                                    ColorAnimation {
                                        duration: Serp.quick
                                    }
                                }
                            }

                            // you: the avatar, the name, "angelOS account"
                            Item {
                                visible: nr.kind === "account"
                                width: parent.width
                                height: nr.fullH
                                Rectangle {
                                    id: face
                                    x: Serp.px(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Serp.px(36)
                                    height: width
                                    radius: width / 2
                                    color: Qt.alpha(Serp.accent, 0.25)
                                    clip: true
                                    Image {
                                        id: avatar
                                        anchors.fill: parent
                                        source: nr.kind === "account" ? StartPrefs.avatarUrl : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        sourceSize: Qt.size(width * 2, height * 2)
                                        visible: status === Image.Ready
                                    }
                                    SIcon {
                                        visible: avatar.status !== Image.Ready
                                        anchors.centerIn: parent
                                        name: "user"
                                        size: parent.width * 0.55
                                        color: Serp.accent
                                    }
                                }
                                Column {
                                    anchors.left: face.right
                                    anchors.leftMargin: Serp.px(10)
                                    anchors.right: parent.right
                                    anchors.rightMargin: Serp.px(nr.fresh ? 22 : 8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    SText {
                                        width: parent.width
                                        text: StartPrefs.userName
                                        size: Serp.px(13)
                                        bold: true
                                        color: nr.active ? Serp.accent : Serp.text
                                    }
                                    SText {
                                        width: parent.width
                                        text: I18n.t("Учётная запись angelOS", "angelOS Account")
                                        size: Serp.smallSize
                                        color: Serp.subtext0
                                    }
                                }
                            }

                            // a category or one of its pages
                            Item {
                                visible: nr.kind !== "account"
                                width: parent.width
                                height: nr.fullH
                                Item {
                                    id: ibox
                                    x: Serp.px(10) + (nr.sub ? Serp.px(20) : 0)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Serp.px(24)
                                    height: width
                                    SIcon {
                                        anchors.centerIn: parent
                                        name: nr.kind === "sec" ? (MacIcons.fromPixel(nr.modelData.sec.icon || "") || "settings") : nr.kind === "page" ? root.iconOf(nr.modelData.id) : "settings"
                                        size: nr.sub ? Serp.px(15) : Serp.px(17)
                                        color: nr.ink
                                    }
                                }
                                SText {
                                    anchors.left: ibox.right
                                    anchors.leftMargin: Serp.px(10)
                                    anchors.right: parent.right
                                    anchors.rightMargin: Serp.px(nr.fresh ? 22 : 8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: nr.kind === "sec" ? nr.modelData.sec.label : nr.kind === "page" ? root.view.labelOf(nr.modelData.id) : ""
                                    size: nr.sub ? Serp.px(12) : Serp.px(13)
                                    color: nr.ink
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Serp.quick
                                        }
                                    }
                                }
                            }

                            // something new there (services/SettingsNews): a dot
                            Rectangle {
                                visible: nr.fresh
                                anchors.right: parent.right
                                anchors.rightMargin: Serp.px(10)
                                y: (nr.fullH - height) / 2
                                width: Serp.px(7)
                                height: width
                                radius: width / 2
                                color: Serp.pink
                            }

                            MouseArea {
                                id: nma
                                width: parent.width
                                // the whole row with its 2 px gap: the gap under each row was no one's,
                                // and the pointer turned into an arrow there between two hands (flicker)
                                height: nr.height
                                enabled: nr.shown
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onClicked: mouse => {
                                    root.openRow(nr.modelData, mouse);
                                    root.view.focusNav();
                                }
                            }
                        }
                    }
                }
            }
        }
        Item {
            id: resultsSlot
            anchors.fill: parent
            anchors.topMargin: searchSlot.y + searchSlot.height + Serp.px(10)
            anchors.leftMargin: Serp.px(6)
            anchors.rightMargin: Serp.px(6)
            anchors.bottomMargin: Serp.px(8)
        }
    }

    // ---- the right side: the header, the page ----
    Item {
        id: main
        anchors.left: side.right
        anchors.leftMargin: Serp.px(4)
        anchors.right: parent.right
        anchors.rightMargin: Serp.px(4)
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Item {
            id: header
            width: parent.width
            height: root.headerH
            MouseArea {
                anchors.fill: parent
                onPressed: root.moveWindow()
                onDoubleClicked: root.zoomWindow()
            }
            // ‹ › through the history
            Row {
                id: hist
                x: Serp.px(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Serp.px(4)
                Repeater {
                    model: [["chevron-left", -1], ["chevron-right", 1]]
                    SButton {
                        id: hb
                        required property var modelData
                        readonly property bool can: modelData[1] < 0 ? root.view.canBack : root.view.canForward
                        width: Serp.px(30)
                        height: Serp.px(30)
                        flat: false
                        opacity: can ? 1 : 0.4
                        onClicked: hb.modelData[1] < 0 ? root.view.back() : root.view.forward()
                        SIcon {
                            name: hb.modelData[0]
                            size: Serp.px(16)
                            color: hb.hovered && hb.can ? Serp.text : Serp.subtext1
                        }
                    }
                }
            }
            // the crumbs: the earlier ones a click back up, the last one the page's name
            Row {
                id: crumbs
                anchors.left: hist.right
                anchors.leftMargin: Serp.px(14)
                anchors.right: tools.left
                anchors.rightMargin: Serp.px(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Serp.px(6)
                clip: true
                readonly property var list: root.view.crumbs || []
                Repeater {
                    model: crumbs.list.slice(0, -1)
                    SText {
                        id: crumb
                        required property string modelData
                        required property int index
                        text: modelData + "  ›"
                        size: Serp.px(13)
                        color: cma.containsMouse ? Serp.accent : Serp.subtext0
                        MouseArea {
                            id: cma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.view.crumbClicked(crumb.index)
                        }
                    }
                }
                SText {
                    width: Math.max(0, crumbs.width - x)
                    text: crumbs.list.length ? crumbs.list[crumbs.list.length - 1] : I18n.t("Настройки", "Settings")
                    size: Serp.px(15)
                    bold: true
                }
            }
            Row {
                id: tools
                anchors.right: parent.right
                anchors.rightMargin: Serp.px(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Serp.px(4)
                // the last change of a setting (Config.undo)
                SButton {
                    id: undo
                    visible: Config.canUndo
                    height: Serp.px(30)
                    flat: false
                    padH: Serp.px(10)
                    onClicked: Config.undo()
                    Row {
                        spacing: Serp.px(6)
                        SIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "undo-2"
                            size: Serp.px(14)
                            color: undo.hovered ? Serp.text : Serp.subtext1
                        }
                        SText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t("Отменить", "Undo")
                            size: Serp.px(12)
                            color: undo.hovered ? Serp.text : Serp.subtext1
                        }
                    }
                }
                // this pane in one more window
                SButton {
                    id: newWin
                    width: Serp.px(30)
                    height: Serp.px(30)
                    opacity: Shell.settingsMore.count < Shell.settingsMoreMax ? 1 : 0.4
                    onClicked: root.view.openNew()
                    SIcon {
                        name: "app-window"
                        size: Serp.px(16)
                        color: newWin.hovered ? Serp.text : Serp.subtext1
                    }
                }
                // the window's own buttons — angel-niri draws them itself when it can
                Item {
                    visible: !Niri.nativeMinimize
                    width: Serp.px(6)
                    height: 1
                }
                Repeater {
                    model: Niri.nativeMinimize ? [] : [["minus", "minimize"], [root.view.hostWindow && root.view.hostWindow.maximized ? "minimize-2" : "maximize-2", "zoom"], ["x", "close"]]
                    SButton {
                        id: wb
                        required property var modelData
                        width: Serp.px(30)
                        height: Serp.px(30)
                        onClicked: {
                            if (wb.modelData[1] === "close")
                                root.view.settingsNav.settingsOpen = false;
                            else if (wb.modelData[1] === "minimize")
                                Minimize.request(root.nativeId(), "settings");
                            else
                                root.zoomWindow();
                        }
                        SIcon {
                            name: wb.modelData[0]
                            size: Serp.px(15)
                            color: wb.hovered ? (wb.modelData[1] === "close" ? Serp.red : Serp.text) : Serp.subtext1
                        }
                    }
                }
            }
        }

        // the page, sliding in softly on each change (as SerpSettings' pages)
        Item {
            id: pageBox
            anchors.fill: parent
            anchors.topMargin: root.headerH
            anchors.leftMargin: Serp.px(16)
            anchors.rightMargin: Serp.px(12)
            anchors.bottomMargin: Serp.px(4)
            clip: true
            Item {
                id: pageSlot
                width: parent.width
                height: parent.height
            }
            ParallelAnimation {
                id: swap
                NumberAnimation {
                    target: pageSlot
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Serp.normal
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: pageSlot
                    property: "y"
                    from: Serp.px(10)
                    to: 0
                    duration: 360
                    easing.type: Easing.OutCubic
                }
            }
            Connections {
                target: root.view
                function onCurrentIdChanged() {
                    swap.restart();
                }
            }
        }
    }
}
