pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// One of Start's buttons (services/StartItems.buttons): a PxButton face of a fixed size, the
// icon centred in the same 12×11 box as a menu row's (PxMenuItem), the label under it when
// `labelled`, else in a tooltip on hover. Sizes are set by the row (StartButtonRow) so every
// button is the same; the editor (modules/settings/StartButtonsEditor) draws its cells with it.
// `unit`/`iu`: the look's units (StartButtonRow passes them on), the plain art pixel by default.
PxButton {
    id: root

    property var button: ({})               // {id, icon, label, accent, run}
    property bool labelled: false
    property bool tip: !labelled            // the label on hover
    property real unit: Theme.u
    property int iu: Theme.u
    function px(n) {
        return Math.round(unit * n);
    }
    // the face's ink, as PxButton picks it for its own icon
    readonly property color ink: mac ? GoldenGate.label : settingsSkin !== "classic" ? (accent || checked ? Theme.selectText : Theme.text) : accent ? Theme.selectText : (Theme.dark ? Theme.text : Theme.edge)
    readonly property color textInk: mac ? GoldenGate.label : accent || (checked && settingsSkin !== "classic") ? Theme.selectText : Theme.text

    width: px(15)
    height: px(15)
    accent: !!button.accent
    Accessible.name: button.label || ""

    Column {
        x: Math.floor((root.width - width) / 2) + (root.down && !root.mac ? root.iu : 0)
        y: Math.floor((root.height - height) / 2) + (root.down && !root.mac ? root.iu : 0)
        spacing: root.px(2)
        Item {
            x: Math.floor((parent.width - width) / 2)
            width: root.iu * 12
            height: root.iu * 11
            PxIcon {
                x: Math.floor((parent.width - width) / 2)
                y: Math.floor((parent.height - height) / 2)
                name: root.button.icon || "heart"
                pixel: root.iu
                ink: root.ink
            }
        }
        PxText {
            visible: root.labelled
            anchors.horizontalCenter: parent.horizontalCenter
            kind: "tiny"
            text: root.button.label || ""
            color: root.textInk
        }
    }

    // the tooltip: above the button, below it near the top of the screen
    PxBox {
        id: tipBox
        property bool below: false
        visible: root.tip && root.hovered && tipDelay.done && (root.button.label || "") !== ""
        z: 10
        x: Math.round((root.width - width) / 2)
        y: below ? root.height + root.px(2) : -height - root.px(2)
        width: Math.ceil(tipText.implicitWidth) + root.px(6)
        height: Math.ceil(tipText.implicitHeight) + root.px(3)
        color: Theme.menuSurface
        edgeColor: Theme.menuBorder
        flat: true
        PxText {
            id: tipText
            anchors.centerIn: parent
            kind: "tiny"
            text: root.button.label || ""
        }
    }
    Timer {
        id: tipDelay
        property bool done: false
        interval: 450
        onTriggered: done = true
    }
    onHoveredChanged: {
        tipDelay.done = false;
        if (hovered) {
            tipBox.below = root.mapToItem(null, 0, 0).y < tipBox.height + root.px(4);
            tipDelay.restart();
        } else
            tipDelay.stop();
    }
}
