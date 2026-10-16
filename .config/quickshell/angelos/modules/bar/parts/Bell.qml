import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar

// The bell: a click opens the notifications (the clock's panel: the month and the history, with
// «Quiet» in it), as the bell does on Windows and macOS. A click used to switch Do not disturb on
// silently — the number next to it read "3 unread, click to read". Right click: Do not disturb.
PxButton {
    id: root
    // screen readers (widgets/A11y.js): what this icon is
    Accessible.name: I18n.t("Уведомления", "Notifications")
    Accessible.description: (Config.notifications.dnd ? I18n.t("не беспокоить; ", "do not disturb; ") : "") + I18n.t("непрочитанных: ", "unread: ") + Notifs.unread

    property bool above: true

    compact: true
    flat: true
    icon: Config.notifications.dnd ? "bellOff" : "bell"
    text: Notifs.unread > 0 ? String(Notifs.unread) : ""
    checked: pop.visible
    onClicked: pop.toggle()
    onRightClicked: Config.notifications.dnd = !Config.notifications.dnd

    // built when the pointer comes to the bell, gone a while after it closed (LazyPopup)
    LazyPopup {
        id: pop
        panelId: "calendar"
        anchorItem: root
        warm: root.hovered
        CalendarPanel {
            anchorItem: root
            above: root.above
        }
    }
}
