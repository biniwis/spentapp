#!/usr/bin/env node
// check_citizen_diversity.js — Character Diversity v1 regression tests
// Tests run in Node without a DOM or Three.js.

// ─── Inline the pure functions from build_diorama.js ───────────────────────

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

// ─── Test harness ────────────────────────────────────────────────────────────

let passed = 0, failed = 0;
function ok(name, condition, detail) {
  if (condition) { console.log('  ✓', name); passed++; }
  else { console.error('  ✗', name, detail ? ('— ' + detail) : ''); failed++; }
}

// ─── 1. buildAppearanceProfile is pure ──────────────────────────────────────
console.log('\n1. buildAppearanceProfile is pure (same key → same profile)');
for (let i = 0; i < 20; i++) {
  const key = 'test:citizen:' + i;
  const a = buildAppearanceProfile(key, 0);
  const b = buildAppearanceProfile(key, 0);
  ok('key=' + key, appearanceSig(a) === appearanceSig(b) &&
     a.heightScale === b.heightScale && a.hairColor === b.hairColor &&
     a.motion.id === b.motion.id);
}

// ─── 2. Salt produces different output ──────────────────────────────────────
console.log('\n2. Salt produces distinct profiles for a given key');
let saltDiffs = 0;
for (let i = 0; i < 20; i++) {
  const key = 'test:salt:' + i;
  const p0 = buildAppearanceProfile(key, 0);
  const p1 = buildAppearanceProfile(key, 1);
  if (appearanceSig(p0) !== appearanceSig(p1)) saltDiffs++;
}
ok('at least 15/20 keys differ between salt 0 and salt 1', saltDiffs >= 15, 'only ' + saltDiffs + '/20 differed');

// ─── 3. No "gender" field in any profile ────────────────────────────────────
console.log('\n3. No gender field in profiles');
for (let i = 0; i < 100; i++) {
  const p = buildAppearanceProfile('nogender:' + i, 0);
  ok('profile ' + i + ' has no gender field', !('gender' in p));
}

// ─── 4. Cap not assigned to long/bun/ponytail ────────────────────────────────
console.log('\n4. Cap is never assigned to blocked hairstyles');
let capViolations = 0;
for (let i = 0; i < 500; i++) {
  const p = buildAppearanceProfile('captest:' + i, 0);
  if (p.accessory === 'cap' && CAP_BLOCKED_HAIR[p.hairStyle]) capViolations++;
}
ok('0 cap+blocked-hair violations in 500 profiles', capViolations === 0, capViolations + ' violations found');

// ─── 5. motionProfile bounds ────────────────────────────────────────────────
console.log('\n5. Motion profile values are in expected ranges');
for (let i = 0; i < 100; i++) {
  const p = buildAppearanceProfile('motion:' + i, 0);
  const m = p.motion;
  ok('motion bounds ' + i,
    m.speedMult >= 0.80 && m.speedMult <= 1.15 &&
    m.swing >= 0.70 && m.swing <= 1.10 &&
    m.cadence >= 0.80 && m.cadence <= 1.15,
    JSON.stringify(m));
}

// ─── 6. Height/width scale bounds ───────────────────────────────────────────
console.log('\n6. Height/width scale values are bounded (0.93–1.08)');
let scaleViolations = 0;
for (let i = 0; i < 500; i++) {
  const p = buildAppearanceProfile('scale:' + i, 0);
  if (p.heightScale < 0.93 || p.heightScale > 1.08 ||
      p.widthScale  < 0.93 || p.widthScale  > 1.08) scaleViolations++;
}
ok('0 out-of-range scale values in 500 profiles', scaleViolations === 0, scaleViolations + ' violations');

// ─── 7. Diversity in 100-key sample ─────────────────────────────────────────
console.log('\n7. Diversity sample — 100 keys, no gender coupling');
const sample = [];
for (let i = 0; i < 100; i++) sample.push(buildAppearanceProfile('diversity:' + i, 0));

// Each hairstyle appears with ≥2 body styles and ≥2 skin tones
const styleStats = {};
sample.forEach(function (p) {
  const k = p.hairStyle;
  if (!styleStats[k]) styleStats[k] = { bodies: new Set(), skins: new Set() };
  styleStats[k].bodies.add(p.bodyId);
  styleStats[k].skins.add(p.skinTone);
});
CITIZEN_HAIR_STYLES.forEach(function (style) {
  const s = styleStats[style];
  if (!s) return; // rare hairstyle may not appear in 100 keys — acceptable
  ok(style + ': ≥2 body profiles', s.bodies.size >= 2, 'only ' + s.bodies.size);
  ok(style + ': ≥2 skin tones',    s.skins.size  >= 2, 'only ' + s.skins.size);
});

// Accessories appear but are minority (<50%)
const accCount = sample.filter(function (p) { return p.accessory !== null; }).length;
ok('accessories < 50% (expected ~22%)', accCount < 50, accCount + '/100 have accessories');

// ─── 8. Pool reassignment identity regression ───────────────────────────────
console.log('\n8. Pool reassignment identity regression');
function sigFor(key) { return appearanceSig(buildAppearanceProfile(key, 0)); }

const keyA = 'food_super:0';
const keyB = 'food_coffee:3';
const sigA1 = sigFor(keyA);
const sigB1 = sigFor(keyB);

// Simulate: slot A → assign, save sig; reassign to B; reassign back to A → should match sig1
// (profile is pure, so re-keying always produces the same output for the same key)
const sigA2 = sigFor(keyA);
const sigB2 = sigFor(keyB);

ok('key A: stable sig across multiple generations', sigA1 === sigA2);
ok('key B: stable sig across multiple generations', sigB1 === sigB2);
ok('key A and key B produce different sigs',        sigA1 !== sigB1);

// ─── 9. chooseAppearanceForSlot avoids clones ───────────────────────────────
console.log('\n9. chooseAppearanceForSlot avoids signature clones in recent window');
let cloneViolations = 0;
const recent = [];
for (let i = 0; i < 50; i++) {
  const chosen = chooseAppearanceForSlot('venue:slot:' + i, recent);
  // Check chosen sig is not in the last 6
  const lastSix = recent.slice(-6);
  if (lastSix.some(function (r) { return appearanceSig(r) === appearanceSig(chosen); })) cloneViolations++;
  recent.push(chosen);
  if (recent.length > 6) recent.shift();
}
ok('0 clone collisions across 50 sequential slots', cloneViolations === 0, cloneViolations + ' found');

// ─── Summary ─────────────────────────────────────────────────────────────────
console.log('\n────────────────────────────────────');
console.log('Results: ' + passed + ' passed, ' + failed + ' failed');
process.exit(failed > 0 ? 1 : 0);
