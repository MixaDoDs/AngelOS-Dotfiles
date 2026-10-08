pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The way between hell's circles, drawn (services/CircleFx runs it): on every screen that
// may show it, the dark (faintly the coming circle's colour) comes down in an ordered dither over everything on the Top layer
// (the bar too), the circle's number in hell's blackletter comes up out of it with its
// name and one line about it, and the dark lifts. Never takes input; Overlay-layer things
// (Start, the power menu, notifications, polkit, the OSD) and the lock stay above it.
Scope {
    id: root

    Variants {
        model: Shell.screens

        Scope {
            id: one
            required property var modelData

            LazyLoader {
                active: CircleFx.active && CircleFx.shownOn(one.modelData.name)

                PanelWindow {
                    id: win
                    screen: one.modelData
                    anchors {
                        top: true
                        bottom: true
                        left: true
                        right: true
                    }
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    mask: Region {}
                    WlrLayershell.layer: WlrLayer.Top
                    WlrLayershell.namespace: "angelos-circle"
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                    readonly property var look: HellLook.looks[CircleFx.target] || ({})

                    ShaderEffect {
                        anchors.fill: parent
                        property real progress: CircleFx.veil
                        property real cell: Theme.u * 2
                        property size size: Qt.size(width, height)
                        // not a plain black: the coming circle's accent, a seventh of it, glows
                        // in the middle of its own dark and sinks to near black at the corners
                        readonly property var circlePalette: win.look.palette || ({})
                        readonly property color ground: (win.look.backdrop || {}).tint || circlePalette.body || "#030303"
                        property color tint: circlePalette.accent ? Theme.mix(Qt.color(ground), Qt.color(circlePalette.accent), 0.14) : "#0b0606"
                        property color edge: Theme.mix(Qt.color(ground), Qt.color("#000000"), 0.5)
                        fragmentShader: Qt.resolvedUrl("../../shaders/circle_veil.frag.qsb")
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.u * 4
                        opacity: CircleFx.title
                        visible: opacity > 0
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Theme.roman(win.look.n || 0)
                            color: Theme.hellAccent
                            font.family: Theme.fontHell
                            font.pixelSize: Theme.hellPx(Math.max(3, Theme.fs * 4))
                            renderType: Text.NativeRendering
                        }
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: win.look.name ? I18n.label(win.look.name) : ""
                            color: Theme.hellText
                            font.family: Theme.fontHell
                            font.pixelSize: Theme.hellPx(Math.max(2, Theme.fs * 2))
                            renderType: Text.NativeRendering
                        }
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(implicitWidth, win.width * 0.6)
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: win.look.where ? I18n.label(win.look.where) : ""
                            color: Theme.hellTextDim
                            font.family: Theme.fontHellText
                            font.pixelSize: Theme.hellTextPx(Math.max(1, Theme.fs))
                            renderType: Text.NativeRendering
                        }
                    }

                    RightClickGuard {}
                }
            }
        }
    }
}
