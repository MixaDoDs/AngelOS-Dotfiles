import QtQuick

// One setting (a row): what every kind shares. `present` is the row's visibility (an Item's own
// `visible` reads false here: the page is never shown itself). Entries inside it are its
// extra buttons (CatButton); anything else inside is drawn in place of a control (CatCustom).
Item {
    id: root

    property string kind: ""
    property string label: ""
    property string hint: ""
    property bool present: true
    property real fade: 1
    // a looping preview under the row (widgets/previews/<scene>.qml), played by show()
    property string preview: ""
    signal showPreview(var value, string caption)
    function show(value, caption) {
        showPreview(value, caption || "");
    }
    readonly property var actions: Array.prototype.filter.call(children, c => c.kind === "button")
    // the items it shows as they are (CatCustom), taken once: they move into a look's row while
    // shown, and the list must not lose them then
    property var content: []
    Component.onCompleted: content = Array.prototype.filter.call(children, c => c.kind === undefined)
    visible: false
}
