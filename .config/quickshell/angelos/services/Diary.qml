pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../novel/NovelCore.js" as Core

// The Angel's diary: a book a thing opens (story/items.json → "opens": "diary", the key the
// achievement "Six windows in a row" leaves in its card). Its pages are story/diary.json:
// each is written once its achievement is earned (`after`) and its condition holds (`when`,
// the achievements' conditions: services/Achievements → ctx, fns); the rest show as torn out,
// or not at all (`secret`). The book is modules/diary/DiaryBook (Shell.diaryOpen).
//
//   adding story  the owner's page «Дневник: редактор» (owner/DiaryAdmin), or the file by
//                 hand: the shell reloads it at once; «Опубликовать» ships it
//   the save      ~/.config/angelos/save.json → achievements.diary {read: {page: ms},
//                 seen: {page: ms}} — what was read, which new pages were announced
//   the game off  every page is open (all of heaven is), nothing is noted
//   watch         it is HER diary: read it while she is away (Angel.away — she leaves the screen
//                 now and then for a few minutes, story/diary.json → watch). Opened in front of
//                 her, or still open when she is back: caught — she takes it, is hurt, her trust
//                 goes down by the times caught (1, 2, 3…), the first time she hides it in
//                 Settings (the bookmark goes; Settings → Achievements → Things still opens it).
//                 Trust (Story.player.trust, `trust` in conditions) crossing a mark chills her.
//   `angelos diary open [page] | close | list | validate | read-reset | away [min] | back |
//   trust [reset]` (modules/Ipc)
Singleton {
    id: root

    property var doc: ({})
    property bool loaded: false
    property string loadError: ""
    // the owner's preview: every page written (owner/DiaryAdmin, `angelos diary preview on`)
    property bool preview: false

    readonly property var pages: (Array.isArray(doc.pages) ? doc.pages : []).filter(p => p && typeof p.id === "string" && p.id !== "")
    readonly property string thingId: doc.thing || Heaven.thingFor("diary")
    readonly property var thing: Heaven.thing(thingId)
    // the key is had (the game off: everything is)
    readonly property bool owned: !!thing && Heaven.has(thingId)
    // where the cover opens: the player's pick, else the author's
    readonly property string side: Config.game.diarySide === "left" || Config.game.diarySide === "right" ? Config.game.diarySide : doc.side === "left" ? "left" : "right"

    readonly property var state: Story.feats && Story.feats.diary ? Story.feats.diary : ({})
    readonly property var readMarks: state.read || ({})

    function title() {
        return I18n.label(doc.title) || I18n.t("Дневник Ангела", "The Angel's Diary");
    }
    function subtitle() {
        return I18n.label(doc.subtitle) || "";
    }

    // ---- which pages are written ----
    // `after` earned and `when` true; no game: all of them
    function written(p, vars) {
        if (!p)
            return false;
        if (preview || !Story.enabled)
            return true;
        if (p.after && !Achievements.has(p.after))
            return false;
        if (p.when) {
            try {
                return Core.evalCond(p.when, vars || Achievements.ctx(), [], Achievements.fns);
            } catch (e) {
                return false;
            }
        }
        return true;
    }
    // re-read on every tick of the check below (conditions change without a signal)
    property int tick: 0
    readonly property var openIds: {
        tick;
        Achievements.got;
        const v = Story.enabled ? Achievements.ctx() : ({});
        return pages.filter(p => written(p, v)).map(p => p.id);
    }
    // the pages the book shows: written ones, and the torn-out places of the rest that aren't secret
    readonly property var shown: pages.filter(p => openIds.includes(p.id) || !p.secret)
    readonly property int unread: openIds.filter(id => !readMarks[id]).length
    function isOpen(id) {
        return openIds.includes(id);
    }
    function page(id) {
        return pages.find(p => p.id === id) || null;
    }
    function lockText(p) {
        return I18n.label(p && p.hint) || I18n.label(doc.locked) || I18n.t("Эта страница ещё не написана", "This page is not written yet");
    }
    function text(p, key) {
        return p ? Story.render(p[key] || "") : "";
    }

    // ---- reading ----
    function markRead(id) {
        if (!Story.enabled || !Story.ready || !isOpen(id) || readMarks[id])
            return;
        const s = Object.assign({}, state);
        s.read = Object.assign({}, readMarks);
        s.read[id] = Date.now();
        Story.feats.diary = s;
        Achievements.note("diary.page", id);
    }
    function resetRead() {
        if (Story.feats)
            Story.feats.diary = ({});
    }

    // ---- the book ----
    // the page to open at: the first unread written one, else the last one read
    property string startAt: ""
    function open(at) {
        if (!owned && !preview)
            return false;
        if (watching) {
            // in front of her: the first time she takes it before it opens and hides it
            if (!hidden) {
                caught("open");
                return false;
            }
            caught("again");
        } else if (Story.enabled && Angel.away)
            Achievements.note("diary.sneak");
        startAt = at || "";
        Shell.diaryOpen = true;
        Achievements.note("diary.open", Theme.hell ? "hell" : "heaven");
        return true;
    }
    function close() {
        Shell.diaryOpen = false;
    }

    // ---- reading behind her back ----
    readonly property var rules: doc.watch || ({})
    readonly property var player: Story.player || ({})
    // she would see it: the game on, the angel (not the demon in hell, not in limbo), not away
    readonly property bool watching: sees(Angel.away)
    // read fresh, not through `watching`: on Angel.awayChanged that binding may not have caught up
    function sees(away) {
        return Story.enabled && Story.ready && !preview && !Angel.demon && !Story.limbo && !away;
    }
    readonly property bool hidden: Story.enabled && !!player.diaryHidden
    readonly property int trustStart: Number(rules.trust) > 0 ? Number(rules.trust) : 10
    readonly property int trust: player.trust === undefined || player.trust < 0 ? trustStart : player.trust
    readonly property int caughtTimes: player.diaryCaught || 0
    // her steps: the last seconds of her walk (the book warns)
    property bool returningSoon: false
    property double lastCaught: 0

    function sayLine(kind, ms) {
        const list = (doc.lines || {})[kind] || [];
        if (!list.length)
            return;
        const l = list[Math.floor(Math.random() * list.length)];
        Angel.say(Story.render(l), null, ms || 0);
    }
    function caught(kind) {
        const first = !player.diaryHidden;
        const n = caughtTimes + 1;
        Story.player.diaryCaught = n;
        Story.player.diaryHidden = true;
        loseTrust(n);
        lastCaught = Date.now();
        Achievements.note("diary.caught", kind);
        // she takes it: the book shuts
        if (kind !== "again")
            Shell.diaryOpen = false;
        Angel.hush();
        sayLine(first ? "caught" : "caughtAgain", 9000);
        tick++;
    }
    function loseTrust(n) {
        const was = trust;
        const now = Math.max(0, was - n);
        Story.player.trust = now;
        const marks = Array.isArray(rules.chillAt) ? rules.chillAt.map(Number) : [6, 3, 0];
        const crossed = Array.from(player.trustMarks || []);
        let chill = 0;
        for (const m of marks)
            if (was > m && now <= m && !crossed.includes(m)) {
                crossed.push(m);
                chill++;
            }
        if (chill) {
            Story.player.trustMarks = crossed;
            Story.chillBy(chill);
        }
    }

    // her walks: planned once the key is had, never in hell, limbo or the game off
    readonly property bool walks: Story.enabled && Story.ready && owned && !preview && !Angel.demon && !Story.limbo
    function minutesBetween() {
        const r = Array.isArray(rules.everyMinutes) && rules.everyMinutes.length === 2 ? rules.everyMinutes.map(Number) : [12, 35];
        return r[0] + Math.random() * Math.max(0, r[1] - r[0]);
    }
    function awayMinutes() {
        const l = Array.isArray(rules.awayMinutes) && rules.awayMinutes.length ? rules.awayMinutes.map(Number).filter(x => x > 0) : [1, 3, 5, 10];
        return l[Math.floor(Math.random() * l.length)] || 3;
    }
    function planWalk(minutes) {
        walkTimer.interval = Math.max(10000, Math.round((minutes || minutesBetween()) * 60000));
        walkTimer.restart();
    }
    onWalksChanged: walks ? planWalk() : walkTimer.stop()
    Timer {
        id: walkTimer
        onTriggered: {
            if (!root.walks || Angel.away)
                return;
            // not mid-word, mid-show, locked, or while the book lies open in front of her
            if (Angel.transition || Angel.menuOpen || Angel.talking || Shell.locked || Shell.diaryOpen) {
                root.planWalk(1);
                return;
            }
            root.leave(root.awayMinutes());
        }
    }
    // she goes: a word first (if she is on screen), then off the screen for `minutes`
    function leave(minutes) {
        if (!Story.enabled || Angel.demon || Angel.away)
            return false;
        walkTimer.stop();
        pendingMinutes = minutes;
        if (Angel.shown) {
            sayLine("leave", 3500);
            goTimer.restart();
        } else
            goNow();
        return true;
    }
    property real pendingMinutes: 0
    Timer {
        id: goTimer
        interval: 3600
        onTriggered: root.goNow()
    }
    function goNow() {
        const ms = Math.max(5000, Math.round(pendingMinutes * 60000));
        Angel.hush();
        Angel.awayUntil = Date.now() + ms;
        backTimer.interval = ms;
        backTimer.restart();
        const warn = Math.max(0, Number(rules.warnSeconds) || 10) * 1000;
        stepsTimer.interval = Math.max(1, ms - warn);
        stepsTimer.restart();
        returningSoon = false;
    }
    Timer {
        id: stepsTimer
        onTriggered: root.returningSoon = true
    }
    Timer {
        id: backTimer
        onTriggered: Angel.awayUntil = 0
    }
    // back (her time is up, or called back): what she sees
    Connections {
        target: Angel
        function onAwayChanged() {
            if (Angel.away)
                return;
            goTimer.stop();
            backTimer.stop();
            stepsTimer.stop();
            root.returningSoon = false;
            Angel.now = Date.now();
            if (Shell.diaryOpen && root.sees(false))
                root.caught("back");
            else
                Qt.callLater(() => root.sayLine("back", 4500));
            if (root.walks)
                root.planWalk();
        }
    }
    // the owner's testing: trust and the hiding place back as new
    function resetTrust() {
        Story.player.trust = -1;
        Story.player.diaryCaught = 0;
        Story.player.diaryHidden = false;
        Story.player.trustMarks = [];
    }

    // ---- new pages: once the key is had, a page that gets written is announced ----
    Timer {
        running: Story.enabled && Story.ready && root.loaded
        interval: 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Connections {
        target: Achievements
        function onGotChanged() {
            refreshSoon.restart();
        }
    }
    Timer {
        id: refreshSoon
        interval: 1500
        onTriggered: root.refresh()
    }
    function refresh() {
        tick++;
        if (!Story.enabled || !Story.ready || preview)
            return;
        const seen = Object.assign({}, state.seen || {});
        const first = !Object.keys(seen).length;
        const fresh = openIds.filter(id => !seen[id]);
        if (!fresh.length)
            return;
        for (const id of fresh)
            seen[id] = Date.now();
        const s = Object.assign({}, state);
        s.seen = seen;
        Story.feats.diary = s;
        // the first pages come with the key (its own card says so); later ones get a card
        if (owned && !first)
            Achievements.announceDiary(fresh.map(id => page(id)).filter(p => p));
    }

    // ---- the file ----
    readonly property string file: Quickshell.shellDir + "/story/diary.json"
    FileView {
        id: view
        path: root.file
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.doc = JSON.parse(text());
                root.loadError = "";
            } catch (e) {
                root.loadError = String(e);
                console.warn("story/diary.json: " + e);
            }
            root.loaded = true;
            root.tick++;
        }
        onLoadFailed: root.loaded = true
    }
    // what is wrong with a diary (the owner's page, `angelos diary validate`, the self-test)
    function problems(d) {
        const out = [];
        const seen = {};
        if (d.side && d.side !== "left" && d.side !== "right")
            out.push(I18n.t("side: left или right", "side: left or right"));
        if (d.thing && !Heaven.thing(d.thing))
            out.push(I18n.t("нет такой вещи: ", "no such thing: ") + d.thing);
        for (const p of Array.isArray(d.pages) ? d.pages : []) {
            const id = p && p.id;
            if (!id || typeof id !== "string" || !/^[a-z0-9][a-z0-9._-]*$/.test(id)) {
                out.push(I18n.t("плохой id: ", "bad id: ") + JSON.stringify(id));
                continue;
            }
            if (seen[id])
                out.push(id + I18n.t(": id повторяется", ": the id is used twice"));
            seen[id] = true;
            if (!I18n.label(p.text))
                out.push(id + I18n.t(": нет текста", ": no text"));
            if (p.after && !Achievements.find(p.after))
                out.push(id + I18n.t(": нет такого достижения ", ": no such achievement ") + p.after);
            if (p.when) {
                const e = Achievements.condError(p.when);
                if (e)
                    out.push(id + I18n.t(": условие: ", ": condition: ") + e);
            }
            if (p.hand && p.hand !== "angel" && p.hand !== "demon")
                out.push(id + ": hand: angel | demon");
        }
        return out;
    }
    function saveData(d) {
        const bad = problems(d);
        if (bad.length)
            return bad;
        view.setText(JSON.stringify(d, null, 2) + "\n");
        doc = JSON.parse(JSON.stringify(d));
        tick++;
        return [];
    }
    function listText() {
        return pages.map(p => (isOpen(p.id) ? (readMarks[p.id] ? "✓ " : "• ") : "· ") + p.id + "  " + (I18n.label(p.title) || "") + (p.after ? "  after " + p.after : "") + (p.when ? "  when " + p.when : "") + (p.secret ? " (secret)" : "")).join("\n") + "\n\n✓ read · • written, unread · · not yet";
    }
}
