import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// Sidebar block: state and plan limits at a glance.
Column {
    id: root

    property var plugin
    spacing: Skin.px(4)

    Row {
        spacing: Skin.px(6)
        Breath {
            plugin: root.plugin
            anchors.verticalCenter: parent.verticalCenter
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Claude · " + Pulse.word
            color: Pulse.colorFor(Pulse.state, Theme)
        }
    }
    Limits {
        width: root.width
        compact: true
    }
}
