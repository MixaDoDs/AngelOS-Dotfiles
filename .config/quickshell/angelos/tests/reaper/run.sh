#!/usr/bin/env bash
# «Смерть на смене» (modules/reaper/ReaperCore.js, ReaperArt.js, ReaperLines.js): the rules' order,
# the shift, the souls and their sprites, the room's pictures, the talk. Plain node, no shell needed.   tests/reaper/run.sh [angelOS dir]   exit 0 = good
set -euo pipefail
DIR="$(cd "${1:-"$(dirname "$0")/../.."}" && pwd)"
command -v node >/dev/null || { echo "no node"; exit 77; }
node - "$DIR/modules/reaper/ReaperCore.js" <<'JS'
const assert = require("assert");
const load = (f, names) => new Function(require("fs").readFileSync(f, "utf8").replace(".pragma library", "") + "; return {" + names + "};")();
const C = load(process.argv[2], "rules, lastDay, active, newRule, quota, seconds, verdict, make, sprite");
const A = load(process.argv[2].replace("Core", "Art"), "W, H, colors, at, room, heavenLight, doors, fire, hole, clock, eye, flame, death, scythe, people, spill");
const T = load(process.argv[2].replace("Core", "Lines"), "cast, talk, after, soulLine");
assert.strictEqual(C.verdict({}, 7).to, "heaven");
assert.strictEqual(C.verdict({knife: true}, 1).to, "hell");
assert.strictEqual(C.verdict({knife: true, halo: true}, 1).to, "hell");     // the halo isn't a rule yet
assert.strictEqual(C.verdict({knife: true, halo: true}, 2).to, "heaven");
assert.strictEqual(C.verdict({halo: true, horns: true}, 3).to, "heaven");
assert.strictEqual(C.verdict({mask: true, halo: true}, 5).to, "limbo");
assert.strictEqual(C.verdict({cat: true, bottle: true}, 6).to, "heaven");
assert.strictEqual(C.verdict({cross: true, horns: true}, 7).to, "hell");
for (let d = 1; d <= C.lastDay; d++)
    assert.ok(C.newRule(d), "a new rule on day " + d);
for (let i = 0; i < 2000; i++) {
    const d = 1 + (i % 9), s = C.make(d);
    assert.ok(!(s.knife && s.bottle));
    for (const r of C.rules)
        if (r.day > d) assert.ok(!s[r.id], r.id + " before its day");
    const rows = C.sprite(s);
    assert.strictEqual(rows.length, 24);
    assert.ok(rows.every(r => r.length === 18 && [...r].every(c => c === "." || A.colors[c])));
    assert.ok(T.soulLine(s).ru.length > 0);
}
// every thing changes the picture
for (const r of C.rules)
    assert.notDeepStrictEqual(C.sprite({[r.id]: true}), C.sprite({}), r.id);
// every picture: even rows, only colours of the palette
const pics = {room: A.room(), death: A.death, scythe: A.scythe(true), hell: A.doors().hell, heaven: A.doors().heaven,
    off: A.eye(null, 0, 0, false), eye: A.eye(1, 1, 1, true), clock: A.clock(5), spill: A.spill("H", 25, 14)};
for (let p = 0; p < 12; p++) Object.assign(pics, {["light" + p]: A.heavenLight(p), ["fire" + p]: A.fire(p), ["hole" + p]: A.hole(p)});
A.flame.forEach((f, i) => pics["flame" + i] = f);
for (const k in A.people) pics[k] = A.people[k];
for (const [k, rows] of Object.entries(pics)) {
    assert.ok(rows.length && rows.every(r => r.length === rows[0].length), k + ": uneven rows");
    assert.ok(rows.every(r => [...r].every(c => c === "." || A.colors[c])), k + ": a colour not in the palette");
}
assert.strictEqual(A.room().length, A.H);
assert.strictEqual(A.room()[0].length, A.W);
for (const k in A.people) assert.deepStrictEqual([A.people[k].length, A.people[k][0].length], [24, 18], k);
// every day talks (the rule days and after), every speaker is in the cast, both languages
for (let d = 1; d <= 20; d++)
    for (const l of T.talk(d))
        assert.ok(T.cast[l.who] && l.ru && l.en, "day " + d + ": " + JSON.stringify(l));
for (const k in T.after) assert.ok(T.after[k].length && T.after[k].every(l => T.cast[l.who] && l.ru && l.en), k);
assert.ok(["won", "time", "mistakes"].every(k => T.after[k]));
assert.ok(/[?.!…]/.test(T.soulLine({mask: true}).ru));
console.log("reaper: ok");
JS
