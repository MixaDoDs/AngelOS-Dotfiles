pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The Angel's diary at hand: a leather bookmark on a screen edge, like the sidebar's tab
// (modules/sidebar/SidebarHost), once the diary's key is had (services/Diary). A click opens
// the diary, a drag moves the bookmark to another edge (it snaps to the nearest one); the
// number on it is the pages not read yet. Settings → Achievements → Things turns it off
// (Config.game.diaryTab; diaryEdge, diaryOffset: where it sits).
Scope {
    id: root

    // gone for good once she caught you and hid it (Settings → Achievements → Things opens it then)
    readonly property bool wanted: Config.ready && Config.game.diaryTab !== false && Diary.owned && !Diary.hidden && !Shell.locked && !Shell.setupLocked
    property bool dragging: false
    property string ghostEdge: ""
    property real ghostOffset: 0.5

    Variants {
        model: root.wanted ? Shell.screens.filter(s => s === Shell.primaryScreen) : []

        Scope {
            id: scope
            required property var modelData
            readonly property string edge: Config.game.diaryEdge || "left"
            readonly property bool vertical: edge === "left" || edge === "right"
            readonly property real offset: Math.max(0.03, Math.min(0.97, Config.game.diaryOffset >= 0 ? Config.game.diaryOffset : 0.35))

            PanelWindow {
                id: tab
                screen: scope.modelData
                readonly property int longSide: Theme.u * 30
                readonly property int shortSide: Theme.u * 12
                implicitWidth: scope.vertical ? shortSide : longSide
                implicitHeight: scope.vertical ? longSide : shortSide
                anchors.left: scope.edge === "left" || !scope.vertical
                anchors.right: scope.edge === "right"
                anchors.top: scope.edge === "top" || scope.vertical
                anchors.bottom: scope.edge === "bottom"
                margins.top: scope.vertical ? Math.round(scope.offset * (scope.modelData.height - longSide)) : 0
                margins.left: scope.vertical ? 0 : Math.round(scope.offset * (scope.modelData.width - longSide))
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: 0
                color: "transparent"
                WlrLayershell.namespace: "angelos-diary-tab"
                WlrLayershell.layer: WlrLayer.Top

                readonly property point origin: Qt.point(scope.edge === "right" ? scope.modelData.width - width : scope.vertical ? 0 : margins.left, scope.edge === "bottom" ? scope.modelData.height - height : scope.vertical ? margins.top : 0)
                readonly property bool hot: mouse.containsMouse || Shell.diaryOpen

                // the bookmark: black-red leather, a gold hairline, the pentagram
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.u * 2
                    color: tab.hot ? "#4a121d" : "#2a0a10"
                    border.width: Math.max(1, Theme.u / 2)
                    border.color: "#c9a04a"
                    // the inner border is cut off on the screen's side
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Theme.u * 1.5
                        radius: Theme.u
                        color: "transparent"
                        border.width: Math.max(1, Theme.u / 3)
                        border.color: Qt.alpha("#c9a04a", 0.45)
                    }
                }
                // she is here: her eye is on it (dim, an eye); away: it glows
                Pentagram {
                    anchors.centerIn: parent
                    opacity: Diary.watching ? 0.45 : 1
                    width: Math.min(parent.width, parent.height) * 0.72
                    height: width
                    color: "#e2b955"
                    glowColor: "#ff5a3c"
                    glow: !Diary.watching && (tab.hot || Diary.unread > 0 || Angel.away)
                    animate: Motion.level !== "off"
                }
                PxIcon {
                    visible: Diary.watching
                    anchors.centerIn: parent
                    name: "eye"
                    pixel: Math.max(1, Math.round(Theme.u / 2))
                    fill: "#f2c75c"
                    ink: "#2a0a10"
                }
                // the pages not read yet
                Rectangle {
                    visible: Diary.unread > 0
                    width: Math.max(Theme.u * 6, unreadText.implicitWidth + Theme.u * 2)
                    height: Theme.u * 6
                    radius: height / 2
                    color: "#b3122a"
                    border.width: Math.max(1, Theme.u / 3)
                    border.color: "#f2c75c"
                    x: scope.edge === "right" ? Theme.u : parent.width - width - Theme.u
                    y: scope.edge === "bottom" ? Theme.u : scope.vertical ? Theme.u : parent.height - height - Theme.u
                    PxText {
                        id: unreadText
                        anchors.centerIn: parent
                        kind: "tiny"
                        color: "#ffffff"
                        text: String(Diary.unread)
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    property point pressAt
                    onPressed: m => {
                        pressAt = Qt.point(m.x, m.y);
                        root.dragging = false;
                    }
                    onPositionChanged: m => {
                        if (!pressed)
                            return;
                        if (!root.dragging && Math.abs(m.x - pressAt.x) + Math.abs(m.y - pressAt.y) < Theme.u * 4)
                            return;
                        root.dragging = true;
                        const s = Sidebar.snap(tab.origin.x + m.x, tab.origin.y + m.y, scope.modelData.width, scope.modelData.height);
                        root.ghostEdge = s.edge;
                        root.ghostOffset = s.offset;
                    }
                    onReleased: {
                        if (root.dragging) {
                            Config.game.diaryEdge = root.ghostEdge;
                            Config.game.diaryOffset = root.ghostOffset;
                            root.dragging = false;
                        } else if (Shell.diaryOpen) {
                            Diary.close();
                        } else {
                            Diary.open();
                        }
                    }
                    onCanceled: root.dragging = false
                }
                RightClickGuard {}
            }

            // where the bookmark lands while dragging
            PanelWindow {
                screen: scope.modelData
                visible: root.dragging
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: 0
                color: "transparent"
                mask: Region {}
                WlrLayershell.namespace: "angelos-diary-tab-ghost"
                WlrLayershell.layer: WlrLayer.Overlay

                readonly property bool gv: root.ghostEdge === "left" || root.ghostEdge === "right"
                Rectangle {
                    x: root.ghostEdge === "right" ? parent.width - width : 0
                    y: root.ghostEdge === "bottom" ? parent.height - height : 0
                    width: parent.gv ? Theme.u * 2 : parent.width
                    height: parent.gv ? parent.height : Theme.u * 2
                    color: Qt.alpha("#c9a04a", 0.5)
                }
                Rectangle {
                    readonly property int ls: Theme.u * 30
                    readonly property int ss: Theme.u * 12
                    width: parent.gv ? ss : ls
                    height: parent.gv ? ls : ss
                    x: parent.gv ? (root.ghostEdge === "right" ? parent.width - width : 0) : Math.round(root.ghostOffset * (parent.width - width))
                    y: parent.gv ? Math.round(root.ghostOffset * (parent.height - height)) : (root.ghostEdge === "bottom" ? parent.height - height : 0)
                    radius: Theme.u * 2
                    color: Qt.alpha("#4a121d", 0.85)
                    border.width: Math.max(1, Theme.u / 2)
                    border.color: "#c9a04a"
                }
                RightClickGuard {}
            }
        }
    }
}
