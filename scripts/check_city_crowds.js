// Production Three.js geometry and native-data fixtures; no browser/GPU measurement.
const fs = require('fs'), path = require('path'), vm = require('vm'), assert = require('assert/strict');
const base = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(base, file), 'utf8');
const THREE = require(path.join(base, 'vendor/three.min.js'));
const fixtures = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const builder = read('build_diorama.js'), source = read('city_v2_crowds.js');
function productionFunction(name) {
  const match = builder.match(new RegExp('    function ' + name + '\\([^]*?\\n    \\}'));
  assert(match, name); return match[0];
}
const scope = vm.createContext({ THREE, console, root: new THREE.Group(), mergeQueue: [],
  walkingCitizens: [], interactiveCitizens: [], venueActors: [], Y_WALK: 0.14,
  clamp: (x, lo, hi) => Math.max(lo, Math.min(hi, x)),
  buildingDistrictKeys: Object.fromEntries(fixtures.empty.map(v => [v.id, true])) });
for (const name of ['C', 'mat', 'mesh', 'roundedBox', 'mergeStaticScenery', 'packRigidModel', 'makeFigure', 'addCitizen', 'bindVenueActor', 'cafeTableSet']) {
  vm.runInContext(productionFunction(name), scope);
}
const materials = new Set((productionFunction('makeFigure') + productionFunction('cafeTableSet')).match(/\bM_[A-Z0-9_]+\b/g));
for (const name of materials) scope[name] = scope.mat(0xAABBCC, 0.8);
vm.runInContext(read('city_v2_life.js').split('function makeLifePlace(')[0], scope);
vm.runInContext(source + '\nthis.inspect = () => ({fronts:CROWD_FRONTAGES, limits:CROWD_LIMITS, snapshot:crowdSnapshot, walkers:crowdWalkers, batches:crowdBatches, states:venueStates});', scope);
function apply(raw) {
  scope.syncVenueStates(raw); scope.applyVenueCrowds(); return scope.inspect();
}
const entry = (state, id) => state.snapshot.find(e => e.id === id);
const population = (state, id) => { const e = entry(state, id); return e.walkers + e.waiting; };
let state = apply(fixtures.empty);
assert.equal(state.walkers.length, 0); assert.equal(state.batches.length, 0, 'Empty city allocates no crowd GPU buffers');
assert(state.snapshot.every(e => e.walkers === 0 && e.waiting === 0));
const once = population(apply(fixtures.once), 'food_coffee');
const daily = population(apply(fixtures.daily), 'food_coffee');
assert.equal(once, 1); assert.equal(daily, 12, 'Habitual cafe has six walkers and six waiting/chatting customers, before seats/satellites');
assert(daily >= once * 6);
assert(apply(fixtures.daily).snapshot.filter(e => e.id !== 'food_coffee').every(e => !e.walkers && !e.waiting));
const shopping = fixtures.daily.map(v => v.id === 'food_coffee' ? { ...v, id: 'shop_boutique' } : v).filter(v => v.id !== 'shop_boutique' || v.amount > 0);
state = apply(shopping);
assert.equal(population(state, 'food_coffee'), 0); assert.equal(population(state, 'shop_boutique'), 12);
assert(population(apply(fixtures.housing), 'house_tower') <= 1, 'Expensive rent never invents a shopping crowd');
assert(population(apply(fixtures.delivery), 'food_wolt') <= 6, 'Delivery uses a modest pickup crowd plus the existing couriers');
const partial = fixtures.daily.map(v => v.id === 'food_coffee' ? {...v, activity: 0.45} : v);
const medium = population(apply(partial), 'food_coffee');
assert(medium > once && medium < daily);
const moreMoney = fixtures.daily.map(v => ({...v, amount: v.amount * 20, share: v.amount > 0 ? 0.2 : 0}));
assert.equal(population(apply(moreMoney), 'food_coffee'), daily, 'Amount/share do not masquerade as visits');
const bad = fixtures.daily.map(v => ({...v, amount: NaN, activity: Infinity}));
assert(apply(bad).snapshot.every(e => e.walkers === 0 && e.waiting === 0));
console.log('PASS: zero/one/medium/daily, coffee vs shopping, rent/delivery, malformed input and money-independent footfall');

state = apply(fixtures.all);
for (const kind of ['walkers', 'waiting']) assert(state.snapshot.reduce((n, e) => n + e[kind], 0) <= state.limits[kind]);
assert.equal(state.snapshot.reduce((n, e) => n + e.walkers, 0), 24);
const identities = state.walkers.map(c => c.obj.uuid);
const batchIDs = state.batches.flat().map(b => b.uuid);
assert(batchIDs.length <= 64, 'Stationary crowd draw batches stay bounded, not one articulated rig per person');
state.walkers[0].t += 0.12;
const beforeT = state.walkers[0].t;
apply(fixtures.all);
assert.equal(state.walkers[0].t, beforeT, 'Identical update does not restart walking');
for (let i = 0; i < 40; i++) { apply(fixtures.daily); apply(shopping); apply(fixtures.empty); apply(fixtures.all); }
assert.deepEqual(Array.from(state.walkers, c => c.obj.uuid), Array.from(identities));
assert.deepEqual(Array.from(state.batches.flat(), b => b.uuid), Array.from(batchIDs));
assert.equal(scope.walkingCitizens.length, 24, 'No hidden monthly accumulation of animated rigs');
const canonical = JSON.stringify(apply(fixtures.all).snapshot);
assert.equal(JSON.stringify(apply([...fixtures.all].reverse()).snapshot), canonical);
state = apply(fixtures.empty);
assert(state.walkers.every(c => !c.obj.visible));
assert(state.batches.flat().every(b => b.count === 0 && !b.visible));
assert(!source.includes('requestAnimationFrame') && !source.includes('setInterval'), 'No independent crowd timers bypass energy scheduler');
console.log('PASS: 24-walker/48-waiting caps, stable reusable objects, deterministic allocation, no paused-scene timers');

// Check authored paths against all anchor footprints, roads and cafe furniture.
const buildings = Array.from(builder.matchAll(/makeBuilding\(\{([\s\S]*?)\n    \}\);/g), m => vm.runInNewContext('({' + m[1] + '})'));
assert(buildings.length >= 10);
function insideFootprint(p, cfg, margin = 0.12) {
  const dx = p.x - cfg.x, dz = p.z - cfg.z, angle = cfg.rotY || 0;
  const x = dx * Math.cos(angle) - dz * Math.sin(angle), z = dx * Math.sin(angle) + dz * Math.cos(angle);
  return Math.abs(x) < cfg.w / 2 + margin && Math.abs(z) < cfg.d / 2 + margin;
}
const tableBounds = [];
for (const id of ['food_coffee', 'food_bistro']) {
  const cfg = buildings.find(b => b.id === id);
  const character = builder.match(new RegExp('      ' + id + ': function \\(g, w, d\\) \\{([^]*?)\\n      \\},'))[1];
  const g = new THREE.Group(); g.position.set(cfg.x, 0.14, cfg.z); g.rotation.y = cfg.rotY;
  for (const match of character.matchAll(/cafeTableSet\(g, ([^,]+), ([^,]+),/g)) {
    const x = vm.runInNewContext(match[1], {w: cfg.w, d: cfg.d});
    const z = vm.runInNewContext(match[2], {w: cfg.w, d: cfg.d});
    const table = scope.cafeTableSet(g, x, z, {});
    g.updateMatrixWorld(true); tableBounds.push(new THREE.Box3().setFromObject(table));
  }
}
const lamps = [];
vm.runInNewContext(builder.match(/    \/\/ Along the four block frontages[^]*?\/\/ 🎪/)[0].split('// 🎪')[0], {addLamp: (x, z) => lamps.push({x, z})});
const plots = vm.runInNewContext(builder.match(/const LIFE_PLOTS = (\[[\s\S]*?\n    \]);/)[1]);
const plotFootprints = plots.map(p => ({id: p.id, x: p.x, z: p.z, w: 1.35 * p.scale, d: 1.05 * p.scale, rotY: p.rot}));
// All interchangeable historical decorations and earned companions must still fit
// beside the new footfall, even if their owner already filled every reward location.
scope.Y_GRASS = 0.09; scope.animObjects = []; scope.window = {matchMedia: () => ({matches:false})};
for (const name of new Set((read('city_v2_reward_models.js') + read('city_v2_companions.js')).match(/\bM_[A-Z0-9_]+\b/g))) {
  if (!scope[name]) scope[name] = scope.mat(0xAABBCC, 0.8);
}
scope.stripedAwningTex = () => new THREE.Texture();
vm.runInContext(read('city_v2_slots.js') + '\nthis.slotDefs = SLOT_DEFS; this.friendDefs = COMPANION_LOCATIONS;', scope);
vm.runInContext(read('city_v2_reward_models.js'), scope);
vm.runInContext(read('city_v2_companions.js') + '\nthis.friendBuilders = COMPANION_BUILDERS;', scope);
vm.runInContext(builder.match(/    const ENRICHMENT_PROPS = \{[^]*?\n    \};/)[0] + '\nthis.props = ENRICHMENT_PROPS;', scope);
const rewardBounds = [];
for (const slot of scope.slotDefs) {
  if (slot.x < 11) continue;
  for (const [id, make] of Object.entries(scope.props)) {
    if (!scope.slotAccepts(slot.id, id)) continue;
    const g = new THREE.Group(); make(g); g.position.set(slot.x, slot.y, slot.z); g.rotation.y = slot.rot || 0; g.scale.setScalar(slot.scale || 1);
    rewardBounds.push({label:slot.id + '/' + id, box:new THREE.Box3().setFromObject(g)});
  }
}
for (const def of scope.friendDefs) {
  const g = new THREE.Group(); scope.friendBuilders[def.id](g); g.position.set(def.x, def.y, def.z);
  rewardBounds.push({label:def.id, box:new THREE.Box3().setFromObject(g)});
}
function checkPoint(p, label) {
  assert(Number.isFinite(p.x) && Number.isFinite(p.z));
  assert(Math.max(Math.abs(p.x), Math.abs(p.z)) < 12.66, label + ' on island with room for feet');
  assert(Math.abs(Math.abs(p.x) - 5.6) > 1.3 && Math.abs(Math.abs(p.z) - 5.6) > 1.3, label + ' off roads');
  for (const cfg of buildings) assert(!insideFootprint(p, cfg), label + ' avoids ' + cfg.id);
  for (const cfg of plotFootprints) assert(!insideFootprint(p, cfg), label + ' avoids additional venue ' + cfg.id);
  for (const lamp of lamps) assert(Math.hypot(p.x - lamp.x, p.z - lamp.z) > 0.16, label + ' avoids lamp posts');
  for (const box of tableBounds) {
    assert(!(p.x > box.min.x - 0.11 && p.x < box.max.x + 0.11 && p.z > box.min.z - 0.11 && p.z < box.max.z + 0.11), label + ' avoids cafe tables/chairs');
  }
  for (const {label: reward, box} of rewardBounds) {
    assert(!(p.x > box.min.x - 0.12 && p.x < box.max.x + 0.12 && p.z > box.min.z - 0.12 && p.z < box.max.z + 0.12), label + ' avoids ' + reward);
  }
}
for (const [id, front] of Object.entries(state.fronts)) {
  const route = scope.crowdRoute(front);
  for (let i = 0; i < route.length; i++) {
    const a = route[i], b = route[(i + 1) % route.length];
    for (let t = 0; t <= 1; t += 0.05) checkPoint({x: a.x + (b.x - a.x) * t, z: a.z + (b.z - a.z) * t}, id + ' walker');
  }
  for (let i = 0; i < (front.maxWait || 6); i++) checkPoint(scope.waitingPose(front, i), id + ' waiting ' + i);
}
state = apply(fixtures.all);
for (const batch of state.batches.flat()) {
  assert(batch.isInstancedMesh && !batch.castShadow);
  assert(Array.from(batch.geometry.attributes.position.array).every(Number.isFinite));
  assert(Array.from(batch.instanceMatrix.array).every(Number.isFinite));
}
// Both seats are activity-bound and survive rigid-table batching independently.
const tableParent = new THREE.Group();
scope.cafeTableSet(tableParent, 0, 0, {occupied: true, venue: 'food_coffee', threshold: 0.18});
assert.equal(scope.venueActors.length, 2);
assert.deepEqual(Array.from(scope.venueActors, a => a.threshold), [0.18, 0.46]);
for (const actor of scope.venueActors) assert(actor.obj.parent && !actor.obj.visible && actor.obj.userData.lifeActor);
assert(builder.includes('${cityCrowdsJs}') && read('city_v2_life.js').includes('applyVenueCrowds();'));
assert(!builder.includes('// 6. Cafe Patio Customer'), 'No unconditional cafe/shop customers remain');
console.log('PASS: sampled routes/queues avoid roads, anchor footprints and cafe furniture; finite instanced geometry, two independently occupied seats');
console.log('Crowd comparison:', JSON.stringify({onePurchase: once, medium, daily, maxAnimated: state.limits.walkers, stationaryDrawBatches: batchIDs.length}));
