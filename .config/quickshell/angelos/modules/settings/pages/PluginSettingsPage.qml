import QtQuick
import qs.config
import qs.services
import qs.widgets

// Hosts a plugin's own settings component.
PxPage {
    id: page
    objectName: plugin ? "plugin-settings:" + plugin.id : "plugin-settings:missing"

    readonly property string loadedPlugin: loader.item && loader.item.plugin ? loader.item.plugin.id : ""
    readonly property var plugin: Plugins.byId(page.nav.settingsPage.slice(7))
    heading: plugin ? I18n.label(plugin.name) : I18n.t("Плагин", "Plugin")
    subtitle: plugin ? I18n.label(plugin.description || "") : I18n.t("плагин не найден", "Plugin not found")

    Loader {
        id: loader
        objectName: "plugin-settings-loader"
        width: parent.width
        height: item ? item.implicitHeight : 0
        function reloadPlugin() {
            const p = page.plugin;
            if (!p) {
                source = "";
                return;
            }
            source = "";
            Qt.callLater(() => {
                if (page.plugin === p)
                    setSource(Plugins.url(p, p.settings), {
                        "plugin": Plugins.context(p)
                    });
            });
        }
        Component.onCompleted: reloadPlugin()
        // changed by Plugin Studio while open: a new load path
        readonly property string src: page.plugin && page.plugin.settings ? Plugins.url(page.plugin, page.plugin.settings) : ""
        onSrcChanged: if (item)
            reloadPlugin()
        Connections {
            target: page
            function onPluginChanged() {
                loader.reloadPlugin();
            }
        }
    }
    PxText {
        visible: loader.status === Loader.Error
        text: I18n.t("не удалось загрузить ", "Could not load ") + (page.plugin ? page.plugin.settings : "") + I18n.t(" — смотри лог quickshell", " — see the Quickshell log")
        color: Theme.danger
    }
}
