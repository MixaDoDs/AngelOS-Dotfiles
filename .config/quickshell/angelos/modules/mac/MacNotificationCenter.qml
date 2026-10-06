pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Notification Center of the Golden Gate skin: a column along the right edge under the menu bar,
// opened by the date and time (as on a Mac). The notifications kept (services/Notifs), newest
// first, each a glass card with the app, the time, the title and the text — × removes one,
// "Clear" all of them — and under them a calendar widget with today marked. Esc or a click outside
// closes it; opening it marks the notifications read.
PanelWindow {
    id: win

    required property var modelData
    readonly property string screenName: modelData.name
    readonly property bool open: GoldenGate.panel === "nc" && GoldenGate.panelScreen === screenName
    readonly property real colW: GoldenGate.px(356)
    readonly property real gap: GoldenGate.px(10)
    onOpenChanged: if (open)
        Notifs.markRead()
    // built on demand (MacDesktop: LazyLoader), often already open: mark read and slide in
    // from the first frame
    property bool built: false
    readonly property bool shown: open && built
    Component.onCompleted: {
        if (open)
            Notifs.markRead();
        built = true;
    }

    screen: modelData
    visible: open || column.opacity > 0
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "angelos-macnc"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // takes input: everywhere but the menu bar while open (a click outside closes it)
    mask: Region {
        item: open ? full : null
        Region {
            item: bar
            intersection: Intersection.Subtract
        }
    }
    BackgroundEffect.blurRegion: GoldenGate.blurOn && open ? blurRegion : null
    Region {
        id: blurRegion
        Region {
            item: header
            radius: GoldenGate.px(16)
        }
        Region {
            item: cal
            radius: GoldenGate.px(22)
        }
        Region {
            item: cards
            radius: GoldenGate.px(18)
        }
    }
    Item {
        id: full
        anchors.fill: parent
    }
    Item {
        id: bar
        width: parent.width
        height: GoldenGate.barHeight
    }
    MouseArea {
        anchors.fill: parent
        onPressed: GoldenGate.closePanel()
    }

    function ago(t) {
        const s = Math.max(0, (Date.now() - t) / 1000);
        if (s < 60)
            return I18n.t("сейчас", "now");
        if (s < 3600)
            return Math.floor(s / 60) + I18n.t(" мин", "m");
        if (s < 86400)
            return Math.floor(s / 3600) + I18n.t(" ч", "h");
        return I18n.locale.toString(new Date(t), "d MMM");
    }

    Column {
        id: column
        x: win.width - win.colW - GoldenGate.px(10)
        y: GoldenGate.barHeight + GoldenGate.px(8)
        width: win.colW
        spacing: win.gap
        opacity: win.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.ms(150)
            }
        }
        transform: Translate {
            x: win.shown ? 0 : GoldenGate.px(30)
            Behavior on x {
                NumberAnimation {
                    duration: Motion.ms(180)
                    easing.type: Easing.OutCubic
                }
            }
        }
        focus: win.open
        Keys.onEscapePressed: GoldenGate.closePanel()

        // "Notifications" and Clear
        MacGlass {
            id: header
            visible: Notifs.history.length > 0
            width: parent.width
            height: GoldenGate.px(34)
            radius: GoldenGate.px(16)
            shadowSize: GoldenGate.px(12)
            MacText {
                x: GoldenGate.px(14)
                height: parent.height
                text: I18n.t("Уведомления", "Notifications")
                semibold: true
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: GoldenGate.px(6)
                anchors.verticalCenter: parent.verticalCenter
                width: clearText.implicitWidth + GoldenGate.px(18)
                height: GoldenGate.px(24)
                radius: height / 2
                color: GoldenGate.controlBg
                MacText {
                    id: clearText
                    anchors.centerIn: parent
                    text: I18n.t("Очистить", "Clear")
                    size: GoldenGate.smallSize + GoldenGate.px(1)
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Notifs.clearHistory()
                }
            }
        }
        // the notifications
        MacGlass {
            id: cards
            visible: Notifs.history.length > 0
            width: parent.width
            height: Math.min(list.contentHeight + GoldenGate.px(8), win.height * 0.55)
            radius: GoldenGate.px(18)
            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: GoldenGate.px(4)
                clip: true
                spacing: 0
                model: Notifs.history.slice(0, 30)
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    id: card
                    required property var modelData
                    required property int index
                    width: list.width
                    height: body.implicitHeight + GoldenGate.px(20)
                    Rectangle {
                        visible: card.index > 0
                        x: GoldenGate.px(12)
                        width: parent.width - GoldenGate.px(24)
                        height: 1
                        color: GoldenGate.separator
                    }
                    Image {
                        id: appIcon
                        x: GoldenGate.px(10)
                        y: GoldenGate.px(10)
                        width: GoldenGate.px(32)
                        height: width
                        sourceSize: Qt.size(width * 2, height * 2)
                        smooth: true
                        source: {
                            const i = String(card.modelData.icon || "");
                            return !i ? Quickshell.iconPath("dialog-information", true) : i.startsWith("/") ? "file://" + i : i.includes("://") ? i : Quickshell.iconPath(i, true);
                        }
                    }
                    Column {
                        id: body
                        anchors.left: appIcon.right
                        anchors.leftMargin: GoldenGate.px(10)
                        anchors.right: parent.right
                        anchors.rightMargin: GoldenGate.px(30)
                        y: GoldenGate.px(9)
                        Row {
                            width: parent.width
                            MacText {
                                width: parent.width - when.implicitWidth
                                text: card.modelData.summary || card.modelData.appName
                                semibold: true
                            }
                            MacText {
                                id: when
                                text: win.ago(card.modelData.time)
                                size: GoldenGate.smallSize
                                color: GoldenGate.secondaryLabel
                            }
                        }
                        MacText {
                            width: parent.width
                            text: String(card.modelData.body || "").replace(/<[^>]*>/g, "")
                            visible: text !== ""
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            color: GoldenGate.label
                        }
                    }
                    MacIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: GoldenGate.px(10)
                        y: GoldenGate.px(11)
                        name: "x"
                        size: GoldenGate.px(13)
                        stroke: 2.2
                        color: GoldenGate.secondaryLabel
                        visible: rowHover.hovered
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -GoldenGate.px(4)
                            onClicked: Notifs.removeHistory(card.modelData.hid)
                        }
                    }
                    HoverHandler {
                        id: rowHover
                    }
                }
            }
        }
        // the calendar widget
        MacGlass {
            id: cal
            width: parent.width
            height: calCol.implicitHeight + GoldenGate.px(24)
            radius: GoldenGate.px(22)
            property date today: new Date()
            Timer {
                interval: 60000
                running: win.open
                repeat: true
                onTriggered: cal.today = new Date()
            }
            readonly property var cells: {
                const d = new Date(today.getFullYear(), today.getMonth(), 1);
                // weeks start on Monday in Russian, on Sunday in English (like macOS by region)
                const first = I18n.english ? d.getDay() : (d.getDay() + 6) % 7;
                const days = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
                const out = [];
                for (let i = 0; i < first; i++)
                    out.push(0);
                for (let i = 1; i <= days; i++)
                    out.push(i);
                return out;
            }
            Column {
                id: calCol
                x: GoldenGate.px(16)
                y: GoldenGate.px(12)
                width: parent.width - GoldenGate.px(32)
                spacing: GoldenGate.px(6)
                MacText {
                    text: {
                        const s = I18n.locale.standaloneMonthName(cal.today.getMonth(), Locale.LongFormat);
                        return s.charAt(0).toUpperCase() + s.slice(1) + " " + cal.today.getFullYear();
                    }
                    color: "#ff453a"
                    semibold: true
                }
                Grid {
                    columns: 7
                    width: parent.width
                    readonly property real cell: width / 7
                    Repeater {
                        model: I18n.english ? ["S", "M", "T", "W", "T", "F", "S"] : ["П", "В", "С", "Ч", "П", "С", "В"]
                        MacText {
                            required property string modelData
                            width: parent.cell
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            size: GoldenGate.smallSize
                            color: GoldenGate.secondaryLabel
                            semibold: true
                        }
                    }
                    Repeater {
                        model: cal.cells
                        Item {
                            id: day
                            required property int modelData
                            width: parent.cell
                            height: GoldenGate.px(26)
                            Rectangle {
                                anchors.centerIn: parent
                                width: GoldenGate.px(24)
                                height: width
                                radius: width / 2
                                color: "#ff453a"
                                visible: day.modelData === cal.today.getDate()
                            }
                            MacText {
                                anchors.centerIn: parent
                                text: day.modelData > 0 ? day.modelData : ""
                                color: day.modelData === cal.today.getDate() ? "#ffffff" : GoldenGate.label
                                size: GoldenGate.smallSize + GoldenGate.px(1)
                            }
                        }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
            }
        }
    }

    RightClickGuard {}
}
