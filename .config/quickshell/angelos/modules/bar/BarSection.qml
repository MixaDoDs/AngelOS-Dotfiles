pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config

// A run of bar widgets; "tasks" may stretch to fill the section.
RowLayout {
    id: root

    required property var ids
    required property var bar
    property bool fillTasks: false
    property real lyricsMax: Theme.u * 150
    // Settings → Bar → Icons → "Right side": compact packs the widgets close together
    property string density: "normal"      // compact | normal | airy
    property bool centered: false          // the Windows 11-like centred group (BarContent)

    spacing: density === "compact" ? Math.max(1, Theme.u / 2) : density === "airy" ? Theme.u * 6 : Theme.u * 3

    Repeater {
        model: root.ids
        BarItem {
            required property string modelData
            wid: modelData
            bar: root.bar
            fillTasks: root.fillTasks
            lyricsMax: root.lyricsMax
            dense: root.density === "compact"
            centered: root.centered
        }
    }
    // the stretched left side without a "Windows" that takes the room (hidden, or "compact"):
    // the rest goes here, after the widgets — a RowLayout with nothing to stretch spreads the
    // room between its cells, and the workspaces after Start slid to the middle of the bar
    Item {
        visible: root.fillTasks && !(root.ids.includes("tasks") && Config.bar.tasksWidth !== "compact")
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        implicitHeight: 1
    }
}
