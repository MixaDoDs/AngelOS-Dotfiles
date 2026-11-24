import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// Try her moods by hand.
Column {
    id: root
    property var plugin
    width: parent ? parent.width : Skin.px(360)
    spacing: Skin.spacing

    PxText {
        width: parent.width
        wrapMode: Text.Wrap
        text: I18n.t("Проверить настроения. Из терминала: qs -c angelos ipc call celestia mood НАСТРОЕНИЕ [сила] [\"реплика\"] [секунды]", "Try her moods. From a terminal: qs -c angelos ipc call celestia mood MOOD [strength] [\"line\"] [seconds]")
        dim: true
    }
    ClaudeSettings {
        plugin: root.plugin
        width: parent.width
    }
    Flow {
        width: parent.width
        spacing: Skin.spacing
        Repeater {
            model: Object.keys(Brain.moods)
            PxButton {
                required property string modelData
                compact: true
                text: Brain.words[modelData] || modelData
                onClicked: Brain.setMood(modelData, 1, "", 6)
            }
        }
    }
}
