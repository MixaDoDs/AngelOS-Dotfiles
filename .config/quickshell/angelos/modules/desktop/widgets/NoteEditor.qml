pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The note's editor (modules/desktop/widgets/NoteWidget, loaded only while it is open): a window
// over everything (layer Top) that owns the keyboard while it is open — the desktop's layer never
// gets the keyboard, so a popup of it could not be typed in. A dimmed screen around the sheet; a
// click there, Esc or Ctrl+Enter close it. Its own file: a window type inside the note would be
// compiled with every note, and offscreen (the UI self-test) there is no window backend.
PanelWindow {
    id: ew

    // the note it edits (NoteWidget sets it as it loads this)
    property Item note: null
    screen: ew.note && ew.note.QsWindow.window ? ew.note.QsWindow.window.screen : null
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "angelos-ew.note-editor"
    // takes input: the editor is modal, a click outside closes it
    WlrLayershell.keyboardFocus: Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive

    // where the sticker is on its screen (the desktop's window covers the whole screen)
    readonly property point at: ew.note ? ew.note.mapToItem(null, 0, 0) : Qt.point(0, 0)
    readonly property int pad: Theme.u * 4
    // the note arrives just after the window is made: its text, the caret at the end
    onNoteChanged: if (note)
        Qt.callLater(() => {
            area.input.forceActiveFocus();
            area.input.cursorPosition = area.text.length;
        })

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.18
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: ew.note.editorState.done()
    }

    PxBox {
        id: sheet
        width: Math.min(Math.max(ew.note ? ew.note.width : 0, Theme.u * 190), ew.width - ew.pad * 2)
        height: Math.min(Theme.u * 140, ew.height - ew.pad * 2)
        x: Math.max(ew.pad, Math.min(ew.at.x, ew.width - width - ew.pad))
        y: ew.at.y + height + ew.pad <= ew.height ? Math.max(ew.pad, ew.at.y) : Math.max(ew.pad, ew.height - height - ew.pad)
        color: (ew.note ? ew.note.paper : Theme.face)
        hell: Theme.hell
        shadow: Config.appearance.shadows
        // a click on the sheet is not one outside
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }
        Column {
            x: Theme.u * 4
            y: Theme.u * 4
            width: parent.width - Theme.u * 8
            spacing: Theme.u * 3
            PxText {
                id: keysHint
                width: parent.width
                elide: Text.ElideRight
                kind: "tiny"
                color: (ew.note ? ew.note.ink : Theme.text)
                opacity: 0.7
                text: I18n.t("Enter после «[ ] » — следующий пункт · Ctrl+Enter или Esc — готово", "Enter after “[ ] ” starts the next box · Ctrl+Enter or Esc: done")
            }
            PxTextArea {
                id: area
                width: parent.width
                height: sheet.height - Theme.u * 8 - keysHint.height - buttons.height - Theme.u * 6
                placeholder: I18n.t("пиши… «[ ] » — пункт с галочкой, «# » — заголовок", "write… “[ ] ” makes a box to tick, “# ” a heading")
                text: ew.note ? ew.note.editorState.draft : ""
                onEdited: {
                    if (ew.note && ew.note.editorState.draft !== text) {
                        ew.note.editorState.draft = text;
                        ew.note.commitSoon();
                    }
                }
                keyFilter: e => {
                    if (e.key === Qt.Key_Escape) {
                        ew.note.editorState.done();
                        return true;
                    }
                    if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                        if (e.modifiers & Qt.ControlModifier) {
                            ew.note.editorState.done();
                            return true;
                        }
                        if (!(e.modifiers & Qt.ShiftModifier))
                            return ew.note.continueList(area);
                    }
                    return false;
                }
                Component.onCompleted: {
                    input.forceActiveFocus();
                    input.cursorPosition = text.length;
                }
            }
            Row {
                id: buttons
                spacing: Theme.u * 2
                PxButton {
                    compact: true
                    hell: Theme.hell
                    text: I18n.t("+ пункт", "+ item")
                    icon: "check"
                    onClicked: {
                        const at = area.input.cursorPosition;
                        const before = area.text.slice(0, at);
                        const add = (before && !before.endsWith("\n") ? "\n" : "") + "[ ] ";
                        area.text = before + add + area.text.slice(at);
                        area.input.cursorPosition = at + add.length;
                        area.input.forceActiveFocus();
                    }
                }
                PxButton {
                    compact: true
                    hell: Theme.hell
                    visible: /^\s*(?:[-*]\s+)?\[[xX]\]/m.test(area.text)
                    text: I18n.t("Убрать отмеченные", "Clear the ticked")
                    icon: "trash"
                    onClicked: {
                        area.text = area.text.split("\n").filter(l => !/^\s*(?:[-*]\s+)?\[[xX]\]/.test(l)).join("\n");
                        area.input.forceActiveFocus();
                    }
                }
                PxButton {
                    compact: true
                    hell: Theme.hell
                    text: I18n.t("Готово", "Done")
                    icon: "heart"
                    accent: true
                    onClicked: ew.note.editorState.done()
                }
            }
        }
    }
    RightClickGuard {}
}
