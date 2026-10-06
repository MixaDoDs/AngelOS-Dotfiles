import QtQuick

// The angel's skin from heaven's prayers (services/HeavenStars.skins) as a layer effect:
// `layer.effect: AngelSkinFx { skin: HeavenStars.worn }` on her SpriteRig.
ShaderEffect {
    property var skin: null
    readonly property var p: skin ? skin.pink : [0, 1, 1, 0]
    readonly property var h: skin ? skin.hair : [0, 1, 1, 0]
    readonly property var w: skin ? skin.white : [0, -1, 0, 0]
    property vector4d pink: Qt.vector4d(p[0], p[1], p[2], p[3])
    property vector4d hair: Qt.vector4d(h[0], h[1], h[2], h[3])
    property vector4d white: Qt.vector4d(w[0], w[1], w[2], w[3])
    fragmentShader: Qt.resolvedUrl("../../shaders/angel_skin.frag.qsb")
}
