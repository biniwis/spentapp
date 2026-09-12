// Targeted event lifecycle checks using the production scheduler and Three.js objects.
const fs = require('fs'), vm = require('vm'), assert = require('assert/strict');
const THREE = require('../vendor/three.min.js');
const source = fs.readFileSync(require('path').join(__dirname, '../city_v2_encounters.js'), 'utf8');
function setup() {
  const scope = vm.createContext({ THREE, Math: Object.assign(Object.create(Math), { random: () => 0.3 }),
    Y_WALK: 0.14, window: { matchMedia: () => ({ matches: false }) }, energyMode: 'normal', currentMode: 'city',
    walkingCitizens: [], vehicleState: [], cityBuildings: { shop_boutique: { tier: 2, shell: { visible: true } } },
    ambientBench: new THREE.Group(), parkedTaxi: new THREE.Group(), transportYard: new THREE.Group(),
    roadClockwise: [{x:-4.35,z:-5.2},{x:4.35,z:-5.2},{x:4.95,z:-4.95},{x:5.2,z:-4.35},{x:5.2,z:4.35},{x:4.95,z:4.95},{x:4.35,z:5.2},{x:-4.35,z:5.2},{x:-4.95,z:4.95},{x:-5.2,z:4.35},{x:-5.2,z:-4.35},{x:-4.95,z:-4.95}] });
  scope.parkedTaxi.userData.passengerDoor = new THREE.Group(); scope.parkedTaxi.position.set(1.6,0,-1.7); scope.transportYard.position.set(9.2,0.14,9.2);
  vm.runInContext(source + '\nthis.system = CityAmbientEventSystem; this.events = cityEncounters; this.motion = ambientMotion;', scope);
  return scope;
}
function person(scope, x, z) {
  const c = { obj: new THREE.Group(), baseY: .14, pIdx: 0, t: 0, speed: .3,
    path: [{x,z},{x:x+3,z}] };
  c.obj.position.set(x,.14,z);
  for (const key of ['legL','legR','kneeL','kneeR','armL','armR']) c[key] = new THREE.Group();
  scope.walkingCitizens.push(c); return c;
}
for (const kind of ['building','bench','taxi']) {
  const s=setup(), c=person(s, kind==='bench'?2:kind==='taxi'?9:-7.2, kind==='bench'?1:kind==='taxi'?6.95:-3.3);
  const origin=c.obj.position.clone(), car=s.parkedTaxi.position.clone();
  const e=s.startEncounter(kind,[c],s.system.anchors[kind==='building'?'boutique':kind]);
  s.system.nextAttempt=Infinity;
  const states=new Set(); let maxCarDistance=0;
  for(let frame=0;frame<6000 && s.events.length;frame++) {
    s.stepCityEncounters(1/30); states.add(c.ambientState);
    maxCarDistance=Math.max(maxCarDistance,s.parkedTaxi.position.distanceTo(car));
    assert(Number.isFinite(c.obj.position.x));
  }
  assert.equal(s.events.length,0,kind+' releases'); assert.equal(c.encounter,null);
  assert(c.obj.position.distanceTo(origin)<1e-7); assert.equal(c.obj.scale.x,1); assert(!c.ambientHidden);
  if(kind==='taxi') { assert(maxCarDistance>15,'Taxi makes a real circuit'); assert(states.has('insideCar')); assert(s.parkedTaxi.position.distanceTo(car)<1e-7); }
  if(kind==='building') { assert(states.has('insideBuilding')); assert(states.has('exitingBuilding')); }
  if(kind==='bench') assert(states.has('sitting'));
}
{
  const s=setup(),a=person(s,0,0),b=person(s,.6,0); b.path=a.path; b.t=.6;
  const e=s.startEncounter('together',[a,b]); e.speed=.2;e.duration=4.2;s.system.nextAttempt=Infinity;
  for(let i=0;i<140;i++)s.stepCityEncounters(1/30);
  assert(a.t>.3 && b.t>.9); assert.equal(s.events.length,0); assert(Math.abs(b.obj.position.x-a.obj.position.x-.6)<1e-7);
}
{
  const s=setup(),c=person(s,9,6.95); const e=s.startEncounter('taxi',[c],s.system.anchors.taxi);
  s.ambientHidden(e,true); s.motion.matches=true; s.stepCityEncounters(.1);
  assert.equal(s.events.length,0);assert.equal(c.obj.scale.x,1);assert(!c.obj.userData.ambientHidden);
  assert.equal(s.parkedTaxi.userData.passengerDoor.rotation.y,0);
}
{
  const s=setup();const c=person(s,9,6.95);c.crowdVenue='trans_station';s.system.clock=1000;s.system.nextHero=0;
  s.chooseAmbientEvent();assert.equal(s.events.length,0,'Sparse city does not create a hero event');
  c.obj.visible=false;s.chooseAmbientEvent();assert.equal(s.events.length,0);
}
const html=fs.readFileSync(require('path').join(__dirname,'../MoneyCity/Resources/diorama.html'),'utf8');
for(const match of html.matchAll(/<script>([\s\S]*?)<\/script>/g))new Function(match[1]);
console.log('PASS: entry/exit, seating, shared walk continuity, taxi circuit, actor release, reduced motion, sparse city, generated syntax.');
