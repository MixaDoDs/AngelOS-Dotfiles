import QtQuick
import qs.config
import "A11y.js" as A11y

// Multiline editor with the same palette and selection as PxField.
Item {
    id: root
    property alias text: editor.text
    property alias readOnly: editor.readOnly
    property alias input: editor
    property string placeholder: ""
    property bool monospace: false
    signal edited
    implicitHeight: Theme.u * 65
    implicitWidth: Theme.u * 180

    PxBox {
        anchors.fill: parent
        sunken: true
        color: Theme.sunken
        edgeColor: editor.activeFocus ? Theme.accent : Theme.edge
    }
    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: Theme.u * 5
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, editor.contentHeight)
        boundsBehavior: Flickable.StopAtBounds
        TextEdit {
            id: editor
            Accessible.name: A11y.name(A11y.rowLabel(root), null, root.placeholder)
            width: flick.width
            height: Math.max(flick.height, contentHeight)
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            selectByMouse: true
            color: Theme.text
            selectionColor: Theme.select
            selectedTextColor: Theme.selectText
            font.family: root.monospace ? Theme.fontMono : Theme.fontBody
            font.pixelSize: root.monospace ? Theme.sizeMonoSmall : Theme.sizeBody
            renderType: Text.NativeRendering
            onTextChanged: root.edited()
            onCursorRectangleChanged: {
                if (cursorRectangle.y < flick.contentY)
                    flick.contentY = cursorRectangle.y;
                else if (cursorRectangle.y + cursorRectangle.height > flick.contentY + flick.height)
                    flick.contentY = cursorRectangle.y + cursorRectangle.height - flick.height;
            }
        }
        PxText {
            visible: editor.text === ""
            width: parent.width
            text: root.placeholder
            dim: true
            wrapMode: Text.Wrap
        }
    }
}
