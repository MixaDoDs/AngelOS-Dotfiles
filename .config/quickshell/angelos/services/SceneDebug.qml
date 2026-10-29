pragma Singleton

import QtQuick
import Quickshell

// The owner's hand on a scene's night (Settings → Debug, owner only): the meteor run off a
// timeline of its own instead of the clock, faster or slower, its colour picked, the hour of the
// day put by hand. Nothing is saved: a restart gives the clock back. Wallpapers.nightEvent /
// nightMix / twilightMix / nightVariant read it, so the picture, the sounds and the colour scheme
// all follow.
Singleton {
    id: root

    // the event by hand: its age, seconds from the impact (-2400 = it comes out of the dark,
    // `afterEnd` = the last of the aftermath gone)
    property bool eventOn: false
    property real eventAge: -2400
    property bool playing: true
    property real speed: 1
    readonly property real eventStart: -2400
    readonly property real afterEnd: 57600
    // the hour the wallpapers see: -1 the clock (or the wallpaper's own pick), else 0..24 — the
    // day, the dusk, the night, the dawn and every step between them, as the clock would show it
    property real hour: -1
    // the meteor's colour: -1 the night's own (seeded by the date), else SceneEvent's variants
    property int variant: -1

    function jump(age) {
        eventOn = true;
        eventAge = Math.max(eventStart, Math.min(afterEnd, age));
        if (hour < 0)
            hour = 4;
    }
    function reset() {
        eventOn = false;
        playing = true;
        speed = 1;
        hour = -1;
        variant = -1;
    }

    // `d` with the hour put by hand
    function at(d) {
        if (hour < 0)
            return d;
        const r = new Date(d);
        r.setHours(0, 0, 0, 0);
        return new Date(r.getTime() + hour * 3600000);
    }

    // a quarter of a second at a time: the scene's own frames do the rest
    Timer {
        running: root.eventOn && root.playing && root.speed > 0 && root.eventAge < root.afterEnd
        interval: 250
        repeat: true
        onTriggered: root.eventAge = Math.min(root.afterEnd, root.eventAge + 0.25 * root.speed)
    }
}
