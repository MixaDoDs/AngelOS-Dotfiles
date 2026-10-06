import QtQuick

// Where one more Settings window is (Shell.newSettingsWindow). The main window keeps its place in
// Shell under the same three names, so a view or a page reads either one the same way
// (Shell.settingsNavFor).
QtObject {
    property bool settingsOpen: true
    property string settingsPage: "home"
    // a sub-page of it: one of its "advanced" groups opened on its own
    property string settingsSub: ""
    onSettingsPageChanged: settingsSub = ""
}
