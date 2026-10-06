pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// Speedometer + results + history. Sizes and colours from the Theme API (services/Skin), the
// controls (PxText, PxButton) take the look of the popup they are in.
Column {
    id: root

    property var plugin
    readonly property var history: plugin ? plugin.get("history", []) : []

    spacing: Skin.px(8)

    Connections {
        target: Speed
        function onFinished(r) {
            if (root.plugin)
                root.plugin.set("history", [r].concat(root.history).slice(0, 20));
        }
    }

    Gauge {
        anchors.horizontalCenter: parent.horizontalCenter
        value: Speed.phase === "upload" ? Speed.up : Speed.phase === "idle" ? (root.history[0] ? root.history[0].down : 0) : Speed.down
    }
    PxText {
        anchors.horizontalCenter: parent.horizontalCenter
        kind: "big"
        text: ({
                "idle": root.history[0] ? root.history[0].down.toFixed(0) + I18n.t(" Мбит/с", " Mbps") : (Skin.mac ? I18n.t("Готов", "Ready") : I18n.t("готов ♡", "Ready ♡")),
                "config": I18n.t("настраиваюсь…", "Configuring…"),
                "ping": I18n.t("ищу сервер…", "Finding a server…"),
                "download": I18n.t("скачиваю…", "Downloading…"),
                "upload": I18n.t("загружаю…", "Uploading…"),
                "done": Speed.down.toFixed(1) + " ↓  " + Speed.up.toFixed(1) + " ↑",
                "error": I18n.t("ой ✕", "Error ✕")
            })[Speed.phase] || ""
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Skin.px(20)
        Repeater {
            model: [
                {
                    "k": I18n.t("пинг", "ping"),
                    "v": Speed.ping ? Speed.ping.toFixed(0) + I18n.t(" мс", " ms") : "—"
                },
                {
                    "k": I18n.t("скачка", "download"),
                    "v": Speed.down ? Speed.down.toFixed(1) : "—"
                },
                {
                    "k": I18n.t("отдача", "upload"),
                    "v": Speed.up ? Speed.up.toFixed(1) : "—"
                }
            ]
            Column {
                required property var modelData
                PxText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.v
                    kind: "title"
                }
                PxText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.k
                    dim: true
                }
            }
        }
    }
    PxText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        dim: true
        text: Speed.error || [Speed.isp, Speed.server].filter(s => s).join(" · ")
        color: Speed.error ? Skin.danger : Skin.textDim
    }
    PxButton {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Speed.running ? I18n.t("Стоп", "Stop") : I18n.t("Старт", "Start")
        icon: Speed.running ? "close" : "gauge"
        accent: !Speed.running
        kind: "title"
        onClicked: Speed.running ? Speed.stop() : Speed.start()
    }
    PxText {
        visible: root.history.length > 0
        text: I18n.t("История", "History")
        kind: "title"
    }
    Repeater {
        model: root.history.slice(0, 6)
        Row {
            required property var modelData
            spacing: Skin.px(12)
            PxText {
                width: Skin.px(100)
                text: Qt.formatDateTime(new Date(modelData.time), "dd.MM HH:mm")
                dim: true
            }
            PxText {
                text: modelData.down.toFixed(1) + " ↓   " + modelData.up.toFixed(1) + " ↑   " + (modelData.ping > 0 && modelData.ping < 60000 ? modelData.ping.toFixed(0) + I18n.t(" мс", " ms") : "— " + I18n.t("мс", "ms"))
            }
        }
    }
}
