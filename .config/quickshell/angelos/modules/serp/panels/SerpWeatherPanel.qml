pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.services
import qs.modules.serp

// serp-skin: the weather (Serpantinum's weather faces and the dashboard's weather column) over
// angelOS's services/Weather (Open-Meteo: now {temp, feels, code, wind, day, max, min, at}). The
// hero: the big temperature, the words, the place, over a little animated sky of the weather's
// kind (SerpWeatherScene). Then the tiles (feels like, wind, min, max), today's min…max bar with
// where it is now, when it was asked and «Обновить». The service has no hourly or daily forecast,
// so there's none here. Opened stale (or never asked): asks once.
Item {
    id: root
    property string screenName: ""
    property real progress: 1
    function st(d) {
        return Math.max(0, Math.min(1, (progress - d) / Math.max(0.01, 1 - d)));
    }
    implicitWidth: Serp.px(480)
    implicitHeight: Serp.px(470)

    readonly property var now: Weather.now
    readonly property bool ok: Weather.ok
    readonly property string kind: now ? Weather.kind(now.code) : "cloudy"
    readonly property bool day: !now || now.day !== false
    // the weather's own colour (his notification scenes): sun yellow, night blue, rain blue…
    readonly property color tint: kind === "clear" ? (day ? Serp.yellow : Serp.blue) : kind === "partly" ? Serp.peach : kind === "rain" ? Serp.blue : kind === "storm" ? Serp.yellow : kind === "snow" ? Serp.teal : Serp.teal

    Component.onCompleted: {
        if (!Weather.now || Date.now() - (Weather.now.at || 0) > Weather.refreshMs)
            Weather.refresh();
    }

    function cap(s) {
        s = String(s || "");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }
    function num(v) {
        return v === undefined || v === null || isNaN(v);
    }
    function windWord(w) {
        return num(w) ? "" : w < 0.5 ? "штиль" : w < 3.4 ? "слабый" : w < 8 ? "умеренный" : w < 13.9 ? "сильный" : "шторм";
    }
    function feelsWord() {
        if (!now || num(now.feels) || num(now.temp))
            return "";
        const d = Math.round(now.feels - now.temp);
        return d === 0 ? "как на градуснике" : d < 0 ? "холоднее на " + (-d) + "°" : "теплее на " + d + "°";
    }
    function at() {
        if (!now || !now.at)
            return "";
        const t = new Date(now.at);
        const old = Date.now() - now.at > 20 * 3600 * 1000;
        return Qt.formatDateTime(t, old ? "dd.MM HH:mm" : "HH:mm");
    }
    readonly property real span: now && !num(now.max) && !num(now.min) ? Math.max(1, now.max - now.min) : 1
    readonly property real here: now && !num(now.min) && !num(now.temp) ? Math.max(0, Math.min(1, (now.temp - now.min) / span)) : 0.5

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Serp.radius * 1.4, 24)
        color: Serp.ground
        border.width: 1
        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
    }
    MouseArea {
        anchors.fill: parent
    }

    // ---- not yet / not at all ----
    Column {
        anchors.centerIn: parent
        visible: !root.ok
        spacing: Serp.px(10)
        opacity: root.st(0)
        SIcon {
            id: waitIcon
            anchors.horizontalCenter: parent.horizontalCenter
            name: Weather.busy ? "refresh-cw" : "cloud"
            size: Serp.px(30)
            color: Weather.busy ? Serp.accent : Serp.surface2
            RotationAnimator on rotation {
                running: Weather.busy && root.visible && !root.ok
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 1200
            }
            onNameChanged: rotation = 0
        }
        SText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Weather.busy ? "Узнаю погоду…" : "Погода недоступна"
            size: Serp.px(15)
            black: true
        }
        SText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !Weather.busy
            text: Weather.error || "нет ответа от Open-Meteo"
            size: Serp.px(11.5)
            dim: true
        }
        Item {
            width: 1
            height: Serp.px(4)
        }
        SButton {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !Weather.busy
            flat: false
            ground: Serp.accent
            implicitHeight: Serp.px(32)
            padH: Serp.px(14)
            Row {
                spacing: Serp.px(6)
                SIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "refresh-cw"
                    size: Serp.px(14)
                    color: Serp.onAccent
                }
                SText {
                    text: "Обновить"
                    size: Serp.px(12)
                    bold: true
                    color: Serp.onAccent
                }
            }
            onClicked: Weather.refresh()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Serp.px(16)
        spacing: Serp.px(12)
        visible: root.ok

        // ---- the hero: the sky and the big number ----
        Item {
            id: hero
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: root.st(0)
            transform: Translate {
                y: Serp.px(20) * (1 - root.st(0))
            }
            readonly property real r: Serp.radius

            Rectangle {
                anchors.fill: parent
                radius: hero.r
                color: Serp.surface0
                border.width: 1
                border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
            }
            Rectangle {
                anchors.fill: parent
                radius: hero.r
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.alpha(root.tint, root.day ? 0.26 : 0.16)
                    }
                    GradientStop {
                        position: 1
                        color: "transparent"
                    }
                }
            }
            SerpWeatherScene {
                anchors.fill: parent
                kind: root.kind
                day: root.day
                live: root.visible && root.ok
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: heroMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }
            }
            Item {
                id: heroMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    anchors.fill: parent
                    radius: hero.r
                }
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: Serp.px(18)
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.55
                spacing: Serp.px(2)
                Row {
                    spacing: Serp.px(6)
                    SIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: SerpIcons.weather(root.now)
                        size: Serp.px(15)
                        color: root.tint
                    }
                    SText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.now ? root.cap(Weather.words(root.now.code)) : ""
                        size: Serp.px(13)
                        bold: true
                        color: Serp.subtext1
                    }
                }
                SText {
                    text: root.now ? Weather.deg(root.now.temp) : "—"
                    size: Serp.px(68)
                    black: true
                }
                Row {
                    spacing: Serp.px(6)
                    SIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Weather.place && Weather.place.from === "ip" ? "globe" : "house"
                        size: Serp.px(12)
                        color: Serp.subtext0
                    }
                    SText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, hero.width * 0.5)
                        text: Weather.place ? Weather.place.name : ""
                        size: Serp.px(12)
                        dim: true
                    }
                }
            }
        }

        // ---- the tiles ----
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false          // a nested layout fills by default: it ate the hero's room
            Layout.preferredHeight: Serp.px(84)
            spacing: Serp.px(8)
            opacity: root.st(0.08)
            transform: Translate {
                y: Serp.px(14) * (1 - root.st(0.08))
            }
            component Tile: SCard {
                id: tile
                property string icon
                property color iconTint: Serp.subtext0
                property string label
                property string value
                property string note
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Column {
                    anchors.fill: parent
                    anchors.margins: Serp.px(10)
                    spacing: Serp.px(3)
                    Row {
                        spacing: Serp.px(5)
                        SIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: tile.icon
                            size: Serp.px(12)
                            color: tile.iconTint
                        }
                        SText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tile.label
                            size: Serp.px(10.5)
                            dim: true
                        }
                    }
                    SText {
                        width: parent.width
                        text: tile.value
                        size: Serp.px(20)
                        black: true
                    }
                    SText {
                        width: parent.width
                        text: tile.note
                        size: Serp.px(9.5)
                        color: Serp.overlay
                    }
                }
            }
            Tile {
                icon: "user"
                iconTint: root.tint
                label: "Ощущается"
                value: root.now ? Weather.deg(root.now.feels) : "—"
                note: root.feelsWord()
            }
            Tile {
                icon: "wind"
                iconTint: Serp.teal
                label: "Ветер"
                value: root.now && !root.num(root.now.wind) ? root.now.wind.toFixed(1).replace(".", ",") + " м/с" : "—"
                note: root.now ? root.windWord(root.now.wind) : ""
            }
            Tile {
                icon: "chevron-down"
                iconTint: Serp.blue
                label: "Мин"
                value: root.now ? Weather.deg(root.now.min) : "—"
                note: "за сегодня"
            }
            Tile {
                icon: "chevron-up"
                iconTint: Serp.peach
                label: "Макс"
                value: root.now ? Weather.deg(root.now.max) : "—"
                note: "за сегодня"
            }
        }

        // ---- today: min … max, and where it is now ----
        SCard {
            Layout.fillWidth: true
            Layout.preferredHeight: Serp.px(78)
            opacity: root.st(0.14)
            transform: Translate {
                y: Serp.px(14) * (1 - root.st(0.14))
            }
            visible: !!root.now && !root.num(root.now.min) && !root.num(root.now.max)
            Item {
                anchors.fill: parent
                anchors.margins: Serp.px(12)
                SText {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: "Сегодня"
                    size: Serp.px(12)
                    bold: true
                }
                SText {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    text: root.now ? "сейчас " + Weather.deg(root.now.temp) : ""
                    size: Serp.px(11)
                    bold: true
                    color: root.tint
                }
                SText {
                    id: lo
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    text: root.now ? Weather.deg(root.now.min) : ""
                    size: Serp.px(11)
                    bold: true
                    color: Serp.blue
                }
                SText {
                    id: hi
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    text: root.now ? Weather.deg(root.now.max) : ""
                    size: Serp.px(11)
                    bold: true
                    color: Serp.peach
                }
                Item {
                    id: bar
                    anchors.left: lo.right
                    anchors.right: hi.left
                    anchors.leftMargin: Serp.px(10)
                    anchors.rightMargin: Serp.px(10)
                    anchors.verticalCenter: lo.verticalCenter
                    height: Serp.px(16)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: Serp.px(8)
                        radius: height / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0
                                color: Serp.blue
                            }
                            GradientStop {
                                position: 0.5
                                color: Serp.teal
                            }
                            GradientStop {
                                position: 1
                                color: Serp.peach
                            }
                        }
                        opacity: 0.85
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Serp.px(16)
                        height: width
                        radius: width / 2
                        x: root.here * (bar.width - width)
                        color: Serp.text
                        border.width: Serp.px(3)
                        border.color: Serp.surface0
                        Behavior on x {
                            NumberAnimation {
                                duration: Serp.slow
                                easing.type: Easing.OutQuint
                            }
                        }
                    }
                }
            }
        }

        // ---- when, and ask again ----
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: Serp.px(6)
            opacity: root.st(0.2)
            SIcon {
                name: "clock"
                size: Serp.px(12)
                color: Serp.subtext0
            }
            SText {
                Layout.fillWidth: true
                text: (Weather.error ? Weather.error + " · показываю на " : "обновлено в ") + root.at() + " · Open-Meteo"
                size: Serp.px(11)
                color: Weather.error ? Serp.red : Serp.subtext0
            }
            SButton {
                flat: false
                ground: Serp.surface0
                implicitHeight: Serp.px(30)
                padH: Serp.px(12)
                enabled: !Weather.busy
                Row {
                    spacing: Serp.px(6)
                    SIcon {
                        id: spin
                        anchors.verticalCenter: parent.verticalCenter
                        name: "refresh-cw"
                        size: Serp.px(13)
                        color: Weather.busy ? Serp.accent : Serp.text
                        RotationAnimator on rotation {
                            running: Weather.busy && root.visible
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 1000
                        }
                        Connections {
                            target: Weather
                            function onBusyChanged() {
                                if (!Weather.busy)
                                    spin.rotation = 0;
                            }
                        }
                    }
                    SText {
                        text: Weather.busy ? "Обновляю…" : "Обновить"
                        size: Serp.px(12)
                        bold: true
                    }
                }
                onClicked: Weather.refresh()
            }
        }
    }
}
