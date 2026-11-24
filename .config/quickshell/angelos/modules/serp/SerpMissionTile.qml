import QtQuick
import qs.services

// serp-skin: a desk in Mission Control's strip in the skin's look (hunks/mission.py lays it over
// the pixel PxBox, which then draws nothing): a rounded plate of the skin, the accent's ring on the
// current desk, the accent's tint while a window is dragged over it (or the pointer, on "+"), a
// plus in the middle of an empty / clean / new desk.
Rectangle {
    id: tile

    property bool hot: false
    property bool current: false
    property bool plus: false

    radius: Serp.radiusSmall
    color: hot ? Qt.alpha(Serp.accent, 0.35) : Qt.alpha(Serp.surface0, 0.85)
    border.width: current ? Serp.px(2) : 1
    border.color: current || hot ? Serp.accent : Serp.line
    Behavior on color {
        ColorAnimation {
            duration: Serp.quick
        }
    }

    SIcon {
        visible: tile.plus
        anchors.centerIn: parent
        name: "plus"
        size: Serp.px(20)
        color: tile.hot ? Serp.accent : Serp.subtext1
    }
}
