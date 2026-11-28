// viewer.js — interactive 3D preview for a build package's START-HERE.html.
//
// Loads high-quality OCCT-tessellated assembly.glb (embedded as base64 for
// offline file:// viewing, or fetched over HTTP), falling back to assembly.gltf.
// When explode.json is present, provides an animated Assembly <-> Exploded
// toggle, scrubbable 0%-100% explode slider, Real/Role color mode, camera
// re-framing, and hover part inspection.
import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";

const panel = document.querySelector(".model-panel");
const canvas = panel ? panel.querySelector("canvas") : null;
const fallback = panel ? panel.querySelector(".model-fallback") : null;
const hint = panel ? panel.querySelector(".model-hint") : null;

function showHint(message) {
  if (!hint) return;
  hint.textContent = message;
  hint.hidden = false;
}

function base64ToArrayBuffer(b64) {
  const bin = atob(b64.replace(/\s+/g, ""));
  const len = bin.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = bin.charCodeAt(i);
  }
  return bytes.buffer;
}

function easeInOutCubic(x) {
  return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
}

function humanizePartName(raw) {
  if (!raw) return "";
  return raw
    .replace(/^bldc_actuator_bldc_actuator_/, "")
    .replace(/^bldc_actuator_/, "")
    .replaceAll("_", " ")
    .replaceAll("/", " · ");
}

async function loadModel(loader, onProgress) {
  const embeddedGlb = document.getElementById("embedded-assembly-glb");
  if (embeddedGlb && embeddedGlb.textContent.trim()) {
    const buf = base64ToArrayBuffer(embeddedGlb.textContent.trim());
    const gltf = await loader.parseAsync(buf, "");
    return { scene: gltf.scene, isOcctGlb: true };
  }
  try {
    const gltf = await loader.loadAsync("assembly.glb", onProgress);
    return { scene: gltf.scene, isOcctGlb: true };
  } catch (_) {
    // Fall back to legacy glTF JSON.
  }
  const embeddedGltf = document.getElementById("embedded-assembly-gltf");
  if (embeddedGltf && embeddedGltf.textContent.trim()) {
    const gltf = await loader.parseAsync(embeddedGltf.textContent, "");
    return { scene: gltf.scene, isOcctGlb: false };
  }
  const gltf = await loader.loadAsync("assembly.gltf", onProgress);
  return { scene: gltf.scene, isOcctGlb: false };
}

async function loadExplodeData() {
  const embedded = document.getElementById("embedded-explode-json");
  if (embedded && embedded.textContent.trim()) {
    try {
      return JSON.parse(embedded.textContent);
    } catch (_) {
      return null;
    }
  }
  try {
    const res = await fetch("explode.json");
    if (res.ok) return await res.json();
  } catch (_) {
    // Ignore when explode.json is not present.
  }
  return null;
}

function createToolbar(panelEl, hasExplode) {
  const bar = document.createElement("div");
  bar.className = "viewer-toolbar";
  bar.innerHTML = hasExplode
    ? `
      <button type="button" class="viewer-btn viewer-btn-primary" data-action="toggle-explode" title="Animate between Assembled and Exploded views">
        <span class="viewer-btn-icon">⇕</span>
        <span class="viewer-btn-label">Explode</span>
      </button>
      <label class="viewer-slider-wrap" title="Scrub assembly explosion (0% – 100%)">
        <input type="range" class="viewer-slider" min="0" max="100" value="0" step="0.5" aria-label="Explode amount" />
        <span class="viewer-slider-pct">0%</span>
      </label>
      <button type="button" class="viewer-btn" data-action="toggle-colors" title="Toggle color-coded exploded palette">
        Role Colors
      </button>
      <button type="button" class="viewer-btn" data-action="reset-view" title="Re-center camera on current view">
        Reset View
      </button>
      <button type="button" class="viewer-btn" data-action="fullscreen" title="Expand 3D viewer to full screen">
        ⛶ Full Screen
      </button>
    `
    : `
      <button type="button" class="viewer-btn" data-action="reset-view" title="Re-center camera">
        Reset View
      </button>
      <button type="button" class="viewer-btn" data-action="fullscreen" title="Expand 3D viewer to full screen">
        ⛶ Full Screen
      </button>
    `;
  panelEl.appendChild(bar);

  const tooltip = document.createElement("div");
  tooltip.className = "viewer-part-tooltip";
  tooltip.hidden = true;
  panelEl.appendChild(tooltip);

  const ctxMenu = document.createElement("div");
  ctxMenu.className = "viewer-context-menu";
  ctxMenu.hidden = true;
  ctxMenu.innerHTML = `
    <div class="viewer-context-header"></div>
    <button type="button" class="viewer-context-item" data-action="focus-part">
      <span>🎯</span>
      <span>Focus Part (Lock During Explode)</span>
    </button>
    <button type="button" class="viewer-context-item" data-action="copy-part-name">
      <span>📋</span>
      <span>Copy Part Name to Clipboard</span>
    </button>
  `;
  panelEl.appendChild(ctxMenu);

  const focusBadge = document.createElement("div");
  focusBadge.className = "viewer-focus-badge";
  focusBadge.hidden = true;
  focusBadge.innerHTML = `
    <span class="viewer-focus-label"></span>
    <button type="button" class="viewer-focus-clear" title="Clear focus (Esc)">✕</button>
  `;
  panelEl.appendChild(focusBadge);

  const toast = document.createElement("div");
  toast.className = "viewer-toast";
  toast.hidden = true;
  panelEl.appendChild(toast);

  return { bar, tooltip, ctxMenu, focusBadge, toast };
}

async function init() {
  if (!panel || !canvas) return;

  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
  } catch (error) {
    showHint("WebGL is unavailable; showing the isometric render.");
    return;
  }
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.15;

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(35, 1, 0.001, 100);

  // Crisp 3-point + rim studio lighting so dark CF-nylon housings read clearly.
  scene.add(new THREE.HemisphereLight(0xf6f9ff, 0x334155, 1.55));
  const key = new THREE.DirectionalLight(0xfffaf0, 2.2);
  key.position.set(1.4, 2.4, 1.8);
  scene.add(key);
  const fill = new THREE.DirectionalLight(0xdbeafe, 1.05);
  fill.position.set(-1.8, 0.9, 1.2);
  scene.add(fill);
  const rim = new THREE.DirectionalLight(0xe0f2fe, 1.25);
  rim.position.set(-0.6, 1.4, -2.0);
  scene.add(rim);

  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.08;

  const loader = new GLTFLoader();
  showHint("Loading interactive 3D model…");
  const onProgress = (ev) => {
    if (ev && ev.lengthComputable && ev.total > 0) {
      const pct = Math.min(99, Math.round((ev.loaded / ev.total) * 100));
      const mb = (ev.total / (1024 * 1024)).toFixed(1);
      showHint(`Loading interactive 3D model… ${pct}% (${mb} MB)`);
    }
  };
  let loaded;
  try {
    loaded = await loadModel(loader, onProgress);
  } catch (error) {
    showHint("3D model unavailable (serve this folder over http); showing the isometric render.");
    return;
  }

  const explodeData = await loadExplodeData();
  const model = loaded.scene;
  // Both OCCT GLB (RWGltf_CafWriter) and MoonBit glTF preserve STEP Z-up;
  // rotate the model container into Three.js Y-up so +Z points straight up
  // and local Z-axis explode offsets slide every part coaxially.
  model.rotation.x = -Math.PI / 2;

  const root = new THREE.Group();
  root.add(model);
  scene.add(root);

  // Enhance materials and bind each part node to its explode vector & window.
  // OCCT GLB meshes with multiple primitives load as a THREE.Group (carrying
  // the real part name) whose children are THREE.Mesh leaves, while single-
  // primitive meshes load directly as a THREE.Mesh. Three.js also sanitizes
  // node names (removing '/' etc.), so we match both exact and sanitized keys.
  const rawPartMap = (explodeData && explodeData.parts) || {};
  const sanitizeKey = (s) => (s || "").replace(/[\/\[\].:\s]/g, "");
  const sanitizedPartMap = new Map();
  for (const [k, v] of Object.entries(rawPartMap)) {
    sanitizedPartMap.set(k, v);
    const sk = sanitizeKey(k);
    if (!sanitizedPartMap.has(sk)) sanitizedPartMap.set(sk, v);
  }
  const lookupPartSpecs = (name) => {
    if (!name) return null;
    if (sanitizedPartMap.has(name)) return { key: name, list: sanitizedPartMap.get(name) };
    const sk = sanitizeKey(name);
    if (sanitizedPartMap.has(sk)) return { key: sk, list: sanitizedPartMap.get(sk) };
    // Three.js GLTFLoader appends _1, _2, _3 to duplicate node names (e.g.
    // identical M3-10 screws or brass inserts). Strip the numeric suffix.
    const stripped = sk.replace(/_\d+$/, "");
    if (stripped !== sk && sanitizedPartMap.has(stripped)) {
      return { key: stripped, list: sanitizedPartMap.get(stripped) };
    }
    return null;
  };

  const usedSpecs = new Map();
  const animatedParts = [];
  const pickableMeshes = [];
  const boundObjects = new Set();

  const partLabelMap = new Map();
  const embeddedLabelsEl = document.getElementById("embedded-part-labels");
  if (embeddedLabelsEl && embeddedLabelsEl.textContent.trim()) {
    try {
      const parsed = JSON.parse(embeddedLabelsEl.textContent);
      for (const [k, v] of Object.entries(parsed)) {
        partLabelMap.set(k, v);
      }
    } catch (_) {
      // Fall back to humanized node names.
    }
  }
  const lookupPartLabel = (rawName) => {
    if (!rawName) return "";
    const sk = sanitizeKey(rawName);
    if (partLabelMap.has(sk)) return partLabelMap.get(sk);
    const stripped = sk.replace(/_\d+$/, "");
    if (stripped !== sk && partLabelMap.has(stripped)) {
      return partLabelMap.get(stripped);
    }
    return "";
  };

  // First pass: enhance all mesh materials and record base colors.
  model.traverse((obj) => {
    if (!obj.isMesh) return;
    if (Array.isArray(obj.material)) {
      obj.material = obj.material.map((m) => m.clone());
    } else if (obj.material) {
      obj.material = obj.material.clone();
    }
    const mats = Array.isArray(obj.material) ? obj.material : [obj.material];
    const baseColors = [];
    for (const m of mats) {
      if (!m || !m.color) continue;
      // Lift pitch-black plastic/CF-nylon slightly so contours and keyways stand out.
      const hsl = { h: 0, s: 0, l: 0 };
      m.color.getHSL(hsl);
      if (hsl.l < 0.08) {
        m.color.setHSL(hsl.h, Math.min(hsl.s, 0.15), 0.14);
      }
      if ("roughness" in m && m.roughness > 0.7) {
        m.roughness = 0.52;
      }
      if ("metalness" in m && m.metalness === 0) {
        m.metalness = 0.12;
      }
      baseColors.push(m.color.clone());
    }
    obj.userData.baseColors = baseColors;
    const rawName = (obj.parent && obj.parent !== model && obj.parent.name) ? obj.parent.name : obj.name;
    obj.userData.rawName = rawName;
    const partLabel = lookupPartLabel(rawName);
    const humanized = humanizePartName(rawName);
    obj.userData.partNumber = partLabel;
    obj.userData.displayName = partLabel ? `${partLabel} · ${humanized}` : humanized;
    pickableMeshes.push(obj);
  });

  // Second pass: bind top-most named part nodes (Group or single Mesh) to explode vectors.
  model.traverse((obj) => {
    if (obj === model) return;
    // Skip children of an already-bound part group.
    let p = obj.parent;
    while (p && p !== model) {
      if (boundObjects.has(p)) return;
      p = p.parent;
    }
    const found = lookupPartSpecs(obj.name);
    if (!found || !found.list || found.list.length === 0) return;

    const { key, list } = found;
    let used = usedSpecs.get(key);
    if (!used) {
      used = new Set();
      usedSpecs.set(key, used);
    }
    // Compute this object's local (STEP Z-up metres) bounding-box center so
    // duplicate-named instances (like top vs bottom HEATSET inserts) match
    // their exact 3D counterpart in explode.json regardless of traversal order.
    let specIdx = -1;
    if (list.length > 1 && list[0].center) {
      model.updateMatrixWorld(true);
      const localBox = new THREE.Box3().setFromObject(obj);
      const worldCenter = localBox.getCenter(new THREE.Vector3());
      const invModel = new THREE.Matrix4().copy(model.matrixWorld).invert();
      const objCenter = worldCenter.applyMatrix4(invModel);
      let bestDist = Infinity;
      for (let i = 0; i < list.length; i++) {
        if (used.has(i) || !list[i].center) continue;
        const c = list[i].center;
        const d =
          (objCenter.x - c[0]) ** 2 +
          (objCenter.y - c[1]) ** 2 +
          (objCenter.z - c[2]) ** 2;
        if (d < bestDist) {
          bestDist = d;
          specIdx = i;
        }
      }
    }
    if (specIdx < 0) {
      for (let i = 0; i < list.length; i++) {
        if (!used.has(i)) {
          specIdx = i;
          break;
        }
      }
      if (specIdx < 0) specIdx = list.length - 1;
    }
    used.add(specIdx);
    const spec = list[specIdx];
    const offset = new THREE.Vector3(spec.offset[0], spec.offset[1], spec.offset[2]);
    const roleColor = spec.color
      ? new THREE.Color(spec.color[0], spec.color[1], spec.color[2])
      : null;

    const meshes = [];
    if (obj.isMesh) {
      meshes.push(obj);
    } else {
      obj.traverse((child) => {
        if (child.isMesh) meshes.push(child);
      });
    }
    boundObjects.add(obj);
    animatedParts.push({
      obj,
      basePos: obj.position.clone(),
      offset,
      window: spec.window || [0, 1],
      meshes,
      roleColor,
    });
  });

  const hasExplode = animatedParts.some((p) => p.offset.lengthSq() > 1e-8);

  function computeFitPose() {
    root.updateMatrixWorld(true);
    const box = new THREE.Box3().setFromObject(root);
    const size = box.getSize(new THREE.Vector3());
    const center = box.getCenter(new THREE.Vector3());
    const radius = Math.max(size.x, size.y, size.z) * 0.52 || 0.1;
    const distance = radius / Math.sin(THREE.MathUtils.degToRad(35) / 2);
    return { center, distance };
  }

  // Center the assembled model at the world origin.
  root.updateMatrixWorld(true);
  const initBox = new THREE.Box3().setFromObject(root);
  const initCenter = initBox.getCenter(new THREE.Vector3());
  root.position.sub(initCenter);

  let currentT = 0;
  let targetT = 0;
  let isAnimating = false;
  let animStartTime = 0;
  let animFromT = 0;
  let animToT = 0;
  const ANIM_DURATION_MS = 1650;
  let useRoleColors = false;

  // Smooth camera transition targets when clicking Explode / Assemble / Reset / Focus.
  let camAnim = null;
  // Sticky focus state: when set, camera + orbit target track this part's
  // world-space center delta as the explosion slider/animation moves parts.
  let focusedTarget = null;

  function computeTargetBounds(meshes) {
    root.updateMatrixWorld(true);
    const box = new THREE.Box3();
    for (const m of meshes) {
      box.expandByObject(m);
    }
    if (box.isEmpty()) {
      return { center: new THREE.Vector3(), radius: 0.05 };
    }
    const size = box.getSize(new THREE.Vector3());
    const center = box.getCenter(new THREE.Vector3());
    const radius = Math.max(size.x, size.y, size.z) * 0.5 || 0.02;
    return { center, radius };
  }

  function applyExplode(t) {
    const prevFocusCenter = focusedTarget
      ? computeTargetBounds(focusedTarget.meshes).center
      : null;

    currentT = Math.max(0, Math.min(1, t));
    for (const part of animatedParts) {
      const [w0, w1] = part.window;
      const local = w1 > w0 ? Math.max(0, Math.min(1, (currentT - w0) / (w1 - w0))) : currentT;
      const eased = easeInOutCubic(local);
      part.obj.position.copy(part.basePos).addScaledVector(part.offset, eased);

      if (part.roleColor) {
        const colorMix = useRoleColors ? 1.0 : 0.0;
        for (const mesh of part.meshes) {
          const mats = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
          const baseColors = mesh.userData.baseColors || [];
          for (let i = 0; i < mats.length; i++) {
            const m = mats[i];
            if (m && m.color && baseColors[i]) {
              m.color.copy(baseColors[i]).lerp(part.roleColor, colorMix);
            }
          }
        }
      }
    }

    if (focusedTarget && prevFocusCenter) {
      const newFocusCenter = computeTargetBounds(focusedTarget.meshes).center;
      const delta = newFocusCenter.clone().sub(prevFocusCenter);
      if (delta.lengthSq() > 1e-14) {
        camera.position.add(delta);
        controls.target.add(delta);
        if (camAnim) {
          camAnim.fromPos.add(delta);
          camAnim.toPos.add(delta);
          camAnim.fromTarget.add(delta);
          camAnim.toTarget.add(delta);
        }
      }
    }
  }

  // Precompute assembled & exploded camera poses (preserving current viewing direction).
  applyExplode(0);
  const assembledFit = computeFitPose();
  let explodedFit = assembledFit;
  if (hasExplode) {
    applyExplode(1);
    explodedFit = computeFitPose();
    applyExplode(0);
  }

  function frameCameraInstant(fit) {
    const dir = new THREE.Vector3(0.78, 0.48, 0.82).normalize();
    camera.position.copy(fit.center).addScaledVector(dir, fit.distance * 1.05);
    camera.near = Math.max(fit.distance / 250, 0.0005);
    camera.far = fit.distance * 25;
    camera.updateProjectionMatrix();
    controls.target.copy(fit.center);
    controls.update();
  }

  function startCameraTransition(fit, durationMs = 1100) {
    const curDir = camera.position.clone().sub(controls.target);
    if (curDir.lengthSq() < 1e-8) {
      curDir.set(0.78, 0.48, 0.82);
    }
    curDir.normalize();
    const goalPos = fit.center.clone().addScaledVector(curDir, fit.distance * 1.08);
    camAnim = {
      startTime: performance.now(),
      duration: durationMs,
      fromPos: camera.position.clone(),
      toPos: goalPos,
      fromTarget: controls.target.clone(),
      toTarget: fit.center.clone(),
      near: Math.max(fit.distance / 250, 0.0005),
      far: fit.distance * 25,
    };
  }

  frameCameraInstant(assembledFit);

  // Stop automatic camera transition if user manually grabs the orbit controls.
  controls.addEventListener("start", () => {
    camAnim = null;
  });

  // Build interactive toolbar, tooltip, context menu, focus badge & toast.
  const { bar, tooltip, ctxMenu, focusBadge, toast } = createToolbar(panel, hasExplode);
  const ctxHeader = ctxMenu.querySelector(".viewer-context-header");
  const ctxFocusBtn = ctxMenu.querySelector('[data-action="focus-part"]');
  const ctxCopyBtn = ctxMenu.querySelector('[data-action="copy-part-name"]');
  const focusLabelEl = focusBadge.querySelector(".viewer-focus-label");
  const focusClearBtn = focusBadge.querySelector(".viewer-focus-clear");
  let ctxTargetName = "";
  let ctxTargetMesh = null;
  let toastTimer = null;

  function setMeshEmissive(mesh, hex, intensity) {
    if (!mesh) return;
    const mats = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
    for (const m of mats) {
      if (m && m.emissive) {
        m.emissive.setHex(hex);
        m.emissiveIntensity = intensity;
      }
    }
  }

  function refreshMeshHighlight(mesh) {
    if (!mesh) return;
    const isFocused = focusedTarget && focusedTarget.meshes.includes(mesh);
    if (mesh === hoveredMesh) {
      setMeshEmissive(mesh, 0x1d4ed8, 0.42);
    } else if (isFocused) {
      setMeshEmissive(mesh, 0xf59e0b, 0.36);
    } else {
      setMeshEmissive(mesh, 0x000000, 0);
    }
  }

  function clearFocus() {
    if (!focusedTarget) return;
    const prev = focusedTarget.meshes;
    focusedTarget = null;
    for (const m of prev) refreshMeshHighlight(m);
    focusBadge.hidden = true;
  }

  function meshesForSamePart(mesh) {
    if (!mesh) return [];
    const parent = mesh.parent;
    if (parent && parent !== model && parent.name) {
      const groupMeshes = [];
      parent.traverse((c) => {
        if (c.isMesh) groupMeshes.push(c);
      });
      if (groupMeshes.length > 0) return groupMeshes;
    }
    return [mesh];
  }

  function focusOnMeshes(meshes, label, scrollToViewer = false) {
    if (!meshes || meshes.length === 0) return;
    clearFocus();
    focusedTarget = { label, meshes };
    for (const m of meshes) refreshMeshHighlight(m);
    if (focusLabelEl) focusLabelEl.textContent = `🎯 Focused: ${label}`;
    focusBadge.hidden = false;
    const { center, radius } = computeTargetBounds(meshes);
    const distance = Math.max(radius * 3.8, 0.045);
    startCameraTransition({ center, distance }, 750);
    if (scrollToViewer) {
      panel.scrollIntoView({ behavior: "smooth", block: "center" });
    }
    showToast(`Focused: ${label}`);
  }

  function focusByQuery(query, scrollToViewer = true) {
    const q = (query || "").trim().toLowerCase();
    if (!q) return false;
    const qNorm = q.replaceAll("_", " ");
    let matched = pickableMeshes.filter(
      (m) =>
        (m.userData.partNumber || "").toLowerCase() === q ||
        (m.userData.displayName || "").toLowerCase() === qNorm,
    );
    if (matched.length === 0) {
      matched = pickableMeshes.filter(
        (m) => (m.userData.rawName || "").toLowerCase() === q,
      );
    }
    if (matched.length === 0) {
      matched = pickableMeshes.filter((m) => {
        const dn = (m.userData.displayName || "").toLowerCase();
        const rn = (m.userData.rawName || "").toLowerCase();
        return dn.includes(qNorm) || rn.includes(q);
      });
    }
    if (matched.length === 0) {
      showToast(`Part not found in 3D view: ${query}`);
      return false;
    }
    const label = matched.length === 1 && matched[0].userData.displayName
      ? matched[0].userData.displayName
      : query;
    focusOnMeshes(matched, label, scrollToViewer);
    return true;
  }

  if (focusClearBtn) {
    focusClearBtn.addEventListener("click", () => {
      clearFocus();
      showToast("Focus cleared");
    });
  }

  document.addEventListener("click", (ev) => {
    const link = ev.target && ev.target.closest ? ev.target.closest("[data-focus-part]") : null;
    if (!link) return;
    ev.preventDefault();
    const query = link.getAttribute("data-focus-part") || link.textContent || "";
    focusByQuery(query, true);
  });

  function showToast(msg) {
    toast.textContent = msg;
    toast.hidden = false;
    if (toastTimer) clearTimeout(toastTimer);
    toastTimer = setTimeout(() => {
      toast.hidden = true;
    }, 1800);
  }

  function copyTextSync(text) {
    // Mount inside fullscreenElement if in fullscreen so focus/select works
    // in the browser's top layer; avoid opacity:0 which Safari may skip.
    const host =
      document.fullscreenElement ||
      document.webkitFullscreenElement ||
      document.body;
    const ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "");
    ta.style.position = "fixed";
    ta.style.left = "-9999px";
    ta.style.top = "0";
    ta.style.fontSize = "16px";
    host.appendChild(ta);
    ta.focus();
    ta.select();
    ta.setSelectionRange(0, text.length);
    let ok = false;
    try {
      ok = document.execCommand("copy");
    } catch (_) {
      ok = false;
    }
    host.removeChild(ta);
    return ok;
  }

  function hideContextMenu() {
    ctxMenu.hidden = true;
    ctxTargetName = "";
    ctxTargetMesh = null;
  }

  if (ctxFocusBtn) {
    ctxFocusBtn.addEventListener("click", () => {
      const targetMesh = ctxTargetMesh;
      const targetName = ctxTargetName;
      hideContextMenu();
      if (!targetMesh) return;
      focusOnMeshes(meshesForSamePart(targetMesh), targetName, false);
    });
  }

  if (ctxCopyBtn) {
    ctxCopyBtn.addEventListener("click", () => {
      const nameToCopy = ctxTargetName;
      hideContextMenu();
      if (!nameToCopy) return;
      if (window.isSecureContext && navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(nameToCopy).then(
          () => showToast(`Copied: ${nameToCopy}`),
          () => {
            const ok = copyTextSync(nameToCopy);
            showToast(ok ? `Copied: ${nameToCopy}` : `Copy failed — ${nameToCopy}`);
          },
        );
      } else {
        const ok = copyTextSync(nameToCopy);
        showToast(ok ? `Copied: ${nameToCopy}` : `Copy failed — ${nameToCopy}`);
      }
    });
  }

  document.addEventListener("pointerdown", (ev) => {
    if (!ctxMenu.hidden && !ctxMenu.contains(ev.target)) {
      hideContextMenu();
    }
  });
  document.addEventListener("keydown", (ev) => {
    if (ev.key === "Escape") {
      if (!ctxMenu.hidden) {
        hideContextMenu();
      } else if (focusedTarget) {
        clearFocus();
        showToast("Focus cleared");
      }
    }
  });
  const toggleBtn = bar.querySelector('[data-action="toggle-explode"]');
  const toggleLabel = toggleBtn ? toggleBtn.querySelector(".viewer-btn-label") : null;
  const slider = bar.querySelector(".viewer-slider");
  const sliderPct = bar.querySelector(".viewer-slider-pct");
  const colorBtn = bar.querySelector('[data-action="toggle-colors"]');
  const resetBtn = bar.querySelector('[data-action="reset-view"]');
  const fsBtn = bar.querySelector('[data-action="fullscreen"]');

  function syncUI() {
    if (slider) slider.value = String(Math.round(currentT * 1000) / 10);
    if (sliderPct) sliderPct.textContent = `${Math.round(currentT * 100)}%`;
    if (toggleLabel) {
      const nextIsAssemble = isAnimating ? animToT > 0.5 : currentT > 0.5;
      toggleLabel.textContent = nextIsAssemble ? "Assemble" : "Explode";
    }
    if (colorBtn) {
      colorBtn.classList.toggle("is-active", useRoleColors);
    }
  }

  if (toggleBtn) {
    toggleBtn.addEventListener("click", () => {
      const goingToExplode = isAnimating ? animToT < 0.5 : currentT < 0.5;
      targetT = goingToExplode ? 1 : 0;
      animFromT = currentT;
      animToT = targetT;
      animStartTime = performance.now();
      isAnimating = true;
      if (!focusedTarget) {
        startCameraTransition(goingToExplode ? explodedFit : assembledFit, ANIM_DURATION_MS);
      }
      syncUI();
    });
  }

  if (slider) {
    slider.addEventListener("input", () => {
      isAnimating = false;
      camAnim = null;
      const val = parseFloat(slider.value) / 100;
      applyExplode(val);
      syncUI();
    });
  }

  if (colorBtn) {
    colorBtn.addEventListener("click", () => {
      useRoleColors = !useRoleColors;
      applyExplode(currentT);
      syncUI();
    });
  }

  if (resetBtn) {
    resetBtn.addEventListener("click", () => {
      clearFocus();
      const fit = computeFitPose();
      startCameraTransition(fit, 650);
    });
  }

  if (fsBtn) {
    const syncFsButton = () => {
      const active =
        document.fullscreenElement === panel ||
        document.webkitFullscreenElement === panel;
      fsBtn.textContent = active ? "✕ Exit Full Screen" : "⛶ Full Screen";
      fsBtn.classList.toggle("is-active", active);
      resize();
    };
    fsBtn.addEventListener("click", () => {
      const active =
        document.fullscreenElement === panel ||
        document.webkitFullscreenElement === panel;
      if (active) {
        if (document.exitFullscreen) document.exitFullscreen();
        else if (document.webkitExitFullscreen) document.webkitExitFullscreen();
      } else {
        if (panel.requestFullscreen) panel.requestFullscreen();
        else if (panel.webkitRequestFullscreen) panel.webkitRequestFullscreen();
      }
    });
    document.addEventListener("fullscreenchange", syncFsButton);
    document.addEventListener("webkitfullscreenchange", syncFsButton);
  }

  // Hover part inspection via raycaster.
  const raycaster = new THREE.Raycaster();
  const pointer = new THREE.Vector2();
  let hoveredMesh = null;

  canvas.addEventListener("pointermove", (ev) => {
    if (ev.buttons !== 0) {
      tooltip.hidden = true;
      return;
    }
    const rect = canvas.getBoundingClientRect();
    pointer.x = ((ev.clientX - rect.left) / rect.width) * 2 - 1;
    pointer.y = -((ev.clientY - rect.top) / rect.height) * 2 + 1;
    raycaster.setFromCamera(pointer, camera);
    const hits = raycaster.intersectObjects(pickableMeshes, false);
    const hit = hits.length > 0 ? hits[0].object : null;
    if (hit !== hoveredMesh) {
      const prev = hoveredMesh;
      hoveredMesh = hit;
      refreshMeshHighlight(prev);
      refreshMeshHighlight(hoveredMesh);
    }
    if (hoveredMesh && hoveredMesh.userData.displayName) {
      tooltip.textContent = hoveredMesh.userData.displayName;
      tooltip.hidden = false;
    } else {
      tooltip.hidden = true;
    }
  });

  canvas.addEventListener("pointerleave", () => {
    const prev = hoveredMesh;
    hoveredMesh = null;
    refreshMeshHighlight(prev);
    tooltip.hidden = true;
  });

  // Right-click context menu (only on clean click, < 5 px drag so right-drag pan still works).
  let rDownPos = null;
  canvas.addEventListener("pointerdown", (ev) => {
    if (ev.button === 2) {
      rDownPos = { x: ev.clientX, y: ev.clientY };
    }
  });
  canvas.addEventListener("contextmenu", (ev) => {
    ev.preventDefault();
    if (rDownPos) {
      const moved = Math.hypot(ev.clientX - rDownPos.x, ev.clientY - rDownPos.y);
      rDownPos = null;
      if (moved > 5) return;
    }
    const rect = canvas.getBoundingClientRect();
    pointer.x = ((ev.clientX - rect.left) / rect.width) * 2 - 1;
    pointer.y = -((ev.clientY - rect.top) / rect.height) * 2 + 1;
    raycaster.setFromCamera(pointer, camera);
    const hits = raycaster.intersectObjects(pickableMeshes, false);
    const hit = hits.length > 0 ? hits[0].object : null;
    const partName = hit && hit.userData.displayName ? hit.userData.displayName : "";
    if (!partName) {
      hideContextMenu();
      return;
    }
    ctxTargetName = partName;
    ctxTargetMesh = hit;
    if (ctxHeader) ctxHeader.textContent = partName;
    const panelRect = panel.getBoundingClientRect();
    let left = ev.clientX - panelRect.left;
    let top = ev.clientY - panelRect.top;
    ctxMenu.hidden = false;
    const menuW = ctxMenu.offsetWidth || 220;
    const menuH = ctxMenu.offsetHeight || 72;
    if (left + menuW > panelRect.width - 8) left = Math.max(8, panelRect.width - menuW - 8);
    if (top + menuH > panelRect.height - 8) top = Math.max(8, panelRect.height - menuH - 8);
    ctxMenu.style.left = `${left}px`;
    ctxMenu.style.top = `${top}px`;
  });

  if (fallback) fallback.hidden = true;
  canvas.hidden = false;
  showHint(hasExplode ? "Drag to orbit · scroll to zoom · hover parts" : "Drag to orbit · scroll to zoom");
  syncUI();

  function resize() {
    const width = panel.clientWidth || 640;
    const height = panel.clientHeight || 520;
    renderer.setSize(width, height, false);
    camera.aspect = width / Math.max(height, 1);
    camera.updateProjectionMatrix();
  }
  window.addEventListener("resize", resize);
  resize();

  renderer.setAnimationLoop((now) => {
    if (isAnimating) {
      const raw = Math.min(1, (now - animStartTime) / ANIM_DURATION_MS);
      const t = animFromT + (animToT - animFromT) * easeInOutCubic(raw);
      applyExplode(t);
      if (raw >= 1) {
        isAnimating = false;
      }
      syncUI();
    }
    if (camAnim) {
      const raw = Math.min(1, (now - camAnim.startTime) / camAnim.duration);
      const e = easeInOutCubic(raw);
      camera.position.lerpVectors(camAnim.fromPos, camAnim.toPos, e);
      controls.target.lerpVectors(camAnim.fromTarget, camAnim.toTarget, e);
      camera.near = camAnim.near;
      camera.far = camAnim.far;
      camera.updateProjectionMatrix();
      if (raw >= 1) camAnim = null;
    }
    controls.update();
    renderer.render(scene, camera);
  });
}

init();
