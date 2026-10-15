pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// «Обслуживание» (services/Care, scripts/care.py): how the computer is, and one button that
// cleans what is safe. The scan changes nothing; the list says what would go and how much.
PxPage {
    heading: I18n.t("Обслуживание", "Maintenance")
    subtitle: I18n.t("Одна кнопка: проверить компьютер и убрать безопасное — старые кэши, временные папки, кэш пакетов. Модели, музыка, профили браузеров и кэши шейдеров игр не трогаются.", "One button: check the computer and clean what is safe — old caches, temporary folders, the package cache. Models, music, browser profiles and game shader caches are never touched.")

    Component.onCompleted: if (!Care.report || Date.now() - Care.lastScan > 60000)
        Care.scan()

    PxGroup {
        name: "main"
        title: I18n.t("Состояние", "Condition")
        icon: "gauge"
        width: parent.width

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
                        color: !Care.report ? Theme.textDim : Care.score >= 85 ? Theme.ok : Care.score >= 60 ? Theme.accent : Theme.danger
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
                Row {
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

        // the checks
        Repeater {
            model: Care.checks
            Row {
                required property var modelData
                width: parent.width
                spacing: Theme.u * 3
                PxIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: parent.modelData.level === "ok" ? "check" : parent.modelData.level === "info" ? "info" : "warn"
                    fill: parent.modelData.level === "ok" ? Theme.ok : parent.modelData.level === "bad" ? Theme.danger : parent.modelData.level === "warn" ? Theme.accent : Theme.accent2
                }
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.u * 12
                    wrapMode: Text.Wrap
                    text: I18n.t(parent.modelData.ru, parent.modelData.en)
                }
            }
        }
    }

    PxGroup {
        name: "clean"
        title: I18n.t("Что убрать", "What to clean")
        icon: "trash"
        width: parent.width
        PxText {
            visible: !Care.items.length
            dim: true
            text: Care.scanning ? I18n.t("Считаю…", "Counting…") : ""
        }
        Repeater {
            model: Care.items
            SettingRow {
                id: row
                required property var modelData
                readonly property var prog: Care.progress[modelData.id]
                label: I18n.t(modelData.ru, modelData.en) + (modelData.root ? I18n.t(" · с паролем", " · needs the password") : "")
                hint: I18n.t(modelData.hintRu, modelData.hintEn)
                Row {
                    spacing: Theme.u * 3
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        dim: !row.prog
                        text: !row.prog ? (row.modelData.bytes > 0 ? Care.size(row.modelData.bytes) : "") : row.prog.state === "start" ? I18n.t("…", "…") : row.prog.state === "fail" ? I18n.t("не вышло", "failed") : row.prog.freed > 0 ? "−" + Care.size(row.prog.freed) : "✓"
                        color: row.prog && row.prog.state === "fail" ? Theme.danger : row.prog && row.prog.state === "done" ? Theme.ok : Theme.text
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
