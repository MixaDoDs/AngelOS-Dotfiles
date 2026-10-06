import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."
import "Frames.js" as Frames

// Animated cat: idle below walk threshold, walks, then runs faster with load.
// In the Mac look (Skin.mac, the Theme API) it is MacCat: a smooth one-colour silhouette, no
// pixels — `ink` colours it (the menu bar's ink there), `pixel` still sets its size (8 × pixel tall).
// While the demon rules it is a puppy Cerberus (Frames.cerberus*): three heads, ember
// eyes, in the circle's colours — walking and running the same way; asleep he lies still
// (no zzz blinking: in hell things move rarely).
Item {
    id: root

    property var plugin
    property int pixel: Theme.u
    readonly property int walkAt: plugin ? plugin.get("walk", 15) : 15
    readonly property int runAt: Math.max(walkAt + 1, plugin ? plugin.get("run", 60) : 60)
    readonly property real cpu: Cpu.percent
    readonly property string pace: cpu < walkAt ? "idle" : cpu < runAt ? "walk" : "run"
    readonly property int frameMs: pace === "walk" ? 380 - (cpu - walkAt) / Math.max(1, runAt - walkAt) * 200 : 160 - (cpu - runAt) / Math.max(1, 100 - runAt) * 105
    readonly property color fur: plugin && plugin.get("colorMode", "theme") === "custom" ? plugin.get("color", "#e8a24c") : Theme.accent4
    readonly property bool hell: Angel.demon
    readonly property bool mac: Skin.mac
    // the Mac cat's one colour: the fur unless a host gives another (the menu bar's ink)
    property color ink: fur
    property int frame: 0

    implicitWidth: mac ? macCat.implicitWidth : hell ? cerberus.width : sprite.width
    implicitHeight: mac ? macCat.implicitHeight : (hell ? cerberus.height : sprite.height) + pixel

    Timer {
        interval: Math.max(50, root.frameMs)
        running: root.pace !== "idle" && root.visible
        repeat: true
        onTriggered: root.frame = (root.frame + 1) % 5
    }
    Timer {
        // slow zzz blink while asleep (the Cerberus sleeps without it)
        interval: 700
        running: root.pace === "idle" && root.visible && (!root.hell || root.mac)
        repeat: true
        onTriggered: root.frame = (root.frame + 1) % 2
    }

    // (made only in the Mac look: the pixel one pays nothing for it)
    Loader {
        id: macCat
        active: root.mac
        visible: active
        sourceComponent: MacCat {
            size: root.pixel * 8
            color: root.ink
            frame: root.frame
            pace: root.pace
            blink: root.frame === 1
        }
    }
    PxIcon {
        id: sprite
        visible: !root.hell && !root.mac
        pixel: root.pixel
        bitmap: root.pace === "idle" ? Frames.sleep.map((r, i) => root.frame === 1 && i < 2 ? r.replace(/y/g, ".") : r) : Frames.run(root.frame)
        body: root.fur
        fill: Theme.accent
        fill3: Theme.accent2
        light: "#ffffff"
        y: root.pace !== "idle" && root.frame % 2 === 1 ? 0 : root.pixel
    }
    CerberusSprite {
        id: cerberus
        visible: root.hell && !root.mac
        pixel: root.pixel
        frame: root.frame
        asleep: root.pace === "idle"
        alert: root.pace === "run"
        blink: root.frame === 1
        y: root.pace !== "idle" && root.frame % 2 === 1 ? 0 : root.pixel
    }
}
