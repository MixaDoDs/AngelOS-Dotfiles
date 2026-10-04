pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Guided tips: UI elements register here, the overlay circles them one by one.
Singleton {
    id: root

    property bool running: false
    property int step: 0
    property var _items: ({})       // key -> {item, window}
    property int revision: 0

    function register(key, item, window) {
        const m = _items;
        m[key] = {
            "item": item,
            "window": window
        };
        revision++;
    }
    function unregister(key, item) {
        if (_items[key] && _items[key].item === item) {
            delete _items[key];
            revision++;
        }
    }
    function target(key) {
        return _items[key] || null;
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
            "title": I18n.t("Рабочий стол", "Desktop"),
            "text": I18n.t("ПКМ по обоям — меню как в Windows 11: виджеты (Вид ▸), заметки, папки, персонализация. Виджеты таскаются за заголовок.", "Right-click the wallpaper for a Windows 11-style menu: widgets (View ▸), notes, folders, personalization. Drag widgets by their title.")
        },
        {
            "key": "end",
            "title": I18n.t("Готово ♡", "That's it ♡"),
            "text": I18n.t("Mod+S — настройки. Подсказки можно пройти снова: Настройки → Внешний вид.", "Mod+S opens settings. Replay these tips from Settings → Account.")
        }
    ]
    // only steps whose element exists (bar layout is configurable)
    readonly property var active: {
        revision;
        return steps.filter(s => s.key === "desktop" || s.key === "end" || !!_items[s.key]);
    }
    readonly property var current: active[Math.min(step, active.length - 1)] || null

    function start() {
        step = 0;
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
