pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config
import qs.services

// serp skin (after frostpix's pc-kit): the backdrop Serpantinum's liquid glass refracts. A Wayland client
// can't see what lies behind its surface, so — as Serpantinum's WallpaperBlur does — every
// layer-shell window keeps its own copy of the WALLPAPER, laid out in SCREEN space: the file the
// background really draws on this screen's active desk (a scene's day or night still; hell's own
// pictures in hell, darkened like modules/background/WallpaperView's hell layer), at half the
// screen's size, a light frost on it, mipmapped (the shader blurs by mip level). One per window,
// at the bottom; it draws nothing itself. The SGlass surfaces of the window sample `texture`.
// The texture is rendered only when the picture, the screen or the frost changes (`live` for a
// moment, then frozen); with the glass off the picture isn't even loaded.
Item {
    id: root

    // ---- set by the window (all optional) ----
    readonly property var win: QsWindow.window
    property string screenName: win && win.screen ? win.screen.name : ""
    // where the window's top-left corner stands on the screen, logical px. By default from the
    // layer-shell anchors and margins (as bar/parts/Tasks.report()); set it yourself when another
    // window's exclusive zone pushes this one off its edge
    property point origin: autoOrigin
    property bool active: Serp.glassOn
    property real blur: 0.15          // the frost laid on the picture before the glass (0..1, MultiEffect)
    property real resolution: 0.5     // of the screen, as Serpantinum's liquid backdrop

    // ---- for SGlass ----
    readonly property Item texture: tex
    readonly property size textureSize: Qt.size(texW, texH)
    readonly property Item screenSpace: frame    // an item covering the screen: map into it for screen px
    readonly property bool ready: active && pic.status === Image.Ready

    readonly property var screenObj: win && win.screen && win.screen.name === screenName ? win.screen : Quickshell.screens.find(s => s.name === screenName) || null
    readonly property real screenW: screenObj ? screenObj.width : 1
    readonly property real screenH: screenObj ? screenObj.height : 1
    readonly property int texW: Math.max(1, Math.round(screenW * resolution))
    readonly property int texH: Math.max(1, Math.round(screenH * resolution))

    readonly property point autoOrigin: {
        const w = root.win;
        if (!w)
            return Qt.point(0, 0);
        const a = w.anchors || {}, m = w.margins || {};
        const wx = a.left ? (m.left || 0) : a.right ? screenW - w.width - (m.right || 0) : (screenW - w.width) / 2;
        const wy = a.top ? (m.top || 0) : a.bottom ? screenH - w.height - (m.bottom || 0) : (screenH - w.height) / 2;
        return Qt.point(wx, wy);
    }

    // ---- the picture: what the background shows (modules/background/WallpaperView) ----
    property int tick: 0
    Timer {
        // a scene's hour: every 10 minutes, every 2 while the dusk or the dawn is going
        interval: (root.twMix > 0 && root.twMix < 1) || (root.nightMix > 0 && root.nightMix < 1) ? 2 * 60 * 1000 : 10 * 60 * 1000
        running: root.active
        repeat: true
        onTriggered: root.tick++
    }
    readonly property string path: {
        if (!active || !screenName)
            return "";
        const ws = Niri.activeWorkspace(screenName);
        return Wallpapers.resolve(screenName, ws ? ws.idx : 1);
    }
    // a layered scene's hours, as the desktop draws them (widgets/SceneWall): the day, its dusk or
    // dawn over it by twMix (scripts/scene-twilight.py), the night over both by nightMix. Wallpapers.still
    // knows only day | night, so the glass stayed on the day picture all through the dusk (too light)
    function fileUrl(d) {
        return d ? (d.startsWith("/") ? "file://" + d : d) : "";
    }
    readonly property string sceneDir: path ? Wallpapers.sceneOf(path) : ""
    readonly property real nightMix: {
        tick;
        return sceneDir && Wallpapers.nightOf(path) ? Wallpapers.nightMix(path, new Date()) : 0;
    }
    readonly property real twMix: {
        tick;
        return sceneDir && Wallpapers.nightOf(path) ? Wallpapers.twilightMix(path, new Date()) : 0;
    }
    readonly property string twKind: {
        tick;
        return Wallpapers.twilightKind(new Date());
    }
    readonly property string url: {
        tick;
        if (sceneDir && Wallpapers.nightOf(path))
            return fileUrl(Wallpapers.display(path));
        return fileUrl(path ? Wallpapers.still(path, new Date()) : "");
    }
    readonly property string twUrl: sceneDir && twMix > 0 && nightMix < 1 ? "file://" + sceneDir + "/logical/" + twKind + "/neutral-656x376.png" : ""
    readonly property string nightUrl: sceneDir && nightMix > 0 ? fileUrl(Wallpapers.nightOf(path)) : ""
    // a layered scene's still: its neutral frame cut to the view SceneWall shows (margin 8)
    readonly property var sceneRect: {
        const m = path && Wallpapers.sceneOf(path) ? Wallpapers.meta[path] : null;
        return m && m.w ? Qt.rect(8, 8, m.w - 16, m.h - 16) : null;
    }
    readonly property bool hell: Theme.hell
    readonly property var hellLook: HellLook.backdrop || ({})

    visible: active
    width: 0
    height: 0

    Item {
        id: frame
        x: -root.origin.x
        y: -root.origin.y
        width: root.screenW
        height: root.screenH
        visible: false

        // the hours stacked (the stack is what the texture takes)
        Item {
            id: stack
            width: root.texW
            height: root.texH
            visible: false
        Image {
            id: pic
            width: root.texW
            height: root.texH
            fillMode: Image.PreserveAspectCrop
            sourceSize: root.sceneRect ? undefined : Qt.size(root.texW, root.texH)
            sourceClipRect: root.sceneRect || Qt.rect(0, 0, 0, 0)
            asynchronous: true
            cache: true
            smooth: true
            source: root.url
            onStatusChanged: {
                if (status === Image.Error && root.path)
                    Wallpapers.fit(root.path);
                else if (status === Image.Ready)
                    root.refresh();
            }
        }
        Repeater {
            model: [
                {
                    "u": root.twUrl,
                    "o": root.twMix
                },
                {
                    "u": root.nightUrl,
                    "o": root.nightMix
                }
            ]
            Image {
                required property var modelData
                width: root.texW
                height: root.texH
                visible: modelData.u !== "" && modelData.o > 0
                opacity: modelData.o
                fillMode: Image.PreserveAspectCrop
                sourceSize: root.sceneRect ? undefined : Qt.size(root.texW, root.texH)
                sourceClipRect: root.sceneRect || Qt.rect(0, 0, 0, 0)
                asynchronous: true
                cache: true
                smooth: true
                source: modelData.u
                onStatusChanged: if (status === Image.Ready)
                    root.refresh()
            }
        }
        }

        MultiEffect {
            id: fx
            width: root.texW
            height: root.texH
            visible: false
            source: root.active ? stack : null
            autoPaddingEnabled: false
            blurEnabled: root.blur > 0
            blurMax: 16
            blur: Math.min(1, root.blur)
            // hell: the circle's dark over the picture (HellLook.backdrop), roughly
            saturation: root.hell ? -(root.hellLook.desat !== undefined ? root.hellLook.desat : 0.3) : 0
            brightness: root.hell ? -0.6 * (root.hellLook.dim !== undefined ? root.hellLook.dim : 0.5) : 0
        }
    }

    ShaderEffectSource {
        id: tex
        width: root.texW
        height: root.texH
        visible: false
        sourceItem: root.active ? (root.blur > 0 || root.hell ? fx : stack) : null
        textureSize: Qt.size(root.texW, root.texH)
        mipmap: true
        smooth: true
        hideSource: false
        format: ShaderEffectSource.RGBA8
        // rendered while the picture settles (the blur's own passes land a frame later), then frozen
        live: settle.running
    }
    Timer {
        id: settle
        interval: 400
        onTriggered: {
            tex.scheduleUpdate();
            again.n = 0;
            again.restart();
        }
    }
    // and twice more a little later: a 4K picture still decoding, or the blur's passes a frame behind,
    // froze a black texture once (the wallpaper turned to its night still, 2026-11-13)
    Timer {
        id: again
        property int n: 0
        interval: n === 0 ? 1200 : 3000
        onTriggered: {
            tex.scheduleUpdate();
            if (++n < 2)
                restart();
        }
    }
    function refresh() {
        if (root.active)
            settle.restart();
    }
    // the window shown again (a panel reopened): look once more
    readonly property bool shownNow: !!win && win.visible
    onShownNowChanged: if (shownNow)
        refresh()
    onUrlChanged: refresh()
    onTwMixChanged: refresh()
    onNightMixChanged: refresh()
    onTexWChanged: refresh()
    onTexHChanged: refresh()
    onBlurChanged: refresh()
    onHellChanged: refresh()
    onHellLookChanged: refresh()
    onActiveChanged: refresh()
}
