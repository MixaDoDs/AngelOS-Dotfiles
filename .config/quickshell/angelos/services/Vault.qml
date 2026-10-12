pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Password managers (Settings → Apps → Passwords, the launcher's `pw …`, `angelos vault`):
// Bitwarden (its own CLI bw, or rbw) and 1Password (op) behind scripts/vault.py. The shell
// knows the entries' names and logins, never a password: Enter in the launcher makes vault.py
// hand the secret from the manager's CLI to the clipboard — marked sensitive, so the clipboard
// history skips it, and wiped after Config.vault.clearAfter seconds. The session keys of bw
// and op are kept here, in memory, until the vault is locked (by hand, after
// Config.vault.lockAfter idle minutes, with the screen) or the shell ends.
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/vault.py"
    property var backends: []          // [{id, name, cli, installed, state, account, ask}]
    property var items: []             // [{backend, id, name, user, url, totp}], logins only
    property var errors: ({})          // backend id -> why its entries could not be read
    property var sessions: ({})        // bw / op session keys, memory only
    property var mine: []              // what the shell opened itself: only that it closes by itself
    property bool loaded: false
    property bool listed: false
    property bool listing: false
    property string busy: ""           // "unlock:bw", "sync", "copy" while it runs
    property string error: ""          // why the last action didn't happen
    property string told: ""           // what the last action did ("Пароль скопирован…")
    property int tick: 0               // bumped when the entries or the states change
    property real usedAt: 0
    property real probedAt: 0

    readonly property bool enabled: Config.ready && Config.vault.enabled !== false
    readonly property var installed: backends.filter(b => b.installed)
    readonly property var open: backends.filter(b => b.state === "unlocked")
    readonly property var closed: backends.filter(b => b.state === "locked")
    readonly property var unset: backends.filter(b => b.state === "setup")
    // names and logins are not shown on air (Config.vault.hideOnStream) — and "on air" is taken
    // widely here: stream mode, OBS merely open (its preview and a recording see the screen as a
    // stream does), privacy mode
    readonly property bool discreet: Config.vault.hideOnStream !== false && (StreamMode.active || StreamMode.obsUp || StreamMode.obsRec || Privacy.on)

    // ---- the launcher: "pw git" ----
    readonly property var prefixes: ["pw", "пароль", "pass"]
    // what follows the prefix, or null when the query isn't for the vault
    function match(query) {
        if (!enabled)
            return null;
        const q = String(query || "").replace(/^\s+/, "");
        const low = q.toLowerCase();
        for (const p of prefixes)
            if (low === p || low.startsWith(p + " "))
                return q.slice(p.length).trim();
        return null;
    }
    function backend(id) {
        return backends.find(b => b.id === id) || null;
    }
    function mask(text) {
        const s = String(text || "");
        if (!discreet || !s)
            return s;
        return s.split("@").map(part => part.charAt(0) + "•••").join("@");
    }
    // the window that was in front last (its title and app, lower case): with nothing typed
    // after `pw`, the entries that fit it come first — the site open in the browser, the app
    property string context: ""
    Connections {
        target: Niri
        function onFocusedWindowChanged() {
            const w = Niri.focusedWindow;
            if (w)
                root.context = (Niri.titleOf(w) + " " + (w.app_id || "")).toLowerCase();
        }
    }
    // an entry's own words: its name, and its site's name without www and the ending
    function fits(it, where) {
        if (!where)
            return false;
        const words = [it.name.toLowerCase()];
        const host = String(it.url || "").replace(/^[a-z]+:\/\//i, "").split(/[\/:?]/)[0].toLowerCase().replace(/^www\./, "");
        if (host) {
            words.push(host);
            const parts = host.split(".");
            if (parts.length > 1)
                words.push(parts[parts.length - 2]);
        }
        return words.some(w => w.length >= 3 && where.includes(w));
    }
    function find(q, limit) {
        const needle = String(q || "").toLowerCase();
        const found = [];
        for (const it of items) {
            const name = it.name.toLowerCase();
            let s = fits(it, context) && !needle ? 990 : 1;
            if (needle) {
                if (name.startsWith(needle))
                    s = 100 - name.length / 10;
                else if (name.includes(needle))
                    s = 70 - name.indexOf(needle);
                else if (String(it.url).toLowerCase().includes(needle))
                    s = 45;
                else if (String(it.user).toLowerCase().includes(needle))
                    s = 40;
                else
                    continue;
            }
            found.push({
                "it": it,
                "s": s
            });
        }
        found.sort((a, b) => b.s - a.s || a.it.name.localeCompare(b.it.name));
        return found.slice(0, limit || 60);
    }
    // launcher rows: what to do first (install, sign in, unlock), then the entries. Once a vault
    // is open and a name is typed, the entries lead — a second manager still closed waits at the
    // bottom — and one not signed in to is not mentioned at all
    function rows(q) {
        tick;
        const list = [];
        const sunk = open.length > 0 && String(q || "").trim() !== "";
        if (!loaded)
            return [
                {
                    "kind": "wait",
                    "title": I18n.t("Смотрю, что с хранилищем…", "Looking at the vault…"),
                    "subtitle": "",
                    "icon": "lock",
                    "s": 900
                }
            ];
        if (!installed.length)
            list.push({
                "kind": "setup",
                "title": I18n.t("Подключить Bitwarden или 1Password", "Connect Bitwarden or 1Password"),
                "subtitle": I18n.t("Настройки → Приложения → Пароли", "Settings → Apps → Passwords"),
                "icon": "lock",
                "s": 900
            });
        for (const b of (open.length || closed.length ? [] : unset))
            list.push({
                "kind": "setup",
                "title": I18n.t("Войти в ", "Sign in to ") + b.name,
                "subtitle": I18n.t("Настройки → Приложения → Пароли", "Settings → Apps → Passwords"),
                "icon": "lock",
                "s": 890
            });
        for (const b of closed)
            list.push({
                "kind": "unlock",
                "backend": b.id,
                "title": I18n.t("Открыть ", "Unlock ") + b.name,
                "subtitle": busy === "unlock:" + b.id ? I18n.t("открываю…", "unlocking…") : mask(b.account),
                "icon": "lock",
                "s": sunk ? 0 : 950
            });
        if (listing && !items.length)
            list.push({
                "kind": "wait",
                "title": I18n.t("Читаю записи…", "Reading the entries…"),
                "subtitle": "",
                "icon": "lock",
                "s": 800
            });
        for (const f of find(q))
            list.push({
                "kind": "item",
                "item": f.it,
                "title": discreet ? mask(f.it.name) : f.it.name,
                "subtitle": mask(f.it.user) + (backends.filter(b => b.state === "unlocked").length > 1 ? " · " + (backend(f.it.backend) || {}).name : ""),
                "icon": "lock",
                "s": f.s
            });
        return list.sort((a, b) => b.s - a.s);
    }

    // ---- state ----
    // the launcher went into `pw` or the page opened: look again unless just looked
    function touch() {
        if (!enabled)
            return;
        if (!loaded || Date.now() - probedAt > 20000) {
            _openWanted = true;
            refresh();
        } else {
            openSaved();
            if (open.length && !listed)
                list();
        }
    }
    // a master password remembered in the login keyring as it is: the vault opens by itself
    property bool _openWanted: false
    function openSaved() {
        _openWanted = false;
        const b = closed.find(x => x.saved === "keyring");
        if (b && !busy && !_job)
            unlock(b.id);
    }
    // a look already under way may have been taken before what just changed: look once more after it
    property bool _again: false
    property bool _listAgain: false
    function refresh() {
        if (probe.running)
            _again = true;
        else
            probe.running = true;
    }
    function list() {
        const ids = open.map(b => b.id);
        if (!ids.length) {
            items = [];
            listed = false;
            tick++;
            return;
        }
        if (lister.running) {
            _listAgain = true;
            return;
        }
        listing = true;
        lister.command = ["python3", script, "list"].concat(ids);
        lister.running = true;
    }
    readonly property var env: ({
            "ANGELOS_LANG": I18n.english ? "en" : "ru",
            "ANGELOS_BW_SESSION": sessions.bw || "",
            "ANGELOS_OP_SESSION": sessions.op || ""
        })

    // ---- actions: one at a time (scripts/vault.py), each answers with one JSON line ----
    property var _jobs: []
    property var _job: null
    function act(args, done, typed) {
        _jobs = _jobs.concat([
            {
                "args": args,
                "done": done,
                "typed": typed === undefined ? null : typed
            }
        ]);
        pump();
    }
    function pump() {
        if (_job || !_jobs.length)
            return;
        _job = _jobs[0];
        _jobs = _jobs.slice(1);
        actor.stdinEnabled = _job.typed !== null;
        actor.command = ["python3", script].concat(_job.args);
        actor.running = true;
    }
    // what was remembered for a backend (scripts/vault.py remember) changed
    function _saved(id, mode) {
        if (mode === undefined || !backend(id) || backend(id).saved === mode)
            return;
        backends = backends.map(b => b.id === id ? Object.assign({}, b, {
                "saved": mode
            }) : b);
    }
    function _opened(id, res) {
        if (res.session) {
            const s = Object.assign({}, sessions);
            s[id] = res.session;
            sessions = s;
        }
        usedAt = Date.now();
        wanted = "";
        if (!mine.includes(id))
            mine = mine.concat([id]);
        _saved(id, res.saved);
        refresh();
    }
    // password: what was typed — the master password, or the PIN it was remembered under
    function unlock(id, password) {
        const b = backend(id);
        if (!b || busy)
            return;
        error = "";
        busy = "unlock:" + id;
        tick++;
        const typed = password !== undefined && password !== null && password !== "";
        const saved = wanted !== id ? (b.saved || "") : "";
        if (saved) {
            act(["unlock", id, "--saved"].concat(typed ? ["--stdin"] : []), res => {
                busy = "";
                if (res && res.ok) {
                    _opened(id, res);
                    return;
                }
                _saved(id, res ? res.saved : undefined);
                // forgotten (five wrong PINs, a changed master password): the master password it is
                if (res && res.ask === "password")
                    wanted = id;
                error = (res && res.error) || "";
                tick++;
            }, typed ? String(password) : null);
            return;
        }
        act(["unlock", id].concat(typed ? ["--stdin"] : []), res => {
            busy = "";
            if (res && res.ok) {
                _saved(id, res.saved);
                if (res.session) {
                    const s = Object.assign({}, sessions);
                    s[id] = res.session;
                    sessions = s;
                }
                usedAt = Date.now();
                wanted = "";
                if (!mine.includes(id))
                    mine = mine.concat([id]);
                refresh();
            } else {
                // a manager that asks by itself said no: the shell asks instead (1Password without its app)
                if (res && res.ask === "password" && !typed)
                    wanted = id;
                else
                    error = (res && res.error) || I18n.t("Не открылось", "It didn't unlock");
                tick++;
            }
        }, typed ? String(password) : null);
    }
    // the backend whose master password the shell should ask now (the launcher's field)
    property string wanted: ""
    // what the shell must ask to open it: "" (nothing: the manager asks itself, or the master
    // password waits in the keyring), "pin" (it waits there under a PIN), "password"
    function asks(id) {
        const b = backend(id);
        if (!b)
            return "";
        if (wanted !== id && b.saved)
            return b.saved === "pin" ? "pin" : "";
        return b.ask === "password" || wanted === id ? "password" : "";
    }
    function wantsPassword(id) {
        return asks(id) !== "";
    }
    // keep the master password in the login keyring: as it is (pin empty) or under a PIN
    function remember(id, password, pin) {
        if (!backend(id) || busy || !password)
            return;
        error = "";
        busy = "unlock:" + id;
        const withPin = pin !== undefined && pin !== null && pin !== "";
        act(["remember", id].concat(withPin ? ["--pin"] : []), res => {
            busy = "";
            if (res && res.ok)
                _opened(id, res);
            if (res && res.error)
                error = res.error;
            else if (!res || !res.ok)
                error = I18n.t("Не получилось", "That didn't work");
            tick++;
        }, String(password) + (withPin ? "\n" + String(pin) : ""));
    }
    function forget(id) {
        _saved(id, "");
        act(["forget", id], () => refresh());
    }
    // everything, or (by the timer, with the screen) only what the shell opened itself: an rbw
    // the user unlocked in a terminal keeps its own timeout
    function lock(onlyMine) {
        const ids = installed.filter(b => b.state === "unlocked" && (!onlyMine || mine.includes(b.id))).map(b => b.id);
        const s = {};
        for (const id in sessions)
            if (!ids.includes(id))
                s[id] = sessions[id];
        sessions = s;
        mine = mine.filter(id => !ids.includes(id));
        items = items.filter(it => !ids.includes(it.backend));
        wanted = "";
        backends = backends.map(b => ids.includes(b.id) ? Object.assign({}, b, {
                "state": "locked"
            }) : b);
        tick++;
        if (ids.length)
            act(["lock"].concat(ids), () => refresh());
    }
    function sync() {
        const ids = open.map(b => b.id);
        if (!ids.length || busy)
            return;
        error = "";
        busy = "sync";
        act(["sync"].concat(ids), res => {
            busy = "";
            if (res && !res.ok)
                error = Object.values(res.errors || {}).join("; ");
            listed = false;
            list();
        });
    }
    // field: password | username | totp
    function copy(item, field) {
        if (!item)
            return;
        error = "";
        usedAt = Date.now();
        const secs = Math.max(0, Config.vault.clearAfter | 0);
        act(["copy", item.backend, item.id, field, "--clear", String(secs)], res => {
            const what = field === "password" ? I18n.t("Пароль", "Password") : field === "username" ? I18n.t("Логин", "Login") : I18n.t("Код", "Code");
            if (res && res.ok) {
                told = what + I18n.t(" в буфере", " is in the clipboard") + (secs > 0 ? I18n.t(" · сотрётся через ", " · wiped in ") + secs + I18n.t(" с", " s") : "");
                say(told, discreet ? "" : item.name);
            } else {
                error = (res && res.error) || I18n.t("Не получилось", "That didn't work");
                say(what + I18n.t(": не получилось", ": that didn't work"), error);
                // the manager closed by itself meanwhile
                refresh();
            }
        });
    }
    function say(title, body) {
        if (!Shell.dev)
            Quickshell.execDetached(["notify-send", "-a", "angelOS", "-i", "dialog-password", "-t", "4000", title, body || ""]);
    }
    // the first sign-in and the CLI's install are a terminal's business
    function setup(id, what) {
        Shell.terminal("ANGELOS_LANG=" + (I18n.english ? "en" : "ru") + " python3 '" + script + "' " + (what === "install" ? "install" : "login") + " " + id);
    }
    function openSettings() {
        Shell.openSettings("vault");
    }

    Process {
        id: probe
        command: ["python3", root.script, "status"]
        environment: root.env
        onExited: {
            if (root._again) {
                root._again = false;
                running = true;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                // stale: the next look is on its way
                if (root._again)
                    return;
                try {
                    root.backends = JSON.parse(text).backends || [];
                } catch (e) {
                    return;
                }
                root.loaded = true;
                root.probedAt = Date.now();
                // a session the manager no longer takes is of no use
                const s = {};
                for (const b of root.backends)
                    if (b.state === "unlocked" && root.sessions[b.id])
                        s[b.id] = root.sessions[b.id];
                if (JSON.stringify(s) !== JSON.stringify(root.sessions))
                    root.sessions = s;
                root.tick++;
                if (root._openWanted)
                    root.openSaved();
                if (root.open.length)
                    root.list();
                else if (root.items.length) {
                    root.items = [];
                    root.listed = false;
                }
            }
        }
    }
    Process {
        id: lister
        environment: root.env
        onExited: {
            if (root._listAgain) {
                root._listAgain = false;
                root.list();
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.listing = false;
                try {
                    const d = JSON.parse(text);
                    root.items = d.items || [];
                    root.errors = d.errors || {};
                    root.listed = true;
                } catch (e) {}
                root.tick++;
            }
        }
    }
    Process {
        id: actor
        property string answer: ""
        property bool gotOut: false
        property bool gone: false
        environment: root.env
        onStarted: {
            gotOut = false;
            gone = false;
            if (root._job && root._job.typed !== null) {
                write(root._job.typed + "\n");
                stdinEnabled = false;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                actor.answer = text;
                actor.gotOut = true;
                actor.finish();
            }
        }
        onExited: {
            gone = true;
            finish();
        }
        function finish() {
            if (!gotOut || !gone || !root._job)
                return;
            const job = root._job;
            root._job = null;
            let res = null;
            try {
                res = JSON.parse(answer.trim().split("\n").pop());
            } catch (e) {}
            answer = "";
            if (job.done)
                job.done(res);
            root.pump();
        }
    }

    // closed after a while without use, and with the screen
    Timer {
        interval: 30000
        repeat: true
        running: root.mine.length > 0 && (Config.vault.lockAfter | 0) > 0
        onTriggered: if (Date.now() - root.usedAt > (Config.vault.lockAfter | 0) * 60000)
            root.lock(true)
    }
    Connections {
        target: Shell
        function onLockedChanged() {
            if (Shell.locked && Config.vault.lockWithScreen !== false && root.mine.length)
                root.lock(true);
        }
    }

    // `angelos vault …`
    function ipc(line) {
        const words = String(line || "").trim().split(/\s+/).filter(w => w);
        const cmd = words[0] || "status";
        switch (cmd) {
        case "status":
            return JSON.stringify({
                "enabled": enabled,
                "loaded": loaded,
                "items": items.length,
                "busy": busy,
                "error": error,
                "backends": backends.map(b => ({
                            "id": b.id,
                            "installed": b.installed,
                            "state": b.state,
                            "ask": b.ask,
                            "saved": b.saved || ""
                        }))
            });
        case "refresh":
            refresh();
            return "ok";
        case "lock":
            lock();
            return "ok";
        case "sync":
            sync();
            return "ok";
        case "unlock":
            // only a manager that asks by itself: a master password is never a command's argument
            if (!backend(words[1]))
                return "vault unlock bw|rbw|op";
            if (wantsPassword(words[1]))
                return I18n.t("мастер-пароль спрашивает лаунчер: Mod+Space → pw", "the launcher asks the master password: Mod+Space → pw");
            unlock(words[1]);
            return "ok";
        case "find":
            return JSON.stringify(find(words.slice(1).join(" "), 20).map(f => ({
                        "backend": f.it.backend,
                        "name": f.it.name,
                        "user": mask(f.it.user)
                    })));
        case "open":
            openSettings();
            return "ok";
        }
        return "angelos vault [status] | refresh | unlock ID | lock | sync | find TEXT | open — password managers (Settings → Apps → Passwords; in the launcher: pw NAME)";
    }
}
