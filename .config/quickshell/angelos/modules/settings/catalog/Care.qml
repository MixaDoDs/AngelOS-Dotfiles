// The settings once in CarePage.qml (converted 23.10.2026 into the catalog, modules/settings/kit);
// from now on this file is where these settings live.
pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings
import qs.modules.settings.kit

// «Обслуживание» (services/Care, scripts/care.py): how the computer is, and one button that
// cleans what is safe. The scan changes nothing; the list says what would go and how much.
CatPage {
    heading: I18n.t("Обслуживание", "Maintenance")
    subtitle: I18n.t("Одна кнопка: проверить компьютер и убрать безопасное — старые кэши, временные папки, кэш пакетов. Модели, музыка, профили браузеров и кэши шейдеров игр не трогаются.", "One button: check the computer and clean what is safe — old caches, temporary folders, the package cache. Models, music, browser profiles and game shader caches are never touched.")
    id: page
    property string armed: ""               // the game whose prefix reset waits for a second click
    Component.onCompleted: {
        if (!Care.report || Date.now() - Care.lastScan > 60000)
            Care.scan();
        if (!Care.games)
            Care.gameScan();
    }
    // one line of a check: {level: ok|info|warn|bad, ru, en}
    component CheckRow: Row {
        required property var modelData
        width: parent.width
        spacing: Theme.u * 3
        PxIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: parent.modelData.level === "ok" ? "check" : parent.modelData.level === "info" ? "info" : "warn"
            fill: parent.modelData.level === "ok" ? Theme.tone("ok", Theme.p5For(parent)) : parent.modelData.level === "bad" ? Theme.danger : parent.modelData.level === "warn" ? Theme.accent : Theme.accent2
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.u * 12
            wrapMode: Text.Wrap
            text: I18n.t(parent.modelData.ru, parent.modelData.en)
        }
    }
    CatGroup {
        name: "main"
        title: I18n.t("Состояние", "Condition")
        icon: "gauge"
        // the score and the button
        CatCustom {
            wide: true
            CatBox {
                // the score and the button
                Row {
                    width: parent.width
                    spacing: Theme.u * 6
                    PxBox {
                        width: Theme.u * 40
                        height: Theme.u * 40
                        sunken: true
                        Column {
                            anchors.centerIn: parent
                            PxText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                kind: "huge"
                                text: Care.report ? String(Care.score) : "…"
                                color: !Care.report ? Theme.tone("textDim", Theme.p5For(parent)) : Care.score >= 85 ? Theme.tone("ok", Theme.p5For(parent)) : Care.score >= 60 ? Theme.accent : Theme.danger
                            }
                            PxText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                kind: "tiny"
                                dim: true
                                text: I18n.t("из 100", "of 100")
                            }
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.u * 46
                        spacing: Theme.u * 3
                        PxText {
                            width: parent.width
                            wrapMode: Text.Wrap
                            kind: "title"
                            text: Care.scanning ? I18n.t("Смотрю…", "Looking…") : Care.running ? I18n.t("Обслуживаю…", "Working…") : Care.finished && !Care.authError ? I18n.t("Готово: освобождено ", "Done: freed ") + Care.size(Care.freed) : Care.report ? I18n.t("Можно освободить ", "Can free ") + Care.size(Care.chosenBytes) : ""
                        }
                        PxText {
                            visible: Care.authError !== ""
                            width: parent.width
                            wrapMode: Text.Wrap
                            color: Theme.danger
                            text: I18n.t("Без пароля администратора: ", "No admin password: ") + Care.authError
                        }
                        Flow {
                            width: parent.width
                            spacing: Theme.u * 3
                            PxButton {
                                text: I18n.t("Обслуживание", "Maintain")
                                icon: "sparkle"
                                accent: true
                                enabled: !!Care.report && !Care.running && !Care.scanning && Care.items.some(i => Care.isPicked(i.id))
                                onClicked: Care.start()
                            }
                            PxButton {
                                text: I18n.t("Проверить снова", "Check again")
                                icon: "refresh"
                                enabled: !Care.running && !Care.scanning
                                onClicked: Care.scan()
                            }
                        }
                        PxText {
                            visible: Care.needsRoot && !Care.running
                            kind: "tiny"
                            dim: true
                            text: I18n.t("пароль администратора спросят один раз", "the admin password is asked once")
                        }
                    }
                }
            }
        }
        // the checks
        CatCustom {
            wide: true
            CatBox {
                // the checks
                Repeater {
                    model: Care.checks
                    CheckRow {}
                }
            }
        }
    }
    CatGroup {
        name: "clean"
        title: I18n.t("Что убрать", "What to clean")
        icon: "trash"
        CatNote {
            present: !Care.items.length
            dim: true
            text: Care.scanning ? I18n.t("Считаю…", "Counting…") : ""
        }
        CatRepeat {
            model: Care.items
            delegate: Component {
                CatCustom {
                    id: row
                    required property var modelData
                    readonly property var prog: Care.progress[modelData.id]
                    label: I18n.t(modelData.ru, modelData.en) + (modelData.root ? I18n.t(" · с паролем", " · needs the password") : "")
                    hint: I18n.t(modelData.hintRu, modelData.hintEn)
                    CatBox {
                        Row {
                            spacing: Theme.u * 3
                            PxText {
                                anchors.verticalCenter: parent.verticalCenter
                                dim: !row.prog
                                text: !row.prog ? (row.modelData.bytes > 0 ? Care.size(row.modelData.bytes) : "") : row.prog.state === "start" ? I18n.t("…", "…") : row.prog.state === "fail" ? I18n.t("не вышло", "failed") : row.prog.freed > 0 ? "−" + Care.size(row.prog.freed) : "✓"
                                color: row.prog && row.prog.state === "fail" ? Theme.danger : row.prog && row.prog.state === "done" ? Theme.tone("ok", Theme.p5For(parent)) : Theme.tone("text", Theme.p5For(parent))
                            }
                            PxToggle {
                                enabled: !Care.running
                                checked: Care.isPicked(row.modelData.id)
                                onToggled: v => Care.pick(row.modelData.id, v)
                            }
                        }
                    }
                }
            }
        }
    }
    // «Доктор игр» (scripts/game-doctor.py): what games need, and the fixes that help when one
    // stops starting. Which Proton a game runs and its launch options stay the user's, in Steam
    CatGroup {
        name: "games"
        title: I18n.t("Игры", "Games")
        icon: "gamepad"
        CatCustom {
            wide: true
            CatBox {
                Flow {
                    width: parent.width
                    spacing: Theme.u * 3
                    PxButton {
                        text: I18n.t("Проверить", "Check")
                        icon: "refresh"
                        enabled: !Care.gamesScanning && !Care.gameBusy
                        onClicked: Care.gameScan()
                    }
                    PxButton {
                        text: I18n.t("Свежий GE-Proton", "The newest GE-Proton")
                        icon: "download"
                        enabled: !Care.gameBusy
                        onClicked: Care.gameFix(["ge-proton"])
                    }
                    PxButton {
                        text: I18n.t("Очистить все кэши шейдеров", "Clear all shader caches")
                        icon: "trash"
                        enabled: !Care.gameBusy
                        onClicked: Care.gameFix(["clear-shaders", "all"])
                    }
                    PxButton {
                        visible: !!Care.games && !Care.games.edition
                        text: I18n.t("Поставить игровую версию", "Install the gaming edition")
                        icon: "package"
                        accent: true
                        onClicked: Care.gameSetup()
                    }
                }
            }
        }
        CatNote {
            present: Care.gameBusy || !!Care.gameResult
            text: Care.gameBusy ? I18n.t("Делаю…", "Working…") : Care.gameResult ? I18n.t(Care.gameResult.ru, Care.gameResult.en) : ""
        }
        CatNote {
            present: !!Care.games && !Care.games.edition
            textKind: "tiny"
            dim: true
            text: I18n.t("Игровая версия: Steam, Proton, драйверы для игр, gamemode, MangoHud, кэш шейдеров 10 ГБ, на btrfs — снимок системы перед каждым обновлением. Откроется терминал: пароль администратора спросит pacman.", "The gaming edition: Steam, Proton, the drivers for games, gamemode, MangoHud, a 10 GB shader cache, on btrfs a snapshot before every update. A terminal opens: pacman asks the admin password.") + (Care.games && Care.games.missing.length ? I18n.t(" Не хватает: ", " Missing: ") + Care.games.missing.join(", ") : "")
        }
        CatNote {
            present: !Care.games
            dim: true
            text: Care.gamesScanning ? I18n.t("Смотрю…", "Looking…") : ""
        }
        CatCustom {
            wide: true
            CatBox {
                Repeater {
                    model: Care.games ? Care.games.checks : []
                    CheckRow {}
                }
            }
        }
        CatRepeat {
            model: Care.games ? Care.games.games : []
            delegate: Component {
                CatCustom {
                    id: game
                    required property var modelData
                    label: modelData.name
                    hint: (modelData.shaderBytes > 0 ? I18n.t("кэш шейдеров ", "shader cache ") + Care.size(modelData.shaderBytes) : I18n.t("кэша шейдеров нет", "no shader cache")) + (page.armed === modelData.id ? I18n.t(" · префикс уйдёт в копию (steamapps/angelos-prefix-backups), Steam создаст чистый", " · the prefix moves to a copy (steamapps/angelos-prefix-backups), Steam makes a clean one") : "")
                    CatBox {
                        Flow {
                            width: parent.width
                            spacing: Theme.u * 2
                            PxButton {
                                compact: true
                                text: I18n.t("Шейдеры", "Shaders")
                                icon: "trash"
                                enabled: !Care.gameBusy && game.modelData.shaderBytes > 0
                                onClicked: Care.gameFix(["clear-shaders", game.modelData.id])
                            }
                            PxButton {
                                compact: true
                                text: page.armed === game.modelData.id ? I18n.t("Точно сбросить", "Reset, sure") : I18n.t("Сбросить префикс", "Reset the prefix")
                                icon: "rotate"
                                danger: page.armed === game.modelData.id
                                enabled: !Care.gameBusy && game.modelData.prefix
                                onClicked: {
                                    if (page.armed !== game.modelData.id) {
                                        page.armed = game.modelData.id;
                                        return;
                                    }
                                    page.armed = "";
                                    Care.gameFix(["reset-prefix", game.modelData.id]);
                                }
                            }
                        }
                    }
                }
            }
        }
        // each game's Proton and launch options, what ProtonDB says, the FPS compared here
        CatNote {
            text: I18n.t("Proton и параметры запуска", "Proton and launch options")
        }
        CatCustom {
            wide: true
            CatBox {
                GameTuneList {
                    width: parent.width
                }
            }
        }
    }
    // «Помощник»: something broke → an AI agent of the user's choice, with the logs gathered and
    // angelOS's rules (scripts/help-agent.sh). The user logs in to their own account in it
    CatGroup {
        name: "helper"
        title: I18n.t("Помощник", "Helper")
        icon: "bot"
        CatChoice {
            label: I18n.t("Агент", "Agent")
            hint: I18n.t("Начинает с выбранного. Кончился лимит — берёт следующий: Claude, потом Codex, потом opencode. Входишь в свой аккаунт; angelOS ключей не хранит.", "Starts with the chosen one. Out of limits: the next — Claude, then Codex, then opencode. You log in to your own account; angelOS keeps no keys.")
            model: [
                {
                    "label": "Claude Code",
                    "value": "claude"
                },
                {
                    "label": "Codex",
                    "value": "codex"
                },
                {
                    "label": "opencode",
                    "value": "opencode"
                }
            ]
            currentValue: Config.system.helpAgent
            onActivated: v => Config.system.helpAgent = v
        }
        CatCustom {
            wide: true
            CatBox {
                PxField {
                    id: trouble
                    width: parent.width
                    placeholder: I18n.t("Что случилось? (можно пусто — спросит сам)", "What happened? (may stay empty: it asks)")
                }
            }
        }
        CatButton {
            text: I18n.t("Позвать помощника", "Call the helper")
            icon: "bot"
            accent: true
            onClicked: {
                Care.callHelper(trouble.text.trim());
                trouble.text = "";
            }
        }
        CatNote {
            textKind: "tiny"
            dim: true
            text: I18n.t("Откроется терминал. Помощник уже видит журналы системы, оболочки и обновлений; перед правкой делает снимок системы (если они есть) и спрашивает перед каждой командой, sudo — только с твоего согласия.", "A terminal opens. The helper sees the system's, the shell's and the updates' logs already; before a change it takes a snapshot (when there are any) and asks before every command, sudo only with your yes.")
        }
    }
}
