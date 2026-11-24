.pragma library

// [glyph, Russian name, English name, optional search aliases]
const symbols = {
    typography: [
        ["—", "Длинное тире", "Em dash", "длинный дефис длинная черта mdash"],
        ["–", "Короткое тире", "En dash", "среднее тире диапазон ndash"],
        ["…", "Многоточие", "Ellipsis", "..."],
        ["«", "Открывающая ёлочка", "Left guillemet", "кавычка кавычки <<"],
        ["»", "Закрывающая ёлочка", "Right guillemet", "кавычка кавычки >>"],
        ["„", "Нижняя двойная кавычка", "Double low quotation mark", "лапки quotes"],
        ["“", "Левая двойная кавычка", "Left double quotation mark", "лапки quotes"],
        ["”", "Правая двойная кавычка", "Right double quotation mark", "лапки quotes"],
        ["‘", "Левая одинарная кавычка", "Left single quotation mark"],
        ["’", "Правая одинарная кавычка", "Right single quotation mark", "апостроф apostrophe"],
        ["‹", "Левая одинарная ёлочка", "Left single guillemet", "кавычка"],
        ["›", "Правая одинарная ёлочка", "Right single guillemet", "кавычка"],
        ["‑", "Неразрывный дефис", "Non-breaking hyphen"],
        ["•", "Маркер списка", "Bullet", "точка"],
        ["·", "Средняя точка", "Middle dot", "interpunct"],
        ["№", "Знак номера", "Numero sign", "номер number"],
        ["§", "Знак параграфа", "Section sign", "параграф"],
        ["¶", "Знак абзаца", "Pilcrow", "абзац paragraph"],
        ["©", "Авторское право", "Copyright", "копирайт"],
        ["®", "Зарегистрированный товарный знак", "Registered trademark"],
        ["™", "Товарный знак", "Trademark", "тм"],
        ["°", "Градус", "Degree sign", "температура temperature"],
        ["′", "Штрих", "Prime", "минута фут"],
        ["″", "Двойной штрих", "Double prime", "секунда дюйм"],
        ["†", "Крестик для сноски", "Dagger", "сноска"],
        ["‡", "Двойной крестик для сноски", "Double dagger", "сноска"]
    ],
    currency: [
        ["₽", "Рубль", "Ruble", "рубль rub"],
        ["€", "Евро", "Euro", "eur"],
        ["$", "Доллар", "Dollar", "usd"],
        ["£", "Фунт", "Pound", "стерлинг gbp"],
        ["¥", "Иена или юань", "Yen or yuan", "jpy cny"],
        ["₴", "Гривна", "Hryvnia", "uah"],
        ["₸", "Тенге", "Tenge", "kzt"],
        ["₺", "Лира", "Lira", "try"],
        ["₹", "Рупия", "Rupee", "inr"],
        ["₩", "Вона", "Won", "krw"],
        ["₿", "Биткоин", "Bitcoin", "btc"],
        ["¢", "Цент", "Cent"]
    ],
    math: [
        ["−", "Минус", "Minus sign", "вычитание"],
        ["±", "Плюс-минус", "Plus-minus sign"],
        ["×", "Умножение", "Multiplication sign", "times"],
        ["÷", "Деление", "Division sign"],
        ["≠", "Не равно", "Not equal"],
        ["≈", "Приблизительно равно", "Approximately equal"],
        ["≤", "Меньше или равно", "Less than or equal"],
        ["≥", "Больше или равно", "Greater than or equal"],
        ["∞", "Бесконечность", "Infinity"],
        ["√", "Квадратный корень", "Square root"],
        ["∑", "Сумма", "Summation"],
        ["∫", "Интеграл", "Integral"],
        ["∆", "Приращение", "Increment", "дельта delta"],
        ["∅", "Пустое множество", "Empty set"],
        ["‰", "Промилле", "Per mille"],
        ["²", "В квадрате", "Superscript two"],
        ["³", "В кубе", "Superscript three"],
        ["½", "Одна вторая", "One half", "половина дробь"],
        ["¼", "Одна четверть", "One quarter", "дробь"],
        ["¾", "Три четверти", "Three quarters", "дробь"],
        ["π", "Пи", "Pi"],
        ["µ", "Микро", "Micro sign"]
    ],
    arrows: [
        ["←", "Стрелка влево", "Left arrow"],
        ["↑", "Стрелка вверх", "Up arrow"],
        ["→", "Стрелка вправо", "Right arrow"],
        ["↓", "Стрелка вниз", "Down arrow"],
        ["↔", "Стрелка в обе стороны", "Left-right arrow"],
        ["↕", "Стрелка вверх и вниз", "Up-down arrow"],
        ["↖", "Стрелка влево-вверх", "Up-left arrow"],
        ["↗", "Стрелка вправо-вверх", "Up-right arrow"],
        ["↘", "Стрелка вправо-вниз", "Down-right arrow"],
        ["↙", "Стрелка влево-вниз", "Down-left arrow"],
        ["⇒", "Двойная стрелка вправо", "Right double arrow"],
        ["⟶", "Длинная стрелка вправо", "Long right arrow"],
        ["↵", "Перевод строки", "Return arrow", "enter"],
        ["↻", "Стрелка по часовой", "Clockwise arrow", "refresh"],
        ["↺", "Стрелка против часовой", "Counterclockwise arrow"]
    ],
    marks: [
        ["✓", "Галочка", "Check mark", "tick"],
        ["✗", "Крестик", "Ballot X", "cross"],
        ["☐", "Пустой флажок", "Ballot box", "checkbox"],
        ["☑", "Отмеченный флажок", "Checked box", "checkbox"],
        ["★", "Звезда", "Black star"],
        ["☆", "Контур звезды", "White star"],
        ["♥", "Сердце", "Heart suit"],
        ["♡", "Контур сердца", "White heart"],
        ["♪", "Нота", "Eighth note", "музыка music"],
        ["♫", "Две ноты", "Beamed eighth notes", "музыка music"],
        ["◇", "Контур ромба", "White diamond"],
        ["◆", "Ромб", "Black diamond"],
        ["○", "Окружность", "White circle"],
        ["●", "Круг", "Black circle"],
        ["△", "Контур треугольника", "White triangle"],
        ["▲", "Треугольник", "Black triangle"]
    ]
};

const symbolGroups = [
    ["typography", "Типографика", "Typography"],
    ["currency", "Валюты", "Currencies"],
    ["math", "Математика", "Math"],
    ["arrows", "Стрелки", "Arrows"],
    ["marks", "Знаки", "Marks"]
];

const emojiGroups = [
    ["faces", "Лица и эмоции", "Smileys & emotion", "смайлик смайлики emoji"],
    ["people", "Люди и жесты", "People & body"],
    ["nature", "Животные и природа", "Animals & nature"],
    ["food", "Еда и напитки", "Food & drink"],
    ["travel", "Путешествия и места", "Travel & places"],
    ["activities", "Занятия и спорт", "Activities & sports"],
    ["objects", "Предметы", "Objects"],
    ["emoji-symbols", "Эмодзи-знаки", "Emoji symbols"],
    ["flags", "Флаги", "Flags"]
];

function searchText(text) {
    return text.toLowerCase().replace(/ё/g, "е").normalize("NFC");
}

function matching(catalog, groups, category, query) {
    const term = searchText(query.trim());
    const words = term ? term.split(/\s+/) : [];
    const result = [];
    for (const group of groups) {
        if (category !== "all" && category !== group[0])
            continue;
        const groupText = group.slice(1).join(" ");
        for (const item of catalog[group[0]] || []) {
            const hay = words.length ? searchText(item.join(" ") + " " + groupText) : "";
            if (words.every(word => hay.includes(word)))
                result.push(item);
        }
    }
    return result;
}
