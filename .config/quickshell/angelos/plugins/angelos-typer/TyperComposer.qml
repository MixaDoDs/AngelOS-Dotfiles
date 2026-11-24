import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import "."

Column {
    id: root
    property string screenName
    signal pinned
    signal openEditor
    spacing: Skin.px(8)
    function focusInput() { editor.input.forceActiveFocus(); }
    function attach() { if (TyperNotes.pin(editor.text, screenName)) root.pinned(); }
    function restore() { if (TyperNotes.restore()) root.pinned(); }
    PxText { width: parent.width; text: "Запиши мысль и оставь её под рукой."; kind: "small"; color: Skin.textDim; wrapMode: Text.Wrap }
    PxTextArea {
        id: editor
        width: parent.width
        height: Skin.px(145)
        text: TyperNotes.draft
        placeholder: "Не забыть…"
        spell: false
        onEdited: TyperNotes.setDraft(text)
        keyFilter: function(event) {
            if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                root.attach(); return true;
            }
            return false;
        }
    }
    PxText { visible: TyperNotes.error !== ""; width: parent.width; text: TyperNotes.error; color: Skin.danger; kind: "small"; wrapMode: Text.Wrap }
    Row {
        spacing: Skin.px(8)
        PxButton { text: "Прикрепить"; icon: "note"; accent: true; enabled: editor.text.trim().length > 0 && editor.text.trim().length <= 8000; onClicked: root.attach() }
        PxButton { text: "Открыть Typer"; onClicked: root.openEditor() }
    }
    PxButton { visible: TyperNotes.archive.length > 0; text: "Вернуть"; enabled: TyperNotes.fading.length === 0; onClicked: root.restore() }
    PxText { width: parent.width; text: "Ctrl+Enter — прикрепить"; kind: "small"; color: Skin.textDim; wrapMode: Text.Wrap }
}
