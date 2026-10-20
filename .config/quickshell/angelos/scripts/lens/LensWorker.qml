// Google Lens without Google's page (services/LensSearch, modules/lenssearch): this process
// sends the picture from a hidden QtWebEngine view and reads the results out of the page;
// the shell's own window draws them. Its own process (qml6 + QtWebEngine): Chromium can't live
// in the shell. The island's profile (scripts/island): a consent or a login given there counts.
// Answers: "LENS {json}" lines on stderr — state, consent, consent-done, captcha, results,
// exact, translated, resolved, shown, error. Commands by a little file (as the island): show,
// hide, resend, exact, translate, resolve {url}, reject (the owner's choice only), quit.
// The window stays hidden; it shows Google's page itself only when asked (consent, "the page").
import QtQuick
import QtQuick.Window
import QtWebEngine

Window {
    id: win
    // qml6 LensWorker.qml -- PICTURE CMDFILE [hl=xx] [storage=NAME] [fake=FILE] [dev]
    readonly property var args: {
        const a = Qt.application.arguments;
        return a.slice(a.indexOf("--") + 1);
    }
    function flag(name) {
        const f = args.slice(2).find(a => a.startsWith(name + "="));
        return f ? f.slice(name.length + 1) : "";
    }
    readonly property string picture: args[0] || ""
    readonly property string cmdFile: args[1] || ""
    readonly property string hl: flag("hl")
    // tests use a scratch profile: the island's is the owner's
    readonly property string storage: flag("storage") || "angelos-island"
    readonly property string fake: flag("fake")     // a canned answer instead of Google (dev)
    readonly property bool dev: args.indexOf("dev", 2) >= 2

    width: 960
    height: 640
    visible: false
    color: "#16141c"
    // the island's niri rule places it (a corner, floating; [dev] → the test screen)
    title: dev ? "angelOS · Остров [dev] · Google" : "angelOS · Остров · Google"
    // closed by the user: hidden, the results stay
    onClosing: close => {
        close.accepted = false;
        win.visible = false;
        win.say({
            "ev": "shown",
            "on": false
        });
    }

    function say(o) {
        console.warn("LENS " + JSON.stringify(o));
    }
    function read(path, binary) {
        const x = new XMLHttpRequest();
        x.open("GET", path.startsWith("file:") ? path : "file://" + path, false);
        if (binary)
            x.responseType = "arraybuffer";
        try {
            x.send();
        } catch (e) {
            return null;
        }
        return binary ? x.response : x.responseText;
    }
    function base64(buf) {
        const T = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        const a = new Uint8Array(buf), out = [];
        let i = 0;
        for (; i + 2 < a.length; i += 3) {
            const n = a[i] << 16 | a[i + 1] << 8 | a[i + 2];
            out.push(T[n >> 18 & 63] + T[n >> 12 & 63] + T[n >> 6 & 63] + T[n & 63]);
        }
        if (i < a.length) {
            const n = a[i] << 16 | (i + 1 < a.length ? a[i + 1] << 8 : 0);
            out.push(T[n >> 18 & 63] + T[n >> 12 & 63] + (i + 1 < a.length ? T[n >> 6 & 63] : "=") + "=");
        }
        return out.join("");
    }

    readonly property string pageJs: read(Qt.resolvedUrl("page.js").toString(), false) || ""
    // our script runs in its own JS world: Google's scripts don't see it, it sees the same DOM
    function js(v, call, cb) {
        v.runJavaScript(pageJs + "\n" + call, WebEngineScript.ApplicationWorld, r => {
            let o = null;
            try {
                o = JSON.parse(r);
            } catch (e) {}
            if (cb)
                cb(o);
        });
    }

    // ---- sending: a google.com page carries the form (same-site: the consent cookie goes with it)
    property string phase: ""          // carrier | upload | results | consent | captcha | done | error
    property string b64: ""
    property string mime: "image/png"
    property int lost: 0               // the picture lost on the way: sent again once
    property string resultsUrl: ""
    property string consentUrl: ""
    property var first: null           // the "All" page's reading, when the visual tab is tried after it
    property bool triedVisual: false
    function start() {
        if (!b64) {
            const buf = read(picture, true);
            if (!buf || !buf.byteLength) {
                fail("picture");
                return;
            }
            b64 = base64(buf);
            mime = /\.jpe?g$/i.test(picture) ? "image/jpeg" : /\.webp$/i.test(picture) ? "image/webp" : "image/png";
        }
        phase = "carrier";
        first = null;
        triedVisual = false;
        resultsUrl = "";
        say({
            "ev": "state",
            "state": "sending"
        });
        guard.restart();
        view.url = "https://www.google.com/robots.txt";
    }
    function upload() {
        phase = "upload";
        const url = "https://lens.google.com/v3/upload?ep=ccm&st=" + Date.now() + (hl ? "&hl=" + hl : "");
        js(view, "__aosLens.upload(" + JSON.stringify(b64) + "," + JSON.stringify(mime) + "," + JSON.stringify(url) + ")", null);
        guard.restart();    // 10 s to the results' address
    }
    function fail(msg) {
        phase = "error";
        guard.stop();
        poll.stop();
        say({
            "ev": "error",
            "msg": msg,
            "url": view.url.toString()
        });
    }
    Timer {
        id: guard
        interval: 10000
        onTriggered: win.fail("timeout")
    }

    // what the page is, by the main frame's address after each navigation (not by its text)
    function route(u, done) {
        if (/^https:\/\/consent\.google\.[a-z.]+\//.test(u)) {
            if (phase !== "consent") {
                phase = "consent";
                consentUrl = u;
                guard.stop();
                poll.stop();
                say({
                    "ev": "consent",
                    "url": u
                });
            }
            return;
        }
        if (/^https:\/\/(www\.|ipv4\.|ipv6\.)?google\.[a-z.]+\/sorry\//.test(u)) {
            // never again on its own: the human decides (the shell hands the search to the browser)
            phase = "captcha";
            guard.stop();
            poll.stop();
            say({
                "ev": "captcha",
                "url": u
            });
            return;
        }
        if (phase === "consent") {
            // back from consent.google.com: the choice is made; the shell says when to send again
            if (done && /^https:\/\/[a-z.]*google\.[a-z.]+\//.test(u)) {
                phase = "";
                win.visible = false;
                say({
                    "ev": "consent-done"
                });
            }
            return;
        }
        if (phase === "carrier" && done && /^https:\/\/www\.google\.com\/robots\.txt/.test(u)) {
            upload();
            return;
        }
        if (phase !== "upload" && phase !== "results")
            return;
        if (/^https:\/\/www\.google\.[a-z.]+\/search\?/.test(u) && /[?&]vsrid=/.test(u) && /[?&]udm=/.test(u)) {
            if (phase === "upload") {
                phase = "results";
                resultsUrl = u;
                guard.stop();
                watch();
            }
            return;
        }
        // the picture didn't arrive: Google's start page, or the upload address without the post
        if (done && (/^https:\/\/www\.google\.[a-z.]+\/\?(.*&)?olud=/.test(u) || /^https:\/\/lens\.google\.com\/v3\/upload/.test(u))) {
            if (lost < 1) {
                lost++;
                say({
                    "ev": "state",
                    "state": "resending"
                });
                Qt.callLater(start);
            } else
                fail("lost");
        }
    }

    // ---- reading: every 500 ms; ready when the cards (and the AI overview) stop changing for
    // 1 s, or after 8 s; nothing at all after 15 s is an error
    property real since: 0
    property real stableSince: 0
    property int lastCards: -1
    property int lastAi: -1
    function watch() {
        since = Date.now();
        stableSince = since;
        lastCards = -1;
        lastAi = -1;
        poll.restart();
    }
    Timer {
        id: poll
        interval: 500
        repeat: true
        onTriggered: win.js(view, "__aosLens.scan(true)", c => {
            if (!c || win.phase !== "results")
                return;
            const now = Date.now(), t = now - win.since;
            if (c.cards !== win.lastCards || c.ai !== win.lastAi) {
                win.lastCards = c.cards;
                win.lastAi = c.ai;
                win.stableSince = now;
            }
            // Google's "before you continue" over the page itself (no consent.google.com address)
            if (c.consentModal && c.tabs === 0 && t >= 3000) {
                win.phase = "consent";
                win.consentUrl = view.url.toString();
                poll.stop();
                win.say({
                    "ev": "consent",
                    "url": win.consentUrl,
                    "inpage": true
                });
                return;
            }
            const ready = c.cards > 0 && now - win.stableSince >= 1000 && (c.bottom || t >= 4000) || t >= 8000 && (c.cards > 0 || c.tabs > 0);
            if (ready) {
                poll.stop();
                win.finish();
            } else if (t >= 15000) {
                win.fail("timeout");
            }
        })
    }
    function finish() {
        js(view, "__aosLens.results()", o => {
            if (!o) {
                fail("script");
                return;
            }
            // nothing on "All": the visual matches' tab, once
            if (!o.visual.length && o.tabs["44"] && !triedVisual) {
                triedVisual = true;
                first = o;
                view.url = o.tabs["44"];
                watch();
                return;
            }
            const f = first || o, c = o.counts;
            // no cards: "nothing found" or a reader Google's markup broke (the counts tell)
            const verdict = o.visual.length ? "ok" : c.goto > 5 || c.ext > 5 ? "broken" : "empty";
            phase = "done";
            tabsExact = f.tabs["48"] || o.tabs["48"] || "";
            view.runJavaScript("window.scrollTo(0, 0)");
            say({
                "ev": "results",
                "verdict": verdict,
                "resultsUrl": resultsUrl,
                "visual": o.visual,
                "words": f.words.length ? f.words : o.words,
                "entity": f.entity.name || f.entity.description ? f.entity : o.entity,
                "translate": f.translate,
                "exactTab": !!(f.tabs["48"] || o.tabs["48"]),
                "counts": c
            });
        });
    }

    // ---- after the results: the exact matches (their own tab, only when asked), the translation
    // (Google draws it into a picture), a /goto? link resolved in this profile
    property string tabsExact: ""
    function exact() {
        const go = u => {
            if (!u) {
                say({
                    "ev": "exact",
                    "exact": [],
                    "counts": null
                });
                return;
            }
            side.task = "exact";
            side.url = u;
            sidePoll.since = Date.now();
            sidePoll.last = -1;
            sidePoll.stable = Date.now();
        };
        if (tabsExact)
            go(tabsExact);
        else
            js(view, "__aosLens.tabs()", o => {
                tabsExact = o && o["48"] ? o["48"] : "";
                go(tabsExact);
            });
    }
    function translate() {
        js(view, "__aosLens.translate()", o => {
            if (!o || !o.clicked) {
                say({
                    "ev": "translated",
                    "img": ""
                });
                return;
            }
            trPoll.since = Date.now();
            trPoll.restart();
        });
    }
    Timer {
        id: trPoll
        property real since: 0
        interval: 500
        repeat: true
        onTriggered: win.js(view, "__aosLens.translated()", o => {
            if (o && o.img) {
                trPoll.stop();
                win.say({
                    "ev": "translated",
                    "img": o.img
                });
            } else if (Date.now() - trPoll.since > 10000) {
                trPoll.stop();
                win.say({
                    "ev": "translated",
                    "img": ""
                });
            }
        })
    }
    property string resolving: ""
    function resolve(u) {
        // a straight link needs no Google
        if (!/^https:\/\/www\.google\.[a-z.]+\/goto\?/.test(u)) {
            say({
                "ev": "resolved",
                "from": u,
                "url": u
            });
            return;
        }
        resolving = u;
        side.task = "resolve";
        side.url = u;
        resolveGuard.restart();
    }
    Timer {
        id: resolveGuard
        interval: 6000
        onTriggered: {
            win.say({
                "ev": "resolved",
                "from": win.resolving,
                "url": win.resolving
            });
            side.task = "";
            side.stop();
        }
    }
    Timer {
        id: sidePoll
        property real since: 0
        property real stable: 0
        property int last: -1
        interval: 500
        repeat: true
        running: side.task === "exact" && !side.loading && side.url.toString() !== "about:blank"
        onTriggered: win.js(side, "__aosLens.exact()", o => {
            if (!o || side.task !== "exact")
                return;
            const now = Date.now(), n = o.exact.length;
            if (n !== sidePoll.last) {
                sidePoll.last = n;
                sidePoll.stable = now;
            }
            if (n > 0 && now - sidePoll.stable >= 1000 || now - sidePoll.since >= 8000) {
                side.task = "";
                win.say({
                    "ev": "exact",
                    "exact": o.exact,
                    "counts": o.counts
                });
            }
        })
    }

    // ---- commands from the shell (qml6 has no stdin): the file polled at 4 Hz, as the island's
    property int seq: -1
    Timer {
        interval: 250
        running: win.cmdFile !== ""
        repeat: true
        onTriggered: {
            const t = win.read(win.cmdFile, false);
            let c;
            try {
                c = JSON.parse(t);
            } catch (e) {
                return;
            }
            if (!c || typeof c.seq !== "number" || c.seq === win.seq)
                return;
            win.seq = c.seq;
            win.command(c);
        }
    }
    function command(c) {
        if (fake) {
            fakeCommand(c);
            return;
        }
        if (c.cmd === "show") {
            win.visible = true;
            win.raise();
            win.requestActivate();
            say({
                "ev": "shown",
                "on": true
            });
        } else if (c.cmd === "hide") {
            win.visible = false;
        } else if (c.cmd === "resend") {
            lost = 0;
            start();
        } else if (c.cmd === "reject") {
            if (phase === "consent")
                js(view, "__aosLens.reject()", null);
        } else if (c.cmd === "exact") {
            exact();
        } else if (c.cmd === "translate") {
            translate();
        } else if (c.cmd === "resolve") {
            resolve(String(c.url || ""));
        } else if (c.cmd === "quit") {
            Qt.quit();
        }
    }

    // ---- dev: a canned answer (ANGELOS_LENS_FAKE → fake=FILE): no Google, no network
    property var canned: null
    function fakeCommand(c) {
        const k = canned || {};
        if (c.cmd === "quit")
            Qt.quit();
        else if (c.cmd === "exact")
            say({
                "ev": "exact",
                "exact": k.exact || [],
                "counts": null
            });
        else if (c.cmd === "translate")
            say({
                "ev": "translated",
                "img": k.translated || ""
            });
        else if (c.cmd === "resolve")
            say({
                "ev": "resolved",
                "from": c.url,
                "url": c.url
            });
    }
    Timer {
        id: fakeTimer
        interval: 1500
        onTriggered: {
            const k = win.canned;
            if (!k) {
                win.say({
                    "ev": "error",
                    "msg": "fake"
                });
                return;
            }
            const out = Object.assign({}, k);
            delete out.exact;
            delete out.translated;
            out.ev = out.ev || "results";
            win.say(out);
        }
    }

    WebEngineProfilePrototype {
        id: proto
        storageName: win.storage
        persistentCookiesPolicy: WebEngineProfile.AllowPersistentCookies
    }

    // the views get the profile once the prototype is complete: bound in place, instance()
    // runs before storageName is set and hands out an off-the-record profile (nothing kept)
    WebEngineView {
        id: view
        anchors.fill: parent
        onUrlChanged: win.route(url.toString(), false)
        onLoadingChanged: info => {
            if (info.status === WebEngineView.LoadSucceededStatus)
                win.route(info.url.toString(), true);
            else if (info.status === WebEngineView.LoadFailedStatus && info.errorCode !== -3 && (win.phase === "carrier" || win.phase === "upload"))
                win.fail("http " + info.errorCode + " " + info.errorString);
        }
        // a link that wants a new window stays here
        onNewWindowRequested: r => view.url = r.requestedUrl
    }
    WebEngineView {
        id: side
        property string task: ""
        visible: false
        width: 960
        height: 640
        onUrlChanged: {
            const u = url.toString();
            if (task === "resolve" && /^https?:/.test(u) && !/^https:\/\/www\.google\.[a-z.]+\/goto\?/.test(u)) {
                resolveGuard.stop();
                task = "";
                stop();
                win.say({
                    "ev": "resolved",
                    "from": win.resolving,
                    "url": /^https:\/\/www\.google\.[a-z.]+\/sorry\//.test(u) ? win.resolving : u
                });
            }
        }
    }

    Component.onCompleted: {
        if (fake) {
            canned = (() => {
                    try {
                        return JSON.parse(read(fake, false));
                    } catch (e) {
                        return null;
                    }
                })();
            say({
                "ev": "state",
                "state": "sending"
            });
            fakeTimer.start();
            return;
        }
        const p = proto.instance();
        // a plain Chrome of the same Chromium: without the QtWebEngine token
        p.httpUserAgent = p.httpUserAgent.replace(/ QtWebEngine\/\S+/, "");
        if (hl)
            p.httpAcceptLanguage = hl === "en" ? "en-US,en;q=0.9" : hl + "," + hl + "-" + hl.toUpperCase() + ";q=0.9,en;q=0.7";
        view.profile = p;
        side.profile = p;
        start();
    }
}
