pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// Spelling under a text field (services/Spell): a pixel zigzag under each misspelt word.
// A child of the TextEdit / TextInput it watches:
//     TextEdit { id: editor; PxSpell { target: editor } }
// (PxTextArea and PxField make it only when the field is first entered: a page of fields nobody
// types in costs nothing.) It asks only once the field has had the caret, a moment after the typing stops, and leaves
// the word still being typed alone. `current` is the misspelt word the caret stands in, with
// `suggestions` for it; replace() and learn() act on it (PxTextArea shows them as a strip).
Item {
    id: root

    property Item target: parent
    property bool enabled: true
    readonly property bool single: !!target && target.echoMode !== undefined       // a TextInput: it scrolls sideways
    readonly property bool live: enabled && Spell.on && !!target && target.readOnly !== true && (!single || target.echoMode === TextInput.Normal)
    property bool touched: false
    property var errors: []            // [{s, l, w}] in the text as it is now
    property var marks: []             // [{x, y, w}] where to draw
    property var current: null         // the error under the caret
    property var suggestions: []
    property int _len: 0
    property int _asked: 0

    anchors.fill: parent
    visible: live

    function recheck() {
        if (!live || !touched || !Spell.ready) {
            if (errors.length)
                errors = [];
            return;
        }
        const text = target.text;
        if (text.trim() === "") {
            errors = [];
            return;
        }
        const mine = ++_asked;
        Spell.check(text, list => {
            // typed on meanwhile: the next answer is the one that fits
            if (mine === root._asked && root.target && root.target.text === text)
                root.errors = list;
        });
    }
    // the text moved under the old answer: shift what stands after the edit, drop what it touched
    function shift() {
        const len = target.length, d = len - _len, at = target.cursorPosition;
        _len = len;
        if (!errors.length || d === 0)
            return;
        const from = d > 0 ? at - d : at, upto = d > 0 ? at - d : at - d;
        errors = errors.filter(e => e.s + e.l < from || e.s >= upto).map(e => e.s >= upto ? {
                "s": e.s + d,
                "l": e.l,
                "w": e.w
            } : e);
    }
    function layout() {
        if (!live || !errors.length) {
            marks = [];
            current = null;
            return;
        }
        const list = [], at = target.cursorPosition;
        let cur = null;
        for (const e of errors.slice(0, 80)) {
            if (e.s + e.l > target.length)
                continue;
            const inWord = target.activeFocus && at >= e.s && at <= e.s + e.l;
            // the word the caret has just written: not yet
            if (inWord && at === e.s + e.l && typing.running)
                continue;
            if (inWord)
                cur = e;
            const a = target.positionToRectangle(e.s), b = target.positionToRectangle(e.s + e.l);
            const w = (b.y === a.y ? b.x : target.width) - a.x;
            if (w > 0)
                list.push({
                    "x": Math.round(a.x),
                    "y": Math.round(a.y + a.height),
                    "w": Math.round(w)
                });
        }
        marks = list;
        if ((cur ? cur.s + ":" + cur.w : "") !== (current ? current.s + ":" + current.w : "")) {
            current = cur;
            suggestions = [];
            if (cur && Config.spell.suggest !== false)
                Spell.suggest(cur.w, list => {
                    if (root.current && root.current.w === cur.w)
                        root.suggestions = list;
                });
        } else {
            current = cur;
        }
    }
    function replace(word) {
        const e = current;
        if (!e || !target)
            return;
        target.remove(e.s, e.s + e.l);
        target.insert(e.s, word);
        target.cursorPosition = e.s + word.length;
    }
    function learn() {
        if (current)
            Spell.learn(current.w);
    }

    function enter() {
        if (touched || !live)
            return;
        touched = true;
        _len = target.length;
        Spell.want();
        wait.restart();
    }
    // made when the field is entered (PxTextArea, PxField): the caret is in it already
    Component.onCompleted: if (target && target.activeFocus)
        enter()
    onErrorsChanged: layout()
    onLiveChanged: wait.restart()
    Connections {
        target: root.target
        function onTextChanged() {
            root.shift();
            typing.restart();
            wait.restart();
        }
        function onActiveFocusChanged() {
            if (root.target.activeFocus)
                root.enter();
            root.layout();
        }
        function onCursorPositionChanged() {
            lay.restart();
        }
        function onWidthChanged() {
            lay.restart();
        }
        function onContentHeightChanged() {
            lay.restart();
        }
        function onCursorRectangleChanged() {
            // a single line scrolls under the marks
            if (root.single)
                lay.restart();
        }
    }
    Connections {
        target: Spell
        function onEpochChanged() {
            if (root.touched)
                wait.restart();
        }
        function onReadyChanged() {
            if (root.touched)
                wait.restart();
        }
    }
    Timer {
        id: wait
        interval: 350
        onTriggered: root.recheck()
    }
    // the caret's own word shows its mark when the typing pauses
    Timer {
        id: typing
        interval: 1200
        onTriggered: root.layout()
    }
    Timer {
        id: lay
        interval: 0
        onTriggered: root.layout()
    }

    Canvas {
        id: ink
        anchors.fill: parent
        // one art pixel, in whole screen pixels
        readonly property int p: Math.max(1, Theme.u)
        readonly property color color: Theme.danger
        visible: root.marks.length > 0
        onColorChanged: requestPaint()
        onVisibleChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = color;
            // a zigzag of squares, two rows: ▀▄▀▄
            for (const m of root.marks) {
                const y = Math.min(m.y - p, height - p * 2);
                for (let i = 0; i * p < m.w; i++)
                    ctx.fillRect(m.x + i * p, y + (i % 2) * p, p, p);
            }
        }
        Connections {
            target: root
            function onMarksChanged() {
                ink.requestPaint();
            }
        }
    }
}
