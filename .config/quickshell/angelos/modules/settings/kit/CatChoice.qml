import QtQuick

// One of a few (PxSegmented) or of a list (PxCombo: `combo`); model: [{label, value, icon}]
// or plain values.
CatEntry {
    kind: "choice"
    property bool combo: false
    property var model: []
    property var currentValue
    property string placeholder: "—"
    readonly property var items: (model || []).map(m => typeof m === "object" && m !== null ? m : {
            "label": String(m),
            "value": m
        })
    readonly property int currentIndex: items.findIndex(i => i.value === currentValue)
    signal activated(var value)
}
