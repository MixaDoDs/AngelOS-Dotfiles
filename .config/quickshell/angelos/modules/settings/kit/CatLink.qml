import QtQuick
import qs.services

// A setting that lives elsewhere (SettingLink): `page` is a tree page (or an old id), `group`
// the group on it.
CatEntry {
    kind: "link"
    property string page: ""
    property string group: ""
    readonly property string target: {
        const p = SettingsTree.page(SettingsTree.resolve(page).page);
        return p ? p.label : page;
    }
}
