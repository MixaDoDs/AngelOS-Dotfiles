pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config
import qs.services
import qs.widgets

PxWindow {
    id: root

    required property var notification
    readonly property bool critical: notification && notification.urgency === NotificationUrgency.Critical
    readonly property int timeout: critical ? 0 : (notification && notification.expireTimeout > 0 ? notification.expireTimeout : Config.notifications.timeout)
    property real remaining: 1

    title: notification ? (notification.appName || I18n.t("уведомление", "notification")) : ""
    icon: critical ? "warn" : "bell"
    compact: true
    decor: false
    implicitHeight: titleHeight + body.implicitHeight + Theme.pad * 2 + Theme.u * 8
    onCloseClicked: Notifs.close(notification)

    // pop in with a small overshoot
    scale: 0.85
    opacity: 0
    Component.onCompleted: {
        scale = 1;
        opacity = 1;
    }
    Behavior on scale {
        NumberAnimation {
            duration: Motion.ms(Theme.normal)
            easing.type: Easing.OutBack
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Motion.ms(Theme.fast)
        }
    }

    property real elapsed: 0
    // the time bar runs down every frame
    FrameAnimation {
        running: root.timeout > 0 && !hover.hovered && !root.replying
        onTriggered: {
            root.elapsed += Math.min(frameTime, 0.1) * 1000;
            root.remaining = Math.max(0, 1 - root.elapsed / root.timeout);
            if (root.remaining <= 0)
                Notifs.dismissPopup(root.notification);
        }
    }

    HoverHandler {
        id: hover
    }

    readonly property bool replying: Notifs.same(Notifs.replyTo, notification)
    // the app's own buttons (Telegram's "Mark as read"); "default" is a click on the card and
    // "Open" here, the reply is "Reply"
    readonly property var buttons: notification ? notification.actions.filter(a => a.identifier !== "default" && a.identifier !== "inline-reply") : []
    readonly property bool canReply: !!notification && notification.hasInlineReply
    readonly property bool canOpen: Notifs.canOpen(notification)

    Column {
        id: body
        width: parent.width
        spacing: Theme.u * 3

        Row {
            width: parent.width
            spacing: Theme.u * 4

            Item {
                id: iconBox
                readonly property string img: Notifs.iconFor(root.notification)
                visible: img !== ""
                width: Theme.u * 24
                height: width
                PxBox {
                    anchors.fill: parent
                    sunken: true
                    color: Theme.sunken
                    Image {
                        id: iconImage
                        anchors.fill: parent
                        source: iconBox.img
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(width * 2, height * 2)
                        asynchronous: true
                        visible: status !== Image.Error
                    }
                    // a name the icon theme can't draw (Qt doesn't follow every inherited
                    // theme GTK does): a bell, not the pink-and-black checkerboard (#47)
                    PxIcon {
                        visible: iconImage.status === Image.Error
                        anchors.centerIn: parent
                        name: "bell"
                    }
                }
            }

            Column {
                width: parent.width - (iconBox.visible ? iconBox.width + Theme.u * 4 : 0)
                spacing: Theme.u * 2
                PxText {
                    width: parent.width
                    text: root.notification ? root.notification.summary : ""
                    font.bold: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: root.critical ? Theme.danger : Theme.text
                }
                PxText {
                    width: parent.width
                    visible: text !== ""
                    text: root.notification ? Notifs.safeMarkup(root.notification.body) : ""
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: 5
                    elide: Text.ElideRight
                    linkColor: Theme.accent2
                    onLinkActivated: l => Notifs.openLink(l)
                }
            }
        }

        Flow {
            width: parent.width
            spacing: Theme.u * 3
            visible: !root.replying && (root.canReply || root.canOpen || root.buttons.length > 0)
            PxButton {
                visible: root.canReply
                compact: true
                text: I18n.t("Ответить", "Reply")
                onClicked: {
                    Notifs.replyTo = root.notification;
                    Qt.callLater(() => replyField.focusField());
                }
            }
            Repeater {
                model: root.buttons
                PxButton {
                    required property var modelData
                    compact: true
                    text: modelData.text || modelData.identifier
                    onClicked: {
                        modelData.invoke();
                        Notifs.dismissPopup(root.notification);
                    }
                }
            }
            PxButton {
                visible: root.canOpen
                compact: true
                text: I18n.t("Открыть", "Open")
                onClicked: Notifs.open(root.notification)
            }
        }

        // the reply, typed right here: Enter sends it, Esc puts the field away
        Row {
            visible: root.replying
            width: parent.width
            spacing: Theme.u * 3
            PxField {
                id: replyField
                width: parent.width - send.width - Theme.u * 3
                anchors.verticalCenter: parent.verticalCenter
                placeholder: Notifs.replyHint(root.notification) || I18n.t("Ответ… (Enter — отправить)", "Reply… (Enter sends)")
                keepFocus: true
                onAccepted: Notifs.reply(root.notification, text)
                onKeyPressed: e => {
                    if (e.key === Qt.Key_Escape) {
                        Notifs.replyTo = null;
                        e.accepted = true;
                    }
                }
            }
            PxButton {
                id: send
                compact: true
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("Отправить", "Send")
                enabled: replyField.text.trim() !== ""
                onClicked: Notifs.reply(root.notification, replyField.text)
            }
        }

        // timeout: draining pink bar
        PxBox {
            visible: root.timeout > 0
            width: parent.width
            height: Theme.u * 4
            sunken: true
            color: Theme.sunken
            Rectangle {
                height: parent.height - Theme.u * 2
                width: (parent.width - Theme.u * 2) * root.remaining
                color: Theme.accent
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.topMargin: root.titleHeight + Theme.u * 4
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.RightButton) {
                Notifs.close(root.notification);
                return;
            }
            if (root.replying)
                return;
            Notifs.open(root.notification);
        }
    }
}
