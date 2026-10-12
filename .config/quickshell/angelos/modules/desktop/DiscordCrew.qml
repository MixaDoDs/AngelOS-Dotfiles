pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import qs.modules.background

// The people of your Discord call as little pixel people over the bar of the main screen
// (Config.discord.crew, services/DiscordVoice): a body of their own colour, their avatar for a
// head, the name above. They stroll, stop, look around, wave now and then; whoever speaks hops,
// the head swollen and a «…» over it; muted ones carry a small red mark, deafened ones
// headphones; you yourself are half as big again as the rest. They keep out of the angel's
// corner. Each takes the pointer on itself only: pick one up, carry, throw; whoever leaves the
// call bursts. This window is a strip over the bar and stays so; those in the hand or in the air
// are drawn once more in a second window over the whole screen, which takes no pointer at all.
PanelWindow {
    id: win

    screen: Shell.screenByName(Config.discord.crewScreen) || Shell.primaryScreen
    visible: stage.count > 0 || stage.bursts > 0
    anchors {
        bottom: true
        left: true
        right: true
    }
    // like the angel: out of the bar's zone, so they stand on its top edge
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    // as tall as the tallest of them needs — but never changed under a pointer that holds one
    property real stripH: Theme.u * 64
    function fit() {
        if (!stage.lifted)
            stripH = stage.tall;
    }
    implicitHeight: stripH
    color: "transparent"
    // Settings: with dragging off they take no pointer at all
    mask: Region {
        regions: Config.discord.crewDrag ? stage.hits : []
    }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "angelos-discord-crew"

    DiscordCrewStage {
        id: stage
        anchors.fill: parent
        screenName: win.screen ? win.screen.name : ""
        room: win.screen ? win.screen.height : 0
    }

    // the air over the strip: there from the moment the pointer is on someone, a little longer
    // than the last one is in it
    Timer {
        id: linger
        interval: 4000
    }
    Connections {
        target: stage
        function onAirWantedChanged() {
            if (!stage.airWanted)
                linger.restart();
        }
        function onTallChanged() {
            win.fit();
        }
        function onLiftedChanged() {
            win.fit();
        }
        // a right click on one of them: their menu, in the desktop menu's look
        function onMenuAsked(who, x, y) {
            personMenu.active = true;
            if (personMenu.item)
                personMenu.item.openList(who.name, stage.itemsFor(who), x, y);
        }
    }
    Component.onCompleted: fit()
    LazyLoader {
        id: personMenu
        DesktopMenu {
            parentWindow: win
        }
    }
    LazyLoader {
        active: win.visible && (stage.airWanted || linger.running)
        PanelWindow {
            id: air
            screen: win.screen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            // the same floor as the strip's: the bar's top edge
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: 0
            color: "transparent"
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "angelos-discord-crew-air"
            onHeightChanged: if (height > 0)
                stage.room = height

            Repeater {
                model: stage.flyers
                DiscordCrewGuy {
                    required property var modelData
                    who: modelData
                    eager: true
                    names: Config.discord.crewNames
                    x: modelData.x
                    y: parent.height - modelData.alt - modelData.hop - height
                }
            }

            RightClickGuard {}
        }
    }

    RightClickGuard {}
}
