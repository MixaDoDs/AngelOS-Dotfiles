pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell
import qs.config
import qs.services

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
