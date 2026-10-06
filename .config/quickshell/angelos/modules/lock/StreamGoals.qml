pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The stream's goals on the NGO lock: the day's three tasks (services/HeavenStars) as stream
// goals, and the heavenly pass as the channel's level.
PxWindow {
    id: root

    title: I18n.exe("goals")
    icon: "star"
    compact: true
    closable: false
    height: titleHeight + col.implicitHeight + Theme.pad * 2 + Theme.u * 6

    Column {
        id: col
        width: parent.width
        spacing: Theme.u * 3
        Repeater {
            model: HeavenStars.tasks
            Column {
                id: goal
                required property var modelData
                width: col.width
                spacing: Theme.u
                Row {
                    width: parent.width
                    PxText {
                        width: parent.width - amount.width
                        text: (goal.modelData.done ? "✓ " : "") + I18n.t(goal.modelData.ru, goal.modelData.en)
                        kind: "tiny"
                        color: goal.modelData.done ? Theme.ok : Theme.text
                        elide: Text.ElideRight
                    }
                    PxText {
                        id: amount
                        text: goal.modelData.have + "/" + goal.modelData.goal
                        kind: "tiny"
                        dim: true
                    }
                }
                Rectangle {
                    width: parent.width
                    height: Theme.u * 3
                    color: Theme.sunken
                    Rectangle {
                        width: Math.round(parent.width * goal.modelData.have / goal.modelData.goal / Theme.u) * Theme.u
                        height: parent.height
                        color: goal.modelData.done ? Theme.ok : Theme.accent
                    }
                }
            }
        }
        Row {
            spacing: Theme.u * 3
            PxText {
                text: I18n.t("канал ур. ", "channel lv ") + HeavenStars.level
                kind: "tiny"
                color: Theme.accent
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: col.width - Theme.u * 50
                height: Theme.u * 3
                color: Theme.sunken
                Rectangle {
                    width: Math.round(parent.width * (HeavenStars.level >= 30 ? 1 : (HeavenStars.xp % HeavenStars.levelXp) / HeavenStars.levelXp) / Theme.u) * Theme.u
                    height: parent.height
                    color: Theme.accent2
                }
            }
        }
    }
}
