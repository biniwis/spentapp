// CityAmbientEventSystem: authored paths, borrowed actors, and the existing render
// clock. Population controls eligibility; transaction amounts never choose events.
const cityEncounters = [];
const ambientMotion = window.matchMedia ? window.matchMedia('(prefers-reduced-motion: reduce)') : { matches: false };
const CityAmbientEventSystem = {
  clock: 0, nextAttempt: 25 + Math.random() * 65, nextHero: 180 + Math.random() * 120,
  maxEvents: 2, maxActors: 4,
  // Delivery encounter state — managed separately from the citizen encounter pool
  nextDeliveryAttempt: 40 + Math.random() * 40,
  deliveryRushActive: false, deliveryRushEnd: 0,
  anchors: {
    boutique:  { building: 'shop_boutique', district: 'shopping', lane: [-7.20, -3.30], door: [-7.88, -3.30], inside: [-8.40, -3.30] },
    bench:     { district: 'city', approach: [2.52, 1.0], seat: [3.0, 1.0], yaw: -Math.PI / 2 },
    taxi:      { district: 'transport', lane: [10.12, 6.95], door: [10.12, 7.42], inside: [10.62, 7.42] },
    // Delivery venue entrance — used by courier encounter choreography
    delivery:  { venue: 'food_wolt', approach: [10.55, 3.60], door: [10.88, 3.85], inside: [11.20, 3.85] }
  }
};
function ambientPoint(p) { return new THREE.Vector3(p[0], Y_WALK, p[1]); }
function ambientRoute(points) {
  const lengths = points.slice(1).map(function (p, i) { return p.distanceTo(points[i]); });
  return { points: points, lengths: lengths, length: lengths.reduce(function (a, b) { return a + b; }, 0) };
}
function ambientFollow(obj, route, distance, backwards, dt) {
  let index = 0, remaining = Math.max(0, Math.min(route.length, distance));
  while (index < route.lengths.length - 1 && remaining > route.lengths[index]) remaining -= route.lengths[index++];
  const a = route.points[index], b = route.points[index + 1];
  obj.position.copy(a).lerp(b, Math.min(1, remaining / Math.max(0.001, route.lengths[index])));
  const yaw = Math.atan2(b.x - a.x, b.z - a.z) + (backwards ? Math.PI : 0);
  ambientTurn(obj, yaw, dt);
}
function ambientTurn(obj, yaw, dt) {
  const delta = Math.atan2(Math.sin(yaw - obj.rotation.y), Math.cos(yaw - obj.rotation.y));
  obj.rotation.y += delta * Math.min(1, dt * 6);
}
function ambientPose(c, age, walking) {
  const swing = walking ? Math.sin(age * 7) * 0.32 : 0;
  if (c.legL) c.legL.rotation.x = swing;
  if (c.legR) c.legR.rotation.x = -swing;
  if (c.armL) c.armL.rotation.set(-swing * 0.8, 0, 0);
  if (c.armR) c.armR.rotation.set(swing * 0.8, 0, 0);
  if (c.kneeL) c.kneeL.rotation.x = Math.max(0, swing) * 0.7;
  if (c.kneeR) c.kneeR.rotation.x = Math.max(0, -swing) * 0.7;
}
function ambientEligible(c) {
  return c.obj.visible && !c.dog && !c.encounter && !c.ambientHidden &&
    CityAmbientEventSystem.clock >= (c.encounterCooldown || 0);
}
function startEncounter(kind, people, anchor) {
  if (people.some(function (c) { return !ambientEligible(c); })) return null;
  if (cityEncounters.length >= CityAmbientEventSystem.maxEvents ||
      cityEncounters.reduce(function (n, e) { return n + e.people.length; }, 0) + people.length > CityAmbientEventSystem.maxActors) return null;
  const event = { kind: kind, anchor: anchor, age: 0, phase: 'approach', elapsed: 0,
    people: people.map(function (c) {
      return { c: c, position: c.obj.position.clone(), yaw: c.obj.rotation.y, scale: c.obj.scale.clone(), pIdx: c.pIdx, t: c.t };
    }) };
  people.forEach(function (c) { c.encounter = event; c.ambientState = kind === 'taxi' ? 'approachingCar' : kind === 'together' ? 'socializing' : 'idle'; });
  if (kind === 'building' || kind === 'taxi') {
    event.route = ambientRoute([event.people[0].position.clone(), ambientPoint(anchor.lane), ambientPoint(anchor.door)]);
    event.threshold = ambientRoute([ambientPoint(anchor.door), ambientPoint(anchor.inside)]);
  } else if (kind === 'bench') {
    event.route = ambientRoute([event.people[0].position.clone(), ambientPoint(anchor.approach), ambientPoint(anchor.seat)]);
  }
  if (kind === 'taxi') {
    event.carPosition = parkedTaxi.position.clone(); event.carYaw = parkedTaxi.rotation.y;
    // The pickup bay joins the clockwise lane, then returns via the eastbound spur.
    // These points are root-local; the taxi itself remains parented to the forecourt.
    const points = [[10.8, 7.5], [10.8, 6.65], [10.10, 5.20], [4.35, 5.20]];
    roadClockwise.slice(7).concat(roadClockwise.slice(0, 6)).forEach(function (p) { points.push([p.x, p.z]); });
    points.push([5.6, 6.0], [10.1, 6.0], [10.8, 6.7], [10.8, 7.5]);
    event.driveRoute = ambientRoute(points.map(ambientPoint)); event.driveDistance = 0;
    event.carPose = new THREE.Object3D(); event.carPose.position.copy(event.driveRoute.points[0]); event.carPose.rotation.y = event.carYaw;
  }
  cityEncounters.push(event); return event;
}
function ambientPhase(event, phase) { event.phase = phase; event.elapsed = 0; }
function finishEncounter(event, cancelled) {
  event.people.forEach(function (saved) {
    const c = saved.c;
    // Excursions walk back before release. Data changes cancel to the saved path cursor.
    if (event.kind !== 'together' || cancelled) {
      c.obj.position.copy(saved.position); c.obj.rotation.y = saved.yaw;
      c.pIdx = saved.pIdx; c.t = saved.t;
    }
    c.obj.scale.copy(saved.scale); c.ambientHidden = false; c.obj.userData.ambientHidden = false; ambientPose(c, 0, false);
    c.obj.position.y = c.baseY; c.encounter = null; c.ambientState = 'walking';
    c.encounterCooldown = CityAmbientEventSystem.clock + 45 + Math.random() * 45;
  });
  if (event.kind === 'taxi') {
    parkedTaxi.position.copy(event.carPosition); parkedTaxi.rotation.y = event.carYaw;
    parkedTaxi.userData.passengerDoor.rotation.y = 0;
  }
}
function cancelCityEncounters() {
  cityEncounters.forEach(function (event) { finishEncounter(event, true); }); cityEncounters.length = 0;
}
function ambientHidden(event, on) {
  const saved = event.people[0]; saved.c.ambientHidden = on; saved.c.obj.userData.ambientHidden = on;
  saved.c.obj.scale.copy(saved.scale).multiplyScalar(on ? 0 : 1);
}
function ambientCarWorldPosition() {
  return { x: parkedTaxi.position.x + transportYard.position.x, z: parkedTaxi.position.z + transportYard.position.z };
}
function ambientTrafficBlocked(obj) {
  if (!cityEncounters.some(function (e) { return e.kind === 'taxi' && e.phase === 'drive'; })) return false;
  const car = ambientCarWorldPosition(), dx = car.x - obj.position.x, dz = car.z - obj.position.z;
  const ahead = dx * Math.sin(obj.rotation.y) + dz * Math.cos(obj.rotation.y);
  const side = Math.abs(dx * Math.cos(obj.rotation.y) - dz * Math.sin(obj.rotation.y));
  return ahead > 0 && ahead < 1.65 && side < 0.60;
}
function stepAmbientExcursion(event, dt) {
  const c = event.people[0].c, age = event.elapsed;
  ambientPose(c, event.age, false);
  if (event.phase === 'approach' || event.phase === 'return') {
    const returning = event.phase === 'return', distance = age * 0.42;
    ambientFollow(c.obj, event.route, returning ? event.route.length - distance : distance, returning, dt);
    ambientPose(c, event.age, true); c.ambientState = returning ? 'walking' : event.kind === 'taxi' ? 'approachingCar' : 'walking';
    if (distance >= event.route.length) {
      if (returning) return true;
      ambientPhase(event, 'pause');
    }
  } else if (event.phase === 'pause') {
    if (event.kind === 'bench') ambientTurn(c.obj, event.anchor.yaw, dt);
    else ambientTurn(c.obj, Math.atan2(event.anchor.inside[0] - event.anchor.door[0], event.anchor.inside[1] - event.anchor.door[1]), dt);
    if (age > 0.65) ambientPhase(event, event.kind === 'bench' ? 'sit' : 'enter');
  } else if (event.phase === 'sit') {
    const blend = Math.min(1, age / 0.6);
    c.obj.position.y = c.baseY - 0.12 * blend;
    c.legL.rotation.x = c.legR.rotation.x = -Math.PI / 2 * blend;
    c.kneeL.rotation.x = c.kneeR.rotation.x = Math.PI / 2 * blend;
    c.armL.rotation.x = c.armR.rotation.x = -0.55 * blend; c.ambientState = 'sitting';
    if (age > 6) ambientPhase(event, 'stand');
  } else if (event.phase === 'stand') {
    const blend = Math.max(0, 1 - age / 0.6);
    c.obj.position.y = c.baseY - 0.12 * blend;
    c.legL.rotation.x = c.legR.rotation.x = -Math.PI / 2 * blend;
    c.kneeL.rotation.x = c.kneeR.rotation.x = Math.PI / 2 * blend;
    if (age > 0.6) ambientPhase(event, 'return');
  } else if (event.phase === 'enter' || event.phase === 'exit') {
    const exiting = event.phase === 'exit';
    ambientHidden(event, false);
    ambientFollow(c.obj, event.threshold, event.threshold.length * (exiting ? 1 - Math.min(1, age / 1.2) : Math.min(1, age / 1.2)), exiting, dt);
    ambientPose(c, event.age, true);
    c.ambientState = exiting ? 'exitingBuilding' : 'enteringBuilding';
    if (event.kind === 'taxi') {
      c.ambientState = exiting ? 'leavingCar' : 'approachingCar';
      c.obj.position.y -= (exiting ? 1 - Math.min(1, age / 1.2) : Math.min(1, age / 1.2)) * 0.28;
    }
    if (age >= 1.2) {
      if (exiting) ambientPhase(event, 'return');
      else { ambientHidden(event, true); c.ambientState = event.kind === 'taxi' ? 'insideCar' : 'insideBuilding'; ambientPhase(event, 'inside'); }
    }
  } else if (event.phase === 'inside') {
    if (age > (event.kind === 'taxi' ? 1.0 : 8 + Math.abs(event.people[0].position.x % 3))) ambientPhase(event, event.kind === 'taxi' ? 'drive' : 'exit');
  } else if (event.phase === 'drive') {
    const pose = event.carPose;
    const blocked = vehicleState.some(function (v) {
      const dx = v.obj.position.x - pose.position.x, dz = v.obj.position.z - pose.position.z;
      const ahead = dx * Math.sin(pose.rotation.y) + dz * Math.cos(pose.rotation.y);
      return v.obj.visible && ahead > 0 && ahead < 1.65 && Math.abs(dx * Math.cos(pose.rotation.y) - dz * Math.sin(pose.rotation.y)) < 0.60;
    });
    if (!blocked) event.driveDistance += dt * Math.min(1.2, age * 0.7, Math.max(0.25, (event.driveRoute.length - event.driveDistance) * 0.8));
    ambientFollow(pose, event.driveRoute, event.driveDistance, false, dt);
    parkedTaxi.position.set(pose.position.x - transportYard.position.x, 0, pose.position.z - transportYard.position.z);
    parkedTaxi.rotation.y = pose.rotation.y;
    if (event.driveDistance >= event.driveRoute.length) ambientPhase(event, 'park');
  } else if (event.phase === 'park') {
    if (age > 0.8) ambientPhase(event, 'exit');
  }
  if (event.kind === 'taxi') {
    const opening = ['pause', 'enter', 'park', 'exit'].includes(event.phase);
    const door = parkedTaxi.userData.passengerDoor;
    door.rotation.y += ((opening ? -1.1 : 0) - door.rotation.y) * Math.min(1, dt * 5);
  }
  return false;
}
function stepAmbientTogether(event, dt) {
  if (event.age < 2.2) {
    event.people.forEach(function (saved, i) {
      const c = saved.c, other = event.people[1 - i].c;
      ambientPose(c, 0, false);
      ambientTurn(c.obj, Math.atan2(other.obj.position.x - c.obj.position.x, other.obj.position.z - c.obj.position.z), dt);
      c.armR.rotation.x = -0.35 - Math.sin(event.age * 2 + i) * 0.12;
    });
  } else {
    // Same segment, same direction, same speed: the normal route cursor progresses
    // while borrowed, so releasing the pair never snaps either person backwards.
    event.people.forEach(function (saved) {
      const c = saved.c, a = c.path[c.pIdx], b = c.path[(c.pIdx + 1) % c.path.length];
      const length = Math.hypot(b.x - a.x, b.z - a.z);
      c.t = Math.min(length, c.t + dt * event.speed);
      c.obj.position.set(a.x + (b.x - a.x) * c.t / length, c.baseY, a.z + (b.z - a.z) * c.t / length);
      ambientTurn(c.obj, Math.atan2(b.x - a.x, b.z - a.z), dt); ambientPose(c, event.age, true);
    });
  }
  return event.age >= event.duration;
}
function chooseAmbientEvent() {
  const system = CityAmbientEventSystem;
  const visible = walkingCitizens.filter(function (c) { return c.obj.visible; });
  const available = visible.filter(ambientEligible);
  if (!available.length || Math.random() > 0.72) return;
  // Visibility influences cost/eligibility, never camera targeting. Offscreen micro
  // moments still occur; hero moments wait while a district is tightly focused.
  const heroAllowed = currentMode === 'city' && visible.length >= 10 && energyMode === 'normal';
  const passenger = available.find(function (c) { return c.crowdVenue === 'trans_station'; });
  if (heroAllowed && passenger && system.clock >= system.nextHero && cityEncounters.length === 0) {
    startEncounter('taxi', [passenger], system.anchors.taxi); system.nextHero = system.clock + 180 + Math.random() * 180; return;
  }
  const kinds = Math.random() < 0.5 ? ['bench', 'building', 'together'] : ['building', 'together', 'bench'];
  for (const kind of kinds) {
    if (cityEncounters.some(function (e) { return e.kind === kind; })) continue;
    if (kind === 'building') {
      const anchor = system.anchors.boutique, building = cityBuildings[anchor.building];
      const person = available.find(function (c) { return c.crowdVenue === anchor.building; });
      if (person && building && building.tier >= 2 && building.shell.visible) { startEncounter(kind, [person], anchor); return; }
    } else if (kind === 'bench') {
      const person = available.find(function (c) { return !c.crowdVenue && c.obj.position.x > 1.6 && c.obj.position.x < 2.6 && c.obj.position.z > 0.6 && c.obj.position.z < 1.9; });
      if (person && ambientBench.visible) { startEncounter(kind, [person], system.anchors.bench); return; }
    } else if (visible.length >= 6) {
      for (let i = 0; i < available.length; i++) for (let j = i + 1; j < available.length; j++) {
        const a = available[i], b = available[j];
        if (!a.crowdVenue || a.crowdVenue !== b.crowdVenue || a.pIdx !== b.pIdx) continue;
        const p = a.path[a.pIdx], q = a.path[(a.pIdx + 1) % a.path.length];
        const length = Math.hypot(q.x - p.x, q.z - p.z), separation = a.obj.position.distanceTo(b.obj.position);
        if (separation < 0.42 || separation > 0.95 || length - Math.max(a.t, b.t) < 0.45) continue;
        const e = startEncounter('together', [a, b]);
        if (e) { e.speed = Math.min(a.speed, b.speed) * 0.8; e.duration = 2.2 + Math.min(4.0, (length - Math.max(a.t, b.t) - 0.03) / e.speed); }
        return;
      }
    }
  }
}
// ── Delivery Encounter System ─────────────────────────────────────────────────
// Uses stationaryCourierPool actors (real courier meshes near the venue),
// not generic crowd walkers. This ensures the activity reads as delivery, not
// generic pedestrian traffic, especially at High and Extreme tiers.

// Track which stationary couriers are currently doing an encounter so we don't
// double-assign them.
const deliveryCourierInEncounter = new Set();

// Choreography for a single courier approaching the delivery venue entrance
// (arrival/hero pattern). Returns a plain state object — not a cityEncounters entry.
let deliveryHeroEvent = null;

function startDeliveryHero() {
  if (deliveryHeroEvent) return;
  if (typeof stationaryCourierPool === 'undefined' || stationaryCourierPool.length === 0) return;
  // Pick a visible, idle stationary courier
  const idle = stationaryCourierPool.filter(function (sc, i) {
    return sc.obj.visible && !deliveryCourierInEncounter.has(i);
  });
  if (!idle.length) return;
  const pick = idle[Math.floor(Math.random() * idle.length)];
  const idx = stationaryCourierPool.indexOf(pick);
  deliveryCourierInEncounter.add(idx);
  const anchor = CityAmbientEventSystem.anchors.delivery;
  const start = pick.obj.position.clone();
  const door  = new THREE.Vector3(anchor.door[0], Y_WALK, anchor.door[1]);
  deliveryHeroEvent = {
    courier: pick, idx: idx,
    phase: 'approach', elapsed: 0, age: 0,
    startPos: start,
    doorPos: door,
    savedPos: start.clone(),
    savedYaw: pick.obj.rotation.y
  };
}

function stepDeliveryHero(dt) {
  if (!deliveryHeroEvent) return;
  const ev = deliveryHeroEvent;
  ev.age += dt; ev.elapsed += dt;
  const courier = ev.courier.obj;
  if (ev.phase === 'approach') {
    const t = Math.min(1, ev.elapsed * 0.28);
    courier.position.lerpVectors(ev.startPos, ev.doorPos, t);
    const yaw = Math.atan2(ev.doorPos.x - ev.startPos.x, ev.doorPos.z - ev.startPos.z);
    ambientTurn(courier, yaw, dt);
    if (t >= 1) { ev.phase = 'pause'; ev.elapsed = 0; }
  } else if (ev.phase === 'pause') {
    if (ev.elapsed > 3.0) { ev.phase = 'return'; ev.elapsed = 0; }
  } else if (ev.phase === 'return') {
    const t = Math.min(1, ev.elapsed * 0.28);
    courier.position.lerpVectors(ev.doorPos, ev.savedPos, t);
    ambientTurn(courier, ev.savedYaw, dt);
    if (t >= 1) {
      courier.position.copy(ev.savedPos);
      courier.rotation.y = ev.savedYaw;
      deliveryCourierInEncounter.delete(ev.idx);
      deliveryHeroEvent = null;
    }
  }
}

// Delivery rush: briefly speed up the first few moving couriers for ~6s
let deliveryRushElapsed = 0;
const DELIVERY_RUSH_BASE_SPEEDS = [];
let deliveryRushInitialised = false;

function triggerDeliveryRush() {
  if (CityAmbientEventSystem.deliveryRushActive) return;
  if (typeof movingCourierPool === 'undefined') return;
  if (!deliveryRushInitialised) {
    for (let i = 0; i < movingCourierPool.length; i++) DELIVERY_RUSH_BASE_SPEEDS.push(movingCourierPool[i].speed);
    deliveryRushInitialised = true;
  }
  CityAmbientEventSystem.deliveryRushActive = true;
  deliveryRushElapsed = 0;
  // Boost speed on active moving couriers only
  const params = DELIVERY_TIER_PARAMS[deliveryTier] || DELIVERY_TIER_PARAMS.quiet;
  for (let i = 0; i < Math.min(params.movingCouriers, movingCourierPool.length); i++) {
    movingCourierPool[i].speed = DELIVERY_RUSH_BASE_SPEEDS[i] * 1.7;
  }
}

function stepDeliveryRush(dt) {
  if (!CityAmbientEventSystem.deliveryRushActive) return;
  deliveryRushElapsed += dt;
  if (deliveryRushElapsed >= 6.0) {
    // Restore speeds
    if (deliveryRushInitialised) {
      for (let i = 0; i < movingCourierPool.length; i++) movingCourierPool[i].speed = DELIVERY_RUSH_BASE_SPEEDS[i];
    }
    CityAmbientEventSystem.deliveryRushActive = false;
  }
}

function stepDeliveryEncounters(dt) {
  const system = CityAmbientEventSystem;
  if (ambientMotion.matches || energyMode === 'critical') {
    // Cancel any active delivery events on reduce-motion / critical energy
    if (deliveryHeroEvent) {
      const ev = deliveryHeroEvent;
      ev.courier.obj.position.copy(ev.savedPos);
      ev.courier.obj.rotation.y = ev.savedYaw;
      deliveryCourierInEncounter.delete(ev.idx);
      deliveryHeroEvent = null;
    }
    if (system.deliveryRushActive) {
      if (deliveryRushInitialised) {
        for (let i = 0; i < movingCourierPool.length; i++) movingCourierPool[i].speed = DELIVERY_RUSH_BASE_SPEEDS[i];
      }
      system.deliveryRushActive = false;
    }
    return;
  }

  stepDeliveryHero(dt);
  stepDeliveryRush(dt);

  // Attempt new delivery events on cooldown
  if (system.clock < system.nextDeliveryAttempt) return;

  const params = DELIVERY_TIER_PARAMS[deliveryTier] || DELIVERY_TIER_PARAMS.quiet;
  if (params.encounterChance === 0) {
    system.nextDeliveryAttempt = system.clock + 30 + Math.random() * 30;
    return;
  }

  // Rush event (rare, High+ only)
  if (!system.deliveryRushActive && params.rushChance > 0 && Math.random() < params.rushChance) {
    triggerDeliveryRush();
    system.nextDeliveryAttempt = system.clock + 25 + Math.random() * 25;
    return;
  }

  // Hero arrival event (Extreme only, very rare)
  const heroAllowed = deliveryTier === 'extreme' && !deliveryHeroEvent && Math.random() < 0.05 && system.clock >= system.nextHero;
  if (heroAllowed) {
    startDeliveryHero();
    system.nextHero = system.clock + 120 + Math.random() * 120;
    system.nextDeliveryAttempt = system.clock + 20 + Math.random() * 20;
    return;
  }

  system.nextDeliveryAttempt = system.clock + 20 + Math.random() * 40;
}

function stepCityEncounters(dt) {
  const system = CityAmbientEventSystem;
  system.clock += dt;
  if (ambientMotion.matches || energyMode === 'critical') { cancelCityEncounters(); return; }
  for (let i = cityEncounters.length - 1; i >= 0; i--) {
    const event = cityEncounters[i]; event.age += dt; event.elapsed += dt;
    const invalid = event.people.some(function (s) { return !s.c.obj.visible; }) ||
      (event.kind === 'building' && (!cityBuildings[event.anchor.building] || cityBuildings[event.anchor.building].tier < 2));
    if (invalid || event.age > 180) { finishEncounter(event, true); cityEncounters.splice(i, 1); continue; }
    if (event.kind === 'together' ? stepAmbientTogether(event, dt) : stepAmbientExcursion(event, dt)) {
      finishEncounter(event, false); cityEncounters.splice(i, 1);
    }
  }
  if (system.clock >= system.nextAttempt) {
    system.nextAttempt = system.clock + 25 + Math.random() * 65;
    if (cityEncounters.length < system.maxEvents) chooseAmbientEvent();
  }
  // Delivery encounters run on their own pool and cooldown, independently of citizen encounters.
  stepDeliveryEncounters(dt);
}
