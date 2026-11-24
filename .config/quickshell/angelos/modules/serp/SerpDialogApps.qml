pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// serp-skin: the author's new apps after an update (modules/settings/AppsSyncCard, in
// AppsSyncPrompt's floating window) in Serpantinum's look: what is new with a tick each, then the
// run — a bar for how far it is, each one with its state, the output's last lines. `host` is the
// card (hidden under the skin, its keys still listen): picking, rows, settled. What is done is
// AppsSync's own (toggle, start, skip, retry, close), as on the card.
SerpDialog {
    id: root

    property var host: null
    readonly property bool picking: host ? host.picking : true
    readonly property var rows: host ? host.rows : []
    readonly property int settled: host ? host.settled : 0

    icon: "download"
    title: AppsSync.allDone ? I18n.t("Поставлено ♡", "Installed ♡") : I18n.t("Новое от автора", "New from the author")
    body: picking ? I18n.t("Автор angelOS добавил это уже после твоей установки. Отмечено то, что подходит к твоему выбору — сними лишнее.", "angelOS's author added these after your install. Ticked is what fits your pick: untick what you don't need.") : AppsSync.allDone ? I18n.t("Всё на месте — как у автора.", "Everything is there, as the author has it.") : AppsSync.done ? (AppsSync.auth ? I18n.t("Установка не началась: ", "The install never started: ") + AppsSync.auth + "." : I18n.t("Не всё поставилось — причина в строчках ниже.", "Not everything installed: the lines below say why.")) : I18n.t("Ставлю. Окно можно закрыть — установка продолжится, а я скажу, чем кончилось.", "Installing. The window can be closed: the install goes on, and I'll say how it ended.")
    cardWidth: Serp.px(480)
    buttons: [
        {
            "label": I18n.t("Не надо", "No, thanks"),
            "kind": "flat",
            "visible": picking
        },
        {
            "label": I18n.t("Поставить", "Install") + (AppsSync.taken.length ? " · " + AppsSync.taken.length : ""),
            "icon": "download",
            "kind": "primary",
            "visible": picking,
            "enabled": AppsSync.taken.length > 0
        },
        {
            "label": I18n.t("Ещё раз", "Try again"),
            "icon": "refresh-cw",
            "visible": AppsSync.done && !AppsSync.allDone
        },
        {
            "label": AppsSync.running ? I18n.t("Скрыть", "Hide") : AppsSync.allDone ? I18n.t("Готово", "Done") : I18n.t("Закрыть", "Close"),
            "kind": AppsSync.allDone ? "primary" : "",
            "visible": !picking
        }
    ]
    onPicked: i => {
        if (i === 0)
            AppsSync.skip();
        else if (i === 1)
            AppsSync.start(AppsSync.taken);
        else if (i === 2)
            AppsSync.retry();
        else
            AppsSync.close();
    }

    // how far it is
    Rectangle {
        visible: !root.picking
        width: parent.width
        height: Serp.px(6)
        radius: height / 2
        color: Serp.surface1
        Rectangle {
            height: parent.height
            radius: height / 2
            color: Serp.accent
            width: parent.width * Math.max(0, Math.min(1, AppsSync.items.length ? (root.settled + (AppsSync.running ? AppsSync.sub : 0)) / AppsSync.items.length : 0))
            Behavior on width {
                NumberAnimation {
                    duration: Serp.normal
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
    SText {
        visible: !root.picking
        width: parent.width
        size: Serp.smallSize
        dim: true
        text: root.settled + " / " + AppsSync.items.length + " · " + AppsSync.status
    }

    // what is new (a tick each) / the run (a state each)
    Flickable {
        id: scroll
        width: parent.width
        height: Math.min(list.implicitHeight, Serp.px(260))
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: list
            width: scroll.width
            spacing: Serp.px(6)
            Repeater {
                model: root.rows
                Item {
                    id: row
                    required property var modelData
                    readonly property string st: root.picking ? "" : modelData.state
                    readonly property bool ticked: !!modelData.on
                    width: list.width
                    height: Serp.px(46)
                    opacity: row.st === "wait" || (root.picking && !ticked) ? 0.55 : 1
                    Rectangle {
                        anchors.fill: parent
                        radius: Serp.radiusSmall
                        color: row.st === "run" ? Qt.alpha(Serp.accent, 0.16) : row.st === "fail" ? Qt.alpha(Serp.red, 0.16) : rowMa.containsMouse ? Serp.surface1 : Qt.alpha(Serp.surface0, 0.8)
                        border.width: 1
                        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
                    }
                    // the tick
                    Rectangle {
                        id: tick
                        visible: root.picking
                        x: Serp.px(12)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Serp.px(18)
                        height: width
                        radius: Serp.px(5)
                        color: row.ticked ? Serp.accent : "transparent"
                        border.width: row.ticked ? 0 : Serp.px(2)
                        border.color: Serp.overlay
                        SIcon {
                            anchors.centerIn: parent
                            visible: row.ticked
                            name: "check"
                            size: Serp.px(13)
                            stroke: 3
                            color: Serp.onAccent
                        }
                    }
                    AppGlyph {
                        id: glyph
                        x: root.picking ? tick.x + tick.width + Serp.px(10) : Serp.px(12)
                        anchors.verticalCenter: parent.verticalCenter
                        app: row.modelData
                        size: Serp.px(26)
                    }
                    Column {
                        x: glyph.x + glyph.width + Serp.px(10)
                        width: parent.width - x - Serp.px(36)
                        anchors.verticalCenter: parent.verticalCenter
                        SText {
                            width: parent.width
                            bold: row.st === "run"
                            text: I18n.t(row.modelData.ru, row.modelData.en)
                        }
                        SText {
                            width: parent.width
                            size: Serp.smallSize
                            dim: true
                            visible: text !== ""
                            text: I18n.t(row.modelData.hintRu || "", row.modelData.hintEn || "")
                        }
                    }
                    SIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: Serp.px(12)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.st === "done" || row.st === "fail" || row.st === "run"
                        name: row.st === "done" ? "check" : row.st === "fail" ? "x" : "download"
                        size: Serp.px(16)
                        color: row.st === "done" ? Serp.green : row.st === "fail" ? Serp.red : Serp.accent
                    }
                    // the whole row ticks
                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        enabled: root.picking
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppsSync.toggle(row.modelData.id, !row.ticked)
                    }
                }
            }
        }
    }

    // the output's last lines, as a terminal would have shown them
    Rectangle {
        visible: !root.picking && AppsSync.log.length > 0
        width: parent.width
        height: logText.implicitHeight + Serp.px(16)
        radius: Serp.radiusSmall
        color: Qt.alpha(Serp.crust, 0.6)
        SText {
            id: logText
            x: Serp.px(10)
            y: Serp.px(8)
            width: parent.width - Serp.px(20)
            size: Serp.smallSize
            dim: true
            wrapMode: Text.NoWrap
            font.family: Theme.fontMono
            text: AppsSync.log.slice(-5).join("\n") || " "
        }
    }
}
