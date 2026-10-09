pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.config
import qs.services
import qs.widgets
import qs.modules.mac
import "../../widgets/Place.js" as Place

// Stack of notification cards in the top-right corner of the chosen screen. The Golden Gate skin
// has banners of its own (modules/mac/MacBanner), right under its menu bar.
PanelWindow {
    id: win

    screen: Config.notifications.screen === "primary" ? Shell.primaryScreen : Shell.screenByName(Config.notifications.screen) || Shell.focusedScreen
    // over the first-run wizard nothing pops up (they wait in the history)
    visible: Notifs.popups.length > 0 && !Shell.setupLocked
    readonly property string pos: Config.notifications.position || "top-right"
    anchors.top: Place.top(pos)
    anchors.bottom: Place.bottom(pos)
    anchors.left: Place.left(pos)
    anchors.right: Place.right(pos)
    readonly property bool mac: GoldenGate.on
    margins.top: mac ? GoldenGate.px(8) : Theme.u * 4
    margins.bottom: mac ? GoldenGate.px(8) : Theme.u * 4
    margins.left: mac ? GoldenGate.px(10) : Theme.u * 4
    margins.right: mac ? GoldenGate.px(10) : Theme.u * 4
    implicitWidth: mac ? GoldenGate.px(356) + GoldenGate.px(12) : Theme.u * 175
    implicitHeight: Math.max(1, col.implicitHeight + (mac ? GoldenGate.px(40) : Theme.u * 3))
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "angelos-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    // the keyboard only while a reply is being typed in a card (Enter sends it, Esc gives it back)
    WlrLayershell.keyboardFocus: Notifs.replyTo ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Golden Gate: niri blurs under each banner's rounded glass (no more than 8 stand at once)
    BackgroundEffect.blurRegion: mac ? (GoldenGate.blurOn ? macBlur : null) : Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: col
    }
    Region {
        id: macBlur
        Region {
            item: banners.count > 0 && banners.itemAt(0) ? banners.itemAt(0).glassItem : null
            radius: GoldenGate.px(20)
        }
        Region {
            item: banners.count > 1 && banners.itemAt(1) ? banners.itemAt(1).glassItem : null
            radius: GoldenGate.px(20)
        }
        Region {
            item: banners.count > 2 && banners.itemAt(2) ? banners.itemAt(2).glassItem : null
            radius: GoldenGate.px(20)
        }
        Region {
            item: banners.count > 3 && banners.itemAt(3) ? banners.itemAt(3).glassItem : null
            radius: GoldenGate.px(20)
        }
        Region {
            item: banners.count > 4 && banners.itemAt(4) ? banners.itemAt(4).glassItem : null
            radius: GoldenGate.px(20)
        }
        Region {
            item: banners.count > 5 && banners.itemAt(5) ? banners.itemAt(5).glassItem : null
            radius: GoldenGate.px(20)
        }
        Region {
            item: banners.count > 6 && banners.itemAt(6) ? banners.itemAt(6).glassItem : null
            radius: GoldenGate.px(20)
        }
        Region {
            item: banners.count > 7 && banners.itemAt(7) ? banners.itemAt(7).glassItem : null
            radius: GoldenGate.px(20)
        }
    }

    Column {
        id: col
        x: win.mac ? GoldenGate.px(6) : 0
        y: win.mac ? GoldenGate.px(6) : 0
        width: parent.width - (win.mac ? GoldenGate.px(12) : Theme.u * 3)
        spacing: win.mac ? GoldenGate.px(10) : Theme.u * 5

        Repeater {
            model: win.mac ? [] : Notifs.popups
            NotificationCard {
                required property var modelData
                notification: modelData
                width: col.width
            }
        }
        Repeater {
            id: banners
            model: win.mac ? Notifs.popups : []
            MacBanner {
                required property var modelData
                notification: modelData
                width: col.width
            }
        }
    }

    RightClickGuard {}
}
