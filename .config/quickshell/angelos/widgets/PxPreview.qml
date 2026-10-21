import QtQuick
import qs.config
import qs.widgets.previews

// "preview.exe": a looping, gif-like animation of what a setting does, drawn
// live in the current theme colours by a scene from widgets/previews/ (listed below).
// SettingRow opens it under the row when an option is clicked.
PxWindow {
    id: root

    property string scene: ""
    property string variant: ""
    property string caption: ""
    property int duration: 3600             // one pass of the scene
    property int hold: 900                  // the last frame stays a moment, like a gif
    property int fps: 12
    property int frame: 0
    property int loops: 0                   // passes played (scenes may vary per pass)
    readonly property int frames: Math.max(1, Math.round(duration / 1000 * fps))
    // Motion "off" (D4): no animation here either — one still frame, the end of the pass:
    // what the setting leads to
    readonly property bool still: Motion.still
    readonly property real t: still ? 1 : Math.min(1, frame / frames)
    property int sceneHeight: Theme.u * 78
    readonly property int stageStatus: stage.status     // the UI self-test checks every scene loads
    readonly property var sceneNames: Object.keys(scenes)

    function restart() {
        frame = 0;
        loops = 0;
    }
    onVariantChanged: restart()

    title: I18n.exe("preview") + (caption ? " · " + caption : "") + (still ? I18n.t(" · кадр", " · still") : "")
    icon: "play"
    compact: true
    translucent: false
    closable: true
    implicitHeight: chrome * 2 + titleHeight + bodyPadding * 2 + sceneHeight

    Timer {
        interval: Math.round(1000 / root.fps)
        running: root.visible && root.scene !== "" && !root.still
        repeat: true
        onTriggered: {
            if (root.frame >= root.frames + Math.round(root.hold / 1000 * root.fps)) {
                root.frame = 0;
                root.loops++;
            } else {
                root.frame++;
            }
        }
    }

    // scenes as components: Quickshell only registers types it can see statically
    readonly property var scenes: ({
            "TaskClose": taskClose,
            "CloseFx": closeFx,
            "OpenFx": openFx,
            "WallpaperFx": wallpaperFx,
            "StartMenu": startMenu,
            "Taskbar": taskbar,
            "DeskSwitch": deskSwitch,
            "LockScreen": lockScreen,
            "CaptureSkin": captureSkin,
            "CircleFx": circleFx,
            "Breakage": breakage
        })
    Component {
        id: breakage
        Breakage {}
    }
    Component {
        id: circleFx
        CircleFx {}
    }
    Component {
        id: deskSwitch
        DeskSwitch {}
    }
    Component {
        id: lockScreen
        LockScreen {}
    }
    Component {
        id: captureSkin
        CaptureSkin {}
    }
    Component {
        id: taskClose
        TaskClose {}
    }
    Component {
        id: closeFx
        CloseFx {}
    }
    Component {
        id: openFx
        OpenFx {}
    }
    Component {
        id: wallpaperFx
        WallpaperFx {}
    }
    Component {
        id: startMenu
        StartMenu {}
    }
    Component {
        id: taskbar
        Taskbar {}
    }

    Loader {
        id: stage
        anchors.fill: parent
        clip: true
        sourceComponent: root.scenes[root.scene] || null
        onLoaded: {
            item.t = Qt.binding(() => root.t);
            item.variant = Qt.binding(() => root.variant);
            if (item.loops !== undefined)
                item.loops = Qt.binding(() => root.loops);
        }
    }
}
