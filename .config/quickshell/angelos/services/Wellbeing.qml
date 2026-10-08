pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import "AngelLines.js" as Lines

// Wellbeing (2026-10-08), like GNOME's (and Noctalia's): how long you sit at the computer, a
// daily limit, and the breaks the angel (the demon) reminds you of — the eyes (20-20-20), a
// stretch, a glass of water. Settings → Wellbeing; `angelos wellbeing`.
//
//   counting   while you're there: some input in the last 2 minutes (a playing video keeps it,
//              like the screensaver), not locked, no screensaver. A tick every 15 s; a gap
//              (sleep) never counts. Per day: the total, per hour, per app (the focused window)
//   the file   ~/.local/state/angelos/screen-time.json: {"days": {"2026-10-08": {"s", "h": [24],
//              "apps": {app_id: s}, "water"}}, "run": the break counters across a shell restart}
//   breaks     every kind counts minutes of use since its last break; you away for 20 s rests
//              the eyes, for `moveLength` minutes everything but the water (that one is a glass).
//              Due while a game fills the screen, on stream or with do-not-disturb: it waits
//   who        the angel with two buttons; a notification when she isn't around (or by choice)
Singleton {
    id: root

    readonly property var cfg: Config.wellbeing
    readonly property bool ready: Config.ready && loaded
    property bool loaded: false
    property var days: ({})
    property int rev: 0                      // bumps on every counted tick (the page's charts follow it)

    // you're at the computer right now
    readonly property bool here: !away.isIdle && !Shell.locked && !Idle.active
    readonly property bool counting: ready && cfg.track && here

    // ---- the day ----
    function dayKey(d) {
        return Qt.formatDate(d || new Date(), "yyyy-MM-dd");
    }
    function day(key) {
        rev;
        return days[key || dayKey()] || null;
    }
    readonly property int todaySeconds: {
        rev;
        const d = days[dayKey()];
        return d ? d.s || 0 : 0;
    }
    readonly property int waterToday: {
        rev;
        const d = days[dayKey()];
        return d ? d.water || 0 : 0;
    }
    // the last n days, oldest first: [{key, date, s}]
    function lastDays(n) {
        rev;
        const out = [];
        const t = new Date();
        for (let i = n - 1; i >= 0; i--) {
            const d = new Date(t.getFullYear(), t.getMonth(), t.getDate() - i);
            const k = dayKey(d);
            out.push({
                "key": k,
                "date": d,
                "s": days[k] ? days[k].s || 0 : 0,
                "water": days[k] ? days[k].water || 0 : 0
            });
        }
        return out;
    }
    // the average of the days before today that have any time (up to n of them)
    function average(n) {
        const list = lastDays(n + 1).slice(0, -1).filter(d => d.s > 60);
        return list.length ? Math.round(list.reduce((a, d) => a + d.s, 0) / list.length) : 0;
    }
    function hours(key) {
        const d = day(key);
        const h = d && d.h ? d.h : [];
        const out = [];
        for (let i = 0; i < 24; i++)
            out.push(h[i] || 0);
        return out;
    }
    // [{id, name, s}] the most used apps of a day
    function topApps(key, n) {
        const d = day(key);
        if (!d || !d.apps)
            return [];
        return Object.keys(d.apps).map(id => ({
                    "id": id,
                    "name": appName(id),
                    "s": d.apps[id]
                })).sort((a, b) => b.s - a.s).slice(0, n || 5);
    }
    function appName(id) {
        if (id === "quickshell" || id === "org.quickshell")
            return "angelOS";
        const e = DesktopEntries.heuristicLookup(id);
        return e && e.name ? e.name : String(id).replace(/^.*\./, "");
    }
    // 3725 → "1 ч 2 мин"; under a minute → "0 мин"
    function fmt(s) {
        const m = Math.floor((s || 0) / 60), h = Math.floor(m / 60), r = m % 60;
        if (!h)
            return I18n.t(r + " мин", r + " min");
        return r ? I18n.t(h + " ч " + r + " мин", h + " h " + r + " min") : I18n.t(h + " ч", h + " h");
    }

    // ---- counting ----
    IdleMonitor {
        id: away
        enabled: root.ready
        timeout: 120
        respectInhibitors: true
    }
    // 20 s without input: a look away, the start of a break
    IdleMonitor {
        id: glance
        enabled: root.ready
        timeout: 20
        respectInhibitors: true
        onIsIdleChanged: root._presence()
    }
    Connections {
        target: Shell
        function onLockedChanged() {
            root._presence();
        }
    }

    property double _last: Date.now()
    property int _ticks: 0
    property bool _dirty: false
    Timer {
        interval: 15000
        repeat: true
        running: root.ready
        onTriggered: root.tick()
    }
    function tick() {
        const t = Date.now();
        const dt = (t - _last) / 1000;
        _last = t;
        // a gap (sleep, a frozen shell) is not time at the computer
        if (dt <= 0 || dt > 45)
            return;
        if (counting)
            add(dt);
        if (here && !Shell.setupLocked) {
            _eyes += dt;
            _move += dt;
            _water += dt;
            rev++;
            check();
        }
        if (++_ticks % 4 === 0 && _dirty)
            save();
    }
    function add(dt) {
        const k = dayKey();
        const d = days[k] || {
            "s": 0,
            "h": []
        };
        d.s = (d.s || 0) + dt;
        const h = d.h || [];
        const hr = new Date().getHours();
        for (let i = h.length; i <= hr; i++)
            h.push(0);
        h[hr] += dt;
        d.h = h;
        if (cfg.apps) {
            const w = Niri.focusedWindow;
            const id = String(w && w.app_id || "");
            if (id) {
                d.apps = d.apps || {};
                d.apps[id] = (d.apps[id] || 0) + dt;
            }
        }
        days[k] = d;
        _dirty = true;
        rev++;
    }

    // ---- breaks ----
    property real _eyes: 0                   // seconds of use since the last rest of each kind
    property real _move: 0
    property real _water: 0
    property string asking: ""               // the reminder on screen: eyes | move | water | limit
    property double _askedAt: 0
    property string _pending: ""             // reminded, the break not taken yet: her word when you're back
    property double _awaySince: 0
    property int _limitNext: 0               // today's seconds when the limit speaks again (0: at the limit)
    property string _limitDay: ""

    readonly property var kinds: ["move", "water", "eyes"]   // when two are due, in this order
    function every(kind) {
        return Math.max(5, kind === "eyes" ? cfg.eyesEvery : kind === "move" ? cfg.moveEvery : cfg.waterEvery) * 60;
    }
    function used(kind) {
        return kind === "eyes" ? _eyes : kind === "move" ? _move : _water;
    }
    function setUsed(kind, v) {
        v = Math.max(0, v);
        if (kind === "eyes")
            _eyes = v;
        else if (kind === "move")
            _move = v;
        else
            _water = v;
        _dirty = true;
    }
    // minutes till the next reminder of a kind (the page shows it)
    function dueIn(kind) {
        rev;
        return Math.max(0, Math.ceil((every(kind) - used(kind)) / 60));
    }

    // a reminder waits: a game or a video on the whole screen, the stream, do-not-disturb
    readonly property string quietWhy: {
        if (Shell.locked || Idle.active || Shell.setupLocked)
            return "away";
        if (cfg.quietStream && StreamMode.active)
            return "stream";
        if (cfg.quietDnd && Config.notifications.dnd)
            return "dnd";
        if (cfg.quietFullscreen && Shell.fullscreenOn(Niri.focusedOutput))
            return "fullscreen";
        return "";
    }

    function check() {
        // the one on screen goes by itself after two minutes unanswered
        if (asking && Date.now() - _askedAt > 120000)
            asking = "";
        if (asking || quietWhy)
            return;
        if (cfg.dailyLimit > 0 && cfg.limitWarn) {
            const k = dayKey();
            if (_limitDay !== k) {
                _limitDay = k;
                _limitNext = 0;
            }
            const at = Math.max(cfg.dailyLimit * 60, _limitNext);
            if (todaySeconds >= at)
                return remind("limit");
        }
        if (!cfg.breaks)
            return;
        for (const k of kinds)
            if (cfg[k] && used(k) >= every(k))
                return remind(k);
    }

    readonly property bool angelHere: cfg.via === "angel" && Angel.present && !Angel.transition
    function lines(kind) {
        const set = Angel.demon ? Lines.wellbeing.demon : Lines.wellbeing.angel;
        return set[kind] || [];
    }
    function text(kind) {
        const l = lines(kind);
        if (!l.length)
            return "";
        const s = Story.render(Angel.line(l, "wb-" + kind + Angel.demon));
        const sat = kind === "limit" || kind === "limitAgain" ? todaySeconds : _move;
        return s.replace(/%t/g, fmt(sat)).replace(/%n/g, String(waterToday)).replace(/%g/g, String(cfg.waterGoal));
    }
    function title(kind) {
        return kind === "eyes" ? I18n.t("Отдых для глаз", "Rest your eyes") : kind === "move" ? I18n.t("Перерыв", "Take a break") : kind === "water" ? I18n.t("Попей воды", "Drink some water") : I18n.t("Экранное время", "Screen time");
    }
    function buttons(kind) {
        if (kind === "limit")
            return [
                {
                    "id": "more",
                    "label": I18n.t("Ещё 15 минут", "15 more minutes"),
                    "icon": "clock"
                },
                {
                    "id": "done",
                    "label": I18n.t("Хватит на сегодня", "Done for today"),
                    "icon": "power"
                }
            ];
        return [
            {
                "id": "done",
                "label": kind === "water" ? I18n.t("Попил{g:|а|и} ♡", "Done ♡") : kind === "move" ? I18n.t("Иду!", "Going!") : I18n.t("Смотрю вдаль", "Looking away"),
                "icon": kind === "water" ? "drop" : "heart"
            },
            {
                "id": "later",
                "label": I18n.t("Через 10 мин", "In 10 min"),
                "icon": "clock"
            }
        ];
    }

    // forced: from the page's «Проверить» (the reminder now, whatever the timers say)
    function remind(kind, forced) {
        const again = kind === "limit" && _limitNext > 0;
        const msg = text(again ? "limitAgain" : kind);
        if (!msg)
            return;
        // she's busy talking: the next tick
        if (angelHere && !forced && (Angel.talking || Angel.menuOpen))
            return;
        asking = kind;
        _askedAt = Date.now();
        // left unanswered: the eyes start over, the rest come back in 15 / 20 minutes (a try
        // from Settings leaves the timers be)
        if (!forced) {
            if (kind === "eyes")
                setUsed("eyes", 0);
            else if (kind === "move")
                setUsed("move", every("move") - 15 * 60);
            else if (kind === "water")
                setUsed("water", every("water") - 20 * 60);
            else
                _limitNext = Math.floor(todaySeconds) + 15 * 60;
        }
        if (kind !== "limit" && !forced)
            _pending = kind;
        const bs = buttons(kind).map(b => Object.assign({}, b, {
                "label": Story.render(b.label)
            }));
        if (angelHere) {
            Angel.say(msg, bs.map(b => ({
                        "label": b.label,
                        "icon": b.icon,
                        "run": () => root.answer(kind, b.id)
                    })), kind === "eyes" ? 25000 : 60000);
            return;
        }
        notify.kind = kind;
        notify.command = ["notify-send", "-a", "angelOS", "--wait", "-t", "60000", "-h", "string:x-angelos-sound:notify", "-i", Quickshell.shellDir + "/data/icons/" + (kind === "water" ? "water.svg" : "wellbeing.svg")].concat(bs.flatMap(b => ["-A", b.id + "=" + b.label])).concat([title(kind), msg]);
        notify.running = false;
        notify.running = true;
    }
    Process {
        id: notify
        property string kind: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const a = text.trim();
                if (a)
                    root.answer(notify.kind, a);
                else if (root.asking === notify.kind)
                    root.asking = "";
            }
        }
    }

    function answer(kind, id) {
        asking = "";
        if (kind === "limit") {
            if (id === "done") {
                _limitNext = Math.floor(todaySeconds) + 60 * 60;
                Shell.sessionOpen = true;
            }
            return;
        }
        if (id === "later") {
            setUsed(kind, every(kind) - 10 * 60);
            _pending = "";
            return;
        }
        setUsed(kind, 0);
        if (kind === "water")
            drink();
        else if (kind === "move")
            Achievements.note("wellbeing.break", "move");
    }
    // a glass of water: +1 today (the page's button, the reminder's, `angelos wellbeing water`)
    function drink() {
        const k = dayKey();
        const d = days[k] || {
            "s": 0,
            "h": []
        };
        d.water = (d.water || 0) + 1;
        days[k] = d;
        setUsed("water", 0);
        _pending = "";
        rev++;
        save();
        Achievements.note("wellbeing.water");
        if (angelHere && Angel.present) {
            const goal = d.water === cfg.waterGoal;
            Angel.say(text(goal ? "goal" : "waterDone"), null, 0, true);
        }
    }
    function undrink() {
        const d = days[dayKey()];
        if (!d || !d.water)
            return;
        d.water--;
        rev++;
        save();
    }

    // away and back: 20 s rest the eyes; moveLength minutes, a whole break
    function _presence() {
        const gone = glance.isIdle || Shell.locked || Idle.active;
        if (gone) {
            if (!_awaySince)
                _awaySince = Date.now() - (glance.isIdle ? 20000 : 0);
            return;
        }
        if (!_awaySince)
            return;
        const was = (Date.now() - _awaySince) / 1000;
        _awaySince = 0;
        if (was >= 20) {
            setUsed("eyes", 0);
            if (_pending === "eyes") {
                _pending = "";
                Achievements.note("wellbeing.break", "eyes");
                if (angelHere)
                    Qt.callLater(() => Angel.say(text("eyesDone"), null, 4000, true));
            }
        }
        if (was >= cfg.moveLength * 60) {
            setUsed("eyes", 0);
            setUsed("move", 0);
            if (_pending === "move") {
                _pending = "";
                Achievements.note("wellbeing.break", "move");
                if (angelHere)
                    backSoon.restart();
            }
        }
    }
    Timer {
        id: backSoon
        interval: 4000
        onTriggered: if (root.angelHere && !Angel.talking)
            Angel.say(root.text("moveDone"), null, 0, true)
    }

    // ---- the file ----
    readonly property string path: Config.stateDir + "/screen-time.json"
    AsyncFile {
        id: file
        path: root.path
        printErrors: false
        onLoaded: {
            try {
                const j = JSON.parse(text());
                root.days = j.days || {};
                const r = j.run || {};
                // the counters go on across a shell restart, not across a night
                if (Date.now() - (r.at || 0) < 10 * 60000) {
                    root._eyes = r.eyes || 0;
                    root._move = r.move || 0;
                    root._water = r.water || 0;
                }
            } catch (e) {
                root.days = {};
            }
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }
    function save() {
        if (!loaded)
            return;
        const keep = Math.max(7, cfg.keepDays || 60);
        const oldest = dayKey(new Date(Date.now() - keep * 86400000));
        const out = {};
        for (const k of Object.keys(days).sort()) {
            if (k < oldest)
                continue;
            const d = days[k];
            const r = {
                "s": Math.round(d.s || 0),
                "h": (d.h || []).map(x => Math.round(x))
            };
            if (d.water)
                r.water = d.water;
            if (d.apps) {
                // the 30 most used of the day; the rest is noise
                r.apps = {};
                for (const id of Object.keys(d.apps).sort((a, b) => d.apps[b] - d.apps[a]).slice(0, 30))
                    r.apps[id] = Math.round(d.apps[id]);
            }
            out[k] = r;
        }
        file.write(JSON.stringify({
            "version": 1,
            "days": out,
            "run": {
                "at": Date.now(),
                "eyes": Math.round(_eyes),
                "move": Math.round(_move),
                "water": Math.round(_water)
            }
        }));
        _dirty = false;
    }
    // Settings → «Стереть историю»
    function clear() {
        days = {};
        rev++;
        save();
    }
    Component.onDestruction: if (_dirty)
        save()

    // `angelos wellbeing` (status) | water | unwater | test eyes|move|water|limit | clear
    function status() {
        return JSON.stringify({
            "today": fmt(todaySeconds),
            "todaySeconds": Math.round(todaySeconds),
            "here": here,
            "water": waterToday + "/" + cfg.waterGoal,
            "next": {
                "eyes": cfg.eyes ? dueIn("eyes") : null,
                "move": cfg.move ? dueIn("move") : null,
                "water": cfg.water ? dueIn("water") : null
            },
            "quiet": quietWhy,
            "asking": asking,
            "via": angelHere ? "angel" : "notify",
            "apps": topApps(dayKey(), 5).map(a => a.name + " " + fmt(a.s))
        });
    }
}
