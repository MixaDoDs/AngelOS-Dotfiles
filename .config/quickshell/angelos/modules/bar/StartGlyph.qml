import QtQuick
import qs.config
import qs.widgets

// The icon of a Start list row (win11's lists, Spotlight, XMB, the iPhone-like look's search
// extras): an app's icon, a found file's picture, else a pixel icon — centred in a fixed box,
// so the text after it starts at the same x on every row. Whole pixels: `iu` is the look's
// art pixel (StartPrefs.of(look).iu), the box 12×11 of them unless the look sets its size.
// `pixelIcon` is the pixel icon itself, for a look that recolours it (pixelIcon.ink: …).
Item {
    id: root

    property var app: null
    property var file: null
    property string icon: ""
    property int iu: Theme.u
    property int appSize: iu * 11
    property int thumbSize: Math.min(width, height)
    property alias pixelIcon: pix

    width: iu * 12
    height: iu * 11

    AppIcon {
        visible: !!root.app
        x: Math.floor((root.width - width) / 2)
        y: Math.floor((root.height - height) / 2)
        iconName: root.app ? root.app.icon || "" : ""
        appId: root.app ? root.app.id || "" : ""
        size: root.appSize
    }
    FileThumb {
        id: thumb
        visible: ok
        x: Math.floor((root.width - width) / 2)
        y: Math.floor((root.height - height) / 2)
        width: root.thumbSize
        height: root.thumbSize
        hit: root.file || null
    }
    PxIcon {
        id: pix
        visible: !root.app && !thumb.ok
        x: Math.floor((root.width - width) / 2)
        y: Math.floor((root.height - height) / 2)
        pixel: root.iu
        name: root.icon || "heart"
    }
}
