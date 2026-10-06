pragma Singleton

import QtQuick
import Quickshell
import qs.config

// The Theme API: one place that says which look is on and gives its tokens — for plugins,
// Plugin Studio's generated code and the shell's own plugin hosts. angelOS has two looks:
//   "pixel"  the original angelOS (Win98 / NEEDY GIRL OVERDOSE): square bevelled boxes, the
//            pixel fonts, sizes on the art-pixel grid (Theme.u), window titles "name.exe"
//   "mac"    Golden Gate (macOS 27, Liquid Glass): rounded glass, the system font (Inter or
//            SF Pro), point sizes, titles without an ending
// and hell over either while the demon rules ("hell": Theme.hell, the circle's palette).
// Bind to these, never copy their values: the look, light/dark, the accent, the font scale and
// Reduce transparency change while the shell runs.
//
// The shared controls change by themselves: PxButton, PxToggle, PxSlider, PxField, PxText,
// PxCombo, PxSegmented … read `settingsSkin` from their parents (Theme.settingsSkinFor), and
// every plugin host (the panel, the menu bar, BarPopup, the desktop, the sidebar, Settings) sets
// it from here. A card for a widget or a popup: SkinCard (widgets/SkinCard.qml).
Singleton {
    id: root

    // Plugin Studio's check loads a draft in every look: "" (the real one) | "pixel" | "mac"
    property string force: ""

    // ---- which look ----
    readonly property bool hell: Theme.hell
    // the Golden Gate skin is on (in hell too: it has a hell version of its own — check `hell` first)
    readonly property bool mac: force !== "" ? force === "mac" : GoldenGate.on
    readonly property bool pixel: !mac
    readonly property string name: hell ? "hell" : mac ? "mac" : "pixel"
    // desktop widgets have a style of their own (Settings → Widgets: auto, pixel, macOS cards); a
    // desktopWidget checks this one, not `mac` (false in hell: hell's widgets are hell's)
    readonly property bool macWidgets: force !== "" ? force === "mac" && !Theme.hell : DesktopWidgets.macLook
    // what the shared controls read (Theme.settingsSkinFor): hosts put it on plugin content
    readonly property string settingsSkin: mac && !hell ? "goldengate" : "classic"
    readonly property bool dark: Theme.dark
    // macOS's Accessibility → Reduce transparency (Golden Gate's Appearance), a fullscreen game
    // (niri-game-mode) or the blur switched off: solid surfaces, no glass effects
    readonly property bool reduceTransparency: !Config.appearance.blur || (Config.ready && Config.mac.reduceTransparency) || GoldenGate.gameMode
    // draw glass (translucent, rim): the Mac look with transparency allowed
    readonly property bool glass: mac && !reduceTransparency

    // ---- colours (premade for the look in use; hell's own while the demon rules) ----
    readonly property color accent: hell ? Theme.hellAccent : Theme.accent
    readonly property color accentText: hell ? Theme.hellBody : mac ? "#ffffff" : Theme.selectText
    readonly property color text: hell ? Theme.hellText : mac ? GoldenGate.label : Theme.text
    readonly property color textDim: hell ? Theme.hellTextDim : mac ? GoldenGate.secondaryLabel : Theme.textDim
    readonly property color textFaint: hell ? Qt.alpha(Theme.hellTextDim, 0.7) : mac ? GoldenGate.tertiaryLabel : Theme.mix(Theme.textDim, Theme.face, 0.35)
    // a card's / popup's body: glass in the Mac look (solid with Reduce transparency), the face in pixel
    readonly property color surface: hell ? Theme.hellFace : mac ? GoldenGate.glass(0) : Theme.face
    // a group inside a card (a row of settings, a tile)
    readonly property color surfaceAlt: hell ? Theme.hellFaceAlt : mac ? GoldenGate.groupBg : Theme.faceAlt
    // wells: fields, tracks, sunken boxes
    readonly property color sunken: hell ? Theme.hellSunken : mac ? GoldenGate.controlBg : Theme.sunken
    readonly property color separator: hell ? Theme.hellEdge : mac ? GoldenGate.separator : Theme.edge
    readonly property color hover: hell ? Theme.mix(Theme.hellFace, Theme.hellAccent, 0.2) : mac ? GoldenGate.hoverBg : Theme.mix(Theme.face, Theme.accent, 0.2)
    readonly property color danger: Theme.danger
    readonly property color ok: Theme.ok
    readonly property color warn: mac ? (dark ? "#ffd60a" : "#ff9f0a") : Theme.accent3
    readonly property color shadow: mac ? GoldenGate.shadow : Qt.alpha(Theme.edge, 0.6)
    function mix(a, b, t) {
        return Theme.mix(a, b, t);
    }
    // ink of a bar widget on the bar of `screenName`: the Golden Gate menu bar is black or white by
    // the wallpaper under it (monochrome, like macOS's menu bar extras), the pixel bar's is the text
    function ink(screenName) {
        return hell ? Theme.hellText : mac ? GoldenGate.barInk(screenName || "") : Theme.text;
    }

    // ---- type ----
    readonly property string font: mac ? Theme.macFont : Theme.fontBody
    readonly property string titleFont: mac ? Theme.macFont : Theme.fontTitle
    readonly property string mono: mac ? Theme.macMono : Theme.fontMono
    // sizes by role: "small" | "body" | "title" | "big" | "huge" (macOS: 11/13/15/22/26 pt)
    function fontSize(role) {
        if (mac)
            return GoldenGate.px(({
                    "small": 11,
                    "body": 13,
                    "title": 15,
                    "big": 22,
                    "huge": 26
                })[role] || 13);
        return ({
                "small": Theme.sizeTiny,
                "body": Theme.sizeBody,
                "title": Theme.sizeTitle,
                "big": Theme.sizeBig,
                "huge": Theme.sizeHuge
            })[role] || Theme.sizeBody;
    }
    readonly property int smallSize: fontSize("small")
    readonly property int textSize: fontSize("body")
    readonly property int titleSize: fontSize("title")
    readonly property int bigSize: fontSize("big")
    // pixel fonts are drawn natively (crisp), the Mac font smooth
    readonly property int renderType: mac ? Text.QtRendering : Text.NativeRendering

    // ---- metrics ----
    // a length in points: the Mac look scales it with the font scale; the pixel look puts it on the
    // art-pixel grid — 2 points are one art pixel (Theme.u), so at the default Theme.u = 2 it is
    // the same size, and a bigger art pixel grows the pixel look as a whole, crisp
    function px(n) {
        if (mac)
            return GoldenGate.px(n);
        return n > 0 ? Math.max(Theme.u, Math.round(n / 2) * Theme.u) : 0;
    }
    readonly property int spacing: mac ? GoldenGate.px(8) : Theme.u * 3
    readonly property int padding: mac ? GoldenGate.px(12) : Theme.pad
    readonly property int radius: mac ? GoldenGate.px(10) : 0             // controls, rows
    readonly property int cardRadius: mac ? GoldenGate.px(16) : 0         // cards, popups
    readonly property int controlHeight: mac ? GoldenGate.px(28) : Theme.u * 15
    readonly property int iconSize: mac ? GoldenGate.px(16) : Theme.u * 8

    // ---- words ----
    // a window's / widget's title: "stats" → "stats.exe" (the ending picked in Settings) in pixel,
    // as it is in the Mac look — a Mac has no .exe
    function title(name) {
        return mac ? String(name) : I18n.exe(name);
    }
    // a duration through Settings → Motion (0 with motion off)
    function ms(v) {
        return Motion.ms(v);
    }
}
