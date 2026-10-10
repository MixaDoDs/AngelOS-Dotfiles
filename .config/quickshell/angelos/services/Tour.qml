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

    readonly property var steps: [
        {
            "key": "bar:start",
            "title": I18n.t("Меню «Пуск»", "Start menu"),
            "text": I18n.t("Программы, настройки, тема, блокировка и выключение. Программы ещё открываются по Mod+Space.", "Apps, settings, theme, lock and power. Apps also open with Mod+Space.")
        },
        {
            "key": "bar:workspaces",
            "title": I18n.t("Воркспейсы", "Workspaces"),
            "text": I18n.t("Клик — перейти, колесо — листать. Сердечки или иконки открытых приложений выбираются в Настройки → Панель задач.", "Click to switch, scroll to flip. Hearts or app icons: Settings → Taskbar.")
        },
        {
            "key": "bar:tasks",
            "title": I18n.t("Окна", "Windows"),
            "text": I18n.t("Открытые окна. ПКМ закрывает окно. Ширину кнопок и окон можно настроить.", "Open windows. Right-click closes one. Button and window widths are adjustable.")
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
            "text": I18n.t("ПКМ по обоям — меню как в Windows 11: виджеты (Вид ▸), заметки, папки, персонализация. Виджеты таскаются за заголовок.", "Right-click the wallpaper for a Windows 11-style menu: widgets (View ▸), notes, folders, personalization. Drag widgets by their title.")
        },
        // the keys: no element to circle; the card shows them and the thing itself opens
        // (modules/tour/TourOverlay: demo = what to show — a real window or a played scene)
        {
            "key": "keys:launcher",
            "demo": "launcher",
            "keys": ["Mod", "Space"],
            "title": I18n.t("Программы", "Apps"),
            "text": I18n.t("Начни печатать название — Enter запускает. Там же калькулятор и поиск по настройкам.", "Start typing a name; Enter launches it. A calculator and the settings search are there too.")
        },
        {
            "key": "keys:overview",
            "demo": "overview",
            "keys": ["Mod", "Tab"],
            "title": I18n.t("Все окна сразу", "Every window at once"),
            "text": I18n.t("Обзор niri: столы и окна мелко, перетаскивай их мышью. Mod+← → листают ленту окон.", "niri's overview: the workspaces and windows small, drag them around. Mod+← → scroll the window ribbon.")
        },
        {
            "key": "keys:settings",
            "demo": "settings",
            "keys": ["Mod", "S"],
            "title": I18n.t("Настройки", "Settings"),
            "text": I18n.t("Всё, что спрашивал мастер, и намного больше. Поиск сверху находит любую настройку.", "Everything the wizard asked and much more. The search on top finds any setting.")
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
            "keys": ["Mod", "Shift", "S"],
            "title": I18n.t("Скриншот области", "Region screenshot"),
            "text": I18n.t("Выдели — картинка в буфере и в Изображения/Screenshots. Mod+Shift+R — то же видео.", "Pick a region: the picture is in the clipboard and in Pictures/Screenshots. Mod+Shift+R records it.")
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
            "text": I18n.t("Mod+S — настройки. Подсказки можно пройти снова: Настройки → Аккаунт.", "Mod+S opens settings. Replay these tips from Settings → Account.")
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
