import QtQuick
import Quickshell

QtObject {
    property var plugin
    property string pluginId
    readonly property string prefix: "typer"
    readonly property bool global: false
    signal changed
    function query(text, prefixed) {
        if (!prefixed) return [];
        return [
            { id: "open", title: "Открыть AngelOS Typer", subtitle: "Тексты и Markdown", icon: "note", score: 100 },
            { id: "note", title: "Быстрая заметка", subtitle: "Записать мысль и сохранить позже", icon: "note", score: 90 }
        ];
    }
    function activate(id) {
        Quickshell.execDetached(id === "note" ? ["qs", "-c", "angelos", "ipc", "call", "typer-notes", "compose"] : ["angelos-typer"]);
    }
}
