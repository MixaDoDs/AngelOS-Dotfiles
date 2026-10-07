pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Effects
import Quickshell
import qs.config
import qs.services
import qs.widgets

// The NGO lock (Settings → Lock → Look: NGO): the pixelated wallpaper, floating hearts,
// the stream overlay with its chat and, after a while, a blurred replay behind it; the
// clock and the login window in the middle, drawn bigger than the rest of the shell
// (Config.lock.size, whole screen pixels only — the art stays sharp).
Item {
    id: root

    required property string screenName
    required property bool primary
    required property var lockScope
    required property date now
    property bool preview: false

    readonly property var ws: Niri.activeWorkspace(screenName)
    readonly property string wall: Wallpapers.resolve(screenName, ws ? ws.idx : 1)
    readonly property bool reactions: Config.lock.reactions
    readonly property int lockedFor: Math.max(0, Math.floor((now.getTime() - lockScope.lockedAt) / 1000))
    readonly property string greeting: {
        const h = now.getHours();
        return h < 5 ? I18n.t("доброй ночи", "good night") : h < 12 ? I18n.t("доброе утро", "good morning") : h < 18 ? I18n.t("добрый день", "good afternoon") : I18n.t("добрый вечер", "good evening");
    }
    // the login window's size: ×1…×2 of the shell, kept to whole screen pixels per art pixel
    readonly property real boxScale: Math.max(1, Math.round(Theme.u * (Config.lock.size || 1)) / Theme.u)
    // where the unlock's heart grows from (0..1 of the screen)
    readonly property point fxOrigin: {
        if (!primary || !boxHolder.visible || width <= 0)
            return Qt.point(0.5, 0.5);
        const p = boxHolder.mapToItem(root, boxHolder.width / 2, boxHolder.height / 2);
        return Qt.point(p.x / width, p.y / height);
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.wall ? "file://" + Wallpapers.display(root.wall) : ""
        fillMode: Image.PreserveAspectCrop
        // physical pixels: sharp on a scaled monitor (issue #18)
        sourceSize: Qt.size(Math.ceil(width * Math.max(1, Screen.devicePixelRatio)), Math.ceil(height * Math.max(1, Screen.devicePixelRatio)))
        asynchronous: true
        visible: !Config.lock.pixelate
        onStatusChanged: if (status === Image.Error)
            Wallpapers.fit(root.wall)
    }
    ShaderEffect {
        anchors.fill: parent
        visible: Config.lock.pixelate
        property var source: ShaderEffectSource {
            sourceItem: img
            hideSource: true
        }
        property real block: Theme.u * 8
        property size resolution: Qt.size(width, height)
        fragmentShader: Qt.resolvedUrl("../../shaders/pixelate.frag.qsb")
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.desk, 0.35)
    }

    // ---- the replay: a random video, blurred beyond reading, after a while on air ----
    readonly property bool streamOn: Config.lock.stream && root.primary
    // never on a screen that is being streamed for real (OBS live, Settings → Stream mode)
    readonly property bool replayAllowed: streamOn && Config.lock.replay && !StreamMode.onStream(root.screenName)
    Loader {
        id: replay
        anchors.fill: parent
        active: root.replayAllowed
        sourceComponent: ReplayFeed {
            active: root.lockedFor >= Math.max(5, Config.lock.replayDelay) && !root.lockScope.unlocking
            folder: Config.expand(Config.lock.replayDir) || Config.home + "/Videos"
        }
    }

    FloatingHearts {
        anchors.fill: parent
        visible: Config.lock.hearts
        count: 22
        maxOpacity: 0.5
    }

    // ---- NGO stream overlay: LIVE, viewers, a chat that knows what you did ----
    Loader {
        id: stream
        anchors.fill: parent
        active: root.streamOn
        sourceComponent: StreamOverlay {
            lockScope: root.lockScope
            replaying: replay.item ? replay.item.opacity > 0.5 : false
        }
    }

    LockIndicators {
        visible: Config.lock.indicators
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.u * 10
        lockScope: root.lockScope
        now: root.now
    }

    Column {
        id: center
        anchors.centerIn: parent
        spacing: Theme.u * 10

        AngelLogo {
            visible: Config.lock.logo
            anchors.horizontalCenter: parent.horizontalCenter
            pixel: Theme.u * 2
            fontSize: Theme.sizeHuge
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, "HH") + (root.now.getSeconds() % 2 || !root.reactions ? ":" : " ") + Qt.formatTime(root.now, "mm")
            font.family: Theme.fontTitle
            font.pixelSize: Theme.fontPx(72, Theme.fontTitle)
            color: "#ffffff"
            style: Text.Outline
            styleColor: Theme.edge
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale(Config.appearance.language === "en" ? "en_US" : "ru_RU").toString(root.now, "dddd, d MMMM")
            kind: "title"
            color: "#ffffff"
            style: Text.Outline
            styleColor: Theme.edge
        }

        Item {
            id: boxHolder
            visible: root.primary
            anchors.horizontalCenter: parent.horizontalCenter
            width: box.width * root.boxScale
            height: box.height * root.boxScale

            property real shakeX: 0
            property real jump: 0
            transform: Translate {
                x: boxHolder.shakeX
                y: -boxHolder.jump
            }
            Keys.onEscapePressed: if (root.preview)
                Shell.lockPreview = false

            PxWindow {
                id: box
                transformOrigin: Item.TopLeft
                scale: root.boxScale
                // drawn at the shell's size and blown up pixel for pixel: no blur
                layer.enabled: root.boxScale !== 1
                layer.smooth: false
                width: Theme.u * 170
                height: titleHeight + form.implicitHeight + Theme.pad * 2 + Theme.u * 8
                title: I18n.exe(I18n.t("вход", "login")) + (root.preview ? I18n.t(" · предпросмотр", " · preview") : "")
                icon: "lock"
                closable: root.preview
                onCloseClicked: Shell.lockPreview = false
                translucent: false

                Column {
                    id: form
                    width: parent.width
                    spacing: Theme.u * 5

                    Row {
                        spacing: Theme.u * 5
                        // the heart beats while typing and breaks on a wrong password
                        Item {
                            width: bigHeart.width
                            height: bigHeart.height
                            PxIcon {
                                id: bigHeart
                                name: heartState.broken ? "heartBroken" : "heart"
                                pixel: Theme.u * 3
                                fill: heartState.broken ? Theme.danger : Theme.accent
                                scale: heartState.beat
                                transformOrigin: Item.Center
                            }
                            QtObject {
                                id: heartState
                                property bool broken: false
                                property real beat: 1
                            }
                            SequentialAnimation {
                                id: beatAnim
                                PropertyAction {
                                    target: heartState
                                    property: "beat"
                                    value: 1.18
                                }
                                PauseAnimation {
                                    duration: Motion.ms(70)
                                }
                                PropertyAction {
                                    target: heartState
                                    property: "beat"
                                    value: 1
                                }
                            }
                            Timer {
                                id: mend
                                interval: 1400
                                onTriggered: heartState.broken = false
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            PxText {
                                text: root.greeting + ", " + (Quickshell.env("USER") || "angel") + " ♡"
                                kind: "title"
                            }
                            PxText {
                                text: I18n.t("с возвращением~", "welcome back~")
                                dim: true
                            }
                        }
                    }
                    Row {
                        width: parent.width
                        spacing: Theme.u * 3
                        HeartPassword {
                            id: field
                            width: parent.width - go.width - parent.spacing
                            busy: root.lockScope.busy
                            reactions: root.reactions
                            placeholder: I18n.t("пароль ♡", "password ♡")
                            onAccepted: root.lockScope.submit(text)
                            onHurried: root.lockScope.hurry()
                            onTyped: (length, added) => root.lockScope.typed(length, added)
                            onBroke: (x, y) => {
                                const p = field.mapToItem(root, x, y);
                                burst.drop(p.x, p.y);
                            }
                            Component.onCompleted: focusField()
                        }
                        PxButton {
                            id: go
                            height: field.height
                            icon: "arrowRight"
                            accent: true
                            enabled: !root.lockScope.busy
                            onClicked: {
                                root.lockScope.submit(field.text);
                                field.focusField();
                            }
                        }
                    }
                    Row {
                        spacing: Theme.u * 4
                        visible: Config.lock.indicators && (root.lockScope.caps || Niri.layoutShort !== "")
                        PxBox {
                            visible: root.lockScope.caps
                            width: capsText.implicitWidth + Theme.u * 8
                            height: Theme.u * 11
                            color: Theme.danger
                            PxText {
                                id: capsText
                                anchors.centerIn: parent
                                text: "CAPS LOCK"
                                kind: "tiny"
                                color: "#ffffff"
                                font.bold: true
                            }
                        }
                        PxText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Niri.layoutShort !== ""
                            text: I18n.t("раскладка: ", "layout: ") + Niri.layoutShort
                            kind: "tiny"
                            dim: true
                        }
                    }
                    // the stars and the wish this unlock will make (services/HeavenStars)
                    Row {
                        visible: Config.lock.wish
                        spacing: Theme.u * 4
                        PxText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "✦ " + HeavenStars.stars
                            color: Theme.accent3
                            font.bold: true
                        }
                        PxBox {
                            width: wishLine.implicitWidth + Theme.u * 8
                            height: wishLine.implicitHeight + Theme.u * 4
                            color: wishMouse.containsMouse ? Theme.faceAlt : Theme.face
                            PxText {
                                id: wishLine
                                anchors.centerIn: parent
                                text: HeavenStars.freeWishToday ? I18n.t("крутка сегодня бесплатно ✧", "today's wish is free ✧") : !Config.lock.wishPaid ? I18n.t("☐ крутка при входе (%1 ✦)", "☐ wish at the unlock (%1 ✦)").arg(HeavenStars.wishCost) : HeavenStars.stars >= HeavenStars.wishCost ? I18n.t("☑ крутка при входе (%1 ✦)", "☑ wish at the unlock (%1 ✦)").arg(HeavenStars.wishCost) : I18n.t("на крутку нужно %1 ✦", "a wish takes %1 ✦").arg(HeavenStars.wishCost)
                                kind: "tiny"
                            }
                            MouseArea {
                                id: wishMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !HeavenStars.freeWishToday
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Config.lock.wishPaid = !Config.lock.wishPaid;
                                    field.focusField();
                                }
                            }
                        }
                    }
                    PxText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: root.lockScope.status || (root.preview ? I18n.t("предпросмотр: пароль не проверяется, Esc — выход", "preview: the password is not checked, Esc to exit") : "")
                        color: root.lockScope.fails > 0 ? Theme.danger : Theme.textDim
                    }
                }
            }

            // a wrong password tears the window into red and cyan for a moment
            ShaderEffectSource {
                id: boxCopy
                sourceItem: glitch.visible ? box : null
                live: true
                visible: false
            }
            Item {
                id: glitch
                anchors.fill: parent
                visible: false
                property real dx: Theme.u * 3
                MultiEffect {
                    width: parent.width
                    height: parent.height
                    x: -glitch.dx
                    source: boxCopy
                    colorization: 1
                    colorizationColor: "#ff2a6d"
                    opacity: 0.55
                }
                MultiEffect {
                    width: parent.width
                    height: parent.height
                    x: glitch.dx
                    source: boxCopy
                    colorization: 1
                    colorizationColor: "#05d9e8"
                    opacity: 0.55
                }
            }
            Timer {
                id: glitchTick
                interval: 45
                repeat: true
                property int left: 0
                onTriggered: {
                    glitch.dx = (Math.random() < 0.5 ? -1 : 1) * Theme.u * (2 + Math.floor(Math.random() * 5));
                    if (--left <= 0) {
                        stop();
                        glitch.visible = false;
                    }
                }
            }
        }
    }
    SequentialAnimation {
        id: shakeAnim
        loops: 3
        NumberAnimation {
            target: boxHolder
            property: "shakeX"
            to: Theme.u * 6
            duration: Motion.ms(40)
        }
        NumberAnimation {
            target: boxHolder
            property: "shakeX"
            to: -Theme.u * 6
            duration: Motion.ms(40)
        }
        NumberAnimation {
            target: boxHolder
            property: "shakeX"
            to: 0
            duration: Motion.ms(40)
        }
    }
    SequentialAnimation {
        id: jumpAnim
        NumberAnimation {
            target: boxHolder
            property: "jump"
            to: Theme.u * 8
            duration: Motion.ms(110)
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: boxHolder
            property: "jump"
            to: 0
            duration: Motion.ms(160)
            easing.type: Easing.OutBounce
        }
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Theme.u * 20
        spacing: Theme.u * 6
        visible: root.primary && Lyrics.title !== ""
        PxIcon {
            name: "music"
        }
        PxText {
            text: Lyrics.title + (Lyrics.artist ? " — " + Lyrics.artist : "")
            color: "#ffffff"
            style: Text.Outline
            styleColor: Theme.edge
        }
    }

    // hearts thrown by typing, failing and unlocking
    HeartBurst {
        id: burst
        anchors.fill: parent
        poolSize: 64
        z: 2
    }

    // the unlock's sticker over the window: "welcome back", or the stream's end card
    PxBox {
        id: stamp
        x: Math.round(center.x + boxHolder.x + boxHolder.width / 2 - width / 2)
        y: Math.round(center.y + boxHolder.y + boxHolder.height / 2 - height / 2)
        width: stampText.implicitWidth + Theme.u * 16
        height: stampText.implicitHeight + Theme.u * 10
        color: root.lockScope.fx === "crt" ? Theme.edge : Theme.accent
        rotation: -6
        visible: pop > 0
        property real pop: 0
        scale: pop * root.boxScale
        PxText {
            id: stampText
            anchors.centerIn: parent
            text: root.lockScope.fx === "crt" ? I18n.t("СТРИМ ОКОНЧЕН ♡ спасибо, что смотрели", "STREAM ENDED ♡ thanks for watching") : I18n.t("♡ С ВОЗВРАЩЕНИЕМ ♡", "♡ WELCOME BACK ♡")
            kind: "big"
            color: "#ffffff"
            style: Text.Outline
            styleColor: Theme.edge
            font.bold: true
        }
        SequentialAnimation {
            id: stampAnim
            NumberAnimation {
                target: stamp
                property: "pop"
                from: 0
                to: 1.25
                duration: Motion.ms(120)
            }
            NumberAnimation {
                target: stamp
                property: "pop"
                to: 1
                duration: Motion.ms(90)
            }
        }
    }

    // ---- the gachapon: a wish at the unlock (HeavenStars.pull via Lock.qml) ----
    // a capsule drops onto the login window, bounces, shakes, pops open in its rarity's
    // colour; the sticker says what it gave
    property var got: null
    property real gachaT: 0
    readonly property color gachaColor: !got ? "#ffffff" : got.stars >= 5 ? "#ffd25a" : got.stars === 4 ? "#c48bff" : "#7fb2ff"
    readonly property point gachaAt: Qt.point(center.x + boxHolder.x + boxHolder.width / 2, center.y + boxHolder.y + boxHolder.height / 2)
    function bounce(p) {
        const n = 7.5625, d = 2.75;
        if (p < 1 / d)
            return n * p * p;
        if (p < 2 / d)
            return n * (p -= 1.5 / d) * p + 0.75;
        if (p < 2.5 / d)
            return n * (p -= 2.25 / d) * p + 0.9375;
        return n * (p -= 2.625 / d) * p + 0.984375;
    }
    Item {
        id: gacha
        anchors.fill: parent
        visible: root.got !== null && root.gachaT > 0
        readonly property int px: Theme.u * 5
        readonly property real fall: root.bounce(Math.min(1, root.gachaT / 0.3))
        readonly property real cy: root.gachaAt.y - capTop.height
        readonly property real shake: root.gachaT > 0.3 && root.gachaT < 0.45 ? Math.round(Math.sin(root.gachaT * 260) * Theme.u * 3) : 0
        readonly property real open: Math.max(0, Math.min(1, (root.gachaT - 0.45) / 0.18))
        Rectangle {
            anchors.fill: parent
            color: Theme.desk
            opacity: 0.55 * Math.min(1, root.gachaT * 6)
        }
        // the rarity's light behind the capsule once it opens
        Repeater {
            model: 12
            Rectangle {
                required property int index
                visible: gacha.open > 0
                width: Theme.u * 4
                height: Theme.u * 40 * gacha.open
                x: root.gachaAt.x - width / 2
                y: root.gachaAt.y - height
                color: root.gachaColor
                opacity: 0.6 * (1 - Math.max(0, root.gachaT - 0.7) * 2)
                transformOrigin: Item.Bottom
                rotation: index * 30 + root.gachaT * 60
            }
        }
        PxIcon {
            id: capBottom
            bitmap: ["############", "#wwwwwwwwww#", "#wwwwwwwwww#", ".#wwwwwwww#.", ".#wwwwwwww#.", "..##wwww##..", "....####...."]
            pixel: gacha.px
            ink: Theme.edge
            light: "#ffffff"
            x: Math.round(root.gachaAt.x - width / 2 + gacha.shake)
            y: Math.round(gacha.cy - (1 - gacha.fall) * (gacha.cy + height * 3)) + capTop.height
        }
        PxIcon {
            id: capTop
            bitmap: ["....####....", "..##oooo##..", ".#oowooooo#.", ".#owoooooo#.", "#oooooooooo#"]
            pixel: gacha.px
            ink: Theme.edge
            fill: root.gachaColor
            light: "#ffffff"
            x: Math.round(root.gachaAt.x - width / 2 + gacha.shake - gacha.open * Theme.u * 18)
            y: Math.round(gacha.cy - (1 - gacha.fall) * (gacha.cy + height * 3) - gacha.open * Theme.u * 30)
            rotation: -gacha.open * 50
            opacity: 1 - Math.max(0, gacha.open - 0.6) * 2.5
        }
        // what it gave
        PxBox {
            id: gachaCard
            visible: root.gachaT >= 0.55
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.gachaAt.y + Theme.u * 10)
            width: gachaCol.implicitWidth + Theme.u * 20
            height: gachaCol.implicitHeight + Theme.u * 12
            color: Theme.face
            edgeColor: root.gachaColor
            shadow: true
            rotation: -3
            scale: Math.min(1, (root.gachaT - 0.55) * 12) * root.boxScale
            Column {
                id: gachaCol
                anchors.centerIn: parent
                spacing: Theme.u * 3
                PxText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.got ? "★".repeat(root.got.stars) : ""
                    kind: "title"
                    color: root.gachaColor
                    style: Text.Outline
                    styleColor: Theme.edge
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.u * 4
                    PxIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.got ? root.got.icon : "heart"
                        pixel: Theme.u * 2
                        fill: root.gachaColor
                    }
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: !root.got ? "" : !root.lockScope.previewing ? I18n.t("капсула откроется на рабочем столе ✦", "the capsule opens on the desktop ✦") : (root.got.kind === "skin" ? I18n.t("скин ангела: ", "the angel's skin: ") : I18n.t("карточка: ", "card: ")) + root.got.name
                        kind: "title"
                        font.bold: true
                    }
                }
                PxText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: !root.got || !root.lockScope.previewing ? "" : root.got.fresh ? I18n.t("НОВОЕ! ♡", "NEW! ♡") : I18n.t("повтор · +%1 ✦", "duplicate · +%1 ✦").arg(root.got.refund)
                    color: root.got && root.got.fresh ? Theme.accent : Theme.textDim
                    font.bold: true
                }
            }
        }
    }
    NumberAnimation {
        id: gachaAnim
        target: root
        property: "gachaT"
        from: 0
        to: 1
    }
    Timer {
        id: gachaOpen
        onTriggered: {
            const p = root.gachaAt;
            burst.burst(p.x, p.y - Theme.u * 20, root.got && root.got.stars >= 5 ? 64 : root.got && root.got.stars === 4 ? 40 : 24, Theme.u * (root.got && root.got.stars >= 5 ? 14 : 10));
        }
    }

    // the stream's highlights at the unlock: the clips of the mistakes, the peak, a line of chat
    PxWindow {
        id: reel
        property var frames: []
        property int at: -1
        visible: at >= 0 && at < frames.length
        x: Math.round(center.x + boxHolder.x + boxHolder.width / 2 - width / 2)
        y: Math.round(center.y + boxHolder.y + boxHolder.height / 2 - height / 2)
        width: Math.max(Theme.u * 170, reelText.implicitWidth + Theme.u * 30)
        height: titleHeight + reelText.implicitHeight + Theme.pad * 2 + Theme.u * 14
        scale: root.boxScale
        title: I18n.exe("highlights") + "  " + (at + 1) + "/" + frames.length
        icon: "play"
        closable: false
        translucent: false
        PxText {
            id: reelText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            y: Theme.u * 4
            text: reel.at >= 0 && reel.at < reel.frames.length ? reel.frames[reel.at] : ""
            kind: reel.at === 0 ? "title" : "body"
            font.bold: reel.at === 0
            color: reel.at === 0 ? Theme.accent : Theme.text
            elide: Text.ElideRight
        }
    }
    Timer {
        id: reelTick
        repeat: true
        onTriggered: {
            if (++reel.at >= reel.frames.length) {
                stop();
                stampAnim.restart();
            }
        }
    }

    // the chat notices the mouse; a click puts the keys back into the field
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onPositionChanged: if (stream.item) {
            stream.item.mouseMoved();
            if (stream.item.camAngel)
                stream.item.camAngel.poke();
        }
        onClicked: {
            root.lockScope.hurry();
            field.focusField();
        }
        z: -1
    }

    // `angelos lockPreviewTry <text>`: types it in, key by key, then presses Enter
    Timer {
        id: demoKeys
        interval: 85
        repeat: true
        property string pending: ""
        onTriggered: {
            if (pending === "") {
                stop();
                root.lockScope.submit(field.text);
                return;
            }
            field.text += pending[0];
            pending = pending.slice(1);
        }
    }

    Connections {
        target: root.lockScope
        function onDemo(text) {
            if (!root.primary)
                return;
            field.clear();
            demoKeys.pending = text;
            demoKeys.restart();
        }
        function onShake() {
            shakeAnim.restart();
            if (!root.reactions || !root.primary) {
                field.clear();
                return;
            }
            field.fail();
            heartState.broken = true;
            mend.restart();
            glitch.visible = true;
            glitchTick.left = 7;
            glitchTick.restart();
            const p = bigHeart.mapToItem(root, bigHeart.width / 2, bigHeart.height / 2);
            for (let i = 0; i < 4; i++)
                burst.drop(p.x + (i - 1.5) * Theme.u * 4, p.y);
        }
        function onSuccess() {
            if (!root.reactions)
                return;
            const p = root.primary ? boxHolder.mapToItem(root, boxHolder.width / 2, boxHolder.height / 2) : Qt.point(root.width / 2, root.height / 2);
            burst.burst(p.x, p.y, root.primary ? 48 : 16, Theme.u * 10);
            if (!root.primary)
                return;
            field.win();
            jumpAnim.restart();
            // a wish: the gachapon capsule; else the stream's highlights, when there is something to show
            const w = root.lockScope.wished;
            const s = stream.item;
            if (w) {
                root.got = w;
                const d = w.stars >= 5 ? 2600 : w.stars === 4 ? 2000 : 1600;
                gachaAnim.duration = d;
                gachaAnim.restart();
                gachaOpen.interval = Math.round(d * 0.45);
                gachaOpen.restart();
                root.lockScope.hold = Math.max(root.lockScope.hold, d + 250);
            } else if (Config.lock.highlights && s && (s.clips.length > 0 || s.elapsed >= 120)) {
                const f = [I18n.t("✦ ХАЙЛАЙТЫ СТРИМА ✦", "✦ STREAM HIGHLIGHTS ✦")];
                for (const c of s.clips.slice(-3))
                    f.push("✂ #" + c.n + " «" + c.title + "» · " + Math.floor(c.at / 60) + ":" + ("0" + c.at % 60).slice(-2));
                f.push(I18n.t("пик: %1 зрителей · %2 сообщений", "peak: %1 viewers · %2 messages").arg(s.peak).arg(s.said));
                if (s.bestLine)
                    f.push("💬 " + s.bestLine);
                reel.frames = f;
                reel.at = 0;
                root.lockScope.hold = Math.max(root.lockScope.hold, Math.min(2200, 300 + f.length * 380));
                reelTick.interval = Math.max(220, (root.lockScope.hold - 300) / f.length);
                reelTick.restart();
            } else {
                stampAnim.restart();
            }
        }
        function onTyped(length, added) {
            if (!root.reactions || !root.primary)
                return;
            beatAnim.restart();
            if (added) {
                const p = field.mapToItem(root, field.caretX, 0);
                burst.pop(p.x, p.y);
            }
        }
    }
}
