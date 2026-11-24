pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.widgets

Item {
    id: desk
    required property string screenName

    Repeater {
        model: LiveCrops.cards

        delegate: Loader {
            id: cardLoader

            required property int index
            required property var windowId
            required property string screen
            required property string appId
            required property string title
            required property real cropX
            required property real cropY
            required property real cropW
            required property real cropH
            required property real aspect
            required property real placeX
            required property real placeY

            active: screen === desk.screenName && LiveCrops.permitted(windowId, screen)
            x: clampX(placeX)
            y: clampY(placeY)

            function clampX(x) {
                const left = BarLayout.edge === "left" ? Theme.barHeight : 0;
                const right = BarLayout.edge === "right" ? Theme.barHeight : 0;
                return Math.round(Math.max(left, Math.min(x, desk.width - width - right)));
            }

            function clampY(y) {
                const top = BarLayout.edge === "top" ? Theme.barHeight : 0;
                const bottom = BarLayout.edge === "bottom" ? Theme.barHeight : 0;
                return Math.round(Math.max(top, Math.min(y, desk.height - height - bottom)));
            }

            sourceComponent: PxBox {
                id: card

                readonly property var app: DesktopEntries.heuristicLookup(cardLoader.appId)
                readonly property int gap: Theme.u * 2
                readonly property bool covered: Niri.focusedOutput === desk.screenName && Niri.focusedWindowId >= 0
                    && !Niri.overviewOpen && !Mission.shown && Shell.coveredScreen(desk.screenName)
                readonly property bool rest: Shell.gaming || Shell.idleOver(desk.screenName) || covered
                readonly property real ratio: Math.max(0.1, Math.min(cardLoader.aspect, 10))

                width: Math.round(Math.min(desk.width * 0.7, Theme.u * 168,
                    Math.max(Theme.u * 75, Theme.u * 100 * ratio)))
                height: strip.height + picture.height + inset * 2
                shadow: true

                Component.onCompleted: {
                    if (!Motion.still && !Motion.calm) {
                        opacity = 0;
                        scale = 0.94;
                        arrive.start();
                    }
                }
                ParallelAnimation {
                    id: arrive
                    NumberAnimation { target: card; property: "opacity"; to: 1; duration: 160 }
                    NumberAnimation { target: card; property: "scale"; to: 1; duration: 180; easing.type: Easing.OutCubic }
                }

                WindowCropFeed {
                    id: feed
                    windowId: cardLoader.windowId
                    requested: !card.rest
                    crop: ({
                        x: cardLoader.cropX,
                        y: cardLoader.cropY,
                        w: cardLoader.cropW,
                        h: cardLoader.cropH
                    })
                }

                Rectangle {
                    id: strip
                    width: parent.width
                    height: closeButton.implicitHeight
                    color: Theme.menuHeader

                    IconImage {
                        id: appIcon
                        anchors.left: parent.left
                        anchors.leftMargin: card.gap
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: Math.min(Theme.u * 8, strip.height)
                        source: card.app ? Quickshell.iconPath(card.app.icon, "") : ""
                        visible: source.toString() !== ""
                    }
                    PxText {
                        anchors.left: appIcon.visible ? appIcon.right : parent.left
                        anchors.leftMargin: card.gap
                        anchors.right: closeButton.left
                        anchors.rightMargin: card.gap
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.app ? card.app.name : cardLoader.title
                        elide: Text.ElideMiddle
                    }
                    MouseArea {
                        anchors.left: parent.left
                        anchors.right: closeButton.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        preventStealing: true

                        property point grabOffset

                        onPressed: mouse => {
                            grabOffset = Qt.point(mouse.x, mouse.y);
                        }
                        onPositionChanged: mouse => {
                            if (!pressed)
                                return;
                            const p = mapToItem(desk, mouse.x, mouse.y);
                            LiveCrops.cards.set(cardLoader.index, {
                                placeX: cardLoader.clampX(p.x - grabOffset.x - card.inset),
                                placeY: cardLoader.clampY(p.y - grabOffset.y - card.inset)
                            });
                        }
                    }
                    PxButton {
                        id: closeButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        compact: true
                        icon: "close"
                        Accessible.name: I18n.t("Убрать вырезку", "Remove clip")
                        onClicked: LiveCrops.cards.remove(cardLoader.index)
                    }
                }

                Item {
                    id: picture
                    anchors.top: strip.bottom
                    width: parent.width
                    height: Math.round(Math.min(Theme.u * 100, Math.max(Theme.u * 12, width / card.ratio)))

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.sunken
                    }
                    Image {
                        anchors.fill: parent
                        source: feed.frameUrl
                        cache: false
                        fillMode: Image.PreserveAspectFit
                    }
                    PxText {
                        anchors.centerIn: parent
                        visible: !feed.frameUrl || feed.failed
                        text: feed.failed ? I18n.t("Нет кадра", "No frame") : card.rest ? "" : "…"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Minimize.restore(cardLoader.windowId, true, desk.screenName)
                    }
                }
            }
        }
    }
}
