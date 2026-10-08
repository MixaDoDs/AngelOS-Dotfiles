pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.modules.bar.parts
import qs.widgets

// One bar widget by id ("clock", "tray", "plugin:cat", …).
Loader {
    id: root

    required property string wid
    required property var bar          // BarContent: screenName, barWindow, above, compact, itemHeight, …
    property bool fillTasks: false
    property real lyricsMax: Theme.u * 150
    // the dense right side: narrower buttons (widgets built on PxButton)
    property bool dense: false
    // the hell bar (BarContent.hellInk): every widget in the circle's own colours — the ones
    // that can (barInk: PxButton and the bar's parts, hellBar: plugins that draw it) are told
    // so, the rest goes through HellBarTint
    readonly property bool hellBar: !!bar && bar.hellInk
    onLoaded: {
        if (item && item.hpad !== undefined)
            item.hpad = Qt.binding(() => root.dense ? Theme.u * 2 : -1);
        if (item && item.barInk !== undefined)
            item.barInk = Qt.binding(() => root.hellBar);
    }
    // an icon without words takes a square cell on the hell bar: one grid, equal steps
    readonly property bool iconOnly: !!item && item.barInk !== undefined && item.icon !== undefined && item.icon !== "" && item.text === ""

    readonly property bool tall: wid === "start" || wid === "tasks" || wid === "media" || wid === "lyrics"
    // Windows 11-like centred taskbar: the window buttons as wide as they need, shrinking when crowded
    property bool centered: false
    Layout.fillWidth: (fillTasks || centered) && wid === "tasks"
    // compact "Windows": grows only as far as its buttons need, the next widgets follow right after (issue #16)
    Layout.maximumWidth: wid === "tasks" && (centered || (fillTasks && Config.bar.tasksWidth === "compact")) && item ? Math.max(Theme.u * 16, item.naturalWidth) : Number.POSITIVE_INFINITY
    Layout.minimumWidth: wid === "tasks" ? Theme.u * 16 : -1
    Layout.preferredWidth: wid === "tasks" ? (centered && item ? Math.max(Theme.u * 16, item.naturalWidth) : fillTasks ? Theme.u * 16 : Theme.u * 120) : hellBar && iconOnly ? bar.itemHeight : -1
    // the hell bar: every widget as tall as the bar's cell, so the state plates are one height
    Layout.preferredHeight: tall || hellBar ? bar.itemHeight : -1
    Layout.alignment: Qt.AlignVCenter
    // Never bind a parent's visibility to its child's effective visibility:
    // once hidden during a track change, both can otherwise stay hidden.
    visible: {
        if (wid === "tasks")
            return Config.bar.showWindows;
        // network indicators show only where there is such hardware
        if (wid === "wifi")
            return Wifi.available && Wifi.hasWifi && Config.network.showWifi;
        if (wid === "bluetooth")
            return Bt.available && Config.network.showBluetooth;
        if (wid === "wired")
            return Wifi.available && !!Wifi.wiredDevice && Config.network.showWired;
        if (wid === "battery")
            return Power.hasBattery && Config.power.showBattery;
        if (wid === "media")
            return Config.bar.showMedia && !!Lyrics.player && Lyrics.title !== "";
        if (wid === "lyrics")
            return Config.lyrics.enabled && Lyrics.visibleToggle && Lyrics.hasLyrics && (!Config.lyrics.screens.length || Config.lyrics.screens.includes(bar.screenName)) && lyricsMax >= Theme.u * 50;
        return true;
    }

    // the hell bar's one rule for the plates of a state, for widgets that don't draw it
    // themselves (PxButton does, barInk): the pointer on it → hellBarHover, open or on (the
    // widget's `barOpen`) → hellBarActive; as tall as the cell
    readonly property bool itemOpen: !!item && item.barOpen === true
    Rectangle {
        z: -1
        anchors.fill: parent
        visible: root.hellBar && !!root.item && root.item.barInk === undefined && (cellHover.hovered || root.itemOpen)
        color: root.itemOpen ? Theme.hellBarActive : Theme.hellBarHover
    }
    HoverHandler {
        id: cellHover
        enabled: root.hellBar
    }

    // guided tips find bar elements by "bar:<id>"
    Component.onCompleted: if (bar && bar.barWindow)
        Tour.register("bar:" + wid, root, bar.barWindow)
    Component.onDestruction: Tour.unregister("bar:" + wid, root)

    sourceComponent: {
        switch (wid) {
        case "start":
            return startC;
        case "workspaces":
            return wsC;
        case "tasks":
            return tasksC;
        case "lyrics":
            return lyricsC;
        case "media":
            return mediaC;
        case "tray":
            return trayC;
        case "layout":
            return layoutC;
        case "volume":
            return volumeC;
        case "bell":
            return bellC;
        case "wifi":
            return wifiC;
        case "bluetooth":
            return btC;
        case "wired":
            return wiredC;
        case "battery":
            return batteryC;
        case "clock":
            return clockC;
        default:
            return wid.startsWith("plugin:") ? pluginC : null;
        }
    }

    Component {
        id: startC
        StartButton {
            small: root.bar.compact || (root.bar.style !== "taskbar" && root.bar.style !== "windose")
            above: root.bar.above
            screenName: root.bar.screenName
            barWindow: root.bar.barWindow
        }
    }
    Component {
        id: wsC
        Workspaces {
            screenName: root.bar.screenName
        }
    }
    Component {
        id: tasksC
        Tasks {
            screenName: root.bar.screenName
            above: root.bar.above
            iconsOnly: root.bar.compact || root.bar.style === "island" || root.bar.style === "dock" || !Config.bar.taskLabels
            dock: root.bar.style === "dock"
            visible: Config.bar.showWindows
        }
    }
    Component {
        id: lyricsC
        BarLyrics {
            screenName: root.bar.screenName
            maxWidth: root.lyricsMax
            fixedWidth: true
        }
    }
    Component {
        id: mediaC
        Media {
            maxWidth: root.bar.compact ? 0 : Theme.u * 130
            showTitle: !root.bar.lyricsShown
            visible: Config.bar.showMedia && !!Lyrics.player && Lyrics.title !== ""
        }
    }
    Component {
        id: trayC
        Tray {
            above: root.bar.above
        }
    }
    Component {
        id: layoutC
        KbLayout {}
    }
    Component {
        id: volumeC
        Volume {
            above: root.bar.above
            showPercent: !root.bar.compact && (root.bar.style === "taskbar" || root.bar.style === "windose")
        }
    }
    Component {
        id: bellC
        Bell {}
    }
    Component {
        id: wifiC
        WifiButton {
            above: root.bar.above
        }
    }
    Component {
        id: btC
        BluetoothButton {
            above: root.bar.above
        }
    }
    Component {
        id: wiredC
        WiredButton {
            above: root.bar.above
        }
    }
    Component {
        id: batteryC
        BatteryButton {
            above: root.bar.above
        }
    }
    Component {
        id: clockC
        Clock {
            screenName: root.bar.screenName
            above: root.bar.above
            showDate: root.bar.style === "taskbar" || root.bar.style === "windose"
        }
    }
    Component {
        id: pluginC
        Loader {
            id: plug
            readonly property var p: Plugins.byId(root.wid.slice(7))
            // the hell bar: a plugin with `hellBar` draws it itself; any other goes through the
            // tint, so its sprite keeps its shape and its darks don't sink into the plate
            readonly property bool own: !!item && item.hellBar !== undefined
            readonly property bool barOpen: !!item && item.barOpen === true
            layer.enabled: root.hellBar && !!item && !own
            layer.effect: HellBarTint {}
            onLoaded: if (own)
                item.hellBar = Qt.binding(() => root.hellBar)
            // a new path after the plugin was changed (Plugin Studio): load the new files
            readonly property string src: p ? Plugins.url(p, p.barWidget) : ""
            function load() {
                if (p && !item)
                    setSource(src, {
                        "plugin": Plugins.context(p),
                        "screenName": root.bar.screenName,
                        "barWindow": root.bar.barWindow
                    });
            }
            onPChanged: load()
            onSrcChanged: if (item) {
                source = "";
                load();
            }
            Component.onCompleted: load()
        }
    }
}
