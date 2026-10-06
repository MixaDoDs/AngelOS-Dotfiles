pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// Tabs: limits / sessions / ask.
Column {
    id: root

    property var plugin
    property string tab: "limits"
    spacing: Skin.px(8)

    PxSegmented {
        model: [
            {
                "label": I18n.t("Лимиты", "Limits"),
                "value": "limits"
            },
            {
                "label": I18n.t("Сессии (", "Sessions (") + CodexState.sessions.length + ")",
                "value": "sessions"
            },
            {
                "label": I18n.t("Спросить", "Ask"),
                "value": "ask"
            }
        ]
        currentValue: root.tab
        onActivated: v => root.tab = v
    }

    Row {
        spacing: Skin.px(8)
        Mascot {
            pixel: Theme.u * 2
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            PxText {
                text: "Codex " + (CodexState.words[CodexState.state] || "")
                kind: "title"
            }
            PxText {
                text: (CodexState.data.model || "codex") + " · " + (CodexState.data.provider || "openai")
                dim: true
            }
        }
    }

    Limits {
        visible: root.tab === "limits"
        width: parent.width
    }
    Row {
        visible: root.tab === "limits"
        spacing: Skin.px(6)
        PxButton {
            compact: true
            text: I18n.t("Обновить", "Refresh")
            icon: "refresh"
            onClicked: CodexState.refresh()
        }
        PxButton {
            compact: true
            text: I18n.t("Новая сессия", "New session")
            icon: "terminal"
            onClicked: CodexState.launch([])
        }
    }

    Column {
        visible: root.tab === "sessions"
        width: parent.width
        spacing: Skin.px(4)
        PxText {
            visible: CodexState.sessions.length === 0
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Нет активных сессий. Запущенный codex находится сам — по его логам в ~/.codex/sessions.", "No active sessions. A running codex is picked up from its logs in ~/.codex/sessions.")
        }
        Repeater {
            model: CodexState.sessions
            SkinCard {
                id: card
                required property var modelData
                width: root.width
                height: Skin.px(48)
                padding: 0
                group: true
                shadow: false
                pixelColor: Theme.faceAlt
                Column {
                    x: Skin.px(8)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Skin.px(16)
                    PxText {
                        width: parent.width
                        elide: Text.ElideRight
                        font.bold: true
                        text: (card.modelData.cwd ? card.modelData.cwd + " · " : "") + card.modelData.model + " · " + (CodexState.words[card.modelData.state] || card.modelData.state)
                        color: CodexState.stateColor(card.modelData.state, Theme)
                    }
                    PxText {
                        kind: "tiny"
                        dim: true
                        text: (card.modelData.window ? I18n.t("контекст ", "context ") + Math.round(100 * card.modelData.context / card.modelData.window) + "% · " : "") + CodexState.ago(Date.now() - card.modelData.age * 1000)
                    }
                }
            }
        }
        PxButton {
            compact: true
            text: I18n.t("Продолжить последнюю", "Resume last")
            icon: "terminal"
            onClicked: CodexState.launch(["resume", "--last"])
        }
    }

    Column {
        visible: root.tab === "ask"
        width: parent.width
        spacing: Skin.px(6)
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Быстрый вопрос: codex exec без shell и веб-поиска, песочница только для чтения. Ответ придёт уведомлением.", "Quick question: codex exec with no shell or web search, read-only sandbox. The answer arrives as a notification.")
        }
        PxField {
            id: q
            width: parent.width
            placeholder: I18n.t("спроси Codex…", "Ask Codex…")
            enabled: !CodexState.asking
            onAccepted: {
                CodexState.ask(text);
                text = "";
            }
        }
        PxButton {
            text: CodexState.asking ? I18n.t("Думаю…", "Thinking…") : I18n.t("Спросить", "Ask")
            icon: "terminal"
            accent: true
            enabled: !CodexState.asking && q.text.trim() !== ""
            onClicked: q.accepted()
        }
        PxText {
            visible: !!CodexState.answer
            width: parent.width
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: CodexState.answer ? "? " + CodexState.answer.q + "\n\n" + (CodexState.answer.text || I18n.t("думаю…", "thinking…")) : ""
            color: CodexState.answer && CodexState.answer.error ? Skin.danger : Skin.text
        }
    }
}
