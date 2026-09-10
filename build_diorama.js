const fs = require('fs');
const path = require('path');

// Author V2 here; city_v2_life.js is inlined by this builder. Never edit the output HTML.
// Reconciled losslessly with the existing V2 scene on 2026-09-06.
const threeMinJs = fs.readFileSync(path.join(__dirname, 'vendor/three.min.js'), 'utf8');
const cityLifeJs = fs.readFileSync(path.join(__dirname, 'city_v2_life.js'), 'utf8');
const cityCrowdsJs = fs.readFileSync(path.join(__dirname, 'city_v2_crowds.js'), 'utf8');
const citySlotsJs = fs.readFileSync(path.join(__dirname, 'city_v2_slots.js'), 'utf8');
const cityRewardModelsJs = fs.readFileSync(path.join(__dirname, 'city_v2_reward_models.js'), 'utf8');
const cityCompanionsJs = fs.readFileSync(path.join(__dirname, 'city_v2_companions.js'), 'utf8');
const cityEnergyJs = fs.readFileSync(path.join(__dirname, 'city_v2_energy.js'), 'utf8');

const htmlContent = `<!DOCTYPE html>
<html lang="he">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
  <style>
    *, html, body, #stage, canvas {
      box-sizing: border-box;
      -webkit-tap-highlight-color: transparent;
      -webkit-touch-callout: none !important;
      -webkit-user-select: none !important;
      user-select: none !important;
    }
    * { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Rounded", "SF Pro Text", "Helvetica Neue", "Arial Hebrew", "Arial", sans-serif; }
    html, body { margin:0; padding:0; width:100%; height:100%; overflow:hidden; background: transparent !important; touch-action:none; }
    #stage { width:100%; height:100%; position:relative; overflow:hidden; background: transparent !important; }
    canvas { display:block; width:100% !important; height:100% !important; background: transparent !important; }
    
    /* One calm overlay layer is reserved for short, contextual speech only. */
    #diorama-overlays {
      position: absolute;
      top: 0; left: 0;
      width: 100%; height: 100%;
      pointer-events: none;
      overflow: hidden;
      z-index: 10;
    }

    /* 💬 Native Crisp Vector Speech Bubbles (Zero Pixelation / Zero Font Glitches) */
    .diorama-speech-bubble {
      position: absolute;
      top: 0; left: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 7px 16px;
      background: #ffffff;
      color: #0f172a;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Rounded", "Rubik", "Heebo", system-ui, sans-serif;
      font-size: 13px;
      font-weight: 800;
      border: 1.5px solid rgba(226, 232, 240, 0.95);
      border-radius: 999px;
      box-shadow: 0 8px 22px rgba(15, 23, 42, 0.14), 0 2px 6px rgba(15, 23, 42, 0.06);
      transform: translate3d(-50%, -100%, 0) scale(0.001);
      opacity: 0;
      transition: transform 0.28s cubic-bezier(0.34, 1.56, 0.64, 1), opacity 0.22s ease;
      pointer-events: none;
      user-select: none;
      -webkit-user-select: none;
      white-space: nowrap;
      z-index: 25;
      direction: rtl;
    }
    .diorama-speech-bubble::after {
      content: "";
      position: absolute;
      bottom: -6px;
      left: 50%;
      transform: translateX(-50%);
      width: 0; height: 0;
      border-left: 6px solid transparent;
      border-right: 6px solid transparent;
      border-top: 6px solid #ffffff;
    }
    .diorama-speech-bubble.active {
      transform: translate3d(-50%, -100%, 0) scale(1);
      opacity: 1;
    }
    .diorama-speech-bubble.closing {
      transform: translate3d(-50%, -130%, 0) scale(0.8);
      opacity: 0;
    }

    /* First-use coach mark. Its position is projected from the actual Three.js building,
       so it remains attached while the user rotates the city or the camera eases. */
    .diorama-tutorial-target {
      display: none;
      padding: 0;
      background: transparent;
      position: absolute;
      top: 0; left: 0;
      width: 68px; height: 68px;
      border: 2px solid rgba(34, 197, 94, 0.96);
      border-radius: 50%;
      box-shadow: 0 0 0 7px rgba(255,255,255,0.86), 0 10px 28px rgba(15,23,42,0.22);
      transform: translate3d(-50%, -50%, 0) scale(0.72);
      opacity: 0;
      transition: opacity 0.22s ease, transform 0.32s cubic-bezier(0.2, 0.9, 0.2, 1.15);
      will-change: left, top, transform;
      pointer-events: auto;
    }
    .diorama-tutorial-target::before {
      content: "";
      position: absolute;
      inset: -12px;
      border: 2px solid rgba(34, 197, 94, 0.62);
      border-radius: 50%;
      animation: tutorialRipple 1.65s ease-out infinite;
    }
    .diorama-tutorial-target::after {
      content: "";
      position: absolute;
      left: 50%; top: 50%;
      width: 16px; height: 16px;
      margin: -8px 0 0 -8px;
      border-radius: 50%;
      background: #ffffff;
      border: 3px solid #22C55E;
      box-shadow: 0 3px 10px rgba(15,23,42,0.22);
      animation: tutorialTap 1.65s ease-in-out infinite;
    }
    .diorama-tutorial-target.active {
      display: block;
      opacity: 1;
      transform: translate3d(-50%, -50%, 0) scale(1);
    }
    @keyframes tutorialRipple {
      0%, 24% { transform: scale(0.78); opacity: 0; }
      38% { opacity: 0.78; }
      82%, 100% { transform: scale(1.32); opacity: 0; }
    }
    @keyframes tutorialTap {
      0%, 22%, 100% { transform: scale(1); }
      34%, 45% { transform: scale(0.68); }
      62% { transform: scale(1.08); }
    }
    @media (prefers-reduced-motion: reduce) {
      .diorama-tutorial-target::before,
      .diorama-tutorial-target::after { animation: none; }
    }
  </style>
  <script>
${threeMinJs}
  </script>
</head>
<body>
  <div id="stage">
    <div id="diorama-overlays"></div>
  </div>
  <script>
    const stage = document.getElementById("stage");
    const overlaysContainer = document.getElementById("diorama-overlays");
    const scene = new THREE.Scene();

    // ========== RENDERER (illustrated daylight, transparent app integration) ==========
    const renderer = new THREE.WebGLRenderer({
      antialias: true,
      alpha: true,
      powerPreference: "default",
      precision: "highp"
    });
    renderer.setClearColor(0x000000, 0);
    renderer.setPixelRatio(Math.min(1.75, window.devicePixelRatio || 1));
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.outputEncoding = THREE.sRGBEncoding;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.03;
    stage.appendChild(renderer.domElement);

    const FR = 15.2;
    let camera = new THREE.OrthographicCamera(-FR, FR, FR, -FR, 5, 85);

    const CAM_MODES = {
      // lookX/lookZ are offset because the built area is not centred on the island: the
      // reserve sits north-east and the shops south-west, so a camera aimed at 0,0 pushes
      // the reserve off the right edge of a phone screen.
      city:     { az: Math.PI * 0.25, el: 0.58, zoom: 1.34, lookX: 0.3,  lookY: 0.6, lookZ: -0.3 },
      // District look-points sit on the actual block centres, and close enough that the
      // district fills the screen — 1.85 barely moved the camera off the city view.
      food:     { az: Math.PI * 0.25, el: 0.52, zoom: 1.95, lookX: 9.2,  lookY: 0.6, lookZ: 0 },
      shopping: { az: Math.PI * 0.25, el: 0.52, zoom: 1.95, lookX: -9.2, lookY: 0.6, lookZ: 0 },
      shop:     { az: Math.PI * 0.25, el: 0.52, zoom: 1.95, lookX: -9.2, lookY: 0.6, lookZ: 0 },
      housing:  { az: Math.PI * 0.25, el: 0.52, zoom: 1.95, lookX: 0,    lookY: 0.6, lookZ: -9.2 },
      savings:  { az: Math.PI * 0.25, el: 0.52, zoom: 2.05, lookX: 9.4,  lookY: 0.4, lookZ: -9.4 },
      transport:{ az: Math.PI * 0.25, el: 0.52, zoom: 1.95, lookX: 9.2, lookY: 0.6, lookZ: 9.2 },
      civic:    { az: Math.PI * 0.25, el: 0.54, zoom: 1.90, lookX: 0,    lookY: 0.9, lookZ: -0.4 }
    };

    let currentMode = "city";
    let currentCam = Object.assign({}, CAM_MODES.city);
    let targetCam  = Object.assign({}, CAM_MODES.city);

    function placeCam() {
      const r = 45;
      camera.position.set(
        currentCam.lookX + r * Math.cos(currentCam.el) * Math.cos(currentCam.az),
        currentCam.lookY + r * Math.sin(currentCam.el),
        currentCam.lookZ + r * Math.cos(currentCam.el) * Math.sin(currentCam.az)
      );
      camera.lookAt(currentCam.lookX, currentCam.lookY, currentCam.lookZ);
    }

    // Fit the frustum to the NARROW axis of the viewport. Fitting to the tall axis on a
    // portrait phone squeezes the horizontal half-width down to FR*aspect (~8.9 units on a
    // 420x720 screen), which cuts the shops and the reserve clean off the sides.
    let viewportWidth = 1, viewportHeight = 1, previousFrustumKey = "";
    function applyFrustum() {
      const a = viewportWidth / viewportHeight;
      const z = (currentCam && currentCam.zoom) ? currentCam.zoom : 1.0;
      const key = a + ":" + z;
      if (key === previousFrustumKey) return;
      previousFrustumKey = key;
      const halfW = (a >= 1 ? FR * a : FR) / z;
      const halfH = (a >= 1 ? FR : FR / a) / z;
      camera.left   = -halfW;
      camera.right  =  halfW;
      camera.top    =  halfH;
      camera.bottom = -halfH;
      camera.near   = 5;
      camera.far    = 85;
      camera.updateProjectionMatrix();
    }

    function resize() {
      const w = stage.clientWidth || window.innerWidth;
      const h = stage.clientHeight || window.innerHeight;
      viewportWidth = w; viewportHeight = h;
      renderer.setSize(w, h);
      applyFrustum();
      placeCam();
    }

    // ========== LIGHTING (soft illustration with readable light and shade) ==========
    // Less flat ambient light lets façades keep a warm lit face and a cool shaded face,
    // which is the depth cue that makes the reference feel illustrated rather than plastic.
    const hemiLight = new THREE.HemisphereLight(0xFFF8E8, 0x9FB2C5, 0.27);
    scene.add(hemiLight);

    const ambientLight = new THREE.AmbientLight(0xFFFDF8, 0.14);
    scene.add(ambientLight);

    const sunLight = new THREE.DirectionalLight(0xFFF3DC, 1.02);
    sunLight.position.set(-24, 38, 28);
    sunLight.castShadow = true;
    sunLight.shadow.mapSize.width = 2048;
    sunLight.shadow.mapSize.height = 2048;
    sunLight.shadow.camera.near = 10;
    sunLight.shadow.camera.far = 95;
    sunLight.shadow.camera.left = -20;
    sunLight.shadow.camera.right = 20;
    sunLight.shadow.camera.top = 20;
    sunLight.shadow.camera.bottom = -20;
    sunLight.shadow.bias = -0.00012;
    sunLight.shadow.normalBias = 0.025;
    scene.add(sunLight);

    const fillLight = new THREE.DirectionalLight(0xCDE9F5, 0.16);
    fillLight.position.set(-20, 18, -20);
    scene.add(fillLight);

    // ========== DATA & OBJECT REPOSITORIES ==========
    const root = new THREE.Group(); scene.add(root);
    const raycaster = new THREE.Raycaster();
    const mouse = new THREE.Vector2();
    const interactiveBuildings = [];
    // Repeated venues share a financial destination, but have separate picking proxies.
    const interactiveVenueInstances = [];
    const venueActors = [];
    function bindVenueActor(obj, venue, threshold) {
      obj.userData.lifeActor = true;
      obj.visible = false;
      venueActors.push({ obj: obj, venue: venue, threshold: threshold });
    }
    function visibleInScene(obj) {
      for (let p = obj; p; p = p.parent) if (!p.visible) return false;
      return true;
    }
    const interactiveCitizens  = [];
    const walkingCitizens      = [];
    const buildingRoots        = {};
    const vehicleState         = [];
    const animObjects          = [];
    const activeBubbles        = [];

    function cv(w, h) { const c = document.createElement("canvas"); c.width = w; c.height = h; return c; }
    function tex(c, rx, ry) {
      const t = new THREE.CanvasTexture(c); t.anisotropy = 8;
      if (THREE.sRGBEncoding !== undefined) t.encoding = THREE.sRGBEncoding;
      if (rx) { t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(rx, ry); }
      return t;
    }
    // Every hex in this file is authored in sRGB, but the shader treats material colours as
    // linear and gamma-encodes on the way out. Without this conversion terracotta reads as
    // pale yellow and dark asphalt as light grey — the whole city washes out.
    function C(hex) {
      const col = new THREE.Color(hex);
      return col.convertSRGBToLinear ? col.convertSRGBToLinear() : col;
    }
    function mat(c, rough, metal, emis, ei) {
      const o = { color: C(c), roughness: rough === undefined ? 0.70 : rough, metalness: metal || 0 };
      if (emis !== undefined) { o.emissive = C(emis); o.emissiveIntensity = ei === undefined ? 1 : ei; }
      return new THREE.MeshStandardMaterial(o);
    }
    function mesh(g, m, x, y, z, cast, rec) {
      const o = new THREE.Mesh(g, m); o.position.set(x || 0, y || 0, z || 0);
      o.castShadow = cast !== false; o.receiveShadow = rec !== false; return o;
    }

    // Static scenery that never moves or toggles is merged into one mesh per material at
    // the end of construction. Road markings, kerbs and lamp posts alone were ~150 draw
    // calls a frame; this build has no BufferGeometryUtils, so the concatenation is here.
    const mergeQueue = [];
    function queueForMerge(m) { mergeQueue.push(m); return m; }

    function mergeStaticScenery(owner, modelMeshes) {
      const input = modelMeshes || mergeQueue;
      if (!input.length) return 0;
      if (owner) owner.updateWorldMatrix(true, true);
      else root.updateMatrixWorld(true);
      const toLocal = owner ? new THREE.Matrix4().copy(owner.matrixWorld).invert() : null;
      const byMaterial = new Map();
      for (let i = 0; i < input.length; i++) {
        const m = input[i];
        if (!m.parent || !m.geometry) continue;
        if (!byMaterial.has(m.material)) byMaterial.set(m.material, []);
        byMaterial.get(m.material).push(m);
      }
      let saved = 0;
      byMaterial.forEach(function (meshes, material) {
        if (meshes.length < 4) return;
        const parts = [];
        let total = 0, hasUV = true;
        for (let i = 0; i < meshes.length; i++) {
          let g = meshes[i].geometry;
          g = g.index ? g.toNonIndexed() : g.clone();
          g.applyMatrix4(meshes[i].matrixWorld);
          if (toLocal) g.applyMatrix4(toLocal);
          if (!g.attributes.uv) hasUV = false;
          total += g.attributes.position.count;
          parts.push(g);
        }
        const pos = new Float32Array(total * 3);
        const nrm = new Float32Array(total * 3);
        const uvs = hasUV ? new Float32Array(total * 2) : null;
        let o3 = 0, o2 = 0;
        for (let i = 0; i < parts.length; i++) {
          const g = parts[i];
          pos.set(g.attributes.position.array, o3);
          if (g.attributes.normal) nrm.set(g.attributes.normal.array, o3);
          if (uvs && g.attributes.uv) uvs.set(g.attributes.uv.array, o2);
          o3 += g.attributes.position.count * 3;
          o2 += g.attributes.position.count * 2;
          g.dispose();
        }
        const merged = new THREE.BufferGeometry();
        merged.setAttribute("position", new THREE.BufferAttribute(pos, 3));
        merged.setAttribute("normal", new THREE.BufferAttribute(nrm, 3));
        if (uvs) merged.setAttribute("uv", new THREE.BufferAttribute(uvs, 2));
        const one = new THREE.Mesh(merged, material);
        one.castShadow = owner ? meshes.some(function (m) { return m.castShadow; }) : false;
        one.receiveShadow = true;
        one.matrixAutoUpdate = false;
        (owner || scene).add(one);
        for (let i = 0; i < meshes.length; i++) {
          meshes[i].parent.remove(meshes[i]);
          meshes[i].geometry.dispose();
        }
        saved += meshes.length - 1;
      });
      if (!modelMeshes) mergeQueue.length = 0;
      return saved;
    }

    // Batch only rigid models in their own local space. Tier visibility and moving people
    // keep their original groups; a whole car or table can move without separate prop draws.
    function packRigidModel(group) {
      const parts = [];
      group.traverse(function (o) {
        if (!o.isMesh || Array.isArray(o.material)) return;
        for (let p = o; p && p !== group; p = p.parent) if (p.userData.lifeActor || p.userData.rewardJoint) return;
        parts.push(o);
      });
      mergeStaticScenery(group, parts);
      return group;
    }

    // ========== SHAPE HELPERS ==========
    function roundedBox(w, h, d, r) {
      // Keep the bevel INSIDE the requested bounds. An outward bevel used to bury
      // windows, clock faces and signs that were correctly placed on the nominal wall.
      const bevel = Math.min(0.04, Math.min(w, h, d) * 0.16);
      const iw = w - bevel * 2, id = d - bevel * 2, depth = h - bevel * 2;
      r = Math.max(0.001, Math.min(r, Math.min(iw, id) / 2 - 0.001));
      const s = new THREE.Shape(), x = -iw / 2, y = -id / 2;
      s.moveTo(x + r, y); s.lineTo(x + iw - r, y); s.quadraticCurveTo(x + iw, y, x + iw, y + r);
      s.lineTo(x + iw, y + id - r); s.quadraticCurveTo(x + iw, y + id, x + iw - r, y + id);
      s.lineTo(x + r, y + id); s.quadraticCurveTo(x, y + id, x, y + id - r);
      s.lineTo(x, y + r); s.quadraticCurveTo(x, y, x + r, y);
      const g = new THREE.ExtrudeGeometry(s, { depth: depth, bevelEnabled: true, bevelSize: bevel, bevelThickness: bevel, bevelSegments: 2, curveSegments: 4 });
      g.rotateX(-Math.PI / 2);
      // ExtrudeGeometry is anchored at its base. Every volume in this city is positioned
      // by its centre (a 1.8-high house body sits at y = 0.9), so re-centre the geometry —
      // without this the whole city floats half a storey above its own footprint.
      g.translate(0, -depth / 2, 0);
      g.computeVertexNormals();
      return g;
    }

    // ========== PROCEDURAL TEXTURES (Hero Reference Exact Palette) ==========
    function sidewalkPaverTex() {
      const c = cv(128, 128), g = c.getContext("2d");
      g.fillStyle = "#FAF5EE"; g.fillRect(0, 0, 128, 128);
      g.strokeStyle = "#E8DFD3"; g.lineWidth = 1.5;
      for (let x = 0; x <= 128; x += 32) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, 128); g.stroke(); }
      for (let y = 0; y <= 128; y += 32) { g.beginPath(); g.moveTo(0, y); g.lineTo(128, y); g.stroke(); }
      return tex(c, 0.5, 0.5);
    }

    function signTex(title, bg, fg, fontSize) {
      const c = cv(256, 80), g = c.getContext("2d");
      g.fillStyle = bg || "#1E293B"; g.fillRect(0, 0, 256, 80);
      g.fillStyle = fg || "#FFFFFF";
      g.font = "900 " + (fontSize || 34) + "px -apple-system, BlinkMacSystemFont, sans-serif";
      g.textAlign = "center"; g.textBaseline = "middle";
      g.fillText(title, 128, 40);
      return tex(c);
    }

    function stripedAwningTex(c1, c2) {
      const c = cv(128, 128), g = c.getContext("2d");
      g.fillStyle = c1; g.fillRect(0, 0, 128, 128);
      g.fillStyle = c2;
      for (let x = 0; x < 128; x += 32) g.fillRect(x, 0, 16, 128);
      return tex(c);
    }

    function clockTex() {
      const c = cv(128, 128), g = c.getContext("2d");
      g.fillStyle = "#FFFFFF"; g.beginPath(); g.arc(64, 64, 60, 0, Math.PI * 2); g.fill();
      g.strokeStyle = "#1E293B"; g.lineWidth = 6; g.stroke();
      g.lineWidth = 4;
      for (let i = 0; i < 12; i++) {
        const a = (i / 12) * Math.PI * 2;
        g.beginPath();
        g.moveTo(64 + Math.cos(a) * 44, 64 + Math.sin(a) * 44);
        g.lineTo(64 + Math.cos(a) * 54, 64 + Math.sin(a) * 54);
        g.stroke();
      }
      g.strokeStyle = "#0F172A"; g.lineWidth = 5;
      g.beginPath(); g.moveTo(64, 64); g.lineTo(44, 42); g.stroke();
      g.lineWidth = 3;
      g.beginPath(); g.moveTo(64, 64); g.lineTo(94, 46); g.stroke();
      return tex(c);
    }

    // Material definitions
    // A compact illustration palette: warm paper-like walls, coral/blue roofs, cool slate
    // roads and layered greens. Avoiding near-black masses keeps the phone render airy.
    const M_CREAM      = mat(0xF6ECDD, 0.82);
    const M_WARM_STONE = mat(0xE8D9C6, 0.84);
    const M_ROOF_OR    = mat(0xF27755, 0.72);
    const M_ROOF_BL    = mat(0x5486CF, 0.72);
    const M_ROOF_PEACH = mat(0xFF916F, 0.74);
    const M_SLATE      = mat(0x40536C, 0.78);
    const M_GLASS_BL   = mat(0x69A9D6, 0.58, 0.05, 0x3A89C2, 0.12);
    const M_WOOD       = mat(0x9A633D, 0.88);
    const M_WHITE      = mat(0xFFFCF6, 0.76);
    const M_GOLD       = mat(0xEFB64A, 0.48, 0.55);
    const M_GRASS_LIME = mat(0x7DBB45, 0.86);
    const M_GRASS_DARK = mat(0x328A49, 0.88);
    const M_ASPHALT    = mat(0x56657A, 0.90);
    const M_WATER      = new THREE.MeshStandardMaterial({
      // A directional light plus an orthographic camera gives every point on a flat plane
      // the same half-vector, so a low roughness turns the entire lake into one specular
      // highlight — measured at (201,248,255), i.e. white. Water stays deliberately matte.
      color: C(0x2EA8DE), roughness: 0.82, metalness: 0.0
    });

    // ────────────────────────────────────────────────────────────────
    // 🌍 1. THE BEVELED DIORAMA ISLAND (Hero Reference)
    // ────────────────────────────────────────────────────────────────
    // Layer heights, from the bottom up. Everything above is stacked on these, so they
    // are the only numbers that decide what is buried and what is visible.
    const Y_GROUND = 0.00;
    const Y_GRASS  = 0.03;  // top face of the island deck — the walkable ground
    const Y_ROAD   = 0.06;  // asphalt slab centre; its top sits 0.06 above the grass
    const Y_WALK   = 0.14;  // sidewalk top, and therefore the base of every building

    // A feathered contact shadow grounds the miniature without creating a visible plane.
    // It is baked into one tiny alpha texture, so it costs a single transparent draw call.
    const islandShadowCanvas = cv(256, 256);
    const islandShadowCtx = islandShadowCanvas.getContext("2d");
    const islandShadowGradient = islandShadowCtx.createRadialGradient(128, 128, 46, 128, 128, 126);
    islandShadowGradient.addColorStop(0, "rgba(44, 68, 84, 0.26)");
    islandShadowGradient.addColorStop(0.68, "rgba(58, 79, 91, 0.13)");
    islandShadowGradient.addColorStop(1, "rgba(58, 79, 91, 0)");
    islandShadowCtx.fillStyle = islandShadowGradient;
    islandShadowCtx.fillRect(0, 0, 256, 256);
    const islandShadowMaterial = new THREE.MeshBasicMaterial({
      map: tex(islandShadowCanvas), transparent: true, depthWrite: false,
      opacity: 0.82, toneMapped: false
    });
    const islandShadow = mesh(new THREE.PlaneGeometry(31.5, 31.5), islandShadowMaterial, 0, -1.24, 0.65, false, false);
    islandShadow.rotation.x = -Math.PI / 2;
    islandShadow.renderOrder = -2;
    root.add(islandShadow);

    // Warm Sandy Earthy Bevel Side Plinth
    const earthBase = mesh(roundedBox(26.0, 1.10, 26.0, 1.2), mat(0xCDAA6B, 0.92), 0, -0.62, 0, false, true);
    root.add(earthBase);

    // Lush Green Landscape Deck (The Main Surface)
    const islandDeck = mesh(roundedBox(25.6, 0.16, 25.6, 1.1), M_GRASS_LIME, 0, Y_GRASS - 0.08, 0, false, true);
    root.add(islandDeck);

    // ────────────────────────────────────────────────────────────────
    // 🛣️ 2. STREET GRID
    // The road ring sits at ±6.0 so each district gets a block it actually fits in.
    // At ±4.2 the blocks had to be drawn straight over the road arms to hold their
    // buildings, which quietly buried half the street network under the pavement.
    // ────────────────────────────────────────────────────────────────
    const whiteMarkMat = new THREE.MeshBasicMaterial({
      color: C(0xFFFFFF),
      polygonOffset: true,
      polygonOffsetFactor: -1.5,
      polygonOffsetUnits: -4.0
    });
    const RW = 2.4;
    const ROAD_AT = 5.6;      // centreline of each arm
    const ROAD_LEN = 23.6;    // long enough to reach the corner districts
    const BLOCK_EDGE = ROAD_AT - RW / 2;  // 4.8 — where a block may start

    // Horizontal road arms cover the full length across all 4 intersections
    root.add(mesh(new THREE.BoxGeometry(ROAD_LEN, 0.06, RW), M_ASPHALT, 0, Y_ROAD, -ROAD_AT, false, true));
    root.add(mesh(new THREE.BoxGeometry(ROAD_LEN, 0.06, RW), M_ASPHALT, 0, Y_ROAD,  ROAD_AT, false, true));

    // Vertical road arms are segmented so they never overlap the horizontal arms at the 4 intersections
    const midRoadLen = (ROAD_AT - RW / 2) * 2; // 8.8
    const endRoadLen = (ROAD_LEN / 2) - (ROAD_AT + RW / 2); // 5.0
    const endRoadZ   = (ROAD_LEN / 2 + ROAD_AT + RW / 2) / 2; // 9.3

    [-ROAD_AT, ROAD_AT].forEach(function (rx) {
      root.add(mesh(new THREE.BoxGeometry(RW, 0.06, endRoadLen), M_ASPHALT, rx, Y_ROAD, -endRoadZ, false, true));
      root.add(mesh(new THREE.BoxGeometry(RW, 0.06, midRoadLen), M_ASPHALT, rx, Y_ROAD, 0, false, true));
      root.add(mesh(new THREE.BoxGeometry(RW, 0.06, endRoadLen), M_ASPHALT, rx, Y_ROAD,  endRoadZ, false, true));
    });

    // Lane dashes down the middle of each arm, skipping the intersections
    function laneDashes(along, fixed, horizontal) {
      for (let t = -11.0; t <= 11.0; t += 1.6) {
        if (Math.abs(Math.abs(t) - ROAD_AT) < 1.6) continue;   // keep junctions clear
        root.add(queueForMerge(mesh(new THREE.BoxGeometry(horizontal ? 0.75 : 0.10, 0.008, horizontal ? 0.10 : 0.75),
          whiteMarkMat, horizontal ? t : fixed, Y_ROAD + 0.034, horizontal ? fixed : t, false, false)));
      }
    }
    laneDashes(0, -ROAD_AT, true);
    laneDashes(0,  ROAD_AT, true);
    laneDashes(0, -ROAD_AT, false);
    laneDashes(0,  ROAD_AT, false);

    function addCrosswalk(cx, cz, isVert) {
      const g = new THREE.Group(); g.position.set(cx, Y_ROAD + 0.034, cz); root.add(g);
      for (let i = 0; i < 5; i++) {
        const off = -0.9 + i * 0.45;
        if (isVert) g.add(queueForMerge(mesh(new THREE.BoxGeometry(0.24, 0.008, 1.1), whiteMarkMat, off, 0, 0, false, false)));
        else        g.add(queueForMerge(mesh(new THREE.BoxGeometry(1.1, 0.008, 0.24), whiteMarkMat, 0, 0, off, false, false)));
      }
    }
    addCrosswalk(-ROAD_AT, -3.1, true);
    addCrosswalk( ROAD_AT, -3.1, true);
    addCrosswalk(-ROAD_AT,  3.1, true);
    addCrosswalk( ROAD_AT,  3.1, true);
    addCrosswalk(-3.1, -ROAD_AT, false);
    addCrosswalk( 3.1, -ROAD_AT, false);
    addCrosswalk(-3.1,  ROAD_AT, false);
    addCrosswalk( 3.1,  ROAD_AT, false);

    // Raised pedestrian pavers. Every block registers its footprint so the greenery pass
    // can scatter trees over open grass only.
    const paverMat = new THREE.MeshStandardMaterial({ map: sidewalkPaverTex(), color: C(0xF4EBDD), roughness: 0.90 });
    const pavedBlocks = [];
    function addSidewalkBlock(cx, cz, w, d) {
      const sb = mesh(roundedBox(w, 0.10, d, 0.35), paverMat, cx, Y_WALK - 0.05, cz, false, true);
      root.add(sb);
      pavedBlocks.push({ x0: cx - w / 2, x1: cx + w / 2, z0: cz - d / 2, z1: cz + d / 2 });
      return sb;
    }

    // Kerb line so the pavement reads as raised rather than painted on
    function addKerb(cx, cz, w, d) {
      const t = 0.09;
      root.add(queueForMerge(mesh(new THREE.BoxGeometry(w + t, 0.13, t), M_WARM_STONE, cx, Y_WALK - 0.07, cz - d / 2, false, false)));
      root.add(queueForMerge(mesh(new THREE.BoxGeometry(w + t, 0.13, t), M_WARM_STONE, cx, Y_WALK - 0.07, cz + d / 2, false, false)));
      root.add(queueForMerge(mesh(new THREE.BoxGeometry(t, 0.13, Math.max(0.01, d - t)), M_WARM_STONE, cx - w / 2, Y_WALK - 0.07, cz, false, false)));
      root.add(queueForMerge(mesh(new THREE.BoxGeometry(t, 0.13, Math.max(0.01, d - t)), M_WARM_STONE, cx + w / 2, Y_WALK - 0.07, cz, false, false)));
    }

    // ────────────────────────────────────────────────────────────────
    // 🧱 3. KIT OF PARTS
    // Buildings are composed from shared pieces rather than drawn one at a time, so a
    // shop can gain a storey, a balcony or a rooftop plant room as spending grows without
    // every district turning into the same beige box.
    // ────────────────────────────────────────────────────────────────
    const FLOOR_H = 1.15;

    const M_MULLION   = mat(0xF8F4EC, 0.74);
    const M_DARKFRAME = mat(0x4B5E73, 0.76);
    const M_HEDGE     = mat(0x4F9B46, 0.90);
    const M_TERRACOTTA_POT = mat(0xC97B55, 0.88);
    const M_CONCRETE  = mat(0xD7D9D5, 0.88);
    const M_CANVAS    = mat(0xF7F1E8, 0.92);
    const M_STREET_LEAF = mat(0x3F9B58, 0.86);
    const M_MARBLE_REF  = mat(0xFFF9EF, 0.52, 0.02);

    // Warm glass that can be lit from inside as the district gets busier.
    function glassMaterial(tint) {
      return new THREE.MeshStandardMaterial({
        color: C(tint || 0x9FC7F0), roughness: 0.45, metalness: 0.08,
        emissive: C(0xFFD98A), emissiveIntensity: 0.0
      });
    }
    const litGlass = [];
    function registerGlass(m) { litGlass.push(m); return m; }

    // A run of windows with mullions — the single most legible "this is a building" cue.
    function windowBand(parent, w, d, y, opts) {
      opts = opts || {};
      const inset = opts.inset === undefined ? 0.03 : opts.inset;
      const h = opts.h || 0.52;
      const g = glassMaterial(opts.tint);
      registerGlass(g);
      const faces = opts.faces || ["front", "right"];
      faces.forEach(function (f) {
        const front = (f === "front");
        const span = (front ? w : d) - 0.34;
        if (span <= 0.2) return;
        const px = front ? 0 : (w / 2 + inset);
        const pz = front ? (d / 2 + inset) : 0;
        const pane = mesh(new THREE.BoxGeometry(front ? span : 0.05, h, front ? 0.05 : span), g, px, y, pz, false, false);
        parent.add(pane);
        // Mullions
        const bars = Math.max(1, Math.round(span / 1.05));
        for (let i = 1; i < bars; i++) {
          const t = -span / 2 + (span / bars) * i;
          parent.add(mesh(new THREE.BoxGeometry(front ? 0.055 : 0.06, h + 0.02, front ? 0.06 : 0.055),
            M_MULLION, front ? t : px, y, front ? pz : t, false, false));
        }
        // Sill and head
        parent.add(mesh(new THREE.BoxGeometry(front ? span + 0.12 : 0.07, 0.055, front ? 0.07 : span + 0.12),
          M_WHITE, px, y - h / 2 - 0.03, pz, false, false));
      });
      return g;
    }

    // Full-height shopfront glazing for a ground floor.
    function storefront(parent, w, d, opts) {
      opts = opts || {};
      const g = glassMaterial(opts.tint || 0xB6D8F5);
      registerGlass(g);
      const span = w - 0.5;
      parent.add(mesh(new THREE.BoxGeometry(span, 0.74, 0.05), g, 0, 0.50, d / 2 + 0.03, false, false));
      const bars = Math.max(1, Math.round(span / 1.15));
      for (let i = 1; i < bars; i++) {
        parent.add(mesh(new THREE.BoxGeometry(0.06, 0.78, 0.07), M_MULLION,
          -span / 2 + (span / bars) * i, 0.50, d / 2 + 0.035, false, false));
      }
      // Door
      parent.add(mesh(new THREE.BoxGeometry(0.42, 0.72, 0.06), M_DARKFRAME, span / 2 - 0.30, 0.38, d / 2 + 0.05, false, false));
      parent.add(mesh(new THREE.BoxGeometry(0.05, 0.05, 0.05), M_GOLD, span / 2 - 0.13, 0.40, d / 2 + 0.09, false, false));
      // Stall riser under the glass
      parent.add(mesh(new THREE.BoxGeometry(w - 0.2, 0.16, 0.08), M_WARM_STONE, 0, 0.08, d / 2 + 0.02, false, false));
      return g;
    }

    function stripedAwning(parent, w, d, c1, c2, y) {
      const m = new THREE.MeshStandardMaterial({ map: stripedAwningTex(c1, c2), roughness: 0.85, side: THREE.DoubleSide });
      const geo = new THREE.PlaneGeometry(w - 0.18, 1, 12, 8);
      const p = geo.attributes.position, uv = geo.attributes.uv;
      for (let i = 0; i < p.count; i++) {
        const t = 1 - uv.getY(i);
        p.setXYZ(i, p.getX(i), -0.20 * (1 - Math.cos(t * Math.PI / 2)), 0.59 * Math.sin(t * Math.PI / 2));
      }
      geo.computeVertexNormals();
      const a = mesh(geo, m, 0, y + 0.06, d / 2 + 0.04); parent.add(a);
      // Curved fabric and a scalloped hem, rather than a rigid sloping slab.
      const hemGeo = new THREE.PlaneGeometry(w - 0.18, 0.11, 48, 1);
      const hp = hemGeo.attributes.position, hu = hemGeo.attributes.uv;
      for (let i = 0; i < hp.count; i++) {
        if (hu.getY(i) === 0) hp.setY(i, hp.getY(i) - 0.035 * Math.abs(Math.sin(hu.getX(i) * Math.PI * 8)));
      }
      parent.add(mesh(hemGeo, m, 0, y - 0.20, d / 2 + 0.63, false, false));
      return a;
    }

    // Small punched windows give the side and rear walls real depth when the city orbits.
    function secondaryFacade(parent, w, d) {
      [[-w / 2 - 0.061, 0, -Math.PI / 2, d], [w / 2 + 0.061, 0, Math.PI / 2, d],
       [0, -d / 2 - 0.061, Math.PI, w]].forEach(function (face) {
        const wall = new THREE.Group(); wall.position.set(face[0], 0, face[1]); wall.rotation.y = face[2]; parent.add(wall);
        [-0.23, 0.23].forEach(function (offset) {
          const x = offset * face[3];
          wall.add(mesh(new THREE.BoxGeometry(0.40, 0.53, 0.036), M_WARM_STONE, x, 0.62, 0, false, false));
          wall.add(mesh(new THREE.BoxGeometry(0.31, 0.42, 0.02), M_GLASS_BL, x, 0.62, 0.032, false, false));
          wall.add(mesh(new THREE.BoxGeometry(0.027, 0.43, 0.025), M_MULLION, x, 0.62, 0.048, false, false));
          wall.add(mesh(new THREE.BoxGeometry(0.45, 0.045, 0.12), M_CREAM, x, 0.345, 0.04, false, false));
        });
      });
    }

    function signPlate(parent, w, y, d, text, bg, fg, size) {
      const m = new THREE.MeshStandardMaterial({ map: signTex(text, bg, fg, size || 34), roughness: 0.6 });
      parent.add(mesh(new THREE.BoxGeometry(Math.min(w - 0.35, 1.9), 0.34, 0.06), m, 0, y, d / 2 + 0.06, false, false));
      // Two small spot lamps over the sign
      parent.add(mesh(new THREE.CylinderGeometry(0.035, 0.05, 0.10, 8), M_DARKFRAME, -0.55, y + 0.26, d / 2 + 0.10, false, false));
      parent.add(mesh(new THREE.CylinderGeometry(0.035, 0.05, 0.10, 8), M_DARKFRAME,  0.55, y + 0.26, d / 2 + 0.10, false, false));
    }

    // Flat roof furniture — what makes a box read as a real building from above.
    function roofDeck(parent, w, d, y, opts) {
      opts = opts || {};
      const g = new THREE.Group(); g.position.y = y; parent.add(g);
      // Parapet
      const t = 0.10, hgt = 0.20;
      g.add(mesh(new THREE.BoxGeometry(w, hgt, t), M_WARM_STONE, 0, hgt / 2, d / 2 - t / 2, false, false));
      g.add(mesh(new THREE.BoxGeometry(w, hgt, t), M_WARM_STONE, 0, hgt / 2, -d / 2 + t / 2, false, false));
      g.add(mesh(new THREE.BoxGeometry(t, hgt, d), M_WARM_STONE, w / 2 - t / 2, hgt / 2, 0, false, false));
      g.add(mesh(new THREE.BoxGeometry(t, hgt, d), M_WARM_STONE, -w / 2 + t / 2, hgt / 2, 0, false, false));
      if (opts.ac !== false) {
        g.add(mesh(roundedBox(0.44, 0.24, 0.36, 0.04), M_CONCRETE, -w / 4, 0.12, -d / 5));
        g.add(mesh(new THREE.BoxGeometry(0.34, 0.02, 0.28), M_MULLION, -w / 4, 0.25, -d / 5, false, false));
      }
      if (opts.tank) {
        g.add(mesh(new THREE.CylinderGeometry(0.20, 0.20, 0.30, 12), M_WHITE, w / 4, 0.28, d / 6));
        g.add(mesh(new THREE.BoxGeometry(0.05, 0.14, 0.05), M_DARKFRAME, w / 4 - 0.14, 0.10, d / 6, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.05, 0.14, 0.05), M_DARKFRAME, w / 4 + 0.14, 0.10, d / 6, false, false));
      }
      if (opts.vent) g.add(mesh(new THREE.CylinderGeometry(0.07, 0.09, 0.26, 8), M_CONCRETE, 0, 0.13, d / 4));
      if (opts.solar) {
        const pm = mat(0x1E3A5F, 0.35, 0.25);
        for (let i = -1; i <= 1; i += 2) {
          const pnl = mesh(new THREE.BoxGeometry(w * 0.32, 0.03, d * 0.30), pm, i * w * 0.20, 0.16, -d * 0.06);
          pnl.rotation.x = -0.35; g.add(pnl);
        }
      }
      return g;
    }

    // A square pyramid over a rectangular footprint overhangs the short side badly — the
    // cafe's roof ended up a metre and a half wider than the cafe. This is a real gable:
    // a triangular prism sized to the plan, with eaves, a ridge cap and closed ends.
    function pitchedRoof(parent, w, d, h, colorMat, y, opts) {
      opts = opts || {};
      const g = new THREE.Group(); g.position.y = y; parent.add(g);
      const ow = w + 0.26, od = d + 0.26;
      const sh = new THREE.Shape();
      sh.moveTo(-ow / 2, 0); sh.lineTo(ow / 2, 0); sh.lineTo(0, h); sh.closePath();
      const geo = new THREE.ExtrudeGeometry(sh, { depth: od, bevelEnabled: false });
      geo.translate(0, 0, -od / 2);
      g.add(mesh(geo, colorMat, 0, 0, 0));
      // Eaves fascia and ridge cap
      g.add(mesh(new THREE.BoxGeometry(ow + 0.04, 0.09, od + 0.04), colorMat, 0, -0.02, 0, false, false));
      g.add(mesh(new THREE.BoxGeometry(0.14, 0.09, od + 0.06), M_WARM_STONE, 0, h - 0.02, 0, false, false));
      // Roof courses and staggered tile joints in one draw call, including both slopes.
      const lines = [], courses = Math.max(3, Math.round(ow / 0.34));
      for (let side = -1; side <= 1; side += 2) {
        for (let row = 1; row <= courses; row++) {
          const x = side * ow * 0.5 * row / courses, yy = h * (1 - row / courses) + 0.008;
          lines.push(x, yy, -od / 2, x, yy, od / 2);
          for (let z = -od / 2 + (row % 2 ? 0.14 : 0.28); z < od / 2; z += 0.28) {
            const x0 = side * ow * 0.5 * (row - 1) / courses;
            lines.push(x, yy, z, x0, h * (1 - (row - 1) / courses) + 0.008, z);
          }
        }
      }
      const tileGeo = new THREE.BufferGeometry(); tileGeo.setAttribute("position", new THREE.Float32BufferAttribute(lines, 3));
      const tileLines = new THREE.LineSegments(tileGeo, new THREE.LineBasicMaterial({ color: colorMat.color.clone().multiplyScalar(0.74) }));
      g.add(tileLines);
      if (opts.chimney) {
        g.add(mesh(new THREE.BoxGeometry(0.26, 0.62, 0.26), mat(0x9A3412, 0.85), w * 0.28, h * 0.46, -d * 0.22));
        g.add(mesh(new THREE.BoxGeometry(0.32, 0.06, 0.32), M_SLATE, w * 0.28, h * 0.46 + 0.34, -d * 0.22, false, false));
      }
      if (opts.dormer) {
        const dm = new THREE.Group(); dm.position.set(-w * 0.18, h * 0.34, d * 0.30); g.add(dm);
        dm.add(mesh(roundedBox(0.52, 0.38, 0.34, 0.04), M_CREAM, 0, 0, 0));
        const dsh = new THREE.Shape();
        dsh.moveTo(-0.32, 0); dsh.lineTo(0.32, 0); dsh.lineTo(0, 0.26); dsh.closePath();
        const dgeo = new THREE.ExtrudeGeometry(dsh, { depth: 0.40, bevelEnabled: false });
        dgeo.translate(0, 0, -0.20);
        dm.add(mesh(dgeo, colorMat, 0, 0.19, 0));
        const gm = glassMaterial(0xA8CDEE); registerGlass(gm);
        dm.add(mesh(new THREE.BoxGeometry(0.26, 0.22, 0.04), gm, 0, 0.02, 0.19, false, false));
      }
      return g;
    }

    // Parisian mansard roof with steep slope, flat crest and round dormers
    function mansardRoof(parent, w, d, h, colorMat, y, opts) {
      opts = opts || {};
      const g = new THREE.Group(); g.position.y = y; parent.add(g);
      const ow = w + 0.18, od = d + 0.18;
      const sh = new THREE.Shape();
      sh.moveTo(-ow / 2, 0);
      sh.lineTo(-ow * 0.38, h * 0.72);
      sh.lineTo(0, h);
      sh.lineTo(ow * 0.38, h * 0.72);
      sh.lineTo(ow / 2, 0);
      sh.closePath();
      const geo = new THREE.ExtrudeGeometry(sh, { depth: od, bevelEnabled: false });
      geo.translate(0, 0, -od / 2);
      g.add(mesh(geo, colorMat, 0, 0, 0));
      g.add(mesh(new THREE.BoxGeometry(ow + 0.08, 0.08, od + 0.08), M_WARM_STONE, 0, -0.02, 0, false, false));
      if (opts.dormers !== false) {
        [-ow * 0.22, ow * 0.22].forEach(function (dx) {
          const dm = new THREE.Group(); dm.position.set(dx, h * 0.32, od / 2 - 0.02); g.add(dm);
          dm.add(mesh(roundedBox(0.42, 0.38, 0.26, 0.03), M_CREAM, 0, 0, 0));
          const gm = glassMaterial(0xBFE3FA); registerGlass(gm);
          dm.add(mesh(new THREE.BoxGeometry(0.24, 0.24, 0.04), gm, 0, 0.02, 0.14, false, false));
          const dsh = new THREE.Shape();
          dsh.moveTo(-0.25, 0); dsh.lineTo(0.25, 0); dsh.lineTo(0, 0.22); dsh.closePath();
          const dgeo = new THREE.ExtrudeGeometry(dsh, { depth: 0.30, bevelEnabled: false });
          dgeo.translate(0, 0, -0.15);
          dm.add(mesh(dgeo, colorMat, 0, 0.20, 0));
        });
      }
      return g;
    }

    // Commercial vaulted market-hall barrel roof with structural ribs
    function barrelRoof(parent, w, d, h, colorMat, y, opts) {
      opts = opts || {};
      const g = new THREE.Group(); g.position.y = y; parent.add(g);
      const ow = w + 0.14, od = d + 0.14;
      const sh = new THREE.Shape();
      const segments = 16;
      sh.moveTo(-ow / 2, 0);
      for (let i = 0; i <= segments; i++) {
        const theta = Math.PI * (1 - i / segments);
        const px = (Math.cos(theta) * ow) / 2;
        const py = Math.sin(theta) * h;
        sh.lineTo(px, py);
      }
      sh.lineTo(ow / 2, 0);
      sh.closePath();
      const geo = new THREE.ExtrudeGeometry(sh, { depth: od, bevelEnabled: false });
      geo.translate(0, 0, -od / 2);
      g.add(mesh(geo, colorMat, 0, 0, 0));
      g.add(mesh(new THREE.BoxGeometry(ow + 0.06, 0.08, od + 0.06), M_WARM_STONE, 0, -0.02, 0, false, false));
      for (let z = -od / 2 + 0.35; z <= od / 2 - 0.2; z += 0.50) {
        g.add(mesh(new THREE.BoxGeometry(ow + 0.02, 0.04, 0.04), M_DARKFRAME, 0, h * 0.94, z, false, false));
      }
      return g;
    }

    // Tiered art-deco stepped marquee crown with illuminated beacon
    function steppedMarqueeRoof(parent, w, d, h, colorMat, y, opts) {
      opts = opts || {};
      const g = new THREE.Group(); g.position.y = y; parent.add(g);
      g.add(mesh(roundedBox(w + 0.12, 0.14, d + 0.12, 0.04), M_WARM_STONE, 0, 0.07, 0));
      g.add(mesh(roundedBox(w * 0.85, 0.16, d * 0.85, 0.04), colorMat, 0, 0.22, 0));
      g.add(mesh(roundedBox(w * 0.65, 0.20, d * 0.65, 0.04), M_DARKFRAME, 0, 0.40, 0));
      const beaconMat = mat(0xEC4899, 0.3, 0, 0xEC4899, 1.8);
      const beacon = mesh(new THREE.OctahedronGeometry(0.18), beaconMat, 0, 0.60, 0);
      g.add(beacon);
      animObjects.push({ type: "beacon", mat: beaconMat, base: 0.6, range: 2.2, phase: 0 });
      return g;
    }

    // Modernist angled single-pitch monopitch roof with timber soffit
    function monopitchRoof(parent, w, d, h, colorMat, y, opts) {
      opts = opts || {};
      const g = new THREE.Group(); g.position.y = y; parent.add(g);
      const ow = w + 0.24, od = d + 0.24;
      const sh = new THREE.Shape();
      sh.moveTo(-ow / 2, 0.04);
      sh.lineTo(ow / 2, h);
      sh.lineTo(ow / 2, h + 0.10);
      sh.lineTo(-ow / 2, 0.14);
      sh.closePath();
      const geo = new THREE.ExtrudeGeometry(sh, { depth: od, bevelEnabled: false });
      geo.translate(0, 0, -od / 2);
      g.add(mesh(geo, colorMat, 0, 0, 0));
      g.add(mesh(new THREE.BoxGeometry(ow, 0.03, od), M_WOOD, 0, 0.01, 0, false, false));
      return g;
    }

    // Mediterranean domed cupola with golden finial
    function domeRoof(parent, w, d, h, colorMat, y, opts) {
      opts = opts || {};
      const g = new THREE.Group(); g.position.y = y; parent.add(g);
      g.add(mesh(roundedBox(w + 0.10, 0.14, d + 0.10, 0.04), M_WARM_STONE, 0, 0.07, 0));
      const drumR = Math.min(w, d) * 0.36;
      g.add(mesh(new THREE.CylinderGeometry(drumR, drumR, 0.22, 16), M_CREAM, 0, 0.25, 0));
      const dome = mesh(new THREE.SphereGeometry(drumR, 16, 12, 0, Math.PI * 2, 0, Math.PI * 0.5), colorMat, 0, 0.36, 0);
      g.add(dome);
      g.add(mesh(new THREE.SphereGeometry(0.12, 8, 8), M_GOLD, 0, 0.36 + drumR + 0.08, 0));
      return g;
    }

    // Rooftop dining timber pergola with climbing ivy vines
    function pergolaRoof(parent, w, d, h, colorMat, y, opts) {
      opts = opts || {};
      const g = new THREE.Group(); g.position.y = y; parent.add(g);
      g.add(mesh(roundedBox(w, 0.10, d, 0.04), M_WOOD, 0, 0.05, 0));
      g.add(mesh(new THREE.BoxGeometry(w, 0.22, 0.05), M_MULLION, 0, 0.16, d / 2 - 0.03, false, false));
      g.add(mesh(new THREE.BoxGeometry(w, 0.22, 0.05), M_MULLION, 0, 0.16, -d / 2 + 0.03, false, false));
      g.add(mesh(new THREE.BoxGeometry(0.05, 0.22, d), M_MULLION, -w / 2 + 0.03, 0.16, 0, false, false));
      g.add(mesh(new THREE.BoxGeometry(0.05, 0.22, d), M_MULLION,  w / 2 - 0.03, 0.16, 0, false, false));
      const pw = w * 0.76, pd = d * 0.76;
      [[-pw/2, -pd/2], [pw/2, -pd/2], [-pw/2, pd/2], [pw/2, pd/2]].forEach(function (c) {
        g.add(mesh(new THREE.BoxGeometry(0.06, 0.70, 0.06), M_WOOD, c[0], 0.45, c[1], false, false));
      });
      for (let rx = -pw / 2 - 0.08; rx <= pw / 2 + 0.08; rx += 0.24) {
        g.add(mesh(new THREE.BoxGeometry(0.04, 0.06, pd + 0.22), M_WOOD, rx, 0.82, 0, false, false));
      }
      for (let i = 0; i < 5; i++) {
        g.add(mesh(new THREE.SphereGeometry(0.11, 6, 6), M_HEDGE, -pw / 2 + i * (pw / 4), 0.86, (i % 2 ? 0.08 : -0.08), false, false));
      }
      return g;
    }

    // Sleek minimalist floating cantilever roof with recessed solar panels
    function modernCantileverRoof(parent, w, d, h, colorMat, y, opts) {
      opts = opts || {};
      const g = new THREE.Group(); g.position.y = y; parent.add(g);
      const ow = w + 0.32, od = d + 0.32;
      g.add(mesh(roundedBox(ow, 0.09, od, 0.03), M_DARKFRAME, 0, 0.05, 0));
      g.add(mesh(new THREE.BoxGeometry(ow - 0.04, 0.02, od - 0.04), M_WOOD, 0, 0.00, 0, false, false));
      if (opts.solar !== false) {
        const sm = mat(0x1E3A5F, 0.35, 0.25);
        g.add(mesh(new THREE.BoxGeometry(ow * 0.65, 0.02, od * 0.65), sm, 0, 0.10, 0, false, false));
      }
      g.add(mesh(new THREE.CylinderGeometry(0.015, 0.025, 0.85, 6), M_MULLION, -w * 0.30, 0.50, -d * 0.30, false, false));
      g.add(mesh(new THREE.SphereGeometry(0.04, 6, 6), mat(0x38BDF8, 0.3, 0, 0x38BDF8, 1.5), -w * 0.30, 0.94, -d * 0.30, false, false));
      return g;
    }

    // Street bench, used on the plaza and in the park
    function addBenchAt(bx, bz, rotY, y) {
      const g = new THREE.Group(); g.position.set(bx, y === undefined ? Y_WALK : y, bz); g.rotation.y = rotY || 0;
      g.add(mesh(new THREE.BoxGeometry(1.05, 0.07, 0.32), M_WOOD, 0, 0.30, 0, false, false));
      g.add(mesh(new THREE.BoxGeometry(1.05, 0.28, 0.06), M_WOOD, 0, 0.45, -0.13, false, false));
      g.add(mesh(new THREE.BoxGeometry(0.07, 0.28, 0.28), M_DARKFRAME, -0.44, 0.15, 0, false, false));
      g.add(mesh(new THREE.BoxGeometry(0.07, 0.28, 0.28), M_DARKFRAME,  0.44, 0.15, 0, false, false));
      root.add(g);
      return g;
    }

    // ---- ground-level props ----
    function planterBox(parent, x, z, kind) {
      const g = new THREE.Group(); g.position.set(x, 0, z); parent.add(g);
      g.add(mesh(roundedBox(0.42, 0.24, 0.42, 0.05), M_TERRACOTTA_POT, 0, 0.12, 0));
      if (kind === "shrub") {
        g.add(mesh(new THREE.SphereGeometry(0.22, 8, 8), M_HEDGE, 0, 0.36, 0));
      } else if (kind === "tree") {
        g.add(mesh(new THREE.CylinderGeometry(0.033, 0.052, 0.57, 7), M_WOOD, 0, 0.51, 0, false, false));
        [[0, 0.93, 0, 0.27], [-0.18, 0.78, 0.02, 0.22], [0.15, 0.86, -0.04, 0.23]].forEach(function (p) {
          const crown = mesh(new THREE.DodecahedronGeometry(p[3], 0), M_STREET_LEAF, p[0], p[1], p[2]);
          crown.scale.y = 1.12; g.add(crown);
        });
      } else {
        [0xEF4444, 0xFACC15, 0xEC4899, 0xF97316].forEach(function (c, i) {
          const a = (i / 4) * Math.PI * 2;
          g.add(mesh(new THREE.SphereGeometry(0.06, 6, 6), mat(c, 0.7), Math.cos(a) * 0.12, 0.28, Math.sin(a) * 0.12, false, false));
        });
      }
      return g;
    }

    function bollard(parent, x, z) {
      parent.add(mesh(new THREE.CylinderGeometry(0.05, 0.06, 0.34, 8), M_DARKFRAME, x, 0.17, z, false, false));
      parent.add(mesh(new THREE.SphereGeometry(0.055, 8, 8), M_GOLD, x, 0.35, z, false, false));
    }

    function hedgeRow(parent, x, z, w, d) {
      parent.add(mesh(roundedBox(w, 0.34, d, 0.10), M_HEDGE, x, 0.17, z));
    }

    function crateStack(parent, x, z) {
      const g = new THREE.Group(); g.position.set(x, 0, z); parent.add(g);
      g.add(mesh(roundedBox(0.34, 0.22, 0.30, 0.03), M_WOOD, 0, 0.11, 0));
      g.add(mesh(roundedBox(0.30, 0.20, 0.28, 0.03), M_WOOD, 0.04, 0.32, 0.03));
      [0xEF4444, 0xFACC15, 0xF97316].forEach(function (c, i) {
        g.add(mesh(new THREE.SphereGeometry(0.055, 6, 6), mat(c, 0.7), -0.08 + i * 0.08, 0.45, 0.03, false, false));
      });
      return g;
    }

    function aFrameBoard(parent, x, z, rotY) {
      const g = new THREE.Group(); g.position.set(x, 0, z); g.rotation.y = rotY || 0; parent.add(g);
      const bm = mat(0x27313F, 0.8);
      const l = mesh(new THREE.BoxGeometry(0.40, 0.52, 0.04), bm, 0, 0.28, 0.05); l.rotation.x = 0.22;
      const r = mesh(new THREE.BoxGeometry(0.40, 0.52, 0.04), bm, 0, 0.28, -0.05); r.rotation.x = -0.22;
      g.add(l, r);
      return g;
    }

    function trashBin(parent, x, z) {
      parent.add(mesh(new THREE.CylinderGeometry(0.13, 0.11, 0.34, 10), M_DARKFRAME, x, 0.17, z, false, false));
      parent.add(mesh(new THREE.CylinderGeometry(0.145, 0.145, 0.04, 10), M_SLATE, x, 0.36, z, false, false));
    }

    // ---- tier 0: a plot that has not been built on yet ----
    function hoardingPlot(parent, w, d) {
      const g = new THREE.Group(); parent.add(g);
      g.add(mesh(roundedBox(w, 0.07, d, 0.10), mat(0xB9AE99, 0.95), 0, 0.035, 0, false, true));
      // Site hoarding on two sides
      const bm = mat(0xE8E2D6, 0.9);
      g.add(mesh(new THREE.BoxGeometry(w, 0.46, 0.05), bm, 0, 0.30, d / 2, false, false));
      g.add(mesh(new THREE.BoxGeometry(0.05, 0.46, d), bm, -w / 2, 0.30, 0, false, false));
      // Signpost
      g.add(mesh(new THREE.CylinderGeometry(0.035, 0.035, 0.80, 6), M_WOOD, -w / 4, 0.40, d / 2 - 0.30, false, false));
      g.add(mesh(new THREE.BoxGeometry(0.62, 0.34, 0.05), M_CANVAS, -w / 4, 0.72, d / 2 - 0.28, false, false));
      // Cone
      g.add(mesh(new THREE.ConeGeometry(0.09, 0.30, 10), mat(0xF97316, 0.65), w / 4, 0.15, d / 2 - 0.35, false, false));
      g.add(mesh(new THREE.BoxGeometry(0.22, 0.025, 0.22), M_DARKFRAME, w / 4, 0.02, d / 2 - 0.35, false, false));
      // Scaffold frame and a pallet of materials, so an unspent category reads as a site
      // waiting to be built rather than as a hole in the city.
      const sm = mat(0xE0A33C, 0.7);
      const sw = Math.min(w, d) * 0.62, sh2 = 0.95;
      [[-sw / 2, -sw / 2], [sw / 2, -sw / 2], [-sw / 2, sw / 2], [sw / 2, sw / 2]].forEach(function (c) {
        g.add(mesh(new THREE.BoxGeometry(0.06, sh2, 0.06), sm, c[0], sh2 / 2, c[1] - 0.25, false, false));
      });
      [0.34, 0.68].forEach(function (yy) {
        g.add(mesh(new THREE.BoxGeometry(sw + 0.06, 0.05, 0.05), sm, 0, yy, -sw / 2 - 0.25, false, false));
        g.add(mesh(new THREE.BoxGeometry(sw + 0.06, 0.05, 0.05), sm, 0, yy, sw / 2 - 0.25, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.05, 0.05, sw), sm, -sw / 2, yy, -0.25, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.05, 0.05, sw), sm, sw / 2, yy, -0.25, false, false));
      });
      g.add(mesh(new THREE.BoxGeometry(sw, 0.04, sw * 0.7), M_WOOD, 0, 0.71, -0.25, false, false));
      g.add(mesh(roundedBox(0.44, 0.20, 0.34, 0.03), mat(0xB08968, 0.9), -w / 4 + 0.1, 0.10, -d / 2 + 0.42, false, false));
      g.add(mesh(roundedBox(0.40, 0.18, 0.30, 0.03), mat(0xB08968, 0.9), -w / 4 + 0.14, 0.29, -d / 2 + 0.45, false, false));
      return g;
    }

    // ---- tier 1: a market stall / street cart ----
    function marketStall(parent, c1, c2) {
      const g = new THREE.Group(); parent.add(g);
      g.add(mesh(roundedBox(1.30, 0.62, 0.80, 0.05), M_WOOD, 0, 0.31, 0));
      g.add(mesh(new THREE.BoxGeometry(1.40, 0.07, 0.92), M_WARM_STONE, 0, 0.66, 0, false, false));
      const canopy = new THREE.MeshStandardMaterial({ map: stripedAwningTex(c1 || "#EF4444", c2 || "#FFFFFF"), roughness: 0.85 });
      g.add(mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.75, 6), M_DARKFRAME, -0.58, 1.03, -0.34, false, false));
      g.add(mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.75, 6), M_DARKFRAME,  0.58, 1.03, -0.34, false, false));
      g.add(mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.75, 6), M_DARKFRAME, -0.58, 1.03,  0.34, false, false));
      g.add(mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.75, 6), M_DARKFRAME,  0.58, 1.03,  0.34, false, false));
      const top = mesh(new THREE.ConeGeometry(1.10, 0.40, 4), canopy, 0, 1.58, 0);
      top.rotation.y = Math.PI / 4;
      g.add(top);
      crateStack(g, 0.74, 0.42);
      return g;
    }


    // ────────────────────────────────────────────────────────────────
    // 🏗️ 3b. SPENDING BUILDS THE CITY
    // Ported from the v1 map: every category has a baseline, and what you spend against
    // that baseline decides what stands on the plot — an empty site, a street stall, a
    // shop, a branch with a storey above it, or a full block. The building is the month.
    // ────────────────────────────────────────────────────────────────
    const CATEGORY_BASELINES = {
      food_super: 900,         // the weekly shop is the largest food line
      food_bistro: 450,
      food_coffee: 200,        // 60 is a stall, 600 is a habit
      food_wolt: 250,
      shop_boutique: 450,
      shop_tech: 350,
      shop_travel: 900,
      shop_arcade: 200,
      house_tower: 4000,
      house_util: 400,
      house_subs: 120,
      museum_curiosities: 250,
      health_pharmacy: 350,
      city_sorting_hub: 300,
      finance_bank: 250
    };

    // 0 empty plot · 1 stall · 2 single storey · 3 two storeys · 4 full block
    function tierFor(id, amount) {
      if (!amount || amount <= 0) return 0;
      // (Baselines are still used below for window-glow activity, but no longer for building
      // size — size is now proportion-based so the skyline reflects WHERE you spent most.)
      return 2; // legacy path, replaced by applyBuildingActivity's share logic
    }

    // Fallback for older payloads that do not include district state.
    // The plot always has a recognisable presence, but zero spend is only a small stall.
    function tierForShare(share) {
      if (share <= 0)    return 1;   // nothing spent → category stall
      if (share < 0.08)  return 2;   // < 8 % of spending  → compact
      if (share < 0.22)  return 3;   // 8–22 %             → mid-rise
      return 4;                       // > 22 %             → landmark
    }

    const cityBuildings = {};

    // Hit proxy: an invisible box covering the whole plot, so a tap lands on the building
    // whatever tier it is currently showing. Scaling or hiding a body mesh would otherwise
    // move the tap target around underneath the user's finger.
    function hitProxy(w, h, d) {
      const m = new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, depthWrite: false, colorWrite: false });
      const box = mesh(new THREE.BoxGeometry(w, h, d), m, 0, h / 2, 0, false, false);
      return box;
    }

    /**
     * cfg: { id, district, name, trend, x, z, rotY, w, d, body, roof, accent,
     *        awning:[c1,c2], sign:{text,bg,fg}, kind:'shop'|'house'|'civic', maxTier }
     */
    function makeBuilding(cfg) {
      const g = new THREE.Group();
      g.position.set(cfg.x, Y_WALK, cfg.z);
      if (cfg.rotY) g.rotation.y = cfg.rotY;
      root.add(g);

      const w = cfg.w, d = cfg.d;
      const bodyMat = mat(cfg.body, 0.74);
      const roofMat = cfg.roof ? mat(cfg.roof, 0.62) : M_SLATE;

      // ---- tier 0 ----
      const plot = new THREE.Group(); g.add(plot);
      hoardingPlot(plot, w, d);
      makeCrew(plot, w, d);

      // ---- tier 1 ----
      const stall = new THREE.Group(); g.add(stall);
      if (typeof CUSTOM_STALLS !== "undefined" && CUSTOM_STALLS[cfg.id]) {
        CUSTOM_STALLS[cfg.id](stall, w, d);
      } else {
        marketStall(stall, cfg.awning ? cfg.awning[0] : "#EF4444", cfg.awning ? cfg.awning[1] : "#FFFFFF");
      }

      // ---- tiers 2+ : the shell ----
      const shell = new THREE.Group(); g.add(shell);

      const ground = new THREE.Group(); shell.add(ground);
      ground.add(mesh(roundedBox(w, FLOOR_H, d, 0.10), bodyMat, 0, FLOOR_H / 2, 0));
      secondaryFacade(ground, w, d);
      if (typeof CUSTOM_FACADES !== "undefined" && CUSTOM_FACADES[cfg.id]) {
        CUSTOM_FACADES[cfg.id](ground, w, d, cfg, bodyMat);
      } else if (cfg.kind === "house") {
        // Houses get punched windows and a front door rather than a shopfront.
        const gm = glassMaterial(0xA8CDEE); registerGlass(gm);
        ground.add(mesh(new THREE.BoxGeometry(0.42, 0.46, 0.05), gm, -w * 0.26, 0.66, d / 2 + 0.03, false, false));
        ground.add(mesh(new THREE.BoxGeometry(0.06, 0.50, 0.06), M_MULLION, -w * 0.26, 0.66, d / 2 + 0.05, false, false));
        ground.add(mesh(new THREE.BoxGeometry(0.44, 0.72, 0.06), mat(cfg.accent || 0x1E3A5F, 0.6), w * 0.24, 0.42, d / 2 + 0.03, false, false));
        ground.add(mesh(new THREE.SphereGeometry(0.035, 6, 6), M_GOLD, w * 0.24 + 0.14, 0.44, d / 2 + 0.07, false, false));
        // Front step
        ground.add(mesh(new THREE.BoxGeometry(0.62, 0.08, 0.26), M_WARM_STONE, w * 0.24, 0.04, d / 2 + 0.16, false, false));
      } else {
        storefront(ground, w, d, { tint: cfg.glass });
        if (cfg.awning) stripedAwning(ground, w, d, cfg.awning[0], cfg.awning[1], 0.98);
      }

      // Upper storeys, revealed one at a time as spending grows
      const floors = [];
      for (let i = 0; i < 2; i++) {
        const f = new THREE.Group();
        f.position.y = FLOOR_H + i * FLOOR_H;
        shell.add(f);
        if (typeof CUSTOM_FLOORS !== "undefined" && CUSTOM_FLOORS[cfg.id]) {
          CUSTOM_FLOORS[cfg.id](f, w, d, i, cfg, bodyMat);
        } else {
          f.add(mesh(roundedBox(w - (cfg.kind === "house" ? 0.10 : 0.04), FLOOR_H, d - (cfg.kind === "house" ? 0.10 : 0.04), 0.09),
            i === 0 ? bodyMat : mat(cfg.accent || cfg.body, 0.74), 0, FLOOR_H / 2, 0));
          windowBand(f, w, d, FLOOR_H * 0.55, { tint: cfg.glass, faces: ["front"] });
          if (i === 0 && cfg.balcony) {
            f.add(mesh(new THREE.BoxGeometry(w * 0.62, 0.07, 0.44), M_WARM_STONE, 0, FLOOR_H * 0.20, d / 2 + 0.20, false, false));
            f.add(mesh(new THREE.BoxGeometry(w * 0.62, 0.26, 0.05), M_MULLION, 0, FLOOR_H * 0.20 + 0.16, d / 2 + 0.40, false, false));
            f.add(mesh(new THREE.SphereGeometry(0.13, 6, 6), M_STREET_LEAF, -w * 0.22, FLOOR_H * 0.20 + 0.16, d / 2 + 0.28, false, false));
          }
        }
        secondaryFacade(f, w, d);
        floors.push(f);
      }

      // Signage sits on the ground floor fascia for shops, above the door for civic blocks
      if (cfg.sign) signPlate(ground, w, cfg.kind === "house" ? 0.95 : 1.02, d, cfg.sign.text, cfg.sign.bg, cfg.sign.fg, cfg.sign.size);

      // Roofs: one per height the building can end up at
      const roofs = [];
      for (let t = 0; t < 3; t++) {
        const y = FLOOR_H * (t + 1);
        let r;
        if (cfg.roofStyle === "mansard") {
          r = mansardRoof(shell, w, d, 0.82, roofMat, y, { dormers: true });
        } else if (cfg.roofStyle === "barrel") {
          r = barrelRoof(shell, w, d, 0.62, roofMat, y);
        } else if (cfg.roofStyle === "stepped") {
          r = steppedMarqueeRoof(shell, w, d, 0.70, roofMat, y);
        } else if (cfg.roofStyle === "monopitch") {
          r = monopitchRoof(shell, w, d, 0.72, roofMat, y);
        } else if (cfg.roofStyle === "dome") {
          r = domeRoof(shell, w, d, 0.78, roofMat, y);
        } else if (cfg.roofStyle === "pergola") {
          r = pergolaRoof(shell, w, d, 0.78, roofMat, y);
        } else if (cfg.roofStyle === "modern_cantilever") {
          r = modernCantileverRoof(shell, w, d, 0.58, roofMat, y, { solar: cfg.solar });
        } else if (cfg.kind === "house" || cfg.roofStyle === "pitch") {
          r = pitchedRoof(shell, w, d, cfg.kind === "house" ? 0.92 : 0.80, roofMat, y,
            { chimney: cfg.chimney && t === 0, dormer: cfg.kind === "house" && t > 0 });
        } else {
          r = roofDeck(shell, w, d, y, { tank: t >= 1, vent: t >= 1, solar: cfg.solar && t >= 1, ac: true });
        }
        roofs.push(r);
      }

      // Street-level dressing, revealed with the tiers so a busy district feels busy
      const dressing = [];
      (cfg.props || []).forEach(function (pr) {
        const holder = new THREE.Group(); g.add(holder);
        if (pr.type === "planter") planterBox(holder, pr.x, pr.z, pr.kind);
        else if (pr.type === "hedge") hedgeRow(holder, pr.x, pr.z, pr.w, pr.d);
        else if (pr.type === "crates") crateStack(holder, pr.x, pr.z);
        else if (pr.type === "aframe") aFrameBoard(holder, pr.x, pr.z, pr.rotY);
        else if (pr.type === "bin") trashBin(holder, pr.x, pr.z);
        else if (pr.type === "bollards") { for (let i = -1; i <= 1; i++) bollard(holder, pr.x + i * 0.5, pr.z); }
        dressing.push({ obj: holder, from: pr.from === undefined ? 2 : pr.from });
      });

      // What this building actually is, beyond a sign: mannequins, crates, a dish, scooters.
      if (typeof CHARACTER !== "undefined" && CHARACTER[cfg.id]) {
        try { CHARACTER[cfg.id](ground, w, d); } catch (e) { console.warn("character " + cfg.id, e); }
      }

      // Batch each independently visible tier, not the whole building. Guests stay separate.
      [stall, ground].concat(floors, roofs, dressing.map(function (p) { return p.obj; })).forEach(packRigidModel);
      const proxy = hitProxy(w + 0.2, FLOOR_H * 3.2, d + 0.2);
      proxy.userData = { id: cfg.id, district: cfg.district, name: cfg.name, amount: 0, trend: cfg.trend };
      g.add(proxy);
      interactiveBuildings.push(proxy);
      buildingRoots[cfg.id] = g;

      const rec = {
        id: cfg.id, group: g, shell: shell, plot: plot, stall: stall,
        floors: floors, roofs: roofs, dressing: dressing, proxy: proxy, ground: ground,
        maxTier: cfg.maxTier === undefined ? 4 : cfg.maxTier,
        // Every category has a place from day one. With no spend that place is deliberately
        // a small, recognisable stall; real buildings must be earned by real transactions.
        minTier: 1, tier: -1
      };
      proxy.userData.shell = shell;
      cityBuildings[cfg.id] = rec;
      // Start quietly while the native payload is loading, then grow only what this month used.
      setBuildingTier(rec, 1);
      return rec;
    }

    // Things that are mid-build: newly revealed storeys grow out of the ground so the
    // moment a category crosses a threshold is something you can actually see happen.
    const risingParts = [];
    function raise(obj) {
      if (!obj) return;
      obj.scale.set(1, 0.02, 1);
      risingParts.push(obj);
    }
    function stepRising(dt) {
      for (let i = risingParts.length - 1; i >= 0; i--) {
        const o = risingParts[i];
        const y = o.scale.y + (1 - o.scale.y) * Math.min(1, dt * 3.2);
        o.scale.set(1, y, 1);
        if (y > 0.995) { o.scale.set(1, 1, 1); risingParts.splice(i, 1); }
      }
    }

    function setBuildingTier(rec, tier) {
      tier = Math.max(rec.minTier || 0, Math.min(rec.maxTier, tier));
      if (rec.tier === tier) return;
      const previous = rec.tier;
      rec.tier = tier;
      rec.plot.visible = (tier === 0);
      rec.stall.visible = (tier === 1);
      rec.shell.visible = (tier >= 2);
      // storeys above ground: tier 2 -> 0, tier 3 -> 1, tier 4 -> 2
      const upper = Math.max(0, tier - 2);
      rec.floors.forEach(function (f, i) {
        const want = i < upper;
        if (want && !f.visible && previous >= 0) raise(f);
        f.visible = want;
      });
      rec.roofs.forEach(function (r, i) { r.visible = (i === upper); });
      rec.dressing.forEach(function (dr) { dr.obj.visible = tier >= dr.from; });
      // Going from a plot or a stall to a real building is worth showing.
      if (previous >= 0 && tier > previous && tier >= 2) raise(rec.shell);
    }


    // ────────────────────────────────────────────────────────────────
    // 👥 3c. PEOPLE, COURIERS AND BUILDERS
    // The v1 map was alive — walkers with dogs, Wolt riders, a busker, builders on the
    // empty plots. Without them the island reads as an architectural model rather than
    // a place where money is being spent.
    // ────────────────────────────────────────────────────────────────
    const M_SKIN = mat(0xF6C88A, 0.82);
    const M_SKIN2 = mat(0xC98C56, 0.82);

    function makeFigure(opts) {
      opts = opts || {};
      const fig = new THREE.Group();
      fig.name = opts.seated ? "seated-cafe-guest" : "articulated-citizen";
      const shirt = mat(opts.shirt || 0x3B82F6, 0.76);
      const pants = mat(opts.pants || 0x1E293B, 0.86);
      const skin = opts.dark ? M_SKIN2 : M_SKIN;
      const hipY = opts.seated ? 0.29 : 0.43;
      // Joint origins, not the centres of box legs: feet stay below knees when walking.
      const torso = new THREE.Group(); torso.position.y = hipY + 0.14; fig.add(torso);
      const body = mesh(new THREE.CylinderGeometry(0.115, 0.092, 0.28, 8), shirt, 0, 0, 0);
      body.scale.z = 0.64; torso.add(body);
      torso.add(mesh(new THREE.CylinderGeometry(0.034, 0.038, 0.07, 8), skin, 0, 0.17, 0, false, false));
      const head = mesh(new THREE.SphereGeometry(0.085, 10, 8), skin, 0, 0.255, 0.005);
      head.scale.set(0.88, 1.13, 0.94); torso.add(head);
      torso.add(mesh(new THREE.SphereGeometry(0.020, 6, 5), skin, 0, 0.245, 0.080, false, false));
      if (opts.hair !== false) {
        torso.add(mesh(new THREE.SphereGeometry(0.083, 10, 8, 0, Math.PI * 2, 0, Math.PI * 0.55),
          mat(opts.hair || 0x3B2412, 0.9), 0, 0.291, -0.004, false, false));
      }
      if (opts.cap) {
        const capMat = mat(opts.cap, 0.7);
        torso.add(mesh(new THREE.SphereGeometry(0.09, 10, 8, 0, Math.PI * 2, 0, Math.PI * 0.5), capMat, 0, 0.305, 0, false, false));
        torso.add(mesh(new THREE.BoxGeometry(0.14, 0.016, 0.08), capMat, 0, 0.305, 0.085, false, false));
      }
      if (opts.bag) {
        const bagMat = mat(opts.bag, 0.8);
        torso.add(mesh(new THREE.BoxGeometry(0.16, 0.19, 0.085), bagMat, 0, 0.01, -0.12, false, false));
        [-0.06, 0.06].forEach(function (x) {
          torso.add(mesh(new THREE.BoxGeometry(0.02, 0.23, 0.02), bagMat, x, 0.02, 0.072, false, false));
        });
      }
      function arm(side) {
        const a = new THREE.Group(); a.position.set(side * 0.132, 0.105, 0); torso.add(a);
        a.add(mesh(new THREE.CylinderGeometry(0.036, 0.028, 0.14, 7), shirt, 0, -0.065, 0, false, false));
        const forearm = new THREE.Group(); forearm.position.y = -0.13; forearm.rotation.x = -0.18; a.add(forearm);
        forearm.add(mesh(new THREE.CylinderGeometry(0.025, 0.021, 0.13, 7), skin, 0, -0.06, 0, false, false));
        forearm.add(mesh(new THREE.SphereGeometry(0.027, 7, 6), skin, 0, -0.135, 0, false, false));
        if (opts.seated) { a.rotation.x = -0.62; forearm.rotation.x = -0.8; }
        return a;
      }
      function leg(side) {
        const l = new THREE.Group(); l.position.set(side * 0.058, hipY, 0); fig.add(l);
        l.add(mesh(new THREE.CylinderGeometry(0.043, 0.033, 0.20, 7), pants, 0, -0.10, 0, false, false));
        const knee = new THREE.Group(); knee.position.y = -0.20; l.add(knee);
        knee.add(mesh(new THREE.CylinderGeometry(0.034, 0.027, 0.19, 7), pants, 0, -0.095, 0, false, false));
        knee.add(mesh(new THREE.BoxGeometry(0.075, 0.052, 0.125), M_DARKFRAME, 0, -0.205, 0.028, false, false));
        if (opts.seated) { l.rotation.x = -Math.PI / 2; knee.rotation.x = Math.PI / 2; }
        return { hip: l, knee: knee };
      }
      const armL = arm(-1), armR = arm(1), left = leg(-1), right = leg(1);
      fig.userData = { legL: left.hip, legR: right.hip, kneeL: left.knee, kneeR: right.knee,
        armL: armL, armR: armR, torso: torso, body: body };
      return fig;
    }

    function makeDog(color) {
      const g = new THREE.Group();
      const m = mat(color || 0xD9A441, 0.85);
      g.add(mesh(roundedBox(0.13, 0.13, 0.30, 0.05), m, 0, 0.19, 0, false, false));
      g.add(mesh(new THREE.SphereGeometry(0.085, 8, 8), m, 0, 0.29, 0.18, false, false));
      g.add(mesh(roundedBox(0.045, 0.10, 0.03, 0.01), mat(0x8A5A20, 0.85), -0.06, 0.35, 0.17, false, false));
      g.add(mesh(roundedBox(0.045, 0.10, 0.03, 0.01), mat(0x8A5A20, 0.85),  0.06, 0.35, 0.17, false, false));
      const tail = mesh(new THREE.CylinderGeometry(0.018, 0.024, 0.18, 5), m, 0, 0.26, -0.17, false, false);
      tail.rotation.x = -0.9; g.add(tail);
      [[-0.05, 0.10], [0.05, 0.10], [-0.05, -0.10], [0.05, -0.10]].forEach(function (p) {
        g.add(mesh(new THREE.CylinderGeometry(0.022, 0.022, 0.14, 5), m, p[0], 0.07, p[1], false, false));
      });
      return g;
    }

    // Delivery rider. The city's most recognisable everyday spend after the supermarket.
    function makeCourier(color) {
      const g = new THREE.Group();
      const body = mat(color || 0x00C2E8, 0.35, 0.35);
      g.add(mesh(roundedBox(0.95, 0.20, 0.30, 0.08), body, 0, 0.22, 0, false, false));
      g.add(mesh(new THREE.BoxGeometry(0.48, 0.04, 0.24), mat(0x18181B, 0.9), 0, 0.33, 0, false, false));
      g.add(mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.58, 6), mat(0x1E293B, 0.5), 0.34, 0.50, 0, false, false));
      g.add(mesh(new THREE.BoxGeometry(0.035, 0.035, 0.28), mat(0x18181B, 0.8), 0.34, 0.72, 0, false, false));
      g.add(mesh(new THREE.SphereGeometry(0.055, 8, 8), M_WHITE, 0.38, 0.58, 0, false, false));
      // The rider uses the same human proportions and bent knees as the cafe guests.
      const rider = makeFigure({ seated: true, shirt: color || 0x00C2E8, cap: 0x155E75, hair: false });
      rider.position.set(-0.06, 0.04, 0); rider.rotation.y = Math.PI / 2; g.add(rider);
      g.add(mesh(roundedBox(0.30, 0.32, 0.30, 0.04), body, -0.30, 0.58, 0, false, false));
      g.add(mesh(new THREE.BoxGeometry(0.20, 0.20, 0.02), M_WHITE, -0.30, 0.58, 0.16, false, false));
      [[-0.36], [0.36]].forEach(function (p) {
        const wh = mesh(new THREE.CylinderGeometry(0.145, 0.145, 0.08, 12), mat(0x09090B, 0.9), p[0], 0.145, 0, false, false);
        wh.rotation.x = Math.PI / 2; g.add(wh);
      });
      // Traffic headings assume +z is forward, while the scooter is authored along +x.
      const vehicle = new THREE.Group(); g.rotation.y = -Math.PI / 2; vehicle.add(g);
      return packRigidModel(vehicle);
    }

    function makeWorker(vest) {
      const g = new THREE.Group();
      const vestMat = mat(vest || 0xF97316, 0.7);
      const torso = new THREE.Group(); torso.position.y = 0.36; g.add(torso);
      torso.add(mesh(roundedBox(0.23, 0.27, 0.14, 0.03), vestMat, 0, 0, 0, false, false));
      torso.add(mesh(new THREE.BoxGeometry(0.24, 0.045, 0.15), mat(0xE2E8F0, 0.25, 0.7), 0, 0.02, 0, false, false));
      torso.add(mesh(new THREE.SphereGeometry(0.075, 10, 8), M_SKIN, 0, 0.22, 0, false, false));
      torso.add(mesh(new THREE.SphereGeometry(0.089, 10, 8, 0, Math.PI * 2, 0, Math.PI * 0.55), mat(0xFACC15, 0.35, 0.15), 0, 0.235, 0, false, false));
      torso.add(mesh(new THREE.CylinderGeometry(0.10, 0.10, 0.014, 12), mat(0xFACC15, 0.35, 0.15), 0, 0.225, 0, false, false));
      const armL = mesh(roundedBox(0.055, 0.22, 0.055, 0.02), vestMat, -0.14, -0.02, 0, false, false);
      const armR = mesh(roundedBox(0.055, 0.22, 0.055, 0.02), vestMat,  0.14, -0.02, 0, false, false);
      torso.add(armL, armR);
      g.add(mesh(roundedBox(0.072, 0.24, 0.072, 0.02), mat(0x1E293B, 0.86), -0.052, 0.12, 0, false, false));
      g.add(mesh(roundedBox(0.072, 0.24, 0.072, 0.02), mat(0x1E293B, 0.86),  0.052, 0.12, 0, false, false));
      g.userData = { armL: armL, armR: armR };
      return g;
    }

    function makePigeon() {
      const g = new THREE.Group();
      g.add(mesh(new THREE.SphereGeometry(0.055, 8, 6), mat(0x9AA5B1, 0.85), 0, 0.055, 0, false, false));
      g.add(mesh(new THREE.SphereGeometry(0.032, 8, 6), mat(0x7C8794, 0.85), 0, 0.10, 0.05, false, false));
      const beak = mesh(new THREE.ConeGeometry(0.014, 0.04, 5), M_GOLD, 0, 0.10, 0.085, false, false);
      beak.rotation.x = Math.PI / 2; g.add(beak);
      return g;
    }

    // Builders that stand on a plot while it has not been built on yet.
    const workCrews = [];
    function makeCrew(parent, w, d) {
      const g = new THREE.Group(); parent.add(g);
      const w1 = makeWorker(0xF97316); w1.position.set(-w * 0.22, 0, d * 0.20); w1.rotation.y = 0.6; g.add(w1);
      const w2 = makeWorker(0xFACC15); w2.position.set(w * 0.20, 0, -d * 0.10); w2.rotation.y = -1.1; g.add(w2);
      // Cement mixer
      const mx = new THREE.Group(); mx.position.set(-w * 0.30, 0, -d * 0.24); g.add(mx);
      mx.add(mesh(new THREE.BoxGeometry(0.30, 0.05, 0.24), M_DARKFRAME, 0, 0.05, 0, false, false));
      mx.add(mesh(new THREE.CylinderGeometry(0.055, 0.055, 0.22, 6), M_DARKFRAME, 0, 0.16, 0, false, false));
      const drum = mesh(new THREE.CylinderGeometry(0.13, 0.09, 0.22, 10), mat(0xF59E0B, 0.6), 0, 0.34, 0, false, false);
      drum.rotation.z = 0.5; mx.add(drum);
      // Wheelbarrow
      g.add(mesh(roundedBox(0.26, 0.12, 0.20, 0.03), mat(0x60A5FA, 0.6), w * 0.32, 0.14, d * 0.24, false, false));
      g.add(mesh(new THREE.CylinderGeometry(0.05, 0.05, 0.03, 8), M_DARKFRAME, w * 0.32, 0.05, d * 0.24 + 0.14, false, false));
      workCrews.push({ w1: w1, w2: w2, drum: drum, t: Math.random() * 6 });
      return g;
    }

    function stepCrews(dt, now) {
      for (let i = 0; i < workCrews.length; i++) {
        const c = workCrews[i];
        if (!c.w1.parent || !c.w1.visible) continue;
        c.t += dt;
        const swing = Math.sin(now * 0.005 + i) * 0.9;
        if (c.w1.userData.armR) c.w1.userData.armR.rotation.x = -0.5 + swing * 0.6;
        if (c.w2.userData.armL) c.w2.userData.armL.rotation.x = -0.3 - swing * 0.5;
        c.drum.rotation.y += dt * 1.6;
      }
    }


    // Vehicle factory, defined before the districts because the transport yard parks a
    // bus and a taxi of its own.
    function createCar(color, isBus, isTaxi) {
      const g = new THREE.Group();
      g.name = isBus ? "city-bus" : "city-car";
      const bMat = mat(color, 0.5, 0.15);
      const wMat = mat(0x0F172A, 0.9);
      if (isBus) {
        g.add(mesh(roundedBox(1.0, 0.78, 2.4, 0.08), bMat, 0, 0.51, 0));
        g.add(mesh(new THREE.BoxGeometry(1.04, 0.045, 2.40), M_CREAM, 0, 0.945, 0));
        [-1, 1].forEach(function (side) {
          // Body bevel extends beyond 0.50: put glazing outside it, not buried inside.
          for (let i = 0; i < 5; i++) {
            g.add(mesh(new THREE.BoxGeometry(0.026, 0.31, 0.31), M_GLASS_BL, side * 0.55, 0.715, -0.88 + i * 0.40, false, false));
          }
          g.add(mesh(new THREE.BoxGeometry(0.025, 0.045, 2.28), M_CREAM, side * 0.552, 0.50, 0, false, false));
          g.add(mesh(new THREE.BoxGeometry(0.025, 0.61, 0.27), M_GLASS_BL, side * 0.556, 0.50, 0.94, false, false));
          g.add(mesh(new THREE.BoxGeometry(0.027, 0.61, 0.023), M_MULLION, side * 0.574, 0.50, 0.94, false, false));
        });
        g.add(mesh(new THREE.BoxGeometry(0.88, 0.38, 0.028), M_GLASS_BL, 0, 0.71, 1.251, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.66, 0.08, 0.032), M_DARKFRAME, 0, 0.87, 1.269, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.48, 0.055, 0.03), M_MULLION, 0, 0.30, 1.263, false, false));
      } else {
        g.add(mesh(roundedBox(0.8, 0.30, 1.5, 0.07), bMat, 0, 0.30, 0));
        // Sloping windscreen and rear glass, with a separate painted roof.
        const profile = new THREE.Shape();
        profile.moveTo(-0.48, 0); profile.lineTo(0.46, 0); profile.lineTo(0.24, 0.30); profile.lineTo(-0.27, 0.30); profile.closePath();
        const cabinGeo = new THREE.ExtrudeGeometry(profile, { depth: 0.66, bevelEnabled: false });
        cabinGeo.translate(0, 0, -0.33); cabinGeo.rotateY(Math.PI / 2);
        g.add(mesh(cabinGeo, M_GLASS_BL, 0, 0.43, -0.08));
        g.add(mesh(new THREE.BoxGeometry(0.69, 0.045, 0.55), bMat, 0, 0.745, -0.065));
        [-1, 1].forEach(function (side) {
          g.add(mesh(new THREE.BoxGeometry(0.025, 0.27, 0.04), bMat, side * 0.342, 0.58, -0.04, false, false));
          g.add(mesh(new THREE.BoxGeometry(0.065, 0.06, 0.11), bMat, side * 0.463, 0.48, 0.32, false, false));
          g.add(mesh(new THREE.BoxGeometry(0.022, 0.025, 0.09), M_MULLION, side * 0.45, 0.36, -0.09, false, false));
        });
        if (isTaxi) g.add(mesh(new THREE.BoxGeometry(0.26, 0.08, 0.14), M_WHITE, 0, 0.805, -0.05));
      }
      const wheelR = isBus ? 0.17 : 0.14, axleZ = isBus ? 0.75 : 0.46;
      [-1, 1].forEach(function (side) {
        [-axleZ, axleZ].forEach(function (z) {
          const wh = mesh(new THREE.CylinderGeometry(wheelR, wheelR, 0.09, 12), wMat, side * (isBus ? 0.55 : 0.43), wheelR, z, false, false);
          wh.rotation.z = Math.PI / 2; g.add(wh);
          const hub = mesh(new THREE.CylinderGeometry(wheelR * 0.53, wheelR * 0.53, 0.015, 10), M_MULLION, side * (isBus ? 0.604 : 0.484), wheelR, z, false, false);
          hub.rotation.z = Math.PI / 2; g.add(hub);
        });
        g.add(mesh(new THREE.BoxGeometry(isBus ? 0.15 : 0.16, 0.065, 0.035), M_WHITE, side * (isBus ? 0.36 : 0.28), 0.37, isBus ? 1.266 : 0.80, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.12, 0.07, 0.035), mat(0xB74236, 0.7), side * (isBus ? 0.37 : 0.29), 0.37, isBus ? -1.25 : -0.80, false, false));
      });
      return packRigidModel(g);
    }


    // ────────────────────────────────────────────────────────────────
    // 🎭 3d. WHAT EACH BUILDING IS
    // A sign alone does not tell you a shop sells clothes. Each building gets props that
    // name it at a glance: mannequins, produce crates, parked delivery scooters, a
    // satellite dish, a transformer. Local +z is the front before the group is rotated.
    // ────────────────────────────────────────────────────────────────
    function cafeTableSet(parent, x, z, opts) {
      opts = opts || {};
      const g = new THREE.Group(); g.name = "pavement-cafe-table";
      g.position.set(x, 0, z); g.rotation.y = opts.rotation || 0; parent.add(g);
      g.add(mesh(new THREE.CylinderGeometry(0.25, 0.25, 0.045, 16), M_CREAM, 0, 0.41, 0));
      g.add(mesh(new THREE.CylinderGeometry(0.028, 0.035, 0.38, 8), M_DARKFRAME, 0, 0.20, 0, false, false));
      g.add(mesh(new THREE.CylinderGeometry(0.15, 0.17, 0.03, 10), M_DARKFRAME, 0, 0.02, 0, false, false));
      [-1, 1].forEach(function (side, i) {
        const chair = new THREE.Group(); chair.position.z = side * 0.46;
        chair.rotation.y = side > 0 ? Math.PI : 0; g.add(chair);
        chair.add(mesh(new THREE.BoxGeometry(0.25, 0.035, 0.25), M_WOOD, 0, 0.255, 0));
        [-0.10, 0.10].forEach(function (cx) {
          [-0.10, 0.10].forEach(function (cz) {
            chair.add(mesh(new THREE.CylinderGeometry(0.014, 0.019, 0.24, 6), M_DARKFRAME, cx, 0.12, cz, false, false));
          });
          chair.add(mesh(new THREE.CylinderGeometry(0.016, 0.016, 0.30, 6), M_DARKFRAME, cx, 0.395, -0.10, false, false));
        });
        [0.39, 0.48].forEach(function (y) {
          chair.add(mesh(new THREE.BoxGeometry(0.25, 0.06, 0.03), M_WOOD, 0, y, -0.11, false, false));
        });
        if (opts.occupied) {
          const guest = makeFigure({ seated: true, shirt: i ? 0x527FA7 : (opts.shirt || 0xE49B4D), dark: i ? !opts.dark : !!opts.dark });
          guest.position.z = 0.015; chair.add(guest);
          packRigidModel(guest);
          if (opts.venue) bindVenueActor(guest, opts.venue, (opts.threshold || 0.18) + i * 0.28);
        }
        g.add(mesh(new THREE.CylinderGeometry(0.063, 0.063, 0.010, 12), M_WHITE, 0.035, 0.44, side * 0.145, false, false));
        g.add(mesh(new THREE.CylinderGeometry(0.040, 0.030, 0.067, 12), M_WHITE, 0.035, 0.475, side * 0.145, false, false));
        g.add(mesh(new THREE.CylinderGeometry(0.033, 0.033, 0.007, 10), M_WOOD, 0.035, 0.511, side * 0.145, false, false));
        g.add(mesh(new THREE.TorusGeometry(0.025, 0.009, 5, 8), M_WHITE, 0.083, 0.478, side * 0.145, false, false));
      });
      g.add(mesh(new THREE.BoxGeometry(0.085, 0.007, 0.12), M_CANVAS, -0.13, 0.44, 0.02, false, false));
      if (opts.umbrella) {
        g.add(mesh(new THREE.CylinderGeometry(0.018, 0.023, 1.32, 8), M_WOOD, 0, 0.66, 0, false, false));
        const canopyMat = mat(opts.umbrella, 0.88);
        g.add(mesh(new THREE.ConeGeometry(0.64, 0.23, 8, 1, true), canopyMat, 0, 1.28, 0));
        g.add(mesh(new THREE.CylinderGeometry(0.64, 0.64, 0.065, 8, 1, true), canopyMat, 0, 1.145, 0, false, false));
        g.add(mesh(new THREE.SphereGeometry(0.034, 8, 6), M_WOOD, 0, 1.415, 0, false, false));
      }
      return packRigidModel(g);
    }

    // Food identities use readable silhouettes, not text or color alone.
    function groceryShelf(parent, x, y, z, width) {
      const g = new THREE.Group(); g.position.set(x, y, z); parent.add(g);
      g.add(mesh(new THREE.BoxGeometry(width, 0.66, 0.09), mat(0x286447, 0.8), 0, 0.33, -0.09));
      [0.08, 0.36].forEach(function (yy) {
        g.add(mesh(new THREE.BoxGeometry(width, 0.045, 0.30), M_WARM_STONE, 0, yy, 0));
        for (let i = 0; i < 5; i++) {
          const xx = (i - 2) * width / 5.4;
          g.add(mesh(new THREE.BoxGeometry(width / 7, 0.20, 0.14), mat([0xEAC454, 0xD76547, 0xF6EDD4, 0x619FC0, 0x86A75A][i], 0.8), xx, yy + 0.12, 0));
          g.add(mesh(new THREE.BoxGeometry(width / 10, 0.045, 0.015), M_WHITE, xx, yy + 0.13, 0.078, false, false));
        }
      });
    }

    function groceryCart(parent, x, z, scale) {
      const g = new THREE.Group(); g.position.set(x, 0, z); g.scale.setScalar(scale || 1); g.rotation.y = -0.35; parent.add(g);
      const steel = M_MULLION;
      g.add(mesh(new THREE.BoxGeometry(0.46, 0.035, 0.38), steel, 0, 0.23, 0));
      [-0.22, 0.22].forEach(function (xx) {
        [0.27, 0.40, 0.53].forEach(function (yy) { g.add(mesh(new THREE.BoxGeometry(0.025, 0.025, 0.40), steel, xx, yy, 0)); });
        [-0.18, 0, 0.18].forEach(function (zz) { g.add(mesh(new THREE.BoxGeometry(0.025, 0.30, 0.025), steel, xx, 0.39, zz)); });
        [-0.15, 0.15].forEach(function (zz) {
          const wheel = mesh(new THREE.CylinderGeometry(0.06, 0.06, 0.04, 8), M_DARKFRAME, xx, 0.07, zz); wheel.rotation.z = Math.PI / 2; g.add(wheel);
        });
      });
      [-0.18, 0.18].forEach(function (zz) { g.add(mesh(new THREE.BoxGeometry(0.46, 0.025, 0.025), steel, 0, 0.53, zz)); });
      g.add(mesh(new THREE.BoxGeometry(0.48, 0.055, 0.06), mat(0x287A4C, 0.7), 0, 0.58, -0.24));
      g.add(mesh(new THREE.BoxGeometry(0.17, 0.29, 0.17), M_CANVAS, -0.09, 0.39, 0));
      g.add(mesh(new THREE.SphereGeometry(0.10, 8, 6), mat(0x6A9B43, 0.8), 0.10, 0.37, 0.04));
    }

    function foodEmblem(parent, kind, x, y, z, scale) {
      const g = new THREE.Group(); g.position.set(x, y, z); g.scale.setScalar(scale || 1); parent.add(g);
      if (kind === "coffee") {
        g.add(mesh(new THREE.CylinderGeometry(0.22, 0.16, 0.32, 14), M_WHITE, 0, 0, 0));
        g.add(mesh(new THREE.CylinderGeometry(0.20, 0.20, 0.018, 14), mat(0x583828, 0.85), 0, 0.165, 0));
        g.add(mesh(new THREE.TorusGeometry(0.11, 0.035, 6, 12), M_WHITE, 0.23, 0.01, 0));
        g.add(mesh(new THREE.CylinderGeometry(0.28, 0.28, 0.035, 14), M_WHITE, 0, -0.18, 0));
      } else {
        const plate = mesh(new THREE.CylinderGeometry(0.26, 0.26, 0.045, 20), M_WHITE, 0, 0, 0); plate.rotation.x = Math.PI / 2; g.add(plate);
        g.add(mesh(new THREE.TorusGeometry(0.19, 0.018, 6, 20), M_GOLD, 0, 0, 0.028));
        [-0.37, 0.37].forEach(function (xx) { g.add(mesh(new THREE.BoxGeometry(0.05, 0.46, 0.05), M_WHITE, xx, 0, 0)); });
        [-0.425, -0.37, -0.315].forEach(function (xx) { g.add(mesh(new THREE.BoxGeometry(0.025, 0.16, 0.05), M_WHITE, xx, 0.21, 0)); });
        g.add(mesh(new THREE.BoxGeometry(0.09, 0.23, 0.05), M_WHITE, 0.39, 0.14, 0));
      }
    }

    function diningTable(parent, x, z, venue) {
      const g = new THREE.Group(); g.position.set(x, 0, z); parent.add(g);
      g.add(mesh(new THREE.BoxGeometry(0.58, 0.05, 0.66), M_WOOD, 0, 0.44, 0));
      g.add(mesh(new THREE.BoxGeometry(0.60, 0.025, 0.68), M_CANVAS, 0, 0.475, 0));
      [-0.21, 0.21].forEach(function (xx) { [-0.24, 0.24].forEach(function (zz) { g.add(mesh(new THREE.BoxGeometry(0.035, 0.42, 0.035), M_DARKFRAME, xx, 0.21, zz)); }); });
      [-1, 1].forEach(function (side) {
        if (venue) {
          const guest = makeFigure({ seated: true, shirt: side < 0 ? 0x417BA9 : 0xBC6978, dark: side > 0 });
          guest.position.z = side * 0.48; guest.rotation.y = side > 0 ? Math.PI : 0;
          g.add(guest); packRigidModel(guest);
          bindVenueActor(guest, venue, (x < 0 ? 0.18 : 0.45) + (side > 0 ? 0.28 : 0));
        }
        g.add(mesh(new THREE.CylinderGeometry(0.12, 0.12, 0.02, 12), M_WHITE, 0, 0.50, side * 0.19));
        g.add(mesh(new THREE.BoxGeometry(0.025, 0.015, 0.16), M_MULLION, 0.17, 0.50, side * 0.19));
        g.add(mesh(new THREE.BoxGeometry(0.28, 0.035, 0.26), M_WOOD, 0, 0.26, side * 0.48));
        g.add(mesh(new THREE.BoxGeometry(0.28, 0.28, 0.035), M_WOOD, 0, 0.39, side * 0.59));
        [-0.10, 0.10].forEach(function (xx) { g.add(mesh(new THREE.BoxGeometry(0.035, 0.26, 0.23), M_DARKFRAME, xx, 0.13, side * 0.48)); });
      });
    }

    const CHARACTER = {
      food_super: function (g, w, d) {
        crateStack(g, -w * 0.34, d / 2 + 0.42);
        crateStack(g,  w * 0.30, d / 2 + 0.40);
        groceryCart(g, w * 0.08, d / 2 + 0.50, 1.15);
      },
      food_bistro: function (g, w, d) {
        aFrameBoard(g, -w * 0.38, d / 2 + 0.35, 0.5);
        diningTable(g, -0.38, d / 2 + 0.75, "food_bistro");
        diningTable(g, 0.38, d / 2 + 0.75, "food_bistro");
        foodEmblem(g, "dining", 0, 1.70, d / 2 + 0.14, 0.90);
      },
      food_coffee: function (g, w, d) {
        foodEmblem(g, "coffee", w * 0.30, 1.56, d / 2 + 0.20, 1.10);
        cafeTableSet(g, w * 0.13, d / 2 + 0.85, { occupied: true, venue: "food_coffee", threshold: 0.18, shirt: 0xBC6978 });
        // Coffee sacks
        g.add(mesh(roundedBox(0.24, 0.28, 0.20, 0.06), mat(0xC8AE7D, 0.92), -w * 0.34, 0.14, d / 2 + 0.40, false, false));
        g.add(mesh(roundedBox(0.22, 0.24, 0.18, 0.06), mat(0xB89C68, 0.92), -w * 0.34 + 0.22, 0.12, d / 2 + 0.46, false, false));
      },
      food_wolt: function (g, w, d) {
        // Roller shutter loading door
        g.add(mesh(new THREE.BoxGeometry(w * 0.52, 0.80, 0.05), mat(0x0E7490, 0.55), -w * 0.20, 0.42, d / 2 + 0.05, false, false));
        for (let y = 0.14; y < 0.78; y += 0.14) {
          g.add(mesh(new THREE.BoxGeometry(w * 0.53, 0.03, 0.07), mat(0x155E75, 0.6), -w * 0.20, y, d / 2 + 0.06, false, false));
        }
        // Two parked scooters
        [[w * 0.28, 0.5], [w * 0.44, -0.4]].forEach(function (p, i) {
          const s = makeCourier(0x00C2E8);
          s.position.set(p[0], 0, d / 2 + 0.55 + i * 0.25);
          s.rotation.y = p[1];
          s.scale.setScalar(0.78);
          g.add(s);
          bindVenueActor(s, "food_wolt", 0.18 + i * 0.30);
        });
      },
      shop_boutique: function (g, w, d) {
        // Mannequins behind the glass
        [-w * 0.22, w * 0.10].forEach(function (mx, i) {
          const m = new THREE.Group(); m.position.set(mx, 0, d / 2 - 0.18); g.add(m);
          m.add(mesh(new THREE.CylinderGeometry(0.09, 0.11, 0.03, 10), M_WARM_STONE, 0, 0.02, 0, false, false));
          m.add(mesh(new THREE.CylinderGeometry(0.035, 0.045, 0.34, 8), M_CREAM, 0, 0.20, 0, false, false));
          m.add(mesh(roundedBox(0.17, 0.24, 0.11, 0.04), mat(i ? 0xEC4899 : 0x1D4ED8, 0.7), 0, 0.48, 0, false, false));
          m.add(mesh(new THREE.SphereGeometry(0.055, 8, 8), M_CREAM, 0, 0.66, 0, false, false));
        });
        // Clothes rail on the pavement
        const r = new THREE.Group(); r.position.set(w * 0.34, 0, d / 2 + 0.45); g.add(r);
        r.add(mesh(new THREE.BoxGeometry(0.04, 0.04, 0.60), M_MULLION, 0, 0.62, 0, false, false));
        r.add(mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.62, 6), M_MULLION, -0.16, 0.31, 0, false, false));
        r.add(mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.62, 6), M_MULLION,  0.16, 0.31, 0, false, false));
        [0xEF4444, 0xFACC15, 0x22C55E, 0x3B82F6].forEach(function (c, i) {
          r.add(mesh(new THREE.BoxGeometry(0.05, 0.30, 0.10), mat(c, 0.75), 0, 0.46, -0.22 + i * 0.15, false, false));
        });
      },
      shop_tech: function (g, w, d) {
        // Rooftop antenna mast with calm, slow beacon breathing pulse
        g.add(mesh(new THREE.CylinderGeometry(0.02, 0.03, 0.75, 6), M_MULLION, w * 0.30, FLOOR_H + 0.38, -d * 0.24, false, false));
        const beaconMat = mat(0xEF4444, 0.3, 0, 0xEF4444, 1.2);
        g.add(mesh(new THREE.SphereGeometry(0.055, 8, 8), beaconMat, w * 0.30, FLOOR_H + 0.78, -d * 0.24, false, false));
        animObjects.push({ type: "beacon", mat: beaconMat, base: 0.6, range: 1.2, phase: 0 });
        g.add(mesh(new THREE.BoxGeometry(0.30, 0.02, 0.02), M_MULLION, w * 0.30, FLOOR_H + 0.62, -d * 0.24, false, false));
      },
      shop_travel: function (g, w, d) {
        // Rotating brass/blue globe on the parapet
        const globeGroup = new THREE.Group();
        globeGroup.position.set(-w * 0.26, FLOOR_H + 0.30, -d * 0.10);
        g.add(globeGroup);
        const globeMesh = mesh(new THREE.SphereGeometry(0.26, 14, 12), mat(0x2563EB, 0.5), 0, 0, 0);
        globeGroup.add(globeMesh);
        globeGroup.add(mesh(new THREE.TorusGeometry(0.27, 0.022, 6, 20), M_GOLD, 0, 0, 0, false, false));
        animObjects.push({ type: "rotate_y", ref: globeGroup, speed: 0.65 });
        // Suitcases by the door
        g.add(mesh(roundedBox(0.26, 0.32, 0.14, 0.03), mat(0xB45309, 0.75), w * 0.32, 0.16, d / 2 + 0.42, false, false));
        g.add(mesh(roundedBox(0.22, 0.26, 0.12, 0.03), mat(0x1D4ED8, 0.7), w * 0.32 + 0.20, 0.13, d / 2 + 0.46, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.10, 0.02, 0.02), M_DARKFRAME, w * 0.32, 0.33, d / 2 + 0.42, false, false));
      },
      shop_arcade: function (g, w, d) {
        // Neon frame around the shopfront with breathing pulse
        const neonMat = mat(0xEC4899, 0.3, 0, 0xEC4899, 1.5);
        g.add(mesh(new THREE.BoxGeometry(w - 0.4, 0.06, 0.05), neonMat, 0, 1.02, d / 2 + 0.09, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.06, 0.95, 0.05), neonMat, -(w - 0.4) / 2, 0.55, d / 2 + 0.09, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.06, 0.95, 0.05), neonMat,  (w - 0.4) / 2, 0.55, d / 2 + 0.09, false, false));
        animObjects.push({ type: "neon_pulse", mat: neonMat, base: 0.8, range: 1.4, phase: 1.0 });
        // Bulb run over the sign
        for (let i = -2; i <= 2; i++) {
          const bMat = mat(0xFACC15, 0.3, 0, 0xFACC15, 1.3);
          g.add(mesh(new THREE.SphereGeometry(0.045, 6, 6), bMat, i * 0.30, 1.24, d / 2 + 0.10, false, false));
        }
      },
      house_tower: function (g, w, d) {
        // Washing line and a bicycle by the door — a lived-in home
        g.add(mesh(new THREE.CylinderGeometry(0.015, 0.015, 0.9, 4), M_MULLION, w * 0.36, 0.55, d * 0.40, false, false));
        [0xEF4444, 0xFFFFFF, 0x3B82F6].forEach(function (c, i) {
          g.add(mesh(new THREE.BoxGeometry(0.11, 0.16, 0.01), mat(c, 0.85), w * 0.36, 0.82, d * 0.40 - 0.22 + i * 0.22, false, false));
        });
        const bk = new THREE.Group(); bk.position.set(-w * 0.36, 0, d / 2 + 0.42); bk.rotation.y = 0.7; g.add(bk);
        bk.add(mesh(new THREE.TorusGeometry(0.12, 0.02, 8, 14), M_SLATE, -0.16, 0.14, 0, false, false));
        bk.add(mesh(new THREE.TorusGeometry(0.12, 0.02, 8, 14), M_SLATE,  0.16, 0.14, 0, false, false));
        bk.add(mesh(new THREE.BoxGeometry(0.34, 0.035, 0.035), mat(0x16A34A, 0.5), 0, 0.22, 0, false, false));
      },
      house_util: function (g, w, d) {
        // Transformer, meters and pipework
        const tr = new THREE.Group(); tr.position.set(w * 0.40, 0, -d * 0.30); g.add(tr);
        tr.add(mesh(roundedBox(0.42, 0.52, 0.34, 0.04), mat(0x9CA3AF, 0.8), 0, 0.26, 0, false, false));
        tr.add(mesh(new THREE.BoxGeometry(0.30, 0.16, 0.02), mat(0xFACC15, 0.6), 0, 0.34, 0.18, false, false));
        tr.add(mesh(new THREE.CylinderGeometry(0.035, 0.035, 0.22, 6), M_MULLION, -0.12, 0.62, 0, false, false));
        tr.add(mesh(new THREE.CylinderGeometry(0.035, 0.035, 0.22, 6), M_MULLION,  0.12, 0.62, 0, false, false));
        // Water pipes up the flank
        g.add(mesh(new THREE.CylinderGeometry(0.035, 0.035, 1.0, 6), M_CONCRETE, -w * 0.44, 0.55, d * 0.18, false, false));
        g.add(mesh(new THREE.CylinderGeometry(0.045, 0.045, 0.16, 8), M_DARKFRAME, -w * 0.44, 0.28, d * 0.18, false, false));
        // Meter box by the door
        g.add(mesh(roundedBox(0.20, 0.24, 0.10, 0.02), M_MULLION, -w * 0.20, 0.62, d / 2 + 0.05, false, false));
      },
      house_subs: function (g, w, d) {
        // Satellite dish and an antenna mast — the subscriptions house
        const dish = new THREE.Group(); dish.position.set(w * 0.30, FLOOR_H + 0.10, -d * 0.26); g.add(dish);
        dish.add(mesh(new THREE.CylinderGeometry(0.03, 0.04, 0.34, 6), M_DARKFRAME, 0, 0.17, 0, false, false));
        const d2 = mesh(new THREE.SphereGeometry(0.22, 12, 8, 0, Math.PI * 2, 0, Math.PI * 0.42), M_WHITE, 0, 0.42, 0);
        d2.rotation.x = 2.1; dish.add(d2);
        dish.add(mesh(new THREE.SphereGeometry(0.035, 6, 6), M_DARKFRAME, 0, 0.42, 0.16, false, false));
        g.add(mesh(new THREE.CylinderGeometry(0.018, 0.026, 0.70, 5), M_MULLION, -w * 0.32, FLOOR_H + 0.35, -d * 0.20, false, false));
        for (let i = 0; i < 3; i++) {
          g.add(mesh(new THREE.BoxGeometry(0.26 - i * 0.05, 0.015, 0.015), M_MULLION, -w * 0.32, FLOOR_H + 0.44 + i * 0.12, -d * 0.20, false, false));
        }
      },
      health_pharmacy: function (g, w, d) {
        // The green cross that says pharmacy, with gentle breathing pulse
        const cm = mat(0x16A34A, 0.4, 0, 0x22C55E, 1.2);
        g.add(mesh(new THREE.BoxGeometry(0.16, 0.44, 0.06), cm, w * 0.34, 1.06, d / 2 + 0.08, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.44, 0.16, 0.06), cm, w * 0.34, 1.06, d / 2 + 0.08, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.05, 0.05, 0.22), M_DARKFRAME, w * 0.34, 1.06, d / 2 - 0.04, false, false));
        animObjects.push({ type: "cross_pulse", mat: cm, phase: 0 });
      },
      museum_curiosities: function (g, w, d) {
        // A small community reading room: a bench, a book box and a lantern
        g.add(mesh(roundedBox(0.30, 0.40, 0.22, 0.03), M_WOOD, -w * 0.36, 0.20, d / 2 + 0.40, false, false));
        [0xEF4444, 0x3B82F6, 0xFACC15].forEach(function (c, i) {
          g.add(mesh(new THREE.BoxGeometry(0.05, 0.16, 0.13), mat(c, 0.8), -w * 0.36 - 0.08 + i * 0.08, 0.48, d / 2 + 0.40, false, false));
        });
        g.add(mesh(new THREE.CylinderGeometry(0.03, 0.04, 0.70, 6), M_DARKFRAME, w * 0.38, 0.35, d / 2 + 0.38, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.14, 0.16, 0.14), mat(0xFEF3C7, 0.3, 0, 0xFDE68A, 1.0), w * 0.38, 0.78, d / 2 + 0.38, false, false));
      },
      city_sorting_hub: function (g, w, d) {
        // A post booth: mailbox, parcel stack, sorting trolley
        g.add(mesh(roundedBox(0.28, 0.52, 0.24, 0.06), mat(0xDC2626, 0.6), -w * 0.40, 0.26, d / 2 + 0.42, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.18, 0.04, 0.03), M_DARKFRAME, -w * 0.40, 0.44, d / 2 + 0.54, false, false));
        g.add(mesh(roundedBox(0.26, 0.20, 0.22, 0.02), mat(0xC8A87A, 0.9), w * 0.30, 0.10, d / 2 + 0.40, false, false));
        g.add(mesh(roundedBox(0.22, 0.18, 0.20, 0.02), mat(0xB8946A, 0.9), w * 0.30 + 0.05, 0.29, d / 2 + 0.44, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.20, 0.02, 0.16), mat(0xDC2626, 0.6), w * 0.30, 0.39, d / 2 + 0.44, false, false));
      }
    };

    // ────────────────────────────────────────────────────────────────
    // 🎪 3e. CUSTOM TIER 1 STALLS — Bespoke character for every category
    // ────────────────────────────────────────────────────────────────
    const CUSTOM_STALLS = {
      // A miniature grocery shop: open shelves and produce under a flat green fascia.
      food_super: function (g, w, d) {
        const green = mat(0x287A4C, 0.8);
        g.add(mesh(roundedBox(1.65, 0.50, 0.64, 0.04), green, 0, 0.25, 0.18));
        g.add(mesh(new THREE.BoxGeometry(1.72, 0.055, 0.70), M_WARM_STONE, 0, 0.53, 0.18));
        groceryShelf(g, 0, 0.30, -0.35, 1.48);
        [-0.53, 0, 0.53].forEach(function (xx, i) {
          g.add(mesh(new THREE.BoxGeometry(0.45, 0.12, 0.40), M_WOOD, xx, 0.60, 0.23));
          for (let j = 0; j < 6; j++) {
            g.add(mesh(new THREE.SphereGeometry(0.075, 7, 6), mat([0xD9533F, 0xE7BD43, 0x79A64B][i], 0.8), xx + (j % 3 - 1) * 0.13, 0.71, 0.13 + Math.floor(j / 3) * 0.16));
          }
        });
        [-0.80, 0.80].forEach(function (xx) { g.add(mesh(new THREE.BoxGeometry(0.06, 1.28, 0.06), green, xx, 0.64, -0.41)); });
        g.add(mesh(new THREE.BoxGeometry(1.78, 0.12, 0.62), green, 0, 1.28, -0.20));
        signPlate(g, 1.90, 1.24, 0.20, "MARKET", "#287A4C", "#FFF9EE", 30);
        groceryCart(g, 0.65, 0.83, 0.95);
        crateStack(g, -0.64, 0.79);
      },

      // 2. Food - Bistro (Vintage Airstream / Food Truck)
      food_bistro: function (g, w, d) {
        const body = mat(0xAC493B, 0.65);
        g.add(mesh(roundedBox(1.50, 0.74, 0.84, 0.16), body, 0, 0.42, 0));
        const gMat = glassMaterial(0xBFE3FA); registerGlass(gMat);
        g.add(mesh(new THREE.BoxGeometry(0.80, 0.34, 0.04), gMat, 0, 0.48, 0.43, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.86, 0.04, 0.20), M_WHITE, 0, 0.30, 0.52, false, false));
        const aw = mesh(new THREE.BoxGeometry(0.86, 0.05, 0.30), new THREE.MeshStandardMaterial({ map: stripedAwningTex("#DC2626", "#FFFFFF") }), 0, 0.68, 0.55);
        aw.rotation.x = -0.25; g.add(aw);
        g.add(mesh(new THREE.CylinderGeometry(0.04, 0.05, 0.24, 8), mat(0x64748B, 0.4, 0.5), 0.50, 0.88, -0.15, false, false));
        [[-0.45], [0.45]].forEach(function (p) {
          const wh = mesh(new THREE.CylinderGeometry(0.12, 0.12, 0.06, 10), mat(0x0F172A, 0.9), p[0], 0.12, 0.43, false, false);
          wh.rotation.x = Math.PI / 2; g.add(wh);
        });
        // Restaurant identity is plated food and a hot kitchen, never an espresso cart.
        foodEmblem(g, "dining", -0.08, 1.14, 0.13, 0.85);
        g.add(mesh(new THREE.BoxGeometry(0.44, 0.16, 0.28), M_DARKFRAME, 0.05, 0.40, 0.54));
        for (let i = 0; i < 5; i++) g.add(mesh(new THREE.BoxGeometry(0.025, 0.025, 0.26), M_MULLION, -0.12 + i * 0.085, 0.49, 0.54));
        const hood = mesh(new THREE.CylinderGeometry(0.10, 0.16, 0.22, 8), M_MULLION, 0.53, 1.02, -0.16); g.add(hood);
        diningTable(g, -0.32, 1.02);
        aFrameBoard(g, 0.64, 0.78, -0.25);
      },

      // 3. Food - Cafe (Retro Italian Espresso Cart / Piaggio Ape)
      food_coffee: function (g, w, d) {
        const mint = mat(0x895D40, 0.8);
        g.add(mesh(roundedBox(1.20, 0.55, 0.75, 0.08), mint, 0, 0.35, 0));
        g.add(mesh(new THREE.BoxGeometry(1.26, 0.05, 0.82), M_WOOD, 0, 0.65, 0, false, false));
        const chrome = mat(0xE2E8F0, 0.2, 0.85);
        g.add(mesh(roundedBox(0.40, 0.28, 0.28, 0.04), chrome, 0.15, 0.82, 0));
        g.add(mesh(new THREE.CylinderGeometry(0.015, 0.015, 0.12, 6), chrome, 0.38, 0.76, 0.10, false, false));
        for (let i = 0; i < 3; i++) {
          g.add(mesh(new THREE.CylinderGeometry(0.04, 0.03, 0.06, 8), M_WHITE, 0.10 + i * 0.09, 0.99, 0, false, false));
        }
        const umbPole = mesh(new THREE.CylinderGeometry(0.025, 0.025, 1.0, 6), M_WOOD, -0.45, 0.80, -0.20, false, false);
        const umbTop = mesh(new THREE.ConeGeometry(0.65, 0.24, 10), mat(0x5C9691, 0.8), -0.45, 1.35, -0.20);
        g.add(umbPole, umbTop);
        foodEmblem(g, "coffee", 0.42, 1.25, 0.17, 1.05);
        g.add(mesh(roundedBox(0.24, 0.26, 0.20, 0.05), mat(0xC8AE7D, 0.9), -0.55, 0.13, 0.40, false, false));
      },

      // 4. Food - Wolt (Courier Dispatch Stand)
      food_wolt: function (g, w, d) {
        const cyan = mat(0x00C2E8, 0.4, 0.3);
        g.add(mesh(roundedBox(1.10, 0.58, 0.65, 0.06), cyan, -0.20, 0.30, 0));
        g.add(mesh(new THREE.BoxGeometry(1.15, 0.05, 0.70), mat(0x0E7490, 0.7), -0.20, 0.61, 0, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.25, 0.20, 0.03), mat(0x0284C7, 0.2, 0, 0x38BDF8, 1.2), -0.20, 0.74, 0.10, false, false));
        [[-0.45, 0.68], [-0.10, 0.68]].forEach(function (p) {
          g.add(mesh(roundedBox(0.24, 0.26, 0.22, 0.03), cyan, p[0], p[1], -0.15, false, false));
          g.add(mesh(new THREE.BoxGeometry(0.14, 0.14, 0.02), M_WHITE, p[0], p[1], -0.03, false, false));
        });
        const sc = makeCourier(0x00C2E8);
        sc.position.set(0.55, 0, 0.10); sc.rotation.y = 0.2; sc.scale.setScalar(0.85); g.add(sc);
      },

      // 5. Shopping - Boutique (Fashion Pop-Up Gazebo)
      shop_boutique: function (g, w, d) {
        const tentMat = new THREE.MeshStandardMaterial({ map: stripedAwningTex("#EF4444", "#FFFFFF"), roughness: 0.85 });
        g.add(mesh(roundedBox(1.40, 0.08, 1.20, 0.04), M_CREAM, 0, 0.04, 0));
        [[-0.60, -0.50], [0.60, -0.50], [-0.60, 0.50], [0.60, 0.50]].forEach(function (p) {
          g.add(mesh(new THREE.CylinderGeometry(0.025, 0.025, 1.05, 6), M_GOLD, p[0], 0.55, p[1], false, false));
        });
        const roof = mesh(new THREE.ConeGeometry(1.05, 0.40, 4), tentMat, 0, 1.25, 0);
        roof.rotation.y = Math.PI / 4; g.add(roof);
        const rk = new THREE.Group(); rk.position.set(-0.15, 0.08, -0.15); g.add(rk);
        rk.add(mesh(new THREE.BoxGeometry(0.03, 0.03, 0.60), M_GOLD, 0, 0.55, 0, false, false));
        rk.add(mesh(new THREE.CylinderGeometry(0.015, 0.015, 0.55, 6), M_GOLD, -0.15, 0.28, 0, false, false));
        rk.add(mesh(new THREE.CylinderGeometry(0.015, 0.015, 0.55, 6), M_GOLD,  0.15, 0.28, 0, false, false));
        [0xEC4899, 0x3B82F6, 0xFACC15].forEach(function (c, i) {
          rk.add(mesh(new THREE.BoxGeometry(0.04, 0.28, 0.12), mat(c, 0.75), 0, 0.40, -0.18 + i * 0.18, false, false));
        });
        const man = new THREE.Group(); man.position.set(0.42, 0.08, 0.22); g.add(man);
        man.add(mesh(new THREE.CylinderGeometry(0.07, 0.09, 0.02, 8), M_WARM_STONE, 0, 0.01, 0, false, false));
        man.add(mesh(new THREE.CylinderGeometry(0.025, 0.025, 0.35, 6), M_CREAM, 0, 0.18, 0, false, false));
        man.add(mesh(roundedBox(0.16, 0.22, 0.11, 0.03), mat(0xDC2626, 0.7), 0, 0.44, 0, false, false));
        man.add(mesh(new THREE.SphereGeometry(0.05, 8, 8), M_CREAM, 0, 0.60, 0, false, false));
      },

      // 6. Shopping - Tech (Minimalist Gadget Kiosk)
      shop_tech: function (g, w, d) {
        g.add(mesh(roundedBox(1.30, 0.60, 0.75, 0.06), M_WHITE, 0, 0.30, 0));
        g.add(mesh(new THREE.BoxGeometry(1.34, 0.04, 0.79), mat(0x0F172A, 0.2, 0.8), 0, 0.62, 0, false, false));
        const stallScrMat = mat(0x38BDF8, 0.2, 0, 0x0284C7, 0.9);
        [-0.38, 0, 0.38].forEach(function (tx, i) {
          const scr = mesh(new THREE.BoxGeometry(0.22, 0.015, 0.16), stallScrMat, tx, 0.65, (i === 1 ? -0.10 : 0.08));
          g.add(scr);
          g.add(mesh(new THREE.BoxGeometry(0.24, 0.03, 0.18), M_WHITE, tx, 0.635, (i === 1 ? -0.10 : 0.08), false, false));
        });
        const haloMat = mat(0x0284C7, 0.2, 0, 0x38BDF8, 1.0);
        const halo = mesh(new THREE.TorusGeometry(0.55, 0.035, 8, 24), haloMat, 0, 1.35, 0);
        halo.rotation.x = Math.PI / 2; g.add(halo);
        [[-0.45, -0.25], [0.45, -0.25]].forEach(function (p) {
          g.add(mesh(new THREE.CylinderGeometry(0.015, 0.015, 0.80, 6), M_MULLION, p[0], 0.95, p[1], false, false));
        });
      },

      // 7. Shopping - Travel (Tiki & Beach Vacation Cabana)
      shop_travel: function (g, w, d) {
        g.add(mesh(roundedBox(1.20, 0.58, 0.70, 0.06), mat(0xD97706, 0.8), 0, 0.29, 0));
        g.add(mesh(new THREE.BoxGeometry(1.26, 0.05, 0.76), M_WOOD, 0, 0.60, 0, false, false));
        const umbPole = mesh(new THREE.CylinderGeometry(0.025, 0.025, 1.05, 6), M_WOOD, -0.45, 0.80, -0.15, false, false);
        const umbTop = mesh(new THREE.ConeGeometry(0.70, 0.28, 12), new THREE.MeshStandardMaterial({ map: stripedAwningTex("#3B82F6", "#FACC15") }), -0.45, 1.38, -0.15);
        g.add(umbPole, umbTop);
        const rack = new THREE.Group(); rack.position.set(0.42, 0.62, 0.10); g.add(rack);
        rack.add(mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.45, 6), M_DARKFRAME, 0, 0.22, 0, false, false));
        for (let i = 0; i < 4; i++) {
          const a = (i / 4) * Math.PI * 2;
          rack.add(mesh(new THREE.BoxGeometry(0.08, 0.12, 0.01), mat(0xEF4444 + i * 0x1020, 0.7), Math.cos(a) * 0.08, 0.25, Math.sin(a) * 0.08, false, false));
        }
        g.add(mesh(roundedBox(0.28, 0.32, 0.14, 0.03), mat(0xB45309, 0.75), -0.55, 0.16, 0.40, false, false));
        g.add(mesh(roundedBox(0.24, 0.26, 0.12, 0.03), mat(0x1D4ED8, 0.7), -0.37, 0.13, 0.44, false, false));
      },

      // 8. Shopping - Arcade (Retro Arcade Machine Pod)
      shop_arcade: function (g, w, d) {
        g.add(mesh(roundedBox(1.30, 0.08, 0.90, 0.05), mat(0x18181B, 0.9), 0, 0.04, 0));
        [-0.26, 0.26].forEach(function (ax, i) {
          const arc = new THREE.Group(); arc.position.set(ax, 0.08, 0); g.add(arc);
          const col = i === 0 ? 0xDC2626 : 0x2563EB;
          arc.add(mesh(roundedBox(0.38, 0.82, 0.44, 0.04), mat(col, 0.6), 0, 0.41, 0));
          const scr = mesh(new THREE.BoxGeometry(0.28, 0.24, 0.02), mat(0x22C55E, 0.3, 0, 0x4ADE80, 1.4), 0, 0.54, 0.21);
          scr.rotation.x = -0.3; arc.add(scr);
          arc.add(mesh(new THREE.BoxGeometry(0.32, 0.06, 0.16), mat(0x0F172A, 0.9), 0, 0.38, 0.24, false, false));
          arc.add(mesh(new THREE.SphereGeometry(0.03, 6, 6), mat(0xEF4444, 0.5, 0, 0xEF4444, 1.0), -0.07, 0.43, 0.24, false, false));
          arc.add(mesh(new THREE.SphereGeometry(0.03, 6, 6), mat(0xFACC15, 0.5, 0, 0xFACC15, 1.0),  0.07, 0.43, 0.24, false, false));
        });
        const arch = mesh(new THREE.TorusGeometry(0.55, 0.035, 8, 16, Math.PI), mat(0xEC4899, 0.3, 0, 0xEC4899, 1.6), 0, 0.95, 0);
        g.add(arch);
      },

      // 9. Housing - Main (Cozy Tiny Home Camper Van)
      house_tower: function (g, w, d) {
        const cream = mat(0xFDF8EE, 0.7);
        const teal = mat(0x0D9488, 0.7);
        g.add(mesh(roundedBox(1.50, 0.76, 0.88, 0.16), cream, 0, 0.45, 0));
        g.add(mesh(new THREE.BoxGeometry(1.52, 0.14, 0.90), teal, 0, 0.36, 0, false, false));
        const gm = glassMaterial(0xBFE3FA); registerGlass(gm);
        g.add(mesh(new THREE.BoxGeometry(0.42, 0.28, 0.04), gm, -0.28, 0.52, 0.45, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.32, 0.56, 0.04), mat(0x78350F, 0.8), 0.35, 0.36, 0.45, false, false));
        g.add(mesh(new THREE.CylinderGeometry(0.035, 0.04, 0.30, 8), mat(0x334155, 0.8), -0.40, 0.95, -0.20, false, false));
        const can = mesh(new THREE.BoxGeometry(1.10, 0.04, 0.45), new THREE.MeshStandardMaterial({ map: stripedAwningTex("#E2622B", "#FFFFFF") }), 0, 0.78, 0.65);
        can.rotation.x = 0.25; g.add(can);
        g.add(mesh(new THREE.BoxGeometry(0.22, 0.22, 0.22), mat(0xEA580C, 0.7), -0.55, 0.14, 0.75, false, false));
      },

      // 10. Housing - Utilities (Field Generator & Cable Maintenance Cart)
      house_util: function (g, w, d) {
        const yellow = mat(0xFACC15, 0.5, 0.2);
        g.add(mesh(roundedBox(1.10, 0.60, 0.75, 0.06), yellow, -0.15, 0.34, 0));
        g.add(mesh(new THREE.BoxGeometry(1.12, 0.10, 0.77), mat(0x18181B, 0.9), -0.15, 0.25, 0, false, false));
        g.add(mesh(new THREE.CylinderGeometry(0.04, 0.04, 0.35, 8), mat(0x64748B, 0.4, 0.5), -0.45, 0.75, -0.20, false, false));
        const sp = mesh(new THREE.CylinderGeometry(0.24, 0.24, 0.28, 12), mat(0xEA580C, 0.7), 0.52, 0.24, 0.10, false, false);
        sp.rotation.z = Math.PI / 2; g.add(sp);
        [[-0.55, 0.50], [0.35, 0.55]].forEach(function (cp) {
          g.add(mesh(new THREE.ConeGeometry(0.08, 0.26, 8), mat(0xF97316, 0.65), cp[0], 0.13, cp[1], false, false));
        });
      },

      // 11. Housing - Subscriptions (Digital Media & Newsstand Kiosk)
      house_subs: function (g, w, d) {
        g.add(mesh(roundedBox(1.15, 0.65, 0.70, 0.05), M_CREAM, 0, 0.35, 0));
        g.add(mesh(new THREE.BoxGeometry(1.22, 0.06, 0.76), mat(0x7C3AED, 0.7), 0, 0.68, 0, false, false));
        for (let r = 0; r < 2; r++) {
          const yy = 0.35 + r * 0.20;
          g.add(mesh(new THREE.BoxGeometry(0.95, 0.04, 0.10), M_WOOD, 0, yy, 0.38, false, false));
          for (let m = -2; m <= 2; m++) {
            g.add(mesh(new THREE.BoxGeometry(0.12, 0.16, 0.01), mat(0x3B82F6 + m * 0x1100, 0.8), m * 0.18, yy + 0.08, 0.39, false, false));
          }
        }
        g.add(mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.55, 6), M_MULLION, 0.45, 0.95, -0.20, false, false));
        const dish = mesh(new THREE.SphereGeometry(0.14, 10, 6, 0, Math.PI * 2, 0, Math.PI * 0.4), M_WHITE, 0.45, 1.22, -0.20);
        dish.rotation.x = 2.0; g.add(dish);
      },

      // 12. South - Pharmacy (Apothecary & First Aid Tent)
      health_pharmacy: function (g, w, d) {
        g.add(mesh(roundedBox(1.20, 0.55, 0.75, 0.05), mat(0xFAFAF7, 0.8), 0, 0.30, 0));
        g.add(mesh(new THREE.BoxGeometry(1.26, 0.05, 0.80), mat(0x16A34A, 0.8), 0, 0.60, 0, false, false));
        const cm = mat(0x16A34A, 0.4, 0, 0x22C55E, 1.2);
        g.add(mesh(new THREE.BoxGeometry(0.12, 0.34, 0.03), cm, 0, 0.78, 0.40, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.34, 0.12, 0.03), cm, 0, 0.78, 0.40, false, false));
        animObjects.push({ type: "cross_pulse", mat: cm, phase: 1.5 });
        const gm = glassMaterial(0xCFE9FB); registerGlass(gm);
        g.add(mesh(new THREE.BoxGeometry(0.55, 0.22, 0.20), gm, -0.25, 0.71, 0, false, false));
        [-0.35, -0.25, -0.15].forEach(function (jx) {
          g.add(mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.08, 6), mat(0xB45309, 0.6), jx, 0.68, 0, false, false));
        });
      },

      // 13. South - Learning (Curbside Old Book Cart)
      museum_curiosities: function (g, w, d) {
        g.add(mesh(roundedBox(1.25, 0.50, 0.70, 0.04), mat(0x78350F, 0.85), 0, 0.35, 0));
        g.add(mesh(new THREE.BoxGeometry(1.30, 0.05, 0.75), mat(0x92400E, 0.85), 0, 0.62, 0, false, false));
        [[-0.50], [0.50]].forEach(function (wx) {
          g.add(mesh(new THREE.TorusGeometry(0.20, 0.025, 6, 12), M_DARKFRAME, wx[0], 0.20, 0.38, false, false));
        });
        const bookColors = [0xDC2626, 0x1D4ED8, 0x15803D, 0xD97706, 0x7C3AED];
        for (let b = 0; b < 7; b++) {
          const bx = -0.42 + b * 0.14;
          g.add(mesh(new THREE.BoxGeometry(0.08, 0.24, 0.28), mat(bookColors[b % bookColors.length], 0.8), bx, 0.76, 0, false, false));
        }
        g.add(mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.65, 6), M_DARKFRAME, 0.50, 0.85, -0.20, false, false));
        g.add(mesh(new THREE.BoxGeometry(0.12, 0.16, 0.12), mat(0xFEF3C7, 0.3, 0, 0xFDE68A, 1.2), 0.50, 1.20, -0.20, false, false));
      },

      // 14. South - Sorting / Post (Royal Post Box & Parcel Hub)
      city_sorting_hub: function (g, w, d) {
        const red = mat(0xDC2626, 0.6);
        const pb = mesh(new THREE.CylinderGeometry(0.20, 0.22, 0.72, 12), red, -0.40, 0.36, 0.15, false, false);
        const pbDome = mesh(new THREE.SphereGeometry(0.20, 12, 8, 0, Math.PI * 2, 0, Math.PI * 0.5), red, -0.40, 0.72, 0.15, false, false);
        g.add(pb, pbDome);
        g.add(mesh(new THREE.BoxGeometry(0.14, 0.03, 0.02), M_GOLD, -0.40, 0.58, 0.35, false, false));
        g.add(mesh(roundedBox(0.80, 0.46, 0.60, 0.04), M_WOOD, 0.25, 0.25, 0));
        g.add(mesh(new THREE.BoxGeometry(0.86, 0.04, 0.65), M_WARM_STONE, 0.25, 0.49, 0, false, false));
        g.add(mesh(roundedBox(0.28, 0.18, 0.24, 0.02), mat(0xC8A87A, 0.9), 0.15, 0.60, 0, false, false));
        g.add(mesh(roundedBox(0.22, 0.14, 0.20, 0.02), mat(0xB8946A, 0.9), 0.35, 0.58, 0.05, false, false));
        g.add(mesh(roundedBox(0.18, 0.12, 0.16, 0.02), mat(0xC8A87A, 0.9), 0.18, 0.74, 0, false, false));
      }
    };

    // ────────────────────────────────────────────────────────────────
    // 🏛️ 3f. CUSTOM FACADES & ARCHITECTURE — Ground floor bespoke character
    // ────────────────────────────────────────────────────────────────
    const CUSTOM_FACADES = {
      // 1. Food - Supermarket (Wide sliding entrance hall with green glass canopy)
      food_super: function (ground, w, d, cfg, bodyMat) {
        const gm = glassMaterial(0xCFE9FB); registerGlass(gm);
        const span = w * 0.38;
        groceryShelf(ground, -w * 0.34, 0.12, d / 2 + 0.13, w * 0.25);
        groceryShelf(ground, w * 0.34, 0.12, d / 2 + 0.13, w * 0.25);
        ground.add(mesh(new THREE.BoxGeometry(span, 0.76, 0.05), gm, 0, 0.48, d / 2 + 0.03, false, false));
        ground.add(mesh(new THREE.BoxGeometry(0.06, 0.80, 0.07), mat(0x15803D, 0.7), 0, 0.50, d / 2 + 0.035, false, false));
        [-span / 2, span / 2].forEach(function (fx) {
          ground.add(mesh(new THREE.BoxGeometry(0.08, 0.82, 0.08), mat(0x15803D, 0.7), fx, 0.50, d / 2 + 0.04, false, false));
        });
        ground.add(mesh(new THREE.BoxGeometry(span + 0.14, 0.14, 0.08), mat(0x15803D, 0.7), 0, 0.95, d / 2 + 0.04, false, false));
        ground.add(mesh(new THREE.BoxGeometry(w + 0.10, 0.12, 0.48), mat(0x287A4C, 0.8), 0, 1.04, d / 2 + 0.24, false, false));
        ground.add(mesh(new THREE.BoxGeometry(w - 0.10, 0.08, 0.10), M_WARM_STONE, 0, 0.04, d / 2 + 0.04, false, false));
      },

      // 2. Food - Bistro (European Brasserie with exposed brick arches and warm glow)
      food_bistro: function (ground, w, d, cfg, bodyMat) {
        const brickMat = mat(0xB45309, 0.8);
        ground.add(mesh(roundedBox(w + 0.04, 0.26, d + 0.04, 0.02), brickMat, 0, 0.13, 0));
        const gm = glassMaterial(0xFEF3C7); registerGlass(gm);
        ground.add(mesh(new THREE.BoxGeometry(w - 0.48, 0.68, 0.05), gm, 0, 0.54, d / 2 + 0.03, false, false));
        [-0.45, 0.45].forEach(function (cx) {
          ground.add(mesh(new THREE.BoxGeometry(0.08, 0.74, 0.07), M_WOOD, cx, 0.54, d / 2 + 0.04, false, false));
        });
        ground.add(mesh(new THREE.BoxGeometry(0.40, 0.70, 0.06), M_WOOD, 0, 0.40, d / 2 + 0.04, false, false));
        ground.add(mesh(new THREE.SphereGeometry(0.035, 6, 6), M_GOLD, 0.14, 0.42, d / 2 + 0.08, false, false));
        stripedAwning(ground, w, d, "#DC2626", "#FEF3C7", 0.98);
      },

      // 3. Food - Cafe (Parisian Bay Window & Timber Facade)
      food_coffee: function (ground, w, d, cfg, bodyMat) {
        const bay = new THREE.Group(); bay.position.set(-w * 0.18, 0, d / 2 + 0.16);
        ground.add(bay);
        bay.add(mesh(new THREE.BoxGeometry(w * 0.53, 0.23, 0.32), M_WOOD, 0, 0.16, 0));
        bay.add(mesh(new THREE.BoxGeometry(w * 0.51, 0.48, 0.025), M_DARKFRAME, 0, 0.53, -0.055, false, false));
        const breadMat = mat(0xDA9B52, 0.9);
        [0.32, 0.53].forEach(function (yy) {
          bay.add(mesh(new THREE.BoxGeometry(w * 0.50, 0.025, 0.26), M_WARM_STONE, 0, yy, 0.04, false, false));
          [-0.23, 0, 0.23].forEach(function (bx) {
            const pastry = mesh(new THREE.TorusGeometry(0.065, 0.031, 6, 9, Math.PI * 1.55), breadMat, bx, yy + 0.049, 0.055, false, false);
            pastry.rotation.x = -Math.PI / 2; bay.add(pastry);
          });
        });
        const displayGlass = new THREE.MeshStandardMaterial({ color: 0xD9EEF1, transparent: true, opacity: 0.16, roughness: 0.18, depthWrite: false });
        bay.add(mesh(new THREE.BoxGeometry(w * 0.52, 0.49, 0.018), displayGlass, 0, 0.52, 0.187, false, false));
        [-1, 1].forEach(function (side) {
          bay.add(mesh(new THREE.BoxGeometry(0.037, 0.53, 0.055), M_WOOD, side * w * 0.265, 0.53, 0.17, false, false));
        });
        bay.add(mesh(new THREE.BoxGeometry(w * 0.56, 0.055, 0.33), M_WOOD, 0, 0.81, 0.04, false, false));
        ground.add(mesh(new THREE.BoxGeometry(0.38, 0.72, 0.06), M_WOOD, w * 0.26, 0.38, d / 2 + 0.063, false, false));
        ground.add(mesh(new THREE.BoxGeometry(0.27, 0.41, 0.024), M_GLASS_BL, w * 0.26, 0.53, d / 2 + 0.108, false, false));
        ground.add(mesh(new THREE.SphereGeometry(0.035, 6, 6), M_GOLD, w * 0.26 + 0.12, 0.42, d / 2 + 0.07, false, false));
        stripedAwning(ground, w, d, "#5C9691", "#FEF3C7", 0.98);
      },

      // 4. Food - Wolt (Industrial Concrete Courier Depot)
      food_wolt: function (ground, w, d, cfg, bodyMat) {
        const conc = mat(0x94A3B8, 0.85);
        ground.add(mesh(roundedBox(w + 0.04, 0.18, d + 0.04, 0.02), conc, 0, 0.09, 0));
        ground.add(mesh(new THREE.BoxGeometry(w - 0.4, 0.10, 0.08), mat(0x00C2E8, 0.5, 0.4), 0, 0.98, d / 2 + 0.04, false, false));
      },

      // 5. Shopping - Boutique (Parisian Classical Arched Portal)
      shop_boutique: function (ground, w, d, cfg, bodyMat) {
        [-w / 2 + 0.14, w / 2 - 0.14].forEach(function (px) {
          ground.add(mesh(new THREE.BoxGeometry(0.18, 0.92, 0.12), M_CREAM, px, 0.48, d / 2 + 0.05, false, false));
          ground.add(mesh(new THREE.BoxGeometry(0.22, 0.06, 0.14), M_GOLD, px, 0.95, d / 2 + 0.05, false, false));
        });
        const gm = glassMaterial(0xD8ECFB); registerGlass(gm);
        ground.add(mesh(new THREE.BoxGeometry(w - 0.48, 0.72, 0.05), gm, 0, 0.50, d / 2 + 0.03, false, false));
        ground.add(mesh(new THREE.BoxGeometry(0.42, 0.72, 0.06), mat(0x1E293B, 0.7), 0, 0.38, d / 2 + 0.04, false, false));
        ground.add(mesh(new THREE.BoxGeometry(0.04, 0.18, 0.04), M_GOLD, 0.08, 0.42, d / 2 + 0.08, false, false));
        stripedAwning(ground, w, d, "#EF4444", "#FFFFFF", 0.98);
      },

      // 6. Shopping - Tech (Apple Store Seamless Glass Cube)
      shop_tech: function (ground, w, d, cfg, bodyMat) {
        const gm = glassMaterial(0xBAE6FD); registerGlass(gm);
        ground.add(mesh(new THREE.BoxGeometry(w - 0.12, 0.88, 0.04), gm, 0, 0.50, d / 2 + 0.04, false, false));
        ground.add(mesh(new THREE.BoxGeometry(w - 0.08, 0.06, 0.22), M_WOOD, 0, 0.96, d / 2 + 0.08, false, false));
        // Clean demo display benches in the window showcase
        const laptopScreenMat = mat(0x38BDF8, 0.2, 0, 0x0284C7, 0.8);
        [-0.42, 0.42].forEach(function (tx) {
          ground.add(mesh(roundedBox(0.36, 0.24, 0.18, 0.02), M_WHITE, tx, 0.18, d / 2 + 0.08));
          ground.add(mesh(new THREE.BoxGeometry(0.18, 0.015, 0.12), laptopScreenMat, tx, 0.31, d / 2 + 0.08, false, false));
        });
      },

      // 7. Shopping - Travel (Streamline Art-Deco Agency)
      shop_travel: function (ground, w, d, cfg, bodyMat) {
        const gm = glassMaterial(0xBFE3FA); registerGlass(gm);
        ground.add(mesh(new THREE.BoxGeometry(w - 0.44, 0.65, 0.05), gm, 0, 0.50, d / 2 + 0.03, false, false));
        [-w * 0.30, w * 0.30].forEach(function (px) {
          const ph = mesh(new THREE.TorusGeometry(0.16, 0.03, 8, 20), M_GOLD, px, 0.55, d / 2 + 0.06, false, false);
          ground.add(ph);
        });
        stripedAwning(ground, w, d, "#3B82F6", "#FFFFFF", 0.98);
      },

      // 8. Shopping - Arcade (Retro Neon Stepped Marquee)
      shop_arcade: function (ground, w, d, cfg, bodyMat) {
        const gm = glassMaterial(0x8FD3F4); registerGlass(gm);
        ground.add(mesh(new THREE.BoxGeometry(w - 0.4, 0.72, 0.05), gm, 0, 0.48, d / 2 + 0.03, false, false));
        const neonMat = mat(0xEC4899, 0.3, 0, 0xEC4899, 1.8);
        ground.add(mesh(new THREE.BoxGeometry(w - 0.32, 0.06, 0.07), neonMat, 0, 0.92, d / 2 + 0.06, false, false));
        ground.add(mesh(new THREE.BoxGeometry(0.06, 0.90, 0.07), neonMat, -(w - 0.32) / 2, 0.48, d / 2 + 0.06, false, false));
        ground.add(mesh(new THREE.BoxGeometry(0.06, 0.90, 0.07), neonMat,  (w - 0.32) / 2, 0.48, d / 2 + 0.06, false, false));
        animObjects.push({ type: "neon_pulse", mat: neonMat, base: 0.8, range: 1.8, phase: 0.5 });
      },

      // 9. Housing - Main (Classic Brick Townhouse with Raised Stoop)
      house_tower: function (ground, w, d, cfg, bodyMat) {
        const gm = glassMaterial(0xFEF3C7); registerGlass(gm);
        ground.add(mesh(new THREE.BoxGeometry(0.44, 0.74, 0.06), mat(0x1E293B, 0.7), w * 0.25, 0.48, d / 2 + 0.03, false, false));
        ground.add(mesh(new THREE.SphereGeometry(0.035, 6, 6), M_GOLD, w * 0.25 + 0.14, 0.48, d / 2 + 0.07, false, false));
        for (let st = 0; st < 3; st++) {
          const sy = 0.04 + st * 0.07;
          const sz = d / 2 + 0.12 + (2 - st) * 0.12;
          ground.add(mesh(new THREE.BoxGeometry(0.60, 0.07, 0.14), M_WARM_STONE, w * 0.25, sy, sz, false, false));
        }
        [w * 0.25 - 0.32, w * 0.25 + 0.32].forEach(function (rx) {
          ground.add(mesh(new THREE.BoxGeometry(0.04, 0.32, 0.38), M_DARKFRAME, rx, 0.26, d / 2 + 0.24, false, false));
        });
        [-w * 0.26].forEach(function (wx) {
          ground.add(mesh(new THREE.BoxGeometry(0.48, 0.54, 0.05), gm, wx, 0.62, d / 2 + 0.03, false, false));
          ground.add(mesh(new THREE.BoxGeometry(0.52, 0.06, 0.08), M_WARM_STONE, wx, 0.32, d / 2 + 0.05, false, false));
          ground.add(mesh(roundedBox(0.46, 0.14, 0.14, 0.02), M_TERRACOTTA_POT, wx, 0.36, d / 2 + 0.12));
          [-0.14, 0, 0.14].forEach(function (fx) {
            ground.add(mesh(new THREE.SphereGeometry(0.055, 6, 6), mat(fx === 0 ? 0xFFFFFF : 0xEF4444, 0.8), wx + fx, 0.46, d / 2 + 0.12, false, false));
          });
        });
      },

      // 10. Housing - Utilities (Industrial Substation with Cooling Louvers & Heavy Pipes)
      house_util: function (ground, w, d, cfg, bodyMat) {
        ground.add(mesh(new THREE.BoxGeometry(w + 0.04, 0.12, d + 0.04), mat(0x18181B, 0.9), 0, 0.06, 0, false, false));
        ground.add(mesh(new THREE.BoxGeometry(0.50, 0.74, 0.06), mat(0x334155, 0.8), w * 0.22, 0.42, d / 2 + 0.03, false, false));
        const louverMat = mat(0x1E293B, 0.85);
        for (let ly = 0.30; ly < 0.75; ly += 0.09) {
          ground.add(mesh(new THREE.BoxGeometry(0.65, 0.035, 0.05), louverMat, -w * 0.24, ly, d / 2 + 0.03, false, false));
        }
      },

      // 11. Housing - Subscriptions (Asymmetric Smart Villa with Cedar Slats)
      house_subs: function (ground, w, d, cfg, bodyMat) {
        const slatMat = mat(0x92400E, 0.8);
        for (let sx = 0.05; sx < w / 2 - 0.08; sx += 0.11) {
          ground.add(mesh(new THREE.BoxGeometry(0.065, FLOOR_H * 0.95, 0.04), slatMat, sx, FLOOR_H * 0.48, d / 2 + 0.03, false, false));
        }
        const gm = glassMaterial(0xCFE9FB); registerGlass(gm);
        ground.add(mesh(new THREE.BoxGeometry(w * 0.46, 0.76, 0.05), gm, -w * 0.24, 0.50, d / 2 + 0.03, false, false));
      },

      // 12. South - Pharmacy (Scandinavian Minimalist Apothecary)
      health_pharmacy: function (ground, w, d, cfg, bodyMat) {
        const gm = glassMaterial(0xCFE9FB); registerGlass(gm);
        ground.add(mesh(new THREE.BoxGeometry(w - 0.44, 0.74, 0.05), gm, 0, 0.50, d / 2 + 0.03, false, false));
        ground.add(mesh(new THREE.BoxGeometry(0.38, 0.72, 0.06), mat(0x16A34A, 0.6), w * 0.26, 0.38, d / 2 + 0.04, false, false));
        const cm = mat(0x16A34A, 0.4, 0, 0x16A34A, 1.4);
        const cross = new THREE.Group(); cross.position.set(-w * 0.36, 0.98, d / 2 + 0.16); ground.add(cross);
        cross.add(mesh(new THREE.BoxGeometry(0.12, 0.38, 0.06), cm, 0, 0, 0, false, false));
        cross.add(mesh(new THREE.BoxGeometry(0.38, 0.12, 0.06), cm, 0, 0, 0, false, false));
        cross.add(mesh(new THREE.BoxGeometry(0.04, 0.04, 0.20), M_DARKFRAME, 0, 0, -0.12, false, false));
      },

      // 13. South - Learning (Old English Curiosity Bookshop)
      museum_curiosities: function (ground, w, d, cfg, bodyMat) {
        const beamMat = mat(0x451A03, 0.9);
        ground.add(mesh(new THREE.BoxGeometry(w + 0.04, 0.08, 0.08), beamMat, 0, 0.98, d / 2 + 0.04, false, false));
        [-w / 2 + 0.12, 0, w / 2 - 0.12].forEach(function (bx) {
          ground.add(mesh(new THREE.BoxGeometry(0.08, 0.98, 0.08), beamMat, bx, 0.49, d / 2 + 0.04, false, false));
        });
        const gm = glassMaterial(0xFEF3C7); registerGlass(gm);
        ground.add(mesh(new THREE.BoxGeometry(w * 0.38, 0.62, 0.05), gm, -w * 0.24, 0.50, d / 2 + 0.03, false, false));
        ground.add(mesh(new THREE.BoxGeometry(0.38, 0.68, 0.06), beamMat, w * 0.24, 0.36, d / 2 + 0.04, false, false));
      },

      // 14. South - Sorting / Post (Royal Red Postal Station)
      city_sorting_hub: function (ground, w, d, cfg, bodyMat) {
        [-w / 2 + 0.08, w / 2 - 0.08].forEach(function (qx) {
          for (let qy = 0.12; qy < 0.95; qy += 0.22) {
            ground.add(mesh(new THREE.BoxGeometry(0.16, 0.10, 0.10), M_WARM_STONE, qx, qy, d / 2 + 0.03, false, false));
          }
        });
        const gm = glassMaterial(0xFEF3C7); registerGlass(gm);
        ground.add(mesh(new THREE.BoxGeometry(w - 0.50, 0.70, 0.05), gm, 0, 0.50, d / 2 + 0.03, false, false));
        ground.add(mesh(new THREE.BoxGeometry(0.42, 0.72, 0.06), mat(0x1E293B, 0.8), 0, 0.38, d / 2 + 0.04, false, false));
        ground.add(mesh(new THREE.BoxGeometry(0.16, 0.035, 0.03), M_GOLD, 0, 0.44, d / 2 + 0.08, false, false));
      }
    };

    // ────────────────────────────────────────────────────────────────
    // 🏢 3g. CUSTOM UPPER FLOORS — Bespoke upper-level architecture
    // ────────────────────────────────────────────────────────────────
    const CUSTOM_FLOORS = {
      // Boutique: French windows with wrought-iron Juliet balconies and flower boxes
      shop_boutique: function (f, w, d, i, cfg, bodyMat) {
        f.add(mesh(roundedBox(w - 0.06, FLOOR_H, d - 0.06, 0.08), bodyMat, 0, FLOOR_H / 2, 0));
        const gm = glassMaterial(cfg.glass); registerGlass(gm);
        [-w * 0.22, w * 0.22].forEach(function (wx) {
          f.add(mesh(new THREE.BoxGeometry(0.38, 0.65, 0.05), gm, wx, FLOOR_H * 0.50, d / 2 + 0.02, false, false));
          f.add(mesh(new THREE.BoxGeometry(0.46, 0.22, 0.14), M_DARKFRAME, wx, FLOOR_H * 0.20, d / 2 + 0.08, false, false));
          f.add(mesh(roundedBox(0.42, 0.10, 0.12, 0.02), M_TERRACOTTA_POT, wx, FLOOR_H * 0.14, d / 2 + 0.12));
          [-0.12, 0.12].forEach(function (fx) {
            f.add(mesh(new THREE.SphereGeometry(0.045, 6, 6), mat(0xFB7185, 0.8), wx + fx, FLOOR_H * 0.22, d / 2 + 0.12, false, false));
          });
        });
      },

      // Housing Townhouse: Projecting 3-sided bay windows on upper floors
      house_tower: function (f, w, d, i, cfg, bodyMat) {
        f.add(mesh(roundedBox(w - 0.08, FLOOR_H, d - 0.08, 0.08), bodyMat, 0, FLOOR_H / 2, 0));
        const gm = glassMaterial(0xFEF3C7); registerGlass(gm);
        const bay = mesh(roundedBox(w * 0.52, FLOOR_H * 0.82, 0.32, 0.06), bodyMat, -w * 0.15, FLOOR_H * 0.46, d / 2 + 0.08);
        f.add(bay);
        bay.add(mesh(new THREE.BoxGeometry(w * 0.44, 0.56, 0.04), gm, 0, 0.04, 0.16, false, false));
        f.add(mesh(new THREE.BoxGeometry(0.42, 0.54, 0.05), gm, w * 0.25, FLOOR_H * 0.52, d / 2 + 0.02, false, false));
      },

      // Bistro: Upper floor dining terrace with wooden railing and hanging vines
      food_bistro: function (f, w, d, i, cfg, bodyMat) {
        f.add(mesh(roundedBox(w - 0.06, FLOOR_H, d - 0.06, 0.08), bodyMat, 0, FLOOR_H / 2, 0));
        windowBand(f, w, d, FLOOR_H * 0.55, { tint: 0xFEF3C7, faces: ["front"] });
        if (i === 0) {
          f.add(mesh(new THREE.BoxGeometry(w * 0.72, 0.08, 0.48), M_WOOD, 0, FLOOR_H * 0.18, d / 2 + 0.22, false, false));
          f.add(mesh(new THREE.BoxGeometry(w * 0.72, 0.26, 0.05), M_MULLION, 0, FLOOR_H * 0.18 + 0.16, d / 2 + 0.44, false, false));
          f.add(mesh(new THREE.SphereGeometry(0.12, 6, 6), M_HEDGE, -w * 0.26, FLOOR_H * 0.18 + 0.16, d / 2 + 0.30, false, false));
        }
      }
    };

    // ────────────────────────────────────────────────────────────────
    // 🏛️ 4. CIVIC PLAZA & THE "SPENT" LANDMARK
    // The one fixed landmark. Everything else is built by what the month costs.
    // ────────────────────────────────────────────────────────────────
    addSidewalkBlock(0, 0, 8.6, 8.6);
    addKerb(0, 0, 8.6, 8.6);

    const plazaInlay = mesh(new THREE.CylinderGeometry(2.75, 2.75, 0.03, 36), mat(0xEFE7D8, 0.9), 0, Y_WALK + 0.01, 1.3, false, true);
    root.add(plazaInlay);
    const plazaRim = mesh(new THREE.TorusGeometry(2.75, 0.06, 6, 44), M_WARM_STONE, 0, Y_WALK + 0.02, 1.3, false, false);
    plazaRim.rotation.x = -Math.PI / 2; root.add(plazaRim);

    const fountainGroup = new THREE.Group();
    fountainGroup.position.set(0, Y_WALK, 1.3);
    root.add(fountainGroup);
    fountainGroup.add(mesh(new THREE.CylinderGeometry(1.25, 1.35, 0.22, 24), mat(0xE7E1D2, 0.55), 0, 0.11, 0));
    const fountRim = mesh(new THREE.TorusGeometry(1.27, 0.06, 6, 28), M_WARM_STONE, 0, 0.22, 0, false, false);
    fountRim.rotation.x = -Math.PI / 2; fountainGroup.add(fountRim);
    const fWater = mesh(new THREE.CylinderGeometry(1.15, 1.15, 0.04, 24), M_WATER, 0, 0.24, 0);
    const fSpout = mesh(new THREE.CylinderGeometry(0.06, 0.10, 0.70, 8), mat(0x93C5FD, 0.45, 0, 0x38BDF8, 0.7), 0, 0.52, 0);
    fountainGroup.add(fWater, fSpout);
    fountainGroup.add(mesh(new THREE.CylinderGeometry(0.16, 0.22, 0.26, 10), M_MARBLE_REF, 0, 0.30, 0));
    animObjects.push({ type: "fountain_spout", spout: fSpout });

    const fRippleMat = new THREE.MeshBasicMaterial({ color: 0xE0F2FE, transparent: true, opacity: 0.65, depthWrite: false });
    const fRipple = new THREE.Mesh(new THREE.RingGeometry(0.18, 0.32, 24), fRippleMat);
    fRipple.rotation.x = -Math.PI / 2;
    fRipple.position.set(0, 0.267, 0);
    fountainGroup.add(fRipple);
    animObjects.push({ type: "fountain_ripple", ring: fRipple, mat: fRippleMat });

    const spentGroup = new THREE.Group();
    spentGroup.position.set(0, Y_WALK, -1.9);
    root.add(spentGroup);

    spentGroup.add(mesh(roundedBox(3.8, 2.1, 2.7, 0.12), M_CREAM, 0, 1.05, 0));
    spentGroup.add(mesh(roundedBox(4.3, 0.16, 3.2, 0.08), M_WARM_STONE, 0, 0.08, 0.10, false, true));
    spentGroup.add(mesh(roundedBox(4.0, 0.12, 2.9, 0.06), M_WARM_STONE, 0, 0.20, 0.06, false, true));
    for (let i = -2; i <= 2; i++) {
      spentGroup.add(mesh(new THREE.CylinderGeometry(0.11, 0.12, 1.52, 12), M_WHITE, i * 0.55, 1.02, 1.58));
      spentGroup.add(mesh(new THREE.CylinderGeometry(0.15, 0.15, 0.10, 12), M_WHITE, i * 0.55, 0.31, 1.58, false, false));
      spentGroup.add(mesh(new THREE.CylinderGeometry(0.15, 0.15, 0.08, 12), M_WHITE, i * 0.55, 1.80, 1.58, false, false));
    }
    spentGroup.add(mesh(new THREE.BoxGeometry(2.24, 0.20, 0.50), M_WHITE, 0, 1.88, 1.58));
    (function () {
      const sh = new THREE.Shape();
      sh.moveTo(-1.16, 0); sh.lineTo(1.16, 0); sh.lineTo(0, 0.54); sh.closePath();
      const geo = new THREE.ExtrudeGeometry(sh, { depth: 0.30, bevelEnabled: false });
      geo.translate(0, 0, -0.15);
      spentGroup.add(mesh(geo, M_CREAM, 0, 1.98, 1.58));
    })();
    const spentSignMat = new THREE.MeshStandardMaterial({ map: signTex("SPENT", "#1E293B", "#F59E0B", 38) });
    spentGroup.add(mesh(new THREE.BoxGeometry(1.5, 0.30, 0.05), spentSignMat, 0, 1.62, 1.36, false, false));
    const civicGlass = glassMaterial(0x9FC7F0); registerGlass(civicGlass);
    [-1.35, 1.35].forEach(function (x) {
      spentGroup.add(mesh(new THREE.BoxGeometry(0.52, 0.78, 0.05), civicGlass, x, 1.05, 1.36, false, false));
      spentGroup.add(mesh(new THREE.BoxGeometry(0.06, 0.82, 0.06), M_MULLION, x, 1.05, 1.38, false, false));
    });
    roofDeck(spentGroup, 3.8, 2.7, 2.1, { ac: true, vent: true, tank: false });

    const tower = mesh(roundedBox(1.35, 2.3, 1.35, 0.10), M_CREAM, 0, 3.25, -0.10);
    spentGroup.add(tower);
    spentGroup.add(mesh(roundedBox(1.55, 0.14, 1.55, 0.06), M_WARM_STONE, 0, 4.45, -0.10, false, false));
    const clockM = new THREE.MeshBasicMaterial({ map: clockTex() });
    spentGroup.add(mesh(new THREE.PlaneGeometry(0.72, 0.72), clockM, 0, 3.85, 0.59, false, false));
    const clockBack = mesh(new THREE.PlaneGeometry(0.72, 0.72), clockM, 0, 3.85, -0.79, false, false);
    clockBack.rotation.y = Math.PI; spentGroup.add(clockBack);
    const spire = mesh(new THREE.ConeGeometry(1.05, 1.7, 4), mat(0x2FA88A, 0.55), 0, 5.35, -0.10);
    spire.rotation.y = Math.PI / 4;
    spentGroup.add(spire);
    spentGroup.add(mesh(new THREE.SphereGeometry(0.13, 10, 10), M_GOLD, 0, 6.28, -0.10));

    packRigidModel(spentGroup);
    const spentProxy = hitProxy(4.2, 4.4, 3.2);
    spentProxy.position.z = 0.1;
    spentProxy.userData = { id: "finance_bank", district: "civic", name: "עיריית SPENT", amount: 0, trend: "מרכז העיר והממשל", shell: spentGroup };
    spentGroup.add(spentProxy);
    interactiveBuildings.push(spentProxy);
    buildingRoots["finance_bank"] = spentGroup;

    // Plaza life: trees, benches, bins, a busker and pigeons
    [[-3.2, 3.2], [3.2, 3.2], [-3.3, -0.4], [3.3, -0.4], [-3.2, -3.3], [3.2, -3.3]].forEach(function (p) {
      const h = new THREE.Group(); h.position.set(p[0], Y_WALK, p[1]); root.add(h);
      planterBox(h, 0, 0, "tree");
    });
    addBenchAt(-2.2, 3.1, 0.7);
    addBenchAt(2.2, 3.1, -0.7);
    addBenchAt(3.0, 1.0, -Math.PI / 2);
    (function () { const h = new THREE.Group(); h.position.set(1.9, Y_WALK, 3.8); root.add(h); trashBin(h, 0, 0); })();

    // Busker by the fountain
    const busker = makeFigure({ shirt: 0x7C3AED, pants: 0x1E293B, hair: 0x1F1207 });
    busker.position.set(-1.8, Y_WALK, 2.5);
    busker.rotation.y = 0.9;
    root.add(busker);
    (function () {
      const gtr = mesh(roundedBox(0.16, 0.36, 0.07, 0.06), M_WOOD, 0.14, 0.44, 0.10, false, false);
      gtr.rotation.z = -0.5; busker.add(gtr);
      busker.add(mesh(new THREE.BoxGeometry(0.03, 0.30, 0.03), M_DARKFRAME, 0.30, 0.66, 0.10, false, false));
      const cse = mesh(roundedBox(0.34, 0.07, 0.22, 0.03), mat(0x92400E, 0.85), -0.35, 0.04, 0.16, false, false);
      busker.add(cse);
    })();
    const pigeons = [];
    [[-1.0, 3.2], [-0.5, 3.6], [0.4, 3.9]].forEach(function (p) {
      const pg = makePigeon(); pg.position.set(p[0], Y_WALK, p[1]); pg.rotation.y = Math.random() * 6; root.add(pg);
      pigeons.push({ obj: pg, phase: Math.random() * 6 });
    });

    // ────────────────────────────────────────────────────────────────
    // 🏡 5. NORTH — HOUSING. The largest line in anyone's month, so it faces the plaza
    // and gets the deepest block.
    // ────────────────────────────────────────────────────────────────
    addSidewalkBlock(0, -9.2, 8.8, 4.8);
    addKerb(0, -9.2, 8.8, 4.8);

    makeBuilding({
      id: "house_tower", minTier: 2, district: "housing", name: "מגורים ושכירות", trend: "שכר דירה או משכנתא",
      kind: "house", x: -2.85, z: -9.4, w: 2.65, d: 2.55,
      body: 0xF2DFC2, roof: 0xEF7657, accent: 0x47617A, glass: 0xC8E1EF,
      chimney: true, balcony: true, roofStyle: "pitch",
      props: [
        { type: "hedge", x: 0, z: 1.62, w: 2.3, d: 0.30, from: 2 },
        { type: "planter", x: -1.50, z: 1.48, kind: "flowers", from: 2 }
      ]
    });
    makeBuilding({
      id: "house_util", minTier: 1, district: "housing", name: "חשבונות בית", trend: "חשמל, מים, גז וארנונה",
      kind: "house", x: 0.0, z: -9.1, w: 2.05, d: 2.20,
      body: 0xD7E6EE, roof: 0x5685C5, accent: 0xE6B94B, glass: 0xBBD7E8, roofStyle: "deck", vent: true, solar: false,
      props: [
        { type: "hedge", x: 0, z: 1.50, w: 1.8, d: 0.26, from: 2 },
        { type: "bin", x: 1.18, z: 1.38, from: 2 }
      ]
    });
    makeBuilding({
      id: "house_subs", minTier: 1, district: "housing", name: "מנויים וסטרימינג", trend: "שירותים דיגיטליים חודשיים",
      kind: "house", x: 2.85, z: -9.4, w: 2.30, d: 2.45,
      body: 0xF4E7D4, roof: 0x526A84, accent: 0x7A87BD, glass: 0xC7DFEC, roofStyle: "monopitch",
      props: [
        { type: "planter", x: -1.26, z: 1.42, kind: "shrub", from: 2 },
        { type: "planter", x: 1.26, z: 1.42, kind: "flowers", from: 3 }
      ]
    });

    // ────────────────────────────────────────────────────────────────
    // 🛍️ 6. WEST — SHOPPING. Regular but not daily, so it faces the plaza across a street.
    // ────────────────────────────────────────────────────────────────
    addSidewalkBlock(-9.2, 0, 4.8, 8.8);
    addKerb(-9.2, 0, 4.8, 8.8);

    makeBuilding({
      id: "shop_boutique", district: "shopping", name: "אופנה ובוטיק", trend: "ביגוד, הנעלה ואופנה",
      kind: "shop", x: -9.3, z: -3.3, w: 1.80, d: 2.40, rotY: Math.PI / 2,
      body: 0xF7E5D0, roof: 0xE47C68, accent: 0xE56F72, glass: 0xCBE3EF, roofStyle: "mansard",
      awning: ["#E87368", "#FFF8ED"], balcony: true,
      sign: { text: "BOUTIQUE", bg: "#B65355", fg: "#FFF8ED", size: 24 }
    });
    makeBuilding({
      id: "shop_tech", district: "shopping", name: "טכנולוגיה", trend: "מחשבים, גאדג'טים וחשמל",
      kind: "shop", x: -9.05, z: -1.1, w: 2.05, d: 2.10, rotY: Math.PI / 2,
      body: 0xD9E7ED, roof: 0x486881, accent: 0x52A7D1, glass: 0xB9DAEA, roofStyle: "modern_cantilever", solar: true,
      sign: { text: "TECH", bg: "#397FA8", fg: "#FFFDF7", size: 32 }
    });
    makeBuilding({
      id: "shop_travel", district: "shopping", name: "חופשות וטיסות", trend: "נסיעות, טיסות ומלונות",
      kind: "shop", x: -9.3, z: 1.15, w: 1.80, d: 2.30, rotY: Math.PI / 2,
      body: 0xF5E9D7, roof: 0x5B92CF, accent: 0x62ADD5, glass: 0xC1DEEC, roofStyle: "dome",
      awning: ["#568ECD", "#FFF9EE"],
      sign: { text: "TRAVEL", bg: "#427DAE", fg: "#FFF9EE", size: 26 }
    });
    makeBuilding({
      id: "shop_arcade", district: "shopping", name: "בילויים וגיימינג", trend: "קולנוע, משחקים ואטרקציות",
      kind: "shop", x: -9.15, z: 3.3, w: 2.00, d: 2.30, rotY: Math.PI / 2,
      body: 0xDDD5E8, roof: 0x7773A8, accent: 0xD874AD, glass: 0xB8D9EB, roofStyle: "stepped",
      sign: { text: "ARCADE", bg: "#78618E", fg: "#FFF0A8", size: 26 }
    });

    // ────────────────────────────────────────────────────────────────
    // 🍜 7. EAST — FOOD. Four separate places, because groceries, a restaurant, coffee
    // and delivery are four different habits and the app already tracks them apart.
    // ────────────────────────────────────────────────────────────────
    // A wider outer pavement separates cafe seating from the busier walking lane.
    // The inner kerb stays at x=6.8; no road or building moves.
    addSidewalkBlock(9.8, 0, 6.0, 8.8);
    addKerb(9.8, 0, 6.0, 8.8);

    makeBuilding({
      id: "food_super", minTier: 1, district: "food", name: "סופרמרקט", trend: "קניות שבועיות במכולת",
      kind: "shop", x: 9.2, z: -3.25, w: 2.25, d: 2.10, rotY: Math.PI / 2,
      body: 0xF6E9D5, roof: 0x55A665, accent: 0x73BA65, glass: 0xC5DFEC, roofStyle: "deck",
      sign: { text: "SUPER", bg: "#438B54", fg: "#FFF9EE", size: 28 }
    });
    makeBuilding({
      id: "food_bistro", district: "food", name: "מסעדות", trend: "ארוחות בחוץ",
      kind: "shop", x: 9.4, z: -1.05, w: 1.80, d: 2.40, rotY: Math.PI / 2,
      body: 0xF1CFA2, roof: 0xB9734C, accent: 0xE3944F, glass: 0xF6DFB9, roofStyle: "pergola",
      awning: ["#E46F58", "#FFF1D7"],
      sign: { text: "BISTRO", bg: "#AD5749", fg: "#FFF1D7", size: 26 }
    });
    makeBuilding({
      id: "food_coffee", minTier: 1, district: "food", name: "קפה ומאפים", trend: "הרגל הקפה היומי",
      kind: "shop", x: 9.1, z: 1.15, w: 1.70, d: 2.10, rotY: Math.PI / 2,
      body: 0xEEDFC7, roof: 0x9B694B, accent: 0xBA8357, glass: 0xF6DFB9, roofStyle: "pitch", chimney: true, dormer: true,
      awning: ["#5C9691", "#FFF2D9"],
      sign: { text: "CAFE", bg: "#A86443", fg: "#FFF2D9", size: 34 }
    });
    makeBuilding({
      id: "food_wolt", district: "food", name: "משלוחי אוכל", trend: "וולט, תן ביס ומשלוחים",
      kind: "shop", x: 9.3, z: 3.3, w: 2.10, d: 2.20, rotY: Math.PI / 2,
      body: 0xD5E7EC, roof: 0x4A91A6, accent: 0x5DB8C9, glass: 0xBEDDE9, roofStyle: "deck", vent: true,
      sign: { text: "DELIVERY", bg: "#397C91", fg: "#FFFDF7", size: 22 }
    });

    // ☕ Warm bakery / cafe chimney smoke puffs, enabled by actual coffee visits.
    const coffeeSmoke = new THREE.Group(); coffeeSmoke.visible = false;
    (function () {
      const smokeGroup = coffeeSmoke;
      smokeGroup.position.set(9.25, 2.35, 1.05);
      root.add(smokeGroup);
      const smokePuffs = [];
      for (let si = 0; si < 4; si++) {
        const smMat = new THREE.MeshStandardMaterial({
          color: 0xF8FAFC,
          roughness: 0.9,
          transparent: true,
          opacity: 0.55,
          depthWrite: false
        });
        const sp = new THREE.Mesh(new THREE.DodecahedronGeometry(0.09, 1), smMat);
        sp.position.set(0, si * 0.28, 0);
        smokeGroup.add(sp);
        smokePuffs.push({ mesh: sp, mat: smMat, phase: si * 0.25 });
      }
      animObjects.push({ type: "chimney_smoke", puffs: smokePuffs });
    })();

    // ────────────────────────────────────────────────────────────────
    // 🩹 8. SOUTH — THE OCCASIONAL ROW
    // A plaster is not a hospital. Pharmacy, community learning and the sorting booth are
    // side expenses, so they get small storefronts on a shared street, not monuments.
    // ────────────────────────────────────────────────────────────────
    addSidewalkBlock(0, 9.2, 8.8, 4.8);
    addKerb(0, 9.2, 8.8, 4.8);

    makeBuilding({
      id: "health_pharmacy", district: "civic", name: "בית מרקחת", trend: "תרופות, פארם ובריאות",
      kind: "shop", x: -2.85, z: 9.2, w: 2.20, d: 2.10, maxTier: 3,
      body: 0xF5EBDD, roof: 0x5AA568, accent: 0x86C989, glass: 0xC5DFEC, roofStyle: "deck", vent: true,
      sign: { text: "PHARMA", bg: "#438B55", fg: "#FFFDF7", size: 24 },
      props: [{ type: "planter", x: -1.24, z: 1.38, kind: "shrub", from: 2 }]
    });
    makeBuilding({
      id: "museum_curiosities", district: "civic", name: "לימודים וקהילה", trend: "השכלה, ספרים ופנאי מסקרן",
      kind: "shop", x: 0.0, z: 9.35, w: 2.10, d: 2.20, maxTier: 3,
      body: 0xE6D2B4, roof: 0x4A6077, accent: 0xA87550, glass: 0xF1DDB8, roofStyle: "pitch", chimney: true,
      sign: { text: "BOOKS", bg: "#496B92", fg: "#FFF0D6", size: 28 },
      props: [{ type: "aframe", x: 1.16, z: 1.38, rotY: -0.4, from: 2 }]
    });
    makeBuilding({
      id: "city_sorting_hub", minTier: 1, district: "civic", name: "עמדת המיון והדואר", trend: "הוצאות שעוד לא סווגו",
      kind: "shop", x: 2.85, z: 9.1, w: 2.10, d: 2.00, maxTier: 2,
      body: 0xF0D2C6, roof: 0x4B6076, accent: 0xD46A5C, glass: 0xF0DDBF, roofStyle: "pitch",
      sign: { text: "POST", bg: "#B75B54", fg: "#FFFDF7", size: 30 },
      props: [{ type: "bollards", x: 0, z: 1.42, from: 2 }]
    });

    // ────────────────────────────────────────────────────────────────
    // 🚌 9. SOUTH-EAST — TRANSPORT YARD
    // Getting around is a real monthly line, so it gets its own corner rather than only
    // showing up as traffic. It fills out as transport spending rises.
    // ────────────────────────────────────────────────────────────────
    addSidewalkBlock(9.2, 9.2, 5.0, 5.0);
    addKerb(9.2, 9.2, 5.0, 5.0);

    const transportYard = new THREE.Group();
    transportYard.position.set(9.2, Y_WALK, 9.2);
    root.add(transportYard);

    // Bus shelter
    transportYard.add(mesh(new THREE.BoxGeometry(2.5, 0.07, 1.0), mat(0x64748B, 0.6), -0.4, 1.10, -1.5, false, false));
    [-1.55, 1.55].forEach(function (x) {
      transportYard.add(mesh(new THREE.CylinderGeometry(0.045, 0.045, 1.10, 8), M_DARKFRAME, x - 0.4 + 0.4, 0.55, -1.5, false, false));
    });
    const shelterGlass = glassMaterial(0xCFE9FB); registerGlass(shelterGlass);
    transportYard.add(mesh(new THREE.BoxGeometry(2.4, 0.95, 0.05), shelterGlass, -0.4, 0.55, -1.95, false, false));
    transportYard.add(mesh(new THREE.BoxGeometry(2.0, 0.10, 0.34), M_WOOD, -0.4, 0.42, -1.65, false, false));
    transportYard.add(mesh(new THREE.BoxGeometry(0.5, 0.34, 0.05), new THREE.MeshStandardMaterial({ map: signTex("BUS", "#1D4ED8", "#FFFFFF", 30) }), 1.15, 1.35, -1.5, false, false));

    // Parking bays
    for (let i = 0; i < 3; i++) {
      transportYard.add(mesh(new THREE.BoxGeometry(0.05, 0.02, 1.7), whiteMarkMat, -1.7 + i * 1.15, 0.02, 1.1, false, false));
    }
    transportYard.add(mesh(new THREE.BoxGeometry(3.5, 0.02, 0.05), whiteMarkMat, -0.6, 0.02, 0.25, false, false));

    // Scooter / bike station — the units appear as transport spending grows
    const transportUnits = [];
    for (let i = 0; i < 4; i++) {
      const u = new THREE.Group();
      u.position.set(-1.8 + i * 0.95, 0, 2.2);
      u.rotation.y = 0.1;
      transportYard.add(u);
      u.add(mesh(new THREE.BoxGeometry(0.55, 0.05, 0.05), M_SLATE, 0, 0.30, -0.22, false, false));
      u.add(mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.30, 6), M_SLATE, -0.22, 0.15, -0.22, false, false));
      u.add(mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.30, 6), M_SLATE, 0.22, 0.15, -0.22, false, false));
      u.add(mesh(new THREE.TorusGeometry(0.12, 0.02, 8, 14), M_SLATE, -0.16, 0.14, 0.05, false, false));
      u.add(mesh(new THREE.TorusGeometry(0.12, 0.02, 8, 14), M_SLATE, 0.16, 0.14, 0.05, false, false));
      u.add(mesh(new THREE.BoxGeometry(0.34, 0.04, 0.04), mat(i % 2 ? 0x0EA5E9 : 0x22C55E, 0.5), 0, 0.22, 0.05, false, false));
      u.add(mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.34, 6), M_DARKFRAME, 0.16, 0.31, 0.05, false, false));
      transportUnits.push(u);
    }
    // A bus at the stand and a taxi in the bays, so the corner is never a bare lot
    (function () {
      const bus = createCar(0x2563EB, true, false);
      bus.position.set(-0.5, 0, -0.4); bus.rotation.y = Math.PI / 2; bus.scale.setScalar(1.15);
      transportYard.add(bus);
      const taxi = createCar(0xFACC15, false, true);
      taxi.position.set(1.6, 0, 1.1); taxi.rotation.y = 0.05;
      transportYard.add(taxi);
    })();
    transportYard.add(mesh(new THREE.BoxGeometry(0.7, 0.34, 0.06), new THREE.MeshStandardMaterial({ map: signTex("RIDE", "#0F766E", "#FFFFFF", 26) }), 0.55, 0.95, 2.55, false, false));
    transportYard.add(mesh(new THREE.CylinderGeometry(0.035, 0.045, 0.95, 6), M_DARKFRAME, 0.55, 0.47, 2.55, false, false));

    const transportHit = new THREE.Mesh(new THREE.BoxGeometry(5.2, 2.8, 5.2), new THREE.MeshBasicMaterial({ visible: false }));
    transportHit.position.set(0, 1.4, 0);
    transportHit.userData = { id: "trans_station", district: "transport", name: "מתחם תחבורה", amount: 0, trend: "התניידות ונסיעות" };
    transportYard.add(transportHit);
    interactiveBuildings.push(transportHit);
    buildingRoots["trans_station"] = transportYard;

    // ────────────────────────────────────────────────────────────────
    // 🏀 10. SOUTH-WEST — THE FREE PARK
    // Not everything on the island costs money. The court, the picnic table and the
    // benches are here so the city has somewhere that is simply pleasant.
    // ────────────────────────────────────────────────────────────────
    const courtGroup = new THREE.Group(); courtGroup.position.set(-9.2, Y_GRASS + 0.03, 8.8); root.add(courtGroup);
    courtGroup.add(mesh(new THREE.BoxGeometry(3.4, 0.03, 2.6), mat(0x1E8A4A, 0.85), 0, 0, 0, false, true));
    courtGroup.add(mesh(new THREE.BoxGeometry(2.5, 0.035, 2.0), mat(0xE2652A, 0.85), 0, 0.008, 0, false, true));
    courtGroup.add(mesh(new THREE.BoxGeometry(2.54, 0.04, 0.04), whiteMarkMat, 0, 0.016, -1.0, false, false));
    courtGroup.add(mesh(new THREE.BoxGeometry(2.54, 0.04, 0.04), whiteMarkMat, 0, 0.016, 1.0, false, false));
    const courtCircle = mesh(new THREE.TorusGeometry(0.45, 0.02, 6, 24), whiteMarkMat, 0, 0.016, 0, false, false);
    courtCircle.rotation.x = -Math.PI / 2; courtGroup.add(courtCircle);
    const bPost = mesh(new THREE.CylinderGeometry(0.035, 0.045, 1.3, 8), M_SLATE, 0, 0.65, -1.15, false, false);
    bPost.add(mesh(new THREE.BoxGeometry(0.60, 0.38, 0.03), M_WHITE, 0, 0.55, 0.10, false, false));
    bPost.add(mesh(new THREE.TorusGeometry(0.11, 0.02, 8, 12), mat(0xEA580C, 0.5), 0, 0.45, 0.22, false, false));
    courtGroup.add(bPost);
    for (let i = -1; i <= 1; i += 2) {
      for (let x = -1.7; x <= 1.7; x += 1.7) {
        courtGroup.add(mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.8, 5), M_SLATE, x, 0.40, i * 1.35, false, false));
      }
      courtGroup.add(mesh(new THREE.BoxGeometry(3.4, 0.03, 0.03), M_SLATE, 0, 0.78, i * 1.35, false, false));
    }

    // Picnic table under the trees
    (function () {
      const g = new THREE.Group(); g.position.set(-9.6, Y_GRASS, 11.4); g.rotation.y = 0.4; root.add(g);
      g.add(mesh(roundedBox(1.10, 0.07, 0.62, 0.03), M_WOOD, 0, 0.44, 0, false, false));
      g.add(mesh(roundedBox(1.10, 0.06, 0.22, 0.02), M_WOOD, 0, 0.26, -0.45, false, false));
      g.add(mesh(roundedBox(1.10, 0.06, 0.22, 0.02), M_WOOD, 0, 0.26, 0.45, false, false));
      g.add(mesh(new THREE.BoxGeometry(0.07, 0.44, 0.07), M_WOOD, -0.45, 0.22, 0, false, false));
      g.add(mesh(new THREE.BoxGeometry(0.07, 0.44, 0.07), M_WOOD, 0.45, 0.22, 0, false, false));
    })();
    addBenchAt(-6.4, 10.9, -0.5, Y_GRASS);
    addBenchAt(-11.9, 7.6, 1.4, Y_GRASS);

    // ────────────────────────────────────────────────────────────────
    // 🌿 10. NATURE RESERVE: LAKE, BRIDGE & WOODS (Hero Reference)
    // ────────────────────────────────────────────────────────────────
    // x=9.1, not 8.2: at 8.2 the lake spilled across the eastern road corridor.
    const reserveGroup = new THREE.Group(); reserveGroup.position.set(9.4, Y_GROUND, -9.4); root.add(reserveGroup);

    // Sandy shore so the water reads as a basin in the ground, not a slab laid on the grass
    const shoreGeo = new THREE.CylinderGeometry(3.05, 3.15, 0.10, 26);
    shoreGeo.scale(0.92, 1, 0.68);
    reserveGroup.add(mesh(shoreGeo, mat(0xE8D7A8, 0.92), -0.2, Y_GRASS - 0.02, 0, false, true));

    // Organic Lake Basin
    const lakeGeo = new THREE.CylinderGeometry(2.6, 2.8, 0.12, 24);
    lakeGeo.scale(0.92, 1, 0.68);
    const lakeMesh = mesh(lakeGeo, M_WATER, -0.2, Y_GRASS - 0.01, 0, false, true);
    reserveGroup.add(lakeMesh);
    lakeMesh.userData = { id: "savings_sanctuary", district: "savings", name: "שמורת הטבע", amount: 0, trend: "יציבות וחיסכון פיננסי" };
    interactiveBuildings.push(lakeMesh); buildingRoots["savings_sanctuary"] = reserveGroup;

    // Invisible hit volume over the entire reserve area so tapping anywhere selects the sanctuary
    const reserveHit = new THREE.Mesh(
      new THREE.CylinderGeometry(3.6, 3.8, 2.5, 16),
      new THREE.MeshBasicMaterial({ visible: false })
    );
    reserveHit.position.set(-0.2, Y_GRASS + 0.8, 0);
    reserveHit.userData = lakeMesh.userData;
    reserveGroup.add(reserveHit);
    interactiveBuildings.push(reserveHit);

    // Lake surface ripple ring
    const lakeRippleMat = new THREE.MeshBasicMaterial({ color: 0xC7D2FE, transparent: true, opacity: 0.45, depthWrite: false });
    const lakeRipple = new THREE.Mesh(new THREE.RingGeometry(0.3, 0.45, 24), lakeRippleMat);
    lakeRipple.rotation.x = -Math.PI / 2;
    lakeRipple.position.set(-0.2, Y_GRASS + 0.01, 0);
    reserveGroup.add(lakeRipple);
    animObjects.push({ type: "lake_ripple", ring: lakeRipple, mat: lakeRippleMat });

    // Arched Wooden Footbridge
    const bridge = new THREE.Group(); bridge.position.set(-0.2, Y_GRASS + 0.10, 0); bridge.rotation.y = Math.PI / 5; reserveGroup.add(bridge);
    bridge.add(mesh(new THREE.BoxGeometry(0.75, 0.06, 2.4), M_WOOD, 0, 0.12, 0));
    bridge.add(mesh(new THREE.BoxGeometry(0.05, 0.26, 2.4), M_WOOD, -0.35, 0.25, 0));
    bridge.add(mesh(new THREE.BoxGeometry(0.05, 0.26, 2.4), M_WOOD,  0.35, 0.25, 0));
    bridge.traverse(function (child) {
      if (child.isMesh) {
        child.userData = lakeMesh.userData;
        interactiveBuildings.push(child);
      }
    });

    // River Boulders framing the water
    const stoneMat = mat(0x94A3B8, 0.8);
    function addStone(sx, sz, s) {
      const b = mesh(new THREE.DodecahedronGeometry(0.32 * s, 1), stoneMat, sx, Y_GRASS + 0.04, sz);
      b.scale.set(1.2, 0.7, 1.0);
      b.userData = lakeMesh.userData;
      reserveGroup.add(b);
      interactiveBuildings.push(b);
    }
    addStone(-2.5,  0.4, 1.2);
    addStone(-1.8,  1.4, 0.9);
    addStone( 1.6,  0.8, 1.3);
    addStone( 1.4, -1.0, 1.0);

    ${citySlotsJs}
    // Small paved pockets outside storefronts keep additions off the carriageways.
    addSidewalkBlock(-11.8, 0, 1.5, 8.8);
    addSidewalkBlock(11.85, 0, 1.4, 8.8);

    // Permanent, bounded frontages. Unused places are planted seating, never rubble or
    // construction. These are separate from the user's six earned enrichment slots.
    addSidewalkBlock(-9.2, -9.5, 5.6, 3.8);
    addKerb(-9.2, -9.5, 5.6, 3.8);
    addSidewalkBlock(0, -11.75, 8.8, 1.25);
    const LIFE_PLOTS = [
      { id: "mixed-west", x: -10.9, z: -9.5, scale: 1, rot: 0, districts: ["food", "shopping"], shared: true, order: 0 },
      { id: "mixed-middle", x: -9.2, z: -9.5, scale: 1, rot: 0, districts: ["food", "shopping"], shared: true, order: 1 },
      { id: "mixed-east", x: -7.5, z: -9.5, scale: 1, rot: 0, districts: ["food", "shopping"], shared: true, order: 2 },
      { id: "food-north", x: 7.5, z: -2.3, scale: 0.60, rot: 0, districts: ["food"], shared: false, order: 0 },
      { id: "food-south", x: 7.5, z: 2.5, scale: 0.60, rot: 0, districts: ["food"], shared: false, order: 1 },
      { id: "shop-lane", x: -7.4, z: 0, scale: 0.60, rot: 0, districts: ["shopping"], shared: false, order: 0 },
      { id: "home-west", x: -2.85, z: -11.7, scale: 1, rot: 0, districts: ["housing"], shared: false, order: 0 },
      { id: "home-east", x: 2.85, z: -11.7, scale: 1, rot: 0, districts: ["housing"], shared: false, order: 1 },
      { id: "civic-west", x: -2.85, z: 7.55, scale: 0.65, rot: Math.PI, districts: ["civic"], shared: false, order: 0 },
      { id: "civic-middle", x: 0, z: 7.55, scale: 0.65, rot: Math.PI, districts: ["civic"], shared: false, order: 1 },
      { id: "civic-east", x: 2.85, z: 7.55, scale: 0.65, rot: Math.PI, districts: ["civic"], shared: false, order: 2 }
    ];
    LIFE_PLOTS.forEach(function (plot) {
      const g = new THREE.Group(); g.name = "quiet-frontage:" + plot.id;
      g.position.set(plot.x, Y_WALK, plot.z); g.rotation.y = plot.rot; g.scale.setScalar(plot.scale);
      planterBox(g, -0.40, 0, "flowers");
      hedgeRow(g, 0.24, -0.12, 0.55, 0.24);
      g.add(mesh(new THREE.BoxGeometry(0.55, 0.07, 0.26), M_WOOD, 0.24, 0.29, 0.23));
      [-0.18, 0.18].forEach(function (x) { g.add(mesh(new THREE.BoxGeometry(0.04, 0.26, 0.23), M_DARKFRAME, 0.24 + x, 0.13, 0.23, false, false)); });
      packRigidModel(g); root.add(g); plot.quiet = g;
    });

    // Conifer Pine & Deciduous Trees.
    // Foliage shares two materials so the reserve's health can be expressed as a single
    // colour lerp instead of walking every tree in the scene each time the data changes.
    const M_PINE = mat(0x2F874D, 0.88);
    const M_LEAF = mat(0x4EAA50, 0.86);
    const M_LEAF_LIGHT = mat(0x79BF58, 0.88);
    const PINE_LUSH = C(0x23824A), PINE_BASE = C(0x2F874D);
    const LEAF_LUSH = C(0x3BA44B), LEAF_BASE = C(0x4EAA50);
    const LEAF_LIGHT_LUSH = C(0x70C552), LEAF_LIGHT_BASE = C(0x79BF58);
    // Trees that answer to parkHealth. Each gets a stable rank in 0..1 and is planted only
    // when the reserve is healthy enough to reach that rank.
    const parkPlantings = [];

    function addPine(px, pz, h, group, rank) {
      const g = new THREE.Group(); g.position.set(px, Y_GRASS, pz);
      g.name = "layered-pine";
      g.add(mesh(new THREE.CylinderGeometry(0.035, 0.075, 1.05 * h, 7), M_WOOD, 0, 0.53 * h, 0));
      [[0.56, 0.78, 0.75], [0.43, 0.76, 1.15], [0.28, 0.71, 1.53]].forEach(function (p, i) {
        const crown = mesh(new THREE.ConeGeometry(p[0] * h, p[1] * h, 7), M_PINE, i === 1 ? 0.04 : 0, p[2] * h, 0);
        crown.rotation.y = i * 0.37 + px * 0.1; g.add(crown);
      });
      packRigidModel(g);
      (group || reserveGroup).add(g);
      if (rank !== undefined) parkPlantings.push({ obj: g, rank: rank });
      return g;
    }
    function addDecid(px, pz, s, group, rank) {
      const g = new THREE.Group(); g.position.set(px, Y_GRASS, pz);
      g.name = "branched-deciduous-tree";
      g.add(mesh(new THREE.CylinderGeometry(0.045 * s, 0.085 * s, 1.10 * s, 7), M_WOOD, 0, 0.55 * s, 0));
      [-1, 1].forEach(function (side) {
        const branch = mesh(new THREE.CylinderGeometry(0.022 * s, 0.039 * s, 0.52 * s, 6), M_WOOD, side * 0.13 * s, 0.83 * s, 0);
        branch.rotation.z = -side * 0.65; g.add(branch);
      });
      [[0, 1.40, 0, 0.41], [-0.31, 1.13, 0.04, 0.37], [0.32, 1.27, -0.04, 0.36],
       [0.07, 1.13, 0.29, 0.35], [-0.06, 1.26, -0.25, 0.33]].forEach(function (p, i) {
        const crown = mesh(new THREE.DodecahedronGeometry(p[3] * s, 0), i % 3 ? M_LEAF : M_LEAF_LIGHT, p[0] * s, p[1] * s, p[2] * s);
        crown.scale.y = 1.12; crown.rotation.y = px * 0.17 + i; g.add(crown);
      });
      packRigidModel(g);
      (group || reserveGroup).add(g);
      if (rank !== undefined) parkPlantings.push({ obj: g, rank: rank });
      return g;
    }
    // The reserve's own stand is the identity of the place, so it holds the lowest ranks and
    // survives even a bad month. The city never looks abandoned.
    addPine(-2.8, -2.4, 1.2, null, 0.00);
    addPine( 2.6, -2.4, 1.1, null, 0.00);
    addPine( 2.8,  2.2, 1.0, null, 0.10);
    addDecid(-2.8, 2.4, 1.0, null, 0.00);
    addDecid( 0.4, 2.6, 0.9, null, 0.18);
    addPine(-1.4, -3.0, 0.9, null, 0.34);
    addDecid( 2.0,  3.1, 0.8, null, 0.46);
    addPine( 0.9, -3.2, 0.8, null, 0.62);
    addDecid(-3.4, -0.6, 0.9, null, 0.80);

    // ────────────────────────────────────────────────────────────────
    // 🌳 10b. CITY GREENERY, LAMPS & BENCHES
    // The hero reference is dense with street planting; an island this size reads as
    // abandoned without it. Trees are scattered procedurally over whatever ground is not
    // road, pavement or lake, from a fixed seed so the layout is identical every launch.
    // ────────────────────────────────────────────────────────────────
    const ISLAND_HALF = 12.2;

    function isOpenGround(x, z) {
      if (Math.max(Math.abs(x), Math.abs(z)) > ISLAND_HALF) return false;
      if (SLOT_DEFS.some(function (s) { return Math.hypot(x - s.x, z - s.z) < (s.radius || 0.65) + 0.65; })) return false;
      if (COMPANION_LOCATIONS.some(function (s) { return Math.hypot(x - s.x, z - s.z) < 1 || (s.fallback && Math.hypot(x - s.fallback[0], z - s.fallback[1]) < 1); })) return false;
      // Road corridors (half-width 1.2, plus 0.7 of verge so nothing grows in the gutter)
      if (Math.abs(Math.abs(x) - ROAD_AT) < 1.9 && Math.abs(z) < 11.4) return false;
      if (Math.abs(Math.abs(z) - ROAD_AT) < 1.9 && Math.abs(x) < 11.4) return false;
      // Paved blocks, padded so canopies do not overhang a facade
      for (let i = 0; i < pavedBlocks.length; i++) {
        const b = pavedBlocks[i];
        if (x > b.x0 - 0.9 && x < b.x1 + 0.9 && z > b.z0 - 0.9 && z < b.z1 + 0.9) return false;
      }
      // The nature reserve plants itself
      if (Math.hypot(x - 9.4, z + 9.4) < 4.2) return false;
      return true;
    }

    // Deterministic LCG — the city must look the same on every launch.
    let _seed = 20260905;
    function rnd() { _seed = (_seed * 1664525 + 1013904223) % 4294967296; return _seed / 4294967296; }

    const cityTrees = [];
    let _planted = 0, _tries = 0;
    while (_planted < 32 && _tries++ < 6000) {
      const x = (rnd() * 2 - 1) * ISLAND_HALF;
      const z = (rnd() * 2 - 1) * ISLAND_HALF;
      if (!isOpenGround(x, z)) continue;
      let tooClose = false;
      for (let i = 0; i < cityTrees.length; i++) {
        if (Math.hypot(cityTrees[i].x - x, cityTrees[i].z - z) < 1.5) { tooClose = true; break; }
      }
      if (tooClose) continue;
      cityTrees.push({ x: x, z: z, pine: rnd() < 0.42, s: 0.7 + rnd() * 0.55 });
      _planted++;
    }
    cityTrees.forEach(function (t, i) {
      // Ranks run from 0.2 upward so the city keeps a green backbone at every health level.
      const rank = 0.20 + (i / Math.max(1, cityTrees.length - 1)) * 0.80;
      if (t.pine) addPine(t.x, t.z, t.s, root, rank);
      else        addDecid(t.x, t.z, t.s, root, rank);
    });

    // Street lamps down both sides of the main crossroads
    const lampMat = mat(0x1E293B, 0.6);
    const lampGlassMat = mat(0xFEF9C3, 0.3, 0, 0xFDE68A, 0.9);
    function addLamp(lx, lz) {
      const g = new THREE.Group(); g.position.set(lx, Y_WALK, lz);
      g.add(queueForMerge(mesh(new THREE.CylinderGeometry(0.045, 0.06, 1.5, 8), lampMat, 0, 0.75, 0, false, false)));
      g.add(queueForMerge(mesh(new THREE.SphereGeometry(0.11, 10, 10), lampGlassMat, 0, 1.56, 0, false, false)));
      root.add(g);
    }
    // Along the four block frontages that face the road ring
    [-3.6, -1.2, 1.2, 3.6].forEach(function (v) {
      addLamp(-4.0, v); addLamp(4.0, v);
      addLamp(v, -4.0); addLamp(v, 4.0);
    });
    [-3.2, 0, 3.2].forEach(function (v) {
      addLamp(v, -7.2); addLamp(v, 7.2);
      addLamp(7.2, v);
    });
    // Keep west-side poles between the local crowd routes, not in the walking lane.
    [-2.15, 2.15].forEach(function (v) { addLamp(-7.2, v); });

    // ────────────────────────────────────────────────────────────────
    // 🎪 10c. MICRO-DETAILS, STREET ACCESSORIES & VIBRANT WILDLIFE
    // The details that give the city life: bistro patio string lights,
    // fire hydrants, scooter dock, bike rack, mailbox, manhole covers,
    // traffic signals, litter bins, mushrooms, picnic spot, squirrel,
    // fluttering butterflies, and birds circling in the sky.
    // ────────────────────────────────────────────────────────────────

    // 1. Bistro Outdoor Patio Fairy String Lights
    function createStringLights(p1, p2, sag, bulbCount, parent) {
      const g = new THREE.Group();
      const points = [];
      const steps = 16;
      for (let i = 0; i <= steps; i++) {
        const f = i / steps;
        const x = p1[0] + (p2[0] - p1[0]) * f;
        const z = p1[2] + (p2[2] - p1[2]) * f;
        const y = p1[1] + (p2[1] - p1[1]) * f - Math.sin(f * Math.PI) * (sag || 0.25);
        points.push(new THREE.Vector3(x, y, z));
      }
      const curve = new THREE.CatmullRomCurve3(points);
      const wireGeo = new THREE.TubeGeometry(curve, 16, 0.008, 5, false);
      g.add(mesh(wireGeo, mat(0x1E293B, 0.8), 0, 0, 0, false, false));

      const bulbGeo = new THREE.SphereGeometry(0.038, 8, 8);
      const bulbMat = new THREE.MeshStandardMaterial({
        color: 0xFEF08A,
        emissive: 0xFEF08A,
        emissiveIntensity: 2.8,
        roughness: 0.2
      });
      for (let b = 1; b < bulbCount; b++) {
        const f = b / bulbCount;
        const pt = curve.getPoint(f);
        g.add(mesh(bulbGeo, bulbMat, pt.x, pt.y - 0.03, pt.z, false, false));
      }
      [p1, p2].forEach(function (pt) {
        g.add(mesh(new THREE.CylinderGeometry(0.03, 0.035, pt[1] - Y_WALK, 6), M_WOOD, pt[0], Y_WALK + (pt[1] - Y_WALK) / 2, pt[2], false, false));
      });
      (parent || root).add(g);
      return g;
    }
    createStringLights([-8.6, Y_WALK + 1.25, -6.8], [-6.4, Y_WALK + 1.25, -6.8], 0.22, 6);
    createStringLights([-6.4, Y_WALK + 1.25, -6.8], [-6.4, Y_WALK + 1.25, -8.6], 0.20, 5);

    // 2. Red Fire Hydrants at Sidewalk Corners
    function createFireHydrant(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, Y_WALK, z); g.rotation.y = ry || 0;
      const redM = mat(0xDC2626, 0.4, 0.6);
      const metalM = mat(0x94A3B8, 0.3, 0.8);
      g.add(mesh(new THREE.CylinderGeometry(0.07, 0.09, 0.30, 8), redM, 0, 0.15, 0));
      g.add(mesh(new THREE.SphereGeometry(0.07, 8, 6, 0, Math.PI * 2, 0, Math.PI * 0.5), redM, 0, 0.30, 0));
      g.add(mesh(new THREE.CylinderGeometry(0.025, 0.025, 0.04, 5), metalM, 0, 0.36, 0));
      [-0.07, 0.07].forEach(function (nx) {
        const noz = mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.05, 6), metalM, nx, 0.19, 0);
        noz.rotation.z = Math.PI / 2; g.add(noz);
      });
      root.add(g);
    }
    createFireHydrant(-4.7, -4.7, 0.8);
    createFireHydrant( 4.7, -4.7, -0.8);
    createFireHydrant(-4.7,  4.7, 2.3);

    // 3. Shared Electric Kick-Scooter Station (Lime Style)
    function createScooterStation(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, Y_WALK, z); g.rotation.y = ry || 0;
      const bay = mesh(new THREE.BoxGeometry(1.4, 0.015, 0.65), mat(0x10B981, 0.8), 0, 0.01, 0, false, false);
      g.add(bay);
      const greenM = mat(0x10B981, 0.6);
      const screenM = mat(0x38BDF8, 0.2, 0, 0x38BDF8, 2.2);
      [-0.38, 0, 0.38].forEach(function (sx, i) {
        const sc = new THREE.Group(); sc.position.set(sx, 0, (i % 2 === 0 ? 0.03 : -0.03));
        sc.rotation.y = (i * 0.10) - 0.05;
        sc.add(mesh(roundedBox(0.10, 0.035, 0.50, 0.02), greenM, 0, 0.09, 0));
        [-0.22, 0.22].forEach(function (wz) {
          const w = mesh(new THREE.CylinderGeometry(0.045, 0.045, 0.025, 8), mat(0x18181B, 0.9), 0, 0.045, wz);
          w.rotation.z = Math.PI / 2; sc.add(w);
        });
        const stand = mesh(new THREE.CylinderGeometry(0.007, 0.007, 0.11, 4), mat(0x64748B, 0.6), 0.04, 0.05, -0.12);
        stand.rotation.x = 0.2; stand.rotation.z = -0.4; sc.add(stand);
        sc.add(mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.58, 6), mat(0x18181B, 0.7), 0, 0.34, 0.19));
        sc.add(mesh(new THREE.BoxGeometry(0.28, 0.018, 0.018), greenM, 0, 0.63, 0.19));
        sc.add(mesh(new THREE.BoxGeometry(0.04, 0.03, 0.01), screenM, 0, 0.64, 0.18, false, false));
        g.add(sc);
      });
      root.add(g);
    }
    createScooterStation(-4.7, 6.8, Math.PI / 2);

    // 4. Stainless Steel Bike Rack with Commuter Bike
    function createBikeRack(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, Y_WALK, z); g.rotation.y = ry || 0;
      const chromeM = mat(0x94A3B8, 0.2, 0.85);
      [-0.22, 0.22].forEach(function (rx) {
        g.add(mesh(new THREE.TorusGeometry(0.15, 0.018, 6, 12, Math.PI), chromeM, rx, 0.30, 0));
        g.add(mesh(new THREE.CylinderGeometry(0.018, 0.018, 0.30, 6), chromeM, rx - 0.15, 0.15, 0));
        g.add(mesh(new THREE.CylinderGeometry(0.018, 0.018, 0.30, 6), chromeM, rx + 0.15, 0.15, 0));
      });
      const bike = new THREE.Group(); bike.position.set(-0.22, 0.18, 0.02); g.add(bike);
      const wheelM = mat(0x18181B, 0.85);
      [-0.26, 0.26].forEach(function (wx) {
        bike.add(mesh(new THREE.TorusGeometry(0.12, 0.015, 6, 12), wheelM, wx, 0, 0));
      });
      const frameM = mat(0x0284C7, 0.4, 0.6);
      bike.add(mesh(new THREE.CylinderGeometry(0.01, 0.01, 0.30, 6), frameM, 0, 0.07, 0));
      bike.add(mesh(new THREE.BoxGeometry(0.06, 0.02, 0.04), mat(0x18181B, 0.8), 0, 0.22, 0));
      bike.add(mesh(new THREE.BoxGeometry(0.02, 0.02, 0.20), chromeM, 0.22, 0.23, 0));
      root.add(g);
    }
    createBikeRack(4.7, -6.6, 0);

    // 5. Postal Mailbox
    function createMailbox(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, Y_WALK, z); g.rotation.y = ry || 0;
      g.add(mesh(new THREE.CylinderGeometry(0.025, 0.025, 0.36, 6), mat(0x18181B, 0.8), 0, 0.18, 0));
      g.add(mesh(roundedBox(0.22, 0.28, 0.18, 0.04), mat(0xEF4444, 0.4, 0.6), 0, 0.45, 0));
      g.add(mesh(new THREE.BoxGeometry(0.14, 0.02, 0.02), mat(0x18181B, 0.9), 0, 0.50, 0.10));
      root.add(g);
    }
    createMailbox(4.7, -2.4, -Math.PI / 2);

    // 6. Cast Iron Manhole Covers Flush in Asphalt
    function createManhole(x, z) {
      const mh = mesh(new THREE.CylinderGeometry(0.20, 0.20, 0.015, 14), mat(0x334155, 0.5, 0.7), x, 0.091, z, false, false);
      root.add(mh);
    }
    createManhole(-ROAD_AT, 0);
    createManhole( ROAD_AT, 0);
    createManhole(0, -ROAD_AT);
    createManhole(0,  ROAD_AT);

    // 7. Traffic Signals at Intersections
    function createTrafficSignal(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, Y_WALK, z); g.rotation.y = ry || 0;
      const blackM = mat(0x18181B, 0.5, 0.8);
      g.add(mesh(new THREE.CylinderGeometry(0.03, 0.045, 1.6, 8), blackM, 0, 0.80, 0));
      g.add(mesh(roundedBox(0.18, 0.54, 0.14, 0.03), blackM, 0, 1.30, 0.06));
      const redLens = mesh(new THREE.SphereGeometry(0.04, 8, 8), new THREE.MeshStandardMaterial({ color: 0xEF4444, emissive: 0xEF4444, emissiveIntensity: 2.2 }), 0, 1.45, 0.13, false, false);
      const ambLens = mesh(new THREE.SphereGeometry(0.04, 8, 8), new THREE.MeshStandardMaterial({ color: 0xF59E0B, emissive: 0xF59E0B, emissiveIntensity: 0.6 }), 0, 1.30, 0.13, false, false);
      const grnLens = mesh(new THREE.SphereGeometry(0.04, 8, 8), new THREE.MeshStandardMaterial({ color: 0x10B981, emissive: 0x10B981, emissiveIntensity: 0.6 }), 0, 1.15, 0.13, false, false);
      g.add(redLens, ambLens, grnLens);
      root.add(g);
    }
    createTrafficSignal(-4.7, -3.2, Math.PI / 2);
    createTrafficSignal( 4.7,  3.2, -Math.PI / 2);

    // 8. Public Litter Bins
    function createTrashCan(x, z) {
      const g = new THREE.Group(); g.position.set(x, Y_WALK, z);
      g.add(mesh(new THREE.CylinderGeometry(0.10, 0.08, 0.28, 8), mat(0x166534, 0.7), 0, 0.14, 0));
      g.add(mesh(new THREE.CylinderGeometry(0.11, 0.11, 0.03, 8), mat(0x0F172A, 0.5), 0, 0.28, 0));
      root.add(g);
    }
    createTrashCan(-4.7, -1.8);
    createTrashCan( 4.7,  1.8);
    createTrashCan(-1.8,  4.7);

    // 9. Polka-Dot Amanita Mushrooms in Nature Reserve Woods
    function createMushroomCluster(x, z) {
      const g = new THREE.Group(); g.position.set(x, Y_GRASS, z);
      const capM = mat(0xEF4444, 0.7);
      const stemM = mat(0xFFEDD5, 0.9);
      [[0, 0, 1.0], [0.10, 0.07, 0.75], [-0.08, 0.05, 0.6]].forEach(function (m) {
        const mx = m[0], mz = m[1], s = m[2];
        g.add(mesh(new THREE.CylinderGeometry(0.02 * s, 0.025 * s, 0.10 * s, 6), stemM, mx, 0.05 * s, mz));
        const cap = mesh(new THREE.SphereGeometry(0.06 * s, 8, 6, 0, Math.PI * 2, 0, Math.PI * 0.6), capM, mx, 0.09 * s, mz);
        g.add(cap);
        [[-0.025 * s, 0.025 * s], [0.025 * s, 0.02 * s], [0, -0.025 * s]].forEach(function (d) {
          g.add(mesh(new THREE.SphereGeometry(0.012 * s, 4, 4), stemM, mx + d[0], 0.12 * s, mz + d[1], false, false));
        });
      });
      root.add(g);
    }
    createMushroomCluster(10.2, -10.8);
    createMushroomCluster( 8.4, -11.6);

    // 10. Picnic Spot in Nature Reserve
    function createPicnicSpot(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, Y_GRASS, z); g.rotation.y = ry || 0;
      const woodM = mat(0xA16207, 0.8);
      g.add(mesh(new THREE.BoxGeometry(0.85, 0.035, 0.55), woodM, 0, 0.38, 0));
      g.add(mesh(new THREE.BoxGeometry(0.60, 0.04, 0.42), new THREE.MeshStandardMaterial({ map: stripedAwningTex("#EF4444", "#FFFFFF") }), 0, 0.39, 0));
      [-0.36, 0.36].forEach(function (bz) {
        g.add(mesh(new THREE.BoxGeometry(0.85, 0.03, 0.18), woodM, 0, 0.22, bz));
        [-0.32, 0.32].forEach(function (lx) {
          g.add(mesh(new THREE.CylinderGeometry(0.018, 0.018, 0.22, 6), woodM, lx, 0.11, bz));
        });
      });
      const basket = mesh(roundedBox(0.20, 0.15, 0.15, 0.02), mat(0xD97706, 0.9), -0.14, 0.46, 0.04);
      g.add(basket);
      const melon = mesh(new THREE.CylinderGeometry(0.08, 0.08, 0.025, 10, 1, false, 0, Math.PI), mat(0xEF4444, 0.6), 0.14, 0.42, -0.04);
      melon.rotation.x = Math.PI / 2; g.add(melon);
      root.add(g);
    }
    createPicnicSpot(11.2, -7.6, 0.35);

    // 11. High-Detail Park Squirrel Sitting on the Bench
    function createParkSquirrel(x, y, z, ry) {
      const sq = new THREE.Group(); sq.position.set(x, y, z); sq.rotation.y = ry || 0;
      sq.add(mesh(new THREE.BoxGeometry(0.12, 0.16, 0.12), mat(0x78350F, 0.85), 0, 0.08, 0));
      sq.add(mesh(new THREE.BoxGeometry(0.09, 0.12, 0.025), mat(0xFEF3C7, 0.9), 0, 0.08, 0.065));
      const sqHead = new THREE.Group(); sqHead.position.set(0, 0.19, 0.03); sq.add(sqHead);
      sqHead.add(mesh(new THREE.SphereGeometry(0.07, 8, 6), mat(0x9A3412, 0.85), 0, 0, 0));
      sqHead.add(mesh(new THREE.ConeGeometry(0.03, 0.05, 5), mat(0x78350F, 0.9), 0, 0, 0.07));
      [-0.04, 0.04].forEach(function (ex) {
        sqHead.add(mesh(new THREE.ConeGeometry(0.02, 0.04, 5), mat(0x78350F, 0.9), ex, 0.08, 0));
        sqHead.add(mesh(new THREE.SphereGeometry(0.014, 4, 4), mat(0x18181B, 0.2), ex, 0.02, 0.06));
      });
      const sqTail = new THREE.Group(); sqTail.position.set(0, 0.06, -0.08); sq.add(sqTail);
      sqTail.add(mesh(new THREE.SphereGeometry(0.09, 8, 6), mat(0x78350F, 0.9), 0, 0.09, -0.04));
      sqTail.add(mesh(new THREE.SphereGeometry(0.10, 8, 6), mat(0x9A3412, 0.85), 0, 0.20, -0.02));
      sqTail.add(mesh(new THREE.ConeGeometry(0.09, 0.16, 6), mat(0x78350F, 0.9), 0, 0.30, 0.03));
      sqTail.rotation.x = -0.32;
      animObjects.push({ type: "bob", ref: sq, base: y, phase: 0.5, baseRotY: ry || 0 });
      root.add(sq);
    }
    createParkSquirrel(-6.4, Y_GRASS + 0.26, 10.9, 0.2);

    // 12. Animated Fluttering Butterflies
    function createButterfly(colorHex, orbitRadius, cx, cz, cy) {
      const g = new THREE.Group(); g.position.set(cx, cy, cz);
      const wingMat = new THREE.MeshStandardMaterial({
        color: colorHex,
        side: THREE.DoubleSide,
        emissive: colorHex,
        emissiveIntensity: 0.65,
        roughness: 0.4
      });
      const wingL = mesh(new THREE.CircleGeometry(0.045, 6), wingMat, -0.04, 0, 0);
      wingL.rotation.y = 0.3; g.add(wingL);
      const wingR = mesh(new THREE.CircleGeometry(0.045, 6), wingMat, 0.04, 0, 0);
      wingR.rotation.y = -0.3; g.add(wingR);
      root.add(g);
      animObjects.push({
        type: "butterfly_orbit",
        ref: g,
        wingL: wingL,
        wingR: wingR,
        radius: orbitRadius,
        speed: 1.2,
        phase: Math.random() * Math.PI * 2,
        cx: cx,
        cz: cz,
        baseY: cy
      });
    }
    createButterfly(0x38BDF8, 1.3,  1.8,   0.8, Y_WALK + 0.8);
    createButterfly(0xF472B6, 1.5,  8.2,  -8.0, Y_GRASS + 0.9);
    createButterfly(0xFACC15, 1.2, 10.5,  -6.5, Y_GRASS + 1.0);
    createButterfly(0x4ADE80, 1.3, -3.2,   1.8, Y_WALK + 0.8);

    // 13. Graceful Birds Circling in the Sky
    for (let bi = 0; bi < 3; bi++) {
      const bird = new THREE.Group(); bird.position.set(0, 5.8, 0); root.add(bird);
      bird.add(mesh(new THREE.SphereGeometry(0.045, 6, 6), mat(0xE2E8F0, 0.7), 0, 0, 0, false, false));
      const bWingL = mesh(new THREE.BoxGeometry(0.13, 0.012, 0.04), mat(0xCBD5E1, 0.7), -0.07, 0, 0, false, false);
      const bWingR = mesh(new THREE.BoxGeometry(0.13, 0.012, 0.04), mat(0xCBD5E1, 0.7),  0.07, 0, 0, false, false);
      bird.add(bWingL, bWingR);
      animObjects.push({
        type: "bird",
        ref: bird,
        wingL: bWingL,
        wingR: bWingR,
        radius: 4.2 + bi * 1.2,
        speed: 0.20 + bi * 0.07,
        phase: bi * 2.1,
        cx: 0.5,
        cz: 0.5,
        baseY: 5.6 + bi * 0.35
      });
    }

    // ────────────────────────────────────────────────────────────────
    // 🌱 10d. RESERVE HEALTH
    // The reserve is part of the city's permanent visual identity. It stays fully planted;
    // positive behaviour enriches its colour and water instead of removing greenery.
    // ────────────────────────────────────────────────────────────────
    const HEALTHY_PARK = 0.78;
    let parkHealthValue = HEALTHY_PARK;

    function parkPlantedFraction(h) {
      return 1;
    }

    function applyParkHealth(h) {
      if (typeof h !== "number" || !isFinite(h)) return;
      parkHealthValue = Math.max(0, Math.min(1, h));
      const frac = parkPlantedFraction(parkHealthValue);
      for (let i = 0; i < parkPlantings.length; i++) {
        const p = parkPlantings[i];
        p.wanted = p.rank <= frac;
        if (p.wanted && !p.obj.visible) { p.obj.visible = true; p.obj.scale.setScalar(0.01); }
      }
      // The baseline is already green; improvement adds a fresher, brighter finish.
      const t = Math.max(0, (parkHealthValue - HEALTHY_PARK) / (1 - HEALTHY_PARK));
      M_PINE.color.copy(PINE_BASE).lerp(PINE_LUSH, t);
      M_LEAF.color.copy(LEAF_BASE).lerp(LEAF_LUSH, t);
      M_LEAF_LIGHT.color.copy(LEAF_LIGHT_BASE).lerp(LEAF_LIGHT_LUSH, t);
      M_GRASS_LIME.color.copy(C(0x7DBB45)).lerp(C(0x86C74A), t);
      if (lakeMesh && lakeMesh.material) {
        // Water starts clear and becomes a little brighter with positive progress.
        lakeMesh.material.color.copy(C(0x2EA8DE)).lerp(C(0x27B8E6), t);
      }
    }

    // Grow and shrink plantings smoothly rather than popping them in and out.
    function stepPlantings(dt) {
      for (let i = 0; i < parkPlantings.length; i++) {
        const p = parkPlantings[i];
        if (!p.obj.visible) continue;
        const target = p.wanted ? 1 : 0;
        const cur = p.obj.scale.y;
        if (p.wanted && Math.abs(cur - target) < 0.001) {
          if (cur !== target) p.obj.scale.setScalar(target);
          continue;
        }
        const next = cur + (target - cur) * Math.min(1, dt * 4.5);
        if (!p.wanted && next < 0.02) { p.obj.visible = false; p.obj.scale.setScalar(0.01); continue; }
        p.obj.scale.setScalar(Math.max(0.01, next));
      }
    }

    // Re-space the ranks evenly once every planting exists, keeping the intended order.
    // Without this the authored ranks bunch up and "30% planted" only shows 20% of the trees.
    parkPlantings.sort(function (a, b) { return a.rank - b.rank; });
    parkPlantings.forEach(function (p, i) { p.rank = i / Math.max(1, parkPlantings.length - 1); });

    applyParkHealth(HEALTHY_PARK);
    parkPlantings.forEach(function (p) { p.obj.scale.setScalar(p.wanted ? 1 : 0.01); p.obj.visible = p.wanted; });

    // ────────────────────────────────────────────────────────────────
    // 🚗 11. ROAD VEHICLES (Two-Way Traffic with Rounded Corners)
    // ────────────────────────────────────────────────────────────────
    // Smooth rounded-corner waypoints for continuous two-way traffic
    // Loop 1 (Clockwise - Inner/Right Lane, offset -0.40 from ROAD_AT = 5.6):
    const R_IN = 5.20, CR_IN = 0.85;
    const roadClockwise = [
      { x: -(R_IN - CR_IN), z: -R_IN },
      { x:  (R_IN - CR_IN), z: -R_IN },
      { x:  R_IN - 0.25,    z: -R_IN + 0.25 },
      { x:  R_IN,           z: -(R_IN - CR_IN) },
      { x:  R_IN,           z:  (R_IN - CR_IN) },
      { x:  R_IN - 0.25,    z:  R_IN - 0.25 },
      { x:  (R_IN - CR_IN), z:  R_IN },
      { x: -(R_IN - CR_IN), z:  R_IN },
      { x: -R_IN + 0.25,    z:  R_IN - 0.25 },
      { x: -R_IN,           z:  (R_IN - CR_IN) },
      { x: -R_IN,           z: -(R_IN - CR_IN) },
      { x: -R_IN + 0.25,    z: -R_IN + 0.25 }
    ];

    // Loop 2 (Counter-Clockwise - Outer Lane, offset +0.40 from ROAD_AT = 5.6):
    const R_OUT = 6.00, CR_OUT = 1.05;
    const roadCounterClockwise = [
      { x:  (R_OUT - CR_OUT), z: -R_OUT },
      { x: -(R_OUT - CR_OUT), z: -R_OUT },
      { x: -R_OUT + 0.30,     z: -R_OUT + 0.30 },
      { x: -R_OUT,            z: -(R_OUT - CR_OUT) },
      { x: -R_OUT,            z:  (R_OUT - CR_OUT) },
      { x: -R_OUT + 0.30,     z:  R_OUT - 0.30 },
      { x: -(R_OUT - CR_OUT), z:  R_OUT },
      { x:  (R_OUT - CR_OUT), z:  R_OUT },
      { x:  R_OUT - 0.30,     z:  R_OUT - 0.30 },
      { x:  R_OUT,            z:  (R_OUT - CR_OUT) },
      { x:  R_OUT,            z: -(R_OUT - CR_OUT) },
      { x:  R_OUT - 0.30,     z: -R_OUT + 0.30 }
    ];

    function addVehicleToPath(color, isBus, isTaxi, path, initP, spd) {
      const v = createCar(color, isBus, isTaxi);
      v.position.y = Y_WALK;
      root.add(v);
      vehicleState.push({ obj: v, path: path, progress: initP, speed: spd, baseY: Y_WALK });
    }

    // Active Two-Way Traffic (Calm, graceful cruising pace ~45-60s per lap):
    // Clockwise vehicles:
    addVehicleToPath(0xFACC15, false, true,  roadClockwise, 0.05, 0.022); // Yellow Taxi (~45s per lap)
    addVehicleToPath(0xEF4444, false, false, roadClockwise, 0.50, 0.019); // Red Compact Sedan (~52s per lap)
    (function () {
      const rider = makeCourier(0x00C2E8);
      rider.position.y = Y_WALK;
      root.add(rider);
      vehicleState.push({ obj: rider, path: roadClockwise, progress: 0.80, speed: 0.024, baseY: Y_WALK }); // Cyan Scooter (~41s per lap)
    })();

    // Counter-Clockwise vehicles (Opposite Lane!):
    addVehicleToPath(0x2563EB, true, false,  roadCounterClockwise, 0.20, 0.016); // Blue City Bus (~62s per lap)
    addVehicleToPath(0xF97316, false, false, roadCounterClockwise, 0.70, 0.018); // Orange Delivery Van (~55s per lap)

    // ────────────────────────────────────────────────────────────────
    // 🚶 12. CITIZENS & SPEECH BUBBLE INTERACTION
    // ────────────────────────────────────────────────────────────────
    function popSpeechBubble(targetObj, text) {
      if (!targetObj || !text) return;
      while (activeBubbles.length > 0) {
        const b = activeBubbles.pop();
        if (b.el && b.el.parentNode) b.el.parentNode.removeChild(b.el);
      }
      const el = document.createElement("div");
      el.className = "diorama-speech-bubble active";
      el.textContent = text;
      (overlaysContainer || stage || document.body).appendChild(el);

      const v = new THREE.Vector3(); targetObj.getWorldPosition(v); v.y += 1.4; v.project(camera);
      el.style.left = (((v.x + 1) * 0.5) * stage.clientWidth) + "px";
      el.style.top  = (((-v.y + 1) * 0.5) * stage.clientHeight) + "px";
      activeBubbles.push({ el: el, life: 0, maxLife: 2.6 });
    }

    function addCitizen(color, pants, hatColor, walkPath, phrases, englishPhrases, withDog, customSpeed) {
      const g = makeFigure({ shirt: color, pants: pants, cap: hatColor,
        dark: walkingCitizens.length % 3 === 1, bag: withDog ? null : (walkingCitizens.length % 2 ? 0xA67F52 : null) });
      const joints = g.userData, torso = joints.body;
      root.add(g);
      const he = phrases || ["איזה יום מקסים! ✨", "שומר על תקציב מעולה 📈"];
      torso.userData = {
        phrases: he,
        phrasesByLang: { he: he, en: englishPhrases || ["What a lovely day ✨", "Budget looking good 📈"] }
      };
      interactiveCitizens.push(torso);

      let dog = null;
      if (withDog) { dog = makeDog(0xD9A441); root.add(dog); }
      if (walkPath && walkPath.length > 1) {
        g.position.set(walkPath[0].x, Y_WALK, walkPath[0].z);
        walkingCitizens.push({
          obj: g,
          legL: joints.legL,
          legR: joints.legR,
          kneeL: joints.kneeL,
          kneeR: joints.kneeR,
          armL: joints.armL,
          armR: joints.armR,
          dog: dog,
          path: walkPath,
          pIdx: 0,
          t: 0,
          speed: customSpeed || 1.15,
          baseY: Y_WALK
        });
      }
      return g;
    }

    // Citizens walking lively around plazas, crosswalks, nature reserve and shops:
    // 1. Central Plaza & Fountain stroller
    addCitizen(0x3B82F6, 0x1E293B, 0xEF4444, [
      {x: -1.8, z: 0.5}, {x: -1.8, z: 2.2}, {x: 1.8, z: 2.2}, {x: 1.8, z: 0.5}
    ], ["איזה כיף לשבת ליד המזרקה ⛲", "העיר הזו נראית מעולה! 🏙️"], ["Lovely by the fountain ⛲", "This city looks amazing! 🏙️"], false, 0.35);

    // 2. Crosswalk Pedestrian crossing the street
    addCitizen(0x10B981, 0x334155, null, [
      {x: -ROAD_AT, z: -3.2}, {x: -ROAD_AT, z: -1.0}, {x: -ROAD_AT, z: 1.0}, {x: -ROAD_AT, z: -3.2}
    ], ["חוצה בזהירות במעבר חצייה 🚶", "העיר תוססת היום! ✨"], ["Crossing at the zebra walk 🚶", "Lively city today! ✨"], false, 0.38);

    // 3. Nature Reserve Bridge & Trail Walker
    addCitizen(0x059669, 0x1E293B, 0x10B981, [
      {x: 8.6, z: -9.8}, {x: 9.3, z: -9.4}, {x: 10.0, z: -9.0}, {x: 9.3, z: -9.4}
    ], ["האוויר כאן בשמורה פשוט נקי 🌲", "שומר על החסכונות שלי 💚"], ["The air is so clean here 🌲", "Growing my savings 💚"], false, 0.30);

    // 4. Active Jogger doing laps with athletic stride
    addCitizen(0xF97316, 0x1E293B, 0xEF4444, [
      {x: -3.6, z: -3.6}, {x: 3.6, z: -3.6}, {x: 3.6, z: 3.6}, {x: -3.6, z: 3.6}
    ], ["ריצת בוקר מסביב למרכז 🏃‍♂️", "כושר גופני וכושר פיננסי 💪"], ["Morning 5k jog 🏃‍♂️", "Fit body, fit finances 💪"], false, 0.65);

    // 5. Dog Walker near park
    addCitizen(0x7C3AED, 0x334155, 0x22C55E, [
      {x: -3.2, z: -7.4}, {x: 3.2, z: -7.4}, {x: 3.2, z: -11.0}, {x: -3.2, z: -11.0}
    ], ["טיול עם הכלב בפארק 🐕", "השכונה שקטה ונעימה 🌳"], ["Walking the dog in the park 🐕", "Peaceful neighbourhood 🌳"], true, 0.34);

    // ────────────────────────────────────────────────────────────────
    // Derived frontages are not rewards or a second financial ledger.
    ${cityLifeJs}
    ${cityCrowdsJs}

    // 🎁 12b. ENRICHMENT SLOTS
    // Six curated spots the user can decorate. Tapping one is the only route into the
    // slot customiser in the app, so without them every unlocked reward is unreachable.
    // ────────────────────────────────────────────────────────────────
    // 🧱 12. ENRICHMENT SLOTS: 13 dedicated positions for accumulated city additions.
    // Empty slots are completely invisible (no empty rings or grey pedestals).
    // ────────────────────────────────────────────────────────────────
    // SLOT_DEFS and legacy aliases are inlined before planting from city_v2_slots.js.

    const interactiveSlots = [];
    const slotGroups = {};
    const slotItems = {};
    const M_PEDESTAL = mat(0xE7E1D6, 0.88);
    const M_PINK  = mat(0xF9A8D4, 0.75);
    const M_ROSE  = mat(0xFB7185, 0.72);
    const M_TEAL  = mat(0x0EA5E9, 0.55);
    const M_CAT   = mat(0x9CA3AF, 0.80);
    const M_DOG   = mat(0xD9A441, 0.80);
    const M_MARBLE = mat(0xF8FAFC, 0.35, 0.05);

    function addSlot(def) {
      const g = new THREE.Group();
      g.position.set(def.x, def.y, def.z);
      g.rotation.y = def.rot || 0;
      root.add(g);
      slotGroups[def.id] = g;

      // The pedestal stays invisible unless an item is standing on it.
      const pad = mesh(new THREE.CylinderGeometry(0.62, 0.68, 0.09, 20), M_PEDESTAL, 0, 0.045, 0, false, true);
      pad.userData = { slotId: def.id, district: def.district, currentItem: null };
      pad.visible = false;
      g.add(pad);
      // Pick the whole prop, not a tiny ground disc. Invisible empty lots cannot intercept.
      const hit = hitProxy((def.radius || 0.65) * 2, 1.65, (def.radius || 0.65) * 2);
      hit.userData = pad.userData; hit.visible = false; g.add(hit);
      // Rewards and historical decorations never register map click targets.

      // Empty-state marker ring is hidden — empty slots do not clutter the world.
      const marker = new THREE.Mesh(
        new THREE.RingGeometry(0.24, 0.32, 20),
        new THREE.MeshBasicMaterial({ color: C(0x94A3B8), transparent: true, opacity: 0, depthWrite: false })
      );
      marker.rotation.x = -Math.PI / 2;
      marker.position.y = 0.10;
      marker.visible = false;
      g.add(marker);

      const holder = new THREE.Group();
      holder.position.y = 0.09;
      g.add(holder);

      slotItems[def.id] = { pad: pad, hit: hit, marker: marker, holder: holder, itemId: null, scale: def.scale || 1 };
      return g;
    }
    SLOT_DEFS.forEach(addSlot);

    // ---- Enrichment prop library (ids match CityProgressEngine) ----
    ${cityRewardModelsJs}
    ${cityCompanionsJs}

    const ENRICHMENT_PROPS = {
      tree_sakura: propTreeSakura,
      flower_bed_plaza: propFlowerBed,
      repair_bench: propBench,
      repair_lamp: propLamp,
      resident_artist: propArtist,
      pet_cat_rooftop: propCat,
      pet_golden_dog: propDog,
      bike_station: propBikeStation,
      cafe_stand: propCafeStand,
      repair_sidewalk: propSidewalk,
      fountain_marble: propFountain,
      park_bridge: propBridge,
      public_art_sculpture: propSculpture
    };

    function disposeChildren(group) {
      const removed = new Set(), ownedMaterials = new Set();
      for (let i = group.children.length - 1; i >= 0; i--) {
        const c = group.children[i];
        group.remove(c);
        c.traverse(function (o) {
          removed.add(o);
          if (o.isMesh && o.geometry) o.geometry.dispose();
          if (o.material && o.material.userData.rewardOwned) ownedMaterials.add(o.material);
        });
      }
      ownedMaterials.forEach(function (m) { if (m.map) m.map.dispose(); m.dispose(); });
      // A marble fountain registers an animated spout. Swapping the slot's item has to drop
      // that registration too, or every swap leaves the loop animating a detached mesh.
      for (let i = animObjects.length - 1; i >= 0; i--) {
        const a = animObjects[i];
        if (removed.has(a.spout) || removed.has(a.ref)) animObjects.splice(i, 1);
      }
    }

    function setSlotItem(slotId, itemId) {
      const slot = slotItems[slotId];
      if (!slot) return;
      if (slot.itemId === itemId) return;
      slot.itemId = itemId || null;
      slot.pad.userData.currentItem = slot.itemId;
      disposeChildren(slot.holder);
      const growthIndex = slotGrowth.indexOf(slot.holder);
      if (growthIndex !== -1) slotGrowth.splice(growthIndex, 1);
      const build = slot.itemId && ENRICHMENT_PROPS[slot.itemId];
      slot.pad.visible = !!build && !["park_bridge", "fountain_marble", "repair_sidewalk"].includes(slot.itemId);
      slot.hit.visible = false;
      slot.marker.visible = false;
      if (build) {
        build(slot.holder);
        // The holder animates; the model keeps its own authored scale throughout growth.
        const model = new THREE.Group();
        while (slot.holder.children.length) model.add(slot.holder.children[0]);
        model.scale.setScalar(slot.scale); slot.holder.add(model);
        slot.holder.scale.setScalar(0.01);
        slotGrowth.push(slot.holder);
      }
    }
    const slotGrowth = [];

    function applySlotPlacements(placements) {
      const map = normalizedSlotPlacements(placements);
      for (let i = 0; i < SLOT_DEFS.length; i++) {
        const id = SLOT_DEFS[i].id;
        setSlotItem(id, map[id] || null);
      }
      // Earned landmarks upgrade the existing structures; removing one restores the base.
      fountainGroup.visible = map.slot_fountain_marble !== "fountain_marble";
      bridge.visible = map.slot_park_bridge !== "park_bridge";
    }

    // ────────────────────────────────────────────────────────────────
    // 👆 13. INTERACTION: one-finger orbit, two-finger pan and pinch zoom.
    // ────────────────────────────────────────────────────────────────
    const pointers = new Map();
    let isDragging = false, downX = 0, downY = 0, downTime = 0;
    let spinVel = 0, tiltVel = 0;
    let gesture = null; // two-finger state: { dist, angle, cx, cy, zoom, az }
    let cameraIsOffset = false;
    let savedCameraBeforeBuilding = null;

    const ZOOM_MIN = 0.65, ZOOM_MAX = 3.20, PAN_LIMIT = 11.5;

    function clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v); }

    function checkCameraOffset() {
      if (currentMode !== "city" || selectedBuilding) {
        if (cameraIsOffset) {
          cameraIsOffset = false;
          post("cameraOffsetChanged", false);
        }
        return;
      }
      const base = CAM_MODES.city;
      const isOff = Math.abs(targetCam.az - base.az) > 0.15 ||
                    Math.hypot(targetCam.lookX - base.lookX, targetCam.lookZ - base.lookZ) > 1.0 ||
                    Math.abs((targetCam.zoom || 1.0) - base.zoom) > 0.18;
      if (isOff !== cameraIsOffset) {
        cameraIsOffset = isOff;
        post("cameraOffsetChanged", isOff);
      }
    }

    // Move the look-at point across the ground plane by a screen-pixel delta.
    function panByPixels(dxPx, dyPx) {
      const w = stage.clientWidth || 1, h = stage.clientHeight || 1;
      const unitsX = (camera.right - camera.left) / w;
      const unitsY = (camera.top - camera.bottom) / h;
      const az = currentCam.az;
      // Camera right vector on the ground, and the ground direction that runs "up" the screen.
      const rx = Math.sin(az), rz = -Math.cos(az);
      const fx = Math.cos(az), fz = Math.sin(az);
      const moveR = -dxPx * unitsX;
      // The ground is foreshortened by sin(elevation), so vertical drags need dividing by it.
      const moveF = -dyPx * unitsY / Math.max(0.30, Math.sin(currentCam.el));
      targetCam.lookX = clamp(targetCam.lookX + rx * moveR + fx * moveF, -PAN_LIMIT, PAN_LIMIT);
      targetCam.lookZ = clamp(targetCam.lookZ + rz * moveR + fz * moveF, -PAN_LIMIT, PAN_LIMIT);
      checkCameraOffset();
    }

    function twoFingerState() {
      const pts = Array.from(pointers.values());
      const a = pts[0], b = pts[1];
      return {
        dist: Math.max(1, Math.hypot(a.x - b.x, a.y - b.y)),
        angle: Math.atan2(b.y - a.y, b.x - a.x),
        cx: (a.x + b.x) / 2,
        cy: (a.y + b.y) / 2
      };
    }

    function onDown(id, x, y) {
      noteEnergyInteraction();
      pointers.set(id, { x: x, y: y, startX: x, startY: y, lastX: x, lastY: y, time: performance.now() });
      if (pointers.size === 1) {
        isDragging = false;
        downX = x; downY = y; downTime = performance.now();
        spinVel = 0; tiltVel = 0; gesture = null;
      } else if (pointers.size === 2) {
        const g = twoFingerState();
        gesture = { dist: g.dist, angle: g.angle, cx: g.cx, cy: g.cy, zoom: targetCam.zoom || 1.0, az: targetCam.az };
        isDragging = true; spinVel = 0; tiltVel = 0;
      }
    }

    function onMove(id, x, y) {
      noteEnergyInteraction();
      const p = pointers.get(id);
      if (!p) return;
      const prevX = p.x, prevY = p.y;
      p.x = x; p.y = y;

      // ── Two Finger: Pinch Zoom + Two-Finger Twist Rotation + Two-Finger Pan ──
      if (pointers.size >= 2) {
        if (!gesture) {
          const g0 = twoFingerState();
          gesture = { dist: g0.dist, angle: g0.angle, cx: g0.cx, cy: g0.cy, zoom: targetCam.zoom || 1.0, az: targetCam.az };
          return;
        }
        const g = twoFingerState();

        // 1. Pinch Zoom
        const zoomRatio = g.dist / gesture.dist;
        targetCam.zoom = clamp(gesture.zoom * zoomRatio, ZOOM_MIN, ZOOM_MAX);

        // 2. Two-Finger Twist / Rotation (natural diorama spin)
        let dAngle = g.angle - gesture.angle;
        while (dAngle > Math.PI) dAngle -= 2 * Math.PI;
        while (dAngle < -Math.PI) dAngle += 2 * Math.PI;
        targetCam.az = gesture.az - dAngle * 1.05;

        // 3. Two-Finger Pan
        panByPixels(g.cx - gesture.cx, g.cy - gesture.cy);
        gesture.cx = g.cx; gesture.cy = g.cy;

        isDragging = true;
        checkCameraOffset();
        return;
      }

      // ── One Finger: Pan ──
      const totalDx = x - p.startX, totalDy = y - p.startY;
      if (!isDragging) {
        // Generous 10px threshold absorbs microscopic finger rolling/tremor on iPhone retina screens
        if (Math.hypot(totalDx, totalDy) <= 10) return;
        isDragging = true;
      }

      const deltaX = x - prevX;
      const deltaY = y - prevY;
      panByPixels(deltaX, deltaY);
      checkCameraOffset();
    }

    function onUp(id, cx, cy) {
      const wasSingle = pointers.size === 1;
      const p = pointers.get(id);
      const tapOriginX = p ? p.startX : cx;
      const tapOriginY = p ? p.startY : cy;
      pointers.delete(id);

      if (pointers.size < 2) gesture = null;
      if (pointers.size === 1) {
        // Second finger lifted: re-seat anchor so view does not jump
        const rest = Array.from(pointers.values())[0];
        rest.startX = rest.x; rest.startY = rest.y;
        downX = rest.x; downY = rest.y; downTime = performance.now();
        isDragging = true;
        return;
      }
      if (!wasSingle) { isDragging = false; return; }

      // A tap must not have crossed the 10px drag threshold and must release within 450ms
      if (!isDragging && performance.now() - downTime < 450) {
        handleTap(tapOriginX, tapOriginY);
      }
      isDragging = false;
    }

    function handleTap(cx, cy) {
      const rect = stage.getBoundingClientRect();
      mouse.x = ((cx - rect.left) / rect.width) * 2 - 1;
      mouse.y = -((cy - rect.top) / rect.height) * 2 + 1;
      raycaster.setFromCamera(mouse, camera);

      // 1. Citizen tapped (direct hit only)
      const cHits = raycaster.intersectObjects(interactiveCitizens.filter(visibleInScene), true);
      if (cHits.length > 0) {
        const u = cHits[0].object.userData;
        if (u && u.phrases) {
          popSpeechBubble(cHits[0].object, u.phrases[Math.floor(Math.random() * u.phrases.length)]);
          post("citizenTapped", {});
          return;
        }
      }

      // 2. Building tapped: Exact Raycast + Screen-Space Nearest-Target Fallback
      const candidates = interactiveBuildings.concat(interactiveVenueInstances).filter(visibleInScene);
      let bestObj = null;

      // Step A: Exact raycast hit on building proxy
      const bHits = raycaster.intersectObjects(candidates, false);
      if (bHits.length > 0) {
        bestObj = bHits[0].object;
      } else {
        // Step B: Screen-space nearest-target resolution within ~34 CSS pixels
        const MAX_SCREEN_FALLBACK_PX = 34;
        let bestDist = MAX_SCREEN_FALLBACK_PX;
        let bestDepth = Infinity;
        const vProj = new THREE.Vector3();

        for (let i = 0; i < candidates.length; i++) {
          const cand = candidates[i];
          cand.getWorldPosition(vProj);
          vProj.y += 0.8; // Representative interaction anchor near mid-height
          vProj.project(camera);

          // Must be in front of near plane and within frustum
          if (vProj.z < -1 || vProj.z > 1) continue;

          const sx = ((vProj.x + 1) / 2) * rect.width + rect.left;
          const sy = ((-vProj.y + 1) / 2) * rect.height + rect.top;
          const d = Math.hypot(sx - cx, sy - cy);

          // Closer candidate wins; ties broken by depth (foreground closest to camera)
          if (d < bestDist || (Math.abs(d - bestDist) < 3.0 && vProj.z < bestDepth)) {
            bestDist = d;
            bestDepth = vProj.z;
            bestObj = cand;
          }
        }
      }

      if (bestObj) {
        const bData = bestObj.userData;
        if (bData && bData.id) {
          // Immediate tactile acknowledgment
          pulseBuilding(bestObj);
          setSelectedBuilding(bestObj);

          if (currentTutorialBuilding) setTutorialBuilding(null);

          // ALWAYS trigger direct building inspection! City -> Building directly
          post("buildingTapped", {
            id: bData.id,
            district: bData.district,
            name: bData.name,
            amount: bData.amount || 0,
            visits: bData.visits || 0,
            trend: bData.trend || ""
          });
        }
      }
    }

    function post(name, body) {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[name]) {
        try { window.webkit.messageHandlers[name].postMessage(body); } catch (e) {}
      }
    }

    stage.addEventListener("pointerdown", function (e) {
      onDown(e.pointerId, e.clientX, e.clientY);
      try { stage.setPointerCapture(e.pointerId); } catch (err) {}
    });
    stage.addEventListener("pointermove", function (e) { onMove(e.pointerId, e.clientX, e.clientY); });
    stage.addEventListener("pointerup", function (e) {
      onUp(e.pointerId, e.clientX, e.clientY);
      try { stage.releasePointerCapture(e.pointerId); } catch (err) {}
    });
    stage.addEventListener("pointercancel", function (e) { pointers.delete(e.pointerId); gesture = null; isDragging = true; spinVel = 0; tiltVel = 0; });
    stage.addEventListener("wheel", function (e) {
      noteEnergyInteraction();
      targetCam.zoom = clamp((targetCam.zoom || 1.0) - e.deltaY * 0.0015, ZOOM_MIN, ZOOM_MAX);
      checkCameraOffset();
    }, { passive: true });
    // iOS fires gesturestart/change for pinch on some WebKit paths; swallow them so the
    // page never scales itself underneath the canvas.
    ["gesturestart", "gesturechange", "gestureend"].forEach(function (n) {
      stage.addEventListener(n, function (e) { e.preventDefault(); });
    });
    ["contextmenu", "selectstart"].forEach(function (n) {
      window.addEventListener(n, function (e) { e.preventDefault(); return false; }, false);
      stage.addEventListener(n, function (e) { e.preventDefault(); return false; }, false);
    });

    // ────────────────────────────────────────────────────────────────
    // 🎥 CAMERA MODES, OVERVIEW & RESET
    // ────────────────────────────────────────────────────────────────
    let overviewOn = false;

    function modeZoom(mode) {
      const base = (CAM_MODES[mode] ? CAM_MODES[mode].zoom : 1.0);
      return base * (overviewOn ? 0.78 : 1.0);
    }

    function setDistrict(id, force) {
      const mode = (id && CAM_MODES[id]) ? id : "city";
      if (mode !== currentMode || force) {
        currentMode = mode;
        targetCam = Object.assign({}, CAM_MODES[currentMode]);
        targetCam.zoom = modeZoom(currentMode);
        spinVel = 0; tiltVel = 0;
        savedCameraBeforeBuilding = null;
        // Clear any building selection when switching district/mode
        setSelectedBuilding(null);
        checkCameraOffset();
      }
    }
    window.setDistrict = setDistrict;

    // Swift pushes viewResetToken on every single data update, so an unconditional reset
    // here would yank the camera back to the city the moment any figure or selection changed.
    // Only an actual change of the token means "the user explicitly asked to reset the camera".
    let lastResetToken = null;
    window.resetCityView = function (token) {
      function doReset() {
        setSelectedBuilding(null);
        savedCameraBeforeBuilding = null;
        currentMode = "city";
        targetCam = Object.assign({}, CAM_MODES.city);
        targetCam.zoom = modeZoom("city");
        spinVel = 0; tiltVel = 0;
        checkCameraOffset();
      }

      if (token === undefined || token === null) {
        doReset();
        return;
      }
      if (lastResetToken === null) {
        lastResetToken = token;
        return;
      }
      if (token !== lastResetToken) {
        lastResetToken = token;
        doReset();
      }
    };

    window.setCityOverview = function (on) {
      const v = !!on;
      if (v === overviewOn) return;
      overviewOn = v;
      targetCam.zoom = modeZoom(currentMode);
    };

    // ────────────────────────────────────────────────────────────────
    // ⏸️ RENDER PAUSE
    // The map keeps rendering at full rate behind other tabs otherwise, which is battery
    // spent on pixels nobody is looking at.
    // ────────────────────────────────────────────────────────────────
    ${cityEnergyJs}

    // ────────────────────────────────────────────────────────────────
    // 🔤 LANGUAGE
    // The names in userData are what Swift shows in the detail sheet, so they have to
    // follow the app's language rather than being frozen in Hebrew at build time.
    // ────────────────────────────────────────────────────────────────
    const I18N_BUILDINGS = {
      finance_bank:       { he: ["עיריית SPENT", "מרכז העיר והממשל"],   en: ["SPENT City Hall", "Civic centre"] },
      house_tower:        { he: ["מגורים ושכירות", "שכר דירה או משכנתא"], en: ["Housing & rent", "Rent or mortgage"] },
      house_util:         { he: ["חשבונות בית", "חשמל, מים, גז וארנונה"], en: ["Utilities", "Power, water, gas, council tax"] },
      house_subs:         { he: ["מנויים וסטרימינג", "שירותים דיגיטליים"], en: ["Subscriptions", "Digital services"] },
      shop_arcade:        { he: ["בילויים וגיימינג", "קולנוע, משחקים ואטרקציות"], en: ["Fun & gaming", "Cinema, games, attractions"] },
      shop_tech:          { he: ["טכנולוגיה", "מחשבים וגאדג'טים"],      en: ["Tech", "Computers and gadgets"] },
      shop_boutique:      { he: ["אופנה ובוטיק", "ביגוד ואופנה"],        en: ["Fashion", "Clothing and style"] },
      shop_travel:        { he: ["חופשות וטיסות", "נסיעות ופנאי"],       en: ["Travel", "Trips and leisure"] },
      food_super:         { he: ["סופרמרקט", "קניות שבועיות במכולת"],        en: ["Supermarket", "The weekly shop"] },
      food_bistro:        { he: ["מסעדות", "ארוחות בחוץ"],                   en: ["Restaurants", "Eating out"] },
      food_coffee:        { he: ["קפה ומאפים", "הרגל הקפה היומי"],           en: ["Coffee", "The daily coffee habit"] },
      food_wolt:          { he: ["משלוחי אוכל", "וולט, תן ביס ומשלוחים"],    en: ["Food delivery", "Delivery apps"] },
      city_sorting_hub:   { he: ["עמדת המיון והדואר", "הוצאות שעוד לא סווגו"], en: ["Sorting & post", "Transactions not filed yet"] },
      health_pharmacy:    { he: ["בית מרקחת", "תרופות, פארם ובריאות"],       en: ["Pharmacy", "Medicine and everyday health"] },
      museum_curiosities: { he: ["לימודים וקהילה", "השכלה, ספרים ופנאי מסקרן"], en: ["Learning", "Books, courses and curiosity"] },
      savings_sanctuary:  { he: ["שמורת הטבע", "יציבות וחיסכון פיננסי"], en: ["Nature reserve", "Savings and stability"] }
    };

    let currentLang = "he";

    function setDioramaLanguage(lang) {
      const L = (lang === "en") ? "en" : "he";
      if (L === currentLang) return;
      currentLang = L;
      for (let i = 0; i < interactiveBuildings.length; i++) {
        const u = interactiveBuildings[i].userData;
        const t = u && I18N_BUILDINGS[u.id];
        if (t && t[L]) { u.name = t[L][0]; u.trend = t[L][1]; }
      }
      for (let i = 0; i < interactiveCitizens.length; i++) {
        const u = interactiveCitizens[i].userData;
        if (u && u.phrasesByLang && u.phrasesByLang[L]) u.phrases = u.phrasesByLang[L];
      }
    }
    window.setDioramaLanguage = setDioramaLanguage;

    // ────────────────────────────────────────────────────────────────
    // ✨ SELECTION & PULSE
    // Tapping a building has to be visible in the map itself, not only in the sheet that
    // slides up underneath it.
    // ────────────────────────────────────────────────────────────────
    const buildingPulses = [];
    function pulseBuilding(m) {
      if (!m) return;
      const ex = buildingPulses.find(function (p) { return p.obj === m; });
      if (ex) { ex.t = 0; return; }
      buildingPulses.push({ obj: m, t: 0 });
    }

    let selectedBuilding = null;
    const selectionRing = new THREE.Mesh(
      new THREE.RingGeometry(1.35, 1.62, 40),
      new THREE.MeshBasicMaterial({ color: C(0xF59E0B), transparent: true, opacity: 0.0, depthWrite: false })
    );
    selectionRing.rotation.x = -Math.PI / 2;
    selectionRing.visible = false;
    root.add(selectionRing);

    function setSelectedBuilding(obj) {
      selectedBuilding = obj || null;
      if (!selectedBuilding) {
        selectionRing.visible = false;
        // Smoothly restore previous camera context before building inspection
        if (savedCameraBeforeBuilding) {
          targetCam.lookX = savedCameraBeforeBuilding.lookX;
          targetCam.lookY = savedCameraBeforeBuilding.lookY;
          targetCam.lookZ = savedCameraBeforeBuilding.lookZ;
          targetCam.zoom  = savedCameraBeforeBuilding.zoom;
          targetCam.az    = savedCameraBeforeBuilding.az;
          targetCam.el    = savedCameraBeforeBuilding.el;
          savedCameraBeforeBuilding = null;
        } else {
          const base = CAM_MODES[currentMode] || CAM_MODES.city;
          targetCam.lookX = base.lookX;
          targetCam.lookY = base.lookY;
          targetCam.lookZ = base.lookZ;
          targetCam.zoom  = base.zoom;
        }
        checkCameraOffset();
        return;
      }
      if (!savedCameraBeforeBuilding) {
        savedCameraBeforeBuilding = {
          lookX: targetCam.lookX,
          lookY: targetCam.lookY,
          lookZ: targetCam.lookZ,
          zoom:  targetCam.zoom,
          az:    targetCam.az,
          el:    targetCam.el
        };
      }
      const w = new THREE.Vector3();
      selectedBuilding.getWorldPosition(w);
      selectionRing.position.set(w.x, Y_WALK + 0.06, w.z);
      selectionRing.visible = true;
      selectionRing.material.opacity = 0.0;
      selectionRing.scale.setScalar(1.35);
      // Drift the camera to centre on the selected building (Google-Maps style)
      targetCam.lookX = w.x * 0.72;
      targetCam.lookY = w.y + 0.4;
      targetCam.lookZ = w.z * 0.72;
      targetCam.zoom  = Math.min(ZOOM_MAX, (targetCam.zoom || 1.0) * 1.35);
      checkCameraOffset();
    }
    window.selectDioramaBuilding = function (id) {
      if (!id) {
        setSelectedBuilding(null);
        return true;
      }
      if (selectedBuilding && selectedBuilding.userData && selectedBuilding.userData.id === id) {
        return true;
      }
      for (let i = 0; i < interactiveBuildings.length; i++) {
        if (interactiveBuildings[i].userData && interactiveBuildings[i].userData.id === id) {
          pulseBuilding(interactiveBuildings[i]);
          setSelectedBuilding(interactiveBuildings[i]);
          return true;
        }
      }
      return false;
    };

    // A newly unlocked upgrade gets one celebratory bounce instead of appearing silently.
    const celebrations = [];
    const slotBounces = [];

    function bounceSlot(slotId) {
      const slot = slotItems[slotId];
      if (!slot) return;
      const ex = slotBounces.find(function (b) { return b.slot === slot; });
      if (ex) { ex.t = 0; return; }
      slotBounces.push({ slot: slot, t: 0 });
    }

    let lastCelebrated = null;
    window.celebrateNewEnrichment = function (id) {
      if (!id || id === lastCelebrated) return;
      lastCelebrated = id;
      if (welcomeCompanion(id)) return;
      // An enrichment id names an item, so look for the slot holding it first.
      for (const sid in slotItems) {
        if (slotItems[sid].itemId === id) { bounceSlot(sid); return; }
      }
      const target = buildingRoots[id];
      if (target) { celebrations.push({ obj: target, t: 0 }); return; }
      window.selectDioramaBuilding(id);
    };

    // ────────────────────────────────────────────────────────────────
    // 🏙️ SPENDING DRIVES THE CITY
    // A building's height and window glow follow what was actually spent there, so the
    // skyline is the month rather than a decoration sitting next to it.
    // ────────────────────────────────────────────────────────────────
    const buildingAmounts = {};
    const buildingDistrictKeys = {
      house_tower: "housing", house_util: "housing", house_subs: "subscriptions",
      food_bistro: "food", food_super: "food", food_coffee: "food", food_wolt: "food",
      shop_boutique: "shopping", shop_tech: "shopping", shop_travel: "shopping", shop_arcade: "entertainment",
      trans_station: "transport", health_pharmacy: "health", finance_bank: "finance",
      museum_curiosities: "miscellaneous", city_sorting_hub: "other"
    };
    let districtStates = {};
    let unlockedEnrichments = [];

    function bodyOf(id) {
      for (let i = 0; i < interactiveBuildings.length; i++) {
        if (interactiveBuildings[i].userData && interactiveBuildings[i].userData.id === id) return interactiveBuildings[i];
      }
      return null;
    }

    window.pulseHintBuilding = function () {
      const b = bodyOf("food_bistro") || bodyOf("food_coffee") || bodyOf("trans_station");
      if (b) pulseBuilding(b);
    };

    const tutorialMarker = document.createElement("button");
    tutorialMarker.type = "button";
    tutorialMarker.className = "diorama-tutorial-target";
    overlaysContainer.appendChild(tutorialMarker);
    const tutorialWorldPoint = new THREE.Vector3();
    const tutorialScreenPoint = new THREE.Vector3();
    let currentTutorialBuilding = null;
    ["pointerdown", "pointerup", "pointermove"].forEach(function (event) {
      tutorialMarker.addEventListener(event, function (e) { e.stopPropagation(); });
    });
    tutorialMarker.addEventListener("click", function (e) {
      e.stopPropagation();
      const obj = currentTutorialBuilding;
      if (!obj) return;
      const data = obj.userData;
      setTutorialBuilding(null);
      if (CAM_MODES[data.district]) setDistrict(data.district);
      setSelectedBuilding(obj);
      pulseBuilding(obj);
      post("buildingTapped", { id: data.id, district: data.district, name: data.name });
    });

    function setTutorialBuilding(id) {
      const next = id ? bodyOf(id) : null;
      tutorialMarker.setAttribute("aria-label", currentLang === "he" ? "פתיחת פרטי הבניין המסומן" : "Open highlighted building details");
      if (next === currentTutorialBuilding) return;
      currentTutorialBuilding = next;
      tutorialMarker.classList.toggle("active", !!next);
      if (next && !companionMotionPreference.matches) pulseBuilding(next);
    }

    function updateTutorialMarker() {
      if (!currentTutorialBuilding || !visibleInScene(currentTutorialBuilding)) {
        tutorialMarker.classList.remove("active");
        return;
      }
      // The proxy is a stable, cheap anchor; hidden upper floors must not push the marker
      // above the visible building. The marker itself is also a 68px accessible tap target.
      currentTutorialBuilding.getWorldPosition(tutorialWorldPoint);
      tutorialScreenPoint.copy(tutorialWorldPoint).project(camera);
      const inFront = tutorialScreenPoint.z >= -1 && tutorialScreenPoint.z <= 1;
      tutorialMarker.classList.toggle("active", inFront);
      if (!inFront) return;
      tutorialMarker.style.left = ((tutorialScreenPoint.x * 0.5 + 0.5) * viewportWidth) + "px";
      tutorialMarker.style.top = ((-tutorialScreenPoint.y * 0.5 + 0.5) * viewportHeight) + "px";
    }

    function tierForBuilding(amount, totalShare, state) {
      // A busy neighbourhood may add people, lights and detail around this plot, but it may
      // never turn a place the user did not spend at into a large building.
      if (!amount || amount <= 0) return 1;
      if (!state || !state.amount || state.amount <= 0) return tierForShare(totalShare);

      const shareInsideDistrict = amount / state.amount;
      if (state.prominence === "dominant") {
        if (shareInsideDistrict >= 0.50) return 4;
        if (shareInsideDistrict >= 0.15) return 3;
        return 2;
      }
      if (state.prominence === "developed") {
        return shareInsideDistrict >= 0.35 ? 3 : 2;
      }
      return 2;
    }

    function syncDistrictStates(rawStates) {
      districtStates = {};
      if (!Array.isArray(rawStates)) return;
      for (let i = 0; i < rawStates.length; i++) {
        const state = rawStates[i];
        if (state && typeof state.id === "string") districtStates[state.id] = state;
      }
    }

    function applyBuildingActivity() {
      // ── Pass 1: total spending across all spending buildings (not savings) ──
      let totalSpent = 0;
      for (let i = 0; i < interactiveBuildings.length; i++) {
        const b = interactiveBuildings[i];
        const id = b.userData && b.userData.id;
        if (!id || id === "savings_sanctuary") continue;
        totalSpent += buildingAmounts[id] || 0;
      }

      // ── Pass 2: districts create atmosphere; actual spend earns each building's mass ──
      let lit = 0, counted = 0;
      for (let i = 0; i < interactiveBuildings.length; i++) {
        const b = interactiveBuildings[i];
        const id = b.userData && b.userData.id;
        if (!id || id === "savings_sanctuary") continue;
        const amt = buildingAmounts[id] || 0;

        // A merchant's own spend makes its windows and street details livelier.
        const base = CATEGORY_BASELINES[id] || 350;
        const localActivity = Math.min(1, amt / base);
        const share = totalSpent > 0 ? amt / totalSpent : 0;
        const rec = cityBuildings[id];
        const district = districtStates[buildingDistrictKeys[id]];
        // The whole neighbourhood reacts to its category, while this particular place's
        // own transactions decide whether it is a stall, shop, mid-rise or landmark.
        b.userData.activity = district
          ? Math.min(1, district.activity * 0.72 + localActivity * 0.28)
          : localActivity;
        if (rec) setBuildingTier(rec, tierForBuilding(amt, share, district));

        lit += b.userData.activity; counted++;
      }
      cityGlowTarget = counted > 0 ? Math.min(0.34, (lit / counted) * 0.34) : 0;
    }
    let cityGlowTarget = 0, cityGlow = 0;

    // ────────────────────────────────────────────────────────────────
    // 🔄 14. DATA BRIDGE: window.updateDioramaData (Swift Inbound Contract)
    // ────────────────────────────────────────────────────────────────
    // Validate the entire envelope before mutating the live scene.
    function validateDioramaPayload(data) {
      const fail = field => { throw new Error("DioramaPayloadV1: invalid " + field); };
      if (!data || data.schemaVersion !== 1) fail("schemaVersion");
      const number = (value, field) => { if (typeof value !== "number" || !Number.isFinite(value)) fail(field); };
      ["food", "shopping", "housing", "transport", "savings", "savingsTarget", "parkHealth"].forEach(k => number(data[k], k));
      for (const [group, fields] of Object.entries({foodSub:["restaurant","groceries","coffee","delivery"], shoppingSub:["fashion","tech","travel","entertainment"], housingSub:["rent","utilities","subs"]})) {
        if (!data[group]) fail(group);
        fields.forEach(k => number(data[group][k], group + "." + k));
      }
      const districtIDs = new Set(Object.values(buildingDistrictKeys).concat(["savings"]));
      for (const [key, ids] of [["districts", districtIDs], ["venues", new Set(Object.keys(buildingDistrictKeys).concat(["savings_sanctuary"]))]]) {
        if (!Array.isArray(data[key])) fail(key);
        const seen = new Set();
        data[key].forEach(state => {
          if (!state || !ids.has(state.id) || seen.has(state.id)) fail(key + ".id");
          seen.add(state.id);
          ["amount", "share", "activity"].forEach(k => number(state[k], key + "." + k));
          if (key === "districts" && !["quiet","active","developed","dominant"].includes(state.prominence)) fail("prominence");
          if (key === "venues") ["purchaseCount","activeDays","merchantCount","presence","additionalPlaces"].forEach(k => number(state[k], "venues." + k));
        });
      }
      if (!data.habits || typeof data.habits.hasTravelOrFlight !== "boolean") fail("habits");
      ["woltCount","coffeeCount","onlinePackagesCount","activeSubscriptionsCount"].forEach(k => number(data.habits[k], "habits." + k));
      ["otherAmount","museumAmount","healthAmount","financeAmount","pendingSortingCount"].forEach(k => { if (data[k] != null) number(data[k], k); });
      if (data.tutorialBuildingId != null && !Object.prototype.hasOwnProperty.call(buildingDistrictKeys, data.tutorialBuildingId)) fail("tutorialBuildingId");
      if (!Array.isArray(data.enrichments) || data.enrichments.some(id => typeof id !== "string")) fail("enrichments");
      if (!data.slotPlacements || typeof data.slotPlacements !== "object" || Array.isArray(data.slotPlacements)) fail("slotPlacements");
      return data;
    }
    function reportDioramaError(error) {
      const message = error instanceof Error ? error.message : "Diorama update failed";
      console.error(message);
      if (window.webkit && window.webkit.messageHandlers.dioramaError) {
        window.webkit.messageHandlers.dioramaError.postMessage(message);
      }
      return false;
    }
    window.updateDioramaData = function (data) {
      try { validateDioramaPayload(data); } catch (error) { return reportDioramaError(error); }
      shadowDirty = true;
      try {
        if (data.language) setDioramaLanguage(data.language);
        if (data.targetDistrict) setDistrict(data.targetDistrict);
        setTutorialBuilding(data.tutorialBuildingId || null);
        syncDistrictStates(data.districts);

        function syncBuilding(id, amount) {
          const amt = (typeof amount === "number" && isFinite(amount)) ? amount : 0;
          buildingAmounts[id] = amt;
          const bg = buildingRoots[id];
          if (bg) { bg.userData = bg.userData || {}; bg.userData.amount = amt; }
          // The tappable mesh is what Swift reads back on buildingTapped, so the figure has
          // to land there too — writing it only on the group left every tap reporting 0.
          const body = bodyOf(id);
          if (body && body.userData) body.userData.amount = amt;
        }

        // Food District
        const fRest   = (data.foodSub && data.foodSub.restaurant !== undefined) ? data.foodSub.restaurant : 0;
        const fSuper  = (data.foodSub && data.foodSub.groceries  !== undefined) ? data.foodSub.groceries  : 0;
        const fCoffee = (data.foodSub && data.foodSub.coffee     !== undefined) ? data.foodSub.coffee     : 0;
        const fWolt   = (data.foodSub && data.foodSub.delivery   !== undefined) ? data.foodSub.delivery   : 0;
        // The food district is four separate places now, exactly as the app already tracks
        // them, so each one is built by its own habit rather than by a shared total.
        syncBuilding("food_bistro", fRest);
        syncBuilding("food_super", fSuper);
        syncBuilding("food_coffee", fCoffee);
        syncBuilding("food_wolt", fWolt);

        // Shopping District
        const sFashion = (data.shoppingSub && data.shoppingSub.fashion       !== undefined) ? data.shoppingSub.fashion       : 0;
        const sTech    = (data.shoppingSub && data.shoppingSub.tech          !== undefined) ? data.shoppingSub.tech          : 0;
        const sTravel  = (data.shoppingSub && data.shoppingSub.travel        !== undefined) ? data.shoppingSub.travel        : 0;
        const sArcade  = (data.shoppingSub && data.shoppingSub.entertainment !== undefined) ? data.shoppingSub.entertainment : 0;
        syncBuilding("shop_boutique", sFashion);
        syncBuilding("shop_tech", sTech);
        syncBuilding("shop_travel", sTravel);
        syncBuilding("shop_arcade", sArcade);

        // Housing District
        const rTower = (data.housingSub && data.housingSub.rent      !== undefined) ? data.housingSub.rent      : 0;
        const rUtil  = (data.housingSub && data.housingSub.utilities !== undefined) ? data.housingSub.utilities : 0;
        const rSubs  = (data.housingSub && data.housingSub.subs      !== undefined) ? data.housingSub.subs      : (data.housingSub && data.housingSub.subscriptions || 0);
        syncBuilding("house_tower", rTower);
        syncBuilding("house_util", rUtil);
        syncBuilding("house_subs", rSubs);

        syncBuilding("city_sorting_hub", data.otherAmount || 0);
        syncBuilding("museum_curiosities", data.museumAmount || 0);
        syncBuilding("health_pharmacy", data.healthAmount || 0);
        syncBuilding("finance_bank", data.financeAmount || 0);
        syncBuilding("trans_station", data.transport || 0);
        syncBuilding("savings_sanctuary", data.savings || 0);
        applyBuildingActivity();

        // Reserve health drives the planting, the foliage colour and the water.
        applyParkHealth(data.parkHealth !== undefined ? data.parkHealth : HEALTHY_PARK);

        // How full the reserve is against the user's own target, shown as lake area.
        if (typeof data.savingsTarget === "number" && data.savingsTarget > 0) {
          const fill = clamp((data.savings || 0) / data.savingsTarget, 0, 1);
          lakeFillTarget = 0.72 + fill * 0.34;
        } else {
          lakeFillTarget = 1.0;
        }

        // Transport spending puts traffic on the roads.
        if (typeof data.transport === "number") setTrafficLevel(data.transport);

        // Unsorted transactions park a delivery van outside the sorting hub.
        setPendingSorting(data.pendingSortingCount || 0);

        // Preserve grandfathered scenery; companions arrive without manual placement.
        applySlotPlacements(data.slotPlacements);
        unlockedEnrichments = Array.isArray(data.enrichments) ? data.enrichments : [];
        applyCompanions(unlockedEnrichments);
        applyCityLife(data);

        if (data.newlyUnlockedId) window.celebrateNewEnrichment(data.newlyUnlockedId);
      } catch (err) {
        return reportDioramaError(err);
      }
    };

    // ────────────────────────────────────────────────────────────────
    // 🚚 TRAFFIC, DELIVERIES & RESERVE FILL
    // ────────────────────────────────────────────────────────────────
    let trafficSpeed = 1.0;
    function setTrafficLevel(transport) {
      const t = (typeof transport === "number" && isFinite(transport)) ? Math.max(0, transport) : 0;
      const level = Math.min(1, t / 900);          // ~900 a month reads as a busy city
      trafficSpeed = 0.85 + level * 0.25;
      // All vehicles in the two-way loops remain active and circulating!
      for (let i = 0; i < vehicleState.length; i++) vehicleState[i].obj.visible = true;
      // The ride station fills up with the transport line rather than only the traffic.
      const units = Math.min(4, 1 + Math.round(level * 3));
      for (let i = 0; i < transportUnits.length; i++) transportUnits[i].visible = i < units;
    }

    // A parked van outside the work complex whenever transactions are waiting to be sorted.
    const deliveryVan = createCar(0xF59E0B, false, false);
    deliveryVan.position.set(8.6, Y_WALK, 10.6);
    deliveryVan.rotation.y = Math.PI / 2;
    deliveryVan.visible = false;
    root.add(deliveryVan);
    let pendingSorting = 0;
    function setPendingSorting(n) {
      pendingSorting = (typeof n === "number" && n > 0) ? n : 0;
      deliveryVan.visible = pendingSorting > 0;
    }

    // How full the reserve is against the user's own savings target, read as lake area.
    let lakeFillTarget = 1.0, lakeFill = 1.0;

    setTrafficLevel(0);
    // ────────────────────────────────────────────────────────────────
    // 🎬 15. MAIN RENDER LOOP
    // ────────────────────────────────────────────────────────────────
    let lastTime = performance.now();

    function loop(now) {
      rafId = null;
      if (renderPaused || energyDisposed) return;
      rafId = requestAnimationFrame(loop);
      if (!energyFrameDue(now)) return;
      // The first rAF timestamp can predate the performance.now() taken while this script
      // was still parsing, so dt must never go negative — a negative dt drove vehicle
      // progress below zero and JS's negative modulo then indexed path[-1].
      const dt = Math.max(0, Math.min(0.1, (now - lastTime) / 1000));
      lastTime = now;

      // Camera smoothing lerp
      const smoothing = 1 - Math.pow(0.88, dt * 60);
      const zoomSmoothing = 1 - Math.pow(0.90, dt * 60);
      ["az", "el", "lookX", "lookY", "lookZ"].forEach(function (key) {
        const delta = targetCam[key] - currentCam[key];
        currentCam[key] = Math.abs(delta) < 0.0001 ? targetCam[key] : currentCam[key] + delta * smoothing;
      });
      const zoomDelta = (targetCam.zoom || 1) - currentCam.zoom;
      currentCam.zoom = Math.abs(zoomDelta) < 0.0001 ? (targetCam.zoom || 1) : currentCam.zoom + zoomDelta * zoomSmoothing;

      if (pointers.size === 0) {
        const decay = Math.pow(0.92, dt * 60), travel = (1 - decay) / (1 - 0.92);
        targetCam.az += spinVel * travel; spinVel *= decay;
        targetCam.el = clamp(targetCam.el + tiltVel * travel, 0.25, 1.25); tiltVel *= decay;
        if (Math.abs(spinVel) < 0.00001) spinVel = 0;
        if (Math.abs(tiltVel) < 0.00001) tiltVel = 0;
      }

      placeCam();
      applyFrustum();
      updateTutorialMarker();

      // Window glow follows how busy the city is
      if (cityGlow !== cityGlowTarget) {
        cityGlow += (cityGlowTarget - cityGlow) * Math.min(1, dt * 1.6);
        if (Math.abs(cityGlow - cityGlowTarget) < 0.0001) cityGlow = cityGlowTarget;
        for (let i = 0; i < litGlass.length; i++) litGlass[i].emissiveIntensity = cityGlow;
      }

      // Tap pulse. The tap target is an invisible proxy box, so the squash has to be applied
      // to the shell it stands for — scaling the proxy would move the hit area, not the building.
      for (let i = buildingPulses.length - 1; i >= 0; i--) {
        const p = buildingPulses[i];
        p.t += dt;
        const k = Math.min(1, p.t / 0.20);
        p.amp = Math.sin(k * Math.PI) * (1 - k) * 0.18;
        const target = (p.obj.userData && p.obj.userData.shell) ? p.obj.userData.shell : (p.obj.userData && p.obj.userData.id && buildingRoots[p.obj.userData.id] ? buildingRoots[p.obj.userData.id] : p.obj);
        if (target) {
          target.scale.y = 1 + p.amp;
          target.scale.x = 1 - p.amp * 0.28;
          target.scale.z = 1 - p.amp * 0.28;
        }
        if (k >= 1) {
          if (target) target.scale.set(1, 1, 1);
          buildingPulses.splice(i, 1);
        }
      }

      // Selection ring under the last tapped building
      if (selectionRing.visible) {
        const m = selectionRing.material;
        m.opacity += (0.55 - m.opacity) * Math.min(1, dt * 6);
        const s0 = selectionRing.scale.x;
        selectionRing.scale.setScalar(s0 + (1 - s0) * Math.min(1, dt * 7));
        selectionRing.rotation.z += dt * 0.6;
      }

      // Unlock celebration bounce
      for (let i = celebrations.length - 1; i >= 0; i--) {
        const c = celebrations[i];
        c.t += dt;
        const k = Math.min(1, c.t / 0.9);
        c.obj.position.y = Y_WALK + Math.sin(k * Math.PI * 3) * (1 - k) * 0.5;
        if (k >= 1) { c.obj.position.y = Y_WALK; celebrations.splice(i, 1); }
      }

      stepPlantings(dt);
      stepRising(dt);
      stepCrews(dt, now);
      for (let i = 0; i < pigeons.length; i++) {
        const pg = pigeons[i];
        pg.obj.position.y = Y_WALK + Math.max(0, Math.sin(now * 0.0011 + pg.phase) - 0.86) * 1.6;
        pg.obj.rotation.y += dt * 0.25;
      }

      // Newly placed enrichments grow in rather than popping into existence
      for (let i = slotGrowth.length - 1; i >= 0; i--) {
        const h = slotGrowth[i];
        const sc = h.scale.x + (1 - h.scale.x) * Math.min(1, dt * 5.0);
        h.scale.setScalar(sc);
        if (sc > 0.995) { h.scale.setScalar(1); slotGrowth.splice(i, 1); }
      }
      for (let i = slotBounces.length - 1; i >= 0; i--) {
        const b = slotBounces[i];
        b.t += dt;
        const k = Math.min(1, b.t / 0.5);
        b.slot.holder.position.y = 0.09 + Math.sin(k * Math.PI) * (1 - k) * 0.22;
        if (k >= 1) { b.slot.holder.position.y = 0.09; slotBounces.splice(i, 1); }
      }

      animateCompanions(now, dt);

      // Reserve fill: the lake grows toward the user's savings target
      lakeFill += (lakeFillTarget - lakeFill) * Math.min(1, dt * 2.0);
      if (lakeMesh) lakeMesh.scale.set(lakeFill, 1, lakeFill);

      // Step walking citizens
      walkingCitizens.forEach(function (c) {
        if (!c.obj.visible) return;
        c.t += dt * (c.speed || 1.0);
        const p1 = c.path[c.pIdx];
        const p2 = c.path[(c.pIdx + 1) % c.path.length];
        const dist = Math.max(0.001, Math.hypot(p2.x - p1.x, p2.z - p1.z));
        const frac = c.t / dist;
        if (frac >= 1.0) {
          c.t = 0;
          c.pIdx = (c.pIdx + 1) % c.path.length;
        } else {
          c.obj.position.x = p1.x + (p2.x - p1.x) * frac;
          c.obj.position.z = p1.z + (p2.z - p1.z) * frac;
          c.obj.rotation.y = Math.atan2(p2.x - p1.x, p2.z - p1.z);
        }
        const walkCycle = now * 0.0055 * Math.max(0.6, (c.speed || 0.35) / 0.35) + (c.phase || 0);
        const legSwing = Math.sin(walkCycle) * 0.38;
        if (c.legL) c.legL.rotation.x = legSwing;
        if (c.legR) c.legR.rotation.x = -legSwing;
        if (c.armL) c.armL.rotation.x = -legSwing * 0.8;
        if (c.armR) c.armR.rotation.x = legSwing * 0.8;
        if (c.kneeL) c.kneeL.rotation.x = Math.max(0, legSwing) * 0.7;
        if (c.kneeR) c.kneeR.rotation.x = Math.max(0, -legSwing) * 0.7;
        c.obj.position.y = (c.baseY || Y_WALK) + Math.abs(Math.sin(walkCycle)) * 0.018;
        if (c.dog) {
          c.dog.position.set(c.obj.position.x + Math.sin(c.obj.rotation.y + 1.2) * 0.45,
                             (c.baseY || Y_WALK),
                             c.obj.position.z + Math.cos(c.obj.rotation.y + 1.2) * 0.45);
          c.dog.rotation.y = c.obj.rotation.y;
        }
      });

      // Step looping vehicles (calm cruising, subtle suspension breathing)
      vehicleState.forEach(function (v) {
        if (!v.obj.visible) return;
        v.progress = ((v.progress + dt * v.speed * trafficSpeed) % 1.0 + 1.0) % 1.0;
        const segs = v.path.length;
        const p = v.progress * segs;
        const idx = Math.floor(p);
        const frac = p - idx;
        const pA = v.path[((idx % segs) + segs) % segs];
        const pB = v.path[((idx + 1) % segs + segs) % segs];
        if (!pA || !pB) return;
        v.obj.position.x = pA.x + (pB.x - pA.x) * frac;
        v.obj.position.z = pA.z + (pB.z - pA.z) * frac;
        v.obj.position.y = (v.baseY || Y_WALK) + Math.sin(now * 0.003 + v.progress * 25) * 0.006;
        v.obj.rotation.y = Math.atan2(pB.x - pA.x, pB.z - pA.z);
      });

      // Step all animated and pulsing diorama elements (gentle and relaxing)
      for (let ai = animObjects.length - 1; ai >= 0; ai--) {
        const a = animObjects[ai];
        if ((a.ref && !a.ref.parent) || (a.spout && !a.spout.parent)) {
          animObjects.splice(ai, 1);
          continue;
        }
        switch (a.type) {
          case "reward_pet":
            if (companionMotionPreference.matches || !visibleInScene(a.ref)) break;
            a.tail.rotation.z = Math.sin(now * 0.004) * 0.24;
            break;
          case "reward_artist":
            if (companionMotionPreference.matches || !visibleInScene(a.ref)) break;
            a.arm.rotation.x = -1.2 + Math.sin(now * 0.0016) * 0.14;
            break;
          case "fountain_spout":
            if (a.spout) {
              const sP = Math.sin(now * 0.0025);
              a.spout.scale.set(
                1 + sP * 0.18,
                1 + Math.sin(now * 0.0035) * 0.25,
                1 + sP * 0.18
              );
              a.spout.rotation.y += dt * 0.4;
            }
            break;
          case "fountain_ripple":
            if (a.ring && a.mat) {
              const rCycle = (now * 0.00045) % 1.0;
              const rScale = 0.3 + rCycle * 2.8;
              a.ring.scale.set(rScale, rScale, 1);
              a.mat.opacity = Math.max(0, (1 - rCycle) * 0.65);
            }
            break;
          case "lake_ripple":
            if (a.ring && a.mat) {
              const lCycle = (now * 0.00028) % 1.0;
              const lScale = 0.4 + lCycle * 3.5;
              a.ring.scale.set(lScale, lScale * 0.75, 1);
              a.mat.opacity = Math.max(0, (1 - lCycle) * 0.45);
            }
            break;
          case "chimney_smoke":
            if (a.puffs) {
              a.puffs.forEach(function (p) {
                const sT = ((now * 0.00035 + p.phase) % 1.0 + 1.0) % 1.0;
                p.mesh.position.y = sT * 1.35;
                p.mesh.position.x = Math.sin(sT * Math.PI * 2) * 0.14 + sT * 0.25;
                p.mesh.position.z = Math.cos(sT * Math.PI * 2) * 0.09;
                const pScale = 0.5 + sT * 1.6;
                p.mesh.scale.setScalar(pScale);
                p.mat.opacity = Math.sin(sT * Math.PI) * 0.6;
              });
            }
            break;
          case "beacon":
            if (a.mat) {
              const bPulse = 0.5 + 0.5 * Math.sin(now * 0.0018 + (a.phase || 0));
              a.mat.emissiveIntensity = (a.base || 0.4) + bPulse * (a.range || 1.6);
            }
            break;
          case "neon_pulse":
            if (a.mat) {
              const nPulse = 0.5 + 0.5 * Math.sin(now * 0.003 + (a.phase || 0));
              a.mat.emissiveIntensity = (a.base || 0.8) + nPulse * (a.range || 1.4);
            }
            break;
          case "cross_pulse":
            if (a.mat) {
              const cPulse = 0.5 + 0.5 * Math.sin(now * 0.0022 + (a.phase || 0));
              a.mat.emissiveIntensity = 0.5 + cPulse * 1.2;
            }
            break;
          case "rotate_y":
            if (a.ref) {
              a.ref.rotation.y += dt * (a.speed || 0.6);
            }
            break;
          case "butterfly_orbit":
            if (a.ref) {
              const bfT = now * 0.0012 * a.speed + a.phase;
              a.ref.position.x = a.cx + Math.sin(bfT) * a.radius;
              a.ref.position.z = a.cz + Math.sin(bfT * 2.0) * (a.radius * 0.65);
              a.ref.position.y = a.baseY + Math.sin(bfT * 3.5) * 0.22;
              a.ref.rotation.y = Math.cos(bfT) * 1.2;
              const wingFlap = Math.sin(now * 0.024) * 0.85;
              if (a.wingL) a.wingL.rotation.y = wingFlap;
              if (a.wingR) a.wingR.rotation.y = -wingFlap;
            }
            break;
          case "bird":
            if (a.ref) {
              const bT = now * 0.0006 * a.speed + a.phase;
              a.ref.position.x = a.cx + Math.cos(bT) * a.radius;
              a.ref.position.z = a.cz + Math.sin(bT) * a.radius;
              a.ref.position.y = a.baseY + Math.sin(bT * 2.5) * 0.35;
              a.ref.rotation.y = -bT;
              if (a.wingL) a.wingL.rotation.z = Math.sin(now * 0.008) * 0.22;
              if (a.wingR) a.wingR.rotation.z = -Math.sin(now * 0.008) * 0.22;
            }
            break;
          case "bob":
            if (a.ref) {
              a.ref.position.y = a.base + Math.abs(Math.sin(now * 0.0025 + a.phase)) * 0.03;
              a.ref.rotation.y = (a.baseRotY || 0) + Math.sin(now * 0.0012 + a.phase) * 0.35;
            }
            break;
        }
      }

      // Step speech bubbles
      for (let bi = activeBubbles.length - 1; bi >= 0; bi--) {
        const b = activeBubbles[bi];
        b.life += dt;
        if (b.life > b.maxLife) {
          if (b.el && b.el.parentNode) b.el.parentNode.removeChild(b.el);
          activeBubbles.splice(bi, 1);
        }
      }

      prepareEnergyRender(now);
      renderer.render(scene, camera);
    }

    window.addEventListener("resize", resize);
    placeCam(); resize();
    startLoop();

    if (window._initialDataPayload) {
      window.updateDioramaData(window._initialDataPayload);
    }

    mergeStaticScenery();

    // Shadow casting costs a second draw call per mesh. Signs, window panes, wheels, lamp
    // bulbs and other small detail read fine without their own shadow, so only geometry big
    // enough to be legible as a silhouette keeps casting.
    (function trimShadowCasters() {
      let dropped = 0;
      root.traverse(function (o) {
        if (!o.isMesh || !o.castShadow || !o.geometry) return;
        if (!o.geometry.boundingSphere) o.geometry.computeBoundingSphere();
        const r = o.geometry.boundingSphere ? o.geometry.boundingSphere.radius : 1;
        if (r < 0.34) { o.castShadow = false; dropped++; }
      });
      return dropped;
    })();

    // Inspection handle. Costs nothing at runtime and is the only way to reason about the
    // scene from outside the closure when something renders wrong.
    window.__diorama = {
      scene: scene, root: root, camera: camera, renderer: renderer,
      buildingRoots: buildingRoots, interactiveBuildings: interactiveBuildings,
      materials: { water: M_WATER, grass: M_GRASS_LIME, pine: M_PINE, leaf: M_LEAF },
      plantings: parkPlantings,
      buildings: cityBuildings,
      life: { states: venueStates, instances: lifeInstances, assignments: lifeAssignments,
        plots: LIFE_PLOTS, actors: venueActors, vehicles: vehicleState, allocate: allocateLifePlaces,
        crowds: function () { return crowdSnapshot; }, crowdWalkers: crowdWalkers, crowdBatches: crowdBatches },
      slots: slotItems,
      companions: companionInstances,
      enrichments: function () { return unlockedEnrichments; },
      camModes: CAM_MODES,
      state: function () { return { mode: currentMode, cam: currentCam, target: targetCam, parkHealth: parkHealthValue }; }
    };

    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.dioramaReady) {
      try { window.webkit.messageHandlers.dioramaReady.postMessage({}); } catch(e) {}
    }
  </script>
</body>
</html>
`;

// Validate every inline script before replacing the generated resource.
for (const match of htmlContent.matchAll(/<script>([\s\S]*?)<\/script>/g)) new Function(match[1]);
const output = path.join(__dirname, 'MoneyCity/Resources/diorama.html');
fs.writeFileSync(output, htmlContent, 'utf8');
console.log('V2 scene validated and generated: ' + output);
