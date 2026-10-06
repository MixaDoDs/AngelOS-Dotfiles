pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Every theme has its own niri keys (scripts/keyprofile.py): the pixel theme angelOS's own,
// Golden Gate the Mac ones (⌘Q ⌘H ⌘M ⌘Tab …, tiling on Super+Alt), both the common file.
// The profile follows the theme — Settings, the setup wizard, `angelos skin`, the debug
// panel all just set Config.settingsUi.skin — in one step: the selector cfg/keybinds.kdl is
// validated with niri and swapped by a rename, rolled back if niri refuses it, so there is
// never a moment with half of one theme's keys and half of the other's. "Mac keys" off
// (Config.mac.keys, offered, never imposed) keeps Golden Gate on the pixel profile.
// Leaving Golden Gate also brings back what only it can hold away: minimized and hidden
// windows come to the desktop in front (services/Minimize).
Singleton {
    id: root

    readonly property bool live: Config.ready && !Shell.dev && Quickshell.env("ANGELOS_TEST") !== "1"
    readonly property string want: GoldenGate.chosen && Config.mac.keys ? "macos" : "pixel"
    property string profile: ""             // the one in front (keyprofile.py status)
    property string error: ""
    readonly property bool busy: switcher.running

    function apply(p) {
        if (!live)
            return;
        if (switcher.running) {
            _again = true;
            return;
        }
        error = "";
        switcher.command = ["python3", Quickshell.shellDir + "/scripts/keyprofile.py", "apply", p || want];
        switcher.running = true;
    }
    property bool _again: false
    // a quick back-and-forth of the theme settles on the last one; at start Config.ready turns
    // true a moment before the file's values are in
    Timer {
        id: settle
        interval: 150
        onTriggered: root.apply(root.want)
    }
    onWantChanged: if (live)
        settle.restart()
    onLiveChanged: if (live)
        startSettle.restart()
    Timer {
        id: startSettle
        interval: 1000
        onTriggered: root.apply(root.want)
    }

    Process {
        id: switcher
        stdout: StdioCollector {
            id: out
        }
        onExited: code => {
            try {
                const r = JSON.parse(out.text);
                if (r.error) {
                    root.error = r.error;
                    console.warn("angelOS keys: the", root.want, "profile was refused, the keys stay as they were:", r.error);
                    Quickshell.execDetached(["notify-send", "-a", "angelOS", "-i", "dialog-warning", I18n.t("Горячие клавиши темы не переключились", "The theme's shortcuts did not switch"), r.error.slice(-300)]);
                } else {
                    root.profile = r.profile;
                    if (r.changed)
                        Keybinds.refresh();
                }
            } catch (e) {
                root.error = String(e);
            }
            if (root._again) {
                root._again = false;
                root.apply(root.want);
            }
        }
    }
}
