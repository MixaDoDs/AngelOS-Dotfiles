import QtQuick
import Quickshell
import qs.config
import qs.services

// App icon by app-id / icon name; falls back to a pixel window.
Item {
    id: root

    property string appId: ""
    property string iconName: ""
    property int size: Theme.u * 8
    property string tint: "off"   // off | mono | accent
    // on the hell bar: the circle's sprite ramp instead (HellBarTint), so no app icon turns
    // into a blot or sinks into the plate
    property bool hellBar: false
    layer.enabled: hellBar
    layer.effect: HellBarTint {}

    readonly property string resolved: {
        let name = iconName;
        if (!name && appId) {
            // the entries may come after the icon (a restart): look again once they're in
            void DesktopEntries.applications.values;
            const e = DesktopEntries.heuristicLookup(appId);
            name = e && e.icon ? e.icon : appId;
        }
        if (!name)
            return "";
        if (name.startsWith("/") || name.includes("://"))
            return name.startsWith("/") ? "file://" + name : name;
        // none in the icon theme: a pixel icon of ours for it (StdIcon), else the window below
        return Quickshell.iconPath(name, true) || Quickshell.iconPath(name.toLowerCase(), true) || StdIcon.pixel(name);
    }

    implicitWidth: size
    implicitHeight: size

    TintedImage {
        anchors.fill: parent
        visible: root.resolved !== ""
        source: root.resolved
        size: root.size
        mode: root.hellBar ? "off" : root.tint
    }
    PxIcon {
        anchors.centerIn: parent
        visible: root.resolved === ""
        name: "window"
        pixel: Math.max(1, Math.floor(root.size / 10))
    }
}
