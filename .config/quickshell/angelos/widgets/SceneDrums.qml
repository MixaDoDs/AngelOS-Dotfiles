pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

// What a layered scene does on the music's hits (services/Bass), for its host: the desktop's
// wallpaper and the wallpaper editor's picture. The effects it has by itself (each its own switch in
// Settings → Wallpaper → Wallpaper sounds) and its modifiers (widgets/SceneWall), each as strong as
// the player really plays (LyricsGlow.loud: its sound after its slider and the master volume).
Scope {
    id: root

    required property Item wall
    property string folder: ""
    property bool hearing: false
    // the wallpaper editor: the modifiers play whatever Settings say, or they couldn't be tuned
    property bool studio: false

    function own(key) {
        return Wallpapers.own(folder, key) === true;
    }
    readonly property bool hearsBass: hearing && wall.builtin && own("sceneBass")
    readonly property bool hearsSnare: hearing && wall.builtin && own("sceneSnare")
    readonly property bool hearsHats: hearing && wall.builtin && own("sceneHats")
    readonly property bool hearsEdges: hearing && wall.builtin && own("sceneEdges")
    readonly property bool hearsBreath: hearing && wall.builtin && own("sceneBreath")
    readonly property bool hearsMods: hearing && wall.modifiers.length > 0 && (studio || own("sceneMods"))
    readonly property bool hearsAny: hearsBass || hearsSnare || hearsHats || hearsEdges || hearsBreath || hearsMods
    // the wall's picture has to go through shaders/scene_kick
    readonly property bool bends: hearsBass || hearsEdges || hearsBreath || hearsMods

    property real kickGain: 0
    property real snareGain: 0
    property real hatGain: 0
    Binding {
        target: root.wall
        property: "kick"
        value: root.hearsBass ? root.kickGain : root.hearsMods && root.wall.hasWaves ? 1 : 0
    }
    Binding {
        target: root.wall
        property: "snare"
        value: root.hearsSnare ? root.snareGain : 0
    }
    Binding {
        target: root.wall
        property: "edge"
        value: root.hearsEdges ? root.snareGain : 0
    }
    // the lens takes the bass on the scene's own tick (wall.time), not on each of Bass's lines:
    // two clocks made the wallpaper draw ~80 frames a second under music, not the scene's 24 (03.11)
    Connections {
        target: root.wall
        enabled: root.hearsBreath
        function onTimeChanged() {
            const v = Bass.dense * LyricsGlow.loud;
            if (v !== root.wall.breath)
                root.wall.breath = v;
        }
    }
    onHearsBreathChanged: if (!hearsBreath)
        wall.breath = 0
    Binding {
        target: root.wall
        property: "breathOn"
        value: root.hearsBreath
    }
    Binding {
        target: root.wall
        property: "hat"
        value: root.hearsHats ? root.hatGain : 0
    }
    Binding {
        target: root.wall
        property: "modsOn"
        value: root.hearsMods
    }
    Binding {
        target: root.wall
        property: "modsGain"
        value: root.studio ? 1 : Math.max(0, Wallpapers.own(root.folder, "sceneModsGain")) / 100
    }

    // every kick rings by how hard it hit, the hardest as the song's first ones
    function kicked(loud, punch, hype) {
        if (hearsBass) {
            kickGain = loud;
            wall.kickNow(loud * (hype > 0 ? 1 : 1 + 1.6 * punch), punch, hype);
        }
        if (hearsMods)
            wall.drum("kick", loud, punch, hype);
    }
    // The snares knock the CRT's screen off its signal, the hats run a scanline down it
    function snared(loud, crack) {
        if (hearsSnare || hearsEdges) {
            wall.snareAt = wall.time;
            snareGain = Math.min(1, loud * (0.5 + crack));
        }
        if (hearsMods)
            wall.drum("snare", loud, crack, 0);
    }
    function hatted(loud) {
        if (hearsHats) {
            wall.hatAt = wall.time;
            hatGain = loud;
            wall.hatSeed = Math.random();
        }
        if (hearsMods)
            wall.drum("hat", loud, 0, 0);
    }
    Connections {
        target: Bass
        enabled: root.hearsAny
        function onKicked() {
            root.kicked(LyricsGlow.loud, Bass.punch, Bass.hype);
        }
        function onSnared() {
            root.snared(LyricsGlow.loud, Bass.crack);
        }
        function onHatted() {
            root.hatted(LyricsGlow.loud);
        }
    }
    property bool listening: false
    function listen(on) {
        if (on === listening)
            return;
        listening = on;
        Bass.walls += on ? 1 : -1;
    }
    onHearsAnyChanged: listen(hearsAny)
    Component.onCompleted: listen(hearsAny)
    Component.onDestruction: listen(false)
}
