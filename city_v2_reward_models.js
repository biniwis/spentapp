// The reward library uses the city's authored materials, human proportions and bevels.
// Keep animated joints separate; pack rigid parts to avoid a draw per tiny detail.
function rewardRod(g, from, to, radius, material) {
  const a = new THREE.Vector3(...from), b = new THREE.Vector3(...to), delta = b.clone().sub(a);
  const rod = mesh(new THREE.CylinderGeometry(radius, radius, delta.length(), 6), material);
  rod.position.copy(a.add(b).multiplyScalar(0.5));
  rod.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), delta.normalize());
  g.add(rod); return rod;
}
function rewardMat(color, roughness) {
  const m = mat(color, roughness); m.userData.rewardOwned = true; return m;
}
function propTreeSakura(g) {
  g.add(mesh(new THREE.CylinderGeometry(0.035, 0.075, 0.65, 7), M_WOOD, 0, 0.325, 0));
  [-1, 1].forEach(function (side) { rewardRod(g, [0, 0.36, 0], [side * 0.25, 0.75, 0.07], 0.025, M_WOOD); });
  [[0, 0.94, 0, 0.31], [-0.27, 0.77, 0.02, 0.27], [0.25, 0.82, 0.01, 0.27], [0.03, 0.75, 0.24, 0.24]].forEach(function (p, i) {
    const crown = mesh(new THREE.DodecahedronGeometry(p[3], 1), i % 2 ? M_PINK : M_ROSE, p[0], p[1], p[2]);
    crown.scale.y = 0.88; g.add(crown);
    for (let j = 0; j < 3; j++) g.add(mesh(new THREE.SphereGeometry(0.035, 5, 4), M_CREAM,
      p[0] + Math.cos(j * 2.1) * p[3] * 0.8, p[1] + 0.10, p[2] + Math.sin(j * 2.1) * p[3] * 0.8, false, false));
  });
  packRigidModel(g);
}
function propFlowerBed(g) {
  g.add(mesh(roundedBox(0.96, 0.16, 0.75, 0.05), M_TERRACOTTA_POT, 0, 0.08, 0));
  g.add(mesh(new THREE.BoxGeometry(0.87, 0.035, 0.66), M_WOOD, 0, 0.16, 0));
  const colors = [M_ROSE, M_PINK, M_GOLD];
  for (let i = 0; i < 9; i++) {
    const x = (i % 3 - 1) * 0.26, z = (Math.floor(i / 3) - 1) * 0.20, y = 0.30 + (i % 2) * 0.05;
    rewardRod(g, [x, 0.17, z], [x, y, z], 0.012, M_HEDGE);
    for (let j = 0; j < 4; j++) g.add(mesh(new THREE.SphereGeometry(0.036, 5, 4), colors[i % 3], x + Math.cos(j * Math.PI / 2) * 0.035, y, z + Math.sin(j * Math.PI / 2) * 0.035, false, false));
    g.add(mesh(new THREE.SphereGeometry(0.023, 5, 4), M_GOLD, x, y + 0.015, z, false, false));
  }
  packRigidModel(g);
}
function propBench(g) {
  [-0.10, 0, 0.10].forEach(function (z) { g.add(mesh(new THREE.BoxGeometry(1.03, 0.04, 0.075), M_WOOD, 0, 0.29, z)); });
  [0.40, 0.49].forEach(function (y) { g.add(mesh(new THREE.BoxGeometry(1.03, 0.065, 0.04), M_WOOD, 0, y, -0.14)); });
  [-0.43, 0.43].forEach(function (x) {
    rewardRod(g, [x, 0.025, -0.10], [x, 0.51, -0.14], 0.022, M_DARKFRAME);
    rewardRod(g, [x, 0.025, 0.10], [x, 0.36, 0.10], 0.022, M_DARKFRAME);
    rewardRod(g, [x, 0.37, -0.10], [x, 0.37, 0.14], 0.022, M_DARKFRAME);
  });
  packRigidModel(g);
}
function propLamp(g) {
  g.add(mesh(new THREE.CylinderGeometry(0.10, 0.14, 0.10, 8), M_DARKFRAME, 0, 0.05, 0));
  g.add(mesh(new THREE.CylinderGeometry(0.025, 0.045, 1.20, 8), M_DARKFRAME, 0, 0.68, 0));
  g.add(mesh(new THREE.BoxGeometry(0.19, 0.25, 0.19), M_CREAM, 0, 1.34, 0));
  [-1, 1].forEach(function (x) { [-1, 1].forEach(function (z) {
    rewardRod(g, [x * 0.10, 1.21, z * 0.10], [x * 0.10, 1.47, z * 0.10], 0.014, M_DARKFRAME);
  }); });
  g.add(mesh(new THREE.ConeGeometry(0.19, 0.14, 4), M_DARKFRAME, 0, 1.52, 0));
  g.add(mesh(new THREE.SphereGeometry(0.035, 6, 5), M_GOLD, 0, 1.62, 0));
  packRigidModel(g);
}
function propArtist(g) {
  const painter = makeFigure({ shirt: 0x8A74A7, pants: 0x40516A, hair: 0x743E25 });
  painter.position.set(0.23, 0, -0.23); painter.rotation.y = -0.3;
  const arm = painter.userData.armR; arm.rotation.x = -1.2; arm.userData.rewardJoint = true;
  rewardRod(arm, [0, -0.24, 0.04], [0, -0.31, 0.18], 0.008, M_WOOD);
  painter.traverse(function (o) {
    if (o.isMesh && ![M_SKIN, M_SKIN2, M_DARKFRAME, M_WOOD].includes(o.material)) o.material.userData.rewardOwned = true;
  });
  packRigidModel(painter); g.add(painter);
  [[-0.32, 0.27], [0.12, 0.27], [-0.1, -0.02]].forEach(function (p) { rewardRod(g, [p[0], 0, p[1]], [-0.10, 0.87, 0.22], 0.023, M_WOOD); });
  g.add(mesh(new THREE.BoxGeometry(0.52, 0.40, 0.045), M_WOOD, -0.10, 0.62, 0.24));
  g.add(mesh(new THREE.BoxGeometry(0.46, 0.34, 0.015), M_CANVAS, -0.10, 0.62, 0.272));
  g.add(mesh(new THREE.BoxGeometry(0.41, 0.14, 0.012), M_GLASS_BL, -0.10, 0.70, 0.285, false, false));
  g.add(mesh(new THREE.SphereGeometry(0.042, 8, 6), M_GOLD, 0.035, 0.72, 0.30, false, false));
  g.add(mesh(new THREE.ConeGeometry(0.12, 0.15, 3), M_HEDGE, -0.15, 0.58, 0.29, false, false));
  [-0.40, -0.26].forEach(function (x, i) { g.add(mesh(new THREE.CylinderGeometry(0.044, 0.036, 0.09, 8), i ? M_ROSE : M_TEAL, x, 0.045, 0.08, false, false)); });
  animObjects.push({ type: "reward_artist", ref: painter, arm: arm });
}
function rewardPet(g, isDog) {
  const pet = new THREE.Group(); g.add(pet);
  const coat = isDog ? M_DOG : rewardMat(0xC87938, 0.87), cream = M_CREAM;
  pet.add(mesh(roundedBox(0.20, 0.22, 0.40, 0.065), coat, 0, 0.25, 0));
  [[-0.075, -0.12], [0.075, -0.12], [-0.075, 0.13], [0.075, 0.13]].forEach(function (p) {
    pet.add(mesh(new THREE.CylinderGeometry(0.030, 0.024, 0.19, 7), coat, p[0], 0.10, p[1]));
    pet.add(mesh(roundedBox(0.065, 0.045, 0.09, 0.012), cream, p[0], 0.027, p[1] + 0.015));
  });
  pet.add(mesh(new THREE.SphereGeometry(0.12, 10, 8), coat, 0, 0.43, 0.18));
  pet.add(mesh(new THREE.SphereGeometry(isDog ? 0.065 : 0.044, 8, 6), cream, 0, 0.405, 0.28));
  pet.add(mesh(new THREE.SphereGeometry(0.022, 6, 5), M_DARKFRAME, 0, 0.43, isDog ? 0.335 : 0.318, false, false));
  [-1, 1].forEach(function (side) {
    pet.add(mesh(new THREE.SphereGeometry(0.014, 6, 5), M_DARKFRAME, side * 0.048, 0.468, 0.282, false, false));
    if (isDog) {
      const ear = mesh(roundedBox(0.060, 0.15, 0.055, 0.024), coat, side * 0.108, 0.43, 0.17); ear.rotation.z = side * 0.2; pet.add(ear);
    } else {
      pet.add(mesh(new THREE.ConeGeometry(0.048, 0.11, 4), coat, side * 0.07, 0.555, 0.18));
      pet.add(mesh(new THREE.ConeGeometry(0.024, 0.058, 4), M_PINK, side * 0.07, 0.563, 0.20, false, false));
    }
  });
  pet.add(mesh(new THREE.TorusGeometry(0.08, 0.015, 6, 12), isDog ? M_TEAL : M_ROSE, 0, 0.34, 0.16, false, false));
  const tail = new THREE.Group(); tail.position.set(0, 0.29, -0.18); tail.userData.rewardJoint = true; pet.add(tail);
  const curve = new THREE.CatmullRomCurve3([new THREE.Vector3(0, 0, 0), new THREE.Vector3(0.07, 0.10, -0.12), new THREE.Vector3(0.06, isDog ? 0.12 : 0.25, -0.24)]);
  tail.add(mesh(new THREE.TubeGeometry(curve, 8, isDog ? 0.032 : 0.020, 6, false), coat));
  packRigidModel(pet); animObjects.push({ type: "reward_pet", ref: pet, tail: tail });
}
function propCat(g) { rewardPet(g, false); }
function propDog(g) { rewardPet(g, true); }
function propBikeStation(g) {
  [-0.39, 0, 0.39].forEach(function (x) { rewardRod(g, [x, 0, -0.13], [x, 0.35, -0.13], 0.018, M_DARKFRAME); });
  rewardRod(g, [-0.43, 0.35, -0.13], [0.43, 0.35, -0.13], 0.018, M_DARKFRAME);
  [-0.12, 0.20].forEach(function (z, n) {
    [-0.26, 0.26].forEach(function (x) {
      g.add(mesh(new THREE.TorusGeometry(0.17, 0.018, 6, 16), M_DARKFRAME, x, 0.19, z));
      for (let j = 0; j < 6; j++) rewardRod(g, [x, 0.19, z], [x + Math.cos(j * Math.PI / 3) * 0.15, 0.19 + Math.sin(j * Math.PI / 3) * 0.15, z], 0.004, M_MULLION);
    });
    const points = [[-0.26, 0.19, z], [-0.09, 0.42, z], [0.03, 0.19, z], [0.20, 0.44, z], [0.26, 0.19, z]];
    [[0, 1], [1, 2], [2, 0], [1, 3], [3, 2], [3, 4]].forEach(function (p) { rewardRod(g, points[p[0]], points[p[1]], 0.014, n ? M_ROSE : M_TEAL); });
    rewardRod(g, [0.20, 0.44, z], [0.18, 0.53, z], 0.012, M_DARKFRAME);
    rewardRod(g, [0.18, 0.53, z - 0.08], [0.18, 0.53, z + 0.08], 0.012, M_DARKFRAME);
    g.add(mesh(new THREE.BoxGeometry(0.13, 0.035, 0.07), M_WOOD, -0.09, 0.46, z));
  }); packRigidModel(g);
}
function propCafeStand(g) {
  const awning = new THREE.MeshStandardMaterial({ map: stripedAwningTex("#BF7952", "#FFF4DF"), roughness: 0.86 });
  awning.userData.rewardOwned = true;
  g.add(mesh(roundedBox(0.78, 0.44, 0.44, 0.06), M_CREAM, 0, 0.31, 0));
  g.add(mesh(new THREE.BoxGeometry(0.86, 0.055, 0.52), M_WOOD, 0, 0.56, 0));
  [-0.31, 0.31].forEach(function (x) {
    const wheel = mesh(new THREE.CylinderGeometry(0.095, 0.095, 0.06, 12), M_DARKFRAME, x, 0.095, 0); wheel.rotation.z = Math.PI / 2; g.add(wheel);
    rewardRod(g, [x, 0.57, -0.16], [x, 1.13, -0.16], 0.016, M_WOOD);
  });
  const cloth = mesh(new THREE.BoxGeometry(0.94, 0.055, 0.62), awning, 0, 1.12, 0.045); cloth.rotation.x = 0.18; g.add(cloth);
  g.add(mesh(new THREE.BoxGeometry(0.24, 0.21, 0.16), M_MULLION, -0.17, 0.68, -0.04));
  g.add(mesh(new THREE.CylinderGeometry(0.05, 0.04, 0.10, 10), M_WHITE, 0.14, 0.64, 0.10));
  g.add(mesh(new THREE.TorusGeometry(0.028, 0.008, 5, 8), M_WHITE, 0.198, 0.65, 0.10));
  g.add(mesh(new THREE.SphereGeometry(0.055, 8, 6), M_GOLD, 0.31, 0.615, 0.06));
  g.add(mesh(new THREE.BoxGeometry(0.32, 0.19, 0.025), M_DARKFRAME, 0, 0.35, 0.234));
  packRigidModel(g);
}
function propSidewalk(g) {
  for (let x = -1; x <= 1; x++) for (let z = -1; z <= 1; z++) {
    g.add(mesh(roundedBox(0.31, 0.045, 0.31, 0.025), (x + z) % 2 ? M_WARM_STONE : M_CREAM, x * 0.325, 0.0225, z * 0.325, false, true));
  } packRigidModel(g);
}
function propFountain(g) {
  g.add(mesh(new THREE.CylinderGeometry(0.48, 0.54, 0.18, 24), M_MARBLE, 0, 0.09, 0));
  const rim = mesh(new THREE.TorusGeometry(0.48, 0.035, 6, 24), M_MARBLE, 0, 0.19, 0); rim.rotation.x = -Math.PI / 2; g.add(rim);
  g.add(mesh(new THREE.CylinderGeometry(0.42, 0.42, 0.03, 24), M_WATER, 0, 0.20, 0));
  g.add(mesh(new THREE.CylinderGeometry(0.07, 0.11, 0.30, 10), M_MARBLE, 0, 0.31, 0));
  const jet = mesh(new THREE.CylinderGeometry(0.035, 0.06, 0.29, 8), M_GLASS_BL, 0, 0.53, 0);
  jet.userData.rewardJoint = true; g.add(jet);
  animObjects.push({ type: "fountain_spout", spout: jet }); packRigidModel(g);
}
function propBridge(g) {
  const steps = 12;
  function height(z) { return 0.12 + Math.cos(z / 0.72 * Math.PI / 2) * 0.16; }
  for (let i = 0; i < steps; i++) {
    const z = -0.66 + i * 0.12, plank = mesh(new THREE.BoxGeometry(0.61, 0.045, 0.112), M_WOOD, 0, height(z), z);
    plank.rotation.x = -Math.atan(-0.16 * Math.PI / 1.44 * Math.sin(z / 0.72 * Math.PI / 2)); g.add(plank);
  }
  [-0.28, 0.28].forEach(function (x) {
    for (let i = 0; i < 5; i++) {
      const z = -0.66 + i * 0.33; rewardRod(g, [x, height(z), z], [x, height(z) + 0.28, z], 0.020, M_WOOD);
      if (i < 4) rewardRod(g, [x, height(z) + 0.28, z], [x, height(z + 0.33) + 0.28, z + 0.33], 0.025, M_WOOD);
    }
  }); packRigidModel(g);
}
function propSculpture(g) {
  g.add(mesh(roundedBox(0.61, 0.15, 0.61, 0.04), M_MARBLE, 0, 0.075, 0));
  g.add(mesh(new THREE.BoxGeometry(0.18, 0.055, 0.015), M_GOLD, 0, 0.10, 0.313, false, false));
  const a = mesh(new THREE.TorusGeometry(0.24, 0.055, 10, 24), M_GOLD, 0, 0.45, 0); a.rotation.x = Math.PI / 2.4; g.add(a);
  const b = mesh(new THREE.TorusGeometry(0.17, 0.04, 10, 24), M_TEAL, 0.04, 0.70, 0); b.rotation.z = Math.PI / 3; g.add(b);
  packRigidModel(g);
}
