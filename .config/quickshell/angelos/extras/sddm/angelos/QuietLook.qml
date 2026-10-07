import QtQuick

// angelOS login, the "quiet" look: the wallpaper as it is (drifting a little), dimmed at the
// bottom; a big clock in the corner, the date, and under them one slim glass field — the
// name and the password as little hearts. Power in a small pill. Other screens: the
// wallpaper and the clock.
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

    Wall {
        id: wall
        anchors.fill: parent
        g: g
        block: 1
        line: 0
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(0, 0, 0, 0)
            }
            GradientStop {
                position: 0.45
                color: Qt.rgba(0, 0, 0, 0.08)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(0, 0, 0, 0.62)
            }
        }
    }
    readonly property int m: root.u * (g.portrait ? 18 : 30)

    // ---- the clock and the field, bottom left ----
    Column {
        id: center
        objectName: "center"
        visible: root.primary
        x: root.m
        y: root.height - height - root.m
        spacing: root.u * 3
        property real shakeX: 0
        transform: Translate {
            x: center.shakeX
        }
        Text {
            text: g.clockText(false)
            color: "#ffffff"
            font.family: g.titleFont
            font.pixelSize: g.titlePx(108)
            renderType: Text.NativeRendering
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.35)
        }
        Text {
            text: g.dateText()
            color: Qt.rgba(1, 1, 1, 0.85)
            font.family: g.titleFont
            font.pixelSize: g.titlePx(27)
            renderType: Text.NativeRendering
        }
        Item {
            width: 1
            height: root.u * 10
        }
        // one glass field: the face, the name, the hearts
        Rectangle {
            id: field
            width: Math.min(root.u * 200, root.width - root.m * 2)
            height: root.u * 26
            radius: height / 2
            color: Qt.rgba(1, 1, 1, pw.activeFocus ? 0.18 : 0.12)
            border.width: Math.max(1, root.u / 2)
            border.color: g.fails > 0 && breakTimer.running ? root.pal.danger : Qt.rgba(1, 1, 1, pw.activeFocus ? 0.55 : 0.3)
            clip: true
            Rectangle {
                id: avatar
                x: root.u * 4
                anchors.verticalCenter: parent.verticalCenter
                width: root.u * 18
                height: width
                radius: width / 2
                color: root.pal.accent
                Image {
                    id: face
                    anchors.fill: parent
                    source: g.userFace
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }
                PixelIcon {
                    visible: face.status !== Image.Ready
                    anchors.centerIn: parent
                    name: "heartSmall"
                    pixel: root.u * 2
                    ink: "transparent"
                    fill: "#ffffff"
                }
            }
            Text {
                id: who
                anchors.left: avatar.right
                anchors.leftMargin: root.u * 5
                anchors.verticalCenter: parent.verticalCenter
                text: g.userShown
                color: "#ffffff"
                font.family: g.titleFont
                font.pixelSize: g.titlePx(18)
                renderType: Text.NativeRendering
                MouseArea {
                    anchors.fill: parent
                    enabled: g.userCount > 1
                    onClicked: {
                        g.nextUser(1);
                        pw.forceActiveFocus();
                    }
                }
            }
            Rectangle {
                id: sep
                anchors.left: who.right
                anchors.leftMargin: root.u * 5
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, root.u / 2)
                height: parent.height * 0.5
                color: Qt.rgba(1, 1, 1, 0.3)
            }
            Item {
                id: dots
                anchors.left: sep.right
                anchors.leftMargin: root.u * 5
                anchors.right: go.left
                anchors.rightMargin: root.u * 3
                height: parent.height
                readonly property real step: Math.min(root.u * 7, width / Math.max(1, pw.text.length))
                Repeater {
                    model: pw.text.length
                    PixelIcon {
                        id: dot
                        required property int index
                        name: "heartSmall"
                        pixel: root.u
                        ink: "transparent"
                        fill: "#ffffff"
                        x: index * dots.step
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: g.busy ? Math.round(Math.sin(g.secs * 9 + index) * root.u * 2) : 0
                        property real pop: 1
                        scale: 1 + pop * 0.8
                        opacity: 1 - pop * 0.5
                        NumberAnimation on pop {
                            from: 1
                            to: 0
                            duration: 140
                        }
                    }
                }
                Text {
                    visible: pw.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: g.t("пароль", "password")
                    color: Qt.rgba(1, 1, 1, 0.55)
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
                anchors.right: parent.right
                anchors.rightMargin: root.u * 4
                anchors.verticalCenter: parent.verticalCenter
                width: root.u * 18
                height: width
                radius: width / 2
                color: gm.containsMouse ? Qt.lighter(root.pal.accent, 1.15) : root.pal.accent
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
        // the small print: the session, the layout, what happened
        Text {
            x: root.u * 6
            text: [g.busy ? g.t("проверяю…", "checking…") : g.live ? g.t("добро пожаловать ♡", "welcome ♡") : g.fails > 0 && breakTimer.running ? g.t("не тот пароль", "wrong password") : "", g.sessionCount > 0 ? g.sessionShown + (g.sessionCount > 1 ? " ▸" : "") : "", g.layoutShort, g.caps ? "CAPS LOCK" : ""].filter(s => s !== "").join("   ·   ")
            color: g.fails > 0 && breakTimer.running ? Qt.lighter(root.pal.danger, 1.2) : Qt.rgba(1, 1, 1, 0.7)
            font.family: g.bodyFont
            font.pixelSize: g.bodyPx(13)
            renderType: Text.NativeRendering
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    g.nextSession();
                    pw.forceActiveFocus();
                }
            }
        }
    }
    Timer {
        id: breakTimer
        interval: 2200
    }

    // ---- power: a small pill, bottom right ----
    Rectangle {
        visible: root.primary
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.m
        width: powerRow.implicitWidth + root.u * 10
        height: root.u * 20
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.12)
        border.width: Math.max(1, root.u / 2)
        border.color: Qt.rgba(1, 1, 1, 0.25)
        Row {
            id: powerRow
            anchors.centerIn: parent
            spacing: root.u * 6
            Repeater {
                model: g.power
                PixelIcon {
                    id: pi
                    required property var modelData
                    name: modelData.icon
                    pixel: root.u
                    ink: "#ffffff"
                    fill: pm.containsMouse ? root.pal.accent : "#ffffff"
                    light: "#ffffff"
                    opacity: pm.containsMouse ? 1 : 0.75
                    MouseArea {
                        id: pm
                        anchors.fill: parent
                        anchors.margins: -root.u * 3
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pi.modelData.run()
                    }
                }
            }
        }
    }

    // ---- the other screens: the clock alone ----
    Column {
        id: camMain
        objectName: "camMain"
        visible: !root.primary
        x: root.m
        y: root.height - height - root.m
        Text {
            text: g.clockText(false)
            color: "#ffffff"
            font.family: g.titleFont
            font.pixelSize: g.titlePx(108)
            renderType: Text.NativeRendering
        }
        Text {
            text: g.dateText()
            color: Qt.rgba(1, 1, 1, 0.85)
            font.family: g.titleFont
            font.pixelSize: g.titlePx(27)
            renderType: Text.NativeRendering
        }
    }

    // ---- what happens ----
    SequentialAnimation {
        id: shake
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
    Connections {
        target: g
        function onFailed() {
            shake.restart();
            breakTimer.restart();
            wall.ring(field, root.pal.danger, 1);
            pw.text = "";
            pw.forceActiveFocus();
        }
        function onSucceeded() {
            fade.restart();
        }
    }
    Rectangle {
        id: veil
        anchors.fill: parent
        color: "#000000"
        opacity: 0
        NumberAnimation on opacity {
            id: fade
            running: false
            to: 1
            duration: 900
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
