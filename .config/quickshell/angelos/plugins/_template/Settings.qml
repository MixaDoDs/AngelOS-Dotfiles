import QtQuick
import qs.config
import qs.services
import qs.widgets

// Page in Настройки → Плагины → __NAME__.
Column {
    property var plugin
    width: parent ? parent.width : 400
    spacing: Skin.px(10)

    PxGroup {
        title: "__NAME__"
        icon: "heart"
        width: parent.width
        SettingRow {
            label: I18n.t("Текст на панели", "Bar text")
            PxField {
                width: parent.width
                text: plugin ? plugin.get("label", "♡") : ""
                onEdited: plugin.set("label", text)
            }
        }
    }
}
