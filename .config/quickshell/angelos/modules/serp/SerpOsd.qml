pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import "../../widgets/MacIcons.js" as MacIcons

// serp-skin: Serpantinum's OSD in place of angelOS's (modules/osd/Osd.qml) — the same triggers:
// volume, the microphone, the backlight, the keyboard's light (a meter card: icon in a box, a thick
// bar, the value), the layout, the laptop's switch keys, the "Desk N" of Desktop and the
// Strip/Desktop toast (a compact card), the first-time Desktop keys (a bigger card, a click hides
// it). On the focused screen only; the Halo still takes the bar on its screen (Halo.takesOsd).
// Where: Settings → Звук → OSD (Config.osd.position), how long: Config.osd.ms — as the original.
PanelWindow {
    id: win
    // the wallpaper in screen space, for the liquid glass (Serp.glassOn)
    SerpBackdrop {
        id: glassBack
    }

    required property var modelData
    readonly property string screenName: modelData ? modelData.name : ""

    property string kind: "volume"
    property bool shown: false
    readonly property string pos: Config.osd.position || "bottom-center"
    readonly property bool compact: kind === "layout" || kind === "flag"
    readonly property bool hint: kind === "hint"
    // the meter: volume, mic, the backlight, the keyboard's light (0…1; the volume may go past 1)
    readonly property real meter: kind === "brightness" ? Backlight.level : kind === "kbd" ? (Backlight.kbdMax > 0 ? Backlight.kbd / Backlight.kbdMax : 0) : kind === "mic" ? (Audio.micMuted ? 0 : Audio.micVolume) : (Audio.muted ? 0 : Audio.volume)
    readonly property bool over: kind === "volume" && !Audio.muted && Audio.volume > 1

    function show(k) {
        if (!Config.osd.enabled)
            return;
        const scr = Shell.focusedScreen ? Shell.focusedScreen.name : "";
        if (scr !== screenName)
            return;
        // the Halo shows the bar on its screen (Settings → Halo → «Volume and brightness»)
        if (Halo.takesOsd(k, scr))
            return;
        kind = k;
        shown = true;
        hide.interval = k === "hint" ? 9000 : k === "layout" || k === "flag" ? Math.round(Config.osd.ms * 0.7) : Config.osd.ms;
        hide.restart();
    }

    Timer {
        id: hide
        onTriggered: win.shown = false
    }

    // ---- the triggers (as modules/osd/Osd.qml) ----
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
    // the laptop's keys that are a switch: touchpad, airplane mode, rotation lock, tablet mode
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
    // (only the window on the focused screen marks the hint as seen)
    Connections {
        target: WindowConfig
        function onModeFlipped(desktop, locked) {
            const here = Shell.focusedScreen && Shell.focusedScreen.name === win.screenName;
            win.flagIcon = desktop ? "layers" : "strip";
            win.flagText = locked ? I18n.t("Golden Gate — всегда Desktop", "Golden Gate is always Desktop") : desktop ? "Desktop" : I18n.t("Лента", "Strip");
            if (desktop && !locked && !Config.windows.desktopHintSeen) {
                if (!here)
                    return;
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

    // angelOS's pixel names (Laptop.flag, the toasts) → Lucide
    function lucide(n) {
        const map = {
            "touchpad": "mouse",
            "plane": "wifi-off",
            "rotate": "rotate-ccw",
            "laptop": "monitor",
            "grid": "layout-grid",
            "layers": "layers",
            "strip": "panel-left"
        };
        return map[n] || MacIcons.fromPixel(n) || "circle-dot";
    }
    readonly property string iconName: kind === "flag" ? lucide(flagIcon) : kind === "brightness" ? "sun" : kind === "kbd" ? "sun-dim" : kind === "mic" ? (Audio.micMuted ? "circle-x" : "mic") : kind === "layout" ? "languages" : kind === "hint" ? "layers" : SerpIcons.volume()
    readonly property string label: kind === "brightness" ? I18n.t("Яркость", "Brightness") : kind === "kbd" ? I18n.t("Подсветка", "Keyboard light") : kind === "mic" ? I18n.t("Микрофон", "Microphone") : I18n.t("Громкость", "Volume")
    readonly property string valueText: kind === "flag" ? flagText : kind === "layout" ? Niri.layoutShort : kind === "brightness" || kind === "kbd" ? Math.round(meter * 100) + "%" : kind === "mic" ? (Audio.micMuted ? I18n.t("выкл", "off") : Math.round(Audio.micVolume * 100) + "%") : Audio.muted ? I18n.t("тихо", "quiet") : Math.round(Audio.volume * 100) + "%"

    // ---- the window ----
    readonly property bool atTop: pos.indexOf("top") === 0
    readonly property bool atBottom: pos.indexOf("bottom") === 0
    readonly property int edge: Serp.px(12)
    readonly property int dockRoom: Serp.cfg.dock ? Serp.px(Serp.cfg.dockSize + 40) : 0

    screen: modelData
    // shown, and kept on screen until the fade is over by a flag of its own: "shown || the fade is
    // running" was false for a frame before the fade started — the surface went and came back
    // (a blink and a jerk as it left, 2026-11-13)
    property bool alive: false
    onShownChanged: {
        if (shown) {
            outHold.stop();
            alive = true;
        } else
            outHold.restart();
    }
    Timer {
        id: outHold
        interval: 330
        onTriggered: win.alive = false
    }
    visible: alive
    // niri's blur can't fade: off the screen as soon as the card is nearly gone (no frosted plate)
    Connections {
        target: card
        function onOpacityChanged() {
            if (!win.shown && win.alive && card.opacity < 0.12)
                win.alive = false;
        }
    }
    anchors.top: atTop
    anchors.bottom: atBottom
    anchors.left: pos.indexOf("left") >= 0
    anchors.right: pos.indexOf("right") >= 0
    margins.top: Serp.barHeight + edge
    margins.bottom: dockRoom + edge
    margins.left: edge
    margins.right: edge
    implicitWidth: card.width + Serp.px(24)
    implicitHeight: card.height + Serp.px(24)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "angelos-serposd"
    WlrLayershell.layer: WlrLayer.Overlay
    // no input; only the first-time Desktop hint takes a click (to go away), as the original
    mask: hint && shown ? hintRegion : noRegion
    Region {
        id: noRegion
    }
    Region {
        id: hintRegion
        item: card
    }
    BackgroundEffect.blurRegion: Serp.blurOn && shown && card.opacity > 0.85 ? blurRegion : noRegion  // only over a card that's there
    Region {
        id: blurRegion
        item: card
        radius: Serp.radius
    }

    SGlass {
        id: card
        readonly property int padX: Serp.px(12)
        anchors.horizontalCenter: parent.horizontalCenter
        // slides from the edge it stands at
        // comes in with a little slide, leaves by fading only: moving the glass while it fades made the
        // wallpaper inside it jump a frame behind (a jerk upwards as it went)
        property real enter: 0
        y: (parent.height - height) / 2 + enter * (win.atTop ? -Serp.px(14) : Serp.px(14))
        Connections {
            target: win
            function onShownChanged() {
                if (win.shown && card.opacity < 0.05) {
                    enterAnim.stop();
                    card.enter = 1;
                    enterAnim.start();
                }
            }
        }
        NumberAnimation {
            id: enterAnim
            target: card
            property: "enter"
            to: 0
            duration: Serp.normal
            easing.type: Easing.OutCubic
        }
        width: win.hint ? hintCol.implicitWidth + Serp.px(32) : win.compact ? compactRow.x + compactRow.implicitWidth + padX : Serp.px(296)
        height: win.hint ? hintCol.implicitHeight + Serp.px(28) : win.compact ? Serp.px(44) : Serp.px(58)
        radius: Serp.radius
        backdrop: glassBack
        tintAmount: Math.max(Serp.cfg.glassTint, 0.45)  // text-heavy: readable over any wallpaper
        opacity: win.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                id: fade
                duration: Serp.normal
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: win.hint
            onClicked: win.shown = false
        }

        // the icon's box
        Rectangle {
            id: iconBox
            visible: !win.hint
            x: win.compact ? Serp.px(7) : Serp.px(9)
            anchors.verticalCenter: parent.verticalCenter
            width: win.compact ? Serp.px(30) : Serp.px(40)
            height: width
            radius: Serp.radiusSmall
            color: Serp.surface1
            SIcon {
                anchors.centerIn: parent
                name: win.iconName
                size: win.compact ? Serp.px(16) : Serp.px(20)
                color: win.over ? Serp.red : Serp.accent
            }
        }

        // ---- a meter: label and value over a thick bar ----
        Item {
            visible: !win.compact && !win.hint
            anchors.left: iconBox.right
            anchors.leftMargin: Serp.px(12)
            anchors.right: parent.right
            anchors.rightMargin: Serp.px(14)
            anchors.verticalCenter: parent.verticalCenter
            height: Serp.px(36)
            SText {
                anchors.left: parent.left
                anchors.right: valueLbl.left
                anchors.rightMargin: Serp.px(8)
                y: 0
                height: Serp.px(16)
                text: win.label
                size: Serp.smallSize
                dim: true
            }
            SText {
                id: valueLbl
                anchors.right: parent.right
                y: 0
                height: Serp.px(16)
                text: win.valueText
                size: Serp.smallSize
                bold: true
                color: win.over ? Serp.red : Serp.text
            }
            Rectangle {
                id: track
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Serp.px(10)
                radius: height / 2
                color: Serp.surface1
                Rectangle {
                    height: parent.height
                    radius: height / 2
                    width: win.meter > 0 ? Math.max(height, parent.width * Math.min(1, win.meter)) : 0
                    color: win.over ? Serp.red : Serp.accent
                    Behavior on width {
                        enabled: win.visible
                        NumberAnimation {
                            duration: Serp.quick
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: Serp.quick
                        }
                    }
                }
            }
        }

        // ---- a text card: the layout, a switch key, the mode ----
        Row {
            id: compactRow
            visible: win.compact
            anchors.verticalCenter: parent.verticalCenter
            x: iconBox.x + iconBox.width + Serp.px(10)
            SText {
                anchors.verticalCenter: parent.verticalCenter
                text: win.valueText
                bold: true
                rightPadding: Serp.px(6)
            }
        }

        // ---- the first time Desktop comes: its keys ----
        Column {
            id: hintCol
            visible: win.hint
            anchors.centerIn: parent
            spacing: Serp.px(6)
            Row {
                spacing: Serp.px(10)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Serp.px(30)
                    height: width
                    radius: Serp.radiusSmall
                    color: Serp.surface1
                    SIcon {
                        anchors.centerIn: parent
                        name: "layers"
                        color: Serp.accent
                    }
                }
                SText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("Desktop: окна как в обычной системе", "Desktop: windows as on a usual system")
                    bold: true
                }
            }
            Repeater {
                model: win.hint ? [I18n.t("Mod+Ctrl+Shift+M — назад в Ленту", "Mod+Ctrl+Shift+M — back to the Strip"), I18n.t("Mod+← → — половина экрана, ↑ — во весь, ↓ — свернуть", "Mod+← → — half the screen, ↑ — all of it, ↓ — minimize"), I18n.t("Mod+D — показать рабочий стол, Mod+W — все окна и столы", "Mod+D — show the desktop, Mod+W — all windows and desks"), I18n.t("потряси окно за заголовок — остальные свернутся", "shake a window by its title — the rest minimize"), I18n.t("колесо по заголовку — шторка, Alt+Пробел — меню окна", "the wheel over a title — roll it up, Alt+Space — the window's menu")] : []
                SText {
                    required property string modelData
                    text: modelData
                    size: Serp.smallSize
                    dim: true
                }
            }
        }
    }

    RightClickGuard {}
}
