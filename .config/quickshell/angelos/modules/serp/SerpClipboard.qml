pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import "../../services/Links.js" as Links

// serp-skin: Serpantinum's launcher-like clipboard in place of angelOS's ClipboardPanel (Mod+V,
// Shell.clipboardOpen) — the same history (services/Clipboard) and keys: type to filter, Up/Down,
// Enter or a click pastes into the window you were in (Shift+Enter only copies), Delete removes,
// Ctrl+D or the star keeps an entry in Favourites, Ctrl+O opens its link in the mini island,
// Tab / Shift+Tab walk All · Text · Images · Favourites, Esc or a click beside it closes.
PanelWindow {
    id: win
    // the wallpaper in screen space, for the liquid glass (Serp.glassOn)
    SerpBackdrop {
        id: glassBack
        origin: Qt.point(0, 0)
    }

    screen: Shell.focusedScreen
    visible: Shell.clipboardOpen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: Qt.alpha(Serp.crust, 0.25)
    WlrLayershell.namespace: "angelos-serpclipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    // takes input: the clipboard history: a click beside it closes it
    WlrLayershell.keyboardFocus: visible ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None
    BackgroundEffect.blurRegion: Serp.blurOn ? blurRegion : null
    Region {
        id: blurRegion
        item: card
        radius: Serp.radius
    }

    // a small tool on a row: ⇩ ♪ ↗ ★
    component Tool: Item {
        id: tool
        property string icon: ""
        property color tint: Serp.text
        readonly property bool hovered: toolMa.containsMouse
        signal hit
        width: Serp.px(26)
        height: Serp.px(26)
        Rectangle {
            anchors.fill: parent
            radius: Serp.radiusSmall
            color: toolMa.containsMouse ? Serp.hover : "transparent"
        }
        SIcon {
            anchors.centerIn: parent
            name: tool.icon
            size: Serp.px(14)
            color: tool.tint
        }
        MouseArea {
            id: toolMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tool.hit()
        }
    }

    property string query: ""
    property int current: 0
    property string kind: "all"          // all | text | image | fav
    // the history as rows filtered in C++ (SortFilterProxyModel): typing keeps the rows that still
    // match, so their pictures are not decoded again on every key
    readonly property var byKey: {
        const m = {};
        for (const h of Clipboard.history)
            m[Clipboard.key(h)] = h;
        return m;
    }
    readonly property int count: list.count
    function entryAt(i) {
        if (i < 0 || i >= shown.rowCount())
            return null;
        const src = shown.mapToSource(shown.index(i, 0)).row;
        return src < 0 ? null : byKey[rows.get(src).key] || null;
    }
    function hay(h) {
        return h.kind === "image" ? I18n.t("картинка", "image") + " image " + (h.mime || "") : String(h.text || "");
    }
    // brings `rows` to the history in place: moves, inserts and removes, never a reset
    function sync() {
        const want = Clipboard.history;
        for (let i = 0; i < want.length; i++) {
            const h = want[i];
            const k = Clipboard.key(h);
            let j = i;
            while (j < rows.count && rows.get(j).key !== k)
                j++;
            if (j === rows.count)
                rows.insert(i, {
                    "key": k,
                    "kind": h.kind || "text",
                    "fav": !!h.fav,
                    "hay": hay(h)
                });
            else {
                if (j !== i)
                    rows.move(j, i, 1);
                if (rows.get(i).fav !== !!h.fav)
                    rows.setProperty(i, "fav", !!h.fav);
            }
        }
        if (rows.count > want.length)
            rows.remove(want.length, rows.count - want.length);
    }
    Connections {
        target: Clipboard
        function onHistoryChanged() {
            win.sync();
            win.current = Math.max(0, Math.min(win.current, win.count - 1));
        }
    }
    ListModel {
        id: rows
        // gives the model its roles before the filters look for them; sync() clears it
        ListElement {
            key: ""
            kind: ""
            fav: false
            hay: ""
        }
    }
    SortFilterProxyModel {
        id: shown
        model: rows
        filters: [
            RegExpFilter {
                roleName: "hay"
                regExp: new RegExp(win.query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i")
            },
            ValueFilter {
                roleName: "kind"
                value: win.kind
                enabled: win.kind === "text" || win.kind === "image"
            },
            ValueFilter {
                roleName: "fav"
                value: true
                enabled: win.kind === "fav"
            }
        ]
    }
    function sizeLabel(h) {
        const parts = [];
        if (h.width && h.height)
            parts.push(h.width + "×" + h.height);
        if (h.bytes)
            parts.push(h.bytes > 1048576 ? (h.bytes / 1048576).toFixed(1) + I18n.t(" МБ", " MB") : Math.max(1, Math.round(h.bytes / 1024)) + I18n.t(" КБ", " KB"));
        parts.push(String(h.mime || "image").replace("image/", "").toUpperCase());
        return parts.join(" · ");
    }
    // the first web link of a text entry (a long one is looked at only at its start)
    function linkOf(entry) {
        if (!entry || entry.kind === "image")
            return "";
        const l = Links.scan(String(entry.text || "").slice(0, 2000)).find(x => x.kind === "url");
        return l ? l.url : "";
    }
    function openLink(entry) {
        const u = linkOf(entry);
        if (!u)
            return;
        Island.open(u);
        Shell.clipboardOpen = false;
    }
    function pick(entry, copyOnly) {
        if (!entry)
            return;
        if (copyOnly)
            Clipboard.copy(entry);
        else
            Clipboard.paste(entry);
        Shell.clipboardOpen = false;
    }
    function setKind(k) {
        kind = k;
        current = 0;
        list.positionViewAtBeginning();
        field.forceActiveFocus();
    }
    function move(d) {
        if (!count)
            return;
        current = Math.max(0, Math.min(count - 1, current + d));
        list.positionViewAtIndex(current, ListView.Contain);
    }

    // built when it opens (a loader), so the first showing is the creation itself
    Component.onCompleted: {
        sync();
        if (visible)
            opened();
    }
    onVisibleChanged: if (visible)
        opened()
    function opened() {
        Clipboard.aim();
        query = "";
        current = 0;
        kind = "all";
        field.text = "";
        clearBtn.armed = false;
        field.forceActiveFocus();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Shell.clipboardOpen = false
    }

    readonly property var kinds: [
        {
            "value": "all",
            "label": I18n.t("Всё", "All") + " · " + Clipboard.history.length
        },
        {
            "value": "text",
            "label": I18n.t("Текст", "Text")
        },
        {
            "value": "image",
            "label": I18n.t("Картинки", "Images") + " · " + Clipboard.imageCount
        },
        {
            "value": "fav",
            "label": I18n.t("Избранное", "Favourites") + " · " + Clipboard.favCount
        }
    ]

    SGlass {
        id: card
        readonly property int pad: Serp.px(12)
        anchors.centerIn: parent
        width: Math.min(Serp.px(600), parent.width - Serp.px(32))
        height: Math.min(Serp.px(520), parent.height - Serp.px(64))
        radius: Serp.radius
        backdrop: glassBack
        tintAmount: Math.max(Serp.cfg.glassTint, 0.75)  // text-heavy: readable over any wallpaper
        frost: 6  // frosted harder: the picture behind becomes light, not shapes
        // the card eats its clicks (a click beside it closes)
        MouseArea {
            anchors.fill: parent
            onClicked: field.forceActiveFocus()
        }

        // ---- the search ----
        Rectangle {
            id: search
            x: card.pad
            y: card.pad
            width: parent.width - card.pad * 2 - clearBtn.width - Serp.px(8)
            height: Serp.px(40)
            radius: Serp.radiusSmall
            color: Serp.surface0
            border.width: 1
            border.color: field.activeFocus ? Qt.alpha(Serp.accent, 0.5) : Serp.line
            SIcon {
                id: searchIcon
                x: Serp.px(12)
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                color: Serp.subtext0
            }
            TextInput {
                id: field
                anchors.left: searchIcon.right
                anchors.leftMargin: Serp.px(10)
                anchors.right: parent.right
                anchors.rightMargin: Serp.px(12)
                anchors.verticalCenter: parent.verticalCenter
                font.family: Serp.font
                font.pixelSize: Serp.textSize
                color: Serp.text
                selectionColor: Serp.selected
                selectedTextColor: Serp.text
                clip: true
                focus: true
                cursorDelegate: Rectangle {
                    width: Serp.px(2)
                    color: Serp.accent
                    visible: field.activeFocus
                }
                onTextEdited: {
                    win.query = text;
                    win.current = 0;
                    list.positionViewAtBeginning();
                }
                SText {
                    visible: field.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("Поиск в буфере…", "Search the clipboard…")
                    dim: true
                }
                Keys.onPressed: e => {
                    const shift = e.modifiers & Qt.ShiftModifier, ctrl = e.modifiers & Qt.ControlModifier;
                    if (e.key === Qt.Key_Escape) {
                        Shell.clipboardOpen = false;
                    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                        if (win.count)
                            win.pick(win.entryAt(win.current), !!shift);
                    } else if (e.key === Qt.Key_O && ctrl && win.count) {
                        win.openLink(win.entryAt(win.current));
                    } else if (e.key === Qt.Key_D && ctrl && win.count) {
                        Clipboard.toggleFav(win.entryAt(win.current));
                    } else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                        const order = ["all", "text", "image", "fav"];
                        win.setKind(order[(order.indexOf(win.kind) + (e.key === Qt.Key_Tab ? 1 : 3)) % 4]);
                    } else if (e.key === Qt.Key_Down) {
                        win.move(1);
                    } else if (e.key === Qt.Key_Up) {
                        win.move(-1);
                    } else if (e.key === Qt.Key_PageDown) {
                        win.move(8);
                    } else if (e.key === Qt.Key_PageUp) {
                        win.move(-8);
                    } else if (e.key === Qt.Key_Delete && win.count) {
                        Clipboard.remove(win.entryAt(win.current));
                    } else {
                        return;
                    }
                    e.accepted = true;
                }
            }
        }
        // "Clear" keeps favourites; on the Favourites tab it clears them, after a second click
        SButton {
            id: clearBtn
            property bool armed: false
            anchors.right: parent.right
            anchors.rightMargin: card.pad
            y: card.pad
            implicitHeight: search.height
            implicitWidth: Math.max(search.height, clearRow.implicitWidth + Serp.px(20))
            flat: false
            active: armed
            Row {
                id: clearRow
                spacing: Serp.px(6)
                SIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "trash-2"
                    color: clearBtn.armed ? Serp.red : Serp.subtext1
                }
                SText {
                    visible: clearBtn.armed
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("ещё раз", "again")
                    color: Serp.red
                }
            }
            onClicked: {
                if (win.kind !== "fav") {
                    Clipboard.clear();
                } else if (armed) {
                    armed = false;
                    Clipboard.clearFavorites();
                } else {
                    armed = true;
                    disarm.restart();
                }
                field.forceActiveFocus();
            }
            Timer {
                id: disarm
                interval: 3000
                onTriggered: clearBtn.armed = false
            }
        }

        // ---- the kinds ----
        Row {
            id: kindRow
            x: card.pad
            y: search.y + search.height + Serp.px(8)
            spacing: Serp.px(4)
            Repeater {
                model: win.kinds
                SButton {
                    id: kb
                    required property var modelData
                    active: win.kind === modelData.value
                    implicitHeight: Serp.px(26)
                    padH: Serp.px(10)
                    Row {
                        spacing: Serp.px(5)
                        SIcon {
                            visible: kb.modelData.value === "fav"
                            anchors.verticalCenter: parent.verticalCenter
                            name: "star"
                            size: Serp.px(12)
                            color: kb.active ? Serp.accent : Serp.subtext0
                        }
                        SText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: kb.modelData.label
                            size: Serp.smallSize
                            bold: kb.active
                            color: kb.active ? Serp.accent : Serp.subtext0
                        }
                    }
                    onClicked: win.setKind(modelData.value)
                }
            }
        }

        Rectangle {
            id: divider
            x: card.pad
            y: kindRow.y + kindRow.height + Serp.px(8)
            width: parent.width - card.pad * 2
            height: 1
            color: Serp.line
        }

        SText {
            visible: win.count === 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: list.y + Serp.px(40)
            width: parent.width - Serp.px(80)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            text: win.kind === "fav" ? I18n.t("здесь живут записи со звёздочкой — нажми ★ у записи или Ctrl+D", "Starred entries live here: press ★ on an entry or Ctrl+D") : I18n.t("пусто… скопируй что-нибудь", "Nothing here… copy something")
            dim: true
        }

        ListView {
            id: list
            x: Serp.px(6)
            y: divider.y + Serp.px(6)
            width: parent.width - Serp.px(12)
            height: parent.height - y - footer.height - Serp.px(6)
            clip: true
            model: shown
            spacing: Serp.px(2)
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: item
                required property string key
                required property int index
                readonly property var entry: win.byKey[key] || ({})
                readonly property bool sel: index === win.current
                readonly property bool isImage: entry.kind === "image"
                readonly property string link: win.linkOf(entry)
                readonly property bool video: !!link && VideoGrab.grabbable(link)
                readonly property bool hot: m.containsMouse || starBtn.hovered || linkBtn.hovered || grabBtn.hovered || soundBtn.hovered
                readonly property color ink: sel ? Serp.accent : Serp.text
                width: list.width
                height: isImage && sel ? Serp.px(96) : Serp.px(44)
                radius: Serp.radiusSmall
                color: sel ? Serp.selected : hot ? Serp.hover : "transparent"
                Behavior on height {
                    NumberAnimation {
                        duration: Serp.normal
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Serp.quick
                    }
                }
                MouseArea {
                    id: m
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => win.pick(item.entry, !!(mouse.modifiers & Qt.ShiftModifier))
                }

                // the left: a kind's box, or the picture
                Rectangle {
                    id: lead
                    x: Serp.px(6)
                    anchors.verticalCenter: parent.verticalCenter
                    width: item.isImage ? Math.min(item.width * 0.4, (item.height - Serp.px(10)) * Math.max(0.6, Math.min(2.4, thumb.ratio))) : Serp.px(32)
                    height: item.isImage ? item.height - Serp.px(10) : Serp.px(32)
                    radius: Serp.radiusSmall
                    color: Serp.surface1
                    clip: true
                    SIcon {
                        visible: !item.isImage || thumb.status !== Image.Ready
                        anchors.centerIn: parent
                        name: item.isImage ? "image" : item.link ? "globe" : "file-text"
                        size: Serp.px(15)
                        color: item.sel ? Serp.accent : Serp.subtext0
                    }
                    Image {
                        id: thumb
                        readonly property real ratio: item.entry.width && item.entry.height ? item.entry.width / item.entry.height : (implicitHeight > 0 ? implicitWidth / implicitHeight : 1.6)
                        anchors.fill: parent
                        visible: item.isImage
                        source: item.isImage ? "file://" + item.entry.path : ""
                        // never decode a full-size screenshot for a thumbnail
                        sourceSize.width: Math.ceil(list.width * 0.4)
                        sourceSize.height: Serp.px(96)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        smooth: true
                        mipmap: true
                    }
                }

                Column {
                    anchors.left: lead.right
                    anchors.leftMargin: Serp.px(10)
                    anchors.right: tools.left
                    anchors.rightMargin: Serp.px(6)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Serp.px(1)
                    SText {
                        width: parent.width
                        text: item.isImage ? (thumb.status === Image.Error ? I18n.t("Картинка — файл удалён", "Image: file missing") : I18n.t("Картинка", "Image")) : String(item.entry.text || "").replace(/\s+/g, " ").slice(0, 300)
                        color: item.ink
                        bold: item.sel
                    }
                    SText {
                        visible: item.isImage || item.sel
                        width: parent.width
                        text: item.isImage ? win.sizeLabel(item.entry) : Clipboard.pastes ? I18n.t("Enter — вставить, Shift+Enter — только скопировать", "Enter: paste, Shift+Enter: copy only") : I18n.t("Enter — скопировать", "Enter: copy")
                        size: Serp.smallSize
                        color: item.sel ? Qt.alpha(Serp.accent, 0.75) : Serp.subtext0
                    }
                }

                // the right: ⇩ ♪ of a video's link, ↗ a link, ★
                Row {
                    id: tools
                    anchors.right: parent.right
                    anchors.rightMargin: Serp.px(6)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Serp.px(2)
                    readonly property bool lit: item.sel || item.hot
                    Tool {
                        id: grabBtn
                        tint: item.ink
                        visible: item.video && tools.lit
                        icon: "download"
                        onHit: {
                            VideoGrab.grab(item.link, false);
                            Shell.clipboardOpen = false;
                        }
                    }
                    Tool {
                        id: soundBtn
                        tint: item.ink
                        visible: item.video && tools.lit
                        icon: "music"
                        onHit: {
                            VideoGrab.grab(item.link, true);
                            Shell.clipboardOpen = false;
                        }
                    }
                    Tool {
                        id: linkBtn
                        tint: item.ink
                        visible: !!item.link && tools.lit
                        icon: "external-link"
                        onHit: win.openLink(item.entry)
                    }
                    Tool {
                        id: starBtn
                        visible: !!item.entry.fav || tools.lit
                        icon: "star"
                        tint: item.entry.fav ? Serp.yellow : item.ink
                        onHit: Clipboard.toggleFav(item.entry)
                    }
                }
            }
        }

        // ---- the keys ----
        SText {
            id: footer
            x: card.pad
            anchors.bottom: parent.bottom
            width: parent.width - card.pad * 2
            height: Serp.px(30)
            text: "↑↓  Enter  ·  Shift+Enter " + I18n.t("копия", "copy") + "  ·  Del  ·  Ctrl+D ★  ·  Ctrl+O ↗  ·  Tab"
            size: Serp.smallSize
            color: Qt.alpha(Serp.subtext0, 0.7)
            horizontalAlignment: Text.AlignHCenter
        }
    }

    RightClickGuard {}
}
