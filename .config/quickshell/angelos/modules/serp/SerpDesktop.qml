pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.widgets

// serp-skin: the Serpantinum skin's pieces on every screen while it is the skin (Serp.on): the
// islands bar and its zone, the dock, and the panels (built when they open on a screen, gone a
// while after closing). The classic bar steps aside meanwhile (Bar.qml).
Variants {
    model: Serp.on && !Shell.desktopHeld ? Shell.screens : []

    Scope {
        id: scope
        required property var modelData

        SerpZone {
            modelData: scope.modelData
        }
        SerpBar {
            modelData: scope.modelData
        }
        SerpOsd {
            modelData: scope.modelData
        }
        SerpDeskStrip {
            modelData: scope.modelData
        }
        LazyLoader {
            active: Serp.cfg.dock
            SerpDock {
                modelData: scope.modelData
            }
        }
        Linger {
            id: panelKeep
            when: Serp.panel !== "" && Serp.panelScreen === scope.modelData.name
        }
        LazyLoader {
            active: panelKeep.alive
            SerpPanels {
                modelData: scope.modelData
            }
        }
    }
}
