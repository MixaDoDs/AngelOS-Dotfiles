import QtQuick
import qs.services
import qs.modules.serp

// serp-skin settings: Serpantinum's Input — a soft field with a glyph, a placeholder and a clear x
Rectangle {
    id: inp
    property alias text: field.text
    property alias field: field
    property string placeholder: "Поиск"
    property string icon: "search"
    signal accepted
    signal escaped
    signal up
    signal down
    implicitWidth: Serp.px(220)
    implicitHeight: Serp.px(32)
    radius: Serp.radiusSmall
    color: Qt.alpha(Serp.surface1, 0.7)
    border.width: 1
    border.color: field.activeFocus ? Qt.alpha(Serp.accent, 0.6) : Serp.line
    Behavior on border.color {
        ColorAnimation {
            duration: Serp.quick
        }
    }
    function focusField() {
        field.forceActiveFocus();
        field.cursorPosition = field.text.length;
    }
    SIcon {
        id: glyph
        x: Serp.px(10)
        anchors.verticalCenter: parent.verticalCenter
        name: inp.icon
        size: Serp.px(14)
        color: field.activeFocus ? Serp.accent : Serp.subtext0
    }
    TextInput {
        id: field
        anchors.left: glyph.right
        anchors.leftMargin: Serp.px(8)
        anchors.right: clear.left
        anchors.rightMargin: Serp.px(4)
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: Serp.text
        selectionColor: Qt.alpha(Serp.accent, 0.4)
        selectedTextColor: Serp.text
        font.family: Serp.font
        font.pixelSize: Serp.px(12)
        selectByMouse: true
        Keys.onReturnPressed: inp.accepted()
        Keys.onEnterPressed: inp.accepted()
        Keys.onEscapePressed: inp.escaped()
        Keys.onUpPressed: inp.up()
        Keys.onDownPressed: inp.down()
        SText {
            anchors.fill: parent
            visible: !field.text
            text: inp.placeholder
            size: Serp.px(12)
            color: Serp.subtext0
        }
    }
    SButton {
        id: clear
        anchors.right: parent.right
        anchors.rightMargin: Serp.px(4)
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Serp.px(24)
        implicitHeight: Serp.px(24)
        visible: field.text !== ""
        onClicked: field.text = ""
        SIcon {
            name: "x"
            size: Serp.px(12)
            color: Serp.subtext0
        }
    }
}
