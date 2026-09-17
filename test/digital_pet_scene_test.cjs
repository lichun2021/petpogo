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
