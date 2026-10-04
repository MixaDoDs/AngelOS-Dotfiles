pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// A settings page of the tree (services/SettingsTree, modules/settings/tree.json): its
// heading, then its parts — page files shown inside it (PxPage.embedded) with only the
// groups the tree gives this page. The settings keep their own code where they always were;
// the tree only says where they show. The parts' sub-pages (advanced groups) are this
// page's ("Title ›" links, or cards that open in place in the Windows 11 look), "Reset this
// page" resets what its groups change (SettingsKeys.keysOf).
PxPage {
    id: root

    property string pageKey: ""
    readonly property var entry: SettingsTree.page(pageKey)
    readonly property var parts: SettingsTree.partsOf(pageKey)
    pageId: pageKey
    heading: entry ? entry.label : ""
    // a page that is one whole page file says what that file said about itself
    readonly property var wholePart: parts.length === 1 && parts[0].loose && partRepeater.count > 0 ? partRepeater.itemAt(0) : null
    subtitle: wholePart && wholePart.item ? wholePart.item.subtitle : ""

    Repeater {
        id: partRepeater
        model: root.parts
        Loader {
            id: part
            required property var modelData
            width: parent.width
            function load() {
                setSource(modelData.file, {
                    "embedded": true,
                    "only": modelData.only,
                    "loose": modelData.loose,
                    "partOf": root.pageKey,
                    // one group is the whole page: shown open, not as a sub-page of itself;
                    // and the groups the tree opens ("open" — a page of sub-pages only)
                    "unfold": root.parts.length === 1 && modelData.only.length === 1 ? modelData.only : (root.entry && root.entry.open || []).filter(b => b.split("/")[0] === modelData.src).map(b => b.split("/")[1])
                });
            }
            Component.onCompleted: load()
        }
    }
}
