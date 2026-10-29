pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Guided tips: UI elements register here, the overlay circles them one by one.
Singleton {
    id: root

    property bool running: false
    property int step: 0
    property string screen: ""       // where it runs (Shell.mainScreenFor)
    property var _items: ({})       // key -> [{item, window}, …]: one per bar that has it
    property int revision: 0

    function register(key, item, window) {
        const m = _items;
        m[key] = (m[key] || []).filter(e => e.item !== item).concat([{
                "item": item,
                "window": window
            }]);
        revision++;
    }
    function unregister(key, item) {
        const list = _items[key];
        if (!list || !list.some(e => e.item === item))
            return;
        const rest = list.filter(e => e.item !== item);
        if (rest.length)
            _items[key] = rest;
        else
            delete _items[key];
        revision++;
    }
    function screenOf(e) {
        return e && e.window && e.window.screen ? e.window.screen.name : "";
    }
    // the element on the tour's screen (several bars have the same one), else the first there is
    function target(key) {
        const list = _items[key] || [];
        return list.find(e => screenOf(e) === screen) || list[0] || null;
    }

    // the key tips name the keys of the profile in front (services/KeyProfile): Golden Gate's
    // Mac keys move the launcher, the overview and window focus; Golden Gate without them keeps
    // the pixel ones
    // Follow the selector actually applied: niri may reject a requested profile switch.
    readonly property bool macKeys: KeyProfile.profile === "macos"
    readonly property string launcherKeys: macKeys ? "Mod+Alt+Space" : "Mod+Space"
    // the key bound to what `does` names, as the profile in front has it (services/Keybinds), or
    // `fallback`: ["Mod", "W"]
    function keysFor(does, fallback) {
        const b = Keybinds.binds.find(x => String(x.action).includes(does));
        if (!b)
            return fallback;
        return String(b.key).split("+").map(k => k.length > 1 ? (k === "ESCAPE" || k === "Escape" ? "Esc" : k[0] + k.slice(1).toLowerCase()) : k);
    }
    readonly property var steps: [
        {
            "key": "halo",
            "title": I18n.t("Нимб — пульт", "The Halo"),
            "text": I18n.t("Что идёт сейчас: музыка, запись, таймер, уведомление. Наведи — откроется карточка, колесо листает её страницы. На закрытом колесо — громкость, средний клик — пауза, ПКМ — меню. Перетащи на него файл — полежит на Полке.", "What is going on: music, a recording, a timer, a notification. Point at it for the card, the wheel turns its pages. Closed: the wheel is the volume, a middle click pauses, a right click opens its menu. Drop a file on it: it waits on the Shelf.")
        },
        {
            "key": "bar:start",
            "title": I18n.t("Меню «Пуск»", "Start menu"),
            "text": I18n.t("Программы, настройки, тема, блокировка и выключение. Программы ещё открываются по ", "Apps, settings, theme, lock and power. Apps also open with ") + launcherKeys + "."
        },
        {
            "key": "bar:workspaces",
            "title": I18n.t("Воркспейсы", "Workspaces"),
            "text": I18n.t("Клик — перейти, колесо — листать. Сердечки или иконки открытых приложений выбираются в Настройки → Панель задач.", "Click to switch, scroll to flip. Hearts or app icons: Settings → Taskbar.")
        },
        {
            "key": "bar:tasks",
            "title": I18n.t("Окна", "Windows"),
            "text": I18n.t("Открытые окна. Клик — перейти к окну, правый клик — меню окна (закрыть, на весь экран…). Ширину кнопок и окон можно настроить.", "Open windows. Click to go to one, right-click for its menu (close, fullscreen…). Button and window widths are adjustable.")
        },
        {
            "key": "bar:lyrics",
            "title": I18n.t("Лирика", "Lyrics"),
            "text": I18n.t("Строка из играющей песни. Клик — настройки, Mod+Alt+Y — спрятать.", "The current line of the song. Click for settings, Mod+Alt+Y hides it.")
        },
        {
            "key": "bar:plugin:claude-companion",
            "title": "Claude",
            "text": I18n.t("Сколько осталось до лимита и что делают сессии Claude Code. Клик — подробности.", "How much is left before the limit and what Claude Code sessions are doing.")
        },
        {
            "key": "bar:tray",
            "title": I18n.t("Трей", "Tray"),
            "text": I18n.t("Значки приложений. Их можно перекрасить под тему — Настройки → Панель задач → Иконки.", "App icons. Recolor them to the theme in Settings → Taskbar → Icons.")
        },
        {
            "key": "bar:clock",
            "title": I18n.t("Часы", "Clock"),
            "text": I18n.t("Клик — календарь и история уведомлений.", "Click for the calendar and notification history.")
        },
        {
            "key": "desktop",
            "demo": "desktop",
            "title": I18n.t("Рабочий стол", "Desktop"),
            "text": I18n.t("ПКМ по обоям — меню стола: виджеты, заметки, папки, персонализация; ПКМ по окну или его кнопке на панели — меню окна. Средняя кнопка по столу — кольцо частых действий.", "Right-click the wallpaper for the desktop menu: widgets, notes, folders, personalization; right-click a window or its taskbar button for the window's. A middle click on the desktop: the ring of frequent actions.")
        },
        // the keys: no element to circle; the card shows them and the thing itself opens
        // (modules/tour/TourOverlay: demo = what to show — a real window or a played scene)
        {
            "key": "keys:launcher",
            "demo": "launcher",
            "keys": keysFor("open launcher", launcherKeys.split("+")),
            "title": I18n.t("Найти что угодно", "Find anything"),
            "text": I18n.t("Программы, настройки, действия с их клавишей, файлы, «5м чай», «2+2». Понимает другую раскладку и опечатки, а выбранное запоминает — в следующий раз оно первое.", "Apps, settings, actions with their key, files, “5m tea”, “2+2”. It understands the other layout and typos and remembers what you pick: next time it comes first.")
        },
        {
            "key": "keys:overview",
            "demo": "overview",
            "keys": keysFor("toggle-overview", macKeys ? ["Mod", "Alt", "Tab"] : ["Mod", "Tab"]),
            "title": I18n.t("Все столы лентой", "Every desk in a ribbon"),
            "text": I18n.t("Обзор niri: все рабочие столы друг под другом, окна мелко — перетаскивай их между столами. ", "niri's overview: every workspace one under another, the windows small; drag them between desks. ") + (macKeys ? "Mod+Alt+← →" : "Mod+← →") + I18n.t(" листают ленту окон.", " scroll the window ribbon.")
        },
        {
            "key": "keys:mission",
            "demo": "mission",
            "keys": keysFor("open mission", macKeys ? ["Ctrl", "↑"] : ["Mod", "W"]),
            "title": "Mission Control",
            "text": I18n.t("Окна этого стола крупно и без наложений, столы — полоской сверху. Клик — к окну, окно на стол — переедет. Ищешь окно — сюда; переставляешь столы — в обзор niri.", "This desk's windows big and side by side, the desks in a strip on top. A click goes to a window, a window dropped on a desk moves there. Looking for a window: here; rearranging desks: niri's overview.")
        },
        {
            "key": "keys:settings",
            "demo": "settings",
            "keys": keysFor("settings appearance", ["Mod", "S"]),
            "title": I18n.t("Где всё настраивается", "Where everything is set"),
            "text": I18n.t("Всё, что спрашивал мастер, и намного больше. Поиск сверху находит любую настройку, даже с опечаткой; лаунчер тоже их находит.", "Everything the wizard asked and much more. The search on top finds any setting, typos and all; the launcher finds them too.")
        },
        {
            "key": "keys:clipboard",
            "demo": "clipboard",
            "keys": ["Mod", "V"],
            "title": I18n.t("Буфер обмена", "Clipboard"),
            "text": I18n.t("Всё, что ты копировал, — текст и картинки. Клик кладёт обратно.", "Everything you copied, text and pictures. A click puts it back.")
        },
        {
            "key": "keys:theme",
            "demo": "theme",
            "keys": ["Mod", "Alt", "T"],
            "title": I18n.t("Светлая ↔ тёмная", "Light ↔ dark"),
            "text": I18n.t("Тема переключается сразу везде: оболочка, окна, терминал, браузер, Telegram, папки.", "The theme flips everywhere at once: the shell, windows, the terminal, the browser, Telegram, folders.")
        },
        {
            "key": "keys:shot",
            "demo": "shot",
            "keys": keysFor("angelos capture", ["Mod", "Shift", "S"]),
            "title": I18n.t("Скриншот и «найти»", "Screenshot and find"),
            "text": I18n.t("Выдели кусок экрана: картинка в буфере и в Изображения/Screenshots, а ещё можно найти похожее, вытащить текст, перевести. Mod+Shift+R — то же видео.", "Pick a piece of the screen: the picture is in the clipboard and in Pictures/Screenshots, and you can search it, take its text, translate it. Mod+Shift+R records it.")
        },
        {
            "key": "keys:voice",
            "demo": "voice",
            "keys": ["Mod", "Shift", "V"],
            "needs": "voxtype",
            "title": I18n.t("Голосовой ввод", "Voice input"),
            "text": I18n.t("Нажми, говори, нажми ещё раз — текст напечатается там, где курсор.", "Press, talk, press again: the text is typed where the cursor is.")
        },
        {
            "key": "keys:all",
            "demo": "keys",
            "keys": ["Mod", "Shift", "Esc"],
            "title": I18n.t("Все сочетания", "Every shortcut"),
            "text": I18n.t("Шпаргалка niri поверх всего. Свои клавиши — Настройки → Клавиатура.", "niri's cheat sheet over everything. Your own keys: Settings → Keyboard.")
        },
        {
            "key": "end",
            "title": I18n.t("Готово ♡", "That's it ♡"),
            "text": I18n.t("Пройти снова: ПКМ по Нимбу → «Как тут всё устроено», «тур» в поиске или Настройки → Учётная запись.", "Again: right-click the Halo → “How it all works”, “tour” in the search, or Settings → Account.")
        }
    ]
    // only steps whose element exists (bar layout is configurable): on the tour's screen when
    // its bar has any, else anywhere
    readonly property var active: {
        revision;
        const here = Object.keys(_items).some(k => _items[k].some(e => screenOf(e) === screen));
        return steps.filter(s => s.key === "desktop" || s.key === "end" || (s.key.startsWith("keys:") && (!s.needs || needs[s.needs])) || !!_items[s.key] && (!here || _items[s.key].some(e => screenOf(e) === screen)));
    }
    readonly property var current: active[Math.min(step, active.length - 1)] || null
    // what some key tips need installed (voice input)
    property var needs: ({})
    Process {
        id: needsProbe
        command: ["sh", "-c", "[ -x \"$HOME/.local/bin/voxtype\" ] && echo voxtype; exit 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = {};
                for (const w of text.split(/\s+/))
                    if (w)
                        n[w] = true;
                root.needs = n;
            }
        }
    }

    // `where`: the screen asked for (the wizard's); otherwise the main one (Shell.mainScreenFor)
    function start(where) {
        const s = Shell.mainScreenFor(where || "");
        screen = s ? s.name : "";
        step = 0;
        needsProbe.running = true;
        Achievements.note("explore", "tour");
        running = true;
    }
    function next() {
        if (step + 1 >= active.length)
            running = false;
        else
            step++;
    }
    function back() {
        step = Math.max(0, step - 1);
    }
    function stop() {
        running = false;
    }
}
