pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// How full the disks are, and the everyday folders a click away:
//   S  the system disk
//   M  every disk (one line each, up to five)
//   L  the disks, then the folders (Home, Downloads, Documents…) — a click opens one
// `df` once a minute while the desk is in sight. A btrfs volume mounted many times (/, /home,
// /var/log…) is one disk; the boot partition and the system's own mounts are left out.
// In hell (Theme.realm) the meters are dried blood, a nearly full one ends in the accent.
Item {
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
    readonly property string labelFont: Theme.hell ? Theme.fontHellText : Theme.fontBody
    readonly property int labelPx: Theme.hell ? Theme.hellTextPx(Theme.fs) : Theme.sizeBody

    implicitWidth: Theme.u * (size === "s" ? 96 : size === "l" ? 140 : 124)
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
            "label": I18n.t("Домашняя", "Home")
        },
        {
            "key": "DOWNLOAD",
            "label": I18n.t("Загрузки", "Downloads")
        },
        {
            "key": "DOCUMENTS",
            "label": I18n.t("Документы", "Documents")
        },
        {
            "key": "PICTURES",
            "label": I18n.t("Изображения", "Pictures")
        },
        {
            "key": "MUSIC",
            "label": I18n.t("Музыка", "Music")
        },
        {
            "key": "VIDEOS",
            "label": I18n.t("Видео", "Videos")
        }
    ]

    Column {
        id: col
        width: parent.width
        spacing: Theme.u * 3

        Repeater {
            model: root.shown
            Column {
                id: d
                required property var modelData
                readonly property real v: modelData.used / Math.max(1, modelData.size)
                width: col.width
                spacing: Theme.u
                Row {
                    width: parent.width
                    spacing: Theme.u * 2
                    PxIcon {
                        id: hdd
                        anchors.verticalCenter: parent.verticalCenter
                        name: "hdd"
                        pixel: Math.max(1, Theme.u - 1)
                        ink: Theme.hell ? Theme.hellEdge : Theme.edge
                        fill: Theme.hell ? Theme.hellBlood : Theme.accent
                        fill2: Theme.hell ? Theme.hellRim : Theme.accent2
                        body: Theme.hell ? Theme.hellFace : Theme.face
                    }
                    PxText {
                        width: parent.width / 2 - hdd.width - Theme.u * 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: d.modelData.name
                        elide: Text.ElideRight
                        font.bold: !Theme.hell
                        font.family: root.labelFont
                        font.pixelSize: root.labelPx
                        color: Theme.hell ? Theme.hellTextDim : Theme.text
                    }
                    PxText {
                        width: parent.width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: root.gb(d.modelData.used) + " / " + root.gb(d.modelData.size)
                        font.family: root.labelFont
                        font.pixelSize: root.labelPx
                        color: Theme.hell ? Theme.hellText : Theme.textDim
                    }
                }
                PxBox {
                    width: parent.width
                    height: Theme.u * 5
                    sunken: true
                    hell: Theme.hell
                    color: Theme.hell ? Theme.hellSunken : Theme.sunken
                    Row {
                        anchors.fill: parent
                        spacing: Math.max(1, Theme.u / 2)
                        Repeater {
                            model: 16
                            Rectangle {
                                required property int index
                                readonly property int lit: Math.round(d.v * 16)
                                width: parent ? (parent.width - 15 * parent.spacing) / 16 : 0
                                height: parent ? parent.height : 0
                                // nearly full: the last block warns (hell: the one accent)
                                color: index >= lit ? "transparent" : Theme.hell ? (d.v > 0.9 && index === lit - 1 ? Theme.hellAccent : Theme.hellBlood) : d.v > 0.9 ? Theme.danger : Theme.mix(Theme.accent4, Theme.accent, index / 16)
                            }
                        }
                    }
                }
            }
        }
        PxText {
            visible: root.disks.length === 0
            text: I18n.t("смотрю диски…", "looking at the disks…")
            kind: "tiny"
            font.family: root.labelFont
            color: Theme.hell ? Theme.hellTextDim : Theme.textDim
        }

        // ---- L: the folders, two to a row ----
        Rectangle {
            visible: root.size === "l"
            width: parent.width
            height: Math.max(1, Theme.u / 2)
            color: Theme.hell ? Theme.hellRim : Qt.alpha(Theme.text, 0.2)
        }
        Grid {
            visible: root.size === "l"
            width: parent.width
            columns: 2
            columnSpacing: Theme.u * 2
            rowSpacing: Theme.u
            Repeater {
                model: root.size === "l" ? root.folders : []
                Item {
                    id: f
                    required property var modelData
                    width: (col.width - Theme.u * 2) / 2
                    height: fRow.implicitHeight + Theme.u * 2
                    PxBox {
                        anchors.fill: parent
                        visible: fMouse.containsMouse
                        hell: Theme.hell
                        sunken: fMouse.pressed
                        flat: true
                        color: Theme.hell ? Theme.hellFaceAlt : Theme.mix(Theme.face, Theme.accent, 0.18)
                    }
                    Row {
                        id: fRow
                        x: Theme.u
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.u * 2
                        PxIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "folder"
                            pixel: Math.max(1, Theme.u - 1)
                        }
                        PxText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: f.width - Theme.u * 12
                            elide: Text.ElideRight
                            text: f.modelData.label
                            font.family: root.labelFont
                            font.pixelSize: root.labelPx
                            color: Theme.hell ? Theme.hellText : Theme.text
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
