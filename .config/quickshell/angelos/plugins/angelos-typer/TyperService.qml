import QtQuick
import Quickshell.Io
import qs.services
import "."

Item {
    property var plugin
    function initialize() {
        if (plugin) {
            TyperNotes.context = plugin;
            Qt.callLater(() => TyperNotes.finishPending());
        }
    }
    onPluginChanged: initialize()
    Component.onCompleted: initialize()
    IpcHandler {
        target: "typer-notes"
        function compose(): string { return PopupManager.showPanel("typer-note", Niri.focusedOutput) ? "ok" : "not available"; }
        function pin(text: string): string { return TyperNotes.pin(text, Niri.focusedOutput) || TyperNotes.error || "empty"; }
        function restore(): string { return TyperNotes.restore() || "empty"; }
        function state(): string {
            return JSON.stringify({papers: TyperNotes.papers.map(w => ({uid:w.uid,x:w.x,y:w.y,screen:w.screen})),
                draftLength: TyperNotes.draft.length, archived: TyperNotes.archive.length, fading: TyperNotes.fading});
        }
    }
}
