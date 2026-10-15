pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.lock

// Always On Display (Config.idle.aod): what the screensaver shows on the screens that are not
// the main one — like a phone's black screen with the time on it. Big pixel clock, the date,
// what is playing, the notifications not read yet, the devices' charge as ampoules, and the
// angel (or the demon) asleep. Dim, nothing moves but the colon; the whole face steps a few
// pixels every minute so nothing stays lit in one place.
Item {
    id: root

    readonly property int u: Theme.u
    readonly property color ink: Theme.mix(Qt.color("#000000"), Theme.text, 0.62)
    readonly property color glow: Theme.mix(Qt.color("#000000"), Theme.accent, 0.7)
    readonly property var player: Lyrics.player
    readonly property bool playing: !!player && player.isPlaying && (player.trackTitle || "") !== ""
    readonly property var unread: Notifs.history.filter(h => !h.read)
    readonly property var apps: {
        const seen = [];
        for (const h of unread) {
            const k = h.appName || "?";
            if (!seen.includes(k))
                seen.push(k);
        }
        return seen.slice(0, 6);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
    // the burn-in walk: a new spot every minute, never far from the middle
    property int step: 0
    readonly property var walk: [[0, 0], [1, -1], [2, 0], [1, 1], [0, 2], [-1, 1], [-2, 0], [-1, -1], [0, -2]]
    Timer {
        interval: 60000
        running: root.visible
        repeat: true
        onTriggered: root.step = (root.step + 1) % root.walk.length
    }

    Column {
        id: face
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.walk[root.step][0] * root.u * 4
        anchors.verticalCenterOffset: root.walk[root.step][1] * root.u * 4
        spacing: root.u * 6

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0
            PxText {
                text: Qt.formatTime(clock.date, "HH")
                kind: "huge"
                font.pixelSize: Math.round(Math.min(root.width, root.height) * 0.16 / root.u) * root.u
                color: root.ink
            }
            PxText {
                text: ":"
                kind: "huge"
                font.pixelSize: Math.round(Math.min(root.width, root.height) * 0.16 / root.u) * root.u
                color: root.glow
                opacity: clock.date.getSeconds() % 2 ? 0.25 : 1
            }
            PxText {
                text: Qt.formatTime(clock.date, "mm")
                kind: "huge"
                font.pixelSize: Math.round(Math.min(root.width, root.height) * 0.16 / root.u) * root.u
                color: root.ink
            }
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale(Config.appearance.language === "en" ? "en_US" : "ru_RU").toString(clock.date, "dddd, d MMMM")
            kind: "title"
            color: Theme.mix(Qt.color("#000000"), Theme.textDim, 0.7)
        }

        // what is playing
        Row {
            visible: root.playing && Config.idle.aodMusic
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.u * 3
            PxIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "music"
                pixel: root.u
                ink: root.ink
                fill: root.glow
                fill2: root.glow
            }
            PxText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.width * 0.6)
                elide: Text.ElideRight
                text: root.playing ? (root.player.trackArtist ? root.player.trackArtist + " — " : "") + root.player.trackTitle : ""
                color: root.ink
            }
        }

        // the notifications not read: the apps' icons and how many
        Row {
            visible: root.unread.length > 0 && Config.idle.aodNotifications
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.u * 3
            Repeater {
                model: root.apps
                Image {
                    required property string modelData
                    readonly property var entry: root.unread.find(h => (h.appName || "?") === modelData)
                    width: root.u * 8
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    sourceSize: Qt.size(width, height)
                    source: entry ? entry.icon || "" : ""
                    opacity: 0.7
                    smooth: false
                }
            }
            PxText {
                anchors.verticalCenter: parent.verticalCenter
                text: "· " + root.unread.length
                color: root.ink
            }
        }

        // the devices' charge
        PxAmpouleRack {
            visible: Config.idle.aodDevices && Peripherals.onBar.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            devices: Peripherals.onBar
            pixel: root.u
            opacity: 0.7
        }
    }

    // she sleeps in the corner
    LockAngel {
        visible: Config.idle.aodAngel
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.u * 10 + root.walk[root.step][0] * root.u * 2
        anchors.bottomMargin: root.u * 10
        px: Math.max(1, Math.round(Math.min(root.width, root.height) * 0.12 / 120))
        mood: "sleep"
        opacity: 0.55
        // what she listens to at the lock; here nobody types
        lockScope: QtObject {
            property bool unlocking: false
            property int fails: 0
            signal shake
            signal success
            signal typed(int length, bool added)
        }
    }
}
