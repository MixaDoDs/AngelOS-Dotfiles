pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// serp skin (after frostpix's pc-kit): a surface of Serpantinum's liquid glass, used in place of a flat
// Rectangle (shaders/serp_liquid_glass.frag, from ilyamiro/serpantinum, GNU AGPL v3: a separate work, THIRD-PARTY.md).
// It refracts the window's SerpBackdrop (the wallpaper in screen space) under its own rect. With
// the glass off (Serp.glassOn: the setting, hell, game mode), no backdrop, or the picture not yet
// loaded, it is the skin's plain island: Serp.ground, the radius, a hair of Serp.line — so it
// can stand everywhere. Children go on top, as in a Rectangle.
//
// Usage in a PanelWindow (one backdrop per window, one SGlass per surface):
//
//     PanelWindow {
//         id: win
//         color: "transparent"
//         SerpBackdrop { id: glassBack; screenName: win.screen.name }   // first child: at the bottom
//         SGlass {
//             backdrop: glassBack
//             x: …; y: …; width: …; height: …
//             radius: Serp.radius
//             hover: hh.hovered ? 1 : 0
//             Behavior on hover { NumberAnimation { duration: Serp.normal; easing.type: Easing.OutCubic } }
//             HoverHandler { id: hh; onPointChanged: parent.cursor = point.position }
//             Row { … }                                               // the content, on the glass
//         }
//     }
//
// Cost: the shader redraws only when its uniforms change (size, place, hover); the backdrop's
// texture only when the picture or the screen does.
Item {
    id: root

    property Item backdrop: null
    property real radius: Serp.radius
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomRightRadius: radius
    property real bottomLeftRadius: radius
    property color tint: Serp.base
    property real tintAmount: Serp.cfg.glassTint
    property real rim: 0.45
    property real frost: 2.7             // blur radius, px (his panel glass: 2.5 × 1.08)
    property real hover: 0               // 0..1: the bulge and the light follow `cursor`
    property point cursor: Qt.point(width / 2, height / 2)
    property real press: 0               // 0..1: a press / pulse (his `energy`)
    property real shadow: 0              // 0..1: a soft drop shadow under the glass (needs 12 px of room)
    // the optics, his defaults
    property real ior: 1.5
    property real dispersion: 0.11
    property real saturation: 1.25
    property real bezel: Math.max(5, Math.min(26, Math.min(width, height) * 0.36))
    property real thickness: bezel * 1.15

    readonly property bool glass: Serp.glassOn && backdrop !== null && backdrop.ready && width > 0 && height > 0 && fx.status !== ShaderEffect.Error
    readonly property real pad: shadow > 0 ? 12 : 0

    // ---- the flat island ----
    Rectangle {
        anchors.fill: parent
        visible: !root.glass
        radius: root.radius
        color: Serp.ground
        border.width: 1
        // opaque: the 92 %-clear line let niri's blur noise through — a grainy, broken-looking rim
        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))
    }

    // ---- the glass ----
    ShaderEffect {
        id: fx
        x: -root.pad
        y: -root.pad
        width: root.width + 2 * root.pad
        height: root.height + 2 * root.pad
        visible: root.glass

        property variant src: root.backdrop ? root.backdrop.texture : null
        property vector2d itemSize: Qt.vector2d(width, height)
        property vector4d radii: Qt.vector4d(root.topLeftRadius, root.topRightRadius, root.bottomRightRadius, root.bottomLeftRadius)
        property color tintColor: root.tint
        property real bezel: root.bezel
        property real thickness: root.thickness
        property real ior: root.ior
        property real dispersion: root.dispersion
        property real frost: root.frost
        property real rim: root.rim
        property real saturation: root.saturation
        property real tintAmount: root.tintAmount
        property vector4d srcRect: root.srcRect
        property vector2d cursor: Qt.vector2d(root.cursor.x + root.pad, root.cursor.y + root.pad)
        property real hover: root.hover
        property real glassPad: root.pad
        property real shadowAmt: root.shadow
        property real energy: root.press

        fragmentShader: Qt.resolvedUrl("shaders/serp_liquid_glass.frag.qsb")
    }

    // ---- where it stands in the backdrop (0..1 of the screen) ----
    property vector4d srcRect: Qt.vector4d(0, 0, 1, 1)
    function refresh() {
        if (!root.glass)
            return;
        const f = root.backdrop.screenSpace;
        if (!f || f.width <= 0 || f.height <= 0)
            return;
        const a = root.mapToItem(f, -root.pad, -root.pad);
        const b = root.mapToItem(f, root.width + root.pad, root.height + root.pad);
        const r = Qt.vector4d(a.x / f.width, a.y / f.height, (b.x - a.x) / f.width, (b.y - a.y) / f.height);
        const o = root.srcRect;
        if (r.x !== o.x || r.y !== o.y || r.z !== o.z || r.w !== o.w)
            root.srcRect = r;
    }
    function queue() {
        Qt.callLater(root.refresh);
    }
    // mapToItem isn't a binding: any ancestor that moves (an island growing, a list scrolling)
    // asks again
    property var hooked: []
    function unhook() {
        for (const a of hooked) {
            try {
                a.xChanged.disconnect(root.queue);
                a.yChanged.disconnect(root.queue);
            } catch (e) {}
        }
        hooked = [];
    }
    function hook() {
        unhook();
        const list = [];
        let a = root.parent;
        for (let n = 0; a && n < 32; n++) {
            a.xChanged.connect(root.queue);
            a.yChanged.connect(root.queue);
            list.push(a);
            a = a.parent;
        }
        hooked = list;
        queue();
    }
    Connections {
        target: root.backdrop
        function onOriginChanged() {
            root.queue();
        }
        function onScreenWChanged() {
            root.queue();
        }
        function onScreenHChanged() {
            root.queue();
        }
    }
    onXChanged: queue()
    onYChanged: queue()
    onWidthChanged: queue()
    onHeightChanged: queue()
    onPadChanged: queue()
    onGlassChanged: if (glass)
        hook()
    else
        unhook()
    onParentChanged: if (glass)
        hook()
    Component.onCompleted: if (glass)
        hook()
    Component.onDestruction: unhook()
}
