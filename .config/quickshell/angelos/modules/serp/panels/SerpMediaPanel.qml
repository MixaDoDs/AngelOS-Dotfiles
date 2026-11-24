pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.config
import qs.services
import qs.modules.serp
import qs.modules.desktop

// serp-skin: Serpantinum's music popup (its MusicPopup / MusicCover / MusicTrackControls) as a
// panel's content: the cover blurred behind the card, a spinning vinyl with the cover in its middle
// and the song's spectrum around it, the title, the source, a wavy seek bar and the buttons, and the
// synced lyrics under them. Everything comes from angelOS's Lyrics (the now-playing hub); the
// spectrum is angelOS's MusicSpectrum (one shared cava), running only while the panel is shown.
Item {
    id: root
    property string screenName
    property real progress: 1

    implicitWidth: Serp.px(625)
    implicitHeight: Serp.px(565)

    readonly property bool shown: visible && progress > 0.01
    readonly property var player: Lyrics.player
    readonly property bool hasTrack: !!player && Lyrics.title !== ""
    readonly property bool playing: Lyrics.playing
    readonly property int m: Serp.px(18)

    // the staggered intro: part d starts at progress d and lands at 1
    function st(d) {
        return Math.max(0, Math.min(1, (progress - d) / Math.max(0.01, 1 - d)));
    }

    // ---- the live position: read from the player while the panel is shown ----
    property real pos: 0
    function readPos() {
        if (!player) {
            pos = 0;
            return;
        }
        player.positionChanged();
        pos = player.position;
    }
    Timer {
        interval: 500
        repeat: true
        triggeredOnStart: true
        running: root.shown && root.hasTrack
        onTriggered: root.readPos()
    }
    onPlayerChanged: readPos()
    readonly property real len: Lyrics.length
    function clock(s) {
        if (!(s > 0))
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
        Lyrics.updateIndex();
    }
    function playerName(p) {
        const n = p ? p.identity || p.desktopEntry || "" : "";
        return n.charAt(0).toUpperCase() + n.slice(1);
    }
    readonly property var playerList: Lyrics.players.filter(p => !!p.trackTitle)

    // ---- the card: the cover blurred under the ground ----
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: Serp.radius
        visible: false
        layer.enabled: true
    }
    Item {
        id: art
        anchors.fill: parent
        visible: false
        // on for as long as the panel exists: switched off at closing, the blur below kept a stale
        // picture over everything (the cover stuck on screen, 2026-11-13)
        layer.enabled: true
        property bool useA: true
        property string want: Lyrics.artUrl
        onWantChanged: {
            if (useA)
                artB.source = want;
            else
                artA.source = want;
        }
        Component.onCompleted: artA.source = want
        Image {
            id: artA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 256
            sourceSize.height: 256
            opacity: art.useA && status === Image.Ready ? 1 : 0
            onStatusChanged: if (status === Image.Ready && source == art.want)
                art.useA = true
            Behavior on opacity {
                NumberAnimation {
                    duration: 700
                    easing.type: Easing.OutCubic
                }
            }
        }
        Image {
            id: artB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 256
            sourceSize.height: 256
            opacity: !art.useA && status === Image.Ready ? 1 : 0
            onStatusChanged: if (status === Image.Ready && source == art.want)
                art.useA = false
            Behavior on opacity {
                NumberAnimation {
                    duration: 700
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: Serp.radius
        color: Serp.base
    }
    MultiEffect {
        anchors.fill: parent
        source: art
        visible: root.hasTrack && Lyrics.artUrl !== "" && root.shown
        opacity: root.st(0)
        blurEnabled: true
        blur: 1
        blurMax: 64
        saturation: 0.2
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
    Rectangle {
        anchors.fill: parent
        radius: Serp.radius
        color: Qt.alpha(Serp.base, 0.85)
        border.width: 1
        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
    }

    // ---- nothing plays ----
    Column {
        anchors.centerIn: parent
        spacing: Serp.px(12)
        visible: !root.hasTrack
        opacity: root.st(0.1)
        SIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "music"
            size: Serp.px(44)
            color: Serp.overlay
        }
        SText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Ничего не играет"
            size: Serp.px(16)
            bold: true
        }
        SText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Включи музыку, и она появится здесь"
            size: Serp.px(12)
            dim: true
        }
    }

    // ---- the song ----
    Item {
        id: body
        anchors.fill: parent
        anchors.margins: root.m
        visible: root.hasTrack

        Row {
            id: top
            width: parent.width
            height: Serp.px(224)
            spacing: Serp.px(16)

            // the vinyl, the cover in its middle, the spectrum around it
            Item {
                id: disc
                width: Serp.px(224)
                height: width
                opacity: root.st(0)
                scale: 0.85 + 0.15 * root.st(0)

                readonly property real vinyl: width - Serp.px(44)

                MusicSpectrum {
                    id: spec
                    width: 1
                    height: 1
                    opacity: 0
                    visible: root.shown && root.hasTrack
                    screenName: root.screenName
                    widget: ({
                            "uid": "serp-media-" + root.screenName,
                            "settings": {
                                "bars": 24
                            }
                        })
                    face: true
                    rows: 1
                    mac: false
                }
                // 48 bars: the 24 levels mirrored, so the ring closes without a seam
                Repeater {
                    model: 48
                    Item {
                        id: rb
                        required property int index
                        readonly property real lv: {
                            const l = spec.levels;
                            const i = index < 24 ? index : 47 - index;
                            return root.playing && l && l.length > i ? Math.min(1, l[i] || 0) : 0;
                        }
                        anchors.centerIn: parent
                        width: Serp.px(3)
                        height: parent.width
                        rotation: index * 7.5
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            radius: width / 2
                            property real barLen: Serp.px(3) + rb.lv * Serp.px(17)
                            height: barLen
                            y: (rb.height - disc.vinyl) / 2 - Serp.px(3) - barLen
                            color: Serp.mauve
                            opacity: 0.4 + 0.6 * rb.lv
                            Behavior on barLen {
                                NumberAnimation {
                                    duration: 90
                                }
                            }
                        }
                    }
                }

                Item {
                    id: vinyl
                    anchors.centerIn: parent
                    width: disc.vinyl
                    height: width
                    scale: root.playing ? 1 : 0.9
                    Behavior on scale {
                        NumberAnimation {
                            duration: Serp.slow
                            easing.type: Easing.OutQuint
                        }
                    }
                    NumberAnimation on rotation {
                        running: root.shown && root.hasTrack
                        paused: running && !root.playing
                        from: 0
                        to: 360
                        duration: 25000
                        loops: Animation.Infinite
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Serp.surface1
                        border.width: Serp.px(1.5)
                        border.color: root.playing ? Serp.mauve : Serp.overlay
                        Behavior on border.color {
                            ColorAnimation {
                                duration: Serp.normal
                            }
                        }
                    }
                    Repeater {
                        model: [0.92, 0.84, 0.76, 0.68, 0.6, 0.52, 0.44]
                        Rectangle {
                            required property var modelData
                            required property int index
                            anchors.centerIn: parent
                            width: vinyl.width * modelData
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: 1
                            border.color: index % 2 ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.035)
                        }
                    }
                    // a gleam across the grooves
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Serp.px(4)
                        radius: width / 2
                        opacity: 0.06
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.2
                                color: "transparent"
                            }
                            GradientStop {
                                position: 0.5
                                color: "white"
                            }
                            GradientStop {
                                position: 0.8
                                color: "transparent"
                            }
                        }
                    }
                    // the cover, round
                    Item {
                        id: coverBox
                        anchors.centerIn: parent
                        width: Math.round(vinyl.width * 0.62)
                        height: width
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Serp.surface2
                            SIcon {
                                anchors.centerIn: parent
                                name: "music"
                                size: parent.width * 0.35
                                color: Serp.overlay
                                visible: cover.status !== Image.Ready
                            }
                        }
                        Image {
                            id: cover
                            anchors.fill: parent
                            visible: false
                            source: Lyrics.artUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 256
                            sourceSize.height: 256
                        }
                        Rectangle {
                            id: coverMask
                            anchors.fill: parent
                            radius: width / 2
                            visible: false
                            layer.enabled: true
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: cover
                            visible: cover.status === Image.Ready
                            maskEnabled: true
                            maskSource: coverMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.width: Serp.px(2)
                            border.color: Qt.rgba(0, 0, 0, 0.25)
                        }
                    }
                    // the label hole
                    Rectangle {
                        anchors.centerIn: parent
                        width: Serp.px(12)
                        height: width
                        radius: width / 2
                        color: Serp.crust
                        border.width: 1
                        border.color: Qt.alpha(Serp.text, 0.12)
                    }
                }
            }

            // the title, the source, the seek bar, the buttons
            Item {
                id: info
                width: top.width - disc.width - top.spacing
                height: top.height

                Column {
                    id: words
                    width: parent.width
                    spacing: Serp.px(6)
                    anchors.top: parent.top
                    anchors.topMargin: Serp.px(14)
                    opacity: root.st(0.1)
                    transform: Translate {
                        x: (1 - root.st(0.1)) * Serp.px(18)
                    }
                    SText {
                        width: parent.width
                        text: Lyrics.title
                        size: Serp.px(19)
                        bold: true
                    }
                    SText {
                        width: parent.width
                        text: Lyrics.artist + (Lyrics.album && Lyrics.album !== Lyrics.title ? "  ·  " + Lyrics.album : "")
                        size: Serp.px(13.5)
                        color: Serp.subtext0
                        visible: text !== ""
                    }
                    Item {
                        width: 1
                        height: Serp.px(4)
                    }
                    // the source; with two players or more it switches to the next one
                    Rectangle {
                        id: chip
                        readonly property bool many: root.playerList.length > 1
                        readonly property var nextPlayer: many ? root.playerList[(root.playerList.indexOf(root.player) + 1) % root.playerList.length] : null
                        height: Serp.px(22)
                        width: chipRow.width + Serp.px(18)
                        radius: height / 2
                        color: chipMa.containsMouse && many ? Serp.surface1 : Serp.surface0
                        border.width: 1
                        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
                        visible: root.playerName(root.player) !== ""
                        scale: chipMa.pressed && many ? 0.96 : 1
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
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: Serp.px(5)
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Serp.px(6)
                                height: width
                                radius: width / 2
                                color: root.playing ? Serp.green : Serp.overlay
                            }
                            SText {
                                text: "через " + root.playerName(root.player)
                                size: Serp.px(11.5)
                                color: Serp.subtext0
                            }
                            SIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: chip.many
                                name: "refresh-cw"
                                size: Serp.px(11)
                                color: Serp.subtext0
                            }
                        }
                        MouseArea {
                            id: chipMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: chip.many
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Lyrics.pinned = chip.nextPlayer
                        }
                    }
                }

                Column {
                    width: parent.width
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Serp.px(6)
                    spacing: Serp.px(4)
                    opacity: root.st(0.2)
                    transform: Translate {
                        y: (1 - root.st(0.2)) * Serp.px(14)
                    }

                    SerpWaveBar {
                        id: wave
                        width: parent.width
                        height: Serp.px(28)
                        value: root.len > 0 ? root.pos / root.len : 0
                        playing: root.playing
                        seekable: !!root.player && root.player.canSeek && root.len > 0
                        active: root.shown
                        onSeek: f => root.seekTo(f * root.len)
                    }
                    Item {
                        width: parent.width
                        height: Serp.px(16)
                        SText {
                            x: wave.pad
                            text: root.clock(wave.dragging ? wave.dragValue * root.len : root.pos)
                            size: Serp.px(12)
                            color: Serp.subtext0
                        }
                        SText {
                            anchors.right: parent.right
                            anchors.rightMargin: wave.pad
                            text: root.len > 0 ? root.clock(root.len) : "--:--"
                            size: Serp.px(12)
                            color: Serp.subtext0
                        }
                    }
                    Item {
                        width: 1
                        height: Serp.px(6)
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Serp.px(18)
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

        Rectangle {
            id: sep
            anchors.top: top.bottom
            anchors.topMargin: Serp.px(16)
            width: parent.width * root.st(0.25)
            anchors.horizontalCenter: parent.horizontalCenter
            height: Serp.px(2)
            radius: 1
            color: Qt.alpha(Serp.text, 0.1)
        }

        // ---- the lyrics ----
        Item {
            id: lyr
            anchors.top: sep.bottom
            anchors.topMargin: Serp.px(12)
            anchors.bottom: parent.bottom
            width: parent.width
            opacity: root.st(0.3)
            transform: Translate {
                y: (1 - root.st(0.3)) * Serp.px(20)
            }

            Row {
                id: lyrHead
                spacing: Serp.px(8)
                SIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "file-text"
                    size: Serp.px(14)
                    color: Serp.mauve
                }
                SText {
                    text: "Текст"
                    size: Serp.px(13)
                    bold: true
                }
                SText {
                    visible: Lyrics.status === "plain"
                    text: "без синхронизации"
                    size: Serp.px(11)
                    dim: true
                }
            }

            SText {
                anchors.centerIn: lv
                visible: !Lyrics.hasLyrics
                width: lv.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: ({
                        "loading": "Ищу текст…",
                        "instrumental": "Инструментал",
                        "error": "Не удалось загрузить текст"
                    })[Lyrics.status] || "Текст не найден"
                size: Serp.px(14)
                color: Serp.subtext0
            }

            ListView {
                id: lv
                anchors.top: lyrHead.bottom
                anchors.topMargin: Serp.px(8)
                anchors.bottom: parent.bottom
                width: parent.width
                clip: true
                visible: Lyrics.hasLyrics
                model: Lyrics.hasLyrics ? Lyrics.lines : []
                readonly property bool synced: Lyrics.status === "ok"
                currentIndex: synced ? Lyrics.index : -1
                highlightFollowsCurrentItem: true
                highlightRangeMode: synced && !lyrHover.hovered ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
                preferredHighlightBegin: height / 2 - Serp.px(18)
                preferredHighlightEnd: height / 2 + Serp.px(18)
                highlightMoveDuration: 450
                highlightMoveVelocity: -1
                spacing: Serp.px(6)
                boundsBehavior: Flickable.StopAtBounds
                header: Item {
                    width: 1
                    height: lv.synced ? 0 : Serp.px(4)
                }
                delegate: Item {
                    id: line
                    required property var modelData
                    required property int index
                    readonly property bool cur: lv.synced && index === Lyrics.index
                    readonly property int dist: lv.synced && Lyrics.index >= 0 ? Math.abs(index - Lyrics.index) : 1
                    width: lv.width
                    height: lt.implicitHeight + Serp.px(4)
                    SText {
                        id: lt
                        width: parent.width - Serp.px(24)
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                        text: line.modelData.text || "♪"
                        size: line.cur ? Serp.px(18) : Serp.px(14)
                        bold: line.cur
                        color: line.cur ? Serp.mauve : lineMa.containsMouse ? Serp.text : Serp.subtext0
                        opacity: line.cur ? 1 : Math.max(0.35, 1 - line.dist * 0.16)
                        Behavior on size {
                            NumberAnimation {
                                duration: Serp.normal
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Serp.normal
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Serp.normal
                            }
                        }
                    }
                    MouseArea {
                        id: lineMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: lv.synced && !!root.player && root.player.canSeek
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.seekTo(line.modelData.t - Config.lyrics.offsetMs / 1000 + 0.05)
                    }
                }
                // the edges fade
                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: Serp.px(28)
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.alpha(Serp.base, 0.85)
                        }
                        GradientStop {
                            position: 1
                            color: "transparent"
                        }
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Serp.px(28)
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 1
                            color: Qt.alpha(Serp.base, 0.85)
                        }
                    }
                }
            }
            // reading by hand: the auto-scroll waits while the pointer is over the lyrics
            HoverHandler {
                id: lyrHover
            }
        }
    }

    // a transport button: Serpantinum's round one, the play button bigger and in the accent
    component Transport: Item {
        id: tb
        property string icon: ""
        property bool big: false
        property bool enabledHere: true
        signal clicked
        width: big ? Serp.px(52) : Serp.px(40)
        height: width
        opacity: enabledHere ? 1 : 0.4
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: tb.big ? (tbMa.containsMouse ? Qt.lighter(Serp.mauve, 1.1) : Serp.mauve) : tbMa.containsMouse ? Serp.surface1 : Serp.surface0
            border.width: tb.big ? 0 : 1
            border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
            scale: tbMa.pressed ? 0.96 : 1
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
                size: tb.big ? Serp.px(22) : Serp.px(17)
                filled: true
                color: tb.big ? Serp.onAccent : tbMa.containsMouse ? Serp.mauve : Serp.text
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

    // a click inside stays inside
    MouseArea {
        anchors.fill: parent
        z: -10
    }
}
