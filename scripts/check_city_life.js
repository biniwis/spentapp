// Read-only allocation/contract checks. No browser, network, renderer or generated writes.
// First run check_city_life.swift with a fixture JSON output path, then pass it here.
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert/strict');
const base = path.join(__dirname, '..');
const fixtures = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const lifeSource = fs.readFileSync(path.join(base, 'city_v2_life.js'), 'utf8');
const builder = fs.readFileSync(path.join(base, 'build_diorama.js'), 'utf8');
const plots = vm.runInNewContext(builder.match(/const LIFE_PLOTS = (\[[\s\S]*?\n    \]);/)[1]);
const scope = vm.createContext({ clamp: (x, lo, hi) => Math.min(hi, Math.max(lo, x)),
  buildingDistrictKeys: Object.fromEntries(fixtures.empty.map(v => [v.id, true])) });
// Exercise the actual pure part of production code, not a copied allocation algorithm.
vm.runInContext(lifeSource.split('function makeLifePlace(')[0] + '\nthis.rules = { syncVenueStates, allocateLifePlaces, venueStates };', scope);
const r = scope.rules;
function allocate(name) { r.syncVenueStates(fixtures[name]); return r.allocateLifePlaces(r.venueStates, plots); }
assert.equal(allocate('empty').length, 0);
assert.equal(allocate('once').length, 0);
const daily = allocate('daily');
assert.equal(daily.length, 3);
assert(daily.every(a => a.venue === 'food_coffee'));
assert(daily.some(a => a.plot.shared));
assert(daily.some(a => !a.plot.shared));
assert.equal(allocate('delivery').length, 3);
assert(allocate('delivery').every(a => a.venue === 'food_wolt'));
assert.equal(allocate('housing').filter(a => a.venue === 'house_tower').length, 2);
const all = allocate('all');
assert.equal(new Set(all.map(a => a.plot.id)).size, all.length);
assert(all.length <= plots.length);
assert.equal(new Set(all.map(a => a.key)).size, all.length);
assert(all.every(a => a.plot.districts.includes(r.venueStates[a.venue].id.startsWith('food_') ? 'food' : a.venue === 'house_tower' ? 'housing' : a.venue.startsWith('shop_') ? 'shopping' : 'civic')));
assert.deepEqual(allocate('daily').map(a => [a.key, a.plot.id]), daily.map(a => [a.key, a.plot.id]));
assert.equal(new Set(plots.map(p => p.id)).size, plots.length);
assert(plots.every(p => Number.isFinite(p.x) && Number.isFinite(p.z) && p.scale > 0 && Math.max(Math.abs(p.x), Math.abs(p.z)) < 12.2));
// The actual generated bundle must parse independently of the builder.
const html = fs.readFileSync(path.join(base, 'MoneyCity/Resources/diorama.html'), 'utf8');
for (const match of html.matchAll(/<script>([\s\S]*?)<\/script>/g)) new Function(match[1]);
new Function(builder);
new Function(lifeSource);
assert(html.includes('interactiveBuildings.concat(interactiveVenueInstances).filter(visibleInScene)'));
assert(lifeSource.includes('interactiveVenueInstances.push(proxy)'));
assert(!lifeSource.includes('interactiveBuildings.push('));
console.log('PASS: empty, single purchase, daily cafe, delivery, rent, capacity, fixed locations, distinct destinations, canonical IDs and JavaScript syntax.');
