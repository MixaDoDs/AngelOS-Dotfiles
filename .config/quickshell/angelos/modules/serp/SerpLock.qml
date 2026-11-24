pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.modules.lock

// serp-skin: the lock screen in Serpantinum's look (modules/lock/LockScreen loads it while the skin
// is on, in place of the face Settings → Lock → Look picks). Only the look is the skin's: the
// password is typed into angelOS's own field (HeartPassword — here invisible, it keeps the
// keyboard, exactly as on the NGO face) and goes to the lock's own submit() → PAM; the shake,
// the success, the relay from the other screens, the preview's demo typing and its Esc, the
// "hurry" click, the caps lock and the wish toggle are wired as the NGO face wires them. The
// capsule only mirrors the field: a dot per character, a caret, red on a mistake.
Item {
    id: root

    required property string screenName
    required property bool primary
    required property var lockScope
    required property date now
    property bool preview: false

    readonly property bool reactions: Config.lock.reactions
    readonly property string lang: Config.appearance.language === "en" ? "en_US" : "ru_RU"
    readonly property string greeting: {
        const h = now.getHours();
        return h < 5 ? I18n.t("Доброй ночи", "Good night") : h < 12 ? I18n.t("Доброе утро", "Good morning") : h < 18 ? I18n.t("Добрый день", "Good afternoon") : I18n.t("Добрый вечер", "Good evening");
    }
    readonly property int minutesLocked: Math.max(0, Math.floor((now.getTime() - lockScope.lockedAt) / 60000))
    readonly property int missed: Notifs.history.filter(h => h.time > lockScope.lockedAt).length
    readonly property real big: Math.max(Serp.px(72), Math.round(Math.min(width, height) * 0.15))
    // where the unlock's heart grows from (0..1 of the screen)
    readonly property point fxOrigin: {
        if (!primary || !login.visible || width <= 0)
            return Qt.point(0.5, 0.5);
        const p = capsuleHolder.mapToItem(root, capsuleHolder.width / 2, capsuleHolder.height / 2);
        return Qt.point(p.x / width, p.y / height);
    }

    property bool failed: false            // the capsule is red for a moment
    property bool won: false               // the right password: green, a check
    property var got: null                 // the wish this unlock made (Lock.wished)
    property int wave: 0                   // the dots wave while PAM checks

    Timer {
        id: failClear
        interval: 1100
        onTriggered: root.failed = false
    }
    Timer {
        interval: 90
        repeat: true
        running: root.lockScope.busy && !Motion.still
        onTriggered: root.wave++
    }

    // ---- the picture ----
    SerpLockWall {
        anchors.fill: parent
        screenName: root.screenName
        now: root.now
        blur: 1
        dim: 0.4
    }
    // the wallpaper in screen space for the capsule's liquid glass (frosted as the wall is)
    SerpBackdrop {
        id: glassBack
        screenName: root.screenName
        origin: Qt.point(0, 0)
        blur: 1
    }

    // a click anywhere: hurry the unlock along, the keys back into the field
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: {
            root.lockScope.hurry();
            if (root.primary)
                field.focusField();
        }
    }

    // ---- the indicators (Settings → Lock → Indicators), top right ----
    Row {
        visible: Config.lock.indicators
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Serp.px(24)
        spacing: Serp.px(8)
        Repeater {
            model: [
                {
                    "show": Power.hasBattery,
                    "icon": Power.plugged ? "battery-charging" : "battery",
                    "text": Power.percent + "%"
                },
                {
                    "show": !!root.lockScope.fingerOn,
                    "icon": "scan",
                    "text": I18n.t("палец", "finger")
                },
                {
                    "show": root.missed > 0,
                    "icon": "bell",
                    "text": String(root.missed)
                },
                {
                    "show": Niri.layoutShort !== "",
                    "icon": "languages",
                    "text": Niri.layoutShort
                },
                {
                    "show": true,
                    "icon": "lock",
                    "text": root.minutesLocked < 1 ? I18n.t("только что", "just now") : root.minutesLocked + I18n.t(" мин", " min")
                }
            ].filter(i => i.show)
            SerpLockChip {
                required property var modelData
                icon: modelData.icon
                text: modelData.text
            }
        }
    }

    // ---- the clock, the date, and (the main screen) who and the password ----
    Column {
        id: center
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -Serp.px(24)
        spacing: Serp.px(4)

        SText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, "HH:mm")
            size: root.big
            black: true
            color: Serp.accent
            elide: Text.ElideNone
            // no negative letter spacing: Qt adds it after the last digit too and the time sat off-centre
        }
        SText {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property string d: Qt.locale(root.lang).toString(root.now, "dddd, d MMMM")
            text: d.charAt(0).toUpperCase() + d.slice(1)
            size: Serp.px(20)
            bold: true
            color: Serp.text
            elide: Text.ElideNone
        }
        Item {
            width: 1
            height: Serp.px(40)
        }

        Column {
            id: login
            visible: root.primary
            // centred in the column (the clock makes it wider): it stood flush left, 45 px off
            anchors.horizontalCenter: parent.horizontalCenter
            width: Serp.px(380)
            spacing: Serp.px(10)

            // the avatar (Settings → Bar → Start → Avatar, else the system's), a ring of the accent
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Serp.px(84)
                height: width
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.alpha(Serp.base, 0.6)
                    border.width: Serp.px(2)
                    border.color: root.failed ? Serp.red : root.won ? Serp.green : Qt.alpha(Serp.accent, 0.85)
                    Behavior on border.color {
                        ColorAnimation {
                            duration: Serp.quick
                        }
                    }
                }
                SerpLockRound {
                    id: avatar
                    anchors.fill: parent
                    anchors.margins: Serp.px(4)
                    source: StartPrefs.avatarUrl
                }
                SIcon {
                    visible: !avatar.ready
                    anchors.centerIn: parent
                    name: "user"
                    size: Serp.px(36)
                    color: Serp.subtext1
                }
            }
            SText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: StartPrefs.userName
                size: Serp.px(18)
                bold: true
                elide: Text.ElideNone
            }
            SText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.greeting + (root.preview ? I18n.t(" · предпросмотр", " · preview") : I18n.t(" · с возвращением", " · welcome back"))
                size: Serp.px(12)
                color: Serp.subtext1
                elide: Text.ElideNone
            }
            Item {
                width: 1
                height: Serp.px(4)
            }

            // the password capsule
            Item {
                id: capsuleHolder
                width: parent.width
                height: Serp.px(50)
                property real shakeX: 0
                property real jump: 0
                transform: Translate {
                    x: capsuleHolder.shakeX
                    y: -capsuleHolder.jump
                }
                Keys.onEscapePressed: if (root.preview)
                    Shell.lockPreview = false

                SGlass {
                    id: capsule
                    anchors.fill: parent
                    backdrop: glassBack
                    radius: height / 2
                    hover: field.focused ? 1 : 0
                    Behavior on hover {
                        NumberAnimation {
                            duration: Serp.normal
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root.failed ? Qt.alpha(Serp.red, 0.12) : "transparent"
                    border.width: field.focused || root.failed || root.won ? Serp.px(2) : 1
                    border.color: root.failed ? Serp.red : root.won ? Serp.green : field.focused ? Qt.alpha(Serp.accent, 0.85) : Serp.line
                    Behavior on border.color {
                        ColorAnimation {
                            duration: Serp.quick
                        }
                    }
                }
                SIcon {
                    id: lockIcon
                    x: Serp.px(18)
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.won ? "check" : "lock"
                    size: Serp.px(16)
                    color: root.failed ? Serp.red : root.won ? Serp.green : Serp.subtext1
                }

                // the real field: angelOS's own, invisible here (opacity, so it keeps the keys)
                HeartPassword {
                    id: field
                    x: dotsArea.x
                    width: dotsArea.width
                    height: parent.height
                    opacity: 0
                    busy: root.lockScope.busy
                    reactions: root.reactions
                    onAccepted: root.lockScope.submit(text)
                    onHurried: root.lockScope.hurry()
                    onTyped: (length, added) => root.lockScope.typed(length, added)
                    Component.onCompleted: focusField()
                }

                // …and its face: a dot per character, the end in sight
                Item {
                    id: dotsArea
                    x: lockIcon.x + lockIcon.width + Serp.px(12)
                    width: go.x - x - Serp.px(10)
                    height: parent.height
                    clip: true
                    SText {
                        visible: field.count === 0 && !field.falling
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.lockScope.busy ? I18n.t("Проверяю…", "Checking…") : I18n.t("Пароль", "Password")
                        color: Serp.subtext0
                    }
                    Row {
                        id: dots
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.min(0, parent.width - width - Serp.px(6))
                        spacing: Serp.px(6)
                        Repeater {
                            model: field.count
                            Rectangle {
                                id: dot
                                required property int index
                                width: Serp.px(9)
                                height: width
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.failed || field.falling ? Serp.red : root.won ? Serp.green : Serp.text
                                opacity: field.falling ? 0.35 : 1
                                anchors.verticalCenterOffset: root.lockScope.busy ? Math.sin((root.wave + index) * 0.8) * Serp.px(3) : 0
                                // the newest one pops in
                                NumberAnimation on scale {
                                    running: dot.index === field.count - 1 && root.reactions && !Motion.still
                                    from: 0.2
                                    to: 1
                                    duration: Motion.ms(Serp.quick)
                                    easing.type: Easing.OutBack
                                }
                            }
                        }
                        Rectangle {
                            id: caret
                            anchors.verticalCenter: parent.verticalCenter
                            width: Serp.px(2)
                            height: Serp.px(18)
                            radius: 1
                            color: Serp.accent
                            visible: field.focused && !root.lockScope.busy && !field.falling && field.count > 0
                            SequentialAnimation on opacity {
                                running: caret.visible && !Motion.still
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: 0
                                    duration: 530
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    to: 1
                                    duration: 530
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }
                }

                // the arrow: submit (what Enter does)
                Rectangle {
                    id: go
                    anchors.right: parent.right
                    anchors.rightMargin: Serp.px(7)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.height - Serp.px(14)
                    height: width
                    radius: width / 2
                    color: goMouse.containsMouse && goMouse.enabled ? Qt.lighter(Serp.accent, 1.12) : Serp.accent
                    opacity: root.lockScope.busy ? 0.5 : 1
                    scale: goMouse.pressed ? 0.92 : 1
                    Behavior on scale {
                        NumberAnimation {
                            duration: Serp.quick
                        }
                    }
                    SIcon {
                        anchors.centerIn: parent
                        name: root.won ? "check" : "chevron-right"
                        size: Serp.px(18)
                        color: Serp.onAccent
                        stroke: 2.5
                    }
                    MouseArea {
                        id: goMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.lockScope.busy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.lockScope.submit(field.text);
                            field.focusField();
                        }
                    }
                }

                // the wish this unlock made: a falling star's colour (the prize opens on the desk)
                SText {
                    visible: !!root.got
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top
                    anchors.bottomMargin: Serp.px(8)
                    text: !root.got ? "" : "✦".repeat(Math.max(1, root.got.stars || 3)) + "  " + (!root.lockScope.previewing ? I18n.t("откроется на рабочем столе", "opens on the desktop") : root.got.name || "")
                    color: !root.got ? Serp.text : root.got.stars >= 5 ? Serp.yellow : root.got.stars === 4 ? Serp.mauve : Serp.blue
                    bold: true
                    elide: Text.ElideNone
                }
            }

            // caps lock and the layout
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Serp.px(8)
                visible: root.lockScope.caps || Niri.layoutShort !== ""
                SerpLockChip {
                    visible: root.lockScope.caps
                    icon: "chevron-up"
                    text: "Caps Lock"
                    ink: Serp.onAccent
                    fill: Serp.red
                }
                SerpLockChip {
                    visible: Niri.layoutShort !== ""
                    icon: "keyboard"
                    text: Niri.layoutShort
                }
            }
            // the stars and the wish this unlock will make (services/HeavenStars)
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Config.lock.wish
                spacing: Serp.px(8)
                SerpLockChip {
                    icon: "sparkles"
                    text: String(HeavenStars.stars)
                    ink: Serp.yellow
                }
                SerpLockChip {
                    id: wishChip
                    icon: HeavenStars.freeWishToday || (Config.lock.wishPaid && HeavenStars.stars >= HeavenStars.wishCost) ? "check" : "star"
                    text: HeavenStars.freeWishToday ? I18n.t("крутка сегодня бесплатно", "today's wish is free") : !Config.lock.wishPaid ? I18n.t("крутка при входе: выкл (%1 ✦)", "wish at the unlock: off (%1 ✦)").arg(HeavenStars.wishCost) : HeavenStars.stars >= HeavenStars.wishCost ? I18n.t("крутка при входе (%1 ✦)", "wish at the unlock (%1 ✦)").arg(HeavenStars.wishCost) : I18n.t("на крутку нужно %1 ✦", "a wish takes %1 ✦").arg(HeavenStars.wishCost)
                    fill: wishMouse.containsMouse ? Qt.alpha(Serp.surface1, 0.75) : Qt.alpha(Serp.base, 0.55)
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
            SText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                visible: text !== ""
                text: root.lockScope.status || (root.preview ? I18n.t("предпросмотр: пароль не проверяется, Esc — выход", "preview: the password is not checked, Esc to exit") : "")
                size: Serp.px(12)
                color: root.lockScope.fails > 0 ? Serp.red : Serp.subtext1
            }
        }
    }

    // ---- now playing (the main screen), at the bottom ----
    Item {
        visible: root.primary && Lyrics.title !== ""
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Serp.px(32)
        width: Math.min(mediaRow.implicitWidth + Serp.px(28), root.width * 0.6)
        height: Serp.px(46)
        SGlass {
            anchors.fill: parent
            backdrop: glassBack
            radius: height / 2
        }
        Row {
            id: mediaRow
            anchors.left: parent.left
            anchors.leftMargin: Serp.px(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Serp.px(10)
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Serp.px(32)
                height: width
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.alpha(Serp.accent, 0.25)
                }
                SerpLockRound {
                    id: art
                    anchors.fill: parent
                    source: Lyrics.artUrl || ""
                    sourceWidth: 96
                }
                SIcon {
                    visible: !art.ready
                    anchors.centerIn: parent
                    name: "music"
                    size: Serp.px(15)
                    color: Serp.accent
                }
            }
            SText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.width * 0.6 - Serp.px(90))
                text: Lyrics.title + (Lyrics.artist ? "  ·  " + Lyrics.artist : "")
                bold: true
            }
            SIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: Lyrics.playing ? "volume-2" : "pause"
                size: Serp.px(14)
                color: Serp.subtext1
            }
        }
    }

    // ---- the motions ----
    SequentialAnimation {
        id: shakeAnim
        loops: 3
        NumberAnimation {
            target: capsuleHolder
            property: "shakeX"
            to: Serp.px(9)
            duration: Motion.ms(45)
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: capsuleHolder
            property: "shakeX"
            to: -Serp.px(9)
            duration: Motion.ms(45)
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: capsuleHolder
            property: "shakeX"
            to: 0
            duration: Motion.ms(45)
            easing.type: Easing.InQuad
        }
    }
    SequentialAnimation {
        id: jumpAnim
        NumberAnimation {
            target: capsuleHolder
            property: "jump"
            to: Serp.px(6)
            duration: Motion.ms(110)
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: capsuleHolder
            property: "jump"
            to: 0
            duration: Motion.ms(180)
            easing.type: Easing.OutBack
        }
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
        function onRelayKey(text, key) {
            if (root.primary)
                field.feed(text, key);
        }
        function onDemo(text) {
            if (!root.primary)
                return;
            field.clear();
            demoKeys.pending = text;
            demoKeys.restart();
        }
        function onShake() {
            shakeAnim.restart();
            root.won = false;
            root.failed = true;
            failClear.restart();
            if (!root.reactions || !root.primary) {
                field.clear();
                return;
            }
            field.fail();
        }
        function onSuccess() {
            root.failed = false;
            root.won = true;
            if (!root.reactions || !root.primary)
                return;
            field.win();
            jumpAnim.restart();
            // a wish: its star shows over the capsule a moment before the lock lets go
            const w = root.lockScope.wished;
            if (w) {
                root.got = w;
                root.lockScope.hold = Math.max(root.lockScope.hold, 1400);
            }
        }
    }
    Connections {
        target: Shell
        function onLockedChanged() {
            root.won = false;
            root.got = null;
        }
        function onLockPreviewChanged() {
            root.won = false;
            root.got = null;
        }
    }
}
