pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import "Engines.js" as Engines

Column {
    id: root
    property var plugin
    readonly property var links: plugin ? plugin.get("links", Engines.defaultLinks) : []
    width: parent ? parent.width : 400
    spacing: Skin.px(10)

    PxGroup {
        title: I18n.t("Поисковик", "Search engine")
        icon: "search"
        width: parent.width
        SettingRow {
            label: I18n.t("Искать через", "Search with")
            hint: I18n.t("в лаунчере: web <запрос>", "In the launcher: web <query>")
            PxCombo {
                width: Skin.px(200)
                model: Object.keys(Engines.engines).map(k => ({
                            "label": Engines.engines[k].label,
                            "value": k
                        }))
                currentValue: root.plugin ? root.plugin.get("provider", "google") : "google"
                onActivated: v => root.plugin.set("provider", v)
            }
        }
    }

    PxGroup {
        title: I18n.t("Любимые сайты", "Favorite websites")
        icon: "heart"
        width: parent.width

        Repeater {
            model: root.links
            Row {
                id: row
                required property string modelData
                required property int index
                spacing: Skin.px(6)
                PxField {
                    width: Skin.px(120)
                    text: row.modelData.split("|")[0]
                    onAccepted: root.update(row.index, text + "|" + row.modelData.split("|").slice(1).join("|"))
                }
                PxField {
                    width: Skin.px(260)
                    text: row.modelData.split("|").slice(1).join("|")
                    onAccepted: root.update(row.index, row.modelData.split("|")[0] + "|" + text)
                }
                PxButton {
                    compact: true
                    icon: "trash"
                    onClicked: root.plugin.set("links", root.links.filter((l, i) => i !== row.index))
                }
            }
        }
        Row {
            spacing: Skin.px(6)
            PxField {
                id: newName
                width: Skin.px(120)
                placeholder: I18n.t("Название", "Name")
            }
            PxField {
                id: newUrl
                width: Skin.px(260)
                placeholder: "https://…"
            }
            PxButton {
                compact: true
                icon: "plus"
                enabled: newName.text !== "" && /^https?:\/\//.test(newUrl.text)
                onClicked: {
                    root.plugin.set("links", root.links.concat([newName.text.trim() + "|" + newUrl.text.trim()]));
                    newName.text = "";
                    newUrl.text = "";
                }
            }
        }
        PxText {
            text: I18n.t("Enter в поле — сохранить правку", "Press Enter to save")
            kind: "tiny"
            dim: true
        }
    }

    function update(i, value) {
        const l = links.slice();
        l[i] = value;
        plugin.set("links", l);
    }
}
