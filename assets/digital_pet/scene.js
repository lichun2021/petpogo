// 数字宠 3D 场景（Three.js r128 UMD，非 ES Module）
// 职责：只做渲染与动画播放，业务状态（饥饿值等）全部由 Flutter 侧管理。
//
// 为什么不用 ES Module：Android WebView 加载 file:// 协议下的
// <script type="module"> 会被 CORS 策略拦截（origin 为 null），
// 因此改用传统全局脚本（THREE / THREE.GLTFLoader 全局变量）。
//
// 模型资源为什么从 OSS 拉取而不是本地打包文件：file:// 页面用 fetch()
// 读取同源本地文件（file:// -> file://）会被当成跨域拦截（每个 file://
// 资源是独立的 opaque origin）；但 fetch() 一个配置了 CORS 响应头的远程
// HTTPS 地址是被允许的。因此模型改为：优先读 IndexedDB 缓存 -> 没有缓存
// 则 fetch 远程 OSS。两条路径都走 GLTFLoader.parse(arrayBuffer, ...)，
// 不用 GLTFLoader.load(url, ...)（后者内部固定用 fetch，且无法接入缓存）。

// 宠物模型配置：新增品种时只需在此加一条，不用改渲染逻辑。
// cacheKey 用作 IndexedDB 里的存储键。
const PET_MODELS = {
  dog: {
    remoteUrl: 'https://pet-20260430.oss-cn-shanghai.aliyuncs.com/pet_3d/dog.glb',
    cacheKey: 'dog.glb',
    scale: 1.0,
  },
  cat: {
    remoteUrl: 'https://pet-20260430.oss-cn-shanghai.aliyuncs.com/pet_3d/cat.glb',
    cacheKey: 'cat.glb',
    scale: 1.0,
  },
};

// 模型二进制缓存：用 IndexedDB（file:// 页面下 Cache Storage API 不可用，
// IndexedDB 可用且跨会话持久，已用真机验证杀进程重启后缓存仍存在）。
const CACHE_DB_NAME = 'digital-pet-cache';
const CACHE_STORE_NAME = 'models';

function openCacheDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(CACHE_DB_NAME, 1);
    req.onupgradeneeded = () => {
      if (!req.result.objectStoreNames.contains(CACHE_STORE_NAME)) {
        req.result.createObjectStore(CACHE_STORE_NAME);
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function getCachedModel(key) {
  try {
    const db = await openCacheDb();
    return await new Promise((resolve, reject) => {
      const tx = db.transaction(CACHE_STORE_NAME, 'readonly');
      const req = tx.objectStore(CACHE_STORE_NAME).get(key);
      req.onsuccess = () => resolve(req.result || null);
      req.onerror = () => reject(req.error);
    });
  } catch (e) {
    return null; // 缓存读取异常时静默降级，走远程
  }
}

async function putCachedModel(key, arrayBuffer) {
  try {
    const db = await openCacheDb();
    await new Promise((resolve, reject) => {
      const tx = db.transaction(CACHE_STORE_NAME, 'readwrite');
      tx.objectStore(CACHE_STORE_NAME).put(arrayBuffer, key);
      tx.oncomplete = resolve;
      tx.onerror = () => reject(tx.error);
    });
  } catch (e) {
    // 写缓存失败不影响本次渲染，下次会重新走远程
  }
}

// 猫、狗共用同一套 4 个动作名（见 tools/blender_pets 美术验收工具）：
// idle 呼吸待机 / walk 原地走路 / excited 开心跳跃 / look 歪头张望
const ACTIONS = ['idle', 'walk', 'excited', 'look'];

const canvas = document.getElementById('scene');
const bgEl = document.getElementById('bg');
const loadingEl = document.getElementById('loading');

// 渲染器与摄像机：位置固定，不支持缩放/平移；宠物朝向可通过拖拽调整（见下方 pointer 事件）
const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.outputEncoding = THREE.sRGBEncoding;

const scene = new THREE.Scene();

const camera = new THREE.PerspectiveCamera(35, window.innerWidth / window.innerHeight, 0.1, 100);
camera.position.set(0, 1.4, 4.2);
camera.lookAt(0, 0.6, 0);

const hemi = new THREE.HemisphereLight(0xfff4e6, 0x8a7b6e, 0.9);
scene.add(hemi);

const keyLight = new THREE.DirectionalLight(0xffffff, 1.1);
keyLight.position.set(2, 3, 2);
scene.add(keyLight);

function resize() {
  const w = window.innerWidth;
  const h = window.innerHeight;
  renderer.setSize(w, h);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
}
resize();
window.addEventListener('resize', resize);

const clock = new THREE.Clock();
const loader = new THREE.GLTFLoader();
let mixer = null;
let currentPet = null;
let clipMap = {};

// 片段名与 ACTIONS 完全一致（美术导出约定），不再需要别名匹配。

// 默认朝向修正：美术导出的模型正面朝 -Z（背对默认摄像机），因此固定加
// 180°(Math.PI) 的朝向修正，让默认朝向正对摄像机。
const FRONT_ROTATION_Y = Math.PI;

// 拖拽旋转：手指在场景区域左右滑动可让宠物自由转向；松手后角度保持，
// 直到用户点击某个动作按钮，才会自动转回正面（FRONT_ROTATION_Y）。
let targetRotationY = FRONT_ROTATION_Y;
let isDragging = false;
let dragStartX = 0;
let dragStartRotationY = FRONT_ROTATION_Y;
const DRAG_SENSITIVITY = 0.012; // 每像素对应的旋转弧度

function onPointerDown(e) {
  if (!currentPet) return;
  isDragging = true;
  dragStartX = e.clientX;
  dragStartRotationY = currentPet.rotation.y;
  canvas.setPointerCapture?.(e.pointerId);
}

function onPointerMove(e) {
  if (!isDragging || !currentPet) return;
  const deltaX = e.clientX - dragStartX;
  currentPet.rotation.y = dragStartRotationY + deltaX * DRAG_SENSITIVITY;
  targetRotationY = currentPet.rotation.y; // 拖动后的朝向保持，不自动回正
}

function onPointerUp(e) {
  isDragging = false;
  canvas.releasePointerCapture?.(e.pointerId);
}

canvas.addEventListener('pointerdown', onPointerDown);
canvas.addEventListener('pointermove', onPointerMove);
canvas.addEventListener('pointerup', onPointerUp);
canvas.addEventListener('pointercancel', onPointerUp);

function applyGltfToScene(gltf, kind, config) {
  if (currentPet) scene.remove(currentPet);
  currentPet = gltf.scene;
  currentPet.scale.setScalar(config.scale);
  currentPet.rotation.y = FRONT_ROTATION_Y;
  targetRotationY = FRONT_ROTATION_Y;
  scene.add(currentPet);

  mixer = new THREE.AnimationMixer(currentPet);
  mixer.addEventListener('finished', () => {
    notifyFlutter('actionFinished', {});
  });
  clipMap = {};
  for (const name of ACTIONS) {
    const clip = gltf.animations.find(c => c.name === name);
    if (clip) clipMap[name] = mixer.clipAction(clip);
  }
  if (!clipMap.idle && gltf.animations[0]) {
    clipMap.idle = mixer.clipAction(gltf.animations[0]);
  }
  if (clipMap.idle) clipMap.idle.play();
  loadingEl.style.display = 'none';
  notifyFlutter('petReady', { kind });
}

function parseAndApply(arrayBuffer, kind, config) {
  loader.parse(arrayBuffer, '', (gltf) => {
    applyGltfToScene(gltf, kind, config);
  }, (err) => {
    loadingEl.style.display = 'none';
    notifyFlutter('petError', { kind, message: String(err) });
  });
}

async function loadPet(kind) {
  const config = PET_MODELS[kind];
  if (!config) return;
  loadingEl.style.display = 'flex';

  // 1) 优先读 IndexedDB 缓存，命中则不发任何网络请求。
  const cached = await getCachedModel(config.cacheKey);
  if (cached) {
    parseAndApply(cached, kind, config);
    return;
  }

  // 2) 缓存未命中，fetch 远程 OSS 地址；成功后写入缓存供下次使用。
  try {
    const res = await fetch(config.remoteUrl);
    if (!res.ok) throw new Error('HTTP ' + res.status);
    const buf = await res.arrayBuffer();
    putCachedModel(config.cacheKey, buf); // 不阻塞渲染，失败也无所谓
    parseAndApply(buf, kind, config);
  } catch (e) {
    loadingEl.style.display = 'none';
    notifyFlutter('petError', { kind, message: String(e) });
  }
}

function playAction(name, opts = {}) {
  const action = clipMap[name];
  if (!action || !mixer) return false;
  Object.values(clipMap).forEach(a => a.fadeOut(0.2));
  action.reset().fadeIn(0.2).play();
  if (opts.oneShot) {
    action.setLoop(THREE.LoopOnce, 1);
    action.clampWhenFinished = true;
  }
  // 点击动作时不管当前被拖到什么角度，都转回正面朝向摄像机。
  targetRotationY = FRONT_ROTATION_Y;
  return true;
}

function notifyFlutter(event, data) {
  const msg = JSON.stringify({ event, data });
  if (window.FlutterBridge) {
    window.FlutterBridge.postMessage(msg);
  }
}

// 转正过程的插值速度：数值越大回正越快。
const ROTATION_LERP_SPEED = 6;

function animate() {
  requestAnimationFrame(animate);
  const delta = clock.getDelta();
  if (mixer) mixer.update(delta);
  if (currentPet && !isDragging) {
    // 拖拽中不插值（跟手），松手/点击动作后才平滑转向 targetRotationY。
    // diff 归一化到 [-PI, PI]，避免拖拽转了很多圈后回正时绕远路。
    let diff = (targetRotationY - currentPet.rotation.y) % (Math.PI * 2);
    if (diff > Math.PI) diff -= Math.PI * 2;
    if (diff < -Math.PI) diff += Math.PI * 2;
    if (Math.abs(diff) > 0.001) {
      currentPet.rotation.y += diff * Math.min(delta * ROTATION_LERP_SPEED, 1);
    } else {
      currentPet.rotation.y = targetRotationY;
    }
  }
  renderer.render(scene, camera);
}
animate();

window.DigitalPet = {
  loadPet,
  playAction,
  setBackground(url) {
    bgEl.style.backgroundImage = `url('${url}')`;
  },
};

// 默认背景，Flutter 侧可通过 setBackground 切换到 bg2 等其他场景图。
window.DigitalPet.setBackground('./bg/bg1.jpg');
window.DigitalPet.loadPet('dog');
