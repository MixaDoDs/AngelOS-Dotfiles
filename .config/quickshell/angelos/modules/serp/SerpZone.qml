import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// serp-skin: the room the islands bar keeps from windows. Exclusive zones on one edge add up:
// the Halo keeps its strip already (HaloWindow), so this keeps only the rest of the bar's height.
// Draws nothing and takes no input.
PanelWindow {
    id: win
    required property var modelData
    readonly property string screenName: modelData.name
    readonly property string haloZoneMode: Config.halo.windows === "maximized" && !WindowConfig.floatAll ? "bar" : Config.halo.windows || "bar"
    readonly property int haloZone: Halo.on(screenName) && Config.halo.reserve && haloZoneMode === "bar" && !Shell.dev ? Halo.strip : 0

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 1
    // the Halo keeping its strip (taller than the islands): nothing more — and never a moment of
    // the full height first, which pushed the Halo down under it at the shell's start
    readonly property bool haloKeeps: Halo.on(screenName) && Config.halo.reserve && haloZoneMode === "bar"
    exclusiveZone: Shell.dev || haloKeeps ? 0 : Serp.barHeight
    onExclusiveZoneChanged: Serp.zoneNow = exclusiveZone
    Component.onCompleted: Serp.zoneNow = exclusiveZone
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "angelos-serpzone"
    WlrLayershell.layer: WlrLayer.Bottom
    ZoneReport {
        win: win
        key: "serpbar"
    }
    RightClickGuard {}
}
