// Inlined before city planting, so dedicated additions reserve their actual footprint.
// Non-interactive authored spots, with alternatives that preserve old decorations.
const COMPANION_LOCATIONS = [
  { id: "pet_cat_rooftop", x: -11.85, z: 2.6, y: Y_WALK, fallback: [-11.85, 3.85] },
  { id: "pet_golden_dog", x: 12.15, z: -9.4, y: Y_GRASS, fallback: [12.1, -11.2] },
  { id: "resident_artist", x: -2.55, z: 1.0, y: Y_WALK, fallback: [-11.85, 1.3] },
  { id: "resident_skater", x: -11.85, z: -1.3, y: Y_WALK },
  { id: "resident_musician", x: 11.85, z: -1.65, y: Y_WALK },
  { id: "resident_balloon", x: 11.85, z: 2.6, y: Y_WALK }
];
const SLOT_DEFS = [
  { id: "slot_tree_sakura", x: 7.4, z: -12.2, y: Y_GRASS, district: "savings" },
  { id: "slot_pet_golden_dog", x: 12.15, z: -9.4, y: Y_GRASS, district: "savings" },
  { id: "slot_repair_bench", x: 7.6, z: -7.25, y: Y_GRASS, district: "savings" },
  { id: "slot_park_bridge", x: 9.2, z: -9.4, y: Y_GRASS, district: "savings", rot: Math.PI / 5, scale: 1.7, radius: 1.1 },
  { id: "slot_fountain_marble", x: 0, z: 1.3, y: Y_WALK, district: "city", scale: 2.2, radius: 1.35 },
  { id: "slot_cafe_stand", x: 11.85, z: 0, y: Y_WALK, district: "food" },
  { id: "slot_resident_artist", x: -2.55, z: 1.0, y: Y_WALK, district: "city" },
  { id: "slot_repair_lamp", x: 11.85, z: -3.3, y: Y_WALK, district: "food" },
  { id: "slot_pet_cat_rooftop", x: -11.85, z: 2.6, y: Y_WALK, district: "shopping" },
  { id: "slot_bike_station", x: -11.85, z: -2.6, y: Y_WALK, district: "shopping" },
  { id: "slot_flower_bed_plaza", x: -11.5, z: 11.4, y: Y_GRASS, district: "shopping" },
  { id: "slot_public_art_sculpture", x: -11.85, z: 0, y: Y_WALK, district: "shopping" },
  { id: "slot_repair_sidewalk", x: 4.0, z: -7.5, y: Y_WALK, district: "housing" }
];
const SLOT_ALIASES = {
  slot_park_center: "slot_tree_sakura", slot_park_overlook: "slot_pet_golden_dog",
  slot_food_plaza: "slot_cafe_stand", slot_shop_promenade: "slot_pet_cat_rooftop",
  slot_housing_terrace: "slot_repair_sidewalk", slot_tech_plaza: "slot_bike_station"
};
function slotAccepts(slotId, itemId) {
  const anchored = ["park_bridge", "fountain_marble", "repair_sidewalk"];
  const own = slotId.replace(/^slot_/, "");
  if (anchored.includes(own) || anchored.includes(itemId)) return own === itemId;
  return SLOT_DEFS.some(function (d) { return d.id === "slot_" + itemId; });
}
function normalizedSlotPlacements(input) {
  const result = {}, used = new Set(), deferred = [];
  Object.keys(input || {}).sort().forEach(function (key) {
    const id = SLOT_ALIASES[key] || key, item = input[key];
    if (typeof item !== "string" || used.has(item)) return;
    if (SLOT_DEFS.some(function (d) { return d.id === id; }) && slotAccepts(id, item) && !result[id]) {
      result[id] = item; used.add(item);
    } else deferred.push(item);
  });
  deferred.forEach(function (item) {
    if (used.has(item)) return;
    const free = SLOT_DEFS.filter(function (d) { return !result[d.id] && slotAccepts(d.id, item); });
    const place = free.find(function (d) { return d.id === "slot_" + item; }) || free[0];
    if (place) { result[place.id] = item; used.add(item); }
  });
  return result;
}
