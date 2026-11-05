import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Golden Gate: in niri's overview every desk on a card of the skin's glass (Settings → Golden
// Gate → Windows, Config.mac.overviewDesks). The workspaces are clear (the wallpaper is in the
// backdrop), and the layer this lies in (Background's angelos-desktop) is the one niri draws inside
// each of them, zoomed out with it: one card under every desk. Its window asks niri to blur the
// wallpaper under `region` while `blurring`. Gone before the desk is back at full size.
MacGlass {
    id: card

    readonly property bool wanted: GoldenGate.on && Config.mac.overviewDesks === "glass" && Niri.overviewOpen
    readonly property bool blurring: GoldenGate.blurOn && visible
    readonly property Region region: Region {
        item: card
        radius: card.radius
    }

    // the edge and the corners as on the other glass once niri has zoomed the desk out
    radius: GoldenGate.px(12) / GoldenGate.overviewZoom
    bevel: GoldenGate.px(14) / GoldenGate.overviewZoom
    shadow: false
    visible: opacity > 0
    opacity: wanted ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: Motion.ms(card.wanted ? 200 : 120)
            easing.type: Easing.OutCubic
        }
    }
}
