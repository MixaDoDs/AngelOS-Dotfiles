pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import qs.modules.mac

// Start menu as a layer-shell overlay: opens from the Start button, from a
// Meta tap or over IPC, takes the keyboard and closes on a click outside.
// Looks (Settings → Bar → Start): classic Win98 list, Windows 11 panel, Windose
// (NGO) window — by the button; iPhone-like grid, PSP XMB, Wii channels — the whole
// screen; Spotlight — a search pill centred in the upper third. All of them animate
// through `reveal` (0 → 1) and share the body interface: closeRequested, current,
// reset(), setQuery(text), key(event). While the demon rules: each of them in a hell
// version (re-inked, the circle's rim on its edges), or hell's own (StartHell).
Variants {
    model: Shell.screens

    PanelWindow {
        id: win

        required property var modelData
        readonly property string screenName: modelData.name
        readonly property bool open: Shell.startScreen === screenName
        // while the demon rules Start goes to hell (Y2K → Angel or demon → Start in hell):
        // "skin" — your look in a hell version (re-inked, shaders/hell_ink.frag, the circle's rim),
        // "hell" — hell's own menu (StartHell), "" — untouched
        readonly property bool hellish: Angel.demon && Config.y2k.hellStart === "hell"
        readonly property bool hellSkin: Angel.demon && Config.y2k.hellStart === "skin"
        // the Golden Gate skin: its own Spotlight (modules/mac/MacSpotlight)
        readonly property string style: hellish ? "hell" : GoldenGate.on ? "mac" : ["classic", "win11", "fullscreen", "xmb", "windose", "wii", "spotlight"].includes(Config.bar.startStyle) ? Config.bar.startStyle : "classic"
        readonly property bool full: style === "fullscreen" || style === "xmb" || style === "wii"
        readonly property bool spot: style === "spotlight" || style === "mac"
        property bool shown: false
        property real reveal: 0
        // this look's deep settings (services/StartPrefs: Settings → Bar → Start → Fine-tune)
        readonly property var prefs: StartPrefs.of(style === "hell" ? "classic" : style === "mac" ? "spotlight" : style)

        screen: modelData
        visible: shown
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "angelos-start"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: open ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

        onOpenChanged: {
            if (open) {
                shown = true;
                if (body.item && body.item.reset)
                    body.item.reset();
                if (body.item)
                    body.item.current = -1;
                win.takePrefill();
                revealAnim.to = 1;
                revealAnim.duration = !win.prefs.anim ? 1 : Math.round((win.full ? 340 : 230) / win.prefs.speed);
                if (win.prefs.sound)
                    Sounds.play("open");
                revealAnim.easing.type = win.full ? Easing.OutQuint : Easing.OutCubic;
                revealAnim.restart();
                Qt.callLater(() => keys.forceActiveFocus());
            } else if (shown) {
                revealAnim.to = 0;
                revealAnim.duration = !win.prefs.anim ? 1 : Math.round((win.full ? 200 : 140) / win.prefs.speed);
                revealAnim.easing.type = Easing.InCubic;
                revealAnim.restart();
            }
        }
        // `angelos startText …`: the search box of the open Start takes the text
        function takePrefill() {
            if (!open || !Shell.startPrefill || !body.item || !body.item.setQuery)
                return;
            body.item.setQuery(Shell.startPrefill);
            Shell.startPrefill = "";
        }
        Connections {
            target: Shell
            function onStartPrefillChanged() {
                win.takePrefill();
            }
        }
        NumberAnimation {
            id: revealAnim
            target: win
            property: "reveal"
            // closed: the typed text goes too, so the results bindings (apps,
            // settings, the calculator) don't keep re-running behind a hidden menu
            onFinished: if (!win.open) {
                win.shown = false;
                if (body.item && body.item.setQuery)
                    body.item.setQuery("");
            }
        }

        // where the Start button of this screen sits (layer shell does not tell
        // us the bar position, so it is derived from the bar window's anchors).
        // A screen without a bar: the bottom-left corner itself, not a gap for a
        // taskbar that isn't there (#48)
        readonly property rect button: {
            const b = Shell.startButtons[screenName];
            if (!b || !b.item || !b.window)
                return Qt.rect(Theme.u * 2, height - Theme.u * 2, Theme.u * 40, 0);
            const w = b.window, it = b.item;
            const p = it.mapToItem(w.contentItem, 0, 0);
            const a = w.anchors || {};
            const bottom = a.bottom && !a.top;
            const wy = bottom ? height - w.height - (w.margins ? w.margins.bottom : 0) : (w.margins ? w.margins.top : 0);
            // across the screen, on its left edge, on its right edge, or centred (the dock, an island)
            const wx = a.left && a.right ? 0 : a.left ? (w.margins ? w.margins.left : 0) : a.right ? width - w.width - (w.margins ? w.margins.right : 0) : (width - w.width) / 2;
            return Qt.rect(wx + p.x, wy + p.y, it.width, it.height);
        }
        readonly property bool above: button.y > height / 2
        // a taskbar on the left or the right edge (BarLayout.side): Start opens beside it, from
        // the button's top down, as Windows 10 does
        readonly property string side: BarLayout.side

        // "close on a click outside" off: only the menu takes the pointer, the rest of the
        // screen keeps working under it (Esc or Start close it)
        mask: Region {
            item: !win.open ? null : win.full || win.prefs.clickOutside ? catcher : body
        }
        // (the pixel Spotlight's pill and list are near opaque; its box is mostly air. Golden
        // Gate's is Liquid Glass: blur under its capsule and its results only)
        readonly property var macLook: win.style === "mac" && body.item && body.item.capsuleItem ? body.item : null
        BackgroundEffect.blurRegion: !win.shown ? null : win.macLook ? (GoldenGate.blurOn ? macBlur : null) : Config.appearance.blur && !win.spot ? blurRegion : null
        Region {
            id: blurRegion
            item: win.full ? catcher : body
        }
        Region {
            id: macBlur
            Region {
                item: win.macLook ? win.macLook.capsuleItem : null
                radius: win.macLook ? win.macLook.capsuleItem.radius : 0
            }
            Region {
                item: win.macLook && win.macLook.panelItem.visible ? win.macLook.panelItem : null
                radius: win.macLook ? win.macLook.panelItem.radius : 0
            }
        }

        MouseArea {
            id: catcher
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: Shell.closeStart()
        }

        Item {
            id: keys
            focus: true
            Keys.onPressed: e => {
                // "typing searches" off: letters do nothing, the keys still walk the menu
                if (!win.prefs.typeSearch && e.text && e.text.trim() !== "" && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                    e.accepted = true;
                    return;
                }
                if (body.item)
                    body.item.key(e);
            }
        }

        // the look is built when Start opens and kept a while after it closes (a quick
        // reopen, the closing animation); a closed Start holds nothing on any screen
        Linger {
            id: keep
            when: win.shown
            ms: 30000
        }
        Loader {
            id: body
            active: keep.alive
            // the room the look has on this screen, before its own zoom: a look taller than that
            // (big fonts, a big art pixel, a small or 2× screen) fits itself in (`room` of the
            // looks: fewer rows, a scrolling list) instead of running off the screen
            readonly property real room: (win.full ? win.height : win.spot ? win.height * 0.75 : win.side ? win.height - Theme.u * 8 : win.above ? win.button.y - Theme.u * 4 : win.height - win.button.y - win.button.height - Theme.u * 4) / Math.max(0.25, win.full ? 1 : win.prefs.zoom || 1)
            Binding {
                target: body.item
                property: "room"
                value: body.room
                when: !!body.item && body.item.room !== undefined
            }
            // Settings → Bar → Start: auto keeps classic at the button and win11 centred;
            // left / center / right pin either of them there. Fullscreen fills.
            readonly property real restY: win.side ? Math.max(Theme.u * 4, Math.min(win.height - height - Theme.u * 4, win.button.y)) : win.above ? win.button.y - height - Theme.u * 2 : win.button.y + win.button.height + Theme.u * 2
            readonly property string align: win.spot ? "center" : Config.bar.startAlign && Config.bar.startAlign !== "auto" ? Config.bar.startAlign : win.style === "win11" ? "center" : "button"
            readonly property real edge: Theme.u * 4
            readonly property real sideX: win.side === "left" ? win.button.x + win.button.width + Theme.u * 4 : win.button.x - width - Theme.u * 4
            x: win.full ? 0 : win.side && !win.spot && (align === "button" || align === "center") ? sideX : align === "center" ? Math.round((win.width - width) / 2) : align === "left" ? edge : align === "right" ? win.width - width - edge : Math.max(Theme.u * 2, Math.min(win.width - width - Theme.u * 2, win.button.x))
            // win11 (and anything over a centred taskbar) slides up like Windows 11;
            // Fine-tune → Animation can make any of them fade, slide or zoom instead
            readonly property string kind: win.prefs.animKind || "auto"
            readonly property bool slides: kind === "slide" || (kind === "auto" && (win.style === "win11" || Config.bar.taskbarAlign === "center"))
            readonly property bool zooms: kind === "zoom" || (kind === "auto" && (win.style === "classic" || win.style === "windose" || win.style === "hell") && !slides)
            // Spotlight: a fifth down the screen, dropping in a little
            y: win.full ? 0 : win.spot ? Math.round(win.height * 0.2) - (kind === "auto" || kind === "slide" ? (1 - win.reveal) * Theme.u * 10 : 0) : restY + (slides && !win.side ? (win.above ? 1 : -1) * (1 - win.reveal) * Theme.u * 24 : 0)
            opacity: win.full ? 1 : win.reveal
            // classic and Windose pop out of their corner, win11 slides, Spotlight swells;
            // the look's own size (Fine-tune → Scale) on top
            scale: (win.full ? 1 : win.prefs.zoom) * (win.spot && kind === "auto" ? 0.96 + 0.04 * win.reveal : zooms ? (kind === "zoom" ? 0.85 + 0.15 * win.reveal : 0.9 + 0.1 * win.reveal) : 1)
            transformOrigin: win.side === "left" ? Item.TopLeft : win.side === "right" ? Item.TopRight : align === "right" ? (win.above ? Item.BottomRight : Item.TopRight) : align === "center" ? (win.above ? Item.Bottom : Item.Top) : (win.above ? Item.BottomLeft : Item.TopLeft)
            sourceComponent: ({
                    "fullscreen": fullComp,
                    "xmb": xmbComp,
                    "wii": wiiComp,
                    "win11": win11Comp,
                    "windose": windoseComp,
                    "spotlight": spotComp,
                    "mac": macComp,
                    "hell": hellComp
                })[win.style] || classicComp
            // hell's version of whatever look this is
            layer.enabled: win.hellSkin && win.shown
            layer.effect: ShaderEffect {
                fragmentShader: Qt.resolvedUrl("../../shaders/hell_ink.frag.qsb")
                property real keep: 0.3
                property color plate: Theme.hellPlate
                property color face: Theme.mix(Theme.hellRim, Theme.hellFace, 0.4)
                property color dim: Theme.hellTextDim
                property color text: Theme.hellText
                property color accent: Theme.hellAccent
            }
            onLoaded: {
                item.closeRequested.connect(Shell.closeStart);
                if (win.open && item.reset)
                    item.reset();
            }
            MouseArea {
                visible: !win.full
                anchors.fill: parent
                z: -1
            }
        }
        // hell's version: the circle's rim on the menu's edges (still; HellAmbient may stir it)
        HellEdge {
            visible: win.hellSkin && win.shown && !!body.item && !win.full
            x: body.x
            y: body.y
            width: body.width * body.scale
            height: body.height * body.scale
            opacity: body.opacity
            seed: 5
        }
        Component {
            id: classicComp
            StartMenuBody {}
        }
        Component {
            id: win11Comp
            StartWin11 {}
        }
        Component {
            id: fullComp
            StartFullscreen {
                reveal: win.reveal
                width: win.width
                height: win.height
            }
        }
        Component {
            id: xmbComp
            StartXmb {
                reveal: win.reveal
                width: win.width
                height: win.height
            }
        }
        Component {
            id: wiiComp
            StartWii {
                reveal: win.reveal
                width: win.width
                height: win.height
            }
        }
        Component {
            id: windoseComp
            StartWindose {}
        }
        Component {
            id: spotComp
            StartSpotlight {}
        }
        Component {
            id: macComp
            MacSpotlight {}
        }
        Component {
            id: hellComp
            StartHell {
                reveal: win.reveal
            }
        }

        RightClickGuard {}
    }
}
