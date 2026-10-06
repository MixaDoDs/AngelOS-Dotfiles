pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Clipboard history (Mod+V): type to filter, Enter copies, Delete removes,
// Ctrl+D or the star keeps an entry in Favourites (never dropped or cleared by "Clear").
PanelWindow {
    id: win

    screen: Shell.focusedScreen
    visible: Shell.clipboardOpen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: Qt.alpha(Theme.shadow, 0.25)
    WlrLayershell.namespace: "angelos-clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    // takes input: the clipboard history: a click beside it closes it
    WlrLayershell.keyboardFocus: visible ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

    property string query: ""
    property int current: 0
    property string kind: "all"          // all | text | image | fav
    readonly property var results: Clipboard.history.filter(h => {
        if (kind === "fav" ? !h.fav : kind !== "all" && (h.kind || "text") !== kind)
            return false;
        if (!query)
            return true;
        const q = query.toLowerCase();
        return h.kind === "image" ? (I18n.t("картинка", "image") + " image " + (h.mime || "")).includes(q) : String(h.text || "").toLowerCase().includes(q);
    })
    function sizeLabel(h) {
        const parts = [];
        if (h.width && h.height)
            parts.push(h.width + "×" + h.height);
        if (h.bytes)
            parts.push(h.bytes > 1048576 ? (h.bytes / 1048576).toFixed(1) + I18n.t(" МБ", " MB") : Math.max(1, Math.round(h.bytes / 1024)) + I18n.t(" КБ", " KB"));
        parts.push(String(h.mime || "image").replace("image/", "").toUpperCase());
        return parts.join(" · ");
    }

    function pick(entry) {
        Clipboard.copy(entry);
        Shell.clipboardOpen = false;
    }

    // built when it opens (shell.qml: LazyLoader), so the first showing is the creation itself
    Component.onCompleted: if (visible)
        opened()
    onVisibleChanged: if (visible)
        opened()
    function opened() {
        query = "";
        current = 0;
        kind = "all";
        kinds.currentValue = "all";
        field.text = "";
        field.focusField();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Shell.clipboardOpen = false
    }

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: dialog
    }

    PxWindow {
        id: dialog
        anchors.centerIn: parent
        width: Theme.u * 230
        height: Theme.u * 250
        title: I18n.t("буфер_обмена.txt", "clipboard.txt")
        icon: "package"
        onCloseClicked: Shell.clipboardOpen = false

        MouseArea {
            anchors.fill: parent
        }

        PxField {
            id: field
            keepFocus: true
            width: parent.width - clearBtn.width - Theme.u * 3
            icon: "search"
            placeholder: I18n.t("поиск…", "Searching…")
            onEdited: {
                win.query = text;
                win.current = 0;
            }
            onAccepted: if (win.results.length)
                win.pick(win.results[win.current])
            onKeyPressed: e => {
                if (e.key === Qt.Key_Escape) {
                    Shell.clipboardOpen = false;
                    e.accepted = true;
                } else if (e.key === Qt.Key_D && (e.modifiers & Qt.ControlModifier) && win.results.length) {
                    Clipboard.toggleFav(win.results[win.current]);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                    const order = ["all", "text", "image", "fav"];
                    win.kind = order[(order.indexOf(win.kind) + (e.key === Qt.Key_Tab ? 1 : 3)) % 4];
                    kinds.currentValue = win.kind;   // PxSegmented keeps its own value after clicks
                    win.current = 0;
                    e.accepted = true;
                } else if (e.key === Qt.Key_Down) {
                    win.current = Math.min(win.results.length - 1, win.current + 1);
                    list.positionViewAtIndex(win.current, ListView.Contain);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Up) {
                    win.current = Math.max(0, win.current - 1);
                    list.positionViewAtIndex(win.current, ListView.Contain);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Delete && win.results.length) {
                    Clipboard.remove(win.results[win.current]);
                    e.accepted = true;
                }
            }
        }
        // "Clear" keeps favourites; on the Favourites tab it clears them, after a second click
        PxButton {
            id: clearBtn
            property bool armed: false
            anchors.right: parent.right
            height: field.height
            icon: "trash"
            text: armed ? I18n.t("ещё раз", "again") : ""
            checked: armed
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
            }
            Timer {
                id: disarm
                interval: 3000
                onTriggered: clearBtn.armed = false
            }
        }

        PxSegmented {
            id: kinds
            y: field.height + Theme.u * 4
            width: parent.width
            model: [
                {
                    "label": I18n.t("Всё", "All") + " · " + Clipboard.history.length,
                    "value": "all"
                },
                {
                    "label": I18n.t("Текст", "Text"),
                    "value": "text"
                },
                {
                    "label": I18n.t("Картинки", "Images") + " · " + Clipboard.imageCount,
                    "value": "image"
                },
                {
                    "label": "★ " + I18n.t("Избранное", "Favourites") + " · " + Clipboard.favCount,
                    "value": "fav"
                }
            ]
            currentValue: win.kind
            onActivated: v => {
                win.kind = v;
                win.current = 0;
                field.focusField();
            }
        }

        PxBox {
            y: kinds.y + kinds.height + Theme.u * 4
            width: parent.width
            height: parent.height - y
            sunken: true
            color: Qt.alpha(Theme.sunken, 0.75)

            PxText {
                visible: win.results.length === 0
                anchors.centerIn: parent
                width: parent.width - Theme.u * 20
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: win.kind === "fav" ? I18n.t("здесь живут записи со звёздочкой — нажми ★ у записи или Ctrl+D", "Starred entries live here: press ★ on an entry or Ctrl+D") : I18n.t("пусто… скопируй что-нибудь ♡", "Nothing here… copy something ♡")
                dim: true
            }

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: Theme.u * 2
                clip: true
                model: win.results
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: item
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === win.current
                    readonly property bool isImage: item.modelData.kind === "image"
                    width: list.width
                    height: isImage ? (sel ? Theme.u * 70 : Theme.u * 44) : txt.implicitHeight + Theme.u * 6
                    color: sel ? Theme.select : m.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.12) : "transparent"
                    Behavior on height {
                        NumberAnimation {
                            duration: Motion.ms(Theme.fast)
                            easing.type: Easing.OutCubic
                        }
                    }
                    // checkerboard behind transparent pictures
                    Rectangle {
                        id: frame
                        visible: item.isImage
                        x: Theme.u * 3
                        y: Theme.u * 3
                        width: Math.min(parent.width * 0.62, (parent.height - Theme.u * 6) * Math.max(0.6, Math.min(2.4, preview.ratio)))
                        height: parent.height - Theme.u * 6
                        color: Theme.sunken
                        border.width: Math.max(1, Theme.u / 2)
                        border.color: item.sel ? Theme.selectText : Theme.lo
                        clip: true
                        Image {
                            id: preview
                            readonly property real ratio: item.modelData.width && item.modelData.height ? item.modelData.width / item.modelData.height : (implicitHeight > 0 ? implicitWidth / implicitHeight : 1.6)
                            anchors.fill: parent
                            anchors.margins: parent.border.width
                            source: item.isImage ? "file://" + item.modelData.path : ""
                            // never decode a full-size screenshot for a thumbnail
                            sourceSize.width: Math.ceil(list.width * 0.62)
                            sourceSize.height: Theme.u * 70
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                            smooth: true
                            mipmap: true
                        }
                        PxText {
                            anchors.centerIn: parent
                            visible: preview.status === Image.Error
                            text: I18n.t("файл удалён", "file missing")
                            kind: "tiny"
                            dim: true
                        }
                    }
                    Column {
                        visible: item.isImage
                        anchors.left: frame.right
                        anchors.leftMargin: Theme.u * 4
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.u * 5 + star.width
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.u
                        Row {
                            spacing: Theme.u * 2
                            PxIcon {
                                name: "image"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            PxText {
                                text: I18n.t("Картинка", "Image")
                                color: item.sel ? Theme.selectText : Theme.text
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        PxText {
                            width: parent.width
                            text: win.sizeLabel(item.modelData)
                            kind: "tiny"
                            wrapMode: Text.Wrap
                            color: item.sel ? Theme.selectText : Theme.textDim
                        }
                        PxText {
                            visible: item.sel
                            width: parent.width
                            text: I18n.t("Enter — вставить в буфер", "Enter — copy back")
                            kind: "tiny"
                            wrapMode: Text.Wrap
                            color: item.sel ? Theme.selectText : Theme.textDim
                        }
                    }
                    PxText {
                        id: txt
                        visible: !item.isImage
                        x: Theme.u * 4
                        width: parent.width - Theme.u * 8 - star.width
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                        text: String(item.modelData.text || "").replace(/\s+/g, " ").slice(0, 300)
                        maximumLineCount: 2
                        wrapMode: Text.WrapAnywhere
                        elide: Text.ElideRight
                        color: item.sel ? Theme.selectText : Theme.text
                    }
                    MouseArea {
                        id: m
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.pick(item.modelData)
                    }
                    // ★ keeps it: shown on favourites, and on the row under the mouse or the selection
                    Item {
                        id: star
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.u * 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.u * 12
                        height: Theme.u * 12
                        visible: item.modelData.fav || m.containsMouse || starMouse.containsMouse || item.sel
                        PxIcon {
                            anchors.centerIn: parent
                            name: "star"
                            hollow: !item.modelData.fav
                            fill3: item.modelData.fav ? Theme.accent3 : Theme.accent4
                            ink: item.sel ? Theme.selectText : (Theme.dark ? Theme.text : Theme.edge)
                            scale: starMouse.containsMouse ? 1.2 : 1
                        }
                        MouseArea {
                            id: starMouse
                            anchors.fill: parent
                            anchors.margins: -Theme.u * 2
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Clipboard.toggleFav(item.modelData)
                        }
                    }
                }
            }
        }
    }

    RightClickGuard {}
}
