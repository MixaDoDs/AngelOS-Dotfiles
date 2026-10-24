import QtQuick
import qs.config
import qs.services
import "A11y.js" as A11y

// Multiline editor with the same palette and selection as PxField. Misspelt words are
// underlined (PxSpell, services/Spell); with the caret in one, a strip along the bottom
// offers what it could have been and «в словарь».
Item {
    id: root
    // inside the P5 settings window: its colours (Theme.tone)
    readonly property bool p5: Theme.p5For(root.parent)
    property alias text: editor.text
    property alias readOnly: editor.readOnly
    property alias input: editor
    property string placeholder: ""
    property bool monospace: false
    property bool spell: !monospace         // check the spelling: prose, not code
    property bool spellWanted: false        // …from the first time the caret is in it
    // a key the owner handles before the text does: keyFilter(event) → true = taken
    property var keyFilter: null
    readonly property var spelling: spellLoader.item
    signal edited
    implicitHeight: Theme.u * 65
    implicitWidth: Theme.u * 180

    PxBox {
        anchors.fill: parent
        sunken: true
        color: Theme.tone("sunken", root.p5)
        edgeColor: editor.activeFocus ? Theme.accent : Theme.tone("edge", root.p5)
    }
    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: Theme.u * 5
        anchors.bottomMargin: Theme.u * 5 + (fixes.visible ? fixes.height + Theme.u * 2 : 0)
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
            color: Theme.tone("text", root.p5)
            selectionColor: Theme.select
            selectedTextColor: Theme.selectText
            font.family: root.monospace ? Theme.fontMono : Theme.fontBody
            font.pixelSize: root.monospace ? Theme.sizeMonoSmall : Theme.sizeBody
            renderType: Text.NativeRendering
            Keys.onPressed: e => {
                if (root.keyFilter && root.keyFilter(e))
                    e.accepted = true;
            }
            onTextChanged: root.edited()
            onCursorRectangleChanged: {
                if (cursorRectangle.y < flick.contentY)
                    flick.contentY = cursorRectangle.y;
                else if (cursorRectangle.y + cursorRectangle.height > flick.contentY + flick.height)
                    flick.contentY = cursorRectangle.y + cursorRectangle.height - flick.height;
            }
            onActiveFocusChanged: if (activeFocus)
                root.spellWanted = true
            Loader {
                id: spellLoader
                anchors.fill: parent
                active: root.spell && root.spellWanted && Spell.on
                sourceComponent: PxSpell {
                    target: editor
                }
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
    // the caret is in a misspelt word: what it could have been (a click puts it in), or keep it
    Row {
        id: fixes
        visible: !!root.spelling && root.spelling.live && !!root.spelling.current && editor.activeFocus && Config.spell.suggest !== false
        x: Theme.u * 5
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.u * 4
        width: parent.width - Theme.u * 10
        height: Theme.u * 12
        spacing: Theme.u * 2
        clip: true
        Repeater {
            model: fixes.visible ? root.spelling.suggestions.slice(0, 4) : []
            PxButton {
                required property string modelData
                compact: true
                text: modelData
                onClicked: root.spelling.replace(modelData)
            }
        }
        PxButton {
            compact: true
            flat: true
            icon: "plus"
            text: I18n.t("в словарь", "to my words")
            onClicked: root.spelling.learn()
        }
    }
}
