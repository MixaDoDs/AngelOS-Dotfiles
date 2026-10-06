import QtQuick
import qs.config
import qs.services

// "plugins <name, author, description or tag>" in the launcher: install, update or remove a
// plugin of the community catalog (services/CommunityPlugins does the work, the same as
// Settings → Plugins). Removing sends a plugin to the trash, never for good.
Item {
    id: root
    visible: false
    width: 0
    height: 0

    property var plugin
    property string pluginId
    readonly property string prefix: "plugins"
    readonly property bool global: false
    signal changed

    Connections {
        target: CommunityPlugins
        function onEntriesChanged() {
            root.changed();
        }
        function onBusyChanged() {
            root.changed();
        }
    }
    Connections {
        target: Plugins
        function onPluginsChanged() {
            root.changed();
        }
    }

    function query(text, prefixed) {
        if (!CommunityPlugins.entries.length) {
            if (!CommunityPlugins.busy)
                CommunityPlugins.refresh();
            return [{
                    "id": "settings",
                    "title": CommunityPlugins.error ? I18n.t("Каталог недоступен", "Catalog unavailable") : I18n.t("Загружаю каталог плагинов…", "Loading the plugin catalog…"),
                    "subtitle": I18n.t("Enter — открыть Настройки → Плагины", "Enter opens Settings → Plugins"),
                    "icon": "package",
                    "score": 1
                }];
        }
        const q = String(text || "").trim().toLowerCase();
        const out = [];
        for (const e of CommunityPlugins.entries) {
            const hay = [e.name, e.id, e.author, e.description, e.category, ...(e.tags || [])].join(" ").toLowerCase();
            if (q && !hay.includes(q))
                continue;
            const score = q ? (String(e.name || "").toLowerCase().startsWith(q) ? 80 : 40) : 10;
            const p = CommunityPlugins.installed(e.id);
            const sub = (e.author || "") + " · v" + e.version;
            if (!p)
                out.push({"id": "install:" + e.id, "title": I18n.t("Установить: ", "Install: ") + e.name, "subtitle": sub, "icon": e.icon || "package", "score": score});
            else if (CommunityPlugins.canUpdate(e.id))
                out.push({"id": "update:" + e.id, "title": I18n.t("Обновить: ", "Update: ") + e.name, "subtitle": "v" + p.version + " → v" + e.version, "icon": e.icon || "download", "score": score + 5});
            if (p && !p.bundled && !Plugins.isCore(p) && Plugins.byId(e.id))
                out.push({"id": "remove:" + e.id, "title": I18n.t("Удалить: ", "Remove: ") + e.name, "subtitle": I18n.t("в корзину плагинов", "to the plugin trash"), "icon": "trash", "score": score - 5});
        }
        return out.slice(0, 30);
    }

    function activate(id) {
        const cut = id.indexOf(":");
        const act = cut < 0 ? id : id.slice(0, cut);
        const pid = cut < 0 ? "" : id.slice(cut + 1);
        if (act === "settings")
            Shell.openSettings("plugins");
        else if (act === "install")
            CommunityPlugins.install(CommunityPlugins.entry(pid));
        else if (act === "update")
            CommunityPlugins.update(pid);
        else if (act === "remove")
            Plugins.remove(pid);
        // the launcher stays open over the results, except for the trip to Settings
        return act !== "settings";
    }
}
