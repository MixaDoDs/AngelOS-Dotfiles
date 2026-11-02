pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The Golden Gate menu bar's desks and its overview button (Settings → Golden Gate → Appearance).
// MacMenuBar keeps one copy at each place they may stand: "left" (before the emblem), "icons" (left
// of the status icons, where a Mac's menu bar extras go) and "clock" (by the clock); a copy shows
// what Config.mac.barDesksAt and barOverviewAt put at its place, the button first.
// The desks: numbers or dots (Config.mac.barDesks). Lit (Config.mac.barDesksLit): "all" — the one
// in front filled, the empty ones paler, one with a window asking for you red; "current" — only
// the one in front; "none" — all alike. A click goes to the desk, the wheel switches, a right
// click opens Mission Control. Desktop on angel-niri keeps no empty desk at the end (its spare one
// is out of sight): "+" opens one, as Mission Control's "+" does; stock niri's empty last desk is
// a desk like the others.
Item {
    id: root

    required property string place
    required property string screenName
    required property color ink
    required property real rowH

    readonly property bool showButton: Config.mac.barOverview !== "off" && Config.mac.barOverviewAt === place
    readonly property bool showDesks: Config.mac.barDesks !== "off" && Config.mac.barDesksAt === place
    readonly property bool dots: Config.mac.barDesks === "dots"
    readonly property string lit: Config.mac.barDesksLit
    readonly property var list: {
        const l = Niri.workspacesOn(screenName).slice().sort((a, b) => a.idx - b.idx);
        const last = l[l.length - 1];
        if (stacking && l.length > 1 && !last.is_active && !last.name && Niri.windowsOn(last.id).length === 0)
            l.pop();
        return l;
    }
    readonly property bool stacking: Niri.nativeMinimize && WindowConfig.floatAll
    // "+": the last desk has windows (empty, it is the new one already)
    readonly property bool plus: stacking && list.length > 0 && Niri.windowsOn(list[list.length - 1].id).length > 0
    readonly property int activeIndex: list.findIndex(w => w.is_active)
    // the number on a filled desk: the bar's ink knocked out
    readonly property color knockout: ink.r > 0.5 ? "#1d1d1f" : "#ffffff"
    readonly property color urgent: "#ff3b30"

    visible: showButton || showDesks
    width: visible ? row.implicitWidth + GoldenGate.px(8) : 0
    height: rowH

    // another screen in focus: its desk by id, the workspace keys would switch the focused screen's
    function go(ws) {
        if (ws.output === Niri.focusedOutput)
            WorkspaceAnim.go(String(ws.idx));
        else
            Niri.focusWorkspace(ws.id);
    }
    function openSpare() {
        Niri.action("OpenSpareWorkspace", {
            "output": screenName
        });
    }
    function overview() {
        if (Config.mac.barOverview === "mission")
            Mission.open();
        else
            Niri.toggleOverview();
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: Mission.open()
        onWheel: w => {
            if (!root.showDesks)
                return;
            const to = root.list[root.activeIndex + (w.angleDelta.y > 0 ? -1 : 1)];
            if (to)
                root.go(to);
        }
    }

    // a hover plate, like the other status items'
    component Plate: Rectangle {
        property bool on: false
        anchors.fill: parent
        anchors.topMargin: -GoldenGate.px(1)
        anchors.bottomMargin: -GoldenGate.px(1)
        anchors.leftMargin: -GoldenGate.px(2)
        anchors.rightMargin: -GoldenGate.px(2)
        radius: GoldenGate.px(5)
        color: on ? Qt.alpha(root.ink, root.ink.r > 0.5 ? 0.2 : 0.1) : "transparent"
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: GoldenGate.px(6)

        // the overview: niri's (as Control Center's Mission Control) or angelOS's Mission Control
        Item {
            visible: root.showButton
            anchors.verticalCenter: parent.verticalCenter
            width: GoldenGate.px(22)
            height: GoldenGate.px(18)
            Plate {
                on: buttonHover.containsMouse || (Config.mac.barOverview === "mission" ? Mission.shown : Niri.overviewOpen)
            }
            MacIcon {
                anchors.centerIn: parent
                name: Config.mac.barOverview === "mission" ? "layout-dashboard" : "layout-grid"
                color: root.ink
                stroke: 1.9
            }
            MouseArea {
                id: buttonHover
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.overview()
            }
        }

        Row {
            visible: root.showDesks
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.dots ? GoldenGate.px(5) : GoldenGate.px(2)
            // model = the count: niri sends a new list on every switch
            Repeater {
                model: root.list.length
                Item {
                    id: cell
                    required property int index
                    readonly property var ws: root.list[index] || ({})
                    readonly property bool front: !!ws.is_active
                    readonly property bool occupied: Niri.windowsOn(ws.id).length > 0
                    readonly property bool filled: front && root.lit !== "none"
                    readonly property bool asking: root.lit === "all" && !front && !!ws.is_urgent
                    readonly property bool pale: root.lit === "all" && !front && !asking && !occupied
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.dots ? GoldenGate.px(8) : Math.max(GoldenGate.px(18), num.implicitWidth + GoldenGate.px(8))
                    height: root.dots ? GoldenGate.px(8) : GoldenGate.px(16)
                    Rectangle {
                        anchors.fill: parent
                        radius: root.dots ? width / 2 : GoldenGate.px(4)
                        color: cell.filled ? root.ink : cell.asking ? root.urgent : root.dots ? (cell.pale ? "transparent" : Qt.alpha(root.ink, root.lit === "all" ? 0.55 : 0.45)) : deskHover.containsMouse ? Qt.alpha(root.ink, 0.14) : "transparent"
                        border.width: root.dots && cell.pale ? Math.max(1, GoldenGate.px(1.2)) : 0
                        border.color: Qt.alpha(root.ink, 0.55)
                    }
                    MacText {
                        id: num
                        visible: !root.dots
                        anchors.centerIn: parent
                        text: String(cell.ws.idx || "")
                        size: GoldenGate.px(11)
                        semibold: true
                        color: cell.filled ? root.knockout : cell.asking ? "#ffffff" : Qt.alpha(root.ink, cell.pale ? 0.45 : 1)
                    }
                    MouseArea {
                        id: deskHover
                        anchors.fill: parent
                        anchors.margins: -GoldenGate.px(2)
                        hoverEnabled: true
                        onClicked: root.go(cell.ws)
                    }
                }
            }
            // a new desk at the end (angel-niri's Desktop)
            Item {
                visible: root.plus
                anchors.verticalCenter: parent.verticalCenter
                width: root.dots ? GoldenGate.px(10) : GoldenGate.px(18)
                height: GoldenGate.px(16)
                Plate {
                    on: plusHover.containsMouse
                }
                MacIcon {
                    anchors.centerIn: parent
                    name: "plus"
                    size: GoldenGate.px(root.dots ? 10 : 12)
                    color: Qt.alpha(root.ink, 0.7)
                    stroke: 2.2
                }
                MouseArea {
                    id: plusHover
                    anchors.fill: parent
                    anchors.margins: -GoldenGate.px(2)
                    hoverEnabled: true
                    onClicked: root.openSpare()
                }
            }
        }
    }
}
