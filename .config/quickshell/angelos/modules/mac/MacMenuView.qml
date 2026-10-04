pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// One level of a Golden Gate menu: glass with rounded corners, 22 pt rows, the hovered or
// keyboard-selected row as an accent pill set in from the edges, a checkmark column on the
// leading side, the shortcut in grey on the trailing side, › for a submenu. Besides items
// (AppMenu.item) it draws what status menus need: "header" (a bold title), "switch" (a
// label with a switch, Wi-Fi), "slider" (sound, brightness), "note" (grey text).
Item {
    id: root

    property var items: []
    property int current: -1
    property real maxWidth: 520
    readonly property real minWidth: GoldenGate.px(180)
    signal activated(var item)
    signal hovered(int index, var item, real rowY)

    readonly property real pad: GoldenGate.menuPad
    readonly property real rowH: GoldenGate.menuRow
    readonly property real sepH: GoldenGate.px(11)
    readonly property real checkW: GoldenGate.px(18)
    implicitWidth: Math.min(maxWidth, Math.max(minWidth, col.widest + pad * 2))
    implicitHeight: col.implicitHeight + pad * 2

    function selectable(i) {
        const it = items[i];
        return !!it && (it.type === "item" || it.type === "submenu" || it.type === "switch") && it.enabled !== false;
    }
    function move(d) {
        if (!items.length)
            return;
        let i = current;
        for (let n = 0; n < items.length; n++) {
            i = (i + d + items.length) % items.length;
            if (i < 0)
                i = items.length - 1;
            if (selectable(i)) {
                current = i;
                return;
            }
        }
    }
    function rowY(i) {
        const r = rep.itemAt(i);
        return r ? r.y + pad : 0;
    }
    // type to jump: the next item starting with the letter
    function jump(ch) {
        const c = String(ch).toLowerCase();
        for (let n = 1; n <= items.length; n++) {
            const i = (current + n) % items.length;
            if (selectable(i) && String(items[i].label || "").toLowerCase().startsWith(c)) {
                current = i;
                return true;
            }
        }
        return false;
    }

    MacGlass {
        anchors.fill: parent
        radius: GoldenGate.menuRadius
    }

    Column {
        id: col
        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        property real widest: 0
        function measure() {
            let w = 0;
            for (let i = 0; i < rep.count; i++) {
                const r = rep.itemAt(i);
                if (r)
                    w = Math.max(w, r.want);
            }
            widest = w;
        }

        Repeater {
            id: rep
            model: root.items
            onItemAdded: Qt.callLater(col.measure)
            onItemRemoved: Qt.callLater(col.measure)

            Item {
                id: row
                required property var modelData
                required property int index
                readonly property string kind: modelData.type || "item"
                readonly property bool sel: root.current === index && root.selectable(index)
                readonly property bool on: modelData.enabled !== false
                readonly property color ink: sel ? GoldenGate.accentText : on ? GoldenGate.label : GoldenGate.tertiaryLabel
                readonly property string keysText: AppMenu.keyText(modelData.keys)
                readonly property real want: kind === "separator" ? 0 : kind === "slider" ? GoldenGate.px(240) : root.checkW + label.implicitWidth + (keysText ? GoldenGate.px(28) + keys.implicitWidth : 0) + (kind === "submenu" ? GoldenGate.px(26) : 0) + (kind === "switch" ? GoldenGate.px(44) : 0) + GoldenGate.px(14)
                onWantChanged: Qt.callLater(col.measure)
                width: col.width
                height: kind === "separator" ? root.sepH : kind === "slider" ? GoldenGate.px(30) : kind === "header" ? GoldenGate.px(26) : root.rowH

                Rectangle {
                    visible: row.kind === "separator"
                    anchors.verticalCenter: parent.verticalCenter
                    x: GoldenGate.px(9)
                    width: parent.width - GoldenGate.px(18)
                    height: 1
                    color: GoldenGate.separator
                }
                Rectangle {
                    anchors.fill: parent
                    radius: GoldenGate.px(6)
                    color: GoldenGate.accent
                    visible: row.sel
                }
                // ✓ for a checked item (macOS uses it for radio choices too)
                MacText {
                    visible: row.kind !== "separator" && row.kind !== "slider" && row.modelData.checked === true && row.modelData.toggle !== ""
                    x: GoldenGate.px(5)
                    width: root.checkW
                    height: parent.height
                    text: "✓"
                    color: row.ink
                    semibold: true
                }
                MacText {
                    id: label
                    visible: row.kind !== "separator" && row.kind !== "slider"
                    x: row.kind === "header" ? GoldenGate.px(9) : root.checkW + GoldenGate.px(5)
                    width: parent.width - x - (keys.visible ? keys.implicitWidth + GoldenGate.px(20) : 0) - (row.kind === "submenu" ? GoldenGate.px(22) : 0) - (row.kind === "switch" ? GoldenGate.px(44) : 0)
                    height: parent.height
                    text: row.modelData.label || ""
                    color: row.kind === "note" ? GoldenGate.secondaryLabel : row.ink
                    bold: row.kind === "header"
                }
                MacText {
                    id: keys
                    visible: row.kind === "item" && text !== ""
                    anchors.right: parent.right
                    anchors.rightMargin: GoldenGate.px(9)
                    height: parent.height
                    text: row.keysText
                    color: row.sel ? GoldenGate.accentText : GoldenGate.secondaryLabel
                    font.letterSpacing: GoldenGate.px(0.5)
                }
                MacIcon {
                    visible: row.kind === "submenu"
                    anchors.right: parent.right
                    anchors.rightMargin: GoldenGate.px(6)
                    anchors.verticalCenter: parent.verticalCenter
                    name: "chevron-right"
                    size: GoldenGate.px(13)
                    stroke: 2.2
                    color: row.ink
                }
                // a switch (Wi-Fi, Bluetooth): the accent when on
                Rectangle {
                    visible: row.kind === "switch"
                    anchors.right: parent.right
                    anchors.rightMargin: GoldenGate.px(8)
                    anchors.verticalCenter: parent.verticalCenter
                    width: GoldenGate.px(32)
                    height: GoldenGate.px(18)
                    radius: height / 2
                    color: row.modelData.checked ? GoldenGate.accent : GoldenGate.controlBg
                    Rectangle {
                        width: parent.height - GoldenGate.px(4)
                        height: width
                        radius: width / 2
                        y: GoldenGate.px(2)
                        x: row.modelData.checked ? parent.width - width - GoldenGate.px(2) : GoldenGate.px(2)
                        color: "#ffffff"
                        Behavior on x {
                            NumberAnimation {
                                duration: Motion.ms(150)
                            }
                        }
                    }
                }
                // a slider (sound, brightness): a thick capsule track, the fill in white over grey
                Item {
                    id: slider
                    visible: row.kind === "slider"
                    anchors.fill: parent
                    anchors.leftMargin: GoldenGate.px(9)
                    anchors.rightMargin: GoldenGate.px(9)
                    readonly property real value: Math.max(0, Math.min(1, row.modelData.value || 0))
                    MacIcon {
                        id: sliderIcon
                        anchors.verticalCenter: parent.verticalCenter
                        name: row.modelData.icon || "volume-2"
                        size: GoldenGate.px(15)
                        color: GoldenGate.secondaryLabel
                    }
                    Rectangle {
                        id: track
                        anchors.left: sliderIcon.right
                        anchors.leftMargin: GoldenGate.px(8)
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: GoldenGate.px(20)
                        radius: height / 2
                        color: GoldenGate.controlBg
                        Rectangle {
                            width: Math.max(parent.height, parent.width * slider.value)
                            height: parent.height
                            radius: height / 2
                            color: GoldenGate.dark ? "#f2f2f2" : "#ffffff"
                            border.width: 1
                            border.color: GoldenGate.separator
                        }
                        MouseArea {
                            anchors.fill: parent
                            function set(mx) {
                                if (row.modelData.set)
                                    row.modelData.set(Math.max(0, Math.min(1, mx / width)));
                            }
                            onPressed: m => set(m.x)
                            onPositionChanged: m => {
                                if (pressed)
                                    set(m.x);
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    visible: row.kind !== "slider"
                    enabled: row.kind !== "separator" && row.kind !== "header" && row.kind !== "note"
                    hoverEnabled: true
                    onEntered: {
                        root.current = row.index;
                        root.hovered(row.index, row.modelData, row.y + root.pad);
                    }
                    onClicked: {
                        if (!row.on)
                            return;
                        if (row.kind === "submenu")
                            root.hovered(row.index, row.modelData, row.y + root.pad);
                        else
                            root.activated(row.modelData);
                    }
                }
            }
        }
    }
}
