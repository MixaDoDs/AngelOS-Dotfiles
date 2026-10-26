import QtQuick
import Quickshell
import qs.config
import qs.services

// tests/island/run.sh: Island.search / Island.lens step by step, the stand-ins' records read back
Scope {
    id: drv
    property int step: 0
    readonly property string fake: Quickshell.env("FAKE_DIR")
    readonly property string rt: Quickshell.env("XDG_RUNTIME_DIR")
    property var cmd1: null

    function read(path) {
        const x = new XMLHttpRequest();
        x.open("GET", "file://" + path, false);
        try {
            x.send();
        } catch (e) {
            return "";
        }
        return x.responseText || "";
    }
    function lines(path) {
        return read(path).split("\n").filter(l => l !== "");
    }
    function cmd() {
        try {
            return JSON.parse(read(rt + "/angelos-island.json"));
        } catch (e) {
            return {};
        }
    }
    function check(name, ok, detail) {
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + " " + (detail || ""));
    }
    readonly property string cat: "%D0%BA%D0%BE%D1%82%20%D0%B2%20%D1%81%D0%B0%D0%BF%D0%BE%D0%B3%D0%B0%D1%85%20%26%20co%3F%23%2B"

    Timer {
        interval: 300
        running: true
        repeat: true
        onTriggered: {
            drv.step++;
            const s = drv.step;
            if (s === 1) {
                const want = {
                    "google": "https://www.google.com/search?q=",
                    "duckduckgo": "https://duckduckgo.com/?q=",
                    "yandex": "https://ya.ru/search/?text=",
                    "ecosia": "https://www.ecosia.org/search?q=",
                    "bing": "https://www.bing.com/search?q=",
                    "brave": "https://search.brave.com/search?q=",
                    "mojeek": "https://www.mojeek.com/search?q="
                };
                const bad = Object.keys(want).filter(e => Island.searchUrl("  кот   в\nсапогах & co?#+ ", e) !== want[e] + drv.cat);
                drv.check("engines", bad.length === 0, "wrong: " + bad.join(","));
                drv.check("unknown-engine-google", Island.searchUrl("a b", "nope") === "https://www.google.com/search?q=a%20b", Island.searchUrl("a b", "nope"));
                Config.circle.engine = "yandex";
                drv.check("engine-from-settings", Island.searchUrl("x") === "https://ya.ru/search/?text=x", Island.searchUrl("x"));
                Config.circle.engine = "google";
                // off: the browser, no island
                Config.island.enabled = false;
                Island.search("кот в сапогах & co?#+");
                Island.search("   ");
            }
            if (s === 4) {
                const x = drv.lines(drv.fake + "/xdg-open");
                drv.check("off-browser", x.length === 1 && x[0] === "https://www.google.com/search?q=" + drv.cat && !Island.running, JSON.stringify(x) + " running " + Island.running);
                drv.check("empty-nothing", x.length === 1, "calls " + x.length);
                Island.lens(drv.fake + "/pic.png");
            }
            if (s === 7) {
                const x = drv.lines(drv.fake + "/xdg-open");
                const page = drv.read(Island.lensFile);
                // the PNG inline, byte for byte: base64 of the stand-in picture
                const b64 = "iVBORw0KGgphbmdlbE9TLWxlbnMtdGVzdAD/";
                drv.check("lens-off-browser", x.length === 2 && x[1] === "file://" + Island.lensFile, JSON.stringify(x));
                drv.check("lens-page", /action="https:\/\/lens\.google\.com\/v3\/upload\?ep=ccm(&amp;hl=\w*)?&amp;st=/.test(page) && page.indexOf('atob("' + b64 + '")') > 0 && page.indexOf('name="encoded_image"') > 0, page.slice(0, 120));
                // on: the island
                Config.island.enabled = true;
                Island.search("привет мир");
            }
            if (s === 10) {
                const a = drv.lines(drv.fake + "/qml6");
                const c = drv.cmd();
                const u = "https://www.google.com/search?q=%D0%BF%D1%80%D0%B8%D0%B2%D0%B5%D1%82%20%D0%BC%D0%B8%D1%80";
                drv.check("on-island", Island.running && a[0].endsWith("scripts/island/Island.qml") && a[1] === "--" && a[2] === u && a[a.length - 1] === "shell-opens", JSON.stringify(a));
                drv.check("on-command", c.cmd === "open" && c.url === u, JSON.stringify(c));
                drv.check("on-no-browser", drv.lines(drv.fake + "/xdg-open").length === 2, "");
                drv.cmd1 = c;
                Island.lens(drv.fake + "/pic.png");
            }
            if (s === 13) {
                const c = drv.cmd();
                drv.check("lens-island", c.cmd === "open" && c.url === "file://" + Island.lensFile && c.seq > drv.cmd1.seq, JSON.stringify(c));
                drv.check("lens-one-island", drv.lines(drv.fake + "/qml6")[2] === drv.cmd1.url, "a second program started");
                Island.open("mail@example.com");
            }
            if (s === 15) {
                const x = drv.lines(drv.fake + "/xdg-open");
                drv.check("mail-to-app", x[x.length - 1] === "mailto:mail@example.com", JSON.stringify(x));
                Island.open("file:///etc/passwd");
            }
            if (s === 17) {
                const x = drv.lines(drv.fake + "/xdg-open");
                drv.check("other-files-not-in-island", x[x.length - 1] === "file:///etc/passwd" && drv.cmd().url === "file://" + Island.lensFile, JSON.stringify(drv.cmd()));
                // ↗ in the island: the page it says goes to the browser (and only a page)
                Quickshell.execDetached(["touch", drv.fake + "/arrow"]);
            }
            if (s === 20) {
                const x = drv.lines(drv.fake + "/xdg-open");
                drv.check("arrow-to-browser", x.length === 5 && x[4] === "https://example.org/now?a=1#b" && drv.cmd().url === "file://" + Island.lensFile, JSON.stringify(x.slice(3)));
                console.log("TEST DONE");
                Qt.quit();
            }
        }
    }
}
