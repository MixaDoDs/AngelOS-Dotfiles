import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.services
import qs.modules.serp

// serp-skin: one notification from the history (Notifs.history entry), Serpantinum's card — the
// icon in a surface2 box, the app small, the summary bold, the body; swipe sideways (or ×) to
// remove; critical ones glow red at the edge
Rectangle {
    id: card
    required property var modelData
    required property int index
    // «clear all» (Serp.clearNotifs): off to the right like a swipe, one after another from the top
    property bool leaving: false
    Connections {
        target: Serp
        function onNotifsClearingChanged() {
            if (Serp.notifsClearing)
                leave.restart();
        }
    }
    SequentialAnimation {
        id: leave
        PauseAnimation {
            duration: Math.min(card.index, 8) * 35
        }
        ScriptAction {
            script: card.leaving = true
        }
        NumberAnimation {
            target: card
            property: "x"
            to: card.width * 1.15
            duration: 260
            easing.type: Easing.InCubic
        }
    }
    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
    implicitHeight: lay.implicitHeight + Serp.px(16)
    radius: Serp.radiusSmall
    color: ma.containsMouse ? Qt.lighter(Serp.surface1, 1.05) : Serp.surface1
    border.width: critical ? 1 : 0
    border.color: Qt.alpha(Serp.red, 0.6)
    x: drag.active ? x : 0
    opacity: 1 - Math.min(1, Math.abs(x) / width * 1.4)
    Behavior on x {
        enabled: !drag.active && !card.leaving
        NumberAnimation {
            duration: Serp.normal
            easing.type: Easing.OutCubic
        }
    }

    RowLayout {
        id: lay
        x: Serp.px(8)
        y: Serp.px(8)
        width: parent.width - Serp.px(16)
        spacing: Serp.px(8)
        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: Serp.px(36)
            Layout.preferredHeight: Serp.px(36)
            radius: Serp.px(9)
            color: Serp.surface2
            Image {
                anchors.fill: parent
                anchors.margins: Serp.px(5)
                source: card.modelData.icon || ""
                sourceSize: Qt.size(64, 64)
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
            }
            SIcon {
                anchors.centerIn: parent
                visible: !card.modelData.icon
                name: "bell"
                size: Serp.px(16)
            }
        }
        Column {
            Layout.fillWidth: true
            spacing: Serp.px(2)
            RowLayout {
                width: parent.width
                SText {
                    Layout.fillWidth: true
                    text: card.modelData.appName || "angelOS"
                    size: Serp.px(10)
                    dim: true
                }
                SText {
                    text: Qt.formatTime(new Date(card.modelData.time), "HH:mm")
                    size: Serp.px(10)
                    dim: true
                }
            }
            SText {
                width: parent.width
                text: card.modelData.summary
                size: Serp.px(12.5)
                bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
            SText {
                visible: text !== ""
                width: parent.width
                text: card.modelData.body
                textFormat: Text.StyledText
                size: Serp.px(11)
                dim: true
                wrapMode: Text.Wrap
                maximumLineCount: 3
            }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        drag.target: card
        drag.axis: Drag.XAxis
        onReleased: {
            if (Math.abs(card.x) > card.width * 0.18)
                Notifs.removeHistory(card.modelData.hid);
            else
                card.x = 0;
        }
    }
    readonly property alias drag: ma.drag
    SButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Serp.px(4)
        implicitWidth: Serp.px(20)
        implicitHeight: Serp.px(20)
        visible: ma.containsMouse || hovered
        SIcon {
            name: "x"
            size: Serp.px(12)
        }
        onClicked: Notifs.removeHistory(card.modelData.hid)
    }
}
