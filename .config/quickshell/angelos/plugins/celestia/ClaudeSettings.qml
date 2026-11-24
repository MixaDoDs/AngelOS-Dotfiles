import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import "."

Column {
    id: root
    property var plugin
    property string hooks: "?"
    property string log: ""
    width: parent ? parent.width : 400
    spacing: Skin.px(10)

    Process {
        id: hookProc
        command: ["python3", Quickshell.shellDir + "/plugins/claude-companion/hooks/install-hooks.py", "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (hookProc.command[2] === "status")
                    root.hooks = text.trim();
                else {
                    root.log = text.trim();
                    hookProc.command = ["python3", Quickshell.shellDir + "/plugins/claude-companion/hooks/install-hooks.py", "status"];
                    hookProc.running = true;
                }
            }
        }
    }
    function run(cmd) {
        hookProc.command = ["python3", Quickshell.shellDir + "/plugins/claude-companion/hooks/install-hooks.py", cmd];
        hookProc.running = true;
    }

    PxGroup {
        title: I18n.t("Сейчас", "Current")
        icon: "bot"
        width: parent.width
        Panel {
            width: parent.width
            plugin: root.plugin
        }
    }

    PxGroup {
        title: I18n.t("Лимиты", "Limits")
        icon: "gauge"
        width: parent.width
        Limits {
            width: parent.width
        }
        SettingRow {
            label: I18n.t("На панели", "In the bar")
            hint: I18n.t("сколько осталось до лимита", "Remaining usage allowance")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("5 ч", "5 h"),
                        "value": "five"
                    },
                    {
                        "label": I18n.t("Неделя", "Week"),
                        "value": "week"
                    },
                    {
                        "label": I18n.t("Оба", "Both"),
                        "value": "both"
                    },
                    {
                        "label": I18n.t("Только значок", "Icon only"),
                        "value": "off"
                    }
                ]
                currentValue: root.plugin ? root.plugin.get("barLimit", "off") : "off"
                onActivated: v => root.plugin.set("barLimit", v)
            }
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            text: I18n.t("Берётся из того же места, что /usage в Claude Code, по токену из ~/.claude/.credentials.json — ничего настраивать не нужно. Обновляется раз в 90 секунд и при открытии окошка.", "Uses the same source as /usage in Claude Code, with the local credentials token. Refreshes every 90 seconds and when this popup opens.")
            dim: true
        }
    }

    PxGroup {
        title: I18n.t("Хуки Claude Code (необязательно)", "Claude Code hooks (optional)")
        icon: "plug"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            text: I18n.t("Сессии и так подхватываются сами — по транскриптам в ~/.claude/projects. Хуки дают точнее и мгновенно (в т.ч. «ждёт тебя» на запросе разрешения): кнопка добавит их в ~/.claude/settings.json (сначала бэкап в ~/.local/state/angelos/backups/). Своё там не трогается.", "Sessions are detected from ~/.claude/projects transcripts. Hooks provide immediate updates, including permission prompts. Installing hooks backs up settings.json first and preserves existing settings.")
            dim: true
        }
        Row {
            spacing: Skin.px(8)
            PxText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.hooks === "installed" ? I18n.t("подключены ♡", "Connected ♡") : root.hooks === "not-installed" ? I18n.t("не подключены", "Not connected") : "…"
                kind: "title"
                color: root.hooks === "installed" ? Skin.ok : Skin.textDim
            }
            PxButton {
                text: root.hooks === "installed" ? I18n.t("Убрать", "Remove") : I18n.t("Подключить", "Connect")
                icon: root.hooks === "installed" ? "trash" : "plug"
                accent: root.hooks !== "installed"
                onClicked: root.run(root.hooks === "installed" ? "uninstall" : "install")
            }
        }
        PxText {
            visible: root.log !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: root.log
            dim: true
        }
    }

    PxGroup {
        title: I18n.t("Вид", "Appearance")
        icon: "sparkle"
        width: parent.width
        SettingRow {
            label: I18n.t("Сфера на рабочем столе", "Desktop orb")
            PxSegmented {
                model: [
                    {
                        "label": I18n.t("Всегда", "Always"),
                        "value": "always"
                    },
                    {
                        "label": I18n.t("Когда активна", "When active"),
                        "value": "active"
                    },
                    {
                        "label": I18n.t("Выкл", "Off"),
                        "value": "off"
                    }
                ]
                currentValue: root.plugin ? root.plugin.get("orb", "active") : "active"
                onActivated: v => root.plugin.set("orb", v)
            }
        }
        SettingRow {
            label: I18n.t("Монитор для сферы", "Orb display")
            PxCombo {
                width: Skin.px(200)
                model: [
                    {
                        "label": I18n.t("Все экраны", "All displays"),
                        "value": ""
                    }
                ].concat(Quickshell.screens.map(s => ({
                            "label": s.name,
                            "value": s.name
                        })))
                currentValue: root.plugin ? root.plugin.get("orbScreen", "") : ""
                onActivated: v => root.plugin.set("orbScreen", v)
            }
        }
        SettingRow {
            label: I18n.t("Значок на панели всегда", "Always show the bar icon")
            hint: I18n.t("иначе только когда есть сессии", "Otherwise, only show active sessions")
            PxToggle {
                checked: root.plugin ? root.plugin.get("barAlways", true) : true
                onToggled: c => root.plugin.set("barAlways", c)
            }
        }
        SettingRow {
            label: I18n.t("Скорость дыхания", "Breathing speed")
            PxSlider {
                width: parent.width
                from: 0.25
                to: 3
                stepSize: 0.05
                decimals: 2
                value: root.plugin ? root.plugin.get("breath", 1.0) : 1
                suffix: "×"
                onReleased: v => root.plugin.set("breath", v)
            }
        }
        SettingRow {
            label: I18n.t("Подключать MCP «angelos»", "Connect angelOS MCP")
            hint: I18n.t("сессии из лаунчера видят окна, музыку, могут менять тему/обои", "Launcher sessions can see windows and music, and change the theme or wallpaper")
            PxToggle {
                checked: root.plugin ? root.plugin.get("mcp", true) : true
                onToggled: c => root.plugin.set("mcp", c)
            }
        }
    }
}
