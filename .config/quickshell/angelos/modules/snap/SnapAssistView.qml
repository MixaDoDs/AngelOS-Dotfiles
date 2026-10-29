pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Snap Assist (services/SnapAssist), as in Windows 11: over the part of the screen a snapped
// window left free, the desk's other windows as cards — a click snaps that one there, and the
// next free part of the layout comes up. Esc or a click beside the cards lets it go. Pictures of
// the windows come from angel-niri's snapshot-window, refreshed each second; else the app icons.
Scope {
    LazyLoader {
        active: SnapAssist.shown
        PanelWindow {
            id: win

            readonly property var offer: SnapAssist.offer
            screen: Shell.screenByName(offer ? offer.output : "") || Shell.focusedScreen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            // takes input: the whole screen — a click beside the cards lets the offer go
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            WlrLayershell.namespace: "angelos-snap-assist"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            readonly property int u: Theme.u
            readonly property rect zone: offer ? SnapAssist.rectOf(offer.zone, offer.area) : Qt.rect(0, 0, 0, 0)
            readonly property var wins: offer ? offer.wins : []
            readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") + "/angel-niri/preview"
            property int tick: 0

            Timer {
                interval: 1000
                repeat: true
                triggeredOnStart: true
                running: win.wins.length > 0 && Niri.nativeMinimize
                onTriggered: {
                    for (const w of win.wins)
                        Niri.action("SnapshotWindow", {
                            "id": w.id,
                            "path": win.dir + "/" + w.id + ".png"
                        });
                    reload.restart();
                }
            }
            Timer {
                id: reload
                interval: 300
                onTriggered: win.tick++
            }

            MouseArea {
                anchors.fill: parent
                onClicked: SnapAssist.dismiss()
            }
            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: SnapAssist.dismiss()
            }

            // the free part, a pixel frame in it, the cards in a grid in the middle
            PxBox {
                id: box
                x: win.zone.x + win.u * 2
                y: win.zone.y + win.u * 2
                width: win.zone.width - win.u * 4
                height: win.zone.height - win.u * 4
                color: Qt.alpha(Theme.panel, 0.9)
                shadow: Config.appearance.shadows
                // a click among the cards is not a click beside them
                MouseArea {
                    anchors.fill: parent
                }

                readonly property int gap: win.u * 4
                readonly property int cardW: Math.min(win.u * 84, Math.floor((width - gap * 2) / win.u) * win.u)
                readonly property int cardH: Math.round(cardW * 0.62 / win.u) * win.u + win.u * 11
                readonly property int cols: Math.max(1, Math.min(win.wins.length, Math.floor((width - gap) / (cardW + gap))))

                Grid {
                    anchors.centerIn: parent
                    columns: box.cols
                    spacing: box.gap
                    Repeater {
                        model: win.wins
                        PxBox {
                            id: card
                            required property var modelData
                            width: box.cardW
                            height: box.cardH
                            color: pick.containsMouse ? Theme.accent : Theme.face
                            Row {
                                id: title
                                x: win.u * 3
                                y: win.u * 2
                                width: parent.width - win.u * 6
                                spacing: win.u * 2
                                AppIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    appId: card.modelData.app_id || ""
                                    size: win.u * 7
                                }
                                PxText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - win.u * 9
                                    text: Niri.titleOf(card.modelData) || card.modelData.app_id || "?"
                                    elide: Text.ElideRight
                                }
                            }
                            Image {
                                id: shot
                                x: win.u * 3
                                y: win.u * 11
                                width: parent.width - win.u * 6
                                height: parent.height - win.u * 14
                                fillMode: Image.PreserveAspectFit
                                asynchronous: false
                                cache: false
                                smooth: true
                                source: Niri.nativeMinimize && win.tick > 0 ? "file://" + win.dir + "/" + card.modelData.id + ".png?" + win.tick : ""
                            }
                            AppIcon {
                                visible: shot.status !== Image.Ready
                                anchors.centerIn: shot
                                appId: card.modelData.app_id || ""
                                size: win.u * 16
                            }
                            MouseArea {
                                id: pick
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SnapAssist.fill(card.modelData)
                            }
                        }
                    }
                }
            }

            RightClickGuard {}
        }
    }
}
