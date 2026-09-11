// Ambient encounters borrow existing walkers. No timers, additional population or
// road stops: the native energy scheduler owns their clock and pauses them too.
const cityEncounters = [];
let encounterClock = 0, nextEncounterAt = 6, encounterSequence = 0;
const encounterMotion = window.matchMedia ? window.matchMedia('(prefers-reduced-motion: reduce)') : { matches: false };

function resetEncounterPose(c) {
  ['legL', 'legR', 'kneeL', 'kneeR', 'armL', 'armR'].forEach(function (key) {
    if (c[key]) c[key].rotation.set(0, 0, 0);
  });
  c.obj.position.y = c.baseY;
}
function finishEncounter(event) {
  event.people.forEach(function (saved) {
    const c = saved.c;
    c.obj.position.copy(saved.position); c.obj.rotation.y = saved.yaw;
    c.obj.scale.copy(saved.scale); resetEncounterPose(c);
    c.encounter = null; c.encounterCooldown = encounterClock + 25;
  });
  if (event.kind === 'taxi') parkedTaxi.userData.passengerDoor.rotation.y = 0;
}
function cancelCityEncounters() {
  cityEncounters.forEach(finishEncounter); cityEncounters.length = 0;
}
function startEncounter(kind, people) {
  const event = { kind: kind, age: 0, people: people.map(function (c) {
    return { c: c, position: c.obj.position.clone(), yaw: c.obj.rotation.y, scale: c.obj.scale.clone() };
  }) };
  people.forEach(function (c) { c.encounter = event; resetEncounterPose(c); });
  if (kind === 'taxi') {
    // An unobstructed approach along the north edge of the transport forecourt.
    const origin = event.people[0].position;
    event.route = [origin.clone(), new THREE.Vector3(10.12, Y_WALK, 6.95),
      new THREE.Vector3(10.12, Y_WALK, 7.42), new THREE.Vector3(10.58, Y_WALK, 7.42)];
    event.lengths = event.route.slice(1).map(function (p, i) { return p.distanceTo(event.route[i]); });
    event.travel = event.lengths.reduce(function (a, b) { return a + b; }, 0) / 0.48;
  }
  cityEncounters.push(event);
}
function taxiEncounterPose(event, distance) {
  let index = 0;
  while (index < event.lengths.length - 1 && distance > event.lengths[index]) distance -= event.lengths[index++];
  const a = event.route[index], b = event.route[index + 1];
  const c = event.people[0].c;
  c.obj.position.copy(a).lerp(b, Math.min(1, distance / Math.max(0.001, event.lengths[index])));
  c.obj.rotation.y = Math.atan2(b.x - a.x, b.z - a.z) + (event.age > event.travel + 7 ? Math.PI : 0);
}
function stepCityEncounters(dt) {
  encounterClock += dt;
  if (encounterMotion.matches || energyMode === 'critical') { cancelCityEncounters(); return; }
  for (let i = cityEncounters.length - 1; i >= 0; i--) {
    const event = cityEncounters[i]; event.age += dt;
    if (event.people.some(function (s) { return !s.c.obj.visible; })) {
      finishEncounter(event); cityEncounters.splice(i, 1); continue;
    }
    if (event.kind === 'taxi') {
      const c = event.people[0].c, t = event.age, travel = event.travel;
      const boarding = t < travel, seated = t >= travel && t < travel + 7;
      taxiEncounterPose(event, (boarding ? t : seated ? travel : Math.max(0, travel * 2 + 7 - t)) * 0.48);
      // Hide only the render scale after reaching the cabin; visibility remains owned by crowd allocation.
      c.obj.scale.copy(event.people[0].scale).multiplyScalar(seated ? 0 : 1);
      const nearDoor = boarding ? t > travel - 2 : !seated && t < travel + 9;
      const target = nearDoor ? -1.15 : 0;
      const door = parkedTaxi.userData.passengerDoor;
      door.rotation.y += (target - door.rotation.y) * Math.min(1, dt * 5);
      const stride = seated ? 0 : Math.sin(t * 8) * 0.32;
      c.legL.rotation.x = stride; c.legR.rotation.x = -stride;
      c.armL.rotation.x = -stride; c.armR.rotation.x = stride;
      if (t >= travel * 2 + 7) { finishEncounter(event); cityEncounters.splice(i, 1); }
    } else {
      event.people.forEach(function (saved, j) {
        const c = saved.c, other = event.people[1 - j].c;
        c.obj.rotation.y = Math.atan2(other.obj.position.x - c.obj.position.x, other.obj.position.z - c.obj.position.z);
        const wave = event.kind === 'wave' || event.age < 1.1;
        c.armR.rotation.x = wave ? -2.1 : -0.45 - Math.sin(event.age * 2.5 + j * Math.PI) * 0.20;
        c.armR.rotation.z = wave ? 0.18 + Math.sin(event.age * 9 + j) * 0.17 : 0.08;
        c.obj.position.y = c.baseY + Math.sin(event.age * 2 + j) * 0.005;
      });
      if (event.age > (event.kind === 'wave' ? 2.2 : 5.5)) {
        finishEncounter(event); cityEncounters.splice(i, 1);
      }
    }
  }
  if (encounterClock < nextEncounterAt || cityEncounters.length >= 2) return;
  nextEncounterAt = encounterClock + 5;
  const available = crowdWalkers.filter(function (c) {
    return c.obj.visible && !c.encounter && encounterClock >= (c.encounterCooldown || 0);
  });
  if (available.length < 2) return;
  const passenger = available.find(function (c) { return c.crowdVenue === 'trans_station'; });
  if (passenger && encounterClock >= (parkedTaxi.userData.nextPickup || 12) && !cityEncounters.some(function (e) { return e.kind === 'taxi'; })) {
    startEncounter('taxi', [passenger]); parkedTaxi.userData.nextPickup = encounterClock + 65; return;
  }
  for (let i = 0; i < available.length; i++) {
    for (let j = i + 1; j < available.length; j++) {
      const a = available[i], b = available[j];
      if (a.crowdVenue !== b.crowdVenue) continue;
      const distance = a.obj.position.distanceTo(b.obj.position);
      if (distance < 0.42 || distance > 1.0) continue;
      startEncounter(encounterSequence++ % 3 === 0 ? 'wave' : 'chat', [a, b]); return;
    }
  }
}
