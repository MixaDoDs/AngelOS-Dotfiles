pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// «Забег»: while something long runs (a build, an install, a system update — scripts/waiting.py
// knows them by name, in any terminal or IDE) the cat runs along the bar's middle
// (modules/bar/parts/Runner.qml) and the lyrics step aside; it ends at a finish flag.
// On and off is the bar element itself (Settings → Bar → Layout: «Забег» in the hidden ones),
// one place. Silent in a game and in «Киберспорт»: nothing read, nothing shown.
// It can't tell a build that failed from one that worked, so the finish is always the same.
Singleton {
    id: root

    readonly property bool wanted: Config.ready && BarLayout.has("runner") && !Shell.gaming && !Power.esports
    // the waits now, oldest first: [{name, pid, start (unix s)}]
    property var jobs: []
    readonly property var job: jobs.length ? jobs[0] : null
    readonly property bool active: wanted && !!job
    // the finish line: the last wait ended {name, secs, jumps, record}, shown until the cat is past it
    property var finish: null
    readonly property bool shown: active || (wanted && !!finish)
    // the bar it runs on: the main screen's, or the first screen that has a bar
    readonly property string screen: {
        const s = Config.bar.screens || [];
        return !s.length || s.includes(Shell.primaryName) ? Shell.primaryName : s[0];
    }

    // this wait's game: the player's jumps, crashes, the best score
    property int jumps: 0
    property int crashes: 0
    property int best: 0
    property bool record: false
    property double since: 0

    function bestOf(name) {
        return Story.ready && Story.runner && Story.runner.best ? Story.runner.best[name] || 0 : 0;
    }
    // a game over (Runner): the score, kept as the command's record if higher
    function scored(points) {
        if (!job || points <= 0)
            return false;
        best = Math.max(best, points);
        if (points <= bestOf(job.name) || !Story.ready)
            return false;
        const b = Object.assign({}, Story.runner.best || {});
        b[job.name] = points;
        Story.runner.best = b;
        record = true;
        return true;
    }
    function jumped() {
        jumps++;
    }
    function crashed() {
        crashes++;
    }
    // fifty bugs jumped in one game
    function streak() {
        Achievements.note("runner.streak");
    }
    // the cat is past the flag and the line has been read
    function done() {
        finish = null;
    }

    function _start(j) {
        jumps = 0;
        crashes = 0;
        best = 0;
        record = false;
        since = j.start;
    }
    function _end(j) {
        const secs = Math.max(0, Math.round(Date.now() / 1000 - j.start));
        finish = {
            "name": j.name,
            "secs": secs,
            "jumps": jumps,
            "best": best,
            "record": record
        };
        finishOff.restart();
        if (Story.ready)
            Story.runner.runs = (Story.runner.runs || 0) + 1;
        Achievements.note("runner.finish", j.name.split(" ")[0]);
        if (secs >= 600 && crashes === 0)
            Achievements.note("runner.marathon");
    }
    onJobsChanged: {
        const cur = job;
        if (cur && cur.start !== since) {
            finish = null;
            _start(cur);
        }
    }
    // the cat may never get there (the bar hidden, the screen asleep): the line goes anyway
    Timer {
        id: finishOff
        interval: 20000
        onTriggered: root.finish = null
    }
    onWantedChanged: if (!wanted) {
        jobs = [];
        finish = null;
    }

    Process {
        running: root.wanted
        command: ["python3", Quickshell.shellDir + "/scripts/waiting.py"]
        stdout: SplitParser {
            onRead: line => {
                let list;
                try {
                    list = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (!Array.isArray(list))
                    return;
                const was = root.job;
                root.jobs = list;
                // the wait the cat ran for is over and nothing else is left to wait for
                if (was && !list.length)
                    root._end(was);
            }
        }
    }

    // the processor's load 0…1 (/proc/stat every 2 s while the cat runs): it runs faster the
    // busier the build keeps the machine
    property real cpu: 0
    property var cpuLast: null
    FileView {
        id: cpuStat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4], total = f.reduce((a, b) => a + b, 0);
            if (root.cpuLast && total > root.cpuLast.t)
                root.cpu = 1 - (idle - root.cpuLast.i) / (total - root.cpuLast.t);
            root.cpuLast = {
                "t": total,
                "i": idle
            };
        }
    }
    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: root.active
        onTriggered: cpuStat.reload()
    }
}
