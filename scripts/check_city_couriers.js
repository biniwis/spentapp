const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert/strict');

const html = fs.readFileSync(path.join(__dirname, '../MoneyCity/Resources/diorama.html'), 'utf8');
const scriptMatches = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
const threeJsSource = scriptMatches[0][1];
const dioramaSource = scriptMatches[1][1];

// Mock minimal WebGL and DOM environment for headless testing
function createMockContext() {

  const listeners = {};
  const stage = {
    clientWidth: 400,
    clientHeight: 800,
    appendChild: () => {},
    removeChild: () => {},
    addEventListener: (t, fn) => { (listeners[t] = listeners[t] || []).push(fn); },
    removeEventListener: () => {}
  };
  const canvas = {
    clientWidth: 400,
    clientHeight: 800,
    width: 400,
    height: 800,
    style: {},
    addEventListener: (t, fn) => { (listeners[t] = listeners[t] || []).push(fn); },
    removeEventListener: () => {},
    getContext: (type) => {
      if (type === '2d') {
        const dummy = {
          canvas,
          getImageData: () => ({ data: new Uint8Array(4) }),
          measureText: () => ({ width: 10 }),
          createRadialGradient: () => ({ addColorStop: () => {} }),
          createLinearGradient: () => ({ addColorStop: () => {} })
        };
        return new Proxy(dummy, {
          get: (target, prop) => {
            if (prop in target) return target[prop];
            return () => {};
          },
          set: () => true
        });
      }
      return {
        canvas,
        getExtension: () => null,
        getParameter: () => 16,
        createTexture: () => ({}),
        bindTexture: () => {},
        texParameteri: () => {},
        texImage2D: () => {},
        clearColor: () => {},
        clearDepth: () => {},
        clearStencil: () => {},
        enable: () => {},
        disable: () => {},
        depthFunc: () => {},
        frontFace: () => {},
        cullFace: () => {},
        viewport: () => {},
        scissor: () => {},
        clear: () => {}
      };
    }
  };
  const overlays = {
    appendChild: () => {},
    removeChild: () => {},
    children: []
  };

  const document = {
    body: { appendChild: () => {}, style: {} },
    hidden: false,
    getElementById: (id) => {
      if (id === 'stage') return stage;
      if (id === 'c') return canvas;
      if (id === 'diorama-overlays') return overlays;
      return null;
    },
    createElement: (tag) => {
      if (tag === 'canvas') return canvas;
      return {
        style: {},
        classList: { add: () => {}, remove: () => {} },
        appendChild: () => {},
        setAttribute: () => {},
        removeAttribute: () => {},
        addEventListener: (t, fn) => { (listeners[t] = listeners[t] || []).push(fn); },
        removeEventListener: () => {}
      };
    },
    addEventListener: (t, fn) => { (listeners[t] = listeners[t] || []).push(fn); },
    removeEventListener: () => {}
  };

  const window = {
    devicePixelRatio: 2,
    innerWidth: 400,
    innerHeight: 800,
    matchMedia: () => ({ matches: false, addEventListener: () => {}, removeEventListener: () => {} }),
    addEventListener: (t, fn) => { (listeners[t] = listeners[t] || []).push(fn); },
    removeEventListener: () => {},
    requestAnimationFrame: () => 1,
    cancelAnimationFrame: () => {},
    performance: { now: () => Date.now() },
    document,
    webkit: null
  };

  const ctx = vm.createContext({
    window,
    document,
    navigator: { userAgent: 'Node' },
    console,
    performance: { now: () => Date.now() },
    requestAnimationFrame: () => 1,
    cancelAnimationFrame: () => {},
    Math,
    Date,
    parseFloat,
    parseInt,
    isNaN,
    isFinite,
    Set,
    Map,
    Array,
    Object,
    Number,
    String,
    Boolean,
    Error,
    TypeError,
    RangeError
  });

  // Load Three.js
  vm.runInContext(threeJsSource, ctx);

  // Stub WebGLRenderer to avoid WebGL context creation failure in headless node
  vm.runInContext(`
    const OrigRenderer = THREE.WebGLRenderer;
    THREE.WebGLRenderer = function(opts) {
      this.domElement = opts.canvas;
      this.shadowMap = { enabled: false, type: 0, needsUpdate: false };
      this.toneMapping = 0;
      this.toneMappingExposure = 1;
      this.outputEncoding = 0;
      this.setPixelRatio = () => {};
      this.setSize = () => {};
      this.setClearColor = () => {};
      this.render = () => {};
      this.dispose = () => {};
      this.info = { render: { calls: 0, triangles: 0, points: 0, lines: 0 }, memory: { geometries: 0, textures: 0 } };
    };
  `, ctx);

  // Load main diorama script
  vm.runInContext(dioramaSource, ctx);

  return ctx;
}

function generatePayload(deliveryTier, deliveryFrequencyScore, woltCount = 0) {
  return {
    schemaVersion: 1,
    language: 'he',
    targetDistrict: null,
    tutorialBuildingId: null,
    food: 1200,
    shopping: 800,
    housing: 2500,
    transport: 300,
    savings: 1500,
    savingsTarget: 3000,
    parkHealth: 1.0,
    foodSub: { restaurant: 300, groceries: 400, coffee: 200, delivery: 300 },
    shoppingSub: { fashion: 300, tech: 200, travel: 150, entertainment: 150 },
    housingSub: { rent: 2000, utilities: 300, subs: 200 },
    otherAmount: 100,
    museumAmount: 50,
    healthAmount: 80,
    financeAmount: 120,
    pendingSortingCount: 0,
    districts: [
      { id: 'food', amount: 1200, share: 0.25, activity: 0.8, prominence: 'active' },
      { id: 'shopping', amount: 800, share: 0.16, activity: 0.5, prominence: 'active' },
      { id: 'housing', amount: 2500, share: 0.50, activity: 0.9, prominence: 'dominant' },
      { id: 'transport', amount: 300, share: 0.06, activity: 0.5, prominence: 'quiet' },
      { id: 'savings', amount: 1500, share: 0.30, activity: 0.7, prominence: 'active' }
    ],
    venues: [
      { id: 'food_bistro', amount: 300, share: 0.25, activity: 0.6, purchaseCount: 3, activeDays: 2, merchantCount: 1, presence: 0.5, additionalPlaces: 0 },
      { id: 'food_super', amount: 400, share: 0.33, activity: 0.7, purchaseCount: 4, activeDays: 3, merchantCount: 2, presence: 0.6, additionalPlaces: 0 },
      { id: 'food_coffee', amount: 200, share: 0.17, activity: 0.8, purchaseCount: 12, activeDays: 10, merchantCount: 2, presence: 0.8, additionalPlaces: 1 },
      { id: 'food_wolt', amount: 300, share: 0.25, activity: 0.7, purchaseCount: woltCount, activeDays: 5, merchantCount: 1, presence: 0.7, additionalPlaces: 0 },
      { id: 'shop_boutique', amount: 300, share: 0.375, activity: 0.5, purchaseCount: 2, activeDays: 2, merchantCount: 1, presence: 0.4, additionalPlaces: 0 },
      { id: 'shop_tech', amount: 200, share: 0.25, activity: 0.4, purchaseCount: 1, activeDays: 1, merchantCount: 1, presence: 0.3, additionalPlaces: 0 },
      { id: 'shop_travel', amount: 150, share: 0.1875, activity: 0.3, purchaseCount: 1, activeDays: 1, merchantCount: 1, presence: 0.2, additionalPlaces: 0 },
      { id: 'shop_arcade', amount: 150, share: 0.1875, activity: 0.3, purchaseCount: 2, activeDays: 2, merchantCount: 1, presence: 0.2, additionalPlaces: 0 },
      { id: 'house_tower', amount: 2000, share: 0.80, activity: 0.9, purchaseCount: 1, activeDays: 1, merchantCount: 1, presence: 0.9, additionalPlaces: 1 },
      { id: 'house_util', amount: 300, share: 0.12, activity: 0.4, purchaseCount: 2, activeDays: 2, merchantCount: 2, presence: 0.3, additionalPlaces: 0 },
      { id: 'house_subs', amount: 200, share: 0.08, activity: 0.5, purchaseCount: 4, activeDays: 4, merchantCount: 4, presence: 0.4, additionalPlaces: 0 },
      { id: 'trans_station', amount: 300, share: 0.06, activity: 0.5, purchaseCount: 8, activeDays: 6, merchantCount: 1, presence: 0.5, additionalPlaces: 0 },
      { id: 'museum_curiosities', amount: 50, share: 0.01, activity: 0.2, purchaseCount: 1, activeDays: 1, merchantCount: 1, presence: 0.1, additionalPlaces: 0 },
      { id: 'health_pharmacy', amount: 80, share: 0.016, activity: 0.3, purchaseCount: 2, activeDays: 2, merchantCount: 1, presence: 0.2, additionalPlaces: 0 },
      { id: 'finance_bank', amount: 120, share: 0.024, activity: 0.3, purchaseCount: 1, activeDays: 1, merchantCount: 1, presence: 0.2, additionalPlaces: 0 },
      { id: 'savings_sanctuary', amount: 1500, share: 0.30, activity: 0.7, purchaseCount: 1, activeDays: 1, merchantCount: 1, presence: 0.7, additionalPlaces: 0 }
    ],
    habits: {
      hasTravelOrFlight: false,
      woltCount: woltCount,
      coffeeCount: 12,
      onlinePackagesCount: 3,
      activeSubscriptionsCount: 4,
      deliveryTier: deliveryTier,
      deliveryFrequencyScore: deliveryFrequencyScore
    },
    enrichments: [],
    slotPlacements: {}
  };
}

console.log('--- Initializing Diorama Context ---');
const ctx = createMockContext();
const diorama = ctx.window.__diorama;
assert(diorama, 'window.__diorama must be exposed');
assert.equal(diorama.movingCouriers.length, 7, 'Must have exactly 7 moving couriers created in pool');
assert.equal(diorama.stationaryCouriers.length, 4, 'Must have exactly 4 stationary couriers created in pool');

// Cache initial mesh references to prove no recreation occurs
const initialMovingMeshes = diorama.movingCouriers.map(c => c.obj);
const initialStationaryMeshes = diorama.stationaryCouriers.map(c => c.obj);

// ── Test 1: All 5 Tiers Visibility Contract ────────────────────────────────
const tierExpected = {
  quiet:   { moving: 0, waiting: 0 },
  normal:  { moving: 1, waiting: 1 },
  active:  { moving: 3, waiting: 2 },
  high:    { moving: 5, waiting: 3 },
  extreme: { moving: 7, waiting: 4 }
};

for (const [tier, expected] of Object.entries(tierExpected)) {
  const payload = generatePayload(tier, 0.5, tier === 'quiet' ? 0 : 15);
  ctx.window.updateDioramaData(payload);

  const activeMoving = diorama.movingCouriers.filter(c => c.obj.visible).length;
  const activeWaiting = diorama.stationaryCouriers.filter(c => c.obj.visible).length;

  assert.equal(diorama.deliveryTier, tier, `Tier should be ${tier}`);
  assert.equal(activeMoving, expected.moving, `Tier ${tier}: expected ${expected.moving} moving, got ${activeMoving}`);
  assert.equal(activeWaiting, expected.waiting, `Tier ${tier}: expected ${expected.waiting} waiting, got ${activeWaiting}`);

  console.log(`PASS: Tier '${tier}' -> ${activeMoving} moving, ${activeWaiting} waiting`);
}

// ── Test 2: Live Dynamic Transitions (No Recreation, Visibility Toggles Only) ─
console.log('--- Testing Live Payload Transitions ---');
const sequence = ['quiet', 'active', 'extreme', 'normal', 'high', 'quiet'];
for (const targetTier of sequence) {
  const payload = generatePayload(targetTier, 0.65, 8);
  ctx.window.updateDioramaData(payload);

  const expected = tierExpected[targetTier];
  const activeMoving = diorama.movingCouriers.filter(c => c.obj.visible).length;
  const activeWaiting = diorama.stationaryCouriers.filter(c => c.obj.visible).length;

  assert.equal(activeMoving, expected.moving, `Transition to ${targetTier}: moving count mismatch`);
  assert.equal(activeWaiting, expected.waiting, `Transition to ${targetTier}: waiting count mismatch`);

  // Verify same exact mesh references
  diorama.movingCouriers.forEach((c, i) => assert.equal(c.obj, initialMovingMeshes[i], 'Moving mesh was recreated!'));
  diorama.stationaryCouriers.forEach((c, i) => assert.equal(c.obj, initialStationaryMeshes[i], 'Stationary mesh was recreated!'));
}
console.log('PASS: Live transitions preserved mesh identity across all switches');

// ── Test 3: deliveryFrequencyScore Fine-Tuning ──────────────────────────────
console.log('--- Testing deliveryFrequencyScore Speed Modulation ---');
// At active tier (3 moving couriers)
ctx.window.updateDioramaData(generatePayload('active', 0.0, 5));
const speedAtZero = diorama.movingCouriers[0].speed;
const baseSpeed = diorama.movingCouriers[0].baseSpeed;
assert.equal(speedAtZero, baseSpeed, 'At frequency score 0.0, speed should equal baseSpeed');

ctx.window.updateDioramaData(generatePayload('active', 1.0, 5));
const speedAtOne = diorama.movingCouriers[0].speed;
assert(Math.abs(speedAtOne - baseSpeed * 1.20) < 1e-6, `Speed at 1.0 should be baseSpeed * 1.20, got ${speedAtOne}`);

// Verify frequency score does NOT change visibility count
const countAtOne = diorama.movingCouriers.filter(c => c.obj.visible).length;
assert.equal(countAtOne, 3, 'Frequency score must not change actor count');
console.log('PASS: deliveryFrequencyScore fine-tunes speed without altering actor count');

// ── Test 4: setTrafficLevel Isolation ──────────────────────────────────────
console.log('--- Testing setTrafficLevel Isolation ---');
// Set to quiet tier (0 moving, 0 waiting) with heavy transport traffic spike
const quietHeavyTransport = generatePayload('quiet', 0.0, 0);
quietHeavyTransport.transport = 2500;
ctx.window.updateDioramaData(quietHeavyTransport);

// Couriers MUST remain invisible in quiet tier!
const movingAfterTrafficSpike = diorama.movingCouriers.filter(c => c.obj.visible).length;
assert.equal(movingAfterTrafficSpike, 0, 'setTrafficLevel must NOT make hidden couriers visible!');
console.log('PASS: Heavy transport traffic spike did not leak into delivery couriers');

// ── Test 5: food_wolt footfall independence ─────────────────────────────────
console.log('--- Testing Independence from food_wolt Footfall ---');
// Quiet tier with very high food_wolt activity
const payloadQuietHighFootfall = generatePayload('quiet', 0.0, 0);
const woltVenue = payloadQuietHighFootfall.venues.find(v => v.id === 'food_wolt');
woltVenue.activity = 1.0;
woltVenue.purchaseCount = 50;
ctx.window.updateDioramaData(payloadQuietHighFootfall);

assert.equal(diorama.movingCouriers.filter(c => c.obj.visible).length, 0, 'Quiet tier with high footfall must have 0 moving');
assert.equal(diorama.stationaryCouriers.filter(c => c.obj.visible).length, 0, 'Quiet tier with high footfall must have 0 waiting');

// Extreme tier with 0 food_wolt venue activity (e.g. cold start footfall or zero visits recorded)
const payloadExtremeLowFootfall = generatePayload('extreme', 0.9, 30);
const woltVenue2 = payloadExtremeLowFootfall.venues.find(v => v.id === 'food_wolt');
woltVenue2.activity = 0.0;
woltVenue2.purchaseCount = 0;
ctx.window.updateDioramaData(payloadExtremeLowFootfall);

assert.equal(diorama.movingCouriers.filter(c => c.obj.visible).length, 7, 'Extreme tier with zero footfall must still show 7 moving');
assert.equal(diorama.stationaryCouriers.filter(c => c.obj.visible).length, 4, 'Extreme tier with zero footfall must still show 4 waiting');
console.log('PASS: Couriers are strictly governed by deliveryTier, independent of venue footfall');

// ── Test 6: Non-delivery vehicle integrity ─────────────────────────────────
console.log('--- Testing Non-delivery Vehicles in vehicleState ---');
const nonDelivery = diorama.life.vehicles.filter(v => v.purpose !== 'delivery');
assert.equal(nonDelivery.length, 4, 'Should have exactly 4 non-delivery vehicles (Taxi, Sedan, Bus, Delivery Van)');
assert(nonDelivery.every(v => v.purpose === 'transport'), 'All base vehicles should have purpose transport');
console.log('PASS: 4 base traffic vehicles intact and separated from delivery couriers');

console.log('\n========================================');
console.log('ALL DELIVERY COURIER TESTS PASSED (100%)');
console.log('========================================\n');
