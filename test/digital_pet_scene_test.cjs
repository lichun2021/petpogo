// Run with: node --test test/digital_pet_scene_test.cjs
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const THREE = require('../assets/digital_pet/vendor/three/three.min.js');

const source = fs.readFileSync(path.join(__dirname, '../assets/digital_pet/scene.js'), 'utf8');
const applySource = source.slice(source.indexOf('function applyGltfToScene('), source.indexOf('\nfunction parseAndApply('));

test('animated pet parts bypass unposed bounds; static meshes and materials stay intact', () => {
  const pet = new THREE.Group();
  const material = new THREE.MeshStandardMaterial({ side: THREE.DoubleSide });
  // Geometry bounds are outside the camera even though skinning can move it into view.
  const geometry = new THREE.BoxGeometry(1, 1, 1).translate(0, 1000, 0);
  const nose = new THREE.SkinnedMesh(geometry, material);
  const ear = new THREE.SkinnedMesh(geometry, [material]);
  const staticMesh = new THREE.Mesh(new THREE.BoxGeometry(), material);
  pet.add(nose, ear, staticMesh);
  const camera = new THREE.PerspectiveCamera(35, 1, 0.1, 100);
  camera.position.z = 4.2;
  camera.updateMatrixWorld();
  const frustum = new THREE.Frustum().setFromProjectionMatrix(
    new THREE.Matrix4().multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse),
  );
  pet.updateMatrixWorld(true);
  assert.equal(frustum.intersectsObject(nose), false);
  const events = [];
  const context = vm.createContext({
    THREE, scene: new THREE.Scene(), currentPet: null, mixer: null,
    PET_SCALE: 0.06, PET_OFFSET_Y: -0.02, PET_ROTATION_Y: 0,
    DEFAULT_IDLE_CLIP: 'Idle1', targetRotationY: 0, clipMap: {}, currentClipName: null,
    loadingEl: { style: {} }, notifyFlutter: (...args) => events.push(args),
  });
  vm.runInContext(applySource, context);
  const idle = new THREE.AnimationClip('Idle1', 1, []);
  context.applyGltfToScene({ scene: pet, animations: [idle] }, 'pet');
  pet.updateMatrixWorld(true);
  for (const part of [nose, ear]) {
    assert.equal(part.frustumCulled, false);
    assert.equal(!part.frustumCulled || frustum.intersectsObject(part), true);
  }
  assert.equal(staticMesh.frustumCulled, true);
  assert.equal(material.side, THREE.DoubleSide);
  assert.equal(material.transparent, false);
  assert.equal(material.opacity, 1);
  assert.equal(context.clipMap.Idle1.isRunning(), true);
  assert.equal(context.loadingEl.style.display, 'none');
  assert.equal(events[0][0], 'petReady');
});

const loadingSource = source.slice(source.indexOf('function withDeadline('), source.indexOf('// 按 clip 名字播放动画'));
function loadingHarness(overrides = {}) {
  const events = [], applied = [], writes = [], deleted = [];
  let fetches = 0;
  const context = vm.createContext({
    setTimeout: (fn, ms) => setTimeout(fn, Math.min(ms, 30)), clearTimeout,
    AbortController,
    loadingEl: { style: {}, textContent: '' },
    notifyFlutter: (event, data) => events.push({ event, data }),
    getCachedModel: async () => null,
    putCachedModel: async (key, buffer) => writes.push(buffer),
    fetch: async () => { fetches++; return { ok: true, arrayBuffer: async () => 'download' }; },
    loader: { parse: (buffer, path, resolve) => resolve({ buffer }) },
    applyGltfToScene: (gltf, key) => { applied.push(gltf.buffer); context.loadingEl.style.display = 'none'; events.push({ event: 'petReady', data: { cacheKey: key } }); },
  });
  vm.runInContext(loadingSource, context);
  context.deleteCachedModel = async (key) => deleted.push(key);
  Object.assign(context, overrides);
  return { context, events, applied, writes, deleted, get fetches() { return fetches; } };
}

test('cache hit avoids download and duplicate loads share one request', async () => {
  const cached = loadingHarness({ getCachedModel: async () => 'cached' });
  await cached.context.loadModel('https://example.test/pet.glb', 'pet');
  assert.equal(cached.fetches, 0);
  assert.deepEqual(cached.applied, ['cached']);
  const fresh = loadingHarness();
  const first = fresh.context.loadModel('https://example.test/pet.glb', 'pet');
  assert.equal(fresh.context.loadModel('https://example.test/pet.glb', 'pet'), first);
  await first;
  await fresh.context.loadModel('https://example.test/pet.glb', 'pet');
  assert.equal(fresh.fetches, 1);
  assert.equal(fresh.applied.length, 1);
});

test('blocked cache falls back to download instead of hanging', async () => {
  const h = loadingHarness({ getCachedModel: () => new Promise(() => {}) });
  await h.context.loadModel('https://example.test/pet.glb', 'pet');
  assert.equal(h.fetches, 1);
  assert.deepEqual(h.applied, ['download']);
});

test('download timeout aborts and emits a retryable failure; same URL retries', async () => {
  let signal;
  const h = loadingHarness({ fetch: (_, options) => { signal = options.signal; return new Promise(() => {}); } });
  await h.context.loadModel('https://example.test/pet.glb', 'pet');
  assert.equal(signal.aborted, true);
  assert.equal(h.events.at(-1).event, 'petError');
  assert.equal(h.events.at(-1).data.stage, 'download');
  assert.equal(h.context.loadingEl.style.display, 'none');
  h.context.fetch = async () => ({ ok: true, arrayBuffer: async () => 'retry' });
  await h.context.loadModel('https://example.test/pet.glb', 'pet');
  assert.deepEqual(h.applied, ['retry']);
});

test('corrupt cache is evicted and only successfully parsed downloads are cached', async () => {
  const h = loadingHarness({ getCachedModel: async () => 'corrupt', loader: { parse: (buf, path, resolve, reject) => buf === 'corrupt' ? reject(new Error('invalid GLB')) : resolve({ buffer: buf }) } });
  await h.context.loadModel('https://example.test/pet.glb', 'pet');
  assert.deepEqual(h.deleted, ['pet']);
  assert.deepEqual(h.applied, ['download']);
  assert.deepEqual(h.writes, ['download']);
  const bad = loadingHarness({ loader: { parse: (buf, path, resolve, reject) => reject(new Error('HTML instead of GLB')) } });
  await bad.context.loadModel('https://example.test/pet.glb', 'pet');
  assert.deepEqual(bad.writes, []);
  assert.equal(bad.events.at(-1).data.stage, 'parse');
});

test('late model parsing cannot replace a newer selection', async () => {
  let finishOld;
  const h = loadingHarness({ getCachedModel: async (key) => key, loader: { parse: (buf, path, resolve) => { if (buf === 'old') finishOld = resolve; else resolve({ buffer: buf }); } } });
  const old = h.context.loadModel('https://example.test/old.glb', 'old');
  await new Promise((resolve) => setImmediate(resolve));
  await h.context.loadModel('https://example.test/new.glb', 'new');
  finishOld({ buffer: 'old' });
  await old;
  assert.deepEqual(h.applied, ['new']);
});

test('empty model URL fails explicitly and does not leave a pending request', async () => {
  const h = loadingHarness();
  await h.context.loadModel('', '');
  await h.context.loadModel('', '');
  assert.equal(h.events.filter((e) => e.event === 'petError').length, 2);
  assert.equal(h.context.loadingEl.style.display, 'none');
});
