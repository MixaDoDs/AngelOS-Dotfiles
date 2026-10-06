import QtQuick
import qs.config
import qs.services
import qs.widgets

// Terminal bubble with a ">_" face; bobs gently (stepped) while Codex works.
// Mac look (Skin.mac, not on hell's desktop): the "terminal" line icon instead — tinted by the
// state, or with `mono` one colour (`monoColor`: the menu bar's ink) and a state dot. 8 × pixel.
Item {
    id: root

    property int pixel: Theme.u
    property string state: CodexState.state
    // the demon rules: two little horns on the bubble (on the bar too); on the desktop
    // in hell (Theme.hell) the circle's dark colours, the state in its one accent
    property bool horns: Angel.demon || Theme.hell
    property bool hellLook: Theme.hell
    readonly property var rows: horns ? hornRows : haloRows
    readonly property var hornRows: [
        ".r.......r.",
        ".rr#####rr.",
        "..#wwwww#..",
        ".#wxxxxxw#.",
        "#wxx#xxxxw#",
        "#wxxx#xxxw#",
        "#wxx#x###w#",
        "#wxxxxxxxw#",
        ".#wwwwwww#.",
        "..#######..",
        "...#...#..."
    ]
    readonly property var haloRows: [
        "...#####...",
        "..#wwwww#..",
        ".#wxxxxxw#.",
        "#wxx#xxxxw#",
        "#wxxx#xxxw#",
        "#wxx#x###w#",
        "#wxxxxxxxw#",
        ".#wwwwwww#.",
        "..#######..",
        "...#...#..."
    ]
    property int bob: 0

    property bool mono: false
    property color monoColor: Skin.text
    readonly property bool mac: Skin.mac && !hellLook
    implicitWidth: mac ? pixel * 8 : face.width
    implicitHeight: mac ? pixel * 8 : face.height + pixel

    Loader {
        active: root.mac
        visible: active
        sourceComponent: Item {
            width: root.pixel * 8
            height: root.pixel * 8
            MacIcon {
                name: "terminal"
                size: root.pixel * 8
                stroke: 2
                color: root.mono ? root.monoColor : root.state === "none" ? Skin.textDim : CodexState.stateColor(root.state, Theme)
                opacity: root.state === "none" ? 0.7 : 1
            }
            Rectangle {
                visible: root.mono && root.state !== "none"
                width: Math.max(4, root.pixel * 2.6)
                height: width
                radius: width / 2
                x: parent.width - width * 0.8
                y: parent.height - width * 0.9
                color: CodexState.stateColor(root.state, Theme)
            }
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.visible && root.state === "working" && !root.mac
        onTriggered: root.bob = root.bob ? 0 : 1
        onRunningChanged: if (!running)
            root.bob = 0
    }
    PxIcon {
        id: face
        visible: !root.mac
        y: root.bob * root.pixel
        bitmap: root.rows
        pixel: root.pixel
        ink: root.hellLook ? Theme.hellRim : (Theme.dark ? Theme.text : Theme.edge)
        fill2: root.hellLook ? CodexState.hellStateColor(root.state, Theme) : root.state === "none" ? Theme.textDim : CodexState.stateColor(root.state, Theme)
        light: root.hellLook ? Theme.hellFaceAlt : Theme.dark ? Theme.face : "#ffffff"
        bad: root.hellLook ? Theme.hellTextDim : "#e0203a"
        opacity: root.state === "none" ? 0.7 : 1
    }
}
