#!/usr/bin/env node
// Execute the production character implementation with real Three.js, not a duplicate/mock.
const fs = require('fs'), path = require('path'), vm = require('vm'), assert = require('assert');
const root = path.resolve(__dirname, '..');
const THREE = require(path.join(root,'vendor/three.min.js'));
const html = fs.readFileSync(path.join(root,'MoneyCity/Resources/diorama.html'),'utf8');
const source = html.slice(html.indexOf('    const M_SKIN  ='),html.indexOf('    // Register micro-idle'));
const helpers = `function mat(c,r){return new THREE.MeshStandardMaterial({color:new THREE.Color(c).convertSRGBToLinear(),roughness:r||.82})}
function mesh(g,m,x,y,z,cast,rec){const o=new THREE.Mesh(g,m);o.position.set(x||0,y||0,z||0);return o;}
const M_DARKFRAME=mat(0x30343a),Y_WALK=0;`;
function load(code=source) {
 const ctx=vm.createContext({THREE,console});
 vm.runInContext(helpers+code+`;globalThis.api={makeFigure,buildAppearanceProfile,applyAppearanceToFigure,appearanceSig,chooseAppearanceForSlot,CITIZEN_BODY_PROFILES,CITIZEN_GEO,citizenMatCache,citizenTorsoCache,citizenRestArms,groundCitizen,citizenSeatBlend};`,ctx);return ctx.api;
}
module.exports={source,helpers,load};
if(require.main !== module) return;
const a=load(), profiles=Array.from({length:30},(_,i)=>a.buildAppearanceProfile('review:citizen:'+i));
assert(profiles.filter(p=>p.presentation==='female').length>=8);
assert(profiles.filter(p=>p.presentation==='male').length>=8);
assert(new Set(profiles.map(p=>p.bodyId)).size>=6);
for(const presentation of ['female','male']) {
 const subset=profiles.filter(p=>p.presentation===presentation);
 assert(subset.some(p=>['crop','short','shaved'].includes(p.hairStyle)));
 assert(subset.some(p=>['long','ponytail','bun','bob'].includes(p.hairStyle)));
}
const records=profiles.map(p=>({obj:a.makeFigure({appearance:p}),baseY:0,appearance:p}));
const soles = c => { c.obj.updateMatrixWorld(true); return [c.obj.userData.kneeL,c.obj.userData.kneeR].map(k=>new THREE.Box3().setFromObject(k.children[2]).min.y); };
for(let i=0;i<30;i++) {
 const p=profiles[i],c=records[i],u=c.obj.userData;
 assert.deepStrictEqual(JSON.parse(JSON.stringify(p)),JSON.parse(JSON.stringify(a.buildAppearanceProfile(p.key))));
 assert(Math.abs(Math.min(...soles(c)))<1e-6,'standing soles grounded');
 for(let step=0;step<24;step++) {
   const swing=Math.sin(step/24*Math.PI*2)*.38;
   u.legL.rotation.x=swing;u.legR.rotation.x=-swing;
   u.kneeL.rotation.x=Math.max(0,swing)*.7;u.kneeR.rotation.x=Math.max(0,-swing)*.7;
   a.citizenRestArms(u,swing);a.groundCitizen(c);
   const y=Math.min(...soles(c)); assert(y>=-1e-5 && y<.009,'walk contact '+y);
 }
 const seated=a.makeFigure({appearance:p,seated:true}),su=seated.userData;
 assert(Math.abs(su.legL.position.y*seated.scale.y-(.2725+su.seatContact*seated.scale.y))<1e-7);
 assert(Math.abs(Math.min(...soles({obj:seated})))<1e-6,'seated soles');
 a.citizenSeatBlend(c,1);u.legL.rotation.x=u.legR.rotation.x=-Math.PI/2;u.kneeL.rotation.x=u.kneeR.rotation.x=Math.PI/2;
 assert(Math.abs(Math.min(...soles(c)))<1e-6,'bench soles');
 assert(Math.abs(c.obj.position.y+u.hipHeight*c.obj.scale.y-(.3275+u.seatContact*c.obj.scale.y))<1e-6,'bench seat contact');
 a.citizenSeatBlend(c,0);
}
function snapshot(c) {
 const out=[]; c.obj.traverse(o=>{out.push([o.type,o.visible,o.geometry&&o.geometry.uuid,o.material&&o.material.uuid,o.position.toArray(),o.scale.toArray(),o.rotation.toArray()]);});return JSON.stringify(out);
}
// Warm every finite combination and bounded mesh slot, then repeated A→B→A.
const r=records[0],rig=r.obj.userData, refs=[rig.armL,rig.armR,rig.legL,rig.legR,rig.kneeL,rig.kneeR,rig.torso];
const all=Array.from({length:3000},(_,i)=>a.buildAppearanceProfile('pool:'+i));
all.forEach(p=>a.applyAppearanceToFigure(r,p));
const count=()=>{let n=0;r.obj.traverse(()=>n++);return n;};
const n=count(),m=a.citizenMatCache.size,g=a.citizenTorsoCache.size;
a.applyAppearanceToFigure(r,profiles[0]);const expected=snapshot(r);
for(let round=0;round<4;round++)all.forEach(p=>a.applyAppearanceToFigure(r,p));
a.applyAppearanceToFigure(r,profiles[0]);assert.strictEqual(snapshot(r),expected,'identity restored A→B→A');
assert.strictEqual(count(),n);assert.strictEqual(a.citizenMatCache.size,m);assert.strictEqual(a.citizenTorsoCache.size,g);
assert.deepStrictEqual([rig.armL,rig.armR,rig.legL,rig.legR,rig.kneeL,rig.kneeR,rig.torso],refs);
assert(rig.skinMeshes.every(o=>o.material===rig.headMesh.material || o===rig.armL.children[1].children[0] || o===rig.armR.children[1].children[0]));
const cached=new Set([...Object.values(a.CITIZEN_GEO),...a.citizenTorsoCache.values()]);
r.obj.traverse(o=>{if(o.isMesh)assert(cached.has(o.geometry),'all meshes use shared geometry');});
const recent=[];for(const p of all.slice(0,100)){const q=a.chooseAppearanceForSlot(p.key,recent);assert(!recent.some(r=>a.appearanceSig(r)===a.appearanceSig(q)));recent.push(q);if(recent.length>6)recent.shift();}
console.log(JSON.stringify({citizens:30,female:profiles.filter(p=>p.presentation==='female').length,bodies:[...new Set(profiles.map(p=>p.bodyId))],props:profiles.filter(p=>p.prop).length,walkSamples:720,poolReassignments:15002,stableNodes:n,stableMaterials:m,torsoGeometries:g,status:'PASS'},null,2));
