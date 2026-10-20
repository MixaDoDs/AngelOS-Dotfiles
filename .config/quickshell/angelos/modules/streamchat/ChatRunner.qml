pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import "../halo/HaloCat.js" as Kitty

// One viewer running across (modules/streamchat/ChatRunners): the Halo's cat in the text colour,
// the nick on a plate over it, a crown for a regular. Where it is goes by the time since it set
// off (modelData.at), so a change of the list moves nobody.
Item {
    id: runner
    required property var modelData
    property int pixel: Theme.u * 2
    property real lane: 1000                // the width it crosses
    property bool still: false              // tests: stays where it is
    readonly property int catW: 20 * pixel
    // a regular's crown, over the cat's head
    readonly property var crown: ["#.##.#", "######", "######"]
    width: Math.max(catW, chip.width)
    height: chip.height + Theme.u + 16 * pixel
    property int tick: 0
    x: -width
    NumberAnimation on x {
        id: go
        running: false
        to: runner.lane
    }
    Component.onCompleted: {
        if (still)
            return;
        const done = Math.min(1, (Date.now() - modelData.at) / StreamChat.runMs);
        x = -width + done * (lane + width);
        go.duration = Math.max(1, (1 - done) * StreamChat.runMs);
        go.start();
    }
    Timer {
        interval: 110
        repeat: true
        running: !runner.still
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
        border.color: runner.modelData.regular ? Theme.accent : Theme.edge
        PxText {
            id: nick
            anchors.centerIn: parent
            text: runner.modelData.author
            kind: "tiny"
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
        ink: Theme.text
        x: (runner.width - runner.catW) / 2
        y: chip.height + Theme.u + 4 * runner.pixel
    }
}
