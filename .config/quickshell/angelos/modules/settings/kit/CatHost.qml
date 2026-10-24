import QtQuick

// Shows a CatCustom's items where it stands (a row's control slot, a group's column): they
// move in while it is here and go back to their entry when it goes.
Item {
    id: root

    property var entry: null
    readonly property Item box: entry && entry.content.length ? entry.content[0] : null
    property Item _held: null
    width: parent ? parent.width : 0
    implicitHeight: box ? box.height : 0
    height: implicitHeight
    function take() {
        if (_held && _held !== box && _held.parent === root)
            _held.parent = entry;
        _held = box;
        if (box)
            box.parent = root;
    }
    onBoxChanged: take()
    Component.onCompleted: take()
    Component.onDestruction: {
        if (_held && _held.parent === root && entry)
            _held.parent = entry;
    }
}
