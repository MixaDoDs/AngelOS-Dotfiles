pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services

// serp-skin: «Which screen is the main one?» (modules/settings/MainScreenPrompt) in Serpantinum's
// look. `host` is the prompt's window: `due` (false = later) and pick(name).
SerpDialog {
    id: root

    property var host: null

    icon: "monitor"
    title: I18n.t("Какой экран главный?", "Which screen is the main one?")
    body: I18n.t("Там при входе в систему и на блокировке появятся поле пароля и курсор, там же живут виджеты и ангел. Потом: Настройки → Монитор → Главный экран.", "The password field and the pointer of the login and the lock show there, the widgets and the angel live there. Later: Settings → Monitor → Main screen.")
    cardWidth: Serp.px(480)
    buttons: [
        {
            "label": I18n.t("Позже", "Later"),
            "kind": "flat"
        }
    ]
    onDismissed: if (host)
        host.due = false
    onPicked: if (host)
        host.due = false

    Flow {
        width: parent.width
        spacing: Serp.px(8)
        Repeater {
            model: Quickshell.screens
            SerpDialogPill {
                required property var modelData
                icon: "monitor"
                kind: modelData.name === (Shell.widestScreen ? Shell.widestScreen.name : "") ? "primary" : ""
                label: modelData.name + "  " + modelData.width + "×" + modelData.height + (modelData.model ? "  " + modelData.model : "")
                onClicked: if (root.host)
                    root.host.pick(modelData.name)
            }
        }
    }
}
