// serp-skin settings: what the search knows — {page, key, title, words}; key is a rowKey on the page
.pragma library

var pages = {
    "welcome": "Добро пожаловать",
    "theme": "Тема",
    "bar": "Панель",
    "dock": "Док",
    "widgets": "Виджеты",
    "about": "О скине"
};

var items = [
    { page: "welcome", key: "", title: "Добро пожаловать", words: "привет начало serpantinum" },
    { page: "welcome", key: "classic", title: "Вернуться на Classic", words: "скин выключить обычный классика" },
    { page: "welcome", key: "angelos", title: "Настройки angelOS", words: "система параметры" },
    { page: "theme", key: "wall", title: "Обои", words: "картинка фон wallpaper" },
    { page: "theme", key: "font", title: "Шрифт", words: "font моно текст гарнитура" },
    { page: "theme", key: "radius", title: "Скругление", words: "углы радиус radius" },
    { page: "theme", key: "opacity", title: "Непрозрачность", words: "прозрачность opacity плотность" },
    { page: "theme", key: "blur", title: "Размытие", words: "blur стекло" },
    { page: "theme", key: "colors", title: "Цвета", words: "палитра пресет тема цвет palette accent акцент" },
    { page: "bar", key: "seconds", title: "Секунды", words: "часы время панель" },
    { page: "bar", key: "weather", title: "Погода", words: "температура панель" },
    { page: "bar", key: "media", title: "Сейчас играет", words: "музыка трек плеер media" },
    { page: "bar", key: "desks", title: "Столы", words: "рабочие столы пилюли цифры workspaces" },
    { page: "dock", key: "dock", title: "Док", words: "dock панель приложений" },
    { page: "dock", key: "magnify", title: "Увеличение при наведении", words: "лупа magnify док" },
    { page: "dock", key: "autohide", title: "Автоскрытие", words: "прятать скрывать док" },
    { page: "dock", key: "running", title: "Запущенные приложения", words: "окна открытые док" },
    { page: "dock", key: "size", title: "Размер значков", words: "иконки док величина" },
    { page: "theme", key: "glass", title: "Жидкое стекло", words: "стекло glass прозрачность преломление liquid" },
    { page: "widgets", key: "more", title: "Виджеты рабочего стола", words: "виджет часы рабочий стол" },
    { page: "widgets", key: "more", title: "Остальные виджеты", words: "визуализатор angelos виджеты" },
    { page: "about", key: "about", title: "О скине", words: "ilyamiro лицензия agpl github" },
    { page: "about", key: "version", title: "Версия", words: "версия 0.1" }
];

function search(q) {
    q = (q || "").trim().toLowerCase();
    if (!q)
        return [];
    var out = [];
    for (var i = 0; i < items.length; i++) {
        var it = items[i];
        var t = it.title.toLowerCase();
        var rank = t.indexOf(q) === 0 ? 0 : t.indexOf(q) > 0 ? 1 : (it.words + " " + pages[it.page].toLowerCase()).indexOf(q) >= 0 ? 2 : -1;
        if (rank >= 0)
            out.push({ page: it.page, key: it.key, title: it.title, where: pages[it.page], rank: rank, n: i });
    }
    out.sort(function (a, b) { return a.rank - b.rank || a.n - b.n; });
    return out;
}
