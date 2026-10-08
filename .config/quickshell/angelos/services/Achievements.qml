pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../novel/NovelCore.js" as Core

// The achievements: little things done on the desktop, easy at first, then harder; some of
// them open heaven's things (services/Heaven). Only while the game is on — "Just the desktop"
// has none of it: nothing counted, nothing shown (and all of heaven open).
//
//   the list    story/achievements.json (the author edits it: Settings → the owner's
//               "Achievements" page, or by hand; «Publish» ships it) + the plugins' own
//               (manifest.json → "achievements", docs/PLUGINS.md)
//   the save    ~/.config/angelos/save.json → achievements (services/SaveSchema): what was
//               earned, which things it opened, the counters; `angelos game reset` clears it
//   counting    note(event, key): the shell's places call it (events below); an achievement
//               is earned when its counter reaches `count` (or `kinds` different keys) and its
//               `cond` holds — the story's conditions (NovelCore) over the game's variables
//               plus days, hour, calmDays, closeOwn, mac, earned, chapters and count("event"),
//               kinds("event"), got("id")
//   in a row    "within": N — the `count` events must follow each other at most N seconds
//               apart ("Six windows in a row"); the times are only kept while the shell runs
//   showing     a card slides in (modules/y2k/AchievementToast), one at a time, with a chime;
//               never over the lock screen or the first-run wizard (they wait). Hell's own
//               card while the demon rules, or for one marked "hell": true; a thing it gives
//               (story/items.json) lies in the card and opens from there
//   testing     the owner's page (owner/AchievementsAdmin → «Тест и сброс») and `angelos ach
//               reset | note <event> [key] [n] | grant | revoke | toast <id> [hell]`
Singleton {
    id: root

    property bool loaded: false
    property var doc: ({})   // story/achievements.json as read
    property string loadError: ""
    readonly property bool active: Story.enabled && Story.ready && loaded
    readonly property var feats: Story.feats
    readonly property var got: feats && feats.got ? feats.got : ({})
    readonly property var counts: feats && feats.counts ? feats.counts : ({})
    readonly property var kindsSeen: feats && feats.kinds ? feats.kinds : ({})

    readonly property var tiers: Array.isArray(doc.tiers) && doc.tiers.length ? doc.tiers : [
        {
            "id": 1,
            "ru": "Первые шаги",
            "en": "First steps"
        }
    ]
    // the list's own (story/achievements.json) and the enabled plugins'
    readonly property var own: (Array.isArray(doc.achievements) ? doc.achievements : []).filter(a => a && typeof a.id === "string" && a.id !== "" && !a.id.startsWith("plugin:"))
    readonly property var fromPlugins: {
        const out = [];
        for (const p of Plugins.plugins || []) {
            if (!Plugins.isEnabled(p) || !p.achievements)
                continue;
            for (const a of Array.from(p.achievements)) {
                if (!a || typeof a.id !== "string" || !a.id)
                    continue;
                const id = "plugin:" + p.id + "/" + a.id;
                out.push({
                    "id": id,
                    "plugin": p.id,
                    "pluginName": p.name,
                    "tier": Number(a.tier) || 2,
                    "icon": a.icon || p.icon || "plug",
                    "name": a.name || a.id,
                    "desc": a.desc || a.description || "",
                    "secret": !!a.secret,
                    "on": id,
                    "count": Math.max(1, Number(a.goal) || 1)
                });
            }
        }
        return out;
    }
    readonly property var list: own.concat(fromPlugins)
    readonly property int total: list.length
    readonly property int earned: list.filter(a => !!got[a.id]).length

    // ---- the events the shell counts (the admin page offers them; docs: this list) ----
    // `key`: what tells one from another (kinds counts the different ones)
    readonly property var events: [
        {
            "id": "angel.menu",
            "ru": "Клик по ангелу или демонице",
            "en": "A click on the angel or the demon",
            "key": "angel | demon"
        },
        {
            "id": "settings.open",
            "ru": "Открыть Настройки",
            "en": "Open Settings"
        },
        {
            "id": "start.open",
            "ru": "Открыть «Пуск»",
            "en": "Open Start",
            "key": "the Start look"
        },
        {
            "id": "launcher.open",
            "ru": "Открыть поиск приложений",
            "en": "Open the launcher"
        },
        {
            "id": "wallpaper.set",
            "ru": "Сменить обои",
            "en": "Change the wallpaper"
        },
        {
            "id": "screenshot",
            "ru": "Сделать скриншот",
            "en": "Take a screenshot"
        },
        {
            "id": "obs.stream",
            "ru": "Стрим в OBS (от минуты)",
            "en": "A stream in OBS (a minute or more)"
        },
        {
            "id": "obs.record",
            "ru": "Запись в OBS (от минуты)",
            "en": "A recording in OBS (a minute or more)"
        },
        {
            "id": "workspace.switch",
            "ru": "Перейти на другой рабочий стол",
            "en": "Go to another desk"
        },
        {
            "id": "hell.summon",
            "ru": "Призвать душу свечами пентаграммы",
            "en": "Summon a soul with the pentagram's candles",
            "key": "the soul's circle"
        },
        {
            "id": "deskmenu.toy",
            "ru": "Поиграть с меню по ПКМ в аду (колесо, вилка, камни…)",
            "en": "Play with hell's right-click menu (the wheel, the fork, the stones…)",
            "key": "the menu's look"
        },
        {
            "id": "deskmenu.open",
            "ru": "Меню по ПКМ на рабочем столе",
            "en": "The right-click menu on the desk",
            "key": "the menu's look"
        },
        {
            "id": "window.open",
            "ru": "Открылось окно",
            "en": "A window opened"
        },
        {
            "id": "widget.add",
            "ru": "Виджет на рабочий стол",
            "en": "A widget on the desk",
            "key": "the widget"
        },
        {
            "id": "accent.set",
            "ru": "Сменить палитру или акцент",
            "en": "Change the palette or the accent",
            "key": "the palette"
        },
        {
            "id": "lens.open",
            "ru": "Лупа у курсора",
            "en": "The lens at the pointer"
        },
        {
            "id": "clipboard.open",
            "ru": "История буфера обмена",
            "en": "The clipboard history"
        },
        {
            "id": "plugin.install",
            "ru": "Поставить плагин из каталога",
            "en": "Install a plugin from the catalog"
        },
        {
            "id": "plugin.create",
            "ru": "Создать свой плагин",
            "en": "Make a plugin of one's own"
        },
        {
            "id": "bar.edit",
            "ru": "Переставить панель",
            "en": "Rearrange the bar"
        },
        {
            "id": "deskmenu.custom",
            "ru": "Свой пункт в меню по ПКМ",
            "en": "An own entry in the right-click menu"
        },
        {
            "id": "novel.chapter",
            "ru": "Дочитать главу новеллы",
            "en": "Finish a chapter of the novel",
            "key": "the chapter"
        },
        {
            "id": "fall",
            "ru": "Ангел упала в ад",
            "en": "The angel fell into hell"
        },
        {
            "id": "circle",
            "ru": "Войти в круг ада",
            "en": "Enter a circle of hell",
            "key": "the circle"
        },
        {
            "id": "outcome",
            "ru": "Исход из ада",
            "en": "An outcome of hell",
            "key": "stars | pact | limbo | amnesty"
        },
        {
            "id": "lock",
            "ru": "Заблокировать экран",
            "en": "Lock the screen"
        },
        {
            "id": "theme.set",
            "ru": "Сменить тему: светлая, тёмная, авто",
            "en": "Change the theme: light, dark, auto",
            "key": "light | dark | auto"
        },
        {
            "id": "file.open",
            "ru": "Открыть файл из поиска",
            "en": "Open a file from the search",
            "key": "the kind: image | video | document…"
        },
        {
            "id": "diary.open",
            "ru": "Открыть дневник Ангела",
            "en": "Open the Angel's diary",
            "key": "heaven | hell"
        },
        {
            "id": "diary.sneak",
            "ru": "Открыть дневник, пока ангела нет",
            "en": "Open the diary while the angel is away"
        },
        {
            "id": "diary.caught",
            "ru": "Ангел застала с дневником",
            "en": "The angel caught you with the diary",
            "key": "open | again | back"
        },
        {
            "id": "diary.page",
            "ru": "Прочитать страницу дневника",
            "en": "Read a page of the diary",
            "key": "the page"
        },
        {
            "id": "wellbeing.water",
            "ru": "Выпить стакан воды (Благополучие)",
            "en": "Drink a glass of water (Wellbeing)"
        },
        {
            "id": "wellbeing.break",
            "ru": "Сделать перерыв по напоминанию",
            "en": "Take a break when reminded",
            "key": "eyes | move"
        }
    ]
    // + "act:<name>" for every action of story/game.json (a joke, "I love you", the throws…)
    readonly property var eventIds: events.map(e => e.id).concat(Object.keys(Story.rules.actions || {}).map(n => "act:" + n))
    // "event" or "event:key" (one kind of it: "outcome:pact", "angel.menu:angel")
    function knownEvent(on) {
        on = String(on || "");
        return eventIds.includes(on) || (on.lastIndexOf(":") > 0 && eventIds.includes(on.slice(0, on.lastIndexOf(":"))));
    }
    // the condition's own variables (besides the game's, Story.ctxVars)
    readonly property var condVars: ["days", "hour", "weekday", "calmDays", "closeOwn", "mac", "earned", "chapters", "realm"]

    // ---- counting ----
    // > 0 while the demon's pranks change settings: what she does is not the player's
    property int mute: 0
    readonly property double startedAt: Date.now()
    // the shell has settled (the windows and desks niri lists at start are not opened by anyone)
    function settled() {
        return Date.now() - startedAt > 15000;
    }
    // when each event happened lately (for "within"): {event: [ms…]}, "event:key" too
    property var _times: ({})
    function _stamp(name, n) {
        const t = Date.now();
        const list = (_times[name] || []).filter(x => t - x < 3600000);
        for (let i = 0; i < n; i++)
            list.push(t);
        _times[name] = list.slice(-200);
    }
    // the longest run of `event` that ends with its last time, each at most `sec` after the one before
    function streak(event, sec) {
        const list = _times[event] || [];
        if (!list.length)
            return 0;
        const gap = Math.max(0.1, Number(sec) || 0) * 1000;
        let n = 1;
        for (let i = list.length - 1; i > 0 && list[i] - list[i - 1] <= gap; i--)
            n++;
        // a run that ended long ago is no run now
        return Date.now() - list[list.length - 1] <= gap ? n : 0;
    }
    function note(event, key, times) {
        if (!active || mute > 0 || !event)
            return;
        const n = Math.max(1, Math.floor(Number(times) || 1));
        key = key === undefined || key === null ? "" : String(key);
        _stamp(event, n);
        if (key !== "")
            _stamp(event + ":" + key, n);
        const c = Object.assign({}, counts);
        c[event] = (c[event] || 0) + n;
        if (key !== "") {
            c[event + ":" + key] = (c[event + ":" + key] || 0) + n;
            const seen = kindsSeen[event] ? Array.from(kindsSeen[event]) : [];
            if (!seen.includes(key)) {
                const k = Object.assign({}, kindsSeen);
                k[event] = seen.concat([key]);
                feats.kinds = k;
            }
        }
        feats.counts = c;
        if (!feats.since)
            feats.since = Date.now();
        checkSoon.restart();
    }
    function count(event) {
        return counts[event] || 0;
    }
    function kinds(event) {
        return kindsSeen[event] ? Array.from(kindsSeen[event]).length : 0;
    }
    readonly property var fns: ({
            "count": e => root.count(String(e)),
            "kinds": e => root.kinds(String(e)),
            "got": id => !!root.got[String(id)]
        })
    function ctx() {
        const v = Story.ctxVars();
        const t = Date.now();
        const from = Story.createdAt || feats.since || t;
        const close = Story.hell.close || {};
        v.days = Math.max(0, Math.floor((t - from) / 86400000));
        v.hour = new Date().getHours();
        v.weekday = new Date().getDay();
        v.calmDays = Math.max(0, Math.floor((t - Math.max(from, Story.player.lastThrow || 0)) / 86400000));
        v.closeOwn = Object.keys(close).filter(c => Story.closeStepOf((close[c] || {}).points || 0) >= 3).length;
        v.mac = GoldenGate.on;
        v.earned = earned;
        v.chapters = Object.keys(((Story.novelState || {}).done) || {}).length;
        return v;
    }
    // the condition's problem ("" = fine): the admin page checks before it saves
    function condError(expr) {
        return Core.checkCond(expr, fns);
    }
    property var _badCond: ({})
    function met(a, vars) {
        if (!a.on && !a.cond)
            return false;
        if (a.on) {
            const need = Math.max(1, a.count || 1);
            if (a.within > 0 ? streak(a.on, a.within) < need : a.kinds > 0 ? kinds(a.on) < a.kinds : count(a.on) < need)
                return false;
        }
        if (a.cond) {
            try {
                return Core.evalCond(a.cond, vars || ctx(), [], fns);
            } catch (e) {
                if (!_badCond[a.id]) {
                    _badCond[a.id] = true;
                    console.warn("story/achievements.json: " + a.id + ": " + e.message);
                }
                return false;
            }
        }
        return true;
    }
    // how far along: {n, of} for a counted one, null otherwise
    function progress(a) {
        if (!a || !a.on)
            return null;
        const of = a.kinds > 0 ? a.kinds : Math.max(1, a.count || 1);
        if (of <= 1)
            return null;
        return {
            "n": Math.min(of, a.within > 0 ? streak(a.on, a.within) : a.kinds > 0 ? kinds(a.on) : count(a.on)),
            "of": of
        };
    }
    function check() {
        if (!active)
            return 0;
        const vars = ctx();
        let n = 0;
        for (const a of list)
            if (!got[a.id] && met(a, vars) && grant(a.id))
                n++;
        return n;
    }
    Timer {
        id: checkSoon
        interval: 400
        onTriggered: root.check()
    }
    // the days, the hour, the angel's warmth and the demons change without an event
    Timer {
        running: root.active
        interval: 60000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.check()
    }

    // ---- what the shell does, watched here ----
    Connections {
        target: Shell
        function onSettingsOpenChanged() {
            if (Shell.settingsOpen)
                root.note("settings.open");
        }
        function onLauncherOpenChanged() {
            if (Shell.launcherOpen)
                root.note("launcher.open");
        }
        function onClipboardOpenChanged() {
            if (Shell.clipboardOpen)
                root.note("clipboard.open");
        }
        function onLockedChanged() {
            if (Shell.locked)
                root.note("lock");
        }
        function onStartScreenChanged() {
            // the kind: the pixel skins' Start looks (Golden Gate's Spotlight is not one of them)
            if (Shell.startScreen !== "")
                root.note("start.open", GoldenGate.on ? "" : StartPrefs.current);
        }
    }
    Connections {
        target: Niri
        function onWindowOpened(id) {
            if (root.settled())
                root.note("window.open");
        }
        function onWorkspaceActivated(ws, focused) {
            if (focused && root.settled())
                root.note("workspace.switch");
        }
    }
    Connections {
        target: Plugins
        function onCreated(id, ok) {
            if (ok)
                root.note("plugin.create", id);
        }
    }
    // settings the player changes (not the file loading, not the demon's pranks: mute)
    function changedByHand() {
        return Config.ready && settled();
    }
    // the colours: the pixel skins' palette, Golden Gate's accent
    Connections {
        target: Config.appearance
        function onFlavorChanged() {
            if (root.changedByHand())
                root.note("accent.set", Config.appearance.flavor);
        }
    }
    Connections {
        target: Config.appearance
        function onModeChanged() {
            if (root.changedByHand())
                root.note("theme.set", Config.appearance.mode);
        }
    }
    Connections {
        target: Config.mac
        function onAccentChanged() {
            if (root.changedByHand())
                root.note("accent.set", "mac:" + Config.mac.accent);
        }
    }
    Connections {
        target: Config.bar
        function onLayoutChanged() {
            if (root.changedByHand())
                root.note("bar.edit");
        }
    }
    property int _customCount: -1
    Connections {
        target: Config.desktop
        function onMenuCustomChanged() {
            const n = (Config.desktop.menuCustom || []).length;
            if (root.changedByHand() && root._customCount >= 0 && n > root._customCount)
                root.note("deskmenu.custom");
            root._customCount = n;
        }
    }
    Component.onCompleted: _customCount = Config.ready ? (Config.desktop.menuCustom || []).length : -1

    // ---- earning ----
    function find(id) {
        return list.find(a => a.id === id) || null;
    }
    function has(id) {
        return !!got[id];
    }
    function grant(id, quiet) {
        const a = find(id);
        if (!a || got[id] || !Story.enabled || !Story.ready)
            return false;
        const g = Object.assign({}, got);
        g[id] = Date.now();
        feats.got = g;
        if (a.reward && Heaven.ids.includes(a.reward)) {
            const it = Object.assign({}, feats.items || {});
            it[a.reward] = Date.now();
            feats.items = it;
        }
        if (!quiet)
            announce(a);
        return true;
    }
    // taken back (the admin testing): the thing it opened goes too, unless another earned one gives it
    function revoke(id) {
        if (!got[id])
            return false;
        const a = find(id);
        const g = Object.assign({}, got);
        delete g[id];
        feats.got = g;
        if (a && a.reward && !list.some(o => o.id !== id && o.reward === a.reward && g[o.id])) {
            const it = Object.assign({}, feats.items || {});
            delete it[a.reward];
            feats.items = it;
        }
        return true;
    }
    // heaven's things (services/Heaven)
    function itemEarned(item) {
        return !!(feats.items || {})[item] || list.some(a => a.reward === item && !!got[a.id]);
    }
    function giverOf(item) {
        return own.find(a => a.reward === item) || null;
    }

    // ---- words ----
    function nameOf(a) {
        if (!a)
            return "";
        if (a.secret && !got[a.id])
            return "???";
        return I18n.label(a.name) || a.id;
    }
    function descOf(a) {
        if (!a)
            return "";
        if (a.secret && !got[a.id])
            return I18n.t("тайное достижение", "a secret achievement");
        return I18n.label(a.desc) || "";
    }
    function tierName(n) {
        const t = tiers.find(x => Number(x.id) === Number(n));
        return t ? I18n.t(t.ru || t.en || "", t.en || t.ru || "") : String(n);
    }
    function eventLabel(id) {
        const e = events.find(x => x.id === id);
        if (e)
            return I18n.t(e.ru, e.en);
        if (String(id).startsWith("act:")) {
            const a = (Story.rules.actions || {})[id.slice(4)];
            return I18n.t("Действие игры: ", "A game action: ") + id.slice(4) + (a && a.note ? " — " + a.note : "");
        }
        return id;
    }

    // ---- the card (modules/y2k/AchievementToast) ----
    property var queue: []
    property var current: null
    readonly property bool canShow: !Shell.locked && !Shell.setupLocked && !Shell.lockPreview
    // hell: hell's own card (null: hell's when the demon rules or the achievement is hell's)
    function announce(a, hell) {
        const thing = a.reward ? Heaven.thing(a.reward) : null;
        queue = queue.concat([{
                "kind": "achievement",
                "id": a.id,
                "name": I18n.label(a.name) || a.id,
                "desc": I18n.label(a.desc) || "",
                "icon": a.icon || "star",
                "tier": a.tier || 1,
                "secret": !!a.secret,
                "hell": hell === undefined || hell === null ? !!a.hell : !!hell,
                "reward": a.reward && Heaven.ids.includes(a.reward) ? Heaven.label(a.reward) : "",
                // a thing lies in the card: its picture and what it opens
                "thing": thing ? thing.id : "",
                "texture": thing ? thing.texture : null,
                "thingDesc": thing ? I18n.label(thing.desc) : "",
                "plugin": a.pluginName ? I18n.label(a.pluginName) : ""
            }]);
        pump();
    }
    // a new page of the Angel's diary (services/Diary)
    function announceDiary(pages, hell) {
        if (!pages || !pages.length)
            return;
        const p = pages[0];
        const thing = Diary.thing;
        queue = queue.concat([{
                "kind": "diary",
                "id": "diary:" + p.id,
                "page": p.id,
                "name": I18n.label(p.title) || p.id,
                "desc": pages.length > 1 ? I18n.t("и ещё страниц: ", "and more pages: ") + (pages.length - 1) : I18n.label(p.date) || "",
                "icon": "document",
                "tier": 1,
                "secret": false,
                "hell": hell === undefined || hell === null ? p.hand === "demon" : !!hell,
                "reward": "",
                "thing": thing ? thing.id : "",
                "texture": thing ? thing.texture : null,
                "thingDesc": "",
                "plugin": ""
            }]);
        pump();
    }
    function pump() {
        if (current || !queue.length || !canShow || !Story.enabled)
            return;
        current = queue[0];
        queue = queue.slice(1);
        Sounds.play("achievement");
    }
    // the card is gone: the next one
    function shown() {
        current = null;
        Qt.callLater(pump);
    }
    onCanShowChanged: pump()
    // the game turned off: nothing more shows
    Connections {
        target: Story
        function onEnabledChanged() {
            if (!Story.enabled) {
                root.queue = [];
                root.current = null;
            }
        }
    }

    // ---- the list: story/achievements.json ----
    readonly property string file: Quickshell.shellDir + "/story/achievements.json"
    FileView {
        id: dataFile
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
                console.warn("story/achievements.json: " + e);
            }
            root._badCond = ({});
            root.loaded = true;
            checkSoon.restart();
        }
        onLoadFailed: {
            root.doc = ({});
            root.loaded = true;
        }
    }
    // what is wrong with a list (the admin page shows it, the self-test and `angelos ach validate` too)
    function problems(d) {
        const out = [];
        const seen = {};
        const tierIds = (Array.isArray(d.tiers) ? d.tiers : []).map(t => Number(t.id));
        for (const a of Array.isArray(d.achievements) ? d.achievements : []) {
            const id = a && a.id;
            if (!id || typeof id !== "string" || !/^[a-z0-9][a-z0-9._-]*$/.test(id)) {
                out.push(I18n.t("плохой id: ", "bad id: ") + JSON.stringify(id));
                continue;
            }
            if (seen[id])
                out.push(id + I18n.t(": id повторяется", ": the id is used twice"));
            seen[id] = true;
            if (!I18n.label(a.name))
                out.push(id + I18n.t(": нет названия", ": no name"));
            if (!tierIds.includes(Number(a.tier)))
                out.push(id + I18n.t(": нет такой ступени ", ": no such tier ") + a.tier);
            if (!a.on && !a.cond)
                out.push(id + I18n.t(": нет условия (событие или выражение)", ": no condition (an event or an expression)"));
            if (a.on && !knownEvent(a.on))
                out.push(id + I18n.t(": неизвестное событие ", ": unknown event ") + a.on);
            if (a.cond) {
                const e = condError(a.cond);
                if (e)
                    out.push(id + I18n.t(": условие: ", ": condition: ") + e);
            }
            if (a.reward && !Heaven.ids.includes(a.reward))
                out.push(id + I18n.t(": неизвестная награда ", ": unknown reward ") + a.reward);
            if (a.within !== undefined && !(Number(a.within) > 0))
                out.push(id + I18n.t(": within — секунды больше нуля", ": within: seconds above zero"));
            if (a.within > 0 && !a.on)
                out.push(id + I18n.t(": within без события", ": within without an event"));
            if (a.within > 0 && a.kinds > 0)
                out.push(id + I18n.t(": within и kinds вместе не бывают", ": within and kinds don't go together"));
        }
        return out;
    }
    // the author's edit (the owner's page): written only when nothing is wrong
    function saveData(d) {
        const bad = problems(d);
        if (bad.length)
            return bad;
        dataFile.setText(JSON.stringify(d, null, 2) + "\n");
        doc = JSON.parse(JSON.stringify(d));
        checkSoon.restart();
        return [];
    }

    // ---- the owner's testing (owner/AchievementsAdmin, `angelos ach reset | note`) ----
    // everything earned, counted and read goes: as on a fresh save (the game's own save stays)
    function resetAll() {
        if (!feats)
            return false;
        feats.got = ({});
        feats.items = ({});
        feats.counts = ({});
        feats.kinds = ({});
        feats.since = 0;
        feats.diary = ({});
        _times = ({});
        queue = [];
        current = null;
        return true;
    }
    // only the counters (what was earned stays)
    function resetCounts() {
        if (!feats)
            return false;
        feats.counts = ({});
        feats.kinds = ({});
        _times = ({});
        return true;
    }
    // an event as if the shell saw it: past `settled`, the demon's mute and the game's pace
    function simulate(event, key, times) {
        if (!active || !event)
            return false;
        const m = mute;
        mute = 0;
        note(event, key, times);
        mute = m;
        return true;
    }

    // ---- `angelos ach …` (modules/Ipc) ----
    function status() {
        return JSON.stringify({
            "game": Story.enabled,
            "active": active,
            "earned": earned + " / " + total,
            "got": Object.keys(got),
            "heaven": Heaven.items.map(i => i.id + (Heaven.has(i.id) ? " open" : " locked")),
            "queue": queue.length
        }, null, 1);
    }
    function listText() {
        return list.map(a => (got[a.id] ? "✓ " : "· ") + a.id + " [" + (a.tier || 1) + "] " + (I18n.label(a.name) || "") + (a.within > 0 ? " (" + (a.count || 1) + " in a row, ≤" + a.within + " s)" : "") + (a.reward ? " → " + a.reward : "") + (a.secret ? " (secret)" : "") + (a.hell ? " (hell)" : "")).join("\n");
    }
    // a plugin's own (Plugins.context → plugin.achieve / plugin.progress)
    function pluginAchieve(pid, aid) {
        return grant("plugin:" + pid + "/" + aid);
    }
    function pluginProgress(pid, aid, n) {
        note("plugin:" + pid + "/" + aid, "", n);
    }
}
