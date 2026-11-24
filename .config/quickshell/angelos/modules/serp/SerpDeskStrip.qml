pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// serp-skin: Serpantinum's desk switch in place of angelOS's heart strip (WorkspaceStrip) and its
// desk-name popup (WorkspacePopup). On a desk switch on this screen (Niri.workspaceActivated, not
// in the overview — as WorkspaceFx): a vertical island at the right edge with the desks as pills
// (Settings → Столы → the indicator) and, beside it, a card with the desk's name (the popup
// mode "window"). It slides in from the right, stays Config.workspaces.popupMs after the last
// switch (at least 400 ms, as the strip), slides out.
PanelWindow {
    id: win
    // the wallpaper in screen space, for the liquid glass (Serp.glassOn)
    SerpBackdrop {
        id: glassBack
    }

    required property var modelData
    readonly property string screenName: modelData ? modelData.name : ""

    property var ws: null
    property bool shown: false
    readonly property bool showStrip: Config.workspaces.indicator
    readonly property bool showLabel: Config.workspaces.popupMode === "window"

    Connections {
        target: Niri
        function onWorkspaceActivated(ws, focused) {
            if (!ws || ws.output !== win.screenName || Niri.overviewOpen)
                return;
            if (!win.showStrip && !win.showLabel)
                return;
            win.ws = ws;
            if (Config.workspaces.phrases)
                win.phrase = win.phrases[Math.floor(Math.random() * win.phrases.length)];
            win.shown = true;
            hideTimer.restart();
        }
    }
    Timer {
        id: hideTimer
        interval: Math.max(400, Config.workspaces.popupMs)
        onTriggered: win.shown = false
    }

    // ---- the data: read only while it is up ----
    readonly property var list: visible ? Niri.workspacesOn(screenName) : []
    readonly property var zero: visible ? Niri.zeroDesk(screenName) : null
    readonly property bool zeroLit: !!zero && zero.is_active
    readonly property int active: list.findIndex(w => w.is_active)
    readonly property string label: {
        if (!ws)
            return "";
        if (ws.idx === 0)
            return I18n.t("чистый стол", "clean desk");
        const names = Config.workspaces.names || {};
        return names[ws.output + ":" + ws.idx] || ws.name || (I18n.t("стол ", "desk ") + ws.idx);
    }
    readonly property var phrases: ["♡ welcome back ♡", I18n.t("работаем~", "Working~"), I18n.t("не забудь попить воды", "Remember to drink water"), "OMG kawaii", I18n.t("ты справишься ♡", "You can do it ♡"), I18n.t("стрим скоро?", "Streaming soon?"), "angel mode: ON", I18n.t("ещё чуть-чуть…", "Just a little more…"), "internet angel ✧", I18n.t("лайк, подписка ♡", "Like and subscribe ♡")]
    property string phrase: ""

    // ---- the window ----
    readonly property int gap: Serp.px(10)
    property real out: shown ? 0 : 1        // 0 in, 1 out past the edge
    Behavior on out {
        NumberAnimation {
            id: slideAnim
            duration: win.shown ? Serp.normal : 200
            easing.type: win.shown ? Easing.OutCubic : Easing.InCubic
        }
    }

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
        interval: 280
        onTriggered: win.alive = false
    }
    visible: alive
    // niri's blur can't fade: off the screen as soon as it is nearly gone (no frosted plate)
    onOutChanged: if (!shown && alive && out > 0.88)
        alive = false
    anchors.right: true
    implicitWidth: content.width + gap * 2
    implicitHeight: Math.max(island.height, labelCard.height) + gap * 2
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "angelos-serpdesks"
    WlrLayershell.layer: WlrLayer.Overlay
    BackgroundEffect.blurRegion: Serp.blurOn && shown && win.out < 0.15 ? blurRegion : noBlur  // only while it stands whole
    Region {
        id: blurRegion
        Region {
            item: win.showLabel ? labelCard : null
            radius: Serp.radius
        }
        Region {
            item: win.showStrip ? island : null
            radius: Serp.radius
        }
    }
    Region {
        id: noBlur
    }

    Item {
        id: content
        width: (win.showLabel ? labelCard.width : 0) + (win.showLabel && win.showStrip ? win.gap : 0) + (win.showStrip ? island.width : 0)
        height: parent.height
        // a short glide and a fade, not the whole width past the edge: the glass inside re-reads
        // the wallpaper under it a frame late, and a long slide made it shudder when it left
        // slides in; leaves by fading only (no move: the glass inside lags a frame and jerked)
        x: win.gap + (win.shown ? win.out : 0) * Serp.px(18)
        opacity: 1 - win.out

        // ---- the desk's name ----
        SGlass {
            id: labelCard
            visible: win.showLabel
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(Serp.px(120), labelCol.implicitWidth + Serp.px(52))
            height: Math.max(Serp.px(44), labelCol.implicitHeight + Serp.px(20))
            radius: Serp.radius
            backdrop: glassBack
            Rectangle {
                id: numBox
                x: Serp.px(7)
                anchors.verticalCenter: parent.verticalCenter
                width: Serp.px(30)
                height: width
                radius: Serp.radiusSmall
                color: Serp.surface1
                SIcon {
                    visible: !!win.ws && win.ws.idx === 0
                    anchors.centerIn: parent
                    name: "plus"
                    size: Serp.px(14)
                    color: Serp.accent
                }
                SText {
                    visible: !!win.ws && win.ws.idx !== 0
                    anchors.centerIn: parent
                    text: win.ws ? win.ws.idx : ""
                    bold: true
                    color: Serp.accent
                }
            }
            Column {
                id: labelCol
                anchors.left: numBox.right
                anchors.leftMargin: Serp.px(10)
                anchors.verticalCenter: parent.verticalCenter
                SText {
                    text: win.label
                    bold: true
                    width: Math.min(implicitWidth, Serp.px(220))
                }
                SText {
                    visible: Config.workspaces.phrases && win.phrase !== ""
                    text: win.phrase
                    size: Serp.smallSize
                    dim: true
                    width: Math.min(implicitWidth, Serp.px(220))
                }
            }
        }

        // ---- the island: desk 0's "+", the desks as pills ----
        SGlass {
            id: island
            visible: win.showStrip
            x: win.showLabel ? labelCard.width + win.gap : 0
            anchors.verticalCenter: parent.verticalCenter
            width: Serp.px(28)
            height: col.height + Serp.px(18)
            radius: Serp.radius
            backdrop: glassBack

            readonly property int dot: Serp.px(9)
            readonly property int tall: Serp.px(24)
            readonly property int sp: Serp.px(7)
            readonly property int top0: Serp.px(9) + (win.zero ? zeroIcon.height + sp : 0)
            readonly property real colH: win.list.length ? win.list.length * dot + (win.active >= 0 ? tall - dot : 0) + sp * (win.list.length - 1) : 0
            // where slot i stands once the layout settles (the active one is tall)
            function slotY(i) {
                return top0 + i * (dot + sp) + (win.active >= 0 && i > win.active ? tall - dot : 0);
            }
            function slotH(i) {
                return i === win.active ? tall : dot;
            }

            Item {
                id: col
                y: Serp.px(9)
                width: parent.width
                height: (win.zero ? zeroIcon.height + island.sp : 0) + island.colH
            }

            SIcon {
                id: zeroIcon
                visible: !!win.zero
                anchors.horizontalCenter: parent.horizontalCenter
                y: Serp.px(9)
                name: "plus"
                size: Serp.px(13)
                stroke: 2.4
                color: win.zeroLit ? Serp.accent : Serp.subtext0
                opacity: win.zeroLit ? 1 : 0.6
            }

            Repeater {
                model: win.list
                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool used: win.visible && Niri.windowsOn(modelData.id).length > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: island.slotY(index)
                    width: island.dot
                    height: modelData.is_active ? island.tall : island.dot
                    radius: width / 2
                    color: modelData.is_urgent ? Serp.red : used ? Qt.alpha(Serp.text, 0.4) : Qt.alpha(Serp.text, 0.16)
                    opacity: modelData.is_active ? 0 : 1
                    Behavior on y {
                        enabled: win.visible
                        NumberAnimation {
                            duration: 380
                            easing.type: Easing.OutQuint
                        }
                    }
                    Behavior on height {
                        enabled: win.visible
                        NumberAnimation {
                            duration: 380
                            easing.type: Easing.OutQuint
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Serp.quick
                        }
                    }
                }
            }

            // the active pill: its top and bottom edges move apart — the leading one first
            // (200 ms), the trailing one after (420 ms), so it stretches like Serpantinum's
            Rectangle {
                id: ind
                property real t: 0
                property real b: 0
                property int at: -1
                visible: win.active >= 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: t
                width: island.dot
                height: Math.max(island.dot, b - t)
                radius: width / 2
                color: Serp.accent
                Behavior on t {
                    enabled: ind.glide
                    NumberAnimation {
                        id: tAnim
                        duration: 380
                        easing.type: Easing.OutQuint
                    }
                }
                Behavior on b {
                    enabled: ind.glide
                    NumberAnimation {
                        id: bAnim
                        duration: 380
                        easing.type: Easing.OutQuint
                    }
                }
                property bool glide: false
                function go(to) {
                    const from = at;
                    at = to;
                    if (to < 0)
                        return;
                    const tt = island.slotY(to), tb = tt + island.slotH(to);
                    // freshly shown (or the list changed under it): it stands, no glide
                    glide = from >= 0 && win.visible && win.out < 1;
                    if (glide) {
                        const down = to > from;
                        tAnim.duration = down ? 420 : 200;
                        bAnim.duration = down ? 200 : 420;
                    }
                    t = tt;
                    b = tb;
                }
            }
        }
    }

    onActiveChanged: ind.go(active)
    onVisibleChanged: if (visible)
        Qt.callLater(() => ind.go(win.active))
    Connections {
        target: island
        function onTop0Changed() {
            ind.glide = false;
            ind.go(win.active);
        }
    }

    RightClickGuard {}
}
