pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell
import qs.config
import qs.services
import qs.widgets

// One screen of the lock: the look picked in Settings → Lock (NGO stream or heaven's gate).
// When the password is right, Lock.qml asks every screen for a picture of itself
// (captureNow): the unlock overlay plays it away over the desktop (UnlockReveal).
Item {
    id: root

    required property string screenName
    required property bool primary
    required property var lockScope
    property bool preview: false

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Loader {
        id: look
        anchors.fill: parent
        sourceComponent: root.lockScope.look === "heaven" ? heaven : ngo
    }
    Component {
        id: ngo
        NgoLock {
            screenName: root.screenName
            primary: root.primary
            lockScope: root.lockScope
            now: clock.date
            preview: root.preview
        }
    }
    Component {
        id: heaven
        HeavenLock {
            screenName: root.screenName
            primary: root.primary
            lockScope: root.lockScope
            now: clock.date
            preview: root.preview
        }
    }

    // a screen without the password box: what is typed here goes to the box on the main
    // screen, and a plate says where it is
    Item {
        id: relay
        anchors.fill: parent
        visible: !root.primary
        focus: !root.primary
        Keys.onPressed: e => {
            root.lockScope.relayKey(e.text, e.key);
            e.accepted = true;
        }
        Timer {
            // the look grabs the focus for its own (hidden) field when it is built
            running: relay.visible
            interval: 300
            onTriggered: relay.forceActiveFocus()
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            propagateComposedEvents: true
            onPressed: e => {
                relay.forceActiveFocus();
                e.accepted = false;
            }
        }
        readonly property var here: Quickshell.screens.find(s => s.name === root.screenName) || null
        readonly property var main: Quickshell.screens.find(s => s.name === (root.preview ? root.lockScope.shownMain : root.lockScope.lockMain)) || null
        readonly property string arrow: !here || !main ? "" : main.x + main.width <= here.x ? "←  " : main.x >= here.x + here.width ? "  →" : main.y + main.height <= here.y ? "↑  " : "  ↓"
        PxBox {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.u * 24
            width: hint.implicitWidth + Theme.u * 12
            height: hint.implicitHeight + Theme.u * 8
            color: Theme.face
            edgeColor: Theme.accent
            PxText {
                id: hint
                anchors.centerIn: parent
                text: (relay.arrow.startsWith("←") || relay.arrow.startsWith("↑") ? relay.arrow : "") + I18n.t("Пароль — на главном экране. Можно печатать и здесь", "The password is on the main screen. You can type here too") + (relay.arrow.startsWith(" ") ? relay.arrow : "")
            }
        }
    }

    Connections {
        target: root.lockScope
        function onCaptureNow() {
            const o = look.item && root.primary ? look.item.fxOrigin : Qt.point(0.5, 0.5);
            const dpr = Math.max(1, Screen.devicePixelRatio);
            // the grab result is handed over whole: its url lives only as long as it does
            const ok = root.grabToImage(r => root.lockScope.captured(root.screenName, r, o), Qt.size(Math.ceil(root.width * dpr), Math.ceil(root.height * dpr)));
            if (!ok)
                root.lockScope.captured(root.screenName, null, o);
        }
    }
}
