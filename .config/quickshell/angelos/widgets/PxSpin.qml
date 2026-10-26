import QtQuick
import qs.config
import "A11y.js" as A11y

Row {
    id: root
    // inside the P5 settings window: its colours (Theme.tone)
    readonly property bool p5: settingsSkin === "p5"
    readonly property string settingsSkin: Theme.settingsSkinFor(root.parent)

    property real value: 0
    // the step just taken, shown until the owner's binding answers (as PxSlider): `value` is
    // never assigned — that cut the binding, and a value the owner clamped or didn't take
    // (the battery levels keep their order) stayed on screen as if it were saved
    property real _held: NaN
    readonly property real shown: isNaN(_held) ? value : _held
    onValueChanged: _held = NaN
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property int decimals: 0
    property string suffix: ""
    signal moved(real value)

    Accessible.role: Accessible.SpinBox
    Accessible.name: A11y.rowLabel(root)
    Accessible.description: shown.toFixed(decimals) + suffix
    Accessible.focusable: true
    Accessible.onIncreaseAction: set(shown + stepSize)
    Accessible.onDecreaseAction: set(shown - stepSize)

    spacing: Theme.u * 2

    function set(v) {
        v = Number(Math.max(from, Math.min(to, Math.round(v / stepSize) * stepSize)).toFixed(Math.max(decimals, 3)));
        _held = v;
        letGo.restart();
        moved(v);
    }

    PxButton {
        compact: true
        icon: "minus"
        Accessible.name: I18n.t("Меньше", "Less")
        onClicked: root.set(root.shown - root.stepSize)
    }
    PxBox {
        width: Theme.u * 34
        height: parent.children[0].height
        sunken: true
        color: Theme.toneOf(root.settingsSkin, "sunken")
        PxText {
            anchors.centerIn: parent
            text: root.shown.toFixed(root.decimals) + root.suffix
        }
        MouseArea {
            id: spinMouse
            anchors.fill: parent
            hoverEnabled: true
            // only once the pointer rests on it: scrolling the page past it doesn't turn it (#93)
            onWheel: w => {
                const n = spinWheel.steps(w);
                if (n !== 0)
                    root.set(root.shown + n * root.stepSize);
            }
            WheelGate {
                id: spinWheel
                hovered: spinMouse.containsMouse
            }
        }
    }
    PxButton {
        compact: true
        icon: "plus"
        Accessible.name: I18n.t("Больше", "More")
        onClicked: root.set(root.shown + root.stepSize)
    }
    Timer {
        id: letGo
        interval: 2000
        onTriggered: root._held = NaN
    }
}
