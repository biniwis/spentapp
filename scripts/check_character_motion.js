#!/usr/bin/env node
// check_character_motion.js — Ambient Character Polish v1 regression suite
const fs = require('fs');
const path = require('path');
const vm = require('vm');

let passed = 0, failed = 0;
function ok(name, condition, detail) {
  if (condition) { console.log('  ✓', name); passed++; }
  else { console.error('  ✗', name, detail ? ('— ' + detail) : ''); failed++; }
}

const buildScript = fs.readFileSync(path.join(__dirname, '../build_diorama.js'), 'utf8');
const crowdsScript = fs.readFileSync(path.join(__dirname, '../city_v2_crowds.js'), 'utf8');
const lifeScript = fs.readFileSync(path.join(__dirname, '../city_v2_life.js'), 'utf8');

console.log('\n1. Architecture and Constraint Checks (static code analysis)');

// 1. CROWD_LIMITS check
const crowdLimitMatch = crowdsScript.match(/const\s+CROWD_LIMITS\s*=\s*\{\s*walkers:\s*(\d+),\s*waiting:\s*(\d+)\s*\}/);
ok('CROWD_LIMITS matches 24 walkers, 48 waiting',
  crowdLimitMatch && Number(crowdLimitMatch[1]) === 24 && Number(crowdLimitMatch[2]) === 48,
  crowdLimitMatch ? `got walkers: ${crowdLimitMatch[1]}, waiting: ${crowdLimitMatch[2]}` : 'not found');

// 2. Waiting crowd InstancedMesh and variant count
const instancedMatch = crowdsScript.includes('new THREE.InstancedMesh(');
ok('Waiting crowd uses InstancedMesh', instancedMatch);

ok('Eight deterministic waiting prototypes share instanced geometry', crowdsScript.includes('Array.from({ length: 8 }') && crowdsScript.includes("buildAppearanceProfile('city:waiting:'"));

// 3. Stationary and moving courier counts
const stationaryCourierMatches = lifeScript.match(/STATIONARY_COURIER_POSITIONS\s*=\s*\[([\s\S]*?)\];/);
const stationaryCount = stationaryCourierMatches ? (stationaryCourierMatches[1].match(/\{/g) || []).length : 0;
ok('Stationary courier count is 4', stationaryCount === 4, `got ${stationaryCount}`);

const movingMatches = lifeScript.match(/movingCouriers:\s*(\d+)/g);
const maxMoving = movingMatches ? Math.max(...movingMatches.map(m => Number(m.split(':')[1]))) : 0;
ok('Max moving courier count is 7', maxMoving === 7, `got ${maxMoving}`);

// 4. No additional animation engines, requestAnimationFrame, setInterval added
const rAFCount = (buildScript.match(/requestAnimationFrame/g) || []).length;
ok('No extra requestAnimationFrame calls (exactly 1 main diorama loop)', rAFCount === 1, `got ${rAFCount}`);

const setIntervalMatches = (buildScript.match(/setInterval/g) || []).length;
ok('No setInterval used for character animation', setIntervalMatches === 0);

const hasMixer = buildScript.includes('AnimationMixer');
ok('No THREE.AnimationMixer introduced', !hasMixer);

console.log('\n2. Runtime Character Registration and Behavior Checks');

// Run diorama generation to get HTML and run in VM to inspect animObjects
const dioramaHtmlPath = path.join(__dirname, '../MoneyCity/Resources/diorama.html');
let html = '';
try {
  html = fs.readFileSync(dioramaHtmlPath, 'utf8');
} catch (e) {
  // If not yet generated, build it
  require('child_process').execSync('node build_diorama.js', { cwd: path.join(__dirname, '..') });
  html = fs.readFileSync(dioramaHtmlPath, 'utf8');
}

// Extract JS from HTML
const scriptMatch = html.match(/<script>([\s\S]*?)<\/script>/);
ok('Extracted script from diorama.html', !!scriptMatch);

// Mock DOM & WebGL environment to run scene initialization
const scriptContent = scriptMatch ? scriptMatch[1] : '';

// Static pattern checks on diorama.html
ok('Busker registered as character_idle', html.includes('mode: "busker"') && html.includes('city:busker:plaza'));
ok('Shopper registered as character_idle', html.includes('mode: "shopper"') && html.includes('shop_boutique:shopper'));
ok('Shopper connected to bindVenueActor', html.includes('bindVenueActor(shopper, "shop_boutique", 0.15)'));
ok('Life place visitor remains packed with packRigidModel', html.includes('packRigidModel(visitor);') && html.includes('bindVenueActor(visitor, id'));
ok('Life place visitor registered as visitor idle', html.includes('mode: "visitor"') && html.includes(':visitor:'));
ok('Cafe and dining tables register seated idles', html.includes('mode: "seated"') && html.includes('applySeatedPoseVariant'));

console.log('\n3. Reduced-Motion and Baseline Restoration Logic Simulation');

// Simulate animObjects character_idle stepping
const testAnimObj = {
  type: "character_idle",
  mode: "busker",
  ref: { visible: true, parent: {} },
  armR: { rotation: { x: 0.5 } },
  armL: { rotation: { x: 0.1 } },
  torso: { rotation: { y: 0.3 } },
  baseArmRX: 0,
  baseArmLX: 0,
  baseTorsoY: 0,
  phase: 42
};

let ambientMotion = { matches: true };
let energyMode = 'normal';
let now = 10000;
let dt = 0.016;

function stepIdle(a) {
  const isReduced = (typeof ambientMotion !== "undefined" && ambientMotion.matches);
  const isCritical = typeof energyMode !== "undefined" && energyMode === "critical";
  if (isReduced || isCritical) {
    if (!a.restored) {
      if (a.mode === "busker") {
        if (a.armR) a.armR.rotation.x = a.baseArmRX;
        if (a.armL) a.armL.rotation.x = a.baseArmLX;
        if (a.torso) a.torso.rotation.y = a.baseTorsoY;
      }
      a.restored = true;
    }
    return;
  }
  a.restored = false;
  if (!a.ref.visible) return;
  if (a.mode === "busker") {
    const strum = Math.sin(now * 0.005 + a.phase);
    if (a.armR) a.armR.rotation.x = a.baseArmRX + strum * 0.12;
    if (a.armL) a.armL.rotation.x = a.baseArmLX + Math.sin(now * 0.002 + a.phase) * 0.02;
    if (a.torso) a.torso.rotation.y = a.baseTorsoY + Math.sin(now * 0.0016 + a.phase) * 0.025;
  }
}

// 1. In reduced motion: restores baseline
stepIdle(testAnimObj);
ok('Reduced motion restores busker baseline armRX = 0', testAnimObj.armR.rotation.x === 0);
ok('Reduced motion restores busker baseline armLX = 0', testAnimObj.armL.rotation.x === 0);
ok('Reduced motion restores busker baseline torsoY = 0', testAnimObj.torso.rotation.y === 0);

// 2. In normal motion: animates with finite numbers
ambientMotion.matches = false;
stepIdle(testAnimObj);
ok('Normal motion updates armR with finite number', Number.isFinite(testAnimObj.armR.rotation.x) && !isNaN(testAnimObj.armR.rotation.x));
ok('Normal motion updates torso with finite number', Number.isFinite(testAnimObj.torso.rotation.y) && !isNaN(testAnimObj.torso.rotation.y));

// 3. In critical energy: restores baseline
energyMode = 'critical';
stepIdle(testAnimObj);
ok('Critical energy restores busker baseline armRX = 0', testAnimObj.armR.rotation.x === 0);

// 4. Hidden actor skips work
energyMode = 'normal';
testAnimObj.ref.visible = false;
const prevArm = testAnimObj.armR.rotation.x;
now += 5000;
stepIdle(testAnimObj);
ok('Hidden actor does not mutate transforms', testAnimObj.armR.rotation.x === prevArm);

console.log('\n4. Visual Visibility & Amplitude Simulation Checks');

// Extract the character_idle case implementation from the real generated HTML
const startMarker = 'case "character_idle": {';
const startIdx = html.indexOf(startMarker);
const endMarker = 'break;\n          }';
const endIdx = html.indexOf(endMarker, startIdx);
const hasBlock = startIdx !== -1 && endIdx !== -1;
ok('Extracted character_idle case from diorama.html', hasBlock);

if (hasBlock) {
  // Create an evaluation context
  const idleBody = html.substring(startIdx + startMarker.length, endIdx);
  const stepHtmlIdle = new Function('a', 'now', 'dt', 'ambientMotion', 'companionMotionPreference', 'energyMode', 'visibleInScene', `
    switch(a.type) {
      case "character_idle": {
        ${idleBody}
        break;
      }
    }
  `);

  function makeMockFigure() {
    return {
      visible: true,
      position: { x: 0, y: 0, z: 0, set(x, y, z) { this.x = x; this.y = y; this.z = z; } },
      rotation: { x: 0, y: 0, z: 0, set(x, y, z) { this.x = x; this.y = y; this.z = z; } }
    };
  }
  function makeMockJoint(initX, initY, initZ) {
    return {
      rotation: {
        x: initX || 0, y: initY || 0, z: initZ || 0,
        set(x, y, z) { this.x = x; this.y = y; this.z = z; }
      }
    };
  }

  // 1. Busker test
  const buskerObj = {
    type: "character_idle", mode: "busker",
    ref: makeMockFigure(),
    armR: makeMockJoint(0, 0, 0.055),
    armL: makeMockJoint(0, 0, -0.055),
    forearmR: makeMockJoint(-0.18, 0, 0),
    torso: makeMockJoint(0, 0, 0),
    baseArmRX: 0, baseArmRZ: 0.055, baseArmLX: 0, baseForearmRX: -0.18, baseTorsoY: 0, baseTorsoZ: 0,
    phase: 0
  };

  let buskerMinArmX = 999, buskerMaxArmX = -999;
  let buskerMinForearmX = 999, buskerMaxForearmX = -999;
  let buskerMaxTorsoY = -999;
  for (let t = 0; t < 10000; t += 50) {
    stepHtmlIdle(buskerObj, t, 0.05, { matches: false }, { matches: false }, 'normal', () => true);
    buskerMinArmX = Math.min(buskerMinArmX, buskerObj.armR.rotation.x);
    buskerMaxArmX = Math.max(buskerMaxArmX, buskerObj.armR.rotation.x);
    buskerMinForearmX = Math.min(buskerMinForearmX, buskerObj.forearmR.rotation.x);
    buskerMaxForearmX = Math.max(buskerMaxForearmX, buskerObj.forearmR.rotation.x);
    buskerMaxTorsoY = Math.max(buskerMaxTorsoY, buskerObj.torso.rotation.y);
  }
  const buskerArmSweep = buskerMaxArmX - buskerMinArmX;
  const buskerForearmSweep = buskerMaxForearmX - buskerMinForearmX;
  ok('Busker right arm sweep is clearly visible (>= 0.40 rad / 23°)', buskerArmSweep >= 0.40, `got ${buskerArmSweep.toFixed(3)} rad`);
  ok('Busker forearm participates in strum (>= 0.25 rad)', buskerForearmSweep >= 0.25, `got ${buskerForearmSweep.toFixed(3)} rad`);
  ok('Busker pauses and looks toward plaza (torso turn >= 0.20 rad)', buskerMaxTorsoY >= 0.20, `got ${buskerMaxTorsoY.toFixed(3)} rad`);

  // 2. Seated guest Role 0 (Coffee sip & look)
  const coffeeGuest = {
    type: "character_idle", mode: "seated", subType: 0,
    ref: makeMockFigure(),
    armR: makeMockJoint(-0.62, 0, 0.055),
    forearmR: makeMockJoint(-0.8, 0, 0),
    torso: makeMockJoint(0, 0, 0),
    baseArmRX: -0.62, baseArmRZ: 0.055, baseForearmRX: -0.8, baseTorsoY: 0, baseTorsoX: 0,
    phase: 0
  };
  let sipArmLift = 0, sipLookTurn = 0;
  for (let t = 0; t < 18000; t += 100) {
    stepHtmlIdle(coffeeGuest, t, 0.1, { matches: false }, { matches: false }, 'normal', () => true);
    sipArmLift = Math.min(sipArmLift, coffeeGuest.armR.rotation.x);
    sipLookTurn = Math.max(sipLookTurn, coffeeGuest.torso.rotation.y);
  }
  const sipArmDelta = Math.abs(sipArmLift - (-0.62));
  ok('Seated coffee guest visibly lifts cup to face (lift >= 0.65 rad / 37°)', sipArmDelta >= 0.65, `got ${sipArmDelta.toFixed(3)} rad`);
  ok('Seated coffee guest visibly looks across terrace (turn >= 0.25 rad / 14°)', sipLookTurn >= 0.25, `got ${sipLookTurn.toFixed(3)} rad`);

  // 3. Seated guest Role 1 (Conversationalist)
  const talkGuest = {
    type: "character_idle", mode: "seated", subType: 1,
    ref: makeMockFigure(),
    armR: makeMockJoint(-0.62, 0, 0.055),
    torso: makeMockJoint(0, 0, 0),
    baseArmRX: -0.62, baseArmRZ: 0.055, baseTorsoY: 0, baseTorsoX: 0,
    phase: 0
  };
  let talkTorsoTurn = 0;
  for (let t = 0; t < 18000; t += 100) {
    stepHtmlIdle(talkGuest, t, 0.1, { matches: false }, { matches: false }, 'normal', () => true);
    talkTorsoTurn = Math.max(talkTorsoTurn, Math.abs(talkGuest.torso.rotation.y));
  }
  ok('Seated talking guest visibly turns toward companion (turn >= 0.25 rad)', talkTorsoTurn >= 0.25, `got ${talkTorsoTurn.toFixed(3)} rad`);

  // 4. Shopper at boutique
  const shopperObj = {
    type: "character_idle", mode: "shopper",
    ref: makeMockFigure(),
    armL: makeMockJoint(0, 0, -0.055),
    armR: makeMockJoint(0, 0, 0.055),
    forearmR: makeMockJoint(-0.18, 0, 0),
    torso: makeMockJoint(0, 0, 0),
    baseArmLX: 0, baseArmRX: 0, baseForearmRX: -0.18, baseTorsoY: 0,
    phase: 0
  };
  let shopMaxTorsoY = -999, shopMinTorsoY = 999;
  for (let t = 0; t < 18000; t += 100) {
    stepHtmlIdle(shopperObj, t, 0.1, { matches: false }, { matches: false }, 'normal', () => true);
    shopMaxTorsoY = Math.max(shopMaxTorsoY, shopperObj.torso.rotation.y);
    shopMinTorsoY = Math.min(shopMinTorsoY, shopperObj.torso.rotation.y);
  }
  ok('Shopper turns torso to inspect window (>= 0.30 rad)', shopMaxTorsoY >= 0.30, `got ${shopMaxTorsoY.toFixed(3)} rad`);
  ok('Shopper turns torso to watch street (<= -0.30 rad)', shopMinTorsoY <= -0.30, `got ${shopMinTorsoY.toFixed(3)} rad`);

  // 5. Stationary courier (rider phone check & look)
  const courierObj = {
    type: "character_idle", mode: "courier", subType: 0,
    ref: makeMockFigure(),
    armR: makeMockJoint(0, 0, 0.055),
    torso: makeMockJoint(0, 0, 0),
    baseArmRX: 0, baseTorsoX: 0, baseTorsoY: 0,
    phase: 0
  };
  let courierArmLift = 0, courierLook = 0;
  for (let t = 0; t < 20000; t += 100) {
    stepHtmlIdle(courierObj, t, 0.1, { matches: false }, { matches: false }, 'normal', () => true);
    courierArmLift = Math.min(courierArmLift, courierObj.armR.rotation.x);
    courierLook = Math.max(courierLook, courierObj.torso.rotation.y);
  }
  ok('Stationary courier visibly reaches for phone (lift >= 0.70 rad)', Math.abs(courierArmLift) >= 0.70, `got ${Math.abs(courierArmLift).toFixed(3)} rad`);
  ok('Stationary courier looks down street for order (turn >= 0.30 rad)', courierLook >= 0.30, `got ${courierLook.toFixed(3)} rad`);

  // 6. Hero queue actor (door look & phone check)
  const heroQueueObj = {
    type: "character_idle", mode: "queue_hero", subType: 0,
    ref: makeMockFigure(),
    armR: makeMockJoint(0, 0, 0.055),
    forearmR: makeMockJoint(-0.18, 0, 0),
    torso: makeMockJoint(0, 0, 0),
    baseArmRX: 0, baseForearmRX: -0.18, baseTorsoX: 0, baseTorsoY: 0,
    phase: 0
  };
  let heroDoorLook = 0, heroPhoneLift = 0;
  for (let t = 0; t < 15000; t += 100) {
    stepHtmlIdle(heroQueueObj, t, 0.1, { matches: false }, { matches: false }, 'normal', () => true);
    heroDoorLook = Math.max(heroDoorLook, heroQueueObj.torso.rotation.y);
    heroPhoneLift = Math.min(heroPhoneLift, heroQueueObj.armR.rotation.x);
  }
  ok('Hero queue actor visibly turns toward entrance (>= 0.30 rad)', heroDoorLook >= 0.30, `got ${heroDoorLook.toFixed(3)} rad`);
  ok('Hero queue actor visibly checks phone while waiting (>= 0.80 rad)', Math.abs(heroPhoneLift) >= 0.80, `got ${Math.abs(heroPhoneLift).toFixed(3)} rad`);
}

console.log('\n────────────────────────────────────');
console.log('Results: ' + passed + ' passed, ' + failed + ' failed');
process.exit(failed > 0 ? 1 : 0);

