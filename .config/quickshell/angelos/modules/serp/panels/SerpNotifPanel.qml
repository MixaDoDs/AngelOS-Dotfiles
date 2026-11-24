pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.modules.serp

// serp-skin: the notification centre (left edge, full height): every notification kept, newest
// first, swipe to remove; Do not disturb and Clear on top
Item {
    id: root
    property string screenName: ""
    property real progress: 1

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Serp.radius * 1.4, 24)
        color: Serp.ground
        border.width: 1
        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
    }
    MouseArea {
        anchors.fill: parent
    }
    Component.onCompleted: Notifs.markRead()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Serp.px(12)
        spacing: Serp.px(10)
        RowLayout {
            Layout.fillWidth: true
            spacing: Serp.px(8)
            SText {
                Layout.fillWidth: true
                text: "Уведомления"
                size: Serp.px(17)
                black: true
            }
            SText {
                text: "Не беспокоить"
                size: Serp.px(11)
                dim: true
            }
            SToggle {
                checked: Config.notifications.dnd
                onToggled: on => Config.notifications.dnd = on
            }
            SButton {
                visible: Notifs.history.length > 0
                SIcon {
                    name: "trash-2"
                }
                onClicked: Serp.clearNotifs()  // the cards fly off first
            }
        }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Serp.px(8)
            model: Notifs.history
            delegate: SerpNotifCard {
                width: list.width
            }
            add: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Serp.normal
                }
            }
            displaced: Transition {
                NumberAnimation {
                    property: "y"
                    duration: Serp.normal
                    easing.type: Easing.OutCubic
                }
            }
        }
        SText {
            visible: Notifs.history.length === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Serp.px(40)
            text: "Тишина. Ангел доволен."
            size: Serp.px(13)
            dim: true
        }
    }
}
