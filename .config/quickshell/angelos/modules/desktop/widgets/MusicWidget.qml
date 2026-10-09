import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.desktop

// Music (the old cava and "now playing" widgets in one, DesktopWidgets.renamed):
//   S  the spectrum alone
//   M  the player: cover, track, progress and the buttons
//   L  the player with the spectrum under it, as wide as the player
// The spectrum runs cava only in the face (MusicSpectrum.face); the input copy has the buttons.
// macOS look keeps one layout: the spectrum at S (capsules), the player otherwise.
Item {
    id: root

    property string screenName
    property var widget
    property string size: "m"
    property string frameKind: "window"
    property bool face: true

    readonly property bool mac: DesktopWidgets.macLook
    readonly property bool hasSpectrum: size !== "m"
    readonly property bool hasPlayer: size !== "s"
    // S is the spectrum alone: nothing to click, the input copy stays empty
    readonly property bool passive: !hasPlayer
    readonly property var st: widget && widget.settings ? widget.settings : ({})

    implicitWidth: hasPlayer ? player.implicitWidth : spectrum.implicitWidth
    implicitHeight: hasPlayer ? player.implicitHeight + (spectrum.visible ? spectrum.implicitHeight + gap : 0) : spectrum.implicitHeight
    readonly property int gap: Theme.u * 4

    MusicPlayer {
        id: player
        visible: root.hasPlayer
        width: implicitWidth
        height: implicitHeight
        screenName: root.screenName
        widget: root.widget
    }
    MusicSpectrum {
        id: spectrum
        visible: root.hasSpectrum && !(root.mac && root.hasPlayer)
        y: root.hasPlayer ? player.height + root.gap : 0
        width: implicitWidth
        height: implicitHeight
        screenName: root.screenName
        widget: root.widget
        face: root.face
        // L: low and as wide as the player above it
        rows: root.hasPlayer ? 7 : 14
        fitWidth: root.hasPlayer && !root.mac ? player.implicitWidth : 0
    }
}
