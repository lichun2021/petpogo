// 数字宠 3D 场景（Three.js r128 UMD，非 ES Module）
// 职责：只做渲染与动画播放，业务状态（养成属性等）全部由 Flutter 侧管理。
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
//
// v2：不再依赖内置的品种/动作常量表——模型 URL、背景图 URL、动作片段名
// 全部由后端驱动（GET /sdkapi/pet/:id/status、/resources），场景只负责
// 按传入的 url/cacheKey 加载模型、按传入的 clip 名字查找并播放动画。

// 模型二进制缓存：用 IndexedDB（file:// 页面下 Cache Storage API 不可用，
// IndexedDB 可用且跨会话持久，已用真机验证杀进程重启后缓存仍存在）。
// cacheKey 由调用方传入（后端资源 id），不再是硬编码的 'dog.glb'/'cat.glb'。
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
    req.onblocked = () => reject(new Error('cache blocked'));
  });
}

async function getCachedModel(key) {
  try {
    const db = await openCacheDb();
    return await new Promise((resolve, reject) => {
      const tx = db.transaction(CACHE_STORE_NAME, 'readonly');
      tx.onabort = () => reject(tx.error);
      const req = tx.objectStore(CACHE_STORE_NAME).get(key);
      req.onsuccess = () => resolve(req.result || null);
      req.onerror = () => reject(req.error);
    }).finally(() => db.close());
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
      tx.onabort = () => reject(tx.error);
    }).finally(() => db.close());
  } catch (e) {
    // 写缓存失败不影响本次渲染，下次会重新走远程
  }
}

// 默认待机动画片段名（后端约定）；模型里若没有同名片段，回退到第一个片段。
const DEFAULT_IDLE_CLIP = 'Idle1';

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

// ── 宠物模型缩放 / 位置 / 朝向调节（自己动手改这三个数就行）─────────
// 试过"按包围盒自动换算缩放"（根据模型自身高度反推倍数），但发现对带
// 骨骼动画（SkinnedMesh）的模型不可靠——包围盒量出来的"原始高度"和它
// 实际蒙皮渲染出来的视觉大小可能对不上（同样标注为"1.7 高"的一个普通
// Mesh 和一个带骨骼的 SkinnedMesh，屏幕占比能差出一个数量级），所以
// 换回最直接的手动倍数，出问题时改这三个数就行，不用猜：
// PET_SCALE：整体缩放倍数。1.0 = 模型原始大小，数值越大模型越大。
// PET_OFFSET_Y：整体上下平移（Three.js 世界坐标，正数向上、负数向下）。
// PET_ROTATION_Y：整体朝向（弧度）。0 = 模型导出时的原始朝向；
//   Math.PI（180°）= 转过来对着镜头；模型"屁股对着我们"就是这个数不对，
//   改这个，不用动摄像机。
const PET_SCALE = 0.06;
const PET_OFFSET_Y = -0.02;
const PET_ROTATION_Y = 0;

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
let clipMap = {}; // clip 名字 -> THREE.AnimationAction，来自当前加载模型的全部动画片段
let currentClipName = null; // 当前正在播放的 clip 名字，供 playAction 判断是否需要切换

// 拖拽旋转：手指在场景区域左右滑动可让宠物自由转向；松手后角度保持，
// 直到用户点击某个动作按钮，才会自动转回正面（PET_ROTATION_Y，见上方
// "自己动手改这三个数"那一块）。
let targetRotationY = PET_ROTATION_Y;
let isDragging = false;
let dragStartX = 0;
let dragStartRotationY = PET_ROTATION_Y;
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

// 把加载完成的 gltf 应用到场景：替换当前宠物、重建 AnimationMixer、
// 把模型里的全部动画片段登记进 clipMap（不再按固定 ACTIONS 白名单过滤），
// 播放默认待机动画（DEFAULT_IDLE_CLIP，没有则用第一个片段兜底）。
function applyGltfToScene(gltf, cacheKey) {
  if (currentPet) scene.remove(currentPet);
  currentPet = gltf.scene;
  currentPet.rotation.y = PET_ROTATION_Y;
  currentPet.scale.setScalar(PET_SCALE);
  currentPet.position.y = PET_OFFSET_Y;
  targetRotationY = PET_ROTATION_Y;

  // 低多边形美术风格需要"平面着色"才能看出清晰的棱面（比如鼻子上的
  // 鼻孔切面、耳朵的棱角），默认的平滑着色会把相邻面的法线插值到一起，
  // 让这些棱面糊成一片、边缘发虚。素材本身没有在导出时打上 flatShading
  // 标记，这里加载后统一给每个 mesh 的材质补上。
  currentPet.traverse((o) => {
    if (!o.isMesh) return;
    // r128 的视锥裁剪使用未蒙皮的 geometry 包围球，不能反映骨骼变换后
    // 的实际位置。鼻子、耳内等独立小网格会被误判为镜头外而消失。
    // 单宠物场景只对 SkinnedMesh 禁用裁剪，普通网格仍保留默认行为。
    if (o.isSkinnedMesh) o.frustumCulled = false;
    const mats = Array.isArray(o.material) ? o.material : [o.material];
    mats.forEach((m) => {
      m.flatShading = true;
      m.needsUpdate = true;
    });
  });

  scene.add(currentPet);

  mixer = new THREE.AnimationMixer(currentPet);
  mixer.addEventListener('finished', () => {
    notifyFlutter('actionFinished', { clip: currentClipName });
  });

  clipMap = {};
  for (const clip of gltf.animations) {
    clipMap[clip.name] = mixer.clipAction(clip);
  }

  currentClipName = null;
  const idleClip = clipMap[DEFAULT_IDLE_CLIP] ? DEFAULT_IDLE_CLIP
    : (gltf.animations[0] ? gltf.animations[0].name : null);
  if (idleClip) {
    clipMap[idleClip].play();
    currentClipName = idleClip;
  }
  loadingEl.style.display = 'none';
  notifyFlutter('petReady', { cacheKey });
}

// Bound every asynchronous stage: a blocked cache or stalled response must not
// leave the UI waiting forever. Keep URLs out of diagnostic bridge messages.
function withDeadline(promise, milliseconds, stage, onTimeout) {
  let timer;
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      timer = setTimeout(() => {
        if (onTimeout) onTimeout();
        const error = new Error(stage + ' timeout');
        error.stage = stage;
        reject(error);
      }, milliseconds);
    }),
  ]).finally(() => clearTimeout(timer));
}

function parseAndApply(arrayBuffer, cacheKey) {
  // Parsing is deliberately separate from applying: an obsolete request must
  // never replace the current pet, even if its parser finishes late.
  return new Promise((resolve, reject) => {
    loader.parse(arrayBuffer, '', resolve, reject);
  });
}

async function deleteCachedModel(key) {
  const db = await openCacheDb();
  try {
    await new Promise((resolve, reject) => {
      const tx = db.transaction(CACHE_STORE_NAME, 'readwrite');
      tx.objectStore(CACHE_STORE_NAME).delete(key);
      tx.oncomplete = resolve;
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error);
    });
  } finally { db.close(); }
}

let loadSequence = 0;
let activeLoad = null;
let activeDownload = null;
let appliedModel = null;

function loadModel(url, cacheKey) {
  const identity = JSON.stringify([url, cacheKey]);
  if (activeLoad && activeLoad.identity === identity) return activeLoad.promise;
  const sequence = ++loadSequence;
  if (activeDownload) activeDownload.abort();
  if (appliedModel === identity) {
    activeLoad = null;
    activeDownload = null;
    loadingEl.style.display = 'none';
    notifyFlutter('petReady', { cacheKey });
    return Promise.resolve();
  }
  const current = () => sequence === loadSequence;
  const stage = (name, label) => {
    if (!current()) return;
    loadingEl.textContent = label;
    notifyFlutter('petLoadStage', { cacheKey, stage: name });
  };
  loadingEl.style.display = 'flex';
  const promise = (async () => {
    let phase = 'resource';
    try {
      if (!url || !cacheKey) throw new Error('missing model resource');
      phase = 'cache';
      stage(phase, '读取模型缓存…');
      const cached = await withDeadline(getCachedModel(cacheKey), 2000, 'cache').catch(() => null);
      if (!current()) return;
      if (cached) {
        try {
          phase = 'parse';
          stage(phase, '解析模型…');
          const gltf = await withDeadline(parseAndApply(cached, cacheKey), 30000, 'parse');
          if (!current()) return;
          applyGltfToScene(gltf, cacheKey);
          appliedModel = identity;
          return;
        } catch (_) {
          if (!current()) return;
          await withDeadline(deleteCachedModel(cacheKey), 2000, 'cache').catch(() => {});
        }
      }
      if (!current()) return;
      phase = 'download';
      stage(phase, '下载模型…');
      const abort = new AbortController();
      activeDownload = abort;
      const buf = await withDeadline((async () => {
        const response = await fetch(url, { signal: abort.signal });
        if (!response.ok) throw new Error('HTTP ' + response.status);
        return response.arrayBuffer();
      })(), 60000, 'download', () => abort.abort());
      if (!current()) return;
      activeDownload = null;
      phase = 'parse';
      stage(phase, '解析模型…');
      const gltf = await withDeadline(parseAndApply(buf, cacheKey), 30000, 'parse');
      if (!current()) return;
      applyGltfToScene(gltf, cacheKey);
      appliedModel = identity;
      // Only successfully parsed files enter the persistent cache.
      void withDeadline(putCachedModel(cacheKey, buf), 2000, 'cache').catch(() => {});
    } catch (error) {
      if (!current()) return;
      loadingEl.style.display = 'none';
      notifyFlutter('petError', { cacheKey, stage: phase, message: String(error) });
    } finally {
      if (current()) {
        activeLoad = null;
        activeDownload = null;
      }
    }
  })();
  activeLoad = { identity, promise };
  // The invalid-resource branch can finish before the first await.
  void promise.finally(() => {
    if (activeLoad && activeLoad.promise === promise) activeLoad = null;
  });
  return promise;
}

// 按 clip 名字播放动画；模型没有该名字的片段时静默忽略（不报错，不切换），
// 由 Flutter 侧决定是否要提示用户——场景本身只管"有就播，没有就不动"。
function playAction(clipName, opts = {}) {
  const action = clipMap[clipName];
  if (!action || !mixer) return false;
  if (currentClipName === clipName && !opts.restart) return true; // 已在播放同一个片段，不重复触发
  Object.values(clipMap).forEach(a => a.fadeOut(0.2));
  action.reset().fadeIn(0.2).play();
  if (opts.oneShot) {
    action.setLoop(THREE.LoopOnce, 1);
    action.clampWhenFinished = true;
  }
  currentClipName = clipName;
  // 点击动作时不管当前被拖到什么角度，都转回正面朝向摄像机。
  targetRotationY = PET_ROTATION_Y;
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
  loadModel,
  playAction,
  setBackground(url) {
    bgEl.style.backgroundImage = url ? `url('${url}')` : 'none';
  },
};
