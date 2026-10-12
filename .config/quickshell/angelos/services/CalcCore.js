.pragma library

// The Start menu / launcher calculator (services/Calc.qml). No eval: a small
// recursive-descent parser for everyday maths, plus unit and currency phrases.
//   2+2*3 · (1+2)^2 · 2,5×4 · 10:4 · 15% от 200 · 200+15% · 5! · sqrt(2) · √9
//   sin(30) (degrees; with pi inside — radians) · ln, log, log2, abs, round…
//   10 км в милях · 100f to c · 5 GB in MB · 2 ч в мин · 70 kg в фунтах
//   100 usd в rub · 50€ to $ · 1000 рублей в долларах (rates come from Calc.qml)
//   100$ · 10к рублей · сколько 2,5 тыс евро в рублях? · курс доллара · курс евро к рублю

const FUNCS = {
    "sqrt": Math.sqrt,
    "cbrt": Math.cbrt,
    "abs": Math.abs,
    "ln": Math.log,
    "log": Math.log10,
    "lg": Math.log10,
    "log2": Math.log2,
    "exp": Math.exp,
    "round": Math.round,
    "floor": Math.floor,
    "ceil": Math.ceil,
    "sin": null,
    "cos": null,
    "tan": null,
    "tg": null,
    "asin": null,
    "acos": null,
    "atan": null,
    "arcsin": null,
    "arccos": null,
    "arctan": null,
    "arctg": null
};
const TRIG = {
    "sin": Math.sin,
    "cos": Math.cos,
    "tan": Math.tan,
    "tg": Math.tan
};
const ATRIG = {
    "asin": Math.asin,
    "acos": Math.acos,
    "atan": Math.atan,
    "arcsin": Math.asin,
    "arccos": Math.acos,
    "arctan": Math.atan,
    "arctg": Math.atan
};
const CONSTS = {
    "pi": Math.PI,
    "e": Math.E,
    "tau": 2 * Math.PI
};

function normalize(s) {
    return String(s).trim().toLowerCase()
        .replace(/[−–—]/g, "-")
        .replace(/π/g, "pi")
        .replace(/√/g, " sqrt ")
        .replace(/\*\*/g, "^")
        .replace(/÷/g, "/")
        .replace(/(\d)\s*:\s*(?=\d)/g, "$1/")                 // 10:4 (a Russian school habit)
        .replace(/(\d|\))\s*[x×х]\s*(?=[\d(])/g, "$1*")       // 2x3, 2×3, 2х3
        .replace(/(\d),(\d)/g, "$1.$2")                       // 2,5
        .replace(/(\d[\d.]*)\s*%\s*(?:of|от)\s*/g, "($1/100)*") // 15% от 200
        .replace(/°/g, "deg");
}

function tokenize(s) {
    const out = [];
    let i = 0;
    while (i < s.length) {
        const c = s[i];
        if (c === " ") {
            i++;
            continue;
        }
        const num = /^(\d+\.?\d*|\.\d+)(e[+-]?\d+)?/.exec(s.slice(i));
        if (num) {
            out.push({"t": "n", "v": parseFloat(num[0])});
            i += num[0].length;
            continue;
        }
        const id = /^(log2|[a-z]+)/.exec(s.slice(i));
        if (id) {
            out.push({"t": "id", "v": id[0]});
            i += id[0].length;
            continue;
        }
        if ("+-*/^()!%".includes(c)) {
            out.push({"t": c});
            i++;
            continue;
        }
        return null;
    }
    return out;
}

// returns {value, degrees} or throws
function parse(tokens) {
    let pos = 0, degrees = false, ops = 0;
    const peek = () => tokens[pos] || {"t": "end"};
    const take = t => {
        if (peek().t !== t)
            throw new Error("expected " + t);
        return tokens[pos++];
    };
    // a percent literal remembers it was one: 200 + 15% = 230
    function expr() {
        let left = term();
        while (peek().t === "+" || peek().t === "-") {
            const op = tokens[pos++].t;
            const right = term();
            ops++;
            const r = right.pct ? left.v * right.v : right.v;
            left = {"v": op === "+" ? left.v + r : left.v - r};
        }
        return left;
    }
    function startsPrimary(t) {
        return t.t === "n" || t.t === "id" || t.t === "(";
    }
    function term() {
        let left = unary();
        for (;;) {
            const t = peek();
            if (t.t === "*" || t.t === "/") {
                pos++;
                const right = unary();
                ops++;
                left = {"v": t.t === "*" ? left.v * right.v : left.v / right.v};
            } else if (startsPrimary(t)) {
                // implicit: 2pi, 3(4+1), 2 sqrt(4)
                const right = unary();
                ops++;
                left = {"v": left.v * right.v};
            } else {
                return left;
            }
        }
    }
    function unary() {
        if (peek().t === "-") {
            pos++;
            const x = unary();
            return {"v": -x.v, "pct": x.pct};
        }
        if (peek().t === "+") {
            pos++;
            return unary();
        }
        return power();
    }
    function power() {
        const base = postfix();
        if (peek().t === "^") {
            pos++;
            ops++;
            return {"v": Math.pow(base.v, unary().v)};
        }
        return base;
    }
    function postfix() {
        let x = primary();
        for (;;) {
            if (peek().t === "!") {
                pos++;
                ops++;
                if (x.v < 0 || x.v > 170 || Math.floor(x.v) !== x.v)
                    throw new Error("factorial");
                let f = 1;
                for (let k = 2; k <= x.v; k++)
                    f *= k;
                x = {"v": f};
            } else if (peek().t === "%") {
                pos++;
                ops++;
                x = {"v": x.v / 100, "pct": true};
            } else if (peek().t === "id" && peek().v === "deg") {
                pos++;
                x = {"v": x.v, "deg": true};
            } else {
                return x;
            }
        }
    }
    function primary() {
        const t = peek();
        if (t.t === "n") {
            pos++;
            return {"v": t.v};
        }
        if (t.t === "(") {
            pos++;
            const x = expr();
            take(")");
            return x;
        }
        if (t.t === "id") {
            pos++;
            if (t.v in CONSTS)
                return {"v": CONSTS[t.v], "pi": t.v !== "e"};
            if (!(t.v in FUNCS))
                throw new Error("unknown " + t.v);
            ops++;
            let start = pos;
            const arg = peek().t === "(" ? (pos++, (() => {
                        const x = expr();
                        take(")");
                        return x;
                    })()) : postfix();
            // radians when pi is inside, otherwise degrees (sin(30) = 0.5)
            const usesPi = tokens.slice(start, pos).some(k => k.t === "id" && (k.v === "pi" || k.v === "tau" || k.v === "rad"));
            if (t.v in TRIG) {
                const rad = usesPi && !arg.deg;
                if (!rad)
                    degrees = true;
                return {"v": TRIG[t.v](rad ? arg.v : arg.v * Math.PI / 180)};
            }
            if (t.v in ATRIG) {
                degrees = true;
                return {"v": ATRIG[t.v](arg.v) * 180 / Math.PI};
            }
            return {"v": FUNCS[t.v](arg.v)};
        }
        throw new Error("unexpected");
    }
    const r = expr();
    if (pos !== tokens.length)
        throw new Error("trailing");
    return {"value": r.v, "degrees": degrees, "ops": ops};
}

function format(v) {
    if (!isFinite(v))
        return null;
    if (v === 0)
        return "0";
    const a = Math.abs(v);
    if (a >= 1e15 || a < 1e-9)
        return v.toExponential(8).replace(/\.?0+e/, "e");
    return String(parseFloat(v.toPrecision(12)));
}
// 1234567.5 → "1 234 567.5" for reading (the copy stays plain)
function pretty(s, english) {
    if (!s || s.includes("e"))
        return s;
    const neg = s.startsWith("-"), body = neg ? s.slice(1) : s;
    const [int, frac] = body.split(".");
    const grouped = int.replace(/\B(?=(\d{3})+(?!\d))/g, english ? "," : " ");
    return (neg ? "-" : "") + grouped + (frac ? (english ? "." : ",") + frac : "");
}

// maths: {value, text, degrees} or null when the text is not an expression
function math(text) {
    const src = normalize(text);
    if (!/\d|\b(pi|tau|e)\b/.test(src))
        return null;
    const tokens = tokenize(src);
    if (!tokens || !tokens.length)
        return null;
    let r;
    try {
        r = parse(tokens);
    } catch (e) {
        return null;
    }
    // a bare number is not a question
    if (!r.ops)
        return null;
    const s = format(r.value);
    return s === null ? null : {
        "value": r.value,
        "text": s,
        "degrees": r.degrees
    };
}

// ---- units: every unit in its category's base (m, kg, s, byte, m/s, m², l, °) ----
const UNITS = [
    // length (m)
    ["length", 0.001, "mm", ["mm", "мм", "миллиметр", "миллиметра", "миллиметров", "миллиметрах"]],
    ["length", 0.01, "cm", ["cm", "см", "сантиметр", "сантиметра", "сантиметров", "сантиметрах"]],
    ["length", 1, "m", ["m", "м", "meter", "meters", "metre", "metres", "метр", "метра", "метров", "метрах"]],
    ["length", 1000, "km", ["km", "км", "kilometer", "kilometers", "километр", "километра", "километров", "километрах"]],
    ["length", 0.0254, "in", ["in", "inch", "inches", "дюйм", "дюйма", "дюймов", "дюймах", "\""]],
    ["length", 0.3048, "ft", ["ft", "foot", "feet", "фут", "фута", "футов", "футах", "'"]],
    ["length", 0.9144, "yd", ["yd", "yard", "yards", "ярд", "ярда", "ярдов", "ярдах"]],
    ["length", 1609.344, "mi", ["mi", "mile", "miles", "миля", "мили", "миль", "милях", "милю"]],
    ["length", 1852, "nmi", ["nmi", "морская миля", "морских миль", "морских милях"]],
    // mass (kg)
    ["mass", 1e-6, "mg", ["mg", "мг", "миллиграмм", "миллиграмма", "миллиграммов"]],
    ["mass", 0.001, "g", ["g", "г", "gram", "grams", "грамм", "грамма", "граммов", "граммах", "гр"]],
    ["mass", 1, "kg", ["kg", "кг", "kilogram", "kilograms", "кило", "килограмм", "килограмма", "килограммов", "килограммах"]],
    ["mass", 1000, "t", ["t", "т", "ton", "tons", "tonne", "tonnes", "тонна", "тонны", "тонн", "тоннах"]],
    ["mass", 0.028349523125, "oz", ["oz", "ounce", "ounces", "унция", "унции", "унций", "унциях"]],
    ["mass", 0.45359237, "lb", ["lb", "lbs", "pound", "pounds", "фунт", "фунта", "фунтов", "фунтах"]],
    ["mass", 6.35029318, "st", ["st", "stone", "stones", "стоун", "стоуна", "стоунов"]],
    // time (s)
    ["time", 0.001, "ms", ["ms", "мс", "миллисекунда", "миллисекунды", "миллисекунд"]],
    ["time", 1, "s", ["s", "sec", "secs", "second", "seconds", "с", "сек", "секунда", "секунды", "секунд", "секундах", "секунду"]],
    ["time", 60, "min", ["min", "mins", "minute", "minutes", "мин", "минута", "минуты", "минут", "минутах", "минуту"]],
    ["time", 3600, "h", ["h", "hr", "hrs", "hour", "hours", "ч", "час", "часа", "часов", "часах"]],
    ["time", 86400, "d", ["d", "day", "days", "д", "дн", "день", "дня", "дней", "днях", "сутки", "суток"]],
    ["time", 604800, "wk", ["wk", "week", "weeks", "нед", "неделя", "недели", "недель", "неделях", "неделю"]],
    ["time", 31557600, "yr", ["y", "yr", "year", "years", "год", "года", "лет", "годах"]],
    // data (bytes); "b" is a bit, "B" a byte (the case is checked first)
    ["data", 0.125, "bit", ["bit", "bits", "b", "бит", "бита", "битов"]],
    ["data", 1, "B", ["B", "byte", "bytes", "байт", "байта", "байтов", "б"]],
    ["data", 1e3, "KB", ["KB", "kb", "kB", "кб", "килобайт", "килобайта", "килобайтов", "килобайтах"]],
    ["data", 1e6, "MB", ["MB", "mb", "мб", "мегабайт", "мегабайта", "мегабайтов", "мегабайтах"]],
    ["data", 1e9, "GB", ["GB", "gb", "гб", "гигабайт", "гигабайта", "гигабайтов", "гигабайтах", "гиг", "гига"]],
    ["data", 1e12, "TB", ["TB", "tb", "тб", "терабайт", "терабайта", "терабайтов", "терабайтах"]],
    ["data", 1024, "KiB", ["kib", "кибибайт"]],
    ["data", 1048576, "MiB", ["mib", "мебибайт"]],
    ["data", 1073741824, "GiB", ["gib", "гибибайт"]],
    ["data", 1099511627776, "TiB", ["tib", "тебибайт"]],
    ["data", 125, "Kbit", ["kbit", "kbps", "кбит"]],
    ["data", 125000, "Mbit", ["mbit", "mbps", "мбит", "мегабит", "мегабита", "мегабитах"]],
    ["data", 125000000, "Gbit", ["gbit", "gbps", "гбит", "гигабит"]],
    // speed (m/s)
    ["speed", 1, "m/s", ["m/s", "м/с", "mps"]],
    ["speed", 1 / 3.6, "km/h", ["km/h", "kmh", "kph", "км/ч", "кмч"]],
    ["speed", 0.44704, "mph", ["mph", "mi/h", "миль/ч", "миль в час"]],
    ["speed", 1852 / 3600, "kn", ["kn", "knot", "knots", "узел", "узла", "узлов", "узлах"]],
    // area (m²)
    ["area", 1, "m²", ["m2", "m²", "sqm", "м2", "м²", "кв м", "кв.м"]],
    ["area", 1e6, "km²", ["km2", "km²", "км2", "км²", "кв км"]],
    ["area", 1e4, "ha", ["ha", "hectare", "hectares", "га", "гектар", "гектара", "гектаров", "гектарах"]],
    ["area", 100, "a", ["ar", "сотка", "сотки", "соток", "сотках"]],
    ["area", 4046.8564224, "acre", ["acre", "acres", "акр", "акра", "акров"]],
    ["area", 0.09290304, "ft²", ["ft2", "ft²", "sqft"]],
    // volume (l)
    ["volume", 0.001, "ml", ["ml", "мл", "миллилитр", "миллилитра", "миллилитров"]],
    ["volume", 1, "l", ["l", "liter", "liters", "litre", "litres", "л", "литр", "литра", "литров", "литрах"]],
    ["volume", 1000, "m³", ["m3", "m³", "м3", "м³", "куб", "кубометр", "кубометров"]],
    ["volume", 3.785411784, "gal", ["gal", "gallon", "gallons", "галлон", "галлона", "галлонов", "галлонах"]],
    ["volume", 0.946352946, "qt", ["qt", "quart", "quarts", "кварта", "кварты", "кварт"]],
    ["volume", 0.473176473, "pt", ["pt", "pint", "pints", "пинта", "пинты", "пинт"]],
    ["volume", 0.2365882365, "cup", ["cup", "cups", "чашка", "чашки", "чашек"]],
    ["volume", 0.0295735295625, "fl oz", ["floz", "fl oz", "fl.oz"]],
    // angle (degrees)
    ["angle", 1, "°", ["deg", "degree", "degrees", "градус", "градуса", "градусов", "градусах"]],
    ["angle", 180 / Math.PI, "rad", ["rad", "radian", "radians", "радиан", "радиана", "радианах"]],
    // temperature: handled apart (offsets)
    ["temp", 0, "°C", ["c", "°c", "°с", "degc", "degс", "celsius", "цельсий", "цельсия", "цельсиях", "градусов цельсия", "градуса цельсия", "по цельсию", "ц"]],
    ["temp", 0, "°F", ["f", "°f", "°ф", "degf", "fahrenheit", "фаренгейт", "фаренгейта", "фаренгейтах", "по фаренгейту", "градусов фаренгейта", "ф"]],
    ["temp", 0, "K", ["k", "kelvin", "kelvins", "кельвин", "кельвина", "кельвинов", "кельвинах", "к"]]
];
const _exact = {}, _lower = {};
for (const u of UNITS)
    for (const a of u[3]) {
        if (!(a in _exact))
            _exact[a] = u;
        const l = a.toLowerCase();
        if (!(l in _lower))
            _lower[l] = u;
    }
function unit(name) {
    const n = String(name).trim().replace(/\s+/g, " ").replace(/^(в|во|to|in)\s+/, "");
    return _exact[n] || _exact[n.replace(/°/g, "deg")] || _lower[n.toLowerCase()] || _lower[n.toLowerCase().replace(/°\s*/g, "°")] || null;
}
function toKelvin(v, sym) {
    return sym === "°C" ? v + 273.15 : sym === "°F" ? (v - 32) * 5 / 9 + 273.15 : v;
}
function fromKelvin(k, sym) {
    return sym === "°C" ? k - 273.15 : sym === "°F" ? (k - 273.15) * 9 / 5 + 32 : k;
}

const PHRASE = /^\s*(-?\d[\d\s]*(?:[.,]\d+)?(?:e[+-]?\d+)?)\s*(.+?)\s+(?:in|to|as|into|в|во|на|->|→|=)\s+(.+?)\s*$/i;
function number(s) {
    return parseFloat(String(s).replace(/\s/g, "").replace(",", "."));
}

// "10 km in mi" → {value, text, from, to} or null
function convert(text) {
    const m = PHRASE.exec(String(text));
    if (!m)
        return null;
    const v = number(m[1]);
    const a = unit(m[2]), b = unit(m[3]);
    if (!isFinite(v) || !a || !b || a[0] !== b[0] || a === b)
        return null;
    const out = a[0] === "temp" ? fromKelvin(toKelvin(v, a[2]), b[2]) : v * a[1] / b[1];
    // six significant digits are plenty for a conversion (6.21371 mi, not 6.21371192237)
    const s = format(Math.abs(out) >= 1e15 || out === 0 ? out : Number(out.toPrecision(6)));
    return s === null ? null : {
        "value": out,
        "text": s,
        "amount": format(v),
        "from": a[2],
        "to": b[2]
    };
}

// ---- currencies: the rates (per 1 USD) come from Calc.qml ----
const CURRENCIES = {
    "USD": ["usd", "$", "us$", "dollar", "dollars", "доллар", "доллара", "долларов", "долларах", "доллары", "доллару", "долл", "бакс", "бакса", "баксов", "баксах", "баксы"],
    "EUR": ["eur", "€", "euro", "euros", "евро"],
    "RUB": ["rub", "₽", "руб", "рубль", "рубля", "рублей", "рублях", "рубли", "рублю", "р"],
    "GBP": ["gbp", "£", "pound", "pounds", "фунт", "фунта", "фунтов", "фунтах", "фунту", "фунт стерлингов", "фунтов стерлингов", "фунтах стерлингов"],
    "JPY": ["jpy", "¥", "yen", "иена", "иены", "иен", "иенах"],
    "CNY": ["cny", "rmb", "yuan", "юань", "юаня", "юаней", "юанях", "юаню"],
    "UAH": ["uah", "₴", "гривна", "гривны", "гривен", "гривнах", "гривне"],
    "KZT": ["kzt", "₸", "тенге"],
    "BYN": ["byn", "бел руб", "белорусский рубль", "белорусских рублей"],
    "TRY": ["try", "₺", "лира", "лиры", "лир", "лирах"],
    "PLN": ["pln", "zł", "злотый", "злотых"],
    "CHF": ["chf", "франк", "франка", "франков"],
    "KRW": ["krw", "₩", "вона", "вон"],
    "INR": ["inr", "₹", "рупия", "рупии", "рупий"],
    "GEL": ["gel", "₾", "лари"],
    "AMD": ["amd", "֏", "драм", "драма", "драмов"],
    "AED": ["aed", "дирхам", "дирхама", "дирхамов"],
    "THB": ["thb", "฿", "бат", "бата", "батов"],
    "CAD": ["cad", "c$", "канадский доллар", "канадских долларов"],
    "AUD": ["aud", "a$", "австралийский доллар", "австралийских долларов"],
    "SEK": ["sek", "шведская крона", "шведских крон"],
    "CZK": ["czk", "kč", "чешская крона", "чешских крон"]
};
const _cur = {};
for (const code in CURRENCIES)
    for (const a of CURRENCIES[code])
        _cur[a] = code;
function currency(name, rates) {
    const n = String(name).trim().toLowerCase().replace(/\s+/g, " ");
    if (_cur[n])
        return _cur[n];
    const up = n.toUpperCase();
    return /^[A-Z]{3}$/.test(up) && rates && rates[up] ? up : null;
}
const SYMBOL_FIRST = /^\s*([$€£¥₽₴₸₺₹₩₾฿])\s*(\d[\d\s]*(?:[.,]\d+)?)(.*)$/;
// "сколько …?", "how much is …": the question around a sum
const ASK = /^\s*(?:сколько\s+(?:будет\s+)?|how\s+much\s+(?:is\s+)?|convert\s+|переведи\s+|перевести\s+)/i;
// 10к, 2,5 тыс, 1.2m, 3 млн: the amount's own multiplier (not a letter of the next word)
const MULT = /^(\s*-?\d[\d\s]*(?:[.,]\d+)?)\s*(k|к|тыс\.?|тысяч[аи]?|m|mln|млн\.?|миллион(?:а|ов)?)(?![a-zа-яё])/i;
const MULTS = {"k": 1e3, "к": 1e3, "m": 1e6, "mln": 1e6};
function multiplier(word) {
    const w = word.toLowerCase().replace(/\.$/, "");
    return MULTS[w] || (w.startsWith("тыс") ? 1e3 : 1e6);
}
const RATE = /^\s*(?:курс|exchange\s+rate|rate)\s+(.+?)(?:\s+(?:к|в|to|in)\s+(.+?))?\s*$/i;
const LONE = /^\s*(-?\d[\d\s]*(?:[.,]\d+)?)\s*(.+?)\s*$/;
// the other side when only one currency is named: home (the locale's), or — home itself
// named — dollars (euros for dollars)
function other(a, home) {
    if (home && a !== home)
        return home;
    return a === "USD" ? "EUR" : "USD";
}

// "100 usd в rub" → {amount, from, to} (the rate is applied by Calc.qml) or null; `home` is the
// currency a lone sum goes into ("100$", "курс доллара")
function money(text, rates, home) {
    let t = String(text).replace(ASK, "").replace(/[?？]+\s*$/, "");
    const r = RATE.exec(t);
    if (r) {
        const a = currency(r[1], rates);
        const b = r[2] ? currency(r[2], rates) : a && other(a, home);
        return a && b && a !== b ? {
            "amount": 1,
            "from": a,
            "to": b
        } : null;
    }
    const sym = SYMBOL_FIRST.exec(t);
    if (sym)
        t = sym[2].trim() + " " + sym[1] + " " + sym[3].trim();
    // "100$ в рублях": a symbol glued to the number
    t = t.replace(/^(\s*-?\d[\d\s]*(?:[.,]\d+)?)([$€£¥₽₴₸₺₹₩₾฿])/, "$1 $2");
    let k = 1;
    const mm = MULT.exec(t);
    if (mm) {
        k = multiplier(mm[2]);
        t = mm[1] + " " + t.slice(mm[0].length).trim();
    }
    const m = PHRASE.exec(t);
    const lone = m ? null : LONE.exec(t);
    if (!m && !lone)
        return null;
    const v = number((m || lone)[1]) * k;
    const a = currency((m || lone)[2], rates);
    const b = m ? currency(m[3], rates) : a && other(a, home);
    if (!isFinite(v) || !a || !b || a === b)
        return null;
    return {
        "amount": v,
        "from": a,
        "to": b
    };
}
