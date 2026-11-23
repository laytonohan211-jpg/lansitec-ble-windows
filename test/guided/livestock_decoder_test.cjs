const assert = require('node:assert/strict');
const {decodeUplink} = require('../../android/app/src/main/assets/decoders/livestock.js');
const decode = hex => decodeUplink({fPort:8,bytes:Array.from(Buffer.from(hex,'hex'))});
for (const payload of ['113732780168016801680104','206450012C09290002','310A0500DC46CAFF90130F1E726AA0F9D8','6B0614']) {
  const result=decode(payload);
  assert.equal((result.errors||[]).length,0,JSON.stringify(result));
}
assert.ok((decode('310A05').errors||[]).length>0);
console.log('Livestock decoder: 5 documented/invalid vectors passed');

assert.equal(decode('206450012C09290002').data.charging_duration_min, 2);
assert.equal(decode('206400000080000000').data.temperature_valid, false);
const unknown = decode('30FFFFFFFF000000000000000000000000').data;
assert.equal(unknown.hdop, null); assert.equal(unknown.satellites_visible, null);
const zero = decode('3000000000000000000000000000000000').data;
assert.equal(zero.hdop, 0); assert.equal(zero.satellites_visible, 0);
assert.equal(zero.accuracy_m, undefined);
const history = decode('800000003C206450012C09290002');
assert.equal(history.data.age_s, 60); assert.equal(history.data.charging_duration_min, 2);
assert.ok(decode('206450012C0929').errors.length > 0);
console.log('Latest workbook: heartbeat, temperature, GNSS zero/unknown and history assertions passed');
