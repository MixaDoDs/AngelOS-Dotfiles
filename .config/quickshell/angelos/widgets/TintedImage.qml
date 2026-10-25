import QtQuick
import qs.config

// Image that can be recolored to the theme (mode: off | mono | accent).
Item {
    id: root

    property url source
    // shown when the source fails: a tray app's picture (image://qsimage/<handle>) asked for after
    // the app replaced it is gone (Quickshell: «unknown handle»), and the cell stood empty
    property url fallback
    property bool failed: false
    onSourceChanged: failed = false
    property string mode: "off"
    property int size: Theme.u * 8

    implicitWidth: size
    implicitHeight: size

    Image {
        id: img
        anchors.fill: parent
        source: root.failed && root.fallback.toString() !== "" ? root.fallback : root.source
        onStatusChanged: if (status === Image.Error && !root.failed)
            root.failed = true
        sourceSize: Qt.size(root.size, root.size)
        smooth: false
        asynchronous: true
        visible: root.mode === "off"
    }
    ShaderEffect {
        anchors.fill: parent
        visible: root.mode !== "off" && img.status === Image.Ready
        property var source: img
        property color dark: root.mode === "mono" ? (Theme.dark ? Theme.textDim : Theme.edge) : Theme.mix(Theme.accent, Theme.dark ? Theme.face : Theme.edge, 0.35)
        property color light: root.mode === "mono" ? Theme.text : Theme.mix(Theme.accent, "#ffffff", Theme.dark ? 0.55 : 0.2)
        property real levels: 4
        fragmentShader: Qt.resolvedUrl("../shaders/tint.frag.qsb")
    }
}
