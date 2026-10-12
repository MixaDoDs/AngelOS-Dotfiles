const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const source = fs.readFileSync(path.join(__dirname, "../modules/bar/parts/EqMotion.js"), "utf8");
const motion = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*/m, ""), motion);

test("cava frames drive ten bounded frequencies, silence stays silent", () => {
    assert.deepEqual(Array.from(motion.decodeSpectrum("0;15;20;30;40;50;60;70;80;100;")),
                     [0, .15, .2, .3, .4, .5, .6, .7, .8, 1]);
    assert.deepEqual(Array.from(motion.decodeSpectrum("0;0;0;0;0;0;0;0;0;0;")),
                     [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
});

test("bad or partial cava frames cannot make a false moving spectrum", () => {
    assert.deepEqual(Array.from(motion.decodeSpectrum("1;2;3;")), []);
    assert.deepEqual(Array.from(motion.decodeSpectrum("1;2;3;4;5;6;7;8;9;NaN;")), []);
    assert.deepEqual(Array.from(motion.decodeSpectrum("1;2;3;4;5;6;7;8;9;10;11;")), []);
});

test("preset pulse lights successive bands once then goes away", () => {
    assert.equal(motion.pulseStrength(-1, 0), 0);
    assert.equal(motion.pulseStrength(0.5, 0), 1);
    assert.equal(motion.pulseStrength(0.5, 1), 0);
    assert.equal(motion.pulseStrength(4.5, 4), 1);
    assert.equal(motion.pulseStrength(10, 9), 0);
});

test("quiet real audio stays visible without inventing motion in silence", () => {
    assert.equal(motion.displayLevel(0), 0);
    assert.ok(motion.displayLevel(.09) >= .3);
    assert.equal(motion.displayLevel(1), 1);
});
