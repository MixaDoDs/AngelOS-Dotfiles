pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

// The Golden Gate skin's desktop pieces on every screen while it is chosen (GoldenGate.on): the
// menu bar, the overlay its menus open in and the About panel for apps without one. The usual
// bar steps aside meanwhile (Bar.qml).
Variants {
    model: GoldenGate.on ? Shell.screens : []

    Scope {
        id: scope
        required property var modelData

        MacMenuBar {
            modelData: scope.modelData
        }
        MacMenuHost {
            modelData: scope.modelData
        }
        MacAbout {
            modelData: scope.modelData
        }
    }
}
