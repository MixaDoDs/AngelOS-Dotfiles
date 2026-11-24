import QtQuick
import QtQuick.Effects

// serp-skin: a picture cropped into a rounded rect (the lock's avatar, the now-playing cover)
Item {
    id: ri
    property url source
    property real radius: width / 2
    property int sourceWidth: 256
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
        smooth: true
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
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
}
