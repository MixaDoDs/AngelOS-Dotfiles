pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// The desktop clock. Stands still while nobody can see the desk.
//   S  the time, the weather small under it
//   M  the time and the date, the weather in the corner
//   L  a big time, the date, and the weather in words: feels like, wind, the day's ↑ ↓
// The weather (services/Weather, Open-Meteo) is on unless its right-click toggle says no.
// In hell (Theme.realm): Roman numerals in blackletter over a pentagram, the degrees Roman
// too, and between three and four in the night the date gives way to "hora diaboli".
// macOS look (DesktopWidgets.macLook): the time large in SF Pro, the date under it.
Item {
    id: root

    property string screenName
    property var widget
    property string size: "m"
    property string frameKind: "window"
    property bool face: true
    readonly property bool passive: true     // nothing to click: no input copy needed
    readonly property var st: widget && widget.settings ? widget.settings : ({})
    readonly property bool seconds: !!st.seconds
    readonly property bool weatherOn: st.weather !== false && Weather.ok
    readonly property var wx: Weather.now || ({})

    readonly property bool mac: DesktopWidgets.macLook
    readonly property bool hell: Theme.hell
    readonly property var body: mac ? macCol : hell ? hellBody : heavenBody
    implicitWidth: mac ? Math.max(DesktopWidgets.mpx(150), macCol.implicitWidth) : body.implicitWidth + (size === "s" ? 0 : Theme.u * 8)
    implicitHeight: body.implicitHeight
    readonly property var locale: Qt.locale(I18n.english ? "en_US" : "ru_RU")
    // "понедельник, 5 октября" ("d MMMM" keeps the month's genitive in Russian)
    readonly property string dateText: locale.toString(clock.date, I18n.english ? "dddd, MMMM d" : "dddd, d MMMM")
    readonly property string shortDate: locale.toString(clock.date, I18n.english ? "ddd, MMM d" : "ddd, d MMM")
    readonly property int timePx: Theme.fontPx(size === "s" ? 32 : size === "l" ? 76 : 54, Theme.fontTitle)

    SystemClock {
        id: clock
        enabled: !Shell.hiddenScreen(root.screenName)
        precision: root.seconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    // ---- macOS look (one layout) ----
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
        MacWidgetText {
            visible: root.weatherOn
            text: Weather.deg(root.wx.temp) + "  " + Weather.words(root.wx.code) + (Weather.place ? " · " + Weather.place.name : "")
            size: 13
            role: "secondary"
        }
    }

    // ---- heaven ----
    // (Components, not inline `component`s: those can't see this file's ids)
    Component {
        id: timeText
        PxText {
            text: I18n.time(clock.date, root.seconds)
            font.family: Theme.fontTitle
            font.pixelSize: root.timePx
            color: Theme.dark ? Theme.text : Theme.edge
            style: Text.Outline
            styleColor: Qt.alpha(Theme.accent, 0.6)
        }
    }
    Item {
        id: heavenBody
        visible: !root.mac && !root.hell
        implicitWidth: root.size === "s" ? sCol.implicitWidth : root.size === "l" ? lCol.implicitWidth : mRow.implicitWidth
        implicitHeight: root.size === "s" ? sCol.implicitHeight : root.size === "l" ? lCol.implicitHeight : mRow.implicitHeight
        anchors.horizontalCenter: parent.horizontalCenter

        // S: the time, the weather small under it
        Column {
            id: sCol
            visible: root.size === "s"
            spacing: Theme.u
            Loader {
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: timeText
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.u * 3
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.shortDate
                    kind: "tiny"
                    dim: true
                }
                PxIcon {
                    visible: root.weatherOn
                    anchors.verticalCenter: parent.verticalCenter
                    name: Weather.icon(root.wx.code, root.wx.day)
                    pixel: Math.max(1, Theme.u - 1)
                }
                PxText {
                    visible: root.weatherOn
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.deg(root.wx.temp)
                    kind: "tiny"
                    font.bold: true
                }
            }
        }

        // M: the time and the date, the weather in the corner
        Row {
            id: mRow
            visible: root.size === "m"
            spacing: Theme.u * 8
            Column {
                spacing: Theme.u * 2
                Loader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    sourceComponent: timeText
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.u * 3
                    PxIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "heart"
                    }
                    PxText {
                        text: root.dateText
                        kind: "title"
                        dim: true
                    }
                }
            }
            Column {
                visible: root.weatherOn
                spacing: Theme.u * 2
                topPadding: Theme.u * 2
                PxIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: Weather.icon(root.wx.code, root.wx.day)
                    pixel: Theme.u * 2
                }
                PxText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.deg(root.wx.temp)
                    kind: "title"
                    font.bold: true
                }
            }
        }

        // L: big time, the date, the weather in words
        Column {
            id: lCol
            visible: root.size === "l"
            spacing: Theme.u * 3
            Loader {
                id: lTime
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: timeText
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.u * 3
                PxIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "heart"
                }
                PxText {
                    text: root.dateText
                    kind: "title"
                    dim: true
                }
            }
            // a dotted line, then the weather
            Row {
                visible: root.weatherOn
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.u * 2
                Repeater {
                    model: Math.max(4, Math.floor(lTime.width / (Theme.u * 4)))
                    Rectangle {
                        width: Theme.u * 2
                        height: Theme.u
                        color: Qt.alpha(Theme.text, 0.25)
                    }
                }
            }
            Row {
                visible: root.weatherOn
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.u * 5
                PxIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Weather.icon(root.wx.code, root.wx.day)
                    pixel: Theme.u * 3
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.u
                    PxText {
                        text: Weather.deg(root.wx.temp) + "  " + Weather.words(root.wx.code)
                        kind: "title"
                        font.bold: true
                    }
                    PxText {
                        text: I18n.t("ощущается ", "feels like ") + Weather.deg(root.wx.feels) + " · " + I18n.t("ветер ", "wind ") + Math.round(root.wx.wind || 0) + I18n.t(" м/с", " m/s")
                        kind: "tiny"
                        dim: true
                    }
                    PxText {
                        text: "↑ " + Weather.deg(root.wx.max) + "  ↓ " + Weather.deg(root.wx.min) + (Weather.place ? "  · " + Weather.place.name : "")
                        kind: "tiny"
                        dim: true
                    }
                }
            }
        }
    }

    // ---- hell ----
    // the degrees in Roman too ("nulla" for zero, as the Romans had no numeral for it)
    function hellDeg(t) {
        if (t === undefined || t === null || isNaN(t))
            return "—";
        const r = Math.round(t);
        return r === 0 ? "nulla°" : (r < 0 ? "−" : "") + Theme.roman(Math.abs(r)) + "°";
    }
    Column {
        id: hellBody
        visible: root.hell && !root.mac
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.u * (root.size === "l" ? 3 : 1)
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Theme.roman(clock.hours) + " : " + Theme.roman(clock.minutes) + (root.seconds ? " : " + Theme.roman(clock.seconds) : "")
            font.family: Theme.fontHell
            font.pixelSize: Theme.hellPx((root.size === "s" ? 1.4 : root.size === "l" ? 2.8 : 2) * Theme.fs)
            color: Theme.hellText
        }
        Row {
            visible: root.size !== "s"
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
                text: witching ? "hora diaboli" : root.locale.toString(clock.date, "dddd, d MMMM").replace(/\d+/, Theme.roman(clock.date.getDate()))
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
        // the weather: the degrees in Roman, the words at L
        PxText {
            visible: root.weatherOn
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.hellDeg(root.wx.temp) + (root.size === "l" ? "  ·  " + Weather.words(root.wx.code) + "  ·  ↑ " + root.hellDeg(root.wx.max) + "  ↓ " + root.hellDeg(root.wx.min) : "")
            font.family: Theme.hellCovers(text) ? Theme.fontHell : Theme.fontHellText
            font.pixelSize: Theme.hellCovers(text) ? Theme.hellPx(Theme.fs) : Theme.hellTextPx(Theme.fs)
            color: Theme.hellTextDim
        }
    }
}
