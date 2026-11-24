import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const geometry = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../../modules/capture/CropGeometry.js', import.meta.url), 'utf8')
    .replace(/^\.pragma library\n/, ''), geometry);
const plain = value => JSON.parse(JSON.stringify(value));

assert.deepEqual(plain(geometry.select(90, 43, 20, 23, 100, 50)), {x: 0.2, y: 0.46, w: 0.7, h: 0.4});
assert.deepEqual(plain(geometry.select(-10, -5, 120, 40, 100, 50)), {x: 0, y: 0, w: 1, h: 0.8});
assert.equal(geometry.select(7, 10, 7, 14, 100, 50), null);
assert.equal(geometry.select(7, 10, 18, 20, 0, 50), null);

assert.equal(geometry.select(-20, 10, 0, 30, 100, 50), null);
assert.deepEqual(plain(geometry.select(0, 0, 100, 50, 100, 50)), {x: 0, y: 0, w: 1, h: 1});
console.log('Live crop geometry: 6 passed');
