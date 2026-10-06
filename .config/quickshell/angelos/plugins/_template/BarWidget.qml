import QtQuick
import qs.config
import qs.services
import qs.widgets

// The panel button — both looks (docs/PLUGINS.md → «Theme API»):
//   pixel  a PxButton next to the tray
//   mac    a menu bar extra in Golden Gate's menu bar: a monochrome line icon (MacIcon) and short
//          text in the bar's ink (Skin.ink: black or white by the wallpaper), no frame
Item {
    id: root

    property var plugin
    property string screenName
    property var barWindow
    // the pixel bar's hooks: its padding and the hell bar's ink go to the button
    property int hpad: -1
    property bool barInk: false
    readonly property string icon: btn.icon
    readonly property string text: btn.text

    readonly property int clicks: plugin ? plugin.get("clicks", 0) : 0
    readonly property string label: plugin ? plugin.get("label", "♡") : "♡"   // Settings.qml
    function click() {
        if (plugin)
            plugin.set("clicks", clicks + 1);
    }

    implicitWidth: Skin.mac ? macRow.implicitWidth + Skin.px(4) : btn.implicitWidth
    implicitHeight: Skin.mac ? Skin.px(18) : btn.implicitHeight

    PxButton {
        id: btn
        visible: !Skin.mac
        anchors.fill: parent
        compact: true
        hpad: root.hpad
        barInk: root.barInk
        icon: "heart"
        text: root.label
        onClicked: root.click()
    }
    Row {
        id: macRow
        visible: Skin.mac
        anchors.centerIn: parent
        spacing: Skin.px(4)
        MacIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "heart"
            size: Skin.px(15)
            stroke: 2
            color: Skin.ink(root.screenName)
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Skin.ink(root.screenName)
        }
    }
    MouseArea {
        visible: Skin.mac
        anchors.fill: parent
        onClicked: root.click()
    }
}
