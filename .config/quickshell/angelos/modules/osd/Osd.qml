import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import "../../widgets/Place.js" as Place

// Small volume / mic / layout / brightness / keyboard light OSD, and the laptop's switch keys. Position comes from Settings → Звук → OSD.
PanelWindow {
    id: win

    property string kind: "volume"
    property bool shown: false
    readonly property string pos: Config.osd.position || "bottom-center"
    readonly property bool compactLayout: kind === "layout" || kind === "flag"
    // the meter: volume, mic, the backlight, the keyboard's light (0…1)
    readonly property real meter: kind === "brightness" ? Backlight.level : kind === "kbd" ? (Backlight.kbdMax > 0 ? Backlight.kbd / Backlight.kbdMax : 0) : kind === "mic" ? (Audio.micMuted ? 0 : Audio.micVolume) : (Audio.muted ? 0 : Math.min(1, Audio.volume))

    function show(k) {
        if (!Config.osd.enabled)
            return;
        kind = k;
        shown = true;
        hide.interval = k === "layout" || k === "flag" ? Math.round(Config.osd.ms * 0.7) : Config.osd.ms;
        hide.restart();
    }

    screen: Shell.focusedScreen
    visible: shown || fade.running
    anchors.top: Place.top(pos)
    anchors.bottom: Place.bottom(pos)
    anchors.left: Place.left(pos)
    anchors.right: Place.right(pos)
    margins.top: Theme.u * 6
    margins.bottom: Theme.u * 6
    margins.left: Theme.u * 6
    margins.right: Theme.u * 6
    implicitWidth: box.width + Theme.u * 3
    implicitHeight: box.height + Theme.u * 3
    // respect the bar's exclusive zone, but don't reserve space ourselves
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "angelos-osd"
    WlrLayershell.layer: WlrLayer.Overlay

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: box
    }

    Timer {
        id: hide
        onTriggered: win.shown = false
    }

    Connections {
        target: Audio
        function onChanged(what) {
            win.show(what);
        }
    }
    Connections {
        target: Backlight
        function onChanged(what) {
            win.show(what);
        }
    }
    // the laptop's keys that are a switch: touchpad, airplane mode, rotation lock (services/Laptop)
    property string flagText: ""
    property string flagIcon: "heart"
    Connections {
        target: Laptop
        function onFlag(icon, text) {
            win.flagIcon = icon;
            win.flagText = text;
            win.show("flag");
        }
    }
    Connections {
        target: Niri
        function onLayoutSwitched() {
            if (Config.osd.layout)
                win.show("layout");
        }
    }

    PxBox {
        id: box
        width: row.implicitWidth + Theme.u * (win.compactLayout ? 10 : 14)
        height: win.compactLayout ? Theme.u * 15 : Theme.u * 17
        color: Theme.panel
        shadow: Config.appearance.shadows
        opacity: win.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                id: fade
                duration: Motion.ms(Theme.fast)
            }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Theme.u * 4

            PxIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: win.kind === "flag" ? win.flagIcon : win.kind === "brightness" ? "sun" : win.kind === "kbd" ? "keyboard" : win.kind === "mic" ? (Audio.micMuted ? "micMute" : "mic") : win.kind === "layout" ? "keyboard" : (Audio.muted ? "speakerMute" : "speaker")
            }
            PxHearts {
                visible: !win.compactLayout
                anchors.verticalCenter: parent.verticalCenter
                count: 10
                pixel: Math.max(1, Theme.u - 1)
                value: win.meter
                fill: Audio.volume > 1 && win.kind === "volume" ? Theme.danger : Theme.accent
            }
            PxText {
                anchors.verticalCenter: parent.verticalCenter
                text: win.kind === "flag" ? win.flagText : win.kind === "brightness" || win.kind === "kbd" ? Math.round(win.meter * 100) + "%" : win.kind === "layout" ? Niri.layoutShort : win.kind === "mic" ? (Audio.micMuted ? I18n.t("выкл", "off") : Math.round(Audio.micVolume * 100) + "%") : (Audio.muted ? I18n.t("тихо", "Quiet") : Math.round(Audio.volume * 100) + "%")
                font.bold: win.compactLayout
            }
        }
    }

    RightClickGuard {}
}
