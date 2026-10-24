pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit
import "P5Lines.js" as Lines

// The Settings window in the angelOS look, the Persona 5 way: the sections slanted down the
// left, the section's card on the right with its pages as tabs (Q/E) and its settings as a
// game's option lines (↑↓ to pick, ←→ to change, Enter), one hint for the picked line in the
// strip at the bottom, typing anywhere searches. Behind it all the rays turn and the angel
// (a sister of the circles in the dark theme) plays every move and talks (P5Doll). The settings come straight
// from the catalog (modules/settings/catalog) through the settings tree (SettingsTree): the
// same entries the other looks draw with the pixel widgets.
// Narrow (half a screen, a laptop with big pixels) the sections hide behind the card — Esc
// shows them; very narrow, the sections fill the window first and the card after a pick.
FocusScope {
    id: root

    required property var view
    // over the desktop (SettingsOverlay), as P5's pause menu over the game: the desktop shows dimmed
    // through the background
    property bool overDesk: false
    // coming in and going out, as P3 Reload's pause: the frozen screen softens and breaks into
    // pixels, the backdrop shows, the sections slide in from the left one by one, the title drops,
    // the card comes from the right, she from below, the hints last; `leaving` plays it back, then
    // `goneOut`. Every piece moves in steps of its own part of `enterT` (stage)
    property bool leaving: false
    signal goneOut
    // the shot of the screen to freeze behind the menu (SettingsOverlay; "": none)
    property string frozen: ""
    property real enterT: 1
    function stage(a, b, n) {
        const k = n || 4;
        return Math.floor(Math.max(0, Math.min(1, (enterT - a) / (b - a))) * k) / k;
    }
    // the same with weight (the owner: «инерции не хватает»): a piece overshoots its place and
    // settles back, and going out it leans in before it leaves (the time played backwards)
    function swing(a, b, n) {
        const x = stage(a, b, n || 10) - 1, c = 1.4;
        return 1 + (c + 1) * x * x * x + c * x * x;
    }
    onShownNowChanged: {
        // opened again: a hello
        if (shownNow && shownCat && !leaving)
            remark(shownCat, true);
        if (!shownNow || leaving)
            return;
        leaveRun.stop();
        enterT = still ? 1 : 0;
        // the way in starts once the window is really on screen: its first frame takes ~100 ms
        // (the surface mapped, everything drawn once) and the start of it was lost in there
        firstFrame = !still;
    }
    property bool firstFrame: false
    Connections {
        target: root.Window.window
        enabled: root.firstFrame
        function onFrameSwapped() {
            root.firstFrame = false;
            enterRun.restart();
            root.snd("ding", 0.55);
        }
    }

    // her coming in (the owner: she popped in in a frame and out in another): a longer part of the
    // way in, finer steps, a shorter rise with weight; a black silhouette, the accent, then her
    // colours (P5's cut-ins); going out the same backwards
    readonly property real arrive: swing(0.55, 1.0, 14)
    readonly property real reveal: stage(0.55, 0.85, 6)
    // (not there at all before her turn: the menu first, then she cuts in)
    readonly property bool dollIn: enterT >= 0.55

    // ---- sound: a lift's ride, quietly — its bell as it opens and closes, a lounge tune while
    // it is open (data/sounds/settings, made by assets/settings-p5/audio/make.py), the menu's
    // little sounds. All through the shell's one sound stream (Sounds: never a stream of its own)
    readonly property string sndDir: Quickshell.shellDir + "/data/sounds/settings/"
    readonly property bool sndOn: Config.y2k.sounds && !StreamMode.quiet && !Sounds.quietNow()
    function snd(name, vol) {
        if (sndOn)
            Sounds.playFile(sndDir + name + ".ogg", vol * Config.y2k.soundVolume);
    }
    // its own sounds, not the desk's click under them
    Binding {
        target: Sounds
        property: "clickHush"
        value: root.shownNow && !root.leaving && root.sndOn
    }
    readonly property bool musicWanted: overDesk && shownNow && !leaving && sndOn && Config.y2k.settingsMusic
    onMusicWantedChanged: Sounds.loop(musicWanted ? sndDir + "lift.ogg" : "", musicWanted ? 0.32 * Config.y2k.soundVolume : 0)
    onLeavingChanged: {
        // opened again while going out: back in from where it got to (not when it is done and gone)
        const midway = leaveRun.running;
        enterRun.stop();
        leaveRun.stop();
        if (leaving && still)
            goneOut();
        else if (leaving) {
            leaveRun.restart();
            speech.shownQ = 0;
            speech.later = "";
            snd("dong", 0.45);
        } else if (midway)
            enterRun.restart();
    }
    NumberAnimation {
        id: enterRun
        target: root
        property: "enterT"
        to: 1
        // even steps: an easing bunched the last one up and it hung there like a stall
        duration: 640
        onFinished: if (speech.later) {
            speech.show(speech.later);
            speech.later = "";
        }
    }
    NumberAnimation {
        id: leaveRun
        target: root
        property: "enterT"
        to: 0
        duration: 380
        onFinished: root.goneOut()
    }
    // what the pixel widgets inside take as their look: P5's (P5Slant plates, Theme.tone colours)
    readonly property string settingsSkin: "p5"
    readonly property bool fluent: false
    readonly property var nav: view.settingsNav
    readonly property real px: Theme.u
    readonly property bool still: Motion.still

    // ---- colours: the theme's, P5's way (black, paper, the accent) ----
    readonly property var pal: ({
            "black": Theme.mix("#000000", Theme.accent, 0.07),
            "paper": Theme.mix("#ffffff", Theme.accent, 0.05),
            "white": Theme.mix("#ffffff", Theme.accent, 0.02),
            "paper2": Theme.mix("#ffffff", Theme.accent, 0.16),
            "paper3": Theme.mix("#ffffff", Theme.accent, 0.3),
            "accent": Theme.accent,
            "accent2": Theme.accent2,
            "dim": Theme.mix(Theme.mix("#000000", Theme.accent, 0.07), "#ffffff", 0.3),
            "danger": Theme.danger,
            "bg": Theme.dark ? Theme.mix(Theme.face, "#000000", 0.5) : Theme.mix(Theme.accent, "#ffffff", 0.8),
            "bg2": Theme.dark ? Theme.mix(Theme.mix(Theme.face, "#000000", 0.5), Theme.accent, 0.13) : Theme.mix(Theme.accent, "#ffffff", 0.68)
        })

    // the card and what is on it (rows, tabs): in the dark theme near-black paper, light ink
    // (Theme.p5*); the window's own black plates and paper letters around it stay as they are
    readonly property var cardPal: Object.assign({}, pal, {
        "black": Theme.p5Black,
        "paper": Theme.p5Paper,
        "white": Theme.p5White,
        "paper2": Theme.p5Paper2,
        "paper3": Theme.p5Paper3,
        "dim": Theme.mix(Theme.p5Black, Theme.dark ? "#000000" : "#ffffff", 0.3)
    })

    // ---- how much room there is ----
    readonly property string mode: width >= px * 420 ? "wide" : width >= px * 230 ? "half" : "tall"
    // narrow: the section list over the card (Esc, a click on the title)
    property bool catsOpen: false
    onModeChanged: catsOpen = mode === "tall" && !pageId

    // ---- where we are: a section of the tree and one of its pages ----
    readonly property var sections: view.visibleSections.map(s => s.id === "main" ? Object.assign({}, s, {
            "pages": s.pages.concat([SettingsTree.accountPage])
        }) : s)
    readonly property string pageId: {
        const id = nav.settingsPage;
        if (!id || id === "home" || id === "more")
            return "main";
        if (String(id).startsWith("cat:")) {
            const s = sections.find(x => x.id === id.slice(4));
            return s ? s.pages[0] : "main";
        }
        return id;
    }
    readonly property int catIndex: Math.max(0, sections.findIndex(s => s.pages.includes(pageId)))
    readonly property var cat: sections[catIndex] || null
    readonly property var tabs: cat ? cat.pages : []
    function go(id, sub) {
        if (nav.settingsPage !== id)
            nav.settingsPage = id;
        nav.settingsSub = sub || "";
    }
    function goSection(i) {
        const s = sections[Math.max(0, Math.min(sections.length - 1, i))];
        if (s)
            go(s.pages[0]);
        if (mode !== "wide")
            catsOpen = false;
    }
    function goTab(delta) {
        if (tabs.length < 2)
            return;
        const i = tabs.indexOf(pageId);
        go(tabs[(i + delta + tabs.length) % tabs.length]);
    }

    // ---- the card shows `shownPage`: it follows pageId, under the angel's wipe on a section change ----
    property string shownPage: ""
    property string shownCat: ""
    onPageIdChanged: follow()
    Component.onCompleted: {
        follow();
        forceActiveFocus();
    }
    function follow() {
        // (the bindings above may not have caught up yet: the section is looked up here)
        const c = sections.find(s => s.pages.includes(pageId)) || sections[0];
        if (!c)
            return;
        const newCat = c.id;
        // a tab: its own shot of her (the first tab: the section's)
        const v = Math.max(0, c.pages.indexOf(pageId));
        // (opening, or coming in: no cut over the way in — the page is just there)
        if (!shownCat || !shownNow || firstFrame || enterRun.running) {
            // the window opens: she bursts in (no cut: the coming in plays instead, the same each time)
            shownCat = newCat;
            show(pageId);
            angel.go(newCat, 1, false, v);
            if (newCat !== remarked)
                remark(newCat, true);
            return;
        }
        if (shownCat === newCat && shownPage === pageId)
            return;
        const dir = shownCat === newCat ? (c.pages.indexOf(pageId) >= c.pages.indexOf(shownPage) ? 1 : -1) : sections.findIndex(s => s.id === newCat) < sections.findIndex(s => s.id === shownCat) ? -1 : 1;
        const tabOnly = shownCat === newCat;
        if (!tabOnly) {
            backdrop.wipe();
            catSlam.restart();
        }
        shownCat = newCat;
        pending = {
            "page": pageId,
            "cat": newCat,
            "dir": dir,
            "v": v
        };
        slash.cut(dir);
        snd(tabOnly ? "tab" : "whoosh", 0.45);
    }
    // what she says on a section: its first visit (the game remembers which), all of them seen,
    // the angel remembering a sister she saw in the dark, a hello when opened again
    property string remarked: ""
    function remark(c, opening) {
        remarked = c;
        const who = angel.who, en = I18n.english;
        const seenBefore = Achievements.active ? Array.from(Achievements.kindsSeen["settings.section"] || []) : sessionSeen;
        const fresh = !seenBefore.includes(c);
        if (fresh)
            sessionSeen = sessionSeen.concat([c]);
        Achievements.note("settings.section", c);
        if (who !== "angel")
            Achievements.note("settings.sister", who);
        const all = sections.filter(x => x.id !== "author").every(x => x.id === c || seenBefore.includes(x.id) || sessionSeen.includes(x.id));
        if (fresh && all)
            return angel.speak(Lines.all(en));
        if (fresh && !opening)
            return angel.speak(Lines.first(who, c, en));
        const sisters = Achievements.active ? Array.from(Achievements.kindsSeen["settings.sister"] || []) : angel.sistersSeen;
        if (who === "angel" && sisters.length && Achievements.count("settings.told") < 3 && Math.random() < 0.3) {
            Achievements.note("settings.told");
            return angel.speak(Lines.seen(sisters[Math.floor(Math.random() * sisters.length)], en));
        }
        if (opening && Math.random() < 0.35)
            angel.speak(Lines.react(who, "back", en));
    }
    property var sessionSeen: []
    // the card and her shot change under the slash
    property var pending: null
    Connections {
        target: slash
        function onCovered() {
            const p = root.pending;
            if (!p)
                return;
            root.pending = null;
            root.show(p.page);
            angel.go(p.cat, p.dir, false, p.v);
            if (p.cat !== root.remarked)
                root.remark(p.cat, false);
            root.bump();
        }
    }

    // ---- the catalogs the shown page is made of ----
    property var catalogs: ({})
    Item {
        id: holder
        visible: false
        // what the old pages read off their page
        readonly property real innerWidth: rowsCol.width
        readonly property real contentY: flick.contentY
        function scrollBy(dy) {
            flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + dy));
        }
    }
    // what the catalogs' pages read for their own `visible`
    readonly property bool shownNow: visible && !!Window.window && Window.window.visible
    // A catalog is built in the background (incubated a slice a frame: the cut plays on while the
    // page is made — built at once, the Windows catalog stalled a frame for 126 ms), the page's
    // rows come when it is ready. The last few stay built: going back is instant. Each has a host of
    // its own, `visible` only while its page is shown — a kept one's previews don't run unseen.
    property var wanted: ({})
    property var building: ({})
    property var recent: []
    readonly property int keepBuilt: 10
    function catalog(name) {
        if (catalogs[name] || building[name])
            return;
        building[name] = true;
        const c = Qt.createComponent(Qt.resolvedUrl("../catalog/" + name + ".qml"), Component.Asynchronous);
        const make = () => {
            if (c.status !== Component.Ready) {
                if (c.status === Component.Error) {
                    console.warn("P5View: " + name + ": " + c.errorString());
                    delete building[name];
                }
                return;
            }
            const inc = c.incubateObject(holder, {
                "host": hostComp.createObject(root, {
                    "name": name
                })
            }, Qt.Asynchronous);
            const done = st => {
                if (st === Component.Error)
                    delete building[name];
                if (st !== Component.Ready)
                    return;
                delete building[name];
                const m = Object.assign({}, catalogs);
                m[name] = inc.object;
                catalogs = m;
            };
            if (inc.status !== Component.Loading)
                done(inc.status);
            else
                inc.onStatusChanged = done;
        };
        if (c.status === Component.Loading)
            c.statusChanged.connect(make);
        else
            make();
    }
    Component {
        id: hostComp
        QtObject {
            property string name
            readonly property bool visible: root.shownNow && !!root.wanted[name]
            readonly property real innerWidth: rowsCol.width
            readonly property real contentY: flick.contentY
            function scrollBy(dy) {
                holder.scrollBy(dy);
            }
        }
    }
    readonly property bool moreOpen: !!SettingsTree.moreOpen[shownPage]
    function show(id) {
        shownPage = id;
        const want = {};
        for (const w of ["top", "more"])
            for (const p of SettingsTree.partsOf(id, w))
                if (p.catalog)
                    want[p.catalog] = true;
        wanted = want;
        for (const name in want)
            catalog(name);
        // the ones not shown stay built, the last few of them; older ones go once the rows let go
        recent = Object.keys(want).concat(recent.filter(n => !want[n]));
        const drop = recent.slice(keepBuilt).filter(n => !!catalogs[n]);
        recent = recent.slice(0, keepBuilt);
        if (drop.length)
            Qt.callLater(() => {
                const m = Object.assign({}, root.catalogs);
                for (const n of drop)
                    if (m[n] && !root.wanted[n]) {
                        m[n].host.destroy();
                        m[n].destroy();
                        delete m[n];
                    }
                root.catalogs = m;
            });
        sel = -1;
        flick.contentY = 0;
        settling = true;
        Qt.callLater(settle);
    }
    // the first line picked (or the one asked for) once the page's rows are there
    property bool settling: false
    onPageReadyChanged: Qt.callLater(settle)
    function settle() {
        if (!settling || !pageReady)
            return;
        settling = false;
        // the tabs on either side built ahead, in the background: Q / E show them at once
        const i = tabs.indexOf(shownPage);
        if (i >= 0)
            for (const t of [tabs[i - 1], tabs[i + 1]])
                if (t)
                    for (const w of ["top", "more"])
                        for (const p of SettingsTree.partsOf(t, w))
                            if (p.catalog && recent.indexOf(p.catalog) < 0) {
                                recent = recent.concat([p.catalog]);
                                catalog(p.catalog);
                            }
        selectFirst();
        if (nav.settingsSub)
            showTarget({
                "kind": "group",
                "target": nav.settingsSub
            });
    }
    // the lines of the card: the page's groups and their entries, «Ещё…» and what it opens
    readonly property var lines: query ? resultLines : pageLines
    // The rows are made a few a frame, the first screenful at once (all of a page's forty at once
    // stopped the window for a quarter of a second); the delegates read their line here
    property var rowLines: []
    ListModel {
        id: rowModel
    }
    onLinesChanged: {
        rowModel.clear();
        rowLines = lines;
        feedRows(3);
        rowFeed.running = rowModel.count < rowLines.length;
    }
    function feedRows(n) {
        const end = Math.min(rowLines.length, rowModel.count + n);
        for (let i = rowModel.count; i < end; i++)
            rowModel.append({
                "k": i
            });
    }
    Timer {
        id: rowFeed
        interval: 16
        repeat: true
        onTriggered: {
            root.feedRows(2);
            if (rowModel.count < root.rowLines.length)
                return;
            stop();
            // the rows above the first line grew as they came: the page at its top again
            if (root.firstPick)
                flick.contentY = 0;
        }
    }
    // the same rows as last time (a catalog of another page got built, a neighbour tab made
    // ahead): the same array, so the rows aren't all made again
    readonly property var linesMemo: ({})
    function sameLines(a, b) {
        return !!b && a.length === b.length && a.every((l, i) => l.t === b[i].t && l.e === b[i].e && l.g === b[i].g && l.file === b[i].file && l.plugin === b[i].plugin && l.opened === b[i].opened && l.count === b[i].count);
    }
    // (all of a page's catalogs ready, or none of its rows: they are built once, not piece by piece)
    readonly property bool pageReady: Object.keys(wanted).every(n => !!catalogs[n])
    readonly property var pageLines: {
        const id = shownPage, out = [];
        if (!id || !pageReady)
            return out;
        if (id.startsWith("plugin:")) {
            out.push({
                "t": "embed",
                "plugin": id.slice(7)
            });
            return out;
        }
        const add = parts => {
            for (const p of parts) {
                if (!p.catalog) {
                    out.push({
                        "t": "embed",
                        "file": p.file
                    });
                    continue;
                }
                const c = root.catalogs[p.catalog];
                if (!c)
                    continue;
                for (const part of c.parts) {
                    if (part.isCatGroup === true) {
                        if (p.only.length && !p.only.includes(part.name))
                            continue;
                        out.push({
                            "t": "group",
                            "g": part,
                            "title": part.title
                        });
                        for (const e of part.entries)
                            out.push({
                                "t": "entry",
                                "e": e,
                                "g": part
                            });
                    } else if (p.loose) {
                        out.push({
                            "t": "entry",
                            "e": part,
                            "g": null
                        });
                    }
                }
            }
        };
        add(SettingsTree.partsOf(id, "top"));
        const more = SettingsTree.partsOf(id, "more");
        if (more.length) {
            out.push({
                "t": "more",
                "opened": root.moreOpen,
                "count": more.length,
                "open": () => SettingsTree.setMoreOpen(id, !root.moreOpen)
            });
            if (root.moreOpen)
                add(more);
        }
        if (sameLines(out, linesMemo.page))
            return linesMemo.page;
        linesMemo.page = out;
        return out;
    }

    // ---- the selection ----
    property int sel: -1
    readonly property var selRow: sel >= 0 ? rowsRep.itemAt(sel) : null
    // the selection is still the one the page opened with (not moved by keys or the pointer)
    property bool firstPick: false
    function selectFirst() {
        // none among the rows made so far: the next few, until one is
        while (!rootFirstSelectable() && rowModel.count < rowLines.length)
            feedRows(2);
        for (let i = 0; i < rowsRep.count; i++) {
            const r = rowsRep.itemAt(i);
            if (r && r.selectable) {
                // (the page opens at its top, even with the first line further down)
                select(i, true);
                firstPick = true;
                return;
            }
        }
        sel = -1;
    }
    function rootFirstSelectable() {
        for (let i = 0; i < rowsRep.count; i++) {
            const r = rowsRep.itemAt(i);
            if (r && r.selectable)
                return true;
        }
        return false;
    }
    // (a pick by the pointer doesn't scroll: the list jumping under the mouse picks the next one)
    function select(i, byPointer) {
        if (i === sel)
            return;
        firstPick = false;
        sel = i;
        const r = rowsRep.itemAt(i);
        if (!r)
            return;
        if (!byPointer)
            ensureVisible(r);
        const n = Math.max(1, rowsRep.count);
        angel.lookY = (i - (n - 1) / 2) / n * 0.03;
        hint.say(r.kind === "more" ? I18n.t("Редкие настройки этой страницы", "This page's rarer settings") : r.kind === "result" ? r.line.r.crumb || "" : r.e ? r.e.hint : "");
    }
    // the pointer really moved (not the list under it): only then does hovering pick
    property point lastPointer: Qt.point(-1, -1)
    function pointerMoved(g) {
        const moved = lastPointer.x >= 0 && Math.abs(g.x - lastPointer.x) + Math.abs(g.y - lastPointer.y) > 2;
        lastPointer = g;
        return moved;
    }
    function move(delta) {
        let i = sel;
        // (down past the rows made so far: the next ones now)
        if (delta > 0 && sel + 4 >= rowModel.count)
            feedRows(8);
        for (let k = 0; k < rowsRep.count; k++) {
            i += delta;
            if (i < 0 || i >= rowsRep.count)
                return;
            const r = rowsRep.itemAt(i);
            if (r && r.selectable) {
                select(i);
                root.snd("tick", 0.3);
                return;
            }
        }
    }
    function ensureVisible(r) {
        const y = r.mapToItem(rowsCol, 0, 0).y;
        if (y < flick.contentY)
            flick.contentY = Math.max(0, y - px * 4);
        else if (y + r.height > flick.contentY + flick.height)
            flick.contentY = Math.min(flick.contentHeight - flick.height, y + r.height - flick.height + px * 4);
    }

    // a found setting (the search, a link, a sub-page): select its line, open «Ещё…» if it is there
    function showTarget(r) {
        if (!r)
            return;
        const match = l => {
            if (r.kind === "row")
                return l.t === "entry" && l.e && l.e.label === r.target;
            if (r.kind === "group")
                return l.t === "group" && (r.name ? l.g.name === r.name : l.g.title === r.target || l.g.name === r.target);
            if (r.kind === "name")
                return l.t === "group" && l.g.name === r.target;
            return false;
        };
        const i = lines.findIndex(match);
        if (i < 0) {
            if (!moreOpen && SettingsTree.partsOf(shownPage, "more").length && !r.moreOpened) {
                SettingsTree.setMoreOpen(shownPage, true);
                Qt.callLater(() => root.showTarget(Object.assign({}, r, {
                        "moreOpened": true
                    })));
            }
            return;
        }
        Qt.callLater(() => {
            // (the rows down to it made now)
            root.feedRows(i + 8 - rowModel.count);
            // a group: its first line
            let j = i;
            if (r.kind !== "row")
                for (let k = i; k < rowsRep.count; k++) {
                    const it = rowsRep.itemAt(k);
                    if (it && it.selectable) {
                        j = k;
                        break;
                    }
                }
            root.select(j);
            const it = rowsRep.itemAt(j);
            if (it)
                flashComp.createObject(it);
        });
    }
    Component {
        id: flashComp
        Rectangle {
            id: fl
            anchors.fill: parent
            color: "transparent"
            border.width: root.px * 2
            border.color: root.pal.accent
            SequentialAnimation on opacity {
                running: true
                loops: 3
                PropertyAction {
                    value: 1
                }
                PauseAnimation {
                    duration: 160
                }
                PropertyAction {
                    value: 0
                }
                PauseAnimation {
                    duration: 120
                }
            }
            Timer {
                running: true
                interval: 900
                onTriggered: fl.destroy()
            }
        }
    }

    // ---- the search: typing anywhere ----
    property string query: ""
    readonly property var results: query.trim() ? SettingsSearch.search(query.trim(), 40) : []
    readonly property var resultLines: results.map(r => ({
                "t": "result",
                "r": r
            }))
    onQueryChanged: {
        const was = !!lastQuery;
        lastQuery = query;
        if (!!query !== was)
            angel.go(query ? "search" : shownCat, query ? 1 : -1, false);
        sel = -1;
        flick.contentY = 0;
        Qt.callLater(root.selectFirst);
    }
    property string lastQuery: ""
    function openResult(r) {
        query = "";
        view.openResult(r);
    }

    // ---- moving about: the keyboard and the gamepad say the same things ----
    function act(a) {
        const r = selRow;
        const narrow = mode !== "wide" && catsOpen;
        if (a === "back") {
            if (query)
                query = "";
            else if (mode !== "wide" && !catsOpen)
                catsOpen = true;
            else
                nav.settingsOpen = false;
        } else if (narrow && (a === "up" || a === "down")) {
            goSection(catIndex + (a === "down" ? 1 : -1));
            catsOpen = true;
        } else if (narrow && (a === "ok" || a === "right")) {
            catsOpen = false;
        } else if (a === "sectionUp" || a === "sectionDown") {
            goSection(catIndex + (a === "sectionDown" ? 1 : -1));
        } else if (a === "up" || a === "down") {
            move(a === "down" ? 1 : -1);
        } else if (a === "left" || a === "right") {
            if (r)
                r.step(a === "right" ? 1 : -1);
        } else if (a === "ok") {
            if (r) {
                if (r.kind === "result")
                    openResult(r.line.r);
                else
                    r.activate();
            }
        } else if (a === "tabLeft" || a === "tabRight") {
            goTab(a === "tabRight" ? 1 : -1);
        }
    }
    Keys.onPressed: e => {
        const r = selRow;
        if (r && r.editing)
            return;
        const shift = e.modifiers & Qt.ShiftModifier, ctrl = e.modifiers & Qt.ControlModifier;
        const keys = {};
        keys[Qt.Key_Escape] = "back";
        keys[Qt.Key_Up] = shift ? "sectionUp" : "up";
        keys[Qt.Key_Down] = shift ? "sectionDown" : "down";
        keys[Qt.Key_Left] = "left";
        keys[Qt.Key_Right] = "right";
        keys[Qt.Key_Return] = "ok";
        keys[Qt.Key_Enter] = "ok";
        keys[Qt.Key_PageUp] = "tabLeft";
        keys[Qt.Key_PageDown] = "tabRight";
        if (keys[e.key]) {
            act(keys[e.key]);
        } else if (e.key === Qt.Key_Space && !query) {
            act("ok");
        } else if (e.key === Qt.Key_Backspace) {
            if (query)
                query = query.slice(0, -1);
        } else if (ctrl && e.key === Qt.Key_F) {
            searchFocus = true;
        } else if (!query && !ctrl && (e.text === "q" || e.text === "e" || e.text === "Q" || e.text === "E")) {
            goTab(e.text.toLowerCase() === "q" ? -1 : 1);
        } else if (e.text && e.text.length === 1 && e.text >= " " && !ctrl && !(e.modifiers & Qt.AltModifier)) {
            query += e.text;
        } else {
            return;
        }
        e.accepted = true;
    }
    property bool searchFocus: false

    // the gamepad while the window has the focus (scripts/gamepad.py reads the pads, never grabs
    // them): the d-pad and the left stick move, A picks, B goes back, LB/RB the tabs, LT/RT
    // the sections
    readonly property bool padWanted: shownNow && !!Window.window && Window.window.active
    Process {
        id: pad
        running: root.padWanted
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/gamepad.py"]
        stdout: SplitParser {
            onRead: line => {
                let ev;
                try {
                    ev = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (ev.event === "key" && ev.value > 0)
                    root.padKey(ev.code);
                else if (ev.event === "abs")
                    root.padAxes(ev.values || {});
            }
        }
    }
    readonly property var padButtons: ({
            "BTN_SOUTH": "ok",
            "BTN_EAST": "back",
            "BTN_TL": "tabLeft",
            "BTN_TR": "tabRight",
            "BTN_TL2": "sectionUp",
            "BTN_TR2": "sectionDown",
            "BTN_DPAD_UP": "up",
            "BTN_DPAD_DOWN": "down",
            "BTN_DPAD_LEFT": "left",
            "BTN_DPAD_RIGHT": "right"
        })
    function padKey(code) {
        const a = padButtons[code];
        if (a)
            act(a);
    }
    // a direction held: once, then repeating
    property string padHeld: ""
    function padAxes(v) {
        const x = v.ABS_HAT0X !== undefined ? v.ABS_HAT0X : v.ABS_X !== undefined ? (Math.abs(v.ABS_X) > 0.6 ? Math.sign(v.ABS_X) : 0) : undefined;
        const y = v.ABS_HAT0Y !== undefined ? v.ABS_HAT0Y : v.ABS_Y !== undefined ? (Math.abs(v.ABS_Y) > 0.6 ? Math.sign(v.ABS_Y) : 0) : undefined;
        let dir = padHeld;
        if (y !== undefined && y !== 0)
            dir = y > 0 ? "down" : "up";
        else if (x !== undefined && x !== 0)
            dir = x > 0 ? "right" : "left";
        else if ((y === 0 && (padHeld === "up" || padHeld === "down")) || (x === 0 && (padHeld === "left" || padHeld === "right")))
            dir = "";
        if (dir === padHeld)
            return;
        padHeld = dir;
        if (dir) {
            act(dir);
            padRepeat.interval = 380;
            padRepeat.restart();
        } else {
            padRepeat.stop();
        }
    }
    Timer {
        id: padRepeat
        repeat: true
        onTriggered: {
            if (root.padHeld)
                root.act(root.padHeld);
            interval = 110;
        }
    }

    // ================= the picture =================
    // where the pointer is: she looks at it
    HoverHandler {
        id: pointer
    }
    // the window is moved by its background
    MouseArea {
        anchors.fill: parent
        onPressed: if (root.view.hostWindow)
            root.view.hostWindow.startSystemMove()
        onClicked: root.forceActiveFocus()
    }
    Image {
        id: frozenShot
        visible: false
        // in the background: the first frames it would show are the desktop itself anyway
        asynchronous: true
        cache: false
        smooth: false
        source: root.overDesk ? root.frozen : ""
    }
    ShaderEffect {
        anchors.fill: parent
        visible: frozenShot.status === Image.Ready && !!root.frozen
        property variant source: frozenShot
        property size size: Qt.size(width, height)
        property real amount: root.stage(0, 0.34, 6)
        property real cell: px * 8
        property color tint: root.pal.bg2
        property real dim: Theme.dark ? 0.45 : 0.15
        fragmentShader: Qt.resolvedUrl("../../../shaders/p5_freeze.frag.qsb")
    }
    P5Backdrop {
        id: backdrop
        opacity: (!root.overDesk ? 1 : frozenShot.status === Image.Ready && root.frozen ? 0.6 : 0.8) * root.stage(0.2, 0.44, 3)
        anchors.fill: parent
        base: root.pal.bg
        base2: root.pal.bg2
        slab: root.pal.accent
        star: root.pal.paper
        still: root.still
        slabWidth: root.mode === "wide" ? 0.55 : root.mode === "half" ? 0.4 : 0.6
        // the light theme (the angel): P3 Reload's water in the accent, pushed a little to the
        // deep blue that water is; the dark one (the fallen): P5's rays
        water: !Theme.dark
        deep: Theme.mix(Theme.mix(Theme.accent, "#0b1a5a", 0.55), "#000000", 0.4)
        shallow: Theme.mix(Theme.mix(Theme.accent, "#2a8cff", 0.5), "#ffffff", 0.25)
        glint: Theme.mix(Theme.accent, "#ffffff", 0.85)
    }
    P5Doll {
        id: angel
        opacity: root.dollIn ? 1 : 0
        transform: Translate {
            x: (1 - root.arrive) * root.width * 0.06
            y: (1 - root.arrive) * root.height * 0.3
        }
        anchors.fill: parent
        // the angel in heaven's light; in the dark the sisters of the circles, one per section
        // (the owner, 23.10: only them)
        cast: Theme.dark ? ["limbo", "heresy", "fraud", "greed"] : ["angel"]
        tabCounts: root.sections.reduce((o, s) => Object.assign(o, {
                [s.id]: (s.pages || []).length
            }), {})
        // carried off: over the card, not behind it
        z: carried ? 30 : 0
        // (wide: close enough to lean over the card's edge)
        zone: root.mode === "wide" ? 0.3 : root.mode === "half" ? 0.88 : 0.62
        accent: root.pal.accent
        black: root.pal.black
        paper: root.pal.paper
        still: root.still
        gaze: pointer.hovered ? pointer.point.position : Qt.point(-1, -1)
        onSay: text => speech.show(text)
        front: dollFront
        reveal: root.reveal
        frontBand: root.mode === "wide" ? Qt.rect(card.x - px * 30, card.y - px * 6, px * 30 + root.cardField, card.height + px * 12) : Qt.rect(0, 0, 0, 0)
        // wide: her canvas well past the field's end — the card hides her beyond it, so only the
        // field shows her, never its words (the owner, 23.10: «заметно, но по полю»)
        edgeX: root.mode === "wide" ? root.cardX + root.cardField * 1.4 : -1
        topY: root.height * 0.05
        // her eyes: right of the menu (the picked one's bolt too), short of the card's words, under the title
        eyeZone: root.mode === "wide" ? Qt.rect(catFlick.x + catList.width + px * 10, title.y + title.height + px * 4, root.cardX + root.cardField - px * 6 - (catFlick.x + catList.width + px * 10), root.height * 0.68 - title.y - title.height) : Qt.rect(0, 0, 0, 0)
        onPoked: {
            Achievements.note("settings.poke");
            root.snd("boop", 0.5);
        }
        // a shot per section ("face": the pose's own face point)
        shots: ({
                "main": {
                    "a": [0.5, 0.5],
                    "dx": 0,
                    "wy": 0.6,
                    "s": 0.95,
                    "r": 0
                },
                "system": {
                    "a": "face",
                    "dx": 0.02,
                    "wy": 0.4,
                    "s": 1.2,
                    "r": -7
                },
                "devices": {
                    "a": [0.5, 0.55],
                    "dx": 0.04,
                    "wy": 0.6,
                    "s": 1.05,
                    "r": 8
                },
                "network": {
                    "a": [0.5, 0.5],
                    "dx": -0.03,
                    "wy": 0.42,
                    "s": 0.62,
                    "r": -5,
                    "f": -1
                },
                "personal": {
                    "a": [0.5, 0.42],
                    "dx": 0,
                    "wy": 0.62,
                    "s": 1.25,
                    "r": 0
                },
                "windows": {
                    "a": "face",
                    "dx": -0.02,
                    "wy": 0.45,
                    "s": 1.05,
                    "r": 9,
                    "f": -1
                },
                "apps": {
                    "a": [0.5, 0.5],
                    "dx": 0.03,
                    "wy": 0.58,
                    "s": 0.95,
                    "r": -8
                },
                "stream": {
                    "a": [0.5, 0.45],
                    "dx": 0.05,
                    "wy": 0.62,
                    "s": 0.95,
                    "r": -16
                },
                "a11y": {
                    "a": [0.5, 0.32],
                    "dx": 0,
                    "wy": 0.52,
                    "s": 1.35,
                    "r": 0,
                    "f": -1
                },
                "game": {
                    "a": "face",
                    "dx": 0,
                    "wy": 0.42,
                    "s": 1.45,
                    "r": 4
                },
                "angelos": {
                    "a": [0.5, 0.15],
                    "dx": 0,
                    "wy": 0.22,
                    "s": 1.15,
                    "r": 0
                },
                "author": {
                    "a": [0.5, 0.4],
                    "dx": 0.02,
                    "wy": 0.55,
                    "s": 1.0,
                    "r": 6
                },
                "search": {
                    "a": "face",
                    "dx": 0.02,
                    "wy": 0.92,
                    "s": 1.2,
                    "r": -6
                }
            })
    }

    // ---- the title ----
    P5Ransom {
        id: title
        transform: Translate {
            y: -(1 - root.swing(0.3, 0.52)) * root.height * 0.3
        }
        x: root.edge
        y: root.edge
        text: root.mode === "half" && !root.catsOpen && root.cat ? String(root.cat.label).toUpperCase() : I18n.t("НАСТРОЙКИ", "SETTINGS")
        pal: root.pal
        small: root.mode !== "wide"
        large: root.mode === "wide" && root.height >= px * 520
        still: root.still
    }
    MouseArea {
        x: title.x
        y: title.y
        width: title.width
        height: title.height
        enabled: root.mode !== "wide"
        onClicked: root.catsOpen = !root.catsOpen
    }

    // ---- the search plate (and the window's ✕) ----
    Item {
        id: search
        transform: Translate {
            y: -(1 - root.swing(0.3, 0.52)) * root.height * 0.3
        }
        readonly property bool typing: !!root.query || root.searchFocus
        anchors.right: closer.left
        anchors.rightMargin: px * 4
        y: root.edge
        width: Math.min(root.width * 0.4, searchText.implicitWidth + px * 16)
        height: searchText.implicitHeight + px * 5
        visible: root.mode !== "tall" || !root.catsOpen
        P5Plate {
            anchors.fill: parent
            poly: [[px * 3, 0], [width, px], [width - px * 3, height], [0, height - px]]
            color: root.pal.black
            rim: search.typing ? root.pal.accent : root.pal.paper
            rimWidth: px
            shadowX: 0
            shadowY: 0
        }
        PxText {
            id: searchText
            kind: "title"
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            x: px * 7
            width: parent.width - px * 12
            elide: Text.ElideLeft
            text: root.query ? "⌕ " + root.query + (caret.on ? "▌" : " ") : I18n.t("⌨ печатай — поиск", "⌨ type to search") + (caret.on ? " ▌" : "  ")
            color: root.query ? root.pal.paper : Theme.mix(root.pal.paper, root.pal.black, 0.35)
        }
        Timer {
            id: caret
            property bool on: true
            running: root.visible
            repeat: true
            interval: 500
            onTriggered: on = !on
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: {
                root.searchFocus = true;
                root.forceActiveFocus();
            }
        }
    }
    Item {
        id: closer
        transform: Translate {
            y: -(1 - root.swing(0.3, 0.52)) * root.height * 0.3
        }
        anchors.right: parent.right
        anchors.rightMargin: root.edge
        y: root.edge
        width: px * 14
        height: px * 13
        P5Plate {
            anchors.fill: parent
            poly: [[px * 2, 0], [width, px], [width - px, height], [0, height - px * 2]]
            color: closeMouse.containsMouse ? root.pal.accent : root.pal.paper
            shadow: root.pal.black
            shadowX: px * 2
            shadowY: px * 2
        }
        PxText {
            kind: "title"
            anchors.centerIn: parent
            text: "✕"
            color: root.pal.black
            font.bold: true
        }
        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.nav.settingsOpen = false
        }
    }

    // ---- the sections ----
    // (scrolls when it is taller than the window: a big pixel, a low window)
    Flickable {
        id: catFlick
        visible: catList.shownHere
        x: root.edge
        y: title.y + title.height + px * 8
        width: catList.width + px * 30
        height: root.height - y - hintBar.height - px * 4
        contentHeight: catList.height + px * 6
        interactive: contentHeight > height
        clip: interactive
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: catList
            readonly property bool shownHere: root.mode === "wide" || root.catsOpen
            spacing: px * 3
            Repeater {
                id: catRep
                model: root.sections
                Item {
                    id: c
                    required property var modelData
                    required property int index
                    readonly property bool on: index === root.catIndex
                    // as wide as it is when not picked (the card's place never follows the pick)
                    readonly property real plainW: glyph.implicitWidth + px * 14
                    readonly property int plainBig: glyph.big
                    // in one by one from the left (the window coming in)
                    transform: Translate {
                        readonly property real q: root.swing(0.3 + c.index * 0.03, 0.5 + c.index * 0.03)
                        x: -(1 - q) * (catFlick.width + root.px * 40)
                    }
                    // three ways to sway, by turns
                    readonly property int way: index % 3
                    property int swayStep: 0
                    width: on ? onBox.width + px * 22 : glyph.implicitWidth + px * 8 + (way === 1 ? px * 6 : way === 2 ? px * 3 : 0)
                    // (the picked one: room above for its bolt, off the name before it)
                    height: on ? onBox.height + px * 18 : glyph.implicitHeight + px * 4
                    Timer {
                        running: !root.still && !c.on && catList.visible
                        repeat: true
                        interval: [2600, 3300, 2900][c.way] / 2
                        onTriggered: c.swayStep = (c.swayStep + 1) % 2
                    }
                    // P5's main menu: one heavy face, white on a black slanted plate, the words a
                    // staircase leaning by turns (cut-out letters only in the window's title)
                    Item {
                        visible: !c.on
                        x: (c.way === 1 ? px * 6 : c.way === 2 ? px * 3 : 0) + (c.way === 1 && c.swayStep ? px * 2 : 0)
                        y: c.way === 2 && c.swayStep ? -px : 0
                        width: glyph.implicitWidth + px * 8
                        height: glyph.implicitHeight + px * 3
                        P5Plate {
                            anchors.fill: parent
                            poly: [[px * 3, 0], [width, 0], [width - px * 3, height], [0, height]]
                            tilt: glyph.tilt
                            color: root.pal.black
                            // a thick paper edge: the word reads over her too
                            rim: root.pal.paper
                            rimWidth: px * 1.5
                        }
                        P5Glyphs {
                            id: glyph
                            x: px * 4
                            y: px * 2
                            text: String(c.modelData.label).toUpperCase()
                            big: Math.max(1, Math.round((root.height >= px * 520 ? 20 : 10) / cell))
                            tilt: [-4, 3, -2][c.way] + (c.swayStep ? 1 : 0)
                            color: catMouse.containsMouse ? root.pal.accent2 : root.pal.paper
                        }
                    }
                    // the picked one: a plate, leaning, with a tail
                    Item {
                        id: onBox
                        visible: c.on
                        x: px * 8 + (catSlam.running ? -px * 12 * (1 - catSlam.q) : 0)
                        y: px * 9
                        width: onText.implicitWidth + px * 12
                        height: onText.implicitHeight + px * 4
                        // P5's lightning behind the picked word: a jagged bolt
                        P5Plate {
                            x: -px * 26
                            y: -px * 10
                            width: parent.width + px * 52
                            height: parent.height + px * 20
                            poly: [[0, height * 0.55], [width * 0.18, height * 0.1], [width * 0.34, height * 0.42], [width * 0.6, 0], [width, height * 0.3], [width * 0.66, height * 0.62], [width * 0.44, height * 0.38], [width * 0.24, height]]
                            // black with a paper rim: it shows on the accent backdrop too
                            color: root.pal.black
                            rim: root.pal.paper
                            shadowX: 0
                            shadowY: 0
                            tilt: -5 - (catSlam.running ? 14 * (1 - catSlam.q) : 0)
                        }
                        P5Plate {
                            anchors.fill: parent
                            tilt: -5 - (catSlam.running ? 9 * (1 - catSlam.q) : 0)
                            color: root.pal.paper
                            shadow: root.pal.black
                            shadowX: px * 3
                            shadowY: px * 3
                        }
                        P5Glyphs {
                            id: onText
                            x: px * 6
                            y: px * 2
                            tilt: -5 - (catSlam.running ? 9 * (1 - catSlam.q) : 0)
                            text: String(c.modelData.label).toUpperCase()
                            // a size up from the others, more if it fits short of the card (never smaller)
                            big: Math.max(c.plainBig + 1 <= fitBig ? c.plainBig + 1 : c.plainBig, Math.min(Math.round((root.height >= px * 520 ? 40 : 26) / cell), fitBig))
                            readonly property int fitBig: Math.floor((root.cardX - catFlick.x - onBox.x - px * 34) / Math.max(1, onMeasure.advanceWidth * Theme.u))
                            TextMetrics {
                                id: onMeasure
                                font.family: onText.family
                                font.bold: true
                                font.pixelSize: onText.cell
                                text: onText.text
                            }
                            color: root.pal.black
                        }
                        // the tail
                        P5Plate {
                            x: parent.width + px * 2
                            y: parent.height / 2 - px * 4
                            width: px * 18
                            height: px * 8
                            poly: [[0, height * 0.3], [width * 0.7, height * 0.3], [width * 0.7, 0], [width, height * 0.5], [width * 0.7, height], [width * 0.7, height * 0.7], [0, height * 0.7]]
                            color: root.pal.accent
                            tilt: -5
                        }
                    }
                    MouseArea {
                        id: catMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.goSection(c.index);
                            root.forceActiveFocus();
                        }
                    }
                }
            }
        }
    }
    // the picked section in sight
    Connections {
        target: root
        function onCatIndexChanged() {
            const it = catRep.itemAt(root.catIndex);
            if (!it || !catFlick.interactive)
                return;
            if (it.y < catFlick.contentY)
                catFlick.contentY = it.y;
            else if (it.y + it.height > catFlick.contentY + catFlick.height)
                catFlick.contentY = it.y + it.height - catFlick.height + root.px * 6;
        }
    }
    // the picked section slams in
    NumberAnimation {
        id: catSlam
        property real q: 1
        target: catSlam
        property: "q"
        from: 0
        to: 1
        duration: root.still ? 0 : 300
    }

    // ---- the card ----
    // its way in on twos, with a smear: where it just was, a plate in the accent for a frame or two
    readonly property real cardShift: (1 - swing(0.42, 0.74)) * width * 0.7
    property real cardWas: 0
    property real cardSmear: 0
    property real cardSmearA: 0
    onCardShiftChanged: {
        // (only along the way in or out: not the jump back to the start as it opens)
        const d = Math.abs(cardShift - cardWas);
        if (!still && (enterRun.running || leaveRun.running) && d > px * 4 && d < width * 0.3) {
            cardSmear = cardWas;
            cardSmearA = 1;
            cardSmearOff.restart();
        }
        cardWas = cardShift;
    }
    Timer {
        id: cardSmearOff
        interval: 45
        onTriggered: root.cardSmearA = 0
    }
    P5Plate {
        visible: root.cardSmearA > 0 && card.visible
        opacity: 0.55
        x: card.x + (root.cardSmear + root.cardShift) / 2
        y: card.y
        width: card.width
        height: card.height
        color: root.pal.accent
        shadowX: 0
        shadowY: 0
    }
    // the window's margin round the title, the menu and the search
    readonly property real edge: mode === "wide" ? Math.max(px * 14, Math.round(width * 0.025)) : px * 6
    // the card's empty left field she may lean onto (wide only)
    readonly property real cardField: mode === "wide" ? Math.round(width * 0.06) : 0
    // the widest section name as it is when not picked
    readonly property real catPlainW: {
        let w = 0;
        for (let i = 0; i < catRep.count; i++) {
            const it = catRep.itemAt(i);
            if (it)
                w = Math.max(w, it.plainW);
        }
        return w;
    }
    readonly property real cardX: mode === "wide" ? Math.min(Math.max(catPlainW + edge + px * 24, width * 0.36), width * 0.45) : px * 6
    Item {
        id: card
        transform: Translate {
            x: root.cardShift
        }
        visible: root.mode === "wide" || !root.catsOpen
        x: root.cardX + (1 - bumpQ) * px * 60
        y: Math.max(title.y + title.height, search.y + search.height) + px * 6
        width: (root.mode === "half" ? root.width * 0.86 : root.width - root.cardX) - px * 10
        height: root.height - y - hintBar.height - px * 6
        // never gone: nothing covers the whole card while it changes any more (the silhouette passes)
        opacity: 0.6 + bumpQ * 0.4
        P5Plate {
            anchors.fill: parent
            poly: [[0, height * 0.015], [width, 0], [width - width * 0.012, height], [width * 0.012, height - height * 0.02]]
            tilt: -1.0 + (1 - root.bumpQ) * 6
            color: root.cardPal.paper
            shadow: Theme.dark ? root.pal.accent : root.pal.black
            shadowX: px * 4
            shadowY: px * 4
            rim: root.pal.accent
            rimWidth: px * 1.5
        }

        // her field: hatched, the accent at its end
        Item {
            visible: root.cardField > 0
            x: px * 3
            y: px * 4
            width: root.cardField - px * 3
            height: parent.height - px * 8
            clip: true
            Repeater {
                model: Math.ceil(parent.height / (px * 10))
                Rectangle {
                    required property int index
                    x: -px * 4
                    y: index * px * 10
                    width: parent.width + px * 8
                    height: px * 2
                    rotation: -18
                    color: root.cardPal.paper2
                }
            }
            Rectangle {
                anchors.right: parent.right
                width: px * 1.5
                height: parent.height
                color: root.pal.accent
            }
        }

        // the tabs: Q … E
        Row {
            id: tabRow
            x: px * 10 + root.cardField
            y: px * 7
            width: parent.width - px * 20 - root.cardField
            spacing: px * 2
            visible: !root.query
            Item {
                width: qText.implicitWidth + px * 5
                height: qText.implicitHeight + px * 3
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    color: root.pal.black
                }
                PxText {
                    id: qText
                    font.bold: true
                    anchors.centerIn: parent
                    text: "Q"
                    kind: "tiny"
                    color: root.pal.accent2
                }
            }
            Flickable {
                id: tabFlick
                readonly property real room: parent.width - px * 30
                // (ends on a whole tab: never a tab cut by the card's edge)
                property real whole: room
                function fit() {
                    let w = 0;
                    for (const t of tabInner.children)
                        if (t.modelData !== undefined && t.x + t.width - contentX <= room + 0.5)
                            w = Math.max(w, t.x + t.width - contentX);
                    whole = w > 0 ? w : room;
                }
                onContentXChanged: fit()
                onRoomChanged: fit()
                width: Math.min(tabInner.width, whole)
                height: tabInner.height
                contentWidth: tabInner.width
                clip: true
                interactive: contentWidth > width
                // the picked tab in sight, the strip starting on a tab's edge (never a sliver of one),
                // the tab before it shown too when both fit
                function show(tab) {
                    const tabs = Array.prototype.filter.call(tabInner.children, c => c.modelData !== undefined);
                    const i = tabs.indexOf(tab);
                    let s = tab.x;
                    if (i > 0 && tab.x + tab.width - tabs[i - 1].x <= room)
                        s = tabs[i - 1].x;
                    const most = Math.max(0, contentWidth - room);
                    if (s > most)
                        s = tabs.map(t => t.x).find(x => x >= most - 0.5);
                    contentX = s;
                }
                function showOn() {
                    const tab = Array.prototype.find.call(tabInner.children, c => c.on === true);
                    if (tab)
                        show(tab);
                }
                Row {
                    id: tabInner
                    spacing: px * 2
                    onWidthChanged: {
                        Qt.callLater(tabFlick.showOn);
                        Qt.callLater(tabFlick.fit);
                    }
                    Repeater {
                        model: root.tabs
                        Item {
                            id: tb
                            required property string modelData
                            readonly property bool on: modelData === root.pageId
                            width: tbText.implicitWidth + px * 12
                            height: tbText.implicitHeight + px * 5
                            y: on ? -px * 2 : 0
                            // (later: a new strip's tabs get their places only after this)
                            onOnChanged: if (on)
                                Qt.callLater(tabFlick.showOn)
                            Component.onCompleted: if (on)
                                Qt.callLater(tabFlick.showOn)
                            P5Plate {
                                anchors.fill: parent
                                poly: [[px * 3, 0], [width, 0], [width - px * 3, height], [0, height]]
                                tilt: tb.on ? -3 : 0
                                color: tb.on ? root.cardPal.black : tbMouse.containsMouse ? root.cardPal.paper3 : root.cardPal.paper2
                                shadow: tb.on ? root.pal.accent : "transparent"
                                shadowX: px * 2
                                shadowY: px * 2
                            }
                            PxText {
                                id: tbText
                                kind: "title"
                                anchors.centerIn: parent
                                text: String(root.view.labelOf(tb.modelData)).toUpperCase()
                                color: tb.on ? root.cardPal.paper : root.cardPal.black
                                font.bold: true
                            }
                            MouseArea {
                                id: tbMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.go(tb.modelData);
                                    root.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }
            Item {
                width: eText.implicitWidth + px * 5
                height: eText.implicitHeight + px * 3
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    color: root.pal.black
                }
                PxText {
                    id: eText
                    font.bold: true
                    anchors.centerIn: parent
                    text: "E"
                    kind: "tiny"
                    color: root.pal.accent2
                }
            }
        }
        // the search's heading in place of the tabs
        PxText {
            font.bold: true
            visible: !!root.query
            x: px * 10 + root.cardField
            y: px * 8
            text: root.results.length ? I18n.t("Найдено: ", "Found: ") + root.results.length : I18n.t("Ничего не нашлось", "Nothing found")
            color: root.pal.accent
            kind: "title"
        }

        Flickable {
            id: flick
            x: px * 8 + root.cardField
            y: tabRow.y + tabRow.height + px * 5
            width: parent.width - px * 16 - root.cardField
            height: parent.height - y - px * 6
            contentHeight: rowsCol.height + px * 6
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: rowsCol
                width: flick.width - px * 4
                spacing: px
                Repeater {
                    id: rowsRep
                    model: rowModel
                    P5Row {
                        required property int index
                        // (a row on its way out as the page changes: an empty group, not shown)
                        readonly property var modelData: root.rowLines[index] || ({
                                "t": "group",
                                "g": null
                            })
                        line: modelData.t === "result" ? Object.assign({}, modelData, {
                            "t": "result"
                        }) : modelData
                        width: rowsCol.width
                        selected: index === root.sel
                        pal: root.cardPal
                        order: index
                        enter: root.rowsIn
                        onPick: root.select(index, true)
                        gate: g => root.pointerMoved(g)
                        onMoved: dir => root.angel_flap(dir)
                        onFollow: l => {
                            if (l.result)
                                root.openResult(l.result);
                            else {
                                Shell.settingsGo(root, l.page);
                                if (l.group)
                                    root.view.showGroup(l.group);
                            }
                        }
                    }
                }
            }
        }
        // where the list is
        Rectangle {
            visible: flick.contentHeight > flick.height
            x: flick.x + flick.width + px
            y: flick.y + flick.contentY / flick.contentHeight * flick.height
            width: px * 2
            height: Math.max(px * 8, flick.height * flick.height / flick.contentHeight)
            color: root.cardPal.black
        }
    }
    function angel_flap(dir) {
        snd("value", 0.35);
        angel.flap(dir);
    }

    // a tab or a section swap: the card comes in from the right, the rows slide in after it
    property real bumpT: 1
    readonly property real bumpQ: Math.floor(bumpT * 5) / 5
    property real rowsIn: 1
    function bump() {
        if (still) {
            bumpT = 1;
            rowsIn = 1;
            return;
        }
        bumpRun.restart();
        rowsRun.restart();
    }
    NumberAnimation {
        id: bumpRun
        target: root
        property: "bumpT"
        from: 0
        to: 1
        duration: 340
    }
    NumberAnimation {
        id: rowsRun
        target: root
        property: "rowsIn"
        from: 0
        to: 1
        duration: 260 + Math.min(rowsRep.count, 14) * 45
    }

    // her strip over the card's left edge (P5Doll.front): she breaks the card's frame a little
    Item {
        id: dollFront
        anchors.fill: parent
        opacity: root.dollIn ? 1 : 0
        transform: Translate {
            x: (1 - root.arrive) * root.width * 0.06
            y: (1 - root.arrive) * root.height * 0.3
        }
    }

    // ---- the hint strip ----
    Item {
        id: hintBar
        transform: Translate {
            y: (1 - root.swing(0.62, 0.92)) * root.height * 0.2
        }
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: -px * 4
        anchors.rightMargin: -px * 4
        height: hintText.implicitHeight + px * 8
        P5Plate {
            anchors.fill: parent
            poly: [[0, px * 2], [width, 0], [width, height + px * 4], [0, height + px * 4]]
            color: root.pal.black
            rim: root.pal.accent
            rimWidth: px * 1.5
            shadowX: 0
            shadowY: 0
        }
        PxText {
            id: hintText
            kind: "title"
            font.bold: true
            x: px * 12
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - keysText.width - px * 16
            elide: Text.ElideRight
            text: hint.shown ? "✧ " + hint.shown : ""
            color: root.pal.paper
        }
        PxText {
            id: keysText
            font.bold: true
            visible: root.mode !== "tall"
            anchors.right: parent.right
            anchors.rightMargin: px * 12
            anchors.verticalCenter: parent.verticalCenter
            kind: "body"
            color: Theme.mix(root.pal.paper, root.pal.black, 0.35)
            text: I18n.t("↑↓ выбор   ←→ значение   Q E вкладки   ⇧↑↓ разделы   ESC назад", "↑↓ pick   ←→ value   Q E tabs   ⇧↑↓ sections   ESC back")
        }
    }
    // the hint types itself in
    QtObject {
        id: hint
        property string full: ""
        property int n: 0
        readonly property string shown: full.slice(0, n)
        function say(t) {
            full = t || "";
            n = root.still ? full.length : 0;
            if (!root.still)
                typer.restart();
        }
    }
    Timer {
        id: typer
        interval: 12
        repeat: true
        onTriggered: {
            hint.n += 2;
            if (hint.n >= hint.full.length)
                stop();
        }
    }

    // ---- what she says: a plate over the hint strip, by her side; types in, stays a while ----
    Item {
        id: speech
        property string full: ""
        property string later: ""
        property int n: 0
        property real shownQ: 0
        function show(t) {
            // (coming in: after it, as she has landed)
            if (root.firstFrame || enterRun.running) {
                later = t;
                return;
            }
            full = t;
            n = root.still ? full.length : 0;
            shownQ = 1;
            if (!root.still)
                speechTyper.restart();
            speechAway.interval = 2600 + full.length * 45;
            speechAway.restart();
        }
        visible: shownQ > 0 && full !== ""
        z: 40
        x: root.mode === "half" ? root.width - width - px * 6 : px * 6
        y: hintBar.y - height - px * 6 + (1 - shownQ) * px * 12
        // wide: by her, short of the card; narrower windows: across
        width: root.mode === "wide" ? Math.min(px * 190, root.cardX - px * 10) : Math.min(root.width - px * 12, px * 230)
        height: speechText.implicitHeight + speechName.implicitHeight + px * 12
        P5Plate {
            anchors.fill: parent
            poly: [[px * 3, 0], [width, px * 2], [width - px * 3, height], [0, height - px * 2]]
            color: root.pal.black
            rim: root.pal.accent
            rimWidth: px * 1.5
            shadow: root.pal.accent
            shadowX: px * 3
            shadowY: px * 3
        }
        PxText {
            id: speechName
            x: px * 8
            y: px * 4
            kind: "body"
            font.bold: true
            color: root.pal.accent
            text: angel.who === "angel" ? I18n.t("Ангел", "Angel") : Lines.name(angel.who, I18n.english)
        }
        PxText {
            id: speechText
            x: px * 8
            anchors.top: speechName.bottom
            anchors.topMargin: px * 2
            width: parent.width - px * 16
            wrapMode: Text.Wrap
            kind: "title"
            font.bold: true
            color: root.pal.paper
            text: speech.full.slice(0, speech.n)
        }
    }
    Timer {
        id: speechTyper
        interval: 16
        repeat: true
        onTriggered: {
            speech.n += 1;
            if (speech.n >= speech.full.length)
                stop();
        }
    }
    Timer {
        id: speechAway
        onTriggered: speech.shownQ = 0
    }

    // the cut over everything: a section or a tab changes under it
    P5Slash {
        id: slash
        anchors.fill: parent
        z: 50
        black: root.pal.black
        accent: root.pal.accent
        still: root.still
        sprite: angel.sprite
        eyes: angel.eyeSpots
        eyeR: angel.eyeR
        glow: root.pal.paper
    }

    // the window's corner: resize
    MouseArea {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: px * 8
        height: px * 8
        cursorShape: Qt.SizeFDiagCursor
        onPressed: if (root.view.hostWindow)
            root.view.hostWindow.startSystemResize(Edges.Bottom | Edges.Right)
    }
}
