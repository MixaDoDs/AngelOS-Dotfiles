import QtQuick
import qs.config
import "A11y.js" as A11y

Row {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property int decimals: 0
    property string suffix: ""
    signal moved(real value)

    Accessible.role: Accessible.SpinBox
    Accessible.name: A11y.rowLabel(root)
    Accessible.description: value.toFixed(decimals) + suffix
    Accessible.focusable: true
    Accessible.onIncreaseAction: set(value + stepSize)
    Accessible.onDecreaseAction: set(value - stepSize)

    spacing: Theme.u * 2

    function set(v) {
        v = Number(Math.max(from, Math.min(to, Math.round(v / stepSize) * stepSize)).toFixed(Math.max(decimals, 3)));
        moved(v);
        if (value !== v)
            value = v;
    }

    PxButton {
        compact: true
        icon: "minus"
        Accessible.name: I18n.t("Меньше", "Less")
        onClicked: root.set(root.value - root.stepSize)
    }
    PxBox {
        width: Theme.u * 34
        height: parent.children[0].height
        sunken: true
        color: Theme.sunken
        PxText {
            anchors.centerIn: parent
            text: root.value.toFixed(root.decimals) + root.suffix
        }
        MouseArea {
            anchors.fill: parent
            onWheel: w => root.set(root.value + (w.angleDelta.y > 0 ? root.stepSize : -root.stepSize))
        }
    }
    PxButton {
        compact: true
        icon: "plus"
        Accessible.name: I18n.t("Больше", "More")
        onClicked: root.set(root.value + root.stepSize)
    }
}
