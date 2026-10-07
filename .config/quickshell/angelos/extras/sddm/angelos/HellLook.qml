import QtQuick

// angelOS login, the "hell" look: the wallpaper burnt dark red, embers rising, a great
// pentagram breathing behind a contract — "I, <user>, give my soul for a session" — signed
// with the password (a little pentagram a letter) and "sign in blood". A wrong one: the
// screen flares red; a right one: the seal. Other screens: the pentagram and the clock.
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
    // hell keeps its own colours whatever the desktop's are
    readonly property color blood: "#8a1020"
    readonly property color ember: "#ff6a2b"
    readonly property color flame: "#ffb347"
    readonly property color ash: "#d9cbbd"
    readonly property color ashDim: "#9c8f85"
    readonly property color stone: "#140c0c"
    readonly property color char_: "#070404"

    Wall {
        id: wall
        anchors.fill: parent
        g: g
        block: root.u * 6
        line: root.u
        tint: "#a0141e"
        tintAmount: 0.62
        fallbackTop: "#1a0607"
        fallbackBottom: "#050202"
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(0, 0, 0, 0.75)
            }
            GradientStop {
                position: 0.5
                color: Qt.rgba(0.05, 0, 0, 0.45)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(0, 0, 0, 0.85)
            }
        }
    }

    // the pentagram, breathing
    PixelArt {
        id: star
        shape: "pentagram"
        cell: root.u * 2
        cols: Math.round(Math.min(root.width, root.height) * 0.86 / cell)
        rows: cols
        body: root.blood
        anchors.centerIn: parent
        opacity: 0.35 + 0.2 * Math.sin(g.secs * 0.8) + flare * 0.5
        property real flare: 0
    }
    PixelArt {
        shape: "ring"
        cell: root.u * 2
        cols: star.cols + 10
        rows: cols
        body: root.ember
        anchors.centerIn: parent
        opacity: 0.12 + 0.1 * Math.sin(g.secs * 0.8 + 1)
    }

    // embers rising, swaying
    Repeater {
        model: 48
        Rectangle {
            required property int index
            readonly property real speed: 18 + (index * 13) % 30
            readonly property real life: (g.secs * speed * root.u + index * 131) % (root.height + 60)
            width: root.u * (index % 5 === 0 ? 2 : 1)
            height: width
            color: index % 3 ? root.ember : root.flame
            opacity: Math.max(0, 1 - life / root.height) * (0.5 + 0.5 * Math.abs(Math.sin(g.secs * 3 + index)))
            x: Math.round(((index * 0.6180339) % 1) * root.width + Math.sin(g.secs * 0.9 + index) * root.u * 10)
            y: Math.round(root.height - life)
        }
    }

    // ---- the name and the hour, in blackletter ----
    Column {
        id: head
        visible: root.primary
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(Math.max(root.u * 12, center.y - height - root.u * 14))
        spacing: root.u * 2
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "angelOS"
            color: root.ember
            style: Text.Raised
            styleColor: root.blood
            font.family: g.gothicFont
            font.pixelSize: g.gothicPx(60)
            renderType: Text.NativeRendering
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: g.clockText(false) + "  †  " + g.dateText()
            color: root.ash
            font.family: g.gothicFont
            font.pixelSize: g.gothicPx(24)
            renderType: Text.NativeRendering
        }
    }

    // ---- the contract ----
    Item {
        id: center
        objectName: "center"
        visible: root.primary
        width: Math.min(root.u * 250, root.width - root.u * 24)
        height: contract.implicitHeight + root.u * 28
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round((root.height - height) / 2 + root.u * 20)
        property real shakeX: 0
        transform: Translate {
            x: center.shakeX
        }
        // stone, a charred edge, an ember rim, the inner line
        Rectangle {
            x: root.u * 4
            y: root.u * 4
            width: parent.width
            height: parent.height
            color: Qt.rgba(0, 0, 0, 0.6)
        }
        Rectangle {
            anchors.fill: parent
            color: root.char_
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: root.u
            color: "transparent"
            border.width: root.u
            border.color: Qt.tint(root.blood, Qt.rgba(1, 0.42, 0.17, 0.3 + 0.25 * Math.sin(g.secs * 2)))
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: root.u * 3
            color: root.stone
            Rectangle {
                anchors.fill: parent
                anchors.margins: root.u * 3
                color: "transparent"
                border.width: root.u
                border.color: Qt.rgba(0.54, 0.06, 0.12, 0.6)
            }
        }
        // four little pentagrams in the corners
        Repeater {
            model: 4
            PixelArt {
                required property int index
                shape: "pentagram"
                cell: Math.max(1, Math.round(root.u / 2))
                cols: 27
                rows: 27
                body: root.ember
                x: index % 2 ? center.width - width - root.u * 9 : root.u * 9
                y: index < 2 ? root.u * 9 : center.height - height - root.u * 9
                opacity: 0.7
            }
        }

        Column {
            id: contract
            x: root.u * 28
            y: root.u * 14
            width: parent.width - root.u * 56
            spacing: root.u * 6
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: g.t("Договор о душе", "A Contract for a Soul")
                color: root.flame
                font.family: g.gothicFont
                font.pixelSize: g.gothicPx(36)
                renderType: Text.NativeRendering
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: g.t("Я, ", "I, ") + g.userShown + g.t(", отдаю душу в обмен на сеанс «", ", give my soul for a session of “") + g.sessionShown + g.t("». Подпись ниже — паролем.", "”. Sign below, with the password.")
                color: root.ash
                font.family: g.bodyFont
                font.pixelSize: g.bodyPx(13)
                renderType: Text.NativeRendering
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.u * 4
                visible: g.userCount > 1 || g.sessionCount > 1
                Repeater {
                    model: [
                        {
                            "label": g.t("другая душа", "another soul"),
                            "show": g.userCount > 1,
                            "run": () => g.nextUser(1)
                        },
                        {
                            "label": g.t("другой сеанс", "another session"),
                            "show": g.sessionCount > 1,
                            "run": () => g.nextSession()
                        }
                    ]
                    Text {
                        required property var modelData
                        visible: modelData.show
                        text: "‹ " + modelData.label + " ›"
                        color: lm.containsMouse ? root.flame : root.ashDim
                        font.family: g.bodyFont
                        font.pixelSize: g.bodyPx(13)
                        renderType: Text.NativeRendering
                        MouseArea {
                            id: lm
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                parent.modelData.run();
                                pw.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // the signature: a line to sign on, a pentagram a letter
            Item {
                id: field
                width: parent.width
                height: root.u * 20
                readonly property real step: Math.min(root.u * 11, (width - root.u * 12) / Math.max(1, pw.text.length))
                Text {
                    anchors.bottom: line.top
                    anchors.bottomMargin: root.u
                    text: "✗"
                    color: root.blood
                    font.family: g.titleFont
                    font.pixelSize: g.titlePx(18)
                    renderType: Text.NativeRendering
                }
                Rectangle {
                    id: line
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: root.u
                    color: g.fails > 0 && flareTimer.running ? root.ember : pw.activeFocus ? root.blood : Qt.rgba(0.54, 0.06, 0.12, 0.5)
                }
                Repeater {
                    model: pw.text.length
                    PixelIcon {
                        id: sig
                        required property int index
                        name: index % 2 ? "sparkle" : "sparkleStar"
                        pixel: root.u
                        ink: "transparent"
                        fill: index % 3 === 1 ? root.flame : root.ember
                        fill2: root.ember
                        fill3: root.flame
                        light: "#ffe2b0"
                        x: root.u * 14 + index * field.step
                        y: field.height - height - root.u * 4 + (g.busy ? Math.round(Math.sin(g.secs * 10 + index) * root.u * 2) : 0)
                        property real burn: 1
                        scale: 1 + sig.burn
                        opacity: 1 - sig.burn * 0.7
                        NumberAnimation on burn {
                            from: 1
                            to: 0
                            duration: 180
                        }
                    }
                }
                Text {
                    visible: pw.text.length === 0
                    x: root.u * 14
                    anchors.bottom: line.top
                    anchors.bottomMargin: root.u * 3
                    text: g.t("подпись (пароль)", "signature (password)")
                    color: root.ashDim
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

            Row {
                width: parent.width
                spacing: root.u * 6
                // sign in blood
                Rectangle {
                    id: sign
                    width: signText.implicitWidth + root.u * 16
                    height: root.u * 17
                    color: sm.containsMouse ? root.blood : Qt.darker(root.blood, 1.6)
                    border.width: root.u
                    border.color: root.ember
                    Text {
                        id: signText
                        anchors.centerIn: parent
                        text: g.t("Подписать кровью", "Sign in blood")
                        color: root.ash
                        font.family: g.gothicFont
                        font.pixelSize: g.gothicPx(24)
                        renderType: Text.NativeRendering
                    }
                    MouseArea {
                        id: sm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: g.submit(pw.text)
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        visible: g.layoutShort !== ""
                        text: g.t("раскладка ", "layout ") + g.layoutShort + (g.caps ? "  ·  CAPS LOCK" : "")
                        color: g.caps ? root.ember : root.ashDim
                        font.family: g.bodyFont
                        font.pixelSize: g.bodyPx(13)
                        renderType: Text.NativeRendering
                    }
                    Text {
                        text: g.busy ? g.t("ад читает подпись…", "hell reads the signature…") : g.live ? g.t("договор подписан †", "the contract is sealed †") : g.fails > 2 ? g.t("рука дрожит? раскладка, Caps Lock…", "a shaking hand? layout, Caps Lock…") : g.fails > 0 ? g.t("подпись не принята", "the signature is refused") : g.t("Enter — подписать", "Enter signs")
                        color: g.fails > 0 && !g.busy && !g.live ? root.ember : root.ashDim
                        font.family: g.bodyFont
                        font.pixelSize: g.bodyPx(13)
                        renderType: Text.NativeRendering
                    }
                }
            }
        }

        // the seal, pressed on when the contract is signed
        Item {
            visible: seal.pop > 0
            x: parent.width - width - root.u * 14
            y: parent.height - height - root.u * 10
            width: root.u * 46
            height: width
            rotation: -12
            scale: seal.pop
            Rectangle {
                id: seal
                property real pop: 0
                anchors.fill: parent
                radius: width / 2
                color: root.blood
                border.width: root.u * 2
                border.color: root.ember
            }
            PixelArt {
                anchors.centerIn: parent
                shape: "pentagram"
                cell: Math.max(1, Math.round(root.u / 2))
                cols: 60
                rows: 60
                body: root.flame
            }
        }
    }
    Timer {
        id: flareTimer
        interval: 1600
    }

    // ---- power: stone buttons ----
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
                color: ph.containsMouse ? root.blood : root.stone
                border.width: root.u
                border.color: ph.containsMouse ? root.ember : Qt.rgba(0.54, 0.06, 0.12, 0.7)
                Row {
                    anchors.centerIn: parent
                    spacing: root.u * 3
                    PixelIcon {
                        name: pbtn.modelData.icon
                        pixel: root.u
                        ink: root.ash
                        fill: root.ember
                        light: root.flame
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id: plabel
                        visible: ph.containsMouse
                        text: pbtn.modelData.label
                        color: root.ash
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

    // ---- the other screens: the clock inside the pentagram ----
    Column {
        id: camMain
        objectName: "camMain"
        visible: !root.primary
        anchors.centerIn: parent
        spacing: root.u * 4
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: g.clockText(true)
            color: root.ember
            style: Text.Raised
            styleColor: root.blood
            font.family: g.gothicFont
            font.pixelSize: g.gothicPx(root.portrait ? 120 : 96)
            renderType: Text.NativeRendering
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: g.dateText()
            color: root.ash
            font.family: g.gothicFont
            font.pixelSize: g.gothicPx(24)
            renderType: Text.NativeRendering
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: g.t("† она ждёт твою подпись †", "† she awaits your signature †")
            color: root.ashDim
            font.family: g.bodyFont
            font.pixelSize: g.bodyPx(13)
            renderType: Text.NativeRendering
        }
    }
    readonly property bool portrait: g.portrait

    // ---- what happens ----
    Rectangle {
        id: flash
        anchors.fill: parent
        color: root.blood
        opacity: 0
    }
    SequentialAnimation {
        id: failAnim
        NumberAnimation {
            target: flash
            property: "opacity"
            to: 0.45
            duration: 60
        }
        ParallelAnimation {
            NumberAnimation {
                target: flash
                property: "opacity"
                to: 0
                duration: 700
            }
            SequentialAnimation {
                loops: 3
                NumberAnimation {
                    target: center
                    property: "shakeX"
                    to: root.u * 6
                    duration: 40
                }
                NumberAnimation {
                    target: center
                    property: "shakeX"
                    to: -root.u * 6
                    duration: 40
                }
                NumberAnimation {
                    target: center
                    property: "shakeX"
                    to: 0
                    duration: 40
                }
            }
        }
    }
    SequentialAnimation {
        id: sealAnim
        NumberAnimation {
            target: seal
            property: "pop"
            from: 0
            to: 1.3
            duration: 120
        }
        NumberAnimation {
            target: seal
            property: "pop"
            to: 1
            duration: 90
        }
        NumberAnimation {
            target: star
            property: "flare"
            to: 1
            duration: 600
        }
    }
    Connections {
        target: g
        function onFailed() {
            failAnim.restart();
            flareTimer.restart();
            pw.text = "";
            pw.forceActiveFocus();
        }
        function onSucceeded() {
            sealAnim.restart();
        }
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
