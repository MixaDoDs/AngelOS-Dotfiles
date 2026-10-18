import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import "../../widgets/Place.js" as Place

// The note a new Steam game gets (services/GameTune.note): pinned in the corner the notifications
// use, on their screen; it takes the keyboard only when clicked. Closing it is "not now":
// Settings → Maintenance → Games still has it.
PanelWindow {
    id: win

    screen: Config.notifications.screen === "primary" ? Shell.primaryScreen : Shell.screenByName(Config.notifications.screen) || Shell.focusedScreen
    visible: !!GameTune.noteGame && !Shell.setupLocked && !Shell.gaming
    readonly property string pos: Config.notifications.position || "top-right"
    anchors.top: Place.top(pos)
    anchors.bottom: Place.bottom(pos)
    anchors.left: Place.left(pos)
    anchors.right: Place.right(pos)
    margins.top: Theme.u * 4
    margins.bottom: Theme.u * 4
    margins.left: Theme.u * 4
    margins.right: Theme.u * 4
    implicitWidth: Theme.u * 190
    implicitHeight: paper.height
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "angelos-gamenote"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    PxWindow {
        id: paper
        width: parent.width
        height: titleHeight + card.implicitHeight + Theme.pad * 2 + Theme.u * 4
        title: GameTune.noteGame ? GameTune.noteGame.name : ""
        icon: "gamepad"
        translucent: false
        onCloseClicked: GameTune.note = ""

        GameTuneCard {
            id: card
            width: parent.width
            game: GameTune.noteGame
        }
    }
}
