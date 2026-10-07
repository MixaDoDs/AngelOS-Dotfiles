import QtQuick
import Quickshell
import qs.services

// Tells services/Zones what this bar window keeps from windows: its exclusive zone on the edge
// it stands on (with the margin there; nothing while hidden, auto-hidden or Ignore). Put one in
// every PanelWindow that keeps an exclusive zone, with a key of its own.
QtObject {
    id: rep

    required property PanelWindow win
    required property string key

    readonly property string screenName: win.screen ? win.screen.name : ""
    readonly property string edge: {
        const a = win.anchors;
        if (a.top !== a.bottom)
            return a.top ? "top" : "bottom";
        if (a.left !== a.right)
            return a.left ? "left" : "right";
        return "";
    }
    readonly property int px: {
        if (!win.visible || !edge || win.exclusionMode === ExclusionMode.Ignore)
            return 0;
        const across = edge === "top" || edge === "bottom";
        const zone = win.exclusionMode === ExclusionMode.Auto ? (across ? win.implicitHeight : win.implicitWidth) : win.exclusiveZone;
        return zone > 0 ? Math.round(zone + (win.margins[edge] || 0)) : 0;
    }
    property string _screen: ""

    function push() {
        if (_screen && _screen !== screenName)
            Zones.drop(_screen, key);
        _screen = screenName;
        Zones.report(screenName, key, edge, px);
    }
    onScreenNameChanged: push()
    onEdgeChanged: push()
    onPxChanged: push()
    Component.onCompleted: push()
    Component.onDestruction: Zones.drop(_screen, key)
}
