import QtQuick
import qs.config
import qs.services

// The little star on what's new in Settings (services/SettingsNews): a row, a group, a page's
// tile, a section. It twinkles now and then — a slow breath, still when motion is off.
PxIcon {
    id: root

    property string tip: I18n.t("Новое", "New")
    // a small five-point star (a plus-like sparkle read as "+" this small)
    bitmap: ["...o...", "..ooo..", "ooowooo", ".ooooo.", "..ooo..", ".oo.oo.", ".o...o."]
    pixel: Math.max(1, Math.round(Theme.u * 0.75))
    ink: Theme.accent
    fill: Theme.accent
    light: Theme.mix(Theme.accent, "#ffffff", 0.6)
    opacity: 1
    SequentialAnimation on opacity {
        running: root.visible && !Motion.calm
        loops: Animation.Infinite
        PauseAnimation {
            duration: 2600
        }
        NumberAnimation {
            to: 0.45
            duration: 700
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 1
            duration: 900
            easing.type: Easing.InOutSine
        }
    }
}
