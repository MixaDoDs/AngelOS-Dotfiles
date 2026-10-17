pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// A call on the phone's screen (PhoneScreen, PhoneLine.call): who rings (her face, or the
// system's bell), then her lines typed out with her voice and your answers on 1 2 3. The
// green key or OK answers, the red one declines or hangs up; opening the lid answers too
// (Phone). The clock counts the call's time.
Item {
    id: root

    required property var phone
    readonly property int k: Theme.u
    readonly property var call: PhoneLine.call
    // her face: her calls, and the pranks made in her voice (or the other one's)
    readonly property string face: !call ? "" : call.kind === "her" ? call.who : call.kind === "prank" && (call.voice === "angel" || call.voice === "demon") ? call.voice : ""
    readonly property bool her: face !== ""
    readonly property color ink: phone.screenInk
    readonly property color dimInk: phone.screenDim

    function key(k) {
        if (!call)
            return false;
        if (PhoneLine.ringing) {
            // the taco answers only edge-on to the ear (Phone)
            if ((k === "call" || k === "ok") && !call.outgoing && PhoneLine.model === "ngage")
                root.phone.wiggle();
            else if ((k === "call" || k === "ok") && !call.outgoing)
                PhoneLine.answer();
            else if (k === "end")
                PhoneLine.decline();
            return true;
        }
        if (k === "end") {
            PhoneLine.hangUp();
            return true;
        }
        const i = "123".indexOf(k);
        if (i >= 0)
            PhoneLine.choose(i);
        return true;
    }

    property int tick: 0
    Timer {
        interval: 125
        running: root.visible
        repeat: true
        onTriggered: root.tick++
    }
    property double now: Date.now()
    Timer {
        interval: 1000
        running: root.visible && PhoneLine.talking
        repeat: true
        onTriggered: root.now = Date.now()
    }
    function clock(ms) {
        const s = Math.max(0, Math.floor(ms / 1000));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // ---- who ----
    Row {
        id: head
        width: parent.width
        spacing: root.k * 2
        Item {
            width: root.k * 22
            height: root.k * 22
            PhoneCharm {
                visible: root.her
                anchors.centerIn: parent
                who: root.face || "angel"
                pixel: root.k
                tick: root.tick
                talk: PhoneLine.speaking
                // ringing: she bounces with the rings
                y: PhoneLine.ringing && root.tick % 4 < 2 ? -root.k : 0
            }
            PxIcon {
                visible: !root.her
                anchors.centerIn: parent
                name: root.call && root.call.voice === "bark" ? "skull" : root.call && root.call.voice === "robot" ? "bot" : "bell"
                pixel: root.k * 2
                rotation: PhoneLine.ringing ? (root.tick % 2 ? 12 : -12) : 0
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - root.k * 24
            PxText {
                width: parent.width
                elide: Text.ElideRight
                text: root.call ? root.call.name : ""
                kind: "title"
                color: root.phone.trim
            }
            PxText {
                text: !root.call ? "" : PhoneLine.ringing ? (root.call.outgoing ? I18n.t("Вызов", "Calling") : I18n.t("Звонит", "Calling you")) + ".".repeat(1 + Math.floor(root.tick / 4) % 3) : root.clock(root.now - root.call.since)
                kind: "tiny"
                color: root.dimInk
            }
        }
    }

    // ---- what she says, what you can answer ----
    Column {
        visible: PhoneLine.talking
        anchors.top: head.bottom
        anchors.topMargin: root.k * 3
        width: parent.width
        spacing: root.k * 2
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            text: PhoneLine.line.slice(0, PhoneLine.typed)
            kind: "tiny"
            color: root.ink
        }
        Repeater {
            model: PhoneLine.speaking || !root.call ? [] : root.call.answers
            Rectangle {
                id: ans
                required property var modelData
                required property int index
                width: parent.width
                height: ansText.implicitHeight + root.k * 2
                color: ansMouse.containsMouse ? root.phone.trim : Qt.alpha(root.phone.trim, 0.15)
                PxText {
                    id: ansText
                    x: root.k
                    y: root.k
                    width: parent.width - root.k * 2
                    wrapMode: Text.Wrap
                    text: (ans.index + 1) + " " + ans.modelData.label
                    kind: "tiny"
                    color: ansMouse.containsMouse ? Theme.selectText : root.ink
                }
                MouseArea {
                    id: ansMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PhoneLine.choose(ans.index)
                }
            }
        }
    }
    // ringing: what the keys do
    PxText {
        visible: PhoneLine.ringing && !!root.call && !root.call.outgoing
        anchors.bottom: parent.bottom
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: I18n.t("Открой крышку или зелёная — ответить", "Open the lid or press green to answer")
        kind: "tiny"
        color: root.dimInk
    }
}
