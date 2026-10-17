pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Experimental sidebar (Settings → Bar → Sidebar). A small bookmark tab sits on
// the chosen screen edge: click opens the panel (or the phone: Config.sidebar.look, Phone),
// drag moves the tab — it snaps to the nearest edge.
Scope {
    id: root

    Variants {
        model: Sidebar.enabled ? Shell.screens.filter(s => s.name === Sidebar.screenName) : []

        Scope {
            id: scope
            required property var modelData
            readonly property string edge: Config.sidebar.edge || "right"
            readonly property bool vertical: edge === "left" || edge === "right"

            // ---- the bookmark tab ----
            PanelWindow {
                id: tab
                screen: scope.modelData
                visible: !Shell.locked
                readonly property int longSide: Theme.u * 36
                readonly property int shortSide: Theme.u * 11
                implicitWidth: scope.vertical ? shortSide : longSide
                implicitHeight: scope.vertical ? longSide : shortSide
                anchors.left: scope.edge === "left" || !scope.vertical
                anchors.right: scope.edge === "right"
                anchors.top: scope.edge === "top" || scope.vertical
                anchors.bottom: scope.edge === "bottom"
                margins.top: scope.vertical ? Math.round(Config.sidebar.offset * (scope.modelData.height - longSide)) : 0
                margins.left: scope.vertical ? 0 : Math.round(Config.sidebar.offset * (scope.modelData.width - longSide))
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: 0
                color: "transparent"
                WlrLayershell.namespace: "angelos-sidebar-tab"
                WlrLayershell.layer: WlrLayer.Top

                // where the tab sits on the screen (for turning drag positions into screen points)
                readonly property point origin: Qt.point(scope.edge === "right" ? scope.modelData.width - width : scope.vertical ? 0 : margins.left, scope.edge === "bottom" ? scope.modelData.height - height : scope.vertical ? margins.top : 0)

                PxBox {
                    anchors.fill: parent
                    color: Sidebar.open || Sidebar.shown ? Theme.accent : tabMouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.3) : Theme.panel
                    edgeColor: Theme.menuBorder
                    PxIcon {
                        anchors.centerIn: parent
                        name: tabMouse.pressed && Sidebar.dragging ? "sparkle" : "heart"
                        fill: Sidebar.open || Sidebar.shown ? "#ffffff" : Theme.accent
                    }
                }
                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Sidebar.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    property point pressAt
                    onPressed: m => {
                        pressAt = Qt.point(m.x, m.y);
                        Sidebar.dragging = false;
                    }
                    onPositionChanged: m => {
                        if (!pressed)
                            return;
                        if (!Sidebar.dragging && Math.abs(m.x - pressAt.x) + Math.abs(m.y - pressAt.y) < Theme.u * 4)
                            return;
                        Sidebar.dragging = true;
                        // the pointer stays grabbed by the tab, so positions arrive even outside it
                        const s = Sidebar.snap(tab.origin.x + m.x, tab.origin.y + m.y, scope.modelData.width, scope.modelData.height);
                        Sidebar.ghostEdge = s.edge;
                        Sidebar.ghostOffset = s.offset;
                    }
                    onReleased: {
                        if (Sidebar.dragging) {
                            Config.sidebar.edge = Sidebar.ghostEdge;
                            Config.sidebar.offset = Sidebar.ghostOffset;
                            Sidebar.dragging = false;
                        } else {
                            Sidebar.toggle();
                        }
                    }
                }

                RightClickGuard {}
            }

            // ---- where the tab lands while dragging ----
            PanelWindow {
                screen: scope.modelData
                visible: Sidebar.dragging
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
                WlrLayershell.namespace: "angelos-sidebar-ghost"
                WlrLayershell.layer: WlrLayer.Overlay

                readonly property bool gv: Sidebar.ghostEdge === "left" || Sidebar.ghostEdge === "right"
                Rectangle {
                    // the whole edge lights up
                    x: Sidebar.ghostEdge === "right" ? parent.width - width : 0
                    y: Sidebar.ghostEdge === "bottom" ? parent.height - height : 0
                    width: parent.gv ? Theme.u * 2 : parent.width
                    height: parent.gv ? parent.height : Theme.u * 2
                    color: Qt.alpha(Theme.accent, 0.5)
                }
                PxBox {
                    readonly property int ls: Theme.u * 36
                    readonly property int ss: Theme.u * 11
                    width: parent.gv ? ss : ls
                    height: parent.gv ? ls : ss
                    x: parent.gv ? (Sidebar.ghostEdge === "right" ? parent.width - width : 0) : Math.round(Sidebar.ghostOffset * (parent.width - width))
                    y: parent.gv ? Math.round(Sidebar.ghostOffset * (parent.height - height)) : (Sidebar.ghostEdge === "bottom" ? parent.height - height : 0)
                    color: Qt.alpha(Theme.accent, 0.8)
                    PxIcon {
                        anchors.centerIn: parent
                        name: "heart"
                        fill: "#ffffff"
                    }
                }

                RightClickGuard {}
            }

            // ---- the panel ----
            PanelWindow {
                id: panelWin
                screen: scope.modelData
                visible: shown
                property bool shown: false
                readonly property bool open: Sidebar.open
                // the phone plays its own coming and going, and says when it is gone
                readonly property bool phoneHere: Sidebar.phone && Sidebar.shown
                onPhoneHereChanged: if (phoneHere)
                    shown = true
                onOpenChanged: {
                    if (Sidebar.phone)
                        return;
                    if (open) {
                        shown = true;
                        slide.from = 1;
                        slide.to = 0;
                    } else {
                        slide.from = panelWin.slideAt;
                        slide.to = 1;
                    }
                    slide.restart();
                }
                property real slideAt: 1          // 0 = fully out, 1 = hidden behind the edge
                NumberAnimation {
                    id: slide
                    target: panelWin
                    property: "slideAt"
                    duration: Motion.ms(Theme.normal)
                    easing.type: Easing.OutCubic
                    onFinished: if (!panelWin.open)
                        panelWin.shown = false
                }

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: 0
                color: "transparent"
                WlrLayershell.namespace: "angelos-sidebar"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
                // open: a click anywhere beside it shuts it (the phone: its lid); the phone shut
                // on the desk takes only the clicks on itself
                mask: Region {
                    item: panelWin.open ? catcher : phoneLoader.item ? phoneLoader.item.hitBox : null
                    Region {
                        item: !panelWin.open && phoneLoader.item ? phoneLoader.item.plugBox : null
                    }
                }
                BackgroundEffect.blurRegion: Config.appearance.blur && panelWin.shown && !Sidebar.phone ? blurRegion : null
                Region {
                    id: blurRegion
                    item: panel
                }

                MouseArea {
                    id: catcher
                    anchors.fill: parent
                    onPressed: Sidebar.open = false
                }

                readonly property real gap: Theme.u * 13
                readonly property real anchorAlong: Config.sidebar.offset * (scope.vertical ? height : width)
                // the phone: it rests where the panel would, its middle on the tab's line
                Loader {
                    id: phoneLoader
                    anchors.fill: parent
                    active: Sidebar.phone && panelWin.shown
                    focus: true
                    sourceComponent: Phone {
                        focus: true
                        edge: scope.edge
                        readonly property real reach: Theme.u * 150
                        restX: scope.edge === "left" ? panelWin.gap + reach : scope.edge === "right" ? panelWin.width - panelWin.gap - reach : Math.max(reach, Math.min(panelWin.width - reach, panelWin.anchorAlong))
                        restY: scope.edge === "top" ? panelWin.gap + Theme.u * 140 : scope.edge === "bottom" ? panelWin.height - panelWin.gap - Theme.u * 140 : Math.max(Theme.u * 140, Math.min(panelWin.height - Theme.u * 140, panelWin.anchorAlong))
                        onGone: panelWin.shown = false
                    }
                }

                SidebarPanel {
                    id: panel
                    visible: !Sidebar.phone
                    focus: !Sidebar.phone
                    height: Math.min(implicitHeight, panelWin.height - Theme.u * 8)
                    readonly property real restX: scope.edge === "left" ? panelWin.gap : scope.edge === "right" ? panelWin.width - width - panelWin.gap : Math.max(Theme.u * 4, Math.min(panelWin.width - width - Theme.u * 4, panelWin.anchorAlong - width / 2))
                    readonly property real restY: scope.edge === "top" ? panelWin.gap : scope.edge === "bottom" ? panelWin.height - height - panelWin.gap : Math.max(Theme.u * 4, Math.min(panelWin.height - height - Theme.u * 4, panelWin.anchorAlong - height / 2))
                    x: restX + (scope.edge === "left" ? -1 : scope.edge === "right" ? 1 : 0) * panelWin.slideAt * (width + panelWin.gap)
                    y: restY + (scope.edge === "top" ? -1 : scope.edge === "bottom" ? 1 : 0) * panelWin.slideAt * (height + panelWin.gap)
                    Keys.onEscapePressed: Sidebar.open = false
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                    }
                }

                RightClickGuard {}
            }
        }
    }
}
