import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// The mascot: face tinted by state, breathing slowly and softly (a bit quicker when it needs you).
// Mac look (Skin.mac, not on hell's desktop): the "bot" line icon instead of the pixel face —
// tinted by the state, or with `mono` one colour (`monoColor`: the menu bar's ink) and the state
// as a small dot when it is busy or wants you, like a macOS menu bar extra. 8 × pixel tall.
Item {
    id: root

    property var plugin
    property int pixel: Theme.u
    property string state: Pulse.state
    readonly property real speed: plugin ? plugin.get("breath", 1.0) : 1.0
    readonly property bool urgent: state === "needs_attention" || state === "error"
    readonly property bool busy: state === "turn_start" || state === "text" || state === "tool_start"
    property real glow: 1

    property bool mono: false
    property color monoColor: Skin.text
    readonly property bool mac: Skin.mac && !hellLook && !barLook
    implicitWidth: mac ? macFace.implicitWidth : face.width
    implicitHeight: mac ? macFace.implicitHeight : face.height

    // Pixel-stepped breathing: ~10 frames a second, and only distinct values
    // reach the scene graph. A 60 fps NumberAnimation here kept every bar and
    // the full-screen desktop layer repainting and cost several % CPU idle.
    property real _phase: 0
    Timer {
        interval: 100
        repeat: true
        running: root.visible && root.state !== "none" && root.state !== "idle" && root.speed > 0
        onRunningChanged: if (!running)
            root.glow = 1
        onTriggered: {
            // one full breath ≈ 4 s (≈ 2 s when it waits for you); depth stays gentle
            const period = (root.urgent ? 2000 : 4000) / Math.max(0.1, root.speed);
            root._phase = (root._phase + interval / period) % 1;
            const depth = root.urgent ? 0.55 : root.busy ? 0.3 : 0.18;
            const v = 1 - depth * (0.5 - 0.5 * Math.cos(root._phase * 2 * Math.PI));
            const stepped = Math.round(v * 16) / 16;
            if (stepped !== root.glow)
                root.glow = stepped;
        }
    }

    // the demon rules: horns where the halo was (on the bar too); on the desktop in
    // hell (Theme.hell) a mask in the circle's colours — the state shows only as a faint
    // tint and in the two embers of its eyes
    property bool horns: Angel.demon || Theme.hell
    property bool hellLook: Theme.hell
    // on the hell bar: the mask drawn like the bar's icons — its outline and horns in the
    // icon colour, no fill — and its eyes tell the state: the accent only when it wants you
    property bool barLook: false

    Loader {
        id: macFace
        active: root.mac
        visible: active
        sourceComponent: Item {
            implicitWidth: root.pixel * 8
            implicitHeight: root.pixel * 8
            MacIcon {
                name: "bot"
                size: root.pixel * 8
                stroke: 2
                color: root.mono ? root.monoColor : Pulse.colorFor(root.state, Theme)
                opacity: root.state === "none" ? 0.6 : root.glow
            }
            // the state on a one-colour icon: a dot at its corner (busy, done, wants you)
            Rectangle {
                visible: root.mono && root.state !== "none" && root.state !== "idle"
                width: Math.max(4, root.pixel * 2.6)
                height: width
                radius: width / 2
                x: parent.width - width * 0.8
                y: parent.height - width * 0.9
                color: Pulse.colorFor(root.state, Theme)
            }
        }
    }
    PxIcon {
        id: face
        visible: !root.mac
        name: root.hellLook || root.barLook ? "botHell" : root.horns ? "botHorns" : "bot"
        pixel: root.pixel
        ink: root.barLook ? Theme.hellBarIcon : root.hellLook ? Theme.hellRim : (Theme.dark ? Theme.text : Theme.edge)
        body: root.hellLook ? Theme.mix(Theme.hellFace, Pulse.hellColorFor(root.state, Theme), 0.2) : Pulse.colorFor(root.state, Theme)
        palette: root.barLook ? ({
                "f": "none"
            }) : ({})
        fill: root.hellLook || root.barLook ? Theme.hellBlood : Theme.accent
        fill3: root.state === "none" ? Theme.textDim : Theme.accent3
        light: root.barLook ? Pulse.hellColorFor(root.state, Theme) : root.hellLook ? (root.state === "none" || root.state === "idle" ? Theme.hellRim : Theme.hellAccent) : "#ffffff"
        bad: root.barLook ? Theme.hellBarIcon : root.hellLook ? Theme.hellTextDim : "#e0203a"
        opacity: root.state === "none" ? (root.barLook ? 0.8 : 0.6) : root.glow
    }
}
