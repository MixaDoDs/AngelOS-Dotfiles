pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.modules.lock

// tests/lock/run.sh: the lock screen in an offscreen window, with a stand-in for Lock.qml's
// scope (no PAM, no session lock). Both looks type, fail and unlock; the stream's audience
// follows the days; the replay plays; each unlock style is drawn halfway over a desktop.
Scope {
    id: root

    readonly property string shots: Quickshell.env("ANGELOS_TEST_SHOTS") || ""
    property int failures: 0
    property var steps: []
    property int stepAt: 0
    property var grab: null
    property var revealGrabs: []

    function report(name, ok, detail) {
        if (!ok)
            failures++;
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + " " + (detail || ""));
    }
    function shot(name) {
        if (!shots)
            return;
        stage.grabToImage(r => r.saveToFile(shots + "/" + name + ".png"));
    }
    function find(item, name) {
        if (!item)
            return null;
        if (item.objectName === name)
            return item;
        const kids = item.children || [];
        for (let i = 0; i < kids.length; i++) {
            const f = find(kids[i], name);
            if (f)
                return f;
        }
        return null;
    }

    // the scope LockScreen talks to (Lock.qml's API, minus PAM)
    QtObject {
        id: scope
        property string status: ""
        property bool busy: unlocking
        property int fails: 0
        property bool unlocking: false
        property real lockedAt: Date.now()
        property bool caps: false
        property bool wantFail: true
        property int hold: 0
        property var claimed: null
        property var wished: null
        function hurry() {
        }
        property int shakes: 0
        property int successes: 0
        readonly property string look: Config.lock.style === "heaven" ? "heaven" : "ngo"
        readonly property string fx: look === "heaven" ? "gate" : "heart"
        signal shake
        signal success
        signal typed(int length, bool added)
        signal demo(string text)
        signal captureNow
        function submit(pw) {
            if (wantFail || pw === "") {
                fails++;
                shakes++;
                status = "wrong";
                shake();
            } else {
                status = "";
                successes++;
                unlocking = true;
                hold = 0;
                wished = HeavenStars.pull(true);
                success();
            }
        }
        function captured(name, result, origin) {
            root.grab = result;
        }
    }

    FloatingWindow {
        id: win
        implicitWidth: 1920
        implicitHeight: 1080
        // niri keeps "angelOS [dev]" windows on the side monitor, out of the screencast
        title: "angelOS [dev] lock test"
        color: "black"
        Item {
            id: stage
            // the size of a screen, whatever size the window got
            width: 1920
            height: 1080
            // a stand-in desktop for the unlock styles
            Grid {
                anchors.fill: parent
                columns: 16
                Repeater {
                    model: 16 * 9
                    Rectangle {
                        required property int index
                        width: 120
                        height: 120
                        color: (index + Math.floor(index / 16)) % 2 ? "#4a7a5a" : "#6aa07a"
                    }
                }
            }
            Loader {
                id: lock
                anchors.fill: parent
                active: false
                sourceComponent: LockScreen {
                    screenName: "TEST-1"
                    primary: true
                    lockScope: scope
                    preview: true
                }
            }
            UnlockReveal {
                id: reveal
                anchors.fill: parent
                visible: false
            }
        }
    }

    function run(list) {
        steps = list;
        stepAt = 0;
        next.interval = Math.max(1, list[0][0]);
        next.restart();
    }
    Timer {
        id: next
        onTriggered: {
            if (root.stepAt >= root.steps.length)
                return;
            const [wait, fn] = root.steps[root.stepAt++];
            fn();
            if (root.stepAt < root.steps.length) {
                interval = Math.max(1, root.steps[root.stepAt][0]);
                restart();
            }
        }
    }

    Component.onCompleted: {
        // the audience: day 1 nobody (a 1 or a 2 slips in), day 30 about 1000–1500
        let d1 = 0, d30min = 1e9, d30max = 0, d7 = 0;
        for (let i = 0; i < 300; i++) {
            d1 = Math.max(d1, LockStream.rollViewers(1));
            const v = LockStream.rollViewers(30);
            d30min = Math.min(d30min, v);
            d30max = Math.max(d30max, v);
            d7 += LockStream.rollViewers(7) / 300;
        }
        report("viewers-day1", d1 <= 2, "max " + d1);
        report("viewers-day30", d30min >= 1000 && d30max <= 1500, d30min + "…" + d30max);
        report("viewers-grow", d7 > 3 && d7 < d30min, "day 7 ≈ " + Math.round(d7));

        const typed = [];
        scope.typed.connect((n, added) => typed.push(n));
        // the stream day's file (or its absence) has been read before the days are set
        run([[1500, () => {
                    Config.lock.style = "ngo";
                    LockStream.days = 30;
                    scope.lockedAt = Date.now();
                    lock.active = true;
                }], [1800, () => root.shot("ngo-idle")], [10, () => scope.demo("hunter22")], [420, () => root.shot("ngo-typing")], [380, () => root.shot("ngo-fail")], [900, () => {
                    report("ngo-typing", typed.length >= 8 && typed[7] === 8, "lengths " + typed.join(","));
                    report("ngo-fail", scope.shakes === 1, "shakes " + scope.shakes);
                    // a long password: the hearts shrink, nothing is cut
                    scope.demo("x".repeat(40));
                }], [3300, () => {
                    const f = root.find(lock.item, "heartPassword");
                    report("long-password", !!f && f.count >= 36 && f.fits, f ? f.count + " typed, caret " + Math.round(f.caretX) + " of " + Math.round(f.width) : "no field");
                    root.shot("ngo-long");
                }], [900, () => {
                    // on air for a minute: the replay comes
                    scope.lockedAt = Date.now() - 60000;
                }], [4500, () => {
                    const r = root.find(lock.item, "replayFeed");
                    const hasVideo = r && r.file !== "";
                    report("replay", !!r && (r.showing || !hasVideo), r ? (hasVideo ? "showing " + r.showing + " opacity " + r.opacity.toFixed(2) : "no test video (ffmpeg missing)") : "no ReplayFeed");
                    root.shot("ngo-replay");
                    scope.wantFail = false;
                    scope.demo("angel");
                }], [560, () => root.shot("ngo-success")], [700, () => root.shot("ngo-gacha")], [10, () => scope.captureNow()], [400, () => {
                    report("capture", root.grab !== null && String(root.grab.url) !== "", root.grab ? String(root.grab.url) : "no grab");
                    lock.active = false;
                    // the unlock styles, halfway, over the stand-in desktop
                    reveal.shot = root.grab ? root.grab.url : "";
                    reveal.origin = Qt.point(0.5, 0.62);
                    reveal.visible = true;
                }], ...[].concat(...["heart", "pixels", "crt", "gate", "glitch"].map(s => [[30, () => {
                            reveal.style = s;
                            reveal.progress = 0.3;
                        }], [120, () => root.shot("reveal-" + s + "-30")], [10, () => reveal.progress = 0.62], [120, () => root.shot("reveal-" + s + "-62")]])), [30, () => {
                    reveal.visible = false;
                    scope.unlocking = false;
                    scope.wantFail = true;
                    scope.fails = 0;
                    scope.status = "";
                    LockStream.days = 1;
                    // a skin from the prayers on the angel by the gate
                    HeavenStars.owned = {
                        "skins": ["moon", "mint", "gold"],
                        "cards": {},
                        "frames": ["holo"],
                        "rows": []
                    };
                    Config.y2k.angelSkin = "moon";
                    Config.lock.frame = "holo";
                    Config.appearance.mode = "light";
                    Config.lock.style = "heaven";
                    scope.lockedAt = Date.now();
                    lock.active = true;
                }], [1800, () => root.shot("heaven-idle")], [10, () => scope.demo("abcdef")], [330, () => root.shot("heaven-typing")], [330, () => root.shot("heaven-fail")], [1400, () => {
                    report("heaven-fail", scope.shakes === 3, "shakes " + scope.shakes);
                    report("skin", HeavenStars.worn !== null && HeavenStars.worn.id === "moon", HeavenStars.worn ? HeavenStars.worn.id : "none");
                    Config.appearance.mode = "dark";
                }], [1200, () => {
                    root.shot("heaven-dark");
                    scope.wantFail = false;
                    scope.demo("angel");
                }], [900, () => root.shot("heaven-wish")], [700, () => root.shot("heaven-wish-2")], [900, () => root.shot("heaven-open")], [400, () => {
                    report("heaven-unlock", scope.successes === 2, "successes " + scope.successes);
                    Config.lock.style = "ngo";
                    lock.active = false;
                    scope.unlocking = false;
                    scope.lockedAt = Date.now();
                    lock.active = true;
                }], [1500, () => root.shot("ngo-day1")], [100, () => {
                    console.log("TEST DONE " + root.failures);
                    Qt.callLater(Qt.quit);
                }]]);
    }
    Timer {
        interval: 115000
        running: true
        onTriggered: {
            root.report("timeout", false, "step " + root.stepAt);
            Qt.quit();
        }
    }
}
