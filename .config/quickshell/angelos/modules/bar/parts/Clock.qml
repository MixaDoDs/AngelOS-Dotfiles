import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar

Item {
    id: root

    required property string screenName
    property bool above: true
    property bool showDate: true
    // in an upright bar (BarItem): as narrow as the bar. The hours and minutes alone in the big
    // line, the seconds and AM/PM small under them — "5:58 PM" (the 12-hour clock English
    // gets) and "17:58:23" in the title font stuck out of the bar and pushed its column aside
    property bool narrow: false
    readonly property var narrowParts: {
        const t = I18n.time(clock.date, false).split(" ");
        return [t[0], ((Config.bar.showSeconds ? Qt.formatTime(clock.date, ":ss") : "") + (t[1] ? " " + t[1] : "")).trim()];
    }
    // the hell bar (BarItem): the circle's text colours; the calendar open is its state
    property bool barInk: false
    readonly property bool barOpen: pop.visible

    implicitWidth: col.implicitWidth + Theme.u * 8
    implicitHeight: col.implicitHeight

    // stands still under a fullscreen game or the lock screen
    SystemClock {
        id: clock
        enabled: !Shell.hiddenScreen(root.screenName)
        precision: Config.bar.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Column {
        id: col
        anchors.centerIn: parent
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.narrow ? root.narrowParts[0] : I18n.time(clock.date, Config.bar.showSeconds)
            kind: root.showDate ? "body" : "title"
            color: root.barInk ? (root.barOpen ? Theme.hellAccent : Theme.hellText) : Theme.text
        }
        PxText {
            visible: root.narrow && text !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.narrow ? root.narrowParts[1] : ""
            kind: "tiny"
            dim: true
            color: root.barInk ? Theme.hellTextDim : Theme.textDim
        }
        PxText {
            visible: root.showDate
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.locale.toString(clock.date, I18n.english ? "ddd, MMM d" : "ddd d MMM")
            kind: "tiny"
            dim: true
            color: root.barInk ? Theme.hellTextDim : Theme.textDim
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pop.toggle()
    }

    // built when the pointer comes to the clock, gone a while after it closed (LazyPopup)
    LazyPopup {
        id: pop
        panelId: "calendar"
        anchorItem: root
        warm: mouse.containsMouse
        CalendarPanel {
            id: panel
            anchorItem: root
            above: root.above
        }
    }
}
