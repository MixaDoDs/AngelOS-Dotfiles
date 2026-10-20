pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The stream's chat (Settings → Stream → «Chat on screen»): scripts/stream-chat.py follows the
// session log a chat reader writes (Config.stream.chatLog — the owner's bot keeps one; nothing
// here talks to YouTube). Each viewer's message: a capsule on the Halo (services/Halo), the cat
// there cheering (a heart for a paid one), and a little cat running along the bottom of the
// streamed screen with the nick over it (modules/streamchat) — a crown for a regular.
Singleton {
    id: root

    // tests point it at a folder of their own (ANGELOS_TEST keeps everything else off)
    readonly property string dir: Quickshell.env("ANGELOS_TEST") === "1" ? Quickshell.env("ANGELOS_CHAT_DIR") || "" : String(Config.stream.chatLog || "").replace(/^~(?=\/|$)/, Config.home)
    readonly property bool on: Config.ready && dir !== ""
    signal message(var m)                   // {author, text, amount, regular, count, place, newbie, color?}
    property var recent: []                 // the last ones, newest last
    // the race of this stream for the desktop widget (modules/desktop/widgets/ChatraceWidget):
    // {session, writers, top: [[author, count, color, regular], …]}; null before the first stream
    property var race: null

    // ---- the mines and the wild spam's bang (modules/streamchat/ChatRunners blows them up) ----
    // a paid message from mineRub roubles lays a mine on the cats' way; whoever runs onto it goes up
    // with every cat within boomPx of it. When the chat goes wild (spamCount in spamMs), now and
    // then one of the running cats goes off by itself, taking the ones around with it. The blown
    // up lose a quarter of their race (at least 3): what each lost this session goes to
    // chat-race-hits.json, scripts/stream-chat.py counts it off.
    readonly property int mineRub: 100
    readonly property int spamCount: 8
    readonly property int spamMs: 10000
    property var mines: []                  // {id, x: where on the way (a share of it), by}
    property var minus: ({})                // author → what the mines took this session
    property string minusSession: ""
    property var spam: []
    property double lastFuse: 0
    signal fuse()                           // the view: one of the running cats, off it goes
    signal blown(var authors)
    function lay(by) {
        if (mines.length < 5)
            mines = mines.concat([{
                    "id": ++n,
                    "x": 0.3 + Math.random() * 0.6,
                    "by": by
                }]);
    }
    // the cats a bang took (mine: its id, or -1 for the spam's): off the screen and off the race
    function hit(mine, victims) {
        mines = mines.filter(m => m.id !== mine);
        const gone = victims.map(v => v.id);
        runners = runners.filter(r => gone.indexOf(r.id) < 0);
        const session = race ? race.session : "";
        const took = session === minusSession ? Object.assign({}, minus) : {};
        const authors = [];
        for (const v of victims) {
            if (authors.indexOf(v.author) >= 0)
                continue;
            authors.push(v.author);
            const t = race ? (race.top || []).find(e => e[0] === v.author) : null;
            const now = t ? t[1] : v.count;
            took[v.author] = (took[v.author] || 0) + Math.min(now, Math.max(3, Math.round(now / 4)));
        }
        minus = took;
        minusSession = session;
        hits.write(JSON.stringify({
            "session": session,
            "minus": took
        }));
        if (authors.length)
            blown(authors);
    }
    AsyncFile {
        id: hits
        path: Config.stateDir + "/chat-race-hits.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.minus = d.minus || {};
                root.minusSession = d.session || "";
            } catch (e) {}
        }
    }

    // a viewer's cat colour: the one they picked in the chat («!pink»), else their nick's own —
    // FNV-1a, stirred, onto 12 hues × 2 shades, so nicks a letter apart still look apart
    function furOf(author, picked) {
        if (picked)
            return picked;
        let h = 2166136261;
        const a = String(author || "");
        for (let i = 0; i < a.length; i++)
            h = Math.imul(h ^ a.charCodeAt(i), 16777619);
        h = Math.imul(h ^ (h >>> 15), 0x2c1b3c6d);
        h = (h ^ (h >>> 12)) >>> 0;
        return Qt.hsla((h % 12) / 12, 0.8, (h >>> 8) % 2 ? 0.62 : 0.76, 1);
    }

    // the running cats: {id, author, regular, at, ms, count, place, newbie}; at = when it sets off,
    // one gapMs after the one before, so a burst of chat runs as a line instead of a heap on one
    // spot (a cat whose turn has not come yet waits off the screen); ms = how long it takes to
    // cross, its own between runMs and slowMs, so they overtake each other — and the race of the
    // stream: the more one wrote this session (count), the faster, down to 40 % of it; place 1–3
    // and newbie as scripts/stream-chat.py tells; more than `most` on the way are let go
    readonly property int most: 30
    readonly property int runMs: 6000
    readonly property int slowMs: 14000
    readonly property int gapMs: 1200
    property var runners: []
    property double last: 0
    property int n: 0
    function run(m) {
        if (!Config.stream.chatRunners || runners.length >= most)
            return;
        last = Math.max(Date.now(), last + gapMs);
        runners = runners.concat([{
                "id": ++n,
                "author": m.author,
                "regular": !!m.regular,
                "at": last,
                "ms": (runMs + Math.random() * (slowMs - runMs)) * Math.max(0.4, 1 - 0.05 * ((m.count || 1) - 1)),
                "count": m.count || 1,
                "place": m.place || 0,
                "newbie": !!m.newbie,
                "color": m.color || ""
            }]);
        tidy.start();
    }
    Timer {
        id: tidy
        interval: 500
        repeat: true
        onTriggered: {
            const now = Date.now();
            const kept = root.runners.filter(r => now - r.at < r.ms);
            if (kept.length !== root.runners.length)
                root.runners = kept;
            if (!kept.length)
                stop();
        }
    }

    function take(m) {
        recent = recent.concat([m]).slice(-20);
        message(m);
        run(m);
        if (!Config.stream.chatRunners)
            return;
        if ((m.rub || 0) >= mineRub)
            lay(m.author);
        const now = Date.now();
        spam = spam.filter(t => now - t < spamMs).concat([now]);
        if (spam.length >= spamCount && now - lastFuse > 30000 && Math.random() < 0.1) {
            lastFuse = now;
            fuse();
        }
    }

    Process {
        id: proc
        running: root.on
        command: ["python3", Quickshell.shellPath("scripts/stream-chat.py"), root.dir, Config.stateDir]
        stdout: SplitParser {
            onRead: line => {
                let m = null;
                try {
                    m = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (m && m.race)
                    root.race = m.race;
                else if (m && m.author)
                    root.take(m);
            }
        }
        // it only ends when it breaks: once more a little later
        onExited: if (root.on)
            again.restart()
    }
    Timer {
        id: again
        interval: 10000
        onTriggered: proc.running = Qt.binding(() => root.on)
    }
}
