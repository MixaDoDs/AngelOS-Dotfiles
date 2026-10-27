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
    // the bubble over it (BarItem)
    readonly property string barTip: (Notifs.unread > 0 ? I18n.t("Непрочитанных: ", "Unread: ") + Notifs.unread : I18n.t("Новых уведомлений нет", "No new notifications")) + (Config.notifications.dnd ? I18n.t(" · не беспокоить", " · do not disturb") : "")

    compact: true
    flat: true
    icon: Config.notifications.dnd ? "bellOff" : "bell"
    // unread ones: a dot in the key's corner, not the count (80 and 2 read the same — something
    // is waiting); the list itself is in the panel the click opens. The hell bar keeps the count.
    text: barInk && Notifs.unread > 0 ? String(Notifs.unread) : ""
    checked: pop.visible

    Rectangle {
        visible: Notifs.unread > 0 && !root.barInk
        x: parent.width - width - Theme.u * 2
        y: Theme.u * 2
        width: Theme.u * 4
        height: Theme.u * 4
        color: Config.notifications.dnd ? Theme.textDim : Theme.accent
        border.width: Theme.u
        border.color: Theme.edge
    }
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
