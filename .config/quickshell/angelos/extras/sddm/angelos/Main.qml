import QtQuick
import QtQuick.Window

// angelOS login (SDDM): the lock screen's look before anyone has logged in — the NGO
// stream that is "starting soon". The pixelated wallpaper, floating hearts, the angelOS
// wordmark and clock, the login window ("login.exe") whose password turns into pixel
// hearts, a waiting chat, and the power buttons. Colours, wallpaper and language come
// from theme.conf, written by `angelos sddm install` from the desktop's own theme.
Rectangle {
    id: root

    width: Screen.width
    height: Screen.height
    color: pal.desk

    // ---- the theme's settings (theme.conf), with angelOS's NGO defaults ----
    function conf(key, fallback) {
        const v = typeof config !== "undefined" && config ? config[key] : undefined;
        return v === undefined || v === null || String(v) === "" ? fallback : String(v);
    }
    readonly property var pal: ({
            "desk": conf("desk", "#2a1b3d"),
            "face": conf("face", "#3a2350"),
            "faceAlt": conf("faceAlt", "#4a2c66"),
            "sunken": conf("sunken", "#1d1230"),
            "edge": conf("edge", "#140c20"),
            "hi": conf("hi", "#5c3a80"),
            "lo": conf("lo", "#1d1230"),
            "text": conf("text", "#fdf3ff"),
            "textDim": conf("textDim", "#c7b2d8"),
            "titleText": conf("titleText", "#ffffff"),
            "accent": conf("accent", "#ff5fa2"),
            "accent2": conf("accent2", "#c9a0ff"),
            "accent3": conf("accent3", "#ffd36a"),
            "danger": conf("danger", "#ff4f6d"),
            "title1": conf("title1", "#ff5fa2"),
            "title2": conf("title2", "#c9a0ff")
        })
    readonly property bool ru: conf("language", Qt.locale().name.indexOf("ru") === 0 ? "ru" : "en") === "ru"
    function t(r, e) {
        return ru ? r : e;
    }
    // window titles end the way the desktop's do (Settings → Appearance: exe, sh or bin)
    readonly property string suffix: ["exe", "sh", "bin"].indexOf(conf("suffix", "")) >= 0 ? conf("suffix", "") : "exe"
    function exe(name) {
        return name + "." + suffix;
    }
    // one art pixel: 2 on 1080p, 3 on 1440p, 4 on 4K
    readonly property int u: Math.max(1, Math.round(height / 540))
    readonly property string titleFont: titleLoader.status === FontLoader.Ready ? titleLoader.name : "monospace"
    readonly property string bodyFont: bodyLoader.status === FontLoader.Ready ? bodyLoader.name : titleFont
    // pixel fonts are sharp only at whole multiples of their cell
    function titlePx(n) {
        return 9 * Math.max(1, Math.round(n * u / 2 / 9));
    }
    function bodyPx(n) {
        return 13 * Math.max(1, Math.round(n * u / 2 / 13));
    }
    readonly property bool primary: typeof primaryScreen === "undefined" ? true : !!primaryScreen

    FontLoader {
        id: titleLoader
        source: Qt.resolvedUrl("fonts/PixeloidSans.ttf")
    }
    FontLoader {
        id: bodyLoader
        source: Qt.resolvedUrl("fonts/CozetteVector.ttf")
    }

    // ---- who and what ----
    property int userIndex: typeof userModel !== "undefined" && userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    readonly property int userCount: typeof userModel !== "undefined" ? userModel.count || userModel.rowCount() : 0
    readonly property int sessionCount: typeof sessionModel !== "undefined" ? sessionModel.rowCount() : 0
    ListView {
        id: users
        // never seen, but sized: a ListView of no size makes no delegates to read
        width: 100
        height: 100
        opacity: 0
        enabled: false
        model: typeof userModel !== "undefined" ? userModel : null
        currentIndex: root.userIndex
        delegate: Item {
            required property string name
            required property string realName
            required property string icon
            property string login: name
            property string shown: realName || name
            property string face: icon
        }
    }
    ListView {
        id: sessions
        // never seen, but sized: a ListView of no size makes no delegates to read
        width: 100
        height: 100
        opacity: 0
        enabled: false
        model: typeof sessionModel !== "undefined" ? sessionModel : null
        currentIndex: root.sessionIndex
        delegate: Item {
            required property string name
            property string shown: name
        }
    }
    readonly property string login: users.currentItem ? users.currentItem.login : (typeof userModel !== "undefined" ? userModel.lastUser : "")
    readonly property string userShown: users.currentItem ? users.currentItem.shown : login
    readonly property string sessionShown: sessions.currentItem ? sessions.currentItem.shown : ""
    readonly property string layoutShort: {
        if (typeof keyboard === "undefined" || !keyboard || !keyboard.layouts || keyboard.layouts.length === 0)
            return "";
        const l = keyboard.layouts[keyboard.currentLayout];
        return l ? String(l.shortName || "").toUpperCase() : "";
    }
    readonly property bool caps: typeof keyboard !== "undefined" && keyboard ? !!keyboard.capsLock : false

    property bool busy: false
    property bool live: false
    property int fails: 0
    property string status: ""

    function submit() {
        if (busy)
            return;
        busy = true;
        status = t("проверяю…", "checking…");
        if (typeof sddm !== "undefined")
            sddm.login(root.login, pw.text, root.sessionIndex);
    }
    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        ignoreUnknownSignals: true
        function onLoginFailed() {
            root.busy = false;
            root.fails++;
            root.status = root.fails > 2 ? root.t("ну пожааалуйста, вспомни пароль…", "try your password again…") : root.t("неправильный пароль ✕", "incorrect password ✕");
            root.failed();
        }
        function onLoginSucceeded() {
            root.status = "";
            root.live = true;
            root.succeeded();
        }
    }
    signal failed
    signal succeeded

    // ---- background: the wallpaper in big pixels, hearts drifting up ----
    Image {
        id: wall
        anchors.fill: parent
        source: root.conf("background", "") !== "" ? Qt.resolvedUrl(root.conf("background", "")) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    ShaderEffect {
        anchors.fill: parent
        visible: wall.status === Image.Ready
        property var source: wall
        property real block: root.conf("pixelate", "true") === "true" ? root.u * 8 : 1
        property size resolution: Qt.size(width, height)
        fragmentShader: Qt.resolvedUrl("pixelate.frag.qsb")
    }
    Rectangle {
        anchors.fill: parent
        visible: wall.status !== Image.Ready
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.darker(root.pal.title1, 1.6)
            }
            GradientStop {
                position: 1
                color: Qt.darker(root.pal.title2, 1.8)
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        color: root.pal.desk
        opacity: 0.35
    }
    property real time: 0
    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: root.time += 0.05
    }
    Repeater {
        model: 20
        PixelIcon {
            required property int index
            name: index % 3 ? "heart" : "heartSmall"
            pixel: root.u * (index % 4 === 0 ? 2 : 1)
            ink: root.pal.edge
            fill: index % 2 ? root.pal.accent : root.pal.accent2
            opacity: 0.18 + (index % 5) * 0.07
            readonly property real speed: 10 + (index * 7) % 18
            x: Math.round((((index * 0.173 + 0.04) % 1) * root.width + Math.sin(root.time * 0.6 + index) * root.u * 8) / root.u) * root.u
            y: Math.round((root.height + 40 - ((root.time * speed * root.u + index * 97) % (root.height + 80))) / root.u) * root.u
        }
    }

    // ---- top left: the stream that is about to start ----
    Row {
        visible: root.primary
        x: root.u * 10
        y: root.u * 10
        spacing: root.u * 4
        Rectangle {
            width: soon.implicitWidth + root.u * 10
            height: root.u * 15
            color: root.live ? root.pal.danger : root.pal.face
            border.width: root.u
            border.color: root.pal.edge
            Row {
                id: soon
                anchors.centerIn: parent
                spacing: root.u * 3
                Rectangle {
                    width: root.u * 4
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.live ? "#ffffff" : root.pal.accent
                    opacity: Math.floor(root.time * 1.7) % 2 ? 1 : 0.25
                }
                Text {
                    text: root.live ? root.t("В ЭФИРЕ", "LIVE") : root.t("СКОРО ЭФИР", "STARTING SOON")
                    color: root.live ? "#ffffff" : root.pal.text
                    font.family: root.titleFont
                    font.pixelSize: root.titlePx(9)
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.conf("streamTitle", "") || root.t("стрим начнётся, как только ангел войдёт ♡", "the stream starts once angel logs in ♡")
            color: "#ffffff"
            style: Text.Outline
            styleColor: root.pal.edge
            font.family: root.bodyFont
            font.pixelSize: root.bodyPx(13)
            renderType: Text.NativeRendering
        }
    }

    // ---- top right: power ----
    Row {
        visible: root.primary
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: root.u * 10
        spacing: root.u * 4
        Repeater {
            model: [
                {
                    "icon": "moon",
                    "label": root.t("сон", "sleep"),
                    "can": typeof sddm !== "undefined" && sddm.canSuspend,
                    "run": () => sddm.suspend()
                },
                {
                    "icon": "refresh",
                    "label": root.t("перезагрузка", "restart"),
                    "can": typeof sddm !== "undefined" && sddm.canReboot,
                    "run": () => sddm.reboot()
                },
                {
                    "icon": "power",
                    "label": root.t("выключение", "shut down"),
                    "can": typeof sddm !== "undefined" && sddm.canPowerOff,
                    "run": () => sddm.powerOff()
                }
            ].filter(b => b.can || typeof sddm === "undefined")
            Rectangle {
                id: pbtn
                required property var modelData
                width: root.u * 17 + (hover.containsMouse ? plabel.implicitWidth + root.u * 4 : 0)
                height: root.u * 17
                color: hover.containsMouse ? root.pal.accent : root.pal.face
                border.width: root.u
                border.color: root.pal.edge
                Row {
                    anchors.centerIn: parent
                    spacing: root.u * 3
                    PixelIcon {
                        name: pbtn.modelData.icon
                        pixel: root.u
                        ink: hover.containsMouse ? "#ffffff" : root.pal.text
                        fill: hover.containsMouse ? "#ffffff" : root.pal.accent
                        light: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id: plabel
                        visible: hover.containsMouse
                        text: pbtn.modelData.label
                        color: "#ffffff"
                        font.family: root.bodyFont
                        font.pixelSize: root.bodyPx(13)
                        anchors.verticalCenter: parent.verticalCenter
                        renderType: Text.NativeRendering
                    }
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pbtn.modelData.run()
                }
            }
        }
    }

    // ---- the middle: wordmark, clock, the login window ----
    Column {
        id: center
        anchors.centerIn: parent
        spacing: root.u * 8

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.u * 4
            PixelIcon {
                name: "heart"
                pixel: root.u * 2
                ink: root.pal.edge
                fill: root.pal.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "angel"
                color: "#ffffff"
                style: Text.Outline
                styleColor: root.pal.edge
                font.family: root.titleFont
                font.pixelSize: root.titlePx(36)
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.NativeRendering
            }
            Rectangle {
                width: os.implicitWidth + root.u * 6
                height: os.implicitHeight + root.u * 2
                color: root.pal.accent
                border.width: root.u
                border.color: root.pal.edge
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    id: os
                    anchors.centerIn: parent
                    text: "OS"
                    color: "#ffffff"
                    font.family: root.titleFont
                    font.pixelSize: root.titlePx(36)
                    renderType: Text.NativeRendering
                }
            }
        }
        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            property date now: new Date()
            Timer {
                interval: 1000
                repeat: true
                running: true
                onTriggered: clock.now = new Date()
            }
            text: Qt.formatTime(now, "HH") + (now.getSeconds() % 2 ? ":" : " ") + Qt.formatTime(now, "mm")
            color: "#ffffff"
            style: Text.Outline
            styleColor: root.pal.edge
            font.family: root.titleFont
            font.pixelSize: root.titlePx(72)
            renderType: Text.NativeRendering
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale(root.ru ? "ru_RU" : "en_US").toString(clock.now, "dddd, d MMMM")
            color: "#ffffff"
            style: Text.Outline
            styleColor: root.pal.edge
            font.family: root.titleFont
            font.pixelSize: root.titlePx(18)
            renderType: Text.NativeRendering
        }

        PxFrame {
            id: win
            visible: root.primary
            anchors.horizontalCenter: parent.horizontalCenter
            pal: root.pal
            u: root.u * 3 / 2 >= 3 ? Math.round(root.u * 1.5) : root.u + 1
            font: root.titleFont
            fontSize: root.titlePx(27)
            title: root.exe(root.t("вход", "login"))
            icon: "lock"
            width: win.u * 175
            height: win.titleHeight + form.implicitHeight + win.u * 20
            property real shakeX: 0
            transform: Translate {
                x: win.shakeX
            }

            Column {
                id: form
                width: parent.width
                spacing: win.u * 5

                // who: the avatar, the name, ◀ ▶ for another user
                Row {
                    spacing: win.u * 5
                    Rectangle {
                        width: win.u * 26
                        height: win.u * 26
                        color: root.pal.sunken
                        border.width: win.u
                        border.color: root.pal.edge
                        Image {
                            id: face
                            anchors.fill: parent
                            anchors.margins: win.u
                            source: users.currentItem && users.currentItem.face ? users.currentItem.face : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                            smooth: false
                        }
                        PixelIcon {
                            id: bigHeart
                            visible: face.status !== Image.Ready
                            anchors.centerIn: parent
                            name: root.fails > 0 && breakTimer.running ? "heartBroken" : "heart"
                            pixel: win.u * 2
                            ink: root.pal.edge
                            fill: name === "heartBroken" ? root.pal.danger : root.pal.accent
                            scale: beat.running ? 1.15 : 1
                        }
                        Timer {
                            id: beat
                            interval: 80
                        }
                        Timer {
                            id: breakTimer
                            interval: 1400
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: win.u
                        Row {
                            spacing: win.u * 3
                            Text {
                                text: (new Date().getHours() < 5 ? root.t("доброй ночи", "good night") : new Date().getHours() < 12 ? root.t("доброе утро", "good morning") : new Date().getHours() < 18 ? root.t("добрый день", "good afternoon") : root.t("добрый вечер", "good evening")) + ", " + root.userShown + " ♡"
                                color: root.pal.text
                                font.family: root.titleFont
                                font.pixelSize: root.titlePx(18)
                                renderType: Text.NativeRendering
                            }
                        }
                        Row {
                            spacing: win.u * 3
                            visible: root.userCount > 1
                            Repeater {
                                model: [-1, 1]
                                Rectangle {
                                    required property int modelData
                                    width: win.u * 11
                                    height: win.u * 11
                                    color: um.containsMouse ? root.pal.accent : root.pal.faceAlt
                                    border.width: Math.max(1, win.u / 2)
                                    border.color: root.pal.edge
                                    PixelIcon {
                                        anchors.centerIn: parent
                                        name: modelData < 0 ? "arrowLeft" : "arrowRight"
                                        pixel: Math.max(1, Math.round(win.u / 2))
                                        ink: root.pal.text
                                        fill: root.pal.text
                                    }
                                    MouseArea {
                                        id: um
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            root.userIndex = (root.userIndex + modelData + root.userCount) % root.userCount;
                                            pw.forceActiveFocus();
                                        }
                                    }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.t("другой пользователь", "another user")
                                color: root.pal.textDim
                                font.family: root.bodyFont
                                font.pixelSize: root.bodyPx(13)
                                renderType: Text.NativeRendering
                            }
                        }
                        Text {
                            visible: root.userCount <= 1
                            text: root.t("с возвращением~", "welcome back~")
                            color: root.pal.textDim
                            font.family: root.bodyFont
                            font.pixelSize: root.bodyPx(13)
                            renderType: Text.NativeRendering
                        }
                    }
                }

                // the password: every character a pixel heart
                Row {
                    width: parent.width
                    spacing: win.u * 3
                    Rectangle {
                        id: field
                        width: parent.width - go.width - parent.spacing
                        height: win.u * 18
                        color: root.pal.sunken
                        border.width: win.u
                        border.color: root.fails > 0 && breakTimer.running ? root.pal.danger : flash.running ? root.pal.accent : Qt.tint(root.pal.edge, Qt.rgba(1, 0.37, 0.64, 0.4))
                        clip: true
                        Timer {
                            id: flash
                            interval: 90
                        }
                        // a long password never runs out of the field: small hearts, then closer
                        readonly property real room: Math.max(win.u * 20, width - win.u * 16)
                        readonly property bool small: pw.text.length * win.u * 11 > room
                        readonly property int glyphW: win.u * (small ? 5 : 9)
                        readonly property real step: small ? Math.min(win.u * 6, room / Math.max(1, pw.text.length)) : win.u * 11
                        Row {
                            id: hearts
                            x: win.u * 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Math.floor(field.step - field.glyphW)
                            Repeater {
                                model: pw.text.length
                                PixelIcon {
                                    id: h
                                    required property int index
                                    name: field.small ? "heartSmall" : root.fails > 0 && breakTimer.running ? "heartBroken" : "heart"
                                    pixel: win.u
                                    ink: root.pal.edge
                                    fill: index % 3 === 2 ? root.pal.accent2 : root.pal.accent
                                    y: root.busy ? Math.round(Math.sin(root.time * 12 + index) * win.u * 1.5) : 0
                                    property real drop: 1
                                    transform: Translate {
                                        y: -h.drop * win.u * 10
                                    }
                                    scale: 1 + h.drop * 0.7
                                    NumberAnimation on drop {
                                        from: 1
                                        to: 0
                                        duration: 140
                                        easing.type: Easing.OutBack
                                    }
                                }
                            }
                        }
                        Rectangle {
                            x: pw.text.length === 0 ? win.u * 6 : hearts.x + hearts.width + win.u * 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: win.u * 2
                            height: win.u * 9
                            color: root.pal.accent
                            visible: pw.activeFocus && !root.busy && Math.floor(root.time * 2) % 2 === 0
                        }
                        Text {
                            visible: pw.text.length === 0
                            x: win.u * 11
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.t("пароль ♡", "password ♡")
                            color: root.pal.textDim
                            font.family: root.bodyFont
                            font.pixelSize: root.bodyPx(13)
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
                            readOnly: root.busy
                            focus: true
                            onAccepted: root.submit()
                            onTextChanged: {
                                flash.restart();
                                beat.restart();
                            }
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
                        color: gm.containsMouse ? Qt.lighter(root.pal.accent, 1.15) : root.pal.accent
                        border.width: win.u
                        border.color: root.pal.edge
                        PixelIcon {
                            anchors.centerIn: parent
                            name: "arrowRight"
                            pixel: win.u
                            ink: "#ffffff"
                            fill: "#ffffff"
                        }
                        MouseArea {
                            id: gm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.submit()
                        }
                    }
                }

                // the session, the layout, Caps Lock
                Row {
                    spacing: win.u * 4
                    Rectangle {
                        visible: root.sessionCount > 0
                        width: sess.implicitWidth + win.u * 10
                        height: win.u * 12
                        color: sm.containsMouse ? root.pal.faceAlt : root.pal.face
                        border.width: Math.max(1, win.u / 2)
                        border.color: root.pal.edge
                        Text {
                            id: sess
                            anchors.centerIn: parent
                            text: root.t("сессия: ", "session: ") + root.sessionShown + (root.sessionCount > 1 ? "  ▸" : "")
                            color: root.pal.text
                            font.family: root.bodyFont
                            font.pixelSize: root.bodyPx(13)
                            renderType: Text.NativeRendering
                        }
                        MouseArea {
                            id: sm
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (root.sessionCount > 1)
                                    root.sessionIndex = (root.sessionIndex + 1) % root.sessionCount;
                                pw.forceActiveFocus();
                            }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.layoutShort !== ""
                        text: root.t("раскладка: ", "layout: ") + root.layoutShort
                        color: root.pal.textDim
                        font.family: root.bodyFont
                        font.pixelSize: root.bodyPx(13)
                        renderType: Text.NativeRendering
                    }
                    Rectangle {
                        visible: root.caps
                        width: capsText.implicitWidth + win.u * 8
                        height: win.u * 12
                        color: root.pal.danger
                        Text {
                            id: capsText
                            anchors.centerIn: parent
                            text: "CAPS LOCK"
                            color: "#ffffff"
                            font.family: root.titleFont
                            font.pixelSize: root.titlePx(9)
                            font.bold: true
                            renderType: Text.NativeRendering
                        }
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    visible: text !== ""
                    text: root.status
                    color: root.fails > 0 ? root.pal.danger : root.pal.textDim
                    font.family: root.bodyFont
                    font.pixelSize: root.bodyPx(13)
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    // ---- bottom right: the chat, waiting ----
    property var chat: []
    readonly property var waitLines: [t("стрим скоро начнётся ♡", "stream starting soon ♡"), t("первый!", "first!"), t("жду-жду", "waiting~"), t("ангел, просыпайся", "angel, wake up"), t("чай готов ☕", "tea's ready ☕"), "OMG kawaii", "♡♡♡", t("пароль не подсматриваем 👀", "no peeking 👀"), t("сегодня что-то будет", "something's happening today"), t("всем привет!", "hi everyone!"), "internet angel ✧", t("ставлю будильник", "setting an alarm")]
    readonly property var nicks: ["first_fan", "lurker404", "ame_fan", "pixel_angel", "kangel_love", "p-chan", "hikiko", "sugar_rush", "moe_moe", "pill_cat"]
    function say(lines, bot) {
        const m = {
            "nick": bot ? "angelbot" : nicks[Math.floor(Math.random() * nicks.length)],
            "text": lines[Math.floor(Math.random() * lines.length)],
            "bot": !!bot,
            "hue": Math.random()
        };
        chat = chat.concat([m]).slice(-7);
    }
    Component.onCompleted: {
        say([t("стрим начнётся после входа", "the stream starts after login")], true);
        say(waitLines);
    }
    Timer {
        interval: 2800
        repeat: true
        running: root.primary
        onTriggered: if (Math.random() < 0.7)
            root.say(root.waitLines)
    }
    PxFrame {
        visible: root.primary
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.u * 10
        pal: root.pal
        u: root.u
        font: root.titleFont
        fontSize: root.titlePx(9) < 13 ? 13 : root.titlePx(9)
        title: root.exe(root.t("чат", "chat"))
        icon: "chat"
        width: root.u * 150
        height: titleHeight + root.u * 13 * 7 + root.u * 18
        Column {
            width: parent.width
            anchors.bottom: parent.bottom
            spacing: root.u * 2
            Repeater {
                model: root.chat
                Row {
                    id: line
                    required property var modelData
                    spacing: root.u * 3
                    property real slide: 1
                    x: Math.round(slide * root.u * 20)
                    opacity: 1 - slide
                    NumberAnimation on slide {
                        from: 1
                        to: 0
                        duration: 160
                    }
                    Text {
                        text: (line.modelData.bot ? "✦ " : "") + line.modelData.nick + ":"
                        color: line.modelData.bot ? root.pal.accent : Qt.hsla(line.modelData.hue, 0.7, 0.7, 1)
                        font.family: root.bodyFont
                        font.pixelSize: root.bodyPx(13)
                        font.bold: true
                        renderType: Text.NativeRendering
                    }
                    Text {
                        text: line.modelData.text
                        color: root.pal.text
                        font.family: root.bodyFont
                        font.pixelSize: root.bodyPx(13)
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }

    // ---- the reactions ----
    SequentialAnimation {
        id: shake
        loops: 3
        NumberAnimation {
            target: win
            property: "shakeX"
            to: root.u * 6
            duration: 40
        }
        NumberAnimation {
            target: win
            property: "shakeX"
            to: -root.u * 6
            duration: 40
        }
        NumberAnimation {
            target: win
            property: "shakeX"
            to: 0
            duration: 40
        }
    }
    onFailed: {
        shake.restart();
        breakTimer.restart();
        pw.text = "";
        say(root.fails > 2 ? [t("капс? раскладка?", "caps? layout?")] : ["F", t("мимо", "miss"), t("бывает ♡", "it happens ♡")]);
        pw.forceActiveFocus();
    }
    onSucceeded: {
        say([t("УРА ♡ стрим начался!", "YAY ♡ we're live!")], true);
        stampAnim.restart();
    }
    Rectangle {
        id: stamp
        visible: pop > 0
        property real pop: 0
        scale: pop
        rotation: -6
        x: Math.round(center.x + win.x + win.width / 2 - width / 2)
        y: Math.round(center.y + win.y + win.height / 2 - height / 2)
        width: stampText.implicitWidth + root.u * 16
        height: stampText.implicitHeight + root.u * 10
        color: root.pal.accent
        border.width: root.u
        border.color: root.pal.edge
        Text {
            id: stampText
            anchors.centerIn: parent
            text: root.t("♡ В ЭФИРЕ ♡", "♡ ON AIR ♡")
            color: "#ffffff"
            style: Text.Outline
            styleColor: root.pal.edge
            font.family: root.titleFont
            font.pixelSize: root.titlePx(36)
            renderType: Text.NativeRendering
        }
        SequentialAnimation {
            id: stampAnim
            NumberAnimation {
                target: stamp
                property: "pop"
                from: 0
                to: 1.25
                duration: 120
            }
            NumberAnimation {
                target: stamp
                property: "pop"
                to: 1
                duration: 90
            }
        }
    }

    // the keys go to the password from the start, and after any click
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
