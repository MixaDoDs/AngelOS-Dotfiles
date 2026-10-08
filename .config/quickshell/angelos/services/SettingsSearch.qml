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
    // what people looked for and didn't find (~/.local/state/angelos/settings-search-misses.log,
    // one "date<TAB>query" a line): the words to teach the search next
    function logMiss(q) {
        const t = String(q || "").trim();
        if (t.length < 3 || Shell.dev || Quickshell.env("ANGELOS_TEST") === "1")
            return;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s\t%s\n" "$(date -Iseconds)" "$2" >> "$1/settings-search-misses.log"', "sh", Config.stateDir, t]);
    }
    // words groups and rows are found by besides their own names (data/settings-keywords.json)
    property var keywords: ({})
    FileView {
        path: Quickshell.shellDir + "/data/settings-keywords.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.keywords = JSON.parse(text());
            } catch (e) {
                root.keywords = {};
            }
        }
    }
    // concepts (data/settings-concepts.json): a word like «ангел» or «рулетка» finds every place
    // tied to it, marked with the concept; also more synonym groups and the weak words
    property var conceptData: ({})
    FileView {
        path: Quickshell.shellDir + "/data/settings-concepts.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.conceptData = JSON.parse(text());
            } catch (e) {
                root.conceptData = {};
            }
        }
    }
    function keywordsOf(e) {
        if (e.kind === "page" || !e.name)
            return [];
        return (e.kind === "group" ? keywords[e.page + "/" + e.name] : keywords[e.page + "/" + e.name + "/" + e.ru]) || [];
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
            "account": ["аккаунт", "учётка", "учетная запись", "имя", "аватарка", "язык", "мастер", "подсказки", "восстановление", "бэкап", "account", "name", "avatar", "language", "wizard", "tips", "backup", "recovery"],
            "main": ["главная", "домой", "home", "start page"],
            "theme": ["тема", "цвет", "цвета", "палитра", "акцент", "оформление", "внешний вид", "скин", "windose", "golden gate", "macos", "theme", "color", "colour", "palette", "accent", "look", "appearance", "skin"],
            "fonts": ["шрифт", "текст", "размер текста", "буквы", "font", "text size", "typeface"],
            "wallpaper": ["обои", "фон", "картинка", "заставка стола", "wallpaper", "background", "picture", "image"],
            "capture": ["скриншот", "скрин", "снимок экрана", "запись экрана", "видео", "обс", "screenshot", "recording", "capture", "video", "grim", "wf-recorder"],
            "cursor": ["курсор", "указатель", "cursor", "pointer"],
            "widgets": ["виджет", "часы", "визуализатор", "cava", "гифка", "гиф", "анимация", "widget", "clock", "visualizer", "gif"],
            "deskmenu": ["пкм", "правая кнопка", "контекстное меню", "меню рабочего стола", "меню обоев", "кольцо", "радиальное меню", "right click", "context menu", "desktop menu", "radial menu", "pie menu"],
            "taskbar": ["панель", "таскбар", "трей", "кнопки окон", "часы", "taskbar", "panel", "tray", "clock"],
            "start": ["пуск", "меню пуск", "кнопка пуск", "meta", "win", "start", "start menu", "start button"],
            "workspaces": ["рабочие столы", "воркспейсы", "столы", "сердечки", "desks", "virtual desktops", "workspaces"],
            "lyrics": ["лирика", "текст песни", "караоке", "песня", "музыка", "lyrics", "song", "karaoke", "music"],
            "display": ["экран", "дисплей", "монитор", "разрешение", "частота", "герцы", "масштаб", "ночной свет", "display", "screen", "monitor", "resolution", "refresh rate", "hz", "scale", "night light"],
            "keyboard": ["клавиатура", "раскладка", "повтор клавиш", "numlock", "keyboard", "layout", "key repeat"],
            "mouse": ["мышь", "мышка", "тачпад", "чувствительность", "ускорение", "mouse", "touchpad", "sensitivity", "acceleration"],
            "shortcuts": ["горячие клавиши", "хоткеи", "сочетания", "бинды", "клавиши", "shortcuts", "hotkeys", "keybinds", "bindings", "keys"],
            "windows": ["окна", "заголовок", "кнопки окна", "отступы", "колонки", "фокус", "windows", "title bar", "gaps", "columns", "focus"],
            "alttab": ["альт таб", "переключение окон", "alt tab", "window switcher"],
            "animations": ["анимации", "анимация окон", "открытие окон", "animations", "window animation"],
            "sound": ["звук", "громкость", "микрофон", "аудио", "колонки", "наушники", "osd", "sound", "audio", "volume", "microphone", "speakers", "headphones"],
            "sfx": ["звуки", "звуки системы", "клик", "клики", "щелчок", "клавиши", "набор", "печать", "звук уведомления", "тихие часы", "sounds", "system sounds", "click", "clicks", "typing", "notification sound", "quiet hours", "грехи", "круги ада", "переход круга", "sins", "hell circles", "приглушить", "микшер", "duck"],
            "network": ["сеть", "интернет", "вайфай", "кабель", "wifi", "network", "internet", "ethernet"],
            "bluetooth": ["блютуз", "беспроводные", "наушники", "bluetooth", "wireless"],
            "gamepad": ["геймпад", "джойстик", "контроллер", "gamepad", "controller", "joystick"],
            "defaults": ["по умолчанию", "браузер", "терминал", "редактор", "файловый менеджер", "default apps", "browser", "terminal", "editor", "file manager"],
            "taskmanager": ["диспетчер задач", "системный монитор", "btop", "htop", "task manager", "system monitor"],
            "notifications": ["уведомления", "не беспокоить", "notifications", "do not disturb", "dnd"],
            "plugins": ["плагины", "расширения", "каталог", "plugins", "extensions", "addons", "store"],
            "studio": ["мастер плагинов", "создать плагин", "ии", "plugin studio", "ai"],
            "lock": ["блокировка", "заставка", "пароль", "экран блокировки", "экран входа", "sddm", "загрузка", "lock", "idle", "lock screen", "screensaver", "login screen", "boot"],
            "updates": ["обновления", "версия", "релиз", "откат", "updates", "upgrade", "version", "release", "rollback"],
            "about": ["система", "о системе", "компьютер", "отчёт", "баг", "system", "about", "computer", "report", "bug"],
            "power": ["питание", "производительность", "энергосбережение", "сон", "простой", "power", "performance", "sleep", "idle"],
            "lab": ["лаборатория", "эксперименты", "разработчик", "режим разработчика", "отладка", "отрисовка", "движок", "nvidia", "lab", "experiments", "developer", "debug", "renderer"],
            "terminal": ["терминал", "fastfetch", "фастфетч", "неофетч", "neofetch", "логотип в терминале", "консоль", "terminal", "console", "logo"],
            "stream": ["стрим", "эфир", "трансляция", "стример", "stream", "broadcast", "on air", "streamer"],
            "obs": ["obs", "обс", "websocket", "порт", "port"],
            "stream-angel": ["ангел на стриме", "стример", "вебка", "голос", "микрофон", "angel on stream", "streamer", "voice"],
            "uisize": ["размер интерфейса", "масштаб", "крупнее", "мельче", "пиксель", "ui size", "scale", "bigger", "smaller", "pixel"],
            "motion": ["меньше движения", "анимации", "тряска", "вспышки", "спокойно", "reduce motion", "animations", "shaking", "flashes", "calm"],
            "contrast": ["контраст", "прозрачность", "чёткость", "читаемость", "contrast", "transparency", "readability"],
            "lens": ["лупа", "увеличение", "зум", "приблизить", "magnifier", "lens", "zoom"],
            "shake": ["найти курсор", "потрясти мышь", "потерял курсор", "shake", "find pointer"],
            "voice": ["голосовой ввод", "диктовка", "voxtype", "voice typing", "dictation"],
            "helper": ["y2k", "ангел", "ангелочек", "помощник", "помощница", "демоница", "облик", "angel", "helper", "demon", "looks"],
            "game": ["игра", "спокойный режим", "ад", "круги", "портал", "новелла", "истории", "game", "calm", "hell", "circles", "portal", "novel"],
            "rewards": ["награды", "достижения", "ачивки", "звёзды", "звезды", "сундуки", "сундук", "пропуск", "молитвы", "rewards", "achievements", "stars", "chests", "pass"],
            "diary": ["дневник", "закладка", "diary", "bookmark"]
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
    readonly property var allSynonyms: synonyms.concat(conceptData.synonyms || [])
    // words that narrow a query down but don't make it ("режим разработчика", "debug игры"): one
    // of them found nowhere costs a third of what a real word would
    readonly property var weak: (conceptData.weak || []).map(w => norm(w))
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
    // a Russian word without its ending, roughly: «разработчика» → «разработчик», «обоями» and
    // «обои» → «обо», «игры» → «игр». Never shorter than three letters; other words stay whole
    readonly property var _endings: ["иями", "ями", "ами", "ого", "его", "ому", "ему", "ыми", "ими", "иях", "ах", "ях", "ов", "ев", "ей", "ой", "ий", "ый", "ая", "яя", "ое", "ее", "ые", "ие", "ую", "юю", "ом", "ем", "ам", "ям", "ия", "ию", "ии", "ью", "ть", "а", "я", "о", "е", "ы", "и", "у", "ю", "ь", "й"]
    function stem(w) {
        if (w.length < 4 || !/^[а-я]+$/.test(w))
            return w;
        for (const e of _endings)
            if (w.endsWith(e) && w.length - e.length >= 3)
                return w.slice(0, -e.length);
        return w;
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
    readonly property var synonymWords: allSynonyms.map(g => {
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
            "y2k|Рай и ад": {
                "ru": "Ангел и портал",
                "en": "Angel and the portal"
            },
            "sfx|Голос ангела и демоницы": {
                "ru": "Голос ангела",
                "en": "The angel's voice"
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
        const author = GameDebug.allowed;
        for (const raw of entries) {
            // developer mode's own groups and rows only while it is on; the author's (the
            // game's debug panel, owner/debug) only for the author
            if (raw.developer && !developer || raw.owner && !author)
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
                // a plain switch ("section.key"): the results show it, flipped right there
                "toggle": e.kind === "row" && e.toggle ? e.toggle : "",
                "icon": info.icon,
                // a page's section («Ангелочек ✧ › Игра») is where it is, not its name
                "primary": words((e.kind === "page" ? title.split(" › ").slice(-1)[0] + " " + (e[lang] || "") : title)),
                "other": words(e[other] || ""),
                "aliasNames": (e.kind === "page" ? aliases[page] || [] : keywordsOf(raw)).map(a => norm(a)),
                "alias": words((e.kind === "page" ? aliases[page] || [] : keywordsOf(raw)).join(" ")),
                "secondary": words((e.hint ? e.hint[lang] + " " + e.hint[other] : "") + " " + (e.words ? e.words[lang].join(" ") + " " + e.words[other].join(" ") : "")),
                "context": words(e.kind === "row" && e.group ? e.group[lang] + " " + e.group[other] : e.kind === "page" ? title.split(" › ").slice(0, -1).join(" ") : ""),
                // its Russian names (the concepts' places say them so, whatever the language)
                "keyTitle": e.kind === "page" ? "" : norm(e.ru),
                "keyGroup": e.kind === "row" && e.group ? norm(e.group.ru) : ""
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
                    "primary": words(pageInfo[id].label.split(" › ").slice(-1)[0]),
                    "other": [],
                    "aliasNames": (aliases[id] || []).map(a => norm(a)),
                    "alias": words((aliases[id] || []).join(" ")),
                    "secondary": [],
                    "context": words(pageInfo[id].label.split(" › ").slice(0, -1).join(" ")),
                    "keyTitle": "",
                    "keyGroup": ""
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
        const byFirst = {}, byStem = {};
        for (let i = 0; i < vocab.length; i++) {
            (byFirst[vocab[i][0]] = byFirst[vocab[i][0]] || []).push(i);
            const st = stem(vocab[i]);
            if (st !== vocab[i])
                (byStem[st] = byStem[st] || []).push(i);
        }
        // the whole vocabulary as one string for native substring search
        const starts = new Int32Array(vocab.length);
        let at = 1;
        for (let i = 0; i < vocab.length; i++) {
            starts[i] = at;
            at += vocab[i].length + 1;
        }
        // each entry's page entry (-1: none): a query word that names the page counts for what is on it
        const pageAt = {}, pageDoc = new Int32Array(docs.length), pages = [];
        for (let d = 0; d < docs.length; d++)
            if (docs[d].kind === "page") {
                pageAt[docs[d].page] = d;
                pages.push(d);
            }
        for (let d = 0; d < docs.length; d++)
            pageDoc[d] = docs[d].kind === "page" || pageAt[docs[d].page] === undefined ? -1 : pageAt[docs[d].page];
        return {
            "pageDoc": pageDoc,
            "pages": pages,
            "vocab": vocab,
            "post": post,
            "byFirst": byFirst,
            "byStem": byStem,
            "joined": "\n" + vocab.join("\n") + "\n",
            "starts": starts,
            "titles": docs.map(x => norm(x.title)),
            "titleLen": Int32Array.from(docs.map(x => x.title.length))
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
        // the same word with another ending: «разработчика» ~ «разработчик», «обоями» ~ «обои»
        const st = v.length >= 4 ? stem(v) : "";
        const same = st ? index.byStem[st] : null;
        if (same) {
            const had = {};
            for (let k = 0; k < h.length; k += 2)
                had[h[k]] = true;
            for (const i of same)
                if (!had[i])
                    h.push(i, 0.85);
        }
        _hits[v] = h;
        return h;
    }

    // one query variant against all entries at once
    function scoreAll(qwords, phrase) {
        const n = docs.length, post = index.post, titles = index.titles;
        const total = new Float64Array(n), hit = new Float64Array(n), best = new Float64Array(n), weakWords = weakSet;
        // how much each word counts: a weak one a third, one found nowhere (a typo, a stray
        // word) nothing — it can't fail what the others found
        let want = 0;
        for (const q of qwords) {
            best.fill(0);
            const w = weakWords[q] ? 0.35 : 1;
            let any = false;
            for (const v of expand(q)) {
                const syn = v === q ? 1 : 0.85, h = hitsFor(v);
                if (h.length)
                    any = true;
                for (let k = 0; k < h.length; k += 2) {
                    const s = h[k + 1] * syn, p = post[h[k]];
                    for (let j = 0; j < p.length; j += 2) {
                        const x = s * p[j + 1];
                        if (x > best[p[j]])
                            best[p[j]] = x;
                    }
                }
            }
            if (any)
                want += w;
            // «частота монитора»: the word that names the page («монитор» → Screens) counts for its
            // rows a little, so the other word decides among them
            if (qwords.length > 1 && index.pages.some(p => best[p] >= 2)) {
                const pageDoc = index.pageDoc;
                for (let d = 0; d < n; d++)
                    if (best[d] === 0 && pageDoc[d] >= 0 && best[pageDoc[d]] >= 2)
                        best[d] = 0.4;
            }
            for (let d = 0; d < n; d++)
                if (best[d] > 0) {
                    total[d] += best[d];
                    hit[d] += w;
                }
        }
        const out = new Float64Array(n);
        for (let d = 0; d < n; d++) {
            if (!hit[d])
                continue;
            let s = total[d] * Math.pow(Math.min(1, hit[d] / Math.max(want, 0.35)), 1.5);
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

    // ---- concepts: each with its tied entries [doc, weight, …], rebuilt with the docs ----
    readonly property var concepts: {
        const out = [];
        const lang = I18n.english ? "en" : "ru";
        for (const c of conceptData.concepts || []) {
            const names = (c.names || []).map(x => norm(x)).filter(x => x);
            const links = [], seen = {};
            function tie(d, weight) {
                if (seen[d] === undefined) {
                    seen[d] = links.length;
                    links.push(d, weight);
                }
            }
            // the curated places in their order, then whatever names one of its words
            (c.places || []).forEach((p, rank) => {
                const parts = p.split("/"), page = parts[0], rest = parts.slice(1).map(x => norm(x));
                for (let d = 0; d < docs.length; d++) {
                    const doc = docs[d];
                    if (doc.page !== page)
                        continue;
                    // "page", "page/*", "page/group or row", "page/group/row"
                    const fits = rest.length === 0 ? doc.kind === "page" : rest[0] === "*" ? true : rest.length === 1 ? !!doc.keyTitle && doc.keyTitle.includes(rest[0]) : doc.keyGroup.includes(rest[0]) && doc.keyTitle.includes(rest[1]);
                    if (fits)
                        tie(d, 4.6 - 0.05 * rank);
                }
            });
            const own = (c.words || []).map(x => norm(x)).filter(x => x);
            for (let d = 0; d < docs.length; d++) {
                const doc = docs[d];
                const text = " " + doc.primary.concat(doc.other, doc.alias, doc.context).join(" ") + " ";
                if (own.some(w => w.includes(" ") ? text.includes(" " + w + " ") : text.includes(" " + w)))
                    tie(d, 1.6);
            }
            out.push({
                "id": c.id,
                "label": c.label ? c.label[lang] || c.label.ru : c.id,
                "names": names,
                "stems": names.map(x => x.includes(" ") ? "" : stem(x)),
                "links": links
            });
        }
        return out;
    }
    // every name of every concept, looked up instead of walked through on each keystroke
    readonly property var conceptIndex: {
        const exact = {}, byStem = {}, single = {};
        concepts.forEach((c, ci) => c.names.forEach((n, i) => {
            (exact[n] = exact[n] || []).push(ci);
            if (n.includes(" "))
                return;
            (single[n[0]] = single[n[0]] || []).push(n, ci);
            if (c.stems[i].length >= 3)
                (byStem[c.stems[i]] = byStem[c.stems[i]] || []).push(ci);
        }));
        return {
            "exact": exact,
            "byStem": byStem,
            "single": single
        };
    }
    readonly property var weakSet: {
        const o = {};
        for (const w of weak)
            o[w] = true;
        return o;
    }
    // the concepts a query names, with how sure: the whole query one of its names 1, the same word
    // with another ending .95, its start typed .85, one typo .8; one word of several .6
    function conceptsFor(phrase) {
        const ix = conceptIndex, cs = concepts, got = {};
        function set(ci, v) {
            if (!(got[ci] >= v))
                got[ci] = v;
        }
        for (const ci of ix.exact[phrase] || [])
            set(ci, 1);
        const qw = phrase.split(" ");
        if (qw.length === 1) {
            const st = stem(phrase);
            if (st.length >= 3)
                for (const ci of ix.byStem[st] || [])
                    set(ci, 0.95);
            if (phrase.length >= 4) {
                const all = ix.single[phrase[0]] || [], len = phrase.length;
                for (let k = 0; k < all.length; k += 2) {
                    const n = all[k], ci = all[k + 1];
                    if (got[ci] >= 0.85)
                        continue;
                    if (n.startsWith(phrase))
                        set(ci, 0.85);
                    else if (len >= 5 && Math.abs(n.length - len) <= 1 && withinOne(phrase, n))
                        set(ci, 0.8);
                }
            }
        } else {
            for (const w of qw) {
                if (w.length < 3 || weakSet[w])
                    continue;
                for (const ci of ix.exact[w] || [])
                    set(ci, 0.6);
                const ws = stem(w);
                if (ws.length >= 3)
                    for (const ci of ix.byStem[ws] || [])
                        set(ci, 0.6);
            }
        }
        const out = [];
        for (const ci in got)
            out.push([cs[ci], got[ci]]);
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
        // what the concepts the query names are tied to: found too, marked with the concept
        // when that is the only way it was found
        const related = {};
        for (const v of variants.filter(x => x === phrase || x === swapped))
            for (const [c, q] of conceptsFor(v)) {
                const k = v === phrase ? 1 : 0.9;
                for (let j = 0; j < c.links.length; j += 2) {
                    const d = c.links[j], s = c.links[j + 1] * q * k;
                    if (s > best[d]) {
                        if (best[d] < floor)
                            related[d] = c.label;
                        best[d] = s;
                    }
                }
            }
        // the entries over the floor by score (then the shorter name), objects only for the ones shown
        const res = [], titleLen = index.titleLen;
        for (let d = 0; d < n; d++)
            if (best[d] >= floor)
                res.push(d);
        res.sort((a, b) => best[b] - best[a] || titleLen[a] - titleLen[b]);
        const out = [], seen = {};
        for (const d of res) {
            const doc = docs[d], key2 = doc.page + "|" + doc.title;
            if (seen[key2])
                continue;
            seen[key2] = true;
            out.push(Object.assign({
                "score": best[d],
                "related": related[d] || ""
            }, doc));
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
