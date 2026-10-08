pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The lock's indicators (Settings → Lock → Indicators): battery, missed notifications
// (a count only), keyboard layout, how long it has been locked. `heaven` draws them as
// white capsules with a gold rim, the way a game's login screen has its corner buttons.
Row {
    id: root

    required property var lockScope
    required property date now
    property bool heaven: false
    property bool dark: false
    readonly property int minutesLocked: Math.floor((now.getTime() - lockScope.lockedAt) / 60000)
    readonly property int missed: Notifs.history.filter(h => h.time > lockScope.lockedAt).length

    spacing: Theme.u * 4
    Repeater {
        model: [
            {
                "show": Power.hasBattery,
                "icon": Power.plugged ? "bolt" : "battery",
                "text": Power.percent + "%"
            },
            {
                "show": !!root.lockScope.fingerOn,
                "icon": "fingerprint",
                "text": I18n.t("палец", "finger")
            },
            {
                "show": root.missed > 0,
                "icon": "bell",
                "text": String(root.missed)
            },
            {
                "show": Niri.layoutShort !== "",
                "icon": "keyboard",
                "text": Niri.layoutShort
            },
            {
                "show": true,
                "icon": "lock",
                "text": root.minutesLocked < 1 ? I18n.t("только что", "just now") : root.minutesLocked + I18n.t(" мин", " min")
            }
        ].filter(i => i.show)
        Item {
            id: ind
            required property var modelData
            width: indRow.implicitWidth + Theme.u * (root.heaven ? 14 : 8)
            height: Theme.u * 15
            PxBox {
                anchors.fill: parent
                visible: !root.heaven
                color: Qt.alpha(Theme.face, 0.8)
            }
            HeavenPlate {
                anchors.fill: parent
                visible: root.heaven
                pill: true
                dark: root.dark
            }
            Row {
                id: indRow
                anchors.centerIn: parent
                spacing: Theme.u * 3
                PxIcon {
                    name: ind.modelData.icon
                    ink: root.heaven ? (root.dark ? "#e8ecff" : "#3a4a78") : (Theme.dark ? Theme.text : Theme.edge)
                    fill: root.heaven ? "#e8b84a" : Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }
                PxText {
                    text: ind.modelData.text
                    color: root.heaven ? (root.dark ? "#e8ecff" : "#3a4a78") : Theme.text
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
