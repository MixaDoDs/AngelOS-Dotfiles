pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.modules.lenssearch

// tests/lens/run.sh, offscreen: the Lens window through every state the worker can report
// (services/LensSearch.handle — no worker, no Google): sending, consent, captcha, results with
// the similar pictures, the exact matches' tab, the text tab, nothing found, a page it couldn't
// read; Escape closes it. ANGELOS_LENS_SHOTS=dir: a picture of each state.
Scope {
    id: root

    property int step: 0
    readonly property string shots: Quickshell.env("ANGELOS_LENS_SHOTS") || ""

    function report(name, ok, detail) {
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + " " + (detail || ""));
    }
    // every text shown in the window
    function texts() {
        const out = [];
        const walk = it => {
            if (!it || it.visible === false)
                return;
            if (typeof it.text === "string" && it.text !== "" && it.opacity !== 0)
                out.push(it.text);
            for (const c of it.children || [])
                walk(c);
        };
        if (lw.window)
            walk(lw.window.contentItem);
        return out;
    }
    function shows(s) {
        return texts().some(t => t.indexOf(s) >= 0);
    }
    // the item holding the tab (the window's own "view")
    function view() {
        let found = null;
        const walk = it => {
            if (!it || found)
                return;
            if (it.tab !== undefined && it.done !== undefined)
                found = it;
            for (const c of it.children || [])
                walk(c);
        };
        if (lw.window)
            walk(lw.window.contentItem);
        return found;
    }
    // then: what comes next, once the picture is taken (offscreen it is drawn a frame later)
    property bool busy: false
    function shot(name, then) {
        // (the window's own content item has no engine to grab with: its first item does)
        const v = view();
        if (!shots || !v) {
            if (then)
                then();
            return;
        }
        busy = true;
        v.grabToImage(r => {
            r.saveToFile(shots + "/" + name + ".png");
            busy = false;
            if (then)
                then();
        });
    }

    readonly property var results: ({
            "ev": "results",
            "verdict": "ok",
            "resultsUrl": "https://www.google.com/search?vsrid=1&udm=26",
            "visual": [
                {
                    "title": "Flag of Germany - Wikipedia",
                    "site": "Wikipedia",
                    "url": "https://www.google.com/goto?url=OPAQUE1",
                    "thumb": "",
                    "favicon": "",
                    "price": "",
                    "extra": ""
                },
                {
                    "title": "Deutschland Fahne 90x150",
                    "site": "Shop.example",
                    "url": "https://shop.example/flag",
                    "thumb": "",
                    "favicon": "",
                    "price": "92 €*",
                    "extra": "Auf Lager"
                }
            ],
            "words": ["Hello world", "second line"],
            "entity": {
                "name": "Flag of Germany",
                "description": "The image shows the national flag of Germany, a tricolour of black, red and gold."
            },
            "translate": true,
            "exactTab": true,
            "counts": {
                "cards": 2
            }
        })

    LensWindow {
        id: lw
    }

    Timer {
        interval: 400
        running: true
        repeat: true
        onTriggered: {
            if (root.busy)
                return;
            root.step++;
            const s = root.step, L = LensSearch;
            if (s === 1) {
                L.open = true;
                L.status = "sending";
            } else if (s === 3) {
                root.report("sending", !!lw.window && root.shows("Ищу по картинке"), JSON.stringify(root.texts().slice(0, 8)));
                root.shot("sending", () => {
                    L.handle({
                        "ev": "consent",
                        "url": "https://consent.google.com/m"
                    });
                });
            } else if (s === 5) {
                root.report("consent", L.status === "consent" && root.shows("cookies") && root.shows("Открыть страницу Google"), JSON.stringify(root.texts().slice(0, 12)));
                root.shot("consent", () => {
                    L.handle({
                        "ev": "consent-done"
                    });
                });
            } else if (s === 6) {
                root.report("consent-done-resends", L.status === "sending", L.status);
                L.handle({
                    "ev": "captcha",
                    "url": "https://www.google.com/sorry/index"
                });
            } else if (s === 8) {
                root.report("captcha", L.status === "captcha" && root.shows("капчу") && L.captchaPause(), JSON.stringify(root.texts().slice(0, 12)));
                root.shot("captcha", () => {
                    L.captchaAt = 0;
                    L.handle(root.results);
                });
            } else if (s === 10) {
                const v = root.view();
                root.report("results", L.status === "results" && !!v && v.tab === "visual" && root.shows("Flag of Germany - Wikipedia") && root.shows("Deutschland Fahne 90x150") && root.shows("92 €*") && root.shows("Shop.example"), JSON.stringify(root.texts().slice(0, 20)));
                root.report("results-entity", root.shows("Flag of Germany") && root.shows("national flag of Germany"), "");
                root.shot("results", () => {
                    v.tab = "exact";
                    L.handle({
                        "ev": "exact",
                        "exact": [
                            {
                                "title": "Black red gold flag",
                                "site": "example.org",
                                "url": "https://www.google.com/goto?url=E1",
                                "thumb": "",
                                "favicon": "",
                                "price": "",
                                "extra": "1.280 x 1.280 · 12 Mar 2024"
                            }
                        ]
                    });
                });
            } else if (s === 12) {
                root.report("exact", L.exactState === "done" && root.shows("Black red gold flag") && root.shows("1.280 x 1.280"), JSON.stringify(root.texts().slice(0, 20)));
                root.shot("exact", () => {
                    root.view().tab = "text";
                });
            } else if (s === 14) {
                root.report("text", root.shows("Hello world") && root.shows("second line"), JSON.stringify(root.texts().slice(0, 20)));
                root.shot("text", () => {
                    L.reset();
                    L.status = "sending";
                    L.handle({
                        "ev": "results",
                        "verdict": "empty",
                        "visual": [],
                        "words": [],
                        "entity": {
                            "name": "",
                            "description": ""
                        },
                        "counts": {}
                    });
                });
            } else if (s === 16) {
                root.report("empty", L.status === "empty" && root.shows("Ничего не нашлось"), JSON.stringify(root.texts().slice(0, 12)));
                root.shot("empty", () => {
                    L.handle({
                        "ev": "results",
                        "verdict": "broken",
                        "visual": [],
                        "words": [],
                        "entity": {
                            "name": "",
                            "description": ""
                        },
                        "counts": {
                            "goto": 9
                        }
                    });
                });
            } else if (s === 18) {
                root.report("broken", L.status === "error" && L.error === "broken" && root.shows("Не смог прочитать страницу") && root.shows("Показать страницу Google"), JSON.stringify(root.texts().slice(0, 12)));
                root.shot("broken", () => {
                    L.close();
                });
            } else if (s === 20) {
                root.report("closed", !L.open && !lw.window, "");
                console.log("TEST DONE");
                Qt.quit();
            }
        }
    }
}
