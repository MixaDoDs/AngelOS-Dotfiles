import QtQuick
import qs.config
import qs.services
import "."

// "claude <task>" → Claude Code in a terminal · "claude ? question" → quick answer.
QtObject {
    id: root

    property var plugin
    property string pluginId
    readonly property string prefix: "claude"
    readonly property bool global: false
    signal changed

    function query(text, prefixed) {
        if (!prefixed)
            return [];
        if (text === "") {
            const rows = [
                {
                    "id": "continue",
                    "title": I18n.t("Продолжить последнюю сессию", "Continue last session"),
                    "subtitle": I18n.t("claude --continue в терминале", "claude --continue in terminal"),
                    "icon": "bot"
                }
            ];
            if (Pulse.answer && Pulse.answer.text)
                rows.push({
                    "id": "answer",
                    "title": I18n.t("Последний ответ", "Last answer"),
                    "subtitle": Pulse.answer.q,
                    "icon": "info"
                });
            return rows;
        }
        const m = text.match(/^\?\s*(.*)$/);
        if (m)
            return [
                {
                    "id": "ask:" + m[1],
                    "title": m[1] ? I18n.t("Спросить Claude", "Ask Claude") : I18n.t("Спросить: claude ? вопрос", "Ask: claude ? question"),
                    "subtitle": m[1] || I18n.t("без инструментов, ответ уведомлением", "No tools; answer delivered as a notification"),
                    "icon": "bot",
                    "score": 100
                }
            ];
        return [
            {
                "id": "task:" + text,
                "title": I18n.t("Запустить Claude Code", "Launch Claude Code"),
                "subtitle": text,
                "icon": "terminal",
                "score": 100
            }
        ];
    }

    function activate(id) {
        const mcp = plugin ? plugin.get("mcp", true) : true;
        if (id === "continue")
            Pulse.launch(["--continue"], mcp);
        else if (id === "answer")
            Shell.openSettings("plugin:celestia");
        else if (id.startsWith("ask:") && id.length > 4)
            Pulse.ask(id.slice(4));
        else if (id.startsWith("task:"))
            Pulse.launch([id.slice(5)], mcp);
    }
}
