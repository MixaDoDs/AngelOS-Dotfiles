import QtQuick
import qs.config
import qs.services

// A row that leads to a setting living elsewhere: every setting is in one place in the
// settings tree (modules/settings/tree.json), the others link to it. `page` is a tree page
// (or an old page id, SettingsTree.resolve), `group` the group's name on it to scroll to.
SettingRow {
    id: root

    property string page: ""
    property string group: ""
    // where it leads, for the button: the page's name
    readonly property string target: {
        const p = SettingsTree.page(SettingsTree.resolve(page).page);
        return p ? p.label : page;
    }

    PxButton {
        compact: true
        text: root.target + " ›"
        onClicked: {
            Shell.openSettings(root.page);
            if (root.group && Shell.settingsView)
                Shell.settingsView.showGroup(root.group);
        }
    }
}
