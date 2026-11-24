pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services

// serp-skin: the screensaver in Serpantinum's look (modules/idle/IdleScreen loads it while the skin
// is on, in place of the ASCII art and the AOD face). A calm clock and the date on the frosted
// wallpaper, what is playing under them; `aod` (the other screens, Config.idle.aod): black, dim,
// the music and the unread count as Settings → Idle asks. Nothing here takes input: the
// screensaver's window still ends on any key, click or move. The whole face steps a few pixels
// every minute so nothing stays lit in one place.
Item {
    id: root

    property string screenName: ""
    property bool aod: false

    readonly property string lang: Config.appearance.language === "en" ? "en_US" : "ru_RU"
    readonly property real big: Math.max(Serp.px(64), Math.round(Math.min(width, height) * (aod ? 0.13 : 0.17)))
    readonly property color ink: aod ? Qt.alpha(Serp.text, 0.55) : Serp.text
    readonly property bool music: Lyrics.title !== "" && (!aod || Config.idle.aodMusic)
    readonly property int unread: Notifs.history.filter(h => !h.read).length

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
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

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        visible: root.aod
    }
    SerpLockWall {
        anchors.fill: parent
        visible: !root.aod
        screenName: root.aod ? "" : root.screenName
        now: clock.date
        blur: 0.55
        dim: 0.5
    }

    Column {
        id: face
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.walk[root.step][0] * Serp.px(6)
        anchors.verticalCenterOffset: root.walk[root.step][1] * Serp.px(6)
        spacing: Serp.px(6)
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.ms(900)
                easing.type: Easing.OutCubic
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            SText {
                text: Qt.formatTime(clock.date, "HH")
                size: root.big
                black: true
                color: root.ink
                elide: Text.ElideNone
            }
            SText {
                text: ":"
                size: root.big
                black: true
                color: root.aod ? Qt.alpha(Serp.accent, 0.6) : Serp.accent
                elide: Text.ElideNone
            }
            SText {
                text: Qt.formatTime(clock.date, "mm")
                size: root.big
                black: true
                color: root.ink
                elide: Text.ElideNone
            }
        }
        SText {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property string d: Qt.locale(root.lang).toString(clock.date, "dddd, d MMMM")
            text: d.charAt(0).toUpperCase() + d.slice(1)
            size: Serp.px(root.aod ? 16 : 20)
            bold: true
            color: root.aod ? Qt.alpha(Serp.subtext1, 0.6) : Serp.subtext1
            elide: Text.ElideNone
        }
        Item {
            width: 1
            height: Serp.px(28)
        }

        // what is playing: a quiet card
        Rectangle {
            visible: root.music
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(nowRow.implicitWidth + Serp.px(24), root.width * 0.6)
            height: Serp.px(60)
            radius: Serp.radius + Serp.px(4)
            color: root.aod ? "transparent" : Qt.alpha(Serp.base, 0.5)
            border.width: root.aod ? 0 : 1
            border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
            opacity: root.aod ? 0.6 : 1
            Row {
                id: nowRow
                anchors.left: parent.left
                anchors.leftMargin: Serp.px(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Serp.px(12)
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Serp.px(42)
                    height: width
                    Rectangle {
                        anchors.fill: parent
                        radius: Serp.radiusSmall
                        color: Qt.alpha(Serp.accent, 0.22)
                    }
                    SerpLockRound {
                        id: art
                        anchors.fill: parent
                        radius: Serp.radiusSmall
                        source: Lyrics.artUrl || ""
                        sourceWidth: 128
                    }
                    SIcon {
                        visible: !art.ready
                        anchors.centerIn: parent
                        name: "music"
                        size: Serp.px(18)
                        color: Serp.accent
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Serp.px(2)
                    SText {
                        width: Math.min(implicitWidth, root.width * 0.6 - Serp.px(110))
                        text: Lyrics.title
                        bold: true
                        color: root.ink
                    }
                    SText {
                        visible: text !== ""
                        width: Math.min(implicitWidth, root.width * 0.6 - Serp.px(110))
                        text: Lyrics.artist
                        size: Serp.smallSize
                        dim: true
                    }
                }
                SIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Lyrics.playing ? "volume-2" : "pause"
                    size: Serp.px(15)
                    color: Serp.subtext1
                }
            }
        }

        // AOD: the notifications not read, a count
        SerpLockChip {
            visible: root.aod && Config.idle.aodNotifications && root.unread > 0
            anchors.horizontalCenter: parent.horizontalCenter
            icon: "bell"
            text: String(root.unread)
            ink: root.ink
            fill: "transparent"
        }
    }

    SText {
        visible: !root.aod
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Serp.px(28)
        text: I18n.t("любая клавиша или мышь — вернуться", "press any key or move the mouse")
        size: Serp.smallSize
        dim: true
        opacity: 0.6
        elide: Text.ElideNone
    }
}
