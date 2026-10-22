pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../plugins/osu-mini/RhythmCore.js" as Core

// The music's beat for the lyric line word by word (Settings → Lyrics → «On the beat»): each
// word comes up on the beat or half-beat nearest its time (Lyrics.wordAt), so the line moves
// with the song instead of with guessed syllables. scripts/osu-beats.py hears the player's own
// stream (never the whole computer) while a line is shown word by word; its guesses are held
// on one grid by osu!mini's rhythm core (the same beat it drums to).
// Not locked (no clear beat yet, free time, quiet): the words keep their own times.
Singleton {
    id: root

    readonly property bool wanted: Config.lyrics.byWord !== false && Config.lyrics.onBeat !== false && Lyrics.playing && Lyrics.status === "ok" && !Lyrics.unseen && Lyrics.lines.some(l => !!l.s)
    property var beat: Core.newBeat()
    property bool locked: false
    readonly property real half: beat.P / 2      // ms between the places a word may land

    // the song time (s) of the beat or half-beat nearest `t`, seen at song time `pos`
    function snap(t, pos) {
        if (!locked || !(half > 0))
            return t;
        const now = Date.now();
        const at = now + (t - pos) * 1000;
        return pos + (beat.anchor + Math.round((at - beat.anchor) / half) * half - now) / 1000;
    }

    Process {
        id: tracker
        running: root.wanted
        // only the player's own stream (its MPRIS name is its stream's: Helium, Spotify…), never
        // the whole computer: a call, a game or a notification would set the beat
        command: ["python3", Quickshell.shellDir + "/scripts/osu-beats.py", "app"].concat([Lyrics.player ? Lyrics.player.identity : "", Lyrics.player ? Lyrics.player.desktopEntry : ""].filter(n => !!n))
        onRunningChanged: if (!running) {
            root.beat = Core.newBeat();
            root.locked = false;
        }
        stdout: SplitParser {
            onRead: line => {
                let msg = null;
                try {
                    msg = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (!msg || msg.idle)
                    return;
                Core.beatFeed(root.beat, msg, Date.now());
                root.locked = root.beat.locked;
                root.beatChanged();
            }
        }
    }
    // a new song: its own beat
    Connections {
        target: Lyrics
        function onTrackKeyChanged() {
            root.beat = Core.newBeat();
            root.locked = false;
        }
    }
}
