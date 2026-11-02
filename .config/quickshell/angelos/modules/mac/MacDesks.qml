pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The Golden Gate menu bar's desks and its overview button (Settings → Golden Gate → Appearance).
// MacMenuBar keeps one copy at each place they may stand: "left" (before the emblem), "icons" (left
// of the status icons, where a Mac's menu bar extras go) and "clock" (by the clock); a copy shows
// what Config.mac.barDesksAt and barOverviewAt put at its place, the button first.
// The desks: numbers or dots (Config.mac.barDesks), angel-niri's clean desk 0 first if there is one.
// Lit (Config.mac.barDesksLit): "all" — the one in front filled, the empty ones paler, one with a
// window asking for you red; "current" — only the one in front; "none" — all alike. A click goes
// to the desk, the wheel switches (WorkspaceAnim), a right click opens Mission Control here. "+"
// opens a new desk where Desktop keeps it out of sight (WindowConfig.newDeskShown).
Item {
    id: root

    required property string place
    required property string screenName
    required property color ink
    required property real rowH

    readonly property bool showButton: Config.mac.barOverview !== "off" && Config.mac.barOverviewAt === place
    readonly property bool showDesks: Config.mac.barDesks !== "off" && Config.mac.barDesksAt === place
    readonly property bool mission: Config.mac.barOverview === "mission"
    readonly property bool dots: Config.mac.barDesks === "dots"
    readonly property string lit: Config.mac.barDesksLit
    // nothing to count where the desks don't stand (the other copies)
    readonly property var list: {
        if (!showDesks)
            return [];
        const zero = Niri.zeroDesk(screenName);
        return (zero ? [zero] : []).concat(Niri.workspacesOn(screenName));
    }
    readonly property bool plus: showDesks && WindowConfig.newDeskShown(screenName)
    // the number on a filled desk: the bar's ink knocked out
    readonly property color knockout: ink.r > 0.5 ? "#1d1d1f" : "#ffffff"

    visible: showButton || showDesks
    width: visible ? row.implicitWidth + GoldenGate.px(8) : 0
    height: rowH

    function overview() {
        if (mission)
            Mission.toggle(screenName);
        else
            Niri.toggleOverview();
    }
    // a desk's fill: dots are the fill; numbers show it only filled, asking or under the pointer
    function fillOf(cell) {
        if (cell.filled)
            return ink;
        if (cell.asking)
            return Theme.danger;
        if (dots)
            return cell.pale ? "transparent" : Qt.alpha(ink, lit === "all" ? 0.55 : 0.45);
        return cell.hovered ? Qt.alpha(ink, 0.14) : "transparent";
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: Mission.open(root.screenName)
        onWheel: w => {
            if (root.showDesks)
                WorkspaceAnim.stepDesk(root.screenName, w.angleDelta.y > 0);
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: GoldenGate.px(6)

        // the overview: niri's (as Control Center's Mission Control) or angelOS's Mission Control
        MacStatusButton {
            visible: root.showButton
            anchors.verticalCenter: parent.verticalCenter
            ink: root.ink
            rowH: root.rowH
            active: root.mission ? Mission.shown : Niri.overviewOpen
            MacIcon {
                name: root.mission ? "layout-dashboard" : "layout-grid"
                color: root.ink
                stroke: 1.9
            }
            onClicked: root.overview()
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
                    readonly property bool hovered: deskMouse.containsMouse
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.dots ? GoldenGate.px(8) : Math.max(GoldenGate.px(18), num.implicitWidth + GoldenGate.px(8))
                    height: root.dots ? GoldenGate.px(8) : GoldenGate.px(16)
                    Rectangle {
                        anchors.fill: parent
                        radius: root.dots ? width / 2 : GoldenGate.px(4)
                        color: root.fillOf(cell)
                        border.width: root.dots && cell.pale ? Math.max(1, GoldenGate.px(1.2)) : 0
                        border.color: Qt.alpha(root.ink, 0.55)
                    }
                    MacText {
                        id: num
                        visible: !root.dots
                        anchors.centerIn: parent
                        text: String(cell.ws.idx === undefined ? "" : cell.ws.idx)
                        size: GoldenGate.px(11)
                        semibold: true
                        color: cell.filled ? root.knockout : cell.asking ? "#ffffff" : Qt.alpha(root.ink, cell.pale ? 0.45 : 1)
                    }
                    MouseArea {
                        id: deskMouse
                        anchors.fill: parent
                        anchors.margins: -GoldenGate.px(2)
                        hoverEnabled: true
                        onClicked: WorkspaceAnim.goDesk(cell.ws)
                    }
                }
            }
            // a new desk at the end (angel-niri's Desktop)
            Item {
                visible: root.plus
                anchors.verticalCenter: parent.verticalCenter
                width: root.dots ? GoldenGate.px(10) : GoldenGate.px(18)
                height: GoldenGate.px(16)
                Rectangle {
                    anchors.fill: parent
                    radius: GoldenGate.px(4)
                    color: plusMouse.containsMouse ? Qt.alpha(root.ink, 0.14) : "transparent"
                }
                MacIcon {
                    anchors.centerIn: parent
                    name: "plus"
                    size: GoldenGate.px(root.dots ? 10 : 12)
                    color: Qt.alpha(root.ink, 0.7)
                    stroke: 2.2
                }
                MouseArea {
                    id: plusMouse
                    anchors.fill: parent
                    anchors.margins: -GoldenGate.px(2)
                    hoverEnabled: true
                    onClicked: Niri.openSpareDesk(root.screenName)
                }
            }
        }
    }
}
