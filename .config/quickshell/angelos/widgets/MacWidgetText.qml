import QtQuick
import qs.services

// Text in a macOS desktop widget (DesktopWidgets.macLook): SF Pro if installed (Display from
// 20 pt), else the skin's font; `size` in points at the font scale, figures tabular so ticking
// numbers stand still. role: label | secondary | tertiary picks the colour.
Text {
    property real size: 13
    property string role: "label"
    property int weight: Font.Normal
    readonly property int px: DesktopWidgets.mpx(size)
    color: role === "secondary" ? DesktopWidgets.macSecondary : role === "tertiary" ? DesktopWidgets.macTertiary : DesktopWidgets.macLabel
    font.family: DesktopWidgets.macFamily(px)
    font.pixelSize: px
    font.weight: weight
    // Apple's tracking: tighter as the type grows
    font.letterSpacing: px >= 20 ? -0.02 * px : px >= 13 ? -0.08 * px / 13 : 0
    font.features: ({
            "tnum": 1
        })
    font.hintingPreference: Font.PreferVerticalHinting
    renderType: Text.QtRendering
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    textFormat: Text.PlainText
}
