pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// The windows of a task button (modules/bar/parts/Tasks), a picture of each under its title:
// live on angel-niri (snapshot-window once a second while it shows), a minimized one the picture
// it left with (services/Minimize). A click on one brings that window up. Opened by resting the
// pointer on a button, or by clicking a group of one app's windows.
PopupWindow {
    id: root

    property Item anchorItem: null
    property var wins: []
    property bool above: true
    property bool pinned: false            // a group clicked open
    readonly property bool hovered: hov.hovered
    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") + "/angel-niri/preview"
    property int tick: 0
    signal picked(var win)

    readonly property int tileW: Theme.u * 84
    readonly property int tileH: Theme.u * 52

    property string side: BarLayout.side
    anchor.item: anchorItem
    anchor.rect.x: side === "left" ? (anchorItem ? anchorItem.width : 0) + Theme.u * 2 : side === "right" ? -Theme.u * 2 : 0
    anchor.rect.y: side ? 0 : above ? -Theme.u * 2 : (anchorItem ? anchorItem.height : 0) + Theme.u * 2
    anchor.rect.width: side ? 1 : (anchorItem ? anchorItem.width : 1)
    anchor.rect.height: side ? (anchorItem ? anchorItem.height : 1) : 1
    anchor.edges: side === "left" ? Edges.Top | Edges.Right : side === "right" ? Edges.Top | Edges.Left : (above ? Edges.Top : Edges.Bottom)
    anchor.gravity: side === "left" ? Edges.Bottom | Edges.Right : side === "right" ? Edges.Bottom | Edges.Left : (above ? Edges.Top : Edges.Bottom)
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
    color: "transparent"
    implicitWidth: box.width
    implicitHeight: box.height
    visible: false

    // a fresh picture of each window a second; the images reload a beat later, once it is saved
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.visible && Niri.nativeMinimize
        onTriggered: {
            for (const w of root.wins) {
                if (!Minimize.isMinimized(w))
                    Niri.action("SnapshotWindow", {
                        "id": w.id,
                        "path": root.dir + "/" + w.id + ".png"
                    });
            }
            reload.restart();
        }
    }
    Timer {
        id: reload
        interval: 300
        onTriggered: root.tick++
    }

    PxBox {
        id: box
        width: tiles.implicitWidth + Theme.u * 8
        height: tiles.implicitHeight + Theme.u * 8
        color: Theme.panel
        shadow: Config.appearance.shadows

        HoverHandler {
            id: hov
        }

        Row {
            id: tiles
            anchors.centerIn: parent
            spacing: Theme.u * 4

            Repeater {
                model: root.wins
                Item {
                    id: tile
                    required property var modelData
                    readonly property bool minimized: Minimize.isMinimized(modelData)
                    width: root.tileW
                    height: title.height + Theme.u * 2 + root.tileH

                    Row {
                        id: title
                        width: parent.width
                        spacing: Theme.u * 2
                        AppIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            appId: tile.modelData.app_id || ""
                            size: Theme.u * 7
                        }
                        PxText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.u * 9
                            text: Niri.titleOf(tile.modelData) || tile.modelData.app_id || "?"
                            elide: Text.ElideRight
                            font.bold: tile.modelData.is_focused
                        }
                    }
                    PxBox {
                        id: frame
                        y: title.height + Theme.u * 2
                        width: parent.width
                        height: root.tileH
                        color: pick.containsMouse ? Theme.accent : Theme.face
                        Image {
                            id: shot
                            anchors.fill: parent
                            anchors.margins: Theme.u * 2
                            fillMode: Image.PreserveAspectFit
                            // loaded at once: an async reload blanks the picture every second
                            asynchronous: false
                            cache: false
                            smooth: true
                            opacity: tile.minimized ? 0.6 : 1
                            source: tile.minimized ? (Minimize.shots[tile.modelData.id] || "") : Niri.nativeMinimize && root.tick > 0 ? "file://" + root.dir + "/" + tile.modelData.id + ".png?" + root.tick : ""
                        }
                        // no picture (plain niri, or not saved yet): the app's icon
                        AppIcon {
                            visible: shot.status !== Image.Ready
                            anchors.centerIn: parent
                            appId: tile.modelData.app_id || ""
                            size: Theme.u * 16
                        }
                        MouseArea {
                            id: pick
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.picked(tile.modelData)
                        }
                    }
                }
            }
        }
    }

    RightClickGuard {}
}
