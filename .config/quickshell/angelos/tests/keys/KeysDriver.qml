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
                drv.ipc.capture();
            }
            if (s === 5) {
                const g = drv.grims();
                drv.check("capture-grabs", g.length === 1 && g[0].indexOf(" -o ") > 0 && g[0].indexOf("-t ppm") > 0, JSON.stringify(drv.calls()));
                drv.ipc.captureOn(drv.screen);
            }
            if (s === 8) {
                const g = drv.grims();
                drv.check("captureOn-screen", g.length === 1 && CircleSearch.screenName === "TEST-1", JSON.stringify(g) + " " + CircleSearch.screenName);
                drv.ipc.circle();
            }
            if (s === 11) {
                drv.check("circle-old-name", drv.grims().length === 2 && CircleSearch.screenName !== "TEST-1", JSON.stringify(drv.grims()));
                drv.ipc.circleOn(drv.screen);
            }
            if (s === 14) {
                drv.check("circleOn-old-name", drv.grims().length === 2 && CircleSearch.screenName === "TEST-1", JSON.stringify(drv.grims()) + " " + CircleSearch.screenName);
                Config.capture.classic = true;
                drv.ipc.captureOn("");
            }
            if (s === 18) {
                const c = drv.calls();
                drv.check("classic-old-selector", c.some(l => l.startsWith("old-selector")) && drv.grims().length === 2, JSON.stringify(c.filter(l => !l.startsWith("niri msg --json"))));
                Config.capture.classic = false;
                Shell.setupOpen = true;
                drv.ipc.capture();
                drv.ipc.captureOn("TEST-2");
            }
            if (s === 21) {
                const c = drv.calls();
                drv.check("setup-locked-nothing", drv.grims().length === 2 && CircleSearch.screenName !== "TEST-2" && c.filter(l => l.startsWith("old-selector")).length === 1, JSON.stringify(c.filter(l => !l.startsWith("niri msg --json"))));
                Shell.setupOpen = false;
                console.log("TEST DONE");
                Qt.quit();
            }
        }
    }
}
