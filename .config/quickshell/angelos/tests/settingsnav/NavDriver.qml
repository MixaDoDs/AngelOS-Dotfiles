pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.modules.settings
import qs.modules.bar

// Where Settings land (tests/settingsnav/run.sh, offscreen): an old page id with a group keeps
// its group — in a window built by the opening, in one already open, in one more window, and
// in Golden Gate's tree, where the group waits under «Ещё…» (F01); the bar's «Choose system
// monitor…» lands on the monitor's own row in both trees (F02); «Ещё…» takes the keyboard:
// Tab reaches it, Space and Enter fold it, the focus shows (F03); the search finds the
// notifications' «History (N)» group by its name with no history and with some, in both
// languages (F04). The windows are the real SettingsWindow, hosted here as LazyWindows does.
Scope {
    id: root

    property int failures: 0
    property int at: 0
    property double since: 0
    property bool acted: false
    property bool busy: false               // a check sending keys spins the event loop: no step meanwhile
    function report(name, ok, detail) {
        if (!ok)
            failures++;
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + (detail ? " " + detail : ""));
    }

    // the main window, built when it opens (LazyWindows' settingsLoader)
    LazyLoader {
        active: Shell.settingsOpen
        SettingsWindow {}
    }
    // the other windows (LazyWindows' Instantiator)
    Instantiator {
        id: more
        model: Shell.settingsMore
        delegate: SettingsWindow {
            id: other
            required property int key
            required property string page
            required property string sub
            nav: SettingsNav {
                settingsPage: other.page
                Component.onCompleted: settingsSub = other.sub
            }
        }
    }

    // the bar's own right-click menu (not shown: only its entries are run)
    FloatingWindow {
        visible: false
        implicitWidth: 100
        implicitHeight: 40
        Item {
            id: barSpot
            width: 10
            height: 10
        }
    }
    PanelMenu {
        id: panelMenu
        anchorItem: barSpot
    }
    // an entry of the bar's menu (services/DeskMenu, target "panel"), in its layout or not
    function runPanelEntry(id) {
        const it = DeskMenu.build("panel", id, {
            "screen": ""
        });
        if (it)
            it.run();
        return !!it;
    }

    function viewIn(w) {
        if (!w || !w.contentItem)
            return null;
        for (const c of w.contentItem.children)
            if (c.settingsNav !== undefined)
                return c;
        return null;
    }
    // a group (PxGroup name) shown on the view's page: found visible, the page scrolled to it
    function shown(view, name) {
        const pg = view ? view.pageItem : null;
        if (!pg || !pg.flick)
            return null;
        return view.findItem(pg.flick.contentItem, {
            "kind": "name",
            "target": name
        }, false);
    }
    function rowShown(view, label) {
        const pg = view ? view.pageItem : null;
        return pg && pg.flick ? view.findItem(pg.flick.contentItem, {
            "kind": "row",
            "target": label
        }, false) : null;
    }
    // the search's flash (SettingsView's flashComp) on the item
    function flashed(it) {
        return !!it && Array.from(it.children).some(c => c.z === 100 && c.border && c.border.width > 0);
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
    function where(view) {
        return view ? view.settingsNav.settingsPage + (view.pageItem && view.pageItem.hasMore ? " more " + view.pageItem.moreOpen : "") : "no view";
    }
    function closeAll() {
        Shell.settingsOpen = false;
        while (Shell.settingsMore.count)
            Shell.settingsMore.remove(0);
        for (const k of Object.keys(SettingsTree.moreOpen))
            SettingsTree.setMoreOpen(k, false);
    }
    // the notifications' history (Wellbeing has a «history» group of its own)
    function searchHistory() {
        return SettingsSearch.search(I18n.english ? "History" : "История", 12).find(r => r.kind === "group" && r.page === "notifications" && r.name === "history") || null;
    }

    // each step: act once, then wait for `until` (or 5 s), then check
    readonly property var steps: [
        {
            "name": "ready",
            "act": () => SettingsSearch.load(),
            "until": () => Config.ready && SettingsSearch.loaded && !SettingsSearch.settling && SettingsSearch.entries.length > 0,
            "check": () => report("ready", SettingsSearch.entries.length > 0, SettingsSearch.entries.length + " entries in " + (Date.now() - root.since) + " ms")
        },
        // F01 cold: nothing open, the old id «novel» (→ hell, group y2k/novel under «Ещё…»)
        {
            "act": () => {
                closeAll();
                Shell.openSettings("novel");
            },
            "until": () => !!shown(Shell.settingsView, "novel"),
            "check": () => {
                const v = Shell.settingsView;
                report("f01-cold", Shell.settingsPage === "hell" && !!shown(v, "novel") && v.pageItem.moreOpen, where(v));
            }
        },
        // F01 already open, on another page, «Ещё…» folded again
        {
            "act": () => {
                Shell.openSettings("about");
                SettingsTree.setMoreOpen("hell", false);
            },
            "until": () => Shell.settingsView && Shell.settingsView.pageItem && Shell.settingsPage === "about",
            "check": () => {}
        },
        {
            "act": () => Shell.openSettings("novel"),
            "until": () => !!shown(Shell.settingsView, "novel"),
            "check": () => report("f01-open", Shell.settingsPage === "hell" && !!shown(Shell.settingsView, "novel"), where(Shell.settingsView))
        },
        // F01 a group shown on top of its page (stars → rewards, not under «Ещё…»)
        {
            "act": () => Shell.openSettings("stars"),
            "until": () => !!shown(Shell.settingsView, "stars-wish"),
            "check": () => report("f01-top-group", Shell.settingsPage === "rewards" && !!shown(Shell.settingsView, "stars-wish"), where(Shell.settingsView))
        },
        // F01 one more window
        {
            "act": () => {
                SettingsTree.setMoreOpen("hell", false);
                Shell.newSettingsWindow("novel");
            },
            "until": () => more.count === 1 && !!shown(viewIn(more.objectAt(0)), "novel"),
            "check": () => {
                const v = viewIn(more.objectAt(0));
                report("f01-new-window", !!v && v.settingsNav.settingsPage === "hell" && !!shown(v, "novel") && Shell.settingsPage === "rewards", where(v) + ", main still " + Shell.settingsPage);
            }
        },
        // F02 the bar's «Choose system monitor…» (modules/bar/PanelMenu): the monitor's row
        {
            "act": () => {
                closeAll();
                runPanelEntry("chooseMonitor");
            },
            "until": () => !!rowShown(Shell.settingsView, I18n.t("Системный монитор", "System monitor")),
            "check": () => report("f02-pixel", Shell.settingsPage === "taskmanager" && !!rowShown(Shell.settingsView, "Системный монитор"), where(Shell.settingsView))
        },
        // F03 «Ещё…» from the keyboard (taskbar: a page with more)
        {
            "act": () => {
                SettingsTree.setMoreOpen("taskbar", false);
                Shell.openSettings("taskbar");
            },
            "until": () => Shell.settingsView && Shell.settingsView.pageItem && Shell.settingsView.pageItem.hasMore === true && Shell.settingsPage === "taskbar",
            "check": () => {
                const pg = Shell.settingsView.pageItem;
                const fold = find(pg, it => it.activeFocusOnTab === true && typeof it.toggle === "function");
                if (!fold)
                    return report("f03-keys", false, "no focusable «Ещё…»");
                // Tab from the search field (where an opened window's focus is) lands on it
                const ev = Qt.createQmlObject("import QtTest; TestEvent {}", fold);
                pg.flick.contentY = 0;
                Shell.settingsView.focusSearch();
                ev.keyClick(Qt.Key_Tab, Qt.NoModifier, -1);
                const tabbed = fold.activeFocus;
                const fy = fold.mapToItem(pg.flick.contentItem, 0, 0).y;
                const inView = fy >= pg.flick.contentY && fy + fold.height <= pg.flick.contentY + pg.flick.height;
                const focusShows = fold.activeFocus && Qt.colorEqual(fold.border.color, Theme.accent) && fold.border.width >= 2;
                ev.keyClick(Qt.Key_Space, Qt.NoModifier, -1);
                const bySpace = pg.moreOpen;
                ev.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
                const byEnter = !pg.moreOpen;
                ev.keyClick(Qt.Key_Enter, Qt.NoModifier, -1);
                const byPadEnter = pg.moreOpen;
                ev.destroy();
                SettingsTree.setMoreOpen("taskbar", false);
                report("f03-keys", tabbed && inView && focusShows && bySpace && byEnter && byPadEnter, "tab " + tabbed + ", in view " + inView + " (y " + Math.round(fy) + ", view " + Math.round(pg.flick.height) + "), focus shows " + focusShows + ", space opens " + bySpace + ", enter closes " + byEnter + ", keypad enter opens " + byPadEnter);
            }
        },
        // F04 the history group by its name: no history, then three (the title «История (3)»)
        {
            "act": () => {
                Notifs.history = [];
                Shell.openSettings("about");
            },
            "until": () => Shell.settingsPage === "about",
            "check": () => {}
        },
        {
            "act": () => Shell.settingsView.openResult(searchHistory()),
            "until": () => flashed(shown(Shell.settingsView, "history")),
            "check": () => report("f04-ru-empty", !!searchHistory() && flashed(shown(Shell.settingsView, "history")), where(Shell.settingsView) + " «" + (shown(Shell.settingsView, "history") || {}).title + "»")
        },
        {
            "act": () => {
                const h = [];
                for (let i = 0; i < 3; i++)
                    h.push({
                        "hid": "t" + i,
                        "appName": "test",
                        "summary": "s" + i,
                        "body": "",
                        "icon": "",
                        "time": Date.now(),
                        "urgency": 1,
                        "read": true
                    });
                Notifs.history = h;
                Shell.openSettings("about");
            },
            "until": () => Shell.settingsPage === "about",
            "check": () => {}
        },
        {
            "act": () => Shell.settingsView.openResult(searchHistory()),
            "until": () => flashed(shown(Shell.settingsView, "history")),
            "check": () => {
                const g = shown(Shell.settingsView, "history");
                report("f04-ru-three", !!g && g.title.indexOf("(3)") > 0 && flashed(g), where(Shell.settingsView) + " «" + (g || {}).title + "»");
            }
        },
        {
            "act": () => {
                Config.appearance.language = "en";
                Shell.openSettings("about");
            },
            "until": () => I18n.english && Shell.settingsPage === "about" && !!searchHistory(),
            "check": () => {}
        },
        {
            "act": () => Shell.settingsView.openResult(searchHistory()),
            "until": () => flashed(shown(Shell.settingsView, "history")),
            "check": () => {
                const g = shown(Shell.settingsView, "history");
                report("f04-en-three", !!g && g.title === "History (3)" && flashed(g), where(Shell.settingsView) + " «" + (g || {}).title + "»");
            }
        },
        // Golden Gate's tree: the monitor and the novel wait under «Ещё…» there
        {
            "act": () => {
                Config.appearance.language = "ru";
                closeAll();
                Config.settingsUi.skin = "goldengate";
            },
            "until": () => SettingsTree.mac,
            "check": () => {}
        },
        {
            "act": () => runPanelEntry("chooseMonitor"),
            "until": () => !!rowShown(Shell.settingsView, "Системный монитор"),
            "check": () => report("f02-goldengate", Shell.settingsPage === "defaults" && !!rowShown(Shell.settingsView, "Системный монитор") && Shell.settingsView.pageItem.moreOpen, where(Shell.settingsView))
        },
        {
            "act": () => Shell.openSettings("novel"),
            "until": () => !!shown(Shell.settingsView, "novel"),
            "check": () => report("f01-goldengate", Shell.settingsPage === "game" && !!shown(Shell.settingsView, "novel"), where(Shell.settingsView))
        }
    ]

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
            if (!root.acted) {
                // the first step waits for the start itself, the others act at once
                if (root.at > 0 || Config.ready)
                    s.act();
                root.acted = root.at > 0 || Config.ready;
                root.since = Date.now();
                return;
            }
            let ok = false;
            try {
                ok = !!s.until();
            } catch (e) {}
            if (!ok && Date.now() - root.since < (root.at === 0 ? 60000 : 5000))
                return;
            root.busy = true;
            try {
                s.check();
            } catch (e) {
                root.report("step-" + root.at, false, String(e));
            }
            root.busy = false;
            root.at++;
            root.acted = false;
        }
    }
}
