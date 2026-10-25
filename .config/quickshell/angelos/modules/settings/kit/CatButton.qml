import QtQuick

// An action (PxButton): a row of its own, or one of a row's extra buttons.
CatEntry {
    id: button
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
    // an action that can't be taken back: the first click asks (`confirming`, for the text to
    // say «Точно?»), a second within 4 s does it — `confirmed`, not `clicked`, is the action
    property bool confirm: false
    property bool confirming: false
    signal clicked
    signal confirmed
    onClicked: {
        if (!confirm)
            return;
        if (confirming) {
            confirming = false;
            confirmed();
        } else {
            confirming = true;
            unconfirm.restart();
        }
    }
    Timer {
        id: unconfirm
        interval: 4000
        onTriggered: button.confirming = false
    }
}
