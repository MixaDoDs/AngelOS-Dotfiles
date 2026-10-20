import QtQuick
import qs.config

// The word of the verdict transition (shaders/pixel_transition.frag, style 11), drawn once in
// the pixel title font at its 9 px design size into a small texture; the shader blows it up
// cell by cell. Hand the shader `texture` as titleTex and `size` as titleSize ("" = no word).
Item {
    id: root

    property string text
    readonly property size size: text !== "" ? Qt.size(src.textureSize.width, src.textureSize.height) : Qt.size(0, 0)
    readonly property alias texture: src

    Text {
        id: label
        text: root.text
        font.family: Theme.fontTitle
        font.bold: true
        font.pixelSize: 9
        color: "white"
        antialiasing: false
    }
    ShaderEffectSource {
        id: src
        sourceItem: label
        hideSource: true
        smooth: false
        textureSize: Qt.size(Math.max(1, Math.ceil(label.implicitWidth)), Math.max(1, Math.ceil(label.implicitHeight)))
        visible: false
    }
}
