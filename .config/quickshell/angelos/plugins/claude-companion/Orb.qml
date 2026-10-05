import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.config
import qs.services
import qs.widgets
import "."

// Desktop presence ("claude.exe"): breathing mascot, state, limits. The host draws the frame.
// macOS look (DesktopWidgets.macLook): a status card — a badge in the state's colour that
// breathes while Claude works, the state, her message, the limits as thin bars.
Item {
    id: root

    property var plugin
    property string screenName
    property var widget
    readonly property string mode: plugin ? plugin.get("orb", "active") : "active"   // always | active | off
    // the host hides the frame when this is false (still movable in edit mode)
    readonly property bool wantVisible: mode === "always" || (mode === "active" && (Pulse.state !== "none" || !!Pulse.presence))

    readonly property bool mac: DesktopWidgets.macLook
    implicitWidth: mac ? DesktopWidgets.mpx(250) : Theme.u * 116
    implicitHeight: mac ? macCol.implicitHeight : col.implicitHeight

    // ---- macOS look ----
    readonly property color stateColor: DesktopWidgets.macInk(Pulse.colorFor(Pulse.state, Theme))
    readonly property bool working: Pulse.state === "turn_start" || Pulse.state === "text" || Pulse.state === "tool_start"
    readonly property bool urgent: Pulse.state === "needs_attention" || Pulse.state === "error"
    // the badge's breath: stepped at 10 frames a second like the mascot's (Breath), and only
    // while there is something to tell
    property real breath: 0
    property real _phase: 0
    Timer {
        interval: 100
        repeat: true
        running: root.mac && root.visible && (root.working || root.urgent) && !Motion.still
        onRunningChanged: if (!running)
            root.breath = 0
        onTriggered: {
            root._phase = (root._phase + interval / (root.urgent ? 2000 : 4000)) % 1;
            const v = Math.round((0.5 - 0.5 * Math.cos(root._phase * 2 * Math.PI)) * 12) / 12;
            if (v !== root.breath)
                root.breath = v;
        }
    }
    Column {
        id: macCol
        visible: root.mac
        width: parent.width
        spacing: DesktopWidgets.mpx(10)
        Row {
            width: parent.width
            spacing: DesktopWidgets.mpx(10)
            Item {
                id: badge
                width: DesktopWidgets.mpx(38)
                height: width
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * (1 + 0.18 * root.breath)
                    height: width
                    radius: width / 2
                    color: Qt.alpha(root.stateColor, 0.16 * (1 - root.breath))
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.alpha(root.stateColor, Pulse.state === "none" ? 0.12 : 0.22)
                }
                // an eight-ray spark in the state's colour
                Shape {
                    anchors.centerIn: parent
                    width: parent.width * 0.5
                    height: width
                    preferredRendererType: Shape.CurveRenderer
                    rotation: root.working ? root._phase * 90 : 0
                    ShapePath {
                        strokeColor: Pulse.state === "none" ? DesktopWidgets.macTertiary : root.stateColor
                        strokeWidth: Math.max(2, DesktopWidgets.mpx(2.6))
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathMultiline {
                            readonly property real c: badge.width * 0.25
                            readonly property real r: c - DesktopWidgets.mpx(1.5)
                            paths: [0, 1, 2, 3].map(i => {
                                const a = i * Math.PI / 4;
                                return [Qt.point(c - r * Math.cos(a), c - r * Math.sin(a)), Qt.point(c + r * Math.cos(a), c + r * Math.sin(a))];
                            })
                        }
                    }
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - badge.width - parent.spacing
                MacWidgetText {
                    width: parent.width
                    text: "Claude"
                    size: 15
                    weight: Font.DemiBold
                }
                MacWidgetText {
                    width: parent.width
                    readonly property string w: Pulse.wordFor(false).replace(" ♡", "")
                    text: w.charAt(0).toUpperCase() + w.slice(1) + (Pulse.list.length > 1 ? " · " + I18n.t("сессий: ", "sessions: ") + Pulse.list.length : "")
                    size: 13
                    weight: root.urgent ? Font.DemiBold : Font.Normal
                    color: Pulse.state === "none" || Pulse.state === "idle" ? DesktopWidgets.macSecondary : root.stateColor
                }
            }
        }
        MacWidgetText {
            visible: !!Pulse.presence
            width: parent.width
            text: Pulse.presence ? Pulse.presence.message : ""
            size: 13
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            maximumLineCount: 4
        }
        Rectangle {
            width: parent.width
            height: 1
            color: DesktopWidgets.macSeparator
        }
        Limits {
            width: parent.width
            compact: true
            mac: true
        }
    }

    Column {
        id: col
        visible: !root.mac
        width: parent.width
        spacing: Theme.u * 3
        Breath {
            anchors.horizontalCenter: parent.horizontalCenter
            plugin: root.plugin
            pixel: Theme.u * 4
            scale: 0.96 + 0.04 * glow * (root.plugin ? root.plugin.get("swell", 1.0) : 1)
        }
        // hell (manifest "realms"): her words in blackletter, the obsidian palette
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Pulse.wordFor(Theme.hell)
            kind: "title"
            font.family: Theme.hell && Theme.latin(text) ? Theme.fontHell : Theme.fontTitle
            font.pixelSize: Theme.hell && Theme.latin(text) ? Theme.hellPx(Theme.fs) : Theme.sizeTitle
            color: Theme.hell ? Pulse.hellColorFor(Pulse.state, Theme) : Pulse.colorFor(Pulse.state, Theme)
        }
        PxText {
            visible: !!Pulse.presence
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: Pulse.presence ? Pulse.presence.message : ""
            dim: !Theme.hell
            color: Theme.hell ? Theme.hellTextDim : Theme.textDim
        }
        Limits {
            width: parent.width
            compact: true
            hell: Theme.hell
        }
        PxText {
            visible: Pulse.list.length > 1
            anchors.horizontalCenter: parent.horizontalCenter
            text: (Theme.hell ? I18n.t("душ в работе: ", "souls at work: ") : I18n.t("сессий: ", "sessions: ")) + Pulse.list.length
            kind: "tiny"
            dim: !Theme.hell
            color: Theme.hell ? Theme.hellGold : Theme.textDim
        }
    }
}
