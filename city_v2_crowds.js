// Local footfall is derived from visits, not money. Fixed territories and bounded pools
// preserve geography and energy limits; seated/waiting people need no animation loop.
const CROWD_LIMITS = { walkers: 24, waiting: 48 };
const crowdWalkers = [];
const crowdBatches = [];
let crowdSnapshot = [];

// Each route is an authored, unobstructed frontage strip, separate from the door/table
// zone. u runs along the pavement; v points towards its outer edge.
const CROWD_FRONTAGES = {
  food_super:    { x: 10.88, z: -3.25, rot: Math.PI / 2, width: 1.85, routeOffset: 1.66, laneWidth: 0.10 },
  food_bistro:   { x: 10.98, z: -1.05, rot: Math.PI / 2, width: 1.70, routeOffset: 1.56, laneWidth: 0.10,
    maxWait: 3, waitSlots: [[0, -0.20], [0, 0.12], [0, 0.43]] },
  food_coffee:   { x: 10.88, z: 1.15, rot: Math.PI / 2, width: 1.70, cafe: true, routeOffset: 1.66, laneWidth: 0.10 },
  food_wolt:     { x: 10.88, z: 3.30, rot: Math.PI / 2, width: 1.80, routeOffset: 1.66, laneWidth: 0.10, maxWalk: 3, maxWait: 3 },
  shop_boutique: { x: -7.40, z: -3.30, rot: Math.PI / 2, width: 1.70, routeOffset: 0.20, waitOffset: -0.30 },
  shop_tech:     { x: -7.40, z: -1.10, rot: Math.PI / 2, width: 1.30, routeOffset: 0.20, waitOffset: -0.30 },
  shop_travel:   { x: -7.40, z: 1.15, rot: Math.PI / 2, width: 1.30, routeOffset: 0.20, waitOffset: -0.30, maxWalk: 3, maxWait: 3 },
  shop_arcade:   { x: -7.40, z: 3.30, rot: Math.PI / 2, width: 1.70, routeOffset: 0.20, waitOffset: -0.30 },
  house_tower:   { x: -2.85, z: -7.60, rot: 0, width: 2.10, maxWalk: 2, maxWait: 2, routeOffset: 0.58, laneWidth: 0.10 },
  health_pharmacy: { x: -2.85, z: 10.85, rot: 0, width: 1.90, maxWalk: 4, maxWait: 4 },
  museum_curiosities: { x: 0, z: 10.95, rot: 0, width: 1.80, maxWalk: 4, maxWait: 4 },
  trans_station: { x: 8.85, z: 7.85, rot: 0, width: 1.90, maxWalk: 4, maxWait: 4, routeOffset: -0.9 }
};

function crowdDemand(state, frontage) {
  if (!state || !(state.amount > 0) || !(state.purchaseCount > 0)) return { walkers: 0, waiting: 0 };
  const a = finiteUnit(state.activity);
  if (a === 0) return { walkers: 0, waiting: 0 };
  return {
    walkers: Math.min(frontage.maxWalk || 6, Math.max(1, Math.round(Math.pow(a, 1.3) * 7))),
    waiting: a < 0.22 ? 0 : Math.min(frontage.maxWait || 6, Math.round(Math.pow(a, 1.5) * 7))
  };
}

function allocateCrowds(states) {
  const entries = Object.keys(CROWD_FRONTAGES).map(function (id) {
    const demand = crowdDemand(states[id], CROWD_FRONTAGES[id]);
    return { id: id, activity: states[id] ? finiteUnit(states[id].activity) : 0,
      walkers: demand.walkers, waiting: demand.waiting };
  });
  // Proportional allocation with deterministic largest remainders. Never fill spare
  // capacity with invented customers in unused venues, or assign everybody equally.
  ["walkers", "waiting"].forEach(function (kind) {
    const total = entries.reduce(function (sum, e) { return sum + e[kind]; }, 0);
    if (total <= CROWD_LIMITS[kind]) return;
    const ranked = entries.map(function (e) {
      const exact = e[kind] * CROWD_LIMITS[kind] / total;
      e[kind] = Math.floor(exact);
      return { entry: e, remainder: exact - e[kind] };
    }).sort(function (a, b) { return b.remainder - a.remainder || b.entry.activity - a.entry.activity || a.entry.id.localeCompare(b.entry.id); });
    let spare = CROWD_LIMITS[kind] - entries.reduce(function (sum, e) { return sum + e[kind]; }, 0);
    ranked.forEach(function (r) { if (spare > 0 && r.remainder > 0) { r.entry[kind]++; spare--; } });
  });
  return entries;
}

function frontagePoint(front, u, v) {
  const s = Math.sin(front.rot), c = Math.cos(front.rot);
  return { x: front.x + u * c + v * s, z: front.z - u * s + v * c };
}

function crowdRoute(front) {
  const near = front.routeOffset === undefined ? 0.46 : front.routeOffset;
  const lane = front.laneWidth === undefined ? 0.22 : front.laneWidth;
  return [[-front.width / 2, near], [front.width / 2, near],
    [front.width / 2, near + lane], [-front.width / 2, near + lane]].map(function (p) {
    return frontagePoint(front, p[0], p[1]);
  });
}

function waitingPose(front, index) {
  // Cafe queues stay beside, not inside, the authored tables and seated guests.
  const u = front.waitSlots ? front.waitSlots[index][0] : front.cafe ? (index < 3 ? -0.73 : 0.73) : [-0.66, -0.30, 0.06, 0.48, 0.72, 0.42][index];
  const v = front.waitSlots ? front.waitSlots[index][1] : front.cafe ? [-0.27, 0.02, 0.28][index % 3] : [-0.06, -0.06, -0.06, -0.11, 0.17, 0.21][index];
  const point = frontagePoint(front, u, v + (front.waitOffset || 0));
  return { x: point.x, z: point.z, yaw: front.rot + (index < 3 ? Math.PI : (index % 2 ? -0.8 : 2.3)),
    role: index < 3 ? "waiting" : "chatting" };
}

function ensureCrowdBatches() {
  if (crowdBatches.length) return;
  [0xBD795D, 0x527DA3, 0x709068, 0xAD6D8A].forEach(function (shirt, variant) {
    const figure = makeFigure({ shirt: shirt, dark: variant % 2 === 1, pants: 0x45536A });
    if (variant % 2) { figure.userData.armR.rotation.x = -0.65; figure.userData.armL.rotation.z = -0.14; }
    packRigidModel(figure); figure.updateMatrixWorld(true);
    const parts = [];
    figure.traverse(function (part) {
      if (!part.isMesh) return;
      // Bake each prototype part once; all waiting people share its geometry/material.
      const geometry = part.geometry.clone().applyMatrix4(part.matrixWorld);
      const batch = new THREE.InstancedMesh(geometry, part.material, CROWD_LIMITS.waiting);
      batch.name = "venue-crowd:" + variant;
      batch.count = 0; batch.visible = false; batch.frustumCulled = false;
      batch.castShadow = false; batch.receiveShadow = true;
      batch.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
      root.add(batch); parts.push(batch);
      part.geometry.dispose();
    });
    crowdBatches.push(parts);
  });
}

function placeCrowdWalker(record, route, phase) {
  record.path = route; record.phase = phase * Math.PI * 2;
  const lengths = route.map(function (p, i) {
    const q = route[(i + 1) % route.length]; return Math.hypot(q.x - p.x, q.z - p.z);
  });
  let distance = lengths.reduce(function (a, b) { return a + b; }, 0) * phase;
  let index = 0;
  while (index < lengths.length - 1 && distance >= lengths[index]) { distance -= lengths[index]; index++; }
  record.pIdx = index; record.t = distance;
  const p = route[index], q = route[(index + 1) % route.length], t = distance / lengths[index];
  record.obj.position.set(p.x + (q.x - p.x) * t, Y_WALK, p.z + (q.z - p.z) * t);
  record.obj.rotation.y = Math.atan2(q.x - p.x, q.z - p.z);
}

function applyVenueCrowds() {
  crowdSnapshot = allocateCrowds(venueStates);
  // Preserve ongoing moments on identical native refreshes. Cancel before a borrowed
  // actor is removed, repositioned or recycled for another venue.
  if (typeof cancelCityEncounters === "function" && crowdWalkers.some(function (c) {
    if (!c.encounter) return false;
    const entry = crowdSnapshot.find(function (e) { return e.id === c.crowdVenue; });
    return !entry || entry.walkers !== c.crowdCount;
  })) cancelCityEncounters();
  const previous = new Map(crowdWalkers.filter(function (c) { return c.obj.visible; }).map(function (c) { return [c.crowdKey, c]; }));
  const used = new Set(), pending = [];
  crowdSnapshot.forEach(function (entry) {
    for (let i = 0; i < entry.walkers; i++) {
      const key = entry.id + ":" + i, existing = previous.get(key);
      if (existing) used.add(existing);
      else pending.push({ key: key, entry: entry, index: i });
    }
  });
  pending.forEach(function (request) {
    let record = crowdWalkers.find(function (c) { return !used.has(c); });
    if (!record) {
      const palette = [0xBC8055, 0x527FA7, 0x6E9868, 0xBC6C87];
      addCitizen(palette[crowdWalkers.length % palette.length], 0x45536A, null,
        crowdRoute(CROWD_FRONTAGES[request.entry.id]), ["נעים להסתובב כאן"], ["A little moment in the neighbourhood"], false,
        0.27 + (crowdWalkers.length % 4) * 0.025);
      record = walkingCitizens[walkingCitizens.length - 1]; crowdWalkers.push(record);
    }
    record.crowdKey = request.key; record.crowdCount = null;
    used.add(record);
  });
  crowdWalkers.forEach(function (c) { c.obj.visible = used.has(c); });
  const byKey = new Map(Array.from(used, function (c) { return [c.crowdKey, c]; }));
  crowdSnapshot.forEach(function (entry) {
    for (let i = 0; i < entry.walkers; i++) {
      const c = byKey.get(entry.id + ":" + i);
      if (c.crowdCount !== entry.walkers || c.crowdVenue !== entry.id) {
        placeCrowdWalker(c, crowdRoute(CROWD_FRONTAGES[entry.id]), (i + 0.35) / entry.walkers);
        c.crowdCount = entry.walkers; c.crowdVenue = entry.id;
      }
    }
  });
  const waiting = [];
  crowdSnapshot.forEach(function (entry) {
    for (let i = 0; i < entry.waiting; i++) waiting.push(waitingPose(CROWD_FRONTAGES[entry.id], i));
  });
  if (waiting.length) ensureCrowdBatches();
  const counts = [0, 0, 0, 0], transform = new THREE.Object3D();
  waiting.forEach(function (pose, index) {
    const variant = index % 4;
    transform.position.set(pose.x, Y_WALK, pose.z); transform.rotation.y = pose.yaw;
    transform.scale.setScalar(0.96 + (index % 3) * 0.035); transform.updateMatrix();
    crowdBatches[variant].forEach(function (batch) { batch.setMatrixAt(counts[variant], transform.matrix); });
    counts[variant]++;
  });
  crowdBatches.forEach(function (parts, variant) {
    parts.forEach(function (batch) { batch.count = counts[variant]; batch.visible = batch.count > 0; batch.instanceMatrix.needsUpdate = true; });
  });
}
