pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// A stack of the Golden Gate Dock (Downloads), shown as macOS's Grid: a glass panel above the
// Dock's icon with the folder's newest files (MacDockModel.recent, by date), each its picture —
// the image itself, the thumbnail the file manager made, or its type's icon — and its name. A
// click opens the file in its default app, the button at the bottom the folder in the file
// manager of Settings → Default apps. MacMenuHost hosts it on its overlay (MacMenus "dock-stack"):
// a click outside closes it, Esc too; ←→↑↓ and Enter walk and open the files.
Item {
    id: root

    property real anchorX: 0                 // the Dock icon's centre (overlay coordinates)
    property real bottomY: 0                 // the panel's bottom edge
    property real areaWidth: 0               // the overlay's width (the panel stays inside it)
    property real areaHeight: 0
    property string side: ""                 // a Dock on the left / right: beside it, x its near edge,
    property real sideY: 0                   // centred on sideY
    readonly property alias panel: panel
    readonly property var files: MacDockModel.recent
    readonly property int columns: Math.max(1, Math.min(5, files.length <= 4 ? files.length : files.length <= 9 ? 3 : files.length <= 12 ? 4 : 5))
    readonly property real tileW: GoldenGate.px(92)
    readonly property real tileH: GoldenGate.px(98)
    readonly property real pad: GoldenGate.px(14)
    readonly property real headH: GoldenGate.px(30)
    readonly property real footH: GoldenGate.px(40)
    property int current: -1                 // the file the keyboard is on

    Component.onCompleted: MacDockModel.refreshRecent()

    // which of the files have a thumbnail of the file manager's (a missing one would fill the log)
    property var thumbs: ({})
    onFilesChanged: Qt.callLater(lookThumbs)
    function lookThumbs() {
        const paths = files.filter(f => !f.dir && imageTypes.indexOf(f.suffix) < 0).map(f => thumbPath(f));
        if (!paths.length)
            return;
        thumbCheck.command = ["sh", "-c", 'for f; do [ -f "$f" ] && echo "$f"; done; true', "sh"].concat(paths);
        thumbCheck.running = true;
    }
    Process {
        id: thumbCheck
        stdout: StdioCollector {
            onStreamFinished: {
                const t = {};
                for (const l of text.split("\n"))
                    if (l)
                        t[l] = true;
                root.thumbs = t;
            }
        }
    }

    width: panel.width
    height: panel.height
    x: Math.max(GoldenGate.px(4), Math.min(areaWidth - width - GoldenGate.px(4), side === "left" ? anchorX : side === "right" ? anchorX - width : anchorX - width / 2))
    y: side ? Math.max(GoldenGate.barHeight + GoldenGate.px(4), Math.min(areaHeight - height - GoldenGate.px(4), sideY - height / 2)) : Math.max(GoldenGate.barHeight + GoldenGate.px(4), bottomY - height)

    function open(i) {
        const f = files[i];
        if (!f)
            return;
        MacMenus.close();
        if (f.dir)
            MacDockModel.openInFileManager(f.path);
        else
            MacDockModel.openFile(f.path);
    }
    function key(e) {
        const n = files.length;
        if (!n)
            return false;
        let c = current < 0 ? 0 : current;
        switch (e.key) {
        case Qt.Key_Right:
            c = Math.min(n - 1, c + (current < 0 ? 0 : 1));
            break;
        case Qt.Key_Left:
            c = Math.max(0, c - (current < 0 ? 0 : 1));
            break;
        case Qt.Key_Down:
            c = Math.min(n - 1, c + (current < 0 ? 0 : columns));
            break;
        case Qt.Key_Up:
            c = current < 0 ? n - 1 : Math.max(0, c - columns);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (current >= 0)
                open(current);
            return true;
        default:
            return false;
        }
        current = c;
        return true;
    }

    // what a file looks like: a picture for images, the file manager's thumbnail, its type's icon
    readonly property var imageTypes: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif", "ico", "tif", "tiff"]
    function typeIcon(f) {
        if (f.dir)
            return ["folder-download", "folder"];
        const s = f.suffix;
        const by = [[["mp4", "mkv", "webm", "mov", "avi", "m4v", "wmv"], "video-x-generic"], [["mp3", "wav", "flac", "ogg", "opus", "m4a", "aac"], "audio-x-generic"], [["pdf"], "application-pdf"], [["zip", "tar", "gz", "tgz", "xz", "zst", "7z", "rar", "bz2"], "package-x-generic"], [["torrent"], "application-x-bittorrent"], [["iso", "img"], "application-x-cd-image"], [["appimage", "deb", "rpm", "run", "bin", "sh"], "application-x-executable"], [["exe", "msi"], "application-x-ms-dos-executable"], [["doc", "docx", "odt", "rtf"], "x-office-document"], [["xls", "xlsx", "ods", "csv"], "x-office-spreadsheet"], [["ppt", "pptx", "odp"], "x-office-presentation"], [["html", "htm"], "text-html"], [["json", "js", "py", "qml", "kdl", "toml", "yaml", "yml", "xml"], "text-x-script"], [["txt", "md", "log", "ini", "conf"], "text-x-generic"], [["ttf", "otf", "woff", "woff2"], "font-x-generic"]];
        for (const [list, icon] of by)
            if (list.indexOf(s) >= 0)
                return [icon, "text-x-generic"];
        if (imageTypes.indexOf(s) >= 0)
            return ["image-x-generic", "text-x-generic"];
        return ["text-x-generic", "unknown"];
    }
    function iconFor(f) {
        // a folder as the Dock draws folders (MacTahoe), when it has them
        const mac = f.dir ? DockIcons.file("places", "folder") : "";
        if (mac)
            return mac;
        for (const n of typeIcon(f)) {
            const p = Quickshell.iconPath(n, true);
            if (p)
                return p;
        }
        return "";
    }
    // the freedesktop thumbnail (~/.cache/thumbnails), named by the md5 of the file's URI
    function thumbPath(f) {
        const uri = "file://" + encodeURI(f.path).replace(/#/g, "%23").replace(/\?/g, "%3F").replace(/;/g, "%3B");
        return Config.home + "/.cache/thumbnails/large/" + Qt.md5(uri) + ".png";
    }
    function thumbFor(f) {
        const p = thumbPath(f);
        return thumbs[p] ? "file://" + p : "";
    }

    MacGlass {
        id: panel
        width: Math.max(GoldenGate.px(260), root.columns * root.tileW + root.pad * 2)
        height: root.headH + (root.files.length ? Math.ceil(root.files.length / root.columns) * root.tileH : GoldenGate.px(70)) + root.footH + root.pad
        radius: GoldenGate.px(18)
        shadowSize: GoldenGate.px(24)
        shadowY: GoldenGate.px(6)
        transformOrigin: Item.Bottom
        // grows up out of the Dock, like a Mac's stack
        opacity: 0
        scale: 0.92
        Component.onCompleted: {
            opacity = 1;
            scale = 1;
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.ms(140)
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Motion.ms(180)
                easing.type: Easing.OutCubic
            }
        }

        // a click inside the panel never closes it
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        MacText {
            x: root.pad
            height: root.headH
            width: parent.width - root.pad * 2
            text: I18n.t("Загрузки", "Downloads")
            semibold: true
        }

        MacText {
            visible: !root.files.length
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.headH + GoldenGate.px(20)
            text: I18n.t("Здесь пока пусто", "Nothing here yet")
            color: GoldenGate.secondaryLabel
        }

        Grid {
            id: grid
            x: Math.round((parent.width - width) / 2)
            y: root.headH
            columns: root.columns
            Repeater {
                model: root.files
                Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool isImage: !modelData.dir && root.imageTypes.indexOf(modelData.suffix) >= 0
                    readonly property bool lit: tileMouse.containsMouse || root.current === index
                    width: root.tileW
                    height: root.tileH

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: GoldenGate.px(3)
                        radius: GoldenGate.px(8)
                        color: tile.lit ? GoldenGate.hoverBg : "transparent"
                    }
                    Item {
                        id: pic
                        width: GoldenGate.px(54)
                        height: width
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: GoldenGate.px(8)
                        // an image: itself; else the thumbnail; else the type's icon
                        Image {
                            id: shot
                            anchors.fill: parent
                            source: tile.isImage ? "file://" + tile.modelData.path : tile.modelData.dir ? "" : root.thumbFor(tile.modelData)
                            sourceSize: Qt.size(GoldenGate.px(108), GoldenGate.px(108))
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            mipmap: true
                        }
                        Image {
                            id: typeIcon
                            anchors.fill: parent
                            visible: shot.status !== Image.Ready
                            source: visible ? root.iconFor(tile.modelData) : ""
                            sourceSize: Qt.size(GoldenGate.px(108), GoldenGate.px(108))
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                        }
                        // no icon in the theme: a sheet with the file's extension, like a Mac's
                        Rectangle {
                            visible: shot.status !== Image.Ready && typeIcon.status !== Image.Ready && typeIcon.status !== Image.Loading
                            anchors.centerIn: parent
                            width: parent.width * 0.74
                            height: parent.height * 0.92
                            radius: GoldenGate.px(4)
                            color: tile.modelData.dir ? "#6cb8f5" : "#f4f4f6"
                            border.width: 1
                            border.color: Qt.rgba(0, 0, 0, 0.18)
                            MacText {
                                anchors.centerIn: parent
                                width: parent.width - GoldenGate.px(4)
                                horizontalAlignment: Text.AlignHCenter
                                text: tile.modelData.dir ? "" : (tile.modelData.suffix || "?").toUpperCase().slice(0, 5)
                                size: GoldenGate.px(10)
                                bold: true
                                color: "#5a5a64"
                            }
                        }
                    }
                    MacText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: pic.bottom
                        anchors.topMargin: GoldenGate.px(5)
                        width: parent.width - GoldenGate.px(10)
                        text: tile.modelData.name
                        size: GoldenGate.smallSize
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignTop
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.current = -1
                        onClicked: root.open(tile.index)
                    }
                }
            }
        }

        // the bottom: how many more, and the folder in the file manager
        Rectangle {
            x: root.pad
            width: parent.width - root.pad * 2
            height: 1
            y: parent.height - root.footH - root.pad / 2
            color: GoldenGate.separator
        }
        MacText {
            visible: MacDockModel.recentMore > 0
            x: root.pad
            y: parent.height - root.footH - root.pad / 2 + 1
            height: root.footH
            text: I18n.t("ещё %1", "%1 more").arg(MacDockModel.recentMore)
            size: GoldenGate.smallSize
            color: GoldenGate.secondaryLabel
        }
        Rectangle {
            id: openBtn
            anchors.right: parent.right
            anchors.rightMargin: root.pad
            y: parent.height - root.footH - root.pad / 2 + (root.footH - height) / 2 + 1
            height: GoldenGate.px(26)
            width: openLabel.implicitWidth + GoldenGate.px(22)
            radius: height / 2
            color: openMouse.containsMouse ? GoldenGate.hoverBg : GoldenGate.controlBg
            MacText {
                id: openLabel
                anchors.centerIn: parent
                text: I18n.t("Открыть в «%1»  ›", "Open in %1  ›").arg(MacDockModel.fileManagerName)
            }
            MouseArea {
                id: openMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    MacMenus.close();
                    MacDockModel.openDownloads();
                }
            }
        }
    }
}
