import QtQuick
import qs.services

// serp-skin: text in the skin's font (Serp.font, mono by default), Serpantinum's weights
Text {
    property real size: Serp.textSize
    property bool bold: false
    property bool black: false
    property bool dim: false
    font.family: Serp.font
    font.pixelSize: Math.round(size)
    font.weight: black ? Font.Black : bold ? Font.Bold : Font.Medium
    color: dim ? Serp.subtext : Serp.text
    renderType: Text.NativeRendering
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
