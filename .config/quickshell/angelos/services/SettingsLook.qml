pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config

// Which look the Settings window opens in: the Windows 11 view (views/Win11View.qml, the
// default while P5 is being redone) or the P5 window over the desk (modules/settings/p5) —
// Config.settingsUi.look, Settings → Appearance → «Settings window look», `angelos settingsView`.
// ANGELOS_SETTINGS_OLD=1 is the way out when P5 won't open: it wins over the setting.
// Taken when the window opens, not bound live: switched inside an open P5 overlay, the overlay
// would go and a window come up under the pointer — the new look comes with the next opening.
// Golden Gate and hell's dresses keep a look of their own (SettingsView.mac / hellDress).
Singleton {
    id: root

    readonly property string picked: Quickshell.env("ANGELOS_SETTINGS_OLD") === "1" ? "win11" : Config.settingsUi.look === "p5" ? "p5" : "win11"
    property string look: "win11"
    readonly property bool p5: look === "p5"
    // the P5 look opens over the whole desktop (SettingsOverlay); Golden Gate and hell's dresses
    // keep a window (the same exceptions as SettingsView.p5)
    readonly property bool overDesk: p5 && Config.settingsUi.skin !== "goldengate" && !(Angel.demon && HellLook.settingsPick !== "")

    function take() {
        if (!Shell.settingsOpen)
            look = picked;
    }
    // asked once (SettingsLookPrompt): the answer opens Settings again in the look picked
    function choose(v) {
        Config.settingsUi.look = v;
        Config.settingsUi.lookAsked = true;
        if (v === look)
            return;
        const page = Shell.settingsPage, sub = Shell.settingsSub;
        Shell.settingsOpen = false;
        look = picked;
        Qt.callLater(() => {
            Shell.settingsPage = page;
            Shell.settingsSub = sub;
            Shell.settingsOpen = true;
        });
    }

    onPickedChanged: take()
    Component.onCompleted: take()
    Connections {
        target: Shell
        function onSettingsOpenChanged() {
            root.take();
        }
    }
}
