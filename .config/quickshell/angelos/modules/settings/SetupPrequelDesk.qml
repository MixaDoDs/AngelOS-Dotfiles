pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// The first run's intro, its first minute: what is on her three monitors on the night of
// 31.12.2002, as a picture 960×240 — three desktops of 320×240 side by side. SetupPrequel shows
// the first whole (the screen filling yours) and fits all three into the blank screens of the
// room's pictures (shaders/setup_prequel.frag).
//   0  the big one: a board, a thread of those alone tonight. She types an answer — slowly,
//      stops when he writes, goes on, starts a sentence about him and rubs it out, sends the
//      rest. Somebody answers with a link to a game; she presses it, it comes down while she
//      is at the pills, starts by itself — «Наденьте очки»; then what the goggles show
//   1  the messenger: everything he wrote tonight, unanswered
//   2  the player, and the clock running to midnight
// In Russian whatever the shell's language: it is her screen (SetupPrequel puts the words under
// the picture for the others). `t`: s into the minute; `b`: its moments (SetupIntro.preBeats).
Item {
    id: root

    width: 960
    height: 240

    property real t: 0
    property var b: ({})
    property bool calm: false

    readonly property color ink: "#4a3560"
    readonly property color face: "#fbeef6"
    readonly property color edge: "#6b4a8f"
    readonly property color bar: "#b98be0"
    readonly property color pink: "#ff7fb0"
    readonly property var msgs: b.messages || []
    readonly property bool mirror: t >= (b.goggles || 1e9)
    // 23:59:xx at the start, midnight at `b.midnight`
    readonly property string clock: clockAt(t)
    function clockAt(at: real): string {
        const s = (86400 - Math.round(b.midnight || 46) + Math.floor(at)) % 86400;
        const two = n => (n < 10 ? "0" : "") + n;
        return two(Math.floor(s / 3600)) + ":" + two(Math.floor(s / 60) % 60) + ":" + two(s % 60);
    }

    // ---- what she types: the answer in two goes, the sentence she rubs out ----
    readonly property string answer: "Да... есть такое."
    readonly property string unsaid: " я его всё ещё"
    readonly property var goes: b.typing || []
    readonly property real sent: b.send || 1e9
    readonly property string typed: {
        if (t >= sent || goes.length < 3)
            return "";
        const part = (i, n) => Math.round(n * Math.max(0, Math.min(1, (t - goes[i][0]) / (goes[i][1] - goes[i][0]))));
        // (the first two goes share the answer by how long they are)
        const first = Math.round(answer.length * (goes[0][1] - goes[0][0]) / (goes[0][1] - goes[0][0] + goes[1][1] - goes[1][0]));
        const rubbed = b.erase ? Math.max(0, Math.min(1, (t - b.erase[0]) / (b.erase[1] - b.erase[0]))) : 0;
        return answer.slice(0, part(0, first) + part(1, answer.length - first)) + unsaid.slice(0, Math.round(part(2, unsaid.length) * (1 - rubbed)));
    }

    // ---- the pointer: her hand on the mouse ----
    // where it goes: to every cross and button she presses, and to what she reads
    readonly property var ways: {
        const k = [[11.5, 130, 118, false]];
        msgs.forEach(m => k.push([m.until, m.x + 119, m.y + 7, true]));
        k.push([sent, 202, 207, true]);
        if (b.replies)
            k.push([b.replies[0] + 1.6, 96, 150, false]);
        if (b.download)
            k.push([b.download, 70, 166, true]);
        if (b.disc)
            k.push([b.disc + 2.2, 164, 166, false]);
        return k.filter(c => c[0] < 1e8).sort((a, c) => a[0] - c[0]);
    }
    // her hands on the keys: the mouse lies still
    readonly property bool atKeys: goes.some(g => t >= g[0] - 0.4 && t < g[1] + 0.3) || !!b.erase && t >= b.erase[0] - 0.3 && t < b.erase[1] + 0.2
    // (a slow wander and a tremble: −1…1, smooth)
    function sway(x: real, seed: int): real {
        const at = n => {
            const s = Math.sin((n + seed * 17) * 127.1) * 43758.5453;
            return (s - Math.floor(s)) * 2 - 1;
        };
        const i = Math.floor(x), f = x - i, u = f * f * (3 - 2 * f);
        return at(i) * (1 - u) + at(i + 1) * u;
    }
    // each way: off quickly, slowing, not quite straight, a little past the place and back; there
    // a quarter of a second before the press. Between them the hand is never quite still.
    readonly property point pointer: {
        let from = [256, 214], x = from[0], y = from[1];
        for (const c of ways) {
            if (t < c[0]) {
                const f = Math.max(0, Math.min(1, (t - c[0] + 1.25) / 1.0));
                const e = 1 - Math.pow(1 - f, 3);
                const dx = c[1] - from[0], dy = c[2] - from[1], far = Math.hypot(dx, dy) || 1;
                const arc = Math.sin(Math.PI * e) * far * 0.08;
                const past = f > 0.75 && f < 1 ? Math.sin((f - 0.75) / 0.25 * Math.PI) * 3 : 0;
                x = from[0] + dx * e - dy / far * arc + dx / far * past;
                y = from[1] + dy * e + dx / far * arc + dy / far * past;
                break;
            }
            from = c.slice(1);
            x = from[0];
            y = from[1];
        }
        if (!atKeys) {
            x += 2.2 * sway(t * 0.9, 1) + 0.7 * sway(t * 5.3, 2);
            y += 1.8 * sway(t * 0.8, 3) + 0.7 * sway(t * 4.7, 4);
        }
        return Qt.point(Math.round(x), Math.round(y));
    }

    component T: Text {
        font.family: Theme.fontHellText
        font.pixelSize: 11
        renderType: Text.NativeRendering
        antialiasing: false
        color: root.ink
    }
    component Win: Rectangle {
        id: win
        property string title: ""
        default property alias body: inner.data
        color: root.face
        border.color: root.edge
        border.width: 1
        Rectangle {
            x: 1
            y: 1
            width: win.width - 2
            height: 13
            color: root.bar
            T {
                x: 3
                y: 0
                color: "#ffffff"
                text: win.title
            }
            Rectangle {
                x: parent.width - 11
                y: 2
                width: 9
                height: 9
                color: root.pink
                border.color: root.edge
                border.width: 1
            }
        }
        Item {
            id: inner
            x: 5
            y: 17
            width: win.width - 10
            height: win.height - 21
            clip: true
        }
    }

    // ---- 0: the big monitor ----
    Rectangle {
        id: main
        width: 320
        height: 240
        color: "#f3c6dc"
        clip: true
        // a wallpaper of two pinks in squares
        Grid {
            columns: 10
            Repeater {
                model: 80
                Rectangle {
                    required property int index
                    width: 32
                    height: 32
                    color: (index + Math.floor(index / 10)) % 2 ? "#f3c6dc" : "#efb8d3"
                }
            }
        }
        Win {
            x: 4
            y: 4
            width: 238
            height: 220
            title: "НОЧНОЙ ЧАН — /new/"
            // the thread, the newest at the bottom; the older going up out of sight
            Item {
                width: parent.width
                height: parent.height - 50
                clip: true
                Column {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: [{
                                "at": -1,
                                "n": "4466 31/12/02 23:31",
                                "s": "Че, рассказывайте как будете\nпраздновать? Клянусь, еще 1 год\nи выстрелю себе в голову"
                            }, {
                                "at": -1,
                                "n": "4468",
                                "s": "никак. оливье и монитор"
                            }, {
                                "at": -1,
                                "n": "4471",
                                "s": "третий год так. привык"
                            }, {
                                "at": -1,
                                "n": "4475",
                                "s": "вы тоже одиноки?"
                            }, {
                                "at": root.sent,
                                "n": "4477",
                                "s": ">>4475\n" + root.answer,
                                "own": true
                            }, {
                                "at": (root.b.replies || [1e9, 1e9])[0],
                                "n": "4478",
                                "s": ">>4477 Слышай, я хз, держи\nторрент ссылку, там игрушка\nинтересная, развей голову\n→ sohrani_sebya.torrent"
                            }, {
                                "at": (root.b.replies || [1e9, 1e9])[1],
                                "n": "4479",
                                "s": ">>4478 не запускай одна"
                            }]
                        Rectangle {
                            id: post
                            required property var modelData
                            visible: root.t >= modelData.at
                            width: parent.width
                            height: body.implicitHeight + 6
                            color: modelData.own ? "#ffe1ee" : "#f6dcec"
                            border.color: "#e3b6d2"
                            border.width: 1
                            T {
                                id: body
                                x: 4
                                y: 2
                                width: post.width - 8
                                lineHeight: 0.95
                                text: "Аноним №" + post.modelData.n + "\n" + post.modelData.s
                            }
                        }
                    }
                }
            }
            // the answer's box, the caret blinking in it
            Rectangle {
                y: parent.height - 46
                width: parent.width
                height: 30
                color: "#ffffff"
                border.color: root.edge
                border.width: 1
                T {
                    x: 3
                    y: 2
                    width: parent.width - 6
                    wrapMode: Text.Wrap
                    text: root.typed + (Math.floor(root.t * 2) % 2 && !root.mirror ? "_" : "")
                }
            }
            Rectangle {
                x: parent.width - 62
                y: parent.height - 14
                width: 62
                height: 14
                color: Math.abs(root.t - root.sent - 0.1) < 0.12 ? "#d9548c" : root.pink
                border.color: root.edge
                border.width: 1
                T {
                    anchors.centerIn: parent
                    color: "#ffffff"
                    text: "отправить"
                }
            }
        }
        // his messages, one over another
        Repeater {
            model: root.msgs
            Win {
                id: pop
                required property var modelData
                required property int index
                visible: root.t >= modelData.at && root.t < modelData.until
                x: modelData.x
                y: modelData.y
                width: 126
                height: 64
                title: "sneg пишет"
                T {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: pop.modelData.ru
                }
            }
        }
        // the game coming down, while she is away at the pills
        Win {
            id: coming
            visible: root.t >= (root.b.download || 1e9) && root.t < (root.b.disc || 1e9)
            x: 176
            y: 150
            width: 140
            height: 62
            title: "Загрузка"
            readonly property real done: Math.max(0, Math.min(1, (root.t - (root.b.download || 0)) / ((root.b.disc || 1) - (root.b.download || 0) - 1)))
            T {
                text: "sohrani_sebya.zip"
            }
            Rectangle {
                y: 15
                width: parent.width
                height: 9
                color: "#ffffff"
                border.color: root.edge
                border.width: 1
                Rectangle {
                    x: 1
                    y: 1
                    width: Math.round((parent.width - 2) * coming.done)
                    height: 7
                    color: root.pink
                }
            }
            T {
                y: 26
                text: Math.floor(coming.done * 100) + " %"
            }
        }
        // …down: it starts by itself
        Win {
            visible: root.t >= (root.b.disc || 1e9) && !root.mirror
            x: 58
            y: 30
            width: 204
            height: 176
            title: "sohrani_sebya.exe"     // suffix-ok: her machine of 2002, not an angelOS window
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: Qt.resolvedUrl("../y2k/sprites/angel-ophanim/body.png")
                smooth: false
                width: sourceSize.width * 0.66
                height: sourceSize.height * 0.66
            }
            T {
                y: 84
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: 22
                text: "СОХРАНИ СЕБЯ"
            }
            T {
                y: 110
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#8a6aa8"
                text: "© 2002 OPHANIM SOFT"
            }
            T {
                y: 130
                anchors.horizontalCenter: parent.horizontalCenter
                color: Math.floor(root.t * 3) % 2 ? root.pink : root.ink
                text: "Наденьте очки"
            }
        }
        // the pointer
        Image {
            visible: !root.mirror
            x: root.pointer.x
            y: root.pointer.y
            source: Qt.resolvedUrl("../../data/intro/cursor.png")
            smooth: false
        }
        // the bar at the bottom
        Rectangle {
            y: 226
            width: 320
            height: 14
            color: root.bar
            visible: !root.mirror
            T {
                x: 4
                color: "#ffffff"
                text: "Пуск"
            }
            T {
                anchors.right: parent.right
                anchors.rightMargin: 4
                color: "#ffffff"
                text: root.clock.slice(0, 5)
            }
        }
        // the goggles on: the monitor shows what they show, small, twice
        Rectangle {
            anchors.fill: parent
            visible: root.mirror
            color: "#06050a"
            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    readonly property real deep: Math.max(0, Math.min(1, (root.t - (root.b.goggles || 0)) / 22))
                    x: 20 + index * 148
                    y: 54
                    width: 132
                    height: 132
                    radius: 66
                    color: Qt.rgba(0.34 + 0.46 * deep, 0.40 - 0.18 * deep, 0.74 - 0.62 * deep, 1)
                    Rectangle {
                        anchors.centerIn: parent
                        width: 60 + 10 * Math.sin(root.t * 2 + parent.index)
                        height: width
                        radius: width / 2
                        color: Qt.rgba(0.05 + 0.9 * parent.deep * parent.deep, 0.03 + 0.25 * parent.deep, 0.08, 1)
                    }
                }
            }
        }
    }

    // ---- 1: the messenger ----
    Rectangle {
        x: 320
        width: 320
        height: 240
        color: "#d9c6ef"
        clip: true
        Win {
            x: 6
            y: 6
            width: 308
            height: 228
            title: "sneg — разговор"
            Column {
                width: parent.width
                spacing: 4
                T {
                    color: "#8a6aa8"
                    text: "sneg в сети · ты: невидимка"
                }
                Repeater {
                    model: [{
                            "at": -1,
                            "ru": "[21:07] ну и сиди одна"
                        }, {
                            "at": -1,
                            "ru": "[22:30] ладно. прости"
                        }].concat(root.msgs)
                    Rectangle {
                        id: line
                        required property var modelData
                        visible: root.t >= modelData.at
                        width: parent.width
                        height: said.implicitHeight + 6
                        color: modelData.at < 0 ? "#f1e3f7" : "#ffe1ee"
                        border.color: "#e3b6d2"
                        border.width: 1
                        T {
                            id: said
                            x: 4
                            y: 2
                            width: line.width - 8
                            wrapMode: Text.WordWrap
                            text: (line.modelData.at < 0 ? "" : "[" + root.clockAt(line.modelData.at).slice(0, 5) + "] ") + line.modelData.ru
                        }
                    }
                }
                T {
                    readonly property int unread: root.msgs.filter(m => root.t >= m.at).length
                    visible: unread > 0
                    color: root.pink
                    text: "непрочитанных: " + unread
                }
            }
        }
    }

    // ---- 2: the player and the clock ----
    Rectangle {
        x: 640
        width: 320
        height: 240
        color: "#2a2140"
        clip: true
        Win {
            x: 20
            y: 14
            width: 280
            height: 96
            title: "плеер"
            T {
                x: -Math.floor(root.t * 9) % 240
                text: "ночной эфир — трек 07.mp3 *** ночной эфир — трек 07.mp3 ***"
            }
            Row {
                y: 20
                spacing: 3
                Repeater {
                    model: 26
                    Rectangle {
                        required property int index
                        readonly property real level: 0.5 + 0.5 * Math.sin(Math.floor(root.t * 4) * (1.3 + index * 0.37) + index)
                        width: 7
                        height: 50
                        color: "transparent"
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: 7
                            // quieter once she is in the goggles' headphones
                            height: Math.round((4 + 44 * parent.level) * (root.mirror ? 0.3 : 1))
                            color: root.pink
                        }
                    }
                }
            }
        }
        T {
            y: 132
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 55
            color: root.t >= (root.b.midnight || 1e9) ? "#ffffff" : "#d9c6ef"
            text: root.clock
        }
        T {
            y: 200
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#8a6aa8"
            text: root.t >= (root.b.midnight || 1e9) ? "1 января 2003" : "31 декабря 2002"
        }
    }
}
