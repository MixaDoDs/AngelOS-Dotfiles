pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.modules.serp
import "."

// serp-skin: the disks in Serpantinum's face (angelOS's modules/desktop/widgets/DisksWidget:
// the same `df` once a minute while the desk is in sight, one btrfs volume is one disk).
//   S  the system disk
//   M  every disk (up to five): an icon box, the name, "68 ГБ / 511 ГБ", a pill bar
//   L  the disks, then the folders (Home, Downloads, Documents…) on chips — a click opens one
// The bar is the accent, red past 90 %. In hell the roles are hell's colours.
Item {
    // the pill bar (inline: loaded by URL from the desktop host, sibling files aren't types)
    component SerpPill: Rectangle {
        id: pillRoot
    
        property real value: 0
        property color fill: Serp.accent
        property bool animate: true
        property real shown: Math.max(0, Math.min(1, value))
        Behavior on shown {
            enabled: pillRoot.animate
            NumberAnimation {
                duration: Serp.normal
                easing.type: Easing.OutCubic
            }
        }
    
        implicitHeight: Serp.px(8)
        radius: height / 2
        color: Serp.surface1
        Rectangle {
            visible: pillRoot.shown > 0.002
            width: Math.max(pillRoot.height, pillRoot.width * pillRoot.shown)
            height: pillRoot.height
            radius: pillRoot.radius
            color: pillRoot.fill
        }
    }

    id: root

    property string screenName
    property var widget
    property string size: "m"
    property string frameKind: "window"
    property bool face: true
    // the folders take clicks (L); the rest only shows
    readonly property bool passive: size !== "l"
    readonly property bool seen: visible && !Shell.hiddenScreen(screenName)

    // [{name, used, size, target}]
    property var disks: []
    readonly property var shown: size === "s" ? disks.slice(0, 1) : disks.slice(0, 5)

    implicitWidth: Serp.px(size === "s" ? 210 : size === "l" ? 300 : 260)
    implicitHeight: col.implicitHeight

    function gb(b) {
        const g = b / 1e9;
        return g >= 1000 ? (g / 1000).toFixed(1) + I18n.t(" ТБ", " TB") : Math.round(g) + I18n.t(" ГБ", " GB");
    }
    function nameOf(target) {
        if (target === "/")
            return I18n.t("Система", "System");
        if (target === "/home")
            return I18n.t("Дом", "Home");
        return target.slice(target.lastIndexOf("/") + 1) || target;
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.seen
        triggeredOnStart: true
        onTriggered: if (!df.running)
            df.running = true
    }
    Process {
        id: df
        command: ["df", "-B1", "--output=source,fstype,size,used,target", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay", "-x", "squashfs", "-x", "ramfs", "-x", "fuse.portal", "-x", "autofs"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seenSrc = {};
                const out = [];
                for (const l of text.split("\n").slice(1)) {
                    const f = l.trim().split(/\s+/);
                    if (f.length < 5)
                        continue;
                    const target = f.slice(4).join(" ");
                    if (/^\/(boot|efi)(\/|$)/.test(target) || /^\/(var\/lib\/(docker|containers)|snap|run\/(user|credentials))/.test(target) || +f[2] <= 0)
                        continue;
                    // one btrfs volume, many mounts: the shortest path names it (df lists / first)
                    const prev = seenSrc[f[0]];
                    if (prev) {
                        if (target.length < prev.target.length) {
                            prev.target = target;
                            prev.name = root.nameOf(target);
                        }
                        continue;
                    }
                    const d = {
                        "name": root.nameOf(target),
                        "size": +f[2],
                        "used": +f[3],
                        "target": target
                    };
                    seenSrc[f[0]] = d;
                    out.push(d);
                }
                // the system first, then by size
                out.sort((a, b) => (a.target === "/" ? -1 : b.target === "/" ? 1 : b.size - a.size));
                root.disks = out;
            }
        }
    }

    readonly property var folders: [
        {
            "key": "HOME",
            "label": I18n.t("Домашняя", "Home"),
            "icon": "house"
        },
        {
            "key": "DOWNLOAD",
            "label": I18n.t("Загрузки", "Downloads"),
            "icon": "download"
        },
        {
            "key": "DOCUMENTS",
            "label": I18n.t("Документы", "Documents"),
            "icon": "file-text"
        },
        {
            "key": "PICTURES",
            "label": I18n.t("Изображения", "Pictures"),
            "icon": "image"
        },
        {
            "key": "MUSIC",
            "label": I18n.t("Музыка", "Music"),
            "icon": "music"
        },
        {
            "key": "VIDEOS",
            "label": I18n.t("Видео", "Videos"),
            "icon": "camera"
        }
    ]

    Column {
        id: col
        width: parent.width
        spacing: Serp.px(10)

        Repeater {
            model: root.shown
            Row {
                id: d
                required property var modelData
                readonly property real v: modelData.used / Math.max(1, modelData.size)
                readonly property bool full: v > 0.9
                width: col.width
                spacing: Serp.px(10)
                // the icon box
                Rectangle {
                    id: box
                    anchors.verticalCenter: parent.verticalCenter
                    width: Serp.px(34)
                    height: width
                    radius: Serp.radiusSmall
                    color: Serp.surface1
                    SIcon {
                        anchors.centerIn: parent
                        name: "hard-drive"
                        size: Serp.px(17)
                        color: d.full ? Serp.red : Serp.subtext0
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - box.width - parent.spacing
                    spacing: Serp.px(5)
                    Row {
                        width: parent.width
                        SText {
                            width: parent.width * 0.45
                            text: d.modelData.name
                            size: Serp.px(13)
                            bold: true
                        }
                        SText {
                            width: parent.width * 0.55
                            horizontalAlignment: Text.AlignRight
                            text: root.gb(d.modelData.used) + " / " + root.gb(d.modelData.size)
                            size: Serp.px(12)
                            color: Serp.subtext0
                        }
                    }
                    SerpPill {
                        width: parent.width
                        height: Serp.px(8)
                        value: d.v
                        fill: d.full ? Serp.red : Serp.accent
                    }
                }
            }
        }
        SText {
            visible: root.disks.length === 0
            text: I18n.t("смотрю диски…", "looking at the disks…")
            size: Serp.smallSize
            color: Serp.subtext0
        }

        // ---- L: the folders, two to a row ----
        Rectangle {
            visible: root.size === "l"
            width: parent.width
            height: 1
            color: Serp.line
        }
        Grid {
            visible: root.size === "l"
            width: parent.width
            columns: 2
            columnSpacing: Serp.px(6)
            rowSpacing: Serp.px(6)
            Repeater {
                model: root.size === "l" ? root.folders : []
                Rectangle {
                    id: f
                    required property var modelData
                    width: (col.width - Serp.px(6)) / 2
                    height: fRow.implicitHeight + Serp.px(12)
                    radius: Serp.radiusSmall
                    color: fMouse.pressed ? Serp.surface2 : fMouse.containsMouse ? Serp.surface1 : Serp.surface0
                    Behavior on color {
                        ColorAnimation {
                            duration: Serp.normal
                            easing.type: Easing.OutCubic
                        }
                    }
                    Row {
                        id: fRow
                        x: Serp.px(10)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Serp.px(8)
                        SIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: f.modelData.icon
                            size: Serp.px(15)
                            color: fMouse.containsMouse ? Serp.accent : Serp.subtext0
                        }
                        SText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: f.width - Serp.px(43)
                            text: f.modelData.label
                            size: Serp.px(12)
                            bold: true
                        }
                    }
                    MouseArea {
                        id: fMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: DesktopActions.openDirectory(f.modelData.key)
                    }
                }
            }
        }
    }
}
