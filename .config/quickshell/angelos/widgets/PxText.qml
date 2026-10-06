import QtQuick
import qs.config

// Text with pixel-font defaults. kind: tiny | body | title | big | huge | mono
// In the grimoire's window (Theme.scriptWindow) it is handwritten instead (Theme.fontScript).
// In the Golden Gate skin's System Settings (Theme.macWindow), and under any host that puts
// settingsSkin "goldengate" on its content (plugin hosts in the Mac look: services/Skin), it is
// set in the skin's font at macOS's sizes: body 13, tiny 11, title 15, big 22, huge 26.
Text {
    property string kind: "body"
    property bool dim: false
    readonly property bool script: Theme.scriptWindow !== null && Window.window === Theme.scriptWindow && kind !== "mono"
    readonly property bool mac: (Theme.macWindow !== null && Window.window === Theme.macWindow) || Theme.settingsSkinFor(parent) === "goldengate"
    readonly property int basePx: mac ? Math.round(Theme.fs * (kind === "tiny" ? 11 : kind === "mono" ? 12 : kind === "title" ? 15 : kind === "big" ? 22 : kind === "huge" ? 26 : 13)) : kind === "tiny" ? Theme.sizeTiny : kind === "mono" ? Theme.sizeMono : kind === "title" ? Theme.sizeTitle : kind === "big" ? Theme.sizeBig : kind === "huge" ? Theme.sizeHuge : Theme.sizeBody

    color: dim ? Theme.textDim : Theme.text
    font.family: script ? Theme.fontScript : mac ? (kind === "mono" ? Theme.macMono : Theme.macFont) : kind === "body" ? Theme.fontBody : kind === "mono" ? Theme.fontMono : Theme.fontTitle
    font.pixelSize: script ? Theme.scriptPx(Math.max(basePx, Theme.sizeTiny + 2)) : basePx
    font.weight: mac && (kind === "title" || kind === "big" || kind === "huge") ? Font.Bold : Font.Normal
    font.hintingPreference: mac ? Font.PreferVerticalHinting : Font.PreferFullHinting
    renderType: script || mac ? Text.QtRendering : Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    // AutoText would render HTML found in window titles, track names or the
    // clipboard (<img src=…> even fetches remote images). Opt in per use.
    textFormat: Text.PlainText
}
