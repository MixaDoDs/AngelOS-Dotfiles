import QtQuick

// On/off (PxToggle): `checked` is the owner's binding, never assigned; toggled(next) asks for it.
CatEntry {
    kind: "toggle"
    property bool checked: false
    property string text: ""
    signal toggled(bool checked)
}
