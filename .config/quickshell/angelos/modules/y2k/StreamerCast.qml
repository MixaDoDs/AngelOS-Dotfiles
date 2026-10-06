pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import "AngelSprite.js" as AngelArt
import "DemonSprite.js" as DemonArt
import "AngelSpriteMini.js" as AngelMini
import "DemonSpriteMini.js" as DemonMini

// The angel on stream for OBS alone (services/StreamAngel, view "obs"): a window of her own,
// "angelOS · ангел для OBS", that OBS takes with "Window capture (PipeWire)" and its
// transparency. niri casts a window wherever it is, but one on a workspace nobody looks at
// gets a frame a second, so it stays on the active workspace of a screen nobody streams,
// moving along with it, see-through on the screen (its niri rule: opacity 0, window-config.py
// `streamAngel`; the cast takes it as drawn) and click-through. Out of the shell's lists (Niri).
// It is open and draws her the whole time OBS runs (or she is shown), so OBS is pointed at it
// once and always has her; Mod+Alt+A only takes her off your own screen. Here she is cut off
// at the waist like on the bar, the mouth on the mic, her words in a bubble, the fall into
// hell and the climb out.
Scope {
    id: root

    // only with its rule in niri's config: without it she'd stand in the middle of a screen
    readonly property bool wanted: StreamAngel.castOpen && StreamAngel.niriKeys
    // where it lives: a screen nobody streams (then the stream one)
    readonly property string output: {
        const off = Shell.screens.find(s => !StreamMode.onStream(s.name) && !(StreamMode.screens || []).includes(s.name));
        return off ? off.name : (StreamAngel.screen ? StreamAngel.screen.name : "");
    }
    readonly property var hostWs: Niri.allWorkspaces.find(w => w.output === root.output && w.is_active) || null
    // the window is elsewhere (opened on the focused screen, or that screen went to another
    // workspace): along to the one in view, keeping the focus where it is
    readonly property bool astray: Niri.castWindowId >= 0 && !!hostWs && Niri.castWindowWs !== hostWs.id
    onAstrayChanged: if (astray)
        Niri.action("MoveWindowToWorkspace", {
            "window_id": Niri.castWindowId,
            "reference": {
                "Id": root.hostWs.id
            },
            "focus": false
        })
    // tucked past the bottom-left corner: niri keeps a sliver of a floating window on the
    // screen (under the bar, see-through), enough for it to count as seen and draw at full rate
    function tuck() {
        if (Niri.castWindowId >= 0)
            Niri.action("MoveFloatingWindow", {
                "id": Niri.castWindowId,
                "x": {
                    "SetFixed": -100000
                },
                "y": {
                    "SetFixed": 100000
                }
            });
    }
    Connections {
        target: Niri
        function onCastWindowWsChanged() {
            if (Niri.castWindowId >= 0 && !root.astray)
                tuckLater.restart();
        }
        function onCastWindowIdChanged() {
            tuckLater.restart();
        }
    }
    Timer {
        id: tuckLater
        interval: 250
        onTriggered: root.tuck()
    }
    // closed from outside (a close key while niri had it focused): opened again
    property bool reopening: false
    Timer {
        running: root.wanted && !root.reopening && Niri.available && Niri.castWindowId < 0
        interval: 3000
        onTriggered: {
            root.reopening = true;
            Qt.callLater(() => root.reopening = false);
        }
    }

    LazyLoader {
        active: root.wanted && !root.reopening

        FloatingWindow {
            id: win

            title: Niri.castTitle
            color: "transparent"
            // nobody sees it on the screen: clicks go through
            mask: Region {}
            // her size on the bar, 1:1 for a stream as big as her screen
            readonly property real screenH: StreamAngel.screen ? StreamAngel.screen.height : 1080
            readonly property real share: Math.max(10, Math.min(50, Config.stream.streamerSize || 30))
            readonly property real waist: sprite.ready && sprite.rig.waist ? sprite.rig.waist : 0.66
            function pxFor(artH) {
                const raw = screenH * share / 100 / Math.max(1, artH * waist);
                return raw >= 3 ? Math.floor(raw) : Math.max(0.5, raw);
            }
            readonly property real artPx: sprite.ready ? sprite.px : pixelArt.exactPixel
            readonly property real cut: Math.round(sprite.height * waist)
            readonly property real bubbleRoom: Theme.u * 70
            readonly property real lift: Math.ceil(artPx * 6)
            readonly property size fixed: Qt.size(Math.ceil(Math.max(sprite.width, Theme.u * 160)), Math.ceil(bubbleRoom + lift + cut))
            implicitWidth: fixed.width
            implicitHeight: fixed.height
            minimumSize: fixed
            maximumSize: fixed

            // her, all the time OBS runs: live or not, on your screen too or not
            readonly property bool drawn: Angel.shown

            // ---- the clock, the mouth (the mic, or her own words), the bob ----
            property int tick: 0
            Timer {
                interval: 125
                running: win.drawn
                repeat: true
                onTriggered: win.tick++
            }
            readonly property bool voiceOn: StreamAngel.talking && !Angel.transition
            readonly property bool speaking: Angel.talking && !Angel.menuOpen && typed < Angel.text.length
            readonly property bool mouthOpen: (speaking && tick % 2 === 0) || (voiceOn && (StreamAngel.level > StreamAngel.threshold * 1.5 || tick % 2 === 0))
            readonly property bool blinking: !mouthOpen && tick % 29 === 0
            property real bounce: voiceOn && !Motion.still ? StreamAngel.level : 0
            Behavior on bounce {
                NumberAnimation {
                    duration: 90
                }
            }
            readonly property real voiceLift: Math.round(bounce * 4) * artPx + (Motion.still ? 0 : [0, 0, 1, 1][Math.floor(tick / 4) % 4] * artPx)
            // the swap: the one leaving sinks below the bar, the one coming climbs up out of it
            readonly property real swapDrop: !Angel.transition ? 0 : (Angel.swap < 0.5 ? Angel.swap / 0.5 : 1 - (Angel.swap - 0.5) / 0.5) * (cut + lift)

            // her words typed out like on the screen
            property int typed: 0
            Timer {
                interval: 32
                running: win.drawn && Angel.talking && win.typed < Angel.text.length
                repeat: true
                onTriggered: win.typed = Math.min(Angel.text.length, win.typed + 1)
            }
            Connections {
                target: Angel
                function onTextChanged() {
                    win.typed = 0;
                }
            }

            Item {
                id: stage
                anchors.fill: parent
                visible: win.drawn
                clip: true

                readonly property bool demonArt: Angel.demon
                readonly property string angelLook: Angel.angelLook
                readonly property string demonLook: ["glitch", "chibi", "adult", "mini"].includes(Config.y2k.demonLook) ? Config.y2k.demonLook : "glitch"
                readonly property string look: demonArt ? demonLook : angelLook
                readonly property bool mini: look === "mini"
                readonly property var art: mini ? (demonArt ? DemonMini : AngelMini) : (demonArt ? DemonArt : AngelArt)
                readonly property var frame: win.mouthOpen ? art.talk : win.blinking ? art.blink : Math.floor(win.tick / 3) % 2 ? art.down : art.up

                PxBox {
                    id: bubble
                    visible: Angel.talking && !Angel.menuOpen && !Angel.transition
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.max(0, win.bubbleRoom - height - Theme.u * 2)
                    width: Math.min(parent.width, Theme.u * 150)
                    height: words.implicitHeight + Theme.u * 8
                    hell: Angel.demon
                    color: Angel.demon ? Theme.hellPanel : Theme.menuSurface
                    ShakyText {
                        id: words
                        x: Theme.u * 4
                        y: Theme.u * 4
                        width: parent.width - Theme.u * 8
                        text: Angel.text
                        shown: win.typed
                        tick: win.tick
                        color: Angel.demon ? Theme.hellText : Theme.text
                        twitch: Config.y2k.textShake === "off" || Motion.calm ? 0 : (Config.y2k.textShake === "strong" ? 0.18 : 0.05) * (Angel.demon ? 0.5 : 1)
                    }
                }

                SpriteRig {
                    id: sprite
                    anchors.horizontalCenter: parent.horizontalCenter
                    // the waist on the window's bottom edge, like on the bar's top edge
                    y: parent.height - win.cut - win.voiceLift + win.swapDrop
                    width: ready ? implicitWidth : pixelArt.width
                    height: ready ? implicitHeight : pixelArt.height
                    who: stage.demonArt ? "demon" : "angel"
                    tick: win.tick
                    blink: win.blinking
                    talk: win.mouthOpen
                    tears: !stage.demonArt && Story.angelFallen && !Motion.still
                    use: stage.look === "chibi" || stage.look === "glitch" || stage.look === "ophanim"
                    angelVariant: stage.angelLook === "glitch" || stage.angelLook === "ophanim" ? stage.angelLook : ""
                    demonVariant: stage.demonLook === "glitch" ? "glitch" : ""
                    skin: !stage.demonArt ? "" : GameDebug.skin === "-" ? "" : GameDebug.skin || (Story.inHell ? HellLook.circle : "")
                    px: ready ? win.pxFor(rig.size[1]) : 1
                    layer.enabled: !stage.demonArt && ready && HeavenStars.worn !== null
                    layer.smooth: false
                    layer.effect: AngelSkinFx {
                        skin: HeavenStars.worn
                    }

                    PxIcon {
                        id: pixelArt
                        visible: !sprite.ready
                        bitmap: sprite.ready ? null : stage.frame
                        pixel: Math.max(1, Math.round(exactPixel))
                        exactPixel: win.pxFor(stage.frame.length)
                        ink: stage.demonArt ? "#1a0a14" : (Theme.dark ? Theme.text : Theme.edge)
                        body: stage.demonArt ? "#f7d9e3" : "#ffd9c7"
                        fill: stage.demonArt ? "#ff3b6b" : Theme.accent
                        fill2: "#3a1a46"
                        fill3: Theme.dark ? "#ffe07a" : "#f5c542"
                        light: stage.demonArt ? "#7a1e46" : "#ffffff"
                        bad: "#d8203a"
                        palette: stage.mini ? ({}) : stage.demonArt ? DemonArt.palette : Object.assign({}, AngelArt.palette, {
                            "o": Theme.hex(Theme.accent)
                        })
                    }
                }
            }

            RightClickGuard {}
        }
    }
}
