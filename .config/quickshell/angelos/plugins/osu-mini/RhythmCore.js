.pragma library

// osu!mini's rhythm mode (Rhythm.qml): two drums, D and K, under the track that plays now —
// the left one on the sung words (services/Lyrics), the right one on the beat
// (scripts/osu-beats.py). The rules here, plain functions: tests/rhythm/run.sh runs them in node.

var PERFECT = 45;       // ms either side
var GOOD = 100;
var MISS = 150;         // later than this the note is gone; earlier a press doesn't take it

// a press `delta` ms off its note: "perfect" | "good" | "miss" | "" (too early, not this note)
function judge(delta) {
    var d = Math.abs(delta);
    return d <= PERFECT ? "perfect" : d <= GOOD ? "good" : d <= MISS ? "miss" : "";
}
function points(result, combo) {
    var base = result === "perfect" ? 300 : result === "good" ? 100 : 0;
    return Math.round(base * (1 + Math.min(combo, 100) / 50));
}
function accuracy(n) {
    var all = n.perfect + n.good + n.miss;
    return all ? (n.perfect + n.good / 2) / all : 1;
}

// ---- the voice: a note where a line starts, or on each word when the lyrics have them ----
// lines: Lyrics.lines ([{t, text, w?: [seconds…]}]); out: track times in ms, at least `gap` apart
function voiceNotes(lines, gap) {
    var out = [];
    for (var i = 0; i < (lines || []).length; i++) {
        var l = lines[i];
        if (!l || !/[^\s♪♫♩♬…·.,:;!?'"()\[\]*~\-–—]/.test(l.text || ""))
            continue;       // a pause («♪», «…», empty) isn't sung
        var ts = l.w && l.w.length ? l.w : [l.t];
        for (var j = 0; j < ts.length; j++) {
            var t = Math.round(ts[j] * 1000);
            if (!out.length || t - out[out.length - 1] >= gap)
                out.push(t);
        }
    }
    return out;
}

// ---- the player's clock: MPRIS from a browser jumps about; our own clock, nudged by it ----
// a sample: the player's position (s) seen at a wall time (ms); `off` = track ms − wall ms
function newClock() {
    return {
        "off": 0,
        "samples": [],
        "settled": false,
        "jumps": 0
    };
}
function median(a) {
    var s = a.slice().sort(function (x, y) {
        return x - y;
    });
    return s.length ? s[s.length >> 1] : 0;
}
function clockFeed(c, pos, wall) {
    var o = pos * 1000 - wall;
    // far off the others: a seek or a restart; start over
    if (c.samples.length && Math.abs(o - median(c.samples)) > 400) {
        c.samples = [];
        c.jumps++;
    }
    c.samples.push(o);
    if (c.samples.length > 7)
        c.samples.shift();
    c.off = median(c.samples);
    var last = c.samples.slice(-3);
    c.settled = last.length === 3 && Math.max.apply(null, last) - Math.min.apply(null, last) < 80;
    return c;
}

// ---- the beat: osu-beats.py's guesses ({bpm, beat: epoch ms, …} four times a second) held on
// one grid. A guess often counts the same pulse twice as fast or half as fast, or flips for a
// while to 4:3 or 3:2 of it: those don't move the grid; a different tempo has to hold for
// SWITCH ms first. Locked while most of the last WINDOW ms agreed; never locked within
// GIVEUP ms of the first guess: the track has no beat to play (free time, rubato, quiet).
var WINDOW = 6000;
var SWITCH = 3000;
var GIVEUP = 12000;
var SHARE = 0.6;

function newBeat() {
    return {
        "P": 0,             // ms a beat
        "anchor": 0,        // epoch ms of a beat
        "since": 0,         // when this tempo was taken
        "first": 0,         // the first guess
        "own": 0,           // the last guess of our pulse (×1, ×2, ×½)
        "inPhase": 0,       // the last guess on our beat
        "votes": [],        // [{at, ok}]
        "others": [],       // [{at, P, beat}] guesses of another pulse, the last SWITCH ms
        "shifted": [],      // [{at, beat}] our tempo off our beat, the last SWITCH ms
        "locked": false,
        "ever": false
    };
}
// how a guessed period relates to ours: 1 the same, 2 / 0.5 the same pulse counted double or
// half, 0 unrelated; `loose` also takes the 4:3 and 3:2 flips
function related(p, P, loose) {
    var ms = loose ? [1, 2, 0.5, 4 / 3, 3 / 4, 3 / 2, 2 / 3] : [1, 2, 0.5];
    for (var i = 0; i < ms.length; i++)
        if (Math.abs(p / (P * ms[i]) - 1) < 0.025)
            return ms[i];
    return 0;
}
function wrap(x, step) {
    return x - Math.round(x / step) * step;
}
function take(b, P, beat, at) {
    b.P = P;
    b.anchor = beat;
    b.since = b.own = b.inPhase = at;
    b.votes = [];
    b.others = [];
    b.shifted = [];
}
function recent(list, at) {
    while (list.length && list[0].at < at - SWITCH)
        list.shift();
}
// a stretch of SWITCH ms that said the same all along
function held(list, at) {
    return list.length >= SWITCH / 250 * 0.6 && list[0].at <= at - SWITCH * 0.8;
}
function beatFeed(b, msg, at) {
    if (!msg || !(msg.bpm > 0))
        return b;
    var p = 60000 / msg.bpm;
    if (!b.first)
        b.first = at;
    if (!b.P)
        take(b, p, msg.beat, at);
    var strict = related(p, b.P, false);
    if (strict)
        b.own = at;
    else
        b.others.push({
            "at": at,
            "P": p,
            "beat": msg.beat
        });
    if (strict === 1) {
        // the guessed beat on our grid; far off it, our tempo on a beat of its own
        b.anchor += Math.round((msg.beat - b.anchor) / b.P) * b.P;
        var e = wrap(msg.beat - b.anchor, b.P);
        if (Math.abs(e) < 0.2 * b.P) {
            b.anchor += e * 0.3;
            b.P = b.P * 0.85 + p * 0.15;
            b.inPhase = at;
        } else
            b.shifted.push({
                "at": at,
                "beat": msg.beat
            });
    } else if (strict) {
        // the pulse counted double (its beats on ours and halfway) or half (on every other of ours)
        var step = strict === 0.5 ? b.P / 2 : b.P;
        if (Math.abs(wrap(msg.beat - b.anchor, step)) < 0.2 * step)
            b.inPhase = at;
    }
    recent(b.others, at);
    recent(b.shifted, at);
    // our tempo on another beat all along: the grid moves over, the lock stays
    if (at - b.inPhase >= SWITCH && held(b.shifted, at)) {
        b.anchor = msg.beat;
        b.inPhase = at;
        b.shifted = [];
    }
    // our pulse unheard for SWITCH ms and another one all that time: the track's tempo now
    if (!strict && at - b.own >= SWITCH && held(b.others, at)) {
        var same = 0;
        for (var i = 0; i < b.others.length; i++)
            if (related(b.others[i].P, p, false) === 1)
                same++;
        if (same >= b.others.length * 0.8)
            take(b, p, msg.beat, at);
    }
    b.votes.push({
        "at": at,
        "ok": related(p, b.P, true) !== 0
    });
    while (b.votes.length && b.votes[0].at < at - WINDOW)
        b.votes.shift();
    var good = 0;
    for (var k = 0; k < b.votes.length; k++)
        if (b.votes[k].ok)
            good++;
    var share = b.votes.length ? good / b.votes.length : 0;
    // on: most agreeing for a while; off again only well below, or off our beat
    var onBeat = at - b.inPhase < SWITCH;
    b.locked = onBeat && (b.locked ? share >= SHARE - 0.15 : share >= SHARE && at - b.since >= 4000 && b.votes.length >= 12);
    if (b.locked)
        b.ever = true;
    return b;
}
// nothing left to try: no lock within GIVEUP of the first guess (or of `start` with none at all)
function beatHopeless(b, now, start) {
    return !b.ever && now - (b.first || start) >= GIVEUP;
}
// the beats (epoch ms) in (from, to]
function beatsBetween(b, from, to) {
    var out = [];
    if (!b.P)
        return out;
    var k = Math.floor((from - b.anchor) / b.P) + 1;
    for (var t = b.anchor + k * b.P; t <= to; t += b.P)
        out.push(t);
    return out;
}

// ---- the best of each track: ~/.local/state/angelos/rhythm.json → tracks[key] ----
// the saved list with this round in: {tracks, best: bool (a new best), first: bool (the
// track's first)}
function record(tracks, key, round) {
    var all = Object.assign({}, tracks || {});
    var had = all[key];
    var best = !had || round.score > had.score;
    if (best)
        all[key] = {
            "score": round.score,
            "acc": Math.round(round.acc * 10000) / 100,
            "combo": round.combo,
            "title": round.title || "",
            "artist": round.artist || "",
            "at": round.at || 0
        };
    return {
        "tracks": all,
        "best": best,
        "first": !had
    };
}
