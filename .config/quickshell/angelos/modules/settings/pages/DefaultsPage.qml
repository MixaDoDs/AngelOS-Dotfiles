pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

PxPage {
    heading: I18n.t("Приложения по умолчанию", "Default applications")
    subtitle: I18n.t("Чем открывать ссылки, файлы и папки. Пишется в ~/.config/mimeapps.list (сначала бэкап).", "What opens links, files and folders. Written to ~/.config/mimeapps.list (backed up first).")

    Component.onCompleted: {
        DefaultApps.refresh();
        NautilusSetup.refresh();
    }

    PxGroup {
        name: "files-nautilus"
        title: I18n.t("Файлы · Nautilus", "Files · Nautilus")
        icon: "folder"
        width: parent.width
        visible: !!NautilusSetup.status.nautilus
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("angelOS добавляет в меню Nautilus «Открыть в терминале» (терминал из настроек angelOS) и «Подготовить для DaVinci Resolve (mediafix)» для видео, а ещё ставит настройки по умолчанию: архивы в 7z, мелкие значки, без дерева в списке. Старые копии этих пунктов переносятся в бэкап.", "angelOS adds «Open in terminal» (the angelOS terminal) and «Prepare for DaVinci Resolve (mediafix)» for videos to Nautilus, plus defaults: 7z archives, small icons, no tree in list view. Older copies of these items are moved to a backup.")
        }
        Repeater {
            model: [
                [I18n.t("Расширения Nautilus (python)", "Nautilus python extensions"), !!NautilusSetup.status.python, I18n.t("sudo pacman -S nautilus-python", "sudo pacman -S nautilus-python")],
                [I18n.t("Открыть в терминале", "Open in terminal"), !!NautilusSetup.status.extensions && NautilusSetup.status.extensions["angelos_open_terminal.py"], ""],
                ["mediafix", !!NautilusSetup.status.extensions && NautilusSetup.status.extensions["angelos_mediafix.py"], ""],
                ["ffmpeg (mediafix)", !!NautilusSetup.status.ffmpeg, "sudo pacman -S ffmpeg"],
                [I18n.t("Настройки Nautilus", "Nautilus preferences"), !!NautilusSetup.status.prefsApplied, ""]
            ]
            SettingRow {
                required property var modelData
                label: modelData[0]
                hint: modelData[1] ? "" : modelData[2]
                PxText {
                    text: modelData[1] ? I18n.t("готово ♡", "ready ♡") : I18n.t("нет", "no")
                    color: modelData[1] ? Theme.ok : Theme.textDim
                }
            }
        }
        PxText {
            visible: !NautilusSetup.status.prefsApplied && !!NautilusSetup.status.prefs
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            text: I18n.t("Масштаб значков и формат архива Nautilus запоминает сам, когда ты их меняешь в нём, — «Применить» вернёт значения angelOS.", "Nautilus remembers the icon zoom and the archive format itself when you change them there — Apply puts angelOS's values back.")
        }
        PxBox {
            visible: NautilusSetup.needsRestart && NautilusSetup.running
            width: parent.width
            height: restartRow.implicitHeight + Theme.u * 6
            color: Theme.mix(Theme.face, Theme.accent, 0.12)
            Row {
                id: restartRow
                x: Theme.u * 3
                y: Theme.u * 3
                width: parent.width - Theme.u * 6
                spacing: Theme.u * 3
                PxText {
                    width: parent.width - restartNow.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    wrapMode: Text.Wrap
                    text: I18n.t("Перезапустите Nautilus: он уже запущен и подхватит изменения (пункты меню, оформление) только при новом старте. Открытые окна Nautilus закроются.", "Restart Nautilus: it is running and picks up the changes (menu items, the look) only when it starts again. Open Nautilus windows will close.")
                }
                PxButton {
                    id: restartNow
                    anchors.verticalCenter: parent.verticalCenter
                    accent: true
                    icon: "refresh"
                    text: I18n.t("Перезапустить", "Restart")
                    enabled: !NautilusSetup.busy
                    onClicked: NautilusSetup.restartNautilus()
                }
            }
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            PxButton {
                text: NautilusSetup.installed ? I18n.t("Применить заново", "Apply again") : I18n.t("Применить", "Apply")
                icon: "check"
                accent: !NautilusSetup.installed
                enabled: !NautilusSetup.busy
                onClicked: NautilusSetup.apply()
            }
            PxButton {
                visible: NautilusSetup.installed
                text: I18n.t("Убрать пункты", "Remove items")
                icon: "trash"
                enabled: !NautilusSetup.busy
                onClicked: NautilusSetup.remove()
            }
            PxButton {
                text: I18n.t("Перезапустить Nautilus", "Restart Nautilus")
                icon: "refresh"
                enabled: !NautilusSetup.busy
                onClicked: NautilusSetup.restartNautilus()
            }
            PxButton {
                text: I18n.t("mediafix…", "mediafix…")
                icon: "music"
                onClicked: NautilusSetup.mediafix([])
            }
        }
        PxText {
            visible: NautilusSetup.log !== ""
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: NautilusSetup.log
        }
    }

    PxGroup {
        name: "defaults"
        title: I18n.t("По умолчанию", "Defaults")
        icon: "star"
        width: parent.width
        enabled: !DefaultApps.busy

        Repeater {
            model: DefaultApps.categories
            SettingRow {
                id: row
                required property var modelData
                readonly property var info: DefaultApps.data[modelData.id] || ({
                        "current": "",
                        "candidates": []
                    })
                readonly property var cur: info.candidates.find(c => c.id === info.current) || null
                label: modelData.label
                hint: info.candidates.length === 0 ? I18n.t("нет подходящих приложений", "no matching applications") : ""
                Row {
                    spacing: Theme.u * 4
                    Item {
                        width: Theme.u * 12
                        height: Theme.u * 12
                        anchors.verticalCenter: parent.verticalCenter
                        AppIcon {
                            anchors.centerIn: parent
                            visible: !!row.cur
                            iconName: row.cur ? row.cur.icon : ""
                            size: Theme.u * 11
                        }
                        PxIcon {
                            anchors.centerIn: parent
                            visible: !row.cur
                            name: row.modelData.icon
                        }
                    }
                    PxCombo {
                        width: Theme.u * 120
                        model: row.info.candidates.map(c => ({
                                    "label": c.name,
                                    "value": c.id
                                }))
                        currentValue: row.info.current
                        placeholder: row.info.current || "—"
                        onActivated: v => DefaultApps.set(row.modelData.id, v)
                    }
                }
            }
        }
    }
    PxText {
        width: parent.width
        wrapMode: Text.Wrap
        text: DefaultApps.log
        dim: true
    }
}
