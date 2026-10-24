import QtQuick

// A line of text between the settings (an explanation, a status).
CatEntry {
    kind: "note"
    property string text: ""
    property bool dim: false
    property string textKind: "body"
}
