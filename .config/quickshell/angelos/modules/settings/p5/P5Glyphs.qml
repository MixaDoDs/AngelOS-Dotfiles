import QtQuick
import qs.config

// Text of the P5 window that leans: set in art pixels in the title font at a whole multiple of
// its cell (`big`), turned by `tilt` as a picture without smoothing, scaled up unsmoothed — the
// letters stay pixel letters when turned.
Item {
    id: root

    property string text: ""
    property color color: "white"
    property color outline: "transparent"
    property int big: 1
    property real tilt: 0
    property string family: Theme.fontTitle
    property bool bold: true
    readonly property int cell: Theme.fontNative[family] || 9
    readonly property real pad: Theme.u * 6
    implicitWidth: label.implicitWidth * Theme.u
    implicitHeight: label.implicitHeight * Theme.u

    Item {
        id: canvas
        x: -root.pad
        y: -root.pad
        width: root.implicitWidth + root.pad * 2
        height: root.implicitHeight + root.pad * 2
        layer.enabled: true
        layer.smooth: false
        layer.textureSize: Qt.size(Math.max(1, Math.round(width / Theme.u)), Math.max(1, Math.round(height / Theme.u)))
        Item {
            width: canvas.width / Theme.u
            height: canvas.height / Theme.u
            scale: Theme.u
            transformOrigin: Item.TopLeft
            Item {
                id: box
                x: root.pad / Theme.u
                y: root.pad / Theme.u
                width: label.implicitWidth
                height: label.implicitHeight
                rotation: root.tilt
                layer.enabled: root.tilt !== 0
                layer.smooth: false
                // the outline, an art pixel wider than Text.Outline's: the words read over the art
                Repeater {
                    model: root.outline.a > 0 ? [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, 1], [-1, 1], [1, -1]] : []
                    Text {
                        required property var modelData
                        x: modelData[0]
                        y: modelData[1]
                        text: root.text
                        color: root.outline
                        font: label.font
                        renderType: Text.NativeRendering
                        style: Text.Outline
                        styleColor: root.outline
                    }
                }
                Text {
                    id: label
                    text: root.text
                    color: root.color
                    font.family: root.family
                    font.pixelSize: root.cell * root.big
                    font.bold: root.bold
                    font.hintingPreference: Font.PreferFullHinting
                    renderType: Text.NativeRendering
                    style: root.outline.a > 0 ? Text.Outline : Text.Normal
                    styleColor: root.outline
                }
            }
        }
    }
}
