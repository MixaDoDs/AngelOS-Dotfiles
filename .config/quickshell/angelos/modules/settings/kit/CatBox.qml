import QtQuick

// What a CatCustom shows, as the page had it: as wide as the place it is moved into (a row's
// control slot, a group's column), the items one under another.
Column {
    readonly property bool fixedWidth: true // PxToggle wraps its label to fit
    width: parent ? parent.width : 0
}
