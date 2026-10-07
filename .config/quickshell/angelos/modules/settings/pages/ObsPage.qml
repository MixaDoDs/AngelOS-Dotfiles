import QtQuick
import qs.config
import qs.services
import qs.widgets

// Streaming → OBS (2026-10-07): the link to OBS that stream mode and the angel on stream use
// (obs-websocket; the password comes from OBS's own config, scripts/obs-watch.py).
PxPage {
    heading: "OBS"
    subtitle: I18n.t("Связь с OBS: стрим-режим и ангел узнают через неё, что идёт эфир.", "The link to OBS: stream mode and the angel learn from it that you're live.")

    PxGroup {
        name: "obs"
        title: I18n.t("Подключение", "Connection")
        icon: "camera"
        width: parent.width
        SettingRow {
            label: I18n.t("Состояние", "Status")
            hint: StreamMode.obsUp ? "" : StreamMode.obsAuth ? I18n.t("OBS просит пароль, а в его настройках его не нашлось: включи вход без пароля или сохрани пароль в OBS", "OBS wants a password that isn't in its settings: allow no password or save it in OBS") : I18n.t("в OBS: Инструменты → Настройки сервера WebSocket → «Включить сервер»", "in OBS: Tools → WebSocket Server Settings → “Enable server”")
            PxText {
                text: StreamMode.obsUp ? (StreamMode.obsLive ? I18n.t("● В эфире", "● Live") : StreamMode.obsRec ? I18n.t("● Идёт запись", "● Recording") : I18n.t("На связи", "Connected")) : StreamMode.obsAuth ? I18n.t("Нужен пароль", "Needs a password") : I18n.t("Не подключено", "Not connected")
                color: StreamMode.obsUp ? (StreamMode.obsLive ? Theme.danger : Theme.ok) : Theme.textDim
            }
        }
        SettingRow {
            label: I18n.t("Порт WebSocket", "WebSocket port")
            hint: I18n.t("как в настройках сервера WebSocket в OBS (обычно 4455)", "as in OBS's WebSocket server settings (usually 4455)")
            Row {
                spacing: Theme.u * 3
                PxField {
                    id: portField
                    width: Theme.u * 30
                    text: String(Config.stream.port || 4455)
                    onAccepted: {
                        const n = parseInt(text);
                        if (n > 0 && n < 65536) {
                            Config.stream.port = n;
                            StreamMode.reconnect();
                        }
                    }
                }
                PxButton {
                    compact: true
                    icon: "refresh"
                    text: I18n.t("Переподключить", "Reconnect")
                    onClicked: portField.accepted()
                }
            }
        }
    }
}
