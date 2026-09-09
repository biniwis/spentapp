// Production scheduler and render-loop gate under a deterministic display clock.
// No WebView, GPU or battery measurement; this checks requests, states and frame budgets.
const fs = require('fs'), vm = require('vm'), assert = require('assert/strict'), path = require('path');
const base = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(base, file), 'utf8');
const builder = read('build_diorama.js'), energy = read('city_v2_energy.js');
function harness(initial = {}) {
  let now = 0, id = 0;
  const queue = new Map(), events = {};
  const eventTarget = prefix => ({
    addEventListener: (name, fn) => { events[prefix + name] = fn; },
    removeEventListener: name => { delete events[prefix + name]; }
  });
  const renderer = { shadowMap: { enabled: true }, ratios: [], disposed: false, contextLost: false,
    setPixelRatio(v) { this.ratios.push(v); }, dispose() { this.disposed = true; }, forceContextLoss() { this.contextLost = true; } };
  const s = { window: { ...eventTarget('w:'), devicePixelRatio: 3, samples: 0, ...initial },
    document: { ...eventTarget('d:'), hidden: !!initial.hidden }, renderer,
    sunLight: { shadow: { map: null, mapSize: { width: 2048, height: 2048, set(w,h) { this.width=w;this.height=h; } } } },
    scene: { traverse() {} }, lastTime: 0, pointers: new Map(), gesture: null, spinVel: 0, tiltVel: 0, isDragging: false,
    currentCam: {az:1,el:0.5,zoom:1,lookX:0,lookY:0,lookZ:0}, targetCam: {az:1,el:0.5,zoom:1,lookX:0,lookY:0,lookZ:0},
    performance: { now: () => now }, requestAnimationFrame: fn => { queue.set(++id,fn);return id; }, cancelAnimationFrame: key => queue.delete(key) };
  vm.createContext(s); vm.runInContext(energy,s);
  const loopStart = builder.indexOf('    function loop(now) {');
  const gate = builder.slice(loopStart, builder.indexOf('      // The first rAF timestamp', loopStart));
  vm.runInContext(gate + 'window.samples++; lastTime = now; prepareEnergyRender(now); }', s);
  function tick(time) { now=time; const callbacks=[...queue.values()];queue.clear();callbacks.forEach(fn=>fn(time)); }
  function duration(ms, refresh=120) { const start=now; for(let i=1;i<=Math.round(ms*refresh/1000);i++)tick(start+i*1000/refresh); }
  function fire(name) { if(events[name])events[name](); }
  return {s,queue,tick,duration,fire,events};
}
const h=harness();h.s.startLoop();
for(let i=0;i<100;i++)h.s.startLoop();assert.equal(h.queue.size,1,'One RAF chain only');
h.s.window.pauseDioramaRendering(true);assert.equal(h.queue.size,0);
h.s.document.hidden=true;h.fire('d:visibilitychange');
h.s.document.hidden=false;h.fire('d:visibilitychange');
assert.equal(h.queue.size,0,'Returning to app cannot undo a hidden-tab pause');
h.s.document.hidden=true;h.fire('d:visibilitychange');h.s.window.pauseDioramaRendering(false);
assert.equal(h.queue.size,0,'Native resume cannot undo hidden document');
h.s.document.hidden=false;h.fire('d:visibilitychange');assert.equal(h.queue.size,1);
h.fire('w:pagehide');assert.equal(h.queue.size,0);h.s.window.pauseDioramaRendering(false);assert.equal(h.queue.size,0);
h.fire('w:pageshow');assert.equal(h.queue.size,1);
const stale=[...h.queue.values()][0];h.s.window.pauseDioramaRendering(true);stale(2000);
assert.equal(h.queue.size,0,'Stale callback cannot restart paused scene');
console.log('PASS: independent native/document/page pauses, stale callbacks and one scheduler chain');
for(const initial of [{_initialRenderPaused:true},{hidden:true},{_initialRenderPaused:true,hidden:true}]) {
  const t=harness(initial);t.s.startLoop();assert.equal(t.queue.size,0,'Hidden startup never schedules a frame');
}
const measured=[];
for(const [mode,idle,active] of [['normal',30,60],['economy',20,30],['critical',10,15]]) {
  for(const touching of [false,true]) {
    const t=harness({_initialPowerMode:mode});if(touching)t.s.pointers.set(1,{});
    t.s.startLoop();t.duration(10000);
    const fps=t.s.window.samples/10, expected=touching?active:idle;
    assert(Math.abs(fps-expected)<0.2, mode+' '+(touching?'active':'idle')+' cap: '+fps);
    const stats=t.s.window.dioramaEnergyState().stats;
    assert(stats.shadowUpdates<=151, 'Shadow pass not tied to 60/120Hz');
    measured.push({mode,touching,fps,shadowUpdates:stats.shadowUpdates});
  }
}
console.log('PASS: simulated 120Hz display budgets',JSON.stringify(measured));
const q=harness();q.s.startLoop();q.duration(1000);
assert.equal(q.s.renderer.ratios.at(-1),1.75);
q.s.window.pauseDioramaRendering(true);
const before=q.s.renderer.ratios.length;q.s.window.setDioramaPowerMode('economy');
assert.equal(q.s.renderer.ratios.length,before,'No quality allocation while paused');
q.s.window.pauseDioramaRendering(false);q.duration(1000);
assert.equal(q.s.renderer.ratios.at(-1),1.25);assert.equal(q.s.sunLight.shadow.mapSize.width,1024);
q.s.window.setDioramaPowerMode('critical');q.duration(1000);assert(!q.s.renderer.shadowMap.enabled);
q.s.window.setDioramaPowerMode('normal');q.duration(1000);assert(q.s.renderer.shadowMap.enabled);
assert.equal(q.s.sunLight.shadow.mapSize.width,2048);
q.s.window.disposeDioramaRendering();q.s.window.pauseDioramaRendering(false);q.s.startLoop();
assert.equal(q.queue.size,0);assert(q.s.renderer.disposed&&q.s.renderer.contextLost);assert.equal(Object.keys(q.events).length,0);
console.log('PASS: power-mode changes, recovery, deferred GPU quality and terminal disposal');
// Real camera integration stays independent of rendering frequency.
const motion = builder.slice(builder.indexOf('      const smoothing ='),builder.indexOf('      placeCam();',builder.indexOf('      const smoothing =')));
function cameraAfter(fps) {
  const s={dt:1/fps,currentCam:{az:0,el:0.5,zoom:1,lookX:0,lookY:0,lookZ:0},targetCam:{az:1,el:0.5,zoom:2,lookX:1,lookY:0,lookZ:0},pointers:new Map(),spinVel:0.02,tiltVel:0,clamp:(x,a,b)=>Math.min(b,Math.max(a,x))};
  vm.createContext(s);for(let i=0;i<fps*2;i++)vm.runInContext('{'+motion+'}',s);return s;
}
const fast=cameraAfter(60),slow=cameraAfter(15);
assert(Math.abs(fast.targetCam.az-slow.targetCam.az)<0.002,'Inertia travel does not depend on FPS');
assert(Math.abs(fast.currentCam.zoom-slow.currentCam.zoom)<0.001,'Zoom timing does not depend on FPS');
assert(Math.abs(fast.currentCam.az-slow.currentCam.az)<0.01,'Camera follows at equivalent speed');
const native=read('MoneyCity/Views/Diorama/ThreeDioramaView.swift'),main=read('MoneyCity/Views/MainCityView.swift');
for(const flag of ['showQuickAdd','showFeed','showProgressSheet','showOnboarding','showSortingHubSheet','showReserveSanctuarySheet']) assert(main.slice(main.indexOf('isPaused:'),main.indexOf('onSelectDistrict:',main.indexOf('isPaused:'))).includes(flag));
assert(native.includes('context.coordinator.parent = self'));
assert(native.includes('isPaused || !coordinator.appIsActive'));
assert(native.includes('encoder.outputFormatting = [.sortedKeys]'));
assert(native.includes('UIApplication.willResignActiveNotification')&&native.includes('ProcessInfo.thermalStateDidChangeNotification'));
assert(!read('MoneyCity/MoneyCityApp.swift').includes('ThreeDioramaView.warmUp()'));
assert(read('MoneyCity/Views/Diorama/DioramaReadyWrapper.swift').includes('if hasStarted || !isPaused'));
console.log('PASS: frame-independent orbit/zoom, native visibility wiring, coordinator refresh, stable payloads and single scene startup');
