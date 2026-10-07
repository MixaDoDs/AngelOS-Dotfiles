import QtQuick
import qs.config
import qs.widgets

// Someone talks in a circle's menu look (CircleToy's games): a speech bubble over `at` with
// the speaker's name, the words typed out, and the answers to pick (choices: [{label, run}]).
// A click on the bubble shows the rest of the words, then closes it when there's nothing to
// pick; `autoHide` (ms) closes it by itself. The look's Esc should hide() it first.
Item {
    id: talk

    required property var menu              // RadialMenu
    property point at: Qt.point(menu.cx, menu.cy)
    property string who: ""
    property string text: ""
    property var choices: []
    property bool open: false
    property int typed: 0
    property bool loud: false               // shouting: the accent's border, bold
    readonly property bool done: typed >= text.length
    signal closed

    function say(speaker, words, answers, autoHide, shout) {
        who = speaker || "";
        text = words || "";
        choices = answers || [];
        loud = !!shout;
        typed = Motion.still ? text.length : 0;
        open = true;
        hideTimer.stop();
        if (autoHide > 0) {
            hideTimer.interval = autoHide + text.length * 25;
            hideTimer.start();
        }
    }
    function hide() {
        if (!open)
            return;
        open = false;
        hideTimer.stop();
        closed();
    }
    anchors.fill: parent
    z: 20

    Timer {
        interval: 22
        repeat: true
        running: talk.open && !talk.done
        onTriggered: talk.typed = Math.min(talk.text.length, talk.typed + 2)
    }
    Timer {
        id: hideTimer
        onTriggered: talk.hide()
    }
    Connections {
        target: talk.menu && talk.menu.opened ? talk.menu : null
        ignoreUnknownSignals: true
        function onOpened() {
            talk.open = false;
        }
    }

    Rectangle {
        id: bubble
        readonly property real room: talk.at.y - height - Theme.u * 12
        visible: talk.open && talk.menu.reveal > 0.5
        width: Math.min(Theme.u * 170, talk.width - Theme.u * 8)
        height: col.implicitHeight + Theme.u * 8
        x: Math.max(Theme.u * 4, Math.min(talk.width - width - Theme.u * 4, talk.at.x - width / 2))
        y: room > Theme.u * 4 ? room : talk.at.y + Theme.u * 12
        color: Theme.hellPlate
        border.width: Math.max(1, Theme.u * (talk.loud ? 1 : 0.5))
        border.color: talk.loud ? Theme.hellAccent : Theme.hellRim
        // the tail, towards the one speaking
        Rectangle {
            readonly property bool above: bubble.y < talk.at.y
            width: Theme.u * 4
            height: width
            rotation: 45
            x: Math.max(Theme.u * 2, Math.min(bubble.width - width - Theme.u * 2, talk.at.x - bubble.x - width / 2))
            y: above ? bubble.height - height / 2 : -height / 2
            color: Theme.hellPlate
            border.width: bubble.border.width
            border.color: bubble.border.color
            z: -1
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!talk.done)
                    talk.typed = talk.text.length;
                else if (!talk.choices.length)
                    talk.hide();
            }
        }
        Column {
            id: col
            x: Theme.u * 4
            y: Theme.u * 4
            width: bubble.width - Theme.u * 8
            spacing: Theme.u * 3
            PxText {
                visible: talk.who !== ""
                kind: "tiny"
                font.bold: true
                color: Theme.hellAccent
                text: talk.who
            }
            // the words, typed out; the full text keeps the size from jumping
            Item {
                width: col.width
                height: full.implicitHeight
                PxText {
                    id: full
                    width: parent.width
                    wrapMode: Text.Wrap
                    opacity: 0
                    font.bold: talk.loud
                    text: talk.text
                }
                PxText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: Theme.hellText
                    font.bold: talk.loud
                    text: talk.text.slice(0, talk.typed)
                }
            }
            Flow {
                visible: talk.done && talk.choices.length > 0
                width: col.width
                spacing: Theme.u * 3
                Repeater {
                    model: talk.choices
                    Rectangle {
                        id: answer
                        required property var modelData
                        width: lbl.implicitWidth + Theme.u * 8
                        height: lbl.implicitHeight + Theme.u * 4
                        color: pick.containsMouse ? Theme.hellFaceAlt : Theme.hellBody
                        border.width: Math.max(1, Theme.u / 2)
                        border.color: pick.containsMouse ? Theme.hellAccent : Theme.hellRim
                        PxText {
                            id: lbl
                            anchors.centerIn: parent
                            kind: "tiny"
                            font.bold: pick.containsMouse
                            color: Theme.hellText
                            text: answer.modelData.label
                        }
                        MouseArea {
                            id: pick
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: answer.modelData.run()
                        }
                    }
                }
            }
            PxText {
                visible: talk.done && !talk.choices.length && !hideTimer.running
                kind: "tiny"
                color: Theme.hellTextDim
                text: I18n.t("▸ клик — закрыть", "▸ click to close")
            }
        }
    }
}
