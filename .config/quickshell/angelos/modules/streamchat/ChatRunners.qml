pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The stream's chat at the bottom of the streamed screen (services/StreamChat): whoever writes
// runs across as the Halo's little cat with the nick over it, a crown for a regular. Over the
// game too (the overlay layer), only while OBS is on air; takes no input.
PanelWindow {
    id: win

    // the first streamed screen (Settings → Stream), else the main one
    screen: Shell.screenByName((Config.stream.screens || [])[0] || "") || Shell.primaryScreen
    visible: StreamMode.onAir && Config.stream.chatRunners !== false && StreamChat.runners.length > 0
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    implicitHeight: Theme.u * 36
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "angelos-chat-runners"
    WlrLayershell.layer: WlrLayer.Overlay
    RightClickGuard {}

    readonly property int pixel: Theme.u * 2

    Repeater {
        // by identity: a cat that is already running keeps running when another joins
        model: ScriptModel {
            values: StreamChat.runners
        }
        ChatRunner {
            pixel: win.pixel
            lane: win.width
        }
    }
}
