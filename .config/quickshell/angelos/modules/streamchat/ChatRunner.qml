pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import "../halo/HaloCat.js" as Kitty

// One viewer running across (modules/streamchat/ChatRunners): the Halo's cat in the viewer's own
// colour (picked with «!pink» in the chat, else from the nick: the same on every stream), the nick on a plate over it, a crown for a
// regular. The race of the stream (services/StreamChat): the plate shows how many they wrote,
// the top three their place and a trail behind (fire for the first), a newbie «НОВЕНЬКИЙ!» and
// sparkles. Where it is goes by the time since it set
// off (modelData.at, maybe still ahead: then it waits off the screen), so a change of the list
// moves nobody; the share of the run is kept, not the place, so a lane that only gets its width
// later (the strip's window just shown) still carries it all the way across.
Item {
    id: runner
    required property var modelData
    property int pixel: Theme.u * 2
    property real lane: 1000                // the width it crosses
    property bool still: false              // tests: stays where it is
    readonly property int catW: 20 * pixel
    // a regular's crown, over the cat's head
    readonly property var crown: ["#.##.#", "######", "######"]
    readonly property var star: [".#.", "###", ".#."]
    readonly property int place: modelData.place || 0
    readonly property int count: modelData.count || 1
    // the viewer's own colour (StreamChat.furOf): picked in the chat, else from the nick
    readonly property color fur: StreamChat.furOf(modelData.author, modelData.color)
    readonly property var medal: ["", "#ffd23f", "#d8e0ec", "#e0904a"]
    readonly property real catX: (width - catW) / 2
    readonly property real catY: chip.height + Theme.u + 4 * pixel
    width: Math.max(catW, chip.width)
    height: chip.height + Theme.u + 16 * pixel
    property int tick: 0
    property real done: 0                   // 0 = just off the left edge, 1 = past the right one
    readonly property bool going: go.running // set off and not past the edge yet
    x: -width + done * (lane + width)
    NumberAnimation on done {
        id: go
        running: false
        to: 1
    }
    function setOff() {
        done = Math.min(1, (Date.now() - modelData.at) / modelData.ms);
        go.duration = Math.max(1, (1 - done) * modelData.ms);
        go.start();
    }
    Component.onCompleted: {
        if (still)
            return;
        const wait = modelData.at - Date.now();
        if (wait > 0) {
            turn.interval = wait;
            turn.start();
        } else
            setOff();
    }
    Timer {
        id: turn
        onTriggered: runner.setOff()
    }
    Timer {
        interval: 110
        repeat: true
        running: go.running
        onTriggered: runner.tick++
    }

    // the nick on a plate of the theme's face: readable over any game
    Rectangle {
        id: chip
        x: (runner.width - width) / 2
        width: nick.implicitWidth + Theme.u * 6
        height: nick.implicitHeight + Theme.u * 2
        color: Theme.face
        border.width: Theme.u
        border.color: runner.place ? runner.medal[runner.place] : runner.modelData.regular ? Theme.accent : Theme.edge
        PxText {
            id: nick
            anchors.centerIn: parent
            text: (runner.modelData.newbie ? I18n.t("НОВЕНЬКИЙ! ", "NEW! ") : "") + (runner.place ? "#" + runner.place + " " : "") + runner.modelData.author + (runner.count > 1 ? " ×" + runner.count : "")
            kind: "tiny"
        }
    }
    // the trail of the top three: squares left behind, flickering; fire for the first
    Repeater {
        model: runner.place ? 4 : 0
        Rectangle {
            required property int index
            readonly property int s: Math.max(1, 3 - Math.floor(index / 2)) * runner.pixel
            width: s
            height: s
            x: runner.catX + 5 * runner.pixel - (index + 1) * 3 * runner.pixel
            y: runner.catY + (6 + (index + runner.tick) % 3 - 1) * runner.pixel - s / 2
            opacity: 1 - index * 0.22
            color: runner.place === 1 ? ((index + runner.tick) % 2 ? "#ff5a1f" : "#ffd23f") : runner.medal[runner.place]
        }
    }
    // a newbie's sparkles, blinking around the cat
    Repeater {
        model: runner.modelData.newbie ? [[1, 2], [17, 0], [9, 9]] : []
        PxIcon {
            required property var modelData
            required property int index
            visible: (runner.tick + index) % 3 !== 0
            bitmap: runner.star
            pixel: runner.pixel
            ink: "#fff3a0"
            x: runner.catX + modelData[0] * runner.pixel
            y: runner.catY + modelData[1] * runner.pixel
        }
    }
    PxIcon {
        visible: !!runner.modelData.regular
        bitmap: runner.crown
        pixel: runner.pixel
        ink: Theme.accent
        x: (runner.width - runner.catW) / 2 + 14 * runner.pixel
        y: chip.height + Theme.u
    }
    PxIcon {
        bitmap: Kitty.run[runner.tick % 5]
        pixel: runner.pixel
        ink: runner.fur
        x: runner.catX
        y: runner.catY
    }
}
