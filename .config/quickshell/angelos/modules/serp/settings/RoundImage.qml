import QtQuick
import QtQuick.Effects

// serp-skin settings: an image cropped into a rounded rect, optionally blurred and darkened
Item {
    id: ri
    property url source
    property real radius: 0
    property real blur: 0             // 0..1
    property real brightness: 0       // -1..1
    property int sourceWidth: 480
    readonly property bool ready: img.status === Image.Ready
    Image {
        id: img
        anchors.fill: parent
        visible: false
        source: ri.source
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: ri.sourceWidth
        asynchronous: true
        cache: true
    }
    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            radius: ri.radius
            antialiasing: true
        }
    }
    MultiEffect {
        anchors.fill: parent
        visible: ri.ready
        source: img
        autoPaddingEnabled: false
        blurEnabled: ri.blur > 0
        blur: ri.blur
        blurMax: 32
        brightness: ri.brightness
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
}
