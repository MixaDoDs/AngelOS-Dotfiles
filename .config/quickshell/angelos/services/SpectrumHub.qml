pragma Singleton

import QtQuick
import Quickshell

// One cava for the same spectrum: MusicSpectrum instances that hear the same thing in the same
// number of bars (the wallpaper's lines on two screens, the Halo's card on two screens) join here
// by `key`; the first live one is the leader, the only one that runs audio-tap/cava, and hands
// every frame to the others (onFrame). The leader goes → the next one takes over.
Singleton {
    id: root

    property var members: ({})       // key → [instances], the first is the leader
    property var lead: ({})          // key → the leader
    signal frame(string key, var levels)

    function join(key, who) {
        const m = members;
        m[key] = (m[key] || []).concat([who]);
        publish(m);
    }
    function leave(key, who) {
        const m = members;
        const l = (m[key] || []).filter(x => x !== who);
        if (l.length)
            m[key] = l;
        else
            delete m[key];
        publish(m);
    }
    function publish(m) {
        const l = {};
        for (const k in m)
            l[k] = m[k][0];
        members = m;
        lead = l;
    }
}
