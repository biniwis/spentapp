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
  const visitor = makeFigure({ shirt: family.color, bag: family.kind === "shop" ? 0xB38B58 : null });
  visitor.position.set(-0.48, 0, 0.77); visitor.rotation.y = 0.35;
  packRigidModel(visitor); g.add(visitor); bindVenueActor(visitor, id, 0.30 + variant * 0.15);
  // Separate visual instance ID from the financial destination. Never add this proxy to
  // interactiveBuildings: that is the canonical amount registry and must not double-count.
  const proxy = hitProxy(w + 0.1, 1.55, d + 0.5);
  proxy.userData = { id: id, district: family.district, name: family.label, amount: 0, visits: 0,
    instanceId: g.name, shell: rigid, trend: "" };
  g.add(proxy); interactiveVenueInstances.push(proxy);
  root.add(g);
  return { group: g, proxy: proxy };
}

function applyCityLife(data) {
  syncVenueStates(data.venues);
  // Old callers still render safely, but no visits or new businesses are invented from ₪.
  Object.keys(cityBuildings).forEach(function (id) {
    const b = cityBuildings[id], v = venueStates[id];
    b.proxy.userData.visits = v ? v.purchaseCount : 0;
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
  const transport = venueActivity("trans_station"), delivery = venueActivity("food_wolt");
  trafficSpeed = 0.85 + transport * 0.2;
  vehicleState.forEach(function (v, index) {
    const purpose = v.purpose || (index === 2 ? "delivery" : "transport");
    const activity = purpose === "delivery" ? delivery : transport;
    const threshold = v.threshold !== undefined ? v.threshold : (index === 1 || index === 3 ? 0 : 0.18);
    v.obj.visible = threshold === 0 || activity >= threshold;
  });
  transportUnits.forEach(function (u, i) { u.visible = i === 0 || transport >= i * 0.22; });
}

// Three extra couriers are a visible delivery rhythm, rather than a crowded dine-in patio.
for (let i = 0; i < 3; i++) {
  const courier = makeCourier(0x45ADBD); courier.position.y = Y_WALK; courier.visible = false; root.add(courier);
  vehicleState.push({ obj: courier, path: i % 2 ? roadClockwise : roadCounterClockwise,
    progress: 0.13 + i * 0.29, speed: 0.020, baseY: Y_WALK, purpose: "delivery", threshold: 0.30 + i * 0.22 });
}
