pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// The 2004 lock (Settings → Lock → Look: 2004): the game is paused at a save point. The layered
// wallpaper stays alive and sharp, the clock stands in the scene between its layers (SaveClock
// in the scene's depth_text place), and the login is a memory card's save slot: three lives
// for wrong passwords, "loading…" at the right one. A plain picture: the clock over its top.
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
    readonly property string clockText: Qt.formatTime(now, "HH") + (now.getSeconds() % 2 || !reactions ? ":" : " ") + Qt.formatTime(now, "mm")
    readonly property real boxScale: Math.max(1, Math.round(Theme.u * (Config.lock.size || 1)) / Theme.u)
    readonly property int lives: Math.max(0, 3 - lockScope.fails)
    property real loading: 0
    readonly property point fxOrigin: {
        if (!primary || width <= 0)
            return Qt.point(0.5, 0.5);
        const p = boxHolder.mapToItem(root, boxHolder.width / 2, boxHolder.height / 2);
        return Qt.point(p.x / width, p.y / height);
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.desk
    }
    Image {
        anchors.fill: parent
        source: root.wall ? "file://" + Wallpapers.display(root.wall) : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.ceil(width * Math.max(1, Screen.devicePixelRatio)), Math.ceil(height * Math.max(1, Screen.devicePixelRatio)))
        asynchronous: true
        smooth: false
        visible: !scene.item
        onStatusChanged: if (status === Image.Error)
            Wallpapers.fit(root.wall)
    }
    Loader {
        id: scene
        // the scene's place for it is in view (a tall screen crops it away)
        readonly property bool clockIn: {
            if (!item || item.depthText === null)
                return false;
            const r = item.depthText.rect, k = item.k, x = item.ox + r[0] * k, y = item.oy + r[1] * k;
            return x >= 0 && y >= 0 && x + r[2] * k <= width && y + r[3] * k <= height;
        }
        anchors.fill: parent
        active: Wallpapers.sceneOf(root.wall) !== ""
        sourceComponent: SceneWall {
            id: wall
            dir: Wallpapers.sceneOf(root.wall)
            still: Motion.still || !StreamMode.effectsOn(root.screenName)
            wind: SceneWind.strength
            windDir: SceneWind.dir
            pulse: SceneWind.pulse
            seed: SceneWind.seed
            readonly property bool running: !still && !root.lockScope.unlocking
            Timer {
                running: wall.running && DeskClock.sceneFps > 0
                interval: 1000 / Math.max(1, DeskClock.sceneFps)
                repeat: true
                onTriggered: wall.time = (wall.time + interval / 1000) % 3600
            }
            FrameAnimation {
                running: wall.running && DeskClock.sceneFps <= 0
                onTriggered: wall.time = (wall.time + Math.min(frameTime, 0.1)) % 3600
            }
            depth: SaveClock {
                anchors.fill: parent
                k: wall.k
                palette: wall.palette
                text: root.clockText
            }
        }
    }
    // no place in the picture: over its top, on the scene's grid (or the shell's)
    SaveClock {
        visible: !scene.clockIn
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.12)
        k: scene.item ? scene.item.k : Theme.u * 3
        width: Math.min(176 * k, parent.width)
        height: 56 * k
        palette: scene.item ? scene.item.palette : []
        text: root.clockText
    }

    // the pause, top left
    Column {
        x: Theme.u * 14
        y: Theme.u * 12
        spacing: Theme.u * 2
        Row {
            spacing: Theme.u * 4
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.u * 2
                Repeater {
                    model: 2
                    Rectangle {
                        width: Theme.u * 3
                        height: Theme.u * 11
                        color: "#ffffff"
                        border.width: Theme.u
                        border.color: Theme.edge
                    }
                }
            }
            PxText {
                text: I18n.t("ПАУЗА", "PAUSED")
                kind: "big"
                color: "#ffffff"
                style: Text.Outline
                styleColor: Theme.edge
            }
        }
        PxText {
            text: I18n.t("игра сохранена в ", "game saved at ") + Qt.formatTime(new Date(root.lockScope.lockedAt || root.now.getTime()), "HH:mm")
            color: "#ffffff"
            style: Text.Outline
            styleColor: Theme.edge
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

    // ---- the save slot ----
    Item {
        id: boxHolder
        visible: root.primary
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(parent.height * 0.1)
        width: card.width * root.boxScale
        height: card.height * root.boxScale
        property real shakeX: 0
        transform: Translate {
            x: boxHolder.shakeX
        }
        Keys.onEscapePressed: if (root.preview)
            Shell.lockPreview = false

        PxBox {
            id: card
            transformOrigin: Item.TopLeft
            scale: root.boxScale
            layer.enabled: root.boxScale !== 1
            layer.smooth: false
            width: Theme.u * 230
            height: slot.implicitHeight + Theme.u * 16
            color: Theme.face
            edgeColor: Theme.edge
            shadow: true

            Column {
                id: slot
                x: Theme.u * 8
                y: Theme.u * 8
                width: parent.width - Theme.u * 16
                spacing: Theme.u * 5

                // the card's label strip
                Rectangle {
                    width: parent.width
                    height: head.implicitHeight + Theme.u * 4
                    color: Theme.accent
                    PxText {
                        id: head
                        x: Theme.u * 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t("КАРТА ПАМЯТИ (8 МБ) · СЛОТ 1", "MEMORY CARD (8 MB) · SLOT 1") + (root.preview ? I18n.t(" · предпросмотр", " · preview") : "")
                        kind: "tiny"
                        color: Theme.inkOn(Theme.accent)
                        font.bold: true
                    }
                    PxText {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.u * 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: "angelOS 2004"
                        kind: "tiny"
                        color: Theme.inkOn(Theme.accent)
                    }
                }
                Row {
                    width: parent.width
                    spacing: Theme.u * 6
                    PxIcon {
                        id: cardIcon
                        anchors.verticalCenter: parent.verticalCenter
                        pixel: Theme.u * 3
                        fill: Theme.accent
                        fill3: Theme.accent3
                        bitmap: ["##########..", "#ffffffff##.", "#fwwwwwwff##", "#fw####wfff#", "#fw#oo#wfff#", "#fw####wfff#", "#fwwwwwwfff#", "#ffffffffff#", "#ffffffffff#", "#f#y#y#y#yf#", "#f#y#y#y#yf#", "############"]
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - cardIcon.width - lifeRow.width - parent.spacing * 2
                        spacing: Theme.u
                        PxText {
                            text: I18n.t("Точка сохранения", "Save point")
                            kind: "title"
                            font.bold: true
                        }
                        PxText {
                            text: (Quickshell.env("USER") || "angel") + " · " + Qt.locale(Config.appearance.language === "en" ? "en_US" : "ru_RU").toString(root.now, "dddd, d MMMM")
                            dim: true
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        PxText {
                            text: I18n.t("на паузе ", "paused ") + Math.floor(root.lockedFor / 60) + ":" + ("0" + root.lockedFor % 60).slice(-2)
                            kind: "tiny"
                            dim: true
                        }
                    }
                    // a life for each wrong password; none left is no lockout, just shame
                    Row {
                        id: lifeRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.u * 2
                        Repeater {
                            model: 3
                            PxIcon {
                                required property int index
                                name: index < root.lives ? "heart" : "heartBroken"
                                pixel: Theme.u * 2
                                fill: index < root.lives ? Theme.accent : Theme.textDim
                            }
                        }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: Theme.u
                    color: Theme.edge
                }
                // the password, or the loading bar once it is right
                Row {
                    visible: root.loading <= 0
                    width: parent.width
                    spacing: Theme.u * 4
                    PxText {
                        id: cont
                        anchors.verticalCenter: parent.verticalCenter
                        text: "▶ " + I18n.t("Продолжить", "Continue")
                        kind: "title"
                        color: Theme.accent
                        font.bold: true
                    }
                    HeartPassword {
                        id: field
                        width: parent.width - cont.width - go.width - parent.spacing * 2
                        busy: root.lockScope.busy
                        reactions: root.reactions
                        placeholder: I18n.t("пароль", "password")
                        onAccepted: root.lockScope.submit(text)
                        onHurried: root.lockScope.hurry()
                        onTyped: (length, added) => root.lockScope.typed(length, added)
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
                Column {
                    visible: root.loading > 0
                    width: parent.width
                    spacing: Theme.u * 3
                    PxText {
                        text: I18n.t("ЗАГРУЗКА… ", "LOADING… ") + Math.round(root.loading * 100) + "%"
                        kind: "title"
                        color: Theme.accent
                        font.bold: true
                    }
                    Row {
                        id: bar
                        readonly property int n: 24
                        spacing: Theme.u
                        Repeater {
                            model: bar.n
                            Rectangle {
                                required property int index
                                width: Math.floor((slot.width - bar.spacing * (bar.n - 1)) / bar.n)
                                height: Theme.u * 6
                                color: index < Math.round(root.loading * bar.n) ? Theme.accent : Theme.sunken
                                border.width: Math.floor(Theme.u / 2)
                                border.color: Theme.edge
                            }
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
                PxText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    visible: text !== ""
                    text: root.lives === 0 && root.lockScope.fails > 0 && !root.lockScope.busy ? I18n.t("GAME OVER… шучу, жизни не кончаются. Ещё раз?", "GAME OVER… kidding, lives never run out. Again?") : root.lockScope.status || (root.preview ? I18n.t("предпросмотр: пароль не проверяется, Esc — выход", "preview: the password is not checked, Esc to exit") : "")
                    color: root.lockScope.fails > 0 ? Theme.danger : Theme.textDim
                }
            }
        }
    }
    // the buttons' hint under the card, like a console's
    PxText {
        visible: root.primary
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: boxHolder.bottom
        anchors.topMargin: Theme.u * 6
        text: "[Enter] " + I18n.t("загрузить", "load") + (root.preview ? "   [Esc] " + I18n.t("выйти", "exit") : "")
        color: "#ffffff"
        style: Text.Outline
        styleColor: Theme.edge
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
    NumberAnimation {
        id: loadAnim
        target: root
        property: "loading"
        from: 0.01
        to: 1
        duration: 600
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
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
            if (root.reactions && root.primary)
                field.fail();
            else
                field.clear();
        }
        function onSuccess() {
            if (!root.primary || !root.reactions || Motion.still)
                return;
            field.win();
            loadAnim.restart();
            root.lockScope.hold = Math.max(root.lockScope.hold, 700);
        }
        function onUnlockingChanged() {
            if (!root.lockScope.unlocking) {
                loadAnim.stop();
                root.loading = 0;
            }
        }
    }
}
