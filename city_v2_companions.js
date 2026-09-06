// Earned characters are life, not properties, spending venues or interactive map targets.
const companionInstances = new Map();
const companionMotionPreference = window.matchMedia ? window.matchMedia("(prefers-reduced-motion: reduce)") : { matches: false };
let companionWelcome = null;

function companionFigure(options) {
  const figure = makeFigure(options);
  figure.traverse(function (o) {
    if (o.isMesh && ![M_SKIN, M_SKIN2, M_DARKFRAME].includes(o.material)) o.material.userData.rewardOwned = true;
  });
  return figure;
}
function makeSkater(g) {
  const figure = companionFigure({ shirt: 0xDA8B47, pants: 0x35455D, cap: 0x397D85, hair: false });
  figure.position.y = 0.11; figure.rotation.y = Math.PI / 2;
  figure.userData.armL.rotation.z = 0.5; figure.userData.armR.rotation.z = -0.5;
  packRigidModel(figure); g.add(figure);
  const deck = mesh(roundedBox(0.65, 0.045, 0.21, 0.06), M_TEAL, 0, 0.085, 0); g.add(deck);
  [-0.22, 0.22].forEach(function (x) { [-0.09, 0.09].forEach(function (z) {
    const wheel = mesh(new THREE.CylinderGeometry(0.04, 0.04, 0.035, 8), M_CREAM, x, 0.04, z);
    wheel.rotation.x = Math.PI / 2; g.add(wheel);
  }); });
}
function makeMusician(g) {
  const figure = companionFigure({ shirt: 0x617F9B, pants: 0x3F4355, hair: 0x593621 });
  const arm = figure.userData.armR; arm.rotation.x = -0.65; arm.userData.rewardJoint = true;
  figure.userData.armL.rotation.x = -1;
  packRigidModel(figure); g.add(figure);
  const guitar = new THREE.Group(); guitar.position.set(0.07, 0.47, 0.17); guitar.rotation.z = -0.4; g.add(guitar);
  [[0, 0, 0.13], [0, 0.14, 0.095]].forEach(function (p) {
    const body = mesh(new THREE.SphereGeometry(p[2], 12, 8), M_WOOD, p[0], p[1], 0); body.scale.z = 0.32; guitar.add(body);
  });
  guitar.add(mesh(new THREE.BoxGeometry(0.035, 0.32, 0.025), M_WOOD, 0, 0.31, 0));
  guitar.add(mesh(new THREE.CylinderGeometry(0.042, 0.042, 0.005, 12), M_DARKFRAME, 0, 0.09, 0.04));
  guitar.children[guitar.children.length - 1].rotation.x = Math.PI / 2;
  for (let i = 0; i < 4; i++) rewardRod(guitar, [(i - 1.5) * 0.008, -0.04, 0.045], [(i - 1.5) * 0.008, 0.45, 0.025], 0.0015, M_MULLION);
  packRigidModel(guitar); g.userData.strumArm = arm;
}
function makeBalloonFriend(g) {
  const figure = companionFigure({ shirt: 0xC17B83, pants: 0x40516A, hair: 0x31241D });
  figure.userData.armR.rotation.x = -1.7;
  packRigidModel(figure); g.add(figure);
  const balloon = new THREE.Group(); balloon.position.set(0.16, 0.75, 0.2); g.add(balloon);
  rewardRod(balloon, [0, 0, 0], [0.13, 0.65, 0], 0.005, M_CREAM);
  const b = mesh(new THREE.SphereGeometry(0.17, 12, 10), M_ROSE, 0.13, 0.83, 0); b.scale.y = 1.2; balloon.add(b);
  balloon.add(mesh(new THREE.ConeGeometry(0.025, 0.05, 6), M_ROSE, 0.13, 0.64, 0));
  g.userData.balloon = balloon;
}
const COMPANION_BUILDERS = {
  pet_cat_rooftop: propCat, pet_golden_dog: propDog, resident_artist: propArtist,
  resident_skater: makeSkater, resident_musician: makeMusician, resident_balloon: makeBalloonFriend
};
function applyCompanions(ids) {
  const owned = new Set(Array.isArray(ids) ? ids : []);
  COMPANION_LOCATIONS.forEach(function (def) {
    let entry = companionInstances.get(def.id);
    if (!owned.has(def.id)) { if (entry) entry.group.visible = false; return; }
    if (!entry) {
      const group = new THREE.Group(); group.name = "earned-companion-" + def.id;
      COMPANION_BUILDERS[def.id](group); root.add(group);
      entry = { group: group, def: def, x: def.x, z: def.z };
      companionInstances.set(def.id, entry);
    }
    // A legacy object can occupy a former animal spot. It stays; the friend takes a safe
    // neighbouring location. No mutation or conversion of the user's saved rewards.
    const occupied = SLOT_DEFS.some(function (s) {
      return slotItems[s.id] && slotItems[s.id].itemId && Math.hypot(s.x - def.x, s.z - def.z) < 0.9;
    });
    entry.x = occupied && def.fallback ? def.fallback[0] : def.x;
    entry.z = occupied && def.fallback ? def.fallback[1] : def.z;
    entry.group.position.set(entry.x, def.y, entry.z); entry.group.visible = true;
  });
}
function welcomeCompanion(id) {
  const entry = companionInstances.get(id);
  if (!entry || !entry.group.visible) return false;
  const previous = Object.assign({}, targetCam);
  const world = entry.group.getWorldPosition(new THREE.Vector3());
  Object.assign(targetCam, { lookX: world.x, lookY: world.y + 0.6, lookZ: world.z, zoom: 3.4 });
  spinVel = 0; tiltVel = 0;
  const message = document.createElement("div");
  message.setAttribute("role", "status");
  message.textContent = currentLang === "en" ? "A new friend is here to stay" : "חבר חדש הצטרף לעיר — והוא כאן להישאר";
  message.style.cssText = "position:absolute;bottom:24px;left:16px;right:16px;text-align:center;background:#fffffff2;color:#173c38;border-radius:18px;padding:14px;font:600 15px system-ui;pointer-events:none;z-index:12";
  if (companionWelcome) companionWelcome.message.remove();
  document.getElementById("stage").appendChild(message);
  companionWelcome = { previous: previous, focused: Object.assign({}, targetCam), elapsed: 0, message: message };
  return true;
}
function animateCompanions(now, dt) {
  const reduced = companionMotionPreference.matches;
  companionInstances.forEach(function (entry) {
    const g = entry.group; if (!g.visible || reduced) return;
    const t = now * 0.001;
    if (entry.def.id === "resident_skater") {
      // A short glide along the pedestrian strip, never into roads or shop fronts.
      g.position.z = entry.z + Math.sin(t * 0.55) * 0.20;
      g.rotation.y = Math.PI / 2;
    }
    if (entry.def.id === "pet_golden_dog") g.rotation.y = Math.sin(t * 0.35) * 0.5;
    if (entry.def.id === "pet_cat_rooftop") g.scale.y = 1 + Math.sin(t * 1.1) * 0.015;
    if (g.userData.strumArm) g.userData.strumArm.rotation.x = -0.65 + Math.sin(t * 3) * 0.12;
    if (g.userData.balloon) g.userData.balloon.rotation.z = Math.sin(t * 0.8) * 0.08;
  });
  if (companionWelcome) {
    companionWelcome.elapsed += dt;
    if (companionWelcome.elapsed > 5) {
      const w = companionWelcome;
      // Return only if the user hasn't taken over the camera in the meantime.
      if (Object.keys(w.focused).every(function (k) { return targetCam[k] === w.focused[k]; }) && pointers.size === 0) Object.assign(targetCam, w.previous);
      w.message.remove(); companionWelcome = null;
    }
  }
}
