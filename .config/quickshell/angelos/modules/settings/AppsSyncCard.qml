pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The card of the author's new apps (AppsSyncPrompt.qml puts it on the screen; the UI self-test
// draws it by itself): what is new with a tick each, then the run — hearts for how far it is,
// each one with its state, the output's last lines, «Ещё раз» for what didn't make it.
PxWindow {
    id: dialog

    readonly property bool picking: !AppsSync.running && !AppsSync.done
    readonly property var rows: picking ? AppsSync.offer : AppsSync.items
    readonly property int settled: AppsSync.items.filter(x => x.state === "done" || x.state === "fail").length
    function takeKeys() {
        keys.forceActiveFocus();
    }

    width: Theme.u * 220
    height: titleHeight + col.implicitHeight + Theme.pad * 2 + Theme.u * 8
    title: AppsSync.allDone ? I18n.t("Поставлено ♡", "Installed ♡") : I18n.t("Новое от автора", "New from the author")
    icon: "download"
    onCloseClicked: AppsSync.close()

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) {
                AppsSync.close();
                e.accepted = true;
            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                if (dialog.picking)
                    AppsSync.start(AppsSync.taken);
                else if (AppsSync.done)
                    AppsSync.close();
                e.accepted = true;
            }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.u * 4

        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            text: dialog.picking ? I18n.t("Автор angelOS добавил это уже после твоей установки. Отмечено то, что подходит к твоему выбору — сними лишнее.", "angelOS's author added these after your install. Ticked is what fits your pick: untick what you don't need.") : AppsSync.allDone ? I18n.t("Всё на месте — как у автора.", "Everything is there, as the author has it.") : AppsSync.done ? (AppsSync.auth ? I18n.t("Установка не началась: ", "The install never started: ") + AppsSync.auth + "." : I18n.t("Не всё поставилось — причина в строчках ниже.", "Not everything installed: the lines below say why.")) : I18n.t("Ставлю. Окно можно закрыть — установка продолжится, а я скажу, чем кончилось.", "Installing. The window can be closed: the install goes on, and I'll say how it ended.")
        }

        // how far it is
        PxProgress {
            visible: !dialog.picking
            width: parent.width
            busy: AppsSync.running
            value: AppsSync.items.length ? (dialog.settled + (AppsSync.running ? AppsSync.sub : 0)) / AppsSync.items.length : 0
        }
        PxText {
            visible: !dialog.picking
            width: parent.width
            elide: Text.ElideRight
            kind: "tiny"
            dim: true
            text: dialog.settled + " / " + AppsSync.items.length + " · " + AppsSync.status
        }

        // what is new (a tick each) / the run (a state each)
        PxScroll {
            id: scroll
            width: parent.width
            height: Math.min(list.implicitHeight, Theme.u * 110)
            contentHeight: list.implicitHeight
            Column {
                id: list
                width: scroll.width - Theme.u * 6
                spacing: Theme.u * 2
                Repeater {
                    model: dialog.rows
                    Item {
                        id: row
                        required property var modelData
                        readonly property string state: dialog.picking ? "" : modelData.state
                        width: list.width
                        height: Theme.u * 15
                        opacity: row.state === "wait" || (dialog.picking && !modelData.on) ? 0.55 : 1
                        PxBox {
                            anchors.fill: parent
                            color: row.state === "run" ? Theme.mix(Theme.face, Theme.accent, 0.25) : row.state === "fail" ? Theme.mix(Theme.face, "#d8203a", 0.25) : Theme.face
                            sunken: row.state === "run"
                        }
                        PxCheck {
                            id: tick
                            visible: dialog.picking
                            x: Theme.u * 3
                            anchors.verticalCenter: parent.verticalCenter
                            checked: !!row.modelData.on
                            onToggled: c => AppsSync.toggle(row.modelData.id, c)
                        }
                        AppGlyph {
                            id: glyph
                            x: dialog.picking ? tick.x + tick.width + Theme.u * 3 : Theme.u * 3
                            anchors.verticalCenter: parent.verticalCenter
                            app: row.modelData
                            size: Theme.u * 9
                        }
                        Column {
                            x: glyph.x + glyph.width + Theme.u * 3
                            width: parent.width - x - Theme.u * 12
                            anchors.verticalCenter: parent.verticalCenter
                            PxText {
                                width: parent.width
                                elide: Text.ElideRight
                                font.bold: row.state === "run"
                                text: I18n.t(row.modelData.ru, row.modelData.en)
                            }
                            PxText {
                                width: parent.width
                                elide: Text.ElideRight
                                kind: "tiny"
                                dim: true
                                visible: text !== ""
                                text: I18n.t(row.modelData.hintRu || "", row.modelData.hintEn || "")
                            }
                        }
                        PxText {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.u * 3
                            anchors.verticalCenter: parent.verticalCenter
                            kind: "tiny"
                            text: ({
                                    "done": "✓",
                                    "fail": "✕",
                                    "run": "…"
                                })[row.state] || ""
                        }
                        // the whole row ticks
                        MouseArea {
                            anchors.fill: parent
                            enabled: dialog.picking
                            onClicked: AppsSync.toggle(row.modelData.id, !row.modelData.on)
                        }
                    }
                }
            }
        }

        // the output's last lines, as a terminal would have shown them
        PxBox {
            visible: !dialog.picking && AppsSync.log.length > 0
            width: parent.width
            height: logText.implicitHeight + Theme.u * 6
            sunken: true
            color: Theme.mix(Theme.face, "#000000", 0.25)
            PxText {
                id: logText
                x: Theme.u * 3
                y: Theme.u * 3
                width: parent.width - Theme.u * 6
                kind: "tiny"
                dim: true
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                font.family: Theme.fontMono
                text: AppsSync.log.slice(-5).join("\n") || " "
            }
        }

        Row {
            anchors.right: parent.right
            spacing: Theme.u * 4
            PxButton {
                visible: dialog.picking
                text: I18n.t("Не надо", "No, thanks")
                onClicked: AppsSync.skip()
            }
            PxButton {
                visible: dialog.picking
                icon: "download"
                accent: true
                enabled: AppsSync.taken.length > 0
                text: I18n.t("Поставить", "Install") + (AppsSync.taken.length ? " · " + AppsSync.taken.length : "")
                onClicked: AppsSync.start(AppsSync.taken)
            }
            PxButton {
                visible: AppsSync.done && !AppsSync.allDone
                icon: "refresh"
                text: I18n.t("Ещё раз", "Try again")
                onClicked: AppsSync.retry()
            }
            PxButton {
                visible: !dialog.picking
                accent: AppsSync.allDone
                text: AppsSync.running ? I18n.t("Скрыть", "Hide") : AppsSync.allDone ? I18n.t("Готово", "Done") : I18n.t("Закрыть", "Close")
                onClicked: AppsSync.close()
            }
        }
    }
}
