pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "TimerCore.js" as Core

// Timers, stopwatches and pomodoros, several at once, started from the launcher ("5m чай",
// "секундомер", "помодоро 50/10"; services/TimerCore.js reads the phrase). Everything is wall
// clock time (ends and starts in epoch ms), kept in ~/.local/state/angelos/timers.json: a timer
// survives sleep and a restart of the shell, and one that ended meanwhile still rings. No
// ticking: one Timer waits for the nearest end (at most 15 s, a sleep stops its clock).
// The end: a notification with the harp; under Do not disturb the harp plays anyway.
// The Halo shows them (services/Halo).
Singleton {
    id: root

    // [{id, kind: timer|stopwatch|pomodoro, label, total (ms), end (epoch ms, 0 = paused),
    //   left (ms while paused), start (epoch ms, 0 = paused), acc (ms), laps [ms],
    //   work, rest (minutes), phase: work|rest, round}]
    property var items: []
    property bool loaded: false
    // one ended (the Halo shows it a moment, even over a full-screen game)
    signal rang(string head, string body)
    // a pomodoro's rest began: what to do with it (Wellbeing.restTip, {kind, text}), else null;
    // set before rang, the Halo's card has its button
    property var restTip: null

    function parse(text, bareMinutes) {
        return Core.parse(text, bareMinutes);
    }
    function clock(ms) {
        return Core.clock(ms);
    }
    function human(ms) {
        return Core.human(ms, I18n.english);
    }

    // a timer's time left / a stopwatch's time run, at `now`
    function left(it, now) {
        return it.end ? Math.max(0, it.end - now) : it.left;
    }
    function elapsed(it, now) {
        return it.acc + (it.start ? now - it.start : 0);
    }
    function title(it) {
        const name = it.label ? " — " + it.label : "";
        if (it.kind === "stopwatch")
            return I18n.t("Секундомер", "Stopwatch") + name;
        if (it.kind === "pomodoro")
            return (it.phase === "work" ? I18n.t("Помодоро: работа ", "Pomodoro: work ") : I18n.t("Помодоро: перерыв ", "Pomodoro: break ")) + it.round + name;
        return I18n.t("Таймер ", "Timer ") + human(it.total) + name;
    }
    // what a row in the launcher says about it (no ticking there: the end's clock time)
    function state(it) {
        const now = Date.now();
        if (it.kind === "stopwatch")
            return it.start ? I18n.t("идёт, было ", "running, was ") + clock(elapsed(it, now)) + (it.laps.length ? I18n.t(" · кругов: ", " · laps: ") + it.laps.length : "") : I18n.t("пауза на ", "paused at ") + clock(it.acc);
        return it.end ? I18n.t("закончится в ", "ends at ") + Qt.formatTime(new Date(it.end), "hh:mm:ss") : I18n.t("пауза, осталось ", "paused, left ") + clock(it.left);
    }

    function add(spec) {
        if (!spec)
            return;
        const now = Date.now();
        const it = {
            "id": now + "-" + Math.floor(Math.random() * 1e6),
            "kind": spec.kind,
            "label": spec.label || "",
            "total": 0,
            "end": 0,
            "left": 0,
            "start": 0,
            "acc": 0,
            "laps": []
        };
        if (spec.kind === "stopwatch")
            it.start = now;
        else if (spec.kind === "pomodoro") {
            it.work = spec.work;
            it.rest = spec.rest;
            it.phase = "work";
            it.round = 1;
            it.total = spec.work * 60000;
            it.end = now + it.total;
        } else {
            it.total = spec.ms;
            it.end = now + spec.ms;
        }
        set(items.concat([it]));
    }
    function find(id) {
        return items.find(i => i.id === id) || null;
    }
    function change(id, fn) {
        set(items.map(i => {
            if (i.id !== id)
                return i;
            const c = JSON.parse(JSON.stringify(i));
            fn(c, Date.now());
            return c;
        }));
    }
    function toggle(id) {
        change(id, (it, now) => {
            if (it.kind === "stopwatch") {
                if (it.start) {
                    it.acc += now - it.start;
                    it.start = 0;
                } else
                    it.start = now;
            } else if (it.end) {
                it.left = Math.max(0, it.end - now);
                it.end = 0;
            } else {
                it.end = now + it.left;
                it.left = 0;
            }
        });
    }
    function lap(id) {
        change(id, (it, now) => {
            if (it.kind === "stopwatch")
                it.laps.push(elapsed(it, now));
        });
    }
    function stop(id) {
        set(items.filter(i => i.id !== id));
    }

    function set(list) {
        items = list;
        if (loaded)
            store.write(JSON.stringify(list));
        Qt.callLater(check);
    }

    // ring what has ended, move pomodoros on, wait for the next end
    function check() {
        const now = Date.now();
        let changed = false;
        const next = [];
        for (const it of items) {
            if (it.kind === "stopwatch" || !it.end || it.end > now) {
                next.push(it);
                continue;
            }
            changed = true;
            ring(it, now);
            if (it.kind === "pomodoro") {
                const c = JSON.parse(JSON.stringify(it));
                if (c.phase === "work")
                    c.phase = "rest";
                else {
                    c.phase = "work";
                    c.round++;
                }
                c.total = (c.phase === "work" ? c.work : c.rest) * 60000;
                c.end = now + c.total;
                next.push(c);
            }
        }
        if (changed) {
            items = next;
            store.write(JSON.stringify(next));
        }
        const ends = items.filter(i => i.end).map(i => i.end - now);
        wake.interval = Math.max(50, Math.min(15000, ...ends.concat([15000])));
        wake.restart();
        wake.running = ends.length > 0;
    }
    function ring(it, now) {
        const late = now - it.end > 60000 ? I18n.t(" (закончился в ", " (ended at ") + Qt.formatTime(new Date(it.end), "hh:mm") + ")" : "";
        let head, body;
        restTip = null;
        if (it.kind === "pomodoro") {
            head = it.phase === "work" ? I18n.t("Перерыв ", "Break ") + it.rest + I18n.t(" мин ☕", " min ☕") : I18n.t("За работу ✦ круг ", "Back to work ✦ round ") + (it.round + 1);
            if (it.phase === "work")
                restTip = Wellbeing.restTip();
            body = (restTip ? restTip.text + "\n" : "") + (it.label ? it.label + " · " : "") + I18n.t("остановить: кнопка «Помодоро» в Нимбе", "to stop: the Pomodoro button in the Halo") + late;
        } else {
            head = I18n.t("Время вышло ♡", "Time's up ♡");
            body = I18n.t("Таймер ", "Timer ") + human(it.total) + (it.label ? " — " + it.label : "") + late;
        }
        // Do not disturb (a stream turns it on) hides the card: the harp still rings, as asked
        if (Config.notifications.dnd)
            Sounds.play("harp");
        Quickshell.execDetached(["notify-send", "-a", "angelOS", "-h", "string:x-angelos-sound:harp", "-i", "alarm-symbolic", head, body]);
        rang(head, body);
    }

    Timer {
        id: wake
        onTriggered: root.check()
    }
    Connections {
        target: Shell
        function onResumed() {
            root.check();
        }
    }

    AsyncFile {
        id: store
        path: Config.stateDir + "/timers.json"
        printErrors: false
        onLoaded: {
            try {
                const list = JSON.parse(text());
                if (Array.isArray(list))
                    root.items = list.filter(i => i && i.id && ["timer", "stopwatch", "pomodoro"].includes(i.kind) && Array.isArray(i.laps));
            } catch (e) {}
            root.loaded = true;
            root.check();
        }
        onLoadFailed: {
            root.loaded = true;
        }
    }
}
