.pragma library

// The launcher's timer phrases (services/Timers.qml). parse(text) → null when the text is
// not one, else {kind: "timer", ms, label, said} · {kind: "stopwatch", label} ·
// {kind: "pomodoro", work, rest, label} (minutes); said = the prefix was typed (таймер …),
// a bare "5m" ranks below the apps (an app called «1С» stays on top). bareMinutes: a bare
// number is minutes ("25", "10 чай") — for a field that is only for timers (the Halo's).
//   5m · 1h30m · 1 ч 30 мин · 90s · 25:00 · 1:30:00 · таймер 10 · таймер на 5 минут чай
//   секундомер · stopwatch · помодоро · помодоро 50/10 · pomodoro учёба

const UNIT = /^(\d+(?:[.,]\d+)?)\s*(h|hrs?|hours?|ч|час(?:а|ов)?|m|mins?|minutes?|м|мин(?:ут[аы]?|ута)?|s|secs?|seconds?|с|сек(?:унд[аы]?|унда)?)(?![a-zа-яё])\s*/i;
const SECS = { "h": 3600, "ч": 3600, "m": 60, "м": 60, "s": 1, "с": 1 };
const MAX = 100 * 3600 * 1000;

function unitMs(n, u) {
    u = u.toLowerCase();
    const k = u.startsWith("ho") || u.startsWith("hr") ? "h" : u.startsWith("min") ? "m" : u.startsWith("sec") ? "s" : u[0];
    return parseFloat(n.replace(",", ".")) * SECS[k] * 1000;
}

// a duration at the start of the text: [ms, rest] or null
function duration(t, bareIsMinutes) {
    const clock = /^(\d{1,2}):([0-5]\d)(?::([0-5]\d))?(?![\d:])\s*/.exec(t);
    if (clock) {
        const a = +clock[1], b = +clock[2];
        const ms = clock[3] !== undefined ? ((a * 60 + b) * 60 + +clock[3]) * 1000 : (a * 60 + b) * 1000;
        return [ms, t.slice(clock[0].length)];
    }
    let ms = 0, rest = t, m;
    while ((m = UNIT.exec(rest))) {
        ms += unitMs(m[1], m[2]);
        rest = rest.slice(m[0].length);
    }
    if (ms)
        return [ms, rest];
    const bare = bareIsMinutes && /^(\d+(?:[.,]\d+)?)(?![\d.,])\s*/.exec(t);
    return bare ? [parseFloat(bare[1].replace(",", ".")) * 60000, t.slice(bare[0].length)] : null;
}

function parse(text, bareMinutes) {
    let t = String(text || "").trim().replace(/\s+/g, " ");
    if (!t || t.length > 120)
        return null;
    let m = /^(?:секундомер|stopwatch)(?:\s+(.*))?$/i.exec(t);
    if (m)
        return { "kind": "stopwatch", "label": (m[1] || "").trim() };
    m = /^(?:помодоро|pomodoro)(?:\s+(\d{1,3})(?:\s*\/\s*(\d{1,3}))?(?![\d/]))?(?:\s+(.*))?$/i.exec(t);
    if (m) {
        const work = m[1] ? +m[1] : 25, rest = m[2] ? +m[2] : 5;
        if (work < 1 || rest < 1)
            return null;
        return { "kind": "pomodoro", "work": work, "rest": rest, "label": (m[3] || "").trim() };
    }
    m = /^(?:таймер|timer)(?:\s+(?:на|for)(?=\s))?\s*/i.exec(t);
    const said = !!m && m[0].length > 0;
    if (said)
        t = t.slice(m[0].length);
    const d = duration(t, said || !!bareMinutes);
    if (!d || d[0] < 1000 || d[0] > MAX)
        return null;
    return { "kind": "timer", "ms": Math.round(d[0]), "label": d[1].trim(), "said": said };
}

// 75000 → "1:15", 3725000 → "1:02:05"
function clock(ms) {
    const s = Math.max(0, Math.ceil(ms / 1000));
    const h = Math.floor(s / 3600), mm = Math.floor(s % 3600 / 60), ss = s % 60;
    const two = n => (n < 10 ? "0" : "") + n;
    return h ? h + ":" + two(mm) + ":" + two(ss) : mm + ":" + two(ss);
}

// 300000 → "5 мин", 5400000 → "1 ч 30 мин", 90000 → "1 мин 30 с"
function human(ms, english) {
    const s = Math.round(ms / 1000);
    const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
    const parts = [];
    if (h)
        parts.push(h + (english ? " h" : " ч"));
    if (m)
        parts.push(m + (english ? " min" : " мин"));
    if (sec)
        parts.push(sec + (english ? " s" : " с"));
    return parts.join(" ") || (english ? "0 s" : "0 с");
}
