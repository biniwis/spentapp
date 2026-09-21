// City Life System Parity Verification across all 5 worlds:
// Urban (reference), Israel, Arctic, Future, Medieval.
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert/strict');

const base = path.join(__dirname, '..');
const THREE = require(path.join(base, 'vendor/three.min.js'));
const fixturePath = process.argv[2] || '/tmp/city_fixtures.json';
if (!fs.existsSync(fixturePath)) {
  console.error('Fixture file not found: ' + fixturePath);
  process.exit(1);
}
const fixtures = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));

const dHtml = fs.readFileSync(path.join(base, 'MoneyCity/Resources/diorama.html'), 'utf8');
const mHtml = fs.readFileSync(path.join(base, 'MoneyCity/Resources/diorama_medieval.html'), 'utf8');

// 1. Syntax check
for (const match of dHtml.matchAll(/<script>([\s\S]*?)<\/script>/g)) new Function(match[1]);
for (const match of mHtml.matchAll(/<script>([\s\S]*?)<\/script>/g)) new Function(match[1]);
console.log('PASS: Both diorama.html and diorama_medieval.html scripts parse cleanly.');

// Helper to extract a balanced function or object block
function extractFunctionBlock(source, signature) {
  const idx = source.indexOf(signature);
  if (idx === -1) return null;
  const braceStart = source.indexOf('{', idx);
  if (braceStart === -1) return null;
  let depth = 1;
  let i = braceStart + 1;
  while (i < source.length && depth > 0) {
    if (source[i] === '{') depth++;
    else if (source[i] === '}') depth--;
    i++;
  }
  return source.slice(idx, i);
}

// 2. Test Crowd Allocations across Urban and Medieval
function extractCrowdEngine(source) {
  const scope = vm.createContext({
    clamp: (x, lo, hi) => Math.max(lo, Math.min(hi, x)),
    CROWD_LIMITS: { walkers: 24, waiting: 48 }
  });

  const frontagesMatch = source.match(/const CROWD_FRONTAGES = \{[\s\S]*?\n\};/);
  const finiteUnitMatch = source.match(/function finiteUnit\([^)]*\)\s*\{[\s\S]*?\n\}/);
  const demandMatch = source.match(/function crowdDemand\([^)]*\)\s*\{[\s\S]*?\n\}/);
  const allocateMatch = source.match(/function allocateCrowds\([^)]*\)\s*\{[\s\S]*?\n\}/);
  const pointMatch = source.match(/function frontagePoint\([^)]*\)\s*\{[\s\S]*?\n\}/);
  const routeMatch = source.match(/function crowdRoute\([^)]*\)\s*\{[\s\S]*?\n\}/);
  const poseMatch = extractFunctionBlock(source, 'function waitingPose');

  assert(frontagesMatch, 'CROWD_FRONTAGES not found');
  assert(finiteUnitMatch, 'finiteUnit not found');
  assert(demandMatch, 'crowdDemand not found');
  assert(allocateMatch, 'allocateCrowds not found');
  assert(pointMatch, 'frontagePoint not found');
  assert(routeMatch, 'crowdRoute not found');
  assert(poseMatch, 'waitingPose not found');

  vm.runInContext(finiteUnitMatch[0], scope);
  vm.runInContext(frontagesMatch[0] + '\nthis.CROWD_FRONTAGES = CROWD_FRONTAGES;', scope);
  vm.runInContext(demandMatch[0] + '\nthis.crowdDemand = crowdDemand;', scope);
  vm.runInContext(allocateMatch[0] + '\nthis.allocateCrowds = allocateCrowds;', scope);
  vm.runInContext(pointMatch[0] + '\nthis.frontagePoint = frontagePoint;', scope);
  vm.runInContext(routeMatch[0] + '\nthis.crowdRoute = crowdRoute;', scope);
  vm.runInContext(poseMatch + '\nthis.waitingPose = waitingPose;', scope);

  return scope;
}

const urbanCrowd = extractCrowdEngine(dHtml);
const medievalCrowd = extractCrowdEngine(mHtml);

// Verify allocation parity across all fixture scenarios
const scenarios = Object.keys(fixtures);
for (const scenario of scenarios) {
  const rawList = fixtures[scenario];
  const states = {};
  for (const s of rawList) {
    states[s.id] = {
      id: s.id,
      amount: Math.max(0, s.amount || 0),
      share: Math.max(0, Math.min(1, s.share || 0)),
      purchaseCount: Math.max(0, Math.floor(s.purchaseCount || 0)),
      activity: s.amount > 0 ? Math.max(0, Math.min(1, s.activity || 0)) : 0
    };
  }

  const urbanAlloc = urbanCrowd.allocateCrowds(states);
  const medievalAlloc = medievalCrowd.allocateCrowds(states);

  assert.equal(urbanAlloc.length, medievalAlloc.length, `Alloc length mismatch for ${scenario}`);

  for (let i = 0; i < urbanAlloc.length; i++) {
    const u = urbanAlloc[i];
    const m = medievalAlloc.find(e => e.id === u.id);
    assert(m, `Medieval missing venue ${u.id} in ${scenario}`);
    assert.equal(m.walkers, u.walkers, `Walker count mismatch for ${u.id} in ${scenario}: Medieval=${m.walkers}, Urban=${u.walkers}`);
    assert.equal(m.waiting, u.waiting, `Waiting count mismatch for ${u.id} in ${scenario}: Medieval=${m.waiting}, Urban=${u.waiting}`);
  }

  const totalWalkers = urbanAlloc.reduce((sum, e) => sum + e.walkers, 0);
  const totalWaiting = urbanAlloc.reduce((sum, e) => sum + e.waiting, 0);
  assert(totalWalkers <= 24, `Walkers exceed 24 cap: ${totalWalkers}`);
  assert(totalWaiting <= 48, `Waiting exceed 48 cap: ${totalWaiting}`);

  if (scenario === 'empty') {
    assert.equal(totalWalkers, 0, 'Empty scenario must have 0 walkers');
    assert.equal(totalWaiting, 0, 'Empty scenario must have 0 waiting');
  }
}
console.log('PASS: Crowd allocation parity across Urban and Medieval for all scenarios (empty, once, daily, all, etc.). Caps respected.');

// 3. Spatial boundary validation
for (const [worldName, engine] of [['Urban/Israel/Arctic/Future', urbanCrowd], ['Medieval', medievalCrowd]]) {
  const frontages = engine.CROWD_FRONTAGES;
  for (const [venueId, front] of Object.entries(frontages)) {
    const route = engine.crowdRoute(front);
    assert.equal(route.length, 4, `Route must have 4 points for ${venueId} in ${worldName}`);
    for (const pt of route) {
      assert(Number.isFinite(pt.x) && Number.isFinite(pt.z), `Non-finite route point in ${venueId} of ${worldName}`);
      assert(Math.abs(pt.x) <= 13.0 && Math.abs(pt.z) <= 13.0, `Route point out of bounds: (${pt.x}, ${pt.z}) in ${venueId} of ${worldName}`);
    }

    const maxW = front.maxWait || 6;
    for (let i = 0; i < maxW; i++) {
      const pose = engine.waitingPose(front, i);
      assert(Number.isFinite(pose.x) && Number.isFinite(pose.z) && Number.isFinite(pose.yaw), `Non-finite pose in ${venueId} of ${worldName}`);
      assert(Math.abs(pose.x) <= 13.0 && Math.abs(pose.z) <= 13.0, `Pose point out of bounds: (${pose.x}, ${pose.z}) in ${venueId} of ${worldName}`);
    }
  }
}
console.log('PASS: Spatial containment validated for all frontages, routes, and waiting poses across all worlds.');

// 4. Test Contextual Venue Actor thresholds and life response in each world
function buildWorldActors(world) {
  const isMedieval = world === 'medieval';
  const source = isMedieval ? mHtml : dHtml;

  const scope = vm.createContext({
    THREE,
    console,
    root: new THREE.Group(),
    venueActors: [],
    animObjects: [],
    Y_WALK: 0.14,
    FLOOR_H: 0.85,
    clamp: (x, lo, hi) => Math.max(lo, Math.min(hi, x)),
    ISRAEL: world === 'israel',
    ARCTIC: world === 'arctic',
    FUTURE: world === 'future',
    mat: (col, rough, metal) => new THREE.MeshBasicMaterial({ color: col }),
    mesh: (geo, mat, x, y, z) => {
      const m = new THREE.Mesh(geo, mat);
      m.position.set(x || 0, y || 0, z || 0);
      return m;
    },
    roundedBox: (w, h, d, r) => new THREE.BoxGeometry(w, h, d),
    cylinder: (rt, rb, h, s) => new THREE.CylinderGeometry(rt, rb, h, s),
    packRigidModel: (g) => g,
    signTex: () => new THREE.Texture(),
    glassMaterial: (c) => new THREE.MeshBasicMaterial({ color: c }),
    registerGlass: () => {},
    stripedAwningTex: () => new THREE.Texture(),
    mdSwallowtailPennant: () => {},
    mdCrateStack: () => {}
  });

  for (const name of ['M_WOOD', 'M_DARKFRAME', 'M_CREAM', 'M_WHITE', 'M_CANVAS', 'M_MULLION', 'M_STREET_LEAF', 'M_WARM_STONE', 'M_GOLD',
                      'MD_TIMBER', 'MD_TIMBER_LT', 'MD_STONE_TAN', 'MD_LINEN_RD', 'MD_LINEN_CR', 'MD_STONE_DK', 'MD_PLASTER_BL']) {
    scope[name] = new THREE.MeshBasicMaterial({ color: 0x888888 });
  }

  // Load from hashCitizenKey to makeFigure (contains all palettes and helpers)
  const citizenPrefix = source.slice(source.indexOf('function hashCitizenKey'), source.indexOf('function makeFigure'));
  vm.runInContext(citizenPrefix, scope);

  const commonFns = [
    'function dressArcticFigure',
    'function applySeatedPoseVariant', 'function registerCharacterIdle', 'function makeFigure',
    'function bindVenueActor', 'function finiteUnit', 'function syncVenueStates',
    'function cafeTableSet', 'function diningTable', 'function foodEmblem', 'function crateStack', 'function groceryCart', 'function aFrameBoard'
  ];

  for (const fn of commonFns) {
    const block = extractFunctionBlock(source, fn);
    if (block) {
      try { vm.runInContext(block, scope); } catch (e) { console.warn('Failed to run', fn, e.message); }
    }
  }

  const charBlock = extractFunctionBlock(source, 'const CHARACTER = {');
  if (charBlock) vm.runInContext(charBlock, scope);

  if (!isMedieval) {
    for (const fn of ['function attachIsraelContextualLife', 'function attachArcticContextualLife', 'function attachFutureContextualLife', 'function attachBuildingContextualLife']) {
      const block = extractFunctionBlock(source, fn);
      if (block) vm.runInContext(block, scope);
    }
  } else {
    const block = extractFunctionBlock(source, 'function attachMedievalContextualLife');
    if (block) vm.runInContext(block, scope);
  }

  vm.runInContext('const venueStates = Object.create(null);', scope);
  scope.buildingDistrictKeys = {
    food_coffee: 'food', food_bistro: 'food', food_super: 'food', food_wolt: 'food',
    shop_boutique: 'shopping', shop_tech: 'shopping', shop_travel: 'shopping', shop_arcade: 'shopping',
    house_tower: 'housing', health_pharmacy: 'civic', museum_curiosities: 'civic'
  };

  const venues = [
    { id: 'food_coffee', w: 1.70, d: 2.10 },
    { id: 'food_bistro', w: 1.80, d: 2.40 },
    { id: 'shop_boutique', w: 1.80, d: 2.40 },
    { id: 'food_super', w: 2.25, d: 2.10 }
  ];

  for (const v of venues) {
    const g = new THREE.Group();
    scope.root.add(g);
    if (isMedieval) {
      scope.attachMedievalContextualLife(g, v, v.w, v.d);
    } else {
      scope.attachBuildingContextualLife(g, v, v.w, v.d);
    }
  }

  return scope;
}

const worlds = ['urban', 'israel', 'arctic', 'future', 'medieval'];
const worldEnvs = {};

for (const w of worlds) {
  worldEnvs[w] = buildWorldActors(w);
  const actors = worldEnvs[w].venueActors;

  // Assert counts per venue
  const coffeeGuests = actors.filter(a => a.venue === 'food_coffee');
  const bistroGuests = actors.filter(a => a.venue === 'food_bistro');
  const boutiqueShoppers = actors.filter(a => a.venue === 'shop_boutique');

  assert.equal(coffeeGuests.length, 2, `${w}: food_coffee must have exactly 2 seated guests, found ${coffeeGuests.length}`);
  assert.equal(bistroGuests.length, 4, `${w}: food_bistro must have exactly 4 seated guests, found ${bistroGuests.length}`);
  assert.equal(boutiqueShoppers.length, 1, `${w}: shop_boutique must have exactly 1 shopper, found ${boutiqueShoppers.length}`);
  assert.equal(actors.length, 7, `${w}: total venue actors must be exactly 7, found ${actors.length}`);

  // Assert thresholds
  const coffeeThresholds = coffeeGuests.map(a => Math.round(a.threshold * 100) / 100).sort((a,b) => a-b);
  assert.deepEqual(coffeeThresholds, [0.18, 0.46], `${w}: food_coffee thresholds mismatch: ${JSON.stringify(coffeeThresholds)}`);

  const bistroThresholds = bistroGuests.map(a => Math.round(a.threshold * 100) / 100).sort((a,b) => a-b);
  assert.deepEqual(bistroThresholds, [0.18, 0.45, 0.46, 0.73], `${w}: food_bistro thresholds mismatch: ${JSON.stringify(bistroThresholds)}`);

  assert.equal(Math.round(boutiqueShoppers[0].threshold * 100) / 100, 0.15, `${w}: boutique threshold mismatch`);
}
console.log('PASS: Exact contextual actor counts (7 per world) and demand thresholds verified across all 5 worlds (Urban, Israel, Arctic, Future, Medieval).');

// 5. Activity sweep: test silence at 0 and identical visibility across all 5 worlds
const testActivities = [0.0, 0.10, 0.16, 0.19, 0.21, 0.45, 0.50, 0.75, 1.0];

for (const act of testActivities) {
  const countsPerWorld = {};

  for (const w of worlds) {
    const env = worldEnvs[w];
    const rawVenues = [
      { id: 'food_coffee', amount: act > 0 ? 50 : 0, purchaseCount: act > 0 ? 5 : 0, activity: act },
      { id: 'food_bistro', amount: act > 0 ? 120 : 0, purchaseCount: act > 0 ? 3 : 0, activity: act },
      { id: 'shop_boutique', amount: act > 0 ? 200 : 0, purchaseCount: act > 0 ? 2 : 0, activity: act },
      { id: 'food_super', amount: act > 0 ? 300 : 0, purchaseCount: act > 0 ? 10 : 0, activity: act }
    ];

    env.syncVenueStates(rawVenues);

    const visibleActors = env.venueActors.filter(a => a.obj.visible);
    countsPerWorld[w] = {
      total: visibleActors.length,
      coffee: visibleActors.filter(a => a.venue === 'food_coffee').length,
      bistro: visibleActors.filter(a => a.venue === 'food_bistro').length,
      boutique: visibleActors.filter(a => a.venue === 'shop_boutique').length
    };
  }

  // All 5 worlds must match Urban EXACTLY at this activity level
  const ref = countsPerWorld['urban'];
  for (const w of worlds) {
    assert.deepEqual(countsPerWorld[w], ref, `Activity response mismatch at activity=${act} for world ${w}: ${JSON.stringify(countsPerWorld[w])} vs Urban ${JSON.stringify(ref)}`);
  }

  if (act === 0.0) {
    assert.equal(ref.total, 0, 'Zero activity must silence ALL venue actors');
  }
}
console.log('PASS: Complete life activity response and zero-activity silence verified identically across all 5 worlds.');
console.log('ALL 12 ACCEPTANCE CRITERIA PASSED.');
