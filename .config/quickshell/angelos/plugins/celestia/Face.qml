import QtQuick
import qs.config
import qs.services
import "."

// One face: the shader, and the colours and grid of the look it stands in.
//   look: desktop | bar
Item {
    id: root
    property var plugin
    property string screenName
    property string look: "desktop"
    property bool mono: false
    property color monoColor: Skin.text

    // counted among those who can see her only while it is true
    // the bar stays in sight under windows; the desktop's face does not
    readonly property bool live: visible && (look === "bar" || !screenName || !Shell.stillScreen(screenName))
    // each face is known by name: a skin switch rebuilds them in any order, a bare counter went
    // below zero and she froze
    readonly property string faceId: Math.random().toString(36).slice(2)
    onLiveChanged: Brain.see(faceId, live)
    Component.onCompleted: Brain.see(faceId, live)
    Component.onDestruction: Brain.see(faceId, false)

    readonly property bool hell: Theme.hell || Brain.forceLook === "hell"
    readonly property bool mac: !hell && (Brain.forceLook === "mac" || (look === "bar" ? Skin.mac : Skin.macWidgets))
    readonly property bool small: look === "bar"

    ShaderEffect {
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("shaders/face.frag.qsb")
        blending: true
        visible: root.visible

        property color ink: root.mono ? root.monoColor : root.hell ? Theme.hellFlame : root.mac ? (Serp.on ? Serp.text : "#f7f4ff") : Theme.accent  // serp-skin
        property color glowC: root.mono ? root.monoColor : root.hell ? Theme.hellEmber : root.mac ? Skin.accent : Theme.accent3
        property color plate: root.small ? Qt.rgba(0, 0, 0, 0) : root.hell ? Theme.hellPlate : root.mac ? (Serp.on ? Qt.alpha(Serp.mantle, 0.75) : Qt.rgba(0.06, 0.05, 0.10, 0.55)) : Qt.darker(Skin.sunken, 1.6)  // serp-skin
        property color cheek: root.hell ? Theme.hellBlood : Serp.on ? Serp.pink : Theme.accent2  // serp-skin

        property vector4d eye: Qt.vector4d(Brain.lookX, Brain.lookY, Brain.open * Brain.blink, Brain.wide)
        property vector4d expr: Qt.vector4d(Brain.happy, Brain.brow, Brain.squint, Brain.blush)
        property vector4d mouth: Qt.vector4d(Brain.mouthOpen, Brain.mouthW, Brain.smile, root.small ? 0 : Brain.music)
        property vector4d fx: Qt.vector4d(Brain.bounce, Brain.beat, Brain.glitch, Brain.think)
        property vector4d fx2: Qt.vector4d(root.hell ? 0 : 1, Brain.sweat, root.hell ? 1 : 0, Brain.sleeping ? 1 : 0)
        // Classic: a matrix of square pixels; hell: heavier; Golden Gate: no matrix at all
        property vector4d cfg: Qt.vector4d(root.mac ? 0 : root.small ? 13 : root.hell ? 27 : 37, root.mac ? 0 : 1, root.mac ? 1 : 0, Brain.clock)
        property vector4d res: Qt.vector4d(width, height, root.small ? 1 : 0, 0)
        // the mood's colour; hell keeps its own fire
        property vector4d tint: root.hell ? Qt.vector4d(0, 0, 0, 0) : Qt.vector4d(Brain.tintR, Brain.tintG, Brain.tintB, Brain.tintA)
    }
}
