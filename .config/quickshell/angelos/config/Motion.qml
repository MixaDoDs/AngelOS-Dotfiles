pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// How much moves on screen (Settings → Appearance → Motion, the setup wizard, `angelos motion`):
// one setting instead of three (C4).
//   full   everything as designed
//   calm   accessibility: no flashes, no screen shaking, no sudden loud sounds (what the game's
//          "calm mode" was); the rest moves gently
//   off    no animations at all, an optimisation mode: the shell's (transitions, menus,
//          wallpapers, the workspace and window effects), niri's own (niri-game-mode keeps
//          `animations { off }` while this is on, as it does for a fullscreen window) and hell's
//          (the circle's splash, the quake, the glass, the flames, the weather). Heaven ⇄ hell
//          switches at once. Only the angel and the demon keep breathing: blink, wings, tail.
// The separate animation choices (menus, hearts, wallpaper transition…) stay for fine tuning;
// `off` wins over them without changing them.
Singleton {
    id: root

    readonly property var levels: ["full", "calm", "off"]
    // the laptop's eco mode (services/Power sets it): `off` for as long as it lasts, the setting
    // itself untouched
    property bool eco: false
    readonly property string chosen: levels.includes(Config.appearance.motion) ? Config.appearance.motion : "full"
    readonly property string level: eco ? "off" : chosen
    readonly property bool calm: level !== "full"
    readonly property bool still: level === "off"
    // an animation's length: nothing while `off`
    function ms(duration) {
        return still ? 0 : duration;
    }
    function set(v) {
        if (!levels.includes(v))
            return "full | calm | off";
        Config.appearance.motion = v;
        return v;
    }

    // the game's old "calm mode" (Config.game.calm) became `calm` here, once
    Connections {
        target: Config
        function onReadyChanged() {
            root.migrate();
        }
    }
    Component.onCompleted: migrate()
    function migrate() {
        if (!Config.ready || !Config.game || !Config.game.calm)
            return;
        if (level === "full")
            Config.appearance.motion = "calm";
        Config.game.calm = false;
    }

    // niri's animations: niri-game-mode is the one that writes them (cfg/game-mode.kdl); it
    // reads this setting, a run now applies it (the watching service keeps it)
    onStillChanged: if (Config.ready)
        niri.running = true
    Process {
        id: niri
        command: ["sh", "-c", "command -v niri-game-mode >/dev/null && exec niri-game-mode >/dev/null 2>&1; exit 0"]
    }
}
