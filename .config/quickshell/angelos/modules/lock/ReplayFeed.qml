pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Io
import qs.config

// The stream's "replay": after the lock has been up a while, a random video from the
// computer (~/Videos: screen recordings, clips…) plays behind the stream, muted, from a
// random point. It can never be read: the picture is decoded into a 64×36 item and only
// a 32×18 copy of that reaches the screen, blurred on top — text, faces and windows are
// gone long before anything is drawn. Its name is never shown.
Item {
    id: root
    objectName: "replayFeed"

    property bool active: false              // the lock wants it now
    property string folder: ""
    readonly property bool showing: player.playbackState === MediaPlayer.PlayingState && frames > 1
    property string file: ""
    property int frames: 0

    opacity: active && showing ? 1 : 0
    visible: opacity > 0
    Behavior on opacity {
        NumberAnimation {
            duration: Motion.ms(1400)
        }
    }

    onActiveChanged: {
        if (active && file === "")
            pick.running = true;
        else if (!active)
            player.stop();
        else
            player.play();
    }
    Process {
        id: pick
        command: ["sh", "-c", 'find -L "$1" -maxdepth 4 -type f \\( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.webm" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.m4v" \\) -size +200k 2>/dev/null | shuf -n 1', "sh", root.folder]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = String(text).trim();
                if (f && root.active)
                    root.file = f;
            }
        }
    }

    MediaPlayer {
        id: player
        source: root.file ? "file://" + root.file.split("/").map(encodeURIComponent).join("/") : ""
        videoOutput: video
        loops: MediaPlayer.Infinite
        // no audioOutput: always silent
        property bool seeked: false
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia && !seeked) {
                seeked = true;
                if (duration > 20000 && seekable)
                    position = Math.floor(duration * (0.1 + Math.random() * 0.7));
                if (root.active)
                    play();
            } else if (mediaStatus === MediaPlayer.InvalidMedia) {
                // a broken file: another one
                root.file = "";
                if (root.active)
                    pick.running = true;
            }
        }
        onSourceChanged: {
            seeked = false;
            root.frames = 0;
        }
        onPositionChanged: if (root.frames < 3)
            root.frames++
    }

    // the decoded picture never reaches the screen at this size or any other
    Item {
        id: tiny
        width: 64
        height: 36
        VideoOutput {
            id: video
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
        }
    }
    ShaderEffectSource {
        id: small
        sourceItem: tiny
        hideSource: true
        live: true
        smooth: true
        textureSize: Qt.size(32, 18)
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: small
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: 64
        saturation: -0.15
        brightness: -0.04
    }
    // the stream's own tint and scanlines over it, so it reads as a broadcast
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.desk, 0.28)
    }
    Column {
        anchors.fill: parent
        opacity: 0.12
        Repeater {
            model: Math.ceil(root.height / (Theme.u * 3))
            Rectangle {
                width: root.width
                height: Theme.u * 3
                color: index % 2 ? "transparent" : "#000000"
                required property int index
            }
        }
    }
}
