import QtQuick

// An action (PxButton): a row of its own, or one of a row's extra buttons.
CatEntry {
    kind: "button"
    property string text: ""
    property string icon: ""
    property bool accent: false
    property bool danger: false
    property bool compact: false
    property bool checkable: false
    property bool checked: false
    // one of a row's extra buttons that stands before its control
    property bool lead: false
    signal clicked
}
