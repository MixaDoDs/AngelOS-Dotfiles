import QtQuick
import qs.config
import qs.services
import qs.widgets

PxButton {
    // screen readers (widgets/A11y.js): what this icon is
    Accessible.name: I18n.t("Раскладка клавиатуры", "Keyboard layout")
    Accessible.description: Niri.layoutShort

    visible: Niri.keyboardLayouts.length > 1
    compact: true
    text: Niri.layoutShort
    onClicked: Niri.switchLayout(true)
}
