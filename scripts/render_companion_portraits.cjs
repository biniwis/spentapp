// Export the actual city companion models as transparent, bundled reward portraits.
// Run with NODE_PATH pointing to a node_modules directory containing playwright.
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');
const root = path.resolve(__dirname, '..');
const companions = ['pet_cat_rooftop', 'pet_golden_dog', 'resident_artist', 'resident_skater', 'resident_musician', 'resident_balloon'];
(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true,
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader']
  });
  try {
    const page = await browser.newPage({ viewport: { width: 640, height: 640 } });
    await page.evaluate(() => { window.requestAnimationFrame = () => 0; });
    await page.setContent(fs.readFileSync(path.join(root, 'MoneyCity/Resources/diorama.html'), 'utf8'));
    for (const id of companions) {
      const png = await page.evaluate((id) => {
        const portraitScene = new THREE.Scene();
        scene.children.filter(node => node.isLight).forEach(light => portraitScene.add(light.clone()));
        const model = new THREE.Group();
        COMPANION_BUILDERS[id](model);
        // Face the camera while retaining the city's authored figure and accessory poses.
        portraitScene.add(model);
        const bounds = new THREE.Box3().setFromObject(model);
        const center = bounds.getCenter(new THREE.Vector3());
        const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.01, 50);
        const angle = id === 'resident_skater' ? 0.95 : 0.38;
        camera.position.copy(center).add(new THREE.Vector3(Math.sin(angle) * 5, 2.1, Math.cos(angle) * 5));
        camera.lookAt(center);
        camera.updateMatrixWorld(true);
        // Fit the projected bounds, including the balloon, easel, tail and skateboard.
        const projected = [];
        for (const x of [bounds.min.x, bounds.max.x]) for (const y of [bounds.min.y, bounds.max.y]) for (const z of [bounds.min.z, bounds.max.z]) {
          projected.push(new THREE.Vector3(x, y, z).applyMatrix4(camera.matrixWorldInverse));
        }
        const left = Math.min(...projected.map(p => p.x)), right = Math.max(...projected.map(p => p.x));
        const bottom = Math.min(...projected.map(p => p.y)), top = Math.max(...projected.map(p => p.y));
        const half = Math.max(right - left, top - bottom) * 0.56;
        camera.left = (left + right) / 2 - half; camera.right = (left + right) / 2 + half;
        camera.bottom = (bottom + top) / 2 - half; camera.top = (bottom + top) / 2 + half;
        camera.updateProjectionMatrix();
        const output = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
        output.setSize(640, 640);
        output.setClearColor(0, 0);
        output.outputEncoding = renderer.outputEncoding;
        output.toneMapping = renderer.toneMapping;
        output.toneMappingExposure = renderer.toneMappingExposure;
        output.render(portraitScene, camera);
        const result = output.domElement.toDataURL('image/png').split(',')[1];
        output.dispose();
        return result;
      }, id);
      const folder = path.join(root, 'MoneyCity/Resources/Assets.xcassets', `companion_${id}.imageset`);
      fs.mkdirSync(folder, { recursive: true });
      fs.writeFileSync(path.join(folder, 'portrait.png'), Buffer.from(png, 'base64'));
      fs.writeFileSync(path.join(folder, 'Contents.json'), JSON.stringify({ images: [{ filename: 'portrait.png', idiom: 'universal' }], info: { author: 'xcode', version: 1 } }, null, 2) + '\n');
      console.log(`Rendered ${id}`);
    }
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
