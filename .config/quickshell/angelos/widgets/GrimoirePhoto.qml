import QtQuick
import qs.config

// For a picture's layer.effect while it sits in the grimoire or a circle's dress
// (shaders/grimoire_photo.frag): it comes out as an engraving the right way round instead of
// a negative. Use with
//   layer.enabled: Theme.inkWindows.length > 0 && Theme.inkWindows.includes(Window.window)
//   layer.effect: GrimoirePhoto {}
ShaderEffect {
    fragmentShader: Qt.resolvedUrl("../shaders/grimoire_photo.frag.qsb")
    property real invert: Theme.dark ? 1 : 0
}
