const fs = require('fs');
const path = require('path');

// The diorama is authored here and compiled into MoneyCity/Resources/diorama.html.
//
// This file was regenerated from that HTML on 2026-08-31, because the two had drifted:
// roughly 776 lines — the construction crews, the street characters, the speech-bubble
// engine — had been written straight into the compiled output, and running this script
// silently deleted every one of them. Edit the diorama HERE from now on, and run
// `node build_diorama.js` to compile. Editing diorama.html directly puts the two out of
// sync again and the next build wins.
const threeMinJs = fs.readFileSync(path.join(__dirname, "vendor/three.min.js"), "utf8");

const htmlContent = `<!DOCTYPE html>
<html lang="he">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
  <style>
    * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Rounded", "SF Pro Text", "Helvetica Neue", "Arial Hebrew", "Arial", sans-serif; }
    html, body { margin:0; padding:0; width:100%; height:100%; overflow:hidden; background: transparent !important; touch-action:none; }
    #stage { width:100%; height:100%; position:relative; overflow:hidden; background: transparent !important; }
    canvas { display:block; width:100% !important; height:100% !important; background: transparent !important; }
    
    /* 🏷️ Crisp Native Vector Floating Pill Tags Overlay */
    #diorama-html-tags {
      position: absolute;
      top: 0; left: 0;
      width: 100%; height: 100%;
      pointer-events: none;
      overflow: hidden;
      z-index: 10;
    }
    .diorama-pill-tag {
      position: absolute;
      top: 0; left: 0;
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 4px 10px 4px 4px;
      background: #ffffff;
      border: 1.5px solid rgba(232, 237, 245, 0.95);
      border-radius: 999px;
      box-shadow: 0 4px 14px rgba(16, 23, 45, 0.08), 0 1px 3px rgba(16, 23, 45, 0.04);
      transform: translate3d(-50%, -100%, 0) scale(0.001);
      opacity: 0;
      transition: opacity 0.25s ease, transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
      pointer-events: auto;
      cursor: pointer;
      user-select: none;
      -webkit-user-select: none;
      white-space: nowrap;
      will-change: transform, opacity;
    }
    .diorama-pill-tag.active {
      opacity: 1;
      transform: translate3d(-50%, -100%, 0) scale(1);
    }
    .diorama-pill-tag.active:active {
      transform: translate3d(-50%, -100%, 0) scale(0.92);
    }
    .diorama-pill-badge {
      width: 22px;
      height: 22px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 11px;
      color: #ffffff;
      flex-shrink: 0;
    }
    .diorama-pill-amount {
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Rounded', 'SF Pro Display', system-ui, sans-serif;
      font-weight: 800;
      font-size: 13px;
      letter-spacing: -0.2px;
      color: #10172D;
    }
    .diorama-pill-amount.zero {
      color: #94a3b8;
      font-weight: 700;
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
  </style>
  <script>
${threeMinJs}
  </script>
</head>
<body>
  <div id="stage">
    <div id="diorama-html-tags"></div>
  </div>
  <script>
    const stage = document.getElementById("stage");
    const tagsContainer = document.getElementById("diorama-html-tags");
    const scene = new THREE.Scene();

    // ========== RENDERER (100% Transparent Canvas with Mobile Thermal Throttling Protection) ==========
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: "high-performance", precision: "mediump" });
    renderer.setClearColor(0x000000, 0);
    renderer.setPixelRatio(Math.min(2.0, window.devicePixelRatio || 1.5));
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.outputEncoding = THREE.sRGBEncoding;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.35;
    stage.appendChild(renderer.domElement);

    const FR = 14.8;
    let camera = new THREE.OrthographicCamera(-FR, FR, FR, -FR, -100, 200);

    const CAM_MODES = {
      city:     { az: Math.PI * 0.25, el: 0.52, zoom: 0.95, lookX: 0,    lookY: 0.20, lookZ: 0 },
      food:     { az: Math.PI * 0.25, el: 0.48, zoom: 2.10, lookX: -6.2, lookY: 0.65, lookZ: -6.8 },
      shopping: { az: Math.PI * 0.25, el: 0.48, zoom: 2.10, lookX: 6.8,  lookY: 0.65, lookZ: -6.8 },
      housing:  { az: Math.PI * 0.25, el: 0.48, zoom: 2.10, lookX: 6.8,  lookY: 0.65, lookZ: 6.0 },
      savings:  { az: Math.PI * 0.25, el: 0.48, zoom: 2.10, lookX: -6.2, lookY: 0.65, lookZ: 6.0 }
    };

    let currentMode = "city";
    let currentCam = Object.assign({}, CAM_MODES.city);
    let targetCam   = Object.assign({}, CAM_MODES.city);

    function placeCam() {
      const r = 40;
      camera.position.set(
        currentCam.lookX + r * Math.cos(currentCam.el) * Math.cos(currentCam.az),
        currentCam.lookY + r * Math.sin(currentCam.el),
        currentCam.lookZ + r * Math.cos(currentCam.el) * Math.sin(currentCam.az)
      );
      camera.lookAt(currentCam.lookX, currentCam.lookY, currentCam.lookZ);
    }

    function resize() {
      const w = stage.clientWidth  || window.innerWidth  || 320;
      const h = stage.clientHeight || window.innerHeight || 380;
      if (!w || !h || w <= 0 || h <= 0) return;
      const a = w / h;
      const z = Math.max(0.1, currentCam.zoom || 1.1);
      camera.left = -FR * a / z; camera.right = FR * a / z;
      camera.top  =  FR / z;     camera.bottom = -FR / z;
      camera.updateProjectionMatrix();
      renderer.setSize(w, h, false);
    }

    // ========== GLOBAL LIGHTING & 24-HOUR DYNAMIC TIME-OF-DAY ==========
    scene.background = new THREE.Color(0xf8fafc);
    const ambientL = new THREE.AmbientLight(0xffffff, 0.38);
    scene.add(ambientL);

    const hemiL = new THREE.HemisphereLight(0xf0f9ff, 0x334155, 0.32);
    scene.add(hemiL);

    const sun = new THREE.DirectionalLight(0xfffaed, 2.25);
    sun.position.set(18, 28, 14);
    sun.castShadow = true;
    sun.shadow.mapSize.set(1536, 1536);
    sun.shadow.radius = 2.0;
    sun.shadow.bias = -0.0004;
    const sc = sun.shadow.camera;
    sc.left = -24; sc.right = 24; sc.top = 24; sc.bottom = -24; sc.near = 1; sc.far = 90;
    scene.add(sun);

    const softFill = new THREE.DirectionalLight(0x93c5fd, 0.40);
    softFill.position.set(-18, 14, -16);
    scene.add(softFill);

    let cityTimeMode = "realtime"; // "realtime" | "day" | "sunset" | "dusk" | "night" | number (0..24)
    window.setCityTime = function(mode) { cityTimeMode = mode; };

    const streetLamps = [];

    // ════════════════════════════════════════════════════════════════
    // 🌅 24-HOUR TIME-OF-DAY & ATMOSPHERE KEYFRAME INTERPOLATOR
    // ════════════════════════════════════════════════════════════════
    function getTimeKeyframe(h) {
      if (h < 5.0 || h >= 21.0) {
        // Deep Midnight (Clean Canvas Background, Silvery Moonlight, Warm Golden Windows & Lanterns)
        return {
          bg: new THREE.Color(0xf8fafc),
          ambientCol: new THREE.Color(0x334155),
          ambientInt: 0.35,
          hemiSky: new THREE.Color(0x475569),
          hemiGround: new THREE.Color(0x1e293b),
          hemiInt: 0.26,
          sunCol: new THREE.Color(0x93c5fd),
          sunInt: 1.10,
          sunPos: new THREE.Vector3(-14, 26, -14),
          winGlowInt: 3.8,
          lampInt: 1.8,
          isNight: true
        };
      } else if (h < 6.5) {
        // Pre-Dawn / Blue Hour (5.0 -> 6.5)
        const t = (h - 5.0) / 1.5;
        return {
          bg: new THREE.Color(0xf8fafc),
          ambientCol: new THREE.Color(0x334155).lerp(new THREE.Color(0x4338ca), t),
          ambientInt: 0.35 + t * 0.05,
          hemiSky: new THREE.Color(0x475569).lerp(new THREE.Color(0x6366f1), t),
          hemiGround: new THREE.Color(0x1e293b).lerp(new THREE.Color(0x0f172a), t),
          hemiInt: 0.26 + t * 0.06,
          sunCol: new THREE.Color(0x93c5fd).lerp(new THREE.Color(0xfb923c), t),
          sunInt: 1.10 + t * 0.3,
          sunPos: new THREE.Vector3(-14 + t * 24, 26 - t * 14, -14 + t * 26),
          winGlowInt: 3.8 - t * 1.5,
          lampInt: 1.8 - t * 0.8,
          isNight: true
        };
      } else if (h < 8.5) {
        // Golden Sunrise (6.5 -> 8.5)
        const t = (h - 6.5) / 2.0;
        return {
          bg: new THREE.Color(0xf8fafc),
          ambientCol: new THREE.Color(0xffedd5),
          ambientInt: 0.40,
          hemiSky: new THREE.Color(0xfde047),
          hemiGround: new THREE.Color(0xfce7f3),
          hemiInt: 0.30,
          sunCol: new THREE.Color(0xf97316).lerp(new THREE.Color(0xfffaed), t),
          sunInt: 1.3 + t * 1.0,
          sunPos: new THREE.Vector3(10 + t * 8, 12 + t * 16, 12 + t * 2),
          winGlowInt: 2.3 - t * 1.6,
          lampInt: 1.0 - t * 1.0,
          isNight: false
        };
      } else if (h < 16.5) {
        // High Noon / Bright Daylight (8.5 -> 16.5) — High Contrast & Deep Physical Shadows
        return {
          bg: new THREE.Color(0xf8fafc),
          ambientCol: new THREE.Color(0xffffff),
          ambientInt: 0.38,
          hemiSky: new THREE.Color(0xf0f9ff),
          hemiGround: new THREE.Color(0xcbd5e1),
          hemiInt: 0.28,
          sunCol: new THREE.Color(0xfffbe8),
          sunInt: 2.35,
          sunPos: new THREE.Vector3(18, 28, 14),
          winGlowInt: 0.4,
          lampInt: 0,
          isNight: false
        };
      } else if (h < 18.5) {
        // Late Afternoon Warmth (16.5 -> 18.5)
        const t = (h - 16.5) / 2.0;
        return {
          bg: new THREE.Color(0xf8fafc),
          ambientCol: new THREE.Color(0xffffff).lerp(new THREE.Color(0xfde047), t),
          ambientInt: 0.38,
          hemiSky: new THREE.Color(0xf0f9ff).lerp(new THREE.Color(0xfb923c), t),
          hemiGround: new THREE.Color(0xcbd5e1).lerp(new THREE.Color(0xfda4af), t),
          hemiInt: 0.28 + t * 0.05,
          sunCol: new THREE.Color(0xfffbe8).lerp(new THREE.Color(0xf97316), t),
          sunInt: 2.35,
          sunPos: new THREE.Vector3(18 - t * 28, 28 - t * 14, 14 + t * 2),
          winGlowInt: 0.4 + t * 1.2,
          lampInt: t * 0.5,
          isNight: false
        };
      } else if (h < 19.8) {
        // Magic Sunset & Coral Sky (18.5 -> 19.8)
        const t = (h - 18.5) / 1.3;
        return {
          bg: new THREE.Color(0xf8fafc),
          ambientCol: new THREE.Color(0xfde047).lerp(new THREE.Color(0xec4899), t),
          ambientInt: 0.38 - t * 0.08,
          hemiSky: new THREE.Color(0xf97316).lerp(new THREE.Color(0xa855f7), t),
          hemiGround: new THREE.Color(0xfda4af).lerp(new THREE.Color(0x312e81), t),
          hemiInt: 0.32 - t * 0.08,
          sunCol: new THREE.Color(0xf97316).lerp(new THREE.Color(0xe11d48), t),
          sunInt: 2.35 - t * 0.6,
          sunPos: new THREE.Vector3(-10 - t * 12, 14 - t * 8, 16 - t * 4),
          winGlowInt: 1.6 + t * 1.5,
          lampInt: 0.5 + t * 0.9,
          isNight: true
        };
      } else {
        // Dusk / Twilight (19.8 -> 21.0)
        const t = (h - 19.8) / 1.2;
        return {
          bg: new THREE.Color(0xf8fafc),
          ambientCol: new THREE.Color(0xec4899).lerp(new THREE.Color(0x334155), t),
          ambientInt: 0.32,
          hemiSky: new THREE.Color(0xa855f7).lerp(new THREE.Color(0x475569), t),
          hemiGround: new THREE.Color(0x312e81).lerp(new THREE.Color(0x1e293b), t),
          hemiInt: 0.26,
          sunCol: new THREE.Color(0xe11d48).lerp(new THREE.Color(0x93c5fd), t),
          sunInt: 1.6 - t * 0.5,
          sunPos: new THREE.Vector3(-22 + t * 8, 6 + t * 20, 12 - t * 26),
          winGlowInt: 3.1 + t * 0.7,
          lampInt: 1.4 + t * 0.2,
          isNight: true
        };
      }
    }

    // ========== HELPERS ==========
    const root = new THREE.Group(); scene.add(root);
    const raycaster = new THREE.Raycaster();
    const mouse = new THREE.Vector2();
    const interactiveBuildings = [];
    const animObjects = [];
    const walkingCitizens = [];
    const seatedCitizens = [];
    const buildingRoots = {};
    const enrichmentObjects = {};

    function cv(w, h) { const c = document.createElement("canvas"); c.width = w; c.height = h; return c; }
    function tex(c, rx, ry) {
      const t = new THREE.CanvasTexture(c); t.anisotropy = 8;
      if (rx) { t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(rx, ry); }
      return t;
    }
    function mat(c, rough, metal, emis, ei, bump, bs) {
      const o = { color: c, roughness: rough === undefined ? 0.70 : rough, metalness: metal || 0 };
      if (emis !== undefined) { o.emissive = emis; o.emissiveIntensity = ei === undefined ? 1 : ei; }
      if (bump) { o.bumpMap = bump; o.bumpScale = bs || 0.05; }
      return new THREE.MeshStandardMaterial(o);
    }
    function mesh(g, m, x, y, z, cast, rec) {
      const o = new THREE.Mesh(g, m); o.position.set(x || 0, y || 0, z || 0);
      o.castShadow = cast !== false; o.receiveShadow = rec !== false; return o;
    }
    function addLight(type, color, intensity, distance, x, y, z, parent) {
      const L = type === "spot" ? new THREE.SpotLight(color, intensity, distance, 0.55, 0.4) : new THREE.PointLight(color, intensity, distance);
      L.position.set(x, y, z); (parent || scene).add(L); return L;
    }

    // ════════════════════════════════════════════════════════════════
    // 🎨 HIGH-DETAIL PROCEDURAL TEXTURE & BUMP MAP ENGINE (Tactile & Deep)
    // ════════════════════════════════════════════════════════════════
    // ════════════════════════════════════════════════════════════════
    // 🎨 HIGH-CONTRAST PROCEDURAL TEXTURE & TACTILE BUMP ENGINE
    // ════════════════════════════════════════════════════════════════

    // 🍽️ FOOD DISTRICT: Mediterranean Terracotta & Tuscan Paver Stones
    function foodPlazaTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#381504"; g.fillRect(0, 0, 512, 512); // Deep dark grout
      const tileSize = 64;
      const palette = ["#ea580c", "#c2410c", "#d97706", "#b45309", "#f59e0b", "#9a3412"];
      for (let y = 0; y < 512; y += tileSize) {
        const row = Math.floor(y / tileSize);
        const off = (row % 2) * (tileSize / 2);
        for (let x = -tileSize + off; x < 512 + tileSize; x += tileSize) {
          const col = palette[Math.abs(Math.floor(x * 7 + y * 13)) % palette.length];
          g.fillStyle = col;
          g.fillRect(x + 4, y + 4, tileSize - 8, tileSize - 8);
          // Highlight edge (top-left)
          g.fillStyle = "rgba(255,255,255,0.40)";
          g.fillRect(x + 4, y + 4, tileSize - 8, 5);
          g.fillRect(x + 4, y + 4, 5, tileSize - 8);
          // Shadow edge (bottom-right)
          g.fillStyle = "rgba(0,0,0,0.45)";
          g.fillRect(x + 4, y + tileSize - 9, tileSize - 8, 5);
          g.fillRect(x + tileSize - 9, y + 4, 5, tileSize - 8);
        }
      }
      return tex(c, 2, 2);
    }

    function foodPlazaBump() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#000000"; g.fillRect(0, 0, 512, 512);
      const tileSize = 64;
      for (let y = 0; y < 512; y += tileSize) {
        const row = Math.floor(y / tileSize);
        const off = (row % 2) * (tileSize / 2);
        for (let x = -tileSize + off; x < 512 + tileSize; x += tileSize) {
          g.fillStyle = "#999999"; g.fillRect(x + 4, y + 4, tileSize - 8, tileSize - 8);
          g.fillStyle = "#ffffff"; g.fillRect(x + 7, y + 7, tileSize - 14, 5); g.fillRect(x + 7, y + 7, 5, tileSize - 14);
          g.fillStyle = "#222222"; g.fillRect(x + 7, y + tileSize - 12, tileSize - 14, 5); g.fillRect(x + tileSize - 12, y + 7, 5, tileSize - 14);
        }
      }
      return tex(c, 2, 2);
    }

    // 🛍️ SHOPPING DISTRICT: French Pedestrian Promenade (Checkered Marble & Charcoal Slate)
    function shopPlazaTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#0f172a"; g.fillRect(0, 0, 512, 512); // Obsidian grout
      const tileSize = 64;
      for (let y = 0; y < 512; y += tileSize) {
        const row = Math.floor(y / tileSize);
        for (let x = 0; x < 512; x += tileSize) {
          const colIdx = Math.floor(x / tileSize);
          const isWhite = (row + colIdx) % 2 === 0;
          g.fillStyle = isWhite ? "#f8fafc" : "#1e293b";
          g.fillRect(x + 3, y + 3, tileSize - 6, tileSize - 6);
          // Inlaid Brass accent dots on intersection corners
          g.fillStyle = "#f59e0b";
          g.fillRect(x, y, 4, 4);
          // Bevel highlights
          g.fillStyle = isWhite ? "rgba(255,255,255,0.70)" : "rgba(255,255,255,0.22)";
          g.fillRect(x + 3, y + 3, tileSize - 6, 4);
          g.fillRect(x + 3, y + 3, 4, tileSize - 6);
          g.fillStyle = "rgba(0,0,0,0.35)";
          g.fillRect(x + 3, y + tileSize - 7, tileSize - 6, 4);
          g.fillRect(x + tileSize - 7, y + 3, 4, tileSize - 6);
        }
      }
      return tex(c, 2, 2);
    }

    function shopPlazaBump() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#000000"; g.fillRect(0, 0, 512, 512);
      const tileSize = 64;
      for (let y = 0; y < 512; y += tileSize) {
        for (let x = 0; x < 512; x += tileSize) {
          g.fillStyle = "#aaaaaa"; g.fillRect(x + 3, y + 3, tileSize - 6, tileSize - 6);
          g.fillStyle = "#ffffff"; g.fillRect(x + 5, y + 5, tileSize - 10, 4); g.fillRect(x + 5, y + 5, 4, tileSize - 10);
        }
      }
      return tex(c, 2, 2);
    }

    // 🏠 RESIDENCE DISTRICT: English Red Brick Herringbone Courtyard
    function housePlazaTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#451a03"; g.fillRect(0, 0, 512, 512); // Mortar
      const bH = 32, bW = 64;
      const palette = ["#b91c1c", "#c2410c", "#991b1b", "#7f1d1d", "#dc2626"];
      for (let y = 0; y < 512; y += bH) {
        const row = Math.floor(y / bH);
        const off = (row % 2) * (bW / 2);
        for (let x = -bW + off; x < 512 + bW; x += bW) {
          const col = palette[Math.abs(Math.floor(x * 5 + y * 11)) % palette.length];
          g.fillStyle = col;
          g.fillRect(x + 3, y + 3, bW - 6, bH - 6);
          g.fillStyle = "rgba(255,255,255,0.30)";
          g.fillRect(x + 3, y + 3, bW - 6, 3); g.fillRect(x + 3, y + 3, 3, bH - 6);
          g.fillStyle = "rgba(0,0,0,0.38)";
          g.fillRect(x + 3, y + bH - 6, bW - 6, 3); g.fillRect(x + bW - 6, y + 3, 3, bH - 6);
        }
      }
      return tex(c, 2, 2);
    }

    function housePlazaBump() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#000000"; g.fillRect(0, 0, 512, 512);
      const bH = 32, bW = 64;
      for (let y = 0; y < 512; y += bH) {
        const row = Math.floor(y / bH);
        const off = (row % 2) * (bW / 2);
        for (let x = -bW + off; x < 512 + bW; x += bW) {
          g.fillStyle = "#999999"; g.fillRect(x + 3, y + 3, bW - 6, bH - 6);
          g.fillStyle = "#ffffff"; g.fillRect(x + 5, y + 5, bW - 10, 3); g.fillRect(x + 5, y + 5, 3, bH - 10);
        }
      }
      return tex(c, 2, 2);
    }

    // 🌱 PARK SANCTUARY: Vibrant Manicured Lawn with Flagstone Stepping Stones
    function parkGrassTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#15803d"; g.fillRect(0, 0, 512, 512);
      // Alternating light/dark lawn stripes
      for (let x = 0; x < 512; x += 64) {
        if ((Math.floor(x / 64) % 2) === 0) {
          g.fillStyle = "#16a34a";
          g.fillRect(x, 0, 64, 512);
        }
      }
      // Flagstone garden path across park
      for (let y = 30; y < 490; y += 70) {
        const px = 256 + Math.sin(y * 0.02) * 50;
        g.fillStyle = "#334155";
        g.fillRect(px - 26, y - 2, 52, 44);
        g.fillStyle = "#cbd5e1";
        g.fillRect(px - 24, y, 48, 40);
        g.fillStyle = "#f8fafc";
        g.fillRect(px - 22, y + 2, 44, 5);
      }
      // Flower blossoms (tulip & daisy tufts)
      const fCols = ["#f43f5e", "#facc15", "#ec4899", "#ffffff", "#38bdf8"];
      for (let i = 0; i < 60; i++) {
        const fx = 30 + (i * 73) % 450, fy = 30 + (i * 127) % 450;
        g.fillStyle = fCols[i % fCols.length];
        g.beginPath(); g.arc(fx, fy, 4, 0, Math.PI * 2); g.fill();
      }
      return tex(c, 1, 1);
    }

    function parkGrassBump() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#666666"; g.fillRect(0, 0, 512, 512);
      for (let y = 30; y < 490; y += 70) {
        const px = 256 + Math.sin(y * 0.02) * 50;
        g.fillStyle = "#ffffff";
        g.fillRect(px - 24, y, 48, 40);
      }
      return tex(c, 1, 1);
    }

    // 🛣️ CITY ASPHALT ROADS: High-Contrast Charcoal Slate with Crisp Markings
    function asphaltTexH() {
      const c = cv(1024, 256), g = c.getContext("2d");
      g.fillStyle = "#1e293b"; g.fillRect(0, 0, 1024, 256); // Rich slate asphalt
      // Aggregate stone texture
      for (let i = 0; i < 1500; i++) {
        g.fillStyle = Math.random() > 0.5 ? "#334155" : "#0f172a";
        g.fillRect(Math.random() * 1024, Math.random() * 256, 3, 3);
      }
      // Solid white road shoulder boundary lines
      g.fillStyle = "#ffffff";
      g.fillRect(0, 18, 1024, 6);
      g.fillRect(0, 232, 1024, 6);
      // Dashed centerline
      for (let x = 0; x < 1024; x += 64) {
        g.fillRect(x, 125, 36, 6);
      }
      // Green painted bicycle lane box
      g.fillStyle = "#059669";
      g.fillRect(100, 28, 90, 50);
      g.fillRect(600, 28, 90, 50);
      g.fillStyle = "#ffffff";
      g.fillRect(120, 48, 50, 6);
      g.fillRect(620, 48, 50, 6);
      return tex(c, 2, 1);
    }

    function asphaltTexV() {
      const c = cv(256, 1024), g = c.getContext("2d");
      g.fillStyle = "#1e293b"; g.fillRect(0, 0, 256, 1024);
      for (let i = 0; i < 1500; i++) {
        g.fillStyle = Math.random() > 0.5 ? "#334155" : "#0f172a";
        g.fillRect(Math.random() * 256, Math.random() * 1024, 3, 3);
      }
      g.fillStyle = "#ffffff";
      g.fillRect(18, 0, 6, 1024);
      g.fillRect(232, 0, 6, 1024);
      for (let y = 0; y < 1024; y += 64) {
        g.fillRect(125, y, 6, 36);
      }
      return tex(c, 1, 2);
    }

    function asphaltBumpTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#555555"; g.fillRect(0, 0, 512, 512);
      for (let i = 0; i < 2000; i++) {
        g.fillStyle = Math.random() > 0.5 ? "#ffffff" : "#000000";
        g.fillRect(Math.random() * 512, Math.random() * 512, 2, 2);
      }
      return tex(c, 4, 4);
    }

    function brickBumpTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#111111"; g.fillRect(0, 0, 512, 512);
      const bH = 32, bW = 64;
      for (let y = 0; y < 512; y += bH) {
        const off = (Math.floor(y / bH) % 2) * (bW / 2);
        for (let x = -bW + off; x < 512 + bW; x += bW) {
          g.fillStyle = "#aaaaaa"; g.fillRect(x + 2, y + 2, bW - 4, bH - 4);
          g.fillStyle = "#ffffff"; g.fillRect(x + 4, y + 4, bW - 8, 3); g.fillRect(x + 4, y + 4, 3, bH - 8);
        }
      }
      return tex(c, 2, 2);
    }

    function plankBumpTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#222222"; g.fillRect(0, 0, 512, 512);
      for (let y = 0; y < 512; y += 32) {
        g.fillStyle = "#aaaaaa"; g.fillRect(0, y + 2, 512, 28);
        g.fillStyle = "#ffffff"; g.fillRect(0, y + 3, 512, 3);
      }
      return tex(c, 1, 3);
    }

    function stoneTex(baseCol) {
      const c = cv(256, 256), g = c.getContext("2d");
      g.fillStyle = baseCol || "#f8fafc"; g.fillRect(0, 0, 256, 256);
      g.fillStyle = "rgba(0,0,0,0.06)";
      for (let i = 0; i < 500; i++) g.fillRect(Math.random() * 256, Math.random() * 256, 2, 2);
      return tex(c, 2, 2);
    }

    function plankTex(col) {
      const c = cv(256, 256), g = c.getContext("2d");
      g.fillStyle = col || "#78350f"; g.fillRect(0, 0, 256, 256);
      g.fillStyle = "rgba(0,0,0,0.15)";
      for (let y = 0; y < 256; y += 32) g.fillRect(0, y, 256, 3);
      return tex(c, 1, 2);
    }

    // 🧱 BUILDING FACADE TEXTURES
    function bistroBrickTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#18181b"; g.fillRect(0, 0, 512, 512);
      const bH = 32, bW = 64;
      const reds = ["#991b1b", "#b91c1c", "#7f1d1d", "#a82020", "#dc2626"];
      for (let y = 0; y < 512; y += bH) {
        const off = (Math.floor(y / bH) % 2) * (bW / 2);
        for (let x = -bW + off; x < 512 + bW; x += bW) {
          g.fillStyle = reds[Math.abs(Math.floor(x + y)) % reds.length];
          g.fillRect(x + 2, y + 2, bW - 4, bH - 4);
          g.fillStyle = "rgba(255,255,255,0.30)";
          g.fillRect(x + 2, y + 2, bW - 4, 3);
          g.fillStyle = "rgba(0,0,0,0.40)";
          g.fillRect(x + 2, y + bH - 5, bW - 4, 3);
        }
      }
      // Cream stone corner quoins
      g.fillStyle = "#fef08a";
      for (let y = 0; y < 512; y += bH * 2) {
        g.fillRect(0, y, (Math.floor(y / (bH*2)) % 2 === 0 ? 36 : 20), bH * 2 - 4);
        g.fillRect(512 - (Math.floor(y / (bH*2)) % 2 === 0 ? 36 : 20), y, 36, bH * 2 - 4);
      }
      return tex(c, 2, 2);
    }

    function superWoodTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#14532d"; g.fillRect(0, 0, 512, 512); // Forest green base
      const sH = 32;
      for (let y = 0; y < 512; y += sH) {
        g.fillStyle = (Math.floor(y / sH) % 2 === 0) ? "#16a34a" : "#15803d";
        g.fillRect(0, y + 2, 512, sH - 4);
        g.fillStyle = "rgba(255,255,255,0.35)";
        g.fillRect(0, y + 2, 512, 4);
        g.fillStyle = "rgba(0,0,0,0.40)";
        g.fillRect(0, y + sH - 4, 512, 4);
      }
      return tex(c, 1, 3);
    }

    function coffeeWoodTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#1c0d02"; g.fillRect(0, 0, 512, 512);
      const sW = 24;
      for (let x = 0; x < 512; x += sW) {
        g.fillStyle = (Math.floor(x / sW) % 2 === 0) ? "#78350f" : "#92400e";
        g.fillRect(x + 2, 0, sW - 4, 512);
        g.fillStyle = "rgba(255,255,255,0.25)";
        g.fillRect(x + 2, 0, 3, 512);
        g.fillStyle = "rgba(0,0,0,0.45)";
        g.fillRect(x + sW - 4, 0, 3, 512);
      }
      return tex(c, 3, 1);
    }

    function woltSteelTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#0891b2"; g.fillRect(0, 0, 512, 512);
      // Corrugated container vertical ribs
      for (let x = 0; x < 512; x += 32) {
        g.fillStyle = "#06b6d4"; g.fillRect(x, 0, 16, 512);
        g.fillStyle = "#0e7490"; g.fillRect(x + 16, 0, 16, 512);
        g.fillStyle = "rgba(255,255,255,0.40)"; g.fillRect(x, 0, 4, 512);
        g.fillStyle = "rgba(0,0,0,0.40)"; g.fillRect(x + 28, 0, 4, 512);
      }
      // Yellow hazard warning stripe banner across top
      g.fillStyle = "#facc15"; g.fillRect(0, 0, 512, 40);
      g.fillStyle = "#18181b";
      for (let x = -40; x < 550; x += 40) {
        g.beginPath();
        g.moveTo(x, 40); g.lineTo(x + 20, 40); g.lineTo(x + 40, 0); g.lineTo(x + 20, 0);
        g.closePath(); g.fill();
      }
      return tex(c, 2, 2);
    }

    function boutiqueStuccoTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#fce7f3"; g.fillRect(0, 0, 512, 512); // Chic blush pink
      const sW = 20;
      for (let x = 0; x < 512; x += sW) {
        g.fillStyle = (Math.floor(x / sW) % 2 === 0) ? "#f472b6" : "#fb7185";
        g.fillRect(x + 1, 0, sW - 2, 512);
        g.fillStyle = "rgba(255,255,255,0.45)"; g.fillRect(x + 1, 0, 3, 512);
        g.fillStyle = "rgba(0,0,0,0.20)"; g.fillRect(x + sW - 3, 0, 2, 512);
      }
      return tex(c, 2, 2);
    }

    function techGridTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#0a0f1d"; g.fillRect(0, 0, 512, 512);
      // Cyan tech grid & circuit traces
      g.strokeStyle = "#0284c7"; g.lineWidth = 4;
      for (let y = 0; y < 512; y += 64) {
        g.beginPath(); g.moveTo(0, y); g.lineTo(512, y); g.stroke();
      }
      for (let x = 0; x < 512; x += 64) {
        g.beginPath(); g.moveTo(x, 0); g.lineTo(x, 512); g.stroke();
      }
      g.fillStyle = "#38bdf8";
      for (let y = 0; y < 512; y += 64) {
        for (let x = 0; x < 512; x += 64) {
          g.fillRect(x - 4, y - 4, 8, 8);
        }
      }
      return tex(c, 2, 2);
    }

    function travelMosaicTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#1e293b"; g.fillRect(0, 0, 512, 512);
      const s = 48;
      const blues = ["#2563eb", "#3b82f6", "#1d4ed8", "#60a5fa", "#0284c7"];
      for (let y = 0; y < 512; y += s) {
        for (let x = 0; x < 512; x += s) {
          g.fillStyle = blues[(Math.floor(x/s) * 3 + Math.floor(y/s) * 7) % blues.length];
          g.fillRect(x + 2, y + 2, s - 4, s - 4);
          g.fillStyle = "rgba(255,255,255,0.40)"; g.fillRect(x + 2, y + 2, s - 4, 3);
        }
      }
      return tex(c, 2, 2);
    }

    function arcadeNeonTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#180d2b"; g.fillRect(0, 0, 512, 512);
      const bH = 32, bW = 64;
      const purples = ["#4c1d95", "#581c87", "#3b0764", "#6b21a8"];
      for (let y = 0; y < 512; y += bH) {
        const off = (Math.floor(y / bH) % 2) * (bW / 2);
        for (let x = -bW + off; x < 512 + bW; x += bW) {
          g.fillStyle = purples[Math.abs(Math.floor(x + y)) % purples.length];
          g.fillRect(x + 2, y + 2, bW - 4, bH - 4);
        }
      }
      // Glowing neon accent grid
      g.strokeStyle = "#ee7cc4"; g.lineWidth = 3;
      g.beginPath(); g.moveTo(0, 256); g.lineTo(512, 256); g.stroke();
      return tex(c, 2, 2);
    }

    function residenceStoneTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#334155"; g.fillRect(0, 0, 512, 512);
      const bH = 48, bW = 96;
      const stones = ["#f8fafc", "#f1f5f9", "#e2e8f0", "#cbd5e1", "#e0e7ff"];
      for (let y = 0; y < 512; y += bH) {
        const off = (Math.floor(y / bH) % 2) * (bW / 2);
        for (let x = -bW + off; x < 512 + bW; x += bW) {
          g.fillStyle = stones[Math.abs(Math.floor(x * 3 + y * 7)) % stones.length];
          g.fillRect(x + 3, y + 3, bW - 6, bH - 6);
          g.fillStyle = "rgba(255,255,255,0.65)"; g.fillRect(x + 3, y + 3, bW - 6, 4); g.fillRect(x + 3, y + 3, 4, bH - 6);
          g.fillStyle = "rgba(0,0,0,0.30)"; g.fillRect(x + 3, y + bH - 7, bW - 6, 4); g.fillRect(x + bW - 7, y + 3, 4, bH - 6);
        }
      }
      return tex(c, 2, 2);
    }

    function utilHazardTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#475569"; g.fillRect(0, 0, 512, 512); // Concrete panels
      g.strokeStyle = "#1e293b"; g.lineWidth = 6;
      g.strokeRect(0, 0, 512, 512);
      g.strokeRect(0, 256, 512, 256);
      // Metal diamond plate stamping
      g.fillStyle = "#64748b";
      for (let y = 20; y < 500; y += 32) {
        for (let x = 20; x < 500; x += 32) {
          g.fillRect(x, y, 10, 4);
          g.fillRect(x + 16, y + 16, 4, 10);
        }
      }
      // Yellow hazard caution band
      g.fillStyle = "#eab308"; g.fillRect(0, 220, 512, 40);
      g.fillStyle = "#0f172a";
      for (let x = -40; x < 550; x += 40) {
        g.beginPath();
        g.moveTo(x, 260); g.lineTo(x + 20, 260); g.lineTo(x + 40, 220); g.lineTo(x + 20, 220);
        g.closePath(); g.fill();
      }
      return tex(c, 2, 2);
    }

    function subsIndigoTex() {
      const c = cv(512, 512), g = c.getContext("2d");
      g.fillStyle = "#1e1b4b"; g.fillRect(0, 0, 512, 512);
      // High-tech server rack grilles & status LEDs
      for (let y = 16; y < 500; y += 48) {
        g.fillStyle = "#312e81"; g.fillRect(16, y, 480, 36);
        g.fillStyle = "#4338ca"; g.fillRect(20, y + 4, 472, 4);
        // Blinking status LEDs
        g.fillStyle = "#10b981"; g.fillRect(36, y + 14, 8, 8);
        g.fillStyle = "#38bdf8"; g.fillRect(52, y + 14, 8, 8);
        g.fillStyle = "#a855f7"; g.fillRect(68, y + 14, 8, 8);
      }
      return tex(c, 2, 2);
    }

    function stripeTex(c1, c2, n) {
      const c = cv(128, 128), g = c.getContext("2d");
      g.fillStyle = c1; g.fillRect(0, 0, 128, 128);
      g.fillStyle = c2;
      const step = 128 / (n || 8);
      for (let i = 0; i < 128; i += step * 2) g.fillRect(i, 0, step, 128);
      return tex(c, 2, 1);
    }

    function solarTex() {
      const c = cv(128, 128), g = c.getContext("2d");
      g.fillStyle = "#1e3a8a"; g.fillRect(0, 0, 128, 128);
      g.strokeStyle = "#60a5fa"; g.lineWidth = 2;
      for (let i = 0; i <= 128; i += 32) { g.beginPath(); g.moveTo(i, 0); g.lineTo(i, 128); g.stroke(); }
      for (let j = 0; j <= 128; j += 32) { g.beginPath(); g.moveTo(0, j); g.lineTo(128, j); g.stroke(); }
      return tex(c, 2, 2);
    }

    function signTex(txt, sub, fg, bg) {
      const c = cv(512, 180), g = c.getContext("2d");
      g.fillStyle = bg; g.fillRect(0, 0, 512, 180);
      g.strokeStyle = "rgba(255,255,255,0.30)"; g.lineWidth = 6; g.strokeRect(6, 6, 500, 168);
      g.fillStyle = fg; g.font = "900 50px -apple-system,BlinkMacSystemFont,sans-serif";
      g.textAlign = "center"; g.textBaseline = "middle";
      g.fillText(txt, 256, sub ? 62 : 90);
      if (sub) {
        g.font = "bold 30px -apple-system,BlinkMacSystemFont,sans-serif";
        g.fillStyle = "rgba(255,255,255,0.92)";
        g.fillText(sub, 256, 128);
      }
      return tex(c);
    }

    function menuTex() {
      const c = cv(128, 256), g = c.getContext("2d");
      g.fillStyle = "#1e1b18"; g.fillRect(0, 0, 128, 256);
      g.fillStyle = "#fef08a"; g.font = "900 26px -apple-system,sans-serif";
      g.textAlign = "center"; g.fillText("MENU", 64, 38);
      g.fillStyle = "rgba(255,255,255,0.65)";
      for (let y = 70; y < 230; y += 20) g.fillRect(14, y, 100, 5);
      return tex(c);
    }

    function woltTex() {
      const c = cv(256, 256), g = c.getContext("2d");
      g.fillStyle = "#00c2e8"; g.fillRect(0, 0, 256, 256);
      g.fillStyle = "#fff"; g.font = "900 70px -apple-system,sans-serif";
      g.textAlign = "center"; g.textBaseline = "middle"; g.fillText("Wolt", 128, 128);
      return tex(c);
    }

    function winGlowTex() {
      const c = cv(128, 128), g = c.getContext("2d");
      g.fillStyle = "#fef08a"; g.fillRect(0, 0, 128, 128);
      g.fillStyle = "#1e293b";
      g.fillRect(0,0,128,10); g.fillRect(0,118,128,10);
      g.fillRect(0,0,10,128); g.fillRect(118,0,10,128);
      g.fillRect(59,0,10,128); g.fillRect(0,59,128,10);
      return tex(c);
    }

    function arcadeTex(frame) {
      const c = cv(128, 128), g = c.getContext("2d");
      g.fillStyle = "#05051a"; g.fillRect(0, 0, 128, 128);
      const cols = ["#ec4899","#06b6d4","#a855f7"];
      g.fillStyle = cols[frame % 3]; g.fillRect(20, 20, 88, 14);
      g.fillStyle = cols[(frame + 1) % 3]; g.fillRect(40, 46, 48, 10);
      g.fillStyle = "#eab308";
      for (let i = 24; i <= 100; i += 18) g.fillRect(i, 82, 8, 8);
      return c;
    }
    const winGlowM = new THREE.MeshStandardMaterial({ map: winGlowTex(), emissive: 0xfbbf24, emissiveIntensity: 3.5, roughness: 0.25 });

    // ────────────────────────────────────────────────────────────────
    // 🚧  CONSTRUCTION PLOT / SITE SIGNPOST GENERATOR
    // ────────────────────────────────────────────────────────────────
    const plotSites = {};

    function plotSignTex(title, subtitle) {
      const c = cv(512, 256), g = c.getContext("2d");
      // Clean white card background
      g.fillStyle = "#ffffff";
      g.fillRect(0, 0, 512, 256);
      
      // Soft modern top accent header in light slate
      g.fillStyle = "#f8fafc";
      g.fillRect(0, 0, 512, 70);

      // Subtle rounded border outline
      g.strokeStyle = "#e2e8f0";
      g.lineWidth = 8;
      g.strokeRect(4, 4, 504, 248);
      
      // Header tag
      g.fillStyle = "#94a3b8";
      g.font = "bold 24px -apple-system, BlinkMacSystemFont, sans-serif";
      g.textAlign = "center";
      g.fillText("🏗️ מגרש פנוי לבנייה", 256, 45);
      
      // Main title
      g.fillStyle = "#0f172a";
      g.font = "bold 40px -apple-system, BlinkMacSystemFont, sans-serif";
      g.fillText(title, 256, 140);
      
      // Subtitle
      g.fillStyle = "#64748b";
      g.font = "600 24px -apple-system, BlinkMacSystemFont, sans-serif";
      g.fillText(subtitle || "הוסף הוצאה כדי להקים מבנה", 256, 198);
      
      return tex(c);
    }

    function createPlotSite(id, title, subtitle, posX, posZ, parent, bData) {
      const g = new THREE.Group();
      g.position.set(posX, 0.22, posZ);
      parent.add(g);
      
      // Flat foundation slab
      const slab = mesh(roundedBox(2.6, 0.08, 2.4, 0.12), mat(0x334155, 0.9, 0.2), 0, 0.04, 0);
      g.add(slab);
      
      // Wooden signpost stuck in the ground
      const signGroup = new THREE.Group();
      signGroup.position.set(0, 0, 0.3);
      
      const postL = mesh(new THREE.CylinderGeometry(0.04, 0.04, 1.2, 8), mat(0x78350f, 0.9), -0.7, 0.6, 0);
      const postR = mesh(new THREE.CylinderGeometry(0.04, 0.04, 1.2, 8), mat(0x78350f, 0.9), 0.7, 0.6, 0);
      signGroup.add(postL, postR);
      
      const board = mesh(new THREE.BoxGeometry(1.7, 0.85, 0.06), new THREE.MeshStandardMaterial({ map: plotSignTex(title, subtitle), roughness: 0.7 }), 0, 0.82, 0.04);
      signGroup.add(board);
      g.add(signGroup);

      // Miniature Orange Construction Cone
      const cone = new THREE.Group();
      cone.position.set(0.85, 0, 0.55);
      cone.add(mesh(new THREE.BoxGeometry(0.24, 0.03, 0.24), mat(0x1e293b, 0.9), 0, 0.015, 0));
      cone.add(mesh(new THREE.ConeGeometry(0.10, 0.38, 12), mat(0xf97316, 0.6), 0, 0.20, 0));
      cone.add(mesh(new THREE.CylinderGeometry(0.065, 0.075, 0.08, 12), mat(0xffffff, 0.4), 0, 0.20, 0));
      g.add(cone);
      
      g.visible = false;
      plotSites[id] = g;
      
      // Allow tapping the sign
      board.userData = bData;
      interactiveBuildings.push(board);
      
      return g;
    }

    // ========== ROUNDED BOX ==========
    function roundedBox(w, h, d, r) {
      r = Math.min(r, Math.min(w, d) / 2 - 0.01);
      const s = new THREE.Shape(), x = -w / 2, y = -d / 2;
      s.moveTo(x + r, y); s.lineTo(x + w - r, y); s.quadraticCurveTo(x + w, y, x + w, y + r);
      s.lineTo(x + w, y + d - r); s.quadraticCurveTo(x + w, y + d, x + w - r, y + d);
      s.lineTo(x + r, y + d); s.quadraticCurveTo(x, y + d, x, y + d - r);
      s.lineTo(x, y + r); s.quadraticCurveTo(x, y, x + r, y);
      const g = new THREE.ExtrudeGeometry(s, { depth: h, bevelEnabled: true, bevelSize: 0.05, bevelThickness: 0.05, bevelSegments: 3, curveSegments: 6 });
      g.rotateX(-Math.PI / 2); g.computeVertexNormals();
      return g;
    }

    // ========== WINDOWS HELPER (Architectural 3D Depth) ==========
    function addWindows(parent, floors, cols, w, h, d, zOff) {
      const xS = w / (cols + 1), yS = (h - 0.7) / floors;
      for (let fl = 0; fl < floors; fl++) {
        const y = 0.65 + fl * yS + yS * 0.4;
        for (let c = 0; c < cols; c++) {
          const x = -w / 2 + (c + 1) * xS;
          // Outer carved stone surround frame
          parent.add(mesh(new THREE.BoxGeometry(0.56, 0.70, 0.05), mat(0x334155, 0.8), x, y, zOff + 0.01));
          // Recessed glass/glowing window pane
          parent.add(mesh(new THREE.BoxGeometry(0.48, 0.62, 0.04), winGlowM, x, y, zOff + 0.02));
          // Window mullions (cross bars)
          parent.add(mesh(new THREE.BoxGeometry(0.025, 0.62, 0.05), mat(0x1e293b, 0.9), x, y, zOff + 0.03));
          parent.add(mesh(new THREE.BoxGeometry(0.48, 0.025, 0.05), mat(0x1e293b, 0.9), x, y, zOff + 0.03));
          // Protruding stone window sill
          parent.add(mesh(new THREE.BoxGeometry(0.62, 0.065, 0.12), mat(0x94a3b8, 0.7), x, y - 0.35, zOff + 0.05));
          // Top lintel arch / crown
          parent.add(mesh(new THREE.BoxGeometry(0.60, 0.055, 0.08), mat(0x94a3b8, 0.7), x, y + 0.35, zOff + 0.03));
        }
      }
    }

    // ════════════════════════════════════════════════════════════════
    // 🎪 TIER 1 AUTHENTIC STREET CARTS, STALLS & POP-UPS (< 45% SPEND)
    // ════════════════════════════════════════════════════════════════
    function createTier1Stall(type) {
      const g = new THREE.Group();
      
      if (type === "bistro") {
        // French Crepe & Croissant Mobile Food Cart
        const cart = mesh(roundedBox(1.1, 0.65, 0.70, 0.08), mat(0x78350f, 0.8), 0, 0.35, 0);
        g.add(cart);
        g.add(mesh(new THREE.BoxGeometry(1.18, 0.04, 0.78), mat(0xfacc15, 0.4, 0.8), 0, 0.70, 0));
        [-0.45, 0.45].forEach(wx => {
          const wh = mesh(new THREE.CylinderGeometry(0.24, 0.24, 0.04, 12), mat(0x1e293b, 0.7), wx, 0.24, 0.38);
          wh.rotation.x = Math.PI / 2; g.add(wh);
        });
        g.add(mesh(new THREE.CylinderGeometry(0.02, 0.02, 1.35, 8), mat(0xfacc15, 0.4, 0.8), 0.35, 1.35, 0));
        const umb = mesh(new THREE.ConeGeometry(0.70, 0.28, 8), new THREE.MeshStandardMaterial({ map: stripeTex("#e11d48", "#ffffff", 6) }), 0.35, 2.05, 0);
        g.add(umb);
        g.add(mesh(new THREE.CylinderGeometry(0.12, 0.12, 0.12, 8), new THREE.MeshStandardMaterial({ color: 0xffffff, transparent: true, opacity: 0.5 }), -0.25, 0.78, 0));
        g.add(mesh(new THREE.TorusGeometry(0.04, 0.02, 6, 8), mat(0xd97706, 0.7), -0.25, 0.74, 0));
        const easel = mesh(new THREE.BoxGeometry(0.28, 0.40, 0.03), new THREE.MeshStandardMaterial({ map: menuTex() }), -0.75, 0.25, 0.25);
        easel.rotation.y = 0.4; g.add(easel);
      } else if (type === "super") {
        // Rustic Farmer's Veggie & Fruit Stand
        const wagon = mesh(roundedBox(1.2, 0.45, 0.75, 0.08), mat(0x854d0e, 0.85), 0, 0.28, 0);
        g.add(wagon);
        const awn = mesh(new THREE.BoxGeometry(1.3, 0.04, 0.85), new THREE.MeshStandardMaterial({ map: stripeTex("#15803d", "#ffffff", 6) }), 0, 1.25, 0);
        awn.rotation.x = 0.15; g.add(awn);
        [[-0.55,-0.3],[0.55,-0.3],[-0.55,0.3],[0.55,0.3]].forEach(p => {
          g.add(mesh(new THREE.CylinderGeometry(0.02, 0.02, 1.0, 6), mat(0x78350f, 0.8), p[0], 0.75, p[1]));
        });
        [-0.35, 0, 0.35].forEach((cx, idx) => {
          const crate = mesh(new THREE.BoxGeometry(0.30, 0.12, 0.35), mat(0xa16207, 0.8), cx, 0.55, 0.05);
          crate.rotation.x = 0.3; g.add(crate);
          const col = [0xe11d48, 0xf97316, 0x22c55e][idx];
          crate.add(mesh(new THREE.SphereGeometry(0.06, 6, 6), mat(col, 0.7), 0, 0.08, 0));
        });
        g.add(mesh(new THREE.ConeGeometry(0.08, 0.06, 6), mat(0xfacc15, 0.4, 0.8), 0.5, 0.95, 0.3));
      } else if (type === "coffee") {
        // Vintage Italian Espresso Trike
        const cart = mesh(roundedBox(0.9, 0.55, 0.65, 0.06), mat(0xfef3c7, 0.7), 0, 0.32, 0);
        g.add(cart);
        g.add(mesh(new THREE.BoxGeometry(0.28, 0.26, 0.24), mat(0xd1d5db, 0.2, 0.9), -0.15, 0.72, 0));
        g.add(mesh(new THREE.CylinderGeometry(0.01, 0.01, 0.18, 6), mat(0x94a3b8, 0.2, 0.9), -0.05, 0.88, 0));
        g.add(mesh(new THREE.CylinderGeometry(0.035, 0.025, 0.14, 8), mat(0xffffff, 0.4), 0.20, 0.68, 0));
        const board = mesh(new THREE.BoxGeometry(0.24, 0.35, 0.02), new THREE.MeshStandardMaterial({ map: menuTex() }), 0.55, 0.30, 0.15);
        board.rotation.y = -0.3; g.add(board);
        const shade = mesh(new THREE.ConeGeometry(0.55, 0.22, 8), new THREE.MeshStandardMaterial({ map: stripeTex("#f4c542", "#ffffff", 6) }), 0, 1.65, 0);
        g.add(shade);
        g.add(mesh(new THREE.CylinderGeometry(0.015, 0.015, 1.1, 6), mat(0x78350f, 0.8), 0, 1.10, 0));
      } else if (type === "wolt") {
        // Single Wolt Courier Bike with backpack
        const bike = new THREE.Group(); bike.position.set(0, 0.18, 0); g.add(bike);
        bike.add(mesh(new THREE.BoxGeometry(0.85, 0.10, 0.12), mat(0x00c2e8, 0.4, 0.6), 0, 0.12, 0));
        [0.35, -0.35].forEach(wx => {
          const wh = mesh(new THREE.CylinderGeometry(0.18, 0.18, 0.04, 12), mat(0x18181b, 0.9), wx, 0, 0);
          wh.rotation.x = Math.PI / 2; bike.add(wh);
        });
        bike.add(mesh(new THREE.CylinderGeometry(0.015, 0.015, 0.45, 6), mat(0x334155, 0.7), 0.28, 0.25, 0));
        bike.add(mesh(new THREE.BoxGeometry(0.35, 0.025, 0.025), mat(0x18181b, 0.8), 0.28, 0.48, 0));
        const bag = mesh(new THREE.BoxGeometry(0.26, 0.28, 0.24), new THREE.MeshStandardMaterial({ map: woltTex(), roughness: 0.4 }), -0.15, 0.32, 0);
        bike.add(bag);
      } else if (type === "boutique") {
        // Rolling Outdoor Fashion Garment Rack
        const rack = new THREE.Group(); rack.position.set(0, 0, 0); g.add(rack);
        rack.add(mesh(new THREE.BoxGeometry(1.2, 0.03, 0.03), mat(0xd1d5db, 0.2, 0.8), 0, 0.06, 0));
        [-0.55, 0.55].forEach(px => {
          rack.add(mesh(new THREE.BoxGeometry(0.03, 0.03, 0.4), mat(0xd1d5db, 0.2, 0.8), px, 0.06, 0));
          rack.add(mesh(new THREE.CylinderGeometry(0.015, 0.015, 1.25, 8), mat(0xd1d5db, 0.2, 0.8), px, 0.68, 0));
        });
        rack.add(mesh(new THREE.BoxGeometry(1.2, 0.025, 0.025), mat(0xd1d5db, 0.2, 0.8), 0, 1.30, 0));
        const dressCols = [0xec4899, 0x38bdf8, 0xfacc15, 0xa855f7, 0x10b981];
        for (let i = 0; i < 5; i++) {
          const dx = -0.40 + i * 0.20;
          rack.add(mesh(new THREE.BoxGeometry(0.14, 0.55, 0.26), mat(dressCols[i], 0.7), dx, 0.95, 0));
        }
        const mirror = mesh(new THREE.BoxGeometry(0.03, 0.95, 0.38), mat(0x94a3b8, 0.2, 0.9), 0.75, 0.55, 0.15);
        mirror.rotation.y = -0.4; g.add(mirror);
      } else if (type === "tech") {
        // Pop-up Tech Gadget & Phone Screen Repair Table
        const table = mesh(new THREE.BoxGeometry(1.2, 0.65, 0.65), mat(0x1e293b, 0.7), 0, 0.32, 0);
        g.add(table);
        const glass = mesh(new THREE.BoxGeometry(1.1, 0.18, 0.55), new THREE.MeshStandardMaterial({ color: 0x38bdf8, transparent: true, opacity: 0.4, roughness: 0.1 }), 0, 0.74, 0);
        g.add(glass);
        [-0.35, 0, 0.35].forEach(px => {
          g.add(mesh(new THREE.BoxGeometry(0.12, 0.02, 0.22), new THREE.MeshStandardMaterial({ color: 0xffffff, emissive: 0x38bdf8, emissiveIntensity: 2.0 }), px, 0.68, 0));
        });
        g.add(mesh(new THREE.BoxGeometry(1.0, 0.25, 0.03), new THREE.MeshStandardMaterial({ map: signTex("⚡ תיקונים", "Phone Repair", "#38bdf8", "#0f0d17") }), 0, 1.25, -0.28));
      } else if (type === "travel") {
        // Vintage Luggage Trunk & Postcard Stand
        const trunk = mesh(new THREE.BoxGeometry(0.85, 0.45, 0.55), mat(0x78350f, 0.8), 0, 0.35, 0);
        trunk.add(mesh(new THREE.BoxGeometry(0.88, 0.04, 0.03), mat(0xfacc15, 0.3, 0.8), 0, 0.10, 0.28));
        g.add(trunk);
        const rack = new THREE.Group(); rack.position.set(0.65, 0, 0.1); g.add(rack);
        rack.add(mesh(new THREE.CylinderGeometry(0.015, 0.015, 1.1, 8), mat(0x94a3b8, 0.5, 0.8), 0, 0.55, 0));
        rack.add(mesh(new THREE.CylinderGeometry(0.18, 0.18, 0.45, 6), new THREE.MeshStandardMaterial({ color: 0x2563eb, emissive: 0x60a5fa, emissiveIntensity: 0.5 }), 0, 0.80, 0));
        g.add(mesh(new THREE.SphereGeometry(0.12, 10, 8), mat(0x0284c7, 0.5), -0.25, 0.70, 0));
      } else if (type === "arcade") {
        // Single Retro 80s Street Corner Arcade Machine
        const cab = mesh(new THREE.BoxGeometry(0.55, 1.15, 0.50), mat(0x1e1035, 0.7), 0, 0.58, 0);
        g.add(cab);
        cab.add(mesh(new THREE.BoxGeometry(0.42, 0.34, 0.04), new THREE.MeshStandardMaterial({ color: 0xec4899, emissive: 0xec4899, emissiveIntensity: 2.2 }), 0, 0.22, 0.25));
        g.add(mesh(new THREE.BoxGeometry(0.32, 0.30, 0.32), mat(0xf97316, 0.8), 0, 0.15, 0.55));
      } else if (type === "housing") {
        // Small 1-Room Ground-Floor Studio Cottage
        const cot = mesh(roundedBox(1.6, 1.3, 1.5, 0.10), new THREE.MeshStandardMaterial({ map: stoneTex("#f8fafc"), roughness: 0.8 }), 0, 0.65, 0);
        g.add(cot);
        const roof = mesh(new THREE.ConeGeometry(1.3, 0.55, 4), mat(0x9a3412, 0.85), 0, 1.55, 0);
        roof.rotation.y = Math.PI / 4; g.add(roof);
        cot.add(mesh(new THREE.BoxGeometry(0.35, 0.70, 0.04), mat(0x78350f, 0.8), 0, -0.28, 0.77));
        cot.add(mesh(new THREE.BoxGeometry(0.12, 0.16, 0.08), mat(0xef4444, 0.7), 0.35, -0.15, 0.78));
      } else if (type === "util") {
        // Electrical Utility Meter Junction Box
        const box = mesh(new THREE.BoxGeometry(0.65, 0.85, 0.45), mat(0x334155, 0.85), 0, 0.42, 0);
        g.add(box);
        box.add(mesh(new THREE.BoxGeometry(0.24, 0.12, 0.02), new THREE.MeshStandardMaterial({ color: 0x22c55e, emissive: 0x22c55e, emissiveIntensity: 2.0 }), 0, 0.18, 0.23));
        box.add(mesh(new THREE.SphereGeometry(0.04, 8, 8), mat(0xfacc15, 0.3, 0.9), 0, 0.32, 0.23));
      } else if (type === "subs") {
        // Sidewalk Newspaper & Magazine Dispenser Box
        const news = mesh(new THREE.BoxGeometry(0.55, 0.85, 0.45), mat(0x7c3aed, 0.7), 0, 0.42, 0);
        g.add(news);
        news.add(mesh(new THREE.BoxGeometry(0.40, 0.32, 0.04), new THREE.MeshStandardMaterial({ map: signTex("NEWS", "Press", "#ffffff", "#1e1b4b") }), 0, 0.12, 0.23));
      }

      g.visible = false;
      return g;
    }

    // ================================================================
    // 💬 MULTILINGUAL SPEECH BUBBLE & STREET SITUATIONS ENGINE
    // ================================================================
    let currentLanguage = "he";
    const activeBubbles = [];
    const interactiveCitizens = [];

    const DIORAMA_PHRASES = {
      he: {
        busStop: "תחנת אוטובוס • העלאת נוסעים",
        vacantSlot: "חלקה פנויה לבנייה",
        arrived: "הגעתי לעיר!",
        newUpgrade: "שדרוג חדש בעיר!",
        construction: [
          "עוד שתי דקות מסיימים... אחי איפה המפתחות?",
          "רק מחזק פה בורג אחד של שכירות",
          "חריגת תקציב קלה, אבל תראה איזה יופי",
          "זה תקן אירופאי, אל תשאל אותי",
          "יצא פיקס! הקפה עליך",
          "בטון מזוין נגד עליות מחירים!",
          "רק מניח פה בלוק וממשיכים"
        ],
        constructionDone: "סיימנו! תתחדש על המבנה! 🎉",
        cat: [
          "אני רואה את כל ההוצאות שלך מלמעלה...",
          "עוד משלוח אוכל? באמת?",
          "מיאו! איזה כיף על הגג החם",
          "גררר... תודה שפתחת אותי!"
        ],
        dog: [
          "הב הב! מטיילים בפארק!",
          "כלב טוב! אל תאכל את הקבלה!",
          "הב! מצאתי מקל חינם בפארק!"
        ],
        fountain: "מזרקת המשאלות • לזרוק שקל?",
        sakura: "פריחת הדובדבן מושלמת!",
        coffeeStand: "שיבולת שועל זה עוד 4 שקלים?!",
        sculpture: "פסל אמנות מודרנית • מה זה מייצג?",
        tap: [
          "בוקר טוב!", "איזה יום מקסים!", "שומר על תקציב מעולה",
          "קפה מושלם היום", "אוהב את העיר!", "שלום חבר!",
          "בדרך לקניות", "הפארק מהמם!", "החיסכון גדל!",
          "באתי רק לקנות חלב, יצאתי ב-400 שקל",
          "הכלב שלי אוכל יותר יקר ממני",
          "האבוקדו יבש, אבל עלה כמו מניית אנבידיה",
          "שוב שכחתי לבטל מנוי ל-7 ימי ניסיון",
          "קניתי ירקות רק כדי לראות אותם נרקבים"
        ],
        street: [
          "איפה דירה 4B? הוויז השתגע!",
          "באתי רק לקנות חלב, יצאתי ב-400 שקל",
          "שוב שכחתי לבטל את המנוי ל-7 ימי ניסיון",
          "האבוקדו יבש, אבל עלה כמו מניית אנבידיה",
          "מי הזמין מים מינרליים ב-38 שקל?!",
          "אחי, רק שתי דקות על כחול-לבן!",
          "דמי משלוח 18 שקל? אני אבשל לבד... טוב לא",
          "דירת 20 מ״ר עם פוטנציאל ונוף לפח הזבל",
          "חם מדי בשביל לקבל החלטות כלכליות",
          "אני בהייטק אבל שותה נס של עלית במשרד",
          "קניתי ירקות כדי לראות אותם נרקבים במקרר",
          "נהג מונית: 'אני בכלל עושה את זה בשביל הנפש'",
          "מאפה ב-28 שקל? הוא עשוי מזהב טהור?",
          "הכלב שלי אוכל יותר יקר ממני",
          "החשבון הגיע... מי מחשב טיפ?",
          "למה עשיתי ריצה במקום להזמין וולט?",
          "שיבולת שועל זה עוד 4 שקלים?!",
          "פירור של לחם מחמצת 45 שקל!",
          "סליחה! זזנו לאותו צד..."
        ]
      },
      en: {
        busStop: "Bus Stop • Boarding",
        vacantSlot: "Vacant Plot",
        arrived: "Welcome to the city!",
        newUpgrade: "New City Upgrade!",
        construction: [
          "Almost done... bro where are the keys?",
          "Just tightening a rent bolt here",
          "Slight budget overrun, but look at that finish!",
          "It's European standard, don't even ask",
          "Pristine job! Coffee is on you",
          "Reinforced concrete against inflation!",
          "Laying down one more brick!"
        ],
        constructionDone: "All done! Enjoy your new building! 🎉",
        cat: [
          "I see all your expenses from up here...",
          "Another food delivery? Really?",
          "Meow! Sunbathing on the warm roof",
          "Purrr... thanks for unlocking me!"
        ],
        dog: [
          "Woof woof! Strolling in the park!",
          "Good boy! Don't chew the receipt!",
          "My dog eats more expensive food than me!"
        ],
        fountain: "Wishing Fountain • Toss a coin?",
        sakura: "Cherry blossoms in full bloom!",
        coffeeStand: "Oat milk is an extra ₪4?!",
        sculpture: "Modern sculpture • What does it mean?",
        tap: [
          "Good morning!", "What a lovely day!", "Keeping my budget on track!",
          "Great coffee today!", "Love this city!", "Hello friend!",
          "Came for milk, spent ₪400",
          "Forgot to cancel the 7-day trial again",
          "Avocado rock hard, cost like Nvidia stock",
          "Work in high-tech, drink instant coffee"
        ],
        street: [
          "Where is Apt 4B? GPS went wild!",
          "Came in for milk, walked out with ₪400",
          "Forgot to cancel the 7-day free trial again",
          "Avocado is rock hard, cost like Nvidia stock",
          "Who ordered the ₪38 mineral water?!",
          "Bro, only stepped out for 2 mins!",
          "₪18 delivery fee? I'll cook... nah",
          "20 sqm studio with trash can views",
          "Too hot for responsible financial decisions",
          "Work in high-tech, drink instant coffee",
          "Bought veggies just to watch them rot",
          "Cab driver: 'I only drive for the soul'",
          "₪28 croissant? Is it made of 24k gold?",
          "My dog eats better than I do",
          "Bill is here... who calculates the tip?",
          "Why did I jog instead of Wolt?",
          "Oat milk is an extra ₪4?!",
          "Crumb of a ₪45 artisan sourdough!",
          "Pardon me! Sidewalk shuffle..."
        ]
      }
    };

    window.setDioramaLanguage = function(lang) {
      if (lang === "en" || lang === "he") {
        currentLanguage = lang;
        document.documentElement.lang = lang;
      }
    };

    function getDioramaPhrases() {
      return DIORAMA_PHRASES[currentLanguage] || DIORAMA_PHRASES.he;
    }

    function popEmojiBubble(parentObj, text, duration) {
      if (!parentObj) return;
      try {
        const cleanText = (text || "").trim();
        if (!cleanText) return;

        // Keep maximum 1 active bubble on screen so speech is calm, clean and never crowded
        while (activeBubbles.length > 0) {
          const oldB = activeBubbles.pop();
          if (oldB.el && oldB.el.parentNode) {
            oldB.el.parentNode.removeChild(oldB.el);
          }
        }

        const bubbleEl = document.createElement("div");
        bubbleEl.className = "diorama-speech-bubble";
        bubbleEl.style.direction = currentLanguage === "he" ? "rtl" : "ltr";
        bubbleEl.textContent = cleanText;

        const container = document.getElementById("diorama-html-tags") || stage || document.body;
        container.appendChild(bubbleEl);

        // Immediate position calculation
        const v = new THREE.Vector3();
        parentObj.getWorldPosition(v);
        v.y += 1.4;
        v.project(camera);
        if (v.z < 1) {
          const screenX = ((v.x + 1) * 0.5) * stage.clientWidth;
          const screenY = ((-v.y + 1) * 0.5) * stage.clientHeight;
          bubbleEl.style.left = screenX + "px";
          bubbleEl.style.top = screenY + "px";
        }

        // Trigger entrance
        requestAnimationFrame(() => {
          bubbleEl.classList.add("active");
        });

        activeBubbles.push({
          el: bubbleEl,
          targetObj: parentObj,
          life: 0,
          maxLife: duration || 2.5,
          offsetY: 1.4
        });
      } catch (err) {
        console.warn("Speech bubble creation caught:", err);
      }
    }

    // ================================================================
    // 🚶 ANIMATED MINIATURE CITIZENS & PETS
    // ================================================================
    function createMiniFigure(opts) {
      opts = opts || {};
      const fig = new THREE.Group();
      const shirtMat = mat(opts.shirtColor || 0x3b82f6, 0.75);
      const pantsMat = mat(opts.pantsColor || 0x1e293b, 0.85);
      const skinMat  = mat(opts.skinColor || 0xfcd34d, 0.80);
      const hairMat  = mat(opts.hairColor || 0x451a03, 0.90);
      const shoeMat  = mat(0x09090b, 0.90);

      const torsoGroup = new THREE.Group();
      fig.add(torsoGroup);
      const shirtMesh = mesh(roundedBox(0.22, 0.28, 0.15, 0.03), shirtMat, 0, 0.38, 0);
      torsoGroup.add(shirtMesh);

      const headGroup = new THREE.Group();
      headGroup.position.set(0, 0.60, 0);
      torsoGroup.add(headGroup);
      headGroup.add(mesh(new THREE.SphereGeometry(0.075, 10, 8), skinMat, 0, 0, 0));
      headGroup.add(mesh(new THREE.SphereGeometry(0.080, 8, 6, 0, Math.PI * 2, 0, Math.PI * 0.55), hairMat, 0, 0.012, 0));

      const legL = new THREE.Group(); legL.position.set(-0.055, 0.24, 0); fig.add(legL);
      legL.add(mesh(new THREE.CylinderGeometry(0.032, 0.028, 0.24, 8), pantsMat, 0, -0.12, 0));
      legL.add(mesh(new THREE.BoxGeometry(0.05, 0.035, 0.08), shoeMat, 0, -0.24, 0.02));

      const legR = new THREE.Group(); legR.position.set(0.055, 0.24, 0); fig.add(legR);
      legR.add(mesh(new THREE.CylinderGeometry(0.032, 0.028, 0.24, 8), pantsMat, 0, -0.12, 0));
      legR.add(mesh(new THREE.BoxGeometry(0.05, 0.035, 0.08), shoeMat, 0, -0.24, 0.02));

      const armL = new THREE.Group(); armL.position.set(-0.14, 0.48, 0); fig.add(armL);
      armL.add(mesh(new THREE.CylinderGeometry(0.028, 0.024, 0.22, 8), shirtMat, 0, -0.11, 0));
      armL.add(mesh(new THREE.SphereGeometry(0.030, 6, 6), skinMat, 0, -0.22, 0));

      const armR = new THREE.Group(); armR.position.set(0.14, 0.48, 0); fig.add(armR);
      armR.add(mesh(new THREE.CylinderGeometry(0.028, 0.024, 0.22, 8), shirtMat, 0, -0.11, 0));
      armR.add(mesh(new THREE.SphereGeometry(0.030, 6, 6), skinMat, 0, -0.22, 0));

      if (opts.hasBag) {
        const bag = new THREE.Group(); bag.position.set(0, -0.28, 0);
        bag.add(mesh(new THREE.BoxGeometry(0.12, 0.14, 0.07), mat(opts.bagColor || 0xec4899, 0.6), 0, 0, 0));
        bag.add(mesh(new THREE.TorusGeometry(0.035, 0.007, 6, 8, Math.PI), mat(0xd1d5db, 0.4), 0, 0.08, 0));
        armR.add(bag);
      }
      if (opts.hasCoffee) {
        const cup = new THREE.Group(); cup.position.set(0, -0.20, 0.05);
        cup.add(mesh(new THREE.CylinderGeometry(0.026, 0.020, 0.06, 8), mat(0xffffff, 0.3), 0, 0, 0));
        cup.add(mesh(new THREE.CylinderGeometry(0.028, 0.028, 0.012, 8), mat(0x78350f, 0.8), 0, 0.035, 0));
        armL.add(cup);
      }
      if (opts.hasPhone) {
        const phone = mesh(new THREE.BoxGeometry(0.035, 0.06, 0.01), mat(0x0284c7, 0.3, 0.8, 0x38bdf8, 1.2), 0, -0.18, 0.06);
        phone.rotation.x = -0.5; armL.add(phone);
      }

      if (opts.isSitting) {
        legL.rotation.x = -Math.PI / 2; legL.position.set(-0.055, 0.18, 0.05);
        legR.rotation.x = -Math.PI / 2; legR.position.set(0.055, 0.18, 0.05);
        armL.rotation.x = -0.3; armR.rotation.x = -0.3;
        torsoGroup.position.y = -0.06;
      }

      const uData = {
        fig: fig,
        torso: torsoGroup, head: headGroup,
        legL: legL, legR: legR, armL: armL, armR: armR,
        isSitting: opts.isSitting || false,
        isJogging: opts.isJogging || false,
        hasCoffee: opts.hasCoffee || false,
        hasPhone: opts.hasPhone || false,
        hasBag: opts.hasBag || false,
        hopTimer: 0
      };
      fig.userData = uData;
      shirtMesh.userData = uData;
      interactiveCitizens.push(shirtMesh);

      return fig;
    }

    function createMiniDog(col) {
      const dog = new THREE.Group();
      const dogMat = mat(col || 0xd97706, 0.85);
      const dogBody = mesh(new THREE.BoxGeometry(0.15, 0.10, 0.22), dogMat, 0, 0.14, 0);
      dog.add(dogBody);
      const head = mesh(new THREE.BoxGeometry(0.10, 0.10, 0.12), dogMat, 0, 0.22, 0.12);
      head.add(mesh(new THREE.BoxGeometry(0.035, 0.07, 0.025), mat(0x78350f, 0.9), -0.05, 0.02, 0));
      head.add(mesh(new THREE.BoxGeometry(0.035, 0.07, 0.025), mat(0x78350f, 0.9),  0.05, 0.02, 0));
      head.add(mesh(new THREE.BoxGeometry(0.05, 0.04, 0.07), mat(0x1e293b, 0.9), 0, -0.02, 0.08));
      dog.add(head);
      const tail = mesh(new THREE.CylinderGeometry(0.012, 0.016, 0.12, 6), dogMat, 0, 0.18, -0.14);
      tail.rotation.x = -0.7; dog.add(tail);

      const dogLegs = [];
      [[-0.05, -0.07], [0.05, -0.07], [-0.05, 0.07], [0.05, 0.07]].forEach(lp => {
        const dl = new THREE.Group(); dl.position.set(lp[0], 0.08, lp[1]); dog.add(dl);
        dl.add(mesh(new THREE.CylinderGeometry(0.018, 0.015, 0.10, 6), dogMat, 0, -0.05, 0));
        dogLegs.push(dl);
      });
      const uData = { isDog: true, dog: dog, tail: tail, head: head, legs: dogLegs, hopTimer: 0 };
      dog.userData = uData;
      dogBody.userData = uData;
      interactiveCitizens.push(dogBody);
      return dog;
    }

    const activeConstructionCrews = [];

    function createConstructionWorker(opts) {
      opts = opts || {};
      const fig = new THREE.Group();
      const vestMat = mat(opts.vestColor || 0xf97316, 0.7); // High-vis neon orange
      const pantsMat = mat(0x1e293b, 0.85); // Sturdy work pants
      const skinMat = mat(0xfbbf24, 0.8);
      const helmetMat = mat(opts.helmetColor || 0xfacc15, 0.3, 0.2); // Bright yellow safety hardhat
      const shoeMat = mat(0x78350f, 0.9); // Heavy work boots

      const torsoGroup = new THREE.Group();
      torsoGroup.position.y = 0.40;
      fig.add(torsoGroup);

      const torsoMesh = mesh(new THREE.BoxGeometry(0.24, 0.28, 0.14), vestMat, 0, 0, 0);
      torsoGroup.add(torsoMesh);
      // Reflective silver safety striping
      torsoGroup.add(mesh(new THREE.BoxGeometry(0.25, 0.05, 0.15), mat(0xe2e8f0, 0.2, 0.9), 0, 0.02, 0));

      const headGroup = new THREE.Group();
      headGroup.position.set(0, 0.22, 0);
      torsoGroup.add(headGroup);
      headGroup.add(mesh(new THREE.SphereGeometry(0.075, 10, 8), skinMat, 0, 0, 0));
      
      // Safety hardhat with visor brim
      const helmet = mesh(new THREE.SphereGeometry(0.090, 10, 8, 0, Math.PI * 2, 0, Math.PI * 0.55), helmetMat, 0, 0.02, 0);
      const helmetBrim = mesh(new THREE.CylinderGeometry(0.105, 0.105, 0.015, 12), helmetMat, 0, 0.01, 0);
      headGroup.add(helmet, helmetBrim);

      const legL = new THREE.Group(); legL.position.set(-0.055, 0.24, 0); fig.add(legL);
      legL.add(mesh(new THREE.CylinderGeometry(0.032, 0.028, 0.24, 8), pantsMat, 0, -0.12, 0));
      legL.add(mesh(new THREE.BoxGeometry(0.06, 0.04, 0.09), shoeMat, 0, -0.24, 0.02));

      const legR = new THREE.Group(); legR.position.set(0.055, 0.24, 0); fig.add(legR);
      legR.add(mesh(new THREE.CylinderGeometry(0.032, 0.028, 0.24, 8), pantsMat, 0, -0.12, 0));
      legR.add(mesh(new THREE.BoxGeometry(0.06, 0.04, 0.09), shoeMat, 0, -0.24, 0.02));

      const armL = new THREE.Group(); armL.position.set(-0.14, 0.48, 0); fig.add(armL);
      armL.add(mesh(new THREE.CylinderGeometry(0.028, 0.024, 0.22, 8), vestMat, 0, -0.11, 0));
      armL.add(mesh(new THREE.SphereGeometry(0.030, 6, 6), skinMat, 0, -0.22, 0));

      const armR = new THREE.Group(); armR.position.set(0.14, 0.48, 0); fig.add(armR);
      armR.add(mesh(new THREE.CylinderGeometry(0.028, 0.024, 0.22, 8), vestMat, 0, -0.11, 0));
      armR.add(mesh(new THREE.SphereGeometry(0.030, 6, 6), skinMat, 0, -0.22, 0));

      if (opts.hasHammer) {
        const hammer = new THREE.Group();
        hammer.position.set(0, -0.22, 0.06);
        hammer.add(mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.16, 6), mat(0x78350f, 0.8), 0, 0, 0));
        hammer.add(mesh(new THREE.BoxGeometry(0.04, 0.04, 0.08), mat(0x64748b, 0.3, 0.8), 0, 0.07, 0.01));
        armR.add(hammer);
      } else if (opts.hasWrench) {
        const wrench = mesh(new THREE.BoxGeometry(0.025, 0.14, 0.01), mat(0x94a3b8, 0.2, 0.9), 0, -0.20, 0.04);
        wrench.rotation.z = 0.3;
        armR.add(wrench);
      } else if (opts.hasBlueprint) {
        const bp = mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.18, 8), mat(0x38bdf8, 0.5), 0, -0.20, 0.04);
        bp.rotation.x = Math.PI / 2;
        armL.add(bp);
      }

      const uData = {
        fig: fig,
        isWorker: true,
        torso: torsoGroup, head: headGroup,
        legL: legL, legR: legR, armL: armL, armR: armR,
        hasHammer: opts.hasHammer || false,
        hasWrench: opts.hasWrench || false,
        hammerPhase: Math.random() * Math.PI * 2,
        hopTimer: 0
      };
      fig.userData = uData;
      torsoMesh.userData = uData;
      interactiveCitizens.push(torsoMesh);

      return fig;
    }

    function createConstructionCrew(buildingId, posX, posZ, parent, opts) {
      opts = opts || {};
      const g = new THREE.Group();
      g.position.set(posX, 0.22, posZ);
      (parent || root).add(g);

      // Worker 1: Active Hammerer
      const w1 = createConstructionWorker({ hasHammer: true, vestColor: 0xf97316, helmetColor: 0xfde047 });
      w1.position.set(0.65, 0, 0.55);
      w1.rotation.y = -Math.PI * 0.75;
      g.add(w1);

      // Worker 2: Wrench / Blueprint Foreman
      const w2 = createConstructionWorker({ hasWrench: true, hasBlueprint: true, vestColor: 0x84cc16, helmetColor: 0xffffff });
      w2.position.set(-0.65, 0, 0.60);
      w2.rotation.y = Math.PI * 0.65;
      g.add(w2);

      // Safety Cones
      [-0.95, 0.95].forEach(cx => {
        const cone = new THREE.Group();
        cone.position.set(cx, 0, 0.85);
        cone.add(mesh(new THREE.BoxGeometry(0.20, 0.025, 0.20), mat(0x1e293b, 0.9), 0, 0.012, 0));
        cone.add(mesh(new THREE.ConeGeometry(0.08, 0.32, 10), mat(0xf97316, 0.6), 0, 0.16, 0));
        cone.add(mesh(new THREE.CylinderGeometry(0.05, 0.06, 0.06, 10), mat(0xffffff, 0.4), 0, 0.16, 0));
        g.add(cone);
      });

      // Sturdy Red Toolbox
      const toolbox = mesh(new THREE.BoxGeometry(0.22, 0.12, 0.14), mat(0xd97706, 0.6), 0, 0.06, 0.75);
      g.add(toolbox);

      // A crane and scaffolding, but only for an actual building site. The permanent
      // roadworks crew in the city centre is patching a street, not raising a tower,
      // so it keeps just its cones and toolbox.
      let crane = null, scaffold = null;
      if (opts.withRig) {
        scaffold = new THREE.Group(); g.add(scaffold);
        [[-1.05, -1.05], [1.05, -1.05], [-1.05, 1.05], [1.05, 1.05]].forEach(pp => {
          scaffold.add(mesh(new THREE.CylinderGeometry(0.028, 0.028, 1.75, 6), mat(0x94a3b8, 0.4, 0.7), pp[0], 0.875, pp[1]));
        });
        [0.58, 1.30].forEach(ry => {
          scaffold.add(mesh(new THREE.BoxGeometry(2.14, 0.032, 0.032), mat(0x94a3b8, 0.4, 0.7), 0, ry, -1.05));
          scaffold.add(mesh(new THREE.BoxGeometry(2.14, 0.032, 0.032), mat(0x94a3b8, 0.4, 0.7), 0, ry, 1.05));
          scaffold.add(mesh(new THREE.BoxGeometry(0.032, 0.032, 2.14), mat(0x94a3b8, 0.4, 0.7), -1.05, ry, 0));
          scaffold.add(mesh(new THREE.BoxGeometry(0.032, 0.032, 2.14), mat(0x94a3b8, 0.4, 0.7), 1.05, ry, 0));
        });
        // A plank walkway on the lower rail, so the scaffold reads as usable.
        scaffold.add(mesh(new THREE.BoxGeometry(2.10, 0.03, 0.26), mat(0xd6b48a, 0.85), 0, 0.60, -1.05));

        const craneG = new THREE.Group(); craneG.position.set(-1.45, 0, -1.30); g.add(craneG);
        craneG.add(mesh(new THREE.BoxGeometry(0.38, 0.07, 0.38), mat(0x475569, 0.8), 0, 0.035, 0));
        craneG.add(mesh(new THREE.BoxGeometry(0.085, 2.20, 0.085), mat(0xfacc15, 0.5), 0, 1.10, 0));
        const jib = new THREE.Group(); jib.position.set(0, 2.16, 0); craneG.add(jib);
        jib.add(mesh(new THREE.BoxGeometry(1.70, 0.055, 0.065), mat(0xfacc15, 0.5), 0.62, 0, 0));
        jib.add(mesh(new THREE.BoxGeometry(0.50, 0.055, 0.065), mat(0x334155, 0.6), -0.32, 0, 0));
        jib.add(mesh(new THREE.BoxGeometry(0.18, 0.16, 0.18), mat(0x334155, 0.7), -0.46, -0.05, 0));
        jib.add(mesh(new THREE.BoxGeometry(0.14, 0.13, 0.16), mat(0xf8fafc, 0.4), 0.10, -0.10, 0));
        const cable = mesh(new THREE.CylinderGeometry(0.006, 0.006, 1.0, 4), mat(0x1e293b, 0.8), 1.18, -0.50, 0);
        const hook = mesh(new THREE.BoxGeometry(0.15, 0.11, 0.15), mat(0x94a3b8, 0.3, 0.8), 1.18, -1.06, 0);
        jib.add(cable, hook);
        crane = { jib: jib, cable: cable, hook: hook };
      }

      const crew = {
        buildingId: buildingId,
        group: g,
        workers: [w1, w2],
        timer: opts.timer || 75.0,
        isTemporary: true,
        speechTimer: 4.0,
        crane: crane,
        scaffold: scaffold,
        buildTarget: null,
        buildElapsed: 0,
        buildDuration: 0
      };
      activeConstructionCrews.push(crew);
      return crew;
    }

    /// Puts a crew on a plot and has them raise the building over a few seconds,
    /// instead of the building simply popping into existence at full height.
    function startConstruction(id, bg, wp) {
      const crew = createConstructionCrew(id, wp.x, wp.z, root, { withRig: true, timer: 9.2 });
      crew.buildTarget = bg;
      crew.buildDuration = 7.4;
      crew.buildElapsed = 0;
      bg.userData.underConstruction = true;
      bg.scale.set(0.06, 0.02, 0.06);
      return crew;
    }

    function addWalkingCitizen(opts) {
      const isStarter = opts.isStarter || false;
      const fig = createMiniFigure(opts);
      fig.visible = isStarter;
      root.add(fig);

      let dogRef = null;
      if (opts.hasDog) {
        dogRef = createMiniDog(opts.dogColor || 0xd97706);
        dogRef.visible = isStarter;
        root.add(dogRef);
      }

      if (opts.enrichmentId) {
        enrichmentObjects[opts.enrichmentId] = { isCitizen: true, fig: fig, dog: dogRef };
      }

      walkingCitizens.push({
        obj: fig,
        dog: dogRef,
        waypoints: opts.path,
        speed: opts.speed || 0.50,
        legPhase: opts.initialPhase || Math.random() * Math.PI * 2,
        progress: opts.initialProgress || 0,
        isJogging: opts.isJogging || false,
        pauseChance: opts.pauseChance !== undefined ? opts.pauseChance : 0.35,
        pauseTimer: 0,
        isPaused: false,
        pauseDuration: 0,
        lookTimer: Math.random() * 5.0,
        lastSegIdx: -1,
        isStarter: isStarter,
        enrichmentId: opts.enrichmentId
      });
    }

    // ════════════════════════════════════════════════════════════════
    // 🌍 ARCHITECTURAL DIORAMA PODIUM (High-End Titanium & Obsidian Plinth)
    // ════════════════════════════════════════════════════════════════
    // 1. Titanium Slate Sub-Base (Sleek Modern Charcoal with Chamfered Corners)
    root.add(mesh(roundedBox(23.2, 0.45, 23.2, 1.4), mat(0x0f172a, 0.95, 0.1), 0, -0.22, 0, false, true));
    
    // 2. Chiseled Anthracite Foundation Layer
    root.add(mesh(roundedBox(23.0, 0.90, 23.0, 1.5), mat(0x18181b, 0.90, 0.2), 0, -0.85, 0, false, true));
    
    // 3. Luxurious Chamfered Base Plinth with Warm Golden Brass Trim Ring
    root.add(mesh(roundedBox(23.6, 0.22, 23.6, 1.6), mat(0xf59e0b, 0.35, 0.85, 0xb45309, 0.2), 0, -1.35, 0, false, false));
    root.add(mesh(roundedBox(22.6, 0.80, 22.6, 1.3), mat(0x09090b, 0.95), 0, -1.85, 0, false, false));

    // ════════════════════════════════════════════════════════════════
    // 🛣️ RECESSED ASPHALT ROADS, RAIN GUTTERS & HIGH-CONTRAST MARKINGS
    // ════════════════════════════════════════════════════════════════
    // Recessed Midnight Charcoal Asphalt Surface (y = 0.05) with stone aggregate bump map
    const asphaltMatH = new THREE.MeshStandardMaterial({
      map: asphaltTexH(),
      bumpMap: asphaltBumpTex(),
      bumpScale: 0.08,
      roughness: 0.85,
      metalness: 0.15
    });
    const asphaltMatV = new THREE.MeshStandardMaterial({
      map: asphaltTexV(),
      bumpMap: asphaltBumpTex(),
      bumpScale: 0.08,
      roughness: 0.85,
      metalness: 0.15
    });
    root.add(mesh(new THREE.BoxGeometry(23.0, 0.10, 4.4), asphaltMatH, 0, 0.05, -0.8, false, true));
    root.add(mesh(new THREE.BoxGeometry(4.4, 0.10, 23.0), asphaltMatV, 0.6, 0.05, 0, false, true));

    // Stone Drainage Gutter Channels along road curbs
    const gutterMat = mat(0x1e293b, 0.9);
    root.add(mesh(new THREE.BoxGeometry(23.0, 0.11, 0.18), gutterMat, 0, 0.055, -2.95));
    root.add(mesh(new THREE.BoxGeometry(23.0, 0.11, 0.18), gutterMat, 0, 0.055, 1.35));
    root.add(mesh(new THREE.BoxGeometry(0.18, 0.11, 23.0), gutterMat, -1.55, 0.055, 0));
    root.add(mesh(new THREE.BoxGeometry(0.18, 0.11, 23.0), gutterMat, 2.75, 0.055, 0));

    // Painted Centerline Dashes (Pure White Crisp Line)
    for (let rx = -10.5; rx < 11.5; rx += 2.8) {
      root.add(mesh(new THREE.BoxGeometry(1.5, 0.11, 0.14), mat(0xffffff, 0.85), rx, 0.06, -0.8, false, false));
    }
    for (let rz = -10.5; rz < 11.5; rz += 2.8) {
      root.add(mesh(new THREE.BoxGeometry(0.14, 0.11, 1.5), mat(0xffffff, 0.85), 0.6, 0.06, rz, false, false));
    }

    // High-Visibility Zebra Crosswalks (Sunflower Yellow + Crisp White Stripes)
    for (let i = -1.6; i <= 1.6; i += 0.42) {
      root.add(mesh(new THREE.BoxGeometry(0.24, 0.11, 3.8), mat(0xfacc15, 0.85), -2.6 + i, 0.06, -0.8, false, false));
      root.add(mesh(new THREE.BoxGeometry(0.24, 0.11, 3.8), mat(0xfacc15, 0.85), 3.8 + i, 0.06, -0.8, false, false));
      root.add(mesh(new THREE.BoxGeometry(3.8, 0.11, 0.24), mat(0xfacc15, 0.85), 0.6, 0.06, -3.8 + i, false, false));
      root.add(mesh(new THREE.BoxGeometry(3.8, 0.11, 0.24), mat(0xfacc15, 0.85), 0.6, 0.06, 2.2 + i, false, false));
    }

    // Yellow Cross-Hatched Intersection Box (No Stopping Zone)
    const hatchMat = mat(0xfacc15, 0.8);
    for (let hi = -1.8; hi <= 1.8; hi += 0.45) {
      const hLine1 = mesh(new THREE.BoxGeometry(0.10, 0.11, 3.4), hatchMat, 0.6 + hi * 0.7, 0.055, -0.8);
      hLine1.rotation.y = Math.PI / 4; root.add(hLine1);
      const hLine2 = mesh(new THREE.BoxGeometry(0.10, 0.11, 3.4), hatchMat, 0.6 + hi * 0.7, 0.055, -0.8);
      hLine2.rotation.y = -Math.PI / 4; root.add(hLine2);
    }

    // ════════════════════════════════════════════════════════════════
    // 🧱 3D PHYSICAL BEVELED GRANITE CURBS (True Architectural Elevation)
    // ════════════════════════════════════════════════════════════════
    const curbGraniteM = mat(0xe2e8f0, 0.7, 0.4);
    const curbDarkM    = mat(0x475569, 0.75, 0.3);

    function add3DCurbLine(pStart, pEnd, isVertical) {
      const len = isVertical ? Math.abs(pEnd.z - pStart.z) : Math.abs(pEnd.x - pStart.x);
      const segLen = 0.85;
      const count = Math.floor(len / segLen);
      for (let s = 0; s < count; s++) {
        const segMat = (s % 2 === 0) ? curbGraniteM : curbDarkM;
        if (isVertical) {
          const cz = pStart.z + (s + 0.5) * (pEnd.z > pStart.z ? segLen : -segLen);
          const cb = mesh(new THREE.BoxGeometry(0.16, 0.16, segLen * 0.96), segMat, pStart.x, 0.14, cz, false, true);
          root.add(cb);
        } else {
          const cx = pStart.x + (s + 0.5) * (pEnd.x > pStart.x ? segLen : -segLen);
          const cb = mesh(new THREE.BoxGeometry(segLen * 0.96, 0.16, 0.16), segMat, cx, 0.14, pStart.z, false, true);
          root.add(cb);
        }
      }
    }

    // 1. Food District Curbs (North-West)
    add3DCurbLine({x: -11.0, z: -3.0}, {x: -1.6, z: -3.0}, false);
    add3DCurbLine({x: -1.6, z: -3.0}, {x: -1.6, z: -11.0}, true);

    // 2. Shopping District Curbs (North-East)
    add3DCurbLine({x: 2.8, z: -3.0}, {x: 11.0, z: -3.0}, false);
    add3DCurbLine({x: 2.8, z: -3.0}, {x: 2.8, z: -11.0}, true);

    // 3. Housing District Curbs (South-East)
    add3DCurbLine({x: 2.8, z: 1.4}, {x: 11.0, z: 1.4}, false);
    add3DCurbLine({x: 2.8, z: 1.4}, {x: 2.8, z: 11.0}, true);

    // 4. Park District Curbs (South-West)
    add3DCurbLine({x: -11.0, z: 1.4}, {x: -1.6, z: 1.4}, false);
    add3DCurbLine({x: -1.6, z: 1.4}, {x: -1.6, z: 11.0}, true);

    // ================================================================
    // BUILDING CREATORS – PROPORTIONALLY SPACED & DETAILED
    // ================================================================

    // ────────────────────────────────────────────────────────────────
    // 🍽️  FOOD DISTRICT (Bright Piazza & Travertine Dining Terrace)
    // ────────────────────────────────────────────────────────────────
    const foodZone = new THREE.Group();
    foodZone.position.set(-6.2, 0.08, -6.8);
    root.add(foodZone);
    foodZone.add(mesh(roundedBox(8.8, 0.22, 8.8, 0.6), new THREE.MeshStandardMaterial({ map: foodPlazaTex(), bumpMap: foodPlazaBump(), bumpScale: 0.12, roughness: 0.78 }), 0, 0.11, 0, false, true));

    // Raised Outdoor Dining Travertine Stone Terrace with White Marble Trim
    const diningTerrace = mesh(roundedBox(4.5, 0.08, 4.0, 0.2), new THREE.MeshStandardMaterial({ map: shopPlazaTex(), bumpMap: shopPlazaBump(), bumpScale: 0.08, roughness: 0.72 }), -2.2, 0.22, -2.2, false, true);
    diningTerrace.add(mesh(new THREE.BoxGeometry(4.6, 0.02, 0.15), mat(0xe2e8f0, 0.9), 0, 0.04, 2.0));
    foodZone.add(diningTerrace);

    // 🥐 THE NEST DINING (Width: 2.6, Depth: 2.4 - Spaced at x: -2.3, z: -2.2)
    function createBistro(parent) {
      const g = new THREE.Group(); g.position.set(-2.3, 0.22, -2.2); parent.add(g);
      buildingRoots["food_bistro"] = g; g.userData = { targetScaleY: 1.0, targetScaleXZ: 1.0 };
      const bGroup = new THREE.Group(); g.add(bGroup);
      const sGroup = createTier1Stall("bistro"); g.add(sGroup);
      g.userData.buildingGroup = bGroup; g.userData.stallGroup = sGroup;

      const body = mesh(roundedBox(2.6, 2.4, 2.4, 0.18), new THREE.MeshStandardMaterial({ map: bistroBrickTex(), bumpMap: brickBumpTex(), bumpScale: 0.08, roughness: 0.75 }), 0, 0, 0);
      bGroup.add(body);
      addWindows(bGroup, 1, 2, 2.6, 2.4, 2.4, 1.22);

      const roofL = mesh(new THREE.BoxGeometry(2.8, 0.09, 1.4), mat(0x18181b, 0.6, 0.5), 0, 2.48, -0.55);
      roofL.rotation.x = -0.40; bGroup.add(roofL);
      const roofR = mesh(new THREE.BoxGeometry(2.8, 0.09, 1.4), mat(0x18181b, 0.6, 0.5), 0, 2.48, 0.55);
      roofR.rotation.x = 0.40; bGroup.add(roofR);
      bGroup.add(mesh(new THREE.BoxGeometry(2.8, 0.12, 0.16), mat(0xf4c542, 0.7, 0.4), 0, 2.78, 0));

      const ch = new THREE.Group(); ch.position.set(0.8, 2.4, -0.6); bGroup.add(ch);
      ch.add(mesh(new THREE.BoxGeometry(0.38, 0.9, 0.38), mat(0x78350f, 0.85), 0, 0.45, 0));
      ch.add(mesh(new THREE.BoxGeometry(0.48, 0.10, 0.48), mat(0x57534e, 0.7), 0, 0.95, 0));
      [0, 0.18, 0.36].forEach((oy, i) => {
        const s = mesh(new THREE.SphereGeometry(0.08 + i * 0.03, 8, 8), mat(0xd1d5db, 0.9, 0, 0xffffff, 0.1), i * 0.05, 1.05 + oy, 0, false, false);
        ch.add(s); animObjects.push({ type: "smoke", ref: s, phase: i * 0.8 });
      });

      bGroup.add(mesh(new THREE.BoxGeometry(2.0, 0.55, 0.12), new THREE.MeshStandardMaterial({ map: signTex("🍽️ מסעדות", "Restaurants & Dining", "#ffffff", "#e11d48"), emissive: 0xe11d48, emissiveIntensity: 0.50 }), 0, 1.95, 1.28));
      const awn = mesh(new THREE.BoxGeometry(2.3, 0.10, 0.95), new THREE.MeshStandardMaterial({ map: stripeTex("#e11d48", "#ffffff", 6), roughness: 0.8 }), 0, 1.28, 1.30);
      awn.rotation.x = -0.25; bGroup.add(awn);
      bGroup.add(mesh(new THREE.BoxGeometry(1.6, 0.65, 0.10), winGlowM, 0, 0.50, 1.22));

      const mb = mesh(new THREE.BoxGeometry(0.38, 0.55, 0.05), new THREE.MeshStandardMaterial({ map: menuTex() }), 1.1, 0.28, 1.6);
      mb.rotation.y = -0.3; bGroup.add(mb);

      // Potted Olive Trees on both sides of entrance
      [-1.15, 1.15].forEach(tx => {
        const pot = new THREE.Group(); pot.position.set(tx, 0, 1.45); bGroup.add(pot);
        pot.add(mesh(new THREE.CylinderGeometry(0.14, 0.10, 0.22, 10), mat(0xc2410c, 0.8), 0, 0.11, 0));
        pot.add(mesh(new THREE.SphereGeometry(0.22, 10, 8), mat(0x166534, 0.85), 0, 0.35, 0));
      });

      // Outdoor AC Compressor Unit on Side Wall
      const acUnit = new THREE.Group(); acUnit.position.set(-1.35, 1.65, 0); bGroup.add(acUnit);
      acUnit.add(mesh(roundedBox(0.42, 0.32, 0.22, 0.04), mat(0xf8fafc, 0.6), 0, 0.16, 0));
      acUnit.add(mesh(new THREE.CylinderGeometry(0.10, 0.10, 0.02, 12), mat(0x334155, 0.8), -0.22, 0.16, 0));

      // Climbing Ivy Vine on Wall
      bGroup.add(mesh(new THREE.DodecahedronGeometry(0.24, 1), mat(0x15803d, 0.9), 1.25, 0.65, -0.65));
      bGroup.add(mesh(new THREE.DodecahedronGeometry(0.18, 1), mat(0x16a34a, 0.85), 1.25, 1.05, -0.65));

      // Dining Table with French Baguette Basket, Wine Bottle & Seated Diners
      const symG = new THREE.Group(); symG.position.set(-0.3, 0, 1.65); bGroup.add(symG);
      symG.add(mesh(new THREE.CylinderGeometry(0.035, 0.035, 0.45, 8), mat(0x1e293b, 0.5), 0, 0.22, 0));
      symG.add(mesh(new THREE.CylinderGeometry(0.35, 0.35, 0.035, 14), mat(0xd97706, 0.6), 0, 0.45, 0));
      symG.add(mesh(new THREE.CylinderGeometry(0.035, 0.040, 0.32, 10), mat(0x14532d, 0.4, 0.5), 0.10, 0.62, 0));
      symG.add(mesh(new THREE.CylinderGeometry(0.015, 0.035, 0.10, 8), mat(0x14532d, 0.4), 0.10, 0.80, 0));
      symG.add(mesh(new THREE.CylinderGeometry(0.09, 0.07, 0.06, 10), mat(0x854d0e, 0.9), -0.12, 0.50, 0));
      symG.add(mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.16, 6), mat(0xd97706, 0.8), -0.12, 0.58, 0));

      const diner1 = createMiniFigure({ shirtColor: 0xe11d48, pantsColor: 0x1e293b, isSitting: true });
      diner1.position.set(-0.35, 0, 1.65); diner1.rotation.y = Math.PI / 2; bGroup.add(diner1);
      const diner2 = createMiniFigure({ shirtColor: 0x3b82f6, pantsColor: 0x475569, isSitting: true, hairColor: 0xd97706 });
      diner2.position.set(0.35, 0, 1.65); diner2.rotation.y = -Math.PI / 2; bGroup.add(diner2);
      seatedCitizens.push(diner1, diner2);

      const bistroSpot = new THREE.SpotLight(0xffb347, 2.0, 5, 0.60, 0.5);
      bistroSpot.position.set(0, 3.2, 2.0); bistroSpot.target.position.set(0, 0.8, 1.28);
      bGroup.add(bistroSpot); bGroup.add(bistroSpot.target);

      body.userData = { id: "food_bistro", district: "food", name: "מסעדות ואוכל בחוץ", emoji: "🍽️", amount: 520, visits: 8, trend: "+12% מחודש שעבר" };
      return body;
    }

    // 🛒 FRESH MARKET (Width: 2.4, Depth: 2.3 - Spaced at x: 2.3, z: -2.2)
    function createFreshMarket(parent) {
      const g = new THREE.Group(); g.position.set(2.3, 0.22, -2.2); parent.add(g);
      buildingRoots["food_super"] = g; g.userData = { targetScaleY: 1.0, targetScaleXZ: 1.0 };
      const bGroup = new THREE.Group(); g.add(bGroup);
      const sGroup = createTier1Stall("super"); g.add(sGroup);
      g.userData.buildingGroup = bGroup; g.userData.stallGroup = sGroup;

      const body = mesh(roundedBox(2.4, 2.1, 2.3, 0.16), new THREE.MeshStandardMaterial({ map: superWoodTex(), bumpMap: plankBumpTex(), bumpScale: 0.08, roughness: 0.70 }), 0, 0, 0);
      bGroup.add(body);
      addWindows(bGroup, 1, 2, 2.4, 2.1, 2.3, 1.17);

      for (let ri = 0; ri < 3; ri++) {
        const ridge = mesh(new THREE.CylinderGeometry(0, 0.42, 0.75, 3), mat(0x166534, 0.75), -0.7 + ri * 0.7, 2.32, 0);
        ridge.rotation.y = Math.PI / 6; bGroup.add(ridge);
      }
      const canopy = mesh(new THREE.BoxGeometry(2.6, 0.08, 1.1), new THREE.MeshStandardMaterial({ map: plankTex("#78350f"), bumpMap: plankBumpTex(), bumpScale: 0.05, roughness: 0.85 }), 0, 1.35, 1.35);
      canopy.rotation.x = -0.22; bGroup.add(canopy);
      [-1.0, 1.0].forEach(px => bGroup.add(mesh(new THREE.CylinderGeometry(0.035, 0.04, 1.35, 8), mat(0x78350f, 0.8), px, 0.68, 1.28)));
      bGroup.add(mesh(new THREE.BoxGeometry(1.9, 0.48, 0.10), new THREE.MeshStandardMaterial({ map: signTex("🛒 סופרמרקט", "Supermarket & Groceries", "#ffffff", "#15803d"), emissive: 0x15803d, emissiveIntensity: 0.45 }), 0, 1.80, 1.20));

      // Realistic Wooden Fruit Crates
      const crateBase = new THREE.Group(); crateBase.position.set(0, 0, 1.45); bGroup.add(crateBase);
      const fruitData = [
        { col: 0xe11d48, positions: [[-0.38,0], [0,0], [0.38,0]] },
        { col: 0xf97316, positions: [[-0.25,0.20], [0.25,0.20]] },
        { col: 0xfacc15, positions: [[0,0.38]] }
      ];
      fruitData.forEach((row, ri) => {
        const crate = mesh(new THREE.BoxGeometry(0.9, 0.16, 0.32), mat(0x854d0e, 0.85), 0, 0.08 + ri * 0.18, 0);
        crateBase.add(crate);
        row.positions.forEach(p => {
          const fr = mesh(new THREE.SphereGeometry(0.065 + (2 - ri) * 0.012, 10, 8), mat(row.col, 0.55), p[0], 0.10, 0);
          crate.add(fr);
        });
      });

      // Miniature Wireframe Grocery Carts parked outside
      [-0.95, -0.65].forEach((gx, idx) => {
        const cartGroup = new THREE.Group(); cartGroup.position.set(gx, 0, 1.50); cartGroup.rotation.y = 0.30 - idx * 0.1; bGroup.add(cartGroup);
        cartGroup.add(mesh(new THREE.BoxGeometry(0.32, 0.24, 0.42), new THREE.MeshStandardMaterial({ color: 0xd1d5db, wireframe: true }), 0, 0.20, 0));
        cartGroup.add(mesh(new THREE.BoxGeometry(0.28, 0.03, 0.04), mat(0xef4444, 0.6), 0, 0.32, -0.21));
        [[-0.12,-0.16], [0.12,-0.16], [-0.12,0.16], [0.12,0.16]].forEach(([wx,wz]) => {
          cartGroup.add(mesh(new THREE.CylinderGeometry(0.035, 0.035, 0.02, 8), mat(0x18181b, 0.9), wx, 0.035, wz));
        });
      });

      addLight("point", 0xfde68a, 1.3, 3.8, 0, 1.6, 1.6, bGroup);

      body.userData = { id: "food_super", district: "food", name: "סופרמרקט ומזון", emoji: "🛒", amount: 410, visits: 4, trend: "-5% מחודש שעבר" };
      return body;
    }

    // ☕ COFFEE HOUSE (Width: 2.4, Depth: 2.3 - Spaced at x: -2.3, z: 2.3)
    function createCoffeeHouse(parent) {
      const g = new THREE.Group(); g.position.set(-2.3, 0.22, 2.3); parent.add(g);
      buildingRoots["food_coffee"] = g; g.userData = { targetScaleY: 1.0, targetScaleXZ: 1.0 };
      const bGroup = new THREE.Group(); g.add(bGroup);
      const sGroup = createTier1Stall("coffee"); g.add(sGroup);
      g.userData.buildingGroup = bGroup; g.userData.stallGroup = sGroup;

      const body = mesh(roundedBox(2.4, 2.0, 2.3, 0.16), new THREE.MeshStandardMaterial({ map: coffeeWoodTex(), bumpMap: plankBumpTex(), bumpScale: 0.08, roughness: 0.70 }), 0, 0, 0);
      bGroup.add(body);
      addWindows(bGroup, 1, 2, 2.4, 2.0, 2.3, 1.17);

      const roofBase = mesh(new THREE.BoxGeometry(2.6, 0.12, 2.5), mat(0xb45309, 0.75), 0, 2.08, 0); bGroup.add(roofBase);
      const roofTop = mesh(new THREE.ConeGeometry(1.8, 0.85, 4), mat(0xc2410c, 0.75), 0, 2.52, 0);
      roofTop.rotation.y = Math.PI / 4; bGroup.add(roofTop);
      bGroup.add(mesh(new THREE.CylinderGeometry(0.18, 0.18, 0.14, 16), mat(0xfbbf24, 0.2, 0.5, 0xfef08a, 1.8), 0, 2.12, 1.15));

      const cup = new THREE.Group(); cup.position.set(-0.25, 2.65, -0.3); bGroup.add(cup);
      cup.add(mesh(new THREE.CylinderGeometry(0.32, 0.24, 0.42, 14), mat(0xffffff, 0.25, 0.15), 0, 0.21, 0));
      cup.add(mesh(new THREE.CylinderGeometry(0.28, 0.28, 0.05, 14), mat(0x451a03, 0.55), 0, 0.42, 0));
      cup.add(mesh(new THREE.CylinderGeometry(0.38, 0.38, 0.04, 14), mat(0xffffff, 0.25), 0, -0.02, 0));
      cup.add(mesh(new THREE.TorusGeometry(0.16, 0.038, 8, 14), mat(0xffffff, 0.25), 0.30, 0.21, 0));
      [0, 0.12].forEach((ox, i) => {
        const sw = mesh(new THREE.SphereGeometry(0.045, 8, 8), mat(0xe2e8f0, 0.85, 0, 0xffffff, 0.08), ox, 0.50 + i * 0.18, 0, false, false);
        cup.add(sw); animObjects.push({ type: "steam", ref: sw, phase: i * 1.2 });
      });

      bGroup.add(mesh(new THREE.BoxGeometry(1.9, 0.48, 0.10), new THREE.MeshStandardMaterial({ map: signTex("☕ בתי קפה", "Coffee & Cafes", "#ffffff", "#b45309"), emissive: 0xb45309, emissiveIntensity: 0.50 }), 0, 1.72, 1.20));
      const awn2 = mesh(new THREE.BoxGeometry(2.1, 0.10, 0.85), new THREE.MeshStandardMaterial({ map: stripeTex("#f4c542", "#ffffff", 6), roughness: 0.8 }), 0, 1.20, 1.25);
      awn2.rotation.x = -0.25; bGroup.add(awn2);

      // Outdoor Cafe Table & Umbrella Grounded
      const umb = new THREE.Group(); umb.position.set(0.6, 0, 1.75); bGroup.add(umb);
      umb.add(mesh(new THREE.CylinderGeometry(0.025, 0.025, 1.45, 6), mat(0x854d0e, 0.7), 0, 0.72, 0));
      const cone = mesh(new THREE.ConeGeometry(0.78, 0.30, 12), mat(0xf4c542, 0.8), 0, 1.45, 0);
      cone.rotation.z = 0.14; umb.add(cone);
      umb.add(mesh(new THREE.CylinderGeometry(0.035, 0.035, 0.42, 6), mat(0x1e293b, 0.5), 0, 0.21, 0));
      umb.add(mesh(new THREE.CylinderGeometry(0.30, 0.30, 0.035, 12), mat(0xd97706, 0.7), 0, 0.44, 0));

      const cafePatron = createMiniFigure({ shirtColor: 0xf4c542, pantsColor: 0x1e293b, isSitting: true, hasCoffee: true });
      cafePatron.position.set(0.6, 0, 1.95); cafePatron.rotation.y = Math.PI; bGroup.add(cafePatron);
      seatedCitizens.push(cafePatron);

      addLight("point", 0xff9a5c, 1.5, 4.5, 0, 1.6, 1.7, bGroup);

      // ☕ Cynical Satire Element: High-Detail Takeaway Coffee Cups & Billowing Steam Rings
      const coffeeChaos = new THREE.Group(); bGroup.add(coffeeChaos);
      coffeeChaos.visible = false;
      g.userData.coffeeChaos = coffeeChaos;
      
      const cupPositions = [[0.95, 1.45], [1.12, 1.40], [0.80, 1.48], [1.02, 1.62], [0.90, 1.60]];
      cupPositions.forEach(([cx, cz], i) => {
        const cGroup = new THREE.Group(); cGroup.position.set(cx, i >= 3 ? 0.20 : 0, cz);
        cGroup.add(mesh(new THREE.CylinderGeometry(0.055, 0.040, 0.18, 12), mat(0xffffff, 0.2, 0.1), 0, 0.09, 0));
        cGroup.add(mesh(new THREE.CylinderGeometry(0.057, 0.048, 0.08, 12), mat(0xa16207, 0.8), 0, 0.09, 0));
        cGroup.add(mesh(new THREE.CylinderGeometry(0.060, 0.058, 0.025, 12), mat(0xffffff, 0.2), 0, 0.19, 0));
        coffeeChaos.add(cGroup);
      });
      [0.60, 1.05, 1.50].forEach((sy, i) => {
        const bigSteam = mesh(new THREE.TorusGeometry(0.14 + i * 0.05, 0.045, 8, 16), mat(0xffffff, 0.9, 0, 0xffffff, 0.18), (i - 1) * 0.06, 3.1 + sy, -0.3, false, false);
        bigSteam.rotation.x = Math.PI / 2;
        coffeeChaos.add(bigSteam);
        animObjects.push({ type: "steam", ref: bigSteam, phase: i * 1.4 });
      });

      body.userData = { id: "food_coffee", district: "food", name: "בתי קפה ומאפים", emoji: "☕", amount: 180, visits: 12, trend: "+20% מחודש שעבר" };
      return body;
    }

    // 🛵 WOLT LOGISTICS HUB (Width: 2.4, Depth: 2.3 - Spaced at x: 2.3, z: 2.3)
    function createWoltDepot(parent) {
      const g = new THREE.Group(); g.position.set(2.3, 0.22, 2.3); parent.add(g);
      buildingRoots["food_wolt"] = g; g.userData = { targetScaleY: 1.0, targetScaleXZ: 1.0 };
      const bGroup = new THREE.Group(); g.add(bGroup);
      const sGroup = createTier1Stall("wolt"); g.add(sGroup);
      g.userData.buildingGroup = bGroup; g.userData.stallGroup = sGroup;

      const body = mesh(roundedBox(2.4, 1.8, 2.3, 0.15), new THREE.MeshStandardMaterial({ map: woltSteelTex(), roughness: 0.40, metalness: 0.70 }), 0, 0, 0);
      bGroup.add(body);
      bGroup.add(mesh(new THREE.BoxGeometry(2.42, 0.18, 2.32), mat(0xf4c542, 0.5, 0.4), 0, 0.09, 0));
      bGroup.add(mesh(new THREE.BoxGeometry(2.5, 0.14, 2.4), mat(0x0369a1, 0.7, 0.4), 0, 1.88, 0));
      bGroup.add(mesh(new THREE.BoxGeometry(2.6, 0.24, 0.10), mat(0x0369a1, 0.7), 0, 2.0, -1.15));
      bGroup.add(mesh(new THREE.BoxGeometry(2.6, 0.24, 0.10), mat(0x0369a1, 0.7), 0, 2.0,  1.15));

      bGroup.add(mesh(new THREE.BoxGeometry(1.4, 1.05, 0.08), mat(0x082f49, 0.65), 0, 0.52, 1.18));
      for (let sy = 0; sy < 4; sy++) bGroup.add(mesh(new THREE.BoxGeometry(1.4, 0.035, 0.10), mat(0x0284c7, 0.5, 0.6), 0, 0.12 + sy * 0.22, 1.22, false, false));

      bGroup.add(mesh(new THREE.BoxGeometry(1.9, 0.48, 0.10), new THREE.MeshStandardMaterial({ map: signTex("🛵 משלוחי אוכל", "Food Delivery", "#ffffff", "#0284c7"), emissive: 0x0284c7, emissiveIntensity: 0.55 }), 0, 1.62, 1.20));

      const shelf = mesh(new THREE.BoxGeometry(1.4, 0.05, 0.4), mat(0x475569, 0.6, 0.5), -0.15, 0.50, 1.30); bGroup.add(shelf);
      [-0.42, 0, 0.42].forEach((bx) => {
        const bag = mesh(new THREE.BoxGeometry(0.24, 0.26, 0.22), new THREE.MeshStandardMaterial({ map: woltTex(), roughness: 0.4 }), bx, 0.66, 1.30);
        bGroup.add(bag);
      });

      // 🛵 Cynical Satire Element: Detailed Wolt Scooters & Pizza Box Avalanche Grounded
      const woltChaos = new THREE.Group(); bGroup.add(woltChaos);
      woltChaos.visible = false;
      g.userData.woltChaos = woltChaos;

      for (let pi = 0; pi < 7; pi++) {
        const pBox = mesh(new THREE.BoxGeometry(0.55, 0.06, 0.55), mat(0xd97706, 0.85), 0.88, 0.03 + pi * 0.065, 1.42);
        pBox.rotation.y = (pi * 0.14) - 0.35;
        pBox.add(mesh(new THREE.BoxGeometry(0.12, 0.005, 0.56), mat(0x0284c7, 0.5), 0, 0.032, 0));
        woltChaos.add(pBox);
      }
      [-0.18, 0.18].forEach((bx) => {
        const bG = new THREE.Group(); bG.position.set(0.88 + bx, 0.52, 1.42);
        bG.add(mesh(new THREE.BoxGeometry(0.24, 0.30, 0.20), new THREE.MeshStandardMaterial({ map: woltTex(), roughness: 0.5 }), 0, 0.15, 0));
        bG.add(mesh(new THREE.TorusGeometry(0.06, 0.012, 6, 10, Math.PI), mat(0x78350f, 0.9), 0, 0.31, 0));
        woltChaos.add(bG);
      });

      [[-0.95, 1.55, -0.6], [-1.35, 1.15, -0.2]].forEach(([sx, sz, sRot]) => {
        const scooter = new THREE.Group(); scooter.position.set(sx, 0, sz); scooter.rotation.y = sRot; woltChaos.add(scooter);
        scooter.add(mesh(new THREE.BoxGeometry(0.18, 0.12, 0.82), mat(0x0284c7, 0.4, 0.4), 0, 0.16, 0));
        scooter.add(mesh(new THREE.BoxGeometry(0.16, 0.38, 0.18), mat(0x0284c7, 0.4, 0.4), 0, 0.32, 0.30));
        // This deck runs along Z, so its wheels have to spin about X. A cylinder's
        // default axis is Y: left alone each wheel lies flat like a coin under the
        // board, which is what made these parked scooters read as tipped over.
        [0.32, -0.32].forEach(wz => {
          const tyre = mesh(new THREE.CylinderGeometry(0.13, 0.13, 0.06, 12), mat(0x18181b, 0.9), 0, 0.13, wz);
          tyre.rotation.z = Math.PI / 2; scooter.add(tyre);
          const rim = mesh(new THREE.CylinderGeometry(0.07, 0.07, 0.065, 10), mat(0xd1d5db, 0.2, 0.9), 0, 0.13, wz);
          rim.rotation.z = Math.PI / 2; scooter.add(rim);
        });
        scooter.add(mesh(new THREE.CylinderGeometry(0.015, 0.015, 0.44, 6), mat(0x18181b, 0.7), 0, 0.56, 0.28));
        const hBar = mesh(new THREE.BoxGeometry(0.42, 0.03, 0.03), mat(0x18181b, 0.7), 0, 0.76, 0.28);
        scooter.add(hBar);
        scooter.add(mesh(new THREE.SphereGeometry(0.045, 8, 8), new THREE.MeshStandardMaterial({ color: 0xffffff, emissive: 0xffffff, emissiveIntensity: 2.0 }), 0, 0.48, 0.40));
        const woltBag = mesh(new THREE.BoxGeometry(0.32, 0.34, 0.30), new THREE.MeshStandardMaterial({ color: 0x0284c7, roughness: 0.3, emissive: 0x0284c7, emissiveIntensity: 0.3 }), 0, 0.42, -0.22);
        woltBag.add(mesh(new THREE.BoxGeometry(0.33, 0.03, 0.31), mat(0xffffff, 0.2), 0, 0.16, 0));
        scooter.add(woltBag);
      });

      addLight("point", 0x0284c7, 1.2, 4.0, 0, 1.9, 1.6, bGroup);

      body.userData = { id: "food_wolt", district: "food", name: "משלוחי אוכל", emoji: "🛵", amount: 130, visits: 6, trend: "+8% מחודש שעבר" };
      return body;
    }

    const nestBody    = createBistro(foodZone);
    const superBody   = createFreshMarket(foodZone);
    const coffeeBody  = createCoffeeHouse(foodZone);
    const woltBody    = createWoltDepot(foodZone);
    interactiveBuildings.push(nestBody, superBody, coffeeBody, woltBody);

    createPlotSite("food_bistro", "מסעדות וביסטרו", "אוכל בחוץ ובילויים", -2.3, -2.2, foodZone, nestBody.userData);
    createPlotSite("food_super",  "סופרמרקט ומזון", "קניות מצרכים",       2.3, -2.2, foodZone, superBody.userData);
    createPlotSite("food_coffee", "בתי קפה ומאפים", "אספרסו ומאפים",    -2.3, 2.2, foodZone, coffeeBody.userData);
    createPlotSite("food_wolt",   "משלוחי אוכל",    "וולט ומשלוחים",      2.3, 2.2, foodZone, woltBody.userData);

    // ────────────────────────────────────────────────────────────────
    // 🛍️  SHOPPING PROMENADE (Paved Plaza & Teak Boardwalk)
    // ────────────────────────────────────────────────────────────────
    const shopZone = new THREE.Group();
    shopZone.position.set(6.8, 0.08, -6.8);
    root.add(shopZone);
    shopZone.add(mesh(roundedBox(8.8, 0.22, 8.8, 0.6), new THREE.MeshStandardMaterial({ map: shopPlazaTex(), bumpMap: shopPlazaBump(), bumpScale: 0.12, roughness: 0.72 }), 0, 0.11, 0, false, true));

    // Inlaid Raised Teak Boardwalk Strip across the shops
    const boardwalk = mesh(roundedBox(8.2, 0.04, 1.8, 0.15), mat(0x78350f, 0.8, 0.3), 0, 0.24, 0);
    for (let bx = -3.8; bx <= 3.8; bx += 0.40) {
      boardwalk.add(mesh(new THREE.BoxGeometry(0.02, 0.045, 1.8), mat(0x451a03, 0.9), bx, 0, 0));
    }
    shopZone.add(boardwalk);

    // 👗 BOUTIQUE SHOP (Width: 2.5, Depth: 2.4 - Spaced at x: -2.3, z: -2.2)
    function createBoutique(parent) {
      const g = new THREE.Group(); g.position.set(-2.3, 0.22, -2.2); parent.add(g);
      buildingRoots["shop_boutique"] = g; g.userData = { targetScaleY: 1.0, targetScaleXZ: 1.0 };
      const bGroup = new THREE.Group(); g.add(bGroup);
      const sGroup = createTier1Stall("boutique"); g.add(sGroup);
      g.userData.buildingGroup = bGroup; g.userData.stallGroup = sGroup;

      const body = mesh(roundedBox(2.5, 2.6, 2.4, 0.18), new THREE.MeshStandardMaterial({ map: boutiqueStuccoTex(), roughness: 0.65 }), 0, 0, 0);
      bGroup.add(body);
      addWindows(bGroup, 2, 2, 2.5, 2.6, 2.4, 1.22);

      [-1.1, -0.36, 0.36, 1.1].forEach(px =>
        bGroup.add(mesh(new THREE.BoxGeometry(0.08, 2.6, 0.10), mat(0xf4c542, 0.2, 0.85), px, 1.3, 1.23))
      );
      bGroup.add(mesh(new THREE.BoxGeometry(2.6, 0.18, 0.15), mat(0xf4c542, 0.2, 0.85), 0, 2.70, 1.21));
      bGroup.add(mesh(new THREE.BoxGeometry(2.6, 0.12, 2.5), mat(0x0f172a, 0.65), 0, 2.64, 0));

      // Rooftop Sky-Lounge (Teak deck, sun loungers, parasol umbrella, glass safety railing, potted palm)
      const roofDeck = new THREE.Group(); roofDeck.position.set(0, 2.70, 0); bGroup.add(roofDeck);
      roofDeck.add(mesh(new THREE.BoxGeometry(2.4, 0.04, 2.2), mat(0xa16207, 0.8), 0, 0.02, 0));
      const glassRailM = new THREE.MeshStandardMaterial({ color: 0x38bdf8, transparent: true, opacity: 0.5, roughness: 0.1 });
      [-1.15, 1.15].forEach(rx => roofDeck.add(mesh(new THREE.BoxGeometry(0.02, 0.42, 2.2), glassRailM, rx, 0.23, 0)));
      [-1.05, 1.05].forEach(rz => roofDeck.add(mesh(new THREE.BoxGeometry(2.3, 0.42, 0.02), glassRailM, 0, 0.23, rz)));
      
      const parasol = new THREE.Group(); parasol.position.set(0.65, 0.04, -0.45); roofDeck.add(parasol);
      parasol.add(mesh(new THREE.CylinderGeometry(0.015, 0.015, 1.1, 6), mat(0xd1d5db, 0.2, 0.9), 0, 0.55, 0));
      const pCanopy = mesh(new THREE.ConeGeometry(0.65, 0.22, 8), new THREE.MeshStandardMaterial({ map: stripeTex("#f43f5e", "#ffffff", 6) }), 0, 1.05, 0);
      pCanopy.rotation.y = 0.4; parasol.add(pCanopy);
      
      [-0.45, -0.05].forEach(lx => {
        const chair = new THREE.Group(); chair.position.set(lx, 0.04, -0.45); roofDeck.add(chair);
        chair.add(mesh(new THREE.BoxGeometry(0.28, 0.06, 0.65), mat(0x78350f, 0.8), 0, 0.06, 0));
        const headRest = mesh(new THREE.BoxGeometry(0.28, 0.05, 0.25), mat(0x78350f, 0.8), 0, 0.14, -0.22);
        headRest.rotation.x = -0.55; chair.add(headRest);
        chair.add(mesh(new THREE.BoxGeometry(0.24, 0.04, 0.60), mat(0xfbcfe8, 0.6), 0, 0.09, 0));
      });
      
      const roofPot = new THREE.Group(); roofPot.position.set(-0.75, 0.04, 0.65); roofDeck.add(roofPot);
      roofPot.add(mesh(new THREE.CylinderGeometry(0.14, 0.10, 0.24, 8), mat(0xc2410c, 0.8), 0, 0.12, 0));
      roofPot.add(mesh(new THREE.SphereGeometry(0.24, 8, 8), mat(0x16a34a, 0.85), 0, 0.35, 0));

      bGroup.add(mesh(new THREE.BoxGeometry(2.0, 0.52, 0.10), new THREE.MeshStandardMaterial({ map: signTex("🛍️ קניות וביגוד", "Clothing & Shopping", "#ffffff", "#db2777"), emissive: 0xdb2777, emissiveIntensity: 0.55 }), 0, 2.15, 1.28));
      const awn3 = mesh(new THREE.BoxGeometry(2.3, 0.10, 0.95), new THREE.MeshStandardMaterial({ map: stripeTex("#ee7cc4", "#ffffff", 6), roughness: 0.8 }), 0, 1.38, 1.30);
      awn3.rotation.x = -0.25; bGroup.add(awn3);

      const vitrine = new THREE.Group(); vitrine.position.set(0, 0, 1.25); bGroup.add(vitrine);
      vitrine.add(mesh(new THREE.BoxGeometry(1.5, 1.1, 0.10), mat(0xf4c542, 0.2, 0.85), 0, 0.55, 0));
      vitrine.add(mesh(new THREE.BoxGeometry(1.35, 0.95, 0.08), new THREE.MeshStandardMaterial({ color: 0xfef9ee, emissive: 0xfef08a, emissiveIntensity: 2.5, transparent: true, opacity: 0.92 }), 0, 0.55, 0.02));
      vitrine.add(mesh(new THREE.CylinderGeometry(0.07, 0.10, 0.45, 10), mat(0xee7cc4, 0.6), 0, 0.38, 0.03));
      vitrine.add(mesh(new THREE.CylinderGeometry(0.025, 0.025, 0.18, 8), mat(0x64748b, 0.5), 0, 0.72, 0.03));
      vitrine.add(mesh(new THREE.SphereGeometry(0.055, 8, 8), mat(0xfbcfe8, 0.6), 0, 0.84, 0.03));

      bGroup.add(mesh(new THREE.BoxGeometry(1.0, 0.025, 1.4), mat(0xb91c1c, 0.85), 0, 0.02, 1.95));
      [-0.55, 0.55].forEach(sx => {
        const pole = mesh(new THREE.CylinderGeometry(0.022, 0.022, 0.38, 8), mat(0xf4c542, 0.2, 0.9), sx, 0.19, 1.95);
        pole.add(mesh(new THREE.SphereGeometry(0.045, 8, 8), mat(0xf4c542, 0.2, 0.9), 0, 0.20, 0));
        bGroup.add(pole);
      });

      // 🛍️ Cynical Satire Element: Detailed Designer Shopping Bags & Metallic Gold Hanger Grounded
      const shoppingChaos = new THREE.Group(); bGroup.add(shoppingChaos);
      shoppingChaos.visible = false;
      g.userData.shoppingChaos = shoppingChaos;

      const bagPalette = [
        { bag: 0xec4899, tissue: 0xffffff },
        { bag: 0x18181b, tissue: 0xf4c542 },
        { bag: 0xf4c542, tissue: 0xffffff },
        { bag: 0xe11d48, tissue: 0xfce7f3 },
        { bag: 0xffffff, tissue: 0xec4899 }
      ];
      bagPalette.forEach((item, i) => {
        const bagG = new THREE.Group();
        bagG.position.set(-0.75 + (i % 3) * 0.32, Math.floor(i / 3) * 0.32, 1.65 + (i % 2) * 0.16);
        bagG.rotation.y = (i * 0.45) - 0.4;
        bagG.add(mesh(new THREE.BoxGeometry(0.28, 0.32, 0.16), mat(item.bag, 0.4), 0, 0.16, 0));
        [-0.08, 0.08].forEach(hx => {
          bagG.add(mesh(new THREE.TorusGeometry(0.05, 0.008, 6, 12, Math.PI), mat(0x18181b, 0.9), hx, 0.32, 0));
        });
        const tissue = mesh(new THREE.ConeGeometry(0.08, 0.12, 6), mat(item.tissue, 0.9), 0, 0.35, 0);
        tissue.rotation.z = (i % 2 === 0 ? 0.25 : -0.25);
        bagG.add(tissue);
        shoppingChaos.add(bagG);
      });

      [0, 0.12, 0.24].forEach((sy, i) => {
        const sBox = mesh(new THREE.BoxGeometry(0.38, 0.10, 0.26), mat(i === 1 ? 0xf4c542 : 0x18181b, 0.3), 0.75, 0.05 + sy, 1.65);
        sBox.rotation.y = (i * 0.15) + 0.2;
        shoppingChaos.add(sBox);
      });

      const goldHanger = new THREE.Group(); goldHanger.position.set(0, 3.0, 0); shoppingChaos.add(goldHanger);
      const goldMat = new THREE.MeshStandardMaterial({ color: 0xfacc15, metalness: 0.92, roughness: 0.12, emissive: 0xca8a04, emissiveIntensity: 0.4 });
      goldHanger.add(mesh(new THREE.TorusGeometry(0.38, 0.028, 10, 20, Math.PI), goldMat, 0, 0, 0));
      goldHanger.add(mesh(new THREE.BoxGeometry(0.76, 0.035, 0.035), goldMat, 0, 0, 0));
      goldHanger.add(mesh(new THREE.TorusGeometry(0.09, 0.022, 10, 16, Math.PI * 1.5), goldMat, 0, 0.44, 0));
      animObjects.push({ type: "rotate_y", ref: goldHanger, speed: 0.9 });

      const bSpot = new THREE.SpotLight(0xffffff, 2.5, 4.5, 0.50, 0.6);
      bSpot.position.set(0, 3.2, 1.2); bSpot.target.position.set(0, 0.6, 1.25);
      bGroup.add(bSpot); bGroup.add(bSpot.target);

      body.userData = { id: "shop_boutique", district: "shopping", name: "קניות וביגוד", emoji: "🛍️", amount: 520, visits: 3, trend: "+15% מחודש שעבר" };
      return body;
    }

    // 📱 TECH PAVILION (Width: 2.4, Depth: 2.3 - Spaced at x: 2.3, z: -2.2)
    function createTechPavilion(parent) {
      const g = new THREE.Group(); g.position.set(2.3, 0.22, -2.2); parent.add(g);
      buildingRoots["shop_tech"] = g; g.userData = { targetScaleY: 1.0, targetScaleXZ: 1.0 };
      const bGroup = new THREE.Group(); g.add(bGroup);
      const sGroup = createTier1Stall("tech"); g.add(sGroup);
      g.userData.buildingGroup = bGroup; g.userData.stallGroup = sGroup;

      [[-0.9,-0.85],[0.9,-0.85],[-0.9,0.85],[0.9,0.85]].forEach(([lx,lz]) =>
        bGroup.add(mesh(new THREE.CylinderGeometry(0.035, 0.05, 0.48, 8), mat(0x94a3b8, 0.3, 0.9), lx, 0.24, lz))
      );
      const body = mesh(roundedBox(2.4, 2.3, 2.3, 0.16),
        new THREE.MeshStandardMaterial({ map: techGridTex(), roughness: 0.25, metalness: 0.85 }), 0, 0.48, 0);
      bGroup.add(body);
      bGroup.add(mesh(new THREE.BoxGeometry(2.35, 0.12, 2.25), mat(0x38bdf8, 0.75, 0.8, 0x0284c7, 1.2), 0, 1.70, 0));
      
      // Floating Holographic Ring above roof
      const holoRing = mesh(new THREE.TorusGeometry(0.55, 0.035, 8, 24), new THREE.MeshStandardMaterial({ color: 0x38bdf8, emissive: 0x38bdf8, emissiveIntensity: 2.8, transparent: true, opacity: 0.85 }), 0, 2.75, 0);
      holoRing.rotation.x = Math.PI / 2.5;
      bGroup.add(holoRing);
      animObjects.push({ type: "rotate_y", ref: holoRing, speed: 0.8 });

      bGroup.add(mesh(new THREE.BoxGeometry(2.0, 0.48, 0.10), new THREE.MeshStandardMaterial({ map: signTex("📱 אלקטרוניקה", "Electronics & Tech", "#38bdf8", "#0f0d17"), emissive: 0x38bdf8, emissiveIntensity: 0.55 }), 0, 1.88, 1.20));

      // Display Tables with Open Laptops & Tablets
      [-0.5, 0.5].forEach(tx => {
        const tbl = new THREE.Group(); tbl.position.set(tx, 0.48, 0); bGroup.add(tbl);
        tbl.add(mesh(new THREE.BoxGeometry(0.55, 0.32, 0.9), mat(0xd4a96a, 0.72), 0, 0.16, 0));
        const lid = mesh(new THREE.BoxGeometry(0.20, 0.015, 0.15), mat(0xd1d5db, 0.2, 0.9), 0, 0.35, 0.03);
        lid.rotation.x = -1.1; tbl.add(lid);
        tbl.add(mesh(new THREE.BoxGeometry(0.18, 0.13, 0.012), new THREE.MeshStandardMaterial({ color: 0xffffff, emissive: 0x38bdf8, emissiveIntensity: 3.2 }), 0, 0.42, -0.04));
        tbl.add(mesh(new THREE.BoxGeometry(0.20, 0.008, 0.12), mat(0xd1d5db, 0.2, 0.9), 0, 0.33, 0.05));
      });

      addLight("point", 0x38bdf8, 1.4, 4.8, 0, 1.4, 0, bGroup);

      body.userData = { id: "shop_tech", district: "shopping", name: "מוצרי חשמל ואלקטרוניקה", emoji: "📱", amount: 300, visits: 1, trend: "הוצאה חודשית" };
      return body;
    }

    // ✈️ TRAVEL GATE (Width: 2.4, Depth: 2.3 - Spaced at x: -2.3, z: 2.3)
    function createTravelGate(parent) {
      const g = new THREE.Group(); g.position.set(-2.3, 0.22, 2.3); parent.add(g);
      buildingRoots["shop_travel"] = g; g.userData = { targetScaleY: 1.0, targetScaleXZ: 1.0 };
      const bGroup = new THREE.Group(); g.add(bGroup);
      const sGroup = createTier1Stall("travel"); g.add(sGroup);
      g.userData.buildingGroup = bGroup; g.userData.stallGroup = sGroup;

      const body = mesh(roundedBox(2.4, 1.8, 2.3, 0.16), new THREE.MeshStandardMaterial({ map: travelMosaicTex(), roughness: 0.65 }), 0, 0, 0);
      bGroup.add(body);
      addWindows(bGroup, 1, 3, 2.4, 1.8, 2.3, 1.17);

      bGroup.add(mesh(new THREE.CylinderGeometry(1.8, 1.8, 0.13, 12, 1, false, 0, Math.PI), mat(0x0f172a, 0.7), 0, 1.95, 0));
      bGroup.add(mesh(new THREE.BoxGeometry(2.4, 0.38, 0.08), new THREE.MeshStandardMaterial({ color: 0x3b82f6, transparent: true, opacity: 0.65, emissive: 0x1d4ed8, emissiveIntensity: 0.4 }), 0, 1.62, 1.18));
      bGroup.add(mesh(new THREE.BoxGeometry(2.0, 0.48, 0.10), new THREE.MeshStandardMaterial({ map: signTex("✈️ חופשות וטיסות", "Vacations & Flights", "#ffffff", "#2563eb"), emissive: 0x2563eb, emissiveIntensity: 0.45 }), 0, 1.76, 1.20));

      // Airplane Flying Spire with Jet Turbines & Tail
      const planePole = new THREE.Group(); planePole.position.set(0.4, 2.0, 0); bGroup.add(planePole);
      planePole.add(mesh(new THREE.CylinderGeometry(0.022, 0.022, 0.85, 8), mat(0x94a3b8, 0.4, 0.7), 0, 0.42, 0));
      const plane = new THREE.Group(); plane.position.set(0, 0.90, 0); planePole.add(plane);
      plane.add(mesh(new THREE.CylinderGeometry(0.050, 0.040, 0.58, 10), mat(0xf8fafc, 0.3, 0.5), 0, 0, 0));
      plane.rotation.z = Math.PI / 2;
      // Main Wings
      plane.add(mesh(new THREE.BoxGeometry(0.58, 0.025, 0.18), mat(0x2563eb, 0.3, 0.5), 0, 0, 0));
      // Jet Turbines
      [-0.14, 0.14].forEach(jx => {
        plane.add(mesh(new THREE.CylinderGeometry(0.022, 0.022, 0.14, 8), mat(0x94a3b8, 0.4), jx, -0.035, 0));
      });
      // Vertical Tail Fin
      plane.add(mesh(new THREE.BoxGeometry(0.18, 0.15, 0.025), mat(0x2563eb, 0.3, 0.5), -0.22, 0.08, 0));
      animObjects.push({ type: "rotate_y", ref: planePole, speed: 0.45 });

      // Luggage Trolley with 3 Suitcases Grounded
      const cart = mesh(new THREE.BoxGeometry(0.72, 0.05, 0.42), mat(0x94a3b8, 0.4, 0.6), 0.55, 0.025, 1.45); bGroup.add(cart);
      [[-0.20, 0xef4444], [0.20, 0xfacc15], [0, 0x06b6d4]].forEach((s, idx) => {
        const sc = mesh(new THREE.BoxGeometry(0.24, 0.20, 0.16), mat(s[1], 0.5), s[0], 0.10 + (idx === 2 ? 0.05 : 0), 0);
        sc.add(mesh(new THREE.BoxGeometry(0.06, 0.03, 0.03), mat(0x18181b, 0.8), 0, 0.11, 0));
        cart.add(sc);
      });

      body.userData = { id: "shop_travel", district: "shopping", name: "חופשות וטיסות", emoji: "✈️", amount: 0, visits: 0, trend: "ללא שינוי" };
      return body;
    }

    // 🎮 ARCADE & CYBER GAMING (Width: 2.4, Depth: 2.3 - Spaced at x: 2.3, z: 2.3)
    function createArcade(parent) {
      const g = new THREE.Group(); g.position.set(2.3, 0.22, 2.3); parent.add(g);
      buildingRoots["shop_arcade"] = g; g.userData = { targetScaleY: 1.0, targetScaleXZ: 1.0 };
      const bGroup = new THREE.Group(); g.add(bGroup);
      const sGroup = createTier1Stall("arcade"); g.add(sGroup);
      g.userData.buildingGroup = bGroup; g.userData.stallGroup = sGroup;

      const body = mesh(roundedBox(2.4, 2.1, 2.3, 0.18), new THREE.MeshStandardMaterial({ map: arcadeNeonTex(), roughness: 0.55 }), 0, 0, 0);
      bGroup.add(body);

      const archM = new THREE.MeshStandardMaterial({ color: 0xee7cc4, emissive: 0xee7cc4, emissiveIntensity: 3.5, roughness: 0.3 });
      bGroup.add(mesh(new THREE.TorusGeometry(1.2, 0.045, 10, 30, Math.PI), archM, 0, 2.25, 1.18));
      [-1.12, 1.12].forEach(px => {
        bGroup.add(mesh(new THREE.CylinderGeometry(0.035, 0.035, 1.6, 8), new THREE.MeshStandardMaterial({ color: 0xa855f7, emissive: 0xa855f7, emissiveIntensity: 3.5, roughness: 0.3 }), px, 1.25, 1.18));
      });
      bGroup.add(mesh(new THREE.BoxGeometry(1.9, 0.55, 0.12), new THREE.MeshStandardMaterial({ map: signTex("🎭 בילוי ופנאי", "Entertainment & Leisure", "#ffffff", "#7c3aed"), emissive: 0x7c3aed, emissiveIntensity: 0.65 }), 0, 1.78, 1.22));

      // Arcade Cabinets Grounded
      const cabinetG = new THREE.Group(); cabinetG.position.set(-0.4, 0, 1.08); bGroup.add(cabinetG);
      cabinetG.add(mesh(new THREE.BoxGeometry(0.55, 0.95, 0.45), mat(0x1e1b4b, 0.8), 0, 0.48, 0));
      const scrCanvas = arcadeTex(0);
      const scrTex = new THREE.CanvasTexture(scrCanvas);
      const screen = mesh(new THREE.BoxGeometry(0.42, 0.32, 0.04), new THREE.MeshStandardMaterial({ map: scrTex, emissive: 0xee7cc4, emissiveIntensity: 1.6 }), 0, 0.65, 0.23);
      cabinetG.add(screen);
      animObjects.push({ type: "arcade_screen", ref: screen, tex: scrTex, frame: 0, timer: 0 });
      cabinetG.add(mesh(new THREE.CylinderGeometry(0.020, 0.020, 0.10, 8), mat(0xe11d48, 0.5), 0.08, 0.32, 0.23));
      cabinetG.add(mesh(new THREE.SphereGeometry(0.035, 8, 8), mat(0xe11d48, 0.5), 0.08, 0.42, 0.23));

      const cab2 = cabinetG.clone(); cab2.position.set(0.45, 0, 1.08); bGroup.add(cab2);

      const neonL = new THREE.PointLight(0xff00ff, 2.2, 4.8);
      neonL.position.set(0, 1.8, 1.3); bGroup.add(neonL);
      animObjects.push({ type: "flicker", ref: neonL, base: 2.2, phase: 0 });

      body.userData = { id: "shop_arcade", district: "shopping", name: "בילוי ופנאי", emoji: "🎭", amount: 150, visits: 2, trend: "+5% מחודש שעבר" };
      return body;
    }

    const boutiqueBody = createBoutique(shopZone);
    const techBody     = createTechPavilion(shopZone);
    const travelBody   = createTravelGate(shopZone);
    const arcadeBody   = createArcade(shopZone);
    interactiveBuildings.push(boutiqueBody, techBody, travelBody, arcadeBody);

    createPlotSite("shop_boutique", "אופנה וביגוד",        "ביגוד, נעליים ואקססוריז", -2.3, -2.2, shopZone, boutiqueBody.userData);
    createPlotSite("shop_tech",     "טכנולוגיה וגאדג'טים", "מחשבים וציוד היקפי",       2.3, -2.2, shopZone, techBody.userData);
    createPlotSite("shop_travel",   "נסיעות וטיסות",        "חופשות ופנאי",           -2.3, 2.2, shopZone, travelBody.userData);
    createPlotSite("shop_arcade",   "בילויים וגיימינג",     "קולנוע, משחקים ואטרקציות", 2.3, 2.2, shopZone, arcadeBody.userData);

    // ────────────────────────────────────────────────────────────────
    // 🏠  RESIDENCE DISTRICT (Garden Terraces & Brick Courtyards)
    // ────────────────────────────────────────────────────────────────
    const houseZone = new THREE.Group();
    houseZone.position.set(6.8, 0.08, 6.0);
    root.add(houseZone);
    houseZone.add(mesh(roundedBox(8.8, 0.22, 8.8, 0.6), new THREE.MeshStandardMaterial({ map: housePlazaTex(), bumpMap: housePlazaBump(), bumpScale: 0.12, roughness: 0.78 }), 0, 0.11, 0, false, true));

    // Raised Garden Courtyard with Grass & Brick Retaining Border
    const gardenBed = mesh(roundedBox(4.4, 0.08, 4.4, 0.2), mat(0x15803d, 0.9), 2.2, 0.24, 2.2, false, true);
    gardenBed.add(mesh(new THREE.BoxGeometry(4.5, 0.12, 0.14), mat(0x9a3412, 0.8), 0, 0.02, 2.2));
    gardenBed.add(mesh(new THREE.BoxGeometry(4.5, 0.12, 0.14), mat(0x9a3412, 0.8), 0, 0.02, -2.2));
    gardenBed.add(mesh(new THREE.BoxGeometry(0.14, 0.12, 4.4), mat(0x9a3412, 0.8), 2.2, 0.02, 0));
    gardenBed.add(mesh(new THREE.BoxGeometry(0.14, 0.12, 4.4), mat(0x9a3412, 0.8), -2.2, 0.02, 0));
    houseZone.add(gardenBed);

    // 🏢 GRAND RESIDENCE TOWER (Width: 2.6, Depth: 2.6 - Spaced at x: -2.2, z: -2.0)
    function createResidenceTower(parent) {
      const g = new THREE.Group(); g.position.set(-2.2, 0.22, -2.0); parent.add(g);
      buildingRoots["house_tower"] = g; g.userData = { targetScaleY: 1.0, targetScaleXZ: 1.0 };
      const bGroup = new THREE.Group(); g.add(bGroup);
      const sGroup = createTier1Stall("housing"); g.add(sGroup);
      g.userData.buildingGroup = bGroup; g.userData.stallGroup = sGroup;

      const body = mesh(roundedBox(2.6, 3.8, 2.6, 0.18), new THREE.MeshStandardMaterial({ map: residenceStoneTex(), bumpMap: brickBumpTex(), bumpScale: 0.08, roughness: 0.65 }), 0, 0, 0);
      bGroup.add(body);
      addWindows(bGroup, 4, 2, 2.6, 3.8, 2.6, 1.32);
      bGroup.add(mesh(new THREE.BoxGeometry(2.8, 0.18, 2.8), mat(0xd1d5db, 0.6, 0.3), 0, 3.90, 0));

      for (let fl = 1; fl <= 4; fl++) {
        const balc = new THREE.Group(); balc.position.set(0, fl * 0.82, 0); bGroup.add(balc);
        balc.add(mesh(new THREE.CylinderGeometry(0.60, 0.60, 0.05, 16, 1, false, -Math.PI * 0.5, Math.PI), mat(0xd1d5db, 0.55, 0.3), 0, 0.025, 1.35));
        for (let bi = -3; bi <= 3; bi++) {
          const bx = bi * 0.15;
          const bz = 1.35 + Math.sqrt(Math.max(0, 0.60 * 0.60 - bx * bx));
          balc.add(mesh(new THREE.CylinderGeometry(0.010, 0.010, 0.24, 6), mat(0x374151, 0.5, 0.6), bx, 0.14, bz, false, false));
        }
        balc.add(mesh(new THREE.BoxGeometry(0.55, 0.08, 0.12), mat(0x15803d, 0.8), 0, 0.08, 1.38));
        balc.add(mesh(new THREE.BoxGeometry(0.55, 0.05, 0.10), mat(fl % 2 === 0 ? 0xf43f5e : 0xf472b6, 0.7), 0, 0.12, 1.40));
        
        [-0.18, 0, 0.18].forEach(ix => {
          balc.add(mesh(new THREE.SphereGeometry(0.045, 5, 5), mat(0x16a34a, 0.85), ix, -0.04, 1.42));
          balc.add(mesh(new THREE.SphereGeometry(0.035, 5, 5), mat(0x22c55e, 0.85), ix, -0.09, 1.42));
        });
      }

      bGroup.add(mesh(new THREE.BoxGeometry(2.2, 0.52, 0.10), new THREE.MeshStandardMaterial({ map: signTex("🏠 שכירות ומשכנתא", "Rent & Mortgage", "#ffffff", "#4338ca"), emissive: 0x4338ca, emissiveIntensity: 0.45 }), 0, 1.85, 1.36));

      // Rooftop Penthouse Terrace with Shimmering Pool & Sun Deck
      const deck = new THREE.Group(); deck.position.set(0, 4.0, 0); bGroup.add(deck);
      deck.add(mesh(new THREE.BoxGeometry(1.3, 0.12, 1.1), mat(0x0e7490, 0.4), -0.5, 0, 0));
      const poolWater = mesh(new THREE.BoxGeometry(1.2, 0.05, 1.0), new THREE.MeshStandardMaterial({ color: 0x38bdf8, roughness: 0.02, metalness: 0.5, emissive: 0x0284c7, emissiveIntensity: 1.8 }), -0.5, 0.08, 0);
      deck.add(poolWater);
      animObjects.push({ type: "water_shimmer", ref: poolWater, phase: 0 });
      [[0.45,-0.45],[0.45,0.45],[1.15,-0.45],[1.15,0.45]].forEach(([px,pz]) =>
        deck.add(mesh(new THREE.CylinderGeometry(0.028, 0.032, 0.75, 8), mat(0x78350f, 0.8), px, 0.38, pz))
      );
      deck.add(mesh(new THREE.BoxGeometry(0.90, 0.040, 1.0), mat(0x78350f, 0.78), 0.80, 0.76, 0));

      // Rooftop Solar Water Heater (Dud Shemesh)
      const dud = new THREE.Group(); dud.position.set(0.7, 4.15, -0.6); bGroup.add(dud);
      dud.add(mesh(new THREE.CylinderGeometry(0.12, 0.12, 0.48, 12), mat(0xf8fafc, 0.3, 0.8), 0, 0.25, 0));
      const dudPanel = mesh(new THREE.BoxGeometry(0.42, 0.04, 0.38), mat(0x0f172a, 0.2, 0.9), 0, 0.12, 0.32);
      dudPanel.rotation.x = 0.45; dud.add(dudPanel);

      addLight("point", 0x38bdf8, 1.2, 3.2, -0.5, 4.2, 0, bGroup);

      body.userData = { id: "house_tower", district: "housing", name: "שכירות ומשכנתא", emoji: "🏠", amount: 1850, visits: 1, trend: "הוצאה קבועה" };
      return body;
    }

    // ⚡ UTILITIES SUBSTATION (Width: 2.4, Depth: 2.4 - Spaced at x: 2.4, z: -2.0)
    function createUtilitiesHub(parent) {
      const g = new THREE.Group(); g.position.set(2.4, 0.22, -2.0); parent.add(g);
      buildingRoots["house_util"] = g; g.userData = { targetScaleY: 1.0, targetScaleXZ: 1.0 };
      const bGroup = new THREE.Group(); g.add(bGroup);
      const sGroup = createTier1Stall("util"); g.add(sGroup);
      g.userData.buildingGroup = bGroup; g.userData.stallGroup = sGroup;

      const body = mesh(roundedBox(2.4, 1.9, 2.4, 0.15), new THREE.MeshStandardMaterial({ map: utilHazardTex(), roughness: 0.75, metalness: 0.35 }), 0, 0, 0);
      bGroup.add(body);
      [-1.05, 1.05].forEach(px =>
        bGroup.add(mesh(new THREE.BoxGeometry(0.24, 1.9, 0.24), mat(0x6b7280, 0.85), px, 0.95, 1.22))
      );
      bGroup.add(mesh(new THREE.BoxGeometry(2.5, 0.24, 2.5), mat(0x4b5563, 0.85), 0, 2.02, 0));
      bGroup.add(mesh(new THREE.BoxGeometry(1.9, 0.48, 0.10), new THREE.MeshStandardMaterial({ map: signTex("💡 חשבונות בית", "Bills & Utilities", "#ffffff", "#047857"), emissive: 0x047857, emissiveIntensity: 0.42 }), 0, 1.58, 1.25));

      // Photovoltaic Solar Panels
      for (let si = -0.70; si <= 0.70; si += 0.70) {
        const panel = mesh(new THREE.BoxGeometry(0.70, 0.055, 0.60), new THREE.MeshStandardMaterial({ map: solarTex(), roughness: 0.18, metalness: 0.85 }), si, 2.22, 0);
        panel.rotation.x = 0.38; bGroup.add(panel);
        bGroup.add(mesh(new THREE.BoxGeometry(0.05, 0.18, 0.05), mat(0x94a3b8, 0.4, 0.7), si, 2.12, 0.18));
      }

      // Wind Turbine Generator
      const turbine = new THREE.Group(); turbine.position.set(-0.75, 2.15, -0.65); bGroup.add(turbine);
      turbine.add(mesh(new THREE.CylinderGeometry(0.03, 0.05, 1.1, 8), mat(0xf8fafc, 0.4, 0.8), 0, 0.55, 0));
      const blades = new THREE.Group(); blades.position.set(0, 1.1, 0.05); turbine.add(blades);
      for (let bi = 0; bi < 3; bi++) {
        const b = mesh(new THREE.BoxGeometry(0.04, 0.38, 0.015), mat(0xf8fafc, 0.4, 0.8), 0, 0.19, 0);
        b.rotation.z = bi * (Math.PI * 2 / 3);
        blades.add(b);
      }
      animObjects.push({ type: "rotate_z", ref: blades, speed: 2.8 });

      // Flashing Safety Beacon Mast
      const mast = new THREE.Group(); mast.position.set(0.9, 2.15, -0.9); bGroup.add(mast);
      mast.add(mesh(new THREE.CylinderGeometry(0.024, 0.038, 1.35, 8), mat(0x94a3b8, 0.4, 0.8), 0, 0.68, 0));
      const beacon = mesh(new THREE.SphereGeometry(0.065, 8, 8), new THREE.MeshStandardMaterial({ color: 0xef4444, emissive: 0xef4444, emissiveIntensity: 2.5 }), 0, 1.38, 0, false, false);
      mast.add(beacon);
      const beaconL = new THREE.PointLight(0xef4444, 1.2, 2.8); beaconL.position.set(0, 1.38, 0); mast.add(beaconL);
      animObjects.push({ type: "beacon", ref: beaconL, refM: beacon, phase: 0 });

      body.userData = { id: "house_util", district: "housing", name: "חשבונות בית (חשמל/מים/ארנונה)", emoji: "💡", amount: 450, visits: 3, trend: "-2% מחודש שעבר" };
      return body;
    }

    // 📶 SUBSCRIPTIONS SPIRE (Width: 3.2, Depth: 2.2 - Spaced at x: 0.2, z: 2.3)
    function createSubscriptionsSpire(parent) {
      const g = new THREE.Group(); g.position.set(0.2, 0.22, 2.3); parent.add(g);
      buildingRoots["house_subs"] = g; g.userData = { targetScaleY: 1.0, targetScaleXZ: 1.0 };
      const bGroup = new THREE.Group(); g.add(bGroup);
      const sGroup = createTier1Stall("subs"); g.add(sGroup);
      g.userData.buildingGroup = bGroup; g.userData.stallGroup = sGroup;

      const body = mesh(roundedBox(3.2, 2.0, 2.2, 0.18), new THREE.MeshStandardMaterial({ map: subsIndigoTex(), roughness: 0.55 }), 0, 0, 0);
      bGroup.add(body);
      addWindows(bGroup, 1, 3, 3.2, 2.0, 2.2, 1.12);

      bGroup.add(mesh(new THREE.SphereGeometry(0.65, 16, 10, 0, Math.PI * 2, 0, Math.PI * 0.5), mat(0x312e81, 0.65, 0.3), 0, 2.15, 0));
      bGroup.add(mesh(new THREE.CylinderGeometry(0.65, 0.70, 0.18, 16), mat(0x312e81, 0.65), 0, 2.01, 0));
      bGroup.add(mesh(new THREE.BoxGeometry(2.0, 0.48, 0.10), new THREE.MeshStandardMaterial({ map: signTex("📱 מנויים חודשיים", "Subscriptions", "#ffffff", "#9333ea"), emissive: 0x9333ea, emissiveIntensity: 0.50 }), 0, 1.60, 1.14));

      const dishGroup = new THREE.Group(); dishGroup.position.set(0, 2.65, 0); bGroup.add(dishGroup);
      dishGroup.add(mesh(new THREE.CylinderGeometry(0.022, 0.022, 0.48, 8), mat(0x94a3b8, 0.4, 0.8), 0, 0.24, 0));
      const dish = new THREE.Group(); dish.position.set(0, 0.50, 0); dishGroup.add(dish);
      dish.add(mesh(new THREE.SphereGeometry(0.30, 14, 8, 0, Math.PI * 2, 0, Math.PI * 0.55), mat(0xd1d5db, 0.3, 0.7), 0, 0, 0));
      dish.rotation.x = -0.6;
      animObjects.push({ type: "rotate_y", ref: dishGroup, speed: 0.35 });

      // 📡 Cynical Satire Element: NASA-Grade Satellite Forest & Blinking Aviation Beacon
      const subsChaos = new THREE.Group(); bGroup.add(subsChaos);
      subsChaos.visible = false;
      g.userData.subsChaos = subsChaos;

      const dishConfigs = [
        { x: -0.95, z: 0.35, rotX: -0.45, rotY: 0.6, scale: 0.26 },
        { x: 0.85, z: -0.45, rotX: -0.35, rotY: -1.1, scale: 0.24 },
        { x: 0.75, z: 0.45, rotX: -0.55, rotY: 2.1, scale: 0.28 }
      ];
      dishConfigs.forEach(cfg => {
        const dG = new THREE.Group(); dG.position.set(cfg.x, 2.35, cfg.z); dG.rotation.set(cfg.rotX, cfg.rotY, 0);
        dG.add(mesh(new THREE.CylinderGeometry(0.018, 0.024, 0.28, 6), mat(0x64748b, 0.6), 0, -0.14, 0));
        const dishMesh = mesh(new THREE.SphereGeometry(cfg.scale, 16, 10, 0, Math.PI * 2, 0, Math.PI * 0.55), mat(0xe2e8f0, 0.3, 0.8), 0, 0, 0);
        dG.add(dishMesh);
        dG.add(mesh(new THREE.CylinderGeometry(0.012, 0.012, cfg.scale * 1.1, 6), mat(0x1e293b, 0.8), 0, 0, cfg.scale * 0.55));
        dG.add(mesh(new THREE.SphereGeometry(0.035, 8, 8), mat(0x38bdf8, 0.2, 0.9), 0, 0, cfg.scale * 1.1));
        subsChaos.add(dG);
      });

      const towerMast = mesh(new THREE.CylinderGeometry(0.015, 0.035, 1.45, 6), mat(0x94a3b8, 0.5, 0.8), -0.75, 2.85, -0.65);
      const beaconLight = mesh(new THREE.SphereGeometry(0.065, 8, 8), new THREE.MeshStandardMaterial({ color: 0xa855f7, emissive: 0xa855f7, emissiveIntensity: 3.8 }), -0.75, 3.58, -0.65);
      subsChaos.add(towerMast); subsChaos.add(beaconLight);
      const subPointL = new THREE.PointLight(0xa855f7, 1.5, 3.5); subPointL.position.set(-0.75, 3.58, -0.65); subsChaos.add(subPointL);
      animObjects.push({ type: "beacon", ref: subPointL, refM: beaconLight, phase: 0 });

      body.userData = { id: "house_subs", district: "housing", name: "מנויים חודשיים", emoji: "📱", amount: 180, visits: 4, trend: "4 מנויים פעילים" };
      return body;
    }

    const towerBody    = createResidenceTower(houseZone);
    const utilBody     = createUtilitiesHub(houseZone);
    const subMediaBody = createSubscriptionsSpire(houseZone);
    interactiveBuildings.push(towerBody, utilBody, subMediaBody);

    createPlotSite("house_tower", "שכירות ומשכנתא",   "מגורים והוצאות קבועות", -2.2, -2.0, houseZone, towerBody.userData);
    createPlotSite("house_util",  "חשבונות בית",       "חשמל, מים וארנונה",     2.2, -2.0, houseZone, utilBody.userData);
    createPlotSite("house_subs",  "מנויים וסטרימינג", "שירותים דיגיטליים",       0, 2.2, houseZone, subMediaBody.userData);

    // ────────────────────────────────────────────────────────────────
    // ────────────────────────────────────────────────────────────────
    // 🌱  SAVINGS PARK SANCTUARY
    // ────────────────────────────────────────────────────────────────
    const parkZone = new THREE.Group();
    parkZone.position.set(-6.2, 0.08, 6.0);
    root.add(parkZone);
    
    const parkBase = mesh(roundedBox(8.8, 0.26, 8.8, 0.8), new THREE.MeshStandardMaterial({ map: parkGrassTex(), bumpMap: parkGrassBump(), bumpScale: 0.08, roughness: 0.85 }), 0, 0.13, 0, false, true);
    parkZone.add(parkBase);

    // Upper Hill Tier with Sculpted Terraced Stone Wall
    const upperHill = mesh(roundedBox(5.6, 0.16, 5.6, 0.6), new THREE.MeshStandardMaterial({ map: parkGrassTex(), bumpMap: parkGrassBump(), bumpScale: 0.08, roughness: 0.85 }), 1.2, 0.30, -1.2, false, true);
    upperHill.add(mesh(new THREE.BoxGeometry(5.7, 0.20, 0.16), mat(0x64748b, 0.85), 0, 0.02, 2.8));
    upperHill.add(mesh(new THREE.BoxGeometry(0.16, 0.20, 5.7), mat(0x64748b, 0.85), -2.8, 0.02, 0));
    parkZone.add(upperHill);

    const parkSign = mesh(new THREE.BoxGeometry(2.4, 0.48, 0.10), new THREE.MeshStandardMaterial({ map: signTex("🌱 חיסכון והשקעות", "Savings & Investments", "#ffffff", "#166534"), emissive: 0x166534, emissiveIntensity: 0.45 }), 0, 1.25, 2.8);
    parkZone.add(parkSign);

    const parkData = { id: "savings_sanctuary", district: "savings", name: "חיסכון והשקעות", emoji: "🌱", amount: 1800, visits: 1, trend: "צמיחה ירוקה" };
    parkBase.userData = parkData;
    parkSign.userData = parkData;
    interactiveBuildings.push(parkBase, parkSign);

    const trShape = new THREE.Shape(); trShape.absellipse(0, 0, 2.7, 1.9, 0, Math.PI * 2);
    const trMesh = new THREE.Mesh(new THREE.ShapeGeometry(trShape, 40), mat(0xd4b886, 0.95));
    trMesh.rotation.x = -Math.PI / 2; trMesh.position.y = 0.28; parkZone.add(trMesh);

    const pondShape = new THREE.Shape(); pondShape.absellipse(-0.5, 0, 1.7, 1.2, 0, Math.PI * 2);
    const pondMat = new THREE.MeshStandardMaterial({ color: 0x38bdf8, roughness: 0.02, metalness: 0.4, emissive: 0x0284c7, emissiveIntensity: 1.5 });
    const pondM = new THREE.Mesh(new THREE.ShapeGeometry(pondShape, 48), pondMat);
    pondM.rotation.x = -Math.PI / 2; pondM.position.y = 0.30; parkZone.add(pondM);
    animObjects.push({ type: "pond_shimmer", ref: pondMat, phase: 0 });
    addLight("point", 0x38bdf8, 1.0, 5.0, -0.5, 0.6, 0, parkZone);

    // Natural Shoreline Pebble Stones Lining the Pond Edge
    const shorePebbleMat = mat(0x78716c, 0.9);
    for (let pa = 0; pa < Math.PI * 2; pa += 0.32) {
      const px = -0.5 + Math.cos(pa) * 1.75;
      const pz = Math.sin(pa) * 1.25;
      const peb = mesh(new THREE.DodecahedronGeometry(0.10 + (Math.sin(pa*4)*0.03), 0), shorePebbleMat, px, 0.32, pz);
      parkZone.add(peb);
    }

    // Floating Lily Pads & Lotus Flowers on Pond
    const lilyMat = mat(0x16a34a, 0.9);
    const lotusMat = new THREE.MeshStandardMaterial({ color: 0xfdf2f8, emissive: 0xf472b6, emissiveIntensity: 1.2 });
    [[-0.85, -0.25], [-0.35, 0.38], [-1.05, 0.20]].forEach(([lx, lz]) => {
      const pad = mesh(new THREE.CircleGeometry(0.18, 12, 0, Math.PI * 1.8), lilyMat, lx, 0.31, lz);
      pad.rotation.x = -Math.PI / 2; parkZone.add(pad);
      const lotus = mesh(new THREE.SphereGeometry(0.065, 8, 8), lotusMat, lx + 0.04, 0.35, lz + 0.04);
      parkZone.add(lotus);
    });

    // River Stepping Stones Crossing the Stream
    const stoneMat = mat(0x64748b, 0.9);
    [[-0.60, -0.62], [-0.42, -0.85], [-0.22, -1.05]].forEach(([sx, sz], i) => {
      const st = mesh(new THREE.CylinderGeometry(0.15 - i * 0.02, 0.17 - i * 0.02, 0.06, 8), stoneMat, sx, 0.31, sz);
      parkZone.add(st);
    });

    const fount = new THREE.Group(); fount.position.set(-0.5, 0.30, 0); parkZone.add(fount);
    fount.add(mesh(new THREE.CylinderGeometry(0.28, 0.34, 0.28, 12), mat(0x94a3b8, 0.65), 0, 0.14, 0));
    fount.add(mesh(new THREE.SphereGeometry(0.10, 8, 8), new THREE.MeshStandardMaterial({ color: 0x38bdf8, emissive: 0x38bdf8, emissiveIntensity: 1.8 }), 0, 0.36, 0));
    [0, Math.PI * 0.66, Math.PI * 1.32].forEach(a => {
      const arc = mesh(new THREE.TorusGeometry(0.18, 0.025, 6, 12, Math.PI * 0.6), mat(0x7dd3fc, 0.3, 0.4, 0x38bdf8, 0.8), Math.cos(a)*0.08, 0.28, Math.sin(a)*0.08, false, false);
      arc.rotation.y = a; arc.rotation.x = -0.5; fount.add(arc);
    });

    const bridgeG = new THREE.Group(); bridgeG.position.set(0.85, 0.30, -0.2); parkZone.add(bridgeG);
    bridgeG.add(mesh(new THREE.BoxGeometry(0.62, 0.10, 1.90), mat(0xb91c1c, 0.75), 0, 0.22, 0));
    bridgeG.rotation.x = -0.18;
    for (let bi = -3; bi <= 3; bi++) {
      bridgeG.add(mesh(new THREE.CylinderGeometry(0.022, 0.022, 0.30, 8), mat(0xb91c1c, 0.7), -0.28, 0.28, bi * 0.28, false, false));
      bridgeG.add(mesh(new THREE.CylinderGeometry(0.022, 0.022, 0.30, 8), mat(0xb91c1c, 0.7), 0.28, 0.28, bi * 0.28, false, false));
    }
    [-0.28, 0.28].forEach(rx => bridgeG.add(mesh(new THREE.BoxGeometry(0.04, 0.04, 1.92), mat(0xb91c1c, 0.7), rx, 0.42, 0, false, false)));

    // 🌳 Sculpted Low-Poly Organic Trees (Branching Trunks, Layered Foliage Tones, Fallen Petals)
    function createTree(x, z, scale, isSakura) {
      const g = new THREE.Group(); g.position.set(x, 0.28, z);
      
      const trunkMat = mat(isSakura ? 0x451a03 : 0x5c381e, 0.95);
      // Root base
      g.add(mesh(new THREE.CylinderGeometry(0.12 * scale, 0.22 * scale, 0.38 * scale, 8), trunkMat, 0, 0.19 * scale, 0));
      // Main trunk
      g.add(mesh(new THREE.CylinderGeometry(0.09 * scale, 0.12 * scale, 0.75 * scale, 8), trunkMat, 0, 0.65 * scale, 0));
      
      // Sculpted Branching Boughs
      const b1 = mesh(new THREE.CylinderGeometry(0.05 * scale, 0.08 * scale, 0.42 * scale, 6), trunkMat, 0.12 * scale, 0.92 * scale, 0.08 * scale);
      b1.rotation.z = -0.55; b1.rotation.y = 0.4; g.add(b1);
      const b2 = mesh(new THREE.CylinderGeometry(0.04 * scale, 0.07 * scale, 0.40 * scale, 6), trunkMat, -0.10 * scale, 0.90 * scale, -0.06 * scale);
      b2.rotation.z = 0.50; b2.rotation.y = -0.3; g.add(b2);

      // Layered Tonal Foliage Canopies
      const c1 = mat(isSakura ? 0xf43f5e : 0x14532d, 0.85); // Deep shadow
      const c2 = mat(isSakura ? 0xf472b6 : 0x16a34a, 0.80); // Vibrant leaf
      const c3 = mat(isSakura ? 0xfbcfe8 : 0x4ade80, 0.75); // Sunlit highlight
      
      g.add(mesh(new THREE.DodecahedronGeometry(0.72 * scale, 1), c2, 0, 1.45 * scale, 0));
      g.add(mesh(new THREE.DodecahedronGeometry(0.55 * scale, 1), c1, -0.18 * scale, 1.18 * scale, 0.15 * scale));
      g.add(mesh(new THREE.DodecahedronGeometry(0.50 * scale, 1), c2, 0.35 * scale, 1.35 * scale, 0.20 * scale));
      g.add(mesh(new THREE.DodecahedronGeometry(0.48 * scale, 1), c1, -0.32 * scale, 1.30 * scale, -0.18 * scale));
      g.add(mesh(new THREE.DodecahedronGeometry(0.42 * scale, 1), c3, 0.08 * scale, 1.82 * scale, 0.05 * scale));

      if (isSakura) {
        // Scattered fallen pink petals on the grass below
        const petalMat = mat(0xfda4af, 0.9);
        [
          [0.35, 0.25], [-0.4, 0.3], [0.2, -0.45], [-0.35, -0.3],
          [0.6, 0.1], [-0.15, 0.6], [0.45, -0.35], [-0.5, -0.2]
        ].forEach(([px, pz]) => {
          const petal = mesh(new THREE.CircleGeometry(0.04 * scale, 5), petalMat, px * scale, 0.015, pz * scale);
          petal.rotation.x = -Math.PI / 2;
          g.add(petal);
        });
      }

      parkZone.add(g);
    }
    [
      [-2.8,-2.8,1.1,false], [-1.1,-3.0,1.0,true],  [1.2,-2.8,0.9,false], [2.8,-2.6,1.1,false],
      [3.1,-0.6,1.0,true],   [2.8,1.4,0.9,false],    [2.4,2.6,1.1,false],  [0.6,3.0,1.0,true],
      [-1.2,3.0,0.9,false],  [-2.8,2.6,1.1,false]
    ].forEach(p => createTree(p[0], p[1], p[2], p[3]));

    // 🌲 Slender Mediterranean Cypress Trees (Outer Island Corners)
    function createItalianCypress(x, z, scale, parent) {
      const g = new THREE.Group(); g.position.set(x, 0.22, z);
      g.add(mesh(new THREE.CylinderGeometry(0.04 * scale, 0.07 * scale, 0.35 * scale, 6), mat(0x451a03, 0.95), 0, 0.17 * scale, 0));
      g.add(mesh(new THREE.ConeGeometry(0.28 * scale, 1.45 * scale, 7), mat(0x14532d, 0.85), 0, 0.90 * scale, 0));
      g.add(mesh(new THREE.ConeGeometry(0.22 * scale, 1.15 * scale, 7), mat(0x166534, 0.80), 0, 1.25 * scale, 0));
      (parent || root).add(g);
    }
    createItalianCypress(-10.2, -10.2, 1.0);
    createItalianCypress(10.2, -10.2, 1.0);
    createItalianCypress(10.2, 9.8, 1.0);

    // 🌸 Blooming Flower Shrubs along Park Paths
    function createFlowerShrub(x, z, flowerColor, parent) {
      const g = new THREE.Group(); g.position.set(x, 0.22, z);
      g.add(mesh(new THREE.DodecahedronGeometry(0.24, 1), mat(0x15803d, 0.85), 0, 0.18, 0));
      const flMat = mat(flowerColor || 0xf43f5e, 0.85);
      [[-0.08, 0.24, 0.08], [0.10, 0.26, -0.06], [0, 0.32, 0], [0.08, 0.22, 0.10], [-0.08, 0.20, -0.08]].forEach(([fx, fy, fz]) => {
        g.add(mesh(new THREE.SphereGeometry(0.055, 6, 6), flMat, fx, fy, fz));
      });
      (parent || root).add(g);
    }
    createFlowerShrub(-1.9, 0.2, 0xf43f5e, parkZone);
    createFlowerShrub(1.8, 0.8, 0xa855f7, parkZone);
    createFlowerShrub(0.2, -1.8, 0xfacc15, parkZone);

    // 🚒 Realistic NYC/Tel Aviv Red Fire Hydrant (Food District Sidewalk Curb)
    function createFireHydrant(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, 0.14, z); g.rotation.y = ry || 0;
      const redM = mat(0xdc2626, 0.4, 0.6);
      const metalM = mat(0x94a3b8, 0.3, 0.8);
      g.add(mesh(new THREE.CylinderGeometry(0.08, 0.10, 0.34, 10), redM, 0, 0.17, 0));
      g.add(mesh(new THREE.SphereGeometry(0.08, 10, 8, 0, Math.PI * 2, 0, Math.PI * 0.5), redM, 0, 0.34, 0));
      g.add(mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.05, 5), metalM, 0, 0.41, 0));
      [-0.08, 0.08].forEach(nx => {
        const noz = mesh(new THREE.CylinderGeometry(0.035, 0.035, 0.06, 8), metalM, nx, 0.22, 0);
        noz.rotation.z = Math.PI / 2; g.add(noz);
      });
      root.add(g);
    }
    createFireHydrant(-2.6, -2.6, 0);

    // 💡 4 Symmetrical Victorian Street Lamps at 4 District Corner Curbs
    function createStreetLamp(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, 0.14, z); g.rotation.y = ry || 0;
      const ironM = mat(0x18181b, 0.4, 0.8);
      g.add(mesh(new THREE.CylinderGeometry(0.05, 0.08, 0.22, 8), ironM, 0, 0.11, 0));
      g.add(mesh(new THREE.CylinderGeometry(0.028, 0.040, 1.75, 8), ironM, 0, 1.05, 0));
      g.add(mesh(new THREE.TorusGeometry(0.16, 0.022, 6, 12, Math.PI * 0.6), ironM, 0.10, 1.92, 0));
      g.add(mesh(new THREE.ConeGeometry(0.14, 0.07, 6), ironM, 0.22, 2.05, 0));
      const bulb = mesh(new THREE.SphereGeometry(0.065, 8, 8), new THREE.MeshStandardMaterial({ color: 0xffedd5, emissive: 0xfef08a, emissiveIntensity: 0.2 }), 0.22, 1.95, 0, false, false);
      g.add(bulb);
      const lampLight = new THREE.PointLight(0xffedd5, 0, 4.5);
      lampLight.position.set(0.22, 1.95, 0); g.add(lampLight);
      root.add(g);
      streetLamps.push({ light: lampLight, bulb: bulb });
    }
    createStreetLamp(-2.2, -2.6, -Math.PI / 4);      // Food District Corner
    createStreetLamp(3.2, -2.6, Math.PI / 4);        // Shopping District Corner
    createStreetLamp(-2.2, 1.8, -Math.PI * 3 / 4);   // Park District Corner
    createStreetLamp(3.2, 1.8, Math.PI * 3 / 4);     // Housing District Corner

    // 🚲 Stainless Steel Bike Rack with Commuter Bike (Shopping Sidewalk)
    function createBikeRack(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, 0.14, z); g.rotation.y = ry || 0;
      const chromeM = mat(0x94a3b8, 0.2, 0.9);
      [-0.22, 0.22].forEach(rx => {
        g.add(mesh(new THREE.TorusGeometry(0.16, 0.020, 6, 12, Math.PI), chromeM, rx, 0.32, 0));
        g.add(mesh(new THREE.CylinderGeometry(0.020, 0.020, 0.32, 6), chromeM, rx - 0.16, 0.16, 0));
        g.add(mesh(new THREE.CylinderGeometry(0.020, 0.020, 0.32, 6), chromeM, rx + 0.16, 0.16, 0));
      });
      const bike = new THREE.Group(); bike.position.set(-0.22, 0.20, 0.02); g.add(bike);
      const wheelM = mat(0x18181b, 0.8);
      [-0.28, 0.28].forEach(wx => {
        const wh = mesh(new THREE.TorusGeometry(0.13, 0.016, 6, 14), wheelM, wx, 0, 0);
        bike.add(wh);
      });
      const frameM = mat(0x06b6d4, 0.3, 0.7);
      bike.add(mesh(new THREE.CylinderGeometry(0.010, 0.010, 0.32, 6), frameM, 0, 0.08, 0));
      bike.add(mesh(new THREE.BoxGeometry(0.07, 0.020, 0.04), mat(0x18181b, 0.8), 0, 0.24, 0));
      bike.add(mesh(new THREE.BoxGeometry(0.020, 0.020, 0.22), chromeM, 0.24, 0.25, 0));
      root.add(g);
    }
    createBikeRack(5.4, -2.7, 0);

    // 🚒 3D High-Detail Fire Hydrants at Sidewalk Corners
    function createFireHydrant(x, z) {
      const g = new THREE.Group(); g.position.set(x, 0.14, z);
      const redM = mat(0xdc2626, 0.4, 0.6);
      const chromeM = mat(0xd1d5db, 0.2, 0.9);
      g.add(mesh(new THREE.CylinderGeometry(0.08, 0.10, 0.45, 10), redM, 0, 0.22, 0));
      g.add(mesh(new THREE.SphereGeometry(0.085, 8, 8), redM, 0, 0.45, 0));
      g.add(mesh(new THREE.BoxGeometry(0.04, 0.04, 0.04), chromeM, 0, 0.54, 0));
      [-0.08, 0.08].forEach(sx => {
        g.add(mesh(new THREE.CylinderGeometry(0.035, 0.035, 0.08, 8), chromeM, sx, 0.32, 0));
      });
      root.add(g);
    }
    createFireHydrant(-1.9, -3.3);
    createFireHydrant(3.1, 1.7);

    // 📬 Red Postal Mailbox (Housing Sidewalk)
    function createMailbox(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, 0.14, z); g.rotation.y = ry || 0;
      g.add(mesh(new THREE.CylinderGeometry(0.025, 0.025, 0.40, 6), mat(0x18181b, 0.8), 0, 0.20, 0));
      g.add(mesh(roundedBox(0.24, 0.32, 0.20, 0.05), mat(0xef4444, 0.4, 0.6), 0, 0.50, 0));
      g.add(mesh(new THREE.BoxGeometry(0.16, 0.02, 0.02), mat(0x18181b, 0.9), 0, 0.56, 0.11));
      root.add(g);
    }
    createMailbox(3.8, 1.8, 0);

    // 🕳️ Cast Iron Manhole Covers embedded flush in Road Asphalt
    function createManhole(x, z) {
      const mh = mesh(new THREE.CylinderGeometry(0.22, 0.22, 0.02, 16), mat(0x334155, 0.5, 0.7), x, 0.08, z);
      root.add(mh);
    }
    createManhole(-6.0, -0.8);
    createManhole(6.0, -0.8);
    createManhole(0.6, 6.0);

    // 🚦 2 Sleek Traffic Signals at Crosswalk Curb Posts
    function createTrafficSignal(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, 0.14, z); g.rotation.y = ry || 0;
      const blackM = mat(0x18181b, 0.4, 0.8);
      g.add(mesh(new THREE.CylinderGeometry(0.035, 0.05, 1.75, 8), blackM, 0, 0.88, 0));
      g.add(mesh(roundedBox(0.22, 0.62, 0.16, 0.04), blackM, 0, 1.40, 0.08));
      const redLens = mesh(new THREE.SphereGeometry(0.048, 8, 8), new THREE.MeshStandardMaterial({ color: 0xef4444, emissive: 0xef4444, emissiveIntensity: 2.2 }), 0, 1.58, 0.16);
      const ambLens = mesh(new THREE.SphereGeometry(0.048, 8, 8), new THREE.MeshStandardMaterial({ color: 0xf59e0b, emissive: 0xf59e0b, emissiveIntensity: 0.8 }), 0, 1.40, 0.16);
      const grnLens = mesh(new THREE.SphereGeometry(0.048, 8, 8), new THREE.MeshStandardMaterial({ color: 0x10b981, emissive: 0x10b981, emissiveIntensity: 0.8 }), 0, 1.22, 0.16);
      g.add(redLens); g.add(ambLens); g.add(grnLens);
      root.add(g);
    }
    createTrafficSignal(3.2, -2.2, 0);
    createTrafficSignal(-2.2, 1.4, Math.PI);

    // 🗑️ Public Slatted Trash & Recycling Bins (Clean Park & Cafe Curbs)
    function createTrashCan(x, z) {
      const g = new THREE.Group(); g.position.set(x, 0.14, z);
      g.add(mesh(new THREE.CylinderGeometry(0.11, 0.09, 0.32, 10), mat(0x166534, 0.7), 0, 0.16, 0));
      g.add(mesh(new THREE.CylinderGeometry(0.12, 0.12, 0.03, 10), mat(0x0f172a, 0.5), 0, 0.32, 0));
      root.add(g);
    }
    createTrashCan(-2.6, 1.8);
    createTrashCan(-2.6, -4.5);

    // ════════════════════════════════════════════════════════════════
    // ✨ FESTIVE BISTRO & PROMENADE OVERHEAD STRING FAIRY LIGHTS
    // ════════════════════════════════════════════════════════════════
    function createStringLights(p1, p2, sag, bulbCount, parent) {
      const g = new THREE.Group();
      const points = [];
      const steps = 18;
      for (let i = 0; i <= steps; i++) {
        const f = i / steps;
        const x = p1[0] + (p2[0] - p1[0]) * f;
        const z = p1[2] + (p2[2] - p1[2]) * f;
        const y = p1[1] + (p2[1] - p1[1]) * f - Math.sin(f * Math.PI) * (sag || 0.30);
        points.push(new THREE.Vector3(x, y, z));
      }
      const curve = new THREE.CatmullRomCurve3(points);
      const wireGeo = new THREE.TubeGeometry(curve, 18, 0.010, 6, false);
      g.add(new THREE.Mesh(wireGeo, mat(0x18181b, 0.8)));

      const bulbGeo = new THREE.SphereGeometry(0.042, 8, 8);
      const bulbMat = new THREE.MeshStandardMaterial({
        color: 0xfef08a,
        emissive: 0xfef08a,
        emissiveIntensity: 3.2,
        roughness: 0.2
      });

      for (let b = 1; b < bulbCount; b++) {
        const f = b / bulbCount;
        const pt = curve.getPoint(f);
        g.add(mesh(bulbGeo, bulbMat, pt.x, pt.y - 0.035, pt.z, false, false));
      }
      (parent || root).add(g);
      return g;
    }

    // Food District Warm String Fairy Lights
    createStringLights([-8.5, 2.5, -9.0], [-3.9, 2.3, -9.0], 0.35, 7);
    createStringLights([-3.9, 2.3, -9.0], [-3.9, 2.3, -4.6], 0.30, 6);
    createStringLights([-8.5, 2.5, -9.0], [-8.5, 2.3, -4.6], 0.30, 6);

    // Shopping District Vibrant String Fairy Lights
    createStringLights([4.5, 2.6, -9.0], [9.1, 2.4, -9.0], 0.35, 7);
    createStringLights([4.5, 2.6, -9.0], [4.5, 2.3, -4.6], 0.30, 6);
    createStringLights([9.1, 2.4, -9.0], [9.1, 2.3, -4.6], 0.30, 6);

    // 🚏 Modern Glass Bus Stop Shelter with Boarding Platform, Signpost & Bench
    function createBusShelter(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, 0.14, z); g.rotation.y = ry || 0;
      const steelM = mat(0x0f172a, 0.3, 0.85);
      const glassM = new THREE.MeshStandardMaterial({ color: 0x38bdf8, transparent: true, opacity: 0.50, roughness: 0.05 });
      const concreteM = mat(0xe2e8f0, 0.8);
      const yellowHazardM = mat(0xfacc15, 0.6);

      // Raised Stone Boarding Platform Base
      g.add(mesh(roundedBox(1.9, 0.06, 1.1, 0.04), concreteM, 0, 0.03, 0));
      // Tactile Yellow Hazard Curb Warning Strip on road-facing edge
      g.add(mesh(new THREE.BoxGeometry(1.85, 0.065, 0.10), yellowHazardM, 0, 0.032, 0.48));

      // Dark Steel Support Pillars
      [-0.75, 0.75].forEach(px => {
        g.add(mesh(new THREE.CylinderGeometry(0.025, 0.025, 1.45, 8), steelM, px, 0.75, -0.35));
      });
      // Cantilevered Glass & Steel Roof Canopy
      g.add(mesh(roundedBox(1.8, 0.04, 0.95, 0.02), steelM, 0, 1.48, 0.05));
      const roofGlass = mesh(new THREE.BoxGeometry(1.65, 0.02, 0.80), glassM, 0, 1.49, 0.05);
      g.add(roofGlass);

      // Rear Tempered Glass Windbreak Panel
      g.add(mesh(new THREE.BoxGeometry(1.5, 1.25, 0.02), glassM, 0, 0.75, -0.35));

      // Side Illuminated Advertising / Route Lightbox (facing oncoming street)
      const adBox = mesh(new THREE.BoxGeometry(0.05, 1.25, 0.65), steelM, 0.78, 0.75, -0.05);
      adBox.add(mesh(new THREE.BoxGeometry(0.055, 1.05, 0.55), new THREE.MeshStandardMaterial({ map: signTex("🚏 קו 1", "City Center Express", "#ffffff", "#0284c7"), emissive: 0x0284c7, emissiveIntensity: 1.8 }), 0, 0, 0));
      g.add(adBox);

      // Wooden Slatted Bench
      g.add(mesh(new THREE.BoxGeometry(1.0, 0.04, 0.26), mat(0x9a3412, 0.8), -0.15, 0.38, -0.18));
      [-0.55, 0.25].forEach(bx => g.add(mesh(new THREE.BoxGeometry(0.03, 0.36, 0.22), steelM, bx, 0.18, -0.18)));

      // Commuter Sitting on Bench Waiting for Bus
      const commuter = createMiniFigure({ shirtColor: 0x0284c7, pantsColor: 0x334155, isSitting: true, hairColor: 0x78350f, hasPhone: true });
      commuter.position.set(-0.15, 0.14, -0.18); commuter.rotation.y = 0; g.add(commuter);
      seatedCitizens.push(commuter);

      // Free-standing Yellow Bus Stop Sign Totem on Curb
      const totem = new THREE.Group(); totem.position.set(-0.85, 0, 0.42); g.add(totem);
      totem.add(mesh(new THREE.CylinderGeometry(0.020, 0.020, 1.45, 8), mat(0x18181b, 0.8), 0, 0.72, 0));
      const disk = mesh(new THREE.CylinderGeometry(0.15, 0.15, 0.03, 16), mat(0xfacc15, 0.5), 0, 1.40, 0);
      disk.rotation.z = Math.PI / 2; totem.add(disk);
      totem.add(mesh(new THREE.BoxGeometry(0.04, 0.25, 0.18), mat(0x1e293b, 0.7), 0, 1.15, 0));

      root.add(g);
    }
    createBusShelter(3.35, -4.8, -Math.PI / 2);

    // 📰 Street Magazine, Newspaper & Cold Drinks Heritage Kiosk
    function createStreetKiosk(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, 0.14, z); g.rotation.y = ry || 0;
      const kioskGreen = mat(0x14532d, 0.7);
      const copperRoof = mat(0x0f766e, 0.5, 0.6);
      
      g.add(mesh(new THREE.CylinderGeometry(0.65, 0.70, 1.25, 8), kioskGreen, 0, 0.62, 0));
      g.add(mesh(new THREE.ConeGeometry(0.85, 0.55, 8), copperRoof, 0, 1.52, 0));
      g.add(mesh(new THREE.SphereGeometry(0.08, 8, 8), mat(0xfacc15, 0.2, 0.9), 0, 1.82, 0));
      
      const awn = mesh(new THREE.BoxGeometry(0.75, 0.04, 0.35), new THREE.MeshStandardMaterial({ map: stripeTex("#0f766e", "#ffffff", 4) }), 0, 1.15, 0.55);
      awn.rotation.x = -0.3; g.add(awn);
      
      const magRack = mesh(new THREE.BoxGeometry(0.65, 0.45, 0.08), mat(0x1e293b, 0.8), 0, 0.75, 0.62);
      [[-0.22, 0xef4444], [0, 0x3b82f6], [0.22, 0xfacc15]].forEach(([mx, col]) => {
        magRack.add(mesh(new THREE.BoxGeometry(0.16, 0.22, 0.02), mat(col, 0.5), mx, 0.05, 0.04));
      });
      g.add(magRack);
      
      const fridge = mesh(roundedBox(0.35, 0.65, 0.32, 0.03), mat(0x18181b, 0.6), -0.72, 0.35, 0.1);
      fridge.add(mesh(new THREE.BoxGeometry(0.02, 0.55, 0.26), new THREE.MeshStandardMaterial({ color: 0xffffff, emissive: 0x38bdf8, emissiveIntensity: 2.2 }), -0.16, 0, 0));
      g.add(fridge);
      
      root.add(g);
    }
    createStreetKiosk(-3.4, 2.6, Math.PI / 4);

    // 🍨 Retro Italian Gelato Ice Cream Cart
    function createGelatoCart(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, 0.22, z); g.rotation.y = ry || 0;
      const cartMat = mat(0xffedd5, 0.7);
      const chromeMat = mat(0xd1d5db, 0.2, 0.9);
      
      g.add(mesh(roundedBox(0.85, 0.55, 0.55, 0.05), cartMat, 0, 0.38, 0));
      g.add(mesh(new THREE.BoxGeometry(0.90, 0.04, 0.60), mat(0x9a3412, 0.8), 0, 0.67, 0));
      
      [-0.22, 0, 0.22].forEach(tx => {
        g.add(mesh(new THREE.CylinderGeometry(0.08, 0.08, 0.04, 10), chromeMat, tx, 0.70, 0));
        g.add(mesh(new THREE.SphereGeometry(0.025, 6, 6), mat(0xfacc15, 0.2, 0.9), tx, 0.73, 0));
      });
      
      [-0.45, 0.45].forEach(wx => {
        const wh = mesh(new THREE.TorusGeometry(0.24, 0.02, 8, 16), mat(0x18181b, 0.9), wx, 0.24, 0);
        wh.rotation.y = Math.PI / 2; g.add(wh);
      });
      
      g.add(mesh(new THREE.CylinderGeometry(0.018, 0.018, 1.2, 6), chromeMat, 0, 1.25, 0));
      const umb = mesh(new THREE.ConeGeometry(0.65, 0.28, 10), new THREE.MeshStandardMaterial({ map: stripeTex("#f43f5e", "#ffffff", 6) }), 0, 1.85, 0);
      g.add(umb);
      
      const chalk = mesh(new THREE.BoxGeometry(0.35, 0.45, 0.03), new THREE.MeshStandardMaterial({ map: menuTex() }), 0.55, 0.25, 0.35);
      chalk.rotation.y = -0.5; g.add(chalk);
      
      root.add(g);
    }
    createGelatoCart(-5.2, -2.6, 0.2);

    // 🛴 Shared Electric Kick-Scooter Fleet Station (Lime/Bird Style)
    function createScooterStation(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, 0.14, z); g.rotation.y = ry || 0;
      
      const bay = mesh(new THREE.PlaneGeometry(1.6, 0.75), new THREE.MeshStandardMaterial({ color: 0x10b981, roughness: 0.9 }), 0, 0.015, 0);
      bay.rotation.x = -Math.PI / 2; g.add(bay);
      
      [-0.45, 0, 0.45].forEach((sx, i) => {
        const sc = new THREE.Group(); sc.position.set(sx, 0, (i % 2 === 0 ? 0.05 : -0.05));
        sc.rotation.y = (i * 0.12) - 0.06;
        
        // Same fix at the sharing station, plus the deck lifted clear of the wheels.
        sc.add(mesh(roundedBox(0.12, 0.04, 0.58, 0.02), mat(0x10b981, 0.6), 0, 0.115, 0));
        [-0.26, 0.26].forEach(wz => {
          const w = mesh(new THREE.CylinderGeometry(0.055, 0.055, 0.03, 10), mat(0x18181b, 0.9), 0, 0.055, wz);
          w.rotation.z = Math.PI / 2;
          sc.add(w);
        });
        // A kickstand, so a parked scooter has a reason not to fall over.
        const stand = mesh(new THREE.CylinderGeometry(0.008, 0.008, 0.14, 5), mat(0x475569, 0.6), 0.05, 0.06, -0.15);
        stand.rotation.x = 0.22; stand.rotation.z = -0.45; sc.add(stand);
        sc.add(mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.68, 6), mat(0x18181b, 0.7), 0, 0.40, 0.22));
        sc.add(mesh(new THREE.BoxGeometry(0.32, 0.02, 0.02), mat(0x10b981, 0.6), 0, 0.74, 0.22));
        sc.add(mesh(new THREE.BoxGeometry(0.05, 0.04, 0.01), new THREE.MeshStandardMaterial({ color: 0x38bdf8, emissive: 0x38bdf8, emissiveIntensity: 2.5 }), 0, 0.75, 0.21));
        g.add(sc);
      });
      root.add(g);
    }
    createScooterStation(7.2, -2.7, 0);

    // 🪵 Rustic Wooden Footbridge over Park Creek
    function createParkFootbridge(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, 0.28, z); g.rotation.y = ry || 0;
      const woodM = mat(0x78350f, 0.85);
      
      const arch = mesh(new THREE.BoxGeometry(0.65, 0.08, 1.8), woodM, 0, 0.18, 0);
      arch.rotation.x = -0.08; g.add(arch);
      
      [-0.30, 0.30].forEach(rx => {
        g.add(mesh(new THREE.BoxGeometry(0.04, 0.04, 1.82), woodM, rx, 0.42, 0));
        for (let bi = -0.7; bi <= 0.7; bi += 0.35) {
          g.add(mesh(new THREE.CylinderGeometry(0.015, 0.015, 0.32, 6), woodM, rx, 0.25, bi));
        }
      });
      parkZone.add(g);
    }
    createParkFootbridge(-0.8, -1.2, Math.PI / 4);

    // 🧺 Wooden Picnic Table with Red-Checkered Cloth & Slices
    function createPicnicSpot(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, 0.28, z); g.rotation.y = ry || 0;
      const woodM = mat(0xa16207, 0.8);
      
      g.add(mesh(new THREE.BoxGeometry(0.95, 0.04, 0.65), woodM, 0, 0.42, 0));
      g.add(mesh(new THREE.BoxGeometry(0.70, 0.045, 0.50), new THREE.MeshStandardMaterial({ map: stripeTex("#ef4444", "#ffffff", 8) }), 0, 0.43, 0));
      
      [-0.42, 0.42].forEach(bz => {
        g.add(mesh(new THREE.BoxGeometry(0.95, 0.035, 0.22), woodM, 0, 0.25, bz));
        [-0.38, 0.38].forEach(lx => g.add(mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.24, 6), woodM, lx, 0.12, bz)));
      });
      [-0.38, 0.38].forEach(lx => g.add(mesh(new THREE.CylinderGeometry(0.025, 0.025, 0.40, 6), woodM, lx, 0.20, 0)));
      
      const basket = mesh(roundedBox(0.24, 0.18, 0.18, 0.03), mat(0xd97706, 0.9), -0.18, 0.52, 0.05);
      g.add(basket);
      const melon = mesh(new THREE.CylinderGeometry(0.10, 0.10, 0.03, 12, 1, false, 0, Math.PI), mat(0xef4444, 0.6), 0.16, 0.46, -0.05);
      melon.rotation.x = Math.PI / 2; g.add(melon);
      
      parkZone.add(g);
    }
    createPicnicSpot(-2.6, 0.8, -0.3);

    // 🍄 Red Amanita Polka-Dot Mushrooms
    function createMushroomCluster(x, z) {
      const g = new THREE.Group(); g.position.set(x, 0.28, z);
      const capM = mat(0xef4444, 0.7);
      const stemM = mat(0xffedd5, 0.9);
      
      [[0, 0, 1.0], [0.12, 0.08, 0.7], [-0.10, 0.06, 0.6]].forEach(([mx, mz, s]) => {
        g.add(mesh(new THREE.CylinderGeometry(0.02*s, 0.03*s, 0.12*s, 6), stemM, mx, 0.06*s, mz));
        const cap = mesh(new THREE.SphereGeometry(0.07*s, 8, 6, 0, Math.PI * 2, 0, Math.PI * 0.6), capM, mx, 0.11*s, mz);
        g.add(cap);
        [[-0.03*s, 0.03*s], [0.03*s, 0.02*s], [0, -0.03*s]].forEach(([dx, dz]) => {
          g.add(mesh(new THREE.SphereGeometry(0.015*s, 4, 4), stemM, mx + dx, 0.14*s, mz + dz));
        });
      });
      parkZone.add(g);
    }
    createMushroomCluster(-2.2, -1.8);
    createMushroomCluster(1.5, 2.2);

    // 🦋 Animated Fluttering Butterflies
    function createButterfly(colorHex, orbitRadius, cx, cz, cy) {
      const g = new THREE.Group(); g.position.set(cx, cy, cz);
      const wingMat = new THREE.MeshStandardMaterial({ color: colorHex, side: THREE.DoubleSide, emissive: colorHex, emissiveIntensity: 0.6 });
      
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
    createButterfly(0x38bdf8, 1.4, -6.2, 6.0, 1.2);
    createButterfly(0xf472b6, 1.2, -5.2, -6.8, 1.0);
    createButterfly(0xfacc15, 1.3, 6.8, -6.8, 1.1);

    // 🐦 Cute Ground Pigeons Pecking for Crumbs (Food District Promenade)
    const pigeonList = [];
    function createPigeon(x, z, ry) {
      const g = new THREE.Group(); g.position.set(x, 0.14, z); g.rotation.y = ry || 0;
      g.add(mesh(new THREE.SphereGeometry(0.055, 8, 6), mat(0x64748b, 0.6), 0, 0.055, 0));
      g.add(mesh(new THREE.SphereGeometry(0.035, 8, 6), mat(0x475569, 0.6), 0, 0.095, 0.04));
      g.add(mesh(new THREE.ConeGeometry(0.012, 0.035, 4), mat(0xf59e0b, 0.7), 0, 0.095, 0.08));
      g.add(mesh(new THREE.BoxGeometry(0.06, 0.015, 0.08), mat(0x334155, 0.7), 0, 0.06, -0.05));
      animObjects.push({ type: "bob", ref: g, base: 0.14, phase: Math.random() * Math.PI * 2 });
      root.add(g);
      pigeonList.push({ obj: g, baseX: x, baseZ: z, baseY: 0.14, flapTimer: 0, scareCooldown: 0 });
    }
    createPigeon(-3.6, -4.5, 0.4);
    createPigeon(-3.2, -4.8, -1.1);
    createPigeon(-3.8, -4.9, 2.2);

    addLight("point", 0xffb8d4, 0.8, 6.0, -1.0, 2.0, -3.0, parkZone);

    // 🐿️ High-Detail Waiting Squirrel on the Park Bench
    const lonelySquirrel = new THREE.Group(); lonelySquirrel.position.set(-1.9, 0.54, 1.9); parkZone.add(lonelySquirrel);
    lonelySquirrel.add(mesh(new THREE.BoxGeometry(0.15, 0.20, 0.15), mat(0x78350f, 0.85), 0, 0.10, 0));
    lonelySquirrel.add(mesh(new THREE.BoxGeometry(0.11, 0.15, 0.03), mat(0xfef3c7, 0.9), 0, 0.10, 0.08));
    const sqHead = new THREE.Group(); sqHead.position.set(0, 0.24, 0.04); lonelySquirrel.add(sqHead);
    sqHead.add(mesh(new THREE.SphereGeometry(0.09, 10, 8), mat(0x9a3412, 0.85), 0, 0, 0));
    sqHead.add(mesh(new THREE.ConeGeometry(0.04, 0.06, 6), mat(0x78350f, 0.9), 0, 0, 0.09));
    [-0.05, 0.05].forEach(ex => {
      sqHead.add(mesh(new THREE.ConeGeometry(0.03, 0.06, 6), mat(0x78350f, 0.9), ex, 0.10, 0));
      sqHead.add(mesh(new THREE.SphereGeometry(0.018, 6, 6), mat(0x18181b, 0.2), ex, 0.02, 0.08));
    });
    lonelySquirrel.add(mesh(new THREE.SphereGeometry(0.035, 6, 6), mat(0x451a03, 0.8), 0, 0.12, 0.12));
    lonelySquirrel.add(mesh(new THREE.CylinderGeometry(0.040, 0.030, 0.025, 8), mat(0x78350f, 0.9), 0, 0.15, 0.12));
    const sqTail = new THREE.Group(); sqTail.position.set(0, 0.08, -0.10); lonelySquirrel.add(sqTail);
    sqTail.add(mesh(new THREE.SphereGeometry(0.11, 10, 8), mat(0x78350f, 0.9), 0, 0.12, -0.06));
    sqTail.add(mesh(new THREE.SphereGeometry(0.13, 10, 8), mat(0x9a3412, 0.85), 0, 0.25, -0.04));
    sqTail.add(mesh(new THREE.ConeGeometry(0.12, 0.20, 8), mat(0x78350f, 0.9), 0, 0.38, 0.04));
    sqTail.rotation.x = -0.35;
    animObjects.push({ type: "bob", ref: lonelySquirrel, base: 0.54, phase: 0 });
    parkZone.userData.squirrel = lonelySquirrel;

    function addBench(x, z, ry, addSittingPerson, enrichmentId) {
      const b = new THREE.Group(); b.position.set(x, 0.28, z); b.rotation.y = ry;
      b.add(mesh(new THREE.BoxGeometry(0.82, 0.05, 0.28), mat(0x854d0e, 0.8), 0, 0.26, 0));
      b.add(mesh(new THREE.BoxGeometry(0.82, 0.30, 0.05), mat(0x854d0e, 0.8), 0, 0.43, -0.11));
      [-0.36, 0.36].forEach(lx => b.add(mesh(new THREE.BoxGeometry(0.04, 0.26, 0.28), mat(0x1e293b, 0.5), lx, 0.13, 0)));
      
      if (addSittingPerson) {
        const sitter = createMiniFigure({ shirtColor: 0x10b981, pantsColor: 0x334155, isSitting: true, hairColor: 0x1e293b });
        sitter.position.set(0, 0.24, 0.04);
        sitter.visible = !enrichmentId;
        b.add(sitter);
        seatedCitizens.push(sitter);
        if (enrichmentId) {
          enrichmentObjects[enrichmentId] = sitter;
        }
      }
      parkZone.add(b);
    }
    addBench(1.5, -0.5, -Math.PI / 3, true, "repair_bench");
    addBench(-1.9, 1.9, Math.PI / 4, false);
    addBench(0.6, 1.6, Math.PI * 0.8, true, "resident_artist");

    for (let bi = 0; bi < 3; bi++) {
      const bird = new THREE.Group(); bird.position.set(0, 5.5, 0); root.add(bird);
      bird.add(mesh(new THREE.SphereGeometry(0.04, 6, 6), mat(0xd1d5db, 0.8), 0, 0, 0, false, false));
      bird.add(mesh(new THREE.BoxGeometry(0.14, 0.015, 0.04), mat(0xd1d5db, 0.8), 0, 0, 0, false, false));
      animObjects.push({ type: "bird", ref: bird, radius: 3.5 + bi * 0.8, speed: 0.18 + bi * 0.07, phase: bi * 2.1, cx: -6.2, cz: 6.0 });
    }

    // ================================================================
    // 🏷️ ULTRA-CRISP NATIVE HTML/CSS FLOATING PILL TAGS (Zero Pixelation)
    // ================================================================
    const districtBuildingTags = {};

    function addDistrictBuildingTag(district, buildingId, icon, title, initialAmount, colHex, posX, posY, posZ) {
      // 1. Create native vector HTML DOM element
      const tagEl = document.createElement("div");
      tagEl.className = "diorama-pill-tag";
      tagEl.id = "tag-" + buildingId;

      const badgeEl = document.createElement("div");
      badgeEl.className = "diorama-pill-badge";
      badgeEl.style.backgroundColor = colHex || "#f43f5e";
      badgeEl.textContent = icon || "📍";

      const amountEl = document.createElement("span");
      const hasSpend = (initialAmount && initialAmount > 0);
      amountEl.className = "diorama-pill-amount" + (hasSpend ? "" : " zero");
      amountEl.textContent = hasSpend ? ("₪" + Math.round(initialAmount).toLocaleString("he-IL")) : "₪0";

      tagEl.appendChild(badgeEl);
      tagEl.appendChild(amountEl);
      if (tagsContainer) {
        tagsContainer.appendChild(tagEl);
      }

      // Tap handler for direct building inspection
      tagEl.addEventListener("pointerdown", (e) => {
        e.stopPropagation();
        selectBuilding({
          id: buildingId,
          district: district,
          buildingId: buildingId,
          name: title,
          emoji: icon,
          amount: tagData.amount || 0,
          trend: ""
        });
      });

      // 2. Clickable Hitbox on 3D map for buildings
      const clickBox = mesh(new THREE.BoxGeometry(2.4, 2.2, 2.4), new THREE.MeshBasicMaterial({ visible: false }), posX, posY - 0.6, posZ);
      clickBox.userData = {
        id: buildingId,
        district: district,
        buildingId: buildingId,
        name: title,
        emoji: icon,
        amount: initialAmount,
        trend: ""
      };
      root.add(clickBox);
      interactiveBuildings.push(clickBox);

      const tagData = {
        district: district,
        buildingId: buildingId,
        icon: icon,
        title: title,
        amount: initialAmount,
        colHex: colHex,
        domEl: tagEl,
        badgeEl: badgeEl,
        amountEl: amountEl,
        posX: posX,
        posY: posY,
        posZ: posZ,
        clickBox: clickBox
      };

      districtBuildingTags[buildingId] = tagData;
      return tagData;
    }

    // Register all district building tags with vibrant category colors and clean heights
    addDistrictBuildingTag("food", "food_bistro", "🍽️", "מסעדות וביסטרו", 0, "#35AEB7", -8.5, 4.4, -9.0);
    addDistrictBuildingTag("food", "food_super", "🛒", "סופרמרקט ומזון", 0, "#10B981", -3.9, 4.0, -9.0);
    addDistrictBuildingTag("food", "food_coffee", "☕", "קפה ומאפים", 0, "#F59E0B", -8.5, 3.8, -4.6);
    addDistrictBuildingTag("food", "food_wolt", "🛵", "וולט ומשלוחים", 0, "#35AEB7", -3.9, 3.8, -4.6);

    addDistrictBuildingTag("shopping", "shop_boutique", "🛍️", "ביגוד ואופנה", 0, "#7C72FF", 4.5, 4.4, -9.0);
    addDistrictBuildingTag("shopping", "shop_tech", "💻", "טכנולוגיה וגאדג'טים", 0, "#253CC4", 9.1, 4.0, -9.0);
    addDistrictBuildingTag("shopping", "shop_travel", "✈️", "חופשות וטיסות", 0, "#F47A28", 4.5, 3.8, -4.6);
    addDistrictBuildingTag("shopping", "shop_arcade", "🎮", "פנאי ובידור", 0, "#EC4899", 9.1, 3.8, -4.6);

    addDistrictBuildingTag("housing", "house_tower", "🏠", "מגורים ושכירות", 0, "#253CC4", 4.5, 5.2, 4.6);
    addDistrictBuildingTag("housing", "house_util", "⚡", "חשמל וארנונה", 0, "#F59E0B", 9.1, 4.2, 4.6);
    addDistrictBuildingTag("housing", "house_subs", "📺", "מנויים וסטרימינג", 0, "#7C72FF", 6.8, 3.8, 8.8);

    // ================================================================
    // 🏗️ SIMS-STYLE DEDICATED CITY UPGRADE SLOTS (Interactive Pads)
    // ================================================================
    const CITY_SLOTS = {
      "slot_park_center":      { id: "slot_park_center", name: "מרכז פארק השמורה", x: -6.2, y: 0.28, z: 6.0, defaultItem: "fountain_marble" },
      "slot_park_overlook":    { id: "slot_park_overlook", name: "מצפה גבעת האגם", x: -8.2, y: 0.28, z: 4.2, defaultItem: "pet_cat_rooftop" },
      "slot_food_plaza":       { id: "slot_food_plaza", name: "רחבת רובע האוכל", x: -4.5, y: 0.22, z: -4.8, defaultItem: "cafe_stand" },
      "slot_shop_promenade":   { id: "slot_shop_promenade", name: "שדרת הקניות והאופנה", x: 6.8, y: 0.22, z: -4.8, defaultItem: "tree_sakura" },
      "slot_housing_terrace":  { id: "slot_housing_terrace", name: "טרסת גן המגורים", x: 6.8, y: 0.22, z: 3.6, defaultItem: "flower_bed_plaza" },
      "slot_tech_plaza":       { id: "slot_tech_plaza", name: "כיכר מתחם ההייטק", x: 8.8, y: 0.22, z: -4.8, defaultItem: "public_art_sculpture" }
    };

    const slotPadMeshes = {};
    for (const sId in CITY_SLOTS) {
      const slot = CITY_SLOTS[sId];
      const g = new THREE.Group(); g.position.set(slot.x, slot.y - 0.04, slot.z);
      
      const pad = mesh(roundedBox(1.6, 0.04, 1.6, 0.2), mat(0x334155, 0.6, 0.4), 0, 0.02, 0, false, true);
      g.add(pad);
      
      const ringMat = new THREE.MeshBasicMaterial({ color: 0xfbbf24, transparent: true, opacity: 0.35 });
      const ring = mesh(new THREE.RingGeometry(0.70, 0.82, 24), ringMat, 0, 0.045, 0, false, false);
      ring.rotation.x = -Math.PI / 2;
      g.add(ring);
      
      const hit = mesh(new THREE.CylinderGeometry(0.9, 0.9, 0.6, 12), new THREE.MeshBasicMaterial({ visible: false }), 0, 0.3, 0);
      hit.userData = { isSlot: true, slotId: slot.id, slotName: slot.name, ref: g };
      g.add(hit);
      interactiveCitizens.push(hit);
      
      root.add(g);
      slotPadMeshes[sId] = g;
    }

    // ================================================================
    // ⛲ CUSTOM USER-UNLOCKED CITY ENRICHMENTS (Progress System)
    // ================================================================

    // 1. Central Park Sanctuary Marble Fountain (fountain_marble)
    function buildCentralPlazaFountain() {
      const g = new THREE.Group(); g.position.set(-6.2, 0.28, 6.0);
      g.add(mesh(new THREE.CylinderGeometry(1.0, 1.15, 0.28, 24), mat(0xe2e8f0, 0.3, 0.8), 0, 0.14, 0));
      const poolMat = new THREE.MeshStandardMaterial({ color: 0x38bdf8, emissive: 0x0284c7, emissiveIntensity: 1.2, roughness: 0.1 });
      const poolWater = mesh(new THREE.CylinderGeometry(0.85, 0.85, 0.08, 20), poolMat, 0, 0.26, 0);
      g.add(poolWater);
      g.add(mesh(new THREE.CylinderGeometry(0.35, 0.40, 0.55, 16), mat(0xe2e8f0, 0.3, 0.8), 0, 0.45, 0));
      g.add(mesh(new THREE.CylinderGeometry(0.55, 0.25, 0.18, 16), mat(0xe2e8f0, 0.3, 0.8), 0, 0.74, 0));
      
      const jet = mesh(new THREE.SphereGeometry(0.12, 10, 10), new THREE.MeshBasicMaterial({ color: 0x7dd3fc }), 0, 0.92, 0);
      g.add(jet);

      const fHit = mesh(new THREE.CylinderGeometry(1.2, 1.2, 1.0, 12), new THREE.MeshBasicMaterial({ visible: false }), 0, 0.5, 0);
      fHit.userData = { isFountain: true, ref: g };
      g.add(fHit);
      interactiveCitizens.push(fHit);

      animObjects.push({
        type: "fountain_anim",
        water: poolWater,
        jet: jet
      });

      root.add(g);
      g.visible = false;
      return g;
    }
    enrichmentObjects["fountain_marble"] = buildCentralPlazaFountain();

    // 2. Garden Terrace Ginger Cat (pet_cat_rooftop)
    function buildRooftopCat() {
      const g = new THREE.Group(); g.position.set(6.8, 0.22, 3.6);
      
      // Low stone garden wall base with wooden cap
      const wallBase = mesh(roundedBox(0.95, 0.46, 0.58, 0.08), mat(0x64748b, 0.8), 0, 0.23, 0);
      g.add(wallBase);
      const woodCap = mesh(roundedBox(1.02, 0.06, 0.65, 0.03), mat(0xa16207, 0.7), 0, 0.49, 0);
      g.add(woodCap);
      
      // Green climbing ivy leaves
      g.add(mesh(new THREE.SphereGeometry(0.12, 6, 6), mat(0x16a34a, 0.8), -0.32, 0.25, 0.28));
      g.add(mesh(new THREE.SphereGeometry(0.10, 6, 6), mat(0x22c55e, 0.8), 0.28, 0.35, 0.28));

      // Cozy velvet cushion
      g.add(mesh(new THREE.CylinderGeometry(0.25, 0.27, 0.06, 16), mat(0xe11d48, 0.8), 0, 0.54, 0));

      // Ginger Cat
      const catRoot = new THREE.Group(); catRoot.position.set(0, 0.57, 0); g.add(catRoot);
      const catMat = mat(0xf97316, 0.80);
      
      const catBody = mesh(roundedBox(0.24, 0.16, 0.32, 0.06), catMat, 0, 0.08, 0);
      catBody.add(mesh(roundedBox(0.14, 0.10, 0.18, 0.04), mat(0xffedd5, 0.9), 0, 0.01, 0.08));
      catRoot.add(catBody);

      // Paws resting over edge
      catRoot.add(mesh(new THREE.SphereGeometry(0.035, 6, 6), mat(0xffedd5, 0.9), -0.07, 0.02, 0.16));
      catRoot.add(mesh(new THREE.SphereGeometry(0.035, 6, 6), mat(0xffedd5, 0.9), 0.07, 0.02, 0.16));

      // Head with ears, eyes, nose
      const catHead = new THREE.Group(); catHead.position.set(0, 0.18, 0.12); catRoot.add(catHead);
      catHead.add(mesh(roundedBox(0.16, 0.14, 0.15, 0.04), catMat, 0, 0, 0));
      const earL = mesh(new THREE.ConeGeometry(0.035, 0.06, 4), mat(0xc2410c, 0.8), -0.055, 0.09, 0);
      earL.rotation.z = 0.2; earL.add(mesh(new THREE.ConeGeometry(0.02, 0.04, 3), mat(0xfda4af, 0.8), 0, 0, 0.01));
      catHead.add(earL);
      const earR = mesh(new THREE.ConeGeometry(0.035, 0.06, 4), mat(0xc2410c, 0.8), 0.055, 0.09, 0);
      earR.rotation.z = -0.2; earR.add(mesh(new THREE.ConeGeometry(0.02, 0.04, 3), mat(0xfda4af, 0.8), 0, 0, 0.01));
      catHead.add(earR);
      catHead.add(mesh(new THREE.SphereGeometry(0.018, 6, 6), new THREE.MeshBasicMaterial({ color: 0x4ade80 }), -0.04, 0.02, 0.08));
      catHead.add(mesh(new THREE.SphereGeometry(0.018, 6, 6), new THREE.MeshBasicMaterial({ color: 0x4ade80 }),  0.04, 0.02, 0.08));
      catHead.add(mesh(new THREE.SphereGeometry(0.012, 6, 6), mat(0x0f172a, 0.9), 0, -0.015, 0.085));

      // Tail
      const catTail = new THREE.Group(); catTail.position.set(0, 0.08, -0.14); catRoot.add(catTail);
      const tailMesh = mesh(new THREE.CylinderGeometry(0.016, 0.022, 0.24, 8), catMat, 0, 0.08, -0.05);
      tailMesh.rotation.x = -0.7; catTail.add(tailMesh);

      // Hitbox
      const hitBox = mesh(new THREE.BoxGeometry(0.8, 0.8, 0.8), new THREE.MeshBasicMaterial({ visible: false }), 0, 0.4, 0);
      g.add(hitBox);
      const uData = { isCat: true, cat: g, catRoot: catRoot, catHead: catHead, catTail: catTail, catBody: catBody, hopTimer: 0 };
      hitBox.userData = uData;
      g.userData = uData;
      interactiveCitizens.push(hitBox);

      animObjects.push({ type: "cat_anim", head: catHead, tail: catTail, body: catBody, root: catRoot, userData: uData });

      root.add(g);
      g.visible = false;
      return g;
    }
    enrichmentObjects["pet_cat_rooftop"] = buildRooftopCat();

    // 3. Pink Sakura Tree in Promenade (tree_sakura)
    function buildPromenadeSakura() {
      const g = new THREE.Group(); g.position.set(6.8, 0.22, -4.8);
      g.add(mesh(new THREE.CylinderGeometry(0.09, 0.14, 0.75, 8), mat(0x5c381e, 0.95), 0, 0.38, 0));
      g.add(mesh(new THREE.SphereGeometry(0.68, 12, 10), mat(0xf472b6, 0.82), 0, 1.05, 0));
      g.add(mesh(new THREE.SphereGeometry(0.48, 10, 8), mat(0xfce7f3, 0.78), 0.25, 1.30, 0.15));
      g.add(mesh(new THREE.SphereGeometry(0.42, 10, 8), mat(0xfda4af, 0.78), -0.22, 1.20, -0.15));
      
      const sHit = mesh(new THREE.CylinderGeometry(0.8, 0.8, 1.4, 8), new THREE.MeshBasicMaterial({ visible: false }), 0, 0.7, 0);
      sHit.userData = { isSakura: true, ref: g };
      g.add(sHit);
      interactiveCitizens.push(sHit);

      root.add(g);
      g.visible = false;
      return g;
    }
    enrichmentObjects["tree_sakura"] = buildPromenadeSakura();

    // 4. Colorful Flower Beds (flower_bed_plaza)
    function buildFlowerBeds() {
      const g = new THREE.Group(); g.position.set(-4.2, 0.22, -4.8);
      g.add(mesh(roundedBox(1.4, 0.18, 0.55, 0.08), mat(0x78350f, 0.9), 0, 0.09, 0));
      const flowerCols = [0xec4899, 0xfacc15, 0xef4444, 0xa855f7, 0x38bdf8];
      for (let fx = -0.5; fx <= 0.5; fx += 0.25) {
        for (let fz = -0.12; fz <= 0.12; fz += 0.24) {
          const col = flowerCols[Math.floor(Math.random() * flowerCols.length)];
          g.add(mesh(new THREE.SphereGeometry(0.065, 6, 6), mat(col, 0.7), fx, 0.22, fz));
        }
      }
      root.add(g);
      g.visible = false;
      return g;
    }
    enrichmentObjects["flower_bed_plaza"] = buildFlowerBeds();

    // 5. Bicycle Rack Station (bike_station)
    function buildBikeStation() {
      const g = new THREE.Group(); g.position.set(4.8, 0.22, -2.8);
      g.add(mesh(new THREE.BoxGeometry(1.4, 0.05, 0.6), mat(0x334155, 0.9), 0, 0.025, 0));
      for (let bx = -0.40; bx <= 0.40; bx += 0.40) {
        g.add(mesh(new THREE.TorusGeometry(0.16, 0.018, 6, 12, Math.PI), mat(0x94a3b8, 0.4), bx, 0.18, 0));
        const bk = new THREE.Group(); bk.position.set(bx, 0.08, 0);
        bk.add(mesh(new THREE.CylinderGeometry(0.09, 0.09, 0.025, 8), mat(0x09090b, 0.9), -0.16, 0.09, 0));
        bk.add(mesh(new THREE.CylinderGeometry(0.09, 0.09, 0.025, 8), mat(0x09090b, 0.9), 0.16, 0.09, 0));
        bk.add(mesh(new THREE.BoxGeometry(0.22, 0.025, 0.025), mat(0x10b981, 0.6), 0, 0.14, 0));
        g.add(bk);
      }
      root.add(g);
      g.visible = false;
      return g;
    }
    enrichmentObjects["bike_station"] = buildBikeStation();

    // 6. Modern Public Art Sculpture (public_art_sculpture)
    function buildArtSculpture() {
      const g = new THREE.Group(); g.position.set(8.8, 0.22, -4.8);
      g.add(mesh(roundedBox(0.85, 0.40, 0.85, 0.08), mat(0x0f172a, 0.3, 0.8), 0, 0.20, 0));
      const torusMesh = mesh(new THREE.TorusKnotGeometry(0.26, 0.075, 36, 8), mat(0xfacc15, 0.2, 0.9), 0, 0.72, 0);
      g.add(torusMesh);
      animObjects.push({ type: "rotate_y", ref: torusMesh, speed: 0.4 });
      
      const aHit = mesh(new THREE.CylinderGeometry(0.6, 0.6, 1.2, 8), new THREE.MeshBasicMaterial({ visible: false }), 0, 0.6, 0);
      aHit.userData = { isSculpture: true, ref: g };
      g.add(aHit);
      interactiveCitizens.push(aHit);

      root.add(g);
      g.visible = false;
      return g;
    }
    enrichmentObjects["public_art_sculpture"] = buildArtSculpture();

    // 7. Artisan Coffee Stand (cafe_stand)
    function buildArtisanCafeStand() {
      const g = new THREE.Group(); g.position.set(-4.5, 0.22, -4.8);
      g.add(mesh(roundedBox(1.05, 0.60, 0.60, 0.06), mat(0x78350f, 0.8), 0, 0.30, 0));
      const awn = mesh(new THREE.BoxGeometry(1.15, 0.07, 0.70), mat(0xd97706, 0.6), 0, 0.82, 0);
      awn.rotation.x = 0.12; g.add(awn);
      g.add(mesh(new THREE.CylinderGeometry(0.04, 0.05, 0.08, 8), mat(0xffffff, 0.4), 0.2, 0.64, 0.1));
      
      const cHit = mesh(new THREE.BoxGeometry(1.3, 1.2, 0.9), new THREE.MeshBasicMaterial({ visible: false }), 0, 0.6, 0);
      cHit.userData = { isCoffeeStand: true, ref: g };
      g.add(cHit);
      interactiveCitizens.push(cHit);

      root.add(g);
      g.visible = false;
      return g;
    }
    enrichmentObjects["cafe_stand"] = buildArtisanCafeStand();

    // ================================================================
    // 🚶 POPULATE CITIZENS (STARTS WITH 1 RESIDENT — EXPANDS VIA PROGRESS)
    // ================================================================

    // 1. Founding Citizen (The 1 and only Starter Resident of the City Island)
    addWalkingCitizen({
      shirtColor: 0x3b82f6, pantsColor: 0x1e293b, hairColor: 0x451a03,
      isStarter: true,
      hasCoffee: true,
      speed: 0.26, initialProgress: 0.0,
      path: [{x: -4.8, z: -3.3}, {x: 4.8, z: -3.3}, {x: 4.8, z: -6.5}, {x: -4.8, z: -6.5}]
    });

    // 2. Creative Street Artist (Unlocked via resident_artist progress option)
    addWalkingCitizen({
      shirtColor: 0xa855f7, pantsColor: 0x1e293b, hairColor: 0xfde047,
      enrichmentId: "resident_artist",
      hasBag: true, bagColor: 0xec4899,
      speed: 0.24, initialProgress: 0.2,
      path: [{x: -4.5, z: -4.5}, {x: -9.5, z: -4.5}, {x: -9.5, z: -9.2}, {x: -4.5, z: -9.2}]
    });

    // 3. 🐕 Golden Dog Walker (Unlocked via pet_golden_dog progress option)
    addWalkingCitizen({
      shirtColor: 0x059669, pantsColor: 0x475569, hairColor: 0x92400e,
      enrichmentId: "pet_golden_dog",
      hasDog: true, dogColor: 0xd97706,
      speed: 0.22, initialProgress: 0.1,
      path: [
        {x: -4.6, z: 4.5}, {x: -5.4, z: 7.6}, {x: -7.8, z: 7.6},
        {x: -8.6, z: 4.8}, {x: -7.2, z: 3.8}, {x: -5.2, z: 3.8}
      ]
    });

    // 4. Fashion Shopper on Promenade (Progress resident)
    addWalkingCitizen({
      shirtColor: 0xec4899, pantsColor: 0x1e293b, hairColor: 0xfde047,
      enrichmentId: "resident_shopper",
      hasBag: true, bagColor: 0x9333ea,
      speed: 0.28, initialProgress: 0.0,
      path: [{x: 4.5, z: -4.5}, {x: 9.5, z: -4.5}, {x: 9.5, z: -9.2}, {x: 4.5, z: -9.2}]
    });

    // 5. Tech Enthusiast in Plaza (Progress resident)
    addWalkingCitizen({
      shirtColor: 0x0284c7, pantsColor: 0x334155, hairColor: 0x1f2937,
      enrichmentId: "resident_tech",
      hasPhone: true, hasCoffee: true,
      speed: 0.24, initialProgress: 0.45,
      path: [{x: 6.8, z: -4.5}, {x: 6.8, z: -9.2}, {x: 6.8, z: -4.5}]
    });

    // 6. Food District Gourmand (Progress resident)
    addWalkingCitizen({
      shirtColor: 0xd97706, pantsColor: 0x1e1b4b, hairColor: 0x1e293b,
      enrichmentId: "resident_coffee",
      hasCoffee: true,
      speed: 0.26, initialProgress: 0.2,
      path: [{x: -4.5, z: -4.5}, {x: -9.5, z: -4.5}, {x: -9.5, z: -9.2}, {x: -4.5, z: -9.2}]
    });

    // 7. Crosswalk Commuter (Progress resident)
    addWalkingCitizen({
      shirtColor: 0x10b981, pantsColor: 0x1e293b, hairColor: 0x78350f,
      enrichmentId: "resident_commuter",
      hasBag: true, bagColor: 0xf59e0b,
      speed: 0.30, initialProgress: 0.15,
      path: [{x: -4.8, z: -3.3}, {x: 4.8, z: -3.3}, {x: -4.8, z: -3.3}]
    });

    // 8. Grand Residence Tower Citizen (Progress resident)
    addWalkingCitizen({
      shirtColor: 0x6366f1, pantsColor: 0x1e293b, hairColor: 0x312e81,
      enrichmentId: "resident_housing",
      hasBag: true, bagColor: 0x06b6d4,
      speed: 0.24, initialProgress: 0.6,
      path: [{x: 4.5, z: 4.2}, {x: 9.5, z: 4.2}, {x: 9.5, z: 8.8}, {x: 4.5, z: 8.8}]
    });

    // 9. 🏃 Park Jogger on Trail (Progress resident)
    addWalkingCitizen({
      shirtColor: 0xf97316, pantsColor: 0x09090b, hairColor: 0x18181b,
      enrichmentId: "resident_jogger",
      isJogging: true,
      speed: 0.55, initialProgress: 0.7,
      path: [
        {x: -4.0, z: 4.0}, {x: -4.0, z: 8.8}, {x: -8.8, z: 8.8},
        {x: -8.8, z: 4.0}
      ]
    });

    // 10. 🚧 Starter Roadworks / City Development Crew (Active from Day 1)
    const starterCrew = createConstructionCrew("starter_city_works", 2.2, -4.6, root);
    starterCrew.isTemporary = false; // Always lively in the city center

    // ════════════════════════════════════════════════════════════════
    // 🎭 URBAN SATIRICAL CITIZENS & PHYSICAL MICRO-SCENES
    // ════════════════════════════════════════════════════════════════

    // 1. 🛴 Electric Lime Scooter Zoomer (Cruising down the promenade)
    function buildElectricScooterFigure() {
      const g = new THREE.Group();
      g.position.set(0, 0.22, -3.4);
      root.add(g);

      // Scooter Frame (Lime Green & Midnight Dark)
      const deck = mesh(roundedBox(0.85, 0.05, 0.22, 0.04), mat(0x84cc16, 0.4, 0.6), 0, 0.08, 0);
      g.add(deck);
      const stem = mesh(new THREE.CylinderGeometry(0.025, 0.025, 0.70, 8), mat(0x18181b, 0.8), 0.32, 0.42, 0);
      const bar = mesh(new THREE.BoxGeometry(0.03, 0.03, 0.32), mat(0x18181b, 0.8), 0.32, 0.76, 0);
      const light = mesh(new THREE.SphereGeometry(0.045, 8, 8), new THREE.MeshBasicMaterial({ color: 0x38bdf8 }), 0.35, 0.72, 0);
      g.add(stem, bar, light);
      
      // Wheels
      [[-0.35, 0], [0.35, 0]].forEach(wp => {
        const wh = mesh(new THREE.CylinderGeometry(0.09, 0.09, 0.05, 12), mat(0x09090b, 0.9), wp[0], 0.09, wp[1]);
        wh.rotation.x = Math.PI / 2;
        g.add(wh);
      });

      // Rider Figure with Oversized Headphones
      const rider = createMiniFigure({
        shirtColor: 0x6366f1, pantsColor: 0x09090b, hairColor: 0x451a03
      });
      // The mini-figure is modelled facing +Z — that is the convention the walking
      // citizens' heading maths assumes — while this scooter is modelled facing +X.
      // Without the quarter turn the rider stands sideways on the deck, which is what
      // made him look like he was riding a scooter lying on its side.
      const riderParts = rider.userData;
      rider.position.set(-0.05, 0.105, 0);
      rider.rotation.y = Math.PI / 2;
      // Hands forward onto the handlebar instead of hanging at his sides.
      if (riderParts) {
        if (riderParts.armL) riderParts.armL.rotation.x = -1.45;
        if (riderParts.armR) riderParts.armR.rotation.x = -1.45;
        // Front foot ahead, back foot behind: a scooter stance, not a standing pose.
        if (riderParts.legL) riderParts.legL.position.z = 0.10;
        if (riderParts.legR) riderParts.legR.position.z = -0.09;
      }
      const hpL = mesh(new THREE.SphereGeometry(0.04, 6, 6), mat(0xec4899, 0.3), -0.09, 0.64, 0);
      const hpR = mesh(new THREE.SphereGeometry(0.04, 6, 6), mat(0xec4899, 0.3), 0.09, 0.64, 0);
      const hpBand = mesh(new THREE.TorusGeometry(0.09, 0.015, 6, 8, Math.PI), mat(0x1e293b, 0.8), 0, 0.64, 0);
      hpBand.rotation.z = Math.PI;
      rider.add(hpL, hpR, hpBand);
      g.add(rider);

      const uData = {
        fig: g,
        isScooter: true,
        rider: rider,
        phrases: [
          "זה מדרכה או אוטוסטרדה?!",
          "דקה אני ברוטשילד!",
          "הברקסים חורקים אבל יש לי ביטוח",
          "שמתי וויז על מהירות 40 קמ״ש"
        ],
        phrasesEn: [
          "Is this a sidewalk or a highway?!",
          "1 min to Rothschild!",
          "Brakes are squeaking but I'm in a rush!",
          "Cruising at max battery speed"
        ],
        progress: 0.2,
        hopTimer: 0
      };
      g.userData = uData;
      rider.userData = uData;
      return g;
    }
    const scooterZoomer = buildElectricScooterFigure();

    // 2. 👮‍♂️ Municipal Parking Inspector
    function buildParkingInspector() {
      const g = new THREE.Group();
      g.position.set(1.5, 0.22, -1.8);
      root.add(g);

      const insp = createMiniFigure({
        shirtColor: 0x1e3a8a, pantsColor: 0x0f172a, hairColor: 0x18181b
      });
      g.add(insp);

      // Inspector Cap
      const cap = mesh(new THREE.CylinderGeometry(0.10, 0.10, 0.04, 10), mat(0x1e3a8a, 0.8), 0, 0.72, 0);
      const visor = mesh(new THREE.BoxGeometry(0.11, 0.015, 0.06), mat(0x09090b, 0.9), 0, 0.70, 0.06);
      insp.add(cap, visor);

      const terminal = mesh(new THREE.BoxGeometry(0.045, 0.08, 0.02), mat(0x09090b, 0.8), 0, -0.16, 0.06);
      if (insp.userData && insp.userData.armL) insp.userData.armL.add(terminal);

      const uData = {
        fig: g,
        phrases: [
          "אחי, רק שתי דקות על כחול-לבן!",
          "חנית על אדום-לבן, אל תתווכח",
          "קנס 250 ש״ח על פריקת סחורה",
          "אין פה פנגו? תשלם דוח"
        ],
        phrasesEn: [
          "Bro, only stepped out for 2 mins!",
          "Parked on red-and-white, don't argue",
          "₪250 fine for double parking",
          "No parking app active? That's a ticket"
        ],
        hopTimer: 0
      };
      g.userData = uData;
      insp.userData = uData;
      return g;
    }
    const parkingInspector = buildParkingInspector();

    // 3. 📸 Influencer with Selfie Stick & Coffee
    function buildInfluencer() {
      const g = new THREE.Group();
      g.position.set(-0.7, 0.22, -3.8);
      root.add(g);

      const figure = createMiniFigure({
        shirtColor: 0xf43f5e, pantsColor: 0xf8fafc, hairColor: 0xfde047, hasCoffee: true
      });
      g.add(figure);

      const stick = mesh(new THREE.CylinderGeometry(0.008, 0.008, 0.35, 6), mat(0xd1d5db, 0.5), 0, -0.15, 0.16);
      stick.rotation.x = -Math.PI / 3;
      const phone = mesh(new THREE.BoxGeometry(0.05, 0.09, 0.012), mat(0xec4899, 0.3, 0.8), 0, 0.16, 0);
      phone.rotation.x = Math.PI / 6;
      stick.add(phone);
      if (figure.userData && figure.userData.armR) figure.userData.armR.add(stick);

      const uData = {
        fig: g,
        phrases: [
          "רק עוד 40 תמונות לאינסטגרם",
          "הקפה כבר קר אבל התאורה מושלמת!",
          "חייבת לתייג את בית הקפה בשביל הנחה",
          "מי מצלם אותי ספונטני עכשיו?"
        ],
        phrasesEn: [
          "Just 40 more takes for Insta",
          "Coffee is cold but lighting is fire!",
          "Tagging the cafe for that 10% discount",
          "Can someone take a 'candid' photo of me?"
        ],
        hopTimer: 0
      };
      g.userData = uData;
      figure.userData = uData;
      return g;
    }
    const influencerFigure = buildInfluencer();

    // 4. 🧑‍💻 Tech Worker with Laptop on Park Bench
    function buildTechWorkerOnBench() {
      const g = new THREE.Group();
      g.position.set(-4.8, 0.22, 7.4);
      root.add(g);

      const worker = createMiniFigure({
        shirtColor: 0x0284c7, pantsColor: 0x1e293b, hairColor: 0x1f2937, isSitting: true
      });
      g.add(worker);

      const laptopBase = mesh(new THREE.BoxGeometry(0.18, 0.012, 0.14), mat(0xd1d5db, 0.3, 0.9), 0, 0.20, 0.10);
      const laptopScreen = mesh(new THREE.BoxGeometry(0.18, 0.12, 0.010), new THREE.MeshBasicMaterial({ color: 0x38bdf8 }), 0, 0.06, -0.06);
      laptopScreen.rotation.x = -0.35;
      laptopBase.add(laptopScreen);
      worker.add(laptopBase);

      const uData = {
        fig: g,
        phrases: [
          "משחרר גרסה לפרודקשן מהפארק...",
          "מישהו יודע מה הסיסמה ל-WiFi של העירייה?",
          "אני בהייטק אבל שותה נס של עלית",
          "זום מנהלים בעוד 3 דקות, איפה השקט?"
        ],
        phrasesEn: [
          "Deploying to prod from the park...",
          "Anyone know the city WiFi password?",
          "Work in high-tech, drink instant coffee",
          "Executive Zoom call in 3 mins, need silence"
        ],
        hopTimer: 0
      };
      g.userData = uData;
      worker.userData = uData;
      return g;
    }
    const techWorkerOnBench = buildTechWorkerOnBench();

    // 5. 🎸 Street Musician in Plaza Arcade
    function buildStreetMusician() {
      const g = new THREE.Group();
      g.position.set(4.2, 0.22, -4.8);
      root.add(g);

      const busker = createMiniFigure({
        shirtColor: 0x10b981, pantsColor: 0x334155, hairColor: 0x92400e
      });
      g.add(busker);

      const guitar = new THREE.Group();
      guitar.position.set(0, 0.35, 0.12);
      guitar.rotation.z = -0.4;
      const gBody = mesh(new THREE.BoxGeometry(0.16, 0.22, 0.06), mat(0xd97706, 0.7), 0, 0, 0);
      const gNeck = mesh(new THREE.CylinderGeometry(0.015, 0.015, 0.24, 6), mat(0x78350f, 0.8), 0, 0.20, 0);
      guitar.add(gBody, gNeck);
      busker.add(guitar);

      const gCase = mesh(new THREE.BoxGeometry(0.24, 0.06, 0.40), mat(0x1e293b, 0.9), 0.35, 0.03, 0.15);
      const coin = mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.005, 8), new THREE.MeshBasicMaterial({ color: 0xfacc15 }), 0, 0.035, 0);
      gCase.add(coin);
      g.add(gCase);

      const uData = {
        fig: g,
        phrases: [
          "מנגן שלמה ארצי בשביל שקלים",
          "אפשר להעביר טיפ גם ב-Apple Pay?",
          "השיר הבא מוקדש לתקציב החודשי",
          "גיטריסט מוסמך, עובד בשביל קפה"
        ],
        phrasesEn: [
          "Playing classic tunes for coins",
          "Do you take tips via Apple Pay?",
          "Next song is dedicated to monthly savings",
          "Certified musician, playing for coffee"
        ],
        hopTimer: 0
      };
      g.userData = uData;
      busker.userData = uData;
      return g;
    }
    const streetMusician = buildStreetMusician();

    // 6. 🧘‍♀️ Park Yoga Guru
    function buildYogaPractitioner() {
      const g = new THREE.Group();
      g.position.set(-7.4, 0.22, 6.2);
      root.add(g);

      const matMesh = mesh(roundedBox(0.45, 0.015, 0.90, 0.02), mat(0xa855f7, 0.8), 0, 0.01, 0);
      g.add(matMesh);

      const yogi = createMiniFigure({
        shirtColor: 0x06b6d4, pantsColor: 0x09090b, hairColor: 0x451a03
      });
      yogi.position.set(0, 0, 0);
      if (yogi.userData && yogi.userData.legL) {
        yogi.userData.legL.rotation.z = 0.8;
        yogi.userData.legL.position.y = 0.28;
      }
      if (yogi.userData && yogi.userData.armL && yogi.userData.armR) {
        yogi.userData.armL.rotation.z = -1.2;
        yogi.userData.armR.rotation.z = 1.2;
      }
      g.add(yogi);

      const uData = {
        fig: g,
        phrases: [
          "נושמת פנימה שלווה, נושפת החוצה את השכירות",
          "נמסטה והעברתי בביט",
          "שומרת על איזון כלכלי ופנימי",
          "תנוחת עץ הדובדבן למשיכת שפע"
        ],
        phrasesEn: [
          "Inhaling peace, exhaling the rent",
          "Namaste and I sent it via Bit",
          "Balancing my inner energy and budget",
          "Tree pose for financial mindfulness"
        ],
        hopTimer: 0
      };
      g.userData = uData;
      yogi.userData = uData;
      return g;
    }
    const yogaPractitioner = buildYogaPractitioner();

    // ────────────────────────────────────────────────────────────────
    // 🚗  CALM & SEPARATED VEHICLES (NO OVERLAPPING / NO CRASHING)
    // ────────────────────────────────────────────────────────────────
    function buildWoltScooter() {
      const g = new THREE.Group();
      // Cyan scooter chassis with black footboard
      g.add(mesh(roundedBox(1.08, 0.22, 0.34, 0.10), mat(0x00c2e8, 0.3, 0.5), 0, 0.22, 0));
      g.add(mesh(new THREE.BoxGeometry(0.55, 0.04, 0.26), mat(0x18181b, 0.9), 0, 0.34, 0));
      // Steering column & headlight
      g.add(mesh(new THREE.CylinderGeometry(0.035, 0.035, 0.65, 8), mat(0x1e293b, 0.5), 0.38, 0.52, 0));
      g.add(mesh(new THREE.SphereGeometry(0.075, 8, 8), new THREE.MeshBasicMaterial({ color: 0xffffff }), 0.42, 0.60, 0));
      // Handlebars
      g.add(mesh(new THREE.BoxGeometry(0.04, 0.04, 0.32), mat(0x18181b, 0.8), 0.38, 0.76, 0));
      // Red Taillight
      g.add(mesh(new THREE.BoxGeometry(0.06, 0.06, 0.12), new THREE.MeshBasicMaterial({ color: 0xef4444 }), -0.52, 0.30, 0));
      // Rider Figure with Wolt Helmet & Backpack
      g.add(mesh(new THREE.CylinderGeometry(0.12, 0.14, 0.44, 8), mat(0x00c2e8, 0.8), -0.08, 0.52, 0));
      g.add(mesh(new THREE.SphereGeometry(0.14, 12, 10), mat(0x00c2e8, 0.4, 0.6), -0.08, 0.84, 0));
      g.add(mesh(new THREE.BoxGeometry(0.36, 0.38, 0.36), new THREE.MeshStandardMaterial({ map: woltTex(), roughness: 0.4 }), -0.32, 0.60, 0));
      // Rubber wheels with chrome hubs
      [[-0.42, 0],[0.42, 0]].forEach(p => {
        const wh = mesh(new THREE.CylinderGeometry(0.16, 0.16, 0.10, 14), mat(0x09090b, 0.9), p[0], 0.16, p[1]);
        wh.rotation.x = Math.PI / 2; g.add(wh);
        const hub = mesh(new THREE.CylinderGeometry(0.08, 0.08, 0.11, 10), mat(0xd1d5db, 0.2, 0.9), p[0], 0.16, p[1]);
        hub.rotation.x = Math.PI / 2; g.add(hub);
      });
      const smoke = new THREE.Group(); smoke.position.set(-0.65, 0.16, 0);
      const sM = new THREE.MeshStandardMaterial({ color: 0xd1d5db, transparent: true, opacity: 0.72, roughness: 0.9 });
      for (let i = 0; i < 3; i++) smoke.add(mesh(new THREE.SphereGeometry(0.08 + i * 0.03, 8, 8), sM, -i * 0.16, i * 0.05, 0, false, false));
      g.add(smoke); g.userData.smoke = smoke;
      return g;
    }

    function buildTaxi() {
      const g = new THREE.Group();
      // Yellow cab chassis
      g.add(mesh(roundedBox(1.95, 0.42, 0.90, 0.18), mat(0xfacc15, 0.2, 0.5), 0, 0.22, 0));
      // Dark cabin & windows
      g.add(mesh(roundedBox(1.05, 0.38, 0.82, 0.14), mat(0x0f172a, 0.1, 0.9), -0.05, 0.58, 0));
      // Checker side decals
      const checkerMat = mat(0x18181b, 0.9);
      [-0.4, 0, 0.4].forEach(cx => {
        g.add(mesh(new THREE.BoxGeometry(0.18, 0.08, 0.01), checkerMat, cx, 0.25, 0.46));
        g.add(mesh(new THREE.BoxGeometry(0.18, 0.08, 0.01), checkerMat, cx, 0.25, -0.46));
      });
      // TAXI Rooftop Sign with Warm Light
      const signM = new THREE.MeshStandardMaterial({ color: 0xffffff, emissive: 0xfef08a, emissiveIntensity: 2.4 });
      g.add(mesh(new THREE.BoxGeometry(0.38, 0.14, 0.18), signM, -0.05, 0.84, 0));
      // Chrome front bumper & grille
      g.add(mesh(new THREE.BoxGeometry(0.06, 0.12, 0.72), mat(0x94a3b8, 0.2, 0.9), 1.0, 0.16, 0));
      // Headlights (White glow)
      g.add(mesh(new THREE.BoxGeometry(0.04, 0.10, 0.18), new THREE.MeshBasicMaterial({ color: 0xffffff }), 1.0, 0.26, 0.30));
      g.add(mesh(new THREE.BoxGeometry(0.04, 0.10, 0.18), new THREE.MeshBasicMaterial({ color: 0xffffff }), 1.0, 0.26, -0.30));
      // Taillights (Red glow)
      g.add(mesh(new THREE.BoxGeometry(0.04, 0.09, 0.18), new THREE.MeshBasicMaterial({ color: 0xef4444 }), -1.0, 0.26, 0.30));
      g.add(mesh(new THREE.BoxGeometry(0.04, 0.09, 0.18), new THREE.MeshBasicMaterial({ color: 0xef4444 }), -1.0, 0.26, -0.30));
      // Wheels with silver hubcaps
      [[-0.6,0.46],[0.6,0.46],[-0.6,-0.46],[0.6,-0.46]].forEach(p => {
        const wh = mesh(new THREE.CylinderGeometry(0.18, 0.18, 0.11, 14), mat(0x09090b, 0.9), p[0], 0.18, p[1]);
        wh.rotation.x = Math.PI / 2; g.add(wh);
        const hub = mesh(new THREE.CylinderGeometry(0.09, 0.09, 0.12, 10), mat(0xd1d5db, 0.2, 0.9), p[0], 0.18, p[1]);
        hub.rotation.x = Math.PI / 2; g.add(hub);
      });
      return g;
    }

    function buildCityBus() {
      const g = new THREE.Group();
      // Mint-green & White Electric City Bus
      g.add(mesh(roundedBox(2.8, 0.75, 1.05, 0.16), mat(0x10b981, 0.3, 0.6), 0, 0.45, 0));
      // Roof White Cap
      g.add(mesh(roundedBox(2.82, 0.16, 1.06, 0.12), mat(0xf8fafc, 0.4, 0.5), 0, 0.88, 0));
      // Panoramic Glass Strip
      g.add(mesh(new THREE.BoxGeometry(2.65, 0.32, 1.07), mat(0x0f172a, 0.1, 0.95), 0, 0.58, 0));
      // Rooftop AC Units
      g.add(mesh(new THREE.BoxGeometry(0.70, 0.12, 0.60), mat(0xd1d5db, 0.5), -0.5, 1.00, 0));
      // LED Destination Screen ("MONEY CITY")
      g.add(mesh(new THREE.BoxGeometry(0.04, 0.10, 0.65), new THREE.MeshStandardMaterial({ color: 0x38bdf8, emissive: 0x38bdf8, emissiveIntensity: 2.5 }), 1.42, 0.82, 0));
      // Headlights & Taillights
      g.add(mesh(new THREE.BoxGeometry(0.04, 0.12, 0.22), new THREE.MeshBasicMaterial({ color: 0xffffff }), 1.42, 0.25, 0.36));
      g.add(mesh(new THREE.BoxGeometry(0.04, 0.12, 0.22), new THREE.MeshBasicMaterial({ color: 0xffffff }), 1.42, 0.25, -0.36));
      g.add(mesh(new THREE.BoxGeometry(0.04, 0.12, 0.22), new THREE.MeshBasicMaterial({ color: 0xef4444 }), -1.42, 0.25, 0.36));
      g.add(mesh(new THREE.BoxGeometry(0.04, 0.12, 0.22), new THREE.MeshBasicMaterial({ color: 0xef4444 }), -1.42, 0.25, -0.36));
      // 4 Heavy Wheels
      [[-0.9, 0.52], [0.9, 0.52], [-0.9, -0.52], [0.9, -0.52]].forEach(p => {
        const wh = mesh(new THREE.CylinderGeometry(0.20, 0.20, 0.12, 14), mat(0x09090b, 0.9), p[0], 0.20, p[1]);
        wh.rotation.x = Math.PI / 2; g.add(wh);
      });
      return g;
    }

    // 3 Dedicated Non-Overlapping Road Lanes:
    const CALM_LANES = [
      // Lane 1: East-to-West (North lane of main avenue)
      [{x: 12.0, z: -1.6}, {x: -12.0, z: -1.6}],
      // Lane 2: West-to-East (South lane of main avenue)
      [{x: -12.0, z: -0.2}, {x: 12.0, z: -0.2}],
      // Lane 3: South-to-North (East lane of cross avenue)
      [{x: 1.2, z: 12.0}, {x: 1.2, z: -12.0}]
    ];

    const vehicleFleet = [
      { id: "taxi", lane: "westbound", obj: buildTaxi(), route: CALM_LANES[0], speed: 0.040, initialProg: 0.1, isBus: false },
      { id: "wolt", lane: "eastbound", obj: buildWoltScooter(), route: CALM_LANES[1], speed: 0.048, initialProg: 0.55, isBus: false },
      { id: "bus", lane: "northbound", obj: buildCityBus(), route: CALM_LANES[2], speed: 0.035, initialProg: 0.85, isBus: true }
    ];

    const vehicleState = [];
    vehicleFleet.forEach(vf => {
      root.add(vf.obj);
      vehicleState.push({
        id: vf.id,
        lane: vf.lane,
        obj: vf.obj,
        route: vf.route,
        speed: vf.speed,
        progress: vf.initialProg,
        pauseTimer: 0,
        isBus: vf.isBus,
        hasPausedAtBusStop: false,
        lastYieldTime: 0
      });
    });

    // ────────────────────────────────────────────────────────────────
    // TOUCH & DRAG ROTATION & PINCH ZOOM ENGINE (iOS 17/18 Optimized)
    // ────────────────────────────────────────────────────────────────
    let isDown = false, isDragging = false, isPinching = false;
    let startX = 0, startY = 0;
    let downTime = 0;
    let startPinchDist = 0;
    let startPinchZoom = 1.35;

    function onDown(clientX, clientY) {
      isDown = true;
      isDragging = false;
      startX = clientX;
      startY = clientY;
      downTime = performance.now();
    }

    function onMove(clientX, clientY) {
      if (!isDown || isPinching) return;
      const dx = clientX - startX;
      const dy = clientY - startY;
      if (Math.abs(dx) > 2 || Math.abs(dy) > 2) {
        isDragging = true;
        targetCam.az -= dx * 0.007;
        targetCam.el = Math.max(0.20, Math.min(1.30, targetCam.el + dy * 0.007));
        startX = clientX;
        startY = clientY;
      }
    }

    function onUp(clientX, clientY) {
      if (!isDown) return;
      isDown = false;
      if (isPinching) {
        isPinching = false;
        return;
      }
      const elapsed = performance.now() - downTime;
      if (!isDragging || elapsed < 220) {
        const rect = stage.getBoundingClientRect();
        mouse.x = ((clientX - rect.left) / rect.width) * 2 - 1;
        mouse.y = -((clientY - rect.top) / rect.height) * 2 + 1;
        raycaster.setFromCamera(mouse, camera);

        // 1. Check if Citizen, Pet, Slot or Enrichment Tapped!
        const cHits = raycaster.intersectObjects(interactiveCitizens, false);
        if (cHits.length > 0) {
          const u = cHits[0].object.userData;
          if (u) {
            const targetObj = u.fig || u.dog || u.cat || u.ref || cHits[0].object;
            if (targetObj && targetObj.visible !== false) {
              u.hopTimer = 0.40;
              
              const ph = getDioramaPhrases();
              if (u.isSlot) {
                popEmojiBubble(targetObj, u.slotName || ph.vacantSlot, 2.4);
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.slotTapped) {
                  try { window.webkit.messageHandlers.slotTapped.postMessage({ slotId: u.slotId, slotName: u.slotName }); } catch(e) {}
                }
                return;
              }

              let phrase = ph.tap[0];
              if (u.phrases && u.phrases.length > 0) {
                const list = currentLanguage === "he" ? u.phrases : (u.phrasesEn || u.phrases);
                phrase = list[Math.floor(Math.random() * list.length)];
              } else if (u.isWorker) {
                const cQuotes = ph.construction || ["עוד שתי דקות מסיימים...", "יצא פיקס! הקפה עליך"];
                phrase = cQuotes[Math.floor(Math.random() * cQuotes.length)];
              } else if (u.isCat) {
                phrase = ph.cat[Math.floor(Math.random() * ph.cat.length)];
              } else if (u.isDog) {
                phrase = ph.dog[Math.floor(Math.random() * ph.dog.length)] || ph.dog;
              } else if (u.isFountain) {
                phrase = ph.fountain;
              } else if (u.isSakura) {
                phrase = ph.sakura;
              } else if (u.isCoffeeStand) {
                phrase = ph.coffeeStand;
              } else if (u.isSculpture) {
                phrase = ph.sculpture;
              } else if (u.phrase) {
                phrase = u.phrase;
              } else {
                phrase = ph.tap[Math.floor(Math.random() * ph.tap.length)];
              }
              popEmojiBubble(targetObj, phrase, 2.5);
              if (u.slotId && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.slotTapped) {
                try { window.webkit.messageHandlers.slotTapped.postMessage({ slotId: u.slotId, currentItem: u.isCat ? "pet_cat_rooftop" : (u.isFountain ? "fountain_marble" : (u.isSakura ? "tree_sakura" : (u.isCoffeeStand ? "cafe_stand" : (u.isSculpture ? "public_art_sculpture" : "")))) }); } catch(e) {}
              }
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.citizenTapped) {
                try { window.webkit.messageHandlers.citizenTapped.postMessage({}); } catch(e) {}
              }
              return;
            }
          }
        }

        // 2. Check if Building Tapped!
        const hits = raycaster.intersectObjects(interactiveBuildings, false);
        if (hits.length > 0) {
          const bData = hits[0].object.userData;
          if (bData) {
            if (currentMode === "city" && CAM_MODES[bData.district]) {
              setDistrict(bData.district);
            }
            if (window.webkit && window.webkit.messageHandlers.districtSelected)
              window.webkit.messageHandlers.districtSelected.postMessage(bData.district);
            if (window.webkit && window.webkit.messageHandlers.buildingTapped)
              window.webkit.messageHandlers.buildingTapped.postMessage(bData);
          }
        }
      }
      isDragging = false;
    }

    // Touch events for iOS with 2-finger pinch zoom
    stage.addEventListener("touchstart", e => {
      if (e.touches && e.touches.length === 2) {
        isPinching = true;
        isDown = false;
        isDragging = false;
        startPinchDist = Math.hypot(
          e.touches[0].clientX - e.touches[1].clientX,
          e.touches[0].clientY - e.touches[1].clientY
        );
        startPinchZoom = (targetCam && targetCam.zoom) || 1.35;
      } else if (e.touches && e.touches.length === 1) {
        isPinching = false;
        onDown(e.touches[0].clientX, e.touches[0].clientY);
      }
    }, { passive: true });

    stage.addEventListener("touchmove", e => {
      if (e.touches && e.touches.length === 2 && isPinching && startPinchDist > 0) {
        const dist = Math.hypot(
          e.touches[0].clientX - e.touches[1].clientX,
          e.touches[0].clientY - e.touches[1].clientY
        );
        const scale = dist / startPinchDist;
        if (isFinite(scale) && scale > 0) {
          targetCam.zoom = Math.max(0.60, Math.min(3.80, startPinchZoom * scale));
        }
      } else if (e.touches && e.touches.length === 1 && !isPinching) {
        onMove(e.touches[0].clientX, e.touches[0].clientY);
      }
    }, { passive: true });

    stage.addEventListener("touchend", e => {
      if (!e.touches || e.touches.length < 2) isPinching = false;
      if (e.changedTouches && e.changedTouches.length > 0) {
        onUp(e.changedTouches[0].clientX, e.changedTouches[0].clientY);
      } else {
        isDown = false; isDragging = false;
      }
    }, { passive: true });

    stage.addEventListener("touchcancel", () => { isDown = false; isDragging = false; isPinching = false; }, { passive: true });

    // Pointer & Wheel events for desktop Xcode Canvas & Simulator
    stage.addEventListener("pointerdown", e => { onDown(e.clientX, e.clientY); });
    window.addEventListener("pointermove", e => { onMove(e.clientX, e.clientY); });
    window.addEventListener("pointerup", e => { onUp(e.clientX, e.clientY); });
    window.addEventListener("pointercancel", () => { isDown = false; isDragging = false; });
    window.addEventListener("wheel", e => {
      if (e.deltaY) {
        targetCam.zoom = Math.max(0.60, Math.min(3.80, (targetCam.zoom || 1.35) - e.deltaY * 0.002));
      }
    }, { passive: true });

    function setDistrict(id) {
      currentMode = (id && CAM_MODES[id]) ? id : "city";
      targetCam = Object.assign({}, CAM_MODES[currentMode]);
    }
    window.setDistrict = setDistrict;

    const CATEGORY_BASELINES = {
      "food_bistro":    500,  // Restaurants & Dining (₪500 standard)
      "food_super":     450,  // Supermarkets & Groceries (₪450 standard)
      "food_coffee":    200,  // Coffee & Cafes (₪200 standard: ₪60 is stall, ₪600 is mega-cafe)
      "food_wolt":      250,  // Wolt / Deliveries (₪250 standard: ₪70 is cart, ₪900 is swarm)
      "shop_boutique":  450,  // Clothing & Fashion (₪450 standard: ₪100 is stall, ₪1800 is mall)
      "shop_tech":      350,  // Tech & Electronics
      "shop_travel":    900,  // Travel & Flights
      "shop_arcade":    200,  // Entertainment & Arcade
      "house_tower":   4000,  // Rent & Housing (₪3800 is standard building, ₪8500 is skyscraper)
      "house_util":     400,  // Utilities & Bills
      "house_subs":     120   // Monthly Subscriptions (₪40 is booth, ₪350 is satellite tower)
    };

    function calcBuildingTransform(amount, buildingId) {
      if (!amount || amount <= 0) {
        return { scaleY: 0.05, scaleXZ: 0.05, tier: 0, tierName: "מגרש פנוי", ratio: 0 };
      }
      
      const baseline = CATEGORY_BASELINES[buildingId] || 350;
      const ratio = amount / baseline;
      
      let sXZ, sY, tier, tierName;
      if (ratio < 0.45) {
        // Tier 1: Authentic Street Cart / Market Stall / Pop-Up Stand (<45% of baseline)
        tier = 1;
        tierName = "דוכן רחוב קטן";
        sXZ = 1.0;
        sY  = 1.0;
      } else if (ratio < 0.90) {
        // Tier 2: Cozy 1-Story Boutique Shop (45% - 90% of baseline)
        const f = (ratio - 0.45) / 0.45;
        sXZ = 0.65 + f * 0.15; // 0.65 - 0.80
        sY  = 0.60 + f * 0.20; // 0.60 - 0.80
        tier = 2;
        tierName = "חנות בוטיק";
      } else if (ratio < 1.40) {
        // Tier 3: Standard Balanced Branch (90% - 140% of baseline)
        const f = (ratio - 0.90) / 0.50;
        sXZ = 0.88 + f * 0.14; // 0.88 - 1.02
        sY  = 0.92 + f * 0.28; // 0.92 - 1.20
        tier = 3;
        tierName = "סניף מרכזי";
      } else {
        // Tier 4: Over-scaled Megastructure / Tower (>140% of baseline)
        const f = Math.min(2.5, (ratio - 1.40) / 1.0);
        sXZ = 1.05 + f * 0.10; // 1.05 - 1.30
        sY  = 1.35 + f * 0.60; // 1.35 - 2.85
        tier = 4;
        tierName = "מבנה ענק מפלצתי";
      }
      return { scaleY: sY, scaleXZ: sXZ, tier, tierName, ratio };
    }


    // ================================================================
    // 🎉 3D CELEBRATORY ENRICHMENT SPAWN & CONFETTI ENGINE
    // ================================================================
    const confettiParticles = [];
    const confettiGeo = new THREE.PlaneGeometry(0.14, 0.14);
    const confettiColors = [0xfacc15, 0xef4444, 0x3b82f6, 0x10b981, 0xec4899, 0xa855f7, 0xf97316, 0x38bdf8];
    const confettiMats = confettiColors.map(c => new THREE.MeshBasicMaterial({ color: c, side: THREE.DoubleSide }));

    window.celebrateNewEnrichment = function(eId) {
      if (!eId) return;
      const item = enrichmentObjects[eId];
      if (!item) return;

      const targetObj = item.isCitizen ? item.fig : item;
      if (!targetObj) return;

      const wp = new THREE.Vector3();
      targetObj.getWorldPosition(wp);
      targetCam.lookX = wp.x;
      targetCam.lookY = Math.max(0.3, wp.y + 0.35);
      targetCam.lookZ = wp.z;
      targetCam.zoom = Math.max(1.8, Math.min(2.7, (targetCam.zoom || 1.35) * 1.35));

      targetObj.scale.set(0.01, 0.01, 0.01);
      targetObj.visible = true;
      if (item.dog) { item.dog.scale.set(0.01, 0.01, 0.01); item.dog.visible = true; }

      const bounceAnim = {
        type: "spawn_bounce",
        target: targetObj,
        dog: item.dog,
        time: 0,
        duration: 1.2
      };
      animObjects.push(bounceAnim);

      for (let i = 0; i < 35; i++) {
        const matIdx = Math.floor(Math.random() * confettiMats.length);
        const pMesh = new THREE.Mesh(confettiGeo, confettiMats[matIdx]);
        pMesh.position.set(wp.x + (Math.random() - 0.5) * 0.4, wp.y + 0.15, wp.z + (Math.random() - 0.5) * 0.4);
        const angle = Math.random() * Math.PI * 2;
        const speed = 1.6 + Math.random() * 2.8;
        const upSpeed = 3.0 + Math.random() * 3.6;
        pMesh.userData = {
          vx: Math.cos(angle) * speed,
          vy: upSpeed,
          vz: Math.sin(angle) * speed,
          rotX: (Math.random() - 0.5) * 16,
          rotY: (Math.random() - 0.5) * 16,
          rotZ: (Math.random() - 0.5) * 16,
          life: 1.8 + Math.random() * 0.9,
          maxLife: 2.7
        };
        root.add(pMesh);
        confettiParticles.push(pMesh);
      }

      const celebrationTitles = {
        "pet_cat_rooftop": "🐱 חתול ג'ינג'ר חדש הצטרף לעיר! 🐾",
        "pet_golden_dog": "🐕 כלב גולדן הגיע לפארק! 🐾",
        "fountain_marble": "⛲ מזרקת שיש יוקרתית נחנכה! 💎",
        "tree_sakura": "🌸 עץ דובדבן פורח בטיילת! 🌺",
        "flower_bed_plaza": "🌷 ערוגת פרחים מרהיבה נוספה!",
        "bike_station": "🚲 תחנת אופניים ירוקה נפתחה!",
        "public_art_sculpture": "🗿 פסל אמנות מודרני הוצב בכיכר!",
        "cafe_stand": "☕ דוכן אספרסו חדש ברחוב!",
        "resident_artist": "🎨 צייר מוכשר הגיע לעיר!",
        "resident_shopper": "🛍️ חובב אופנה הצטרף לשדרת החנויות!",
        "resident_tech": "💻 מפתח הייטק פתח משרד בעיר!",
        "resident_coffee": "☕ חובב קפה מושבע הצטרף!",
        "resident_jogger": "🏃 רץ אנרגטי הצטרף למסלול הפארק!",
        "resident_commuter": "🚶 תושב חדש הצטרף לטיילת!",
        "resident_housing": "🪴 דייר חדש עבר למגדל המגורים!"
      };
      const title = celebrationTitles[eId] || "🏛️ שדרוג חדש נבנה בעיר! 🎉";
      setTimeout(() => {
        popEmojiBubble(targetObj, title, 3.8);
      }, 350);
    };

    // The first payload is the app telling the diorama what the city already looks
    // like. Everything after it is a change the user just caused — and only a change
    // deserves a construction crew or an arrival celebration.
    let hasHydratedCity = false;

    window.updateDioramaData = function(data) {
      if (!data) return;
      try {
        if (data.newlyUnlockedId) {
          window.celebrateNewEnrichment(data.newlyUnlockedId);
        }

        if (data.targetDistrict !== undefined) {
          setDistrict(data.targetDistrict);
        }

        function syncBuilding(id, amount, body, trendActive) {
          const bg = buildingRoots[id];
          const ps = plotSites[id];
          const hasSpend = (amount !== undefined && amount > 0);
          const tf = calcBuildingTransform(amount, id);
          const isStall = hasSpend && (tf.tier === 1);
          const isBuilding = hasSpend && (tf.tier >= 2);

          if (bg) {
            const wasEmpty = (bg.userData.hasSpend !== true);
            if (wasEmpty && hasSpend) {
              bg.userData.hasSpend = true;
              // Skipped on the first payload: otherwise opening the app drops a crew on
              // every building the user already has, which says "twelve new buildings"
              // when nothing was built at all.
              if (hasHydratedCity) {
                // The matrices are only refreshed by the render loop, and the very first
                // payload can arrive before a single frame has run — without this the
                // crew is placed from a stale matrix and lands at the island's origin.
                bg.updateWorldMatrix(true, false);
                const wp = new THREE.Vector3();
                bg.getWorldPosition(wp);
                startConstruction(id, bg, wp);
              }
            } else if (!hasSpend) {
              bg.userData.hasSpend = false;
              bg.userData.underConstruction = false;
            }

            bg.visible = hasSpend;
            if (bg.userData.stallGroup) {
              bg.userData.stallGroup.visible = isStall;
            }
            if (bg.userData.buildingGroup) {
              bg.userData.buildingGroup.visible = isBuilding;
              bg.userData.targetScaleY  = isBuilding ? tf.scaleY  : 1.0;
              bg.userData.targetScaleXZ = isBuilding ? tf.scaleXZ : 1.0;
            } else {
              bg.userData.targetScaleY  = hasSpend ? tf.scaleY  : 0.05;
              bg.userData.targetScaleXZ = hasSpend ? tf.scaleXZ : 0.05;
            }
          }
          if (ps) {
            ps.visible = !hasSpend;
          }
          if (body) {
            body.userData.amount = Math.round(amount || 0);
            body.userData.tier = tf.tier;
            body.userData.tierName = tf.tierName;
            body.userData.ratio = tf.ratio;
            body.userData.trend = hasSpend ? (trendActive + " • " + tf.tierName) : "שטח בבנייה • ₪0 החודש";
          }
          if (districtBuildingTags[id]) {
            const tag = districtBuildingTags[id];
            tag.amount = amount || 0;
            const hasSpend = (amount && amount > 0);
            if (tag.amountEl) {
              tag.amountEl.textContent = hasSpend ? ("₪" + Math.round(amount).toLocaleString("he-IL")) : "₪0";
              if (hasSpend) {
                tag.amountEl.classList.remove("zero");
              } else {
                tag.amountEl.classList.add("zero");
              }
            }
            if (tag.clickBox && tag.clickBox.userData) {
              tag.clickBox.userData.amount = Math.round(amount || 0);
            }
          }
        }

        // 1. Food District
        const fRest   = (data.foodSub && data.foodSub.restaurant !== undefined) ? data.foodSub.restaurant : 0;
        const fSuper  = (data.foodSub && data.foodSub.groceries  !== undefined) ? data.foodSub.groceries  : 0;
        const fCoffee = (data.foodSub && data.foodSub.coffee     !== undefined) ? data.foodSub.coffee     : 0;
        const fWolt   = (data.foodSub && data.foodSub.delivery   !== undefined) ? data.foodSub.delivery   : 0;

        syncBuilding("food_bistro", fRest, nestBody, "+12% מחודש שעבר");
        syncBuilding("food_super", fSuper, superBody, "-5% מחודש שעבר");
        syncBuilding("food_coffee", fCoffee, coffeeBody, "+20% מחודש שעבר");
        syncBuilding("food_wolt", fWolt, woltBody, "+8% מחודש שעבר");

        // 2. Shopping District
        const sFashion = (data.shoppingSub && data.shoppingSub.fashion       !== undefined) ? data.shoppingSub.fashion       : 0;
        const sTech    = (data.shoppingSub && data.shoppingSub.tech          !== undefined) ? data.shoppingSub.tech          : 0;
        const sTravel  = (data.shoppingSub && data.shoppingSub.travel        !== undefined) ? data.shoppingSub.travel        : 0;
        const sArcade  = (data.shoppingSub && data.shoppingSub.entertainment !== undefined) ? data.shoppingSub.entertainment : 0;

        syncBuilding("shop_boutique", sFashion, boutiqueBody, "+15% מחודש שעבר");
        syncBuilding("shop_tech", sTech, techBody, "חדש החודש");
        syncBuilding("shop_travel", sTravel, travelBody, "חופשה פעילה");
        syncBuilding("shop_arcade", sArcade, arcadeBody, "+5% מחודש שעבר");

        // 3. Residence District
        const rTower = (data.housingSub && data.housingSub.rent          !== undefined) ? data.housingSub.rent          : 0;
        const rUtil  = (data.housingSub && data.housingSub.utilities     !== undefined) ? data.housingSub.utilities     : 0;
        const rSubs  = (data.housingSub && data.housingSub.subscriptions !== undefined) ? data.housingSub.subscriptions : (data.housingSub && data.housingSub.subs !== undefined ? data.housingSub.subs : 0);

        syncBuilding("house_tower", rTower, towerBody, "חיוב קבוע");
        syncBuilding("house_util", rUtil, utilBody, "-2% מחודש שעבר");
        syncBuilding("house_subs", rSubs, subMediaBody, "מנויים פעילים");

        // Traffic should arrive with the city rather than greet an empty island. A user
        // on day one has one resident and empty plots; a taxi, a bus and a delivery
        // scooter already circling it makes the city look finished before it is built.
        const savingsForTraffic = data.savings || 0;
        const trafficTotal = fRest + fSuper + fCoffee + fWolt
                           + sFashion + sTech + sTravel + sArcade
                           + rTower + rUtil + rSubs;
        // Any activity at all means the city is inhabited, and an inhabited city has a bus
        // route and a cab on it. Holding them back behind a shekel figure made a perfectly
        // alive city look unfinished, so the only state without traffic is the genuinely
        // empty one: day one, one resident, empty plots, quiet streets.
        const cityIsAlive = trafficTotal > 0 || savingsForTraffic > 0;
        vehicleState.forEach(v => {
          // The delivery scooter stays tied to delivery spending — that is what it is for,
          // not a gate on how developed the city is.
          const show = (v.id === "wolt") ? (fWolt > 0) : cityIsAlive;
          if (v.obj.visible !== show) v.obj.visible = show;
        });

        // 4. Cynical Behavioral Habits & Absurdity Satire Engine
        const habits = data.habits || {};
        const woltCount = habits.woltCount || 0;
        const coffeeCount = habits.coffeeCount || 0;
        const onlinePkg = habits.onlinePackagesCount || 0;
        const subsCount = habits.activeSubscriptionsCount || 0;

        const woltRoot = buildingRoots["food_wolt"];
        if (woltRoot && woltRoot.userData.woltChaos) {
          woltRoot.userData.woltChaos.visible = (woltCount >= 4) || ((fWolt / 250) >= 1.35);
        }

        const coffeeRoot = buildingRoots["food_coffee"];
        if (coffeeRoot && coffeeRoot.userData.coffeeChaos) {
          coffeeRoot.userData.coffeeChaos.visible = (coffeeCount >= 5) || ((fCoffee / 200) >= 1.35);
        }

        const boutiqueRoot = buildingRoots["shop_boutique"];
        if (boutiqueRoot && boutiqueRoot.userData.shoppingChaos) {
          boutiqueRoot.userData.shoppingChaos.visible = ((sFashion / 450) >= 1.35) || (onlinePkg >= 3);
        }

        const subsRoot = buildingRoots["house_subs"];
        if (subsRoot && subsRoot.userData.subsChaos) {
          subsRoot.userData.subsChaos.visible = (subsCount >= 3) || ((rSubs / 120) >= 1.35);
        }

        // 5. Savings Sanctuary & The Lonely Squirrel
        const savings = data.savings || 0;
        const s = Math.min(1.20, Math.max(0.35, 0.35 + (savings / 2500) * 0.85));
        parkZone.scale.set(s, 1.0, s);
        parkData.amount = Math.round(savings);
        parkData.trend = savings > 0 ? ("צמיחה ירוקה • ₪" + Math.round(savings)) : "התחל לחסוך כדי להצמיח את השמורה";

        if (parkZone.userData.squirrel) {
          parkZone.userData.squirrel.visible = (savings <= 0);
        }

        if (data.timeMode !== undefined) {
          cityTimeMode = data.timeMode;
        }

        // 5. Custom Progress-Unlocked Enrichments, Residents & Sims-Style Slot Placement
        const activeSlots = data.slotPlacements || {};
        const itemToSlotMap = {};
        for (const sId in activeSlots) {
          if (activeSlots[sId]) {
            itemToSlotMap[activeSlots[sId]] = sId;
          }
        }

        if (data.enrichments && Array.isArray(data.enrichments)) {
          for (const eId in enrichmentObjects) {
            const item = enrichmentObjects[eId];
            const shouldBeVisible = data.enrichments.includes(eId);
            if (item) {
              if (item.isCitizen) {
                if (item.fig && item.fig.visible !== shouldBeVisible) {
                  item.fig.visible = shouldBeVisible;
                  if (item.dog) item.dog.visible = shouldBeVisible;
                  const ph = getDioramaPhrases();
                  if (shouldBeVisible && (!data.newlyUnlockedId || data.newlyUnlockedId !== eId)) {
                    popEmojiBubble(item.fig, ph.arrived, 2.8);
                  }
                }
              } else if (item.visible !== undefined) {
                if (item.visible !== shouldBeVisible) {
                  item.visible = shouldBeVisible;
                  const ph = getDioramaPhrases();
                  if (shouldBeVisible && (!data.newlyUnlockedId || data.newlyUnlockedId !== eId)) {
                    popEmojiBubble(item, ph.newUpgrade, 2.8);
                  }
                }

                // Relocate to assigned slot or default slot
                let targetSlotId = itemToSlotMap[eId];
                if (!targetSlotId) {
                  for (const sId in CITY_SLOTS) {
                    if (CITY_SLOTS[sId].defaultItem === eId) {
                      targetSlotId = sId;
                      break;
                    }
                  }
                }

                if (targetSlotId && CITY_SLOTS[targetSlotId]) {
                  const s = CITY_SLOTS[targetSlotId];
                  item.position.set(s.x, s.y, s.z);
                  if (item.userData) {
                    item.userData.slotId = targetSlotId;
                  }
                }
              }
            }
          }
        }
        hasHydratedCity = true;
      } catch (err) {
        console.warn("updateDioramaData caught error:", err);
        hasHydratedCity = true; // a failed payload still counts as "we have seen the city"
      }
    };

    // If initial data payload was injected at document start, apply it right now before first frame!
    if (window._initialDataPayload) {
      window.updateDioramaData(window._initialDataPayload);
    }

    // Notify native iOS container that diorama is ready
    try {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.dioramaReady) {
        window.webkit.messageHandlers.dioramaReady.postMessage({});
      }
    } catch(e) {}

    // ────────────────────────────────────────────────────────────────
    // RENDER LOOP WITH SMART MOBILE LIFECYCLE (PAUSE WHEN TAB HIDDEN)
    // ────────────────────────────────────────────────────────────────
    let last = performance.now();
    let situationClock = 0;
    let nextSituationTime = 6.0;
    var isRenderingPaused = false;

    window.pauseDioramaRendering = function(pause) {
      const shouldPause = !!pause;
      if (isRenderingPaused !== shouldPause) {
        isRenderingPaused = shouldPause;
        if (!isRenderingPaused) {
          last = performance.now();
          requestAnimationFrame(loop);
        }
      }
    };

    document.addEventListener("visibilitychange", () => {
      if (document.hidden) {
        isRenderingPaused = true;
      } else {
        isRenderingPaused = false;
        last = performance.now();
        requestAnimationFrame(loop);
      }
    });

    function loop(t) {
      if (isRenderingPaused || (typeof document !== "undefined" && document.hidden)) {
        return; // 0% GPU/CPU overhead when tab is not visible
      }
      const dt = Math.min(0.05, (t - last) / 1000); last = t;
      const T = t * 0.001;

      // Dynamic Building Scaling Lerp
      for (const bId in buildingRoots) {
        const bg = buildingRoots[bId];
        // While a crew is raising it, the crew owns its scale. Letting the lerp run too
        // would snap the building to full height in half a second and leave the workers
        // hammering at something already finished.
        if (bg.userData.underConstruction) continue;
        const tY = bg.userData.targetScaleY || 1.0;
        const tXZ = bg.userData.targetScaleXZ || 1.0;
        bg.scale.y += (tY - bg.scale.y) * Math.min(1, dt * 5.0);
        bg.scale.x += (tXZ - bg.scale.x) * Math.min(1, dt * 5.0);
        bg.scale.z += (tXZ - bg.scale.z) * Math.min(1, dt * 5.0);
      }

      // Camera lerp
      currentCam.az    += (targetCam.az    - currentCam.az)    * Math.min(1, dt * 6);
      currentCam.el    += (targetCam.el    - currentCam.el)    * Math.min(1, dt * 6);
      currentCam.zoom  += (targetCam.zoom  - currentCam.zoom)  * Math.min(1, dt * 6);
      currentCam.lookX += (targetCam.lookX - currentCam.lookX) * Math.min(1, dt * 6);
      currentCam.lookY += (targetCam.lookY - currentCam.lookY) * Math.min(1, dt * 6);
      currentCam.lookZ += (targetCam.lookZ - currentCam.lookZ) * Math.min(1, dt * 6);
      
      if (isNaN(currentCam.az)) currentCam.az = Math.PI * 0.25;
      if (isNaN(currentCam.el)) currentCam.el = 0.52;
      if (isNaN(currentCam.zoom) || currentCam.zoom <= 0) currentCam.zoom = 1.35;
      if (isNaN(targetCam.zoom) || targetCam.zoom <= 0) targetCam.zoom = 1.35;
      if (isNaN(currentCam.lookX)) currentCam.lookX = 0;
      if (isNaN(currentCam.lookY)) currentCam.lookY = 0.28;
      if (isNaN(currentCam.lookZ)) currentCam.lookZ = 0;

      placeCam(); resize();

      // ════════════════════════════════════════════════════════════════
      // 🌅 TIME-OF-DAY ATMOSPHERE & SKY LIGHTING UPDATE
      // ════════════════════════════════════════════════════════════════
      let effectiveHour = 12.0;
      if (cityTimeMode === "realtime") {
        const d = new Date();
        effectiveHour = d.getHours() + d.getMinutes() / 60.0 + d.getSeconds() / 3600.0;
      } else if (cityTimeMode === "day") {
        effectiveHour = 12.0;
      } else if (cityTimeMode === "sunset") {
        effectiveHour = 19.2;
      } else if (cityTimeMode === "night") {
        effectiveHour = 22.5;
      } else if (cityTimeMode === "morning") {
        effectiveHour = 7.4;
      } else if (typeof cityTimeMode === "number") {
        effectiveHour = cityTimeMode;
      }

      const kf = getTimeKeyframe(effectiveHour);
      
      // Lerp Background Sky
      if (scene.background && scene.background.lerp) {
        scene.background.lerp(kf.bg, Math.min(1, dt * 3.5));
      }
      
      // Lerp Ambient & Hemisphere Lights
      ambientL.color.lerp(kf.ambientCol, Math.min(1, dt * 3.5));
      ambientL.intensity += (kf.ambientInt - ambientL.intensity) * Math.min(1, dt * 3.5);

      hemiL.color.lerp(kf.hemiSky, Math.min(1, dt * 3.5));
      hemiL.groundColor.lerp(kf.hemiGround, Math.min(1, dt * 3.5));
      hemiL.intensity += (kf.hemiInt - hemiL.intensity) * Math.min(1, dt * 3.5);

      // Lerp Sun / Moon Directional Light
      sun.color.lerp(kf.sunCol, Math.min(1, dt * 3.5));
      sun.intensity += (kf.sunInt - sun.intensity) * Math.min(1, dt * 3.5);
      sun.position.lerp(kf.sunPos, Math.min(1, dt * 3.5));

      // Lerp Window Interior Warmth
      winGlowM.emissiveIntensity += (kf.winGlowInt - winGlowM.emissiveIntensity) * Math.min(1, dt * 3.5);

      // Lerp Street Lamps & Lanterns
      // 🏷️ Project and position native HTML floating tags in screen space (100% Vector Crisp)
      const tagVec = new THREE.Vector3();
      const stageW = stage.clientWidth || window.innerWidth || 360;
      const stageH = stage.clientHeight || window.innerHeight || 420;

      for (const bId in districtBuildingTags) {
        const tag = districtBuildingTags[bId];
        const isSelectedDistrict = (currentMode === tag.district);

        if (isSelectedDistrict && tag.domEl) {
          const bob = Math.sin(T * 2.2 + bId.length) * 0.08;
          tagVec.set(tag.posX, tag.posY + bob, tag.posZ);
          tagVec.project(camera);

          const screenX = (tagVec.x * 0.5 + 0.5) * stageW;
          const screenY = (-(tagVec.y * 0.5) + 0.5) * stageH;

          tag.domEl.style.left = screenX.toFixed(1) + "px";
          tag.domEl.style.top  = screenY.toFixed(1) + "px";

          if (!tag.domEl.classList.contains("active")) {
            tag.domEl.classList.add("active");
          }
        } else if (tag.domEl) {
          if (tag.domEl.classList.contains("active")) {
            tag.domEl.classList.remove("active");
          }
        }
      }



      // ════════════════════════════════════════════════════════════════
      // 🚦 ADVANCED ZERO-COLLISION INTERSECTION & TRAFFIC CONTROLLER
      // ════════════════════════════════════════════════════════════════
      const INTERSECTION_MIN_X = -1.2, INTERSECTION_MAX_X = 2.6;
      const INTERSECTION_MIN_Z = -2.6, INTERSECTION_MAX_Z = 0.8;

      function isInsideIntersection(pos) {
        return pos.x >= INTERSECTION_MIN_X && pos.x <= INTERSECTION_MAX_X &&
               pos.z >= INTERSECTION_MIN_Z && pos.z <= INTERSECTION_MAX_Z;
      }

      // Identify if any vehicle is currently inside the central intersection
      let vehicleInIntersection = null;
      for (let i = 0; i < vehicleState.length; i++) {
        const v = vehicleState[i];
        if (isInsideIntersection(v.obj.position)) {
          vehicleInIntersection = v;
          break;
        }
      }

      const busObj = vehicleState.find(v => v.isBus);

      vehicleState.forEach((v, vIdx) => {
        if (v.pauseTimer > 0) {
          v.pauseTimer -= dt;
          return;
        }

        const pA = v.route[0], pB = v.route[1];
        const currentX = v.obj.position.x;
        const currentZ = v.obj.position.z;

        // 1. Bus Stop Routine: City Bus stops at roadside shelter at z = -4.8 (Shopping promenade)
        if (v.isBus) {
          if (!v.hasPausedAtBusStop && Math.abs(currentZ - (-4.8)) < 0.45) {
            v.pauseTimer = 2.4;
            v.hasPausedAtBusStop = true;
            const ph = getDioramaPhrases();
            popEmojiBubble(v.obj, ph.busStop, 2.2);
            return;
          }
          if (currentZ < -8.0 || currentZ > 8.0) {
            v.hasPausedAtBusStop = false;
          }
        }

        // 2. Perpendicular Intersection Yielding (Westbound Taxi / Eastbound Wolt vs Northbound Bus)
        if (!v.isBus && busObj) {
          const busZ = busObj.obj.position.z;
          if (v.lane === "westbound") {
            // Taxi crosses bus lane at (1.2, -1.6)
            if (busZ > -2.4 && busZ < -0.8 && currentX > 1.2 && currentX < 2.6) {
              return; // Brief yield while bus passes through crossing
            }
          } else if (v.lane === "eastbound") {
            // Wolt crosses bus lane at (1.2, -0.2)
            if (busZ > -1.0 && busZ < 0.6 && currentX < 1.2 && currentX > -0.2) {
              return; // Brief yield while bus passes through crossing
            }
          }
        }

        // 3. Drive forward continuously & smoothly
        v.progress = (v.progress + dt * v.speed) % 1.0;
        v.obj.position.x = pA.x + (pB.x - pA.x) * v.progress;
        v.obj.position.z = pA.z + (pB.z - pA.z) * v.progress;
        v.obj.rotation.y = Math.atan2(-(pB.z - pA.z), pB.x - pA.x);

        if (v.obj.userData && v.obj.userData.smoke) {
          v.obj.userData.smoke.scale.setScalar(0.85 + Math.sin(T * 12) * 0.18);
        }
      });

      // 🐦 Pigeon Scattering When Citizens Approach
      pigeonList.forEach(p => {
        if (p.scareCooldown > 0) p.scareCooldown -= dt;
        if (p.flapTimer > 0) {
          p.flapTimer -= dt;
          const prog = Math.max(0, p.flapTimer / 0.75);
          p.obj.position.y = p.baseY + Math.sin(prog * Math.PI) * 0.28;
          p.obj.rotation.y += dt * 12.0;
        } else {
          p.obj.position.y = p.baseY;
          if (p.scareCooldown <= 0) {
            for (let ci = 0; ci < walkingCitizens.length; ci++) {
              const c = walkingCitizens[ci];
              if (!c.obj || !c.obj.visible) continue;
              const d = Math.hypot(c.obj.position.x - p.baseX, c.obj.position.z - p.baseZ);
              if (d < 1.35) {
                p.flapTimer = 0.75;
                p.scareCooldown = 4.0;
                break;
              }
            }
          }
        }
      });

      // Update Speech Bubbles (project 3D position to 2D HTML/DOM)
      const bubbleVec = new THREE.Vector3();
      for (let bi = activeBubbles.length - 1; bi >= 0; bi--) {
        const b = activeBubbles[bi];
        b.life += dt;
        if (b.life >= b.maxLife) {
          if (b.el && b.el.parentNode) {
            b.el.parentNode.removeChild(b.el);
          }
          activeBubbles.splice(bi, 1);
          continue;
        }

        if (b.life >= b.maxLife - 0.28) {
          b.el.classList.remove("active");
          b.el.classList.add("closing");
        }

        if (b.targetObj && b.targetObj.visible !== false) {
          b.targetObj.getWorldPosition(bubbleVec);
          bubbleVec.y += (b.offsetY || 1.35) + Math.sin(b.life * 2.5) * 0.04;
          bubbleVec.project(camera);

          if (bubbleVec.z < 1) {
            const screenX = ((bubbleVec.x + 1) * 0.5) * stage.clientWidth;
            const screenY = ((-bubbleVec.y + 1) * 0.5) * stage.clientHeight;
            b.el.style.left = screenX + "px";
            b.el.style.top = screenY + "px";
          } else {
            b.el.style.opacity = "0";
          }
        } else {
          if (b.el && b.el.parentNode) {
            b.el.parentNode.removeChild(b.el);
          }
          activeBubbles.splice(bi, 1);
        }
      }

      // Spontaneous Street Situations ("פה ושם" - Every 25-50 seconds, rare & delightful)
      situationClock += dt;
      if (situationClock > nextSituationTime) {
        situationClock = 0;
        nextSituationTime = 25.0 + Math.random() * 25.0;

        const activeCitizens = walkingCitizens.filter(c => c.obj.visible);
        if (activeCitizens.length > 0) {
          const ph = getDioramaPhrases();
          const sitKind = Math.floor(Math.random() * ph.street.length);
          const chosenPhrase = ph.street[sitKind] || ph.street[0];
          
          if (sitKind === 3) {
            // Dog Love
            const dogWalkers = activeCitizens.filter(c => c.dog && c.dog.visible);
            if (dogWalkers.length > 0) {
              const dw = dogWalkers[0];
              dw.isPaused = true;
              dw.pauseDuration = 2.5;
              dw.pauseTimer = 2.5;
              popEmojiBubble(dw.obj, chosenPhrase, 2.3);
            }
          } else if (sitKind === 4) {
            // Courier
            const courier = activeCitizens.find(c => c.obj.userData && (c.obj.userData.hasPhone || c.obj.userData.hasBag));
            if (courier) {
              courier.isPaused = true;
              courier.pauseDuration = 3.0;
              courier.pauseTimer = 3.0;
              popEmojiBubble(courier.obj, chosenPhrase, 2.8);
            }
          } else if (sitKind === 5 && activeCitizens.length >= 2) {
            // Shuffle
            const c1 = activeCitizens[0];
            c1.isPaused = true;
            c1.pauseDuration = 2.2;
            c1.pauseTimer = 2.2;
            popEmojiBubble(c1.obj, chosenPhrase, 2.0);
          } else {
            // Citizen greeting / photo / coffee
            const c = activeCitizens[Math.floor(Math.random() * activeCitizens.length)];
            c.isPaused = true;
            c.pauseDuration = 2.4;
            c.pauseTimer = 2.4;
            popEmojiBubble(c.obj, chosenPhrase, 2.3);
          }
        }
      }

      // 👷 Construction crews animation & calm occasional contractor chatter (every 35-60s)
      for (let ci = activeConstructionCrews.length - 1; ci >= 0; ci--) {
        const crew = activeConstructionCrews[ci];
        if (!crew.group || !crew.group.visible) continue;

        crew.speechTimer -= dt;
        if (crew.speechTimer <= 0) {
          crew.speechTimer = 35.0 + Math.random() * 25.0;
          const ph = getDioramaPhrases();
          if (ph.construction && ph.construction.length > 0) {
            const chosenWorker = crew.workers[Math.floor(Math.random() * crew.workers.length)];
            const quote = ph.construction[Math.floor(Math.random() * ph.construction.length)];
            popEmojiBubble(chosenWorker, quote, 2.6);
          }
        }

        // Raise the building under the crew's hands.
        if (crew.buildTarget) {
          const bg = crew.buildTarget;
          crew.buildElapsed += dt;
          const p = Math.min(1, crew.buildElapsed / crew.buildDuration);
          const eased = 1 - Math.pow(1 - p, 3);
          const tY = bg.userData.targetScaleY || 1.0;
          const tXZ = bg.userData.targetScaleXZ || 1.0;
          // A little shake on every hammer blow, fading out as the structure sets.
          const shake = (p < 1) ? Math.sin(crew.buildElapsed * 24.0) * 0.014 * (1 - p) : 0;
          bg.scale.y = Math.max(0.02, tY * eased + shake);
          const spread = 0.40 + 0.60 * eased;
          bg.scale.x = Math.max(0.02, tXZ * spread);
          bg.scale.z = Math.max(0.02, tXZ * spread);
          if (p >= 1) {
            bg.scale.set(tXZ, tY, tXZ);
            bg.userData.underConstruction = false;
            crew.buildTarget = null;
          }
        }

        // Crane: the jib slews and the hook rides up and down over the plot.
        if (crew.crane) {
          crew.crane.jib.rotation.y = Math.sin(T * 0.42 + crew.buildElapsed) * 0.75;
          const lift = 0.62 + Math.sin(T * 0.9) * 0.30;
          crew.crane.hook.position.y = -0.44 - lift;
          crew.crane.cable.scale.y = Math.max(0.15, lift * 1.35);
          crew.crane.cable.position.y = -0.44 - lift * 0.5;
        }

        crew.workers.forEach(w => {
          const u = w.userData;
          if (!u) return;

          // Realistic Hammering / Wrench action
          if (u.hasHammer && u.armR) {
            u.hammerPhase = (u.hammerPhase || 0) + dt * 11.0;
            u.armR.rotation.x = -1.1 + Math.sin(u.hammerPhase) * 0.50;
            if (u.torso) u.torso.position.y = 0.40 + Math.abs(Math.sin(u.hammerPhase)) * 0.03;
          } else if (u.hasWrench && u.armR) {
            u.hammerPhase = (u.hammerPhase || 0) + dt * 4.5;
            u.armR.rotation.z = Math.sin(u.hammerPhase) * 0.35;
          }

          // Hop on tap
          if (u.hopTimer > 0) {
            u.hopTimer -= dt;
            const hopP = Math.max(0, u.hopTimer / 0.40);
            if (u.torso) u.torso.position.y = 0.40 + Math.sin(hopP * Math.PI) * 0.35;
            if (u.armR) u.armR.rotation.x = -2.2;
          }
        });

        if (crew.isTemporary) {
          crew.timer -= dt;
          if (crew.timer <= 0) {
            const ph = getDioramaPhrases();
            popEmojiBubble(crew.workers[0], ph.constructionDone || "סיימנו! תתחדש! 🎉", 3.5);
            // Clean up after bubble
            setTimeout(() => {
              if (crew.group && crew.group.parent) {
                crew.group.parent.remove(crew.group);
              }
            }, 3500);
            activeConstructionCrews.splice(ci, 1);
          }
        }
      }

      // 🛴 Electric Scooter Zoomer movement & banking
      if (scooterZoomer && scooterZoomer.userData) {
        const su = scooterZoomer.userData;
        su.progress = (su.progress || 0) + dt * 0.16;
        const scooterP = (Math.sin(su.progress) + 1) * 0.5; // 0..1 smooth glide
        scooterZoomer.position.x = -3.6 + scooterP * 7.2;
        // It moves along X and the model faces +X, so the heading is 0 or PI. The old
        // +/-PI/2 pointed it across its own path and it crabbed down the promenade.
        scooterZoomer.rotation.y = (Math.cos(su.progress) >= 0) ? 0 : Math.PI;
        // A lean is a roll about the direction of travel, which is X here, not Z.
        scooterZoomer.rotation.x = Math.sin(su.progress * 2.0) * 0.05;
        scooterZoomer.rotation.z = 0;
        if (su.hopTimer > 0) {
          su.hopTimer -= dt;
          const hopP = Math.max(0, su.hopTimer / 0.40);
          scooterZoomer.position.y = 0.22 + Math.sin(hopP * Math.PI) * 0.25;
        } else {
          scooterZoomer.position.y = 0.22; // pin it back down; a missed frame left it floating
        }
      }

      // 📸 Influencer gentle selfie posing
      if (influencerFigure && influencerFigure.userData) {
        const iu = influencerFigure.userData;
        if (iu.fig) {
          iu.fig.rotation.y = Math.sin(T * 0.8) * 0.35;
        }
        if (iu.hopTimer > 0) {
          iu.hopTimer -= dt;
          const hopP = Math.max(0, iu.hopTimer / 0.40);
          influencerFigure.position.y = 0.22 + Math.sin(hopP * Math.PI) * 0.30;
        }
      }

      // 🎸 Street Musician guitar strumming
      if (streetMusician && streetMusician.userData) {
        const mu = streetMusician.userData;
        if (mu.fig) {
          mu.fig.rotation.y = Math.PI * 0.75 + Math.sin(T * 1.8) * 0.12;
        }
        if (mu.hopTimer > 0) {
          mu.hopTimer -= dt;
          const hopP = Math.max(0, mu.hopTimer / 0.40);
          streetMusician.position.y = 0.22 + Math.sin(hopP * Math.PI) * 0.30;
        }
      }

      // 🧘‍♀️ Park Yogi subtle breathing
      if (yogaPractitioner && yogaPractitioner.userData) {
        const yu = yogaPractitioner.userData;
        if (yu.fig) {
          yu.fig.position.y = 0.22 + Math.sin(T * 1.2) * 0.02;
        }
        if (yu.hopTimer > 0) {
          yu.hopTimer -= dt;
          const hopP = Math.max(0, yu.hopTimer / 0.40);
          yogaPractitioner.position.y = 0.22 + Math.sin(hopP * Math.PI) * 0.30;
        }
      }

      // 👮‍♂️ Parking Inspector looking around
      if (parkingInspector && parkingInspector.userData) {
        const pu = parkingInspector.userData;
        if (pu.fig) {
          pu.fig.rotation.y = -Math.PI * 0.25 + Math.sin(T * 0.6) * 0.45;
        }
        if (pu.hopTimer > 0) {
          pu.hopTimer -= dt;
          const hopP = Math.max(0, pu.hopTimer / 0.40);
          parkingInspector.position.y = 0.22 + Math.sin(hopP * Math.PI) * 0.30;
        }
      }

      // 🧑‍💻 Tech Worker typing on laptop
      if (techWorkerOnBench && techWorkerOnBench.userData) {
        const tu = techWorkerOnBench.userData;
        if (tu.hopTimer > 0) {
          tu.hopTimer -= dt;
          const hopP = Math.max(0, tu.hopTimer / 0.40);
          techWorkerOnBench.position.y = 0.22 + Math.sin(hopP * Math.PI) * 0.25;
        }
      }

      try {
        // Calm, natural pedestrians with gentle strolling pace & micro-pauses
        walkingCitizens.forEach(c => {
          if (!c.obj || !c.obj.visible) return;

          const wps = c.waypoints;
          if (!wps || wps.length < 2) return;
          const n = wps.length;
          if (isNaN(c.progress) || c.progress < 0) c.progress = 0;
          const totalP = (c.progress % 1.0) * n;
          const segIdx = Math.max(0, Math.min(n - 1, Math.floor(totalP)));
          const pA = wps[segIdx];
          const pB = wps[(segIdx + 1) % n];
          if (!pA || !pB) return;
          const segProgress = totalP % 1.0;

          // Micro-pause check at waypoints
          if (segIdx !== c.lastSegIdx) {
            c.lastSegIdx = segIdx;
            if (Math.random() < c.pauseChance) {
              c.isPaused = true;
              c.pauseDuration = 2.0 + Math.random() * 2.0; // 2-4s relaxed pause
              c.pauseTimer = c.pauseDuration;
            }
          }

          const u = c.obj.userData;

          // Interactive Tap Hop Animation
          if (u && u.hopTimer > 0) {
            u.hopTimer -= dt;
            const hopP = Math.max(0, u.hopTimer / 0.40);
            if (u.torso) u.torso.position.y = Math.sin(hopP * Math.PI) * 0.32;
            if (u.armR) u.armR.rotation.x = -2.1;
          }

          if (c.isPaused) {
            c.pauseTimer -= dt;
            if (c.pauseTimer <= 0) {
              c.isPaused = false;
            } else {
              // Idle breathing & looking around
              if (u && u.head) {
                u.head.rotation.y = Math.sin(T * 1.5 + c.legPhase) * 0.35;
              }
              if (u && u.armR && u.hasCoffee) {
                u.armR.rotation.x = -0.9 + Math.sin(T * 1.8) * 0.15;
              }
              if (u && u.armR && u.hasPhone) {
                u.armR.rotation.x = -1.1 + Math.sin(T * 1.2) * 0.08;
              }
              if (c.dog) {
                const du = c.dog.userData;
                if (du && du.tail) du.tail.rotation.y = Math.sin(T * 8) * 0.35;
              }
              return;
            }
          }

          // Gentle, relaxed strolling pace
          c.progress = (c.progress + dt * (c.speed * 0.016)) % 1.0;

          const posX = pA.x + (pB.x - pA.x) * segProgress;
          const posZ = pA.z + (pB.z - pA.z) * segProgress;
          c.obj.position.set(posX, 0.22, posZ);

          const dx = pB.x - pA.x, dz = pB.z - pA.z;
          const targetAngle = Math.atan2(-dz, dx) + Math.PI / 2;
          c.obj.rotation.y = targetAngle;

          // Reset head during walk
          if (u && u.head) {
            u.head.rotation.y *= 0.90;
          }

          // Smooth locomotion
          const strideSpeed = c.isJogging ? 8.5 : 5.2;
          c.legPhase += dt * strideSpeed;

          if (u && u.legL && u.legR && (u.hopTimer <= 0)) {
            const swing = Math.sin(c.legPhase) * (c.isJogging ? 0.65 : 0.45);
            u.legL.rotation.x = swing;
            u.legR.rotation.x = -swing;
            u.armL.rotation.x = -swing * 0.65;
            if (!u.hasPhone && !u.hasCoffee) {
              u.armR.rotation.x = swing * 0.65;
            } else if (u.hasCoffee) {
              u.armR.rotation.x = -0.6 + Math.sin(c.legPhase * 0.5) * 0.10;
            } else if (u.hasPhone) {
              u.armR.rotation.x = -0.8 + Math.sin(c.legPhase * 0.5) * 0.08;
            }
            u.torso.position.y = Math.abs(Math.sin(c.legPhase * 2)) * 0.025;
          }

          // Dog trotting alongside owner
          if (c.dog) {
            const sideAngle = targetAngle - Math.PI / 2;
            const dogX = posX + Math.cos(sideAngle) * 0.42 - Math.cos(targetAngle - Math.PI/2) * 0.15;
            const dogZ = posZ - Math.sin(sideAngle) * 0.42 + Math.sin(targetAngle - Math.PI/2) * 0.15;
            c.dog.position.set(dogX, 0.22, dogZ);
            c.dog.rotation.y = targetAngle;

            const du = c.dog.userData;
            if (du && du.legs) {
              const dogSwing = Math.sin(c.legPhase * 1.2) * 0.40;
              du.legs[0].rotation.x = dogSwing;
              du.legs[1].rotation.x = -dogSwing;
              du.legs[2].rotation.x = -dogSwing;
              du.legs[3].rotation.x = dogSwing;
              if (du.tail) du.tail.rotation.y = Math.sin(T * 10) * 0.35;
            }
          }
        });

        // Seated Citizens gentle idle breathing & gesturing
        seatedCitizens.forEach((sc, idx) => {
          if (!sc || !sc.visible) return;
          const u = sc.userData;
          if (u && u.head) {
            u.head.rotation.y = Math.sin(T * 1.5 + idx * 1.2) * 0.22;
            u.head.rotation.x = Math.sin(T * 2.0 + idx * 0.8) * 0.08;
          }
        });

        // Scene environmental animations
        animObjects.forEach(a => {
          switch(a.type) {
            case "cat_anim":
              a.tail.rotation.z = Math.sin(T * 3.2) * 0.45;
              a.tail.rotation.x = -0.3 + Math.sin(T * 1.8) * 0.15;
              a.head.rotation.y = Math.sin(T * 1.4) * 0.35;
              a.head.rotation.x = Math.sin(T * 2.2) * 0.08;
              a.body.scale.y = 1.0 + Math.sin(T * 2.2) * 0.05;
              if (a.userData && a.userData.hopTimer > 0) {
                a.userData.hopTimer -= dt;
                const hopP = Math.max(0, a.userData.hopTimer / 0.40);
                a.root.position.y = 0.57 + Math.sin(hopP * Math.PI) * 0.24;
              }
              break;
            case "fountain_anim":
              a.water.material.emissiveIntensity = 1.0 + Math.sin(T * 3.5) * 0.4;
              a.jet.scale.set(1 + Math.sin(T * 4.0) * 0.2, 1 + Math.cos(T * 4.0) * 0.3, 1 + Math.sin(T * 4.0) * 0.2);
              break;
            case "smoke":
            case "steam":
              a.ref.position.y += dt * 0.06;
              a.ref.scale.setScalar(1 + Math.sin(T * 1.8 + a.phase) * 0.12);
              if (a.ref.position.y > 0.7) a.ref.position.y = 0;
              break;
            case "rotate_y":
              a.ref.rotation.y += dt * a.speed;
              break;
            case "flicker":
              a.ref.intensity = a.base + Math.sin(T * 7.5 + a.phase) * 0.7 + Math.sin(T * 23) * 0.4;
              break;
            case "beacon":
              const pulse = 0.5 + 0.5 * Math.sin(T * 2.5 + a.phase);
              a.ref.intensity = 0.4 + pulse * 1.8;
              a.refM.material.emissiveIntensity = 1.0 + pulse * 3.0;
              break;
            case "water_shimmer":
            case "pond_shimmer":
              a.ref.emissiveIntensity = 1.2 + Math.sin(T * 1.4 + a.phase) * 0.55;
              break;
            case "arcade_screen":
              a.timer += dt;
              if (a.timer > 0.75) {
                a.frame = (a.frame + 1) % 3;
                const newC = arcadeTex(a.frame);
                a.tex.image = newC; a.tex.needsUpdate = true;
                a.timer = 0;
              }
              break;
            case "spawn_bounce":
              a.time += dt;
              const tNorm = a.time / a.duration;
              if (tNorm >= 1.0) {
                a.target.scale.set(1, 1, 1);
                if (a.dog) a.dog.scale.set(1, 1, 1);
              } else {
                const s = Math.sin(tNorm * Math.PI * 2.5) * Math.exp(-tNorm * 3.2) * 0.75 + 1.0;
                const scaleVal = Math.max(0.01, Math.min(1.45, s * Math.min(1.0, tNorm * 3.5)));
                a.target.scale.set(scaleVal, scaleVal, scaleVal);
                if (a.dog) a.dog.scale.set(scaleVal, scaleVal, scaleVal);
              }
              break;
            case "bird":
              const bT = T * a.speed + a.phase;
              a.ref.position.x = a.cx + Math.cos(bT) * a.radius;
              a.ref.position.z = a.cz + Math.sin(bT) * a.radius;
              a.ref.position.y = 5.5 + Math.sin(bT * 2.4) * 0.45;
              a.ref.rotation.y = -bT;
              break;
            case "butterfly_orbit":
              const bfT = T * a.speed + a.phase;
              a.ref.position.x = a.cx + Math.sin(bfT) * a.radius;
              a.ref.position.z = a.cz + Math.sin(bfT * 2.0) * (a.radius * 0.6);
              a.ref.position.y = a.baseY + Math.sin(bfT * 3.5) * 0.22;
              a.ref.rotation.y = Math.cos(bfT) * 1.2;
              const wingFlap = Math.sin(T * 18.0) * 0.8;
              a.wingL.rotation.y = wingFlap;
              a.wingR.rotation.y = -wingFlap;
              break;
          }
        });

        // Animate Confetti Particles with gravity & rotation
        for (let i = confettiParticles.length - 1; i >= 0; i--) {
          const p = confettiParticles[i];
          const u = p.userData;
          u.life -= dt;
          if (u.life <= 0) {
            root.remove(p);
            confettiParticles.splice(i, 1);
          } else {
            u.vy -= dt * 7.5; // gravity
            p.position.x += u.vx * dt;
            p.position.y += u.vy * dt;
            p.position.z += u.vz * dt;
            p.rotation.x += u.rotX * dt;
            p.rotation.y += u.rotY * dt;
            p.rotation.z += u.rotZ * dt;
            const progress = u.life / u.maxLife;
            p.scale.setScalar(Math.max(0, Math.min(1, progress * 1.5)));
          }
        }
      } catch (loopErr) {
        console.warn("Loop internal caught:", loopErr);
      }

      renderer.render(scene, camera);
      requestAnimationFrame(loop);
    }

    window.addEventListener("resize", resize);
    placeCam(); resize();
    requestAnimationFrame(loop);
  </script>
</body>
</html>
`;

// Validate JS before writing
const sceneCode = htmlContent.match(/<script>([\s\S]*?)<\/script>/g)[1].replace(/<\/?script>/g, "");
try {
  new Function("window", "document", "performance", "requestAnimationFrame", "THREE", sceneCode);
  console.log("JS validation PASSED");
} catch(e) {
  console.error("JS VALIDATION FAILED:", e.message);
  process.exit(1);
}

const outHtmlPath = path.join(__dirname, "MoneyCity/Resources/diorama.html");
fs.writeFileSync(outHtmlPath, htmlContent, "utf8");
console.log(`Build complete \u2013 ${outHtmlPath} written successfully (${Math.round(Buffer.byteLength(htmlContent)/1024)} KB).`);
