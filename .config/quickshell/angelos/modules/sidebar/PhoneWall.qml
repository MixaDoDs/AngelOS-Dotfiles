pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.widgets

// The phone's home-screen wallpaper (the tuning: Config.phone.look.wall): stars, hearts,
// a checker, flames along the bottom, clouds — faint, in the trim's colour, laid out the same
// every time (a fixed seed), so nothing moves and nothing is drawn twice.
Item {
    id: root

    property string kind: "plain"
    property color color: Theme.accent
    readonly property int k: Theme.u
    clip: true
    opacity: 0.28
    readonly property var spots: {
        const out = [];
        let seed = 11;
        const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
        const n = kind === "stars" ? 26 : kind === "hearts" || kind === "clouds" ? 9 : 0;
        for (let i = 0; i < n; i++)
            out.push([rnd() * width, rnd() * height]);
        return out;
    }
    Repeater {
        model: root.kind === "stars" ? root.spots : []
        Rectangle {
            required property var modelData
            required property int index
            x: Math.round(modelData[0])
            y: Math.round(modelData[1])
            width: root.k * (index % 4 === 0 ? 2 : 1)
            height: width
            color: root.color
        }
    }
    Repeater {
        model: root.kind === "hearts" || root.kind === "clouds" ? root.spots : []
        PxIcon {
            required property var modelData
            x: Math.round(modelData[0])
            y: Math.round(modelData[1])
            name: root.kind === "hearts" ? "heart" : "cloud"
            fill: root.color
        }
    }
    Grid {
        visible: root.kind === "checker"
        columns: Math.ceil(root.width / (root.k * 6))
        Repeater {
            model: root.kind === "checker" ? Math.ceil(root.width / (root.k * 6)) * Math.ceil(root.height / (root.k * 6)) : 0
            Rectangle {
                required property int index
                readonly property int cols: Math.ceil(root.width / (root.k * 6))
                width: root.k * 6
                height: root.k * 6
                color: (index % cols + Math.floor(index / cols)) % 2 ? root.color : "transparent"
            }
        }
    }
    Row {
        visible: root.kind === "flames"
        anchors.bottom: parent.bottom
        Repeater {
            model: root.kind === "flames" ? Math.ceil(root.width / (root.k * 9)) : 0
            PxIcon {
                name: "fire"
                pixel: root.k
                fill3: root.color
            }
        }
    }
}
