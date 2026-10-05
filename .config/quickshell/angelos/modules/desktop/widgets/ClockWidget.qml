import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Big pixel clock + date. Stands still while nobody can see the desk.
// In hell (Theme.realm): Roman numerals in blackletter over a pentagram, and
// between three and four in the night the date gives way to "hora diaboli".
// macOS look (DesktopWidgets.macLook): the time large in SF Pro, the date under it.
Item {
    id: root

    property string screenName
    property var widget
    readonly property bool passive: true     // nothing to click: no input copy needed
    readonly property bool seconds: widget && widget.settings ? !!widget.settings.seconds : false

    readonly property bool mac: DesktopWidgets.macLook
    implicitWidth: mac ? Math.max(DesktopWidgets.mpx(150), macCol.implicitWidth) : (Theme.hell ? hellCol.implicitWidth : col.implicitWidth) + Theme.u * 8
    implicitHeight: mac ? macCol.implicitHeight : Theme.hell ? hellCol.implicitHeight : col.implicitHeight
    // "понедельник, 5 октября" ("d MMMM" keeps the month's genitive in Russian)
    readonly property string dateText: Qt.locale(I18n.english ? "en_US" : "ru_RU").toString(clock.date, I18n.english ? "dddd, MMMM d" : "dddd, d MMMM")

    SystemClock {
        id: clock
        enabled: !Shell.hiddenScreen(root.screenName)
        precision: root.seconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Column {
        id: macCol
        visible: root.mac
        spacing: DesktopWidgets.mpx(2)
        MacWidgetText {
            text: root.dateText
            size: 15
            weight: Font.DemiBold
            role: "secondary"
        }
        MacWidgetText {
            text: I18n.time(clock.date, root.seconds)
            size: root.seconds ? 46 : 58
            weight: Font.DemiBold
            lineHeightMode: Text.ProportionalHeight
            lineHeight: 0.92
        }
    }

    Column {
        id: col
        visible: !Theme.hell && !root.mac
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.u * 2
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.time(clock.date, root.seconds)
            font.family: Theme.fontTitle
            font.pixelSize: Theme.fontPx(54, Theme.fontTitle)
            color: Theme.dark ? Theme.text : Theme.edge
            style: Text.Outline
            styleColor: Qt.alpha(Theme.accent, 0.6)
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.u * 3
            PxIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "heart"
            }
            PxText {
                text: Qt.locale(I18n.english ? "en_US" : "ru_RU").toString(clock.date, "dddd, d MMMM")
                kind: "title"
                dim: true
            }
        }
    }

    Column {
        id: hellCol
        visible: Theme.hell
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.u
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Theme.roman(clock.hours) + " : " + Theme.roman(clock.minutes) + (root.seconds ? " : " + Theme.roman(clock.seconds) : "")
            font.family: Theme.fontHell
            font.pixelSize: Theme.hellPx(2 * Theme.fs)
            color: Theme.hellText
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.u * 3
            PxIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "pentagram"
                ink: Theme.hellRim
                fill: Theme.hellFace
            }
            PxText {
                readonly property bool witching: clock.hours === 3
                // "d MMMM" keeps the month's genitive in Russian; the day becomes Roman
                text: witching ? "hora diaboli" : Qt.locale(I18n.english ? "en_US" : "ru_RU").toString(clock.date, "dddd, d MMMM").replace(/\d+/, Theme.roman(clock.date.getDate()))
                kind: "title"
                font.family: Theme.hellCovers(text) ? Theme.fontHell : Theme.fontHellText
                font.pixelSize: Theme.hellCovers(text) ? Theme.hellPx(Theme.fs) : Theme.hellTextPx(Theme.fs)
                color: witching ? Theme.hellAccent : Theme.hellTextDim
            }
            PxIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "pentagram"
                ink: Theme.hellRim
                fill: Theme.hellFace
            }
        }
    }
}
