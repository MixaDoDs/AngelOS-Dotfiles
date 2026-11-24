pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.config
import qs.services
import qs.modules.serp
import "."
import qs.modules.serp.panels
import qs.modules.desktop

// serp-skin: angelOS's Music widget (modules/desktop/widgets/MusicWidget + MusicPlayer +
// MusicSpectrum) in Serpantinum's face (its MusicFace / Visualizer / WavySeekBar), same sizes:
//   S  the spectrum alone: mirrored round bars in the accent (nothing to click)
//   M  the player: a rounded cover, the title Bold, the artist, a wavy seek line with the
//      times, round prev / play / next (play bigger, in the accent)
//   L  bigger: a spinning disc with the cover in its middle, and the spectrum under it all
// The data is the original's: services/Lyrics (the now-playing hub) and angelOS's MusicSpectrum
// (one shared cava, honouring widget.settings.bars / .source), here invisible and only read.
// Nothing moves while nobody can see it: the position timer, the wave and the disc run only while
// this copy is on show and the music plays.
Item {
    id: root

    property string screenName
    property var widget
    property string size: "m"
    property string frameKind: "window"
    property bool face: true

    readonly property bool hasSpectrum: size !== "m"
    readonly property bool hasPlayer: size !== "s"
    // S is the spectrum alone: nothing to click, the input copy stays empty
    readonly property bool passive: !hasPlayer
    readonly property var st: widget && widget.settings ? widget.settings : ({})
    readonly property bool big: size === "l"

    readonly property int gap: Serp.px(12)
    readonly property int playerW: Serp.px(big ? 400 : 340)
    readonly property int playerH: Serp.px(big ? 136 : 104)
    readonly property int specH: Serp.px(hasPlayer ? 48 : 88)
    implicitWidth: hasPlayer ? playerW : Serp.px(260)
    implicitHeight: hasPlayer ? playerH + (hasSpectrum ? specH + gap : 0) : specH

    // ---- on show? (the input copy lies over its face only while hovered) ----
    property Item hostItem: null
    function findHost() {
        let p = parent;
        while (p) {
            if (p.faceTwin !== undefined && p.wantContent !== undefined) {
                hostItem = p;
                return;
            }
            p = p.parent;
        }
        hostItem = null;
    }
    Component.onCompleted: {
        findHost();
        Serp.mediaUsers++;
    }
    onParentChanged: findHost()
    // the hover copy over its face (the host's overFace): only what lies on top is drawn here —
    // the buttons; the disc, the wave and the bars are the face's below
    readonly property bool overFace: !face && !!hostItem && hostItem.overFace === true
    readonly property bool seen: visible && !Shell.hiddenScreen(screenName) && (face || !hostItem || !!hostItem.shown)
    readonly property bool still: Shell.stillScreen(screenName) || Power.eco

    // ---- the track ----
    readonly property var player: Lyrics.player
    readonly property bool hasTrack: !!player && Lyrics.title !== ""
    readonly property bool playing: !!player && player.isPlaying
    readonly property real len: Lyrics.length
    property real pos: 0
    // what the bar and the time show: the skin's one clock of the track (Serp.mediaNow, ms), the same
    // in the face and in its hover copy — each reading the player on its own put the bar in two places
    readonly property real livePos: Serp.mediaNow / 1000
    // the disc turns by the skin's one clock of the playing track (Serp.mediaNow): the face and its
    // hover copy show the same angle, and it never turns back
    Component.onDestruction: Serp.mediaUsers--
    function readPos() {
        if (!player) {
            pos = 0;
            return;
        }
        player.positionChanged();
        pos = player.position;
    }
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.hasPlayer && root.seen && root.playing
        onTriggered: root.readPos()
    }
    onPlayerChanged: readPos()
    onSeenChanged: if (seen && hasPlayer)
        readPos()
    Connections {
        target: Lyrics
        function onTitleChanged() {
            root.readPos();
        }
    }
    function clock(s) {
        if (!(s > 0) || !isFinite(s))
            return "0:00";
        s = Math.floor(s);
        const h = Math.floor(s / 3600), mm = Math.floor(s % 3600 / 60), ss = s % 60;
        return (h > 0 ? h + ":" + (mm < 10 ? "0" : "") : "") + mm + ":" + (ss < 10 ? "0" : "") + ss;
    }
    function seekTo(sec) {
        const p = player;
        if (!p || !p.canSeek)
            return;
        p.position = Math.max(0, sec);
        p.positionChanged();
        pos = p.position;
        Serp.mediaRead(true);
        Lyrics.updateIndex();
    }

    // ---- the spectrum's data: angelOS's own, unseen ----
    MusicSpectrum {
        id: spec
        width: 1
        height: 1
        opacity: 0
        visible: root.hasSpectrum
        screenName: root.screenName
        widget: root.widget
        face: root.face
        rows: 1
        mac: false
    }

    // ================= S, and L's strip: the spectrum =================
    Item {
        id: bars
        opacity: root.overFace ? 0 : 1
        // the input copy (over the face while hovered) has no cava of its own: the face's bars show
        visible: root.hasSpectrum && root.face
        y: root.hasPlayer ? root.playerH + root.gap : 0
        width: root.width
        height: root.specH
        readonly property int n: spec.bars
        readonly property real gapX: Serp.px(n > 40 ? 3 : 4)
        readonly property real barW: Math.max(Serp.px(2), (width - gapX * (n - 1)) / n)
        readonly property real half: (n - 1) / 2
        // a line under the bars, as Serpantinum's quiet floor
        Rectangle {
            visible: root.hasPlayer
            anchors.top: parent.top
            anchors.topMargin: -root.gap / 2
            width: parent.width
            height: 1
            color: Serp.line
        }
        Repeater {
            model: bars.visible && !spec.missing ? bars.n : 0
            Rectangle {
                id: bar
                required property int index
                // the low notes in the middle, mirrored to both sides
                readonly property int src: Math.round(Math.abs(index - bars.half) / Math.max(0.5, bars.half) * (bars.n - 1))
                readonly property real lv: Math.min(1, spec.levels[src] || 0)
                // the ends fade a little (Serpantinum's edgeFade)
                readonly property real edge: Math.min(1, Math.sin((index + 0.5) / bars.n * Math.PI) * 2)
                x: index * (bar.width + bars.gapX)
                anchors.bottom: parent.bottom
                width: bars.barW
                height: Math.max(width, lv * bars.height * 0.96)
                radius: Math.min(width / 2, Serp.px(3))
                antialiasing: true
                color: Serp.accent
                opacity: (0.3 + 0.7 * lv) * (0.45 + 0.55 * edge)
            }
        }
        SText {
            visible: spec.missing
            anchors.centerIn: parent
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            text: I18n.t("Нужен cava: sudo pacman -S cava", "Needs cava: sudo pacman -S cava")
            size: Serp.smallSize
            dim: true
        }
    }

    // ================= M, L: the player =================
    Item {
        id: playerBox
        visible: root.hasPlayer
        width: root.width
        height: root.playerH

        // nothing plays
        Row {
            visible: !root.hasTrack
            anchors.centerIn: parent
            spacing: Serp.px(10)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Serp.px(root.big ? 44 : 36)
                height: width
                radius: Serp.radiusSmall
                color: Serp.surface0
                SIcon {
                    anchors.centerIn: parent
                    name: "music"
                    size: parent.width * 0.45
                    color: Serp.subtext0
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Serp.px(2)
                SText {
                    text: I18n.t("Ничего не играет", "Nothing is playing")
                    size: Serp.px(root.big ? 15 : 14)
                    bold: true
                }
                SText {
                    text: I18n.t("Включи музыку, и она появится здесь", "Play something and it shows up here")
                    size: Serp.smallSize
                    dim: true
                }
            }
        }

        // the song
        Item {
            visible: root.hasTrack
            anchors.fill: parent

            // M: the cover, a rounded square
            Item {
                id: square
                visible: !root.big
                width: parent.height
                height: width
                Rectangle {
                    anchors.fill: parent
                    radius: Serp.radius
                    color: Serp.surface1
                    SIcon {
                        anchors.centerIn: parent
                        visible: squareArt.status !== Image.Ready
                        name: "music"
                        size: parent.width * 0.35
                        color: Serp.subtext0
                    }
                }
                Image {
                    id: squareArt
                    anchors.fill: parent
                    visible: false
                    source: square.visible && root.hasTrack ? Lyrics.artUrl : ""
                    sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }
                Rectangle {
                    id: squareMask
                    anchors.fill: parent
                    radius: Serp.radius
                    visible: false
                    layer.enabled: true
                    antialiasing: true
                }
                MultiEffect {
                    anchors.fill: parent
                    visible: squareArt.status === Image.Ready
                    source: squareArt
                    maskEnabled: true
                    maskSource: squareMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }
            }

            // L: the disc, the cover round in its middle; turns while it plays
            Item {
                id: disc
                opacity: root.overFace ? 0 : 1
                visible: root.big
                width: parent.height
                height: width
                scale: root.playing ? 1 : 0.92
                Behavior on scale {
                    NumberAnimation {
                        duration: Serp.slow
                        easing.type: Easing.OutQuint
                    }
                }
                // one turn per 25 s of the track's time (both copies agree; paused, it stands)
                rotation: root.still ? 0 : (Serp.mediaNow / 25000 * 360) % 360
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Serp.surface1
                    border.width: Serp.px(1.5)
                    border.color: root.playing ? Serp.accent : Serp.surface2
                    Behavior on border.color {
                        ColorAnimation {
                            duration: Serp.normal
                        }
                    }
                }
                Repeater {
                    model: disc.visible ? [0.9, 0.8, 0.7] : []
                    Rectangle {
                        required property var modelData
                        required property int index
                        anchors.centerIn: parent
                        width: disc.width * modelData
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.alpha(Serp.text, index % 2 ? 0.03 : 0.06)
                    }
                }
                Item {
                    id: label
                    anchors.centerIn: parent
                    width: Math.round(disc.width * 0.6)
                    height: width
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Serp.surface2
                        SIcon {
                            anchors.centerIn: parent
                            visible: discArt.status !== Image.Ready
                            name: "music"
                            size: parent.width * 0.35
                            color: Serp.subtext0
                        }
                    }
                    Image {
                        id: discArt
                        anchors.fill: parent
                        visible: false
                        source: disc.visible && root.hasTrack ? Lyrics.artUrl : ""
                        sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        mipmap: true
                    }
                    Rectangle {
                        id: discMask
                        anchors.fill: parent
                        radius: width / 2
                        visible: false
                        layer.enabled: true
                        antialiasing: true
                    }
                    MultiEffect {
                        anchors.fill: parent
                        visible: discArt.status === Image.Ready
                        source: discArt
                        maskEnabled: true
                        maskSource: discMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: Serp.px(9)
                    height: width
                    radius: width / 2
                    color: Serp.ground
                    border.width: 1
                    border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
                }
            }

            // the words, the wave, the buttons
            Item {
                id: info
                x: parent.height + Serp.px(root.big ? 18 : 14)
                width: parent.width - x
                height: parent.height

                Column {
                    width: parent.width
                    spacing: Serp.px(2)
                    SText {
                        width: parent.width
                        text: Lyrics.title
                        size: Serp.px(root.big ? 17 : 15)
                        bold: true
                    }
                    SText {
                        width: parent.width
                        visible: text !== ""
                        text: Lyrics.artist
                        size: Serp.px(root.big ? 13 : 12)
                        color: Serp.subtext0
                    }
                }

                // time · wave · time
                Item {
                    id: seekRow
                    anchors.bottom: controls.top
                    anchors.bottomMargin: Serp.px(root.big ? 6 : 2)
                    width: parent.width
                    height: Serp.px(22)
                    SText {
                        id: tNow
                        anchors.verticalCenter: parent.verticalCenter
                        width: tEnd.width
                        horizontalAlignment: Text.AlignLeft
                        text: root.clock(wave.dragging ? wave.dragValue * root.len : root.livePos)
                        size: Serp.px(10.5)
                        bold: true
                        color: Serp.subtext0
                    }
                    SerpWaveBar {
                        id: wave
                        anchors.left: tNow.right
                        anchors.right: tEnd.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        amplitude: Serp.px(3.5)
                        stroke: Serp.px(3)
                        value: root.len > 0 ? Math.min(1, root.livePos / root.len) : 0
                        playing: root.playing && !root.still
                        active: root.hasTrack && root.seen && !root.still
                        seekable: !!root.player && root.player.canSeek && root.len > 0
                        ghost: root.overFace
                        onSeek: f => root.seekTo(f * root.len)
                    }
                    SText {
                        id: tEnd
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(implicitWidth, Serp.px(30))
                        horizontalAlignment: Text.AlignRight
                        text: root.len > 0 ? root.clock(root.len) : "--:--"
                        size: Serp.px(10.5)
                        bold: true
                        color: Serp.subtext0
                    }
                }

                Row {
                    id: controls
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Serp.px(root.big ? 14 : 10)
                    Transport {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "skip-back"
                        enabledHere: !!root.player && root.player.canGoPrevious
                        onClicked: root.player.previous()
                    }
                    Transport {
                        anchors.verticalCenter: parent.verticalCenter
                        big: true
                        icon: root.playing ? "pause" : "play"
                        enabledHere: !!root.player && root.player.canTogglePlaying
                        onClicked: root.player.togglePlaying()
                    }
                    Transport {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "skip-forward"
                        enabledHere: !!root.player && root.player.canGoNext
                        onClicked: root.player.next()
                    }
                }
            }
        }
    }

    // a round button: surface0 with a hair of a line; the big one is the accent
    component Transport: Item {
        id: tb
        property string icon: ""
        property bool big: false
        property bool enabledHere: true
        signal clicked
        width: Serp.px(big ? (root.big ? 40 : 34) : (root.big ? 32 : 28))
        height: width
        opacity: enabledHere ? 1 : 0.4
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: tb.big ? (tbMa.containsMouse ? Qt.lighter(Serp.accent, 1.1) : Serp.accent) : tbMa.containsMouse ? Serp.surface1 : Serp.surface0
            border.width: tb.big ? 0 : 1
            border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
            scale: tbMa.pressed ? 0.94 : 1
            Behavior on color {
                ColorAnimation {
                    duration: Serp.quick
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Serp.quick
                    easing.type: Easing.OutCubic
                }
            }
            SIcon {
                anchors.centerIn: parent
                name: tb.icon
                size: tb.width * (tb.big ? 0.44 : 0.46)
                filled: true
                color: tb.big ? Serp.onAccent : tbMa.containsMouse ? Serp.accent : Serp.text
            }
        }
        MouseArea {
            id: tbMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: tb.enabledHere
            cursorShape: Qt.PointingHandCursor
            onClicked: tb.clicked()
        }
    }
}
