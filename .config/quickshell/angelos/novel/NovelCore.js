.pragma library

// angelOS novel — the rules both sides share: the engine in the shell (services/Novel.qml)
// and the dialogue editor in the browser (the author's tool, owner/novel-editor — not shipped;
// served by nov-editor.py with the pragma line cut off). One file, so the editor's play-test
// does exactly what the shell does.
//
// A story (one chapter) is JSON:
//   { id, title, with: "angel"|"demon"|"any", start: nodeId, vars: {name: default},
//     nodes: { id: node }, pools: { questions: [nodeId…], drops: [{who, text}…] },
//     ambient: { questions: [minMin, maxMin], drops: [minMin, maxMin] } }
// Node types (every node may have `when`: now | click | resume | "minutes:N", the moment
// it waits for, and `note` — a comment for the author):
//   event   the chapter's entry: `trigger` resume | start | manual; → next
//   say     who + sprite say text; → next
//   choice  who asks text, `choices`: [{text, tone, set, reply: {who, sprite, text}, next}];
//           `shuffle`: the answers come in another order every time (silent ones last)
//   note    a crumpled paper: from "desk" (on the wallpaper) or "angel" (she drops it); title,
//           text; read it → next
//   set     vars changed (`set`: {trust: "+1", gender: "f"}); → next
//   if      `cond` (trust >= 2 and gender == "f"; seen(nodeId); not …) → then | else
//   random  one of `next` (a list) at random
//   free    the chapter opens up: from now on random questions (pools.questions, each once)
//           and dropped notes (pools.drops) come by themselves; → next (optional)
//   end     the chapter is over; `chapter`: the next one to start (optional)
// The game's scenes (story/scenes/*.json in the shell, services/Game) are stories too, with
// three more nodes and a `cond` on their event (the scene plays only when it holds; of
// several, the highest `priority`, then the first by id):
//   circle  hell: `to` deeper (the next circle down) | stay (the try failed) | a circle's id;
//           → next (optional)
//   exit    the way out of hell: `outcome` stars | pact | limbo (the scene ends)
//   scene   go on in another scene: `to` its id
// Text templates: {name} · {g:male|female|unknown} (the unknown part may be left out:
// "male/female") · {app} · {song} · {time} · {daypart} · {uptime} · {var:name}. A text may
// also be {ru, en}: the shell's language picks.

var TYPES = ["event", "say", "choice", "note", "set", "if", "random", "free", "end", "circle", "exit", "scene"];
var OUTCOMES = ["stars", "pact", "limbo"];
var WHO = ["angel", "demon", "narrator"];
var TONES = ["positive", "negative", "silent", "neutral"];

function dayPart(h) {
    return h < 5 ? "ночь" : h < 12 ? "утро" : h < 18 ? "день" : h < 23 ? "вечер" : "ночь";
}

// ---- text ----
// ctx: {vars, name, app, song, uptime, english, now: Date}
function pickLang(text, english) {
    if (text && typeof text === "object" && !Array.isArray(text))
        return english ? (text.en !== undefined ? text.en : text.ru) : (text.ru !== undefined ? text.ru : text.en);
    return text;
}
function render(text, ctx) {
    ctx = ctx || {};
    var vars = ctx.vars || {};
    text = pickLang(text, ctx.english);
    return String(text || "").replace(/\{([^{}]*)\}/g, function (all, body) {
        if (body.indexOf("g:") === 0) {
            var parts = body.slice(2).split("|");
            var g = vars.gender;
            if (g === "m")
                return parts[0] || "";
            if (g === "f")
                return parts[1] !== undefined ? parts[1] : parts[0];
            return parts[2] !== undefined ? parts[2] : (parts[0] || "") + (parts[1] !== undefined ? "/" + parts[1] : "");
        }
        if (body.indexOf("var:") === 0) {
            var v = vars[body.slice(4).trim()];
            return v === undefined || v === null ? "" : String(v);
        }
        var now = ctx.now || new Date();
        switch (body.trim()) {
        case "name":
            return ctx.name || "";
        case "app":
            return ctx.app || "компьютер";
        case "song":
            return ctx.song || "тишина";
        case "uptime":
            return ctx.uptime || "";
        case "time":
            return ("0" + now.getHours()).slice(-2) + ":" + ("0" + now.getMinutes()).slice(-2);
        case "daypart":
            return dayPart(now.getHours());
        }
        return all;
    });
}

// ---- conditions: a tiny safe language, no eval ----
//   trust >= 2 and (gender == "f" or not seen("q_stay"))
function tokens(src) {
    var out = [], i = 0, s = String(src || "");
    while (i < s.length) {
        var c = s[i];
        if (/\s/.test(c)) {
            i++;
            continue;
        }
        var two = s.substr(i, 2);
        if (["==", "!=", ">=", "<=", "&&", "||"].indexOf(two) >= 0) {
            out.push({ t: "op", v: two === "&&" ? "and" : two === "||" ? "or" : two });
            i += 2;
            continue;
        }
        if ("<>()!,".indexOf(c) >= 0) {
            out.push({ t: c === "!" ? "op" : c === "(" || c === ")" || c === "," ? c : "op", v: c === "!" ? "not" : c });
            i++;
            continue;
        }
        if (c === '"' || c === "'") {
            var j = s.indexOf(c, i + 1);
            if (j < 0)
                throw new Error("незакрытая кавычка");
            out.push({ t: "str", v: s.slice(i + 1, j) });
            i = j + 1;
            continue;
        }
        var m = /^-?\d+(\.\d+)?/.exec(s.slice(i));
        if (m) {
            out.push({ t: "num", v: parseFloat(m[0]) });
            i += m[0].length;
            continue;
        }
        m = /^[A-Za-z_А-Яа-яЁё][\wА-Яа-яЁё]*/.exec(s.slice(i));
        if (m) {
            var w = m[0];
            if (w === "and" || w === "or" || w === "not" || w === "и" || w === "или" || w === "не")
                out.push({ t: "op", v: w === "и" ? "and" : w === "или" ? "or" : w === "не" ? "not" : w });
            else if (w === "true" || w === "false")
                out.push({ t: "bool", v: w === "true" });
            else
                out.push({ t: "id", v: w });
            i += w.length;
            continue;
        }
        throw new Error("не понимаю «" + c + "»");
    }
    return out;
}
// recursive descent: or → and → not → compare → value
// fns: more functions of one argument the condition may call ({name: fn}; the achievements'
// count("event"), kinds("event"), got("id") — services/Achievements); seen() is always there
function evalCond(expr, vars, seen, fns) {
    if (expr === undefined || expr === null || String(expr).trim() === "")
        return true;
    var ts = tokens(expr), p = 0;
    vars = vars || {};
    seen = seen || [];
    fns = fns || {};
    function peek() {
        return ts[p];
    }
    function eat(t, v) {
        var k = ts[p];
        if (!k || k.t !== t || (v !== undefined && k.v !== v))
            throw new Error("ожидалось " + (v || t));
        p++;
        return k;
    }
    function value() {
        var k = ts[p++];
        if (!k)
            throw new Error("условие обрывается");
        if (k.t === "num" || k.t === "str" || k.t === "bool")
            return k.v;
        if (k.t === "(") {
            var v = orx();
            eat(")");
            return v;
        }
        if (k.t === "id") {
            if (peek() && peek().t === "(") {
                eat("(");
                var arg = value();
                eat(")");
                if (k.v === "seen")
                    return seen.indexOf(String(arg)) >= 0;
                if (typeof fns[k.v] === "function")
                    return fns[k.v](arg);
                throw new Error("нет функции " + k.v);
            }
            var x = vars[k.v];
            return x === undefined ? 0 : x;
        }
        throw new Error("лишнее «" + k.v + "»");
    }
    function compare() {
        var a = value();
        var k = peek();
        if (k && k.t === "op" && ["==", "!=", ">", "<", ">=", "<="].indexOf(k.v) >= 0) {
            p++;
            var b = value();
            switch (k.v) {
            case "==":
                return a == b;
            case "!=":
                return a != b;
            case ">":
                return a > b;
            case "<":
                return a < b;
            case ">=":
                return a >= b;
            case "<=":
                return a <= b;
            }
        }
        return !!a;
    }
    function notx() {
        var k = peek();
        if (k && k.t === "op" && k.v === "not") {
            p++;
            return !notx();
        }
        return compare();
    }
    function andx() {
        var v = notx();
        while (peek() && peek().t === "op" && peek().v === "and") {
            p++;
            var w = notx();
            v = v && w;
        }
        return v;
    }
    function orx() {
        var v = andx();
        while (peek() && peek().t === "op" && peek().v === "or") {
            p++;
            var w = andx();
            v = v || w;
        }
        return v;
    }
    var r = orx();
    if (p < ts.length)
        throw new Error("лишнее в конце");
    return !!r;
}
function checkCond(expr, fns) {
    try {
        evalCond(expr, {}, [], fns);
        return "";
    } catch (e) {
        return e.message;
    }
}

// ---- variables ----
// set: {trust: "+1", mood: "-2", gender: "f", met: true}
function applySet(vars, set) {
    var out = {};
    for (var k in vars)
        out[k] = vars[k];
    for (var key in (set || {})) {
        var v = set[key];
        if (typeof v === "string" && /^[+-]\d+(\.\d+)?$/.test(v.trim()))
            out[key] = (Number(out[key]) || 0) + parseFloat(v);
        else
            out[key] = v;
    }
    return out;
}

// ---- the graph ----
// every way out of a node: [{to, label, kind}]
function exits(node) {
    var out = [];
    if (!node)
        return out;
    var push = function (to, label, kind) {
        if (to)
            out.push({ to: String(to), label: label || "", kind: kind || "next" });
    };
    switch (node.type) {
    case "choice":
        (node.choices || []).forEach(function (c, i) {
            push(c.next, (i + 1) + ". " + (c.text || ""), c.tone || "neutral");
        });
        break;
    case "if":
        push(node.then, "да", "then");
        push(node["else"], "нет", "else");
        break;
    case "random":
        (Array.isArray(node.next) ? node.next : [node.next]).forEach(function (to) {
            push(to, "?", "random");
        });
        break;
    case "exit":
    case "scene":
        break;
    default:
        if (Array.isArray(node.next))
            node.next.forEach(function (to) {
                push(to, "", "next");
            });
        else
            push(node.next, "", "next");
    }
    return out;
}

// problems an author should know about: [{node, level: error|warn, text}]
function validate(story) {
    var out = [];
    if (!story || typeof story !== "object")
        return [{ node: "", level: "error", text: "это не глава" }];
    var nodes = story.nodes || {};
    var ids = Object.keys(nodes);
    if (!story.start || !nodes[story.start])
        out.push({ node: "", level: "error", text: "нет стартового узла (start)" });
    var reach = {};
    var stack = story.start && nodes[story.start] ? [story.start] : [];
    // the pools' questions are entered by themselves
    ((story.pools || {}).questions || []).forEach(function (q) {
        if (nodes[q])
            stack.push(q);
        else
            out.push({ node: "", level: "error", text: "в пуле вопросов нет узла «" + q + "»" });
    });
    while (stack.length) {
        var id = stack.pop();
        if (reach[id])
            continue;
        reach[id] = true;
        exits(nodes[id]).forEach(function (e) {
            if (nodes[e.to])
                stack.push(e.to);
        });
    }
    ids.forEach(function (id) {
        var n = nodes[id];
        if (TYPES.indexOf(n.type) < 0)
            out.push({ node: id, level: "error", text: "неизвестный тип «" + n.type + "»" });
        exits(n).forEach(function (e) {
            if (!nodes[e.to])
                out.push({ node: id, level: "error", text: "ведёт в несуществующий узел «" + e.to + "»" });
        });
        var said = pickLang(n.text, false);
        if ((n.type === "say" || n.type === "choice") && !String(said || "").trim())
            out.push({ node: id, level: "warn", text: "пустая реплика" });
        if (n.type === "choice" && !(n.choices || []).length)
            out.push({ node: id, level: "error", text: "у вопроса нет вариантов ответа" });
        if (n.type === "if" || (n.type === "event" && n.cond)) {
            var err = checkCond(n.cond);
            if (err)
                out.push({ node: id, level: "error", text: "условие: " + err });
        }
        if (n.type === "circle" && !n.to)
            out.push({ node: id, level: "error", text: "круг: нет «to» (deeper, stay или id круга)" });
        if (n.type === "exit" && OUTCOMES.indexOf(n.outcome) < 0)
            out.push({ node: id, level: "error", text: "выход: неизвестный исход «" + n.outcome + "»" });
        if (n.type === "scene" && !n.to)
            out.push({ node: id, level: "error", text: "сцена: нет «to»" });
        if (["say", "note", "set", "event"].indexOf(n.type) >= 0 && !n.next)
            out.push({ node: id, level: "warn", text: "никуда не ведёт (нет «дальше»)" });
        if (n.type === "choice")
            (n.choices || []).forEach(function (c, i) {
                if (!c.next && !(c.reply && c.reply.text))
                    out.push({ node: id, level: "warn", text: "ответ " + (i + 1) + " никуда не ведёт" });
            });
        if (!reach[id])
            out.push({ node: id, level: "warn", text: "сюда нельзя попасть" });
        if (n.when && !/^(now|click|resume|minutes:\d+)$/.test(n.when))
            out.push({ node: id, level: "error", text: "непонятное «когда»: " + n.when });
    });
    return out;
}

// a fresh node of a type, for the editor
function blank(type) {
    switch (type) {
    case "say":
        return { type: "say", who: "angel", sprite: "neutral", text: "" , next: "" };
    case "choice":
        return { type: "choice", who: "angel", sprite: "neutral", text: "", choices: [
                { text: "", tone: "positive", next: "" }, { text: "", tone: "negative", next: "" }, { text: "Промолчать", tone: "silent", next: "" }] };
    case "note":
        return { type: "note", from: "desk", title: "", text: "", next: "" };
    case "set":
        return { type: "set", set: {}, next: "" };
    case "if":
        return { type: "if", cond: "", then: "", "else": "" };
    case "random":
        return { type: "random", next: [] };
    case "free":
        return { type: "free", next: "" };
    case "end":
        return { type: "end" };
    case "event":
        return { type: "event", trigger: "resume", next: "" };
    case "circle":
        return { type: "circle", to: "deeper" };
    case "exit":
        return { type: "exit", outcome: "stars" };
    case "scene":
        return { type: "scene", to: "" };
    }
    return { type: type };
}
