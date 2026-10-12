import QtQuick
import qs.config
import qs.services
import qs.widgets

PxButton {
    // screen readers (widgets/A11y.js): what this icon is
    Accessible.name: I18n.t("Раскладка клавиатуры", "Keyboard layout")
    Accessible.description: CapsLock.on ? Niri.layoutShort + ", Caps Lock" : Niri.layoutShort

    // Caps Lock on: the key's arrow next to the layout, the button lit (with one layout it shows up for that alone)
    visible: Niri.keyboardLayouts.length > 1 || CapsLock.on
    compact: true
    icon: CapsLock.on ? "caps" : ""
    checked: CapsLock.on
    text: Niri.layoutShort
    onClicked: Niri.switchLayout(true)
}
