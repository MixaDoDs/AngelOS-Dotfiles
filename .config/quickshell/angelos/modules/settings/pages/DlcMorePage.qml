pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Simple settings view: every section as a tile, in the sidebar's groups, in the settings
// skin (Config.settingsUi.skin). One tile size for all of them, on an even grid.
PxPage {
    id: page

    readonly property string skin: ["classic", "windose", "stream"].includes(Config.settingsUi.skin) ? Config.settingsUi.skin : "classic"
    // Windose: on lilac checks the heading is a pink sticker colour, the subtitle full ink
    headingColor: skin === "windose" ? Theme.windoseTitle : skin === "stream" ? Theme.streamLive : Theme.dark ? Theme.accent : Theme.edge
    subtitleColor: Theme.textDim
    heading: I18n.t("Все разделы", "All sections")
    subtitle: I18n.t("То же, что в боковой панели, только плитками.", "The same as in the sidebar, as tiles.")

    Repeater {
        model: Shell.settingsView ? Shell.settingsView.visibleGroups : []
        PxGroup {
            name: "tiles"
            id: grp
            required property var modelData
            width: page.innerWidth
            title: modelData.title
            Grid {
                id: grid
                width: parent.width
                spacing: Theme.u * (page.skin === "windose" ? 5 : 4)
                columns: Math.max(2, Math.floor((width + spacing) / (Theme.u * 78 + spacing)))
                readonly property real tileW: Math.floor((width - (columns - 1) * spacing) / columns)
                readonly property real tileH: Theme.u * (page.skin === "windose" ? 50 : page.skin === "stream" ? 26 : 36)
                Repeater {
                    model: grp.modelData.pages
                    SkinTile {
                        required property var modelData
                        required property int index
                        skin: page.skin
                        tint: index
                        width: grid.tileW
                        height: grid.tileH
                        small: true
                        icon: modelData.icon
                        text: modelData.label
                        onClicked: Shell.settingsPage = modelData.id
                    }
                }
            }
        }
    }
}
