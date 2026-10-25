import QtQuick
import qs.config

// Text with pixel-font defaults. kind: tiny | body | title | big | huge | mono
// In the grimoire's window (Theme.scriptWindows) it is handwritten instead (Theme.fontScript).
// In the Golden Gate skin's System Settings (Theme.macWindow), and under any host that puts
// settingsSkin "goldengate" on its content (plugin hosts in the Mac look: services/Skin), it is
// set in the skin's font at macOS's sizes: body 13, tiny 11, title 15, big 22, huge 26.
Text {
    property string kind: "body"
    property bool dim: false
    readonly property bool script: Theme.scriptWindows.length > 0 && Theme.scriptWindows.includes(Window.window) && kind !== "mono"
    // inside the P5 settings window: ink on paper
    readonly property bool p5: Theme.p5For(parent)
    readonly property bool mac: (Theme.macWindow !== null && Window.window === Theme.macWindow) || Theme.settingsSkinFor(parent) === "goldengate"
    readonly property int basePx: mac ? Math.round(Theme.fs * (kind === "tiny" ? 11 : kind === "mono" ? 12 : kind === "title" ? 15 : kind === "big" ? 22 : kind === "huge" ? 26 : 13)) : kind === "tiny" ? Theme.sizeTiny : kind === "mono" ? Theme.sizeMono : kind === "title" ? Theme.sizeTitle : kind === "big" ? Theme.sizeBig : kind === "huge" ? Theme.sizeHuge : Theme.sizeBody

    // the P5 window's text in its own narrow face (Theme.fontP5Body), a size larger
    readonly property bool p5Body: p5 && !script && (kind === "body" || kind === "tiny")
    color: dim ? (p5 ? Theme.p5Dim : Theme.textDim) : (p5 ? Theme.p5Black : Theme.text)
    font.family: script ? Theme.fontScript : mac ? (kind === "mono" ? Theme.macMono : Theme.macFont) : p5Body ? Theme.fontP5Body : kind === "body" ? Theme.fontBody : kind === "mono" ? Theme.fontMono : Theme.fontTitle
    font.pixelSize: script ? Theme.scriptPx(Math.max(basePx, Theme.sizeTiny + 2)) : p5Body ? Theme.p5BodyPx(basePx) : basePx
    font.weight: (mac && (kind === "title" || kind === "big" || kind === "huge")) || (p5 && kind !== "mono") ? Font.Bold : Font.Normal
    font.hintingPreference: mac ? Font.PreferVerticalHinting : Font.PreferFullHinting
    // a fractional screen scale (1.25, 1.5; the window's own ratio, the screen's is rounded up): the
    // pixel faces came out with soft grey edges (#119) — hard edges instead, a column now and then
    // a pixel wider. NativeRendering only (QtRendering ignores it)
    readonly property real dpr: Window.window ? Window.window.devicePixelRatio : 1
    readonly property bool fractional: Math.abs(dpr - Math.round(dpr)) > 0.01
    antialiasing: !(fractional && !script && !mac)
    readonly property bool zoomed: Theme.zoomedFor(parent)
    renderType: script || mac || zoomed ? Text.QtRendering : Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    // AutoText would render HTML found in window titles, track names or the
    // clipboard (<img src=…> even fetches remote images). Opt in per use.
    textFormat: Text.PlainText
}
