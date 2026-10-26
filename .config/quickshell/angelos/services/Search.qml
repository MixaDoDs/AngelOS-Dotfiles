pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// One search for the launcher, every Start look and Spotlight: apps, settings, files, actions
// (the niri keys with their titles and the key itself, Start's power buttons), the calculator,
// timers, an open vault's logins. A word is understood in the other layout ("ыеуфь" → steam),
// transliterated ("телеграм" → telegram, "nastrojki" → настройки) and with one typo; the row
// chosen for some words comes first for them next time (search-learn.json, local only).
//
// Rows: {kind: app|setting|file|action|calc|timer|timerItem|vault, id, title, sub, icon, key,
// run(), keep, s (0…1, the calculator and a spelled-out timer 2)} + app/doc/file/calc/spec/item/
// vault — and the launcher's own fields (builtin, r) so it shows them as they are.
Singleton {
    id: root

    // ---- words ----
    function norm(s) {
        return String(s || "").trim().toLowerCase().replace(/ё/g, "е");
    }
    readonly property var _ru2lat: ({
            "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ж": "zh", "з": "z", "и": "i", "й": "j", "к": "k", "л": "l", "м": "m",
            "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ф": "f", "х": "h", "ц": "c", "ч": "ch", "ш": "sh", "щ": "sch",
            "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya"
        })
    readonly property var _lat2ru: [["sch", "щ"], ["sh", "ш"], ["ch", "ч"], ["zh", "ж"], ["kh", "х"], ["ts", "ц"], ["yu", "ю"], ["ya", "я"], ["yo", "е"], ["ck", "к"], ["ph", "ф"], ["a", "а"], ["b", "б"], ["c", "к"], ["d", "д"], ["e", "е"], ["f", "ф"], ["g", "г"], ["h", "х"], ["i", "и"], ["j", "й"], ["k", "к"], ["l", "л"], ["m", "м"], ["n", "н"], ["o", "о"], ["p", "п"], ["q", "к"], ["r", "р"], ["s", "с"], ["t", "т"], ["u", "у"], ["v", "в"], ["w", "в"], ["x", "кс"], ["y", "ы"], ["z", "з"]]
    function translit(q) {
        if (/[а-я]/.test(q))
            return q.split("").map(ch => _ru2lat[ch] !== undefined ? _ru2lat[ch] : ch).join("");
        let out = "";
        for (let i = 0; i < q.length;) {
            const p = _lat2ru.find(x => q.startsWith(x[0], i));
            out += p ? p[1] : q[i];
            i += p ? p[0].length : 1;
        }
        return out;
    }
    // the query as typed, in the other layout (only when every key maps), transliterated
    function variants(q) {
        const out = [q];
        const sw = SettingsSearch.swapLayout(q);
        if (sw.replace(/\s/g, "").length === q.replace(/\s/g, "").length && /^[a-zа-я0-9 ]+$/.test(sw))
            out.push(sw);
        const tr = translit(q);
        if (/^[a-zа-я0-9 .+-]+$/.test(q))
            out.push(tr);
        return out.filter((v, i) => v && out.indexOf(v) === i);
    }
    // how well v matches the text t (both lower case): 1 its start … 0.3 its letters in order
    function textScore(t, v) {
        if (!t || !v)
            return 0;
        if (t.startsWith(v))
            return 1 - Math.min(0.04, t.length / 1000);
        const i = t.indexOf(v);
        if (i > 0)
            return /[\s\-_.]/.test(t[i - 1]) ? 0.9 : 0.8;
        if (v.length >= 4)
            for (const w of t.split(/[\s\-_.]+/))
                if (SettingsSearch.withinOne(v, w) || w.length > v.length && SettingsSearch.withinOne(v, w.slice(0, v.length)))
                    return 0.6;
        let k = 0;
        for (const ch of t)
            if (ch === v[k])
                k++;
        return k === v.length ? 0.3 : 0;
    }
    function best(t, vs, extra) {
        let s = 0;
        for (let i = 0; i < vs.length; i++) {
            const k = i === 0 ? 1 : 0.95;
            s = Math.max(s, textScore(t, vs[i]) * k);
            if (extra && vs[i].length >= 2 && extra.includes(vs[i]))
                s = Math.max(s, 0.55 * k);
        }
        return s;
    }

    // ---- learning: the words typed → the row chosen ----
    property var learned: ({})         // words → {id: [times, last ms]}
    property var _last: ({
            "q": "",
            "at": 0,
            "ids": []
        })
    function bonuses(q) {
        const out = {}, now = Date.now();
        for (const k in learned) {
            if (k !== q && !(q.length >= 2 && k.startsWith(q)))
                continue;
            const w = k === q ? 1 : 0.5;
            for (const id in learned[k]) {
                const e = learned[k][id];
                out[id] = (out[id] || 0) + e[0] * w * Math.pow(0.9, (now - e[1]) / 604800000);
            }
        }
        for (const id in out)
            out[id] = Math.min(0.3, out[id] * 0.06);
        return out;
    }
    // a row was opened: remembered for the query it was found by (a minute ago at most)
    function chosen(id) {
        const l = _last;
        if (!l.q || Date.now() - l.at > 60000 || !l.ids.includes(id))
            return;
        const all = Object.assign({}, learned);
        const e = Object.assign({}, all[l.q] || {});
        e[id] = [((e[id] || [0])[0]) + 1, Date.now()];
        all[l.q] = e;
        const keys = Object.keys(all);
        if (keys.length > 400)
            for (const k of keys.sort((a, b) => Math.max(...Object.values(all[a]).map(x => x[1])) - Math.max(...Object.values(all[b]).map(x => x[1]))).slice(0, keys.length - 400))
                delete all[k];
        learned = all;
        saver.restart();
    }
    FileView {
        id: learnFile
        path: Quickshell.env("HOME") + "/.local/state/angelos/search-learn.json"
        printErrors: false
        onLoaded: {
            try {
                root.learned = JSON.parse(text()) || {};
            } catch (e) {
                root.learned = {};
            }
        }
    }
    Timer {
        id: saver
        interval: 1500
        onTriggered: learnFile.setText(JSON.stringify(root.learned))
    }

    // ---- actions: Start's power buttons and the niri keys that have a title ----
    function keyOf(call) {
        const b = Keybinds.binds.find(x => callOf(x.action) === call);
        return b ? Keybinds.pretty(b.key) : "";
    }
    function callOf(action) {
        const m = String(action).match(/(?:ipc call angelos|bin\/angelos) (\S+)/);
        return m ? m[1].replace(/"$/, "") : "";
    }
    function runBind(action) {
        const a = Keybinds.args(action);
        later.run = a[0] === "spawn-sh" ? ["sh", "-c", a[1]] : a[0] === "spawn" ? a.slice(1) : ["niri", "msg", "action"].concat(a);
        later.restart();
    }
    // after the search's own window is gone: a screenshot must not catch it
    Timer {
        id: later
        property var run: []
        interval: 180
        onTriggered: Quickshell.execDetached(run)
    }
    readonly property var actions: {
        const out = [];
        const calls = {
            "lock": "lock",
            "power": "session"
        };
        for (const id of ["lock", "sleep", "reboot", "logout", "power", "idle"]) {
            const b = StartItems.buttons[id];
            out.push({
                "id": "act:" + id,
                "title": b.row || b.label,
                "icon": b.icon,
                "key": calls[id] ? keyOf(calls[id]) : "",
                "run": b.run
            });
        }
        out.push({
            "id": "act:tour",
            "title": I18n.t("Как тут всё устроено — тур", "How it all works: the tour"),
            "icon": "info",
            "key": "",
            "run": () => Tour.start()
        });
        const skip = ["lock", "session", "alttab", "lens"];
        for (const b of Keybinds.binds) {
            if (!b.title || skip.includes(callOf(b.action)) || Keybinds.describe(b).appId)
                continue;
            let t = String(b.title).replace(/^angelOS:\s*/, "");
            t = t.charAt(0).toUpperCase() + t.slice(1);
            if (out.some(x => x.title === t))
                continue;
            const action = b.action;
            out.push({
                "id": "act:" + t,
                "title": t,
                "icon": Keybinds.describe(b).icon,
                "key": Keybinds.pretty(b.key),
                "run": () => root.runBind(action)
            });
        }
        return out.map(a => Object.assign(a, {
                "words": norm(a.title)
            }));
    }

    // ---- the search ----
    readonly property var apps: StartApps.apps
    function row(kind, id, title, sub, icon, s, run, more) {
        return Object.assign({
            "kind": kind,
            "builtin": kind === "app" ? undefined : kind,
            "id": id,
            "title": title,
            "sub": sub,
            "icon": icon,
            "s": s,
            "run": run,
            "r": {
                "title": title,
                "subtitle": sub,
                "icon": icon
            }
        }, more || {});
    }
    // opts: {settings: false} leaves settings out, {files: n} how many files (default 8, 0 none)
    function query(text, limit, opts) {
        Timers.items;
        Vault.tick;
        const o = opts || {};
        const raw = String(text || "").trim();
        const q = norm(raw);
        if (!q)
            return [];
        const vs = variants(q);
        const bonus = bonuses(q);
        const usage = Config.launcher.usage || {};
        const rows = [];
        // the calculator first (2+2, 10 km in mi), a timer spelled out ("5m чай", "помодоро")
        const calc = Calc.evaluate(raw);
        if (calc)
            rows.push(row("calc", "", calc.title, calc.subtitle || I18n.t("Enter — скопировать", "Enter copies"), "calc", 2, () => Calc.copy(calc), {
                "calc": calc
            }));
        const tm = Timers.parse(raw);
        if (tm)
            rows.push(row("timer", "", tm.kind === "stopwatch" ? I18n.t("Запустить секундомер", "Start a stopwatch") : tm.kind === "pomodoro" ? I18n.t("Помодоро ", "Pomodoro ") + tm.work + "/" + tm.rest + I18n.t(" мин", " min") : I18n.t("Таймер на ", "Timer for ") + Timers.human(tm.ms), (tm.label ? tm.label + " · " : "") + I18n.t("Enter — запустить", "Enter to start"), "clock",
                // a bare "5m" below the apps (an app called «1С»), the words above all
                tm.kind !== "timer" || tm.said ? 2 : 0.99, () => Timers.add(tm), {
                "spec": tm
            }));
        if (/^(таймер|timer|секундомер|stopwatch|помодоро|pomodoro)/.test(q))
            for (const it of Timers.items)
                rows.push(row("timerItem", "", Timers.title(it), Timers.state(it) + " · " + ((it.kind === "stopwatch" ? it.start : it.end) ? I18n.t("Enter — пауза", "Enter: pause") : I18n.t("Enter — дальше", "Enter: resume")) + (it.kind === "stopwatch" ? I18n.t(", Shift+Enter — круг", ", Shift+Enter: lap") : "") + I18n.t(", Ctrl+Enter — убрать", ", Ctrl+Enter: remove"), it.kind === "pomodoro" && it.phase === "rest" ? "coffee" : (it.kind === "stopwatch" ? it.start : it.end) ? "play" : "pause", 1.9, () => Timers.toggle(it.id), {
                    "item": it,
                    "keep": true
                }));
        // apps: the name, then generic name / keywords / id; the often opened a bit higher
        for (const a of apps) {
            const sc = best(String(a.name || "").toLowerCase(), vs, ((a.genericName || "") + " " + String(a.keywords || "") + " " + (a.id || "")).toLowerCase());
            if (sc <= 0)
                continue;
            const id = "app:" + a.id;
            rows.push(row("app", id, a.name, a.genericName || a.comment || "", "", sc + Math.min(0.08, (usage[a.id] || 0) * 0.005) + (bonus[id] || 0), () => StartApps.launch(a), {
                "app": a
            }));
        }
        // actions, with their key: searching teaches it
        if (q.length >= 2)
            for (const a of actions) {
                const sc = best(a.words, vs);
                if (sc >= 0.6)
                    rows.push(row("action", a.id, a.title, (a.key ? a.key + " · " : "") + I18n.t("действие", "action"), a.icon, sc * 0.9 + (bonus[a.id] || 0), () => {
                        root.chosen(a.id);
                        a.run();
                    }, {
                        "key": a.key
                    }));
            }
        // settings (not for a sum: "2*3" would match "Size")
        if (o.settings !== false && Config.launcher.settings !== false && !calc) {
            // later: load() sets the indexer's state — inside the caller's binding a binding loop
            Qt.callLater(SettingsSearch.load);
            for (const d of SettingsSearch.search(raw, 8)) {
                const id = "set:" + d.page + "|" + d.title;
                rows.push(row("setting", id, d.title, I18n.t("Настройки", "Settings") + (d.crumb ? " › " + d.crumb : ""), d.icon || "gear", Math.min(0.95, d.score / 6.3) + (bonus[id] || 0), () => StartApps.openSetting(d), {
                    "doc": d
                }));
            }
        }
        // files by name or type: a few among the rest, all of them for ".jpeg"
        if (!calc && o.files !== 0)
            for (const f of FileSearch.rows(raw, /^(\.\S+\s*)+$/.test(q) ? 40 : (o.files || 8)))
                rows.push(row("file", "", f.name, FileSearch.where(f), FileSearch.pixelIcon(f), f.s, () => FileSearch.open(f), {
                    "file": f
                }));
        // an open vault's logins, no "pw" needed (not on air: a masked name says nothing)
        if (q.length >= 2 && Vault.enabled && Config.vault.everywhere !== false && Vault.items.length && !Vault.discreet)
            for (const f of Vault.find(q, 3))
                rows.push(row("vault", "", f.it.name, f.it.user, "lock", Math.min(0.65, f.s * 0.0065), () => Vault.copy(f.it, "password"), {
                    "vault": {
                        "kind": "item",
                        "item": f.it
                    }
                }));
        rows.sort((x, y) => y.s - x.s || (x.app && y.app ? String(x.app.name).localeCompare(String(y.app.name)) : 0));
        const out = rows.slice(0, limit || 40);
        // for chosen(): plain fields, no change signal inside the caller's binding
        _last.q = q.slice(0, 40);
        _last.at = Date.now();
        _last.ids = out.map(r => r.id).filter(id => !!id);
        return out;
    }
}
