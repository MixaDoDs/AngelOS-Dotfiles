pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.modules.streamchat

// tests/streamchat/run.sh, offscreen: a chat reader's session log (FAKE_DIR, written here line by
// line) through services/StreamChat — the Halo's capsule, a paid message, a regular, the cats'
// queue at the bottom (six at a time, the rest after), their switch. ANGELOS_CHAT_SHOTS=dir: the
// running cats in a picture.
Scope {
    id: root

    property int step: 0
    property double since: Date.now()
    readonly property string dir: Quickshell.env("ANGELOS_CHAT_DIR")
    readonly property string shots: Quickshell.env("ANGELOS_CHAT_SHOTS") || ""
    property var got: []

    function report(name, ok, detail) {
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + " " + (detail || ""));
    }
    function next() {
        step++;
        since = Date.now();
    }
    function until(name, cond, ms, detail) {
        const ok = !!cond();
        if (!ok && Date.now() - since < (ms || 6000))
            return false;
        report(name, ok, detail ? detail() : "");
        next();
        return true;
    }
    // a line into the session log, as the chat reader writes it
    function say(author, text, amount) {
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" >>"$2"', "sh", JSON.stringify({
                "event": "chat",
                "author": author,
                "text": text || "",
                "kind": "text",
                "amount": amount || "",
                "owner": false
            }), dir + "/2026-10-20_2100.jsonl"]);
    }
    function chatItem() {
        return Halo.items.find(i => i.kind === "chat") || null;
    }

    Connections {
        target: StreamChat
        function onMessage(m) {
            root.got = root.got.concat([m]);
        }
    }
    // the running cats as the bottom strip draws them (its PanelWindow needs a compositor)
    FloatingWindow {
        id: strip
        implicitWidth: 900
        implicitHeight: 90
        color: Theme.shadow
        Row {
            id: lane
            x: 8
            y: 8
            spacing: 16
            Repeater {
                model: StreamChat.runners
                ChatRunner {
                    still: true
                    x: 0
                }
            }
        }
    }

    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            const s = root.step;
            if (s === 0) {
                // the Halo is there from the start in the shell (singletons come when first asked)
                void Halo.items;
                // the follower starts at the end of the log: what it said before is not replayed
                if (Date.now() - root.since < 1500)
                    return;
                root.say("@viewer", "привет с https://spam.example/x стрима");
                root.next();
            } else if (s === 1) {
                root.until("message", () => root.got.length === 1 && root.got[0].author === "@viewer" && root.got[0].text === "привет с … стрима" && !root.got[0].regular, 6000, () => JSON.stringify(root.got));
            } else if (s === 2) {
                root.until("halo-capsule", () => {
                    const c = root.chatItem();
                    return !!c && c.author === "@viewer" && c.text.indexOf("привет") === 0;
                }, 3000, () => JSON.stringify(Halo.items.map(i => i.kind)));
                if (root.step === 3)
                    root.say("@regular", "", "€5.00");
            } else if (s === 3) {
                root.until("paid-regular", () => {
                    const c = root.chatItem();
                    return root.got.length === 2 && !!c && c.author === "@regular" && c.amount === "€5.00" && c.regular === true;
                }, 6000, () => JSON.stringify(root.got[1] || null) + " " + JSON.stringify(root.chatItem()));
                if (root.step === 4)
                    for (let i = 0; i < 6; i++)
                        root.say("@crowd" + i, "go " + i);
            } else if (s === 4) {
                root.until("queue", () => root.got.length === 8 && StreamChat.runners.length === 6 && StreamChat.waiting.length === 2, 6000, () => StreamChat.runners.length + " running, " + StreamChat.waiting.length + " waiting, " + root.got.length + " got");
                if (root.step === 5 && root.shots)
                    root.shotAt = Date.now() + 500;
            } else if (s === 5) {
                if (root.shots && Date.now() < root.shotAt)
                    return;
                if (root.shots && !root.shotTaken) {
                    root.shotTaken = true;
                    root.grabRunners();
                }
                // the first ones finish their run (9 s), the waiting two set off
                root.until("queue-moves", () => StreamChat.waiting.length === 0 && StreamChat.runners.some(r => r.author === "@crowd5"), 14000, () => StreamChat.runners.length + " running, " + StreamChat.waiting.length + " waiting");
                if (root.step === 6) {
                    Config.stream.chatRunners = false;
                    root.say("@quiet", "no cat for me");
                }
            } else if (s === 6) {
                root.until("runners-off", () => root.got.some(m => m.author === "@quiet") && !StreamChat.runners.some(r => r.author === "@quiet") && !StreamChat.waiting.some(r => r.author === "@quiet"), 6000, () => JSON.stringify(StreamChat.runners.map(r => r.author)));
            } else if (s === 7) {
                console.log("TEST DONE");
                Qt.quit();
            }
        }
    }
    property double shotAt: 0
    property bool shotTaken: false
    function grabRunners() {
        lane.grabToImage(r => r.saveToFile(root.shots + "/runners.png"));
    }
}
