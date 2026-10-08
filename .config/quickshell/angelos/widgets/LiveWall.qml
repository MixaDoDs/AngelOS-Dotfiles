pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// The wallpaper, half alive (modules/background/WallpaperView; Settings → Wallpaper shows it small) (services/LiveWalls, shaders/live_wall.frag): drawn over the
// picture once its transition is over; fades in, gone at once when the picture changes.
// The clock stops while nobody sees the screen (locked, a fullscreen window) and with the
// stream's effects off on a streamed screen.
ShaderEffect {
    id: root

    required property string screenName
    property string path: ""
    property var picture: null              // the shown picture as a texture (WallpaperView)
    property bool allowed: true             // false while a transition runs

    readonly property var fx: LiveWalls.effective(path)
    readonly property bool wanted: LiveWalls.on && !!fx && fx.alive && !Theme.hell && StreamMode.effectsOn(screenName)
    readonly property bool maskCurrent: maskImg.status === Image.Ready && maskUrl !== "" && maskImg.source.toString() === maskUrl
    readonly property bool ready: wanted && allowed && maskCurrent
    readonly property string maskUrl: {
        const i = LiveWalls.info(path);
        return i && i.mask ? "file://" + i.mask : "";
    }
    onPathChanged: LiveWalls.request(path)
    Component.onCompleted: LiveWalls.request(path)

    property real fade: ready ? 1 : 0
    Behavior on fade {
        enabled: root.allowed
        NumberAnimation {
            duration: 1400
            easing.type: Easing.InOutSine
        }
    }
    // another picture: off until its mask is there (no fading the old one's over it)
    visible: allowed && maskCurrent && fade > 0

    property real time: 0
    // Config.wallpaper.liveFps: 12 / 24 / 60 a second, or 0 — every frame of the screen
    Timer {
        interval: Math.round(1000 / Math.max(1, Config.wallpaper.liveFps))
        repeat: true
        running: Config.wallpaper.liveFps > 0 && root.visible && !Shell.hiddenScreen(root.screenName)
        onTriggered: root.time += interval / 1000
    }
    FrameAnimation {
        running: Config.wallpaper.liveFps <= 0 && root.visible && !Shell.hiddenScreen(root.screenName)
        onTriggered: root.time += Math.min(frameTime, 0.1)
    }

    Image {
        id: maskImg
        source: root.maskUrl
        visible: false
        smooth: false
        mipmap: false
        cache: false
        asynchronous: true
    }

    readonly property var info: LiveWalls.info(path) || ({})
    property var source: picture
    property var mask: maskImg
    property real strength: Config.wallpaper.liveStrength / 100 * fade
    property real night: fx ? fx.night : 0
    property real axis: fx ? fx.axis : 0.65
    property real mirror: fx && fx.mirror ? 1 : 0
    property real skyMode: fx ? fx.skyMode : 2
    property real waterMode: fx ? fx.waterMode : 2
    property real stars: Config.wallpaper.liveStars ? 1 : 0
    property real meteors: Config.wallpaper.liveMeteors ? 1 : 0
    property real water: Config.wallpaper.liveWater ? 1 : 0
    property real lights: Config.wallpaper.liveLights ? 1 : 0
    property real pixelArt: info.pixelArt ? 1 : 0
    property real seed: screenName.length * 7.13
    property size resolution: Qt.size(width, height)
    property size imgSize: info.size ? Qt.size(info.size[0], info.size[1]) : Qt.size(width, height)
    property vector4d grid: info.grid ? Qt.vector4d(info.grid[0], info.grid[1], info.grid[2], info.grid[3]) : Qt.vector4d(1, 1, 0, 0)
    fragmentShader: Qt.resolvedUrl("../shaders/live_wall.frag.qsb")
}
