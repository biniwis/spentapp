// One scheduler, independent pause reasons. Page visibility must never undo a native
// pause for another tab, a sheet, an inactive app, or a disposed WebView.
const ENERGY_PROFILES = {
  normal:   { idleFPS: 30, activeFPS: 60, pixelRatio: 1.75, shadowSize: 2048, shadowFPS: 15 },
  economy:  { idleFPS: 20, activeFPS: 30, pixelRatio: 1.25, shadowSize: 1024, shadowFPS: 8 },
  critical: { idleFPS: 10, activeFPS: 15, pixelRatio: 1.0, shadowSize: 0, shadowFPS: 0 }
};
let energyMode = ENERGY_PROFILES[window._initialPowerMode] ? window._initialPowerMode : "normal";
let nativeRenderPaused = !!window._initialRenderPaused;
let pageRenderHidden = false;
let energyDisposed = false;
let renderPaused = nativeRenderPaused || document.hidden;
let rafId = null, lastEnergyFrame = null, appliedEnergyMode = null;
let energyBoostUntil = 0, lastShadowFrame = -Infinity, shadowDirty = true;
const energyStats = { rendered: 0, skipped: 0, shadowUpdates: 0 };

function startLoop() {
  if (renderPaused || energyDisposed || rafId !== null) return;
  lastTime = performance.now(); lastEnergyFrame = null; shadowDirty = true;
  rafId = requestAnimationFrame(loop);
}
function syncRenderPause() {
  const next = nativeRenderPaused || document.hidden || pageRenderHidden || energyDisposed;
  if (next === renderPaused) return;
  renderPaused = next;
  if (renderPaused) {
    if (rafId !== null) cancelAnimationFrame(rafId);
    rafId = null; lastEnergyFrame = null;
    pointers.clear(); gesture = null; spinVel = 0; tiltVel = 0; isDragging = false;
  } else startLoop();
}
window.pauseDioramaRendering = function (on) { nativeRenderPaused = !!on; syncRenderPause(); };
function energyVisibilityChanged() { syncRenderPause(); }
function energyPageHide() { pageRenderHidden = true; syncRenderPause(); }
function energyPageShow() { pageRenderHidden = false; syncRenderPause(); }
document.addEventListener("visibilitychange", energyVisibilityChanged);
window.addEventListener("pagehide", energyPageHide);
window.addEventListener("pageshow", energyPageShow);

function noteEnergyInteraction() { energyBoostUntil = performance.now() + 1200; }
function energyCameraMoving() {
  return ["az", "el", "zoom", "lookX", "lookY", "lookZ"].some(function (key) {
    return Math.abs((targetCam[key] || 0) - (currentCam[key] || 0)) > 0.001;
  }) || Math.abs(spinVel) > 0.0001 || Math.abs(tiltVel) > 0.0001;
}
function energyTargetFPS(now) {
  const profile = ENERGY_PROFILES[energyMode];
  return pointers.size > 0 || now < energyBoostUntil || energyCameraMoving() ? profile.activeFPS : profile.idleFPS;
}
function energyFrameDue(now) {
  if (renderPaused || energyDisposed) return false;
  if (lastEnergyFrame === null) { lastEnergyFrame = now; return true; }
  const interval = 1000 / energyTargetFPS(now), elapsed = now - lastEnergyFrame;
  if (elapsed + 0.1 < interval) { energyStats.skipped++; return false; }
  lastEnergyFrame += Math.max(1, Math.floor((elapsed + 0.1) / interval)) * interval;
  return true;
}
window.setDioramaPowerMode = function (mode) {
  const next = ENERGY_PROFILES[mode] ? mode : "normal";
  if (next === energyMode) return;
  energyMode = next; lastEnergyFrame = null; shadowDirty = true;
};
function applyEnergyQuality() {
  if (appliedEnergyMode === energyMode) return;
  const profile = ENERGY_PROFILES[energyMode];
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, profile.pixelRatio));
  const shadowsChanged = renderer.shadowMap.enabled !== (profile.shadowSize > 0);
  renderer.shadowMap.enabled = profile.shadowSize > 0;
  renderer.shadowMap.autoUpdate = false;
  if (shadowsChanged) scene.traverse(function (o) {
    if (o.material) (Array.isArray(o.material) ? o.material : [o.material]).forEach(function (m) { m.needsUpdate = true; });
  });
  if (profile.shadowSize === 0 && sunLight.shadow.map) { sunLight.shadow.map.dispose(); sunLight.shadow.map = null; }
  if (sunLight.shadow.mapSize.width !== profile.shadowSize && profile.shadowSize > 0) {
    if (sunLight.shadow.map) { sunLight.shadow.map.dispose(); sunLight.shadow.map = null; }
    sunLight.shadow.mapSize.set(profile.shadowSize, profile.shadowSize);
  }
  appliedEnergyMode = energyMode; shadowDirty = true;
}
function prepareEnergyRender(now) {
  applyEnergyQuality();
  const profile = ENERGY_PROFILES[energyMode];
  const update = profile.shadowFPS > 0 && (shadowDirty || now - lastShadowFrame >= 1000 / profile.shadowFPS - 0.1);
  renderer.shadowMap.needsUpdate = update;
  if (update) { lastShadowFrame = now; shadowDirty = false; energyStats.shadowUpdates++; }
  energyStats.rendered++;
}
window.disposeDioramaRendering = function () {
  if (energyDisposed) return;
  energyDisposed = true; syncRenderPause();
  document.removeEventListener("visibilitychange", energyVisibilityChanged);
  window.removeEventListener("pagehide", energyPageHide);
  window.removeEventListener("pageshow", energyPageShow);
  renderer.dispose();
  if (renderer.forceContextLoss) renderer.forceContextLoss();
};
window.dioramaEnergyState = function () {
  return { mode: energyMode, paused: renderPaused, nativePaused: nativeRenderPaused,
    pageHidden: !!document.hidden || pageRenderHidden, scheduled: rafId !== null,
    fps: renderPaused ? 0 : energyTargetFPS(performance.now()), stats: Object.assign({}, energyStats) };
};
