// what the screenshot overlay learns (services/CircleLearn.js), in node
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
const src = readFileSync(new URL("../../services/CircleLearn.js", import.meta.url), "utf8").replace(/^\.pragma library/m, "");
const L = new Function(src + "\nreturn { fresh, addEdge, edgeFor, edgeUnsure, moved, edgeDelta, addGrain, grainFor, grainOf, addDrop, unwanted, wordFixes, addFix, fixFor, fixUnsure, fixWords, count };")();
let n = 0;
const ok = (c, what) => { assert.ok(c, what); n++; };

// edges: a window taken without its 30 px title bar, three times → sure, in that app only
let db = L.fresh();
ok(L.edgeFor(db, "kitty", "window") === null, "nothing learned: nothing to do");
ok(L.edgeUnsure(db, "kitty", "window", [0, 30, 0, 0]), "the first one is asked about");
L.addEdge(db, "kitty", "window", [0, 30, 0, 0]);
ok(!L.edgeFor(db, "kitty", "window").sure, "one sample is not sure");
L.addEdge(db, "kitty", "window", [1, 29, 0, -2]);
L.addEdge(db, "kitty", "window", [0, 31, 2, 0]);
let e = L.edgeFor(db, "kitty", "window");
ok(e.sure && e.d[1] >= 29 && e.d[1] <= 31, "three alike: sure " + JSON.stringify(e));
ok(!L.edgeUnsure(db, "kitty", "window", [0, 33, 0, 0]), "a sample like them is not asked about");
ok(L.edgeUnsure(db, "kitty", "window", [0, 0, -200, 0]), "one unlike them is");
ok(L.edgeFor(db, "kitty", "image") === null, "another kind: nothing");
ok(L.edgeFor(db, "discord", "window").sure, "an app not seen: the common habit");
// one confirmed ("Remember") is enough
db = L.fresh();
L.addEdge(db, "discord", "image", [0, 0, 0, 24], true);
ok(L.edgeFor(db, "discord", "image").sure, "confirmed once: sure");
// opposite habits: not sure
db = L.fresh();
for (const d of [[0, 30, 0, 0], [0, -40, 0, 0], [0, 30, 0, 0], [0, -40, 0, 0]])
    L.addEdge(db, "x", "ui", d);
ok(!L.edgeFor(db, "x", "ui").sure, "habits that disagree are not sure");
// moved / edgeDelta: logical px × scale, kept in the frame
const r = { x: 100, y: 100, w: 400, h: 300 };
assert.deepEqual(L.moved(r, [0, 30, 0, 0], 2, 1920, 1080), { x: 100, y: 160, w: 400, h: 240 }); n++;
assert.deepEqual(L.moved(r, [-200, 0, 0, 0], 1, 1920, 1080), { x: 0, y: 100, w: 500, h: 300 }); n++;
ok(L.moved(r, [0, 400, 0, 0], 1, 1920, 1080) === r, "a move that leaves nothing: the area as it is");
ok(L.edgeDelta(r, { x: 101, y: 99, w: 400, h: 302 }, 1) === null, "3 px: no change");
assert.deepEqual(L.edgeDelta(r, { x: 100, y: 160, w: 400, h: 240 }, 2), [0, 30, 0, 0]); n++;

// grain: what a pick took against the tapped line
const w = (line, block, para) => ({ line, block, para });
const tapped = [w("1.1.1", 1, 1), w("1.1.1", 1, 1)];
ok(L.grainOf(tapped, tapped) === "line", "the line itself");
ok(L.grainOf(tapped, [...tapped, w("1.1.2", 1, 1)]) === "para", "its paragraph");
ok(L.grainOf(tapped, [...tapped, w("1.2.3", 1, 2)]) === "block", "its block");
ok(L.grainOf(tapped, [w("2.1.1", 2, 1)]) === null, "something else: nothing learned");
ok(L.grainOf(tapped, [tapped[0]]) === null, "a piece of the line: nothing learned");
db = L.fresh();
L.addGrain(db, "discord", "para");
L.addGrain(db, "discord", "para");
ok(L.grainFor(db, "discord") === null, "two: not yet");
L.addGrain(db, "discord", "para");
ok(L.grainFor(db, "discord") === "para", "three of a kind: the paragraph");
L.addGrain(db, "discord", "line");
L.addGrain(db, "discord", "line");
ok(L.grainFor(db, "discord") === null, "mixed habits: no rule");

// drops: let go of 5 of 6 → not shown; used often → shown
db = L.fresh();
for (let i = 0; i < 5; i++)
    L.addDrop(db, "kitty", "ui", true);
ok(!L.unwanted(db, "kitty", "ui"), "five: too few to tell");
L.addDrop(db, "kitty", "ui", true);
ok(L.unwanted(db, "kitty", "ui"), "six let go of: not shown");
L.addDrop(db, "kitty", "ui", false);
L.addDrop(db, "kitty", "ui", false);
ok(!L.unwanted(db, "kitty", "ui"), "used again: shown again");

// fixes: one for one, confirmed or twice
assert.deepEqual(L.wordFixes("Storage 14.2 CB of 15 GB", "Storage 14.2 GB of 15 GB"), [["CB", "GB"]]); n++;
assert.deepEqual(L.wordFixes("a b c", "a b"), []); n++;
db = L.fresh();
L.addFix(db, "kitty", "CB", "GB");
ok(L.fixFor(db, "kitty", "CB") === null && L.fixUnsure(db, "kitty", "CB", "GB"), "once: not yet, asked about");
L.addFix(db, "kitty", "CB", "GB");
ok(L.fixFor(db, "kitty", "CB") === "GB" && !L.fixUnsure(db, "kitty", "CB", "GB"), "twice: fixed");
ok(!(db.apps["*"] && db.apps["*"].fixes.CB), "a short word: not fixed for every app");
L.addFix(db, "", "teh", "the");
ok(L.fixFor(db, "", "teh") === null, "no app: once is once");
L.addFix(db, "tg", "anaelOS", "angelOS", true);
const fixed = L.fixWords(db, [{ t: "anaelOS", app: "tg" }, { t: "CB", app: "kitty" }, { t: "ok", app: "kitty" }], q => q.app);
assert.deepEqual(fixed.map(q => q.t), ["angelOS", "GB", "ok"]); n++;
ok(L.count(db) === 2, "counted (the short word not in it): " + L.count(db));

console.log("  ✓ learning: " + n + " checks (edges, grain, drops, fixes)");
