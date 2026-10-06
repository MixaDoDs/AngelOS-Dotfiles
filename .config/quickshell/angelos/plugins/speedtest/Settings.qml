import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

Column {
    id: root
    property var plugin
    width: parent ? parent.width : 400
    spacing: Skin.px(10)

    PxGroup {
        title: I18n.t("Спидтест", "Speedtest")
        icon: "gauge"
        width: parent.width
        Panel {
            width: parent.width
            plugin: root.plugin
        }
        PxButton {
            text: I18n.t("Очистить историю", "Clear history")
            icon: "trash"
            onClicked: root.plugin.set("history", [])
        }
    }
}
