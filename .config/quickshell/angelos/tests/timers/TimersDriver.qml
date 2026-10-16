import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Timers, offscreen (started by tests/timers/run.sh): the state file seeded by run.sh holds a
// timer that ended while the shell was off, a pomodoro at the end of its work and a paused
// timer; then a 2 s timer rings, a stopwatch pauses and laps. notify-send is a stand-in that
// keeps what it was asked ($FAKE_DIR/notify).
Scope {
    id: root

    property int step: 0
    readonly property string fake: Quickshell.env("FAKE_DIR")
    Component.onCompleted: Quickshell.watchFiles = false
    property string sw: ""

    function ok(name, cond, detail) {
        console.log("TEST " + name + " " + (cond ? "PASS" : "FAIL") + " " + (detail || ""));
    }
    FileView {
        id: notify
        watchChanges: true
        onFileChanged: reload()
        path: root.fake + "/notify"
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: saved
        watchChanges: true
        onFileChanged: reload()
        path: Config.stateDir + "/timers.json"
        blockLoading: true
        printErrors: false
    }
    function lines() {
        return String(notify.text() || "").split("\n").filter(l => l);
    }

    Timer {
        interval: 400
        running: true
        repeat: true
        onTriggered: {
            root.step++;
            const T = Timers;
            if (root.step === 4) {
                const l = root.lines();
                root.ok("missed", l.some(x => x.includes("Время вышло") && x.includes("чай") && x.includes("закончился в")), JSON.stringify(l));
                root.ok("pomodoro", l.some(x => x.includes("Перерыв 5 мин")) && T.items.some(i => i.kind === "pomodoro" && i.phase === "rest" && Math.abs(i.end - Date.now() - 300000) < 5000), JSON.stringify(T.items));
                root.ok("paused-kept", T.items.some(i => i.kind === "timer" && !i.end && i.left === 60000) && T.items.length === 2, T.items.length);
                T.add(T.parse("2s тест"));
                T.add(T.parse("секундомер"));
                root.sw = T.items.find(i => i.kind === "stopwatch").id;
            } else if (root.step === 6) {
                T.toggle(root.sw);
                const s = T.find(root.sw);
                root.ok("stopwatch-pause", !s.start && s.acc >= 600 && s.acc < 1500, s.acc);
                T.lap(root.sw);
                root.ok("lap", T.find(root.sw).laps.length === 1, "");
                const p = T.items.find(i => i.kind === "timer" && !i.end);
                T.toggle(p.id);
                root.ok("resume", Math.abs(T.find(p.id).end - Date.now() - 60000) < 1000, "");
            } else if (root.step === 11) {
                const l = root.lines();
                root.ok("rings", l.some(x => x.includes("Время вышло") && x.includes("тест") && !x.includes("закончился")) && !T.items.some(i => i.label === "тест"), JSON.stringify(l));
                T.stop(root.sw);
            } else if (root.step === 13) {
                let list = [];
                try {
                    list = JSON.parse(saved.text());
                } catch (e) {}
                root.ok("saved", list.length === T.items.length && list.length === 2 && !list.some(i => i.kind === "stopwatch"), saved.text());
                root.ok("parse-none", T.parse("telegram") === null && T.parse("10") === null, "");
                console.log("TEST DONE");
                Qt.quit();
            }
        }
    }
}
