pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import qs.config
import qs.services
import qs.widgets

// Two stacked images blended by the pixel transition shader.
Item {
    id: root

    required property string screenName
    readonly property var activeWs: Niri.activeWorkspace(screenName)
    readonly property string target: Wallpapers.resolve(screenName, activeWs ? activeWs.idx : 1)
    property string shown: ""
    // decoded at the screen's real pixels: Qt reads sourceSize as physical
    // pixels, so logical ones blur the picture on a scaled monitor (issue #18)
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    property real progress: 1
    // -1 = no transition; "random" picks again for every change
    property int styleIndex: Wallpapers.transitionIndex(Config.wallpaper.transition)

    function url(p) {
        const d = Wallpapers.display(p);
        return d ? (d.startsWith("/") ? "file://" + d : d) : "";
    }
    function load(img, p) {
        img.path = p;
        img.source = url(p);
    }
    // a picture too big for Qt came back as a fitted copy: show that instead
    Connections {
        target: Wallpapers
        function onFittedChanged() {
            for (const img of [fromImg, toImg])
                if (Wallpapers.fitted[img.path])
                    img.source = root.url(img.path);
        }
    }

    // pixel transition only when the picture itself is changed (settings / IPC);
    // switching workspaces swaps instantly, even with per-workspace wallpapers
    readonly property string configKey: Wallpapers.stateKey
    property bool configChanged: false
    onConfigKeyChanged: configChanged = true

    function go(path) {
        styleIndex = Qt.binding(() => Wallpapers.transitionIndex(Config.wallpaper.transition));
        // another file of the same wallpaper (day ⇄ night, the screen turned): a change too
        const variant = Wallpapers.settled && Wallpapers.sameSet(shown, path);
        const animate = (configChanged || variant) && styleIndex >= 0 && Niri.ready && shown !== "" && !Motion.still;
        configChanged = false;
        anim.stop();
        if (!animate) {
            shown = path;
            load(fromImg, path);
            load(toImg, path);
            progress = 1;
            return;
        }
        load(fromImg, shown);
        shown = path;
        load(toImg, path);
        progress = 0;
        if (toImg.status === Image.Ready)
            anim.start();
        else
            waitingForLoad = true;
    }
    property bool waitingForLoad: false

    onTargetChanged: if (target !== shown)
        Qt.callLater(() => go(target))
    Component.onCompleted: {
        shown = target;
        load(fromImg, target);
        load(toImg, target);
        configChanged = false;
    }

    NumberAnimation {
        id: anim
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: Motion.ms(Config.wallpaper.duration)
        easing.type: Easing.Linear
    }

    Image {
        id: fromImg
        property string path
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.ceil(root.width * root.dpr), Math.ceil(root.height * root.dpr))
        asynchronous: true
        cache: true
        smooth: true
        visible: false
        onStatusChanged: if (status === Image.Error)
            Wallpapers.fit(path)
    }
    Image {
        id: toImg
        property string path
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.ceil(root.width * root.dpr), Math.ceil(root.height * root.dpr))
        asynchronous: true
        cache: true
        smooth: true
        visible: false
        onStatusChanged: {
            if (status === Image.Error)
                Wallpapers.fit(path);
            else if (status === Image.Ready && root.waitingForLoad) {
                root.waitingForLoad = false;
                anim.start();
            }
        }
    }

    ShaderEffectSource {
        id: fromSrc
        textureSize: Qt.size(Math.ceil(root.width * root.dpr), Math.ceil(root.height * root.dpr))
        sourceItem: fromImg
        hideSource: true
        live: true
        visible: false
    }
    ShaderEffectSource {
        id: toSrc
        textureSize: Qt.size(Math.ceil(root.width * root.dpr), Math.ceil(root.height * root.dpr))
        sourceItem: toImg
        hideSource: true
        live: true
        visible: false
    }

    Item {
        anchors.fill: parent
        // in hell the circle lays its dark over the picture (HellLook.backdrop); heaven
        // draws the wallpaper untouched
        layer.enabled: Theme.hell
        layer.smooth: false
        layer.effect: ShaderEffect {
            readonly property var b: HellLook.backdrop || ({})
            property real dim: b.dim !== undefined ? b.dim : 0.5
            property real desat: b.desat !== undefined ? b.desat : 0.3
            property real vignette: b.vignette !== undefined ? b.vignette : 0.6
            property real cell: Theme.u * 2 * root.dpr
            property size resolution: Qt.size(root.width * root.dpr, root.height * root.dpr)
            property color tint: b.tint || Theme.hellBody
            // the circle's ambient (fog, rain, the Styx…), still but for the rare event
            readonly property var kinds: ["", "fog", "wind", "rain", "dust", "ripple", "embers", "sand", "pitch", "ice"]
            property real kind: Math.max(0, kinds.indexOf(HellLook.ambient))
            property real event: HellLook.eventTarget === -2 ? HellLook.event : 0
            property real phase: HellLook.eventTarget === -2 ? HellLook.phase : 0
            property real seed: root.screenName.length
            property color light: Theme.hellTextDim
            property color accent: Theme.hellAccent
            fragmentShader: Qt.resolvedUrl("../../shaders/hell_backdrop.frag.qsb")
        }

        ShaderEffect {
            anchors.fill: parent
            property var fromTex: fromSrc
            property var toTex: toSrc
            property real progress: root.progress
            property real maxBlock: Config.wallpaper.maxBlock
            property real style: Math.max(0, root.styleIndex)
            property size resolution: Qt.size(width, height)
            property color accent: Theme.accent
            fragmentShader: Qt.resolvedUrl("../../shaders/pixel_transition.frag.qsb")
        }

        // the picture, half alive (stars, water): over it once a transition is over
        LiveWall {
            anchors.fill: parent
            screenName: root.screenName
            path: root.shown
            picture: toSrc
            allowed: root.progress >= 1 && !anim.running
        }
    }
}
