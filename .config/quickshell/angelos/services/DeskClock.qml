pragma Singleton

import QtQuick
import Quickshell
import qs.config

// One clock for what moves on the desk: the live wallpaper's scene (widgets/LiveWall) and the
// music spectrum (modules/desktop/MusicSpectrum) share their screen's wallpaper window, so two
// clocks out of phase drew a frame for each — 24 + 30 a second on a 200 Hz screen (angelos perf:
// 46 frames a second instead of 24). On one clock the window draws once a tick: the scene at
// Config.wallpaper.liveFps, and while a spectrum is live at least the spectrum's 30. On a
// laptop's battery never more than 24 (#60): the window holds every desktop widget too, so the
// scene's «Monitor» (liveFps 0, every frame of a 144 Hz screen) and anything above 24 run at 24,
// and a spectrum doesn't lift the clock past it either (its bars wait one tick longer).
//   DeskClock.sceneFps         the scene's rate after the battery cap (0 = every frame)
//   DeskClock.walls++ / --     a live wallpaper on the timer (sceneFps > 0) is running
//   DeskClock.spectra++ / --   a spectrum is live
//   onTick: dt                 seconds since the last tick
Singleton {
    id: root

    property int walls: 0
    property int spectra: 0
    readonly property int spectrumFps: 30
    readonly property int batteryFps: 24
    // a laptop on its battery (the self-test sets it by hand)
    property bool battery: Power.discharging
    readonly property int sceneFps: battery && (Config.wallpaper.liveFps <= 0 || Config.wallpaper.liveFps > batteryFps) ? batteryFps : Config.wallpaper.liveFps
    readonly property int fps: Math.max(walls > 0 ? sceneFps : 0, spectra > 0 ? (battery ? Math.min(spectrumFps, batteryFps) : spectrumFps) : 0)
    signal tick(real dt)

    Timer {
        interval: Math.round(1000 / Math.max(1, root.fps))
        repeat: true
        running: root.fps > 0
        onTriggered: root.tick(interval / 1000)
    }
}
