pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config

// Heaven's stars ✦: what the heaven lock's prayers cost and what they give.
//   earn     1 ✦ for every 10 minutes at the computer (not idle, not locked), the daily
//            login reward (LockStream.claim), the day's three tasks, the heavenly pass
//   wish     160 ✦ (the first unlock of a day prays for free): 3★ / 4★ / 5★ with the pity of
//            LockStream.wish; it gives a card for the album or one of the angel's skins —
//            Moon and Mint at 4★, Gold at 5★. A card she already has gives stars back.
//   album    the cards; a whole row of a rarity gives stars
//   tasks    three a day from what you really do (time at the computer, songs, windows,
//            breaks, the first try at the password, a prayer)
//   pass     a 30-day season: experience from the minutes, tasks and unlocks; a reward on
//            every level — stars, two frames for the login plate, the season's halo card
//   skins    the angel's recolours (shaders/angel_skin): Config.y2k.angelSkin, the helper on
//            the desktop and the lock wear it
// ~/.local/state/angelos/heaven-stars.json. Nothing here leaves the computer.
Singleton {
    id: root

    readonly property int wishCost: 160
    property int stars: 0
    property int earned: 0
    property var owned: ({
            "skins": [],
            "cards": {},
            "frames": [],
            "rows": []
        })
    property var day: ({})
    property var pass: ({})
    property var history: []
    property string freeWishDay: ""
    property bool loaded: false
    property bool gift: false
    signal rewarded(string text)
    // the first day of heaven: one prayer's worth to start with. Quietly, no desktop
    // notification: it also comes to every shell started on a fresh state (an update that
    // brings heaven, a test stand next to the live one sharing its D-Bus) and read like a
    // reward for publishing; the stars are just there, on the heaven lock and in Settings
    function welcome() {
        if (gift)
            return;
        gift = true;
        earn(wishCost, I18n.t("подарок на старт", "a gift to start with"), true);
    }

    // ---- the catalogue ----
    readonly property var skins: [
        {
            "id": "moon",
            "ru": "Лунная",
            "en": "Moonlit",
            "rarity": 4,
            "pink": [225, 0.55, 1.02, 1],
            "hair": [222, 0.22, 1.1, 1],
            "white": [0, -1, 0, 0]
        },
        {
            "id": "mint",
            "ru": "Мятная",
            "en": "Mint",
            "rarity": 4,
            "pink": [158, 0.7, 1.0, 1],
            "hair": [52, 0.55, 1.04, 1],
            "white": [0, -1, 0, 0]
        },
        {
            "id": "gold",
            "ru": "Золотая",
            "en": "Golden",
            "rarity": 5,
            "pink": [42, 0.95, 1.06, 1],
            "hair": [46, 1.0, 1.06, 1],
            "white": [45, 0.14, 0, 0]
        }
    ]
    readonly property var cards: [
        {
            "id": "heart",
            "icon": "heart",
            "ru": "Сердечко",
            "en": "A little heart",
            "rarity": 3
        },
        {
            "id": "spark",
            "icon": "sparkle",
            "ru": "Искорка",
            "en": "A spark",
            "rarity": 3
        },
        {
            "id": "cd",
            "icon": "cd",
            "ru": "Диск с плейлистом",
            "en": "The playlist disc",
            "rarity": 3
        },
        {
            "id": "pill",
            "icon": "pill",
            "ru": "Таблетка счастья",
            "en": "A happy pill",
            "rarity": 3
        },
        {
            "id": "nightlight",
            "icon": "moon",
            "ru": "Ночник",
            "en": "The night light",
            "rarity": 3
        },
        {
            "id": "morning",
            "icon": "sun",
            "ru": "Утро",
            "en": "Morning",
            "rarity": 3
        },
        {
            "id": "track",
            "icon": "music",
            "ru": "Любимый трек",
            "en": "The favourite song",
            "rarity": 3
        },
        {
            "id": "bell",
            "icon": "bell",
            "ru": "Колокольчик",
            "en": "A little bell",
            "rarity": 3
        },
        {
            "id": "selfie",
            "icon": "camera",
            "ru": "Селфи ангела",
            "en": "The angel's selfie",
            "rarity": 3
        },
        {
            "id": "calendar",
            "icon": "calendar",
            "ru": "Календарик",
            "en": "A little calendar",
            "rarity": 3
        },
        {
            "id": "mouse",
            "icon": "mouse",
            "ru": "Мышка",
            "en": "The mouse",
            "rarity": 3
        },
        {
            "id": "keys",
            "icon": "keyboard",
            "ru": "Клавиатурка",
            "en": "The keyboard",
            "rarity": 3
        },
        {
            "id": "falling",
            "icon": "sparkleStar",
            "ru": "Падающая звезда",
            "en": "A falling star",
            "rarity": 4
        },
        {
            "id": "onair",
            "icon": "star",
            "ru": "Звезда эфира",
            "en": "The star of the stream",
            "rarity": 4
        },
        {
            "id": "ghost",
            "icon": "ghost",
            "ru": "Призрак-друг",
            "en": "A ghost friend",
            "rarity": 4
        },
        {
            "id": "nightgame",
            "icon": "gamepad",
            "ru": "Ночной гейминг",
            "en": "Gaming at night",
            "rarity": 4
        },
        {
            "id": "eye",
            "icon": "eye",
            "ru": "Внимательный глаз",
            "en": "The watchful eye",
            "rarity": 4
        },
        {
            "id": "dayone",
            "icon": "chat",
            "ru": "Чат первого дня",
            "en": "The day-one chat",
            "rarity": 4
        },
        {
            "id": "heavenheart",
            "icon": "heart",
            "ru": "Сердце небес",
            "en": "The heart of heaven",
            "rarity": 5
        },
        {
            "id": "ophanim",
            "icon": "sun",
            "ru": "Нимб Офаним",
            "en": "The Ophanim halo",
            "rarity": 5
        }
    ]
    // a whole row of a rarity: stars back
    readonly property var rowReward: ({
            "3": 320,
            "4": 640,
            "5": 1280
        })
    readonly property var frames: [
        {
            "id": "rose",
            "ru": "Рамка «Розовое золото»",
            "en": "The Rose Gold frame"
        },
        {
            "id": "holo",
            "ru": "Рамка «Голограмма»",
            "en": "The Hologram frame"
        }
    ]
    function skin(id) {
        return skins.find(s => s.id === id) || null;
    }
    function card(id) {
        return cards.find(c => c.id === id) || null;
    }
    function hasSkin(id) {
        return (owned.skins || []).includes(id);
    }
    function cardCount(id) {
        return (owned.cards || {})[id] || 0;
    }
    readonly property int albumHave: cards.filter(c => cardCount(c.id) > 0).length
    // the skin she wears now: picked and owned; the game off doesn't open them — they are earned here
    readonly property var worn: {
        const id = Config.y2k.angelSkin || "";
        return id && hasSkin(id) ? skin(id) : null;
    }
    // the login plate's frame: picked and owned
    readonly property string frame: (owned.frames || []).includes(Config.lock.frame) ? Config.lock.frame : ""

    // ---- the save ----
    readonly property string file: Config.stateDir + "/heaven-stars.json"
    // a burst of changes (a ten-prayer) is written once
    function save() {
        if (loaded)
            saveSoon.restart();
    }
    Timer {
        id: saveSoon
        interval: 400
        onTriggered: root.writeNow()
    }
    function writeNow() {
        store.write(JSON.stringify({
            "stars": stars,
            "earned": earned,
            "owned": owned,
            "day": day,
            "pass": pass,
            "history": history.slice(-50),
            "freeWishDay": freeWishDay,
            "gift": gift
        }));
    }
    AsyncFile {
        id: store
        path: root.file
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text()) || {};
                root.stars = Math.max(0, Number(s.stars) || 0);
                root.earned = Math.max(0, Number(s.earned) || 0);
                root.owned = Object.assign({
                    "skins": [],
                    "cards": {},
                    "frames": [],
                    "rows": []
                }, s.owned || {});
                root.day = s.day || {};
                root.pass = s.pass || {};
                root.history = Array.isArray(s.history) ? s.history : [];
                root.freeWishDay = String(s.freeWishDay || "");
                root.gift = !!s.gift;
            } catch (e) {}
            root.loaded = true;
            root.newDay();
            root.welcome();
        }
        onLoadFailed: err => {
            root.loaded = true;
            root.newDay();
            root.welcome();
        }
    }

    // ---- the day: its tasks and what counts towards them ----
    function dayKey(d) {
        return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
    }
    readonly property var taskPool: [
        {
            "id": "active60",
            "ru": "Час за компьютером",
            "en": "An hour at the computer",
            "of": "active",
            "goal": 60
        },
        {
            "id": "active120",
            "ru": "Два часа за компьютером",
            "en": "Two hours at the computer",
            "of": "active",
            "goal": 120
        },
        {
            "id": "tracks5",
            "ru": "Послушай 5 треков",
            "en": "Listen to 5 songs",
            "of": "tracks",
            "goal": 5
        },
        {
            "id": "firsttry",
            "ru": "Войди с первой попытки",
            "en": "Unlock at the first try",
            "of": "firstTry",
            "goal": 1
        },
        {
            "id": "breaks2",
            "ru": "Сделай 2 перерыва (блокировка)",
            "en": "Take 2 breaks (lock the screen)",
            "of": "unlocks",
            "goal": 2
        },
        {
            "id": "windows10",
            "ru": "Открой 10 окон",
            "en": "Open 10 windows",
            "of": "windows",
            "goal": 10
        },
        {
            "id": "wish1",
            "ru": "Помолись у врат",
            "en": "Make a wish at the gate",
            "of": "wishes",
            "goal": 1
        }
    ]
    readonly property int taskReward: 20
    readonly property int allTasksBonus: 40
    readonly property var tasks: {
        const ids = day.tasks || [];
        return ids.map(id => taskPool.find(t => t.id === id)).filter(t => !!t).map(t => Object.assign({}, t, {
                    "have": Math.min(t.goal, (day.count || {})[t.of] || 0),
                    "done": (day.done || []).includes(t.id)
                }));
    }
    function newDay() {
        const today = dayKey(new Date());
        if (day.key === today)
            return;
        // three tasks, the same all day: picked by the date
        let h = 0;
        for (let i = 0; i < today.length; i++)
            h = (h * 31 + today.charCodeAt(i)) >>> 0;
        const pool = taskPool.map(t => t.id).filter(id => id !== "active120" || h % 2);
        const pick = [];
        while (pick.length < 3 && pool.length) {
            h = (h * 1103515245 + 12345) >>> 0;
            const i = h % pool.length;
            const id = pool.splice(i, 1)[0];
            // one task of time a day
            if (id.startsWith("active") && pick.some(p => p.startsWith("active")))
                continue;
            pick.push(id);
        }
        day = {
            "key": today,
            "tasks": pick,
            "count": {},
            "done": [],
            "bonus": false
        };
        save();
    }
    function count(what, n) {
        if (!loaded)
            return;
        newDay();
        const d = Object.assign({}, day);
        const c = Object.assign({}, d.count || {});
        c[what] = (c[what] || 0) + (n === undefined ? 1 : n);
        d.count = c;
        day = d;
        checkTasks();
        save();
    }
    function checkTasks() {
        const done = (day.done || []).slice();
        let changed = false;
        for (const t of tasks) {
            if (!t.done && t.have >= t.goal) {
                done.push(t.id);
                changed = true;
                earn(taskReward, I18n.t("задание «%1»", "task “%1”").arg(I18n.t(t.ru, t.en)));
                addXp(60);
            }
        }
        if (!changed)
            return;
        const d = Object.assign({}, day);
        d.done = done;
        if (!d.bonus && (d.tasks || []).every(id => done.includes(id))) {
            d.bonus = true;
            day = d;
            earn(allTasksBonus, I18n.t("все задания дня", "all of the day's tasks"));
        } else {
            day = d;
        }
    }

    // ---- earning and spending ----
    function earn(n, why, quiet) {
        if (n <= 0)
            return;
        stars += n;
        earned += n;
        save();
        const text = "+" + n + " ✦ · " + why;
        rewarded(text);
        if (why && !quiet && !Shell.locked && !Shell.lockPreview)
            // our own picture, not the theme's "starred": icon themes without a "status"
            // context (pixora on Windose…) have none, and the card showed a broken image (#47)
            notify.exec(["notify-send", "-a", "angelOS", "-h", "string:x-angelos-sound:stars", "-i", Quickshell.shellDir + "/data/icons/heaven-star.svg", I18n.t("Небеса", "Heaven"), text]);
    }
    Process {
        id: notify
    }
    function spend(n) {
        if (stars < n)
            return false;
        stars -= n;
        save();
        return true;
    }
    readonly property bool freeWishToday: freeWishDay !== dayKey(new Date())
    // will the next unlock pray: the day's free prayer, or 160 ✦ when that is switched on
    readonly property bool canWish: Config.lock.wish && (freeWishToday || (Config.lock.wishPaid && stars >= wishCost))

    // ---- the minutes at the computer: 1 ✦ per 10, experience for the pass ----
    IdleMonitor {
        id: idle
        enabled: root.loaded
        timeout: 180
        respectInhibitors: true
    }
    property int minuteCarry: 0
    Timer {
        interval: 60000
        repeat: true
        running: root.loaded
        onTriggered: {
            root.newDay();
            root.seasonCheck();
            if (idle.isIdle || Shell.locked)
                return;
            root.count("active");
            root.addXp(1);
            if (++root.minuteCarry >= 10) {
                root.minuteCarry = 0;
                root.earn(1, "");
            }
        }
    }
    // songs, windows
    // a song counts once it has played for 20 s (its title and artist settle first)
    property string lastTrack: ""
    Connections {
        target: Lyrics
        function onTrackKeyChanged() {
            songHeard.restart();
        }
    }
    Timer {
        id: songHeard
        interval: 20000
        onTriggered: {
            if (Lyrics.title && Lyrics.playing && Lyrics.trackKey !== root.lastTrack) {
                root.lastTrack = Lyrics.trackKey;
                root.count("tracks");
            }
        }
    }
    property var seenWindows: ({})
    Connections {
        target: Niri
        function onWindowsChanged() {
            const seen = Object.assign({}, root.seenWindows);
            let fresh = 0;
            for (const w of Niri.windows) {
                if (!seen[w.id]) {
                    seen[w.id] = true;
                    fresh++;
                }
            }
            const first = Object.keys(root.seenWindows).length === 0;
            root.seenWindows = seen;
            // the windows already open at start-up are not "opened"
            if (!first && fresh > 0)
                root.count("windows", fresh);
        }
    }
    // the lock tells: an unlock, at the first try or not
    function unlocked(fails) {
        count("unlocks");
        if (fails === 0)
            count("firstTry");
        addXp(30);
    }

    // ---- the prayer ----
    // pays for one (or takes the day's free one); false: not enough stars
    function payWish(free) {
        if (free && freeWishToday) {
            freeWishDay = dayKey(new Date());
            save();
            return true;
        }
        return spend(wishCost);
    }
    // what a prayer gives: {stars, kind: card|skin, id, name, icon, fresh, refund}
    function pull(dry) {
        const r = LockStream.wish(dry);
        const pickOf = list => list[Math.floor(Math.random() * list.length)];
        let out;
        if (r === 5) {
            const five = cards.filter(c => c.rarity === 5);
            if (!hasSkin("gold") && (Math.random() < 0.5 || five.every(c => cardCount(c.id) > 0)))
                out = {
                    "kind": "skin",
                    "id": "gold"
                };
            else
                out = {
                    "kind": "card",
                    "id": pickOf(five).id
                };
        } else if (r === 4) {
            const free = skins.filter(s => s.rarity === 4 && !hasSkin(s.id));
            if (free.length && Math.random() < 0.5)
                out = {
                    "kind": "skin",
                    "id": pickOf(free).id
                };
            else
                out = {
                    "kind": "card",
                    "id": pickOf(cards.filter(c => c.rarity === 4)).id
                };
        } else {
            out = {
                "kind": "card",
                "id": pickOf(cards.filter(c => c.rarity === 3)).id
            };
        }
        const it = out.kind === "skin" ? skin(out.id) : card(out.id);
        out.stars = r;
        out.name = I18n.t(it.ru, it.en);
        out.icon = out.kind === "skin" ? "heart" : it.icon;
        out.fresh = out.kind === "skin" ? true : cardCount(out.id) === 0;
        out.refund = out.fresh ? 0 : r === 5 ? 120 : r === 4 ? 30 : 5;
        if (dry)
            return out;
        const o = JSON.parse(JSON.stringify(owned));
        if (out.kind === "skin")
            o.skins = (o.skins || []).concat([out.id]);
        else
            o.cards[out.id] = (o.cards[out.id] || 0) + 1;
        owned = o;
        history = history.concat([
            {
                "s": r,
                "k": out.kind,
                "id": out.id,
                "t": Date.now()
            }
        ]).slice(-50);
        count("wishes");
        save();
        if (out.refund)
            earn(out.refund, I18n.t("повтор «%1»", "a duplicate “%1”").arg(out.name));
        checkRows();
        return out;
    }
    function checkRows() {
        for (const r of [3, 4, 5]) {
            const row = cards.filter(c => c.rarity === r);
            const key = String(r);
            if (row.every(c => cardCount(c.id) > 0) && !(owned.rows || []).includes(key)) {
                const o = JSON.parse(JSON.stringify(owned));
                o.rows = (o.rows || []).concat([key]);
                owned = o;
                earn(rowReward[key], I18n.t("альбом: все %1★", "the album: every %1★").arg(r));
            }
        }
    }

    // ---- the heavenly pass: a season of 30 days, 30 levels of 300 experience ----
    readonly property int levelXp: 300
    readonly property int season: pass.season || 1
    readonly property int xp: pass.xp || 0
    readonly property int level: Math.min(30, Math.floor(xp / levelXp) + 1)
    readonly property real seasonDaysLeft: pass.start ? Math.max(0, 30 - (Date.now() - pass.start) / 86400000) : 30
    function passReward(lv) {
        if (lv === 10)
            return {
                "kind": "frame",
                "id": "rose",
                "stars": 0
            };
        if (lv === 20)
            return {
                "kind": "frame",
                "id": "holo",
                "stars": 0
            };
        if (lv === 30)
            return {
                "kind": "stars",
                "stars": 640
            };
        if (lv % 5 === 0)
            return {
                "kind": "stars",
                "stars": 160
            };
        return {
            "kind": "stars",
            "stars": 40
        };
    }
    function seasonCheck() {
        if (!loaded)
            return;
        if (!pass.start) {
            pass = {
                "season": 1,
                "start": Date.now(),
                "xp": 0,
                "claimed": 1
            };
            save();
        } else if (Date.now() - pass.start > 30 * 86400000) {
            pass = {
                "season": (pass.season || 1) + 1,
                "start": Date.now(),
                "xp": 0,
                "claimed": 1
            };
            save();
            rewarded(I18n.t("новый сезон небесного пропуска", "a new season of the heavenly pass"));
        }
    }
    function addXp(n) {
        if (!loaded)
            return;
        seasonCheck();
        const p = Object.assign({}, pass);
        p.xp = (p.xp || 0) + n;
        pass = p;
        while ((pass.claimed || 1) < level) {
            const lv = (pass.claimed || 1) + 1;
            const q = Object.assign({}, pass);
            q.claimed = lv;
            pass = q;
            const r = passReward(lv);
            if (r.kind === "frame" && !(owned.frames || []).includes(r.id)) {
                const o = JSON.parse(JSON.stringify(owned));
                o.frames = (o.frames || []).concat([r.id]);
                owned = o;
                const f = frames.find(x => x.id === r.id);
                rewarded(I18n.t("пропуск, уровень %1: %2", "the pass, level %1: %2").arg(lv).arg(I18n.t(f.ru, f.en)));
            }
            if (r.stars)
                earn(r.stars, I18n.t("пропуск, уровень %1", "the pass, level %1").arg(lv));
        }
        save();
    }
}
