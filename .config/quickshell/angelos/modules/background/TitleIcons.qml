pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// angel-niri's stacking mode draws a window's icon in its title bar from
// $XDG_RUNTIME_DIR/angel-niri/title-icons/<app id>.png (it looks again every 2 s): the icon the
// taskbar shows (AppIcon), snapped once per app and session. Off the window's edge, unseen.
// The apps only ever get added (a ListModel, not a recomputed array): a delegate destroyed while
// its grab was still rendering crashed the shell (QQuickItemGrabResult posting to a dead item).
Item {
    id: root

    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") + "/angel-niri/title-icons"
    readonly property bool on: Niri.nativeMinimize && WindowConfig.floatAll

    function sync() {
        if (!on)
            return;
        const have = new Set();
        for (let i = 0; i < apps.count; i++)
            have.add(apps.get(i).app);
        for (const w of Niri.windows) {
            const a = w.app_id || "";
            if (a && !a.includes("/") && !have.has(a)) {
                have.add(a);
                apps.append({ "app": a });
            }
        }
    }

    x: -1000
    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", dir]);
        sync();
    }
    onOnChanged: sync()

    Connections {
        target: Niri
        function onWindowsChanged() {
            root.sync();
        }
    }

    ListModel {
        id: apps
    }

    Repeater {
        model: apps
        AppIcon {
            id: icon
            required property string app
            appId: app
            property bool saved: false
            property bool grabbing: false
            // a beat for the image to load before it is snapped; again until it is saved, one grab at a time
            Timer {
                running: !icon.saved && !icon.grabbing
                repeat: true
                interval: 500
                onTriggered: icon.grabbing = icon.grabToImage(r => {
                    icon.grabbing = false;
                    icon.saved = r.saveToFile(root.dir + "/" + icon.app + ".png");
                })
            }
        }
    }
}
