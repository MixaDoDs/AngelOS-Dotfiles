import QtQuick
import QtQuick.Effects
import qs.config
import qs.services

// A desktop widget as macOS Golden Gate draws one (DesktopWidgets.widgetStyle "mac"): a rounded
// card of Liquid Glass — the wallpaper under it blurred (the face lives on the wallpaper's own
// surface, so the shell blurs it itself: `backdrop`), a tint of the theme's surface over it, a dark
// outer edge, a bright rim fading down from the top and a soft shadow. No blur (Settings → blur
// off, or a copy away from the wallpaper): a nearly opaque matte tint instead.
// No title bar: in edit mode the whole card is the handle (`dragArea`, over the content) and
// a "−" at the top-left corner removes it; otherwise the handle lies under the content, so
// buttons in it still work and a double click on a bare spot still reaches the host.
Item {
    id: root

    property real radius: DesktopWidgets.macRadius
    property int padding: DesktopWidgets.macPad
    property bool editing: false
    property bool closable: editing
    property bool shadow: Config.appearance.shadows
    // false: an input copy over its face, which already draws the glass — only the content
    property bool glassBody: true
    // the wallpaper to blur, the card's top-left in its coordinates and the card's scale there
    property Item backdrop: null
    property point backdropOrigin: Qt.point(0, 0)
    property real backdropScale: 1
    readonly property bool blurred: !!backdrop && Config.appearance.blur
    property alias dragArea: dragArea
    property alias bodyItem: body
    signal closeClicked

    // blur reach: the wallpaper is taken this far around the card, so the blur has
    // something to pull in at the edges instead of fading out
    readonly property int reach: 40

    RectangularShadow {
        visible: root.glassBody && root.shadow
        anchors.fill: parent
        offset.y: DesktopWidgets.mpx(6)
        radius: root.radius
        blur: DesktopWidgets.mpx(26)
        spread: -DesktopWidgets.mpx(2)
        color: DesktopWidgets.macShadow
        cached: true
    }

    // ---- the glass ----
    Item {
        id: glass
        anchors.fill: parent
        visible: root.glassBody

        ShaderEffectSource {
            id: wallTex
            visible: false
            sourceItem: root.blurred ? root.backdrop : null
            live: true
            smooth: true
            readonly property real s: root.backdropScale
            sourceRect: Qt.rect(root.backdropOrigin.x - root.reach * s, root.backdropOrigin.y - root.reach * s, (root.width + root.reach * 2) * s, (root.height + root.reach * 2) * s)
        }
        MultiEffect {
            visible: root.blurred
            x: -root.reach
            y: -root.reach
            width: root.width + root.reach * 2
            height: root.height + root.reach * 2
            source: wallTex
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 48
            blurMultiplier: 0.4
            saturation: 0.35
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
        Item {
            id: mask
            visible: false
            layer.enabled: true
            x: -root.reach
            y: -root.reach
            width: root.width + root.reach * 2
            height: root.height + root.reach * 2
            Rectangle {
                x: root.reach
                y: root.reach
                width: root.width
                height: root.height
                radius: root.radius
                antialiasing: true
            }
        }

        // the tint, its dark outer edge
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: root.blurred ? DesktopWidgets.macFill : Qt.alpha(DesktopWidgets.macFill, 0.94)
            border.width: 1
            border.color: DesktopWidgets.macEdge
            antialiasing: true
        }
        // the light caught on top: a sheen fading down and the bright rim inside the edge
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, root.radius - 1)
            antialiasing: true
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(1, 1, 1, Theme.dark ? 0.07 : 0.22)
                }
                GradientStop {
                    position: 0.45
                    color: Qt.rgba(1, 1, 1, 0)
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, root.radius - 1)
            color: "transparent"
            border.width: 1
            border.color: DesktopWidgets.macRim
            antialiasing: true
            opacity: 0.8
        }
    }

    // ---- the handle: under the content, or over it in edit mode ----
    MouseArea {
        id: dragArea
        anchors.fill: parent
        z: root.editing ? 2 : -1
        acceptedButtons: Qt.LeftButton
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: root.padding
    }

    // ---- edit mode: "−" at the top-left corner ----
    Item {
        visible: root.closable
        z: 3
        x: -width / 3
        y: -height / 3
        width: DesktopWidgets.mpx(22)
        height: width
        RectangularShadow {
            anchors.fill: parent
            radius: width / 2
            blur: DesktopWidgets.mpx(6)
            offset.y: 1
            color: Qt.rgba(0, 0, 0, 0.3)
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            antialiasing: true
            color: closeMouse.pressed ? Theme.mix(DesktopWidgets.macFill, Theme.text, 0.3) : closeMouse.containsMouse ? Theme.mix(Theme.face, Theme.text, 0.14) : Theme.mix(Theme.face, Theme.text, 0.06)
            border.width: 1
            border.color: DesktopWidgets.macEdge
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.42
            height: Math.max(2, Math.round(parent.width / 11))
            radius: height / 2
            color: DesktopWidgets.macLabel
        }
        MouseArea {
            id: closeMouse
            anchors.fill: parent
            anchors.margins: -2
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeClicked()
        }
    }
}
