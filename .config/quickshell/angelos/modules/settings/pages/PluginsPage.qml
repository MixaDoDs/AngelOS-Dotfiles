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
    property string confirmUpdateId: ""
    property string communitySearch: ""
    property string communityFilter: "all"
    readonly property string communityError: CommunityPluginCatalog.error
    readonly property string communityMessage: CommunityPluginCatalog.message
    readonly property var communityEntries: CommunityPluginCatalog.entries
    readonly property bool communityBusy: CommunityPluginCatalog.busy
    readonly property var communityShown: communityEntries.filter(entry => {
        if (!entry || entry.status !== "approved")
            return false;
        const query = communitySearch.trim().toLowerCase();
        const haystack = [entry.name, entry.id, entry.author || "", entry.description || "", ...(entry.tags || [])].join(" ").toLowerCase();
        const installed = installedCommunity(entry.id);
        return (!query || haystack.includes(query))
            && (communityFilter === "all" || communityFilter === "installed" && !!installed
                || communityFilter === "updates" && !!installed && !installed.bundled && newerCommunity(installed.version, entry.version));
    })
    function installedCommunity(id) {
        return Plugins.byId(id) || Plugins.removed.find(p => p.id === id && p.bundled) || null;
    }
    function newerCommunity(oldVersion, newVersion) {
        const oldParts = String(oldVersion || "0").split(".").map(Number);
        const newParts = String(newVersion || "0").split(".").map(Number);
        for (let i = 0; i < Math.max(oldParts.length, newParts.length); ++i) {
            const oldNumber = Number.isFinite(oldParts[i]) ? oldParts[i] : 0;
            const newNumber = Number.isFinite(newParts[i]) ? newParts[i] : 0;
            if (newNumber !== oldNumber)
                return newNumber > oldNumber;
        }
        return false;
    }
    Component.onCompleted: if (Quickshell.env("ANGELOS_TEST") !== "1" && !communityEntries.length) CommunityPluginCatalog.refresh()
    Timer {
        id: confirmReset
        interval: 4000
        onTriggered: {
            page.confirmId = "";
            page.confirmUpdateId = "";
        }
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
        name: "community"
        title: I18n.t("Плагины сообщества", "Community plugins")
        icon: "package"
        width: parent.width

        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Только approved из официального registry. Плагины работают с твоими правами; без SHA-256 в записи registry неизменность ZIP после проверки автором не подтверждена.", "Only approved entries from the official registry. Plugins run with your user permissions; without a SHA-256 in the registry, the ZIP cannot be verified against the reviewed release.")
        }
        PxField {
            width: parent.width
            placeholder: I18n.t("Поиск по названию, автору, тегам", "Search name, author, tags")
            text: page.communitySearch
            onEdited: page.communitySearch = text
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            PxButton {
                icon: "refresh"
                text: I18n.t("Обновить каталог", "Refresh catalog")
                enabled: !page.communityBusy
                onClicked: CommunityPluginCatalog.refresh()
            }
            PxButton {
                compact: true
                icon: "external"
                text: I18n.t("Опубликовать плагин", "Publish a plugin")
                onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/futureUnd1ground/angelos-community-registry/blob/main/CONTRIBUTING.md"])
            }
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 2
            Repeater {
                model: [
                    {key: "all", ru: "Все", en: "All"},
                    {key: "installed", ru: "Установленные", en: "Installed"},
                    {key: "updates", ru: "Обновления", en: "Updates"}
                ]
                PxButton {
                    required property var modelData
                    compact: true
                    text: I18n.label({ru: modelData.ru, en: modelData.en})
                    checked: page.communityFilter === modelData.key
                    onClicked: page.communityFilter = modelData.key
                }
            }
        }
        PxText {
            visible: CommunityPluginCatalog.busy
            text: CommunityPluginCatalog.action === "install"
                ? I18n.t("Устанавливаю плагин…", "Installing plugin…")
                : I18n.t("Загружаю каталог…", "Loading catalog…")
            dim: true
        }
        PxText {
            visible: page.communityError !== ""
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.danger
            text: page.communityError
        }
        PxText {
            visible: page.communityMessage !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: I18n.t("Плагин установлен: ", "Plugin installed: ") + page.communityMessage
                + I18n.t(". Перезапусти оболочку для применения изменений.", ". Restart the shell to apply changes.")
        }
        PxButton {
            visible: page.communityMessage !== ""
            compact: true
            icon: "refresh"
            text: I18n.t("Перезапустить AngelOS", "Restart AngelOS")
            onClicked: Quickshell.execDetached([Quickshell.shellDir + "/bin/angelos", "restart"])
        }
        PxText {
            visible: !page.communityBusy && page.communityError === "" && page.communityShown.length === 0
            text: page.communityEntries.length ? I18n.t("Ничего не найдено.", "No matching plugins.") : I18n.t("Каталог пуст. Нажми «Обновить каталог».", "Catalog is empty. Press Refresh catalog.")
            dim: true
        }
        Repeater {
            model: page.communityShown
            PxBox {
                id: communityCard
                required property var modelData
                readonly property var installed: page.installedCommunity(modelData.id)
                readonly property bool canUpdate: !!installed && !installed.bundled && page.newerCommunity(installed.version, modelData.version)
                width: parent.width
                height: communityCardColumn.implicitHeight + Theme.u * 8
                color: Theme.face

                Column {
                    id: communityCardColumn
                    x: Theme.u * 4
                    y: Theme.u * 4
                    width: parent.width - Theme.u * 8
                    spacing: Theme.u * 2
                    PxText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        font.bold: true
                        text: communityCard.modelData.name + "  v" + communityCard.modelData.version
                    }
                    PxText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        kind: "tiny"
                        dim: true
                        text: (communityCard.modelData.author || "") + "  ·  " + (communityCard.modelData.category || "") + "  ·  " + (communityCard.modelData.tags || []).join(", ")
                    }
                    PxText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        dim: true
                        text: communityCard.modelData.description || ""
                    }
                    Flow {
                        width: parent.width
                        spacing: Theme.u * 2
                        PxButton {
                            compact: true
                            accent: !communityCard.installed
                            icon: communityCard.installed ? (communityCard.canUpdate ? "download" : "check") : "download"
                            text: communityCard.installed
                                ? (communityCard.canUpdate ? (page.confirmUpdateId === communityCard.modelData.id ? I18n.t("Точно обновить?", "Confirm update?") : I18n.t("Обновить", "Update"))
                                    : (communityCard.installed.bundled ? I18n.t("Встроенный", "Bundled") : I18n.t("Установлен", "Installed")))
                                : I18n.t("Установить", "Install")
                            enabled: !page.communityBusy && (!communityCard.installed || communityCard.canUpdate)
                            onClicked: {
                                if (communityCard.canUpdate && page.confirmUpdateId !== communityCard.modelData.id) {
                                    page.confirmUpdateId = communityCard.modelData.id;
                                    confirmReset.restart();
                                    return;
                                }
                                page.confirmUpdateId = "";
                                CommunityPluginCatalog.install(communityCard.modelData,
                                                               communityCard.canUpdate ? communityCard.installed.version : undefined);
                            }
                        }
                        PxButton {
                            visible: !!communityCard.modelData.repository
                            compact: true
                            icon: "external"
                            text: I18n.t("Исходники", "Source")
                            onClicked: Quickshell.execDetached(["xdg-open", communityCard.modelData.repository])
                        }
                        PxButton {
                            compact: true
                            icon: "info"
                            text: I18n.t("Подробности", "Details")
                            onClicked: page.confirmId = page.confirmId === "details:" + communityCard.modelData.id ? "" : "details:" + communityCard.modelData.id
                        }
                    }
                    PxText {
                        visible: page.confirmId === "details:" + communityCard.modelData.id
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: I18n.t("Лицензия: ", "License: ") + (communityCard.modelData.license || "—")
                            + I18n.t("\nЗависимости: ", "\nDependencies: ") + (communityCard.modelData.dependencies || []).join(", ")
                            + I18n.t("\nРазрешения: ", "\nPermissions: ") + (communityCard.modelData.permissions || []).join(", ")
                            + (communityCard.installed ? I18n.t("\nУстановлена версия: ", "\nInstalled version: ") + (communityCard.installed.version || "0") : "")
                            + (communityCard.canUpdate ? I18n.t("\nСтарая версия при обновлении попадёт в корзину плагинов.", "\nUpdating moves the old version to the plugin trash.") : "")
                            + (communityCard.modelData.sha256 ? I18n.t("\nSHA-256 релиза: проверяется", "\nRelease SHA-256: checked")
                                : I18n.t("\nSHA-256 в registry отсутствует", "\nNo SHA-256 in the registry"))
                        dim: true
                    }
                }
            }
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
