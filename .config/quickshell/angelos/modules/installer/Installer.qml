import QtQuick
import Quickshell
import qs.services

// The live ISO's installer (InstallerScreens): made only there (Shell.installer). A one-line module in
// shell.qml, as the tests expect (they leave such lines out: no PanelWindow backend offscreen)
Scope {
    LazyLoader {
        active: Shell.installer
        InstallerScreens {}
    }
}
