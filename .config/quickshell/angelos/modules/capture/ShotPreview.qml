pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import "../../widgets/Place.js" as Place

// A screenshot just saved (services/ShotEdit), as phones keep it: ShotCard in the corner of the
// screen it was taken on for a few seconds (held while the pointer is on it), ShotEditor in a
// window of its own once it is clicked. The faces are their own files: the offscreen test (tests/circle)
// hosts them in plain windows.
Scope {
    LazyLoader {
        active: ShotEdit.thumb

        PanelWindow {
            id: corner
            screen: Shell.screenByName(ShotEdit.screenName) || Shell.focusedScreen
            // the place ShotEdit picked (Settings, or the first one the angel and the widgets leave free)
            anchors {
                top: Place.top(ShotEdit.at)
                bottom: Place.bottom(ShotEdit.at)
                left: Place.left(ShotEdit.at)
                right: Place.right(ShotEdit.at)
            }
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.namespace: "angelos-shot-preview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            readonly property int m: Theme.u * 10
            implicitWidth: card.width + m * 2
            implicitHeight: card.height + m * 2

            Timer {
                interval: 6000
                running: !card.held
                onTriggered: ShotEdit.dismiss()
            }
            ShotCard {
                id: card
                x: corner.m
                y: corner.m
            }
        }
    }

    // the editor: a window of its own (alt-tab to it, move it to another workspace or screen)
    LazyLoader {
        active: ShotEdit.editing

        FloatingWindow {
            id: win
            title: Shell.appTitle + " · " + I18n.t("Правка снимка", "Screenshot editor")
            visible: true
            color: "transparent"
            implicitWidth: 1320
            implicitHeight: 860
            minimumSize: Qt.size(960, 620)
            onClosed: ShotEdit.close()
            onVisibleChanged: if (!visible)
                ShotEdit.close()

            ShotEditor {
                anchors.fill: parent
                host: win
            }
        }
    }
}
