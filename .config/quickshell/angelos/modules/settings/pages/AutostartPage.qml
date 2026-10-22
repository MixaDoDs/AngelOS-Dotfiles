pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Autostart (services/Autostart, scripts/autostart.py): what starts at login — a switch and a
// bin each — an installed app added by its name, a command of one's own, and the system's own
// entries folded away (switched off by an override of the user's, never touched themselves).
PxPage {
    id: page

    heading: I18n.t("Автозапуск", "Autostart")
    subtitle: I18n.t("Программы, которые запускаются сами при входе в систему.", "Apps that start by themselves when you log in.")
    Component.onCompleted: Autostart.refresh()

    // installed apps that fit what is typed and aren't starting already
    readonly property var found: {
        const q = search.text.trim().toLowerCase();
        if (!q)
            return [];
        return StartApps.apps.filter(a => String(a.name).toLowerCase().includes(q) && !Autostart.has(a.id)).slice(0, 6);
    }

    PxGroup {
        name: "apps"
        title: I18n.t("При входе запускается", "Starts at login")
        icon: "bolt"
        width: parent.width

        PxText {
            visible: Autostart.loaded && !Autostart.works
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.danger
            text: I18n.t("Эта сессия не запускает автозапуск сама (niri стартовал не через niri-session). Записи сохранятся и заработают при обычном входе.", "This session doesn't start autostart entries itself (niri wasn't started through niri-session). The entries are kept and will work after a normal login.")
        }
        PxText {
            visible: Autostart.error !== ""
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.danger
            text: "✕ " + Autostart.error
        }
        PxText {
            visible: Autostart.loaded && Autostart.mine.length === 0
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Пока ничего. Добавь программу ниже — например, мессенджер или музыку.", "Nothing yet. Add an app below: a messenger or your music, say.")
        }
        Repeater {
            model: Autostart.mine
            SettingRow {
                id: entry
                required property var modelData
                label: modelData.name
                hint: modelData.exec + (modelData.fits ? "" : I18n.t(" · не для этого рабочего стола", " · not for this desktop"))
                Row {
                    spacing: Theme.u * 3
                    PxToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: entry.modelData.on
                        onToggled: c => Autostart.setOn(entry.modelData.id, c)
                    }
                    PxButton {
                        visible: entry.modelData.source === "user"
                        icon: "trash"
                        text: I18n.t("Убрать", "Remove")
                        onClicked: Autostart.remove(entry.modelData.id)
                    }
                }
            }
        }
    }

    PxGroup {
        name: "add"
        title: I18n.t("Добавить", "Add")
        icon: "plus"
        width: parent.width

        SettingRow {
            label: I18n.t("Программа", "An app")
            hint: I18n.t("начни печатать её название", "start typing its name")
            PxField {
                id: search
                width: Math.min(Theme.u * 80, parent.width)
                icon: "search"
                placeholder: I18n.t("название", "its name")
            }
        }
        Repeater {
            model: page.found
            SettingRow {
                id: hit
                required property var modelData
                label: modelData.name
                hint: modelData.comment || modelData.genericName || ""
                PxButton {
                    icon: "plus"
                    text: I18n.t("В автозапуск", "Start at login")
                    onClicked: {
                        Autostart.add(hit.modelData.id);
                        search.text = "";
                    }
                }
            }
        }
        PxText {
            visible: search.text.trim() !== "" && page.found.length === 0
            width: parent.width
            dim: true
            text: I18n.t("Такой программы нет (или она уже в автозапуске).", "No such app (or it starts at login already).")
        }
        SettingRow {
            label: I18n.t("Своя команда", "A command of your own")
            hint: I18n.t("имя и то, что выполнить при входе", "a name and what to run at login")
            Flow {
                width: parent.width
                spacing: Theme.u * 3
                PxField {
                    id: cmdName
                    width: Theme.u * 34
                    placeholder: I18n.t("имя", "a name")
                }
                PxField {
                    id: cmdLine
                    width: Math.min(Theme.u * 60, parent.width)
                    placeholder: I18n.t("команда", "the command")
                    kind: "mono"
                    input.onAccepted: cmdAdd.clicked()
                }
                PxButton {
                    id: cmdAdd
                    icon: "plus"
                    enabled: cmdName.text.trim() !== "" && cmdLine.text.trim() !== ""
                    text: I18n.t("Добавить", "Add")
                    onClicked: {
                        Autostart.addCommand(cmdName.text, cmdLine.text);
                        cmdName.text = "";
                        cmdLine.text = "";
                    }
                }
            }
        }
    }

    PxGroup {
        name: "system"
        title: I18n.t("Служебное от системы", "The system's own")
        icon: "chip"
        width: parent.width
        advanced: true

        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Это запускает сама система: связка ключей, снимки, папки пользователя. Обычно лучше не трогать; выключенное можно включить обратно — системные файлы не меняются.", "The system starts these itself: the keyring, snapshots, the user's folders. Usually best left alone; what is switched off can be switched back on: the system's files are never changed.")
        }
        Repeater {
            model: Autostart.system
            SettingRow {
                id: sys
                required property var modelData
                label: modelData.name
                hint: modelData.exec
                PxToggle {
                    checked: sys.modelData.on
                    onToggled: c => Autostart.setOn(sys.modelData.id, c)
                }
            }
        }
    }
}
