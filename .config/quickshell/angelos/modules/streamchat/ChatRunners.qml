pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import "../halo/HaloCat.js" as Kitty

// The stream's chat at the bottom of the streamed screen (services/StreamChat): whoever writes
// runs across as the Halo's little cat with the nick over it, a crown for a regular. Over the
// game too (the overlay layer), only while OBS is on air; takes no input. Above the bar, not over
// it: its start menu stays easy to see and use. The mines (services/StreamChat: a paid message
// from 100 ₽) lie on the way: a cat that runs onto one goes up with every cat within boomPx, and
// so on the wild spam's StreamChat.fuse with a cat picked at random; the blown up fly off.
PanelWindow {
    id: win

    // the first streamed screen (Settings → Stream), else the main one
    screen: Shell.screenByName((Config.stream.screens || [])[0] || "") || Shell.primaryScreen
    visible: StreamMode.onAir && Config.stream.chatRunners !== false && (StreamChat.runners.length > 0 || StreamChat.mines.length > 0 || booms > 0)
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    margins.bottom: Theme.u * 2
    // tall enough for the plate, the crown and the cat's feet (ChatRunner), and the sky over them
    // for a bang and the cats it throws
    implicitHeight: Theme.u * 96 + Theme.sizeTiny * 2
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "angelos-chat-runners"
    WlrLayershell.layer: WlrLayer.Overlay
    RightClickGuard {}

    // angel-niri (Niri.nativeMinimize): the cats only in the stream's capture, not on the monitor
    // (Settings → Stream → «Котики только зрителям»); needs the empty mask above
    readonly property bool viewersOnly: Config.stream.chatRunnersViewersOnly !== false
    function applyViewersOnly() {
        if (Niri.nativeMinimize)
            Niri.action("SetCastOnlyLayer", {
                "namespace": "angelos-chat-runners",
                "on": viewersOnly
            });
    }
    onViewersOnlyChanged: applyViewersOnly()
    Connections {
        target: Niri
        function onMinimizeProbedChanged() {
            win.applyViewersOnly();
        }
    }

    readonly property int pixel: Theme.u * 2
    readonly property int boomPx: Theme.u * 50           // «5 metres»: 100 px at the usual size
    property int booms: 0                                // bangs still on the screen
    property int blink: 0

    Repeater {
        id: cats
        // by identity: a cat that is already running keeps running when another joins
        model: ScriptModel {
            values: StreamChat.runners
        }
        ChatRunner {
            pixel: win.pixel
            lane: win.width
            y: win.height - height
        }
    }

    // the mines on the way, a light blinking on top
    Repeater {
        model: StreamChat.mines
        PxIcon {
            required property var modelData
            bitmap: ["...r...", "..###..", ".#####.", "#######"]
            palette: ({
                    "r": win.blink % 2 ? "#ff3b1f" : "#5a1a10"
                })
            pixel: win.pixel
            ink: "#3a3a46"
            x: modelData.x * win.width - width / 2
            y: win.height - height - win.pixel
        }
    }
    Timer {
        interval: 350
        repeat: true
        running: win.visible && StreamChat.mines.length > 0
        onTriggered: win.blink++
    }

    function racers() {
        const out = [];
        for (let i = 0; i < cats.count; i++) {
            const c = cats.itemAt(i);
            if (c && c.going)
                out.push(c);
        }
        return out;
    }
    function middle(c) {
        return c.x + c.catX + c.catW / 2;
    }
    // whoever stepped on a mine
    Timer {
        interval: 40
        repeat: true
        running: win.visible && StreamChat.mines.length > 0
        onTriggered: {
            const all = win.racers();
            for (const m of StreamChat.mines) {
                const mx = m.x * win.width;
                if (all.some(c => Math.abs(win.middle(c) - mx) < c.catW / 3)) {
                    win.bang(m.id, mx);
                    return;
                }
            }
        }
    }
    Connections {
        target: StreamChat
        function onFuse() {
            const on = win.racers().filter(c => win.middle(c) > 0 && win.middle(c) < win.width);
            if (on.length)
                win.bang(-1, win.middle(on[Math.floor(Math.random() * on.length)]));
        }
    }
    function bang(mine, mx) {
        const hit = win.racers().filter(c => Math.abs(win.middle(c) - mx) <= win.boomPx);
        boom.createObject(win.contentItem, {
            "x": mx,
            "y": win.height - win.pixel * 4
        });
        for (const c of hit)
            flier.createObject(win.contentItem, {
                "x": c.x + c.catX,
                "y": c.y + c.catY,
                "fur": c.fur,
                "dx": (win.middle(c) - mx) * 1.5 + (Math.random() - 0.5) * 80,
                "spin": (Math.random() < 0.5 ? -1 : 1) * (360 + Math.random() * 360)
            });
        StreamChat.hit(mine, hit.map(c => c.modelData));
    }

    // the bang: pixels flying out as far as it reaches, and its word
    Component {
        id: boom
        Item {
            id: fx
            Component.onCompleted: win.booms++
            Component.onDestruction: win.booms--
            Repeater {
                model: 28
                Rectangle {
                    required property int index
                    readonly property real a: index / 28 * 6.283 + Math.random() * 0.2
                    readonly property real r: win.boomPx * (0.5 + Math.random() * 0.5)
                    width: win.pixel * (1 + index % 3)
                    height: width
                    color: ["#fff3a0", "#ffd23f", "#ff7a1a", "#ff3b1f", "#6b6b78"][index % 5]
                    NumberAnimation on x {
                        from: 0
                        to: Math.cos(a) * r
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation on y {
                        from: 0
                        to: -Math.abs(Math.sin(a)) * r
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation on opacity {
                        from: 1
                        to: 0
                        duration: 1000
                        easing.type: Easing.InQuad
                    }
                }
            }
            PxText {
                x: -width / 2
                y: -win.boomPx * 0.7
                kind: "big"
                color: "#ffd23f"
                style: Text.Outline
                styleColor: "#3a0a00"
                text: I18n.t("БАХ!", "BOOM!")
                NumberAnimation on scale {
                    from: 0.3
                    to: 1.2
                    duration: 250
                    easing.type: Easing.OutBack
                }
                NumberAnimation on opacity {
                    from: 1
                    to: 0
                    duration: 1100
                    easing.type: Easing.InQuad
                }
            }
            Timer {
                interval: 1200
                running: true
                onTriggered: fx.destroy()
            }
        }
    }
    // a blown up cat: up, around, away
    Component {
        id: flier
        PxIcon {
            id: up
            property color fur
            property real dx: 0
            property real spin: 360
            bitmap: Kitty.run[2]
            pixel: win.pixel
            ink: fur
            Component.onCompleted: win.booms++
            Component.onDestruction: win.booms--
            ParallelAnimation {
                running: true
                NumberAnimation {
                    target: up
                    property: "x"
                    to: up.x + up.dx
                    duration: 1100
                }
                NumberAnimation {
                    target: up
                    property: "y"
                    to: up.y - win.height
                    duration: 1100
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: up
                    property: "rotation"
                    to: up.spin
                    duration: 1100
                }
                NumberAnimation {
                    target: up
                    property: "opacity"
                    to: 0
                    duration: 1100
                    easing.type: Easing.InQuad
                }
                onFinished: up.destroy()
            }
        }
    }
}
