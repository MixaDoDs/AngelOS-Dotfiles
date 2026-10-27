import QtQuick
import qs.config
import qs.services
import qs.widgets

// Start menu: style (classic | win11 | tiles | fullscreen | xmb | spotlight) or position
// (auto | left | center | right, for the current style). The button is clicked,
// the menu opens where it will on the real screen.
Scene {
    id: root

    readonly property bool isPos: ["auto", "left", "center", "right"].includes(variant)
    readonly property string style: isPos ? StartPrefs.current : variant
    readonly property string align: {
        const a = isPos ? variant : (Config.bar.startAlign || "auto");
        return a === "auto" ? (style === "win11" || style === "spotlight" ? "center" : "left") : a;
    }
    readonly property real open: ease(seg(0.3, 0.42))
    readonly property bool shown: t > 0.3 && t < 0.92

    MiniBar {
        id: bar
        y: root.height - height
        width: root.width
        height: Math.round(root.height * 0.17)
        count: 2
    }

    // fullscreen: pages of icons over everything
    Rectangle {
        visible: root.style === "fullscreen" && root.shown
        anchors.fill: parent
        color: Qt.alpha(Theme.menuSurface, 0.92 * root.open)
        Grid {
            anchors.centerIn: parent
            columns: 5
            spacing: Theme.u * 3
            opacity: root.open
            Repeater {
                model: 10
                Rectangle {
                    required property int index
                    width: root.height * 0.13
                    height: width
                    radius: width * 0.25
                    color: [Theme.accent, Theme.accent2, Theme.accent3, Theme.accent4][index % 4]
                }
            }
        }
    }

    // PSP XMB: a dark gradient, a wave, icons in a row and a column under one
    Rectangle {
        visible: root.style === "xmb" && root.shown
        anchors.fill: parent
        opacity: root.open
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.mix("#140818", Theme.accent, 0.2)
            }
            GradientStop {
                position: 1
                color: Theme.mix("#24102c", Theme.accent2, 0.3)
            }
        }
        Rectangle {
            y: parent.height * 0.6
            width: parent.width
            height: Math.max(1, Theme.u)
            color: Qt.alpha("#ffffff", 0.5)
            rotation: -4
        }
        Row {
            x: parent.width * 0.12
            y: parent.height * 0.18
            spacing: parent.width * 0.06
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    width: root.height * (index === 1 ? 0.12 : 0.08)
                    height: width
                    radius: width * 0.2
                    color: index === 1 ? "#ffffff" : Qt.alpha("#ffffff", 0.45)
                }
            }
        }
        Column {
            x: parent.width * 0.12 + root.height * 0.08 + parent.width * 0.06
            y: parent.height * 0.36
            spacing: Theme.u * 2
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: parent.parent.width * (index === 0 ? 0.32 : 0.24)
                    height: Theme.u * (index === 0 ? 4 : 3)
                    color: Qt.alpha("#ffffff", index === 0 ? 0.95 : 0.5)
                }
            }
        }
    }

    // Spotlight: a pill in the upper third and a few rows under it
    Item {
        visible: root.style === "spotlight" && root.shown
        anchors.fill: parent
        opacity: root.open
        Rectangle {
            id: spotPill
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.18
            width: parent.width * 0.56
            height: parent.height * 0.12
            radius: height / 2
            color: Theme.menuSurface
            border.width: Math.max(1, Theme.u / 2)
            border.color: Theme.accent
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: spotPill.bottom
            anchors.topMargin: Theme.u * 2
            width: spotPill.width
            height: parent.height * 0.3 * root.open
            radius: Theme.u * 4
            color: Theme.menuSurface
            clip: true
            Column {
                x: Theme.u * 3
                y: Theme.u * 3
                spacing: Theme.u * 2
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: spotPill.width * (index === 0 ? 0.8 : 0.55)
                        height: Theme.u * 3
                        color: index === 0 ? Theme.accent : Theme.mix(Theme.face, Theme.text, 0.35)
                    }
                }
            }
        }
    }

    // classic / win11 menu
    Rectangle {
        id: menu
        visible: (root.style === "classic" || root.style === "win11" || root.style === "tiles") && root.shown
        readonly property real w: root.style === "win11" ? root.width * 0.42 : root.style === "tiles" ? root.width * 0.5 : root.width * 0.3
        width: w
        height: root.height * 0.66 * root.open
        y: bar.y - height - Theme.u
        x: root.align === "left" ? Theme.u * 2 : root.align === "right" ? root.width - w - Theme.u * 2 : (root.width - w) / 2
        clip: true
        color: Theme.menuSurface
        border.width: Math.max(1, Theme.u / 2)
        border.color: Theme.edge
        // classic: coloured side strip and a list
        Rectangle {
            visible: root.style === "classic"
            width: parent.width * 0.16
            height: parent.height
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.title2
                }
                GradientStop {
                    position: 1
                    color: Theme.title1
                }
            }
        }
        Column {
            visible: root.style === "classic"
            x: parent.width * 0.22
            y: Theme.u * 3
            spacing: Theme.u * 3
            Repeater {
                model: 6
                Row {
                    required property int index
                    spacing: Theme.u * 2
                    Rectangle {
                        width: Theme.u * 5
                        height: width
                        color: [Theme.accent, Theme.accent2, Theme.accent3][parent.index % 3]
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: menu.width * (0.35 + 0.1 * (parent.index % 3))
                        height: Math.max(1, Theme.u)
                        color: Theme.mix(Theme.face, Theme.text, 0.4)
                    }
                }
            }
        }
        // tiles: the apps in a column, flat tiles beside them, live ones wide in the accent
        Column {
            visible: root.style === "tiles"
            x: Theme.u * 3
            y: Theme.u * 4
            spacing: Theme.u * 3
            Repeater {
                model: 6
                Rectangle {
                    required property int index
                    width: menu.width * (0.22 + 0.06 * (index % 3))
                    height: Math.max(1, Theme.u)
                    color: Theme.mix(Theme.face, Theme.text, 0.4)
                }
            }
        }
        Repeater {
            // [column, row, width] in cells of a 4-wide grid
            model: [[0, 0, 2], [2, 0, 1], [3, 0, 1], [0, 1, 1], [1, 1, 2], [3, 1, 1], [0, 2, 1], [1, 2, 1], [2, 2, 1]]
            Rectangle {
                required property var modelData
                readonly property real c: (menu.width * 0.52 - Theme.u * 3) / 4
                visible: root.style === "tiles"
                x: menu.width * 0.45 + modelData[0] * c
                y: Theme.u * 4 + modelData[1] * c
                width: modelData[2] * c - Theme.u
                height: c - Theme.u
                color: modelData[2] === 2 ? Theme.accent : Theme.menuHeader
            }
        }
        // win11: search box and a grid of pinned apps
        Rectangle {
            visible: root.style === "win11"
            x: Theme.u * 3
            y: Theme.u * 3
            width: parent.width - Theme.u * 6
            height: Theme.u * 6
            color: Theme.sunken
            border.width: Math.max(1, Theme.u / 2)
            border.color: Theme.lo
        }
        Grid {
            visible: root.style === "win11"
            x: Theme.u * 4
            y: Theme.u * 13
            columns: 5
            spacing: Theme.u * 3
            Repeater {
                model: 10
                Rectangle {
                    required property int index
                    width: (menu.width - Theme.u * 20) / 5
                    height: width * 0.8
                    color: [Theme.accent, Theme.accent2, Theme.accent3, Theme.accent4][index % 4]
                }
            }
        }
    }

    MiniCursor {
        readonly property point startBtn: Qt.point(bar.x + bar.height * 0.7, bar.y + bar.height / 2)
        readonly property point p: root.mixp(Qt.point(root.width * 0.6, root.height * 0.35), startBtn, root.ease(root.seg(0.04, 0.24)))
        x: p.x
        y: p.y
        click: root.t > 0.24 && root.t < 0.32 ? "left" : ""
    }
}
