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
        StrataSetup.refresh();
    }

    // Strata, the file manager angelOS installs (services/StrataSetup, scripts/strata-setup.py)
    PxGroup {
        name: "files-strata"
        title: I18n.t("Файлы · Strata", "Files · Strata")
        icon: "folder"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: StrataSetup.installed ? I18n.t("Файловый менеджер angelOS: колонки, превью на пробел, поиск по Ctrl+K. angelOS добавляет в его меню «Открыть в терминале», «Отправить рядом» и mediafix для видео, а его тема «angelOS» сама следует за раем и адом. Mod+E открывает тот менеджер, что выбран ниже в «Файлы».", "angelOS's file manager: columns, Space previews, Ctrl+K search. angelOS adds «Open in terminal», «Send nearby» and mediafix for videos to its menu, and its «angelOS» theme follows heaven and hell by itself. Mod+E opens whichever manager «File manager» below names.") : I18n.t("Strata — файловый менеджер, который ставит angelOS (колонки, превью на пробел, быстрый поиск). Его ещё нет: он ставится из релиза на GitHub, для твоего пользователя, а обновляется сам.", "Strata is the file manager angelOS installs (columns, Space previews, fast search). It isn't here yet: it comes from its GitHub release, for your user, and updates itself.")
        }
        Repeater {
            model: !StrataSetup.installed ? [] : [
                [I18n.t("Открывает папки (Mod+E, «Пуск»)", "Opens folders (Mod+E, Start)"), !!StrataSetup.status.default, I18n.t("кнопка «Сделать основным»", "the «Make it the default» button")],
                [I18n.t("«Показать в папке» из браузера и программ", "«Show in folder» from browsers and apps"), !!StrataSetup.status.fileManager1, I18n.t("включится вместе с «основным»", "comes with «the default»")],
                [I18n.t("Открыть в терминале", "Open in terminal"), !!StrataSetup.status.actions && StrataSetup.status.actions["angelos-terminal"], ""],
                [I18n.t("Отправить рядом (LocalSend)", "Send nearby (LocalSend)"), !!StrataSetup.status.actions && StrataSetup.status.actions["angelos-share"], ""],
                ["mediafix", !!StrataSetup.status.actions && StrataSetup.status.actions["angelos-mediafix"], ""],
                ["ffmpeg (mediafix)", !!StrataSetup.status.ffmpeg, "sudo pacman -S ffmpeg"],
                [I18n.t("Тема angelOS (рай/ад на лету)", "The angelOS theme (heaven/hell on the fly)"), !!StrataSetup.status.themeSelected, StrataSetup.themePending ? I18n.t("включится, когда Strata закроется", "switches on once Strata closes") : ""]
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
        SettingRow {
            visible: StrataSetup.installed
            label: I18n.t("Окна «Открыть» и «Сохранить»", "Open and Save dialogs")
            hint: I18n.t("у всех программ через портал — окна Strata вместо GTK-шных; выключишь — вернутся прежние", "for every app through the portal: Strata's instead of GTK's; off brings the old ones back")
            PxToggle {
                checked: !!StrataSetup.status.portal
                enabled: !StrataSetup.busy
                onToggled: v => StrataSetup.portal(v)
            }
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            PxButton {
                visible: !StrataSetup.installed
                text: I18n.t("Поставить Strata", "Install Strata")
                icon: "download"
                accent: true
                onClicked: Shell.exec(Shell.terminalArgv(["python3", Quickshell.shellDir + "/scripts/apps-install.py", "install", "strata"]))
            }
            PxButton {
                visible: StrataSetup.installed && !StrataSetup.status.default
                text: I18n.t("Сделать основным", "Make it the default")
                icon: "star"
                accent: true
                enabled: !DefaultApps.busy
                onClicked: {
                    DefaultApps.set("files", "io.github.lgse.Strata.desktop");
                    strataRecheck.restart();
                }
            }
            PxButton {
                visible: StrataSetup.installed
                text: StrataSetup.applied ? I18n.t("Применить заново", "Apply again") : I18n.t("Применить", "Apply")
                icon: "check"
                accent: !StrataSetup.applied && !!StrataSetup.status.default
                enabled: !StrataSetup.busy
                onClicked: StrataSetup.apply()
            }
            PxButton {
                visible: StrataSetup.installed && !!StrataSetup.status.actions && Object.values(StrataSetup.status.actions).some(v => v)
                text: I18n.t("Убрать пункты и тему", "Remove the items and the theme")
                icon: "trash"
                enabled: !StrataSetup.busy
                onClicked: StrataSetup.remove()
            }
            PxButton {
                visible: StrataSetup.installed
                text: I18n.t("Открыть Strata", "Open Strata")
                icon: "folder"
                onClicked: Shell.exec([StrataSetup.status.bin, Config.home])
            }
        }
        Timer {
            id: strataRecheck
            interval: 1500
            onTriggered: {
                StrataSetup.refresh();
                DefaultApps.refresh();
            }
        }
        PxText {
            visible: StrataSetup.log !== ""
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: StrataSetup.log
        }
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
                [I18n.t("Отправить рядом (LocalSend)", "Send nearby (LocalSend)"), !!NautilusSetup.status.extensions && NautilusSetup.status.extensions["angelos_share.py"], ""],
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
        SettingRow {
            label: I18n.t("Просмотр по пробелу", "Quick Look on Space")
            hint: !Config.quicklook.enabled ? I18n.t("выключено", "off") : QuickLook.nameOurs ? I18n.t("пробел на файле в Nautilus — окно angelOS с картинкой, видео, текстом, PDF", "Space on a file in Nautilus opens it in an angelOS window: pictures, video, text, PDF") : I18n.t("пробел занят другим просмотрщиком (sushi?)", "Space is taken by another previewer (sushi?)")
            PxToggle {
                checked: Config.quicklook.enabled
                onToggled: v => Config.quicklook.enabled = v
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
