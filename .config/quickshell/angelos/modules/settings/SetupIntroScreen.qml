import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.y2k

// The first run's minute (SetupIntro) on one screen: the dark, an installer window that installs
// something it should not (on the screen with the questions), «Привет» and «Я тут» typed out
// above it, and at the bottom, small, the way out: space five times. SetupWake does the waking
// up over all of it. Gone at the cut: the wizard is behind it.
Item {
    id: root

    property var intro: null
    property bool hosting: false
    readonly property real t: intro ? intro.t : 0
    readonly property bool running: !!intro && intro.phase === "run"
    visible: !!intro && intro.holding

    Rectangle {
        anchors.fill: parent
        color: "#07060c"
    }

    // what it says it is doing, from when
    readonly property var status: [[0, I18n.t("Подготовка…", "Preparing…")], [4, I18n.t("Копирую файлы: heaven.dat", "Copying files: heaven.dat")], [9, I18n.t("Распаковываю крылья…", "Unpacking the wings…")], [13, I18n.t("Ищу пользователя…", "Looking for the user…")], [17, I18n.t("Пользователь найден.", "User found.")], [21, I18n.t("Проверяю сердцебиение…", "Checking the heartbeat…")], [26, I18n.t("ОШИБКА: что-то горит", "ERROR: something is burning")], [30, I18n.t("Не выключай компьютер.", "Do not turn off your computer.")], [37, I18n.t("Ты меня слышишь?", "Can you hear me?")], [43, I18n.t("Осталось немного.", "Almost there.")], [49, I18n.t("Осталось совсем немного.", "Almost, almost there.")], [54, I18n.t("Просыпайся.", "Wake up.")], [57, I18n.t("ПРОСЫПАЙСЯ.", "WAKE UP.")]]
    readonly property string now: {
        if (!running)
            return status[0][1];
        let s = status[0][1];
        for (const e of status)
            if (t >= e[0])
                s = e[1];
        return s;
    }
    // quick at first, stuck at two thirds while the tree falls, crawling to 99 % and staying there
    readonly property real progress: {
        if (!running)
            return 0;
        const p = [[0, 0], [12, 0.41], [22, 0.63], [31, 0.66], [46, 0.9], [55, 0.99], [60, 0.99]];
        for (let i = 1; i < p.length; i++)
            if (t <= p[i][0])
                return p[i - 1][1] + (p[i][1] - p[i - 1][1]) * (t - p[i - 1][0]) / (p[i][0] - p[i - 1][0]);
        return 0.99;
    }
    function typed(text, at) {
        return text.slice(0, Math.max(0, Math.min(text.length, Math.floor((t - at) * 7))));
    }

    // the ophanim, glimpsed first: in one corner of the screen after another, half out of sight,
    // a blink each (from `corners`, 35 s)
    SpriteRig {
        id: glimpse
        readonly property real from: root.intro ? root.intro.timeline.corners || 35 : 35
        readonly property int corner: Math.floor((root.t - from) / 0.7)
        readonly property bool shown: root.hosting && root.running && root.t >= from && corner < 4 && (root.t - from) % 0.7 < 0.45
        who: "angel"
        angelVariant: "ophanim"
        px: Math.max(2, Math.floor(root.width * 0.3 / 179))
        width: implicitWidth
        height: implicitHeight
        visible: shown
        // top left, bottom right, top right, bottom left
        x: [0, 1, 1, 0][Math.max(0, Math.min(3, corner))] ? root.width - width * 0.55 : -width * 0.45
        y: [0, 1, 0, 1][Math.max(0, Math.min(3, corner))] ? root.height - height * 0.55 : -height * 0.45
        tick: wings.n
    }

    // the ophanim for good: up from below near the end (a flash and a sting come with it:
    // SetupWake, the sound), its golden eye watching to the end
    SpriteRig {
        id: ophanim
        readonly property real moment: root.intro ? root.intro.timeline.ophanim || 50 : 50
        readonly property bool up: root.hosting && root.running && root.t >= moment
        who: "angel"
        angelVariant: "ophanim"
        px: Math.max(2, Math.floor(root.width * 0.7 / 179))
        width: implicitWidth
        height: implicitHeight
        flutter: true
        tick: wings.n
        visible: up
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height
        onUpChanged: if (up) {
            ophanimRise.restart();
        } else {
            ophanimRise.stop();
            y = root.height;
        }
        YAnimator {
            id: ophanimRise
            target: ophanim
            from: root.height
            to: root.height - ophanim.height * 0.8
            duration: 1400
            easing.type: Easing.OutBack
        }
        Timer {
            id: wings
            property int n: 0
            interval: 110
            repeat: true
            running: ophanim.up || glimpse.shown
            onTriggered: n++
        }
    }

    PxBox {
        id: win
        visible: root.hosting
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.u * 24, Theme.u * 250)
        height: body.implicitHeight + bar.height + Theme.u * 16
        color: Theme.face
        Rectangle {
            id: bar
            x: win.inset
            y: win.inset
            width: win.width - win.inset * 2
            height: barText.implicitHeight + Theme.u * 4
            color: Theme.accent
            PxText {
                id: barText
                x: Theme.u * 4
                anchors.verticalCenter: parent.verticalCenter
                font.bold: true
                color: Theme.dark ? Theme.desk : "#ffffff"
                text: I18n.t("angelOS — установка", "angelOS — setup")
            }
        }
        Column {
            id: body
            x: Theme.u * 8
            y: bar.y + bar.height + Theme.u * 6
            width: win.width - Theme.u * 16
            spacing: Theme.u * 4
            PxText {
                kind: "title"
                text: I18n.t("Установка angelOS", "Installing angelOS")
            }
            PxText {
                width: parent.width
                elide: Text.ElideRight
                readonly property bool alarm: root.running && (root.t >= 26 && root.t < 30 || root.t >= 57)
                dim: !alarm
                color: alarm ? Theme.danger : Theme.textDim
                text: root.now
            }
            // the bar: whole blocks
            Row {
                id: blocks
                readonly property int count: 24
                readonly property int cell: Math.floor((parent.width - spacing * (count - 1)) / count)
                spacing: Theme.u
                Repeater {
                    model: blocks.count
                    Rectangle {
                        required property int index
                        width: blocks.cell
                        height: Theme.u * 6
                        color: index < Math.floor(root.progress * blocks.count) ? Theme.accent : Theme.sunken
                    }
                }
            }
            PxText {
                kind: "tiny"
                dim: true
                text: Math.floor(root.progress * 100) + " %"
            }
        }
    }

    // the words, typed out above the window
    Column {
        visible: root.hosting && root.running
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: win.top
        anchors.bottomMargin: Theme.u * 16
        spacing: Theme.u * 4
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            kind: "huge"
            font.pixelSize: Theme.sizeHuge * 2
            color: "#f4eefc"
            text: root.typed(I18n.t("Привет", "Hi"), root.intro ? root.intro.timeline.hello || 15 : 15)
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            kind: "huge"
            font.pixelSize: Theme.sizeHuge * 2
            color: "#ff5a6e"
            text: root.typed(I18n.t("Я тут", "I'm here"), root.intro ? root.intro.timeline.here || 25 : 25)
        }
    }

    // the way out
    Column {
        visible: root.hosting
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.u * 8
        spacing: Theme.u * 2
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            kind: "tiny"
            opacity: 0.25
            color: "#8a8498"
            text: I18n.t("Нажми пробел 5 раз, чтобы пропустить", "Press space 5 times to skip")
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.u * 2
            Repeater {
                model: root.intro ? root.intro.pressesToSkip : 5
                Rectangle {
                    required property int index
                    width: Theme.u * 3
                    height: width
                    opacity: 0.25
                    color: root.intro && index < root.intro.presses ? "#f4eefc" : "#3a3546"
                }
            }
        }
    }
}
