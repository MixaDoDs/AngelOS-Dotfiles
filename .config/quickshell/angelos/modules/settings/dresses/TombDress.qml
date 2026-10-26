pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.dresses

// Settings in the circle of heresy: the lid of a burning tomb, slid aside. Dark stone, cracked,
// the view cut into the sandstone of the lid under an epitaph; the fire inside licks up along
// its upper edge.
HellDress {
    id: dress

    paper: "#d6c29a"
    ink: "#2a1b12"
    redInk: "#8a2c10"
    title: I18n.t("Здесь покоятся настройки", "Here lie the Settings")
    titleColor: "#e8c890"
    closer: "#4a3a30"
    closerInk: "#e8c890"
    headHeight: Theme.u * 24
    pageX: Theme.u * 12
    pageRight: Theme.u * 12
    pageTop: headHeight + Theme.u * 2
    pageBottom: Theme.u * 12

    // the tomb
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: Theme.u * 8
        color: "#3b302a"
        border.width: Math.max(2, Theme.u)
        border.color: "#1c1612"
    }
    // the fire inside, along the upper edge
    Row {
        x: Theme.u * 4
        y: 0
        Repeater {
            model: Math.max(0, Math.ceil((dress.width - Theme.u * 8) / (Theme.u * 6)))
            PxIcon {
                required property int index
                bitmap: index % 3 === 0 ? ["..r...", ".rrr..", ".ryr..", "rryyr.", "ryyyr.", "ryyyr."] : index % 3 === 1 ? ["......", "...r..", "..rr..", ".ryr..", "rryyr.", "ryyyr."] : ["......", "......", ".r....", ".rr...", "ryyr..", "ryyyr."]
                pixel: Math.max(1, Theme.u)
                bad: "#b4431a"
                fill3: "#e8a040"
                opacity: 0.85
            }
        }
    }
    // cracks in the stone
    Repeater {
        model: 3
        PxIcon {
            required property int index
            bitmap: ["#.....", ".#....", ".##...", "...#..", "...#..", "....##"]
            pixel: Math.max(1, Theme.u)
            ink: "#15100c"
            mirror: index === 1
            x: [Theme.u * 3, dress.width - width - Theme.u * 3, Theme.u * 3][index]
            y: [dress.height * 0.3, dress.height * 0.55, dress.height - height - Theme.u * 3][index]
        }
    }
}
