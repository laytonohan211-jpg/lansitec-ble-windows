const assert = require('node:assert/strict');
const {decodeUplink} = require('../../assets/decoders/livestock.js');
const decode = hex => decodeUplink({fPort:8,bytes:Array.from(Buffer.from(hex,'hex'))});
for (const payload of ['113732780168016801680104','206450012C0929','310A0500DC46CAFF90130F1E726AA0F9D8','6B0614']) {
  const result=decode(payload);
  assert.equal((result.errors||[]).length,0,JSON.stringify(result));
}
assert.ok((decode('310A05').errors||[]).length>0);
console.log('Livestock decoder: 5 documented/invalid vectors passed');
