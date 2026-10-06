pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.widgets

// The NGO lock's password field: every character drops in as a pixel heart that lands
// with a bounce and a flash, a light runs along the field, fast typing builds a combo;
// Backspace breaks the last heart, a wrong password knocks them all down, checking makes
// them wave. A long password never runs out of the field: past what fits the hearts turn
// small, past that they huddle closer and closer. The text itself is never drawn.
Item {
    id: root
    objectName: "heartPassword"

    property alias text: input.text
    property bool busy: false
    property bool reactions: true
    property string placeholder: ""
    // the heaven lock: gold and sky-blue stars in a white field with a blue rim (`dark`:
    // a night-blue field)
    property bool heaven: false
    property bool dark: false
    readonly property color ink1: heaven ? "#e8b84a" : Theme.accent
    readonly property color ink2: heaven ? (dark ? "#9cc6ff" : "#6aa6e8") : Theme.accent2
    readonly property color line: heaven ? (dark ? "#c9d6ff" : "#4a6aa8") : Theme.accent
    // the room the glyphs have; big ones while they fit, then small ones, then closer
    readonly property real room: Math.max(Theme.u * 20, width - Theme.u * 16)
    readonly property bool small: count * Theme.u * 11 > room
    readonly property int glyphW: Theme.u * (small ? (heaven ? 7 : 5) : 9)
    readonly property real step: small ? Math.min(Theme.u * 6 + (heaven ? Theme.u * 2 : 0), room / Math.max(1, count)) : Theme.u * 11
    readonly property int count: input.text.length
    readonly property bool focused: input.activeFocus
    readonly property real caretX: hearts.x + hearts.width + Theme.u * 2
    // the tests check that a long password still fits
    readonly property bool fits: caretX <= width - Theme.u * 2

    signal accepted
    // a key while the unlock plays: hurry it along
    signal hurried
    signal typed(int length, bool added)
    // a heart broke at (x, y) in this item: the screen drops its pieces
    signal broke(real x, real y)

    implicitWidth: Theme.u * 140
    implicitHeight: Theme.u * 18

    function focusField() {
        input.forceActiveFocus();
    }
    function clear() {
        last = 0;
        combo = 0;
        model.clear();
        input.text = "";
    }
    // a wrong password: the hearts break and fall, one after another
    function fail() {
        falling = true;
        fallDone.restart();
    }
    // the right one: the hearts jump and go up, the light runs twice
    function win() {
        winning = true;
        sweep.restart();
    }

    property bool falling: false
    property bool winning: false
    property int last: 0
    property int serial: 0
    property int combo: 0
    property real lastKey: 0
    property int wave: 0

    Timer {
        id: fallDone
        interval: Motion.ms(650)
        onTriggered: {
            root.falling = false;
            root.clear();
        }
    }

    ListModel {
        id: model
    }

    HeavenPlate {
        anchors.fill: parent
        visible: root.heaven
        shadow: false
        corner: 2
        fill: root.dark ? "#121735" : "#ffffff"
        hi: root.dark ? "#2a3366" : "#ffffff"
        rim: root.falling ? "#e86a7a" : flash.running || root.winning ? "#e8b84a" : root.dark ? "#4a5a9a" : "#a9cdf2"
        edge: root.dark ? "#0a0d22" : "#4a6aa8"
    }
    PxBox {
        id: frame
        anchors.fill: parent
        opacity: root.heaven ? 0 : 1
        color: Theme.sunken
        edgeColor: root.falling ? Theme.danger : flash.running || root.winning ? Theme.accent : root.focused ? Theme.mix(Theme.edge, Theme.accent, 0.45) : Theme.edge
    }
    // a light runs along the field on every key
    Item {
        anchors.fill: parent
        anchors.margins: Theme.u * 2
        clip: true
        Rectangle {
            id: shine
            width: Theme.u * 6
            height: parent.height
            x: -width
            color: root.heaven ? Qt.alpha("#ffe9a8", 0.6) : Qt.alpha("#ffffff", 0.35)
            visible: sweep.running
        }
    }
    NumberAnimation {
        id: sweep
        target: shine
        property: "x"
        from: -shine.width
        to: root.width
        duration: Motion.ms(root.winning ? 260 : 200)
        loops: root.winning ? 2 : 1
    }
    Timer {
        id: flash
        interval: 90
    }

    Row {
        id: hearts
        x: Theme.u * 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.floor(root.step - root.glyphW)
        Repeater {
            model: model
            Item {
                id: slot
                required property int index
                required property int sid
                width: root.glyphW
                height: Theme.u * (root.small ? (root.heaven ? 7 : 5) : root.heaven ? 9 : 8)
                // the hearts shrink together when they stop fitting
                Connections {
                    target: root
                    function onSmallChanged() {
                        shrink.restart();
                    }
                }
                NumberAnimation {
                    id: shrink
                    target: slot
                    property: "pop"
                    from: 1.4
                    to: 1
                    duration: Motion.ms(160)
                    easing.type: Easing.OutBack
                }
                property real dy: 0
                property real pop: 1
                property bool fresh: true
                property real fall: 0
                PxIcon {
                    id: icon
                    name: root.heaven ? (root.small ? "sparkle" : "sparkleStar") : root.small ? "heartSmall" : root.falling ? "heartBroken" : "heart"
                    pixel: Theme.u
                    ink: root.heaven ? root.line : (Theme.dark ? Theme.text : Theme.edge)
                    fill: slot.fresh ? (root.heaven ? "#fff6c8" : "#ffffff") : root.falling ? (root.heaven ? "#9aa3b8" : Theme.danger) : slot.sid % 3 === 2 ? root.ink2 : root.ink1
                    y: slot.dy + slot.fall * Theme.u * 26 + (root.busy ? Math.round(Math.sin((root.wave + slot.index) * 0.9) * Theme.u * 1.5) : 0) - (root.winning ? Theme.u * 2 * ((slot.index + root.wave) % 2) : 0)
                    rotation: slot.fall * (slot.index % 2 ? 40 : -40)
                    opacity: 1 - slot.fall
                    scale: slot.pop
                    transformOrigin: Item.Bottom
                }
                SequentialAnimation {
                    running: true
                    PropertyAction {
                        target: slot
                        property: "dy"
                        value: Motion.still || !root.reactions ? 0 : -Theme.u * 10
                    }
                    PropertyAction {
                        target: slot
                        property: "pop"
                        value: Motion.still || !root.reactions ? 1 : 1.7
                    }
                    NumberAnimation {
                        target: slot
                        property: "dy"
                        to: 0
                        duration: Motion.ms(110)
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        target: slot
                        property: "pop"
                        to: 0.8
                        duration: Motion.ms(50)
                    }
                    NumberAnimation {
                        target: slot
                        property: "pop"
                        to: 1.15
                        duration: Motion.ms(60)
                    }
                    NumberAnimation {
                        target: slot
                        property: "pop"
                        to: 1
                        duration: Motion.ms(60)
                    }
                    PropertyAction {
                        target: slot
                        property: "fresh"
                        value: false
                    }
                }
                NumberAnimation on fall {
                    running: root.falling
                    from: 0
                    to: 1
                    duration: Motion.ms(520)
                    easing.type: Easing.InQuad
                }
            }
        }
    }
    // the caret: a blinking pixel block after the last heart
    Rectangle {
        x: root.count === 0 ? Theme.u * 6 : root.caretX
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.u * 2
        height: Theme.u * 9
        color: root.line
        visible: root.focused && !root.busy && !root.falling
        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: root.focused && !Motion.still
            PropertyAction {
                value: 1
            }
            PauseAnimation {
                duration: Motion.ms(480)
            }
            PropertyAction {
                value: 0
            }
            PauseAnimation {
                duration: Motion.ms(480)
            }
        }
    }
    PxText {
        visible: root.count === 0 && !root.falling
        x: Theme.u * 11
        anchors.verticalCenter: parent.verticalCenter
        text: root.placeholder
        dim: !root.heaven
        color: root.heaven ? (root.dark ? "#7f8bc0" : "#8a9ac0") : Theme.textDim
    }
    // checking: the hearts wave
    Timer {
        interval: 70
        repeat: true
        running: (root.busy || root.winning) && !Motion.still
        onTriggered: root.wave++
    }

    // a combo of fast keys
    // a sticker over the field's corner: the hearts underneath stay whole
    Rectangle {
        id: comboText
        anchors.right: parent.right
        anchors.rightMargin: -Theme.u * 4
        anchors.bottom: parent.top
        anchors.bottomMargin: -Theme.u * 4
        width: comboLabel.implicitWidth + Theme.u * 8
        height: comboLabel.implicitHeight + Theme.u * 3
        color: root.ink1
        border.width: Theme.u
        border.color: root.heaven ? (root.dark ? "#0a0d22" : "#3a4a78") : Theme.edge
        rotation: 4
        visible: root.reactions && root.combo >= 5 && comboHide.running
        transformOrigin: Item.Right
        property real pop: 1
        scale: pop
        PxText {
            id: comboLabel
            anchors.centerIn: parent
            text: "COMBO ×" + root.combo + (root.heaven ? " ✦" : " ♡")
            color: "#ffffff"
            font.bold: true
        }
        NumberAnimation on pop {
            id: comboPop
            from: 1.5
            to: 1
            duration: Motion.ms(140)
        }
    }
    Timer {
        id: comboHide
        interval: 900
        onTriggered: root.combo = 0
    }

    TextInput {
        id: input
        anchors.fill: parent
        // the text is never drawn: the hearts stand for it
        color: "transparent"
        selectionColor: "transparent"
        selectedTextColor: "transparent"
        echoMode: TextInput.Password
        cursorDelegate: Item {}
        readOnly: root.busy || root.falling
        focus: true
        Keys.onPressed: e => {
            if (root.busy)
                root.hurried();
        }
        onAccepted: root.accepted()
        onTextChanged: {
            const n = text.length;
            if (n === root.last)
                return;
            const added = n > root.last;
            if (added) {
                for (let i = root.last; i < n; i++)
                    model.append({
                        "sid": root.serial++
                    });
                const now = Date.now();
                root.combo = now - root.lastKey < 380 ? root.combo + 1 : 1;
                root.lastKey = now;
                if (root.combo >= 5) {
                    comboPop.restart();
                    comboHide.restart();
                }
                if (root.reactions) {
                    sweep.restart();
                    flash.restart();
                }
            } else {
                for (let i = n; i < root.last && model.count > 0; i++) {
                    if (root.reactions)
                        root.broke(root.caretX - Theme.u * 6, height / 2);
                    model.remove(model.count - 1);
                }
                root.combo = 0;
            }
            if (n === 0)
                model.clear();
            root.last = n;
            root.typed(n, added);
        }
    }
}
