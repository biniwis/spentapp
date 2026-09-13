// CityAmbientEventSystem: authored paths, borrowed actors, and the existing render
// clock. Population controls eligibility; transaction amounts never choose events.
const cityEncounters = [];
const ambientMotion = window.matchMedia ? window.matchMedia('(prefers-reduced-motion: reduce)') : { matches: false };
const CityAmbientEventSystem = {
  clock: 0, nextAttempt: 12, nextHero: 35,
  bag: [], recent: [], lastAnchor: null, cooldowns: {}, variants: {},
  seed: Number(new Date().toISOString().slice(0, 10).replace(/-/g, "")),
  maxEvents: 2, maxActors: 4,
  anchors: {
    boutique:  { building: 'shop_boutique', district: 'shopping', lane: [-7.20, -3.30], door: [-7.88, -3.30], inside: [-8.40, -3.30] },
    bench:     { district: 'city', approach: [2.52, 1.0], seat: [3.0, 1.0], yaw: -Math.PI / 2 },
    taxi:      { district: 'transport', lane: [10.12, 6.95], door: [10.12, 7.42], inside: [10.62, 7.42] }
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
  if (c.appearance) { citizenRestArms(c.obj.userData, swing); groundCitizen(c); }
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
    c.obj.scale.copy(saved.scale); if (c.appearance) citizenSeatBlend(c, 0); c.ambientHidden = false; c.obj.userData.ambientHidden = false; ambientPose(c, 0, false);
    c.obj.position.y = c.baseY; c.encounter = null; c.ambientState = 'walking';
    c.encounterCooldown = CityAmbientEventSystem.clock + 45 + cityLifeRandom() * 45;
  });
  if (event.ball) { root.remove(event.ball); event.ball.geometry.dispose(); }
  if (event.anchor && event.anchor.companion) event.anchor.companion.encounter = null;
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
    citizenSeatBlend(c, blend);
    c.legL.rotation.x = c.legR.rotation.x = -Math.PI / 2 * blend;
    c.kneeL.rotation.x = c.kneeR.rotation.x = Math.PI / 2 * blend;
    c.armL.rotation.x = c.armR.rotation.x = -0.55 * blend; c.ambientState = 'sitting';
    if (age > 6) ambientPhase(event, 'stand');
  } else if (event.phase === 'stand') {
    const blend = Math.max(0, 1 - age / 0.6);
    citizenSeatBlend(c, blend);
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
// Weighted shuffle without replacement; history survives bag refills and data redraws.
function cityLifeRandom() {
  const s = CityAmbientEventSystem;
  s.seed = (Math.imul(s.seed, 1664525) + 1013904223) >>> 0;
  return s.seed / 4294967296;
}
const CityLifeScenes = [
  { id: 'bench', anchor: 'bench', actors: 1, duration: 6, cooldown: 55, weight: 1, hero: false, variants: ['rest', 'look'] },
  { id: 'building', anchor: 'boutique', actors: 1, duration: 9, cooldown: 70, weight: 1, hero: false, variants: ['visit'] },
  { id: 'together', anchor: 'promenade', actors: 2, duration: 6, cooldown: 45, weight: 1.2, hero: false, variants: ['greet', 'chat'] },
  { id: 'taxi', anchor: 'taxi', actors: 1, duration: 90, cooldown: 180, weight: 0.5, hero: true, variants: ['pickup'] },
  { id: 'basketball', anchor: 'court', actors: 2, duration: 22, cooldown: 65, weight: 1.3, hero: true, variants: ['solo', 'shootaround', 'pass'] },
  { id: 'musician_listener', anchor: 'resident_musician', actors: 1, duration: 9, cooldown: 65, weight: 1, hero: false, variants: ['listen', 'linger'] },
  { id: 'artist_working', anchor: 'resident_artist', actors: 1, duration: 8, cooldown: 65, weight: 1, hero: false, variants: ['watch'] },
  { id: 'dog_walk', anchor: 'pet_golden_dog', actors: 1, duration: 12, cooldown: 65, weight: 1, hero: false, variants: ['stroll'] }
];
function sceneCandidate(scene, available) {
  const system = CityAmbientEventSystem;
  if (scene.hero && (currentMode !== 'city' || energyMode !== 'normal' || system.clock < system.nextHero || cityEncounters.some(e => e.scene && e.scene.hero))) return null;
  if (scene.id === 'taxi' && walkingCitizens.filter(c => c.obj.visible).length < 10) return null;
  let anchor = system.anchors[scene.anchor], people;
  if (scene.id === 'building') {
    const building = cityBuildings[anchor.building];
    if (!building || building.tier < 2 || !building.shell.visible) return null;
    people = available.filter(c => c.crowdVenue === anchor.building).slice(0, 1);
  } else if (scene.id === 'taxi') people = available.filter(c => c.crowdVenue === 'trans_station').slice(0, 1);
  else if (scene.id === 'bench') {
    if (!ambientBench.visible) return null;
    people = available.filter(c => Math.hypot(c.obj.position.x - 2.52, c.obj.position.z - 1) < 1.4).slice(0, 1);
  } else if (scene.id === 'together') {
    for (const a of available) for (const b of available) {
      if (a === b || !a.crowdVenue || a.crowdVenue !== b.crowdVenue || a.pIdx !== b.pIdx) continue;
      const p = a.path[a.pIdx], q = a.path[(a.pIdx + 1) % a.path.length];
      const remaining = Math.hypot(q.x-p.x,q.z-p.z)-Math.max(a.t,b.t), gap = a.obj.position.distanceTo(b.obj.position);
      if (gap >= 0.42 && gap <= 0.95 && remaining > 0.5) return { people: [a,b], remaining: remaining };
    }
    return null;
  } else if (scene.id === 'basketball') {
    anchor = { point: [courtGroup.position.x, courtGroup.position.z + 0.6] };
    people = available.filter(c => Math.hypot(c.obj.position.x-anchor.point[0],c.obj.position.z-anchor.point[1]) < 3.5).slice(0,2);
    if (!people.length) return null;
    const variant = scene.variants[(system.variants[scene.id] || 0) % scene.variants.length];
    if (variant === 'pass' && people.length < 2) return null;
    return { people: variant === 'pass' ? people : people.slice(0,1), anchor: anchor };
  } else {
    const companion = companionInstances.get(scene.anchor);
    if (!companion || !companion.group.visible || companion.encounter) return null;
    anchor = { point: [companion.x, companion.z + 0.65], companion: companion };
    people = available.filter(c => Math.hypot(c.obj.position.x-anchor.point[0],c.obj.position.z-anchor.point[1]) < 2.5).slice(0,1);
  }
  return people.length === scene.actors ? { people: people, anchor: anchor } : null;
}
function chooseAmbientEvent() {
  const s = CityAmbientEventSystem, available = walkingCitizens.filter(ambientEligible);
  if (!available.length) return;
  if (!s.bag.length) s.bag = CityLifeScenes.map(scene => ({scene:scene, key: -Math.log(Math.max(1e-9,cityLifeRandom())) / scene.weight})).sort((a,b)=>a.key-b.key).map(x=>x.scene);
  for (let i=0; i<s.bag.length; i++) {
    const scene=s.bag[i];
    if (s.recent.includes(scene.id) || s.lastAnchor===scene.anchor || s.clock<(s.cooldowns[scene.id]||0)) continue;
    const candidate=sceneCandidate(scene,available); if (!candidate) continue;
    const e=startEncounter(scene.id,candidate.people,candidate.anchor); if (!e) continue;
    e.scene=scene; e.variant=scene.variants[(s.variants[scene.id]||0)%scene.variants.length];
    s.variants[scene.id]=(s.variants[scene.id]||0)+1;
    if (scene.id==='together') { e.speed=Math.min(...candidate.people.map(c=>c.speed))*0.8; e.duration=2.2+Math.min(4,(candidate.remaining-0.03)/e.speed); }
    if (candidate.anchor && candidate.anchor.point) prepareLifeScene(e);
    s.bag.splice(i,1); s.recent.push(scene.id); if(s.recent.length>3)s.recent.shift();
    s.lastAnchor=scene.anchor; s.cooldowns[scene.id]=s.clock+scene.cooldown;
    if(scene.hero)s.nextHero=s.clock+65+cityLifeRandom()*40;
    return;
  }
  // Unavailable entries must not starve newly unlocked scenes. Preserve recent history.
  s.bag=[];
}
function prepareLifeScene(e) {
  e.routes=e.people.map((saved,i)=>ambientRoute([saved.position.clone(),ambientPoint([e.anchor.point[0]+i*0.65,e.anchor.point[1]])]));
  e.travel=Math.max(...e.routes.map(r=>r.length))/0.42;
  if(e.anchor.companion)e.anchor.companion.encounter=e;
  if(e.kind==='basketball') {
    e.ball=mesh(new THREE.SphereGeometry(0.075,10,8),M_WOOD,0,0,0); root.add(e.ball);
    e.shot=new THREE.Vector3(courtGroup.position.x,courtGroup.position.y+1.10,courtGroup.position.z-0.93);
    e.release=new THREE.Vector3(); e.landing=new THREE.Vector3();
  }
}
function stepLifeScene(e,dt) {
  const t=e.age-e.travel, duration=e.scene.duration;
  e.people.forEach((saved,i)=>{
    const c=saved.c,route=e.routes[i];
    if(t<0 || t>duration) {
      const back=t>duration, distance=back?route.length-(t-duration)*0.42:Math.min(route.length,e.age*0.42);
      ambientFollow(c.obj,route,distance,back,dt);ambientPose(c,e.age,true);
    } else {
      c.obj.position.copy(route.points[route.points.length-1]);
      ambientPose(c,e.age,false);
      const target=e.shot || (e.anchor.companion && e.anchor.companion.group.position);
      if(target)ambientTurn(c.obj,Math.atan2(target.x-c.obj.position.x,target.z-c.obj.position.z),dt);
    }
  });
  if(e.ball) {
    e.ball.visible=t>=0 && t<=duration;
    const pass=e.variant==='pass' && e.people.length>1;
    const cycle=e.variant==='shootaround'?9:11, phase=((Math.max(0,t)%cycle)/cycle);
    const shooter=e.people[pass?1:0].c.obj.position;
    e.release.copy(shooter);e.release.y+=0.7;
    e.landing.copy(shooter);e.landing.z-=0.3;e.landing.y=shooter.y+0.075;
    if(pass && phase<0.18) {
      const other=e.people[0].c.obj.position;
      e.ball.position.copy(other).lerp(shooter,phase/0.18);e.ball.position.y+=0.55+Math.sin(phase/0.18*Math.PI)*0.15;
    } else if(phase<0.4) {
      e.ball.position.copy(shooter);e.ball.position.x+=0.2;e.ball.position.y+=0.09+Math.abs(Math.sin(t*5))*0.42;
    } else if(phase<0.65) {
      const u=(phase-0.4)/0.25;e.ball.position.copy(e.release).lerp(e.shot,u);e.ball.position.y+=Math.sin(u*Math.PI)*0.65;
      e.people[pass?1:0].c.armR.rotation.x=-2.2;
    } else if(phase<0.8) {
      const u=(phase-0.65)/0.15;e.ball.position.copy(e.shot).lerp(e.landing,u);e.ball.position.y+=Math.sin(u*Math.PI)*(e.variant==='shootaround'?0.35:0.1);
    } else {
      const u=(phase-0.8)/0.2;e.ball.position.copy(e.landing).lerp(e.release,u);
      const index=pass?1:0, c=e.people[index].c;
      // Retrieval is an offset from the authored spot, never a frame-integrated delta.
      // Outside play time the return route owns the actor's position.
      if(t>=0 && t<=duration) {
        c.obj.position.z=e.routes[index].points[e.routes[index].points.length-1].z-Math.sin(u*Math.PI)*0.3;
        ambientPose(c,t,true);
      }
    }
  }
  return t>duration+e.travel;
}
function stepCityEncounters(dt) {
  const system = CityAmbientEventSystem;
  system.clock += dt;
  if (ambientMotion.matches || energyMode === 'critical') { cancelCityEncounters(); return; }
  for (let i = cityEncounters.length - 1; i >= 0; i--) {
    const event = cityEncounters[i]; event.age += dt; event.elapsed += dt;
    const invalid = event.people.some(function (s) { return !s.c.obj.visible; }) ||
      (event.anchor && event.anchor.companion && !event.anchor.companion.group.visible) ||
      (event.kind === 'building' && (!cityBuildings[event.anchor.building] || cityBuildings[event.anchor.building].tier < 2));
    if (invalid || event.age > 180) { finishEncounter(event, true); cityEncounters.splice(i, 1); continue; }
    if (event.routes ? stepLifeScene(event, dt) : event.kind === 'together' ? stepAmbientTogether(event, dt) : stepAmbientExcursion(event, dt)) {
      finishEncounter(event, false); cityEncounters.splice(i, 1);
    }
  }
  if (system.clock >= system.nextAttempt) {
    system.nextAttempt = system.clock + 16 + cityLifeRandom() * 20;
    if (cityEncounters.length < system.maxEvents) chooseAmbientEvent();
  }
}
