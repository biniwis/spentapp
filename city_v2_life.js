// Inlined into the scene closure by build_diorama.js. No extra network or bundle resource.
// Amount = anchor mass; repeated purchases = life; habitual presence = additional places.
const venueStates = Object.create(null);
const lifeInstances = new Map();
const lifeAssignments = new Map();
const LIFE_FAMILIES = {
  food_coffee: { district: "food", label: "CAFE", color: 0xBC8055, kind: "cafe" },
  food_bistro: { district: "food", label: "BISTRO", color: 0xD9805A, kind: "cafe" },
  food_super: { district: "food", label: "MARKET", color: 0x55985C, kind: "market" },
  food_wolt: { district: "food", label: "PICK UP", color: 0x48AABC, kind: "delivery" },
  shop_boutique: { district: "shopping", label: "SHOP", color: 0xB76574, kind: "shop" },
  shop_tech: { district: "shopping", label: "TECH", color: 0x5795B6, kind: "shop" },
  shop_travel: { district: "shopping", label: "TRAVEL", color: 0x759CC4, kind: "shop" },
  shop_arcade: { district: "shopping", label: "PLAY", color: 0x9C7FB3, kind: "leisure" },
  house_tower: { district: "housing", label: "HOME", color: 0xDA8A67, kind: "home" },
  health_pharmacy: { district: "civic", label: "CARE", color: 0x69A57C, kind: "health" },
  museum_curiosities: { district: "civic", label: "BOOKS", color: 0x6996B2, kind: "books" }
};

function finiteUnit(value) { return typeof value === "number" && isFinite(value) ? clamp(value, 0, 1) : 0; }

function syncVenueStates(raw) {
  Object.keys(venueStates).forEach(function (id) { delete venueStates[id]; });
  (Array.isArray(raw) ? raw : []).forEach(function (state) {
    if (!state || !Object.prototype.hasOwnProperty.call(buildingDistrictKeys, state.id)) return;
    const amount = Math.max(0, Number.isFinite(state.amount) ? state.amount : 0);
    venueStates[state.id] = {
      id: state.id, amount: amount, share: finiteUnit(state.share),
      memberShares: (Array.isArray(state.memberShares) ? state.memberShares : []).filter(function (member) {
        return member && typeof member.memberID === 'string' && /^#[0-9a-f]{6}$/i.test(member.color)
          && Number.isFinite(member.share) && member.share > 0;
      }).map(function (member) { return { memberID: member.memberID, color: member.color, share: finiteUnit(member.share) }; }),
      purchaseCount: Math.max(0, Math.floor(Number.isFinite(state.purchaseCount) ? state.purchaseCount : 0)),
      activity: amount > 0 ? finiteUnit(state.activity) : 0,
      presence: amount > 0 ? finiteUnit(state.presence) : 0,
      additionalPlaces: amount > 0 ? clamp(Math.floor(Number.isFinite(state.additionalPlaces) ? state.additionalPlaces : 0), 0, 3) : 0
    };
  });
}

function venueActivity(id) { return venueStates[id] ? venueStates[id].activity : 0; }

// Each family has a permanent home territory. The small mixed-use street can host food
// or shopping, so coffee culture is visible in more than one isolated block.
function allocateLifePlaces(states, plots) {
  const requests = [];
  Object.keys(LIFE_FAMILIES).forEach(function (id) {
    const state = states[id];
    if (!state) return;
    for (let index = 0; index < state.additionalPlaces; index++) {
      requests.push({ id: id, index: index, presence: state.presence });
    }
  });
  requests.sort(function (a, b) { return a.index - b.index || b.presence - a.presence || a.id.localeCompare(b.id); });
  const used = new Set(), result = [];
  requests.forEach(function (request) {
    const family = LIFE_FAMILIES[request.id];
    const candidates = plots.filter(function (p) { return p.districts.includes(family.district); });
    // Alternate the neighbourhood and the shared street. Stable IDs/ordering, never RNG.
    candidates.sort(function (a, b) {
      const preferShared = request.index === 0 && (request.id === "food_coffee" || request.id === "shop_boutique");
      const score = function (p) { return (p.shared === preferShared ? 0 : 10) + p.order; };
      return score(a) - score(b);
    });
    const plot = candidates.find(function (p) { return !used.has(p.id); });
    if (plot) { used.add(plot.id); result.push({ key: request.id + ":" + request.index, venue: request.id, index: request.index, plot: plot }); }
  });
  return result;
}

function makeLifePlace(id, variant) {
  const family = LIFE_FAMILIES[id], g = new THREE.Group();
  g.name = "life-place:" + id + ":" + variant;
  const w = 1.35, d = 1.05, h = family.kind === "home" ? 1.12 : 0.98;
  const accent = mat(family.color, 0.82);
  g.add(mesh(roundedBox(w, h, d, 0.07), M_CREAM, 0, h / 2, 0));
  g.add(mesh(new THREE.BoxGeometry(w + 0.08, 0.07, d + 0.08), M_WARM_STONE, 0, 0.04, 0));
  if (family.kind === "home") {
    pitchedRoof(g, w, d, 0.50, variant % 2 ? M_ROOF_BL : M_ROOF_OR, h, { chimney: variant === 0 });
    g.add(mesh(new THREE.BoxGeometry(0.30, 0.64, 0.04), accent, 0.31, 0.34, d / 2 + 0.03, false, false));
    g.add(mesh(new THREE.BoxGeometry(0.34, 0.39, 0.04), M_GLASS_BL, -0.30, 0.64, d / 2 + 0.03, false, false));
    g.add(mesh(new THREE.BoxGeometry(0.44, 0.05, 0.15), M_WHITE, -0.30, 0.42, d / 2 + 0.06, false, false));
    hedgeRow(g, -0.32, 0.79, 0.75, 0.16);
  } else {
    storefront(g, w, d, { tint: 0xA4CFE1 });
    const canopyColor = "#" + family.color.toString(16).padStart(6, "0");
    if (family.kind !== "delivery") stripedAwning(g, w, d, canopyColor, "#FFF6E8", 0.84);
    if (variant % 2 === 0 && family.kind !== "delivery") pitchedRoof(g, w, d, 0.40, accent, h, {});
    else roofDeck(g, w, d, h, { ac: false });
    signPlate(g, w, 0.87, d, family.label, canopyColor, "#FFFFFF", 27);
    if (family.kind === "market") {
      crateStack(g, -0.36, 0.79); crateStack(g, 0.36, 0.79);
    } else if (family.kind === "delivery") {
      g.add(mesh(new THREE.BoxGeometry(0.76, 0.61, 0.045), accent, -0.17, 0.35, d / 2 + 0.05, false, false));
      for (let y = 0.14; y < 0.65; y += 0.13) g.add(mesh(new THREE.BoxGeometry(0.76, 0.02, 0.06), M_MULLION, -0.17, y, d / 2 + 0.06, false, false));
      crateStack(g, 0.39, 0.80);
    } else if (family.kind === "health") {
      g.add(mesh(new THREE.BoxGeometry(0.10, 0.33, 0.04), accent, 0, 1.32, 0.34, false, false));
      g.add(mesh(new THREE.BoxGeometry(0.33, 0.10, 0.04), accent, 0, 1.32, 0.34, false, false));
    } else if (family.kind === "books") {
      for (let i = 0; i < 4; i++) g.add(mesh(new THREE.BoxGeometry(0.08, 0.22, 0.16), i % 2 ? M_ROOF_OR : M_ROOF_BL, -0.17 + i * 0.11, 0.30, 0.73, false, false));
    }
  }
  const rigid = new THREE.Group();
  while (g.children.length) rigid.add(g.children[0]);
  packRigidModel(rigid); g.add(rigid);
  if (family.kind === "cafe") {
    cafeTableSet(g, 0.12, 1.02, { occupied: true, venue: id, threshold: 0.18 + variant * 0.15,
      umbrella: variant % 2 ? family.color : null, shirt: variant % 2 ? 0x507FA7 : 0xBE806D });
  }
  const visitor = makeFigure({ appearance: buildAppearanceProfile(id + ':visitor:' + variant) });
  visitor.position.set(-0.48, 0, 0.77); visitor.rotation.y = 0.35;
  visitor.userData.lifeActor = true;
  packRigidModel(visitor); g.add(visitor); bindVenueActor(visitor, id, 0.30 + variant * 0.15);
  if (typeof registerCharacterIdle === "function") {
    registerCharacterIdle({
      mode: "visitor",
      ref: visitor,
      torso: visitor.userData.torso,
      armR: visitor.userData.armR,
      armL: visitor.userData.armL,
      baseYaw: 0.35,
      baseY: 0,
      phase: hashCitizenKey(id + ":visitor:" + variant) % 1000
    });
  }
  // Separate visual instance ID from the financial destination. Never add this proxy to
  // interactiveBuildings: that is the canonical amount registry and must not double-count.
  const proxy = hitProxy(w + 0.1, 1.55, d + 0.5);
  proxy.userData = { id: id, district: family.district, name: family.label, amount: 0, visits: 0,
    instanceId: g.name, shell: rigid, trend: "" };
  g.add(proxy); interactiveVenueInstances.push(proxy);
  root.add(g);
  return { group: g, proxy: proxy };
}

// ── Delivery intensity globals (driven by Swift DeliveryIntensityEngine) ───────────────
const validDeliveryTiers = { quiet: 1, normal: 1, active: 1, high: 1, extreme: 1 };
let deliveryTier = "quiet";
let deliveryFreqScore = 0;

const DELIVERY_TIER_PARAMS = {
  quiet:   { movingCouriers: 0, stationaryCouriers: 0 },
  normal:  { movingCouriers: 1, stationaryCouriers: 1 },
  active:  { movingCouriers: 3, stationaryCouriers: 2 },
  high:    { movingCouriers: 5, stationaryCouriers: 3 },
  extreme: { movingCouriers: 7, stationaryCouriers: 4 }
};

// ── Moving courier pool (7 actors) ───────────────────────────────────────────
// Created once during scene init. Alternating cw / ccw paths and staggered progress
// guarantee wide distribution across city streets without clustering or pops.
const MOVING_COURIER_DEFS = [
  { path: "cw",  progress: 0.13, speed: 0.020, color: 0x45ADBD },
  { path: "ccw", progress: 0.42, speed: 0.019, color: 0x45ADBD },
  { path: "cw",  progress: 0.71, speed: 0.021, color: 0x45ADBD },
  { path: "ccw", progress: 0.28, speed: 0.018, color: 0x3AA8C1 },
  { path: "cw",  progress: 0.56, speed: 0.022, color: 0x3AA8C1 },
  { path: "ccw", progress: 0.85, speed: 0.020, color: 0x3AA8C1 },
  { path: "cw",  progress: 0.07, speed: 0.019, color: 0x45ADBD }
];
const movingCourierPool = [];
for (let i = 0; i < MOVING_COURIER_DEFS.length; i++) {
  const def = MOVING_COURIER_DEFS[i];
  const courier = makeCourier(def.color);
  courier.position.y = Y_WALK;
  courier.visible = false;
  root.add(courier);
  const entry = {
    obj: courier,
    path: def.path === "cw" ? roadClockwise : roadCounterClockwise,
    progress: def.progress,
    baseSpeed: def.speed,
    speed: def.speed,
    baseY: Y_WALK,
    purpose: "delivery",
    poolIndex: i
  };
  movingCourierPool.push(entry);
  vehicleState.push(entry);
}

// ── Stationary / waiting courier pool (4 actors) ───────────────────────────────
// Clustered near the food_wolt entrance on the pavement. Zero movement loop needed;
// only visibility is toggled according to behavioral intensity.
const STATIONARY_COURIER_POSITIONS = [
  { x: 10.25, z: 3.85, yaw:  0.5 },  // near venue door left
  { x: 10.65, z: 4.05, yaw: -0.3 },  // near venue door right
  { x: 10.10, z: 3.40, yaw:  1.1 },  // pavement approach
  { x: 10.45, z: 2.90, yaw:  0.0 }   // further back waiting
];
const stationaryCourierPool = [];
for (let i = 0; i < STATIONARY_COURIER_POSITIONS.length; i++) {
  const pos = STATIONARY_COURIER_POSITIONS[i];
  const sc = makeCourier(0x45ADBD, i);
  sc.position.set(pos.x, Y_WALK, pos.z);
  sc.rotation.y = pos.yaw;
  sc.visible = false;
  root.add(sc);
  stationaryCourierPool.push({ obj: sc, pos: pos });
  if (typeof registerCharacterIdle === "function") {
    const rider = sc.userData ? sc.userData.rider : null;
    registerCharacterIdle({
      mode: "courier",
      ref: sc,
      rider: rider,
      torso: rider && rider.userData ? rider.userData.torso : null,
      armR: rider && rider.userData ? rider.userData.armR : null,
      armL: rider && rider.userData ? rider.userData.armL : null,
      baseYaw: pos.yaw,
      baseY: Y_WALK,
      phase: (i * 350 + 120),
      subType: i
    });
  }
}

function applyCityLife(data) {
  // Sync delivery intensity directly from habits payload
  deliveryTier = (data.habits && validDeliveryTiers[data.habits.deliveryTier]) ? data.habits.deliveryTier : "quiet";
  deliveryFreqScore = (data.habits && typeof data.habits.deliveryFrequencyScore === "number" && isFinite(data.habits.deliveryFrequencyScore))
    ? Math.max(0, Math.min(1, data.habits.deliveryFrequencyScore)) : 0;

  syncVenueStates(data.venues);
  // Old callers still render safely, but no visits or new businesses are invented from ₪.
  Object.keys(cityBuildings).forEach(function (id) {
    const b = cityBuildings[id], v = venueStates[id];
    if (b && b.proxy && b.proxy.userData) {
      b.proxy.userData.visits = v ? v.purchaseCount : 0;
    }
  });
  const next = allocateLifePlaces(venueStates, LIFE_PLOTS);
  lifeInstances.forEach(function (entry) { entry.group.visible = false; });
  lifeAssignments.clear();
  LIFE_PLOTS.forEach(function (plot) { plot.quiet.visible = true; });
  next.forEach(function (assignment) {
    let entry = lifeInstances.get(assignment.key);
    if (!entry) { entry = makeLifePlace(assignment.venue, assignment.index); lifeInstances.set(assignment.key, entry); }
    const plot = assignment.plot, state = venueStates[assignment.venue];
    entry.group.position.set(plot.x, Y_WALK, plot.z);
    entry.group.rotation.y = plot.rot;
    entry.group.scale.setScalar(plot.scale);
    entry.group.visible = true; plot.quiet.visible = false;
    entry.proxy.userData.amount = buildingAmounts[assignment.venue] || 0;
    entry.proxy.userData.visits = state.purchaseCount;
    const canonical = bodyOf(assignment.venue);
    if (canonical) entry.proxy.userData.name = canonical.userData.name;
    lifeAssignments.set(assignment.key, plot.id);
  });
  venueActors.forEach(function (actor) { actor.obj.visible = venueActivity(actor.venue) >= actor.threshold; });
  applyVenueCrowds();
  // Smoke belongs to the coffee anchor, not an arbitrary always-on point in space.
  coffeeSmoke.visible = venueActivity("food_coffee") > 0.12 && cityBuildings.food_coffee.tier > 1;
  coffeeSmoke.position.y = Y_WALK + FLOOR_H * Math.max(1, cityBuildings.food_coffee.tier - 1) + 0.72;
  applyHabitTraffic();
}

function applyHabitTraffic() {
  const transport = venueActivity("trans_station");
  trafficSpeed = 0.85 + transport * 0.2;

  const params = DELIVERY_TIER_PARAMS[deliveryTier] || DELIVERY_TIER_PARAMS.quiet;
  const speedMultiplier = 1.0 + deliveryFreqScore * 0.20;

  // 1. Moving couriers visibility and speed tuning
  for (let i = 0; i < movingCourierPool.length; i++) {
    const courier = movingCourierPool[i];
    courier.obj.visible = i < params.movingCouriers;
    courier.speed = courier.baseSpeed * speedMultiplier;
  }

  // 2. Stationary couriers waiting near food_wolt
  for (let i = 0; i < stationaryCourierPool.length; i++) {
    stationaryCourierPool[i].obj.visible = i < params.stationaryCouriers;
  }

  // 3. Non-delivery vehicles (transports) — unchanged behaviour
  vehicleState.forEach(function (v) {
    if (v.purpose !== "delivery") {
      const threshold = v.threshold !== undefined ? v.threshold : (v.poolIndex === 1 || v.poolIndex === 3 ? 0 : 0.18);
      v.obj.visible = threshold === 0 || transport >= threshold;
    }
  });
  transportUnits.forEach(function (u, i) { u.visible = i === 0 || transport >= i * 0.22; });
}
