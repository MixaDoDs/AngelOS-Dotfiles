import QtQuick
import qs.services

// Text of the Golden Gate skin: Inter (or Config.mac.font) at the HIG's 13 pt body by default,
// with Apple's tracking for small sizes (−0.08 pt at 13 pt).
Text {
    property bool bold: false
    property bool semibold: false
    property real size: GoldenGate.textSize
    color: GoldenGate.label
    font.family: GoldenGate.font
    font.pixelSize: Math.round(size)
    font.weight: bold ? Font.Bold : semibold ? Font.DemiBold : Font.Normal
    font.letterSpacing: size >= 13 ? -0.08 * size / 13 : 0
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    maximumLineCount: 1
    textFormat: Text.PlainText
}
