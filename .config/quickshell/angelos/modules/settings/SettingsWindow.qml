pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// angelOS settings: a real toplevel window with a client-drawn NGO frame.
// The main window's place is Shell itself; any other window gets a SettingsNav of its own.
FloatingWindow {
    id: win

    property var nav: Shell

    // the other windows say which page they are on (the Dock, Alt+Tab, Mission Control)
    title: Shell.appTitle + " · " + I18n.t("Настройки", "Settings") + (nav === Shell || !view.currentPage ? "" : " — " + view.currentPage.label)
    visible: nav.settingsOpen
    color: "transparent"
    implicitWidth: 1040
    implicitHeight: 740
    minimumSize: Qt.size(720, 480)
    onClosed: nav.settingsOpen = false
    onVisibleChanged: if (!visible)
        nav.settingsOpen = false

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: view.frame
    }

    SettingsView {
        id: view
        anchors.fill: parent
        hostWindow: win
        settingsNav: win.nav
    }

    RightClickGuard {}
}
