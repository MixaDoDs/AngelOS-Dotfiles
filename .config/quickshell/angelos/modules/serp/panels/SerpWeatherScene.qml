pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.serp

// serp-skin: the weather panel's little sky (after Serpantinum's weather scenes): the sun with
// turning rays, or the moon and twinkling stars at night, drifting clouds, rain streaks, snow,
// a storm's flash, fog bands — chosen by Weather.kind(code) and day / night. Plain Items only;
// every animation runs only while `live` (the panel is shown). Drawn on the right side, the
// words of the hero stay on the left.
Item {
    id: sc
    property string kind: "clear"            // clear partly cloudy fog rain snow storm
    property bool day: true
    property bool live: true

    readonly property bool clear: kind === "clear"
    readonly property bool partly: kind === "partly"
    readonly property bool wet: kind === "rain" || kind === "storm"
    readonly property bool heavy: wet || kind === "snow" || kind === "cloudy"
    readonly property real cx: width * 0.74
    readonly property real cy: height * 0.42
    readonly property real u: Math.min(width, height) / 200       // the scene's unit

    function rnd(i, k) {
        const v = Math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
        return v - Math.floor(v);
    }

    // ---- stars: night, fewer and fainter behind clouds ----
    Repeater {
        model: sc.day ? 0 : sc.clear || sc.partly ? 18 : 8
        Rectangle {
            id: star
            required property int index
            readonly property real r: sc.rnd(index, 5)
            x: sc.width * (0.38 + sc.rnd(index, 6) * 0.6)
            y: sc.height * sc.rnd(index, 7) * 0.75
            width: Serp.px(1.5 + r * 2)
            height: width
            radius: width / 2
            color: Serp.text
            property real tw: 0.5
            opacity: (sc.clear || sc.partly ? 0.35 : 0.15) + tw * 0.55
            SequentialAnimation on tw {
                running: sc.live
                loops: Animation.Infinite
                PauseAnimation {
                    duration: star.r * 1800
                }
                NumberAnimation {
                    to: 1
                    duration: 900 + star.r * 900
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 0.1
                    duration: 1200 + star.r * 900
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    // ---- the sun ----
    Item {
        id: sun
        visible: sc.day && (sc.clear || sc.partly)
        readonly property real d: (sc.clear ? 58 : 44) * sc.u
        x: (sc.partly ? sc.cx - 26 * sc.u : sc.cx) - d / 2
        y: (sc.partly ? sc.cy - 22 * sc.u : sc.cy) - d / 2
        width: d
        height: d
        Rectangle {
            anchors.centerIn: parent
            width: sun.d * 2.3
            height: width
            radius: width / 2
            color: Serp.yellow
            opacity: 0.1
            SequentialAnimation on scale {
                running: sc.live && sun.visible
                loops: Animation.Infinite
                NumberAnimation {
                    to: 1.12
                    duration: 2600
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 0.94
                    duration: 2600
                    easing.type: Easing.InOutSine
                }
            }
        }
        Item {
            anchors.centerIn: parent
            width: sun.d
            height: width
            RotationAnimator on rotation {
                running: sc.live && sun.visible
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 40000
            }
            Repeater {
                model: 12
                Rectangle {
                    required property int index
                    readonly property real a: index * 30 * Math.PI / 180
                    readonly property real rr: sun.d * 0.5 + 9 * sc.u
                    width: 3.2 * sc.u
                    height: (index % 2 ? 7 : 11) * sc.u
                    radius: width / 2
                    x: sun.d / 2 + Math.cos(a) * rr - width / 2
                    y: sun.d / 2 + Math.sin(a) * rr - height / 2
                    rotation: index * 30 + 90
                    color: Serp.yellow
                    opacity: 0.85
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.lighter(Serp.yellow, 1.12)
                }
                GradientStop {
                    position: 1
                    color: Serp.peach
                }
            }
        }
    }

    // ---- the moon: a pale disc with soft craters, bobbing ----
    Item {
        id: moon
        visible: !sc.day && (sc.clear || sc.partly)
        readonly property real d: (sc.clear ? 50 : 40) * sc.u
        x: (sc.partly ? sc.cx - 26 * sc.u : sc.cx) - d / 2
        y: (sc.partly ? sc.cy - 22 * sc.u : sc.cy) - d / 2 + bob * 4 * sc.u
        width: d
        height: d
        property real bob: 0
        SequentialAnimation on bob {
            running: sc.live && moon.visible
            loops: Animation.Infinite
            NumberAnimation {
                to: 1
                duration: 3200
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: -1
                duration: 3200
                easing.type: Easing.InOutSine
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: moon.d * 2
            height: width
            radius: width / 2
            color: Serp.blue
            opacity: 0.1
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Serp.subtext1
        }
        Repeater {
            model: [[0.28, 0.3, 0.2], [0.55, 0.55, 0.26], [0.32, 0.66, 0.13], [0.62, 0.22, 0.11]]
            Rectangle {
                required property var modelData
                x: moon.d * modelData[0]
                y: moon.d * modelData[1]
                width: moon.d * modelData[2]
                height: width
                radius: width / 2
                color: Qt.alpha(Serp.crust, 0.14)
            }
        }
    }

    // ---- fog bands ----
    Repeater {
        model: sc.kind === "fog" ? 4 : 0
        Rectangle {
            id: band
            required property int index
            readonly property real r: sc.rnd(index, 9)
            property real d: r
            x: sc.width * 0.36 + (d - 0.5) * 30 * sc.u
            y: sc.height * (0.3 + index * 0.13)
            width: sc.width * (0.42 + r * 0.2)
            height: 7 * sc.u
            radius: height / 2
            color: Serp.text
            opacity: 0.1 + r * 0.08
            SequentialAnimation on d {
                running: sc.live
                loops: Animation.Infinite
                NumberAnimation {
                    to: 1
                    duration: 5000 + band.r * 3000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 0
                    duration: 5000 + band.r * 3000
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    // ---- the storm's flash: the whole sky blinks, a bolt under the cloud ----
    property real flash: 0
    SequentialAnimation on flash {
        running: sc.live && sc.kind === "storm"
        loops: Animation.Infinite
        PauseAnimation {
            duration: 2600
        }
        NumberAnimation {
            to: 1
            duration: 60
        }
        NumberAnimation {
            to: 0.2
            duration: 90
        }
        NumberAnimation {
            to: 0.9
            duration: 60
        }
        NumberAnimation {
            to: 0
            duration: 420
            easing.type: Easing.OutCubic
        }
        PauseAnimation {
            duration: 1400
        }
    }
    Rectangle {
        anchors.fill: parent
        color: Serp.yellow
        opacity: sc.flash * 0.1
        visible: sc.kind === "storm"
    }

    // ---- rain or snow, under the clouds ----
    SerpWeatherFall {
        visible: sc.wet || sc.kind === "snow"
        x: sc.width * 0.42
        y: sc.cy - 4 * sc.u
        width: sc.width * 0.56
        height: sc.height - y
        snow: sc.kind === "snow"
        count: sc.kind === "snow" ? 22 : sc.kind === "storm" ? 26 : 18
        tint: sc.kind === "snow" ? Serp.text : Serp.blue
        live: sc.live && visible
    }
    SIcon {
        visible: sc.kind === "storm"
        x: sc.cx - size / 2
        y: sc.cy + 4 * sc.u
        name: "zap"
        size: 34 * sc.u
        color: Serp.yellow
        filled: true
        opacity: 0.25 + sc.flash * 0.75
    }

    // ---- clouds ----
    readonly property color cloudTint: sc.wet ? Serp.overlay : sc.day ? Qt.lighter(Serp.subtext1, 1.15) : Serp.surface2
    SerpWeatherCloud {
        // the far one, behind
        visible: sc.heavy || sc.kind === "fog"
        width: 84 * sc.u
        baseX: sc.cx - 70 * sc.u
        y: sc.cy - 46 * sc.u
        tint: sc.cloudTint
        opacity: 0.45
        drift: 10 * sc.u
        period: 11000
        live: sc.live && visible
    }
    SerpWeatherCloud {
        // the big one
        visible: !sc.clear
        width: (sc.partly ? 92 : 112) * sc.u
        baseX: sc.cx - width / 2 + (sc.partly ? 10 * sc.u : 0)
        y: sc.cy - (sc.partly ? 18 : 44) * sc.u
        tint: sc.cloudTint
        opacity: sc.kind === "fog" ? 0.5 : 0.95
        drift: 8 * sc.u
        period: 8000
        live: sc.live && visible
    }
    SerpWeatherCloud {
        // a small one in front
        visible: sc.heavy || sc.partly
        width: 56 * sc.u
        baseX: sc.cx + 6 * sc.u
        y: sc.cy - (sc.partly ? -6 : 14) * sc.u
        tint: Qt.lighter(sc.cloudTint, 1.08)
        opacity: 0.85
        drift: 14 * sc.u
        period: 6500
        live: sc.live && visible
    }
}
