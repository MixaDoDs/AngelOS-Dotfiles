import QtQuick

// Entries made from a model (a Repeater of rows): `delegate` is a Cat entry.
Item {
    id: root

    readonly property bool isCatRepeat: true
    property alias model: inst.model
    property alias delegate: inst.delegate
    property var entries: []
    visible: false
    // The page makes a row for every entry, all of them again for a new list: one list per object
    // made every row once per row, and a long list held the shell for seconds (#128). One per change
    property var made: []
    function publish() {
        entries = made.slice();
    }
    Component.onCompleted: publish()
    Instantiator {
        id: inst
        onObjectAdded: (i, o) => {
            o.parent = root;
            root.made.splice(i, 0, o);
            Qt.callLater(root.publish);
        }
        onObjectRemoved: (i, o) => {
            // now, not later: this object is about to go, and a row still on it would read null
            if (root.entries.length)
                root.entries = [];
            root.made = root.made.filter(x => x !== o);
            Qt.callLater(root.publish);
        }
    }
}
