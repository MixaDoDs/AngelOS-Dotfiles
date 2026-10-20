pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Google Lens in angelOS's own window (modules/lenssearch): a helper process (scripts/lens,
// qml6 + QtWebEngine, the island's profile) sends the picture from a hidden page and reads the
// results out of it; the window draws them itself. Google's page is always one click away
// (showPage: the same hidden view, shown). Island.lens comes here when Config.circle.lensWindow
// is on. (services/Lens is something else: the magnifier at the pointer.)
Singleton {
    id: root

    property bool open: false
    property string picture: ""
    property string status: ""              // sending | consent | captcha | results | empty | error
    property string error: ""               // with "error": timeout | lost | broken | worker | picture | http …
    property var visual: []                 // [{title, site, url, thumb, favicon, price, extra}]
    property var exact: []
    property string exactState: ""          // "" (not asked) | loading | done
    property bool exactTab: false
    property var words: []                  // the recognised text, a line each
    readonly property string text: words.join("\n")
    property var entity: ({
            "name": "",
            "description": ""
        })
    property string resultsUrl: ""
    property bool canTranslate: false
    property string translated: ""          // Google's translation, drawn into a picture (data:)
    property string translateState: ""      // "" | loading | done | failed
    property bool pageShown: false
    // after a captcha Google is left alone for half an hour: searches go to the browser
    property real captchaAt: 0
    function captchaPause() {
        return captchaAt > 0 && Date.now() - captchaAt < 30 * 60000;
    }

    readonly property bool test: Quickshell.env("ANGELOS_TEST") === "1"
    property var lastCommand: []
    readonly property string cmdFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos-lens.json"
    property int seq: 0
    property string next: ""                // a picture waiting for the last worker to go

    function search(png) {
        if (!png)
            return;
        reset();
        picture = png;
        open = true;
        if (captchaPause()) {
            status = "captcha";
            toBrowser();
            return;
        }
        status = "sending";
        if (proc.running) {
            next = png;
            send({
                "cmd": "quit"
            });
            killer.restart();
            return;
        }
        launch(png);
    }
    function reset() {
        status = "";
        error = "";
        visual = [];
        exact = [];
        exactState = "";
        exactTab = false;
        words = [];
        entity = {
            "name": "",
            "description": ""
        };
        resultsUrl = "";
        canTranslate = false;
        translated = "";
        translateState = "";
        pageShown = false;
    }
    function launch(png) {
        // "start" overwrites a command an earlier worker left (a quit would end this one at once)
        send({
            "cmd": "start"
        });
        const fake = Shell.dev ? Quickshell.env("ANGELOS_LENS_FAKE") || "" : "";
        proc.command = ["qml6", Quickshell.shellPath("scripts/lens/LensWorker.qml"), "--", png, cmdFile, "hl=" + (I18n.english ? "en" : "ru")].concat(fake ? ["fake=" + fake] : [], Shell.dev ? ["dev"] : []);
        // a test never asks Google: it sees what would have run (tests/lens drives the states)
        if (test) {
            lastCommand = proc.command;
            return;
        }
        proc.running = true;
    }
    function close() {
        open = false;
        next = "";
        if (proc.running) {
            send({
                "cmd": "quit"
            });
            killer.restart();
        }
    }
    function retry() {
        if (picture)
            search(picture);
    }
    // the same view with Google's own page, shown (consent, a page the reader couldn't read)
    function showPage() {
        if (proc.running)
            send({
                "cmd": "show"
            });
        else
            toBrowser();
    }
    function loadExact() {
        if (exactState !== "" || !proc.running)
            return;
        exactState = "loading";
        send({
            "cmd": "exact"
        });
    }
    function translate() {
        if (translateState === "loading" || !proc.running)
            return;
        if (translated) {
            translateState = translateState === "done" ? "" : "done";    // a toggle once it is there
            return;
        }
        translateState = "loading";
        send({
            "cmd": "translate"
        });
    }
    // a /goto? link is opened through the worker's profile (its token is Google's), then the
    // real address goes to the island or the browser (Island.open: per its setting)
    function openMatch(url) {
        if (!url)
            return;
        if (/^https:\/\/www\.google\.[a-z.]+\/goto\?/.test(url) && proc.running)
            send({
                "cmd": "resolve",
                "url": url
            });
        else
            Island.open(url);
    }
    function copyText(t) {
        const s = String(t === undefined ? text : t);
        if (s)
            Quickshell.execDetached(["wl-copy", "--type", "text/plain;charset=utf-8", "--", s]);
    }
    // the island's old way, in the default browser: our page posts the picture there (the
    // session here can't go: Google ties its results' address to this profile)
    function toBrowser() {
        if (picture && !reader.running) {
            reader.command = ["base64", "-w0", picture];
            reader.running = true;
        }
    }
    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                if (!/^[A-Za-z0-9+\/=]+$/.test(text))
                    return;
                page.setText(Island.lensPage(text, Date.now(), /\.jpe?g$/i.test(root.picture) ? "image/jpeg" : "image/png"));
                Island.toBrowser("file://" + Island.lensFile);
            }
        }
    }
    FileView {
        id: page
        path: Island.lensFile
        blockWrites: true       // on disk before the browser is told to load it
        blockLoading: false
        printErrors: false
    }

    function send(c) {
        seq++;
        c.seq = seq;
        cmd.setText(JSON.stringify(c));
    }
    FileView {
        id: cmd
        path: root.cmdFile
        blockWrites: true
        blockLoading: false
        printErrors: false
    }
    // a worker that doesn't take its quit (hung page) goes the hard way
    Timer {
        id: killer
        interval: 2500
        onTriggered: proc.running = false
    }

    function handle(ev) {
        if (ev.ev === "state") {
            status = "sending";
        } else if (ev.ev === "consent") {
            status = "consent";
        } else if (ev.ev === "consent-done") {
            // the human has decided on Google's consent page: the picture again (we still have it)
            status = "sending";
            send({
                "cmd": "resend"
            });
        } else if (ev.ev === "captcha") {
            // never again on its own: the same search to the default browser, where the user is known
            captchaAt = Date.now();
            status = "captcha";
            console.warn("LensSearch: captcha", ev.url || "");
            send({
                "cmd": "quit"
            });
            toBrowser();
        } else if (ev.ev === "results") {
            visual = ev.visual || [];
            words = ev.words || [];
            entity = ev.entity || {
                "name": "",
                "description": ""
            };
            resultsUrl = ev.resultsUrl || "";
            canTranslate = !!ev.translate;
            exactTab = !!ev.exactTab;
            // the counts go to the journal: the first sign of Google changing its page
            console.info("LensSearch:", ev.verdict, JSON.stringify(ev.counts || {}));
            if (visual.length || words.length || entity.name || entity.description)
                status = "results";
            else if (ev.verdict === "broken") {
                status = "error";
                error = "broken";
            } else
                status = "empty";
        } else if (ev.ev === "exact") {
            exact = ev.exact || [];
            exactState = "done";
        } else if (ev.ev === "translated") {
            translated = ev.img || "";
            translateState = translated ? "done" : "failed";
        } else if (ev.ev === "resolved") {
            Island.open(ev.url || ev.from);
        } else if (ev.ev === "shown") {
            pageShown = !!ev.on;
        } else if (ev.ev === "error") {
            console.warn("LensSearch: error", ev.msg, ev.url || "");
            status = "error";
            error = String(ev.msg || "");
        }
    }

    Process {
        id: proc
        environment: ({
                "QML_XHR_ALLOW_FILE_READ": "1",
                "QT_FORCE_STDERR_LOGGING": "1"
            })
        stderr: SplitParser {
            onRead: line => {
                const i = line.indexOf("LENS {");
                if (i < 0)
                    return;
                let ev;
                try {
                    ev = JSON.parse(line.slice(i + 5));
                } catch (e) {
                    return;
                }
                root.handle(ev);
            }
        }
        onExited: {
            killer.stop();
            root.pageShown = false;
            if (root.next) {
                const png = root.next;
                root.next = "";
                root.launch(png);
                return;
            }
            // no qml6 or no QtWebEngine, or it fell over before answering
            if (root.open && (root.status === "sending" || root.status === "consent")) {
                root.status = "error";
                root.error = "worker";
            }
        }
    }
}
