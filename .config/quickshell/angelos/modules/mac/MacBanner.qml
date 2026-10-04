pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config
import qs.services
import qs.widgets

// A notification banner of the Golden Gate skin (NotificationPopups while the skin is on): a glass
// card with the app's icon, the app and "now", the title in bold, the text in two lines and its
// actions as buttons; × on hover. A click runs the default action, a right click dismisses it for
// good; it goes on its own after the timeout unless the pointer is on it — a critical one stays.
Item {
    id: root

    property var notification
    readonly property bool critical: notification && notification.urgency === NotificationUrgency.Critical
    readonly property int timeout: critical ? 0 : (notification && notification.expireTimeout > 0 ? notification.expireTimeout : Config.notifications.timeout)
    property int elapsed: 0
    implicitHeight: card.height

    Timer {
        interval: 100
        repeat: true
        running: root.timeout > 0 && !hover.hovered
        onTriggered: {
            root.elapsed += interval;
            if (root.elapsed >= root.timeout)
                Notifs.dismissPopup(root.notification);
        }
    }
    HoverHandler {
        id: hover
    }

    MacGlass {
        id: card
        width: parent.width
        height: Math.max(GoldenGate.px(64), col.implicitHeight + GoldenGate.px(24))
        radius: GoldenGate.px(20)
        shadowSize: GoldenGate.px(20)
        shadowY: GoldenGate.px(6)
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.ms(160)
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => {
                if (m.button === Qt.RightButton) {
                    Notifs.close(root.notification);
                    return;
                }
                const def = root.notification.actions.find(a => a.identifier === "default");
                if (def)
                    def.invoke();
                Notifs.dismissPopup(root.notification);
            }
        }
        Image {
            id: icon
            x: GoldenGate.px(12)
            y: GoldenGate.px(12)
            width: GoldenGate.px(38)
            height: width
            sourceSize: Qt.size(width * 2, height * 2)
            smooth: true
            source: {
                const i = root.notification ? String(Notifs.iconFor(root.notification) || "") : "";
                return !i ? Quickshell.iconPath("dialog-information", true) : i.startsWith("/") ? "file://" + i : i.includes("://") ? i : Quickshell.iconPath(i, true);
            }
        }
        // no icon from the app or the theme: a bell on a squircle
        Rectangle {
            visible: icon.status !== Image.Ready
            anchors.fill: icon
            radius: width * 0.24
            color: GoldenGate.accent
            MacIcon {
                anchors.centerIn: parent
                name: "bell"
                size: parent.width * 0.55
                stroke: 2
                color: "#ffffff"
            }
        }
        Column {
            id: col
            anchors.left: icon.right
            anchors.leftMargin: GoldenGate.px(10)
            anchors.right: parent.right
            anchors.rightMargin: GoldenGate.px(14)
            y: GoldenGate.px(11)
            spacing: GoldenGate.px(1)
            Row {
                width: parent.width
                MacText {
                    width: parent.width - when.implicitWidth
                    text: root.notification ? root.notification.summary : ""
                    semibold: true
                }
                MacText {
                    id: when
                    text: I18n.t("сейчас", "now")
                    size: GoldenGate.smallSize
                    color: GoldenGate.secondaryLabel
                }
            }
            MacText {
                width: parent.width
                visible: text !== ""
                text: root.notification ? String(root.notification.body || "").replace(/<[^>]*>/g, "") : ""
                wrapMode: Text.Wrap
                maximumLineCount: 3
            }
            Flow {
                width: parent.width
                spacing: GoldenGate.px(6)
                topPadding: GoldenGate.px(6)
                visible: !!root.notification && root.notification.actions.some(a => a.identifier !== "default")
                Repeater {
                    model: root.notification ? root.notification.actions.filter(a => a.identifier !== "default") : []
                    Rectangle {
                        id: act
                        required property var modelData
                        width: actText.implicitWidth + GoldenGate.px(20)
                        height: GoldenGate.px(24)
                        radius: height / 2
                        color: GoldenGate.controlBg
                        MacText {
                            id: actText
                            anchors.centerIn: parent
                            text: act.modelData.text
                            size: GoldenGate.smallSize + GoldenGate.px(1)
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                act.modelData.invoke();
                                Notifs.dismissPopup(root.notification);
                            }
                        }
                    }
                }
            }
        }
        // × on hover, in the corner as on a Mac
        Rectangle {
            visible: hover.hovered
            x: -GoldenGate.px(6)
            y: -GoldenGate.px(6)
            width: GoldenGate.px(20)
            height: width
            radius: width / 2
            color: GoldenGate.glass(0.4)
            border.width: 1
            border.color: GoldenGate.glassEdge
            MacIcon {
                anchors.centerIn: parent
                name: "x"
                size: GoldenGate.px(11)
                stroke: 2.4
            }
            MouseArea {
                anchors.fill: parent
                onClicked: Notifs.dismissPopup(root.notification)
            }
        }
    }
}
