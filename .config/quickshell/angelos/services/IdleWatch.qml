import QtQuick
import Quickshell
import Quickshell.Wayland

// An IdleMonitor whose timeout may change. Quickshell 0.3.1's IdleMonitor goes deaf once its
// timeout changes after it was made — and ours all are made before settings.json is read, so
// the screensaver, the lock, the screens off and sleep never came. A new one for every
// timeout (Variants keeps it while the value stays). Reads like IdleMonitor: isIdle.
Scope {
    id: root

    property bool enabled: true
    property int timeout: 60                // seconds
    property bool respectInhibitors: true
    property bool isIdle: false

    onEnabledChanged: if (!enabled)
        isIdle = false

    Variants {
        model: root.enabled && root.timeout > 0 ? [root.timeout] : []
        IdleMonitor {
            required property var modelData
            timeout: modelData
            respectInhibitors: root.respectInhibitors
            onIsIdleChanged: root.isIdle = isIdle
            Component.onCompleted: root.isIdle = isIdle
        }
    }
}
