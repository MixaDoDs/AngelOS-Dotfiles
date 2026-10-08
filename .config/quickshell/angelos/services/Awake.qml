pragma Singleton

import QtQuick
import Quickshell
import qs.config

// "Do not sleep": while on, niri does not count the system idle — no idle screen, lock,
// screens off or sleep (a Wayland idle inhibitor held by modules/idle/AwakeKeeper). On by
// hand (the sidebar, the control centre, `angelos awake on`), while stream mode is on, or
// while a window fills a whole screen (a video, a game) — the last two by Settings → Lock.
Singleton {
    id: root

    property bool manual: false              // by hand; a restart forgets it, like a coffee does

    // the window that fills its screen on an active workspace (niri reports no fullscreen flag:
    // its own size against the screen's logical size); null when none
    readonly property var fullscreenWindow: {
        for (const ws of Niri.allWorkspaces) {
            if (!ws.is_active || ws.active_window_id === null || ws.active_window_id === undefined)
                continue;
            const w = Niri.windows.find(x => x.id === ws.active_window_id);
            const s = Quickshell.screens.find(x => x.name === ws.output);
            const size = w && w.layout ? w.layout.window_size : null;
            if (s && size && size[0] >= s.width && size[1] >= s.height)
                return w;
        }
        return null;
    }
    readonly property bool byStream: Config.idle.awakeStream && StreamMode.active
    readonly property bool byFullscreen: Config.idle.awakeFullscreen && fullscreenWindow !== null
    readonly property bool active: Config.ready && (manual || byStream || byFullscreen)
    // why it is on: manual | stream | fullscreen | ""
    readonly property string reason: !active ? "" : manual ? "manual" : byStream ? "stream" : "fullscreen"
    readonly property string reasonText: reason === "manual" ? I18n.t("включено вручную", "on by hand") : reason === "stream" ? I18n.t("идёт стрим", "streaming") : reason === "fullscreen" ? I18n.t("окно на весь экран: ", "full-screen window: ") + Niri.titleOf(fullscreenWindow) : ""

    function set(mode) {
        if (mode === "on")
            manual = true;
        else if (mode === "off")
            manual = false;
        else if (mode === "toggle")
            manual = !manual;
    }
}
