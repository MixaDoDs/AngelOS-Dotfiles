pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Month grid + notification history.
BarPopup {
    id: root

    title: I18n.exe(I18n.t("календарь", "calendar"))
    panelId: "calendar"                  // `angelos panel calendar`, a gesture (services/Gestures)
    icon: "calendar"
    contentWidth: Theme.u * 170
    contentHeight: Theme.u * 250

    property date month: new Date()
    onVisibleChanged: if (visible) {
        month = new Date();
        Notifs.markRead();
    }

    readonly property var days: {
        const first = new Date(month.getFullYear(), month.getMonth(), 1);
        const offset = (first.getDay() + 6) % 7;
        const count = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
        const out = [];
        for (let i = 0; i < offset; i++)
            out.push(0);
        for (let d = 1; d <= count; d++)
            out.push(d);
        return out;
    }

    Column {
        anchors.fill: parent
        spacing: Theme.u * 4

        Row {
            width: parent.width
            PxButton {
                compact: true
                icon: "arrowLeft"
                onClicked: root.month = new Date(root.month.getFullYear(), root.month.getMonth() - 1, 1)
            }
            PxText {
                width: parent.width - Theme.u * 30
                horizontalAlignment: Text.AlignHCenter
                kind: "title"
                text: I18n.locale.standaloneMonthName(root.month.getMonth()) + " " + root.month.getFullYear()
            }
            PxButton {
                compact: true
                icon: "arrowRight"
                onClicked: root.month = new Date(root.month.getFullYear(), root.month.getMonth() + 1, 1)
            }
        }

        Grid {
            id: grid
            columns: 7
            width: parent.width
            readonly property int cell: Math.floor(width / 7)
            Repeater {
                model: [I18n.t("пн", "Mon"), I18n.t("вт", "Tue"), I18n.t("ср", "Wed"), I18n.t("чт", "Thu"), I18n.t("пт", "Fri"), I18n.t("сб", "Sat"), I18n.t("вс", "Sun")]
                PxText {
                    required property string modelData
                    width: grid.cell
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    dim: true
                }
            }
            Repeater {
                model: root.days
                Item {
                    id: day
                    required property int modelData
                    readonly property var now: new Date()
                    readonly property bool today: modelData === now.getDate() && root.month.getMonth() === now.getMonth() && root.month.getFullYear() === now.getFullYear()
                    width: grid.cell
                    height: Theme.u * 11
                    PxIcon {
                        visible: day.today
                        anchors.centerIn: parent
                        name: "heart"
                        pixel: Theme.u + 1
                    }
                    PxText {
                        anchors.centerIn: parent
                        visible: day.modelData > 0
                        text: day.modelData
                        color: day.today ? "#ffffff" : Theme.text
                        font.bold: day.today
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: Theme.u * 3
            PxText {
                kind: "title"
                text: I18n.t("Уведомления", "Notifications")
                width: parent.width - dnd.width - clear.width - Theme.u * 6
            }
            PxToggle {
                id: dnd
                text: I18n.t("тихо", "Quiet")
                checked: Config.notifications.dnd
                onToggled: c => Config.notifications.dnd = c
            }
            PxButton {
                id: clear
                compact: true
                icon: "trash"
                onClicked: Notifs.clearHistory()
            }
        }

        PxBox {
            width: parent.width
            height: parent.height - y
            sunken: true
            color: Qt.alpha(Theme.sunken, 0.7)

            PxScroll {
                anchors.fill: parent
                anchors.margins: Theme.u * 2
                contentHeight: list.implicitHeight

                Column {
                    id: list
                    width: parent.width
                    spacing: Theme.u * 2
                    PxText {
                        visible: Notifs.history.length === 0
                        text: I18n.t("  никто не пишет… ♡", "  No activity… ♡")
                        dim: true
                        height: Theme.u * 20
                    }
                    Repeater {
                        model: Notifs.history
                        Item {
                            id: h
                            required property var modelData
                            width: list.width
                            height: hcol.implicitHeight + Theme.u * 6
                            Rectangle {
                                anchors.fill: parent
                                color: hm.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.12) : "transparent"
                            }
                            AppIcon {
                                id: hicon
                                x: Theme.u * 2
                                y: Theme.u * 3
                                iconName: h.modelData.icon || ""
                                size: Theme.u * 10
                            }
                            Column {
                                id: hcol
                                x: hicon.width + Theme.u * 5
                                y: Theme.u * 3
                                width: parent.width - x - Theme.u * 12
                                PxText {
                                    width: parent.width
                                    text: h.modelData.summary
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                PxText {
                                    width: parent.width
                                    text: Notifs.safeMarkup(h.modelData.body)
                                    textFormat: Text.StyledText
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    dim: true
                                }
                                PxText {
                                    text: h.modelData.appName + " · " + Qt.formatTime(new Date(h.modelData.time), "HH:mm")
                                    kind: "tiny"
                                    dim: true
                                }
                            }
                            MouseArea {
                                id: hm
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Notifs.removeHistory(h.modelData.hid)
                            }
                        }
                    }
                }
            }
        }
    }
}
