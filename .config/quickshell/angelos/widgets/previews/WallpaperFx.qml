import QtQuick
import qs.config
import qs.services
import qs.widgets

// Wallpaper transitions through the real shader (shaders/pixel_transition.frag)
// between two little pictures in the theme colours. variant: a transition id
// from Wallpapers.transitions, "random" or "none".
Scene {
    id: root

    readonly property int index: {
        if (variant === "none")
            return -1;
        if (variant === "random") {
            const x = Math.sin((loops + 1) * 91.7) * 43758.5453;
            return Math.floor((x - Math.floor(x)) * Wallpapers.transitions.length);
        }
        return Math.max(0, Wallpapers.transitions.findIndex(s => s.id === variant));
    }
    readonly property real p: index < 0 ? (t > 0.45 ? 1 : 0) : seg(0.18, 0.78)
    readonly property bool flip: loops % 2 === 1

    // ---- picture A: day, hills and a sun ----
    Item {
        id: day
        width: root.width
        height: root.height
        visible: false
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.mix(Theme.title2, "#ffffff", 0.35)
                }
                GradientStop {
                    position: 1
                    color: Theme.mix(Theme.accent, "#ffffff", 0.55)
                }
            }
        }
        Rectangle {
            x: parent.width * 0.7
            y: parent.height * 0.14
            width: parent.height * 0.22
            height: width
            color: Theme.mix(Theme.accent4, "#ffffff", 0.3)
        }
        Repeater {
            model: 9
            Rectangle {
                required property int index
                x: index * root.width / 8 - width / 2
                y: root.height * (0.55 + 0.12 * Math.sin(index * 1.7))
                width: root.width / 5
                height: root.height
                color: Theme.mix(Theme.accent3, Theme.edge, 0.25 + 0.1 * (index % 2))
            }
        }
    }
    // ---- picture B: night, stars and a big heart ----
    Item {
        id: night
        width: root.width
        height: root.height
        visible: false
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.mix(Theme.edge, "#000000", 0.4)
                }
                GradientStop {
                    position: 1
                    color: Theme.mix(Theme.accent2, "#000000", 0.45)
                }
            }
        }
        Repeater {
            model: 18
            Rectangle {
                required property int index
                x: ((index * 73) % 97) / 97 * root.width
                y: ((index * 41) % 53) / 53 * root.height * 0.7
                width: Math.max(1, Theme.u)
                height: width
                color: "#ffffff"
            }
        }
        PxIcon {
            anchors.centerIn: parent
            name: "heart"
            pixel: Math.max(2, Math.round(root.height / 22))
        }
    }

    ShaderEffectSource {
        id: srcDay
        sourceItem: day
        hideSource: true
        live: true
        visible: false
    }
    ShaderEffectSource {
        id: srcNight
        sourceItem: night
        hideSource: true
        live: true
        visible: false
    }
    ShaderEffect {
        anchors.fill: parent
        property var fromTex: root.flip ? srcNight : srcDay
        property var toTex: root.flip ? srcDay : srcNight
        property real progress: root.p
        property real maxBlock: Math.max(4, Config.wallpaper.maxBlock * root.width / 1920 * 2)
        property real style: Math.max(0, root.index)
        property size resolution: Qt.size(width, height)
        property color accent: Theme.accent
        property var titleTex: title.texture
        property size titleSize: title.size
        fragmentShader: Qt.resolvedUrl("../../shaders/pixel_transition.frag.qsb")
    }
    VerdictTitle {
        id: title
        text: Config.wallpaper.verdictTitle === "off" ? "" : Config.wallpaper.verdictTitle !== "auto" ? Config.wallpaper.verdictTitle : root.flip ? "ASCEND" : "DESCEND"
    }
    PxText {
        x: Theme.u * 2
        y: root.height - height - Theme.u
        visible: root.variant === "random"
        text: "→ " + (Wallpapers.transitions[root.index] ? Wallpapers.transitions[root.index].label : "")
        kind: "tiny"
        color: "#ffffff"
        style: Text.Outline
        styleColor: Theme.edge
    }
}
