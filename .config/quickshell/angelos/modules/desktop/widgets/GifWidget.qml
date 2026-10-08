pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// A GIF (or animated WebP / PNG) on the desktop, from Settings → Widgets. Qt 6.12's AnimatedImage
// ends a playback by itself: `loops` times through, then it rests on its first or last frame
// (`finishBehavior`) and says `finished` — and the widget may start it again N minutes later.
// Pixel art stays sharp (no smoothing) unless the setting says otherwise. Stands still while
// nobody can see the desk, and in the input copy (it is passive: never shown there).
Item {
    id: root

    property string screenName
    property var widget
    readonly property bool passive: true     // nothing to click: no input copy needed

    readonly property var st: widget && widget.settings ? widget.settings : ({})
    readonly property string file: st.file || ""
    readonly property int loops: st.loops === undefined ? 0 : st.loops          // 0 = for ever
    readonly property bool restOnLast: st.rest !== "first"
    readonly property int every: st.every || 0                                  // minutes, 0 = once
    readonly property int side: Math.max(Theme.u * 24, (st.size || 100) * Theme.u)   // the longer side
    readonly property bool sharp: st.sharp !== false
    readonly property bool seen: root.visible && !Shell.hiddenScreen(root.screenName)

    // Qt 6.12: an AnimatedImage with cache: false that ends on its final frame after a number of
    // loops recurses in QMovie::jumpToFrame until the stack runs out (the shell dies). So a GIF
    // that ends keeps its frames (cache: true) and one that loops for ever streams them; the
    // switch makes a new image (`cache` set on a live one reloads it and fell over the same way)
    readonly property bool cached: loops > 0
    onCachedChanged: {
        holder.active = false;
        holder.active = true;
    }
    readonly property AnimatedImage gif: holder.item
    readonly property int status: gif ? gif.status : AnimatedImage.Null
    readonly property bool ok: status === AnimatedImage.Ready && gif.sourceSize.width > 0
    readonly property real fit: ok ? side / Math.max(gif.sourceSize.width, gif.sourceSize.height) : 1
    // whole multiples for pixel art when they fit, so its pixels stay square
    readonly property real zoom: sharp && fit >= 1 ? Math.floor(fit) : fit
    implicitWidth: ok ? Math.round(gif.sourceSize.width * zoom) : Theme.u * 80
    implicitHeight: ok ? Math.round(gif.sourceSize.height * zoom) : empty.implicitHeight + Theme.u * 8

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: AnimatedImage {
            visible: root.ok
            asynchronous: true
            smooth: !root.sharp
            mipmap: !root.sharp
            fillMode: Image.PreserveAspectFit
            loops: root.loops > 0 ? root.loops : AnimatedImage.Infinite
            finishBehavior: root.restOnLast ? AnimatedImage.FinishAtFinalFrame : AnimatedImage.FinishAtInitialFrame
            playing: root.ok
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
    function replay() {
        if (!gif)
            return;
        again.stop();
        gif.playing = false;
        gif.currentFrame = 0;
        gif.playing = Qt.binding(() => root.ok);
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
            name: root.status === AnimatedImage.Error ? "heartBroken" : "image"
        }
        PxText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            kind: "tiny"
            dim: true
            text: root.status === AnimatedImage.Error ? I18n.t("гифка не открылась — выбери другую в Настройках → Виджеты", "The GIF did not open: choose another in Settings → Widgets") : root.status === AnimatedImage.Loading ? I18n.t("загружаю…", "Loading…") : I18n.t("выбери гифку: Настройки → Виджеты", "Choose a GIF: Settings → Widgets")
        }
    }
}
