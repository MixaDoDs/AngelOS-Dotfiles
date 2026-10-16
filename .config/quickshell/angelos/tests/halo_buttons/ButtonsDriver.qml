import QtQuick
import Quickshell
import qs.config
import qs.services
import "../../widgets/Icons.js" as Icons

// The Halo's quick buttons, offscreen (started by tests/halo_buttons/run.sh): every button of
// the catalog with an icon that exists, the chosen order (unknown ids skipped), only the
// recording reads as on, the fields start a timer and put a note on the shelf, the pomodoro
// starts one.
Scope {
    id: root

    property int step: 0
    Component.onCompleted: Quickshell.watchFiles = false

    function ok(name, cond, detail) {
        console.log("TEST " + name + " " + (cond ? "PASS" : "FAIL") + " " + (detail || ""));
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            root.step++;
            const B = HaloButtons;
            if (root.step === 3) {
                const want = ["pomodoro", "timer", "record", "picker", "note"];
                const ids = B.catalog.map(b => b.id);
                root.ok("catalog", want.every(id => ids.includes(id)) && ids.length === want.length, ids.join(","));
                const names = Icons.names();
                const bad = B.catalog.filter(b => !names.includes(b.icon)).map(b => b.id + ":" + b.icon);
                root.ok("icons", bad.length === 0, bad.join(","));
                root.ok("labels", B.catalog.every(b => B.label(b) !== "" && ["action", "toggle", "field"].includes(b.kind)) && B.hint("timer") !== "" && B.hint("note") !== "", "");
                root.ok("default-order", B.list.map(b => b.id).join(",") === want.join(","), B.list.map(b => b.id).join(","));
                const keep = Config.halo.buttons;
                // "dnd" was a button once (the sidebar has it): an old settings file keeps working
                Config.halo.buttons = ["note", "bogus", "dnd", "picker"];
                root.ok("order-skips-unknown", B.list.map(b => b.id).join(",") === "note,picker", B.list.map(b => b.id).join(","));
                Config.halo.buttons = keep;

                root.ok("not-toggles-off", !B.on("pomodoro") && !B.on("timer") && !B.on("note") && !B.on("record"), "");

                root.ok("field-empty", !B.submit("timer", "  ") && !B.submit("note", ""), "");
                root.ok("field-timer", B.submit("timer", "12m чай"), "");
                // only timers are typed there: a bare number is minutes, words are refused
                root.ok("field-bare-minutes", B.submit("timer", "25") && Timers.items.some(t => t.kind === "timer" && t.total === 25 * 60000), JSON.stringify(Timers.items));
                root.ok("field-refuses", !B.submit("timer", "чай"), "");
                root.ok("field-note", B.submit("note", "купить молоко"), "");
                B.run("pomodoro");
            } else if (root.step === 5) {
                root.ok("timer-started", Timers.items.some(t => t.kind === "timer" && t.label === "чай" && t.total === 12 * 60000), JSON.stringify(Timers.items));
                root.ok("pomodoro-started", Timers.items.some(t => t.kind === "pomodoro"), JSON.stringify(Timers.items));
                root.ok("pomodoro-on", B.on("pomodoro"), "");
                // a second press stops it instead of starting another
                B.run("pomodoro");
                root.ok("pomodoro-toggles-off", !B.on("pomodoro") && !Timers.items.some(t => t.kind === "pomodoro") && Timers.items.some(t => t.kind === "timer"), JSON.stringify(Timers.items));
                root.ok("note-on-shelf", Shelf.items.some(i => i.kind === "text" && i.text === "купить молоко"), JSON.stringify(Shelf.items));
                // the grid: small a, b, c then wide W (no room) — d fills the hole, W opens the next row
                const g = B.pack([{"id": "a"}, {"id": "b"}, {"id": "c"}, {"id": "W", "wide": true}, {"id": "d"}, {"id": "V", "wide": true}], 4).map(p => p.b.id + "@" + p.row + "," + p.col).join(" ");
                root.ok("pack", g === "a@0,0 b@0,1 c@0,2 d@0,3 W@1,0 V@1,2", g);
                console.log("TEST DONE");
                Qt.quit();
            }
        }
    }
}
