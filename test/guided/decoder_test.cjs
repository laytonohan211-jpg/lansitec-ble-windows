const fs=require('fs'),vm=require('vm'),assert=require('assert');
for(const family of ['container','badge']){
 const c=vm.createContext({});vm.runInContext(fs.readFileSync(`android/app/src/main/assets/decoders/${family}.js`,'utf8'),c);
 const decode=h=>c.decodeChecked(h);
 for(const h of ['20','60FF00','6001','GG','F000'])assert.throws(()=>decode(h));
 const hb=Buffer.alloc(19);hb[0]=0x20;hb[3]=0x40;hb[5]=193;hb.writeInt16BE(-10,9);hb.writeUInt16BE(12,11);
 const d=decode(hb.toString('hex')).data;assert.equal(d.temperature,'-10°C');assert.equal(d.movementSeconds,60);assert.equal(d.batteryVoltage,'3.93V');
 const pos=Buffer.alloc(13);pos[0]=0x30;pos.writeFloatBE(-73.5,1);pos.writeFloatBE(40.75,5);
 const p=decode(pos.toString('hex')).data;assert.equal(p.longitude,-73.5);assert.equal(p.latitude,40.75);assert.equal(p.time,'1970-01-01T00:00:00.000Z');
 console.log(family+' decoder tests passed');
}
{
 const c=vm.createContext({});vm.runInContext(fs.readFileSync('android/app/src/main/assets/decoders/gateway.js','utf8'),c);
 for(const h of ['20','60FF00','6001','GG','F000'])assert.throws(()=>c.decodeChecked(h));
 assert(c.decodeChecked('60010078').data);
 console.log('gateway decoder bounds passed');
}
