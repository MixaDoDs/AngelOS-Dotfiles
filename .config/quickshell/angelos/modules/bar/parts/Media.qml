import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// ♪ title — artist + transport.
Row {
    id: root

    property int maxWidth: Theme.u * 160
    property bool showTitle: true
    // the hell bar (BarItem): its buttons and words in the circle's colours
    property bool barInk: false
    readonly property var player: Lyrics.player

    visible: !!player && Lyrics.title !== "" && Config.bar.showMedia
    spacing: Theme.u * 2

    PxButton {
        compact: true
        flat: true
        barInk: root.barInk
        icon: "prev"
        iconPixel: Math.max(1, Theme.u - 1)
        onClicked: root.player.previous()
    }
    PxButton {
        compact: true
        flat: true
        barInk: root.barInk
        icon: root.player && root.player.isPlaying ? "pause" : "play"
        iconPixel: Math.max(1, Theme.u - 1)
        onClicked: root.player.togglePlaying()
    }
    PxButton {
        compact: true
        flat: true
        barInk: root.barInk
        icon: "next"
        iconPixel: Math.max(1, Theme.u - 1)
        onClicked: root.player.next()
    }
    Item {
        visible: root.showTitle && root.maxWidth > 0
        width: Math.min(label.implicitWidth + note.width + Theme.u * 4, root.maxWidth)
        height: parent.height
        PxIcon {
            id: note
            name: "music"
            pixel: Math.max(1, Theme.u - 1)
            ink: root.barInk ? Theme.hellBarIcon : Theme.dark ? Theme.text : Theme.edge
            palette: root.barInk ? ({
                    "o": "none",
                    "w": "none"
                }) : ({})
            anchors.verticalCenter: parent.verticalCenter
        }
        PxText {
            id: label
            anchors.left: note.right
            anchors.leftMargin: Theme.u * 3
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Lyrics.title + (Lyrics.artist ? " — " + Lyrics.artist : "")
            elide: Text.ElideRight
            color: root.barInk ? Theme.hellText : Theme.text
        }
        // left: lyrics on/off, right: the song's menu, middle: pause / play
        MouseArea {
            id: titleArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: m => {
                if (m.button === Qt.MiddleButton)
                    root.player.togglePlaying();
                else if (m.button === Qt.RightButton) {
                    songMenu.active = true;
                    const p = titleArea.mapToItem(null, m.x, m.y);
                    if (songMenu.item)
                        songMenu.item.popup(Lyrics.playerMenu(), "", p.x, p.y);
                } else
                    Lyrics.visibleToggle = !Lyrics.visibleToggle;
            }
        }
    }
    LazyLoader {
        id: songMenu
        PxMenu {
            parentWindow: root.QsWindow.window
            kind: "panel"
        }
    }
}
