const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
let seed = 0x6b17;
function next() { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed >>> 24; }
let checked = 0;
for (const family of ['container','badge','gateway','livestock']) {
  const base = fs.existsSync('assets/decoders') ? 'assets/decoders' : 'android/app/src/main/assets/decoders';
  const script = fs.readFileSync(`${base}/${family}.js`, 'utf8');
  const context = vm.createContext({});
  vm.runInContext(script, context, {timeout: 1000});
  for (const invalid of ['', '0', 'GG', 'AA'.repeat(4097), "';throw Error('injected');//"]) {
    context.input = invalid;
    assert.throws(() => vm.runInContext('decodeChecked(input)', context, {timeout:1000}));
    checked++;
  }
  for (let i=0;i<200;i++) {
    const length = i===199 ? 4096 : i % 128 + 1;
    context.input = Array.from({length}, () => next().toString(16).padStart(2,'0')).join('');
    let output;
    try { output=vm.runInContext('JSON.stringify(decodeChecked(input))', context, {timeout:1000}); }
    catch (error) { assert.notEqual(error.code,'ERR_SCRIPT_EXECUTION_TIMEOUT'); checked++; continue; }
    assert.equal(typeof output,'string');
    assert.ok(output.length < 1000000);
    JSON.parse(output);
    checked++;
  }
}
console.log(`Decoder boundary checks: ${checked} malformed/random/boundary payloads completed across four families`);

