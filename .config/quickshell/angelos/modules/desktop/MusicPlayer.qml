import QtQuick
import QtQuick.Effects
import qs.config
import qs.services
import qs.widgets

// The music widget's player (MusicWidget: M alone, L over the spectrum): cover, track and
// controls of the current MPRIS player.
// In hell (Theme.realm) the cover is the label of a burning record: a pixel disc
// that turns while the music plays, flames licking up from under it.
// macOS look (DesktopWidgets.macLook): the cover with round corners, the track, a thin
// progress line with the times and the controls in SF-like glyphs.
Item {
    id: root

    property string screenName
    property var widget
    readonly property var p: Lyrics.player
    property real pos: 0
    readonly property bool playing: !!p && p.isPlaying
    readonly property bool live: visible && !Shell.hiddenScreen(screenName)

    property bool mac: DesktopWidgets.macLook
    implicitWidth: mac ? DesktopWidgets.mpx(320) : Theme.u * 150
    implicitHeight: mac ? DesktopWidgets.mpx(104) : Theme.u * 44

    Timer {
        interval: 1000
        running: root.visible && root.playing
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.p.positionChanged();
            root.pos = root.p.position;
        }
    }

    // ---- macOS look ----
    function clock(sec) {
        if (!(sec >= 0) || !isFinite(sec))
            return "0:00";
        const s = Math.floor(sec);
        return Math.floor(s / 60) + ":" + ("0" + s % 60).slice(-2);
    }
    readonly property bool hasTrack: !!p && !!Lyrics.title
    Row {
        visible: root.mac && !root.hasTrack
        anchors.centerIn: parent
        spacing: DesktopWidgets.mpx(8)
        MacIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "music"
            size: DesktopWidgets.mpx(18)
            color: DesktopWidgets.macSecondary
        }
        MacWidgetText {
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t("Ничего не играет", "Not Playing")
            size: 15
            weight: Font.DemiBold
            role: "secondary"
        }
    }
    Row {
        visible: root.mac && root.hasTrack
        anchors.fill: parent
        spacing: DesktopWidgets.mpx(14)
        Item {
            id: macCover
            width: parent.height
            height: parent.height
            Rectangle {
                anchors.fill: parent
                radius: DesktopWidgets.mpx(12)
                color: DesktopWidgets.macSeparator
                MacIcon {
                    anchors.centerIn: parent
                    visible: macArt.status !== Image.Ready
                    name: "music"
                    size: parent.width * 0.36
                    color: DesktopWidgets.macTertiary
                }
            }
            Image {
                id: macArt
                anchors.fill: parent
                source: root.mac && root.p ? (root.p.trackArtUrl || "") : ""
                sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                visible: macArt.status === Image.Ready
                source: macArt
                maskEnabled: true
                maskSource: coverMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
            Item {
                id: coverMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    anchors.fill: parent
                    radius: DesktopWidgets.mpx(12)
                    antialiasing: true
                }
            }
        }
        Column {
            width: parent.width - macCover.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: DesktopWidgets.mpx(2)
            MacWidgetText {
                width: parent.width
                text: Lyrics.title
                size: 15
                weight: Font.DemiBold
            }
            MacWidgetText {
                width: parent.width
                text: Lyrics.artist
                size: 13
                role: "secondary"
            }
            Item {
                width: 1
                height: DesktopWidgets.mpx(6)
            }
            Rectangle {
                width: parent.width
                height: DesktopWidgets.mpx(4)
                radius: height / 2
                color: DesktopWidgets.macSeparator
                Rectangle {
                    height: parent.height
                    radius: height / 2
                    width: root.p && root.p.length > 0 ? Math.max(height, parent.width * Math.min(1, root.pos / root.p.length)) : 0
                    color: DesktopWidgets.macLabel
                    opacity: 0.85
                }
            }
            Item {
                width: parent.width
                height: macTimes.implicitHeight
                MacWidgetText {
                    id: macTimes
                    text: root.clock(root.pos)
                    size: 11
                    role: "tertiary"
                }
                MacWidgetText {
                    anchors.right: parent.right
                    text: root.p && root.p.length > 0 ? "−" + root.clock(root.p.length - root.pos) : ""
                    size: 11
                    role: "tertiary"
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: DesktopWidgets.mpx(14)
                Repeater {
                    model: [
                        {
                            "id": "prev",
                            "icon": "skip-back",
                            "size": 18
                        },
                        {
                            "id": "play",
                            "icon": root.playing ? "pause" : "play",
                            "size": 24
                        },
                        {
                            "id": "next",
                            "icon": "skip-forward",
                            "size": 18
                        }
                    ]
                    Item {
                        id: macBtn
                        required property var modelData
                        width: DesktopWidgets.mpx(32)
                        height: width
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: DesktopWidgets.macLabel
                            opacity: macBtnMouse.pressed ? 0.2 : macBtnMouse.containsMouse ? 0.1 : 0
                        }
                        MacIcon {
                            anchors.centerIn: parent
                            name: macBtn.modelData.icon
                            size: DesktopWidgets.mpx(macBtn.modelData.size)
                            filled: true
                            stroke: 1.5
                            color: DesktopWidgets.macLabel
                        }
                        MouseArea {
                            id: macBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: macBtn.modelData.id === "prev" ? root.p.previous() : macBtn.modelData.id === "next" ? root.p.next() : root.p.togglePlaying()
                        }
                    }
                }
            }
        }
    }

    PxText {
        visible: !root.mac && (!root.p || !Lyrics.title)
        anchors.centerIn: parent
        text: Theme.hell ? I18n.t("тишина", "silence") : I18n.t("ничего не играет ♡", "nothing is playing ♡")
        color: Theme.hell ? Theme.hellTextDim : Theme.textDim
    }

    Row {
        visible: !root.mac && !!root.p && !!Lyrics.title
        anchors.fill: parent
        spacing: Theme.u * 5

        Item {
            width: parent.height
            height: parent.height

            PxBox {
                anchors.fill: parent
                visible: !Theme.hell
                sunken: true
                color: Theme.sunken
            }
            Image {
                // heaven: the whole box; hell: the record's label in the middle
                readonly property int side: Theme.hell ? vinyl.labelPx * 2 : parent.width
                anchors.centerIn: parent
                width: side
                height: side
                source: root.p ? (root.p.trackArtUrl || "") : ""
                sourceSize: Qt.size(Theme.u * 24, Theme.u * 24)   // tiny source + no smoothing = pixel cover
                fillMode: Image.PreserveAspectCrop
                smooth: false
                asynchronous: true
            }

            // ---- hell: the record ----
            // Drawn art pixel by art pixel in the circle's palette: grooves, a dull glint that
            // moves an eighth of a turn every few seconds while it plays (hell is slow), and a
            // clear hole where the cover shows through as the label.
            Canvas {
                id: vinyl
                visible: Theme.hell
                anchors.fill: parent
                readonly property int n: Math.max(8, Math.floor(width / Theme.u))   // art pixels across
                readonly property int labelPx: Math.round(n * 0.22) * Theme.u
                property int step: 0
                renderStrategy: Canvas.Cooperative
                onStepChanged: requestPaint()
                onNChanged: requestPaint()
                onVisibleChanged: if (visible)
                    requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    const u = width / n, c = (n - 1) / 2, R = n / 2 - 0.5, L = n * 0.22;
                    ctx.clearRect(0, 0, width, height);
                    const glint = step * Math.PI / 4;
                    for (let y = 0; y < n; y++)
                        for (let x = 0; x < n; x++) {
                            const dx = x - c, dy = y - c, r = Math.sqrt(dx * dx + dy * dy);
                            if (r > R || r <= L)
                                continue;
                            let col = String(Theme.hellSunken);
                            if (r > R - 1)
                                col = String(Theme.hellFaceAlt);
                            else if (Math.round(r) % 3 === 0)
                                col = String(Theme.hellFace);
                            // the glint: a short arc that moves an eighth of a turn a step
                            let a = Math.atan2(dy, dx) - glint;
                            a = Math.atan2(Math.sin(a), Math.cos(a));
                            if (Math.abs(a) < 0.28 && r > L + 1 && r < R - 1)
                                col = String(Theme.hellRim);
                            if (r <= L + 1)
                                col = String(Theme.hellBlood);
                            ctx.fillStyle = col;
                            ctx.fillRect(Math.round(x * u), Math.round(y * u), Math.ceil(u), Math.ceil(u));
                        }
                }
                Timer {
                    interval: 6000
                    repeat: true
                    running: vinyl.visible && root.playing && root.live
                    onTriggered: vinyl.step = (vinyl.step + 1) % 8
                }
            }
        }
        Column {
            width: parent.width - parent.height - Theme.u * 5
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.u * 2
            PxText {
                width: parent.width
                text: Lyrics.title
                font.bold: !Theme.hell
                font.family: Theme.hell ? Theme.fontHellText : Theme.fontBody
                font.pixelSize: Theme.hell ? Theme.hellTextPx(Theme.fs) : Theme.sizeBody
                color: Theme.hell ? Theme.hellText : Theme.text
                elide: Text.ElideRight
            }
            PxText {
                width: parent.width
                text: Lyrics.artist
                font.family: Theme.hell ? Theme.fontHellText : Theme.fontBody
                font.pixelSize: Theme.hell ? Theme.hellTextPx(Theme.fs) : Theme.sizeBody
                color: Theme.hell ? Theme.hellTextDim : Theme.textDim
                elide: Text.ElideRight
            }
            PxBox {
                width: parent.width
                height: Theme.u * 4
                sunken: true
                hell: Theme.hell
                color: Theme.hell ? Theme.hellSunken : Theme.sunken
                Rectangle {
                    height: parent.height
                    width: root.p && root.p.length > 0 ? parent.width * Math.min(1, root.pos / root.p.length) : 0
                    color: Theme.hell ? Theme.hellBlood : Theme.accent
                }
            }
            Row {
                spacing: Theme.u * 2
                PxButton {
                    compact: true
                    hell: Theme.hell
                    icon: "prev"
                    iconPixel: Math.max(1, Theme.u - 1)
                    onClicked: root.p.previous()
                }
                PxButton {
                    compact: true
                    hell: Theme.hell
                    icon: root.playing ? "pause" : "play"
                    iconPixel: Math.max(1, Theme.u - 1)
                    onClicked: root.p.togglePlaying()
                }
                PxButton {
                    compact: true
                    hell: Theme.hell
                    icon: "next"
                    iconPixel: Math.max(1, Theme.u - 1)
                    onClicked: root.p.next()
                }
            }
        }
    }
}
