pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import "../../../widgets/MacIcons.js" as MacIcons

// Community Plugins — angelOS's one place for plugins (services/CommunityPlugins): everything
// installed (bundled, from the community catalog, your own) next to the approved entries of
// the registry. Install, switch on and off, update, remove; the removed ones and a new plugin
// below. The launcher's "plugins …" does the same (plugins/community, a core plugin).
PxPage {
    id: page

    heading: I18n.t("Плагины · Community", "Plugins · Community")
    subtitle: I18n.t("Один каталог: встроенные плагины, плагины сообщества и твои собственные. Установка, включение, обновление и удаление — здесь. Плагин — папка ~/.config/angelos/plugins/<id>/ с manifest.json (docs/PLUGINS.md).", "One catalog: bundled plugins, community plugins and your own. Install, enable, update and remove them here. A plugin is a folder ~/.config/angelos/plugins/<id>/ with manifest.json (docs/PLUGINS.md).")

    property string createLog: ""
    property string removeLog: ""
    property string confirmId: ""           // the card whose bin was clicked once ("details:<id>" — its details open)
    property string confirmUpdateId: ""
    property string search: ""
    property string filter: "all"           // all | installed | updates | available
    readonly property var updateIds: CommunityPlugins.updates.map(e => e.id)
    function matches(o) {
        const q = search.trim().toLowerCase();
        if (!q)
            return true;
        return [I18n.label(o.name), o.id, o.author || "", I18n.label(o.description || ""), o.category || "", ...(o.tags || [])].join(" ").toLowerCase().includes(q);
    }
    // installed ones (with their catalog entry, if any), then the catalog's not installed ones
    readonly property var installedShown: (filter === "available" ? [] : Plugins.plugins).filter(p => matches(p) && (filter !== "updates" || updateIds.includes(p.id)))
    readonly property var availableShown: (filter === "all" || filter === "available" ? CommunityPlugins.entries : []).filter(e => !CommunityPlugins.installed(e.id) && matches(e))
    function capabilities(p) {
        return [p.menu ? I18n.t("ПКМ-меню", "menu") : "", p.menuComponent ? I18n.t("меню (QML)", "menu (QML)") : "", p.barWidget ? I18n.t("панель", "bar") : "", p.desktopWidget ? I18n.t("рабочий стол", "desktop") : "", p.launcher ? I18n.t("лаунчер", "launcher") : "", p.main ? I18n.t("сервис", "service") : "", p.settings ? I18n.t("настройки", "settings") : ""].filter(s => s).join(" · ");
    }
    function originText(p) {
        if (Plugins.isCore(p))
            return I18n.t("часть angelOS", "part of angelOS");
        const o = CommunityPlugins.origin(p);
        return o === "bundled" ? I18n.t("встроенный", "bundled") : o === "community" ? I18n.t("из каталога", "from the catalog") : I18n.t("свой", "your own");
    }
    Component.onCompleted: if (Quickshell.env("ANGELOS_TEST") !== "1" && !CommunityPlugins.entries.length) CommunityPlugins.refresh()
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
        title: I18n.t("Каталог", "Catalog")
        icon: "package"
        width: parent.width

        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: I18n.t("Каталог — только одобренные плагины из официального registry. Плагины работают с твоими правами; без SHA-256 в записи registry неизменность архива не подтверждена. Перед обновлением старая версия сохраняется, и если новая не загрузится, angelOS сам вернёт прежнюю.", "The catalog holds only approved plugins of the official registry. Plugins run with your user permissions; without a SHA-256 in the registry the archive cannot be verified. Before an update the old version is saved, and if the new one does not load angelOS puts the old one back by itself.")
        }
        PxField {
            width: parent.width
            icon: "search"
            placeholder: I18n.t("Поиск по названию, автору, описанию, тегам", "Search name, author, description, tags")
            text: page.search
            onEdited: page.search = text
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 2
            Repeater {
                model: [
                    {key: "all", ru: "Все", en: "All"},
                    {key: "installed", ru: "Установленные", en: "Installed"},
                    {key: "updates", ru: "Обновления", en: "Updates"},
                    {key: "available", ru: "Доступные", en: "Available"}
                ]
                PxButton {
                    required property var modelData
                    compact: true
                    text: I18n.label({ru: modelData.ru, en: modelData.en}) + (modelData.key === "updates" && page.updateIds.length ? " (" + page.updateIds.length + ")" : "")
                    checked: page.filter === modelData.key
                    onClicked: page.filter = modelData.key
                }
            }
        }
        Flow {
            width: parent.width
            spacing: Theme.u * 3
            PxButton {
                icon: "refresh"
                text: I18n.t("Проверить обновления", "Check for updates")
                enabled: !CommunityPlugins.busy
                onClicked: CommunityPlugins.refresh()
            }
            PxButton {
                visible: page.updateIds.length > 0
                accent: true
                icon: "download"
                text: I18n.t("Обновить все (", "Update all (") + page.updateIds.length + ")"
                enabled: !CommunityPlugins.busy
                onClicked: CommunityPlugins.updateAll()
            }
            PxButton {
                compact: true
                icon: "external"
                text: I18n.t("Опубликовать плагин", "Publish a plugin")
                onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/futureUnd1ground/angelos-community-registry/blob/main/CONTRIBUTING.md"])
            }
        }
        SettingRow {
            label: I18n.t("Проверять обновления раз в день", "Check for updates once a day")
            hint: I18n.t("Придёт уведомление; обновление — по кнопке в нём или здесь", "A notification tells you; update from it or here")
            PxToggle {
                checked: Config.plugins.autoCheck
                onToggled: v => Config.plugins.autoCheck = v
            }
        }
        PxText {
            visible: CommunityPlugins.busy
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: CommunityPlugins.action === "fetch" ? I18n.t("Загружаю каталог…", "Loading the catalog…")
                : CommunityPlugins.action === "rollback" ? I18n.t("Возвращаю прежнюю версию…", "Putting the earlier version back…")
                : (CommunityPlugins.action === "update" ? I18n.t("Обновляю ", "Updating ") : I18n.t("Устанавливаю ", "Installing ")) + CommunityPlugins.busyId + (CommunityPlugins.queue.length ? I18n.t(" · ещё в очереди: ", " · still queued: ") + CommunityPlugins.queue.length : "") + "…"
        }
        PxText {
            visible: CommunityPlugins.error !== ""
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.danger
            text: CommunityPlugins.error
        }
        PxText {
            visible: CommunityPlugins.message !== "" && !CommunityPlugins.busy
            width: parent.width
            wrapMode: Text.Wrap
            text: CommunityPlugins.message + " ♡"
        }
        PxText {
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            text: (CommunityPlugins.entries.length ? I18n.t("В каталоге: ", "In the catalog: ") + CommunityPlugins.entries.length : I18n.t("Каталог ещё не загружен", "The catalog is not loaded yet"))
                + (Config.plugins.lastCheck ? I18n.t(" · проверено ", " · checked ") + new Date(Config.plugins.lastCheck).toLocaleString(Qt.locale(), "d MMM HH:mm") : "")
        }
    }

    PxGroup {
        name: "installed"
        visible: page.filter !== "available"
        title: (page.filter === "updates" ? I18n.t("Обновления (", "Updates (") : I18n.t("Установленные (", "Installed (")) + page.installedShown.length + ")"
        icon: "plug"
        width: parent.width

        PxText {
            visible: page.installedShown.length === 0
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: page.filter === "updates" ? I18n.t("Все плагины свежие.", "Every plugin is up to date.") : I18n.t("Ничего не найдено.", "Nothing found.")
        }
        Repeater {
            model: page.installedShown
            // a card: the pixel box, or a rounded group in the Mac look (SkinCard, the Theme API)
            SkinCard {
                id: card
                required property var modelData
                padding: 0
                group: true
                readonly property bool on: Plugins.isEnabled(modelData)
                readonly property bool core: Plugins.isCore(modelData)
                readonly property var entry: CommunityPlugins.entry(modelData.id)
                readonly property bool canUpdate: page.updateIds.includes(modelData.id)
                width: parent.width
                height: cardCol.implicitHeight + Theme.u * 10
                pixelColor: on ? Theme.mix(Theme.face, Theme.accent, 0.08) : Theme.face

                Row {
                    x: Theme.u * 4
                    y: Theme.u * 4
                    width: parent.width - Theme.u * 8
                    spacing: Theme.u * 5
                    // its icon: the pixel one, a line icon in the Mac look
                    Item {
                        id: cardIcon
                        readonly property bool mac: Skin.mac && !Skin.hell
                        width: mac ? GoldenGate.px(24) : pxIcon.width
                        height: mac ? GoldenGate.px(24) : pxIcon.height
                        PxIcon {
                            id: pxIcon
                            visible: !cardIcon.mac
                            name: card.modelData.icon || "plug"
                            pixel: Theme.u * 2
                        }
                        MacIcon {
                            visible: cardIcon.mac
                            name: MacIcons.fromPixel(card.modelData.icon || "") || "puzzle"
                            size: GoldenGate.px(24)
                            color: Theme.accent
                        }
                    }
                    Column {
                        id: cardCol
                        width: parent.width - cardIcon.width - cardSide.width - parent.spacing * 2
                        spacing: Theme.u
                        PxText {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: I18n.label(card.modelData.name) + "  v" + (card.modelData.version || "0") + "  · " + page.originText(card.modelData)
                            font.bold: true
                        }
                        // which themes it draws (manifest "themes"), and a word when not this one
                        PluginThemeBadge {
                            plugin: card.modelData
                        }
                        PxText {
                            visible: text !== ""
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: Plugins.themeWarning(card.modelData)
                            color: Theme.danger
                            kind: "tiny"
                        }
                        PxText {
                            visible: card.canUpdate
                            text: I18n.t("Доступна версия ", "Version available: ") + (card.entry ? card.entry.version : "")
                            color: Theme.accent
                            kind: "tiny"
                        }
                        PxText {
                            visible: CommunityPlugins.failed.includes(card.modelData.id)
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: I18n.t("Последнее обновление не загрузилось — оставлена прежняя версия", "The last update did not load — the earlier version stays")
                            color: Theme.danger
                            kind: "tiny"
                        }
                        PxText {
                            width: parent.width
                            text: I18n.label(card.modelData.description || "")
                            wrapMode: Text.Wrap
                            dim: true
                        }
                        PxText {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: page.capabilities(card.modelData) + (card.modelData.author ? "  —  " + card.modelData.author : "")
                            kind: "tiny"
                            dim: true
                        }
                    }
                    Column {
                        id: cardSide
                        spacing: Theme.u * 3
                        PxToggle {
                            visible: !card.core
                            checked: card.on
                            onToggled: c => Plugins.setEnabled(card.modelData.id, c)
                        }
                        Row {
                            spacing: Theme.u * 2
                            PxButton {
                                visible: card.canUpdate
                                compact: true
                                accent: true
                                icon: "download"
                                text: page.confirmUpdateId === card.modelData.id ? I18n.t("Точно?", "Sure?") : I18n.t("Обновить", "Update")
                                enabled: !CommunityPlugins.busy
                                onClicked: {
                                    if (page.confirmUpdateId !== card.modelData.id) {
                                        page.confirmUpdateId = card.modelData.id;
                                        confirmReset.restart();
                                        return;
                                    }
                                    page.confirmUpdateId = "";
                                    CommunityPlugins.update(card.modelData.id);
                                }
                            }
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
                            PxButton {
                                visible: !!card.entry && !!card.entry.repository
                                compact: true
                                icon: "external"
                                onClicked: Quickshell.execDetached(["xdg-open", card.entry.repository])
                            }
                            // remove (a second click confirms): yours go to the trash, bundled ones hide;
                            // angelOS's own part (core) stays
                            PxButton {
                                readonly property bool asking: page.confirmId === card.modelData.id
                                visible: !card.core
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
        name: "available"
        visible: page.filter === "all" || page.filter === "available"
        title: I18n.t("Доступные в каталоге (", "Available in the catalog (") + page.availableShown.length + ")"
        icon: "download"
        width: parent.width

        PxText {
            visible: page.availableShown.length === 0 && !CommunityPlugins.busy
            width: parent.width
            wrapMode: Text.Wrap
            dim: true
            text: CommunityPlugins.entries.length ? I18n.t("Всё из каталога уже установлено (или ничего не нашлось).", "Everything in the catalog is installed (or nothing matched).") : I18n.t("Каталог пуст. Нажми «Проверить обновления».", "The catalog is empty. Press Check for updates.")
        }
        Repeater {
            model: page.availableShown
            SkinCard {
                id: offer
                required property var modelData
                padding: 0
                group: true
                width: parent.width
                height: offerCol.implicitHeight + Theme.u * 8
                pixelColor: Theme.face

                Column {
                    id: offerCol
                    x: Theme.u * 4
                    y: Theme.u * 4
                    width: parent.width - Theme.u * 8
                    spacing: Theme.u * 2
                    PxText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        font.bold: true
                        text: offer.modelData.name + "  v" + offer.modelData.version
                    }
                    PluginThemeBadge {
                        plugin: offer.modelData
                    }
                    PxText {
                        visible: text !== ""
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: Plugins.themeWarning(offer.modelData)
                        color: Theme.danger
                        kind: "tiny"
                    }
                    PxText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        kind: "tiny"
                        dim: true
                        text: [offer.modelData.author || "", offer.modelData.category || "", (offer.modelData.tags || []).join(", ")].filter(s => s).join("  ·  ")
                    }
                    PxText {
                        width: parent.width
                        wrapMode: Text.Wrap
                        dim: true
                        text: offer.modelData.description || ""
                    }
                    Flow {
                        width: parent.width
                        spacing: Theme.u * 2
                        PxButton {
                            compact: true
                            accent: true
                            icon: "download"
                            text: I18n.t("Установить", "Install")
                            enabled: !CommunityPlugins.busy
                            onClicked: CommunityPlugins.install(offer.modelData)
                        }
                        PxButton {
                            visible: !!offer.modelData.repository
                            compact: true
                            icon: "external"
                            text: I18n.t("Исходники", "Source")
                            onClicked: Quickshell.execDetached(["xdg-open", offer.modelData.repository])
                        }
                        PxButton {
                            compact: true
                            icon: "info"
                            text: I18n.t("Подробности", "Details")
                            onClicked: page.confirmId = page.confirmId === "details:" + offer.modelData.id ? "" : "details:" + offer.modelData.id
                        }
                    }
                    PxText {
                        visible: page.confirmId === "details:" + offer.modelData.id
                        width: parent.width
                        wrapMode: Text.Wrap
                        dim: true
                        text: I18n.t("Лицензия: ", "License: ") + (offer.modelData.license || "—")
                            + I18n.t("\nЗависимости: ", "\nDependencies: ") + ((offer.modelData.dependencies || []).join(", ") || "—")
                            + I18n.t("\nРазрешения: ", "\nPermissions: ") + ((offer.modelData.permissions || []).join(", ") || "—")
                            + (offer.modelData.sha256 ? I18n.t("\nSHA-256 релиза: проверяется", "\nRelease SHA-256: checked") : I18n.t("\nSHA-256 в registry отсутствует", "\nNo SHA-256 in the registry"))
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
