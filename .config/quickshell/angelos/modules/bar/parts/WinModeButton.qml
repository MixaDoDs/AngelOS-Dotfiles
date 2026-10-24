import QtQuick
import qs.config
import qs.services
import qs.widgets

// Desktop or the Strip (services/WindowConfig, angel-niri's stacking): which one the windows are
// in now, a click for the other. Not in Golden Gate, which is always Desktop (BarLayout.valid).
// Right click: Settings → Windows.
PxButton {
    Accessible.name: I18n.t("Режим окон", "Window mode")
    Accessible.description: WindowConfig.floatAll ? "Desktop" : I18n.t("Лента", "Strip")

    compact: true
    flat: true
    icon: WindowConfig.floatAll ? "layers" : "strip"
    onClicked: WindowConfig.setFloatAll(!WindowConfig.floatAll)
    onRightClicked: Shell.openSettings("windows")
}
