import QtQuick

// Anything that is not one of the kinds: its items (`content`) are drawn as they are — beside
// the label in a row, or across the group without one (`wide`). The items live here and move
// into the look's row while it is shown.
CatEntry {
    kind: "custom"
    property bool wide: false
}
