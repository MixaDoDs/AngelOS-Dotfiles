pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

PxPage {
    id: page

    heading: I18n.t("Плагины", "Plugins")
    subtitle: I18n.t("Папка ~/.config/angelos/plugins/<id>/ с manifest.json. Плагин может добавить пункты в ПКМ-меню, виджет на панель или рабочий стол, фоновый сервис и страницу настроек. Документация: docs/PLUGINS.md", "Plugins live in ~/.config/angelos/plugins/<id>/ with manifest.json. They can add menus, bar or desktop widgets, services, and settings pages. See docs/PLUGINS.md.")

    property string createLog: ""
    property string removeLog: ""
    property string confirmId: ""           // the card whose bin was clicked once
    Timer {
        id: confirmReset
        interval: 4000
        onTriggered: page.confirmId = ""
    }
    PxButton {
        visible: Config.developer.enabled
        text: I18n.t("Создать плагин с ИИ", "Create a plugin with AI")
        icon: "sparkle"
        accent: true
        onClicked: Shell.openSettings("studio")
    }
    Connections {
        target: Plugins
        function onMoveFailed(why) {
            page.removeLog = why;
        }
        function onCreated(id, ok) {
            page.createLog = ok ? I18n.t("создан ~/.config/angelos/plugins/", "Created ~/.config/angelos/plugins/") + id + " ♡" : I18n.t("не получилось (такая папка уже есть?)", "Could not create plugin. Does the folder already exist?");
        }
    }

    PxGroup {
        name: "installed"
        title: I18n.t("Установленные (", "Installed (") + Plugins.plugins.length + ")"
        icon: "plug"
        width: parent.width

        Repeater {
            model: Plugins.plugins
            PxBox {
                id: card
                required property var modelData
                readonly property bool on: Plugins.isEnabled(modelData)
                width: parent.width
                height: cardCol.implicitHeight + Theme.u * 10
                color: on ? Theme.mix(Theme.face, Theme.accent, 0.08) : Theme.face

                Row {
                    x: Theme.u * 4
                    y: Theme.u * 4
                    width: parent.width - Theme.u * 8
                    spacing: Theme.u * 5
                    PxIcon {
                        id: cardIcon
                        name: card.modelData.icon || "plug"
                        pixel: Theme.u * 2
                    }
                    Column {
                        id: cardCol
                        width: parent.width - cardIcon.width - cardSide.width - parent.spacing * 2
                        spacing: Theme.u
                        PxText {
                            text: I18n.label(card.modelData.name) + "  v" + (card.modelData.version || "0") + (card.modelData.bundled ? I18n.t("  · встроенный", "  · bundled") : "")
                            font.bold: true
                        }
                        PxText {
                            width: parent.width
                            text: I18n.label(card.modelData.description || "")
                            wrapMode: Text.Wrap
                            dim: true
                        }
                        PxText {
                            text: [card.modelData.menu ? "ПКМ-меню" : "", card.modelData.menuComponent ? I18n.t("меню (QML)", "menu (QML)") : "", card.modelData.barWidget ? I18n.t("панель", "bar") : "", card.modelData.desktopWidget ? I18n.t("рабочий стол", "desktop") : "", card.modelData.main ? I18n.t("сервис", "service") : "", card.modelData.settings ? I18n.t("настройки", "settings") : ""].filter(s => s).join(" · ") + (card.modelData.author ? "  —  " + card.modelData.author : "")
                            kind: "tiny"
                            dim: true
                        }
                    }
                    Column {
                        id: cardSide
                        spacing: Theme.u * 3
                        PxToggle {
                            checked: card.on
                            onToggled: c => Plugins.setEnabled(card.modelData.id, c)
                        }
                        Row {
                            spacing: Theme.u * 2
                            PxButton {
                                visible: !!card.modelData.settings && card.on
                                compact: true
                                icon: "gear"
                                onClicked: Shell.settingsPage = "plugin:" + card.modelData.id
                            }
                            PxButton {
                                compact: true
                                icon: "folder"
                                onClicked: Shell.openPath(card.modelData.dir)
                            }
                            // remove (a second click confirms): yours go to the trash, bundled ones hide
                            PxButton {
                                readonly property bool asking: page.confirmId === card.modelData.id
                                compact: true
                                danger: true
                                icon: "trash"
                                text: asking ? I18n.t("Точно?", "Sure?") : ""
                                checked: asking
                                onClicked: {
                                    if (!asking) {
                                        page.confirmId = card.modelData.id;
                                        confirmReset.restart();
                                        return;
                                    }
                                    page.confirmId = "";
                                    page.removeLog = "";
                                    Plugins.remove(card.modelData.id);
                                }
                            }
                            // your own plugins: load the files again, or improve them in Plugin Studio
                            PxButton {
                                visible: !card.modelData.bundled
                                compact: true
                                icon: "refresh"
                                enabled: !PluginStudio.busy
                                onClicked: PluginStudio.reloadPlugin(card.modelData.id)
                            }
                            PxButton {
                                visible: !card.modelData.bundled && Config.developer.enabled
                                compact: true
                                icon: "sparkle"
                                text: I18n.t("Доработать", "Improve")
                                onClicked: {
                                    PluginStudio.editRequest = card.modelData.id;
                                    Shell.openSettings("studio");
                                }
                            }
                            // its desktop widget only knows heaven: Studio draws its hell (offered while the demon rules)
                            PxButton {
                                visible: Angel.hellShown && Config.developer.enabled && PluginStudio.needsHell(card.modelData)
                                compact: true
                                icon: "fire"
                                text: I18n.t("Адская версия", "Hell version")
                                enabled: !PluginStudio.busy
                                onClicked: {
                                    PluginStudio.hellRequest = card.modelData.id;
                                    PluginStudio.editRequest = card.modelData.id;
                                    Shell.openSettings("studio");
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    PxGroup {
        name: "removed"
        visible: Plugins.removed.length > 0 || page.removeLog !== ""
        title: I18n.t("Удалённые (", "Removed (") + Plugins.removed.length + ")"
        icon: "trash"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Свои плагины лежат в корзине ~/.local/state/angelos/plugin-trash, встроенные просто спрятаны — «Вернуть» ставит их обратно вместе с настройками.", "Your own plugins wait in the trash (~/.local/state/angelos/plugin-trash), bundled ones are only hidden — Restore puts them back with their settings.")
        }
        PxText {
            visible: page.removeLog !== ""
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.danger
            text: page.removeLog
        }
        Repeater {
            model: Plugins.removed
            Item {
                id: gone
                required property var modelData
                width: parent.width
                height: Math.max(goneIcon.height, goneText.implicitHeight, goneButtons.height)
                PxIcon {
                    id: goneIcon
                    anchors.verticalCenter: parent.verticalCenter
                    name: gone.modelData.icon || "plug"
                    pixel: Theme.u
                    opacity: 0.6
                }
                PxText {
                    id: goneText
                    x: goneIcon.width + Theme.u * 4
                    width: parent.width - x - goneButtons.width - Theme.u * 4
                    anchors.verticalCenter: parent.verticalCenter
                    wrapMode: Text.Wrap
                    text: I18n.label(gone.modelData.name) + (gone.modelData.trashed ? I18n.t("  · в корзине", "  · in the trash") : I18n.t("  · встроенный, спрятан", "  · bundled, hidden"))
                }
                Row {
                    id: goneButtons
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.u * 2
                    PxButton {
                        compact: true
                        icon: "refresh"
                        text: I18n.t("Вернуть", "Restore")
                        onClicked: {
                            page.removeLog = "";
                            Plugins.restore(gone.modelData);
                        }
                    }
                    PxButton {
                        readonly property bool asking: page.confirmId === "erase:" + gone.modelData.dir
                        visible: !!gone.modelData.trashed
                        compact: true
                        danger: true
                        icon: "trash"
                        text: asking ? I18n.t("Стереть навсегда?", "Erase for good?") : ""
                        checked: asking
                        onClicked: {
                            if (!asking) {
                                page.confirmId = "erase:" + gone.modelData.dir;
                                confirmReset.restart();
                                return;
                            }
                            page.confirmId = "";
                            Plugins.erase(gone.modelData);
                        }
                    }
                }
            }
        }
    }

    PxGroup {
        name: "new-plugin"
        title: I18n.t("Новый плагин", "New plugin")
        icon: "plus"
        width: parent.width
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            text: I18n.t("Создаст заготовку со всеми точками встраивания — открой папку и правь QML, потом нажми ↻ у плагина, чтобы он перезагрузился. Или доработай его в Мастере плагинов (кнопка «Доработать»).", "Creates a template with extension points. Open the folder, edit its QML files, then press ↻ next to the plugin to reload it — or improve it in Plugin Studio.")
            dim: true
        }
        Row {
            spacing: Theme.u * 3
            PxField {
                id: newId
                width: Theme.u * 70
                placeholder: I18n.t("id, напр. my-widget", "ID, e.g. my-widget")
            }
            PxField {
                id: newName
                width: Theme.u * 80
                placeholder: I18n.t("Название", "Name")
            }
            PxButton {
                text: I18n.t("Создать", "Create")
                icon: "plus"
                accent: true
                enabled: newId.text.trim() !== ""
                onClicked: Plugins.create(newId.text.trim(), newName.text.trim() || newId.text.trim())
            }
        }
        PxText {
            visible: page.createLog !== ""
            text: page.createLog
        }
        Row {
            spacing: Theme.u * 3
            PxButton {
                text: I18n.t("Перечитать плагины", "Reload plugins")
                icon: "refresh"
                onClicked: Plugins.reload()
            }
            PxButton {
                text: I18n.t("Открыть папку", "Open folder")
                icon: "folder"
                onClicked: Shell.openPath(Config.pluginsDir)
            }
        }
    }
}
