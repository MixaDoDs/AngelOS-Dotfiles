import QtQuick

// Entries made from a model (a Repeater of rows): `delegate` is a Cat entry.
Item {
    id: root

    readonly property bool isCatRepeat: true
    property alias model: inst.model
    property alias delegate: inst.delegate
    property var entries: []
    visible: false
    Instantiator {
        id: inst
        onObjectAdded: (i, o) => {
            o.parent = root;
            const e = root.entries.slice();
            e.splice(i, 0, o);
            root.entries = e;
        }
        onObjectRemoved: (i, o) => root.entries = root.entries.filter(x => x !== o)
    }
}
