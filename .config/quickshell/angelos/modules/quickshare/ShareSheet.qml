pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Quick Share (services/QuickShare) in a window of its own (ShareView): it stays beside the file
// manager for files to be dragged into it, can be alt-tabbed to and moved to another workspace
// or screen — it was a sheet over everything, and nothing could be dragged into it from under it.
Scope {
    LazyLoader {
        active: QuickShare.sheetOpen

        FloatingWindow {
            id: win
            RightClickGuard {}
            title: Shell.appTitle + " · " + I18n.t("Отправить рядом", "Quick Share")
            visible: true
            color: "transparent"
            implicitWidth: 760
            implicitHeight: 680
            minimumSize: Qt.size(560, 520)
            onClosed: QuickShare.close()
            onVisibleChanged: if (!visible)
                QuickShare.close()

            ShareView {
                anchors.fill: parent
                host: win
            }
        }
    }
}
