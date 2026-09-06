// Mathematical scene tests only: no browser, GPU, screenshots or user data.
const fs = require('fs'), path = require('path'), vm = require('vm'), assert = require('assert/strict');
const base = path.join(__dirname, '..');
const THREE = require(path.join(base, 'vendor/three.min.js'));
const read = file => fs.readFileSync(path.join(base, file), 'utf8');
const builder = read('build_diorama.js'), models = read('city_v2_reward_models.js');
function productionFunction(name) {
  const match = builder.match(new RegExp('    function ' + name + '\\([^]*?\\n    \\}'));
  assert(match, 'Production function exists: ' + name); return match[0];
}
const scope = vm.createContext({ THREE, console, Y_GRASS: 0.09, Y_WALK: 0.14,
  animObjects: [], slotGrowth: [], slotItems: {}, root: new THREE.Group(), mergeQueue: [],
  // Only canvas texture creation is mocked; production geometry and batching run intact.
  stripedAwningTex: () => new THREE.Texture() });
vm.runInContext(read('city_v2_slots.js') + '\nthis.defs = SLOT_DEFS; this.aliases = SLOT_ALIASES;', scope);
const defs = scope.defs, normalize = scope.normalizedSlotPlacements;
const swift = read('MoneyCity/Models/CitySlot.swift');
assert.deepEqual(Array.from(defs, d => d.id).sort(), [...swift.matchAll(/CitySlot\(id: "([^"]+)"/g)].map(m => m[1]).sort());
for (const [alias, id] of Object.entries(scope.aliases)) assert(swift.includes('"' + alias + '": "' + id + '"'));
assert.equal(defs.length, 13);
const all = Object.fromEntries(Array.from(defs, d => [d.id, d.id.slice(5)]));
assert.equal(Object.keys(normalize(all)).length, 13);
assert.equal(Object.keys(normalize({ slot_park_center: 'tree_sakura', slot_tree_sakura: 'repair_bench' })).length, 2);
assert.equal(normalize({ slot_food_plaza: 'park_bridge' }).slot_park_bridge, 'park_bridge');
assert.equal(Object.keys(normalize({ nope: 'unknown' })).length, 0);
assert.equal(Object.keys(normalize({ slot_cafe_stand: 'tree_sakura', slot_tree_sakura: 'tree_sakura' })).length, 1);
for (const d of defs) {
  assert(Math.abs(d.x) < 13 && Math.abs(d.z) < 13, d.id + ' stays on island');
  assert(Math.abs(Math.abs(d.x) - 5.6) > 1.2 && Math.abs(Math.abs(d.z) - 5.6) > 1.2, d.id + ' is not on a road');
}
console.log('PASS: Swift/Three.js IDs, legacy aliases, collisions, deduplication and stable locations');
for (const name of ['C', 'mat', 'mesh', 'roundedBox', 'mergeStaticScenery', 'packRigidModel', 'makeFigure', 'disposeChildren', 'setSlotItem']) {
  vm.runInContext(productionFunction(name), scope);
}
// Shared material identities matter for disposal; appearance is not asserted in this test.
const materialNames = new Set((models + productionFunction('makeFigure')).match(/\bM_[A-Z0-9_]+\b/g));
for (const name of materialNames) scope[name] = scope.mat(0xAABBCC, 0.8);
vm.runInContext(models, scope);
vm.runInContext(builder.match(/    const ENRICHMENT_PROPS = \{[^]*?\n    \};/)[0] + '\nthis.props = ENRICHMENT_PROPS;', scope);
let totalMeshes = 0;
for (const d of defs) {
  const g = new THREE.Group(); scope.props[d.id.slice(5)](g);
  let count = 0;
  g.traverse(o => {
    if (!o.isMesh) return;
    count++;
    assert(Array.from(o.geometry.attributes.position.array).every(Number.isFinite), d.id + ' finite vertices');
  });
  const box = new THREE.Box3().setFromObject(g), size = box.getSize(new THREE.Vector3());
  assert(size.x > 0 && size.z > 0 && size.y > 0, d.id + ' nonempty model');
  assert(size.x < 1.4 && size.z < 1.5 && size.y < 1.8, d.id + ' fits authored local footprint');
  // Check every interchangeable prop against every compatible slot, not just its default.
  for (const target of defs.filter(t => scope.slotAccepts(t.id, d.id.slice(5)))) {
    g.position.set(target.x, target.y, target.z); g.rotation.y = target.rot || 0; g.scale.setScalar(target.scale || 1);
    const bounds = new THREE.Box3().setFromObject(g);
    assert(bounds.min.x > -13.1 && bounds.max.x < 13.1 && bounds.min.z > -13.1 && bounds.max.z < 13.1, d.id + ' stays on island at ' + target.id);
  }
  totalMeshes += count;
  scope.disposeChildren(g);
  assert.equal(scope.animObjects.length, 0, d.id + ' animation cleaned up');
}
console.log('PASS: all 13 production models, finite geometry, compatible placement bounds, joint-safe batching (' + totalMeshes + ' meshes total)');
const slot = { itemId: null, pad: new THREE.Mesh(), hit: new THREE.Mesh(new THREE.BoxGeometry(1.3, 1.65, 1.3)), marker: new THREE.Mesh(), holder: new THREE.Group(), scale: 1 };
scope.slotItems.test = slot;
let sharedDisposed = 0;
for (const name of materialNames) scope[name].addEventListener('dispose', () => sharedDisposed++);
for (let cycle = 0; cycle < 12; cycle++) {
  for (const d of defs) {
    scope.setSlotItem('test', d.id.slice(5));
    assert.equal(scope.slotGrowth.length, 1, 'Growth queue bounded while replacing');
    assert(!slot.hit.visible, 'Rewards never become map click targets');
    assert(scope.animObjects.length <= 1, 'Old animated prop is detached');
  }
  scope.setSlotItem('test', null);
  assert.equal(scope.slotGrowth.length, 0);
  assert.equal(scope.animObjects.length, 0);
  assert.equal(slot.holder.children.length, 0);
  assert(!slot.hit.visible && !slot.pad.visible, 'Empty location neither renders nor intercepts');
}
assert.equal(sharedDisposed, 0, 'Removing rewards never disposes city-wide materials');
const ray = new THREE.Raycaster(new THREE.Vector3(0, 3, 0), new THREE.Vector3(0, -1, 0));
assert.equal(ray.intersectObjects([slot.hit].filter(o => o.visible)).length, 0);
scope.setSlotItem('test', 'cafe_stand');
assert.equal(ray.intersectObjects([slot.hit].filter(o => o.visible)).length, 0);
const owned = new Set(); slot.holder.traverse(o => { if (o.material?.userData.rewardOwned) owned.add(o.material); });
let materialDisposals = 0, textureDisposals = 0;
for (const m of owned) { m.addEventListener('dispose', () => materialDisposals++); m.map?.addEventListener('dispose', () => textureDisposals++); }
scope.setSlotItem('test', null);
assert.equal(materialDisposals, owned.size); assert.equal(textureDisposals, 1);
assert(!builder.includes('post("slotTapped"'));
assert(builder.includes('fountainGroup.visible = map.slot_fountain_marble !== "fountain_marble"'));
assert(builder.includes('bridge.visible = map.slot_park_bridge !== "park_bridge"'));
console.log('PASS: 156 replacements, animation/growth cleanup, owned texture disposal, shared material safety and ray picking');

// Production companion scene, no renderer. DOM stubs only exercise welcome lifecycle.
scope.window = { matchMedia: () => ({ matches: false }) };
scope.currentLang = 'en'; scope.spinVel = 0; scope.tiltVel = 0; scope.pointers = new Set();
scope.targetCam = { lookX: 0, lookY: 0, lookZ: 0, zoom: 1 };
scope.document = { createElement: () => ({ setAttribute() {}, style: {}, remove() {} }), getElementById: () => ({ appendChild() {} }) };
vm.runInContext(read('city_v2_companions.js') + '\nthis.companions = companionInstances; this.locations = COMPANION_LOCATIONS;', scope);
const ids = Array.from(scope.locations, d => d.id);
assert.equal(ids.length, 6);
scope.applyCompanions([]); assert.equal(scope.companions.size, 0, 'No free companions at launch');
scope.applyCompanions(ids.concat(ids)); assert.equal(scope.companions.size, 6, 'Earned IDs deduplicate');
const groups = Array.from(scope.companions.values(), e => e.group.uuid);
for (let i = 0; i < 50; i++) { scope.applyCompanions(ids); scope.animateCompanions(i * 100, 0.1); }
assert.deepEqual(Array.from(scope.companions.values(), e => e.group.uuid), groups, 'Updates never recreate friends');
for (const [id, entry] of scope.companions) {
  const box = new THREE.Box3().setFromObject(entry.group);
  assert(box.min.x > -13 && box.max.x < 13 && box.min.z > -13 && box.max.z < 13, id + ' on island');
  assert(box.max.y - box.min.y < 2.1, id + ' character proportions');
  entry.group.traverse(o => {
    assert(!o.userData.slotId && !o.userData.amount, 'No reward pick or spending metadata');
    if (o.isMesh) assert(Array.from(o.geometry.attributes.position.array).every(Number.isFinite));
  });
}
scope.slotItems.slot_pet_cat_rooftop = { itemId: 'tree_sakura' };
scope.applyCompanions(ids);
assert.equal(scope.companions.get('pet_cat_rooftop').z, 3.85, 'Legacy decoration preserved, companion uses alternative');
scope.applyCompanions([]); assert(Array.from(scope.companions.values()).every(e => !e.group.visible));
scope.applyCompanions(ids); assert(Array.from(scope.companions.values()).every(e => e.group.visible));
assert(scope.welcomeCompanion('pet_golden_dog'));
assert.equal(scope.targetCam.zoom, 3.4);
scope.animateCompanions(6000, 6); assert.equal(scope.targetCam.zoom, 1, 'Welcome returns camera');
scope.welcomeCompanion('resident_artist'); scope.targetCam.zoom = 2;
scope.animateCompanions(12000, 6); assert.equal(scope.targetCam.zoom, 2, 'User camera input wins');
const main = read('MoneyCity/Views/MainCityView.swift');
assert(!main.includes('showSlotCustomizer') && !main.includes('handleAssignSlot'));
assert(main.includes('onSlotTapped: nil'));
const catalog = read('MoneyCity/Services/CityProgressEngine.swift').split('public let legacyCatalogOptions')[0];
assert.deepEqual([...catalog.matchAll(/ProgressRewardOption\(id: "([^"]+)"/g)].map(m => m[1]).sort(), ids.sort());
console.log('PASS: six earned companions, no free spawns, no interactive rewards, stable caching, old decoration coexistence and welcome camera lifecycle');
