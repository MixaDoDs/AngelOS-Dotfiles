import QtQuick
import qs.config
import qs.services
import "."

// The companion's panels asked for its mascot; here it is her face. Same properties.
Item {
    id: root
    property var plugin
    property real pixel: Theme.u
    property bool mono: false
    property color monoColor: Skin.text
    property bool barLook: false
    readonly property real glow: Brain.beat
    implicitWidth: pixel * 14
    implicitHeight: pixel * 14
    Face {
        anchors.fill: parent
        plugin: root.plugin
        look: "bar"
        mono: root.mono
        monoColor: root.monoColor
    }
}
