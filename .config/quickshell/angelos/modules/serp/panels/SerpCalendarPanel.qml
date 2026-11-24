pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.services
import qs.modules.serp

// serp-skin: Serpantinum's calendar dashboard (its Dashboard / CalendarPopup / SunArc) as a
// panel's content, three columns in one card: the month, the big clock with the sun's arc, the
// weather (angelOS's Weather). Sunrise and sunset are worked out from the place's latitude and
// longitude (a plain solar formula); without a place: 7:00 and 17:00.
Item {
    id: root
    property string screenName
    property real progress: 1

    readonly property int m: Serp.px(18)
    readonly property int gap: Serp.px(20)
    implicitWidth: m * 2 + gap * 2 + Serp.px(270) + Serp.px(300) + Serp.px(260)
    implicitHeight: m * 2 + Serp.px(330)

    readonly property bool shown: visible && progress > 0.01
    readonly property var ru: Qt.locale("ru_RU")

    function st(d) {
        return Math.max(0, Math.min(1, (progress - d) / Math.max(0.01, 1 - d)));
    }
    function cap(s) {
        return s ? s.charAt(0).toUpperCase() + s.slice(1) : s;
    }

    // ---- now ----
    property date now: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: root.shown
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // ---- the sun ----
    readonly property var sun: {
        const d = now;
        const p = Weather.place;
        if (!p || p.lat === undefined || p.lon === undefined)
            return {
                "rise": 7,
                "set": 17,
                "guess": true
            };
        const start = new Date(d.getFullYear(), 0, 0);
        const n = Math.floor((d - start) / 86400000);
        const rad = Math.PI / 180;
        const decl = 23.44 * Math.sin(2 * Math.PI * (284 + n) / 365);
        const b = 2 * Math.PI * (n - 81) / 364;
        const eot = 9.87 * Math.sin(2 * b) - 7.53 * Math.cos(b) - 1.5 * Math.sin(b); // minutes
        const tz = -d.getTimezoneOffset() / 60;
        const noon = 12 - p.lon / 15 - eot / 60 + tz;
        // -0.833°: the refraction and the sun's own size
        const cosH = (Math.sin(-0.833 * rad) - Math.sin(p.lat * rad) * Math.sin(decl * rad)) / (Math.cos(p.lat * rad) * Math.cos(decl * rad));
        if (cosH >= 1)
            return {
                "rise": noon,
                "set": noon,
                "guess": false
            };
        if (cosH <= -1)
            return {
                "rise": 0,
                "set": 24,
                "guess": false
            };
        const h = Math.acos(cosH) / rad / 15;
        return {
            "rise": noon - h,
            "set": noon + h,
            "guess": false
        };
    }
    readonly property real hourNow: now.getHours() + now.getMinutes() / 60 + now.getSeconds() / 3600
    readonly property bool daytime: hourNow >= sun.rise && hourNow <= sun.set
    readonly property real dayFrac: sun.set > sun.rise ? Math.max(0, Math.min(1, (hourNow - sun.rise) / (sun.set - sun.rise))) : 0
    function hm(h) {
        h = (h + 24) % 24;
        let hh = Math.floor(h), mm = Math.round((h - hh) * 60);
        if (mm === 60) {
            hh = (hh + 1) % 24;
            mm = 0;
        }
        return (hh < 10 ? "0" : "") + hh + ":" + (mm < 10 ? "0" : "") + mm;
    }

    // ---- the card ----
    Rectangle {
        anchors.fill: parent
        radius: Serp.radius
        color: Serp.ground
        border.width: 1
        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
    }

    Row {
        x: root.m
        y: root.m
        spacing: root.gap

        // ================= the month =================
        Item {
            id: cal
            width: Serp.px(270)
            height: Serp.px(330)
            opacity: root.st(0)
            transform: Translate {
                y: (1 - root.st(0)) * Serp.px(16)
            }

            property int year: root.now.getFullYear()
            property int month: root.now.getMonth()
            property int shift: 0                 // months away from today's
            readonly property int vy: year + Math.floor((month + shift) / 12)
            readonly property int vm: ((month + shift) % 12 + 12) % 12
            readonly property date first: new Date(vy, vm, 1)
            readonly property int lead: (first.getDay() + 6) % 7
            property int slide: 0                 // -1 / +1: which way the grid came in

            function go(d) {
                slide = d;
                shift += d;
                gridIn.restart();
            }

            Item {
                id: head
                width: parent.width
                height: Serp.px(34)
                SText {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Serp.px(4)
                    text: root.cap(root.ru.standaloneMonthName(cal.vm, Locale.LongFormat)) + " " + cal.vy
                    size: Serp.px(16)
                    bold: true
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Serp.px(2)
                    SButton {
                        visible: cal.shift !== 0
                        onClicked: cal.go(-cal.shift)
                        SText {
                            text: "Сегодня"
                            size: Serp.px(11)
                            color: Serp.mauve
                        }
                    }
                    SButton {
                        onClicked: cal.go(-1)
                        SIcon {
                            name: "chevron-left"
                            size: Serp.px(16)
                        }
                    }
                    SButton {
                        onClicked: cal.go(1)
                        SIcon {
                            name: "chevron-right"
                            size: Serp.px(16)
                        }
                    }
                }
            }
            Row {
                id: wk
                anchors.top: head.bottom
                anchors.topMargin: Serp.px(6)
                Repeater {
                    model: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
                    SText {
                        required property var modelData
                        required property int index
                        width: cal.width / 7
                        height: Serp.px(24)
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        size: Serp.px(11.5)
                        bold: true
                        color: index >= 5 ? Serp.red : Serp.subtext0
                        opacity: index >= 5 ? 0.8 : 1
                    }
                }
            }
            Item {
                anchors.top: wk.bottom
                anchors.topMargin: Serp.px(4)
                anchors.bottom: parent.bottom
                width: parent.width
                clip: true
                Grid {
                    id: grid
                    columns: 7
                    width: parent.width
                    readonly property real cell: Math.min(width / 7, parent.height / 6)
                    NumberAnimation on x {
                        id: gridIn
                        running: false
                        from: cal.slide * Serp.px(30)
                        to: 0
                        duration: Serp.normal
                        easing.type: Easing.OutCubic
                    }
                    Repeater {
                        model: 42
                        Item {
                            id: day
                            required property int index
                            readonly property date d: new Date(cal.vy, cal.vm, 1 - cal.lead + index)
                            readonly property bool inMonth: d.getMonth() === cal.vm
                            readonly property bool today: d.getFullYear() === root.now.getFullYear() && d.getMonth() === root.now.getMonth() && d.getDate() === root.now.getDate()
                            readonly property bool weekend: index % 7 >= 5
                            width: grid.width / 7
                            height: grid.cell
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height) - Serp.px(4)
                                height: width
                                radius: width / 2
                                color: day.today ? Serp.mauve : dayMa.containsMouse ? Serp.surface1 : "transparent"
                                scale: dayMa.pressed ? 0.96 : 1
                                Behavior on color {
                                    ColorAnimation {
                                        duration: Serp.quick
                                    }
                                }
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Serp.quick
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                            SText {
                                anchors.centerIn: parent
                                text: day.d.getDate()
                                size: Serp.px(13)
                                bold: day.today
                                color: day.today ? Serp.onAccent : !day.inMonth ? Serp.subtext0 : day.weekend ? Qt.tint(Serp.text, Qt.alpha(Serp.red, 0.35)) : Serp.text
                                opacity: day.inMonth || day.today ? 1 : 0.5
                            }
                            MouseArea {
                                id: dayMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    // a day of the next or the last month: go there
                                    if (!day.inMonth)
                                        cal.go(day.index < 7 ? -1 : 1);
                                }
                            }
                        }
                    }
                }
            }
            // the wheel turns the months
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => cal.go(e.angleDelta.y > 0 ? -1 : 1)
            }
        }

        Rectangle {
            width: 1
            height: Serp.px(330)
            color: Serp.line
            opacity: root.st(0.1)
        }

        // ================= the clock and the sun =================
        Item {
            id: mid
            width: Serp.px(300) - root.gap - 1
            height: Serp.px(330)
            opacity: root.st(0.12)
            transform: Translate {
                y: (1 - root.st(0.12)) * Serp.px(16)
            }

            Column {
                id: clockCol
                width: parent.width
                y: Serp.px(18)
                spacing: Serp.px(2)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Serp.px(4)
                    SText {
                        id: hhmm
                        text: Qt.formatTime(root.now, "HH:mm")
                        size: Serp.px(46)
                        black: true
                        color: Serp.mauve
                    }
                    SText {
                        anchors.baseline: hhmm.baseline
                        text: Qt.formatTime(root.now, "ss")
                        size: Serp.px(18)
                        bold: true
                        color: Serp.subtext0
                    }
                }
                SText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.ru.toString(root.now, "dddd, d MMMM")
                    size: Serp.px(13.5)
                    color: Serp.subtext1
                }
            }

            // the sun's arc
            Item {
                id: arc
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Serp.px(30)
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - Serp.px(24)
                height: width / 2 + Serp.px(8)
                readonly property real r: width / 2 - Serp.px(10)
                readonly property real cx: width / 2
                readonly property real cy: height - Serp.px(4)
                // the arc draws itself in with the intro
                readonly property real frac: root.daytime ? root.dayFrac * root.st(0.3) : 0
                readonly property real ang: Math.PI * (1 - frac)

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Serp.surface2
                        strokeWidth: Serp.px(2)
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [2, 3]
                        PathAngleArc {
                            centerX: arc.cx
                            centerY: arc.cy
                            radiusX: arc.r
                            radiusY: arc.r
                            startAngle: 180
                            sweepAngle: 180
                        }
                    }
                    ShapePath {
                        strokeColor: Serp.mauve
                        strokeWidth: Serp.px(3)
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: arc.cx
                            centerY: arc.cy
                            radiusX: arc.r
                            radiusY: arc.r
                            startAngle: 180
                            sweepAngle: 180 * arc.frac
                        }
                    }
                }
                // the horizon
                Rectangle {
                    x: 0
                    y: arc.cy
                    width: parent.width
                    height: 1
                    color: Serp.line
                }
                // the sun (or, at night, the moon resting on the horizon)
                Rectangle {
                    readonly property real s: Serp.px(root.daytime ? 18 : 14)
                    width: s
                    height: s
                    radius: s / 2
                    x: arc.cx + arc.r * Math.cos(arc.ang) - s / 2
                    y: arc.cy - arc.r * Math.sin(arc.ang) - s / 2
                    color: root.daytime ? Serp.yellow : Serp.surface2
                    border.width: root.daytime ? Serp.px(3) : 1
                    border.color: root.daytime ? Qt.alpha(Serp.yellow, 0.35) : Serp.overlay
                    visible: root.daytime
                }
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Serp.px(12)
                    spacing: Serp.px(2)
                    SIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: root.daytime ? "sun" : "moon"
                        size: Serp.px(18)
                        color: root.daytime ? Serp.yellow : Serp.blue
                    }
                    SText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        readonly property int remain: Math.round((root.daytime ? root.sun.set - root.hourNow : (root.sun.rise - root.hourNow + 24) % 24) * 60)
                        text: (root.daytime ? "до заката " : "до восхода ") + Math.floor(remain / 60) + " ч " + remain % 60 + " мин"
                        size: Serp.px(11)
                        color: Serp.subtext0
                    }
                }
            }
            // the hours under the ends
            SText {
                anchors.top: arc.bottom
                anchors.topMargin: Serp.px(2)
                x: arc.x
                text: "↑ " + root.hm(root.sun.rise)
                size: Serp.px(11.5)
                color: Serp.subtext0
            }
            SText {
                anchors.top: arc.bottom
                anchors.topMargin: Serp.px(2)
                anchors.right: arc.right
                text: root.hm(root.sun.set) + " ↓"
                size: Serp.px(11.5)
                color: Serp.subtext0
            }
        }

        Rectangle {
            width: 1
            height: Serp.px(330)
            color: Serp.line
            opacity: root.st(0.2)
        }

        // ================= the weather =================
        Item {
            id: wx
            width: Serp.px(260) - 1
            height: Serp.px(330)
            opacity: root.st(0.24)
            transform: Translate {
                y: (1 - root.st(0.24)) * Serp.px(16)
            }
            readonly property var w: Weather.now

            Column {
                anchors.centerIn: parent
                spacing: Serp.px(8)
                visible: !Weather.ok
                SIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "cloud"
                    size: Serp.px(40)
                    color: Serp.overlay
                }
                SText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.busy ? "Узнаю погоду…" : "Погода недоступна"
                    size: Serp.px(14)
                    color: Serp.subtext0
                }
            }

            Column {
                visible: Weather.ok
                width: parent.width
                spacing: Serp.px(10)
                y: Serp.px(6)

                Row {
                    spacing: Serp.px(14)
                    Rectangle {
                        width: Serp.px(64)
                        height: width
                        radius: Serp.radius
                        color: Qt.alpha(Serp.mauve, 0.14)
                        SIcon {
                            anchors.centerIn: parent
                            name: SerpIcons.weather(wx.w)
                            size: Serp.px(34)
                            color: Serp.mauve
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        SText {
                            text: wx.w ? Weather.deg(wx.w.temp) : ""
                            size: Serp.px(36)
                            black: true
                        }
                        SText {
                            text: wx.w ? root.cap(Weather.words(wx.w.code)) : ""
                            size: Serp.px(13)
                            color: Serp.subtext1
                        }
                    }
                }
                Row {
                    spacing: Serp.px(5)
                    SIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "house"
                        size: Serp.px(12)
                        color: Serp.subtext0
                    }
                    SText {
                        width: wx.width - Serp.px(20)
                        text: Weather.place ? Weather.place.name || "" : ""
                        size: Serp.px(12)
                        color: Serp.subtext0
                    }
                }
                Item {
                    width: 1
                    height: Serp.px(4)
                }
                Grid {
                    columns: 2
                    spacing: Serp.px(8)
                    Repeater {
                        model: [
                            {
                                "label": "Ощущается",
                                "icon": "activity",
                                "value": wx.w ? Weather.deg(wx.w.feels) : "—"
                            },
                            {
                                "label": "Ветер",
                                "icon": "wind",
                                "value": wx.w && wx.w.wind !== undefined ? Math.round(wx.w.wind) + " м/с" : "—"
                            },
                            {
                                "label": "Мин",
                                "icon": "chevron-down",
                                "value": wx.w ? Weather.deg(wx.w.min) : "—"
                            },
                            {
                                "label": "Макс",
                                "icon": "chevron-up",
                                "value": wx.w ? Weather.deg(wx.w.max) : "—"
                            }
                        ]
                        SCard {
                            id: tile
                            required property var modelData
                            required property int index
                            width: (wx.width - Serp.px(8)) / 2
                            height: Serp.px(64)
                            color: tileHover.hovered ? Serp.surface1 : Serp.surface0
                            opacity: root.st(0.3 + index * 0.06)
                            transform: Translate {
                                y: (1 - root.st(0.3 + tile.index * 0.06)) * Serp.px(12)
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: Serp.quick
                                }
                            }
                            HoverHandler {
                                id: tileHover
                            }
                            Row {
                                x: Serp.px(10)
                                y: Serp.px(10)
                                spacing: Serp.px(5)
                                SIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: tile.modelData.icon
                                    size: Serp.px(12)
                                    color: Serp.mauve
                                }
                                SText {
                                    text: tile.modelData.label
                                    size: Serp.px(11)
                                    color: Serp.subtext0
                                }
                            }
                            SText {
                                x: Serp.px(10)
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: Serp.px(8)
                                text: tile.modelData.value
                                size: Serp.px(18)
                                bold: true
                            }
                        }
                    }
                }
            }
        }
    }

    // a click inside stays inside
    MouseArea {
        anchors.fill: parent
        z: -10
    }
}
