pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// The devices' ampoules standing in a row on their shelf: the device's tag (a small icon of
// its own, the ampoule is the thing to look at), its ampoule (PxAmpoule), the number when asked. The bar's widget (modules/bar/parts/PeripheralsButton)
// and the preview in Settings are this one item, drawn by Config.peripherals.
//   devices   entries of services/Peripherals: {kind, percent, charging, asleep, level}
//   vertical  a taskbar on a side edge: one under another, no shelf
Item {
    id: root

    property var devices: []
    property int pixel: Theme.u
    property int rows: 13
    property bool vertical: false
    property bool barInk: false             // the hell bar: outlines in the bar's icon colour
    // the bar's keys: the liquid in the accent like the icons' fills beside it, red only low
    // (the palette picked in Settings stays for the panel and the preview)
    property bool plain: false
    property var stops: Peripherals.stops

    readonly property var c: Config.peripherals
    readonly property int cols: c.size === "slim" ? 4 : c.size === "wide" ? 8 : 6
    // the text's colour, not the icons' outline: in a light theme whose outlines are light too
    // the tags (outlines only) and the glass would be lost on the bar
    readonly property color ink: barInk ? Theme.hellBarIcon : Theme.text
    readonly property bool shelf: c.rack && !vertical && devices.length > 0
    // the tags: outlines a few art pixels across, one weight, so three of them stay quieter
    // than one ampoule
    readonly property var tags: ({
            "mouse": [".###.", "#.#.#", "#.#.#", "#...#", "#...#", "#...#", ".###."],
            "keyboard": ["#.#.#.#", ".......", "#.#.#.#", ".......", "#.###.#"],
            "headset": [".#####.", "#.....#", "#.....#", "##...##", "##...##"],
            "gamepad": [".#####.", "#.....#", "#.#.#.#", "#.....#", ".##.##."],
            "phone": ["#####", "#...#", "#...#", "#...#", "#...#", "#.#.#", "#####"],
            "pen": ["...##", "..#.#", ".#.#.", "#.#..", "##..."],
            "speaker": ["#####", "#...#", "#.#.#", "#...#", "#.#.#", "#...#", "#####"],
            "touchpad": ["#######", "#.....#", "#.....#", "#######", "#..#..#", "#######"],
            "other": [".#.#.", ".#.#.", "#####", "#...#", ".###.", "..#.."]
        })

    implicitWidth: grid.implicitWidth + (shelf ? pixel * 2 : 0)
    implicitHeight: grid.implicitHeight + (shelf ? pixel : 0)

    Grid {
        id: grid
        x: root.shelf ? root.pixel : 0
        columns: root.vertical ? 1 : Math.max(1, root.devices.length)
        columnSpacing: root.pixel * 3
        rowSpacing: root.pixel * 2
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignBottom
        Repeater {
            model: root.devices
            Row {
                id: cell
                required property var modelData
                readonly property bool low: modelData.level !== "ok"
                readonly property bool blink: modelData.level === "veryLow" && !modelData.asleep && !Motion.calm && root.visible
                spacing: root.pixel
                PxIcon {
                    visible: root.c.glyphs
                    anchors.bottom: parent.bottom
                    bitmap: root.tags[cell.modelData.kind] || root.tags.other
                    iconStyle: "angelos"
                    pixel: root.pixel
                    // quieter than the glass next to it
                    opacity: cell.modelData.asleep ? 0.4 : 0.75
                    ink: root.ink
                }
                PxAmpoule {
                    id: glass
                    anchors.bottom: parent.bottom
                    pixel: root.pixel
                    cols: root.cols
                    rows: root.rows
                    value: cell.modelData.percent / 100
                    charging: cell.modelData.charging
                    asleep: cell.modelData.asleep
                    low: cell.low
                    stops: root.plain ? [Theme.hex(cell.low ? Theme.danger : Theme.accent)] : root.stops
                    paint: root.c.paint
                    steps: root.c.steps
                    glint: root.c.glint
                    bubbles: root.c.bubbles
                    ink: root.ink
                    lowColor: root.barInk ? Theme.hellAccent : Theme.danger
                    // almost empty: it blinks (calm motion: it doesn't)
                    SequentialAnimation {
                        running: cell.blink
                        loops: Animation.Infinite
                        onRunningChanged: if (!running)
                            glass.dim = 1
                        NumberAnimation {
                            target: glass
                            property: "dim"
                            to: 0.25
                            duration: 500
                        }
                        NumberAnimation {
                            target: glass
                            property: "dim"
                            to: 1
                            duration: 500
                        }
                        PauseAnimation {
                            duration: 700
                        }
                    }
                }
                PxText {
                    visible: root.c.percent === "always" || (root.c.percent === "low" && cell.low)
                    anchors.verticalCenter: parent.verticalCenter
                    text: cell.modelData.percent
                    kind: "tiny"
                    color: cell.low ? (root.barInk ? Theme.hellAccent : Theme.danger) : root.barInk ? Theme.hellText : Theme.text
                    opacity: cell.modelData.asleep ? 0.45 : 1
                }
            }
        }
    }
    // the shelf: one line under all of them, a pixel wider on each side
    Rectangle {
        visible: root.shelf
        y: grid.height
        width: parent.width
        height: root.pixel
        color: Qt.alpha(root.ink, 0.5)
    }
}
