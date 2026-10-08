import QtQuick
import qs.config
import qs.services
import qs.widgets

PxButton {
    // screen readers (widgets/A11y.js): what this icon is
    Accessible.name: I18n.t("Уведомления", "Notifications")
    Accessible.description: (Config.notifications.dnd ? I18n.t("не беспокоить; ", "do not disturb; ") : "") + I18n.t("непрочитанных: ", "unread: ") + Notifs.unread

    compact: true
    flat: true
    icon: Config.notifications.dnd ? "bellOff" : "bell"
    text: Notifs.unread > 0 ? String(Notifs.unread) : ""
    onClicked: Config.notifications.dnd = !Config.notifications.dnd
}
