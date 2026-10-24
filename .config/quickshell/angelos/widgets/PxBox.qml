import QtQuick
import qs.config

// Win98-style bevelled box. raised by default, `sunken` for inputs/pressed.
// By day (Theme.zine) it is flat: the outline alone, no bevels.
// `hell: Theme.hell` gives it hell's obsidian bevels (Theme.realm).
Item {
    id: root

    property bool hell: false
    readonly property string settingsSkin: hell ? "classic" : Theme.settingsSkinFor(root.parent)
    // the P5 settings window: a flat paper plate with a black outline
    readonly property bool p5: settingsSkin === "p5"
    property color color: hell ? Theme.hellFace : p5 ? Theme.p5Paper2 : Theme.face
    property int bevel: settingsSkin === "windose" ? Math.max(1, Math.floor(Theme.u / 2)) : Theme.u
    property bool sunken: false
    property bool outline: true
    property bool flat: settingsSkin === "windose" || p5 || (Theme.zine && !hell)
    property bool shadow: false
    property int shadowSize: Theme.u * 2
    property color shadowColor: Qt.alpha(Theme.shadow, Theme.shadowAlpha)
    property color hiColor: hell ? Theme.hellHi : settingsSkin === "windose" ? Theme.windoseLine : Theme.hi
    property color loColor: hell ? Theme.hellLo : settingsSkin === "windose" ? Theme.windoseLine : Theme.lo
    property color edgeColor: hell ? Theme.hellEdge : settingsSkin === "windose" ? Theme.windoseLine : p5 ? Theme.p5Black : Theme.edge
    readonly property int ob: outline ? bevel : 0
    readonly property int inset: ob + (flat ? 0 : bevel)
    default property alias content: inner.data

    // hard pixel shadow (right + bottom strips so translucent boxes stay clean)
    Rectangle {
        visible: root.shadow
        x: root.width
        y: root.shadowSize
        width: root.shadowSize
        height: root.height
        color: root.shadowColor
    }
    Rectangle {
        visible: root.shadow
        x: root.shadowSize
        y: root.height
        width: root.width
        height: root.shadowSize
        color: root.shadowColor
    }

    Rectangle {
        anchors.fill: parent
        color: root.color
        border.width: root.ob
        border.color: root.edgeColor
    }
    Rectangle {
        visible: !root.flat
        x: root.ob
        y: root.ob
        width: root.width - 2 * root.ob
        height: root.bevel
        color: root.sunken ? root.loColor : root.hiColor
    }
    Rectangle {
        visible: !root.flat
        x: root.ob
        y: root.ob
        width: root.bevel
        height: root.height - 2 * root.ob
        color: root.sunken ? root.loColor : root.hiColor
    }
    Rectangle {
        visible: !root.flat
        x: root.ob + root.bevel
        y: root.height - root.ob - root.bevel
        width: root.width - 2 * root.ob - root.bevel
        height: root.bevel
        color: root.sunken ? root.hiColor : root.loColor
    }
    Rectangle {
        visible: !root.flat
        x: root.width - root.ob - root.bevel
        y: root.ob + root.bevel
        width: root.bevel
        height: root.height - 2 * root.ob - root.bevel
        color: root.sunken ? root.hiColor : root.loColor
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: root.inset
    }
}
