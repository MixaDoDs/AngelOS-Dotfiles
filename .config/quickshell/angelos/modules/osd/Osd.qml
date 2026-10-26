import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import "../../widgets/Place.js" as Place

// Small volume / mic / layout / brightness / keyboard light OSD, the laptop's switch keys, and
// Desktop or the Strip (with its keys the first time Desktop comes). Position comes from
// Settings → Звук → OSD.
PanelWindow {
    id: win

    property string kind: "volume"
    property bool shown: false
    readonly property string pos: Config.osd.position || "bottom-center"
    readonly property bool compactLayout: kind === "layout" || kind === "flag" || kind === "hint"
    // the meter: volume, mic, the backlight, the keyboard's light (0…1)
    readonly property real meter: kind === "brightness" ? Backlight.level : kind === "kbd" ? (Backlight.kbdMax > 0 ? Backlight.kbd / Backlight.kbdMax : 0) : kind === "mic" ? (Audio.micMuted ? 0 : Audio.micVolume) : (Audio.muted ? 0 : Math.min(1, Audio.volume))

    function show(k) {
        if (!Config.osd.enabled)
            return;
        // the Halo shows the bar on its screen (Settings → Halo → «Volume and brightness»)
        if (Halo.takesOsd(k, Shell.focusedScreen ? Shell.focusedScreen.name : ""))
            return;
        kind = k;
        shown = true;
        hide.interval = k === "hint" ? 9000 : k === "layout" || k === "flag" ? Math.round(Config.osd.ms * 0.7) : Config.osd.ms;
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
    // only the hint takes a click (to go away)
    mask: kind === "hint" && shown ? hintRegion : noRegion
    Region {
        id: noRegion
    }
    Region {
        id: hintRegion
        item: box
    }
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
    // Desktop hides the desks' strip: a switch of desk on a screen says which one is in front (not
    // a click onto another screen, not into a full-screen window, not while Mission Control is up)
    property string deskOut: ""
    property int deskId: -1
    readonly property var desk: WindowConfig.floatAll ? Niri.activeWorkspace(Niri.focusedOutput) : null
    onDeskChanged: {
        const out = Niri.focusedOutput, id = desk ? desk.id : -1;
        const moved = out === deskOut && deskId !== -1 && id !== -1 && id !== deskId;
        deskOut = out;
        deskId = id;
        if (!moved || Mission.shown || Shell.fullscreenOn(out))
            return;
        flagIcon = "grid";
        flagText = I18n.t("Стол ", "Desk ") + desk.idx;
        show("flag");
    }
    // Desktop or the Strip (services/WindowConfig): the first time Desktop comes, its keys too
    Connections {
        target: WindowConfig
        function onModeFlipped(desktop, locked) {
            win.flagIcon = desktop ? "layers" : "strip";
            win.flagText = locked ? I18n.t("Golden Gate — всегда Desktop", "Golden Gate is always Desktop") : desktop ? "Desktop" : I18n.t("Лента", "Strip");
            if (desktop && !locked && !Config.windows.desktopHintSeen) {
                Config.windows.desktopHintSeen = true;
                win.show("hint");
            } else {
                win.show("flag");
            }
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
        width: (win.kind === "hint" ? hint.implicitWidth : row.implicitWidth) + Theme.u * (win.compactLayout ? 10 : 14)
        height: win.kind === "hint" ? hint.implicitHeight + Theme.u * 10 : win.compactLayout ? Theme.u * 15 : Theme.u * 17
        color: Theme.panel
        shadow: Config.appearance.shadows
        opacity: win.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                id: fade
                duration: Motion.ms(Theme.fast)
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: win.kind === "hint"
            onClicked: win.shown = false
        }

        Column {
            id: hint
            visible: win.kind === "hint"
            anchors.centerIn: parent
            spacing: Theme.u * 2
            Row {
                spacing: Theme.u * 4
                PxIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "layers"
                }
                PxText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("Desktop: окна как в обычной системе", "Desktop: windows as on a usual system")
                    font.bold: true
                }
            }
            Repeater {
                model: [I18n.t("Mod+Ctrl+Shift+M — назад в Ленту", "Mod+Ctrl+Shift+M — back to the Strip"), I18n.t("Mod+← → — половина экрана, ↑ — во весь, ↓ — свернуть", "Mod+← → — half the screen, ↑ — all of it, ↓ — minimize"), I18n.t("Mod+D — показать рабочий стол, Mod+W — все окна и столы", "Mod+D — show the desktop, Mod+W — all windows and desks"), I18n.t("потряси окно за заголовок — остальные свернутся", "shake a window by its title — the rest minimize"), I18n.t("колесо по заголовку — шторка, Alt+Пробел — меню окна", "the wheel over a title — roll it up, Alt+Space — the window's menu")]
                PxText {
                    required property string modelData
                    text: modelData
                    dim: true
                }
            }
        }

        Row {
            id: row
            visible: win.kind !== "hint"
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
