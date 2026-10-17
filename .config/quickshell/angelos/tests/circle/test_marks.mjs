// the screenshot editor's geometry (modules/capture/ShotMarks.js), in node
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
const src = readFileSync(new URL("../../modules/capture/ShotMarks.js", import.meta.url), "utf8").replace(/^\.pragma library/m, "");
const M = new Function(src + "\nreturn { bounds, hit, moved, box, snap45, arrowHead, cropDrag, fitAspect };")();

// crop, Telegram-like: a corner, the whole box (kept inside), a ratio held and kept inside
assert.deepEqual(M.cropDrag({ x: 0, y: 0, w: 100, h: 100 }, 2, -20, -50, 100, 100, 0, 10), { x: 0, y: 0, w: 80, h: 50 });
assert.deepEqual(M.cropDrag({ x: 10, y: 10, w: 50, h: 50 }, 8, 100, -100, 100, 100, 0, 10), { x: 50, y: 0, w: 50, h: 50 });
let r = M.cropDrag({ x: 0, y: 0, w: 100, h: 50 }, 2, -50, 0, 200, 200, 2, 10);
assert.ok(Math.abs(r.w / r.h - 2) < 1e-9 && r.w === 50, JSON.stringify(r));
r = M.cropDrag({ x: 0, y: 0, w: 100, h: 50 }, 2, 500, 0, 200, 100, 2, 10);
assert.ok(r.x + r.w <= 200.0001 && r.y + r.h <= 100.0001 && Math.abs(r.w / r.h - 2) < 1e-9, JSON.stringify(r));
assert.deepEqual(M.cropDrag({ x: 20, y: 20, w: 50, h: 50 }, 0, 100, 100, 100, 100, 0, 10), { x: 60, y: 60, w: 10, h: 10 });
assert.deepEqual(M.fitAspect(200, 100, 1), { x: 50, y: 0, w: 100, h: 100 });

// marks: the topmost under the pointer, moved, boxes, 45° steps
assert.equal(M.hit([{ t: "rect", x: 0, y: 0, w: 10, h: 10 }, { t: "num", x: 5, y: 5, n: 1, s: 4 }], 5, 5, 0), 1);
assert.equal(M.hit([{ t: "rect", x: 0, y: 0, w: 10, h: 10 }], 50, 5, 2), -1);
assert.equal(M.hit([{ t: "pen", pts: [[0, 0], [100, 0]], w: 4 }], 50, 1, 0), 0);
assert.deepEqual(M.moved({ t: "arrow", a: [0, 0], b: [1, 1], w: 1 }, 2, 3).b, [3, 4]);
assert.deepEqual(M.moved({ t: "pen", pts: [[1, 1]], w: 1 }, 1, 1).pts, [[2, 2]]);
assert.deepEqual(M.box([10, 10], [0, 30], true), { x: -10, y: 10, w: 20, h: 20 });
assert.ok(Math.abs(M.snap45([0, 0], [10, 1])[1]) < 1e-9);
const h = M.arrowHead([0, 0], [100, 0], 4);
assert.ok(h.left[1] > 0 && h.right[1] < 0 && h.shaftEnd[0] < 100);
console.log("marks: ok");
