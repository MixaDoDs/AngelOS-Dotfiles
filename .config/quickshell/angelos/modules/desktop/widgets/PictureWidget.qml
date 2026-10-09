pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Qt.labs.folderlistmodel
import Quickshell
import qs.config
import qs.services
import qs.widgets

// A picture on the desktop (the old "GIF" widget, DesktopWidgets.renamed), from its right-click
// menu or Settings → Widgets:
//   file    a GIF (or animated WebP / PNG), a still picture, or a video without its sound
//   folder  a slideshow of a folder's pictures, one every N minutes (in order or shuffled),
//           going over through big pixels
// S / M / L: its longer side (64 / 100 / 160 angelOS pixels; an old widget's own size stays
// until a size is picked). The mat: none, or a polaroid with the file's name under it.
// Qt 6.12's AnimatedImage ends a playback by itself: `loops` times through, then it rests on its
// first or last frame (`finishBehavior`) and says `finished` — and the widget may start it again
// N minutes later. Pixel art stays sharp (no smoothing) unless the setting says otherwise. Stands
// still while nobody can see the desk, and in the input copy (it is passive: never shown there).
Item {
    id: root

    property string screenName
    property var widget
    property string size: "m"
    property string frameKind: "window"
    property bool face: true
    readonly property bool passive: true     // nothing to click: no input copy needed

    readonly property var st: widget && widget.settings ? widget.settings : ({})
    readonly property bool slideshow: st.mode === "folder"
    readonly property string file: st.file || ""
    readonly property bool video: !slideshow && /\.(mp4|webm|mkv|mov|m4v|avi)$/i.test(file)
    readonly property int loops: st.loops === undefined ? 0 : st.loops          // 0 = for ever
    readonly property bool restOnLast: st.rest !== "first"
    readonly property int every: st.every || 0                                  // minutes, 0 = once
    // the longer side: the size picked, else an old widget's own number, else M
    readonly property int side: Theme.u * (widget && widget.size ? ({
                "s": 64,
                "m": 100,
                "l": 160
            })[size] || 100 : Math.max(24, st.size || 100))
    readonly property bool sharp: st.sharp !== false
    readonly property bool polaroid: st.mat === "polaroid"
    readonly property bool seen: root.visible && !Shell.hiddenScreen(root.screenName)

    // ---- the mat around the picture ----
    readonly property int matSide: polaroid ? Theme.u * 4 : 0
    readonly property int matBottom: polaroid ? Theme.u * 14 : 0
    readonly property string caption: {
        const p = slideshow ? slides.currentPath : file;
        return p.slice(p.lastIndexOf("/") + 1).replace(/\.[a-z0-9]+$/i, "");
    }
    readonly property bool ok: slideshow ? slides.count > 0 : video ? videoBox.ok : gifOk
    // the picture's own box (its proportions in file mode, 4:3 for a slideshow)
    readonly property size pic: slideshow ? Qt.size(side, Math.round(side * 3 / 4)) : video ? videoBox.fitted : gifSize
    implicitWidth: ok ? pic.width + matSide * 2 : Theme.u * 80
    implicitHeight: ok ? pic.height + matSide + matBottom : empty.implicitHeight + Theme.u * 8

    Rectangle {
        visible: root.polaroid && root.ok
        anchors.fill: parent
        color: Theme.hell ? Theme.hellFaceAlt : "#f6f3ec"
        border.width: Math.max(1, Theme.u / 2)
        border.color: Theme.hell ? Theme.hellEdge : Qt.alpha("#000000", 0.25)
        PxText {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round((root.matBottom - height) / 2)
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Theme.u * 8
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.caption
            kind: "tiny"
            font.family: Theme.hell ? Theme.fontHellText : Theme.fontBody
            color: Theme.hell ? Theme.hellText : "#3a3340"
        }
    }
    Item {
        id: stage
        x: root.matSide
        y: root.matSide
        width: root.pic.width
        height: root.pic.height
        clip: true

        // ---- one file: a GIF / an animated picture / a still one ----
        // Qt 6.12: an AnimatedImage with cache: false that ends on its final frame after a number
        // of loops recurses in QMovie::jumpToFrame until the stack runs out (the shell dies). So a
        // GIF that ends keeps its frames (cache: true) and one that loops for ever streams them;
        // the switch makes a new image (`cache` set on a live one reloads it and fell over the same way)
        Loader {
            id: holder
            anchors.fill: parent
            active: !root.slideshow && !root.video
            sourceComponent: AnimatedImage {
                visible: root.gifOk
                asynchronous: true
                smooth: !root.sharp
                mipmap: !root.sharp
                fillMode: Image.PreserveAspectFit
                loops: root.loops > 0 ? root.loops : AnimatedImage.Infinite
                finishBehavior: root.restOnLast ? AnimatedImage.FinishAtFinalFrame : AnimatedImage.FinishAtInitialFrame
                playing: root.gifOk
                paused: !root.seen
                onFinished: if (root.every > 0)
                    again.restart()
                // a new file or new loops: from the start
                onSourceChanged: again.stop()
                onLoopsChanged: root.replay()
                // cache before the source: the picture loads once, the right way
                Component.onCompleted: {
                    cache = root.cached;
                    source = Qt.binding(() => root.file ? "file://" + root.file : "");
                }
            }
        }

        // ---- a video, without its sound, round and round ----
        Loader {
            id: videoBox
            anchors.fill: parent
            active: root.video
            readonly property bool ok: !!item && item.ok
            readonly property size fitted: item ? item.fitted : Qt.size(root.side, root.side)
            sourceComponent: Item {
                readonly property size natural: out.sourceRect.width > 0 ? Qt.size(out.sourceRect.width, out.sourceRect.height) : Qt.size(0, 0)
                readonly property bool ok: natural.width > 0
                readonly property real k: ok ? root.side / Math.max(natural.width, natural.height) : 1
                readonly property size fitted: Qt.size(Math.round(natural.width * k), Math.round(natural.height * k))
                MediaPlayer {
                    id: player
                    source: root.file ? "file://" + root.file : ""
                    loops: MediaPlayer.Infinite
                    videoOutput: out
                    audioOutput: null
                    Component.onCompleted: if (root.seen)
                        play()
                }
                Connections {
                    target: root
                    function onSeenChanged() {
                        root.seen ? player.play() : player.pause();
                    }
                }
                VideoOutput {
                    id: out
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectCrop
                }
            }
        }

        // ---- a folder: the slideshow ----
        Item {
            id: slides
            anchors.fill: parent
            visible: root.slideshow
            readonly property int count: folder.count
            property int index: -1
            property string currentPath: ""
            property bool showingA: true
            property real t: 1                      // 0 → 1 through a change
            FolderListModel {
                id: folder
                folder: root.slideshow && root.st.folder ? "file://" + root.st.folder : ""
                nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp", "*.avif", "*.svg", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP"]
                showDirs: false
                sortField: FolderListModel.Name
                onStatusChanged: if (status === FolderListModel.Ready && slides.index < 0)
                    slides.step()
            }
            function step() {
                if (!count)
                    return;
                let i = index + 1;
                if (root.st.shuffle !== false && count > 1)
                    do {
                        i = Math.floor(Math.random() * count);
                    } while (i === index);
                index = i % count;
                const path = folder.get(index, "filePath");
                if (path === currentPath)
                    return;
                currentPath = path;
                // the hidden one takes the new picture, then they trade places through big pixels
                (showingA ? imgB : imgA).source = "file://" + path;
                showingA = !showingA;
                if (Motion.still || !root.seen) {
                    t = 1;
                } else {
                    swap.restart();
                }
            }
            NumberAnimation {
                id: swap
                target: slides
                property: "t"
                from: 0
                to: 1
                duration: Motion.ms(900)
            }
            // the old one coarsens to big pixels and fades, the new one comes out of them
            readonly property real coarse: 1 / 28
            function grain(showing) {
                const p = showing ? t : 1 - t;
                return p >= 1 ? 1 : Math.max(coarse, Math.pow(p, 3));
            }
            Image {
                id: imgA
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(root.side * 2, root.side * 2)
                opacity: slides.showingA ? Math.min(1, slides.t * 1.6) : 1 - slides.t
                z: slides.showingA ? 1 : 0
                layer.enabled: swap.running
                layer.smooth: false
                layer.textureSize: Qt.size(Math.max(1, Math.round(width * slides.grain(slides.showingA))), Math.max(1, Math.round(height * slides.grain(slides.showingA))))
            }
            Image {
                id: imgB
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(root.side * 2, root.side * 2)
                opacity: !slides.showingA ? Math.min(1, slides.t * 1.6) : 1 - slides.t
                z: slides.showingA ? 0 : 1
                layer.enabled: swap.running
                layer.smooth: false
                layer.textureSize: Qt.size(Math.max(1, Math.round(width * slides.grain(!slides.showingA))), Math.max(1, Math.round(height * slides.grain(!slides.showingA))))
            }
            Timer {
                interval: Math.max(1, root.st.interval || 5) * 60000
                repeat: true
                running: root.slideshow && root.seen && slides.count > 1
                onTriggered: slides.step()
            }
            Connections {
                target: DesktopWidgets
                function onRequest(uid, what) {
                    if (root.face && root.widget && uid === root.widget.uid && what === "next")
                        slides.step();
                }
            }
        }
    }

    // ---- the GIF's own bookkeeping ----
    readonly property bool cached: loops > 0
    onCachedChanged: {
        holder.active = false;
        holder.active = Qt.binding(() => !root.slideshow && !root.video);
    }
    readonly property AnimatedImage gif: holder.item
    readonly property int status: gif ? gif.status : AnimatedImage.Null
    readonly property bool gifOk: status === AnimatedImage.Ready && gif.sourceSize.width > 0
    readonly property real fit: gifOk ? side / Math.max(gif.sourceSize.width, gif.sourceSize.height) : 1
    // whole multiples for pixel art when they fit, so its pixels stay square
    readonly property real zoom: sharp && fit >= 1 ? Math.floor(fit) : fit
    readonly property size gifSize: gifOk ? Qt.size(Math.round(gif.sourceSize.width * zoom), Math.round(gif.sourceSize.height * zoom)) : Qt.size(side, side)
    function replay() {
        if (!gif)
            return;
        again.stop();
        gif.playing = false;
        gif.currentFrame = 0;
        gif.playing = Qt.binding(() => root.gifOk);
    }
    Timer {
        id: again
        interval: root.every * 60000
        // missed while out of sight: then as soon as the desk shows again
        onTriggered: if (root.seen)
            root.replay()
        else
            pending = true
        property bool pending: false
    }
    onSeenChanged: if (seen && again.pending) {
        again.pending = false;
        replay();
    }

    Column {
        id: empty
        visible: !root.ok
        anchors.centerIn: parent
        width: Theme.u * 72
        spacing: Theme.u * 2
        PxIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: root.status === AnimatedImage.Error ? "heartBroken" : root.slideshow ? "folder" : "image"
        }
        PxText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            text: root.slideshow ? (root.st.folder ? I18n.t("в папке нет картинок", "No pictures in the folder") : I18n.t("выбери папку: ПКМ → Слайд-шоу из папки…", "Choose a folder: right-click → Slideshow from a folder…")) : root.status === AnimatedImage.Error ? I18n.t("картинка не открылась — выбери другую: ПКМ → Выбрать картинку…", "The picture did not open: right-click → Choose a picture…") : root.status === AnimatedImage.Loading ? I18n.t("загружаю…", "Loading…") : I18n.t("выбери картинку: ПКМ → Выбрать картинку…", "Choose a picture: right-click → Choose a picture…")
        }
    }
}
