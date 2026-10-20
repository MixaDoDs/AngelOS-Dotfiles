pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import qs.config
import qs.services
import qs.modules.session

// Logging out, restarting and shutting down ask first (tests/session/run.sh, offscreen): the
// session menu by a click, by its letters, by the arrows and Enter, and Start's own buttons all
// open the one confirmation (modules/session/SessionConfirm); only its yes does it; Esc, Cancel
// and a click beside it drop it; a second ask replaces the first (one dialog, Cancel picked
// again); a held key's repeats and a yes in the first moments do nothing; Lock and Sleep never
// ask. Nothing ends: Shell.sessionNow only writes the action down under ANGELOS_TEST, and run.sh
// puts stand-ins for systemctl, loginctl and niri first on the PATH.
Scope {
    id: root

    property int failures: 0
    property int at: 0
    property double since: 0
    property bool acted: false
    property bool busy: false
    function report(name, ok, detail) {
        if (!ok)
            failures++;
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + (detail ? " " + detail : ""));
    }

    SessionMenu {
        id: menu
    }
    SessionConfirm {
        id: confirmWin
    }

    function find(item, test) {
        if (!item)
            return null;
        if (test(item))
            return item;
        for (const c of item.children) {
            const f = find(c, test);
            if (f)
                return f;
        }
        return null;
    }
    readonly property var card: find(confirmWin.contentItem, it => it.grace !== undefined && typeof it.confirm === "function")
    function menuButton(i) {
        const all = [];
        const walk = it => {
            if (it.danger !== undefined && it.checked !== undefined && it.modelData !== undefined)
                all.push(it);
            for (const c of it.children)
                walk(c);
        };
        walk(menu.contentItem);
        return all[i];
    }
    function cardButton(i) {
        const all = [];
        const walk = it => {
            if (it.danger !== undefined && it.checked !== undefined)
                all.push(it);
            for (const c of it.children)
                walk(c);
        };
        walk(card);
        return all[i];
    }
    function keysTo(win, key) {
        const ev = Qt.createQmlObject("import QtTest; TestEvent {}", win.contentItem);
        ev.keyClick(key, Qt.NoModifier, -1);
        ev.destroy();
    }
    function click(item) {
        const ev = Qt.createQmlObject("import QtTest; TestEvent {}", item);
        ev.mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
        ev.destroy();
    }
    function state() {
        return "ask=" + (Shell.sessionConfirm || "-") + " menu=" + Shell.sessionOpen + " ran=" + (Shell.sessionRan.join(",") || "-") + " dialog=" + confirmWin.visible;
    }
    function reset() {
        Shell.sessionConfirm = "";
        Shell.sessionOpen = false;
        Shell.sessionRan = [];
    }
    // asked, nothing done yet
    function asking(id) {
        return Shell.sessionConfirm === id && confirmWin.visible && !Shell.sessionOpen && Shell.sessionRan.length === 0 && card.current === 0;
    }
    // the card past its first moments (Enter there says yes only then)
    function settled() {
        return card && card.ready;
    }

    // a way in: open the menu (or not), pick, check the question; then cancel or say yes
    function askStep(name, id, how) {
        return [
            {
                "act": () => {
                    reset();
                    if (how !== "start")
                        Shell.sessionOpen = true;
                },
                "until": () => how === "start" || menu.visible,
                "check": () => {}
            },
            {
                "act": () => {
                    const i = menu.actions.findIndex(a => a.id === id);
                    if (how === "mouse")
                        click(menuButton(i));
                    else if (how === "letter")
                        keysTo(menu, Qt.Key_A + menu.actions[i].key.charCodeAt(0) - 65);
                    else if (how === "arrows") {
                        for (let k = 0; k < i; k++)
                            keysTo(menu, Qt.Key_Right);
                        keysTo(menu, Qt.Key_Return);
                    } else
                        StartItems.buttons[id].run();
                },
                "until": () => asking(id),
                "check": () => report(name + "-asks", asking(id), state())
            }
        ];
    }

    readonly property var steps: [].concat([
            {
                "act": () => {},
                "until": () => Config.ready && !!root.card,
                "check": () => report("ready", !!root.card && !!menuButton(4), "card " + !!root.card + ", menu buttons " + !!menuButton(4))
            }
        ],
        // every way in asks, Esc / Cancel / a click beside the card drop it, nothing done
        askStep("mouse-reboot", "reboot", "mouse"), [
            {
                "act": () => keysTo(confirmWin, Qt.Key_Escape),
                "until": () => Shell.sessionConfirm === "",
                "check": () => report("esc-cancels", Shell.sessionConfirm === "" && Shell.sessionRan.length === 0 && !confirmWin.visible, state())
            }
        ], askStep("letter-poweroff", "poweroff", "letter"), [
            {
                "act": () => click(cardButton(0)),
                "until": () => Shell.sessionConfirm === "",
                "check": () => report("cancel-button", Shell.sessionConfirm === "" && Shell.sessionRan.length === 0, state())
            }
        ], askStep("arrows-logout", "logout", "arrows"), [
            {
                "act": () => {
                    const ev = Qt.createQmlObject("import QtTest; TestEvent {}", confirmWin.contentItem);
                    ev.mouseClick(confirmWin.contentItem, 2, 2, Qt.LeftButton, Qt.NoModifier, -1);
                    ev.destroy();
                },
                "until": () => Shell.sessionConfirm === "",
                "check": () => report("click-beside-cancels", Shell.sessionConfirm === "" && Shell.sessionRan.length === 0, state())
            }
        ], askStep("start-reboot", "reboot", "start"), [
            // Enter right away: Cancel is the picked one
            {
                "act": () => keysTo(confirmWin, Qt.Key_Return),
                "until": () => Shell.sessionConfirm === "",
                "check": () => report("enter-default-cancels", Shell.sessionConfirm === "" && Shell.sessionRan.length === 0, state())
            }
        ], askStep("start-logout", "logout", "start"), [
            // a second ask while the first is up: one dialog, the newer question, Cancel again
            {
                "act": () => {
                    card.current = 1;
                    Shell.sessionAction("poweroff");
                },
                "until": () => Shell.sessionConfirm === "poweroff",
                "check": () => report("second-ask-replaces", Shell.sessionConfirm === "poweroff" && card.current === 0 && !card.ready && Shell.sessionRan.length === 0, state() + " picked " + card.current + " ready " + card.ready)
            },
            // the yes in the first moments (a double click, a key still down) does nothing
            {
                "act": () => {
                    card.current = 1;
                    keysTo(confirmWin, Qt.Key_Return);
                },
                "until": () => true,
                "check": () => report("early-yes-ignored", Shell.sessionConfirm === "poweroff" && Shell.sessionRan.length === 0, state())
            },
            // a held key's repeats: nothing either, past the first moments too
            {
                "act": () => {},
                "until": () => settled(),
                "check": () => {
                    card.current = 1;
                    const took = card.key({
                        "key": Qt.Key_Return,
                        "text": "\r",
                        "isAutoRepeat": true
                    });
                    report("repeat-ignored", took && Shell.sessionConfirm === "poweroff" && Shell.sessionRan.length === 0, state());
                }
            },
            // the yes: → to the action, Enter — done once, the dialog gone
            {
                "act": () => {
                    card.current = 0;
                    keysTo(confirmWin, Qt.Key_Right);
                    keysTo(confirmWin, Qt.Key_Return);
                },
                "until": () => Shell.sessionRan.length > 0,
                "check": () => report("yes-runs-once", JSON.stringify(Shell.sessionRan) === "[\"poweroff\"]" && Shell.sessionConfirm === "" && !confirmWin.visible, state())
            }
        ], askStep("mouse-logout", "logout", "mouse"), [
            {
                "act": () => {},
                "until": () => settled(),
                "check": () => {}
            },
            {
                "act": () => click(cardButton(1)),
                "until": () => Shell.sessionRan.length > 0,
                "check": () => report("yes-button-runs", JSON.stringify(Shell.sessionRan) === "[\"logout\"]" && Shell.sessionConfirm === "", state())
            },
            // whatever else opens drops the question (no yes left waiting under it)
            {
                "act": () => {
                    reset();
                    Shell.sessionAction("reboot");
                    Shell.launcherOpen = true;
                },
                "until": () => Shell.sessionConfirm === "",
                "check": () => {
                    report("other-window-drops", Shell.sessionConfirm === "" && Shell.sessionRan.length === 0, state());
                    Shell.launcherOpen = false;
                }
            },
            // Sleep and Lock never ask (the dev stand only plays the sleep's fade)
            {
                "act": () => {
                    reset();
                    Shell.sessionOpen = true;
                },
                "until": () => menu.visible,
                "check": () => {}
            },
            {
                "act": () => keysTo(menu, Qt.Key_S),
                "until": () => Shell.sleepFx,
                "check": () => report("sleep-no-ask", Shell.sleepFx && Shell.sessionConfirm === "" && !confirmWin.visible, state() + " sleepFx " + Shell.sleepFx)
            },
            {
                "act": () => {
                    Shell.sleepFx = false;
                    Shell.sessionAction("lock");
                },
                "until": () => Shell.locked,
                "check": () => report("lock-no-ask", Shell.locked && Shell.sessionConfirm === "" && !confirmWin.visible, state() + " locked " + Shell.locked)
            },
            // locked: no question opens over the lock
            {
                "act": () => StartItems.buttons.reboot.run(),
                "until": () => true,
                "check": () => report("locked-no-ask", Shell.sessionConfirm === "" && Shell.sessionRan.length === 0, state())
            }
        ])

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            if (root.busy)
                return;
            const s = root.steps[root.at];
            if (!s) {
                stop();
                console.log("TEST DONE " + root.failures);
                Qt.quit();
                return;
            }
            root.busy = true;
            if (!root.acted) {
                try {
                    s.act();
                } catch (e) {
                    root.report("act-" + root.at, false, String(e));
                }
                root.acted = true;
                root.since = Date.now();
                root.busy = false;
                return;
            }
            let ok = false;
            try {
                ok = !!s.until();
            } catch (e) {}
            if (!ok && Date.now() - root.since < (root.at === 0 ? 60000 : 5000)) {
                root.busy = false;
                return;
            }
            try {
                s.check();
            } catch (e) {
                root.report("step-" + root.at, false, String(e));
            }
            root.at++;
            root.acted = false;
            root.busy = false;
        }
    }
}
