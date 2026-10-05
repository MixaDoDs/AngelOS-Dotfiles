pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// ⌘Tab of the Golden Gate skin's Mac keys (services/AltTab in mode "apps"): macOS's app switcher —
// a glass slab in the middle of the screen with the apps in a row (in the order they were used),
// the picked one on a lighter square with its name under it. MacTahoe's icons (DockIcons) when they
// are there, the theme's otherwise. The pointer picks too.
Item {
    id: root

    required property var host
    readonly property real icon: GoldenGate.px(88)
    readonly property real cell: icon + GoldenGate.px(20)
    readonly property real pad: GoldenGate.px(14)
    readonly property real label: GoldenGate.px(26)
    readonly property real maxW: (host.screen ? host.screen.width : 1920) * 0.9
    readonly property int perRow: Math.max(1, Math.min(AltTab.items.length, Math.floor((maxW - pad * 2) / cell)))
    readonly property int rows: Math.ceil(AltTab.items.length / perRow)
    implicitWidth: perRow * cell + pad * 2
    implicitHeight: rows * cell + pad * 2 + label

    MacGlass {
        anchors.fill: parent
        radius: GoldenGate.px(26)
        shadowSize: GoldenGate.px(30)
        shadowY: GoldenGate.px(6)
    }

    Grid {
        id: grid
        x: root.pad
        y: root.pad
        columns: root.perRow
        Repeater {
            model: AltTab.items
            Item {
                id: slot
                required property var modelData
                required property int index
                readonly property bool picked: index === AltTab.index
                readonly property string mac: DockIcons.forItem(modelData)
                width: root.cell
                height: root.cell
                Rectangle {
                    visible: slot.picked
                    anchors.fill: parent
                    anchors.margins: GoldenGate.px(2)
                    radius: GoldenGate.px(18)
                    color: GoldenGate.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)
                    border.width: 1
                    border.color: GoldenGate.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)
                }
                Image {
                    id: img
                    anchors.centerIn: parent
                    width: root.icon
                    height: root.icon
                    sourceSize: Qt.size(Math.ceil(root.icon) * 2, Math.ceil(root.icon) * 2)
                    smooth: true
                    mipmap: true
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    source: {
                        if (slot.mac)
                            return slot.mac;
                        const n = String(slot.modelData.icon || "");
                        if (!n)
                            return "";
                        if (n.startsWith("/"))
                            return "file://" + n;
                        return Quickshell.iconPath(n, true) || Quickshell.iconPath(n.toLowerCase(), true) || "";
                    }
                }
                // no icon: its initial in a squircle, as the Dock draws it
                Rectangle {
                    visible: img.status !== Image.Ready
                    anchors.centerIn: parent
                    width: root.icon * 0.88
                    height: width
                    radius: width * 0.225
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#8e9bb0"
                        }
                        GradientStop {
                            position: 1
                            color: "#5a667a"
                        }
                    }
                    MacText {
                        anchors.centerIn: parent
                        text: String(slot.modelData.name || "?").charAt(0).toUpperCase()
                        size: parent.width * 0.5
                        bold: true
                        color: "#ffffff"
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: AltTab.select(slot.index)
                    onClicked: {
                        AltTab.select(slot.index);
                        AltTab.commit();
                    }
                }
            }
        }
    }
    // the picked app's name, under the rows, below its icon
    MacText {
        readonly property int col: AltTab.index % root.perRow
        text: AltTab.current ? AltTab.current.name || "" : ""
        y: root.pad + root.rows * root.cell + GoldenGate.px(3)
        x: Math.max(root.pad / 2, Math.min(root.width - width - root.pad / 2, root.pad + col * root.cell + root.cell / 2 - width / 2))
        semibold: true
    }
}
