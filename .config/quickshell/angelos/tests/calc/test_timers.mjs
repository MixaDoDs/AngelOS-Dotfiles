// the launcher's timer phrases (services/TimerCore.js parse)
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
const src = readFileSync(new URL("../../services/TimerCore.js", import.meta.url), "utf8").replace(/^\.pragma library/m, "");
const T = new Function(src + "\nreturn { parse, clock, human };")();
const timer = (t, ms, label = "", said = false) => assert.deepEqual(T.parse(t), { kind: "timer", ms, label, said }, t);

timer("5m", 300000);
timer("5 мин", 300000);
timer("5 минут", 300000);
timer("90s", 90000);
timer("1h30m", 5400000);
timer("1 ч 30 мин", 5400000);
timer("2ч", 7200000);
timer("1,5 h", 5400000);
timer("25:00", 1500000);
timer("1:30:00", 5400000);
timer("5m чай", 300000, "чай");
timer("таймер 10", 600000, "", true);
timer("таймер на 5 минут чай", 300000, "чай", true);
timer("timer for 3 min eggs", 180000, "eggs", true);
timer("Таймер 2:30 паста", 150000, "паста", true);
assert.deepEqual(T.parse("секундомер"), { kind: "stopwatch", label: "" });
assert.deepEqual(T.parse("stopwatch бег"), { kind: "stopwatch", label: "бег" });
assert.deepEqual(T.parse("помодоро"), { kind: "pomodoro", work: 25, rest: 5, label: "" });
assert.deepEqual(T.parse("помодоро 50/10 диплом"), { kind: "pomodoro", work: 50, rest: 10, label: "диплом" });
assert.deepEqual(T.parse("pomodoro учёба"), { kind: "pomodoro", work: 25, rest: 5, label: "учёба" });
// the Halo's timer field: a bare number is minutes
assert.deepEqual(T.parse("25", true), { kind: "timer", ms: 1500000, label: "", said: false });
assert.deepEqual(T.parse("10 чай", true), { kind: "timer", ms: 600000, label: "чай", said: false });
assert.deepEqual(T.parse("помодоро 50/10", true), { kind: "pomodoro", work: 50, rest: 10, label: "" });
for (const t of ["abc", "0", "чай 10"])
    assert.equal(T.parse(t, true), null, t);
// not timers: a bare number, words, apps, maths, zero, too long
for (const t of ["10", "5", "telegram", "мин", "5 км", "5mm", "2+2", "0s", "таймер", "таймер 0", "200h", "10 мышей", "5 mi", "помодоро 0/5"])
    assert.equal(T.parse(t), null, t);

assert.equal(T.clock(75000), "1:15");
assert.equal(T.clock(3725000), "1:02:05");
assert.equal(T.clock(400), "0:01");
assert.equal(T.human(5400000), "1 ч 30 мин");
assert.equal(T.human(90000, true), "1 min 30 s");
console.log("timers ✓");
