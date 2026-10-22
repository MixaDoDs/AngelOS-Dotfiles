import QtQuick

// A settings page's groups as cards in columns (Settings' angelOS look, PxPage): each group
// (PxGroup) goes into the shortest column, in order; anything else (a note, buttons, a part of
// a page put together from groups), a group marked `wide` and a group alone between those span
// the width and start below all of them. One column: a plain column.
Item {
    id: root

    property int columns: 1
    property real spacing: 0
    readonly property real columnWidth: columns > 1 ? (width - spacing * (columns - 1)) / columns : width
    property real laidHeight: 0
    implicitHeight: laidHeight
    // a resize (PxScroll.resizing): what lands wholly below the view (viewBottom, in this item)
    // keeps its width and is placed only; it is laid out to the new width once the resize ends.
    // Text wrapping again below the screen on every step is what a long page paid for
    property bool resizing: false
    property real viewBottom: Infinity
    onResizingChanged: if (!resizing)
        later()

    function isCard(c) {
        return c.advanced !== undefined && c.title !== undefined && c.wide !== true;
    }
    // the children's sizes and visibility move the others: watched once each
    property var watched: []
    function watch() {
        for (const c of children) {
            if (watched.indexOf(c) >= 0)
                continue;
            watched.push(c);
            c.heightChanged.connect(root.later);
            c.visibleChanged.connect(root.later);
        }
        watched = watched.filter(c => children.indexOf(c) >= 0);
    }
    // (a card's signal may come while the page is being torn down: nothing to lay out then.
    // A flag, not a look at root.layout: reading a function off a page being torn down is what
    // warned "QQmlVMEMetaObject: … invalid context" each time Settings closed)
    property bool gone: false
    Component.onDestruction: gone = true
    function later() {
        if (!gone)
            Qt.callLater(root.layout);
    }
    function layout() {
        const n = Math.max(1, columns);
        // what takes room: a Repeater, a part not loaded yet is nothing between two cards
        const shown = [];
        for (const c of children) {
            if (!c.visible)
                continue;
            if (!isCard(c)) {
                if (!resizing || c.y <= viewBottom || c.width <= 0)
                    c.width = width;
                if (c.height <= 0)
                    continue;
            }
            shown.push(c);
        }
        // a card alone between full-width things (or a page of one group) takes the width too
        const card = shown.map((c, i) => n > 1 && isCard(c));
        const alone = shown.map((c, i) => card[i] && !card[i - 1] && !card[i + 1]);
        let tops = [];
        for (let i = 0; i < n; i++)
            tops.push(0);
        let any = false;
        shown.forEach((c, i) => {
            if (card[i] && !alone[i]) {
                let k = 0;
                for (let j = 1; j < n; j++)
                    if (tops[j] < tops[k])
                        k = j;
                if (!resizing || tops[k] <= viewBottom || c.width <= 0)
                    c.width = columnWidth;
                c.x = k * (columnWidth + spacing);
                c.y = tops[k];
                tops[k] += c.height + spacing;
                any = true;
                return;
            }
            const top = Math.max.apply(null, tops);
            if (!resizing || top <= viewBottom || c.width <= 0)
                c.width = width;
            c.x = 0;
            c.y = top;
            for (let j = 0; j < n; j++)
                tops[j] = top + c.height + spacing;
            any = true;
        });
        laidHeight = any ? Math.max(0, Math.max.apply(null, tops) - spacing) : 0;
    }
    onChildrenChanged: {
        watch();
        later();
    }
    onWidthChanged: later()
    onColumnsChanged: later()
    onSpacingChanged: later()
    Component.onCompleted: {
        watch();
        layout();
    }
}
