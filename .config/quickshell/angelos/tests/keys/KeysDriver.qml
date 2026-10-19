import QtQuick
import Quickshell
import qs.config
import qs.services

// tests/keys/run.sh: the screenshot's IPC and the desktop menus' old "circle", step by step;
// the stand-ins (grim, niri, the old selector) write what they were asked into FAKE_DIR/calls
Scope {
    id: drv
    required property var ipc
    property int step: 0
    readonly property string fake: Quickshell.env("FAKE_DIR")
    // offscreen has one nameless screen: a named one that isn't there reaches the overlay
    // (its screenName) and goes no further
    readonly property string screen: "TEST-1"

    function calls() {
        const x = new XMLHttpRequest();
        x.open("GET", "file://" + fake + "/calls", false);
        try {
            x.send();
        } catch (e) {
            return [];
        }
        return (x.responseText || "").split("\n").filter(l => l !== "");
    }
    function grims() {
        return calls().filter(l => l.startsWith("grim "));
    }
    // what the shell asked the overlay's process, taken (so its 3 s fallback stays quiet)
    function asked() {
        const p = CircleHost.pending;
        CircleHost.pending = null;
        return p;
    }
    function check(name, ok, detail) {
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + " " + (detail || ""));
    }

    Timer {
        interval: 300
        running: true
        repeat: true
        onTriggered: {
            drv.step++;
            const s = drv.step;
            if (s === 1) {
                const c = DeskMenu.canon(["circle", "screenshot", "sep", "terminal", "sep", "circle"]);
                drv.check("menu-circle-is-screenshot", JSON.stringify(c) === '["screenshot","sep","terminal","sep"]', JSON.stringify(c));
                Config.desktop.menuQuick = ["terminal", "circle"];
                Config.desktop.menuItems = ["circle", "sep", "more"];
                drv.check("menu-catalog-no-circle", DeskMenu.catalog.indexOf("circle") < 0 && DeskMenu.catalog.indexOf("screenshot") >= 0, "");
                drv.check("menu-old-entry-label", DeskMenu.entry("circle").label === "Скриншот" && DeskMenu.entry("screenshot").label === "Скриншот", DeskMenu.entry("circle").label);
            }
            if (s === 2) {
                drv.check("menu-quick", JSON.stringify(DeskMenu.quick) === '["terminal","screenshot"]', JSON.stringify(DeskMenu.quick));
                drv.check("menu-items", JSON.stringify(DeskMenu.items) === '["screenshot","sep","more"]', JSON.stringify(DeskMenu.items));
                // the overlay runs in its own process (services/CircleHost), not started under
                // ANGELOS_TEST: what the shell asks of it waits in CircleHost.pending
                drv.ipc.capture();
                const p = drv.asked();
                drv.check("capture-asks-overlay", !!p && p.t === "toggle" && drv.grims().length === 0, JSON.stringify(p) + " " + JSON.stringify(drv.calls()));
                drv.ipc.captureOn(drv.screen);
                const q = drv.asked();
                drv.check("captureOn-screen", !!q && q.screen === "TEST-1", JSON.stringify(q));
                drv.ipc.circle();
                const r = drv.asked();
                drv.check("circle-old-name", !!r && r.t === "toggle" && r.screen !== "TEST-1", JSON.stringify(r));
                drv.ipc.circleOn(drv.screen);
                const u = drv.asked();
                drv.check("circleOn-old-name", !!u && u.screen === "TEST-1", JSON.stringify(u));
                Config.capture.classic = true;
                drv.ipc.captureOn("");
                drv.check("classic-asks-nothing", !CircleHost.pending, JSON.stringify(CircleHost.pending));
            }
            if (s === 6) {
                const c = drv.calls();
                drv.check("classic-old-selector", c.filter(l => l.startsWith("old-selector")).length === 1 && drv.grims().length === 0, JSON.stringify(c.filter(l => !l.startsWith("niri msg --json"))));
                Config.capture.classic = false;
                Shell.setupOpen = true;
                drv.ipc.capture();
                drv.ipc.captureOn("TEST-2");
                drv.check("setup-locked-nothing", !CircleHost.pending, JSON.stringify(CircleHost.pending));
                Shell.setupOpen = false;
                // no process within 3 s: the classic selector takes the shot
                drv.ipc.capture();
            }
            if (s === 19) {
                const c = drv.calls();
                drv.check("no-process-old-selector", c.filter(l => l.startsWith("old-selector")).length === 2 && !CircleHost.pending, JSON.stringify(c.filter(l => !l.startsWith("niri msg --json"))));
                console.log("TEST DONE");
                Qt.quit();
            }
        }
    }
}
