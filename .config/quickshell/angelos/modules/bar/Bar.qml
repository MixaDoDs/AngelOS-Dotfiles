pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services

// One bar per screen; style picks the window flavour (BarLayout.style). The Golden Gate skin
// has a menu bar and a Dock of its own instead (modules/mac/MacDesktop).
Variants {
    model: GoldenGate.on || Shell.desktopHeld ? [] : Shell.screens.filter(s => !Config.bar.screens || Config.bar.screens.length === 0 || Config.bar.screens.includes(s.name))

    Scope {
        id: scope
        required property var modelData

        LazyLoader {
            active: BarLayout.style === "taskbar"
            TaskbarWindow {
                modelData: scope.modelData
            }
        }
        LazyLoader {
            active: BarLayout.style === "top"
            TopBarWindow {
                modelData: scope.modelData
            }
        }
        LazyLoader {
            active: BarLayout.style === "island"
            IslandWindow {
                modelData: scope.modelData
            }
        }
        LazyLoader {
            active: BarLayout.style === "dock"
            DockWindow {
                modelData: scope.modelData
            }
        }
        LazyLoader {
            active: BarLayout.style === "capsules"
            CapsuleWindow {
                modelData: scope.modelData
            }
        }
        LazyLoader {
            active: BarLayout.style === "windose"
            WindoseBarWindow {
                modelData: scope.modelData
            }
        }
    }
}
