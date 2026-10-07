import QtQuick

// angelOS login, the "retro" look: angelOS 98. The wallpaper as a Y2K desktop with its
// icons, a taskbar with Start (sleep, restart, shut down) and the tray clock, and in the
// middle the logon dialog: the banner, "type your user name and password", OK / Clear /
// Shut Down…. A wrong password: the error box; a right one: "loading your settings…".
// Other screens: the desktop with the angelOS 98 screensaver drifting about.
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

    // ---- the desktop ----
    Wall {
        id: wall
        anchors.fill: parent
        g: g
        block: root.u * 4
        line: 0
        fallbackTop: root.pal.desk
        fallbackBottom: Qt.darker(root.pal.desk, 1.3)
    }
    Rectangle {
        anchors.fill: parent
        color: root.pal.desk
        opacity: wall.ready ? 0.35 : 0
    }

    component Btn: Bevel {
        id: b
        property string text: ""
        property bool isDefault: false
        signal clicked
        pal: root.pal
        u: root.u
        sunken: bm.pressed
        face: bm.containsMouse ? root.pal.faceAlt : root.pal.face
        width: Math.max(root.u * 44, label.implicitWidth + root.u * 14)
        height: root.u * 15
        Rectangle {
            visible: b.isDefault
            anchors.fill: parent
            anchors.margins: -root.u * 2
            color: "transparent"
            border.width: root.u
            border.color: root.pal.edge
        }
        Text {
            id: label
            anchors.centerIn: parent
            text: b.text
            color: root.pal.text
            font.family: g.bodyFont
            font.pixelSize: g.bodyPx(13)
            renderType: Text.NativeRendering
        }
        MouseArea {
            id: bm
            anchors.fill: parent
            hoverEnabled: true
            onClicked: b.clicked()
        }
    }
    component Caption: Text {
        color: root.pal.text
        font.family: g.bodyFont
        font.pixelSize: g.bodyPx(13)
        renderType: Text.NativeRendering
    }
    // a window: outline, bevel, the title bar in the title gradient
    component Win: Bevel {
        id: w
        property string title: ""
        property string icon: "heart"
        default property alias body: bodyArea.data
        property int barH: g.titlePx(18) + root.u * 6
        pal: root.pal
        u: root.u
        Rectangle {
            id: bar
            visible: w.barH > 0
            width: parent.width
            height: w.barH
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: root.pal.title1
                }
                GradientStop {
                    position: 1
                    color: root.pal.title2
                }
            }
            Row {
                x: root.u * 3
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.u * 3
                PixelIcon {
                    name: w.icon
                    pixel: root.u
                    ink: root.pal.edge
                    fill: "#ffffff"
                    light: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: w.title
                    color: root.pal.titleText
                    font.family: g.titleFont
                    font.pixelSize: g.titlePx(18)
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: root.u * 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.u
                Repeater {
                    model: ["?", "✕"]
                    Bevel {
                        id: tb
                        required property string modelData
                        pal: root.pal
                        u: root.u
                        width: root.u * 11
                        height: root.u * 10
                        Text {
                            anchors.centerIn: parent
                            text: tb.modelData
                            color: root.pal.text
                            font.family: g.titleFont
                            font.pixelSize: g.titlePx(9)
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }
        Item {
            id: bodyArea
            y: w.barH + root.u * 4
            x: root.u * 4
            width: parent.width - root.u * 8
            height: parent.height - y - root.u * 4
        }
    }

    // desktop icons down the left
    Column {
        x: root.u * 10
        y: root.u * 10
        spacing: root.u * 12
        Repeater {
            model: [
                {
                    "icon": "monitor",
                    "label": g.t("Мой компьютер", "My Computer")
                },
                {
                    "icon": "heart",
                    "label": "angelOS"
                },
                {
                    "icon": "chat",
                    "label": g.t("Чат.txt", "Chat.txt")
                },
                {
                    "icon": "ghost",
                    "label": g.t("Корзина", "Recycle Bin")
                }
            ]
            Column {
                required property var modelData
                spacing: root.u * 2
                width: root.u * 40
                PixelIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: parent.modelData.icon
                    pixel: root.u * 2
                    ink: root.pal.edge
                    fill: root.pal.accent
                    fill2: root.pal.accent2
                    light: "#ffffff"
                    body: root.pal.face
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: parent.modelData.label
                    color: "#ffffff"
                    style: Text.Outline
                    styleColor: root.pal.edge
                    font.family: g.bodyFont
                    font.pixelSize: g.bodyPx(13)
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    // ---- the logon dialog ----
    Win {
        id: dialog
        objectName: "center"
        visible: root.primary
        title: g.t("Вход в angelOS", "Log On to angelOS")
        icon: "lock"
        width: Math.min(root.u * 230, root.width - root.u * 20)
        height: barH + root.u * 8 + banner.height + form.implicitHeight + root.u * 14
        x: Math.round((root.width - width) / 2) + shakeX
        y: Math.round((root.height - taskbar.height - height) / 2)
        property real shakeX: 0

        // the banner: angelOS 98 on the title gradient, little hearts, a rule under it
        Rectangle {
            id: banner
            width: parent.width
            height: root.u * 42
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Qt.darker(root.pal.title1, 1.25)
                }
                GradientStop {
                    position: 1
                    color: Qt.darker(root.pal.title2, 1.4)
                }
            }
            Repeater {
                model: 9
                PixelIcon {
                    required property int index
                    name: index % 2 ? "heartSmall" : "sparkle"
                    pixel: root.u
                    ink: "transparent"
                    fill: "#ffffff"
                    fill2: "#ffffff"
                    light: "#ffffff"
                    opacity: 0.25 + 0.5 * Math.abs(Math.sin(g.secs * 0.8 + index))
                    x: Math.round(banner.width * (0.45 + (index * 0.137) % 0.5))
                    y: Math.round(banner.height * ((index * 0.29) % 0.8 + 0.08))
                }
            }
            Row {
                x: root.u * 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.u * 5
                PixelIcon {
                    name: "heart"
                    pixel: root.u * 2
                    ink: root.pal.edge
                    fill: root.pal.accent
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Row {
                        spacing: root.u * 2
                        Text {
                            text: "angelOS"
                            color: "#ffffff"
                            font.family: g.titleFont
                            font.pixelSize: g.titlePx(36)
                            font.bold: true
                            renderType: Text.NativeRendering
                        }
                        Text {
                            text: "98"
                            color: root.pal.accent3
                            font.family: g.titleFont
                            font.pixelSize: g.titlePx(27)
                            font.bold: true
                            anchors.baseline: parent.children[0].baseline
                            renderType: Text.NativeRendering
                        }
                    }
                    Text {
                        text: "Internet Angel Edition ♡"
                        color: Qt.rgba(1, 1, 1, 0.8)
                        font.family: g.bodyFont
                        font.pixelSize: g.bodyPx(13)
                        renderType: Text.NativeRendering
                    }
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: root.u
                color: root.pal.edge
            }
        }

        Column {
            id: form
            y: banner.height + root.u * 8
            width: parent.width
            spacing: root.u * 6

            Row {
                spacing: root.u * 6
                PixelIcon {
                    name: "lock"
                    pixel: root.u * 2
                    ink: root.pal.edge
                    fill: root.pal.accent3
                    light: "#ffffff"
                }
                Caption {
                    width: form.width - root.u * 30
                    wrapMode: Text.Wrap
                    anchors.verticalCenter: parent.verticalCenter
                    text: g.t("Введите пароль для входа в angelOS. Сердечки вместо букв — так задумано ♡", "Type your password to log on to angelOS. Hearts instead of letters, on purpose ♡")
                }
            }

            Row {
                spacing: root.u * 8
                Column {
                    id: fields
                    spacing: root.u * 4
                    width: form.width - buttons.width - root.u * 8
                    readonly property int labelW: root.u * 48
                    // user: click to take the next one
                    Row {
                        spacing: root.u * 3
                        Caption {
                            width: fields.labelW
                            text: g.t("Пользователь:", "User name:")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Bevel {
                            pal: root.pal
                            u: root.u
                            sunken: true
                            face: root.pal.sunken
                            width: fields.width - fields.labelW - root.u * 3
                            height: root.u * 15
                            Caption {
                                anchors.verticalCenter: parent.verticalCenter
                                text: g.login
                            }
                            Caption {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: g.userCount > 1
                                text: "▾"
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    g.nextUser(1);
                                    pw.forceActiveFocus();
                                }
                            }
                        }
                    }
                    Row {
                        spacing: root.u * 3
                        Caption {
                            width: fields.labelW
                            text: g.t("Пароль:", "Password:")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Bevel {
                            id: field
                            pal: root.pal
                            u: root.u
                            sunken: true
                            face: root.pal.sunken
                            width: fields.width - fields.labelW - root.u * 3
                            height: root.u * 15
                            clip: true
                            readonly property real step: Math.min(root.u * 8, (width - root.u * 10) / Math.max(1, pw.text.length))
                            Repeater {
                                model: pw.text.length
                                PixelIcon {
                                    required property int index
                                    name: "heartSmall"
                                    pixel: root.u
                                    ink: root.pal.edge
                                    fill: index % 3 === 2 ? root.pal.accent2 : root.pal.accent
                                    x: index * field.step
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Rectangle {
                                x: pw.text.length * field.step + root.u
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.u
                                height: root.u * 8
                                color: root.pal.text
                                visible: pw.activeFocus && !g.busy && !errorBox.visible && Math.floor(g.secs * 2) % 2 === 0
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
                                readOnly: g.busy || errorBox.visible
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
                    }
                    Row {
                        spacing: root.u * 3
                        visible: g.sessionCount > 0
                        Caption {
                            width: fields.labelW
                            text: g.t("Сеанс:", "Session:")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Bevel {
                            pal: root.pal
                            u: root.u
                            sunken: true
                            face: root.pal.sunken
                            width: fields.width - fields.labelW - root.u * 3
                            height: root.u * 15
                            Caption {
                                anchors.verticalCenter: parent.verticalCenter
                                text: g.sessionShown
                            }
                            Caption {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: g.sessionCount > 1
                                text: "▾"
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    g.nextSession();
                                    pw.forceActiveFocus();
                                }
                            }
                        }
                    }
                    Row {
                        spacing: root.u * 6
                        Caption {
                            visible: g.layoutShort !== ""
                            text: g.t("Раскладка: ", "Layout: ") + g.layoutShort
                            color: root.pal.textDim
                        }
                        Caption {
                            visible: g.caps
                            text: "CAPS LOCK"
                            color: root.pal.danger
                        }
                        Caption {
                            visible: g.busy
                            text: g.t("проверка…", "checking…")
                            color: root.pal.textDim
                        }
                    }
                }
                Column {
                    id: buttons
                    spacing: root.u * 4
                    Btn {
                        text: g.t("ОК", "OK")
                        isDefault: true
                        onClicked: g.submit(pw.text)
                    }
                    Btn {
                        text: g.t("Очистить", "Clear")
                        onClicked: {
                            pw.text = "";
                            pw.forceActiveFocus();
                        }
                    }
                    Btn {
                        text: g.t("Выключение…", "Shut Down…")
                        onClicked: shutdown.visible = true
                    }
                }
            }
        }

        // loading your settings: segments filling a bar
        Rectangle {
            anchors.fill: parent
            visible: g.live
            color: root.pal.face
            Column {
                anchors.centerIn: parent
                spacing: root.u * 6
                Caption {
                    text: g.t("Загрузка личных параметров…", "Loading your personal settings…")
                }
                Bevel {
                    pal: root.pal
                    u: root.u
                    sunken: true
                    width: root.u * 150
                    height: root.u * 14
                    Row {
                        spacing: root.u
                        Repeater {
                            model: Math.min(20, Math.floor(loadTick.n))
                            Rectangle {
                                width: root.u * 6
                                height: root.u * 8
                                color: root.pal.accent
                            }
                        }
                    }
                }
            }
            Timer {
                id: loadTick
                property real n: 0
                interval: 70
                repeat: true
                running: g.live
                onTriggered: n += 1
            }
        }
    }

    // the error box (a wrong password)
    Win {
        id: errorBox
        visible: false
        title: g.t("Ошибка входа", "Logon Message")
        icon: "lock"
        width: Math.min(root.u * 190, root.width - root.u * 20)
        height: barH + root.u * 62
        x: Math.round((root.width - width) / 2)
        y: Math.round(dialog.y + dialog.height * 0.35)
        z: 5
        Row {
            spacing: root.u * 6
            Rectangle {
                width: root.u * 18
                height: width
                radius: width / 2
                color: root.pal.danger
                border.width: root.u
                border.color: root.pal.edge
                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: "#ffffff"
                    font.family: g.titleFont
                    font.pixelSize: g.titlePx(18)
                    font.bold: true
                    renderType: Text.NativeRendering
                }
            }
            Caption {
                width: errorBox.width - root.u * 40
                wrapMode: Text.Wrap
                text: g.fails > 2 ? g.t("Пароль снова не подошёл. Проверьте раскладку (" + g.layoutShort + ") и Caps Lock — ангел верит в вас.", "Still not it. Check the layout (" + g.layoutShort + ") and Caps Lock — the angel believes in you.") : g.t("Система не может войти: неверный пароль. Буквы пароля вводятся с учётом регистра.", "The system could not log you on: the password is incorrect. Letters in passwords are case-sensitive.")
            }
        }
        Btn {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: g.t("ОК", "OK")
            isDefault: true
            onClicked: {
                errorBox.visible = false;
                pw.forceActiveFocus();
            }
        }
    }

    // the shut-down box
    Win {
        id: shutdown
        visible: false
        title: g.t("Завершение работы angelOS", "Shut Down angelOS")
        icon: "power"
        width: Math.min(root.u * 190, root.width - root.u * 20)
        height: barH + root.u * 30 + choices.height
        x: Math.round((root.width - width) / 2)
        y: Math.round(dialog.y + root.u * 30)
        z: 6
        property int pick: g.power.length - 1
        Column {
            id: choices
            spacing: root.u * 3
            Caption {
                text: g.t("Что сделать с компьютером?", "What do you want the computer to do?")
            }
            Repeater {
                model: g.power
                Row {
                    id: choice
                    required property var modelData
                    required property int index
                    spacing: root.u * 4
                    Rectangle {
                        width: root.u * 8
                        height: width
                        radius: width / 2
                        color: root.pal.sunken
                        border.width: root.u
                        border.color: root.pal.edge
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            visible: shutdown.pick === choice.index
                            anchors.centerIn: parent
                            width: root.u * 3
                            height: width
                            color: root.pal.accent
                        }
                    }
                    Caption {
                        text: choice.modelData.label.charAt(0).toUpperCase() + choice.modelData.label.slice(1)
                        MouseArea {
                            anchors.fill: parent
                            onClicked: shutdown.pick = choice.index
                        }
                    }
                }
            }
        }
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: root.u * 4
            Btn {
                text: g.t("ОК", "OK")
                isDefault: true
                onClicked: {
                    shutdown.visible = false;
                    if (g.power[shutdown.pick])
                        g.power[shutdown.pick].run();
                }
            }
            Btn {
                text: g.t("Отмена", "Cancel")
                onClicked: {
                    shutdown.visible = false;
                    pw.forceActiveFocus();
                }
            }
        }
    }

    // ---- the taskbar ----
    Bevel {
        id: taskbar
        pal: root.pal
        u: root.u
        outline: false
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.u * 21
        Bevel {
            id: startBtn
            pal: root.pal
            u: root.u
            sunken: startMenu.visible
            width: startRow.implicitWidth + root.u * 12
            height: parent.height
            Row {
                id: startRow
                anchors.centerIn: parent
                spacing: root.u * 3
                PixelIcon {
                    name: "heart"
                    pixel: root.u
                    ink: root.pal.edge
                    fill: root.pal.accent
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: g.t("Пуск", "Start")
                    color: root.pal.text
                    font.family: g.titleFont
                    font.pixelSize: g.titlePx(18)
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: startMenu.visible = !startMenu.visible
            }
        }
        // the one task: the logon itself
        Bevel {
            visible: root.primary
            pal: root.pal
            u: root.u
            sunken: true
            face: root.pal.faceAlt
            x: startBtn.width + root.u * 6
            width: Math.min(root.u * 110, parent.width * 0.3)
            height: parent.height
            Row {
                spacing: root.u * 3
                anchors.verticalCenter: parent.verticalCenter
                PixelIcon {
                    name: "lock"
                    pixel: root.u
                    ink: root.pal.edge
                    fill: root.pal.accent3
                    anchors.verticalCenter: parent.verticalCenter
                }
                Caption {
                    text: dialog.title
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        // the tray: layout, Caps, the clock
        Bevel {
            pal: root.pal
            u: root.u
            sunken: true
            anchors.right: parent.right
            width: tray.implicitWidth + root.u * 12
            height: parent.height
            Row {
                id: tray
                anchors.centerIn: parent
                spacing: root.u * 5
                Caption {
                    visible: g.layoutShort !== ""
                    text: g.layoutShort
                    color: root.pal.textDim
                }
                PixelIcon {
                    name: "heartSmall"
                    pixel: root.u
                    ink: root.pal.edge
                    fill: root.pal.accent
                    anchors.verticalCenter: parent.verticalCenter
                }
                Caption {
                    text: g.clockText(false)
                }
            }
        }
    }
    // Start: a banner up the side, the power items
    Win {
        id: startMenu
        visible: false
        title: ""
        icon: "heart"
        barH: 0
        width: root.u * 120
        height: g.power.length * root.u * 20 + root.u * 12
        x: 0
        y: taskbar.y - height
        z: 7
        Rectangle {
            x: -root.u * 4
            y: -root.u * 4
            width: root.u * 18
            height: startMenu.height - root.u * 8
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: root.pal.title2
                }
                GradientStop {
                    position: 1
                    color: root.pal.title1
                }
            }
            Text {
                anchors.centerIn: parent
                rotation: -90
                text: "angelOS 98"
                color: "#ffffff"
                font.family: g.titleFont
                font.pixelSize: g.titlePx(18)
                font.bold: true
                renderType: Text.NativeRendering
            }
        }
        Column {
            x: root.u * 18
            width: parent.width - x
            Repeater {
                model: g.power
                Rectangle {
                    id: item
                    required property var modelData
                    width: parent.width
                    height: root.u * 20
                    color: im.containsMouse ? root.pal.accent : "transparent"
                    Row {
                        x: root.u * 4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.u * 5
                        PixelIcon {
                            name: item.modelData.icon
                            pixel: root.u
                            ink: root.pal.edge
                            fill: root.pal.accent2
                            light: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Caption {
                            text: item.modelData.label.charAt(0).toUpperCase() + item.modelData.label.slice(1)
                            color: im.containsMouse ? "#ffffff" : root.pal.text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: im
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: item.modelData.run()
                    }
                }
            }
        }
    }

    // ---- the other screens: angelOS 98 drifting about, the clock under it ----
    Item {
        id: camMain
        objectName: "camMain"
        visible: !root.primary
        width: saver.width
        height: saver.height
        // bounces off the edges (above the taskbar)
        readonly property real rangeX: Math.max(1, root.width - width)
        readonly property real rangeY: Math.max(1, root.height - taskbar.height - height)
        function bounce(t, range) {
            const p = t % (2 * range);
            return p < range ? p : 2 * range - p;
        }
        x: Math.round(bounce(g.secs * root.u * 30, rangeX))
        y: Math.round(bounce(g.secs * root.u * 21 + rangeY * 0.4, rangeY))
        Column {
            id: saver
            spacing: root.u * 4
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.u * 4
                PixelIcon {
                    name: "heart"
                    pixel: root.u * 3
                    ink: root.pal.edge
                    fill: Qt.hsla((g.secs * 0.05) % 1, 0.8, 0.7, 1)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "angelOS 98"
                    color: "#ffffff"
                    style: Text.Outline
                    styleColor: root.pal.edge
                    font.family: g.titleFont
                    font.pixelSize: g.titlePx(54)
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: g.clockText(true) + " · " + g.dateText()
                color: "#ffffff"
                style: Text.Outline
                styleColor: root.pal.edge
                font.family: g.titleFont
                font.pixelSize: g.titlePx(18)
                renderType: Text.NativeRendering
            }
        }
    }

    // ---- what happens ----
    SequentialAnimation {
        id: shake
        loops: 3
        NumberAnimation {
            target: dialog
            property: "shakeX"
            to: root.u * 5
            duration: 40
        }
        NumberAnimation {
            target: dialog
            property: "shakeX"
            to: -root.u * 5
            duration: 40
        }
        NumberAnimation {
            target: dialog
            property: "shakeX"
            to: 0
            duration: 40
        }
    }
    Connections {
        target: g
        function onFailed() {
            shake.restart();
            pw.text = "";
            errorBox.visible = true;
            okFocus.forceActiveFocus();
        }
    }
    // Enter or Esc closes the error box, like the real one
    Item {
        id: okFocus
        Keys.onPressed: e => {
            if (errorBox.visible && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Escape || e.key === Qt.Key_Space)) {
                errorBox.visible = false;
                pw.forceActiveFocus();
                e.accepted = true;
            }
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
        onClicked: {
            startMenu.visible = false;
            if (!errorBox.visible)
                pw.forceActiveFocus();
        }
    }
}
