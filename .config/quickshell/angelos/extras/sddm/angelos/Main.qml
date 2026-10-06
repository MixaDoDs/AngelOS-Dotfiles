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
    // one art pixel: 2 on 1080p, 3 on 1440p, 4 on 4K — by the short side, so a 1080×1920
    // screen standing on its edge is a 1080p one too
    readonly property int u: Math.max(1, Math.round(Math.min(width, height) / 540))
    readonly property bool portrait: height > width * 1.1
    readonly property string titleFont: titleLoader.status === FontLoader.Ready ? titleLoader.name : "monospace"
    readonly property string bodyFont: bodyLoader.status === FontLoader.Ready ? bodyLoader.name : titleFont
    // pixel fonts are sharp only at whole multiples of their cell
    function titlePx(n) {
        return 9 * Math.max(1, Math.round(n * u / 2 / 9));
    }
    function bodyPx(n) {
        return 13 * Math.max(1, Math.round(n * u / 2 / 13));
    }
    // the login is on the primary screen; the others are the stream's second camera
    // (theme.conf role=login|cam pins it: a preview of one or the other)
    property bool primary: conf("role", "") === "cam" ? false : conf("role", "") === "login" ? true : typeof primaryScreen === "undefined" ? true : !!primaryScreen

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

    // ---- background: the wallpaper in big pixels, alive (shaders/sddm_wall), hearts drifting up ----
    // the desktop's own wallpaper for this screen's shape (walls/, kept in step by angelOS:
    // `angelos sddm walls`), else the other shape's, else the one copied at install
    readonly property var wallCandidates: {
        const own = portrait ? "walls/tall.jpg" : "walls/wide.jpg", other = portrait ? "walls/wide.jpg" : "walls/tall.jpg";
        return [own, other, conf("background", "")].filter(f => f !== "");
    }
    property int wallTry: 0
    Image {
        id: wall
        anchors.fill: parent
        source: root.wallTry < root.wallCandidates.length ? Qt.resolvedUrl(root.wallCandidates[root.wallTry]) : ""
        asynchronous: true
        cache: false
        visible: false
        onStatusChanged: if (status === Image.Error)
            root.wallTry++
    }
    // seconds, smooth (the shader and the second camera run on it)
    property real secs: 0
    NumberAnimation on secs {
        from: 0
        to: 3600
        duration: 3600 * 1000
        loops: Animation.Infinite
    }
    // the hour's light: violet night, pink dawn, clear day, orange-pink evening
    readonly property color hourTint: {
        const h = root.now.getHours();
        return h < 5 ? "#7a4cff" : h < 8 ? "#ff9ec7" : h < 17 ? "#ffffff" : h < 21 ? "#ff8a66" : "#a04cff";
    }
    readonly property real hourTintAmount: {
        const h = root.now.getHours();
        return h < 5 ? 0.24 : h < 8 ? 0.16 : h < 17 ? 0 : h < 21 ? 0.16 : 0.2;
    }
    ShaderEffect {
        id: wallFx
        anchors.fill: parent
        visible: wall.status === Image.Ready
        property var source: wall
        property real block: root.conf("pixelate", "true") === "true" ? root.u * 8 : 1
        property real line: root.u
        property real time: root.secs
        property size resolution: Qt.size(width, height)
        property size imgSize: Qt.size(Math.max(1, wall.implicitWidth), Math.max(1, wall.implicitHeight))
        property vector4d tint: Qt.vector4d(root.hourTint.r, root.hourTint.g, root.hourTint.b, root.hourTintAmount)
        // a key typed: a ring of pixels from the password; a mistake: a red one
        property vector4d ripple: Qt.vector4d(rippleAt.x, rippleAt.y, rippleAge, rippleAge < 1.4 ? rippleStrength : 0)
        property vector4d rippleColor: Qt.vector4d(rippleTint.r, rippleTint.g, rippleTint.b, 1)
        property point rippleAt: Qt.point(width / 2, height / 2)
        property real rippleAge: 9
        property real rippleStrength: 0.6
        property color rippleTint: root.pal.accent
        fragmentShader: Qt.resolvedUrl("sddm_wall.frag.qsb")
        function ring(item, color, strength) {
            if (item) {
                const p = item.mapToItem(wallFx, item.width / 2, item.height / 2);
                rippleAt = Qt.point(p.x, p.y);
            }
            rippleTint = color;
            rippleStrength = strength;
            ringAnim.restart();
        }
        NumberAnimation {
            id: ringAnim
            target: wallFx
            property: "rippleAge"
            from: 0
            to: 1.5
            duration: 1500
        }
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
    property date now: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
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
    Flow {
        id: topBar
        visible: root.primary
        x: root.u * 10
        y: root.u * 10
        // room up to the power buttons; on a narrow screen the title goes under the badge
        width: root.width - x - power.width - root.u * 18
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
            width: Math.min(implicitWidth, topBar.width)
            height: Math.max(implicitHeight, root.u * 15)
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
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
        id: power
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
    // landscape: in the middle; portrait: in the middle of what the top bar and the chat leave
    Column {
        id: center
        objectName: "center"
        visible: root.primary
        anchors.horizontalCenter: parent.horizontalCenter
        y: {
            if (!root.portrait)
                return Math.round((root.height - height) / 2);
            const top = topBar.y + topBar.height + root.u * 12, bottom = chatWin.y - root.u * 10;
            return Math.round(Math.max(top, top + (bottom - top - height) / 2));
        }
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
            text: Qt.formatTime(root.now, "HH") + (root.now.getSeconds() % 2 ? ":" : " ") + Qt.formatTime(root.now, "mm")
            color: "#ffffff"
            style: Text.Outline
            styleColor: root.pal.edge
            font.family: root.titleFont
            font.pixelSize: root.titlePx(72)
            renderType: Text.NativeRendering
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale(root.ru ? "ru_RU" : "en_US").toString(root.now, "dddd, d MMMM")
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
            objectName: "login"
            width: Math.min(win.u * 175, root.width - root.u * 20)
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
                                if (text.length > 0)
                                    wallFx.ring(field, root.pal.accent, 0.6);
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
    ListModel {
        id: chatModel
    }
    property alias chatModel: chatModel
    // the login screen's chat sits by the login; the second camera's has room
    readonly property int chatLines: portrait ? 11 : primary ? 7 : 14
    readonly property var waitLines: [t("стрим скоро начнётся ♡", "stream starting soon ♡"), t("первый!", "first!"), t("жду-жду", "waiting~"), t("ангел, просыпайся", "angel, wake up"), t("чай готов ☕", "tea's ready ☕"), "OMG kawaii", "♡♡♡", t("пароль не подсматриваем 👀", "no peeking 👀"), t("сегодня что-то будет", "something's happening today"), t("всем привет!", "hi everyone!"), "internet angel ✧", t("ставлю будильник", "setting an alarm")]
    readonly property var nicks: ["first_fan", "lurker404", "ame_fan", "pixel_angel", "kangel_love", "p-chan", "hikiko", "sugar_rush", "moe_moe", "pill_cat"]
    // a line not among the last few
    function fresh(lines) {
        let m = "";
        for (let i = 0; i < 6; i++) {
            m = lines[Math.floor(Math.random() * lines.length)];
            let seen = false;
            for (let j = Math.max(0, chatModel.count - 4); j < chatModel.count; j++)
                seen = seen || chatModel.get(j).msg === m;
            if (!seen)
                break;
        }
        return m;
    }
    function say(lines, bot) {
        chatModel.append({
            "nick": bot ? "angelbot" : nicks[Math.floor(Math.random() * nicks.length)],
            "msg": fresh(lines),
            "bot": !!bot,
            "hue": Math.random()
        });
        while (chatModel.count > chatLines)
            chatModel.remove(0);
    }
    readonly property var camLines: [t("тсс, ангел спит 💤", "shh, angel is asleep 💤"), t("второй кам лучший кам", "cam 2 best cam"), t("у неё крылья дёргаются", "her wings are twitching"), "zzz", t("какая милая", "so cute"), t("не будите!!", "don't wake her!!"), t("сколько она спит??", "how long has she been asleep??"), t("ASMR дыхания ангела", "angel breathing ASMR"), t("она приоткрыла глаз 👀", "she opened an eye 👀"), "♡♡♡", t("жду с самого утра", "been waiting since morning"), t("ангел, просыпайся", "angel, wake up")]
    // a chat that has been going for a while: the bot's line and a few viewers'
    // (a moment after start: the screen's role and theme.conf are known by then)
    Timer {
        interval: 150
        running: true
        onTriggered: {
            root.say([root.primary ? root.t("стрим начнётся после входа", "the stream starts after login") : root.t("камера 2: ангел ещё спит", "cam 2: angel is still asleep")], true);
            for (let i = 0; i < (root.portrait || !root.primary ? 5 : 3); i++)
                root.say(root.primary ? root.waitLines : root.camLines);
        }
    }
    Timer {
        interval: 2800
        repeat: true
        running: true
        onTriggered: if (Math.random() < 0.7)
            root.say(root.primary ? root.waitLines : root.camLines)
    }
    // landscape: bottom right; portrait: across the bottom, under the login window
    PxFrame {
        id: chatWin
        objectName: "chat"
        visible: root.primary
        x: root.portrait ? root.u * 10 : root.width - width - root.u * 10
        y: root.height - height - root.u * 10
        pal: root.pal
        u: root.u
        font: root.titleFont
        fontSize: root.titlePx(9) < 13 ? 13 : root.titlePx(9)
        title: root.exe(root.t("чат", "chat"))
        icon: "chat"
        width: root.portrait ? root.width - root.u * 20 : root.u * 150
        height: titleHeight + root.u * 13 * root.chatLines + root.u * 18
        ChatLines {
            theme: root
            width: parent.width
            anchors.bottom: parent.bottom
        }
    }

    // ---- the other screens: the stream's second camera, the angel asleep ----
    Item {
        id: cam
        objectName: "cam"
        visible: !root.primary
        anchors.fill: parent
        readonly property int m: root.u * 10
        property int viewers: 3 + Math.floor(Math.random() * 9)
        Timer {
            interval: 4000
            repeat: true
            running: cam.visible
            onTriggered: {
                const r = Math.random();
                cam.viewers = Math.max(1, cam.viewers + (r < 0.5 ? 1 : r < 0.62 ? 2 : r < 0.75 ? -1 : 0));
            }
        }

        // top: REC, the camera's name; the viewers waiting
        Row {
            x: cam.m
            y: cam.m
            spacing: root.u * 4
            Rectangle {
                width: rec.implicitWidth + root.u * 10
                height: root.u * 15
                color: root.pal.face
                border.width: root.u
                border.color: root.pal.edge
                Row {
                    id: rec
                    anchors.centerIn: parent
                    spacing: root.u * 3
                    Rectangle {
                        width: root.u * 4
                        height: width
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.pal.danger
                        opacity: Math.floor(root.time * 1.2) % 2 ? 1 : 0.2
                    }
                    Text {
                        text: "REC  " + root.t("КАМЕРА 2", "CAM 2")
                        color: root.pal.text
                        font.family: root.titleFont
                        font.pixelSize: root.titlePx(9)
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
        Rectangle {
            x: root.width - width - cam.m
            y: cam.m
            width: watching.implicitWidth + root.u * 10
            height: root.u * 15
            color: root.pal.face
            border.width: root.u
            border.color: root.pal.edge
            Row {
                id: watching
                anchors.centerIn: parent
                spacing: root.u * 3
                PixelIcon {
                    name: "eye"
                    pixel: root.u
                    ink: root.pal.edge
                    fill: root.pal.accent
                    light: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: cam.viewers + " " + root.t("ждут", "waiting")
                    color: root.pal.text
                    font.family: root.titleFont
                    font.pixelSize: root.titlePx(9)
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                }
            }
        }

        // the clock (hours over minutes when the screen stands) and the camera's window;
        // portrait: one column over the chat; landscape: on the left, the chat on the right
        Column {
            id: camMain
            objectName: "camMain"
            spacing: root.u * 8
            x: root.portrait ? Math.round((root.width - width) / 2) : Math.round((camChat.x - width) / 2)
            y: {
                const top = cam.m + root.u * 24, bottom = root.portrait ? camChat.y - root.u * 10 : root.height - cam.m;
                return Math.round(Math.max(top, top + (bottom - top - height) / 2));
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 0.85
                text: Qt.formatTime(root.now, "HH") + (root.portrait ? "\n" : root.now.getSeconds() % 2 ? ":" : " ") + Qt.formatTime(root.now, "mm")
                color: "#ffffff"
                style: Text.Outline
                styleColor: root.pal.edge
                font.family: root.titleFont
                font.pixelSize: root.titlePx(root.portrait ? 126 : 72)
                renderType: Text.NativeRendering
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.locale(root.ru ? "ru_RU" : "en_US").toString(root.now, "dddd, d MMMM")
                color: "#ffffff"
                style: Text.Outline
                styleColor: root.pal.edge
                font.family: root.titleFont
                font.pixelSize: root.titlePx(18)
                renderType: Text.NativeRendering
            }
            PxFrame {
                id: camWin
                anchors.horizontalCenter: parent.horizontalCenter
                pal: root.pal
                u: root.u
                font: root.titleFont
                fontSize: root.titlePx(9) < 13 ? 13 : root.titlePx(9)
                title: root.exe(root.t("кам2", "cam2"))
                icon: "monitor"
                readonly property int spritePx: root.u * (root.portrait ? 2 : 1.5)
                width: Math.min(root.portrait ? root.width - cam.m * 2 : root.width * 0.42, angel.implicitWidth + root.u * 40)
                height: titleHeight + angel.implicitHeight + root.u * 42
                // her room at night: a sky, a few stars twinkling, the angel asleep
                Rectangle {
                    anchors.fill: parent
                    anchors.bottomMargin: root.u * 12
                    color: root.pal.sunken
                    border.width: root.u
                    border.color: root.pal.edge
                    clip: true
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.darker(root.pal.sunken, 1.4)
                        }
                        GradientStop {
                            position: 1
                            color: root.pal.faceAlt
                        }
                    }
                    Repeater {
                        model: 7
                        PixelIcon {
                            required property int index
                            name: index % 2 ? "sparkle" : "sparkleStar"
                            pixel: root.u
                            ink: "transparent"
                            fill: index % 3 ? root.pal.accent2 : root.pal.accent3
                            light: "#ffffff"
                            x: Math.round(((index * 0.37 + 0.08) % 1) * (parent.width - width))
                            y: Math.round(((index * 0.61 + 0.1) % 1) * parent.height * 0.5)
                            opacity: 0.3 + 0.7 * Math.abs(Math.sin(root.secs * 0.8 + index * 1.7))
                        }
                    }
                    AngelCam {
                        id: angel
                        objectName: "angel"
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: root.u * 4
                        px: camWin.spritePx
                        time: root.secs
                        font: root.titleFont
                        zEdge: root.pal.edge
                    }
                }
                Text {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.bottomMargin: -root.u * 2
                    text: angel.peek ? root.t("👀 …ещё пять минуточек", "👀 …five more minutes") : root.t("💤 ангел спит — стрим начнётся, когда она войдёт", "💤 angel is asleep — the stream starts when she logs in")
                    color: root.pal.textDim
                    font.family: root.bodyFont
                    font.pixelSize: root.bodyPx(13)
                    width: parent.width
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }
            }
        }

        PxFrame {
            id: camChat
            objectName: "camChat"
            pal: root.pal
            u: root.u
            font: root.titleFont
            fontSize: root.titlePx(9) < 13 ? 13 : root.titlePx(9)
            title: root.exe(root.t("чат", "chat"))
            icon: "chat"
            width: root.portrait ? root.width - cam.m * 2 : Math.round(root.width * 0.36)
            height: titleHeight + root.u * 13 * root.chatLines + root.u * 18
            x: root.width - width - cam.m
            y: root.portrait ? root.height - height - cam.m : Math.round((root.height - height) / 2)
            ChatLines {
                theme: root
                width: parent.width
                anchors.bottom: parent.bottom
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
        wallFx.ring(field, root.pal.danger, 1);
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
