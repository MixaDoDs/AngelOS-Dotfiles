import QtQuick
import qs.config
import qs.services
import qs.widgets

// A cup of coffee: «Stay awake» (services/Awake — no idle screen, lock, screens off or sleep).
// A click switches it on and off by hand; while it is on (by hand, or by itself for a stream or
// a full-screen window) the cup steams. Right click: Settings → Lock, where the automatic ones are.
PxButton {
    id: root
    // screen readers (widgets/A11y.js): what this icon is
    Accessible.name: I18n.t("Не выключать", "Stay awake")
    Accessible.description: Awake.active ? (Awake.manual ? I18n.t("включено", "on") : I18n.t("включено само", "on by itself")) : I18n.t("выключено", "off")

    compact: true
    flat: true
    checked: Awake.manual
    opacity: Awake.active ? 1 : 0.55
    icon: !Awake.active ? "coffeeCold" : steam ? "coffeeSteam" : "coffee"
    onClicked: Awake.set("toggle")
    onRightClicked: Shell.openSettings("lock")

    property bool steam: false
    Timer {
        interval: 600
        repeat: true
        running: Awake.active && root.visible
        onTriggered: root.steam = !root.steam
    }
}
