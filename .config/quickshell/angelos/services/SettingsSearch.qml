pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Settings search: pages, groups and single settings, found by name or by a
// rough description ("прозрачность панели", "display", "ифк" typed in the wrong
// layout). The index comes from the pages' own QML (scripts/settings-index.py);
// the synonyms below connect everyday words to the angelOS names.
Singleton {
    id: root

    property var entries: []
    property bool loaded: false
    property string _raw: ""
    // Once. Start's and the launcher's result bindings call this on every keystroke,
    // and a new index re-runs them: reindexing from there looped forever (python +
    // JSON ~4 times a second, the shell at 90 % CPU) while a query sat in a closed Start.
    function load() {
        if (!loaded)
            reload();
    }
    // a fresh index (the settings window, when it opens); the same text changes nothing
    function reload() {
        if (!indexer.running)
            indexer.running = true;
    }
    Process {
        id: indexer
        command: ["python3", Quickshell.shellDir + "/scripts/settings-index.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.loaded && text === root._raw)
                    return;
                try {
                    root.entries = JSON.parse(text);
                    root._raw = text;
                    root.loaded = true;
                } catch (e) {}
            }
        }
    }

    // everyday words per page, both languages (also used for completion)
    readonly property var aliases: ({
            // only words the page itself doesn't say (its rows are found by their own names)
            // the pages of the settings tree (modules/settings/tree.json)
            "account": ["аккаунт", "имя", "аватарка", "язык", "мастер", "подсказки", "account", "name", "avatar", "language", "wizard", "tips"],
            "theme": ["тема", "цвет", "цвета", "палитра", "акцент", "оформление", "внешний вид", "theme", "color", "colour", "palette", "accent", "look", "appearance"],
            "fonts": ["шрифт", "текст", "размер текста", "буквы", "font", "text size", "typeface"],
            "wallpaper": ["обои", "фон", "картинка", "заставка стола", "wallpaper", "background", "picture", "image"],
            "capture": ["скриншот", "снимок экрана", "запись экрана", "screenshot", "recording", "capture"],
            "cursor": ["курсор", "указатель", "cursor", "pointer"],
            "widgets": ["виджет", "часы", "визуализатор", "cava", "widget", "clock", "visualizer"],
            "deskmenu": ["пкм", "правая кнопка", "контекстное меню", "меню рабочего стола", "меню обоев", "кольцо", "радиальное меню", "right click", "context menu", "desktop menu", "radial menu", "pie menu"],
            "taskbar": ["панель", "таскбар", "трей", "кнопки окон", "часы", "taskbar", "panel", "tray", "dock", "clock"],
            "start": ["пуск", "меню пуск", "кнопка пуск", "start", "start menu", "start button"],
            "workspaces": ["рабочие столы", "воркспейсы", "столы", "сердечки", "переход", "desks", "virtual desktops", "workspaces", "transition"],
            "lyrics": ["лирика", "текст песни", "караоке", "песня", "музыка", "lyrics", "song", "karaoke", "music"],
            "display": ["экран", "дисплей", "монитор", "разрешение", "частота", "герцы", "масштаб", "display", "screen", "monitor", "resolution", "refresh rate", "hz", "scale"],
            "keyboard": ["клавиатура", "раскладка", "голосовой ввод", "диктовка", "keyboard", "layout", "voice typing", "dictation"],
            "mouse": ["мышь", "мышка", "тачпад", "чувствительность", "лупа", "увеличение", "зум", "приблизить", "mouse", "touchpad", "sensitivity", "lens", "magnifier", "zoom"],
            "shortcuts": ["горячие клавиши", "хоткеи", "сочетания", "бинды", "клавиши", "shortcuts", "hotkeys", "keybinds", "bindings", "keys"],
            "windows": ["окна", "закрытие окон", "анимация закрытия", "отступы", "колонки", "диспетчер", "windows", "close", "gaps", "columns"],
            "sound": ["звук", "громкость", "микрофон", "аудио", "колонки", "наушники", "sound", "audio", "volume", "microphone", "speakers", "headphones"],
            "sfx": ["звуки", "звуки системы", "клик", "клики", "щелчок", "клавиши", "набор", "печать", "звук уведомления", "тихие часы", "sounds", "system sounds", "click", "clicks", "keys", "typing", "notification sound", "quiet hours"],
            "network": ["сеть", "интернет", "вайфай", "wifi", "network", "internet"],
            "bluetooth": ["блютуз", "беспроводные", "bluetooth", "wireless"],
            "gamepad": ["геймпад", "джойстик", "контроллер", "gamepad", "controller", "joystick"],
            "defaults": ["по умолчанию", "браузер", "терминал", "редактор", "файловый менеджер", "диспетчер задач", "default apps", "browser", "terminal", "editor", "file manager", "task manager"],
            "notifications": ["уведомления", "не беспокоить", "notifications", "do not disturb", "dnd"],
            "plugins": ["плагины", "расширения", "plugins", "extensions", "addons"],
            "lock": ["блокировка", "заставка", "пароль", "экран блокировки", "lock", "idle", "lock screen", "screensaver"],
            "updates": ["обновления", "версия", "updates", "upgrade", "version"],
            "about": ["система", "о системе", "компьютер", "отчёт", "system", "about", "computer", "report"],
            "power": ["питание", "производительность", "отрисовка", "power", "performance", "renderer"],
            "developer": ["разработчик", "режим разработчика", "отладка", "developer", "debug"],
            "stream": ["стрим", "эфир", "obs", "трансляция", "stream", "broadcast", "on air"],
            "game": ["игра", "спокойный режим", "выключить игру", "game", "calm"],
            "helper": ["y2k", "ангел", "ангелочек", "помощник", "помощница", "демоница", "облик", "angel", "helper", "demon", "looks"],
            "hell": ["ад", "круги", "демоница", "hell", "circles", "demon"],
            "novel": ["новелла", "истории", "сюжет", "novel", "stories", "story"]
        })
    // words that mean the same thing; a query word pulls in its whole group
    readonly property var synonyms: [
        ["блюр", "размытие", "blur", "стекло", "glass"],
        ["прозрачность", "непрозрачность", "opacity", "transparency", "прозрачный"],
        ["экран", "дисплей", "монитор", "display", "screen", "monitor"],
        ["звук", "аудио", "sound", "audio"],
        ["громкость", "volume", "громко", "тихо"],
        ["микрофон", "mic", "microphone", "мик"],
        ["обои", "фон", "wallpaper", "background"],
        ["тема", "theme", "оформление"],
        ["цвет", "цвета", "color", "colour", "палитра", "palette", "акцент", "accent"],
        ["тёмная", "темная", "dark", "ночная"],
        ["светлая", "light", "дневная"],
        ["шрифт", "font", "шрифты", "fonts"],
        ["клавиатура", "keyboard", "раскладка", "layout"],
        ["мышь", "мышка", "mouse", "курсор", "cursor", "указатель"],
        ["хоткей", "хоткеи", "горячие", "сочетание", "shortcut", "hotkey", "keybind", "бинд"],
        ["панель", "таскбар", "bar", "taskbar", "panel"],
        ["пуск", "start", "меню"],
        ["окно", "окна", "window", "windows"],
        ["закрыть", "закрытие", "close", "closing"],
        ["анимация", "анимации", "animation", "переход", "transition", "эффект"],
        ["стол", "столы", "воркспейс", "воркспейсы", "workspace", "desk"],
        ["уведомления", "notifications", "оповещения"],
        ["блокировка", "lock", "замок"],
        ["заставка", "idle", "screensaver"],
        ["лирика", "lyrics", "текст песни", "караоке"],
        ["сеть", "network", "wifi", "интернет", "вайфай"],
        ["размер", "size", "масштаб", "scale", "ширина", "width", "высота", "height"],
        ["скриншот", "screenshot", "снимок"],
        ["язык", "language", "english", "русский"],
        ["плагин", "plugin", "расширение"],
        ["обновление", "обновления", "update", "updates"],
        ["больше", "меньше", "крупнее", "мельче", "увеличить", "уменьшить", "bigger", "smaller", "larger", "размер", "масштаб", "scale", "size"],
        ["центр", "центру", "посередине", "середина", "center", "centre", "middle"],
        ["слева", "левый", "left"],
        ["справа", "правый", "right"],
        ["задач", "диспетчер", "task", "tasks", "монитор ресурсов", "btop"]
    ]
    // intent words that say nothing about *which* setting
    readonly property var stopwords: ["как", "где", "что", "это", "мне", "мой", "моя", "мои", "свой", "чтобы", "для", "на", "в", "во", "с", "со", "по", "и", "или", "не", "а", "у", "к", "от", "из", "сделать", "сменить", "поменять", "изменить", "включить", "выключить", "отключить", "настроить", "настройка", "настройки", "поставить", "убрать", "хочу", "нужно", "можно", "how", "to", "do", "i", "the", "a", "an", "my", "where", "what", "is", "change", "set", "enable", "disable", "turn", "on", "off", "make", "settings", "setting", "want"]
    // completion prefers these, in this order ("D" → Display, "Bl" → Blur)
    readonly property var common: ["Display", "Wallpaper", "Blur", "Bar", "Sound", "Theme", "Fonts", "Keyboard", "Mouse", "Monitor", "Lyrics", "Lock screen", "Notifications", "Network", "Bluetooth", "Cursor", "Widgets", "Workspaces", "Start menu", "Shortcuts", "Hotkeys", "Plugins", "Updates", "Screenshots", "Gamepad", "Transparency", "Opacity", "Animation", "Volume", "Microphone", "Language", "Task manager", "Close animation", "Обои", "Блюр", "Звук", "Тема", "Шрифты", "Экран", "Монитор", "Панель", "Пуск", "Клавиатура", "Мышь", "Лирика", "Блокировка", "Уведомления", "Сеть", "Курсор", "Виджеты", "Воркспейсы", "Горячие клавиши", "Плагины", "Обновления", "Скриншоты", "Прозрачность", "Размытие", "Громкость", "Микрофон", "Язык", "Анимация", "Диспетчер задач", "Закрытие окон"]

    // ---- text helpers ----
    function norm(s) {
        return String(s || "").toLowerCase().replace(/ё/g, "е").replace(/[«»"“”'’`.,:;!?()\[\]{}…·|/\\+*=<>#~_—–-]+/g, " ").replace(/\s+/g, " ").trim();
    }
    function words(s) {
        const n = norm(s);
        return n ? n.split(" ") : [];
    }
    readonly property string _en: "qwertyuiop[]asdfghjkl;'zxcvbnm,.`"
    readonly property string _ru: "йцукенгшщзхъфывапролджэячсмитьбюё"
    // the same keys typed in the other layout: "ифк" → "bar", "pdzr" → "звук"
    function swapLayout(s) {
        let out = "";
        for (const ch of String(s || "").toLowerCase()) {
            let i = _en.indexOf(ch);
            if (i >= 0) {
                out += _ru[i];
                continue;
            }
            i = _ru.indexOf(ch);
            out += i >= 0 ? _en[i] : ch;
        }
        return out;
    }
    // three reusable rows: no allocation per comparison
    property var _rows: [new Int32Array(64), new Int32Array(64), new Int32Array(64)]
    // stops early once every cell of a row is over `max` (then returns max + 1)
    function dist(a, b, max) {
        // Damerau–Levenshtein (optimal string alignment), small words only
        const m = a.length, n = b.length;
        if (Math.abs(m - n) > 2)
            return 9;
        if (n >= 63)
            return 9;
        let pp = _rows[0], prev = _rows[1], cur = _rows[2];
        for (let j = 0; j <= n; j++)
            prev[j] = j;
        for (let i = 1; i <= m; i++) {
            cur[0] = i;
            let low = i;
            for (let j = 1; j <= n; j++) {
                const c = a[i - 1] === b[j - 1] ? 0 : 1;
                let v = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + c);
                if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1] && pp[j - 2] + 1 < v)
                    v = pp[j - 2] + 1;
                cur[j] = v;
                if (v < low)
                    low = v;
            }
            if (max !== undefined && low > max)
                return max + 1;
            const t = pp;
            pp = prev;
            prev = cur;
            cur = t;
        }
        return prev[n];
    }
    // dist(a, b) <= 1 in one pass (one substitution, insertion, deletion or swap)
    function withinOne(a, b) {
        const m = a.length, n = b.length;
        if (m - n > 1 || n - m > 1)
            return false;
        let i = 0;
        while (i < m && i < n && a[i] === b[i])
            i++;
        if (i === m && i === n)
            return true;
        if (m === n)
            return a.slice(i + 1) === b.slice(i + 1) || (a[i] === b[i + 1] && a[i + 1] === b[i] && a.slice(i + 2) === b.slice(i + 2));
        return m > n ? a.slice(i + 1) === b.slice(i) : a.slice(i) === b.slice(i + 1);
    }
    // how well query word q matches text word t (0..1)
    function wordScore(q, t) {
        if (!q || !t)
            return 0;
        if (q === t)
            return 1;
        if (t.startsWith(q))
            return q.length === 1 ? 0.55 : 0.9;
        if (q.length < 3)
            return 0;
        // same stem: "панели" ~ "панелей", "обоями" ~ "обои"
        let k = 0;
        while (k < q.length && k < t.length && q[k] === t[k])
            k++;
        if (k >= 4 && k >= Math.max(q.length, t.length) - 3)
            return 0.8;
        if (k >= 3 && k === Math.min(q.length, t.length))
            return 0.75;
        if (t.includes(q))
            return 0.6;
        if (q.length >= 4 && q[0] === t[0]) {
            // a typo in the whole word or in the part typed so far ("blru" → "blur…")
            const part = t.slice(0, q.length);
            if (withinOne(q, t) || withinOne(q, part))
                return 0.65;
            if (q.length >= 7 && (dist(q, part, 2) <= 2 || dist(q, t, 2) <= 2))
                return 0.5;
        }
        return 0;
    }
    // synonym groups as normalized words, prepared once
    readonly property var synonymWords: synonyms.map(g => {
        const out = [];
        for (const w of g)
            for (const x of words(w))
                if (!out.includes(x))
                    out.push(x);
        return {
            "names": g.map(w => norm(w)),
            "words": out
        };
    })
    property var _expanded: ({})
    function expand(q) {
        // a query word and the words of its synonym groups
        if (_expanded[q])
            return _expanded[q];
        const out = [q];
        for (const g of synonymWords)
            if (g.names.some(w => wordScore(q, w) >= 0.8))
                for (const x of g.words)
                    if (!out.includes(x))
                        out.push(x);
        _expanded[q] = out;
        return out;
    }

    // ---- entries with their searchable fields, rebuilt when the index or pages change ----
    property var pageInfo: ({})       // id -> {label, icon} from the settings sidebar
    // hell's own groups and rows ("page|Russian title"): their pages hide them while the
    // angel is here (Angel.hellShown), so the search does too …
    readonly property var hellOnly: ["cursor|Курсор в аду", "y2k|Демоница", "y2k|ПКМ в аду", "y2k|Настройки в аду", "y2k|Виджеты в аду", "y2k|Курсор в аду", "y2k|Какой ад на обоях", "y2k|Трещины на экране", "y2k|Alt+Tab в аду", "y2k|Терминал в аду", "y2k|Приложения в аду", "y2k|Лирика в аду", "y2k|Колесо Ада", "y2k|Панель в аду", "y2k|Ад"]
    // … and these groups go by the angel's name there
    readonly property var heavenGroups: ({
            "y2k|Ангел или демон": {
                "ru": "Ангел и портал",
                "en": "Angel and the portal"
            },
            "sfx|Ангел и демоница": {
                "ru": "Ангелочек",
                "en": "The angel"
            }
        })
    function _inHeaven(e) {
        const key = e.page + "|" + e.ru, gkey = e.group ? e.page + "|" + e.group.ru : "";
        if (hellOnly.includes(key) || (gkey && hellOnly.includes(gkey)))
            return null;
        if (e.kind === "group" && heavenGroups[key])
            return Object.assign({}, e, heavenGroups[key]);
        if (gkey && heavenGroups[gkey])
            return Object.assign({}, e, {
                "group": heavenGroups[gkey]
            });
        return e;
    }
    readonly property var docs: {
        const lang = I18n.english ? "en" : "ru", other = I18n.english ? "ru" : "en";
        const heaven = !Angel.hellShown;
        const out = [];
        const seenPages = {};
        const developer = Config.developer.enabled;
        for (const raw of entries) {
            // developer mode's own groups and rows (the game's tools) only while it is on
            if (raw.developer && !developer)
                continue;
            const e = heaven && raw.kind !== "page" ? _inHeaven(raw) : raw;
            if (!e)
                continue;
            // the page of the tree it is on now (services/SettingsTree): a group by its name, a
            // page file by where its groups went (its old heading stays a word to find it by)
            const page = e.kind === "page" ? SettingsTree.resolve(e.page).page : SettingsTree.pageOfGroup(e.page, e.name || "");
            const info = pageInfo[page];
            if (!info)
                continue;   // hidden (owner/developer) or unknown pages
            const title = e.kind === "page" ? info.label : (e[lang] || e[other]);
            if (e.kind === "page") {
                if (seenPages[page])
                    continue;
                seenPages[page] = true;
            }
            out.push({
                "page": page,
                "kind": e.kind,
                "title": title,
                "target": e.kind === "page" ? "" : e[lang],
                "crumb": e.kind === "row" && e.group && e.group[lang] ? info.label + " › " + e.group[lang] : e.kind === "page" ? "" : info.label,
                "hint": e.hint ? e.hint[lang] : "",
                "icon": info.icon,
                "primary": words(title + (e.kind === "page" ? " " + (e[lang] || "") : "")),
                "other": words(e[other] || ""),
                "aliasNames": e.kind === "page" ? (aliases[page] || []).map(a => norm(a)) : [],
                "alias": e.kind === "page" ? words((aliases[page] || []).join(" ")) : [],
                "secondary": words((e.hint ? e.hint[lang] + " " + e.hint[other] : "") + " " + (e.words ? e.words[lang].join(" ") + " " + e.words[other].join(" ") : "")),
                "context": words(e.kind === "row" && e.group ? e.group[lang] + " " + e.group[other] : "")
            });
        }
        // pages without an index entry (plugins): name only
        for (const id in pageInfo)
            if (!seenPages[id])
                out.push({
                    "page": id,
                    "kind": "page",
                    "title": pageInfo[id].label,
                    "target": "",
                    "crumb": "",
                    "hint": "",
                    "icon": pageInfo[id].icon,
                    "primary": words(pageInfo[id].label),
                    "other": [],
                    "aliasNames": (aliases[id] || []).map(a => norm(a)),
                    "alias": words((aliases[id] || []).join(" ")),
                    "secondary": [],
                    "context": []
                });
        return out;
    }

    // ---- inverted index: every distinct word once, with the entries it is in ----
    // A keystroke used to score every word of every entry (~100 ms, far more on a
    // laptop CPU). Now a query word is matched against the vocabulary once and the
    // entries come from the posting lists. Field weights: name 3, alias 2.6, other
    // language 2.5, description 1.3, group 1 (an entry keeps its best field).
    readonly property var index: {
        const vocab = [], ids = {}, post = [];      // post[id] = [entry, weight, entry, weight, …]
        function add(w, d, weight, seen) {
            let id = ids[w];
            if (id === undefined) {
                id = ids[w] = vocab.length;
                vocab.push(w);
                post.push([]);
            }
            const at = seen[id];
            if (at === undefined) {
                seen[id] = post[id].length;
                post[id].push(d, weight);
            } else if (post[id][at + 1] < weight) {
                post[id][at + 1] = weight;
            }
        }
        for (let d = 0; d < docs.length; d++) {
            const doc = docs[d], seen = {};
            for (const w of doc.context)
                add(w, d, 1, seen);
            for (const w of doc.secondary)
                add(w, d, 1.3, seen);
            for (const w of doc.other)
                add(w, d, 2.5, seen);
            for (const w of doc.alias)
                add(w, d, 2.6, seen);
            for (const w of doc.primary)
                add(w, d, 3, seen);
        }
        const byFirst = {};
        for (let i = 0; i < vocab.length; i++)
            (byFirst[vocab[i][0]] = byFirst[vocab[i][0]] || []).push(i);
        // the whole vocabulary as one string for native substring search
        const starts = new Int32Array(vocab.length);
        let at = 1;
        for (let i = 0; i < vocab.length; i++) {
            starts[i] = at;
            at += vocab[i].length + 1;
        }
        return {
            "vocab": vocab,
            "post": post,
            "byFirst": byFirst,
            "joined": "\n" + vocab.join("\n") + "\n",
            "starts": starts,
            "titles": docs.map(x => norm(x.title))
        };
    }
    // per query word: [wordId, score, …] of the vocabulary words it matches; per text: results
    property var _hits: ({})
    property var _results: ({})
    onIndexChanged: {
        _hits = {};
        _results = {};
        _warm = synonymWords.reduce((all, g) => all.concat(g.words), []);
        warmer.restart();
    }
    // the first keystrokes that pull in a synonym group ("ра" → размер, размытие…)
    // would match ~30 words at once; match them in the background, a few per frame
    property var _warm: []
    Timer {
        id: warmer
        interval: 16
        repeat: true
        onTriggered: {
            for (let k = 0; k < 12 && root._warm.length; k++)
                root.hitsFor(root._warm.shift());
            if (!root._warm.length)
                stop();
        }
    }
    onSynonymWordsChanged: _expanded = {}
    function hitsFor(v) {
        let h = _hits[v];
        if (h)
            return h;
        h = [];
        const vocab = index.vocab;
        // wordScore is 0 unless both start alike or t contains v (3+ letters)
        for (const i of index.byFirst[v[0]] || []) {
            const s = wordScore(v, vocab[i]);
            if (s > 0)
                h.push(i, s);
        }
        if (v.length >= 3 && !v.includes("\n")) {
            const joined = index.joined, starts = index.starts;
            let last = -1;
            for (let at = joined.indexOf(v); at >= 0; at = joined.indexOf(v, at + 1)) {
                // the word the match falls in: last start <= at
                let lo = 0, hi = starts.length - 1;
                while (lo < hi) {
                    const mid = (lo + hi + 1) >> 1;
                    if (starts[mid] <= at)
                        lo = mid;
                    else
                        hi = mid - 1;
                }
                if (lo !== last && vocab[lo][0] !== v[0])
                    h.push(lo, 0.6);
                last = lo;
            }
        }
        _hits[v] = h;
        return h;
    }

    // one query variant against all entries at once
    function scoreAll(qwords, phrase) {
        const n = docs.length, post = index.post, titles = index.titles;
        const total = new Float64Array(n), hit = new Uint8Array(n), best = new Float64Array(n);
        for (const q of qwords) {
            best.fill(0);
            for (const v of expand(q)) {
                const syn = v === q ? 1 : 0.85, h = hitsFor(v);
                for (let k = 0; k < h.length; k += 2) {
                    const s = h[k + 1] * syn, p = post[h[k]];
                    for (let j = 0; j < p.length; j += 2) {
                        const x = s * p[j + 1];
                        if (x > best[p[j]])
                            best[p[j]] = x;
                    }
                }
            }
            for (let d = 0; d < n; d++)
                if (best[d] > 0) {
                    total[d] += best[d];
                    hit[d]++;
                }
        }
        const out = new Float64Array(n);
        for (let d = 0; d < n; d++) {
            if (!hit[d])
                continue;
            let s = total[d] * Math.pow(hit[d] / qwords.length, 1.5);
            const title = titles[d];
            if (title === phrase)
                s += 3;
            else if (title.startsWith(phrase))
                s += 1;
            else if (phrase.length > 2 && title.includes(phrase))
                s += 0.8;
            // a page's everyday name typed as is: "экран" → Monitor, "display" → Monitor
            if (docs[d].aliasNames.includes(phrase))
                s += 3.5;
            out[d] = s + (docs[d].kind === "page" ? 0.4 : docs[d].kind === "group" ? 0.2 : 0);
        }
        return out;
    }

    function meaningful(phrase) {
        const w = phrase.split(" ").filter(x => x && !stopwords.includes(x));
        return w.length ? w.join(" ") : phrase;
    }
    function search(text, limit) {
        const key = (limit || 12) + "\u0001" + text;
        if (_results[key])
            return _results[key];
        const phrase = meaningful(norm(text));
        if (!phrase)
            return [];
        const variants = [phrase];
        const swapped = meaningful(norm(swapLayout(phrase)));
        // only a real word typed in the other layout ("ифк" → bar): "блюр" turns into ",k.h",
        // whose stray single letters would match "keybinds" and "hotkeys"
        const letters = x => x.replace(/[\s]/g, "").length;
        if (swapped !== phrase && letters(norm(swapLayout(phrase))) === letters(phrase))
            variants.push(swapped);
        // what the ghost completion suggests counts too ("Bl" → Blur ranks first)
        const ghost = complete(text);
        if (ghost)
            variants.push(meaningful(norm(text + ghost)));
        const n = docs.length, best = new Float64Array(n);
        for (let i = 0; i < variants.length; i++) {
            const k = i === 0 ? 1 : variants[i] === swapped ? 0.92 : 1.1;
            const sc = scoreAll(variants[i].split(" "), variants[i]);
            for (let d = 0; d < n; d++)
                if (sc[d] * k > best[d])
                    best[d] = sc[d] * k;
        }
        // one or two letters only count against names, not descriptions
        const floor = phrase.length <= 2 ? 2.2 : 1.2;
        const res = [];
        for (let d = 0; d < n; d++)
            if (best[d] >= floor)
                res.push({
                    "doc": docs[d],
                    "score": best[d]
                });
        res.sort((a, b) => b.score - a.score || a.doc.title.length - b.doc.title.length);
        const out = [], seen = {};
        for (const r of res) {
            const key2 = r.doc.page + "|" + r.doc.title;
            if (seen[key2])
                continue;
            seen[key2] = true;
            out.push(Object.assign({
                "score": r.score
            }, r.doc));
            if (out.length >= (limit || 12))
                break;
        }
        // cleared in place: search() also runs inside bindings (Start, the launcher)
        if (Object.keys(_results).length > 400)
            for (const k in _results)
                delete _results[k];
        _results[key] = out;
        return out;
    }

    readonly property var vocabulary: {
        const v = {};
        for (const d of docs)
            for (const w of d.primary.concat(d.other, d.alias))
                v[w] = true;
        for (const c of common)
            for (const w of words(c))
                v[w] = true;
        return v;
    }
    // whole names for completion: common words, then page / group / row names
    readonly property var names: common.concat(docs.filter(d => d.kind === "page").map(d => d.title), docs.filter(d => d.kind === "group").map(d => d.title), docs.filter(d => d.kind === "row").map(d => d.title))
    // ghost completion for what is typed: the rest of the word or name ("Bl" → "ur")
    function complete(text) {
        const raw = String(text || "");
        if (!raw.trim() || /\s$/.test(raw))
            return "";
        const low = raw.toLowerCase();
        const lastStart = raw.search(/\S+$/);
        const last = raw.slice(lastStart).toLowerCase();
        // a finished word ("display") needs no completion
        if (last.length >= 3 && vocabulary[norm(last)])
            return "";
        const fit = w => w.toLowerCase().startsWith(low) && w.length > raw.length ? w.slice(raw.length) : "";
        const fitLast = w => w.toLowerCase().startsWith(last) && w.length > last.length ? w.slice(last.length) : "";
        for (const n of names) {
            const r = fit(n);
            if (r)
                return r;
        }
        if (lastStart > 0 && last.length >= 2)
            for (const n of names)
                for (const w of n.split(/\s+/)) {
                    const r = fitLast(w);
                    if (r)
                        return r;
                }
        return "";
    }
}
