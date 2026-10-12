import QtQuick
import Quickshell
import qs.config

// An app of the author's catalog (data/apps-catalog.json): its own pixel icon
// (data/app-icons/<id>.png, scripts/app-icons.py), else the catalog's icon name. plain: no
// picture of its own to look for (a system package, fish).
Item {
    id: glyph
    property var app: ({})
    property int size: Theme.u * 9
    width: size
    height: size
    readonly property string own: app && app.id && !app.plain ? Quickshell.shellDir + "/data/app-icons/" + app.id + ".png" : ""
    Image {
        id: ownIcon
        anchors.fill: parent
        source: glyph.own ? "file://" + glyph.own : ""
        smooth: false
        mipmap: false
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(32, 32)
    }
    PxIcon {
        anchors.centerIn: parent
        visible: ownIcon.status !== Image.Ready
        name: glyph.app && glyph.app.icon || "package"
        pixel: Math.max(1, Math.round(glyph.size / 14))
    }
}
