import QtQuick

// The desktop's wallpaper for a look (walls/, kept in step by angelOS), alive through
// sddm_wall.frag: cover-cropped, drifting, `block` px pixels (1 = the picture as it is),
// scanlines every `line` px (0 = none), the `tint` laid over it, a ring from ring().
// No picture: the `fallback` gradient.
Item {
    id: root

    required property var g                  // the look's Greeter
    property real block: g.u * 8
    property real line: g.u
    property color tint: "#ffffff"
    property real tintAmount: 0
    property color fallbackTop: Qt.darker(g.pal.title1, 1.6)
    property color fallbackBottom: Qt.darker(g.pal.title2, 1.8)
    readonly property bool ready: wall.status === Image.Ready

    property int wallTry: 0
    Image {
        id: wall
        anchors.fill: parent
        source: root.wallTry < root.g.wallCandidates.length ? Qt.resolvedUrl(root.g.wallCandidates[root.wallTry]) : ""
        asynchronous: true
        cache: false
        visible: false
        onStatusChanged: if (status === Image.Error)
            root.wallTry++
    }
    ShaderEffect {
        id: fx
        anchors.fill: parent
        visible: root.ready
        property var source: wall
        property real block: root.block
        property real line: root.line
        property real time: root.g.secs
        property size resolution: Qt.size(width, height)
        property size imgSize: Qt.size(Math.max(1, wall.implicitWidth), Math.max(1, wall.implicitHeight))
        property vector4d tint: Qt.vector4d(root.tint.r, root.tint.g, root.tint.b, root.tintAmount)
        property vector4d ripple: Qt.vector4d(rippleAt.x, rippleAt.y, rippleAge, rippleAge < 1.4 ? rippleStrength : 0)
        property vector4d rippleColor: Qt.vector4d(rippleTint.r, rippleTint.g, rippleTint.b, 1)
        property point rippleAt: Qt.point(width / 2, height / 2)
        property real rippleAge: 9
        property real rippleStrength: 0.6
        property color rippleTint: root.g.pal.accent
        fragmentShader: Qt.resolvedUrl("sddm_wall.frag.qsb")
        NumberAnimation {
            id: ringAnim
            target: fx
            property: "rippleAge"
            from: 0
            to: 1.5
            duration: 1500
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: !root.ready
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.fallbackTop
            }
            GradientStop {
                position: 1
                color: root.fallbackBottom
            }
        }
    }
    // a ring of pixels from `item`'s middle (a key typed, a mistake)
    function ring(item, color, strength) {
        if (item) {
            const p = item.mapToItem(fx, item.width / 2, item.height / 2);
            fx.rippleAt = Qt.point(p.x, p.y);
        }
        fx.rippleTint = color;
        fx.rippleStrength = strength;
        ringAnim.restart();
    }
}
