import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// Sidebar block: Codex state and limits at a glance.
Column {
    id: root

    property var plugin
    spacing: Skin.px(4)

    Row {
        spacing: Skin.px(6)
        Mascot {
            anchors.verticalCenter: parent.verticalCenter
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Codex · " + (CodexState.words[CodexState.state] || "")
            color: CodexState.stateColor(CodexState.state, Theme)
        }
    }
    Limits {
        width: root.width
        compact: true
    }
}
