import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Win98 taskbar, on the edge picked in Settings → Bar (Config.bar.edge, like Windows 10): the
// bottom, the top, or upright on the left or the right (BarContent.vertical). Auto-hide (Bar →
// Auto-hide): the bar slides off its edge leaving a thin line there, windows get the whole
// screen; the pointer at that edge, Start or a bar menu bring it back.
// In hell (BarLayout.hell): the circle's ground with calm plates under the widgets and a
// thin rim along the top (HellBarFrame) — nothing above the bar, nothing over its buttons.
PanelWindow {
    id: win

    required property var modelData
    readonly property bool compact: Config.bar.compactOnVertical && modelData.width < 1300
    readonly property string edge: BarLayout.edge
    readonly property bool vertical: BarLayout.vertical

    readonly property bool autoHide: Config.bar.autoHide
    // what keeps it up: the pointer on it, Start or one of its menus open on this screen
    readonly property bool held: hover.hovered || Shell.startScreen === modelData.name || (PopupManager.active !== null && (!PopupManager.active.outputName || PopupManager.active.outputName === modelData.name)) || PopupManager.registered.some(p => p.visible && p.outputName === modelData.name)
    property bool up: true
    onHeldChanged: {
        if (held) {
            hideLater.stop();
            up = true;
        } else if (autoHide)
            hideLater.restart();
    }
    onAutoHideChanged: {
        if (autoHide && !held)
            hideLater.restart();
        else
            up = true;
    }
    Timer {
        id: hideLater
        interval: Config.bar.autoHideMs
        onTriggered: if (win.autoHide && !win.held)
            win.up = false
    }
    // 0 = shown, 1 = tucked away below the edge
    property real tucked: autoHide && !up ? 1 : 0
    Behavior on tucked {
        NumberAnimation {
            duration: Motion.ms(win.tucked < 0.5 ? 160 : 260)
            easing.type: Easing.OutCubic
        }
    }
    // the line that stays at the edge while it hides, the pointer finds it there
    readonly property int peek: Math.max(2, Theme.u)

    readonly property bool hell: BarLayout.hell
    readonly property int barHeight: Theme.barHeight
    // how deep the bar is from its edge: its height across, its width upright (room for the
    // icons, the clock and the tray's arrow)
    readonly property int thick: vertical ? Theme.u * 36 : barHeight
    // how far it has slid off its edge, towards the outside
    readonly property real slide: Math.round(tucked * (thick - peek))

    screen: modelData
    anchors {
        top: win.edge !== "bottom"
        bottom: win.edge !== "top"
        left: win.edge !== "right"
        right: win.edge !== "left"
    }
    implicitHeight: vertical ? 0 : thick
    implicitWidth: vertical ? thick : 0
    exclusionMode: Shell.dev || autoHide ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: thick
    mask: Region {
        item: hot
    }
    // what takes the pointer: the bar where it is now, at least the line left at the edge
    Item {
        id: hot
        x: win.edge === "right" ? Math.min(box.x, win.width - win.peek) : 0
        y: win.edge === "bottom" ? Math.min(box.y, win.height - win.peek) : 0
        width: win.edge === "left" ? Math.max(win.peek, box.x + box.width) : win.width - x
        height: win.edge === "top" ? Math.max(win.peek, box.y + box.height) : win.height - y
    }
    color: "transparent"
    WlrLayershell.namespace: "angelos-bar"
    WlrLayershell.layer: WlrLayer.Top
    // the edge it keeps from windows, for the screenshot selector (services/Zones)
    ZoneReport {
        win: win
        key: "taskbar"
    }

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: box
    }

    // the pointer over the taskbar, in screen coordinates (Pointer: the demon's
    // glass over the Start button clears up as it comes near)
    HoverHandler {
        id: hover
        onPointChanged: if (hovered)
            Pointer.report("bar", win.modelData.name, (win.edge === "right" ? win.modelData.width - win.width : 0) + point.position.x, (win.edge === "bottom" ? win.modelData.height - win.height : 0) + point.position.y)
        onHoveredChanged: if (!hovered)
            Pointer.left("bar", win.modelData.name)
    }

    PxBox {
        id: box
        width: win.vertical ? win.thick : parent.width
        height: win.vertical ? parent.height : win.thick
        x: win.edge === "left" ? -win.slide : win.edge === "right" ? win.slide : 0
        y: win.edge === "bottom" ? win.slide : win.edge === "top" ? -win.slide : 0
        color: win.hell ? "transparent" : Theme.panel
        hell: win.hell
        outline: false

        Rectangle {
            // the highlight line like the original taskbar, on the side facing the desktop
            visible: !win.hell
            width: win.vertical ? Theme.u : parent.width
            height: win.vertical ? parent.height : Theme.u
            x: win.edge === "left" ? box.width - box.inset - Theme.u : -box.inset
            y: win.edge === "top" ? box.height - box.inset - Theme.u : -box.inset
            color: Theme.hi
        }
        // hell: the ground, the plates under the widgets, the rim on top
        HellBarFrame {
            visible: win.hell
            x: -box.inset
            y: -box.inset
            width: box.width
            height: box.height
            content: taskbarContent
            rim: win.edge === "top" ? "bottom" : win.edge === "bottom" ? "top" : "all"
        }

        BarContent {
            id: taskbarContent
            anchors.fill: parent
            anchors.leftMargin: win.vertical ? 0 : Theme.u
            anchors.rightMargin: win.vertical ? 0 : Theme.u
            screenName: win.modelData.name
            barWindow: win
            style: "taskbar"
            vertical: win.vertical
            compact: win.compact || win.vertical
            itemHeight: Theme.fit(15)
        }
    }

    RightClickGuard {}
}
