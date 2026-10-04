import QtQuick
import qs.services
import "MacIcons.js" as MacIcons

// A line icon of the Golden Gate skin (widgets/MacIcons.js: Lucide, ISC; the emblem is ours),
// drawn as SVG at its size in any colour. SVG Tiny knows no alpha in colours: it goes to opacity.
Image {
    id: root

    property string name: "circle-help"
    property color color: GoldenGate.label
    property real size: GoldenGate.iconSize
    property real stroke: 1.75
    property bool filled: false

    readonly property string rgb: "#" + [color.r, color.g, color.b].map(c => ("0" + Math.round(c * 255).toString(16)).slice(-2)).join("")
    width: size
    height: size
    sourceSize.width: Math.ceil(size)
    sourceSize.height: Math.ceil(size)
    opacity: color.a
    smooth: true
    mipmap: false
    asynchronous: false
    source: MacIcons.url(name, rgb, stroke, filled ? rgb : "")
}
