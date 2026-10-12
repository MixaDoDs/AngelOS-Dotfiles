pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Presets of settings (Settings → Presets, `angelos preset`): a desktop that fits in one click,
// so nobody has to walk a hundred switches to get there.
//  - the author's (data/presets.json): a few whole moods. They share one list of settings — every
//    key any of them names; a preset puts each key of the list to its own value, the rest of the
//    list to its default. So they replace each other cleanly, "which one is on" is a plain
//    comparison, and nothing outside the list is ever touched.
//  - the user's own (~/.config/angelos/presets.json): everything as it is right now, under a
//    name, to come back to. Without the shell's bookkeeping (Config.notUndoable) and what belongs
//    to the install rather than to a taste (the wizard's answers, updates, the developer's keys).
// Applying is one step for Settings' Undo; «Вернуть как было» here undoes the last one applied.
Singleton {
    id: root

    property var builtin: []        // [{id, icon, ru, en, hintRu, hintEn, pointsRu, pointsEn, set}]
    property var own: []            // [{id, name, at, set}]
    // the author's presets' shared list: ["appearance.motion", …]
    readonly property var keys: {
        const seen = {};
        for (const p of builtin)
            for (const k in p.set)
                seen[k] = true;
        return Object.keys(seen).sort();
    }
    // sections a preset of the user's leaves alone
    readonly property var ownSkips: ["setup", "updates", "dotfiles", "developer", "plugins", "recovery"]
    property var before: null       // what the last applied preset changed: {path: the value before}
    property string lastId: ""      // … and which one it was
    readonly property bool canUndo: before !== null

    function value(path) {
        const [sec, key] = String(path).split(".");
        const o = Config[sec];
        return o ? o[key] : undefined;
    }
    function same(a, b) {
        return JSON.stringify(a === undefined ? null : a) === JSON.stringify(b === undefined ? null : b);
    }
    function find(id) {
        return builtin.find(p => p.id === id) || own.find(p => p.id === id) || null;
    }
    // every setting a preset decides: {path: value}
    function target(p) {
        if (!p)
            return {};
        if (String(p.id).startsWith("my-"))
            return p.set;
        const out = {};
        for (const k of keys)
            out[k] = k in p.set ? p.set[k] : Config.defaultOf(k);
        return out;
    }
    // what applying it would change now: [{path, from, to}]
    function plan(id) {
        const t = target(find(id)), out = [];
        for (const k in t) {
            const now = value(k);
            if (now !== undefined && t[k] !== undefined && !same(now, t[k]))
                out.push({
                    "path": k,
                    "from": now,
                    "to": t[k]
                });
        }
        return out;
    }
    // the author's preset the settings match right now ("" = the user's own mix)
    readonly property string active: {
        for (const p of builtin) {
            let ok = keys.length > 0;
            for (const k of keys)
                if (!same(value(k), k in p.set ? p.set[k] : Config.defaultOf(k))) {
                    ok = false;
                    break;
                }
            if (ok)
                return p.id;
        }
        return "";
    }

    function apply(id) {
        const changes = plan(id);
        if (!find(id))
            return -1;
        // what was changed just before stays its own Undo step
        Config.flush();
        const was = {};
        for (const c of changes) {
            const [sec, key] = c.path.split(".");
            was[c.path] = c.from !== null && typeof c.from === "object" ? JSON.parse(JSON.stringify(c.from)) : c.from;
            Config[sec][key] = c.to !== null && typeof c.to === "object" ? JSON.parse(JSON.stringify(c.to)) : c.to;
        }
        Config.flush();
        before = changes.length ? was : null;
        lastId = changes.length ? id : "";
        return changes.length;
    }
    function undo() {
        if (!before)
            return false;
        Config.flush();
        for (const path in before) {
            const [sec, key] = path.split(".");
            Config[sec][key] = before[path];
        }
        Config.flush();
        before = null;
        lastId = "";
        return true;
    }

    // ---- the user's own ----
    function slug(name) {
        const s = String(name).toLowerCase().replace(/[^\p{L}\p{N}]+/gu, "-").replace(/^-+|-+$/g, "");
        return s || "preset";
    }
    // everything as it is now, minus bookkeeping and the install's own keys
    function current() {
        const snap = Config.snapshot(), out = {};
        for (const path in snap) {
            if (Config.notUndoable.includes(path) || ownSkips.includes(path.split(".")[0]))
                continue;
            out[path] = JSON.parse(snap[path]);
        }
        return out;
    }
    // a name used already is saved over
    function save(name) {
        const n = String(name || "").trim().slice(0, 40);
        if (!n)
            return "";
        const id = "my-" + slug(n);
        own = own.filter(p => p.id !== id).concat([{
                "id": id,
                "name": n,
                "at": new Date().toISOString(),
                "set": current()
            }]);
        write();
        return id;
    }
    function remove(id) {
        if (!own.some(p => p.id === id))
            return false;
        own = own.filter(p => p.id !== id);
        write();
        return true;
    }
    function write() {
        file.setText(JSON.stringify({
            "presets": own
        }, null, 1) + "\n");
    }

    function ipc(line) {
        const a = String(line || "").trim().split(/\s+/).filter(x => x);
        const cmd = a[0] || "list";
        const rest = a.slice(1).join(" ");
        if (cmd === "list")
            return JSON.stringify({
                "active": active,
                "builtin": builtin.map(p => ({
                            "id": p.id,
                            "name": I18n.t(p.ru, p.en),
                            "changes": plan(p.id).length
                        })),
                "own": own.map(p => ({
                            "id": p.id,
                            "name": p.name,
                            "at": p.at,
                            "changes": plan(p.id).length
                        })),
                "canUndo": canUndo
            });
        if (cmd === "show")
            return find(rest) ? JSON.stringify(plan(rest)) : "no such preset: " + rest;
        if (cmd === "apply") {
            // a name of the user's works too
            const p = find(rest) || own.find(x => x.name === rest);
            if (!p)
                return "no such preset: " + rest + " (angelos preset list)";
            return "applied " + p.id + ": " + apply(p.id) + " settings changed (angelos preset undo)";
        }
        if (cmd === "undo")
            return undo() ? "undone" : "nothing to undo";
        if (cmd === "save")
            return rest ? "saved " + save(rest) : "angelos preset save NAME";
        if (cmd === "delete")
            return remove(rest) || remove("my-" + slug(rest)) ? "deleted" : "no such preset of yours: " + rest;
        return "angelos preset [list] | show ID | apply ID | undo | save NAME | delete ID — presets of settings (Settings → Presets)";
    }

    FileView {
        path: Quickshell.shellDir + "/data/presets.json"
        printErrors: false
        onLoaded: {
            try {
                root.builtin = (JSON.parse(text()).presets || []).filter(p => p.id && p.set);
            } catch (e) {
                root.builtin = [];
            }
        }
    }
    FileView {
        id: file
        path: Config.dir + "/presets.json"
        printErrors: false
        watchChanges: true
        blockWrites: true
        atomicWrites: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.own = (JSON.parse(text()).presets || []).filter(p => p.id && p.name && p.set);
            } catch (e) {
                root.own = [];
            }
        }
    }
}
