pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The menus of the focused window's app for the Golden Gate menu bar (modules/mac/MacMenuBar).
// scripts/appmenu.py finds what the app offers over D-Bus by the window's pid — a Qt or GTK 3
// menubar, a GtkApplication's menubar or only its actions — and it is shown as macOS would:
//   the app menu (the app's name in bold): About, Settings…, Quit — the app's own items moved
//     there, or the shell's (the About panel, closing every window of the app through niri);
//   the app's menus (File, Edit, View…), or for apps with none standard menus that work through
//     the app's own shortcuts (data/appmenu-profiles.json), its .desktop actions and its D-Bus
//     actions (New Window, New Tab, Preferences…);
//   Window: niri's — Fill, Center, Full Screen, floating, to another desktop or display, the
//     app's windows;
//   Help, when there is something in it.
// Nothing dead: what can't be done is not shown. An item the app itself greys out stays grey.
// An item is {id, label, enabled, type: item|separator|submenu, toggle, checked, keys, children,
// act} — act says how to run it (trigger()).
Singleton {
    id: root

    readonly property bool wanted: GoldenGate.on && Config.mac.appMenus
    // the frontmost app's window. While the menu bar (or another shell surface) has the keyboard
    // niri reports no focused window — the app stays frontmost: the active window of the focused
    // desktop, as macOS keeps the app's menus while you are in its menu bar
    readonly property var window: Niri.focusedWindow || frontmost()
    function frontmost() {
        const ws = Niri.workspaces.find(w => w.is_focused);
        const id = ws ? ws.active_window_id : null;
        return id === null || id === undefined ? null : Niri.windows.find(w => w.id === id) || null;
    }
    readonly property int pid: window && window.pid ? window.pid : 0
    readonly property string appId: window ? String(window.app_id || "") : ""
    readonly property var entry: appId ? (DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId)) : null
    // angelOS's own Settings window: macOS's System Settings here, with menus of its own
    readonly property bool shellSettings: !!window && appId === "org.quickshell" && String(window.title || "").indexOf("angelOS") === 0
    // no window in front (the desktop): the file manager's menus, as a Mac shows Finder's
    readonly property var filesEntry: {
        const d = DefaultApps.data && DefaultApps.data.files ? String(DefaultApps.data.files.current || "").replace(/\.desktop$/, "") : "";
        return DesktopEntries.byId(d || "org.gnome.Nautilus") || null;
    }
    readonly property string appName: shellSettings ? I18n.t("Системные настройки", "System Settings") : !window ? (filesEntry && filesEntry.name ? filesEntry.name : I18n.t("Файлы", "Files")) : entry && entry.name ? entry.name : prettyName(appId)

    // what the helper reported for the focused window
    property var report: ({
            "pid": 0,
            "source": "none",
            "menus": [],
            "actions": [],
            "ambiguous": false
        })
    readonly property bool current: report.pid === pid
    readonly property string source: current ? report.source : "none"
    property bool registrar: false
    property var profiles: ({})
    readonly property string profileId: {
        const m = profiles.match || {};
        for (const id in m)
            if (m[id].includes(appId))
                return id;
        if (source === "actions")
            return "gtk";
        return "";
    }
    readonly property var profile: profileId && profiles.profiles ? profiles.profiles[profileId] || null : null

    function prettyName(id) {
        const last = String(id).split(".").pop();
        return last ? last.charAt(0).toUpperCase() + last.slice(1) : I18n.t("Приложение", "App");
    }
    function tr(pair) {
        return Array.isArray(pair) ? I18n.t(pair[0], pair[1]) : String(pair);
    }

    // ---- the helper ----
    Process {
        id: helper
        running: root.wanted
        command: ["python3", Quickshell.shellDir + "/scripts/appmenu.py", "serve"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => root._event(data)
        }
        stderr: SplitParser {
            onRead: data => console.log("appmenu:", data)
        }
        onStarted: root._sendFocus()
        onRunningChanged: if (!running)
            root.registrar = false
    }
    // the helper went away while wanted (a crash): start it again — Qt apps started under the
    // registrar have no in-window menu bar any more and depend on it
    Timer {
        interval: 2000
        running: root.wanted && !helper.running
        onTriggered: helper.running = true
    }
    function _send(obj) {
        if (helper.running)
            helper.write(JSON.stringify(obj) + "\n");
    }
    function _sendFocus() {
        _send({
            "cmd": "focus",
            "pid": pid,
            "app": appId
        });
    }
    onPidChanged: _sendFocus()
    onAppIdChanged: _sendFocus()
    function _event(line) {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (ev.ev === "menu")
            report = ev;
        else if (ev.ev === "registrar")
            registrar = ev.owned;
        else if (ev.ev === "activated" && !ev.ok)
            console.warn("appmenu: activation failed", ev.id, ev.error || "");
    }
    function refresh() {
        _send({
            "cmd": "refresh"
        });
    }
    function opened(item) {
        if (item && item.act && item.act.kind === "app")
            _send({
                "cmd": "open",
                "id": item.act.id
            });
    }
    function closed(item) {
        if (item && item.act && item.act.kind === "app")
            _send({
                "cmd": "closed",
                "id": item.act.id
            });
    }

    FileView {
        path: Quickshell.shellDir + "/data/appmenu-profiles.json"
        onLoaded: {
            try {
                root.profiles = JSON.parse(text());
            } catch (e) {
                console.warn("appmenu-profiles.json:", e);
            }
        }
    }

    // ---- building the menus ----
    function sep(key) {
        return {
            "id": "sep:" + key,
            "type": "separator"
        };
    }
    function item(id, label, act, extra) {
        return Object.assign({
            "id": id,
            "label": label,
            "enabled": true,
            "type": "item",
            "toggle": "",
            "checked": false,
            "keys": act && act.kind === "keys" ? act.keys : [],
            "children": [],
            "act": act
        }, extra || {});
    }
    function submenu(id, label, children) {
        return {
            "id": id,
            "label": label,
            "enabled": children.length > 0,
            "type": "submenu",
            "children": children,
            "keys": [],
            "act": null
        };
    }
    // separators only between items: none leading, trailing or doubled
    function tidy(list) {
        const out = [];
        for (const it of list) {
            if (it.type === "separator" && (out.length === 0 || out[out.length - 1].type === "separator"))
                continue;
            out.push(it);
        }
        while (out.length && out[out.length - 1].type === "separator")
            out.pop();
        return out;
    }
    // the app's own items: what the helper sent, made runnable; with an unknown focused window
    // (ambiguous) an item without a shortcut is left out, one with a shortcut goes by its keys
    function fromApp(list) {
        const amb = report.ambiguous;
        const out = [];
        for (const it of list || []) {
            if (it.type === "separator") {
                out.push(sep(it.id));
                continue;
            }
            if (it.type === "submenu") {
                const kids = fromApp(it.children);
                if (kids.length)
                    out.push(Object.assign({}, it, {
                        "children": tidy(kids),
                        "act": {
                            "kind": "app",
                            "id": it.id
                        }
                    }));
                continue;
            }
            if (amb && !(it.keys && it.keys.length))
                continue;
            out.push(Object.assign({}, it, {
                "act": amb ? {
                    "kind": "keys",
                    "keys": it.keys
                } : {
                    "kind": "app",
                    "id": it.id
                }
            }));
        }
        return tidy(out);
    }
    function fromProfile(list, key) {
        const out = [];
        let n = 0;
        for (const it of list || []) {
            n++;
            if (it === "-") {
                out.push(sep(key + n));
                continue;
            }
            const act = it.keys ? {
                "kind": "keys",
                "keys": it.keys
            } : it.seq ? {
                "kind": "seq",
                "steps": it.seq
            } : it.run ? {
                "kind": "run",
                "argv": it.run
            } : null;
            if (act)
                out.push(item(key + n, tr(it.label), act));
        }
        return out;
    }
    function profileMenus() {
        if (!profile)
            return [];
        const shared = profiles.menus || {};
        const out = [];
        let n = 0;
        for (const m of profile.menus || []) {
            n++;
            const base = m.ref ? shared[m.ref] || {} : m;
            const items = fromProfile((base.items || []).concat(m.extra || []), "p" + n + ":");
            if (items.length)
                out.push({
                    "title": tr(base.title),
                    "items": tidy(items),
                    "window": !!m.window
                });
        }
        return out;
    }

    // D-Bus actions of a GtkApplication with no menubar (source "actions")
    function action(name) {
        return current ? (report.actions || []).find(a => a.name === name || a.id === "a:" + name) || null : null;
    }
    // a known action: by D-Bus when there is one window, else by its stock shortcut
    function stdAction(names, keys) {
        for (const n of names) {
            const a = action(n);
            if (a)
                return {
                    "act": {
                        "kind": "app",
                        "id": a.id
                    },
                    "enabled": a.enabled,
                    "state": a.state
                };
        }
        return keys && report.ambiguous && source === "actions" ? {
            "act": {
                "kind": "keys",
                "keys": keys
            },
            "enabled": true,
            "state": null
        } : null;
    }
    function fromActions(id, label, names, keys) {
        const a = stdAction(names, keys);
        if (!a)
            return null;
        return item(id, label, a.act, {
            "enabled": a.enabled,
            "keys": keys || [],
            "toggle": typeof a.state === "boolean" ? "check" : "",
            "checked": a.state === true
        });
    }

    // the app's own item matching one of these patterns (About, Settings, Quit), to move it to the
    // app menu as macOS does with Qt and GTK apps
    readonly property var aboutRe: /^(about\b|about$|о программе|о приложении|об? \S)/i
    readonly property var prefsRe: /^(preferences|settings|options|настройки|параметры)\b/i
    readonly property var quitRe: /^(quit|exit|выход|выйти|завершить)\b/i
    function takeItem(menus, re) {
        for (const m of menus)
            for (let i = 0; i < m.children.length; i++) {
                const it = m.children[i];
                if (it.type === "item" && re.test(it.label)) {
                    m.children.splice(i, 1);
                    m.children = tidy(m.children);
                    return it;
                }
            }
        return null;
    }

    // the menus of the bar: [{title, bold, items, id}]
    readonly property var menus: build(report, profile, window, Niri.workspaces, Niri.windows, entry, I18n.english)
    function build() {
        if (!window)
            return desktopMenus();
        if (shellSettings)
            return settingsMenus();
        const name = appName;
        // the app's own menus (a copy: items get moved)
        const own = source === "dbusmenu" || source === "gmenu" ? fromApp(report.menus).filter(m => m.type === "submenu").map(m => Object.assign({}, m, {
                    "children": m.children.slice()
                })) : [];
        const about = own.length ? takeItem(own, aboutRe) : null;
        const prefs = own.length ? takeItem(own, prefsRe) : null;
        const quit = own.length ? takeItem(own, quitRe) : null;

        // ---- the app menu ----
        const app = [];
        const gAbout = fromActions("app:about", I18n.t("О программе ", "About ") + name, ["about"]);
        app.push(about ? Object.assign({}, about, {
            "label": I18n.t("О программе ", "About ") + name
        }) : gAbout || item("app:about", I18n.t("О программе ", "About ") + name, {
            "kind": "about"
        }));
        app.push(sep("app1"));
        const gPrefs = fromActions("app:prefs", I18n.t("Настройки…", "Settings…"), ["preferences", "settings", "prefs"], ["ctrl", "comma"]);
        const pPrefs = profile && profile.prefs ? item("app:prefs", I18n.t("Настройки…", "Settings…"), profile.prefs.keys ? {
            "kind": "keys",
            "keys": profile.prefs.keys
        } : {
            "kind": "seq",
            "steps": profile.prefs.seq
        }) : null;
        const p = prefs ? Object.assign({}, prefs, {
            "label": I18n.t("Настройки…", "Settings…")
        }) : gPrefs || pPrefs;
        if (p)
            app.push(p);
        app.push(sep("app2"));
        const gQuit = fromActions("app:quit", I18n.t("Завершить ", "Quit ") + name, ["quit"], ["ctrl", "q"]);
        app.push(quit ? Object.assign({}, quit, {
            "label": I18n.t("Завершить ", "Quit ") + name
        }) : gQuit || item("app:quit", I18n.t("Завершить ", "Quit ") + name, {
            "kind": "quit"
        }));
        const out = [
            {
                "id": "m:app",
                "title": name,
                "bold": true,
                "items": tidy(app)
            }
        ];

        // ---- the app's menus, or the standard ones ----
        let help = null;
        if (own.length) {
            for (const m of own) {
                if (/^(help|справка|помощь)$/i.test(m.label)) {
                    help = m;
                    continue;
                }
                out.push({
                    "id": "m:" + m.id,
                    "title": m.label,
                    "items": tidy(m.children),
                    "owner": m
                });
            }
        } else {
            out.push(...standardMenus());
        }

        // ---- Window (niri) ----
        out.push({
            "id": "m:window",
            "title": I18n.t("Окно", "Window"),
            "items": windowMenu(out)
        });
        // ---- Help ----
        const hi = help ? help.children : helpItems();
        if (hi.length)
            out.push({
                "id": help ? "m:" + help.id : "m:help",
                "title": I18n.t("Справка", "Help"),
                "items": tidy(hi),
                "owner": help
            });
        return out;
    }

    // the desktop: the file manager's app menu, a new window of it, Go to the usual places
    function desktopMenus() {
        const name = appName;
        const places = [["Домой", "Home", Config.home], ["Документы", "Documents", Config.home + "/Documents"], ["Рабочий стол", "Desktop", Config.home + "/Desktop"], ["Загрузки", "Downloads", Config.home + "/Downloads"], ["Изображения", "Pictures", Config.home + "/Pictures"]];
        const go = places.map((p, i) => item("dg:" + i, I18n.t(p[0], p[1]), {
                "kind": "fn",
                "fn": () => Shell.openPath(p[2])
            }));
        go.push(sep("dg"), item("dg:trash", I18n.t("Корзина", "Trash"), {
            "kind": "run",
            "argv": ["gio", "open", "trash:///"]
        }));
        const fe = filesEntry;
        return [
            {
                "id": "m:app",
                "title": name,
                "bold": true,
                "items": tidy([fe ? item("d:about", I18n.t("О программе ", "About ") + name, {
                        "kind": "fn",
                        "fn": () => root.aboutApp = {
                                "name": name,
                                "id": fe.id,
                                "icon": fe.icon,
                                "comment": fe.comment || fe.genericName || "",
                                "pid": 0
                            }
                    }) : sep("d0"), sep("d1"), item("d:settings", I18n.t("Системные настройки…", "System Settings…"), {
                        "kind": "fn",
                        "fn": () => Shell.openSettings()
                    })])
            },
            {
                "id": "m:file",
                "title": I18n.t("Файл", "File"),
                "items": fe ? [item("d:new", I18n.t("Новое окно «", "New ") + name + I18n.t("»", " Window"), {
                            "kind": "fn",
                            "fn": () => StartApps.launch(fe)
                        })] : []
            },
            {
                "id": "m:go",
                "title": I18n.t("Переход", "Go"),
                "items": go
            }
        ].filter(m => m.items.length > 0);
    }

    // angelOS's Settings as System Settings: View lists the panes like macOS's does
    function settingsMenus() {
        const panes = [];
        for (const c of SettingsTree.categories || []) {
            for (const id of c.pages || []) {
                const pg = SettingsTree.pages[id];
                if (pg && SettingsTree.shown(pg))
                    panes.push(item("sp:" + id, pg.label, {
                        "kind": "fn",
                        "fn": () => Shell.openSettings(id)
                    }, {
                        "toggle": "check",
                        "checked": Shell.settingsPage === id
                    }));
            }
            panes.push(sep("sc:" + c.id));
        }
        const name = appName;
        return [
            {
                "id": "m:app",
                "title": name,
                "bold": true,
                "items": tidy([item("s:about", I18n.t("О программе «", "About ") + name + I18n.t("»", ""), {
                        "kind": "fn",
                        "fn": () => Shell.openSettings("about")
                    }), sep("s1"), item("s:quit", I18n.t("Завершить «", "Quit ") + name + I18n.t("»", ""), {
                        "kind": "fn",
                        "fn": () => Shell.settingsOpen = false
                    })])
            },
            {
                "id": "m:file",
                "title": I18n.t("Файл", "File"),
                "items": [item("s:close", I18n.t("Закрыть окно", "Close Window"), {
                        "kind": "fn",
                        "fn": () => Shell.settingsOpen = false
                    })]
            },
            {
                "id": "m:edit",
                "title": I18n.t("Правка", "Edit"),
                "items": tidy([item("s:undo", I18n.t("Отменить", "Undo"), {
                        "kind": "fn",
                        "fn": () => Config.undo()
                    }, {
                        "enabled": Config.canUndo,
                        "keys": ["ctrl", "z"]
                    }), item("s:find", I18n.t("Найти", "Find"), {
                        "kind": "fn",
                        "fn": () => Shell.settingsView && Shell.settingsView.focusSearch()
                    }, {
                        "keys": ["ctrl", "f"]
                    })])
            },
            {
                "id": "m:view",
                "title": I18n.t("Вид", "View"),
                "items": tidy([item("s:back", I18n.t("Назад", "Back"), {
                        "kind": "fn",
                        "fn": () => Shell.settingsView && Shell.settingsView.back()
                    }, {
                        "keys": ["alt", "Left"]
                    }), item("s:fwd", I18n.t("Вперёд", "Forward"), {
                        "kind": "fn",
                        "fn": () => Shell.settingsView && Shell.settingsView.forward()
                    }, {
                        "keys": ["alt", "Right"]
                    }), sep("sv")].concat(panes))
            },
            {
                "id": "m:window",
                "title": I18n.t("Окно", "Window"),
                "items": windowMenu([])
            }
        ];
    }

    function standardMenus() {
        const out = [];
        const prof = profileMenus();
        // File: the profile's, the .desktop file's actions (New Window, New Private Window…),
        // D-Bus actions, and Close Window
        const file = [];
        const pf = prof.find(m => /^(Файл|File)$/.test(m.title));
        const nw = fromActions("f:newwin", I18n.t("Новое окно", "New Window"), ["new-window", "clone-window"], ["ctrl", "n"]);
        const nt = fromActions("f:newtab", I18n.t("Новая вкладка", "New Tab"), ["new-tab"], ["ctrl", "t"]);
        // the app's own New Window / New Tab (D-Bus) lead, unless the profile has them already
        const has = re => !!pf && pf.items.some(x => re.test(x.label || ""));
        if (nw && !has(/Новое окно|New Window/))
            file.push(nw);
        if (nt && !has(/Новая вкладка|New Tab/))
            file.push(nt);
        if (pf)
            file.push(sep("f:p"), ...pf.items);
        const deskActs = entry && entry.actions ? entry.actions : [];
        if (deskActs.length) {
            file.push(sep("f:desk"));
            for (let i = 0; i < deskActs.length; i++) {
                const a = deskActs[i];
                // the profile's File menu already has New Window / New Private Window
                if (pf && (pf.items.some(x => x.label === a.name) || /new.?(private.?|incognito.?)?window|new.?tab/i.test(String(a.id))))
                    continue;
                file.push(item("f:desk" + i, a.name, {
                    "kind": "desktop",
                    "index": i
                }));
            }
        }
        const close = fromActions("f:closetab", I18n.t("Закрыть вкладку", "Close Tab"), ["close-current-view", "close-tab"], ["ctrl", "w"]);
        if (close && !pf)
            file.push(sep("f:c"), close);
        if (!pf || !pf.items.some(x => /Закрыть окно|Close Window/.test(x.label)))
            file.push(sep("f:cw"), item("f:closewin", I18n.t("Закрыть окно", "Close Window"), {
                "kind": "niri",
                "action": "close"
            }));
        out.push({
            "id": "m:file",
            "title": pf ? pf.title : I18n.t("Файл", "File"),
            "items": tidy(file)
        });
        // Edit: the profile's (the app's own shortcuts), D-Bus undo/redo first
        const pe = prof.find(m => /^(Правка|Edit)$/.test(m.title));
        if (pe)
            out.push({
                "id": "m:edit",
                "title": pe.title,
                "items": pe.items
            });
        // the profile's other menus (View, History, Go…), View with D-Bus toggles of the app
        for (const m of prof) {
            if (m === pf || m === pe || m.window)
                continue;
            out.push({
                "id": "m:p:" + m.title,
                "title": m.title,
                "items": m.items
            });
        }
        const side = fromActions("v:side", I18n.t("Боковая панель", "Sidebar"), ["toggle-sidebar", "show-hide-sidebar", "sidebar"], ["F9"]);
        if (side) {
            const v = out.find(m => /^(Вид|View)$/.test(m.title));
            if (v)
                v.items = tidy([side, sep("v:s")].concat(v.items));
            else
                out.push({
                    "id": "m:view",
                    "title": I18n.t("Вид", "View"),
                    "items": [side]
                });
        }
        return out;
    }

    function helpItems() {
        const out = [];
        const h = fromActions("h:help", appName + I18n.t(" — справка", " Help"), ["help"], ["F1"]);
        if (h)
            out.push(h);
        const k = fromActions("h:keys", I18n.t("Сочетания клавиш", "Keyboard Shortcuts"), ["shortcuts", "show-help-overlay"], ["ctrl", "question"]);
        if (k)
            out.push(k);
        if (profile && profile.help)
            out.push(...fromProfile(profile.help, "h:p"));
        return out;
    }

    // niri reports no fullscreen state: a window as big as its display is one
    function isFullscreen(w) {
        const ws = Niri.workspaceById(w.workspace_id);
        const s = ws ? Shell.screenByName(ws.output) : null;
        const size = w.layout ? w.layout.window_size : null;
        return !!s && !!size && size[0] >= s.width && size[1] >= s.height;
    }
    function windowMenu(menus) {
        const w = window;
        const out = [];
        // a profile's window-level items (next/previous tab)
        for (const m of profileMenus().filter(m => m.window))
            out.push(...m.items, sep("w:p" + m.title));
        // to the Dock (services/Minimize: niri has no minimizing of its own)
        out.push(item("w:min", I18n.t("Свернуть", "Minimize"), {
            "kind": "niri",
            "action": "minimize"
        }, Config.mac.keys ? {
            "keys": ["logo", "m"]
        } : {}), sep("w:0"));
        out.push(item("w:fill", I18n.t("Заполнить", "Fill"), {
            "kind": "niri",
            "action": "fill"
        }), item("w:center", I18n.t("По центру", "Center"), {
            "kind": "niri",
            "action": "center"
        }), item("w:full", isFullscreen(w) ? I18n.t("Выйти из полноэкранного режима", "Exit Full Screen") : I18n.t("Войти в полноэкранный режим", "Enter Full Screen"), {
            "kind": "niri",
            "action": "fullscreen"
        }));
        out.push(sep("w:1"), item("w:float", w.is_floating ? I18n.t("Вернуть в колонки", "Tile in Columns") : I18n.t("Сделать плавающим", "Float on Top"), {
            "kind": "niri",
            "action": "float"
        }));
        // to another desktop of this display, and to the other displays
        const ws = Niri.workspaces.filter(x => x.output === (Niri.workspaceById(w.workspace_id) || {}).output);
        const desks = [];
        for (const x of ws)
            if (x.id !== w.workspace_id)
                desks.push(item("w:ws" + x.id, x.name || I18n.t("Рабочий стол ", "Desktop ") + x.idx, {
                    "kind": "niri",
                    "action": "workspace",
                    "idx": x.idx
                }));
        if (desks.length)
            out.push(submenu("w:desk", I18n.t("Переместить на рабочий стол", "Move to Desktop"), desks));
        const outputs = [...new Set(Niri.workspaces.map(x => x.output))].filter(o => o && o !== (Niri.workspaceById(w.workspace_id) || {}).output);
        if (outputs.length)
            out.push(submenu("w:mon", I18n.t("Переместить на дисплей", "Move to Display"), outputs.map(o => item("w:out" + o, o, {
                            "kind": "niri",
                            "action": "output",
                            "output": o
                        }))));
        // the app's windows
        const mine = Niri.windows.filter(x => x.app_id === w.app_id).sort((a, b) => String(Niri.titleOf(a)).localeCompare(String(Niri.titleOf(b))));
        if (mine.length > 1) {
            out.push(sep("w:2"));
            for (const x of mine)
                out.push(item("w:win" + x.id, String(Niri.titleOf(x) || appName).slice(0, 60), {
                    "kind": "niri",
                    "action": "focus",
                    "id": x.id
                }, {
                    "toggle": "check",
                    "checked": x.id === w.id
                }));
        }
        return tidy(out);
    }

    // ---- running an item ----
    // keys and typed text go to the focused window once the menu has closed and the window has
    // the keyboard back
    property var _queue: []
    function trigger(it) {
        const act = it && it.act;
        if (!act || it.enabled === false)
            return;
        const w = window;
        switch (act.kind) {
        case "app":
            _send({
                "cmd": "activate",
                "id": act.id
            });
            break;
        case "keys":
            _queue = _queue.concat([["keys", act.keys]]);
            keyTimer.restart();
            break;
        case "seq":
            _queue = _queue.concat(act.steps.map(s => s.keys ? ["keys", s.keys] : ["type", String(s.type).replace(/^~/, Config.home)]));
            keyTimer.restart();
            break;
        case "run":
            Shell.exec(act.argv);
            break;
        case "desktop":
            if (entry && entry.actions && entry.actions[act.index])
                entry.actions[act.index].execute();
            break;
        case "about":
            aboutApp = {
                "name": appName,
                "id": appId,
                "icon": entry ? entry.icon : "",
                "comment": entry ? entry.comment || entry.genericName || "" : "",
                "pid": pid
            };
            break;
        case "quit":
            // the app's every window, through niri: the app may still ask to save
            for (const x of Niri.windows.filter(x => x.app_id === w.app_id && x.pid === w.pid))
                Niri.closeWindow(x.id);
            break;
        case "niri":
            niriAction(act, w);
            break;
        case "fn":
            act.fn();
            break;
        }
    }
    function niriAction(act, w) {
        if (!w)
            return;
        switch (act.action) {
        case "close":
            Niri.closeWindow(w.id);
            break;
        case "minimize":
            Minimize.minimize(w.id);
            break;
        case "fill":
            Niri.maximizeWindow(w.id);
            break;
        case "center":
            Niri.action(w.is_floating ? "CenterWindow" : "CenterColumn", w.is_floating ? {
                "id": w.id
            } : {});
            break;
        case "fullscreen":
            Niri.fullscreenWindow(w.id);
            break;
        case "float":
            Niri.toggleFloating(w.id);
            break;
        case "workspace":
            Niri.moveWindowToWorkspace(w.id, act.idx);
            break;
        case "output":
            Niri.moveWindowToMonitor(w.id, act.output);
            break;
        case "focus":
            Niri.focusWindow(act.id);
            break;
        }
    }
    Timer {
        id: keyTimer
        interval: 160
        onTriggered: root._pump()
    }
    function _pump() {
        if (!_queue.length || typer.running)
            return;
        const [kind, val] = _queue[0];
        _queue = _queue.slice(1);
        typer.command = kind === "keys" ? wtypeArgs(val) : ["wtype", "-d", "4", "--", val];
        typer.running = true;
    }
    Process {
        id: typer
        onExited: if (root._queue.length)
            keyTimer.restart()
    }
    // ["ctrl", "shift", "t"] → wtype -M ctrl -M shift -k t -m shift -m ctrl
    function wtypeArgs(keys) {
        const mods = ["ctrl", "shift", "alt", "logo"];
        const held = keys.filter(k => mods.includes(k));
        const rest = keys.filter(k => !mods.includes(k));
        const argv = ["wtype"];
        for (const m of held)
            argv.push("-M", m);
        for (const k of rest)
            argv.push("-k", k);
        for (const m of held.slice().reverse())
            argv.push("-m", m);
        return argv;
    }
    // ⌃⇧T — how a shortcut reads in a Mac menu (Control, Option, Shift, Command)
    function keyText(keys) {
        if (!keys || !keys.length)
            return "";
        const sym = {
            "ctrl": "⌃",
            "alt": "⌥",
            "shift": "⇧",
            "logo": "⌘"
        };
        const names = {
            "Return": "↩",
            "Escape": "⎋",
            "Delete": "⌦",
            "BackSpace": "⌫",
            "Tab": "⇥",
            "Left": "←",
            "Right": "→",
            "Up": "↑",
            "Down": "↓",
            "Home": "↖",
            "End": "↘",
            "Prior": "⇞",
            "Next": "⇟",
            "equal": "=",
            "plus": "+",
            "minus": "−",
            "comma": ",",
            "period": ".",
            "question": "?",
            "grave": "`",
            "space": I18n.t("Пробел", "Space")
        };
        const order = ["ctrl", "alt", "shift", "logo"];
        let out = "";
        for (const m of order)
            if (keys.includes(m))
                out += sym[m];
        for (const k of keys)
            if (!order.includes(k))
                out += names[k] || (k.length === 1 ? k.toUpperCase() : k);
        return out;
    }

    // the shell's own About panel for apps without one (modules/mac/MacAbout)
    property var aboutApp: null
}
