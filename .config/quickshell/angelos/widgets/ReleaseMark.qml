pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// Which big release this is, small and see-through on the wallpaper (Settings → Wallpaper →
// Release name): «angelOS 3» over its codename, from data/release.json (Updates.release),
// so every new release names itself. It sits in a free corner: none a desktop widget covers
// (`obstacles`: the widgets' faces) and not the angel's (modules/y2k/AngelHelper stands in a
// bottom corner of her screen), off the bar's edge; Config.wallpaper.releaseMarkCorner
// pins one. Not in Golden Gate, not before the first release.
Item {
    id: root

    property Item obstacles: null           // the item the desktop widgets' faces are children of
    property string screenName: ""

    readonly property var release: Updates.release
    readonly property bool wanted: Config.wallpaper.releaseMark && !!release && !!release.number && !GoldenGate.on
    visible: wanted

    readonly property real gap: Theme.u * 6
    readonly property var corners: ["bottom-right", "bottom-left", "top-right", "top-left"]
    property string corner: "bottom-right"

    // the bar's edge is not free: the bar stands over the wallpaper there (a taskbar, the
    // dock: the thickest of them)
    function inset(side) {
        if (BarLayout.edge !== side)
            return gap;
        return (BarLayout.vertical ? Theme.u * 36 : Math.max(Theme.barHeight, Theme.fit(22) + Theme.u * 4)) + gap;
    }
    function angelAt(c) {
        if (!Angel.shown || Angel.screenName !== screenName || !c.startsWith("bottom"))
            return false;
        const left = Angel.streamer && Config.stream.streamerSide === "left";
        return c.endsWith("left") === left;
    }
    function rectAt(c) {
        const w = mark.width, h = mark.height;
        const x = c.endsWith("right") ? width - inset("right") - w : inset("left");
        const y = c.startsWith("bottom") ? height - inset("bottom") - h : inset("top");
        return Qt.rect(x, y, w, h);
    }
    function covered(r) {
        if (!obstacles)
            return false;
        const kids = obstacles.children;
        for (let i = 0; i < kids.length; i++) {
            const k = kids[i];
            if (!k.visible || k.opacity <= 0 || k.width <= 0 || k.height <= 0 || (k.width >= width && k.height >= height))
                continue;
            if (k.x < r.x + r.width + gap && r.x < k.x + k.width + gap && k.y < r.y + r.height + gap && r.y < k.y + k.height + gap)
                return true;
        }
        return false;
    }
    function place() {
        const pinned = Config.wallpaper.releaseMarkCorner;
        if (corners.includes(pinned)) {
            corner = pinned;
            return;
        }
        for (const c of corners) {
            if (!angelAt(c) && !covered(rectAt(c))) {
                corner = c;
                return;
            }
        }
        corner = corners[0];
    }
    // widgets move and come and go without telling: a look now and then is enough
    Timer {
        interval: 2500
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.place()
    }
    Connections {
        target: Config.wallpaper
        function onReleaseMarkCornerChanged() {
            root.place();
        }
    }
    onWidthChanged: place()
    onHeightChanged: place()

    readonly property rect at: rectAt(corner)

    Column {
        id: mark
        x: root.at.x
        y: root.at.y
        opacity: Config.wallpaper.releaseMarkOpacity / 100
        spacing: 0
        readonly property bool alignRight: root.corner.endsWith("right")

        Repeater {
            model: [
                {
                    "text": "angelOS " + (root.release ? root.release.number : ""),
                    "kind": "tiny"
                },
                {
                    "text": root.release && root.release.codename ? root.release.codename : "",
                    "kind": "title"
                }
            ]
            // a hard pixel shadow, no blur: readable on a light sky and a dark sea
            Item {
                id: line
                required property var modelData
                visible: modelData.text !== ""
                width: label.implicitWidth + 1
                height: label.implicitHeight + 1
                x: mark.alignRight ? mark.width - width : 0
                PxText {
                    x: 1
                    y: 1
                    kind: line.modelData.kind
                    text: line.modelData.text
                    color: "#000000"
                    opacity: 0.55
                }
                PxText {
                    id: label
                    kind: line.modelData.kind
                    text: line.modelData.text
                    color: "#ffffff"
                }
            }
        }
    }
}
