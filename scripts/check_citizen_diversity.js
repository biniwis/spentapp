#!/usr/bin/env node
// check_citizen_diversity.js — Character Diversity v1 regression tests
// Tests run in Node without a DOM. Three.js is mocked minimally for applyAppearanceToFigure.

// ─── Minimal Three.js mock for structural tests ──────────────────────────────
const THREE = {
  Group: class {
    constructor() { this.children = []; this.name = ''; }
    add(child) { this.children.push(child); return this; }
    remove(child) { const i = this.children.indexOf(child); if (i >= 0) this.children.splice(i, 1); }
  },
  Vector3: class { constructor(x, y, z) { this.x = x || 0; this.y = y || 0; this.z = z || 0; } },
};

// ─── Inline palette / PRNG code from build_diorama.js ────────────────────────

function hashCitizenKey(str) {
  let h = 0x811c9dc5;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = (Math.imul(h, 0x01000193)) >>> 0;
  }
  return h;
}
function makePRNG(seed) {
  let s = seed >>> 0;
  return function () {
    s = (s + 0x6D2B79F5) >>> 0;
    let z = Math.imul(s ^ (s >>> 15), 1 | s);
    z = (z + Math.imul(z ^ (z >>> 7), 61 | z)) >>> 0;
    return ((z ^ (z >>> 14)) >>> 0) / 4294967296;
  };
}

const CITIZEN_SKIN_TONES  = [0xF1C7A3, 0xD9A176, 0xB97A52, 0x8D593E, 0x60402F];
const CITIZEN_HAIR_COLORS = [0x2B211D, 0x4A3025, 0x68452F, 0x8C5A36, 0xB57A45, 0xC9A26B];
const CITIZEN_TOPS        = [0x66879A, 0x6E8B73, 0xB97867, 0xC19A5B, 0x756C86, 0xA56F78, 0x596F88, 0x92745B];
const CITIZEN_BOTTOMS     = [0x39495A, 0x505760, 0x62564D, 0x405650, 0x484955, 0x746C64];
const CITIZEN_HAIR_STYLES = ['crop', 'short', 'bob', 'long', 'bun', 'ponytail', 'shaved'];
const CITIZEN_BODY_PROFILES = [
  { id: 'compact',  h: 0.95, w: 1.02 },
  { id: 'standard', h: 1.00, w: 1.00 },
  { id: 'tall',     h: 1.05, w: 0.98 },
  { id: 'broad',    h: 1.00, w: 1.05 }
];
const CITIZEN_TOP_STYLES  = ['basic', 'jacket', 'longTop', 'looseBtm'];
const CITIZEN_ACCESSORIES = [null, 'backpack', 'crossbody', 'tote', 'cap', 'headphones'];
const CAP_BLOCKED_HAIR    = { long: true, bun: true, ponytail: true };
const CITIZEN_MOTION_PROFILES = [
  { id: 'relaxed', speedMult: 0.90, swing: 0.85, cadence: 0.90 },
  { id: 'normal',  speedMult: 1.00, swing: 1.00, cadence: 1.00 },
  { id: 'brisk',   speedMult: 1.11, swing: 1.05, cadence: 1.10 },
  { id: 'stroll',  speedMult: 0.83, swing: 0.72, cadence: 0.82 }
];

// Skin material stubs: indexed by skinTone
const CITIZEN_SKIN_MATS = CITIZEN_SKIN_TONES.map(function (h, i) { return { _hex: h, _idx: i }; });

function citizenMat(hex, roughness) { return { _hex: hex, _rough: roughness }; }
function addHairToGroup(grp, style, colorHex) {
  grp._style = style; grp._color = colorHex;
}
function addAccessoryToGroup(grp, accessory, topColorHex) {
  grp._accessory = accessory; grp._topColor = topColorHex;
}
function addClothingDetail(grp, topStyle, topMat) {
  grp._clothingStyle = topStyle; grp._clothingMat = topMat;
}

function buildAppearanceProfile(key, salt) {
  const fullKey = (salt !== undefined && salt > 0) ? key + ':' + salt : key;
  const rand    = makePRNG(hashCitizenKey(fullKey));
  const skinIdx     = Math.floor(rand() * CITIZEN_SKIN_TONES.length);
  const hairIdx     = Math.floor(rand() * CITIZEN_HAIR_STYLES.length);
  const hairColIdx  = Math.floor(rand() * CITIZEN_HAIR_COLORS.length);
  const bodyIdx     = Math.floor(rand() * CITIZEN_BODY_PROFILES.length);
  const topStyleIdx = Math.floor(rand() * CITIZEN_TOP_STYLES.length);
  const topColIdx   = Math.floor(rand() * CITIZEN_TOPS.length);
  const btmColIdx   = Math.floor(rand() * CITIZEN_BOTTOMS.length);
  const motionIdx   = Math.floor(rand() * CITIZEN_MOTION_PROFILES.length);
  const accRoll     = rand();
  const hairStyle   = CITIZEN_HAIR_STYLES[hairIdx];
  let accessory     = null;
  if (accRoll < 0.22) {
    let accIdx = 1 + Math.floor(rand() * (CITIZEN_ACCESSORIES.length - 1));
    if (CITIZEN_ACCESSORIES[accIdx] === 'cap' && CAP_BLOCKED_HAIR[hairStyle]) accIdx = 1;
    accessory = CITIZEN_ACCESSORIES[accIdx];
  }
  const body    = CITIZEN_BODY_PROFILES[bodyIdx];
  const hJitter = 1 + (rand() - 0.5) * 0.018;
  const wJitter = 1 + (rand() - 0.5) * 0.018;
  return {
    key: fullKey, skinTone: skinIdx,
    hairStyle: hairStyle, hairColor: CITIZEN_HAIR_COLORS[hairColIdx],
    bodyId: body.id, heightScale: body.h * hJitter, widthScale: body.w * wJitter,
    topStyle: CITIZEN_TOP_STYLES[topStyleIdx],
    topColor: CITIZEN_TOPS[topColIdx], bottomColor: CITIZEN_BOTTOMS[btmColIdx],
    accessory: accessory, motion: CITIZEN_MOTION_PROFILES[motionIdx]
  };
}

function appearanceSig(p) {
  return p.hairStyle + '|' + p.skinTone + '|' + p.topColor + '|' + p.bottomColor + '|' + p.bodyId;
}

function chooseAppearanceForSlot(key, recentProfiles) {
  const recent = recentProfiles || [];
  for (let salt = 0; salt <= 5; salt++) {
    const p = buildAppearanceProfile(key, salt);
    if (recent.some(function (r) { return appearanceSig(r) === appearanceSig(p); })) continue;
    if (recent.filter(function (r) { return r.hairStyle === p.hairStyle && r.topColor === p.topColor; }).length >= 2) continue;
    return p;
  }
  return buildAppearanceProfile(key, 0);
}

// ─── Minimal mock of makeFigure (just the parts applyAppearanceToFigure touches) ─
function makeFigureMock(appearance) {
  // Six skin meshes: head, nose, neck, forearmL, handL, forearmR, handR — but 6 total
  const skinMeshes  = [{material: null},{material:null},{material:null},{material:null},{material:null},{material:null}];
  const shirtMeshes = [{material: null},{material:null},{material:null}]; // body + 2 upper arms
  const pantsMeshes = [{material: null},{material:null},{material:null},{material:null}]; // 4 cylinders
  const hairGrp     = new THREE.Group();
  const accGrp      = new THREE.Group();
  const clothingGrp = new THREE.Group();
  const bodyMesh    = { scale: { x:1, y:1, z:0.64, set: function(x,y,z){ this.x=x; this.y=y; this.z=z; } } };

  skinMeshes.forEach(function(m) { m.material = CITIZEN_SKIN_MATS[appearance.skinTone]; });
  shirtMeshes.forEach(function(m) { m.material = citizenMat(appearance.topColor, 0.76); });
  pantsMeshes.forEach(function(m) { m.material = citizenMat(appearance.bottomColor, 0.86); });
  addHairToGroup(hairGrp, appearance.hairStyle, appearance.hairColor);
  addAccessoryToGroup(accGrp, appearance.accessory, appearance.topColor);
  if (appearance.topStyle === 'longTop') {
    bodyMesh.scale.set(1, 1.12, 0.64);
  } else if (appearance.topStyle !== 'basic') {
    addClothingDetail(clothingGrp, appearance.topStyle, citizenMat(appearance.topColor, 0.76));
  }

  const fig = new THREE.Group();
  const scale = { x: appearance.widthScale, y: appearance.heightScale, z: appearance.widthScale,
    set: function(x,y,z){ this.x=x; this.y=y; this.z=z; } };
  fig.userData = { skinMeshes, shirtMeshes, pantsMeshes, hairGrp, accGrp, clothingGrp, bodyMesh };
  return { obj: { userData: fig.userData, scale: scale },
    motion: appearance.motion, appearance: appearance, appearanceKey: appearance.key };
}

// Inline applyAppearanceToFigure (mirrors the production code)
function applyAppearanceToFigure(record, appearance) {
  const ud = record.obj.userData;
  record.obj.scale.set(appearance.widthScale, appearance.heightScale, appearance.widthScale);
  const skinMat = CITIZEN_SKIN_MATS[appearance.skinTone];
  if (ud.skinMeshes)  ud.skinMeshes.forEach(function (m) { m.material = skinMat; });
  const topMat  = citizenMat(appearance.topColor, 0.76);
  if (ud.shirtMeshes) ud.shirtMeshes.forEach(function (m) { m.material = topMat; });
  const btmMat  = citizenMat(appearance.bottomColor, 0.86);
  if (ud.pantsMeshes) ud.pantsMeshes.forEach(function (m) { m.material = btmMat; });
  if (ud.hairGrp) {
    while (ud.hairGrp.children.length) ud.hairGrp.remove(ud.hairGrp.children[0]);
    addHairToGroup(ud.hairGrp, appearance.hairStyle, appearance.hairColor);
  }
  if (ud.accGrp) {
    while (ud.accGrp.children.length) ud.accGrp.remove(ud.accGrp.children[0]);
    addAccessoryToGroup(ud.accGrp, appearance.accessory, appearance.topColor);
  }
  if (ud.clothingGrp) {
    while (ud.clothingGrp.children.length) ud.clothingGrp.remove(ud.clothingGrp.children[0]);
  }
  if (ud.bodyMesh) {
    if (appearance.topStyle === 'longTop') {
      ud.bodyMesh.scale.set(1, 1.12, 0.64);
    } else {
      ud.bodyMesh.scale.set(1, 1, 0.64);
    }
    if (ud.clothingGrp && appearance.topStyle !== 'basic' && appearance.topStyle !== 'longTop') {
      addClothingDetail(ud.clothingGrp, appearance.topStyle, topMat);
    }
  }
  record.motion        = appearance.motion;
  record.appearance    = appearance;
  record.appearanceKey = appearance.key;
}

// ─── Test harness ─────────────────────────────────────────────────────────────
let passed = 0, failed = 0;
function ok(name, condition, detail) {
  if (condition) { console.log('  ✓', name); passed++; }
  else { console.error('  ✗', name, detail ? ('— ' + detail) : ''); failed++; }
}

// ─── 1. buildAppearanceProfile is pure ────────────────────────────────────────
console.log('\n1. buildAppearanceProfile is pure (same key → same profile)');
for (let i = 0; i < 20; i++) {
  const key = 'test:citizen:' + i;
  const a = buildAppearanceProfile(key, 0);
  const b = buildAppearanceProfile(key, 0);
  ok('key=' + key, appearanceSig(a) === appearanceSig(b) &&
     a.heightScale === b.heightScale && a.hairColor === b.hairColor &&
     a.motion.id === b.motion.id);
}

// ─── 2. Salt produces different output ────────────────────────────────────────
console.log('\n2. Salt produces distinct profiles for a given key');
let saltDiffs = 0;
for (let i = 0; i < 20; i++) {
  const key = 'test:salt:' + i;
  if (appearanceSig(buildAppearanceProfile(key, 0)) !== appearanceSig(buildAppearanceProfile(key, 1))) saltDiffs++;
}
ok('at least 15/20 keys differ between salt 0 and salt 1', saltDiffs >= 15, 'only ' + saltDiffs + '/20 differed');

// ─── 3. No "gender" field in any profile ──────────────────────────────────────
console.log('\n3. No gender field in profiles');
for (let i = 0; i < 100; i++) {
  ok('profile ' + i, !('gender' in buildAppearanceProfile('nogender:' + i, 0)));
}

// ─── 4. Cap not assigned to long/bun/ponytail ─────────────────────────────────
console.log('\n4. Cap never assigned to blocked hairstyles');
let capViolations = 0;
for (let i = 0; i < 500; i++) {
  const p = buildAppearanceProfile('captest:' + i, 0);
  if (p.accessory === 'cap' && CAP_BLOCKED_HAIR[p.hairStyle]) capViolations++;
}
ok('0 cap+blocked-hair violations in 500 profiles', capViolations === 0, capViolations + ' violations found');

// ─── 5. Motion profile bounds ─────────────────────────────────────────────────
console.log('\n5. Motion profile values are in expected ranges');
for (let i = 0; i < 100; i++) {
  const m = buildAppearanceProfile('motion:' + i, 0).motion;
  ok('motion bounds ' + i,
    m.speedMult >= 0.80 && m.speedMult <= 1.15 &&
    m.swing >= 0.70 && m.swing <= 1.10 &&
    m.cadence >= 0.80 && m.cadence <= 1.15, JSON.stringify(m));
}

// ─── 6. Height/width scale bounds ─────────────────────────────────────────────
console.log('\n6. Height/width scale values are bounded (0.93–1.08)');
let scaleViolations = 0;
for (let i = 0; i < 500; i++) {
  const p = buildAppearanceProfile('scale:' + i, 0);
  if (p.heightScale < 0.93 || p.heightScale > 1.08 || p.widthScale < 0.93 || p.widthScale > 1.08) scaleViolations++;
}
ok('0 out-of-range scale values in 500 profiles', scaleViolations === 0, scaleViolations + ' violations');

// ─── 7. Diversity sample — no gender coupling ─────────────────────────────────
console.log('\n7. Diversity sample — 100 keys, no gender coupling');
const sample = [];
for (let i = 0; i < 100; i++) sample.push(buildAppearanceProfile('diversity:' + i, 0));
const styleStats = {};
sample.forEach(function (p) {
  if (!styleStats[p.hairStyle]) styleStats[p.hairStyle] = { bodies: new Set(), skins: new Set() };
  styleStats[p.hairStyle].bodies.add(p.bodyId);
  styleStats[p.hairStyle].skins.add(p.skinTone);
});
CITIZEN_HAIR_STYLES.forEach(function (style) {
  const s = styleStats[style]; if (!s) return;
  ok(style + ': ≥2 body profiles', s.bodies.size >= 2, 'only ' + s.bodies.size);
  ok(style + ': ≥2 skin tones',    s.skins.size  >= 2, 'only ' + s.skins.size);
});
const accCount = sample.filter(function (p) { return p.accessory !== null; }).length;
ok('accessories < 50% (expected ~22%)', accCount < 50, accCount + '/100 have accessories');

// ─── 8. chooseAppearanceForSlot avoids clones ─────────────────────────────────
console.log('\n8. chooseAppearanceForSlot avoids signature clones in recent window');
let cloneViolations = 0;
const recentBuf = [];
for (let i = 0; i < 50; i++) {
  const chosen = chooseAppearanceForSlot('venue:slot:' + i, recentBuf);
  if (recentBuf.slice(-6).some(function (r) { return appearanceSig(r) === appearanceSig(chosen); })) cloneViolations++;
  recentBuf.push(chosen);
  if (recentBuf.length > 6) recentBuf.shift();
}
ok('0 clone collisions across 50 sequential slots', cloneViolations === 0, cloneViolations + ' found');

// ─── 9. Pool reassignment regression — simulates real applyAppearanceToFigure ─
console.log('\n9. Pool reassignment regression — full A→B→A simulation via applyAppearanceToFigure');

const keyA = 'food_super:0';
const keyB = 'food_coffee:3';
const profA = buildAppearanceProfile(keyA, 0);
const profB = buildAppearanceProfile(keyB, 0);

// Ensure A and B have different enough profiles for a meaningful test.
// (They just need to differ in at least one dimension.)
ok('A and B produce different sigs', appearanceSig(profA) !== appearanceSig(profB));

// --- Step 1: create record for key A ---
const record = makeFigureMock(profA);

function checkRecord(label, prof) {
  const ud = record.obj.userData;
  const sc = record.obj.scale;
  const expectedSkin = CITIZEN_SKIN_MATS[prof.skinTone];
  const expectedTopColor = citizenMat(prof.topColor, 0.76)._hex;
  const expectedBtmColor = citizenMat(prof.bottomColor, 0.86)._hex;

  // skinMeshes — all 6 must match the current skinTone
  ok(label + ': all skin meshes match skinTone', ud.skinMeshes.every(function (m) {
    return m.material && m.material._idx === prof.skinTone;
  }), 'found: ' + ud.skinMeshes.map(function(m){ return m.material && m.material._idx; }).join(','));

  // shirtMeshes
  ok(label + ': all shirt meshes match topColor', ud.shirtMeshes.every(function (m) {
    return m.material && m.material._hex === expectedTopColor;
  }));

  // pantsMeshes
  ok(label + ': all pants meshes match bottomColor', ud.pantsMeshes.every(function (m) {
    return m.material && m.material._hex === expectedBtmColor;
  }));

  // hair
  ok(label + ': hairGrp style matches', ud.hairGrp._style === prof.hairStyle,
     'got ' + ud.hairGrp._style + ' expected ' + prof.hairStyle);
  ok(label + ': hairGrp color matches', ud.hairGrp._color === prof.hairColor);

  // accessory
  ok(label + ': accGrp accessory matches', ud.accGrp._accessory === prof.accessory,
     'got ' + ud.accGrp._accessory + ' expected ' + prof.accessory);

  // clothing silhouette
  if (prof.topStyle === 'longTop') {
    ok(label + ': bodyMesh y-scale is 1.12 for longTop', ud.bodyMesh.scale.y === 1.12, 'got ' + ud.bodyMesh.scale.y);
    ok(label + ': clothingGrp is empty for longTop', ud.clothingGrp.children.length === 0, ud.clothingGrp.children.length + ' children');
  } else if (prof.topStyle === 'basic') {
    ok(label + ': bodyMesh y-scale is 1 for basic', ud.bodyMesh.scale.y === 1, 'got ' + ud.bodyMesh.scale.y);
    ok(label + ': clothingGrp is empty for basic', ud.clothingGrp.children.length === 0, ud.clothingGrp.children.length + ' children');
  } else {
    ok(label + ': bodyMesh y-scale is 1 for ' + prof.topStyle, ud.bodyMesh.scale.y === 1, 'got ' + ud.bodyMesh.scale.y);
    ok(label + ': clothingGrp style matches ' + prof.topStyle, ud.clothingGrp._clothingStyle === prof.topStyle,
       'got ' + ud.clothingGrp._clothingStyle);
  }

  // scale
  ok(label + ': widthScale matches', Math.abs(sc.x - prof.widthScale) < 0.0001);
  ok(label + ': heightScale matches', Math.abs(sc.y - prof.heightScale) < 0.0001);

  // record fields
  ok(label + ': record.appearanceKey matches', record.appearanceKey === prof.key,
     'got ' + record.appearanceKey + ' expected ' + prof.key);
  ok(label + ': record.motion matches', record.motion.id === prof.motion.id);
}

// After initial creation with A:
// (makeFigureMock already applies profA, check it directly)
checkRecord('A (initial)', profA);

// --- Step 2: reassign to B ---
applyAppearanceToFigure(record, profB);
checkRecord('B (after reuse)', profB);

// --- Step 3: reassign back to A ---
applyAppearanceToFigure(record, profA);
checkRecord('A (after re-reuse)', profA);

// No stale fields from B should remain — verify a few explicitly
ok('No stale B hair after return to A',  record.obj.userData.hairGrp._style === profA.hairStyle);
ok('No stale B skin after return to A',
  record.obj.userData.skinMeshes.every(function(m){ return m.material._idx === profA.skinTone; }));

// ─── Summary ──────────────────────────────────────────────────────────────────
console.log('\n────────────────────────────────────');
console.log('Results: ' + passed + ' passed, ' + failed + ' failed');
process.exit(failed > 0 ? 1 : 0);
