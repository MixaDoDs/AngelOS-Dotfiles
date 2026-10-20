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
    signal message(var m)                   // {author, text, amount, regular}
    property var recent: []                 // the last ones, newest last

    // the running cats: {id, author, regular, at}; a few at a time, the rest wait their turn
    readonly property int most: 6
    readonly property int runMs: 9000
    property var runners: []
    property var waiting: []
    property int n: 0
    function run(m) {
        if (!Config.stream.chatRunners)
            return;
        const r = {
            "id": ++n,
            "author": m.author,
            "regular": !!m.regular,
            "at": Date.now()
        };
        if (runners.length < most)
            runners = runners.concat([r]);
        else if (waiting.length < 30)
            waiting = waiting.concat([r]);
        tidy.start();
    }
    Timer {
        id: tidy
        interval: 500
        repeat: true
        onTriggered: {
            const now = Date.now();
            let kept = root.runners.filter(r => now - r.at < root.runMs);
            let wait = root.waiting;
            while (kept.length < root.most && wait.length) {
                kept = kept.concat([Object.assign({}, wait[0], {
                        "at": now
                    })]);
                wait = wait.slice(1);
            }
            if (kept.length !== root.runners.length || wait !== root.waiting) {
                root.runners = kept;
                root.waiting = wait;
            }
            if (!kept.length && !wait.length)
                stop();
        }
    }

    function take(m) {
        recent = recent.concat([m]).slice(-20);
        message(m);
        run(m);
    }

    Process {
        id: proc
        running: root.on
        command: ["python3", Quickshell.shellPath("scripts/stream-chat.py"), root.dir]
        stdout: SplitParser {
            onRead: line => {
                let m = null;
                try {
                    m = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (m && m.author)
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
