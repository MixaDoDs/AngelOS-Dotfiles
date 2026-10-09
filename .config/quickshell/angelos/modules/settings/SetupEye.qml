import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.widgets

// The first run's intro (SetupIntro) on a screen without the installer: one huge eye
// (shaders/setup_eye.frag). Over the first twenty seconds it opens out of the dark, watching the
// installer's bar on the other screen — where that screen really is, following the bar's edge as
// it fills. At the ophanim's first flash (timeline `glimpses`, 22 s) it snaps round to look
// straight out at you, the pupil wide, and trembles; under it Latin flickers by too fast to read
// whole (do not trust the angel — nor the demons). When the ophanim rises for good (50 s) the eye
// is gone: this computer's name stands in its place, glitching, and slanted rows of
// УМРИ УМРИ УМРИ spread over the screen around it to the end.
// All the screens run on the one clock (SetupIntro.t), so they keep together up to a frame.
Item {
    id: root

    property var intro: null
    property var here: null              // this screen
    property var host: null              // the one with the installer
    readonly property real t: intro ? intro.t : 0
    readonly property real turn: {
        const g = intro && intro.timeline.glimpses || [];
        return g.length ? g[0].t + 0.04 : 22;
    }
    readonly property bool watching: t >= turn
    readonly property real doom: intro ? intro.timeline.ophanim || 50 : 50
    readonly property bool dooming: t >= doom

    // where the installer's bar fills, seen from the middle of this screen: an angle each way, so
    // the iris still moves with the bar when the other screen is far
    readonly property point toBar: {
        if (!here || !host)
            return Qt.point(-1, 0);
        const barW = Math.min(host.width - Theme.u * 24, Theme.u * 250) - Theme.u * 16;
        const p = intro ? intro.progress : 0;
        const dx = host.x + host.width / 2 + (p - 0.5) * barW - (here.x + here.width / 2);
        const dy = host.y + host.height / 2 - (here.y + here.height / 2);
        const D = Math.max(here.width, here.height);
        return Qt.point(dx / Math.sqrt(dx * dx + D * D) * 1.25, dy / Math.sqrt(dy * dy + D * D) * 1.25);
    }
    // the turn: from the bar to you in a tenth of a second
    readonly property real turned: Math.max(0, Math.min(1, (t - turn) / 0.1))
    property point jitter: Qt.point(0, 0)

    ShaderEffect {
        id: eye
        visible: !root.dooming
        width: root.width
        height: root.height
        property size itemSize: Qt.size(width, height)
        property real px: Math.max(3, Math.floor(Math.min(width, height) / 150))
        property point look: Qt.point(root.toBar.x * (1 - root.turned) + root.jitter.x, root.toBar.y * (1 - root.turned) + root.jitter.y)
        property real open: 0.12 + 0.88 * Math.pow(Math.min(1, root.t / 20), 1.2)
        property real pupil: 0.36 + 0.16 * root.turned
        property real shown: Math.pow(Math.min(1, root.t / 20), 1.6)
        property real time: root.t
        fragmentShader: Qt.resolvedUrl("../../shaders/setup_eye.frag.qsb")
    }

    // looking at you: the iris and the whole eye tremble, more and more to the end
    Timer {
        interval: 40
        repeat: true
        running: root.visible && root.watching
        onTriggered: {
            const k = Math.min(1, (root.t - root.turn) / Math.max(1, (root.intro ? root.intro.length : 60) - root.turn));
            const a = 0.03 + 0.07 * k;
            root.jitter = Qt.point((Math.random() * 2 - 1) * a, (Math.random() * 2 - 1) * a * 0.6);
            const s = eye.px * Math.round(Math.random() * (1 + 2 * k));
            eye.x = Math.random() < 0.5 ? -s : s;
            eye.y = Math.round((Math.random() * 2 - 1) * (0.5 + k)) * eye.px;
        }
        onRunningChanged: if (!running) {
            root.jitter = Qt.point(0, 0);
            eye.x = 0;
            eye.y = 0;
        }
    }

    // ---- the Latin, looking at you: a phrase every few frames ----
    readonly property var latin: ["NOLI CREDERE ANGELO", "ANGELUS MENTITUR", "ANGELUS TE FALLIT", "ALIS EIUS NE CREDAS", "OCULI EIUS NUMQUAM DORMIUNT", "VIDET TE", "LUX QUOQUE FALLIT", "SED NEC DAEMONIBUS CREDE", "DAEMONES QUOQUE MENTIUNTUR", "NEMINI CREDE", "QUIS CUSTODIET IPSOS CUSTODES", "NON EST QUOD VIDETUR"]
    readonly property real eyeW: Math.min(width * 0.44, height * 0.62)
    PxText {
        visible: root.watching && !root.dooming
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height / 2 + root.eyeW * 0.46 + eye.px * 8
        width: root.width - eye.px * 16
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        font.pixelSize: eye.px * 6
        color: "#e8c870"
        // 70 ms a phrase, in a scrambled order
        text: root.latin[(Math.floor(Math.max(0, root.t - root.turn) / 0.07) * 7) % root.latin.length]
    }

    // ---- the doom: the computer's name, glitching, and УМРИ everywhere round it ----
    FileView {
        id: hostFile
        path: "/etc/hostname"
        printErrors: false
    }
    readonly property string hostName: (hostFile.loaded ? hostFile.text().trim() : "") || Quickshell.env("HOSTNAME") || "angelOS"
    readonly property real since: t - doom
    // a few of its letters broken at a time, more towards the end — still its name
    property string glitched: hostName
    Timer {
        interval: 50
        repeat: true
        running: root.visible && root.dooming
        onTriggered: {
            const k = 0.08 + 0.22 * Math.min(1, root.since / 10);
            const junk = "УМРИ█▓▒#%&@?!";
            let out = "";
            for (const ch of root.hostName)
                out += Math.random() < k ? junk[Math.floor(Math.random() * junk.length)] : ch;
            root.glitched = out;
        }
    }
    readonly property string word: glitched
    readonly property real rowH: eye.px * 9

    // the rows, slanted, spreading out from the middle, each sliding its own way
    Item {
        visible: root.dooming
        anchors.centerIn: parent
        width: Math.hypot(root.width, root.height)
        height: width
        rotation: -14
        Repeater {
            model: Math.ceil(Math.hypot(root.width, root.height) / root.rowH) + 1
            PxText {
                required property int index
                readonly property int fromMiddle: Math.abs(index - Math.floor(Math.hypot(root.width, root.height) / root.rowH / 2))
                readonly property real speed: (60 + (index * 37) % 90) * root.eyeW / 400 * (index % 2 ? 1 : -1)
                visible: root.since > 0.6 && fromMiddle <= (root.since - 0.6) * 5
                y: index * root.rowH
                x: ((root.since * speed) % (eye.px * 60)) - eye.px * 60
                font.pixelSize: eye.px * 7
                color: index % 3 ? "#b0141e" : "#e0303a"
                opacity: 0.55 + 0.45 * ((Math.floor(root.t * 15) + index) % 3 === 0 ? 1 : 0.6)
                text: ("УМРИ ").repeat(40)
            }
        }
    }
    // the name in the eye's place, red and blue apart, shaking
    Item {
        visible: root.dooming
        width: big.implicitWidth
        height: big.implicitHeight
        x: (root.width - width) / 2 + root.jitter.x * eye.px * 40
        y: (root.height - height) / 2 + root.jitter.y * eye.px * 40
        PxText {
            x: -eye.px * 2
            font.pixelSize: big.font.pixelSize
            color: "#ff2030"
            opacity: 0.8
            text: root.word
        }
        PxText {
            x: eye.px * 2
            font.pixelSize: big.font.pixelSize
            color: "#3050ff"
            opacity: 0.8
            text: root.word
        }
        PxText {
            id: big
            font.pixelSize: eye.px * 16
            color: "#f4eefc"
            text: root.word
        }
    }
}
