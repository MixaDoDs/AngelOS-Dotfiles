import QtQuick

// angelOS login, the "heaven" look: a sky of the hour (dawn pink, clear day, gold-pink
// evening, a starry night), pixel clouds drifting in layers, the gold gate with the light of
// the other side, and before it a plate on the clouds: the halo, the name, the password as
// little stars. The angel dozes on a cloud by the gate. Other screens: the sky, the clock
// and the angel asleep.
Item {
    id: root

    property bool primary: true
    readonly property int u: g.u
    readonly property var pal: g.pal

    Greeter {
        id: g
        screenW: root.width
        screenH: root.height
    }

    // ---- the sky of the hour ----
    readonly property string phase: g.hour < 5 || g.hour >= 21 ? "night" : g.hour < 8 ? "dawn" : g.hour < 17 ? "day" : "evening"
    readonly property bool night: phase === "night"
    readonly property var sky: ({
            "dawn": {
                "top": "#6f7dea",
                "mid": "#ffadd0",
                "low": "#ffe0bf",
                "cloud": "#fff4f8",
                "shade": "#f2c4dd",
                "rim": "#ffffff",
                "plate": "#fffaf3",
                "ink": "#4a3768",
                "dim": "#8c76a6"
            },
            "day": {
                "top": "#7fb8ff",
                "mid": "#c4e2ff",
                "low": "#ffeaf6",
                "cloud": "#ffffff",
                "shade": "#d9e6ff",
                "rim": "#ffffff",
                "plate": "#fffaf3",
                "ink": "#3b3560",
                "dim": "#7d7aa3"
            },
            "evening": {
                "top": "#4d3f9e",
                "mid": "#ff8db0",
                "low": "#ffc78f",
                "cloud": "#ffe6ef",
                "shade": "#d6a2cf",
                "rim": "#fff6e8",
                "plate": "#fff5ee",
                "ink": "#4b2f5e",
                "dim": "#93708f"
            },
            "night": {
                "top": "#0b0f30",
                "mid": "#232b66",
                "low": "#55468c",
                "cloud": "#8e93cc",
                "shade": "#5c6099",
                "rim": "#c3c6f0",
                "plate": "#1e2350",
                "ink": "#f4f1ff",
                "dim": "#a9a6d6"
            }
        })[phase]
    readonly property color gold: "#f2c14e"
    readonly property color goldDark: "#b07a1f"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.sky.top
            }
            GradientStop {
                position: 0.55
                color: root.sky.mid
            }
            GradientStop {
                position: 1
                color: root.sky.low
            }
        }
    }
    // the stars at night, a few sparkles by day
    Repeater {
        model: root.night ? 46 : 10
        PixelIcon {
            required property int index
            name: index % 3 ? "sparkle" : "sparkleStar"
            pixel: root.u * (index % 7 === 0 ? 2 : 1)
            ink: "transparent"
            fill: index % 4 ? "#ffffff" : root.gold
            fill2: "#ffffff"
            fill3: root.gold
            light: "#ffffff"
            x: Math.round(((index * 0.6180339 + 0.05) % 1) * root.width)
            y: Math.round(((index * 0.4142 + 0.02) % 1) * root.height * (root.night ? 0.62 : 0.4))
            opacity: (root.night ? 0.35 : 0.2) + 0.65 * Math.abs(Math.sin(g.secs * (0.4 + index % 5 * 0.15) + index * 1.7))
        }
    }
    // the sun or the moon
    PixelArt {
        id: orb
        shape: root.night ? "crescent" : "disc"
        cell: root.u * 3
        cols: 16
        rows: 16
        body: root.night ? "#f5f0d0" : root.phase === "evening" ? "#ffb070" : "#fff3b8"
        shade: root.night ? "#cfc79a" : root.phase === "evening" ? "#ff8a5c" : "#ffd36a"
        rim: "#ffffff"
        x: Math.round(root.width * (root.portrait ? 0.72 : 0.8))
        y: Math.round(root.height * (root.phase === "day" ? 0.08 : 0.16))
        opacity: 0.95
    }
    readonly property bool portrait: g.portrait

    // clouds in three layers: far and pale, middle, and the sea the gate stands on
    component Drift: PixelArt {
        id: d
        required property int index
        property real speed: 4
        property real lane: 0.2
        property real start: 0
        shape: "cloud"
        seed: index * 7 + 3
        body: root.sky.cloud
        shade: root.sky.shade
        rim: root.sky.rim
        readonly property real span: root.width + width
        x: Math.round((((start * span + g.secs * speed * root.u) % span) - width) / cell) * cell
        y: Math.round(root.height * lane / cell) * cell
    }
    Repeater {
        model: 5
        Drift {
            cell: root.u * 2
            cols: 34 + index * 5
            rows: 11 + index % 3 * 2
            speed: 1.2 + index * 0.25
            lane: 0.08 + index * 0.085
            start: index * 0.27
            opacity: 0.55
        }
    }
    Repeater {
        model: 4
        Drift {
            cell: root.u * 3
            cols: 40 + index * 6
            rows: 13 + index % 2 * 3
            speed: 2.6 + index * 0.4
            lane: 0.3 + index * 0.1
            start: index * 0.31 + 0.1
            opacity: 0.85
        }
    }

    // ---- the gate (login screen) ----
    readonly property int gateCell: Math.max(2, Math.round(Math.min(root.width * 0.8 / 64, root.height * (root.portrait ? 0.45 : 0.62) / 84)))
    readonly property real seaY: root.height * (root.portrait ? 0.7 : 0.8)
    HeavenGate {
        id: gate
        visible: root.primary
        cell: root.gateCell
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.seaY - height + cell * 6)
        heart: root.pal.accent
        lightEdge: root.night ? "#8f86ff" : root.pal.accent2
    }
    // the light of the other side, breathing
    Rectangle {
        visible: root.primary
        x: gate.x + gate.innerLeft * gate.cell
        y: gate.y + gate.springY * gate.cell
        width: (gate.innerRight - gate.innerLeft) * gate.cell
        height: gate.height - gate.springY * gate.cell - gate.cell * 6
        color: "#ffffff"
        opacity: 0.08 + 0.08 * Math.sin(g.secs * 0.9) + root.open * 0.9
    }
    property real open: 0
    // the sea of clouds: a flat floor, and a bank of big clouds over its edge and the gate's feet
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        y: Math.round(root.seaY + root.u * 14)
        height: parent.height - y
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.sky.cloud
            }
            GradientStop {
                position: 1
                color: root.sky.shade
            }
        }
    }
    Repeater {
        model: 9
        PixelArt {
            required property int index
            shape: "cloud"
            seed: 40 + index * 3
            cell: root.u * 4
            cols: 70 + index % 3 * 12
            rows: 22 + index % 2 * 6
            body: root.sky.cloud
            shade: index >= 5 ? Qt.tint(root.sky.cloud, Qt.rgba(root.sky.shade.r, root.sky.shade.g, root.sky.shade.b, 0.5)) : root.sky.cloud
            rim: root.sky.rim
            x: Math.round(((index * 0.137) % 1.1 - 0.12) * root.width + Math.sin(g.secs * 0.05 + index) * root.u * 10)
            y: Math.round(root.seaY - height * (index % 3 === 0 ? 0.55 : 0.4) + (index >= 5 ? root.u * 22 : 0))
        }
    }

    // the angel dozes on a cloud by the gate's right pillar (landscape; portrait has no room)
    Item {
        visible: root.primary && !root.portrait && angelNap.ready
        x: Math.round(Math.min(root.width - width - root.u * 12, gate.x + gate.width + (root.width - gate.x - gate.width - width) * 0.35))
        y: Math.round(root.seaY - angelNap.height * 0.92 + Math.sin(g.secs * 0.7) * root.u * 2)
        width: angelNap.width
        height: angelNap.height
        PixelArt {
            shape: "cloud"
            seed: 91
            cell: root.u * 3
            cols: Math.round(angelNap.width / cell * 1.5)
            rows: 16
            body: root.sky.cloud
            shade: root.sky.shade
            rim: root.sky.rim
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(angelNap.height * 0.78)
        }
        AngelCam {
            id: angelNap
            px: root.u
            time: g.secs
            font: g.titleFont
            zEdge: root.sky.ink
        }
    }

    // ---- the wordmark, the clock, the plate ----
    Column {
        id: head
        objectName: "head"
        visible: root.primary
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(Math.max(root.u * 12, (gate.y - height) * 0.5))
        spacing: root.u * 4

        // angelOS under a halo
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: mark.width
            height: mark.height + halo.height * 0.6
            PixelArt {
                id: halo
                shape: "ring"
                cell: root.u
                cols: 26
                rows: 7
                body: root.gold
                x: Math.round(markA.width * 0.5 - width / 2)
                y: Math.round(Math.sin(g.secs * 1.6) * root.u * 1.5)
            }
            Row {
                id: mark
                y: halo.height * 0.6
                spacing: root.u * 3
                Text {
                    id: markA
                    text: "angel"
                    color: "#ffffff"
                    style: Text.Outline
                    styleColor: root.goldDark
                    font.family: g.titleFont
                    font.pixelSize: g.titlePx(36)
                    renderType: Text.NativeRendering
                }
                Text {
                    text: "OS"
                    color: root.gold
                    style: Text.Outline
                    styleColor: root.goldDark
                    font.family: g.titleFont
                    font.pixelSize: g.titlePx(36)
                    renderType: Text.NativeRendering
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: g.clockText(false)
            color: "#ffffff"
            style: Text.Outline
            styleColor: root.night ? "#2a2f6a" : "#8a5a14"
            font.family: g.titleFont
            font.pixelSize: g.titlePx(63)
            renderType: Text.NativeRendering
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: g.dateText()
            color: "#ffffff"
            style: Text.Outline
            styleColor: root.night ? "#2a2f6a" : "#8a5a14"
            font.family: g.titleFont
            font.pixelSize: g.titlePx(18)
            renderType: Text.NativeRendering
        }
    }

    // the plate before the gate's light: gold rim, notched corners
    Item {
        id: center
        objectName: "center"
        visible: root.primary
        anchors.horizontalCenter: parent.horizontalCenter
        width: plate.width
        height: plate.height
        y: Math.round(gate.y + gate.springY * gate.cell + (gate.height - gate.springY * gate.cell - gate.cell * 6 - height) * 0.45)
        Item {
            id: plate
            objectName: "login"
            width: Math.min(root.u * 190, root.width - root.u * 24)
            height: form.implicitHeight + root.u * 24
            property real shakeX: 0
            transform: Translate {
                x: plate.shakeX
            }
            Rectangle {
                x: root.u * 3
                y: root.u * 3
                width: parent.width
                height: parent.height
                color: Qt.rgba(0.1, 0.05, 0.2, 0.25)
            }
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: root.u * 2
                anchors.rightMargin: root.u * 2
                color: root.goldDark
            }
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: root.u * 2
                anchors.bottomMargin: root.u * 2
                color: root.goldDark
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: root.u * 2
                color: root.gold
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: root.u * 4
                color: root.sky.plate
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: root.u * 2
                    color: "transparent"
                    border.width: root.u
                    border.color: Qt.rgba(root.gold.r, root.gold.g, root.gold.b, 0.45)
                }
            }

            Column {
                id: form
                x: root.u * 12
                y: root.u * 12
                width: parent.width - root.u * 24
                spacing: root.u * 6

                Row {
                    spacing: root.u * 6
                    // the avatar in a ring, a halo floating over it
                    Item {
                        width: root.u * 28
                        height: root.u * 30
                        PixelArt {
                            shape: "ring"
                            cell: root.u
                            cols: 18
                            rows: 5
                            body: root.gold
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.round(Math.sin(g.secs * 2 + 1) * root.u)
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: root.u * 26
                            color: root.night ? "#2c3270" : "#eaf2ff"
                            border.width: root.u
                            border.color: root.gold
                            Image {
                                id: face
                                anchors.fill: parent
                                anchors.margins: root.u
                                source: g.userFace
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready
                            }
                            PixelIcon {
                                visible: face.status !== Image.Ready
                                anchors.centerIn: parent
                                name: g.fails > 0 && breakTimer.running ? "heartBroken" : "heart"
                                pixel: root.u * 2
                                ink: root.goldDark
                                fill: root.pal.accent
                            }
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.u * 2
                        Text {
                            text: g.greeting + ", " + g.userShown
                            color: root.sky.ink
                            font.family: g.titleFont
                            font.pixelSize: g.titlePx(18)
                            renderType: Text.NativeRendering
                        }
                        Row {
                            spacing: root.u * 3
                            visible: g.userCount > 1
                            Repeater {
                                model: [-1, 1]
                                Rectangle {
                                    required property int modelData
                                    width: root.u * 11
                                    height: root.u * 11
                                    color: um.containsMouse ? root.gold : "transparent"
                                    border.width: root.u
                                    border.color: root.gold
                                    PixelIcon {
                                        anchors.centerIn: parent
                                        name: parent.modelData < 0 ? "arrowLeft" : "arrowRight"
                                        pixel: Math.max(1, Math.round(root.u / 2))
                                        ink: root.sky.ink
                                        fill: root.sky.ink
                                    }
                                    MouseArea {
                                        id: um
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            g.nextUser(parent.modelData);
                                            pw.forceActiveFocus();
                                        }
                                    }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: g.t("другая душа", "another soul")
                                color: root.sky.dim
                                font.family: g.bodyFont
                                font.pixelSize: g.bodyPx(13)
                                renderType: Text.NativeRendering
                            }
                        }
                        Text {
                            visible: g.userCount <= 1
                            text: g.t("врата ждут тебя ✦", "the gate awaits ✦")
                            color: root.sky.dim
                            font.family: g.bodyFont
                            font.pixelSize: g.bodyPx(13)
                            renderType: Text.NativeRendering
                        }
                    }
                }

                // the password: a little star for every character
                Row {
                    width: parent.width
                    spacing: root.u * 3
                    Rectangle {
                        id: field
                        width: parent.width - go.width - parent.spacing
                        height: root.u * 18
                        color: root.night ? "#151940" : "#f3f6ff"
                        border.width: root.u
                        border.color: g.fails > 0 && breakTimer.running ? root.pal.danger : pw.activeFocus ? root.gold : Qt.rgba(root.gold.r, root.gold.g, root.gold.b, 0.5)
                        clip: true
                        readonly property real room: Math.max(root.u * 20, width - root.u * 16)
                        readonly property real step: Math.min(root.u * 10, room / Math.max(1, pw.text.length))
                        Repeater {
                            model: pw.text.length
                            PixelIcon {
                                id: star
                                required property int index
                                name: index % 2 ? "sparkle" : "sparkleStar"
                                pixel: root.u
                                ink: "transparent"
                                fill: index % 3 === 1 ? root.pal.accent : root.gold
                                fill2: root.gold
                                fill3: root.gold
                                light: "#ffffff"
                                x: root.u * 6 + index * field.step
                                y: Math.round((field.height - height) / 2 + (g.busy ? Math.sin(g.secs * 9 + index) * root.u * 2 : 0))
                                property real drop: 1
                                transform: Translate {
                                    y: -star.drop * root.u * 8
                                }
                                opacity: 1 - star.drop * 0.6
                                NumberAnimation on drop {
                                    from: 1
                                    to: 0
                                    duration: 220
                                    easing.type: Easing.OutBack
                                }
                            }
                        }
                        Rectangle {
                            x: root.u * 6 + pw.text.length * field.step + root.u
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.u * 2
                            height: root.u * 9
                            color: root.gold
                            visible: pw.activeFocus && !g.busy && Math.floor(g.secs * 2) % 2 === 0
                        }
                        Text {
                            visible: pw.text.length === 0
                            x: root.u * 11
                            anchors.verticalCenter: parent.verticalCenter
                            text: g.t("пароль — и врата откроются ✦", "your password opens the gate ✦")
                            color: root.sky.dim
                            font.family: g.bodyFont
                            font.pixelSize: g.bodyPx(13)
                            renderType: Text.NativeRendering
                        }
                        TextInput {
                            id: pw
                            objectName: "password"
                            anchors.fill: parent
                            color: "transparent"
                            selectionColor: "transparent"
                            selectedTextColor: "transparent"
                            echoMode: TextInput.Password
                            cursorDelegate: Item {}
                            readOnly: g.busy
                            focus: true
                            onAccepted: g.submit(text)
                            Keys.onPressed: e => {
                                if (e.key === Qt.Key_Escape) {
                                    text = "";
                                    e.accepted = true;
                                }
                            }
                        }
                    }
                    Rectangle {
                        id: go
                        width: field.height
                        height: field.height
                        color: gm.containsMouse ? "#ffd977" : root.gold
                        border.width: root.u
                        border.color: root.goldDark
                        PixelIcon {
                            anchors.centerIn: parent
                            name: "arrowRight"
                            pixel: root.u
                            ink: "#ffffff"
                            fill: "#ffffff"
                        }
                        MouseArea {
                            id: gm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: g.submit(pw.text)
                        }
                    }
                }

                Row {
                    spacing: root.u * 5
                    Text {
                        visible: g.sessionCount > 0
                        text: "✦ " + g.sessionShown + (g.sessionCount > 1 ? " ▸" : "")
                        color: sm.containsMouse ? root.goldDark : root.sky.dim
                        font.family: g.bodyFont
                        font.pixelSize: g.bodyPx(13)
                        renderType: Text.NativeRendering
                        MouseArea {
                            id: sm
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                g.nextSession();
                                pw.forceActiveFocus();
                            }
                        }
                    }
                    Text {
                        visible: g.layoutShort !== ""
                        text: "⌨ " + g.layoutShort
                        color: root.sky.dim
                        font.family: g.bodyFont
                        font.pixelSize: g.bodyPx(13)
                        renderType: Text.NativeRendering
                    }
                    Text {
                        visible: g.caps
                        text: "CAPS LOCK"
                        color: root.pal.danger
                        font.family: g.titleFont
                        font.pixelSize: g.titlePx(9)
                        font.bold: true
                        renderType: Text.NativeRendering
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    visible: text !== ""
                    text: g.busy ? g.t("врата слушают…", "the gate is listening…") : g.live ? g.t("врата открываются ♡", "the gate opens ♡") : g.fails > 2 ? g.t("ангелы шепчут: проверь раскладку и Caps Lock", "the angels whisper: check the layout and Caps Lock") : g.fails > 0 && breakTimer.running ? g.t("врата не открылись — попробуй ещё", "the gate stayed shut — try again") : ""
                    color: g.fails > 0 && !g.busy && !g.live ? root.pal.danger : root.sky.dim
                    font.family: g.bodyFont
                    font.pixelSize: g.bodyPx(13)
                    renderType: Text.NativeRendering
                }
            }
        }
    }
    Timer {
        id: breakTimer
        interval: 2600
    }

    // ---- power, top right: little gold tablets ----
    Row {
        visible: root.primary
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: root.u * 10
        spacing: root.u * 4
        Repeater {
            model: g.power
            Rectangle {
                id: pbtn
                required property var modelData
                width: root.u * 17 + (ph.containsMouse ? plabel.implicitWidth + root.u * 4 : 0)
                height: root.u * 17
                color: ph.containsMouse ? root.gold : Qt.rgba(1, 1, 1, root.night ? 0.12 : 0.55)
                border.width: root.u
                border.color: root.goldDark
                Row {
                    anchors.centerIn: parent
                    spacing: root.u * 3
                    PixelIcon {
                        name: pbtn.modelData.icon
                        pixel: root.u
                        ink: root.night && !ph.containsMouse ? "#ffffff" : root.goldDark
                        fill: root.pal.accent
                        light: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id: plabel
                        visible: ph.containsMouse
                        text: pbtn.modelData.label
                        color: "#ffffff"
                        font.family: g.bodyFont
                        font.pixelSize: g.bodyPx(13)
                        anchors.verticalCenter: parent.verticalCenter
                        renderType: Text.NativeRendering
                    }
                }
                MouseArea {
                    id: ph
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pbtn.modelData.run()
                }
            }
        }
    }

    // ---- the other screens: the sky, the clock, the angel asleep on a cloud ----
    Column {
        id: camMain
        objectName: "camMain"
        visible: !root.primary
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round((root.height - height) / 2)
        spacing: root.u * 8
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 0.85
            text: Qt.formatTime(g.now, "HH") + (root.portrait ? "\n" : ":") + Qt.formatTime(g.now, "mm")
            color: "#ffffff"
            style: Text.Outline
            styleColor: root.night ? "#2a2f6a" : "#8a5a14"
            font.family: g.titleFont
            font.pixelSize: g.titlePx(root.portrait ? 126 : 90)
            renderType: Text.NativeRendering
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: g.dateText()
            color: "#ffffff"
            style: Text.Outline
            styleColor: root.night ? "#2a2f6a" : "#8a5a14"
            font.family: g.titleFont
            font.pixelSize: g.titlePx(18)
            renderType: Text.NativeRendering
        }
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(camCloud.width, camAngel.width)
            height: camAngel.height + camCloud.height * 0.6
            PixelArt {
                id: camCloud
                shape: "cloud"
                seed: 77
                cell: root.u * 3
                cols: 44
                rows: 14
                body: root.sky.cloud
                shade: root.sky.shade
                rim: root.sky.rim
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
            }
            AngelCam {
                id: camAngel
                px: root.u * 2
                time: g.secs
                font: g.titleFont
                zEdge: root.sky.ink
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(Math.sin(g.secs * 0.7) * root.u * 2)
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: g.t("✦ ангел дремлет на облаке ✦", "✦ the angel naps on a cloud ✦")
            color: "#ffffff"
            style: Text.Outline
            styleColor: root.night ? "#2a2f6a" : "#8a5a14"
            font.family: g.bodyFont
            font.pixelSize: g.bodyPx(13)
            renderType: Text.NativeRendering
        }
    }

    // ---- what happens ----
    SequentialAnimation {
        id: shake
        loops: 3
        NumberAnimation {
            target: plate
            property: "shakeX"
            to: root.u * 6
            duration: 40
        }
        NumberAnimation {
            target: plate
            property: "shakeX"
            to: -root.u * 6
            duration: 40
        }
        NumberAnimation {
            target: plate
            property: "shakeX"
            to: 0
            duration: 40
        }
    }
    Connections {
        target: g
        function onFailed() {
            shake.restart();
            breakTimer.restart();
            pw.text = "";
            pw.forceActiveFocus();
        }
        function onSucceeded() {
            openAnim.restart();
        }
    }
    // the gate opens: its light floods the screen
    Rectangle {
        anchors.fill: parent
        color: "#ffffff"
        opacity: Math.max(0, root.open - 0.4) / 0.6
    }
    NumberAnimation {
        id: openAnim
        target: root
        property: "open"
        from: 0
        to: 1
        duration: 1400
        easing.type: Easing.InQuad
    }

    Timer {
        interval: 300
        running: true
        onTriggered: pw.forceActiveFocus()
    }
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: pw.forceActiveFocus()
    }
}
