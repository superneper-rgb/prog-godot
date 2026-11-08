// LEVEL EXPORTER, page half: runs inside the three.js game (tools/export/export.mjs injects it). Turns what a level built into scene.glb, colliders.json, level.json,
// instances.bin, shaders/*.json and probes.json for the Godot port. See tools/export/export.mjs for the commands and CLAUDE.md for where the files live.
//
// How a level becomes a GLB:
//  - Every Object3D under the level's root is watched for a few seconds of real play (sample): local matrix, visibility, geometry version, material state, instance buffers.
//  - Whatever moved, toggled, has a .name or is hidden becomes a KEPT node (Godot node, findable by its JS name); everything else is baked into merged meshes, one per material
//    family and cell (64 m, like auto-merge.js), under its nearest kept ancestor. The auto-merge's own meshes are skipped: its originals stay in the graph on layer 0.
//  - Materials fold like auto-merge's: colour goes per vertex (sRGB encoded, because Godot keeps vertex colours as RGBA8 and this game's palette is near black), so only what
//    glTF cannot put per vertex splits a family: map, roughness / metalness bucket, emissive, alpha mode, sides, blending.
//  - InstancedMesh stays instancing: Godot 4.7 does not read EXT_mesh_gpu_instancing (not in the binary), so a template node goes in the GLB and the transforms into instances.bin,
//    in the exact layout of MultiMesh.buffer. Static ones are split per cell for culling.
//  - Textures become real files in <out>/_tex/<hash>.jpg|webp, deduped by content across levels, referenced from the GLB by uri (Godot's importer loads them through its own
//    texture import, which is what gives VRAM compression and mipmaps). three.js flipY textures keep their pixels upright and the UVs get v = 1 - v instead.
//  - ShaderMaterials and onBeforeCompile hooks cannot go in glTF: their source goes to shaders/<name>.json as a work list, the node gets a placeholder and is tagged via extras.
(() => {
  if (window.__exp) return;
  const G = window.__game, THREE = G.THREE;
  const MP = THREE.Material.prototype;
  // Stand-ins for three.js's shaders: every chunk marker an onBeforeCompile hook in this game replaces, so what it adds can be read back.
  const OBC_V = ['#include <common>', '#include <begin_vertex>', '#include <project_vertex>', 'void main() {'].join('\n');
  const OBC_F = ['#include <common>', '#include <map_fragment>', '#include <color_fragment>', '#include <specularmap_fragment>', '#include <emissivemap_fragment>', '#include <opaque_fragment>', 'void main() {'].join('\n');
  const TM_NAMES = ['none', 'linear', 'reinhard', 'cineon', 'aces', 'custom', 'agx'];
  let RECV = '', GLTFExporter = null;

  // ------------------------------------------------------------------------------------------------ small helpers ----
  const put = async (rel, body) => { const r = await fetch(RECV + '/put?f=' + encodeURIComponent(rel), { method: 'POST', body }); if (!r.ok) throw new Error('put failed: ' + rel); };
  const say = (m) => { console.log('[export] ' + m); };
  const rnd = (v, n = 5) => (Number.isFinite(v) ? +v.toFixed(n) : null);
  const arr3 = (v) => [rnd(v.x), rnd(v.y), rnd(v.z)];
  const col3 = (c) => [rnd(c.r), rnd(c.g), rnd(c.b)];
  const linToS = (c) => (c <= 0 ? 0 : c >= 1 ? 1 : c < 0.0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - 0.055);
  const hashBytes = (u8) => { let a = 0x811c9dc5, b = 0x9747b28c; for (let i = 0; i < u8.length; i++) { const x = u8[i]; a = Math.imul(a ^ x, 16777619); b = Math.imul(b + x, 0x5bd1e995); b ^= b >>> 13; } return (a >>> 0).toString(16).padStart(8, '0') + (b >>> 0).toString(16).padStart(8, '0'); };
  const hashStr = (s) => { const u = new Uint8Array(s.length * 2); for (let i = 0; i < s.length; i++) { const c = s.charCodeAt(i); u[i * 2] = c & 255; u[i * 2 + 1] = c >> 8; } return hashBytes(u); };
  const safeName = (s) => String(s || '').replace(/[^A-Za-z0-9_]+/g, '_').replace(/^_+|_+$/g, '').slice(0, 48);
  const blobOf = (cv, type, q) => new Promise((ok, bad) => cv.toBlob((b) => (b ? ok(b) : bad(new Error('toBlob failed'))), type, q));
  const nextFrame = () => new Promise((ok) => setTimeout(ok, 16));

  /** JSON-able copy of level data: numbers, strings, plain objects and arrays; functions and engine objects dropped (an Object3D keeps its name) */
  function plain(v, depth = 0, seen = new Set()) {
    if (v === null || typeof v === 'boolean' || typeof v === 'string') return v;
    if (typeof v === 'number') return Number.isFinite(v) ? rnd(v, 5) : null;
    if (typeof v !== 'object' || depth > 7) return undefined;
    if (seen.has(v)) return undefined; seen.add(v);
    if (v.isVector3 || v.isVector2 || v.isVector4) return v.toArray().map((x) => rnd(x));
    if (v.isEuler) return [rnd(v.x), rnd(v.y), rnd(v.z)];
    if (v.isColor) return col3(v);
    if (v.isObject3D) return v.name ? { object3d: v.name } : undefined;
    if (ArrayBuffer.isView(v)) return v.length <= 64 ? Array.from(v).map((x) => rnd(x)) : undefined;
    if (Array.isArray(v)) { const a = []; for (let i = 0; i < Math.min(v.length, 4000); i++) { const x = plain(v[i], depth + 1, seen); a.push(x === undefined ? null : x); } return a; }
    if (v instanceof Map) { const o = {}; for (const [k, x] of v) { const p = plain(x, depth + 1, seen); if (p !== undefined && typeof k !== 'object') o[k] = p; } return o; }
    const proto = Object.getPrototypeOf(v);
    if (proto !== Object.prototype && proto !== null) return undefined;
    const o = {}; for (const k of Object.keys(v)) { let x; try { x = plain(v[k], depth + 1, seen); } catch { x = undefined; } if (x !== undefined) o[k] = x; }
    return o;
  }

  // ------------------------------------------------------------------------------------------------ tone mapping ----
  const acesFit = (v) => (v * (v + 0.0245786) - 0.000090537) / (v * (0.983729 * v + 0.432951) + 0.238081);
  /** three.js's ACESFilmicToneMapping (linear in, display-referred linear out) */
  function aces(c, exposure) {
    const k = exposure / 0.6, x = c[0] * k, y = c[1] * k, z = c[2] * k;
    const r = acesFit(0.59719 * x + 0.35458 * y + 0.04823 * z), g = acesFit(0.076 * x + 0.90834 * y + 0.01566 * z), b = acesFit(0.0284 * x + 0.13383 * y + 0.83777 * z);
    return [1.60475 * r - 0.53108 * g - 0.07367 * b, -0.10208 * r + 1.10813 * g - 0.00605 * b, -0.00327 * r - 0.07276 * g + 1.07602 * b];
  }
  /** the value that comes out of the tone mapper as `target`: three.js draws fog, clear colours and toneMapped:false materials straight in display space, Godot tone maps everything */
  function untonemap(target, tm, exposure) {
    const t = target.map((x) => Math.min(0.995, Math.max(0, x)));
    if (tm === 'none') return t;
    if (tm === 'linear') return t.map((x) => x / exposure);
    if (tm === 'reinhard') return t.map((x) => x / (1 - x) / exposure);
    if (tm !== 'aces') return t;
    const x = t.map((c) => c + 0.01);
    for (let it = 0; it < 200; it++) {
      const f = aces(x, exposure);
      for (let i = 0; i < 3; i++) { const ratio = Math.max(1e-4, t[i] + 1e-4) / Math.max(1e-4, f[i] + 1e-4); x[i] = Math.min(32, Math.max(0, x[i] * Math.pow(ratio, 0.6))); }
    }
    return x;
  }

  // ------------------------------------------------------------------------------------------------ watching the level ----
  const matState = (x) => {
    const c = x.color, e = x.emissive, m = x.map, em = x.emissiveMap;
    return [c ? c.r : 0, c ? c.g : 0, c ? c.b : 0, e ? e.r : 0, e ? e.g : 0, e ? e.b : 0, x.emissiveIntensity ?? 0, x.opacity ?? 1, x.visible ? 1 : 0, m ? m.id : -1, m ? m.version : -1, m ? m.offset.x : 0, m ? m.offset.y : 0, em ? em.version : -1];
  };
  const MAT_FIELDS = ['color', 'color', 'color', 'emissive', 'emissive', 'emissive', 'emissive', 'opacity', 'visible', 'map', 'map', 'scroll', 'scroll', 'emissiveMap'];
  const solidState = (s) => [s.cx, s.cz, s.yaw, s.hx, s.hz, s.top, s.bottom, s.kind === 'ramp' ? s.topLow : 0, s.off ? 1 : 0];
  const matsOf = (o) => (Array.isArray(o.material) ? o.material : o.material ? [o.material] : []);
  const isAutoMerge = (o) => o.name === 'auto-merge';

  /** Records what changes over `ms` of real play. objs: Object3D -> { M, vis, moved, visCh, ... }; mats: material -> { st, changed:Set }; solids: Solid -> { st, moves } */
  async function sample(root, world, ms, step = 100, S0 = null) {
    const S = S0 || { objs: new Map(), mats: new Map(), solids: new Map(), ticks: 0 };
    const near = (a, b, eps) => { for (let i = 0; i < a.length; i++) if (Math.abs(a[i] - b[i]) > eps) return false; return true; };
    const look = (o, first) => {
      let r = S.objs.get(o);
      if (!r) {
        r = { M: Float64Array.from(o.matrix.elements), vis: o.visible, moved: false, visCh: false, late: !first, gv: -1, gCh: false, iv: -1, iCh: false, liv: 0, licol: 0, lCh: false, cnt: o.count ?? 0 };
        if (o.geometry && o.geometry.attributes && o.geometry.attributes.position) r.gv = o.geometry.attributes.position.version + (o.geometry.index ? o.geometry.index.version * 4096 : 0);
        if (o.isInstancedMesh) r.iv = o.instanceMatrix.version + (o.instanceColor ? o.instanceColor.version * 4096 : 0);
        if (o.isLight) { r.liv = o.intensity; r.licol = o.color.getHex(); }
        r.first = !!first; S.objs.set(o, r);
        return;
      }
      if (!r.moved && !near(o.matrix.elements, r.M, 1e-5)) r.moved = true;
      if (o.visible !== r.vis) r.visCh = true;
      if (r.gv >= 0 && o.geometry && o.geometry.attributes.position && r.gv !== o.geometry.attributes.position.version + (o.geometry.index ? o.geometry.index.version * 4096 : 0)) r.gCh = true;
      if (o.isInstancedMesh && (r.iv !== o.instanceMatrix.version + (o.instanceColor ? o.instanceColor.version * 4096 : 0) || o.count !== r.cnt)) r.iCh = true;
      if (o.isLight && (Math.abs(o.intensity - r.liv) > 1e-4 || o.color.getHex() !== r.licol)) r.lCh = true;
    };
    const lookMat = (x) => {
      let r = S.mats.get(x); const st = matState(x);
      if (!r) { S.mats.set(x, { st, changed: new Set() }); return; }
      for (let i = 0; i < st.length; i++) if (Math.abs(st[i] - r.st[i]) > 1e-5) r.changed.add(MAT_FIELDS[i]);
    };
    const tick = (first) => {
      const visit = (o) => { if (isAutoMerge(o)) return; look(o, first); for (const m of matsOf(o)) if (m && m.isMaterial) lookMat(m); for (const c of o.children) visit(c); };
      visit(root);
      for (const list of [world.solids, world.camSolids]) if (list) for (const s of list) {
        let r = S.solids.get(s); const st = solidState(s);
        if (!r) { S.solids.set(s, { st, moves: false }); continue; }
        if (!r.moves && !near(st, r.st, 1e-4)) r.moves = true;
      }
      S.ticks++;
    };
    tick(!S0);
    const t0 = performance.now();
    while (performance.now() - t0 < ms) { await new Promise((ok) => setTimeout(ok, step)); tick(false); }
    return S;
  }

  /** After a tour of the level's stages: everything that changed goes back to how it first looked, so the export is the level as it starts */
  function restoreInitial(root, S) {
    for (const [o, r] of S.objs) {
      if (r.moved) { o.matrixAutoUpdate = false; o.matrix.fromArray(r.M); o.matrixWorldNeedsUpdate = true; }
      if (r.visCh) o.visible = r.vis;
      if (o.isLight && r.lCh) { o.intensity = r.liv; o.color.setHex(r.licol); }
    }
    for (const [x, r] of S.mats) {
      if (!r.changed.size) continue;
      const st = r.st;
      if (x.color) x.color.setRGB(st[0], st[1], st[2], THREE.LinearSRGBColorSpace);
      if (x.emissive) x.emissive.setRGB(st[3], st[4], st[5], THREE.LinearSRGBColorSpace);
      if (x.emissiveIntensity !== undefined) x.emissiveIntensity = st[6];
      x.opacity = st[7]; x.visible = !!st[8];
    }
    for (const [s, r] of S.solids) {
      if (!r.moves) continue;
      const q = r.st; s.place(q[0], q[1], q[2], q[3], q[4]); s.top = q[5]; s.bottom = q[6]; if (s.kind === 'ramp') s.topLow = q[7]; s.off = !!q[8];
      s.maxTop = Math.max(s.top, s.kind === 'ramp' ? s.topLow : s.top);
    }
    root.updateMatrixWorld(true);
  }

  // ------------------------------------------------------------------------------------------------ one export run ----
  class Build {
    constructor(opt) {
      Object.assign(this, { opt, images: new Map(), srcCache: new Map(), mats: new Map(), keys: new Map(), buckets: new Map(), nodes: [], instances: [], lights: [], matTex: new WeakMap(), warnings: new Map(),
        work: new Map(), fields: [], fieldBuf: [], fieldOff: 0, fieldSeen: new Set(), shared: new Map(), nameCount: new Map(), S: opt.S || null, tm: opt.tm || 'none', exposure: opt.exposure || 1, flatCache: new Map(), floats: new Map(), dynamic: [], counts: { meshes: 0, pieces: 0, hiddenMeshes: 0, skippedMat: 0, tris: 0, verts: 0, split: 0 }, texBytes: 0, instBuf: [], instOff: 0 });
    }
    warn(w) { this.warnings.set(w, (this.warnings.get(w) || 0) + 1); }

    // -------------------------------- textures --------------------------------
    /** the texture's pixels as an ImageData (max side opt.maxTex, sides multiples of 4, because BC compression needs that), or null */
    pixels(tex, size) {
      const im = tex.image;
      if (!im || Array.isArray(im) || tex.isCompressedTexture || tex.isRenderTargetTexture || tex.isDepthTexture) return null;
      const W = im.naturalWidth || im.videoWidth || im.width, H = im.naturalHeight || im.videoHeight || im.height;
      if (!W || !H) return null;
      const k = Math.min(1, (size || this.opt.maxTex || 2048) / Math.max(W, H));
      const w = Math.max(4, Math.round(W * k / 4) * 4), h = Math.max(4, Math.round(H * k / 4) * 4);
      const cv = document.createElement('canvas'); cv.width = w; cv.height = h;
      const cx = cv.getContext('2d', { willReadFrequently: true });
      if (im.data) {
        const raw = im.data, n = W * H, id = new ImageData(W, H), d = id.data;
        const stride = raw.length >= n * 4 ? 4 : raw.length >= n * 3 ? 3 : raw.length >= n * 2 ? 2 : 1;
        const scale = (raw instanceof Float32Array || raw instanceof Float64Array) ? 255 : raw instanceof Uint16Array ? 255 / 65535 : 1;
        if (tex.type === THREE.HalfFloatType) { this.warn('half float DataTexture'); return null; }
        for (let i = 0; i < n; i++) { const s = i * stride; d[i * 4] = raw[s] * scale; d[i * 4 + 1] = (stride > 1 ? raw[s + 1] : raw[s]) * scale; d[i * 4 + 2] = (stride > 2 ? raw[s + 2] : raw[s]) * scale; d[i * 4 + 3] = stride > 3 ? raw[s + 3] * scale : 255; }
        const t = document.createElement('canvas'); t.width = W; t.height = H; t.getContext('2d').putImageData(id, 0, 0);
        cx.drawImage(t, 0, 0, w, h);
      } else {
        try { cx.drawImage(im, 0, 0, w, h); } catch (e) { this.warn('undrawable image: ' + e.message); return null; }
      }
      return { cv, cx, w, h, id: cx.getImageData(0, 0, w, h) };
    }

    /** a texture as a file in _tex, deduped by content. purpose: color (decoded as sRGB by Godot) | data | normal. alphaTex: an alphaMap put into the alpha channel */
    async texEntry(tex, purpose, needAlpha, alphaTex) {
      if (!tex) return null;
      if (Array.isArray(tex.image) || !tex.image) { this.warn('texture without a flat image: ' + (tex.name || tex.type)); return null; }
      const flags = purpose + (needAlpha ? 'A' : '') + (tex.colorSpace === THREE.SRGBColorSpace ? 's' : 'r') + (alphaTex ? alphaTex.uuid : '') + ':' + (tex.version || 0);
      let per = this.srcCache.get(tex.image); if (!per) this.srcCache.set(tex.image, per = new Map());
      if (per.has(flags)) return per.get(flags);
      const px = this.pixels(tex);
      if (!px) { per.set(flags, null); return null; }
      const d = px.id.data;
      if (alphaTex) { const a = this.pixels(alphaTex, Math.max(px.w, px.h)); if (a && a.w === px.w && a.h === px.h) for (let i = 3; i < d.length; i += 4) d[i] = a.id.data[i - 2]; }
      if (!needAlpha) for (let i = 3; i < d.length; i += 4) d[i] = 255;
      // three.js reads a map without SRGBColorSpace as linear numbers; Godot decodes every albedo / emission map as sRGB, so such a map is stored encoded
      if (purpose === 'color' && tex.colorSpace !== THREE.SRGBColorSpace) { const lut = new Uint8Array(256); for (let i = 0; i < 256; i++) lut[i] = Math.round(linToS(i / 255) * 255); for (let i = 0; i < d.length; i += 4) { d[i] = lut[d[i]]; d[i + 1] = lut[d[i + 1]]; d[i + 2] = lut[d[i + 2]]; } }
      let alpha = false; if (needAlpha) for (let i = 3; i < d.length; i += 4) if (d[i] < 250) { alpha = true; break; }
      const hash = hashBytes(d) + '_' + px.w + 'x' + px.h;
      let entry = this.images.get(hash);
      if (!entry) {
        px.cx.putImageData(px.id, 0, 0);
        const ext = alpha ? 'webp' : 'jpg', blob = await blobOf(px.cv, alpha ? 'image/webp' : 'image/jpeg', alpha ? 0.95 : 0.92), file = hash + '.' + ext;
        await put(this.opt.texDir + '/' + file, blob);
        this.texBytes += blob.size;
        entry = { file, w: px.w, h: px.h, alpha, purpose };
        this.images.set(hash, entry);
      }
      per.set(flags, entry);
      return entry;
    }
    texRef(entry, tex) { return entry ? { entry, wrapS: tex.wrapS, wrapT: tex.wrapT, mag: tex.magFilter, min: tex.minFilter } : null; }

    // -------------------------------- materials --------------------------------
    /** what a three.js material means for the export: everything the bake and the Godot material need, cached per material */
    async describe(m) {
      let d = this.mats.get(m); if (d) return d;
      const shader = !!(m.isShaderMaterial || m.isRawShaderMaterial), st = this.S && this.S.mats.get(m), changed = st ? st.changed : new Set();
      const unlit = !shader && (m.isMeshBasicMaterial || m.isLineBasicMaterial || m.isPointsMaterial || m.isSpriteMaterial);
      const lambert = !!m.isMeshLambertMaterial, phong = !!m.isMeshPhongMaterial, toon = !!m.isMeshToonMaterial;
      d = { m, name: m.name || '', kind: shader ? 'shader' : unlit ? 'unlit' : 'lit', color: m.color ? [m.color.r, m.color.g, m.color.b] : [1, 1, 1], opacity: m.opacity ?? 1, rough: 1, metal: 0, spec: 0.5, emis: [0, 0, 0],
        side: m.side === THREE.BackSide ? 'back' : m.side === THREE.DoubleSide ? 'double' : 'front', blend: 'mix', depthWrite: m.depthWrite !== false, depthTest: m.depthTest !== false, fog: m.fog !== false, toneMapped: m.toneMapped !== false,
        polyOff: m.polygonOffset ? Math.max(Math.abs(m.polygonOffsetFactor || 0), Math.abs(m.polygonOffsetUnits || 0)) : 0, flat: !!m.flatShading, vc: !!m.vertexColors, dyn: changed.size > 0 || !!m.matcap || !!(m.userData && m.userData.expDyn), dynWhy: [...changed], obc: '', shaderName: '', mapRef: null, normalRef: null, emisRef: null, aoRef: null, rmRef: null, uvTex: null, wire: !!m.wireframe, size: m.size || 0, normalScale: m.normalScale ? m.normalScale.x : 1 };
      this.mats.set(m, d);
      if (m.blending === THREE.AdditiveBlending || (m.blending === THREE.CustomBlending && m.blendDst === THREE.OneFactor)) d.blend = 'add';
      else if (m.blending === THREE.SubtractiveBlending) d.blend = 'sub';
      else if (m.blending === THREE.MultiplyBlending) d.blend = 'mul';
      else if (m.blending === THREE.CustomBlending) this.warn('custom blending treated as mix');
      if (!shader) {
        if (m.roughness !== undefined) d.rough = m.roughness;
        else if (phong) d.rough = Math.sqrt(2 / ((m.shininess ?? 30) + 2));
        if (m.metalness !== undefined) d.metal = m.metalness;
        if (lambert || toon) d.spec = 0;
        else if (phong) d.spec = Math.min(1, m.specular ? 0.2126 * m.specular.r + 0.7152 * m.specular.g + 0.0722 * m.specular.b : 0.07) * 2;
        if (m.emissive) { const k = m.emissiveIntensity ?? 1; d.emis = [m.emissive.r * k, m.emissive.g * k, m.emissive.b * k]; }
      }
      // onBeforeCompile: the source goes on the work list; the material itself exports as what it is underneath
      if (!shader && m.onBeforeCompile !== MP.onBeforeCompile) {
        const src = m.onBeforeCompile.toString(), h = hashStr(src).slice(0, 10), nm = 'obc_' + (safeName(m.name) || h) + '_' + h.slice(0, 4);
        d.obc = nm;
        if (!this.work.has(nm)) this.work.set(nm, { name: nm, type: 'onBeforeCompile', source: src, base: m.type, cacheKey: m.customProgramCacheKey !== MP.customProgramCacheKey ? String(m.customProgramCacheKey()) : '', defines: plain(m.defines), userData: plain(m.userData), uses: 0, nodes: [] });
        // The source above still reads fill.toFixed(2) written out: what this material really gets (its fill strength, its detail texture) only exists once the hook has run. Run it on a stand-in and keep the result as a variant.
        const w = this.work.get(nm), held = m.userData.shader, sh = { uniforms: {}, vertexShader: OBC_V, fragmentShader: OBC_F };
        try { m.onBeforeCompile(sh, {}); } catch (e) { this.warn('onBeforeCompile on a stand-in: ' + e.message); }
        if (held === undefined) delete m.userData.shader; else m.userData.shader = held;
        const uni = {};
        for (const [k, u] of Object.entries(sh.uniforms)) {
          const v = u && u.value;
          if (v && v.isTexture) { const e = v.image && !Array.isArray(v.image) ? await this.texEntry(v, v.colorSpace === THREE.SRGBColorSpace ? 'color' : 'data', false) : null; uni[k] = { type: 't', file: e ? this.opt.texDir + '/' + e.file : null, srgb: v.colorSpace === THREE.SRGBColorSpace }; }
          else if (typeof v === 'number') uni[k] = { type: 'f', value: rnd(v, 6) };
          else if (v && v.isColor) uni[k] = { type: 'c', value: col3(v) };
          else { const q = plain(v); if (q !== undefined) uni[k] = { type: 'v', value: q }; }
        }
        const vk = sh.vertexShader + '//FRAG' + sh.fragmentShader + JSON.stringify(uni);
        w.variant_keys = w.variant_keys || []; w.variants = w.variants || [];
        let vi = w.variant_keys.indexOf(vk);
        if (vi < 0) { vi = w.variant_keys.length; w.variant_keys.push(vk); w.variants.push({ vertex: sh.vertexShader, fragment: sh.fragmentShader, uniforms: uni }); }
        d.obcVar = vi;
      }
      const needAlpha = m.transparent || m.alphaTest > 0 || !!m.alphaHash;
      if (shader) await this.describeShader(m, d, needAlpha);
      else {
        const mapTex = m.map || m.alphaMap || null;
        if (mapTex) {
          const entry = m.map ? await this.texEntry(m.map, 'color', needAlpha, m.alphaMap || null) : await this.whiteWithAlpha(m.alphaMap);
          d.mapRef = this.texRef(entry, mapTex); if (entry) d.uvTex = mapTex;
        }
        if (m.emissiveMap) { d.emisRef = this.texRef(await this.texEntry(m.emissiveMap, 'color', false), m.emissiveMap); d.uvTex = d.uvTex || m.emissiveMap; }
        if (m.normalMap) { d.normalRef = this.texRef(await this.texEntry(m.normalMap, 'normal', false), m.normalMap); d.uvTex = d.uvTex || m.normalMap; }
        if (m.aoMap) { d.aoRef = this.texRef(await this.texEntry(m.aoMap, 'data', false), m.aoMap); d.aoChan = m.aoMap.channel || 0; d.aoI = m.aoMapIntensity ?? 1; d.uvTex = d.uvTex || m.aoMap; }
        if (m.roughnessMap || m.metalnessMap) {
          const t = m.roughnessMap || m.metalnessMap;
          const entry = m.roughnessMap && m.metalnessMap && m.roughnessMap !== m.metalnessMap ? await this.packRM(m.roughnessMap, m.metalnessMap) : (m.roughnessMap && !m.metalnessMap && d.metal > 0) || (!m.roughnessMap && m.metalnessMap) ? await this.packRM(m.roughnessMap, m.metalnessMap) : await this.texEntry(t, 'data', false);
          d.rmRef = this.texRef(entry, t); d.uvTex = d.uvTex || t;
          if (m.metalnessMap && !(m.metalness > 0)) d.metal = 0;
        }
        if (m.lightMap) this.warn('lightMap dropped (' + (m.name || m.type) + ')');
        if (m.bumpMap) this.warn('bumpMap dropped (' + (m.name || m.type) + ')');
        if (m.envMap) this.warn('envMap dropped (' + (m.name || m.type) + ')');
        if (m.displacementMap) this.warn('displacementMap dropped');
        if (m.isMeshPhysicalMaterial && (m.transmission > 0 || m.clearcoat > 0)) this.warn('physical extras dropped (transmission / clearcoat)');
      }
      // alpha mode: a "transparent" material that shows nothing through and never fades draws as opaque
      const mapAlpha = !!(d.mapRef && d.mapRef.entry && d.mapRef.entry.alpha);
      if (m.alphaTest > 0) { d.alpha = 'MASK'; d.cutoff = m.alphaTest; }
      else if (m.alphaHash) { d.alpha = 'MASK'; d.cutoff = 0.5; }
      else if (m.transparent && (d.opacity < 0.995 || mapAlpha || d.blend !== 'mix' || changed.has('opacity') || m.depthWrite === false || shader)) d.alpha = 'BLEND';
      else d.alpha = 'OPAQUE';
      if (m.transparent && d.alpha === 'OPAQUE' && m.vertexColors) d.alphaVC = true;
      // three.js skips the tone mapper for this one; Godot cannot, so the colour is moved to where the tone mapper brings it back
      if (!d.toneMapped || shader) { d.color = untonemap(d.color, this.tm, this.exposure); d.emis = d.emis.map((x, i) => (x > 0 ? untonemap([x, x, x], this.tm, this.exposure)[i] : 0)); }
      d.fold = !shader && !d.dyn && !d.wire && d.toneMapped && Math.max(...d.color) <= 1;
      const q = (v, s) => Math.round(v / s) * s;
      const samp = (r) => (r ? r.entry.file + ':' + r.wrapS + ':' + r.wrapT + ':' + r.mag + ':' + r.min : '');
      const uvm = d.uvTex ? (d.uvTex.updateMatrix(), Array.from(d.uvTex.matrix.elements).map((x) => rnd(x, 4)).join(',')) + (d.uvTex.flipY ? 'f' : '') + (d.uvTex.channel || 0) : '';
      d.key = [d.kind, samp(d.mapRef), samp(d.normalRef), d.normalRef ? rnd(d.normalScale, 2) : '', samp(d.emisRef), samp(d.aoRef), d.aoRef ? rnd(d.aoI, 2) + ':' + d.aoChan : '', samp(d.rmRef), q(d.rough, 0.05).toFixed(2), q(d.metal, 0.05).toFixed(2), q(d.spec, 0.05).toFixed(2),
        d.emis.map((x) => x.toFixed(3)).join(','), d.alpha, d.cutoff ?? '', q(d.opacity, 0.01).toFixed(2), d.side === 'double' ? 'D' : 'F', d.blend, d.depthWrite, d.depthTest, d.fog, d.toneMapped, d.obc, d.obcVar ?? '', d.shaderName, d.shaderVar ?? '', d.dyn ? m.uuid : '', d.fold ? '' : d.color.map((x) => x.toFixed(3)).join(','), d.wire, m.isPointsMaterial ? 'P' + d.size : '', m.isSpriteMaterial ? 'S' : ''].join('|');
      return d;
    }

    /** a ShaderMaterial: source + uniforms go on the work list; the placeholder is unlit, in the colour its uniforms suggest, with its first readable texture */
    async describeShader(m, d, needAlpha) {
      const src = (m.vertexShader || '') + '\n//FRAG\n' + (m.fragmentShader || ''), h = hashStr(src).slice(0, 10), nm = (safeName(m.name) || (m.type === 'RawShaderMaterial' ? 'raw' : 'shader')) + '_' + h.slice(0, 6);
      d.shaderName = nm;
      const uni = {}; let col = null, tex = null, op = null;
      for (const [k, u] of Object.entries(m.uniforms || {})) {
        const v = u && u.value;
        if (v && v.isTexture) { uni[k] = { type: 't', file: null, name: v.name || '', srgb: v.colorSpace === THREE.SRGBColorSpace }; if (!tex && v.image && !Array.isArray(v.image)) tex = { k, v }; const e = v.image && !Array.isArray(v.image) ? await this.texEntry(v, v.colorSpace === THREE.SRGBColorSpace ? 'color' : 'data', true) : null; if (e) uni[k].file = this.opt.texDir + '/' + e.file; }
        else if (v && v.isColor) { uni[k] = { type: 'c', value: col3(v) }; if (!col || /color|col|tint|base|glow|lava|water/i.test(k)) col = [v.r, v.g, v.b]; }
        else if (typeof v === 'number') { uni[k] = { type: 'f', value: rnd(v, 6) }; if (/^(u?opacity|alpha)$/i.test(k)) op = v; }
        else { const p = plain(v); uni[k] = { type: 'v', value: p === undefined ? null : p }; }
      }
      // One shader source can serve many materials with different values (the city's road, pavement, yard and plaza): each set of values is a variant, and the material says which one it is. Clocks and fog do not make a variant.
      const varKey = JSON.stringify(Object.fromEntries(Object.entries(uni).filter(([k]) => !/^(uTime|time|fogDensity|fogNear|fogFar|fogColor)$/.test(k))));
      let w = this.work.get(nm);
      const addVariant = (e) => { let i = e.variant_keys.indexOf(varKey); if (i < 0) { i = e.variant_keys.length; e.variant_keys.push(varKey); e.variants.push(uni); } d.shaderVar = i; };
      if (w) addVariant(w);
      if (!w) { w = { name: nm, type: m.type, vertexShader: m.vertexShader, fragmentShader: m.fragmentShader, uniforms: uni, variants: [], variant_keys: [], defines: plain(m.defines), transparent: !!m.transparent, side: d.side, blend: d.blend, depthWrite: d.depthWrite, depthTest: d.depthTest, mergeSafe: !!m.userData.mergeSafe, userData: plain(m.userData), attributes: [], uses: 0, nodes: [] }; addVariant(w); this.work.set(nm, w); }
      if (col) d.color = col; else d.color = [0.5, 0.5, 0.5];
      if (op !== null) d.opacity = op;
      if (tex) { const e = await this.texEntry(tex.v, tex.v.colorSpace === THREE.SRGBColorSpace ? 'color' : 'data', needAlpha); d.mapRef = this.texRef(e, tex.v); if (e) { d.uvTex = tex.v; d.color = [1, 1, 1]; } }
    }

    /** glTF's metallic-roughness texture from separate maps: G = roughness, B = metalness, as three.js reads them */
    async packRM(rTex, mTex) {
      const base = rTex || mTex, a = this.pixels(base); if (!a) return null;
      const b = rTex && mTex ? this.pixels(mTex, Math.max(a.w, a.h)) : null, d = a.id.data;
      for (let i = 0; i < d.length; i += 4) { const g = rTex ? d[i + 1] : 255, bl = mTex ? (b && b.w === a.w && b.h === a.h ? b.id.data[i + 2] : (rTex ? 255 : d[i + 2])) : 255; d[i] = 0; d[i + 1] = g; d[i + 2] = bl; d[i + 3] = 255; }
      const hash = hashBytes(d) + '_' + a.w + 'x' + a.h; let entry = this.images.get(hash);
      if (!entry) { a.cx.putImageData(a.id, 0, 0); const blob = await blobOf(a.cv, 'image/jpeg', 0.92), file = hash + '.jpg'; await put(this.opt.texDir + '/' + file, blob); this.texBytes += blob.size; entry = { file, w: a.w, h: a.h, alpha: false, purpose: 'data' }; this.images.set(hash, entry); }
      return entry;
    }
    /** an alphaMap without a map: white with the map's green channel as alpha */
    async whiteWithAlpha(aTex) {
      const a = this.pixels(aTex); if (!a) return null;
      const d = a.id.data; for (let i = 0; i < d.length; i += 4) { d[i + 3] = d[i + 1]; d[i] = d[i + 1] = d[i + 2] = 255; }
      const hash = hashBytes(d) + '_' + a.w + 'x' + a.h; let entry = this.images.get(hash);
      if (!entry) { a.cx.putImageData(a.id, 0, 0); const blob = await blobOf(a.cv, 'image/webp', 0.95), file = hash + '.webp'; await put(this.opt.texDir + '/' + file, blob); this.texBytes += blob.size; entry = { file, w: a.w, h: a.h, alpha: true, purpose: 'color' }; this.images.set(hash, entry); }
      return entry;
    }

    // -------------------------------- plan: which objects become nodes, which get merged --------------------------------
    newNode(o, parent, name, opt = {}) {
      const n = { idx: this.nodes.length, o, parent, name: name ?? o.name ?? '', world: (o ? o.matrixWorld : new THREE.Matrix4()).clone(), inv: null, hidden: !!opt.hidden, moved: !!opt.moved, why: opt.why || [], children: [], pieces: 0, extras: opt.extras || {}, kind: opt.kind || '' };
      n.inv = n.world.clone().invert(); this.nodes.push(n); if (parent) parent.children.push(n);
      return n;
    }

    /** the one node all the still pieces of this name (and parent, and hidden state) go into */
    sharedNode(en, name, hidden, why) {
      const k = en.idx + '#' + name + '#' + (hidden ? 'h' : 'v'); let n = this.shared.get(k);
      if (!n) { n = this.newNode(null, en, name, { hidden, moved: en.moved, why: why.concat(['shared']) }); n.world = en.world.clone(); n.inv = en.inv.clone(); this.shared.set(k, n); }
      return n;
    }

    /** walk the subtree under `o` into nodes, buckets, instances and lights */
    async walk(o, en, shown, top = false) {
      const opt = this.opt;
      if (isAutoMerge(o) || (opt.skipName && opt.skipName.test(o.name))) return;
      const r = this.S ? this.S.objs.get(o) : null;
      const named = !top && o.name && !(opt.ignoreName && opt.ignoreName.test(o.name));
      let cur = en, hiddenHere = !o.visible;
      const why = [];
      if (!top) {
        const dyn = !!(r && (r.moved || r.visCh || r.gCh));
        if (r && r.moved) why.push('moved');
        if (r && r.visCh) why.push('toggles');
        if (r && r.gCh) why.push('geometry');
        if (hiddenHere) why.push('hidden');
        if (named) why.push('named');
        if (o.isSkinnedMesh) why.push('skinned');
        if (o.isSprite) why.push('sprite');
        if (o.isPoints) why.push('points');
        if (opt.keep && opt.keep(o)) why.push('keep');
        // Still, and not worth a node of its own: pieces that share a name (hundreds of "static fitting"s), a hidden thing with no name to find it by, a static instanced mesh.
        // They share one node per name, parent and hidden state, so level logic can still find and switch them by name, but they merge.
        const plain0 = !dyn && !o.isSkinnedMesh && !o.isSprite && !o.isPoints && !(opt.keep && opt.keep(o));
        const many = named && (this.nameCount.get(o.name) || 0) > (opt.namedLimit ?? 6);
        if (plain0 && o.isInstancedMesh && !hiddenHere) { why.length = 0; }
        else if (plain0 && (many || (hiddenHere && !named))) {
          cur = this.sharedNode(en, named ? o.name : '', hiddenHere, why);
          why.length = 0;
        }
        if (why.length) {
          cur = this.newNode(o, en, o.name || '', { hidden: hiddenHere, moved: !!(r && (r.moved || r.gCh)) || en.moved, why, kind: o.isSkinnedMesh ? 'skinned' : o.isSprite ? 'sprite' : o.isPoints ? 'points' : '' });
          if (why.some((w) => w === 'moved' || w === 'toggles' || w === 'geometry')) this.dynamic.push({ name: o.name || '', type: o.type, why: why.slice(), pos: arr3(new THREE.Vector3().setFromMatrixPosition(o.matrixWorld)), parent: en.name || '' });
        }
      }
      const vis = shown && o.visible;
      if (o.isInstancedMesh) await this.addInstanced(o, cur, vis, r);
      else if (o.isMesh) await this.addMesh(o, cur, vis);
      else if (o.isLineSegments || o.isLine) await this.addLine(o, cur, vis);
      else if (o.isPoints) await this.addSingle(o, cur, vis, 'points');
      else if (o.isSprite) await this.addSprite(o, cur, vis);
      else if (o.isLight) this.addLight(o, cur, vis, r);
      for (const c of o.children) await this.walk(c, cur, vis);
    }

    async addMesh(o, en, vis) {
      let g = o.geometry;
      if (!g || !g.attributes || !g.attributes.position) return;
      if (o.isSkinnedMesh) g = this.bakeSkin(o);
      const pos = g.attributes.position, total = g.index ? g.index.count : pos.count, dr = g.drawRange;
      const rangeS = Math.max(0, dr.start || 0), rangeE = Math.min(total, dr.count === Infinity ? total : rangeS + dr.count);
      const list = Array.isArray(o.material) && g.groups.length ? g.groups.map((gr) => [o.material[gr.materialIndex], Math.max(rangeS, gr.start), Math.min(rangeE, gr.start + gr.count)]) : [[Array.isArray(o.material) ? o.material[0] : o.material, rangeS, rangeE]];
      this.counts.meshes++; if (!vis) this.counts.hiddenMeshes++;
      for (const [m, start, end] of list) {
        if (!m || !m.isMaterial || end <= start) continue;
        if (m.visible === false || m.colorWrite === false) { this.counts.skippedMat++; continue; }
        await this.addPiece(o, g, m, start, end - start, en, 'tri');
      }
    }

    async addLine(o, en, vis) {
      const g = o.geometry; if (!g || !g.attributes.position) return;
      const m = Array.isArray(o.material) ? o.material[0] : o.material; if (!m || m.visible === false) return;
      const total = g.index ? g.index.count : g.attributes.position.count;
      await this.addPiece(o, g, m, 0, total, en, o.isLineSegments ? 'lines' : o.isLineLoop ? 'loop' : 'strip');
    }
    async addSingle(o, en, vis, mode) {
      const g = o.geometry; if (!g || !g.attributes.position) return;
      const m = Array.isArray(o.material) ? o.material[0] : o.material; if (!m) return;
      await this.addPiece(o, g, m, 0, g.index ? g.index.count : g.attributes.position.count, en, mode);
    }
    async addSprite(o, en, vis) {
      const m = o.material; if (!m) return;
      const sx = new THREE.Vector3().setFromMatrixColumn(o.matrixWorld, 0).length(), sy = new THREE.Vector3().setFromMatrixColumn(o.matrixWorld, 1).length(), cx = o.center ? o.center.x : 0.5, cy = o.center ? o.center.y : 0.5;
      const g = new THREE.BufferGeometry();
      g.setAttribute('position', new THREE.BufferAttribute(new Float32Array([-cx * sx, -cy * sy, 0, (1 - cx) * sx, -cy * sy, 0, (1 - cx) * sx, (1 - cy) * sy, 0, -cx * sx, (1 - cy) * sy, 0]), 3));
      g.setAttribute('normal', new THREE.BufferAttribute(new Float32Array([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]), 3));
      g.setAttribute('uv', new THREE.BufferAttribute(new Float32Array([0, 0, 1, 0, 1, 1, 0, 1]), 2));
      g.setIndex([0, 1, 2, 0, 2, 3]);
      await this.addPiece(o, g, m, 0, 6, en, 'tri', { sprite: true });
    }

    /** a skinned mesh as it stands right now: its posed vertices in a plain geometry */
    bakeSkin(o) {
      const src = o.geometry, g = new THREE.BufferGeometry(), n = src.attributes.position.count, p = new Float32Array(n * 3), v = new THREE.Vector3();
      for (let i = 0; i < n; i++) { o.getVertexPosition(i, v); p[i * 3] = v.x; p[i * 3 + 1] = v.y; p[i * 3 + 2] = v.z; }
      g.setAttribute('position', new THREE.BufferAttribute(p, 3));
      for (const k of ['uv', 'uv1', 'color']) if (src.attributes[k]) g.setAttribute(k, src.attributes[k]);
      if (src.index) g.setIndex(src.index);
      for (const gr of src.groups) g.addGroup(gr.start, gr.count, gr.materialIndex);
      g.computeVertexNormals();
      return g;
    }

    /** A shader driven by its own per-point data (sprite fields, wet reflections, beacons, smoke) cannot go through glTF: the arrays go to shader_fields.bin, and the level's hand-ported shader draws them. */
    recordField(o, g, d, mode, en) {
      const names = Object.keys(g.attributes);
      if (!names.some((k) => !['position', 'normal', 'uv', 'uv1', 'color'].includes(k)) || this.fieldSeen.has(o)) return;
      this.fieldSeen.add(o);
      const attrs = {};
      for (const k of names) {
        const a = g.attributes[k], f = Float32Array.from(this.floatsOf(a));
        attrs[k] = { size: a.itemSize, off: this.fieldOff, count: a.count, instanced: !!a.isInstancedBufferAttribute };
        this.fieldBuf.push(f); this.fieldOff += f.byteLength;
      }
      this.fields.push({ name: o.name || '', parent: en.name || '', shader: d.shaderName, shader_var: d.shaderVar ?? 0, mode, world: o.matrixWorld.toArray(), attrs, index: g.index ? Array.from(g.index.array) : null, instance_count: g.instanceCount === Infinity ? null : (g.instanceCount ?? null), order: o.renderOrder || 0, hidden: !o.visible });
    }

    async addPiece(o, g, m, start, count, en, mode, extra = {}) {
      const d = await this.describe(m);
      if (d.wire && mode === 'tri') this.warn('wireframe mesh exported solid');
      this.counts.pieces++;
      const isShader = d.kind === 'shader';
      if (isShader && o.isObject3D) this.recordField(o, g, d, mode, en);
      const castShadow = !!o.castShadow, receive = !!o.receiveShadow;
      const order = d.alpha === 'BLEND' ? (o.renderOrder || 0) : 0;
      const key = d.key + '|' + (castShadow ? 'c' : '') + (receive ? 'r' : '') + '|' + order + '|' + mode + (extra.sprite ? '|sprite' : '');
      let info = this.keys.get(key);
      if (!info) { info = { key, idx: this.keys.size, d, cast: castShadow, receive, order, mode, sprite: !!extra.sprite, colors: new Set(), anyVC: false, nodes: 0 }; this.keys.set(key, info); }
      if (d.obc || isShader) { const w = this.work.get(d.obc || d.shaderName); w.uses++; if (w.nodes.length < 16) w.nodes.push(o.name || en.name || ''); if (isShader) for (const k of Object.keys(g.attributes)) if (!['position', 'normal', 'uv', 'uv1', 'color'].includes(k) && !w.attributes.includes(k)) w.attributes.push(k); }
      const hasVC = d.vc && !!g.attributes.color;
      if (hasVC || (isShader && g.attributes.color)) info.anyVC = true;
      info.colors.add(d.color.map((x) => x.toFixed(4)).join(','));
      const toNode = new THREE.Matrix4().multiplyMatrices(en.inv, o.matrixWorld);
      const base = { o, g, m, d, start, count, M: toNode, mode, hasVC: hasVC || (isShader && !!g.attributes.color) };
      en.pieces++;
      // a still piece of geometry lands in a cell; a big baked batch is cut into cells by triangle, so culling keeps working
      const cell = this.opt.cell || 64, splitOK = !en.moved && mode === 'tri' && !extra.sprite && !o.isSkinnedMesh;
      if (!g.boundingSphere) g.computeBoundingSphere();
      const sph = g.boundingSphere, c = new THREE.Vector3().copy(sph.center).applyMatrix4(o.matrixWorld), rad = sph.radius * o.matrixWorld.getMaxScaleOnAxis();
      if (splitOK && rad > cell * 0.75 && count > 3000) { this.splitPiece(base, en, info, Math.max(cell, rad / 4)); return; }   // (at most a few dozen parts: an asteroid field or a starfield is kilometres across)
      const ck = en.moved || mode !== 'tri' ? '' : Math.floor(c.x / cell) + ':' + Math.floor(c.z / cell);
      this.bucket(en, info, ck).push(base);
    }
    bucket(en, info, ck) {
      const k = en.idx + '#' + info.idx + '#' + ck; let b = this.buckets.get(k);
      if (!b) { b = { en, info, ck, pieces: [] }; this.buckets.set(k, b); }
      return b.pieces;
    }
    splitPiece(base, en, info, cell) {
      const g = base.g, ix = g.index ? g.index.array : null, P = this.floatsOf(g.attributes.position), W = base.o.matrixWorld.elements, cells = new Map();
      for (let i = base.start; i + 2 < base.start + base.count; i += 3) {
        const a = ix ? ix[i] : i, b = ix ? ix[i + 1] : i + 1, c = ix ? ix[i + 2] : i + 2;
        const lx = (P[a * 3] + P[b * 3] + P[c * 3]) / 3, ly = (P[a * 3 + 1] + P[b * 3 + 1] + P[c * 3 + 1]) / 3, lz = (P[a * 3 + 2] + P[b * 3 + 2] + P[c * 3 + 2]) / 3;
        const x = W[0] * lx + W[4] * ly + W[8] * lz + W[12], z = W[2] * lx + W[6] * ly + W[10] * lz + W[14];
        const k = Math.floor(x / cell) + ':' + Math.floor(z / cell); let list = cells.get(k); if (!list) cells.set(k, list = []);
        list.push(a, b, c);
      }
      for (const [k, list] of cells) this.bucket(en, info, k).push({ ...base, tris: Uint32Array.from(list), count: list.length });
      this.counts.split++;
    }

    /** an attribute as plain floats (shared when it already is) */
    floatsOf(attr) {
      let f = this.floats.get(attr); if (f) return f;
      if (!attr.isInterleavedBufferAttribute && attr.array instanceof Float32Array && !attr.normalized) f = attr.array;
      else { const n = attr.count, w = attr.itemSize; f = new Float32Array(n * w); const get = [attr.getX, attr.getY, attr.getZ, attr.getW]; for (let i = 0; i < n; i++) for (let c = 0; c < w; c++) f[i * w + c] = get[c].call(attr, i); }
      this.floats.set(attr, f); return f;
    }

    // -------------------------------- bake --------------------------------
    /** the merged BufferGeometry of a bucket's pieces, in the space of its node */
    bake(pieces, info, foldColor) {
      const d0 = info.d, mode = info.mode, tris = mode === 'tri';
      const flesh = !d0.uvTex && pieces.some((q) => q.g.attributes.aFlesh);      // the Spire's flesh attribute (vein, swell, wetness) goes out as uv = (wet, 0), uv1 = (vein, swell): glTF has no slot for it
      const omni = !d0.uvTex && pieces.some((q) => q.g.attributes.aWear);      // OMNISPHERE's paint (levels/omnisphere/paint.js) reads aStyle, aWear, aTint, aGlow: uv = aGlow.rg, uv1 = (aGlow.b, aStyle + aWear * .99), color = aTint, its alpha = the baked AO
      const wantUV = !!d0.uvTex || flesh || omni, wantUV1 = !!(d0.aoRef && d0.aoChan === 1) || flesh || omni, lit = d0.kind === 'lit';
      const wantCol = foldColor || omni || pieces.some((p) => p.hasVC);
      // vertex / index counts
      let nv = 0, ni = 0; const plans = [];
      for (const p of pieces) {
        const g = p.g, ix = p.tris || (g.index ? g.index.array : null), nAll = g.attributes.position.count, flat = tris && (p.d.flat || !g.attributes.normal) && lit;
        const s = p.tris ? 0 : p.start, n = p.tris ? p.tris.length : p.count;
        let use = n; if (mode === 'strip' || mode === 'loop') use = (n - 1 + (mode === 'loop' ? 1 : 0)) * 2;
        if (flat) { plans.push({ p, ix, s, n, flat: true, nv: n, map: null }); nv += n; ni += n; continue; }
        const whole = !ix ? (s === 0 && n === nAll) : (s === 0 && n === ix.length && !p.tris && n >= nAll);
        if (whole && !p.tris && mode !== 'strip' && mode !== 'loop') { plans.push({ p, ix, s, n, flat: false, nv: nAll, map: null }); nv += nAll; ni += n; continue; }
        const map = new Int32Array(nAll).fill(-1); let k = 0;
        for (let i = s; i < s + n; i++) { const v = ix ? ix[i] : i; if (map[v] < 0) map[v] = k++; }
        plans.push({ p, ix, s, n, flat: false, nv: k, map }); nv += k; ni += use;
      }
      const pos = new Float32Array(nv * 3), nor = new Float32Array(nv * 3), uv = wantUV ? new Float32Array(nv * 2) : null, uv1 = wantUV1 ? new Float32Array(nv * 2) : null, col = wantCol ? new Uint8Array(nv * 4) : null, idx = new Uint32Array(ni);
      let vo = 0, io = 0;
      const N3 = new THREE.Matrix3();
      for (const pl of plans) {
        const { p, ix, s, n, flat, map } = pl, g = p.g, d = p.d, A = g.attributes;
        const e = p.M.elements, mirror = p.M.determinant() < 0, back = d.side === 'back';
        N3.getNormalMatrix(p.M); const ne = N3.elements;
        const P = this.floatsOf(A.position), Nn = A.normal && !flat ? this.floatsOf(A.normal) : null;
        const tex = d0.uvTex, uvName = tex && (tex.channel || 0) === 1 ? 'uv1' : 'uv';
        const U = wantUV && !flesh && A[uvName] ? this.floatsOf(A[uvName]) : null, U1 = wantUV1 && !flesh && A.uv1 ? this.floatsOf(A.uv1) : null, FL = flesh && A.aFlesh ? this.floatsOf(A.aFlesh) : null;
        const C = (d.vc || d.kind === 'shader') && A.color ? this.floatsOf(A.color) : null, cw = C ? A.color.itemSize : 0;
        // per texture uv transform and the flip (see the header): pieces of a bucket share the texture, so its transform is one and the same
        const texP = d.uvTex; let um = null; const flip = texP ? !!texP.flipY : false;
        if (texP) { texP.updateMatrix(); const q = texP.matrix.elements; if (!(q[0] === 1 && q[4] === 1 && q[6] === 0 && q[7] === 0 && q[1] === 0 && q[3] === 0)) um = q; }
        const cr = foldColor ? d.color[0] : 1, cg = foldColor ? d.color[1] : 1, cb = foldColor ? d.color[2] : 1;
        const sr = Math.round(linToS(cr) * 255), sg = Math.round(linToS(cg) * 255), sb = Math.round(linToS(cb) * 255);
        const offs = d.polyOff ? Math.min(4, d.polyOff) * 0.0025 : 0;
        const writeVert = (src, w) => {
          const px = P[src * 3], py = P[src * 3 + 1], pz = P[src * 3 + 2];
          let x = e[0] * px + e[4] * py + e[8] * pz + e[12], y = e[1] * px + e[5] * py + e[9] * pz + e[13], z = e[2] * px + e[6] * py + e[10] * pz + e[14];
          if (Nn) {
            const nx = Nn[src * 3], ny = Nn[src * 3 + 1], nz = Nn[src * 3 + 2]; let ox = ne[0] * nx + ne[3] * ny + ne[6] * nz, oy = ne[1] * nx + ne[4] * ny + ne[7] * nz, oz = ne[2] * nx + ne[5] * ny + ne[8] * nz;
            const L = Math.hypot(ox, oy, oz) || 1; ox /= L; oy /= L; oz /= L;
            if (back) { ox = -ox; oy = -oy; oz = -oz; }
            nor[w * 3] = ox; nor[w * 3 + 1] = oy; nor[w * 3 + 2] = oz;
            if (offs) { x += ox * offs; y += oy * offs; z += oz * offs; }
          } else if (!flat) nor[w * 3 + 1] = 1;
          pos[w * 3] = x; pos[w * 3 + 1] = y; pos[w * 3 + 2] = z;
          if (uv) {
            let u = U ? U[src * 2] : 0, v = U ? U[src * 2 + 1] : 0;
            if (um) { const a = um[0] * u + um[3] * v + um[6], b = um[1] * u + um[4] * v + um[7]; u = a; v = b; }
            uv[w * 2] = u; uv[w * 2 + 1] = flip ? 1 - v : v;
            if (FL) { uv[w * 2] = FL[src * 3 + 2]; uv[w * 2 + 1] = 0; }
          }
          if (uv1) { uv1[w * 2] = U1 ? U1[src * 2] : 0; uv1[w * 2 + 1] = U1 ? (flip ? 1 - U1[src * 2 + 1] : U1[src * 2 + 1]) : 0; if (FL) { uv1[w * 2] = FL[src * 3]; uv1[w * 2 + 1] = FL[src * 3 + 1]; } }
          if (col) {
            if (C) {
              col[w * 4] = Math.round(linToS(cr * C[src * cw]) * 255); col[w * 4 + 1] = Math.round(linToS(cg * C[src * cw + 1]) * 255); col[w * 4 + 2] = Math.round(linToS(cb * C[src * cw + 2]) * 255);
              col[w * 4 + 3] = cw === 4 ? Math.round(Math.min(1, Math.max(0, C[src * cw + 3])) * 255) : 255;
            } else { col[w * 4] = sr; col[w * 4 + 1] = sg; col[w * 4 + 2] = sb; col[w * 4 + 3] = 255; }
          }
          if (omni) {
            const AG = A.aGlow, AT = A.aTint, AS = A.aStyle, AW = A.aWear;
            uv[w * 2] = AG ? AG.getX(src) : 0; uv[w * 2 + 1] = AG ? AG.getY(src) : 0;
            uv1[w * 2] = AG ? AG.getZ(src) : 0; uv1[w * 2 + 1] = (AS ? AS.getX(src) : 0) + Math.min(1, Math.max(0, AW ? AW.getX(src) : 0)) * .99;
            col[w * 4] = Math.round((AT ? AT.getX(src) : 1) * 255); col[w * 4 + 1] = Math.round((AT ? AT.getY(src) : 1) * 255); col[w * 4 + 2] = Math.round((AT ? AT.getZ(src) : 1) * 255);
            col[w * 4 + 3] = Math.round((A.color ? Math.min(1, A.color.getX(src)) : 1) * 255);
          }
        };
        if (flat) {
          for (let i = 0; i < n; i += 3) {
            const a = ix ? ix[s + i] : s + i, b = ix ? ix[s + i + 1] : s + i + 1, c = ix ? ix[s + i + 2] : s + i + 2, w = vo + i;
            writeVert(a, w); writeVert(b, w + 1); writeVert(c, w + 2);
            const ax = pos[w * 3], ay = pos[w * 3 + 1], az = pos[w * 3 + 2], ux = pos[w * 3 + 3] - ax, uy = pos[w * 3 + 4] - ay, uz = pos[w * 3 + 5] - az, vx = pos[w * 3 + 6] - ax, vy = pos[w * 3 + 7] - ay, vz = pos[w * 3 + 8] - az;
            let fx = uy * vz - uz * vy, fy = uz * vx - ux * vz, fz = ux * vy - uy * vx; const L = Math.hypot(fx, fy, fz) || 1; fx /= L; fy /= L; fz /= L;
            if (mirror) { fx = -fx; fy = -fy; fz = -fz; } if (back) { fx = -fx; fy = -fy; fz = -fz; }
            for (let t = 0; t < 3; t++) { nor[(w + t) * 3] = fx; nor[(w + t) * 3 + 1] = fy; nor[(w + t) * 3 + 2] = fz; }
            if (mirror !== back) { idx[io++] = w; idx[io++] = w + 2; idx[io++] = w + 1; } else { idx[io++] = w; idx[io++] = w + 1; idx[io++] = w + 2; }
          }
          vo += n;
          continue;
        }
        if (map) { for (let v = 0; v < map.length; v++) if (map[v] >= 0) writeVert(v, vo + map[v]); }
        else for (let v = 0; v < pl.nv; v++) writeVert(v, vo + v);
        const at = (i) => { const v = ix ? ix[i] : i; return (map ? map[v] : v) + vo; };
        if (tris) { const flipW = mirror !== back; for (let i = s; i + 2 < s + n; i += 3) { const a = at(i), b = at(i + 1), c = at(i + 2); idx[io++] = a; if (flipW) { idx[io++] = c; idx[io++] = b; } else { idx[io++] = b; idx[io++] = c; } } }
        else if (mode === 'lines' || mode === 'points') for (let i = s; i < s + n; i++) idx[io++] = at(i);
        else { for (let i = s; i + 1 < s + n; i++) { idx[io++] = at(i); idx[io++] = at(i + 1); } if (mode === 'loop') { idx[io++] = at(s + n - 1); idx[io++] = at(s); } }
        vo += pl.nv;
      }
      const geo = new THREE.BufferGeometry();
      geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
      if (tris) geo.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
      if (uv) geo.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
      if (uv1) geo.setAttribute('uv1', new THREE.BufferAttribute(uv1, 2));
      if (col) geo.setAttribute('color', new THREE.BufferAttribute(col, 4, true));
      geo.setIndex(new THREE.BufferAttribute(idx.subarray(0, io), 1));
      this.counts.tris += io / (tris ? 3 : 2); this.counts.verts += nv;
      return geo;
    }

    /** the glTF material of a material family (one per key: the buckets of all cells share it) */
    exportMaterial(info) {
      if (info.mat) return info.mat;
      const d = info.d, unlit = d.kind !== 'lit' || info.mode !== 'tri';
      const one = info.colors.size === 1 && !info.anyVC;
      info.fold = d.fold && !one;
      const c = info.fold ? [1, 1, 1] : d.color;
      const M = unlit ? new THREE.MeshBasicMaterial() : new THREE.MeshStandardMaterial();
      M.name = (d.kind === 'shader' ? 'shader_' + d.shaderName : d.obc ? d.obc : safeName(d.name) || d.m.type.replace('Mesh', '').replace('Material', '').toLowerCase()) + '_' + info.idx;
      M.color.setRGB(c[0], c[1], c[2], THREE.LinearSRGBColorSpace);
      M.opacity = d.opacity; M.side = d.side === 'double' ? THREE.DoubleSide : THREE.FrontSide; M.fog = d.fog;
      if (d.alpha === 'BLEND') M.transparent = true; else if (d.alpha === 'MASK') M.alphaTest = d.cutoff;
      if (!unlit) {
        M.roughness = Math.round(d.rough * 20) / 20; M.metalness = Math.round(d.metal * 20) / 20;
        const em = Math.max(...d.emis);
        if (em > 0 || d.emisRef) { if (em > 1) { M.emissive.setRGB(d.emis[0] / em, d.emis[1] / em, d.emis[2] / em, THREE.LinearSRGBColorSpace); M.emissiveIntensity = em; } else { M.emissive.setRGB(d.emis[0], d.emis[1], d.emis[2], THREE.LinearSRGBColorSpace); M.emissiveIntensity = 1; } }
      }
      // what glTF has no field for: tools/export/glb_post_import.gd applies these at import
      const x = { srgb_vc: 1 };
      if (d.spec !== 0.5 && !unlit) x.spec = d.spec;
      if (d.blend !== 'mix') x.blend = d.blend;
      if (d.alpha === 'BLEND' && d.depthWrite) x.depth_write = 1;
      if (!d.depthTest) x.no_depth_test = 1;
      if (!d.fog) x.no_fog = 1;
      if (!info.receive && !unlit) x.no_receive = 1;
      if (info.order) x.priority = Math.max(-128, Math.min(127, info.order));
      if (info.sprite) x.billboard = 1;
      if (info.mode === 'points') x.point_size = d.size || 1;
      if (d.obc) { x.obc = d.obc; x.obc_var = d.obcVar ?? 0; }
      if (d.kind === 'shader') { x.shader = d.shaderName; x.shader_var = d.shaderVar ?? 0; }
      if (d.dyn) { x.dyn = 1; x.dyn_why = d.dynWhy; x.js_name = d.name; }
      if (!d.toneMapped) x.not_tone_mapped = 1;
      if (info.useVC) x.use_vc = 1;
      if (d.polyOff) x.poly_off = 1;
      M.userData = x;
      const t = { map: d.mapRef, normal: d.normalRef, normalScale: d.normalScale, emis: d.emisRef, rm: d.rmRef, ao: d.aoRef, aoChan: d.aoChan || 0, aoI: d.aoI ?? 1 };
      if (unlit) { t.normal = t.emis = t.rm = t.ao = null; }
      this.matTex.set(M, t);
      info.mat = M;
      return M;
    }

    // -------------------------------- instances --------------------------------
    async addInstanced(o, en, vis, r) {
      const n = o.count, g = o.geometry; if (!n || !g || !g.attributes.position) return;
      const mats = Array.isArray(o.material) && g.groups.length ? g.groups.map((gr) => [o.material[gr.materialIndex], gr.start, gr.count]) : [[Array.isArray(o.material) ? o.material[0] : o.material, 0, g.index ? g.index.count : g.attributes.position.count]];
      const moves = !!(r && (r.iCh || r.moved)) || en.moved, toNode = new THREE.Matrix4().multiplyMatrices(en.inv, o.matrixWorld), M = new THREE.Matrix4(), W = new THREE.Matrix4(), e = W.elements;
      const hasCol = !!o.instanceColor, cell = (this.opt.cellInst || 128), stride = hasCol ? 16 : 12;
      this.counts.meshes++; if (!vis) this.counts.hiddenMeshes++;
      // a few still instances of something small cost less merged with the rest of their material than as a draw of their own
      const triCount = (g.index ? g.index.count : g.attributes.position.count) / 3;
      if (!moves && !hasCol && n * triCount <= 30000 && n <= 512) {
        for (let i = 0; i < n; i++) {
          o.getMatrixAt(i, M); W.multiplyMatrices(o.matrixWorld, M);
          if (W.elements[0] ** 2 + W.elements[1] ** 2 + W.elements[2] ** 2 < 1e-10) continue;
          for (const [m, start, count] of mats) if (m && m.isMaterial && m.visible !== false) await this.addPiece({ matrixWorld: W.clone(), castShadow: o.castShadow, receiveShadow: o.receiveShadow, renderOrder: o.renderOrder, name: o.name }, g, m, start, count, en, 'tri');
        }
        return;
      }
      const cells = new Map();
      for (let i = 0; i < n; i++) {
        o.getMatrixAt(i, M); W.multiplyMatrices(toNode, M);
        const sx = e[0] * e[0] + e[1] * e[1] + e[2] * e[2], sy = e[4] * e[4] + e[5] * e[5] + e[6] * e[6], sz = e[8] * e[8] + e[9] * e[9] + e[10] * e[10];
        if (!moves && (sx < 1e-10 || sy < 1e-10 || sz < 1e-10)) continue;       // a pooled instance parked at scale 0
        const k = moves || n <= 32 ? '' : Math.floor(e[12] / cell) + ':' + Math.floor(e[14] / cell);
        let c = cells.get(k); if (!c) cells.set(k, c = []);
        c.push(e[0], e[4], e[8], e[12], e[1], e[5], e[9], e[13], e[2], e[6], e[10], e[14]);
        if (hasCol) { const ic = o.instanceColor.array, q = i * 3; c.push(linToS(ic[q]), linToS(ic[q + 1]), linToS(ic[q + 2]), 1); }
      }
      if (!cells.size) return;
      if (g.attributes.aCard && g.attributes.uv && !g.userData.cardBaked) { const u = g.attributes.uv, ac = g.attributes.aCard; for (let i = 0; i < u.count; i++) u.setX(i, (u.getX(i) + ac.getX(i)) * .25); g.userData.cardBaked = true; }      // (a card picked from an atlas in the vertex shader, VISITING HOURS' reeds: the pick goes into the UVs)
      for (const [m, start, count] of mats) {
        if (!m || !m.isMaterial || m.visible === false) continue;
        const d = await this.describe(m);
        if (d.obc || d.kind === 'shader') { const w = this.work.get(d.obc || d.shaderName); w.uses += n; if (w.nodes.length < 16) w.nodes.push(o.name || 'instanced'); if (d.kind === 'shader') for (const k of Object.keys(g.attributes)) if (!['position', 'normal', 'uv', 'uv1', 'color'].includes(k) && !w.attributes.includes(k)) w.attributes.push(k); }
        const info = { key: '', idx: this.keys.size + 100000 + this.instances.length, d, cast: !!o.castShadow, receive: !!o.receiveShadow, order: d.alpha === 'BLEND' ? (o.renderOrder || 0) : 0, mode: 'tri', sprite: false, colors: new Set([d.color.map((x) => x.toFixed(4)).join(',')]), anyVC: d.vc && !!g.attributes.color, useVC: hasCol, nodes: 0 };
        const piece = { o, g, m, d, start, count, M: new THREE.Matrix4(), mode: 'tri', hasVC: d.vc && !!g.attributes.color };
        const inst = { o, en, g, info, piece, name: o.name || '', moves, hidden: !o.visible, hasCol, entries: [] };      // (its own switch only: a parent that hides it is a node above it in Godot too)
        for (const [k, c] of cells) { const a = Float32Array.from(c); inst.entries.push({ cell: k, off: this.instOff, count: a.length / stride }); this.instBuf.push(a); this.instOff += a.byteLength; }
        this.instances.push(inst);
      }
      if (moves) this.dynamic.push({ name: o.name || '', type: 'InstancedMesh', why: ['instances move'], count: n, parent: en.name || '' });
    }

    // -------------------------------- lights --------------------------------
    addLight(o, en, vis, r) {
      const p = new THREE.Vector3().setFromMatrixPosition(o.matrixWorld);
      const j = { type: o.isPointLight ? 'point' : o.isSpotLight ? 'spot' : o.isDirectionalLight ? 'dir' : o.isHemisphereLight ? 'hemi' : o.isAmbientLight ? 'ambient' : o.isRectAreaLight ? 'rect' : o.type, name: o.name || '', color: col3(o.color), hex: o.color.getHexString(), intensity: rnd(o.intensity), pos: arr3(p), hidden: !vis, cast: !!o.castShadow };
      if (o.isPointLight || o.isSpotLight) { j.distance = rnd(o.distance); j.decay = rnd(o.decay); }
      if (o.isSpotLight || o.isDirectionalLight) { const t = new THREE.Vector3().setFromMatrixPosition(o.target.matrixWorld); j.target = arr3(t); }
      if (o.isSpotLight) { j.angle = rnd(o.angle); j.penumbra = rnd(o.penumbra); }
      if (o.isHemisphereLight) j.ground = col3(o.groundColor);
      if (o.castShadow && o.shadow) j.shadow = { bias: rnd(o.shadow.bias), normal_bias: rnd(o.shadow.normalBias), size: o.shadow.mapSize.x };
      const moved = r && r.moved, ch = r && r.lCh;
      if (moved || ch || r?.visCh || en.moved) { j.dyn = { moved: !!(moved || en.moved), flicker: !!ch, toggles: !!r?.visCh }; if (en.moved) j.parent = en.name || ''; }
      this.lights.push(j);
    }

    // -------------------------------- the GLB --------------------------------
    /** builds the export scene from the plan and writes the GLB */
    async writeGLB(rel) {
      const scene = new THREE.Scene(); scene.name = this.opt.sceneName || 'level';
      const nodeName = (n) => (n.parent ? 'n' + n.idx + (n.name ? '_' + safeName(n.name) : (n.kind ? '_' + n.kind : '')) : 'world');
      // drop kept nodes that hold nothing and are not named (a hidden empty group)
      const prune = (n) => { n.children = n.children.filter((c) => { prune(c); return c.pieces > 0 || c.children.length > 0 || c.name || this.instances.some((i) => i.en === c); }); };
      prune(this.nodes[0]);
      const build = (n, parentObj, parentNode) => {
        const g = new THREE.Group(); g.name = nodeName(n);
        const local = parentNode ? new THREE.Matrix4().multiplyMatrices(parentNode.inv, n.world) : n.world.clone();
        g.matrix.copy(local); g.matrixAutoUpdate = false;
        const x = {}; if (n.name) x.js_name = n.name; if (n.hidden) x.hidden = 1; if (n.moved) x.moved = 1; if (n.why.length) x.why = n.why; if (n.kind) x.kind = n.kind;
        g.userData = x;
        n.obj = g; parentObj.add(g);
        for (const c of n.children) build(c, g, n);
      };
      build(this.nodes[0], scene, null);
      let bakedN = 0; const list = [...this.buckets.values()];
      for (const b of list) {
        const info = b.info, mat = this.exportMaterial(info), geo = this.bake(b.pieces, info, info.fold);
        const mesh = info.mode === 'tri' ? new THREE.Mesh(geo, mat) : info.mode === 'points' ? new THREE.Points(geo, mat) : new THREE.LineSegments(geo, mat);
        mesh.name = 'm' + info.idx + (b.ck ? '_' + b.ck.replace(':', '_').replace(/-/g, 'm') : '') + '_n' + b.en.idx;
        const x = {}; if (!info.cast) x.no_cast = 1; if (info.d.kind === 'shader') x.shader = info.d.shaderName; if (info.d.obc) x.obc = info.d.obc; mesh.userData = x;
        if (!b.en.obj) continue;
        b.en.obj.add(mesh); bakedN++; b.pieces = null;
        if (bakedN % 64 === 0) await nextFrame();
      }
      // instancing templates
      const instRoot = new THREE.Group(); instRoot.name = 'instancing_templates'; instRoot.userData = { kind: 'templates', hidden: 1 }; scene.add(instRoot);
      const entries = [];
      for (let k = 0; k < this.instances.length; k++) {
        const I = this.instances[k], info = I.info, mat = this.exportMaterial(info), geo = this.bake([I.piece], info, info.fold), mesh = new THREE.Mesh(geo, mat);
        mesh.name = 'i' + k + (I.name ? '_' + safeName(I.name) : '');
        mesh.userData = { kind: 'template', ...(info.cast ? {} : { no_cast: 1 }), ...(info.d.kind === 'shader' ? { shader: info.d.shaderName } : {}) };
        instRoot.add(mesh);
        for (const e of I.entries) entries.push({ tpl: mesh.name, off: e.off, count: e.count, colors: I.hasCol, parent: I.en.parent && I.en.obj ? I.en.obj.name : '', moves: I.moves, hidden: I.hidden, name: I.name });
      }
      this.instEntries = entries;
      const exporter = new GLTFExporter(), self = this;
      exporter.register((w) => new UriTextures(w, self));
      const buf = await exporter.parseAsync(scene, { binary: true, onlyVisible: false, trs: false, animations: [], includeCustomExtensions: false });
      await put(rel, new Blob([buf]));
      this.glbBytes = buf.byteLength;
      return buf.byteLength;
    }
    /** the node index of level.json: everything kept, by its JS name */
    nodeTable() {
      const out = []; for (const n of this.nodes) if (n.parent && n.obj) out.push({ node: n.obj.name, name: n.name, why: n.why, hidden: n.hidden, moved: n.moved, kind: n.kind });
      return out;
    }
    workList() { return [...this.work.values()]; }
    usedTextures() { return [...this.images.values()].map((e) => ({ file: e.file, purpose: e.purpose, alpha: e.alpha, w: e.w, h: e.h })); }
  }

  /** glTF textures that point at the files in _tex (GLTFExporter itself can only embed): one image per file, one sampler per wrap / filter set */
  class UriTextures {
    constructor(writer, build) { this.w = writer; this.b = build; this.name = 'PROG_uri_textures'; this.imgs = new Map(); this.sm = new Map(); this.tx = new Map(); }
    idx(ref) {
      const j = this.w.json; j.images = j.images || []; j.textures = j.textures || []; j.samplers = j.samplers || [];
      const file = ref.entry.file; let im = this.imgs.get(file);
      if (im === undefined) { im = j.images.length; j.images.push({ uri: this.b.opt.texUri + file, mimeType: file.endsWith('.jpg') ? 'image/jpeg' : 'image/webp', name: file.split('.')[0] }); this.imgs.set(file, im); }
      const GL = { [THREE.RepeatWrapping]: 10497, [THREE.ClampToEdgeWrapping]: 33071, [THREE.MirroredRepeatWrapping]: 33648, [THREE.NearestFilter]: 9728, [THREE.LinearFilter]: 9729, [THREE.NearestMipmapNearestFilter]: 9984, [THREE.LinearMipmapNearestFilter]: 9985, [THREE.NearestMipmapLinearFilter]: 9986, [THREE.LinearMipmapLinearFilter]: 9987 };
      const sk = [ref.wrapS, ref.wrapT, ref.mag, ref.min].join(); let s = this.sm.get(sk);
      if (s === undefined) { s = j.samplers.length; j.samplers.push({ magFilter: GL[ref.mag] || 9729, minFilter: GL[ref.min] || 9987, wrapS: GL[ref.wrapS] || 10497, wrapT: GL[ref.wrapT] || 10497 }); this.sm.set(sk, s); }
      const tk = im + ':' + s; let t = this.tx.get(tk);
      if (t === undefined) { t = j.textures.length; j.textures.push({ sampler: s, source: im }); this.tx.set(tk, t); }
      return t;
    }
    writeMaterial(mat, def) {
      const t = this.b.matTex.get(mat); if (!t) return;
      def.pbrMetallicRoughness = def.pbrMetallicRoughness || {};
      if (t.map) def.pbrMetallicRoughness.baseColorTexture = { index: this.idx(t.map), texCoord: 0 };
      if (t.rm) def.pbrMetallicRoughness.metallicRoughnessTexture = { index: this.idx(t.rm), texCoord: 0 };
      if (t.normal) def.normalTexture = { index: this.idx(t.normal), texCoord: 0, scale: t.normalScale };
      if (t.emis) def.emissiveTexture = { index: this.idx(t.emis), texCoord: 0 };
      if (t.ao) def.occlusionTexture = { index: this.idx(t.ao), texCoord: t.aoChan === 1 ? 1 : 0, strength: t.aoI };
    }
  }

  // ------------------------------------------------------------------------------------------------ colliders ----
  const solidJSON = (s, moves, fields) => {
    const d = { kind: s.kind, cx: rnd(s.cx), cz: rnd(s.cz), hx: rnd(s.hx), hz: rnd(s.hz), yaw: rnd(s.yaw, 6), bottom: rnd(s.bottom), top: rnd(s.top), tag: s.tag };
    if (s.kind === 'ramp') d.top_low = rnd(s.topLow);
    if (s.off) d.off = true;
    if (s.r) d.r = rnd(s.r);
    if (s.noCam) d.no_cam = true;
    if (s.holes && s.holes.length) d.holes = s.holes.map((h) => h.map((x) => rnd(x)));
    if (moves) d.moves = true;
    // JS leaves bottom at its default 0 under a surface below zero: only `top` matters there, and a Godot box needs bottom < top
    if (s.kind === 'box' && !(d.bottom < d.top)) { d.bottom = rnd(s.top - 0.02); d.bottom_was = rnd(s.bottom); }
    if (s.kind === 'field') {
      const r = s.r, cell = Math.min(2, Math.max(0.25, r / 96)), n = Math.ceil(r * 2 / cell) + 1, x0 = s.cx - r, z0 = s.cz - r, a = new Float32Array(n * n);
      for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) { const h = s.fn(x0 + i * cell, z0 + j * cell); a[i * n + j] = Number.isFinite(h) ? h : -1e4; }
      d.cell = cell; d.floor = s.floor ?? null; d.grid = { n, x0: rnd(x0), z0: rnd(z0), off: fields.bytes }; fields.parts.push(a); fields.bytes += a.byteLength;
    }
    // anything else the level hung on the solid that is plain data (ids, door names)
    for (const k of Object.keys(s)) if (!SOLID_KNOWN.has(k) && (typeof s[k] === 'string' || typeof s[k] === 'number' || typeof s[k] === 'boolean')) { (d.extra = d.extra || {})[k] = s[k]; }
    return d;
  };
  const SOLID_KNOWN = new Set(['kind', 'cx', 'cz', 'hx', 'hz', 'yaw', 'bottom', 'top', 'topLow', 'tag', 'off', 'r', 'holes', 'fn', 'floor', 'noCam', 'c', 's', 'R2', 'maxTop', '_gr', '_gw', '_gv', '_gs']);

  /** A solid with a topAt of its own (the Spire's bile basin is a sector of a disc): its footprint sampled into rows of boxes, since the World only knows the standard shapes */
  function topAtBoxes(s, moves) {
    const R = s.kind === 'disc' || s.kind === 'field' ? s.r : Math.hypot(s.hx, s.hz), cell = Math.min(0.5, Math.max(0.15, R / 64)), n = Math.ceil(2 * R / cell), x0 = s.cx - R, z0 = s.cz - R, out = [], off = s.off;
    s.off = false;
    for (let i = 0; i < n; i++) {
      const x = x0 + (i + 0.5) * cell; let start = -1, top = null;
      for (let j = 0; j <= n; j++) {
        const z = z0 + (j + 0.5) * cell, t = j < n ? s.topAt(x, z) : null;
        if (top !== null && (t === null || Math.abs(t - top) > 0.001)) {
          out.push({ kind: 'box', cx: rnd(x), cz: rnd(z0 + (start + j) * 0.5 * cell), hx: rnd(cell / 2), hz: rnd((j - start) * cell / 2), yaw: 0, bottom: rnd(Math.min(s.bottom, top - 0.02)), top: rnd(top), tag: s.tag, ...(off ? { off: true } : {}), ...(s.noCam ? { no_cam: true } : {}), ...(moves ? { moves: true } : {}) });
          top = null;
        }
        if (top === null && t !== null) { start = j; top = t; }
      }
    }
    s.off = off;
    return out;
  }

  /** colliders.json (and fields.bin / tris.bin) */
  async function writeColliders(dir, world, S) {
    const fields = { parts: [], bytes: 0 };
    const moves = (s) => !!(S && S.solids.get(s) && S.solids.get(s).moves);
    const each = (s) => (Object.prototype.hasOwnProperty.call(s, 'topAt') ? topAtBoxes(s, moves(s)) : [solidJSON(s, moves(s), fields)]);
    const out = { solids: ((window.__game && window.__game.level && window.__game.level.allSolids) || world.solids).flatMap(each),      /* (a level that culls world.solids per frame keeps them all in allSolids) */ cam_solids: (world.camSolids || []).flatMap(each), custom: !!world.customQueries };
    let tris = 0;
    const col = customCollision(world);
    if (col) {
      const n = col.length, a = new Float32Array(n * 9); let k = 0;
      for (const t of col) { for (const p of [t.a, t.b, t.c]) { a[k++] = p.x; a[k++] = p.y; a[k++] = p.z; } }
      await put(dir + '/tris.bin', new Blob([a]));
      out.tris = { file: 'tris.bin', count: n }; tris = n;
    }
    if (fields.bytes) { await put(dir + '/fields.bin', new Blob(fields.parts)); out.fields_file = 'fields.bin'; }
    await put(dir + '/colliders.json', JSON.stringify(out));
    return { solids: out.solids.length, cam: out.cam_solids.length, moving: out.solids.filter((s) => s.moves).length, tris, fields: fields.parts.length };
  }
  const customCollision = (world) => (world.__expTriangles ? world.__expTriangles() : (G.level && (G.level.collision || (G.level.scene && G.level.scene.collision)) ? (G.level.collision || G.level.scene.collision).triangles : null));

  // ------------------------------------------------------------------------------------------------ probes: the same questions to compare in Godot ----
  function writeProbes(world, n) {
    let seed = 0x13572468; const rand = () => { seed = (seed + 0x6D2B79F5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
    const live = world.solids.filter((s) => !s.off);
    let x0 = Infinity, x1 = -Infinity, z0 = Infinity, z1 = -Infinity, y0 = Infinity, y1 = -Infinity;
    for (const s of live) { const R = Math.sqrt(s.R2 || 1); x0 = Math.min(x0, s.cx - R); x1 = Math.max(x1, s.cx + R); z0 = Math.min(z0, s.cz - R); z1 = Math.max(z1, s.cz + R); y0 = Math.min(y0, s.bottom); y1 = Math.max(y1, s.maxTop ?? s.top); }
    const tris = customCollision(world);
    if (tris) for (const t of tris) for (const p of [t.a, t.b, t.c]) { x0 = Math.min(x0, p.x); x1 = Math.max(x1, p.x); z0 = Math.min(z0, p.z); z1 = Math.max(z1, p.z); y0 = Math.min(y0, p.y); y1 = Math.max(y1, p.y); }
    if (!Number.isFinite(x0)) return { n: 0, ground: [] };
    const r = 0.36, ground = [], other = [], spawnY = world.spawn ? world.spawn.y : 0;
    for (let i = 0; i < n; i++) {
      let x, z, maxY;
      const k = i % 4;
      if (k < 2 && live.length) {            // on a solid (the walkable bits), asked from above it or from just over its own top
        const s = live[Math.floor(rand() * live.length)], R = Math.max(0.2, Math.sqrt(s.R2 || 1)), a = rand() * Math.PI * 2, q = Math.sqrt(rand()) * R;
        x = s.cx + Math.cos(a) * q; z = s.cz + Math.sin(a) * q;
        maxY = k === 0 ? y1 + 1 : (s.maxTop ?? s.top) + 0.3;
      } else {                               // anywhere in the level's box, from the very top or a random height
        x = x0 + rand() * (x1 - x0); z = z0 + rand() * (z1 - z0);
        maxY = k === 2 ? y1 + 1 : y0 + rand() * (y1 - y0 + 1);
      }
      const h = world.groundHeight(x, z, r, maxY);
      ground.push([rnd(x, 4), rnd(z, 4), rnd(maxY, 4), Number.isFinite(h) ? rnd(h, 4) : null]);
      if (i % 2 === 0) {                     // the body and the ceiling at the same spot, a pace above that surface
        const feet = Number.isFinite(h) ? h : spawnY;
        let bl = false, ceil = null; try { bl = !!world.blocked(x, z, feet + 0.05, 1.1, r, 0.42); ceil = world.ceiling(x, z, r, feet + 1.0, feet + 3.0); } catch { /* a custom world without them */ }
        other.push([rnd(x, 4), rnd(z, 4), rnd(feet, 4), bl ? 1 : 0, ceil === null || ceil === undefined ? null : rnd(ceil, 4)]);
      }
    }
    return { n, r, bbox: [x0, x1, z0, z1, y0, y1].map((v) => rnd(v, 3)), ground, other };
  }

  // ------------------------------------------------------------------------------------------------ level data ----
  /** water: at(x, z) sampled into a grid (the harbour); ladders as they are */
  function waterJSON(world, bbox) {
    const w = world.water; if (!w) return null;
    const out = { level: typeof w.level === 'number' ? w.level : null, ladders: plain(w.ladders) ?? [] };
    if (typeof w.at === 'function' && bbox) {
      const step = 4, x0 = Math.floor(bbox[0] / step) * step, z0 = Math.floor(bbox[2] / step) * step, nx = Math.ceil((bbox[1] - x0) / step) + 1, nz = Math.ceil((bbox[3] - z0) / step) + 1, cells = [];
      for (let i = 0; i < nx; i++) for (let j = 0; j < nz; j++) { let h = null; try { h = w.at(x0 + i * step, z0 + j * step); } catch { h = null; } if (h !== null && h !== undefined && Number.isFinite(h)) cells.push(i * nz + j, rnd(h, 3)); }
      if (!cells.length) return out.level === null && !out.ladders.length ? null : out;
      out.grid = { step, x0, z0, nx, nz, cells };
    }
    return out;
  }
  /** cameraZoneWeight(p) sampled on the footprints (the rooms it marks), as sparse cells */
  function cameraZoneJSON(world, bbox) {
    const f = world.cameraZoneWeight; if (typeof f !== 'function' || !bbox) return null;
    const step = 1, x0 = Math.floor(bbox[0]), z0 = Math.floor(bbox[2]), nx = Math.ceil(bbox[1] - x0) + 1, nz = Math.ceil(bbox[3] - z0) + 1;
    if (nx * nz > 4e6) return { source: f.toString().slice(0, 2000), too_big: true };
    const cells = [], yProbe = [];
    for (let i = 0; i < nx; i += 1) for (let j = 0; j < nz; j += 1) {
      const x = x0 + i * step, z = z0 + j * step, g = world.groundHeight(x, z, 0.1, 1e6), y = Number.isFinite(g) ? g : 0;
      let w = 0; try { w = f({ x, y: y + 0.1, z }); } catch { w = 0; }
      if (w > 0) cells.push(i * nz + j, rnd(w, 3));
      if (!Number.isFinite(g)) continue;
    }
    return { source: f.toString().slice(0, 2000), grid: { step, x0, z0, nx, nz, cells } };
  }

  function lightOfView(v) {
    const hemi = v.hemi, sun = v.sun, sp = new THREE.Vector3().setFromMatrixPosition(sun.matrixWorld), st = new THREE.Vector3().setFromMatrixPosition(sun.target.matrixWorld), dir = sp.clone().sub(st);
    return { hemi: { color: col3(hemi.color), ground: col3(hemi.groundColor), intensity: rnd(hemi.intensity), visible: hemi.visible },
      sun: { color: col3(sun.color), intensity: rnd(sun.intensity), visible: sun.visible, cast: !!sun.castShadow, dir: arr3(dir.normalize()), far: rnd(sun.shadow.camera.far), bias: rnd(sun.shadow.bias), normal_bias: rnd(sun.shadow.normalBias) } };
  }

  async function backgroundJSON(build, sc, tm, exposure, dir) {
    const b = sc.background;
    if (!b) return { type: 'none' };
    if (b.isColor) return { type: 'color', color: col3(b), hex: b.getHexString(), pre_tonemap: untonemap([b.r, b.g, b.b], tm, exposure) };
    if (b.isTexture) {
      if (b.isCubeTexture || Array.isArray(b.image)) { build.warn('cube background'); return { type: 'cube', note: 'cube texture background not exported' }; }
      const e = await build.texEntry(b, 'color', false);
      return { type: 'texture', file: e ? e.file : null, mapping: b.mapping === THREE.EquirectangularReflectionMapping || b.mapping === THREE.EquirectangularRefractionMapping ? 'equirect' : 'screen', flip: !!b.flipY };
    }
    return { type: 'unknown' };
  }

  const rootOf = () => (G.levelHost ? G.levelHost.root : G.view.scene.children.find((o) => o.name === 'HUB'));

  // ------------------------------------------------------------------------------------------------ the city's life (levels/city_life.gd, levels/hub/*.gd) ----
  /** What CityView animates lives in closures and fields the scene does not show. Names go on it before the sample, so the parts stay findable in Godot by name. Materials: extras.js_name. */
  function nameCityParts(C) {
    if (!C) return;
    const moves = (m, nm) => { m.name = nm; m.userData.expDyn = true; };
    (C.flick || []).forEach((f, i) => moves(f.mt, 'CityFlick' + i));
    (C.blink || []).forEach((b, i) => moves(b.amb, 'CityBlink' + i));
    if (C.beacon) C.beacon.name = 'CityBeacon';
    if (C.clubSpill) C.clubSpill.spills.forEach((q, i) => { q.lamp.name = 'CitySpillLamp' + i; q.pavement.name = 'CitySpillPavement' + i; q.aperture.name = 'CitySpillAperture' + i; moves(q.pavement.material, 'CitySpillPavementMat' + i); moves(q.aperture.material, 'CitySpillApertureMat' + i); });
    if (C.armorV) { const v = C.armorV; moves(v.col.material, 'CityHoloColumnMat'); v.L.name = 'CityHoloLight'; v.holos.forEach((h, i) => { h.name = 'CityHolo' + i; if (h.userData.holo) { moves(h.userData.holo.hm, 'CityHoloHm' + i); moves(h.userData.holo.lm, 'CityHoloLm' + i); } }); }
    for (const sp of citySprites(C).keys()) if (sp.parent) sp.name = 'CityLifeSprite';     // the sprites the field below takes over (the ones JS spriteField did not already pull out of the scene)
    const D = C.district;
    if (D) {
      const lens = []; D.root.traverse((o) => { if (o.isPoints && o.material.isPointsMaterial && o.material.size === 1.5) lens.push(o); });
      lens.forEach((o) => { o.name = 'SignalLenses'; });
    }
  }
  /** sprite -> what CityView does to it, [kind, p0..p4, opacity]: 0 nothing, 1 neon (rate, ph, gate), 2 wall fixture (fail, ph), 3 dead signal, 4 steam puff (t, sp0, dx, y0, rise), 5 lamp head (bad, base) */
  function citySprites(C) {
    const r = new Map();
    for (const f of C.flick || []) if (f.sp) r.set(f.sp, [1, f.rate, f.ph, f.gate ?? -1, 0, 0, f.spBase]);
    for (const f of C.fixtures || []) r.set(f.sp, [2, f.fail ? 1 : 0, f.ph, 0, 0, 0, f.base]);
    for (const b of C.blink || []) r.set(b.sp, [3, 0, 0, 0, 0, 0, b.sp.material.opacity]);
    for (const q of C.puffs || []) r.set(q.sp, [4, q.t, q.sp0, q.dx, q.y0 === undefined ? 0.2 : q.y0, q.rise || 3.4, 0.34]);
    for (const l of C.lampLights || []) r.set(l.hs, [5, l.bad ? 1 : 0, l.base, 0, 0, 0, 0.9]);
    return r;
  }
  /** city_life.json: every sprite with its job, by texture and blending (one instanced draw each, animated in levels/shaders/city_sprites*.gdshader), and the numbers of what levels/city_life.gd drives */
  async function cityLifeJSON(C, b) {
    const roles = citySprites(C), all = new Set(roles.keys());
    if (C.spriteField) for (const F of C.spriteField.fields) for (const s of F.list) all.add(s);
    const sets = new Map(), v = new THREE.Vector3();
    for (const s of all) {
      const m = s.material; if (!m.map) continue;
      const key = m.map.uuid + '|' + m.blending;
      if (!sets.has(key)) { const e = await b.texEntry(m.map, 'color', true); sets.set(key, { tex: e ? b.opt.texDir + '/' + e.file : null, blend: m.blending === THREE.AdditiveBlending ? 'add' : 'mix', depth_test: m.depthTest !== false, fog: m.fog !== false, list: [] }); }
      const q = roles.get(s) || [0, 0, 0, 0, 0, 0, m.opacity];
      s.updateWorldMatrix(true, false); v.setFromMatrixPosition(s.matrixWorld);
      const sx = new THREE.Vector3().setFromMatrixColumn(s.matrixWorld, 0).length(), sy = new THREE.Vector3().setFromMatrixColumn(s.matrixWorld, 1).length();
      if (q[0] === 4) { const p = C.puffs.find((u) => u.sp === s); v.set(p.x, 0, p.z); }
      sets.get(key).list.push([q[0], rnd(v.x), rnd(v.y), rnd(v.z), rnd(sx), rnd(sy), rnd(m.color.r), rnd(m.color.g), rnd(m.color.b), rnd(q[6]), rnd(q[1]), rnd(q[2]), rnd(q[3]), rnd(q[4]), rnd(q[5])]);
    }
    const city = C.city || {};
    return { sprites: [...sets.values()], flick: (C.flick || []).map((f, i) => ({ name: 'CityFlick' + i, base: f.base, rate: rnd(f.rate), ph: rnd(f.ph), gate: f.gate ?? -1 })), blink: (C.blink || []).map((q, i) => ({ name: 'CityBlink' + i })),
      spill: C.clubSpill ? C.clubSpill.spills.map((q, i) => ({ strength: q.strength, phase: rnd(q.phase) })) : [], sw: city.SW ?? 0, club9_z: city.club9 ? city.club9.z : 0, holos: C.armorV ? C.armorV.holos.length : 0 };
  }

  /** a bone per Object3D of a talker, a surface per material: its parts in the talker's own space, as they stand now, weighted to their bones (read by levels/hub/npc_rig.gd) */
  async function rigJSON(root, b, bin, opt = {}) {
    // (writing a texture lets frames through, and the talker's idle runs on: every material is described first, so the pose below is one moment)
    { const seen = []; root.traverse((o) => { if (o.isMesh) for (const m of Array.isArray(o.material) ? o.material : [o.material]) if (m && m.isMaterial) seen.push(m); }); for (const m of seen) await b.describe(m); }
    root.updateWorldMatrix(true, true);
    const space = new THREE.Matrix4().copy((opt.space || root).matrixWorld).invert();
    if (opt.drop_scale) { const p = new THREE.Vector3(), q = new THREE.Quaternion(), sc = new THREE.Vector3(); opt.space.matrixWorld.decompose(p, q, sc); space.compose(p, q, new THREE.Vector3(1, 1, 1)).invert(); }
    const bones = [], index = new Map(), surfaces = new Map(), named = new Map(opt.named || []);
    const walk = (o, parent) => {
      if (o.isSkinnedMesh) { for (const c of o.children) walk(c, parent); return; }
      if (o.isSprite || o.isLight || o.isPoints || o.isLine) return;
      const i = bones.length; index.set(o, i);
      const here = o === opt.space;      // (the space itself: the model stands at its own origin, whatever spot the JS has it at)
      bones.push({ name: named.get(o) || o.name || '', parent, p: here ? [0, 0, 0] : [rnd(o.position.x, 6), rnd(o.position.y, 6), rnd(o.position.z, 6)], q: here ? [0, 0, 0, 1] : [rnd(o.quaternion.x, 6), rnd(o.quaternion.y, 6), rnd(o.quaternion.z, 6), rnd(o.quaternion.w, 6)], s: here && !opt.drop_scale ? [1, 1, 1] : [rnd(o.scale.x, 6), rnd(o.scale.y, 6), rnd(o.scale.z, 6)], hidden: !o.visible });
      for (const c of o.children) walk(c, i);
    };
    walk(root, -1);
    const M = new THREE.Matrix4(), N = new THREE.Matrix3(), P = new THREE.Vector3(), Q = new THREE.Vector3(), R3 = new THREE.Vector3();
    const addTris = async (g, m, posOf, norOf, boneOf) => {
      if (!m || !m.isMaterial || m.visible === false) return;
      let e = surfaces.get(m);
      if (!e) { const d = await b.describe(m); e = { d, m, pos: [], nor: [], uv: [], col: [], bi: [], bw: [] }; surfaces.set(m, e); }
      const idx = g.index, n = idx ? idx.count : g.attributes.position.count, U = g.attributes.uv, C = g.attributes.color, flat = !!m.flatShading, at = (k) => (idx ? idx.getX(k) : k);
      for (let t = 0; t + 2 < n; t += 3) {
        const a = at(t), bb = at(t + 1), c = at(t + 2), pa = posOf(a), pb = posOf(bb), pc = posOf(c);
        let fn = null;
        if (flat) { P.set(pb[0] - pa[0], pb[1] - pa[1], pb[2] - pa[2]); Q.set(pc[0] - pa[0], pc[1] - pa[1], pc[2] - pa[2]); R3.crossVectors(P, Q).normalize(); fn = [R3.x, R3.y, R3.z]; }
        for (const [vi, p] of [[a, pa], [c, pc], [bb, pb]]) {     // (Godot's front faces wind the other way round)
          e.pos.push(p[0], p[1], p[2]);
          const nn = fn || norOf(vi); e.nor.push(nn[0], nn[1], nn[2]);
          e.uv.push(U ? U.getX(vi) : 0, U ? U.getY(vi) : 0);
          if (C) e.col.push(C.getX(vi), C.getY(vi), C.getZ(vi)); else e.col.push(1, 1, 1);
          const w = boneOf(vi); e.bi.push(w[0], w[1], w[2], w[3]); e.bw.push(w[4], w[5], w[6], w[7]);
        }
      }
    };
    const meshes = []; root.traverse((o) => { if (o.isMesh && o.name !== 'rigid shadow') meshes.push(o); });
    for (const o of meshes) {
      if (o.layers.mask === 0) continue;      // (merged into a 'rigid parts' mesh: only its joint stays)
      const g = o.geometry; if (!g || !g.attributes.position) continue;
      const mats = Array.isArray(o.material) && g.groups.length ? o.material : [Array.isArray(o.material) ? o.material[0] : o.material];
      if (o.isSkinnedMesh) {
        const skel = o.skeleton, SI = g.attributes.skinIndex, SW = g.attributes.skinWeight, n = g.attributes.position.count, W = new THREE.Matrix4().multiplyMatrices(space, o.matrixWorld);
        skel.update();
        const pos = new Float32Array(n * 3); for (let i = 0; i < n; i++) { o.getVertexPosition(i, P); P.applyMatrix4(W); pos[i * 3] = P.x; pos[i * 3 + 1] = P.y; pos[i * 3 + 2] = P.z; }
        const tmp = new THREE.BufferGeometry(); tmp.setAttribute('position', new THREE.BufferAttribute(pos, 3)); if (g.index) tmp.setIndex(g.index);
        let nor;
        if (g.attributes.normal && !mats[0].flatShading) {     // the bone turns the normal as it turns the vertex
          const na = g.attributes.normal, out = new Float32Array(n * 3), sm = new THREE.Matrix4();
          for (let i = 0; i < n; i++) {
            const best = SW.getX(i) >= SW.getY(i) ? SI.getX(i) : SI.getY(i);
            sm.multiplyMatrices(skel.bones[best].matrixWorld, skel.boneInverses[best]).premultiply(space);
            N.getNormalMatrix(sm);
            P.fromBufferAttribute(na, i).applyMatrix3(N).normalize(); out[i * 3] = P.x; out[i * 3 + 1] = P.y; out[i * 3 + 2] = P.z;
          }
          nor = out;
        } else { tmp.computeVertexNormals(); nor = tmp.attributes.normal.array; }
        const boneMap = skel.bones.map((x) => { const k = index.get(x); return k === undefined ? 0 : k; });
        await addTris(g, mats[0], (i) => [pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2]], (i) => [nor[i * 3], nor[i * 3 + 1], nor[i * 3 + 2]], (i) => [boneMap[SI.getX(i)], boneMap[SI.getY(i)], boneMap[SI.getZ(i)], boneMap[SI.getW(i)], SW.getX(i), SW.getY(i), SW.getZ(i), SW.getW(i)]);
      } else {
        M.multiplyMatrices(space, o.matrixWorld); N.getNormalMatrix(M);
        const PA = g.attributes.position, NA = g.attributes.normal, self = index.get(o) ?? 0;
        const pf = (i) => { P.fromBufferAttribute(PA, i).applyMatrix4(M); return [P.x, P.y, P.z]; }, nf = (i) => { if (!NA) return [0, 1, 0]; P.fromBufferAttribute(NA, i).applyMatrix3(N).normalize(); return [P.x, P.y, P.z]; }, bf = () => [self, 0, 0, 0, 1, 0, 0, 0];
        if (Array.isArray(o.material) && g.groups.length) { for (const gr of g.groups) { const sub = new THREE.BufferGeometry(); for (const k of Object.keys(g.attributes)) sub.setAttribute(k, g.attributes[k]); const ia = []; for (let k = gr.start; k < gr.start + gr.count; k++) ia.push(g.index ? g.index.getX(k) : k); sub.setIndex(ia); await addTris(sub, o.material[gr.materialIndex], pf, nf, bf); } }
        else await addTris(g, mats[0], pf, nf, bf);
      }
    }
    const outS = [];
    for (const e of surfaces.values()) {
      const d = e.d, m = e.m, n = e.pos.length / 3, tex = d.mapRef ? b.opt.texDir + '/' + d.mapRef.entry.file : null;
      const put2 = (a, T) => { const t = T.from(a); bin.parts.push(t); const o = bin.bytes; bin.bytes += t.byteLength; return o; };
      outS.push({ n, pos: put2(e.pos, Float32Array), nor: put2(e.nor, Float32Array), uv: put2(e.uv, Float32Array), col: put2(e.col, Float32Array), bi: put2(e.bi, Int32Array), bw: put2(e.bw, Float32Array),
        kind: d.kind, color: col3(m.color || { r: 1, g: 1, b: 1 }), rough: rnd(d.rough), metal: rnd(d.metal), spec: rnd(d.spec), emissive: d.emis.map((x) => rnd(x)), opacity: rnd(d.opacity), blend: d.blend, depth_write: d.depthWrite, side: d.side, tex, nearest: !!(d.mapRef && d.mapRef.mag === THREE.NearestFilter), vc: !!m.vertexColors, tone_mapped: m.toneMapped !== false, flip_y: !!(m.map && m.map.flipY) });
    }
    return { bones, surfaces: outS };
  }

  /** life.json + life.bin: the lane graph, the cars and people as they are built, the townsfolk's geometry with the attributes glTF cannot carry, the talkers. Read by levels/hub/*.gd; the JS closures are out of reach of the scene walk. */
  async function hubLife(C, b, world, dir) {
    const D = C.district, W = C.city.district, plan = W.plan, F = W.furniture, T = D.traffic, K = D.crowd, GY = W.GY;
    const mods = { folk: await import(location.origin + '/levels/hub/city-folk.js'), drivers: await import(location.origin + '/levels/hub/city-drivers.js'), district: await import(location.origin + '/levels/hub/district.js') };
    const bin = { parts: [], bytes: 0 };
    const deckPlan = await import(location.origin + '/levels/hub/deck-plan.js');
    const put1 = (a) => { const o = bin.bytes; const t = a instanceof Float32Array || a instanceof Int32Array ? a : Float32Array.from(a); bin.parts.push(t); bin.bytes += t.byteLength; return o; };
    const sol = (s) => world.solids.indexOf(s);
    // ---- the street plan
    const pl = { roads: plan.roads.map((r) => ({ id: r.id, name: r.name, axis: r.axis, c: r.c, a0: r.a0, a1: r.a1, hw: r.hw, rect: r.rect })),
      nodes: plan.nodes.map((n) => ({ id: n.id, x: rnd(n.x), z: rnd(n.z), dead: !!n.dead, signal: !!n.signal, offset: n.offset ?? 0, box: n.box, arms: n.arms, in: Object.fromEntries(Object.entries(n.in).map(([k, e]) => [k, e.id])), out: Object.fromEntries(Object.entries(n.out).map(([k, e]) => [k, e.id])) })),
      edges: plan.edges.map((e) => ({ id: e.id, road: e.road.id, from: e.from.id, to: e.to.id, d: e.d, axis: e.axis, a0: rnd(e.a0), a1: rnd(e.a1), sg: e.sg, pts: e.path.pts })) };
    // ---- the traffic
    const types = {}; for (const k of T.kit.KINDS) { const t = T.kit.types[k]; types[k] = { L: t.L, W: t.W, H: t.H, lamps: t.lamps, cb: t.cb, seat: t.seat }; }
    const nodeNear = (x, z) => plan.nodes.find((n) => Math.abs(n.x - x) < 1 && Math.abs(n.z - z) < 1), busTurn = [[nodeNear(72, 180), 'S'], [nodeNear(72, 367), 'W'], [nodeNear(-72, 367), 'N'], [nodeNear(-72, 180), 'E']].filter((p) => p[0]).map(([n, d]) => [n.id, d]);
    const PARK = 4.55, rightOf = (d) => { const a = { E: [1, 0], W: [-1, 0], S: [0, 1], N: [0, -1] }[d]; return [-a[1], a[0]]; };
    const stops = F.stops.map((s) => ({ ...s, edge: plan.edges.find((e) => e.d === s.d && (e.axis === 'x' ? Math.abs(e.road.c - (s.z - rightOf(s.d)[1] * (PARK + 0.2))) < 0.5 && (s.x - e.a0) * e.sg > 0 && (e.a1 - s.x) * e.sg > 0 : Math.abs(e.road.c - (s.x - rightOf(s.d)[0] * (PARK + 0.2))) < 0.5 && (s.z - e.a0) * e.sg > 0 && (e.a1 - s.z) * e.sg > 0)) })).filter((s) => s.edge).map((s) => ({ x: s.x, z: s.z, d: s.d, axis: s.axis, edge: s.edge.id }));
    const cars = T.cars.map((c) => ({ id: c.id, kind: c.kind, color: c.color, x: rnd(c.x), z: rnd(c.z), hx: rnd(c.hx), hz: rnd(c.hz), s: rnd(c.s), edge: c.queue[0].edge ? c.queue[0].edge.id : c.queue[1].edge.id, slot: c.slot, glow: c.glow, bus: !!c.bus, truck: !!c.truck, vmax: rnd(c.vmax), solid: sol(c.solid), lat: c.lat }));
    const counts = {}; for (const k of T.kit.KINDS) counts[k] = T.meshes[k].p.count;
    // ---- the crowd
    const loops = K.loops.map((lp) => ({ pts: lp.back ? [lp.pts[0], lp.pts[1], lp.pts[0]] : lp.pts, kind: lp.kind, cross: lp.cross.map((c) => ({ s0: c.s0, s1: c.s1, x: rnd(c.x), z: rnd(c.z), node: c.node ? c.node.id : -1, axis: c.axis })) }));
    const folk = K.folk.map((f) => ({ name: f.name, loop: f.loop ? K.loops.indexOf(f.loop) : -1, s: rnd(f.s ?? 0), dir: f.dir ?? 1, vmax: rnd(f.vmax ?? 0), amp: f.amp, phase: rnd(f.phase ?? 0), seed: rnd(f.seed), pause: rnd(f.pause ?? 0), side: rnd(f.side ?? 0), side0: rnd(f.side0 ?? 0), col: f.col, still: !!f.still, vendor: !!f.vendor, x: rnd(f.x), z: rnd(f.z), hx: rnd(f.hx), hz: rnd(f.hz), lead: f.lead ? K.folk.indexOf(f.lead) : -1, sz: f.sz, slot: f.slot, tid: f.T.id, r: f.T.r, h: f.T.h, max: f.T.max }));
    const obstacles = [...F.lamps.map((o) => [o.x, o.z, 0.2]), ...F.signals.map((o) => [o.x, o.z, 0.2]), ...F.trees.map((o) => [o.x, o.z, 0.3]), ...F.hydrants.map((o) => [o.x, o.z, 0.22]), ...F.bins.map((o) => [o.x, o.z, 0.34]), ...F.papers.map((o) => [o.x, o.z, 0.34]), ...F.planters.map((o) => [o.x, o.z, 2.2]),
      ...F.benches.flatMap((o) => [-0.6, 0, 0.6].map((u) => [o.x + Math.cos(o.yaw) * u, o.z - Math.sin(o.yaw) * u, 0.4])), ...F.shelters.flatMap((o) => [-1.4, 0, 1.4].map((u) => [o.x + Math.cos(o.yaw) * u, o.z - Math.sin(o.yaw) * u, 0.7]))].map((o) => o.map((x) => rnd(x)));
    // ---- geometry: the species as the JS builds them, attributes as they are
    const geoOf = (g) => ({ n: g.attributes.position.count, pos: put1(Float32Array.from(g.attributes.position.array)), nor: put1(Float32Array.from(g.attributes.normal.array)), col: put1(Float32Array.from(g.attributes.color.array)), uv: put1(Float32Array.from(g.attributes.uv.array)), tile: put1(Float32Array.from(g.attributes.aTile.array)), pivot: put1(Float32Array.from(g.attributes.aPivot.array)), b4: put1(Float32Array.from(g.attributes.aB4.array)) });
    const species = {}; for (const name of mods.folk.SPECIES_NAMES) species[name] = geoOf(mods.folk.folkGeometry(name));
    const drivers = {}; for (const name of mods.drivers.DRIVER_SPECIES) { const d = mods.folk.folkDriverGeometry(name); drivers[name] = { geo: geoOf(d.geo), hipY: d.hipY, shX: d.shX, shY: d.shY, armLen: d.armLen, headTop: d.headTop }; }
    const atlas = await b.texEntry(K.material.map, 'color', false);
    let glow = null; { const cl = D.root.getObjectByName('CarLamps'); if (cl && cl.material.map) { const e = await b.texEntry(cl.material.map, 'color', true); glow = e ? b.opt.texDir + '/' + e.file : null; } }
    // ---- what the district view keeps to itself: the signal lenses (its statements, city-streets.js), the roaming lamps (district-view.js)
    const lens = [], REV = { E: 'W', W: 'E', N: 'S', S: 'N' }, DIRS = { E: [1, 0], W: [-1, 0], S: [0, 1], N: [0, -1] };
    for (const s of F.signals) {
      const n = s.node, PH = 6.2, approach = s.sx < 0 && s.sz > 0 ? 'S' : s.sx > 0 && s.sz < 0 ? 'N' : s.sx > 0 && s.sz > 0 ? 'E' : 'W', axis = approach === 'N' || approach === 'S' ? 'z' : 'x', served = n.arms[REV[approach]];
      const [hx, hz] = DIRS[approach], armLen = served ? 6.2 : 0.01, ax = s.armAxis === 'x' ? -s.sx : 0, az = s.armAxis === 'z' ? -s.sz : 0;
      const heads = served ? [[s.x + ax * (armLen - 0.5), GY + PH - 1.05, s.z + az * (armLen - 0.5)], [s.x + ax * (armLen * 0.45), GY + PH - 1.05, s.z + az * (armLen * 0.45)]] : [];
      for (let k = 0; k < 2; k++) { const p = heads[k]; if (!p) continue; for (const [dy, kind] of [[0.38, 0], [0, 1], [-0.38, 2]]) lens.push([rnd(p[0] - hx * 0.2), rnd(p[1] + dy), rnd(p[2] - hz * 0.2), rnd(n.offset), axis === 'x' ? 0 : 1, kind]); }
      for (let k = 0; k < 2; k++) { const dir = k === 0 ? [0, -s.sz] : [-s.sx, 0], px = s.x + dir[0] * 0.22, pz = s.z + dir[1] * 0.22; lens.push([rnd(px + dir[0] * 0.17), rnd(GY + 2.7), rnd(pz + dir[1] * 0.17), rnd(n.offset), k === 0 ? 1 : 0, 3]); }
    }
    const { BRIDGE, PIERS, bridgeY } = mods.district, L = W.layout, A = L.arena, mix = (a, c, t) => a + (c - a) * t, lamps = [];
    { const ringLamps = 12; for (let i = 0; i < ringLamps; i++) { const th = (i / ringLamps) * Math.PI * 2, rr = A.plaza - 5; if (Math.abs(th - Math.PI) < 0.4) continue; lamps.push({ x: A.x + Math.sin(th) * rr, y: GY, z: A.z + Math.cos(th) * rr, nx: -Math.sin(th), nz: -Math.cos(th), warm: i % 2 === 0 }); }
      for (let z = 72; z < BRIDGE.z1 - 2; z += 20) for (const s of [-1, 1]) lamps.push({ x: s * 7.0, y: bridgeY(z) + 1.0, z, nx: -s, nz: 0, warm: z % 40 < 20, bridge: true });
      for (const [x0, x1, z0, z1, side, shed] of PIERS) if (!shed) for (let k = 0; k < 3; k++) { const u = (k + 0.5) / 3; lamps.push({ x: side === 's' ? (x0 + x1) / 2 : mix(x0, x1, u), y: GY, z: side === 's' ? mix(z0, z1, u) : (z0 + z1) / 2, nx: 0, nz: 1, warm: k !== 1 }); } }
    const lampPts = [...lamps.map((l) => ({ hx: rnd(l.x + l.nx * 1.1), hz: rnd(l.z + l.nz * 1.1), top: rnd(l.y + (l.bridge ? 7.2 : 8.4)), warm: l.warm })), ...D.streets.lamps.map((l) => ({ hx: rnd(l.hx), hz: rnd(l.hz), top: rnd(l.top), warm: l.warm })), ...D.office.lights.map((l) => ({ hx: l.hx, hz: l.hz, top: rnd(l.top), warm: l.warm, office: true, intensity: l.intensity, distance: l.distance, color: l.color }))];
    // ---- the talkers: rigs, joints by name
    const npcs = {};
    for (const t of G.talkers) {
      const a = t.actor; if (!a || !a.root) continue;
      if (a.ready) await a.ready;
      const named = []; if (a.view && a.view.J) for (const k of Object.keys(a.view.J)) { const v = a.view.J[k]; if (v && v.isObject3D) named.push([v, k]); }
      if (a.view && a.view.g) named.push([a.view.g, 'g']);
      if (a.view && a.view.mouthHole) named.push([a.view.mouthHole, 'mouthHole']);
      const r = await rigJSON(a.root, b, bin, { named, space: a.view && a.view.g ? a.view.g : a.root, drop_scale: !!(a.view && a.view.g) }); r.x = t.x; r.y = t.y; r.z = t.z; r.yaw = t.yaw; npcs[t.id] = r;
    }
    // ---- the saucers' pilots: the same two alien models, one rig of each, flattened in Godot (levels/hub/city_traffic.gd)
    const pilots = {}; { const seen = {}; D.root.traverse((o) => { if ((o.name === 'Gray alien (NPC)' || o.name === 'Green alien (NPC)') && !o.visible && !seen[o.name]) seen[o.name] = o; });
      for (const nm of Object.keys(seen)) { const o = seen[nm], g = o.children[0]; pilots[nm.startsWith('Gray') ? 'gray' : 'green'] = await rigJSON(o, b, bin, { space: g, drop_scale: true }); } }
    await put(dir + '/life.bin', new Blob(bin.parts));
    const parked = T.parked.map((p) => ({ kind: p.kind, color: p.color, glow: p.glow || 0, x: rnd(p.x), z: rnd(p.z), yaw: rnd(p.yaw), hx: rnd(p.hx), hz: rnd(p.hz), slot: p.slot, solid: sol(p.solid), idx: p.parkedIdx }));
    const car_models = {};
    for (const k of T.kit.KINDS) { const m = T.kit.makeModel(k, 0xffffff, 0), t = T.kit.types[k]; car_models[k] = { wheel_r: m.wheelR, hl: m.hl, hw: m.hw, cb: m.cb, wheelbase: m.wheelbase, axle_f: m.axleF, axle_r: m.axleR, track: m.track, height: m.height, seat: m.seat, door_info: m.doorInfo, wheels: m.wheels.map((w) => ({ x: w.x, z: w.z, r: w.r, front: w.front })), lamps: t.lamps, L: t.L, palette0: T.kit.PALETTE[k][0], name: T.kit.names[k] }; if (m.dispose) m.dispose(); }
    return { parked, car_models, vents: F.manholes.filter((m) => m.steam).map((m) => ({ x: m.x, z: m.z })), arena: { x: plan.layout.arena.x, z: plan.layout.arena.z, r: plan.layout.arena.r }, land: plan.land, deck_rects: (D.driving && D.driving.deckRects) || [], GY, RY: T.RY, plan: pl, types, cars, counts, bus_turn: busTurn, stops, loops, folk, obstacles, people_solids: W.movers.people.map(sol), species, drivers, driver_species: mods.drivers.DRIVER_SPECIES, atlas: atlas ? b.opt.texDir + '/' + atlas.file : null, glow, lens, lamp_pts: lampPts, npcs, pilots, pod_path: (() => { const p = deckPlan.podPath(GY, mods.district.TERMINAL.z0 + 0.5); return { pts: p.pts, hidden: p.hidden }; })() };
  }
  /** The city's life on its own, without the 6 minute scene export (the JS data changed, the scene did not). */
  async function exportLife(opt) {
    RECV = opt.recv; GLTFExporter = (await import('three/addons/exporters/GLTFExporter.js')).GLTFExporter;
    const C = G.view.city, dir = 'levels/' + G.LEVEL, b = new Build({ S: null, tm: 'aces', exposure: G.view.renderer.toneMappingExposure, cell: 64, cellInst: 128, maxTex: 2048, texDir: 'levels/_tex', texUri: '../_tex/', sceneName: G.LEVEL });
    const life = C && C.district ? await hubLife(C, b, G.world, dir) : null;
    await put(dir + '/city_life.json', JSON.stringify(await cityLifeJSON(C, b)));
    if (life) await put(dir + '/life.json', JSON.stringify(life));
    return { textures: b.usedTextures(), bytes: life ? Object.keys(life.species).length : 0 };
  }

  /** rigs.json + rigs.bin: a kit level's talkers (those whose id starts with its rigPrefix) as bones and skinned surfaces, the same files HubNpcs builds the hub's talkers from */
  async function exportRigs(opt) {
    const dir = 'levels/' + G.LEVEL, b = new Build({ S: null, tm: 'aces', exposure: G.view.renderer.toneMappingExposure, cell: 64, cellInst: 128, maxTex: 2048, texDir: 'levels/_tex', texUri: '../_tex/', sceneName: G.LEVEL });
    const bin = { parts: [], bytes: 0 }, npcs = {};
    for (const t of G.talkers) {
      if (!t.id.startsWith(G.level.rigPrefix)) continue;
      const a = t.actor; if (!a || !a.root) continue;
      if (a.ready) await a.ready;
      const named = []; if (a.view && a.view.J) for (const k of Object.keys(a.view.J)) { const v = a.view.J[k]; if (v && v.isObject3D) named.push([v, k]); }
      if (a.view && a.view.g) named.push([a.view.g, 'g']);
      if (a.view && a.view.mouthHole) named.push([a.view.mouthHole, 'mouthHole']);
      const r = await rigJSON(a.root, b, bin, { named, space: a.view && a.view.g ? a.view.g : a.root, drop_scale: !!(a.view && a.view.g) }); r.x = t.x; r.y = t.y; r.z = t.z; r.yaw = t.yaw; npcs[t.id] = r;
    }
    await put(dir + '/rigs.bin', new Blob(bin.parts));
    await put(dir + '/rigs.json', JSON.stringify({ npcs }));
    return { textures: b.usedTextures() };
  }

  // ------------------------------------------------------------------------------------------------ export a level ----
  async function exportLevel(opt) {
    RECV = opt.recv; GLTFExporter = (await import('three/addons/exporters/GLTFExporter.js')).GLTFExporter;
    const t0 = performance.now(), id = G.LEVEL, root = rootOf(), world = G.world, view = G.view, dir = 'levels/' + id, b0warn = [];
    root.updateMatrixWorld(true);
    const spawn0 = { ...world.spawn };
    const CV = G.view.city && G.view.city.flick ? G.view.city : null;
    nameCityParts(CV);
    const lifeOut = CV ? await exportLife(opt) : (G.level && G.level.rigPrefix ? await exportRigs(opt) : null);      // (before the sample below moves anyone: the cars and people as they are built)
    const S = await sample(root, world, opt.sampleMs ?? 6000);
    // The hub: FOINT CITY only runs while the camera is down there (district-view.js), so seen from the spawn its traffic, crowd and sky never move: walk down and look, or none of it reads as moving and the cars stay parked where they were built
    if (G.LEVEL === 'hub') {
      const P = G.player, go = (x, y, z) => { P.x = x; P.y = y; P.z = z; P.vy = 0; if (G.rig.snapTo) G.rig.snapTo(P); };
      for (const [x, y, z] of [[0, -10, 200], [0, -10, 320], [60, -10, 420]]) { go(x, y, z); await sample(root, world, 2000, 150, S); }
      go(spawn0.x, spawn0.y, spawn0.z);
      await sample(root, world, 400, 100, S);
    }
    // a kit level: visit every F6 checkpoint, so what only moves, opens or appears in a later stage gets found too; then back to how it started
    const LVT = G.level, route = [];
    if (LVT && typeof LVT.load === 'function' && Array.isArray(LVT.checkpoints) && LVT.checkpoints.length && opt.tour !== false) {
      const cps = LVT.checkpoints, per = Math.min(1500, Math.max(500, 60000 / cps.length));
      say('touring ' + cps.length + ' checkpoints');
      for (let i = 0; i < cps.length; i++) {
        try { LVT.load(i); } catch (e) { b0warn.push('checkpoint ' + cps[i].name + ': ' + e.message); }
        await sample(root, world, per, 150, S);
        route.push({ name: cps[i].name, key: cps[i].key || '', x: rnd(G.player.x, 3), y: rnd(G.player.y, 3), z: rnd(G.player.z, 3) });
      }
      try { LVT.load(0); } catch (e) { /* the level starts there anyway */ }
      await sample(root, world, 400, 100, S);
    }
    try { G.setPaused(true); } catch (e) { /* no pause in this mode */ }
    await nextFrame();
    restoreInitial(root, S);
    world.spawn = spawn0;
    const renderer = view.renderer, tm = TM_NAMES[renderer.toneMapping] || 'none', exposure = renderer.toneMappingExposure;
    const b = new Build({ S, tm, exposure, cell: opt.cell || 64, cellInst: opt.cellInst || 128, maxTex: opt.maxTex || 2048, texDir: 'levels/_tex', texUri: '../_tex/', sceneName: id, ignoreName: opt.ignoreName ? new RegExp(opt.ignoreName) : null, skipName: new RegExp(opt.skipName || '^Blockout guidance$') });
    for (const w of b0warn) b.warn(w);
    const top = b.newNode(root, null, '', {});
    root.traverse((o) => { if (o.name) b.nameCount.set(o.name, (b.nameCount.get(o.name) || 0) + 1); });
    say('walking the scene');
    for (const c of root.children) await b.walk(c, top, root.visible);
    say(`plan: ${b.nodes.length} kept nodes, ${b.buckets.size} buckets, ${b.keys.size} material families, ${b.instances.length} instanced, ${b.lights.length} lights`);
    const size = await b.writeGLB(dir + '/scene.glb');
    say('glb ' + (size / 1048576).toFixed(1) + ' MB');
    if (b.instBuf.length) await put(dir + '/instances.bin', new Blob(b.instBuf));
    if (b.fieldBuf.length) await put(dir + '/shader_fields.bin', new Blob(b.fieldBuf));
    const colliders = await writeColliders(dir, world, S);
    const probes = writeProbes(world, opt.probes || 3000);
    await put(dir + '/probes.json', JSON.stringify(probes));
    // shaders: the work list for the hand-ported versions
    for (const w of b.workList()) await put(dir + '/shaders/' + w.name + '.json', JSON.stringify(w, null, 1));
    // level.json
    const sc = view.scene, LV = G.level, fog = sc.fog;
    const fogJ = !fog ? null : fog.isFogExp2 ? { type: 'exp2', color: col3(fog.color), hex: fog.color.getHexString(), density: rnd(fog.density, 6), pre_tonemap: untonemap([fog.color.r, fog.color.g, fog.color.b], tm, exposure) } : { type: 'linear', color: col3(fog.color), hex: fog.color.getHexString(), near: rnd(fog.near), far: rnd(fog.far), pre_tonemap: untonemap([fog.color.r, fog.color.g, fog.color.b], tm, exposure) };
    const skip = new Set(['world', 'root', 'stats', 'rig', 'view', 'mesh', 'scene', 'collision', 'lights', 'music', 'audio']);
    const lvData = {}; if (LV) for (const k of Object.keys(LV)) { if (skip.has(k)) continue; const v = plain(LV[k]); if (v !== undefined && !(v && typeof v === 'object' && !Array.isArray(v) && !Object.keys(v).length)) lvData[k] = v; }
    const wExtra = {}; for (const k of Object.keys(world)) { if (['solids', 'camSolids', 'spawn', 'city', 'water', 'poles'].includes(k) || k.startsWith('_')) continue; const v = plain(world[k]); if (v !== undefined) wExtra[k] = v; }
    const level = {
      id, name: opt.name || id, exporter: { version: 1, at: new Date().toISOString() },
      spawn: { x: rnd(spawn0.x), y: rnd(spawn0.y), z: rnd(spawn0.z), yaw: rnd(spawn0.yaw || 0, 6) }, route,
      fall_reset_y: world.fallResetY ?? -25, fog: fogJ, background: await backgroundJSON(b, sc, tm, exposure, dir), environment_map: !!sc.environment,
      tone_mapping: tm, exposure: rnd(exposure), shadows: !!renderer.shadowMap.enabled, camera: { near: rnd(view.camera.near), far: rnd(view.camera.far) },
      look: LV && LV.look ? plain(LV.look) : id, ...lightOfView(view), lights: b.lights,
      poles: plain(world.poles) || [], water: waterJSON(world, probes.bbox), camera_zone: cameraZoneJSON(world, probes.bbox), camera_room_dist: world.cameraRoomDist || 0, camera_room_lens_max: world.cameraRoomLensMax || 0, camera_no_swing: !!world.cameraNoSwing,
      portals: LV ? plain(LV.portals) || [] : plain(opt.portals) || [], actions: LV && LV.actions ? LV.actions.map((a) => ({ x: rnd(a.x), z: rnd(a.z), y: a.y !== undefined ? rnd(a.y) : undefined, label: typeof a.label === 'function' ? null : a.label, radius: a.radius !== undefined ? rnd(a.radius) : undefined, active: a.active ? a.active.toString().slice(0, 400) : undefined })) : [],
      checkpoints: LV && LV.checkpoints ? plain(LV.checkpoints) : [], data: lvData, world_extra: wExtra, music: LV && LV.createMusic ? 'createMusic' : (typeof G.music === 'object' && G.music ? Object.keys(G.music) : null),
      nodes: b.nodeTable(), instances: b.instEntries, instances_file: b.instBuf.length ? 'instances.bin' : '', shader_fields: b.fields, shader_fields_file: b.fieldBuf.length ? 'shader_fields.bin' : '', shaders: b.workList().map((w) => ({ name: w.name, type: w.type, uses: w.uses, attributes: w.attributes, mergeSafe: w.mergeSafe })), dynamic: b.dynamic,
      warnings: [...b.warnings.entries()].map(([k, n]) => k + (n > 1 ? ' x' + n : '')), textures: b.usedTextures(), colliders, counts: { ...b.counts, keys: b.keys.size, buckets: b.buckets.size, kept: b.nodes.length, glb_mb: rnd(size / 1048576, 1), tex_mb: rnd(b.texBytes / 1048576, 1), inst_mb: rnd(b.instOff / 1048576, 1), wall_s: rnd((performance.now() - t0) / 1000, 1) },
      normal_maps: b.usedTextures().some((t) => t.purpose === 'normal'),
    };
    await put(dir + '/level.json', JSON.stringify(level));
    return { life_textures: lifeOut ? lifeOut.textures : [], counts: level.counts, colliders, warnings: level.warnings, shaders: level.shaders.map((s) => s.name + ' x' + s.uses), dynamic: b.dynamic.length, textures: level.textures, normal_maps: level.normal_maps, lights: b.lights.length, spawn: level.spawn };
  }

  // ------------------------------------------------------------------------------------------------ export anything else: objects, weapons, suits ----
  /** one object tree as a GLB. `keep(o)`: objects that stay separate nodes (moving parts); everything else merges per material under its nearest kept ancestor. No cells: one thing at one spot. */
  async function exportTree(o, rel, opt) {
    const b = new Build({ S: null, tm: opt.tm || 'aces', exposure: opt.exposure || 1, cell: 1e6, cellInst: 1e6, maxTex: opt.maxTex || 1024, texDir: opt.texDir, texUri: opt.texUri, sceneName: opt.sceneName || 'object', keep: opt.keep, ignoreName: opt.ignoreName || null });
    o.updateMatrixWorld(true);
    const top = b.newNode(null, null, '', {}); top.world = new THREE.Matrix4(); top.inv = new THREE.Matrix4();
    await b.walk(o, top, true, opt.mergeRoot !== false);
    const size = await b.writeGLB(rel);
    return { size, b };
  }
  async function exportObject(opt) {
    RECV = opt.recv; GLTFExporter = (await import('three/addons/exporters/GLTFExporter.js')).GLTFExporter;
    const o = await (0, eval)('(async () => (' + opt.expr + '))()');
    if (!o || !o.isObject3D) throw new Error('expression is not an Object3D: ' + opt.expr);
    const { size, b } = await exportTree(o, 'objects/' + opt.name + '.glb', { texDir: 'objects/_tex', texUri: '_tex/', sceneName: opt.name, mergeRoot: false, ignoreName: null, tm: opt.tm });
    return { name: opt.name, size, counts: b.counts, warnings: [...b.warnings.keys()], textures: b.usedTextures() };
  }
  /** every gun of the BUILD table as a GLB: parts the info object points at (slides, mags, drums...) stay separate nodes, named after their key in info */
  async function exportWeapons(opt) {
    RECV = opt.recv; GLTFExporter = (await import('three/addons/exporters/GLTFExporter.js')).GLTFExporter;
    const out = [], textures = [];
    const ids = opt.only ? opt.only.split(',') : Object.keys(G.BUILD);
    for (const wid of ids) {
      const g = new THREE.Group(); g.name = wid;
      let info; try { info = G.BUILD[wid](g); } catch (e) { out.push({ id: wid, error: e.message }); continue; }
      info = info || {};
      const parts = new Map();
      const scan = (v, path, depth) => { if (!v || typeof v !== 'object' || depth > 3) return; if (v.isObject3D) { if (!parts.has(v) && v !== g) parts.set(v, path); return; } if (Array.isArray(v)) v.forEach((x, i) => scan(x, path + '_' + i, depth + 1)); else if (Object.getPrototypeOf(v) === Object.prototype) for (const k of Object.keys(v)) scan(v[k], path ? path + '_' + k : k, depth + 1); };
      scan(info, '', 0);
      for (const [o, path] of parts) if (!o.name) o.name = path;
      const { size, b } = await exportTree(g, 'weapons/' + wid + '.glb', { texDir: 'weapons/_tex', texUri: '_tex/', sceneName: wid, keep: (o) => parts.has(o), mergeRoot: true });
      const pl = plain(info);
      await put('weapons/' + wid + '.json', JSON.stringify({ id: wid, info: pl, parts: [...parts.values()], tris: b.counts.tris }));
      for (const t of b.usedTextures()) textures.push(t);
      out.push({ id: wid, kb: Math.round(size / 1024), tris: b.counts.tris, nodes: b.nodes.length, warnings: [...b.warnings.keys()] });
      await nextFrame();
    }
    return { out, textures };
  }

  /** The armor suits on the playable character's skeleton: phantom-suit.js dresses the Animator, each resulting SkinnedMesh goes out bound to a clean copy of the skeleton with the same bone names
   *  (Godot's named skins bind by name to the character's Skeleton3D). What a suit does to the body itself (retint, paint) is plain data in <id>.json for the character port. */
  async function exportSuits(opt) {
    RECV = opt.recv; GLTFExporter = (await import('three/addons/exporters/GLTFExporter.js')).GLTFExporter;
    const mod = await import(new URL('./phantom-suit.js', location.href).href), an = G.animator, cid = (G.CHAR && G.CHAR.id) || 'prog', out = [], textures = [];
    for (const id of Object.keys(mod.WEARABLE_SUITS)) {
      mod.wearSuitById(an, id);
      const meshes = []; an.model.traverse((o) => { if (o.isSkinnedMesh && o.name && o.name.startsWith(id + ':')) meshes.push(o); });
      if (!meshes.length) { out.push({ id, error: 'no meshes' }); continue; }
      for (let t = 0; t < 600 && meshes.some((m) => m.material.map && !m.material.map.image); t++) await nextFrame();      // a decal's image is still loading the first time the suit goes on
      const sk0 = meshes[0].skeleton, known = new Set(sk0.bones);
      // a copy of the bones only (props hang on them in the running game), in the bind pose
      const copy = new Map(), mk = (b) => { const c = new THREE.Bone(); c.name = b.name; copy.set(b, c); for (const k of b.children) if (k.isBone || known.has(k)) c.add(mk(k)); return c; };
      const roots = sk0.bones.filter((b) => !(b.parent && (b.parent.isBone || known.has(b.parent))));
      const scene = new THREE.Scene(); scene.name = id + '_' + cid;
      for (const r of roots) scene.add(mk(r));
      const bones = sk0.bones.map((b) => copy.get(b)), sk = new THREE.Skeleton(bones, sk0.boneInverses.map((m) => m.clone()));
      sk.pose(); for (const r of roots) copy.get(r).updateMatrixWorld(true);
      const b = new Build({ S: null, tm: 'aces', exposure: opt.exposure || 1, maxTex: 512, texDir: 'suits/_tex', texUri: '_tex/', sceneName: id });
      for (const m of meshes) {
        const g0 = m.geometry, n = g0.attributes.position.count, flatGeo = new THREE.BufferGeometry();
        const d = await b.describe(m.material);
        // flat, per facet (they are flat shaded and non-indexed), with the PS2 facet tone of the JS shader baked into the colour
        const cellM = /phantom-shade-([\d.]+?)(b?)(0?\.\d+)$/.exec(m.material.customProgramCacheKey ? String(m.material.customProgramCacheKey()) : ''), cell = cellM ? +cellM[1] : 0, amp = cellM ? +cellM[3] : 0;
        const pos = g0.attributes.position.array, col = new Uint8Array(n * 4), nor = new Float32Array(n * 3), C = d.vc && g0.attributes.color ? g0.attributes.color : null;
        for (let t = 0; t + 2 < n; t += 3) {
          const ax = pos[t * 3], ay = pos[t * 3 + 1], az = pos[t * 3 + 2], ux = pos[t * 3 + 3] - ax, uy = pos[t * 3 + 4] - ay, uz = pos[t * 3 + 5] - az, vx = pos[t * 3 + 6] - ax, vy = pos[t * 3 + 7] - ay, vz = pos[t * 3 + 8] - az;
          let fx = uy * vz - uz * vy, fy = uz * vx - ux * vz, fz = ux * vy - uy * vx; const L = Math.hypot(fx, fy, fz) || 1; fx /= L; fy /= L; fz /= L;
          let k = 1;
          if (cell) { const h = Math.sin(Math.floor(Math.abs(fx) * cell + 0.5) * 12.9898 + Math.floor(Math.abs(fy) * cell + 0.5) * 78.233 + Math.floor(Math.abs(fz) * cell + 0.5) * 37.719) * 43758.5453; k = 1 - amp / 2 + amp * (h - Math.floor(h)); }
          for (let v = t; v < t + 3; v++) {
            nor[v * 3] = fx; nor[v * 3 + 1] = fy; nor[v * 3 + 2] = fz;
            const cr = C ? C.getX(v) : d.color[0], cg = C ? C.getY(v) : d.color[1], cb = C ? C.getZ(v) : d.color[2];
            col[v * 4] = Math.round(linToS(cr * k) * 255); col[v * 4 + 1] = Math.round(linToS(cg * k) * 255); col[v * 4 + 2] = Math.round(linToS(cb * k) * 255); col[v * 4 + 3] = 255;
          }
        }
        flatGeo.setAttribute('position', new THREE.BufferAttribute(pos.slice(), 3));
        flatGeo.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
        flatGeo.setAttribute('color', new THREE.BufferAttribute(col, 4, true));
        if (d.uvTex && g0.attributes.uv) { const uv = Float32Array.from(g0.attributes.uv.array); if (d.uvTex.flipY) for (let i = 1; i < uv.length; i += 2) uv[i] = 1 - uv[i]; flatGeo.setAttribute('uv', new THREE.BufferAttribute(uv, 2)); }
        flatGeo.setAttribute('skinIndex', new THREE.BufferAttribute(Uint16Array.from(g0.attributes.skinIndex.array), 4));
        flatGeo.setAttribute('skinWeight', new THREE.BufferAttribute(Float32Array.from(g0.attributes.skinWeight.array), 4));
        const info = { idx: b.keys.size, d, cast: true, receive: true, order: 0, mode: 'tri', sprite: false, colors: new Set(['x', 'y']), anyVC: true };
        b.keys.set(m.name, info);
        d.fold = true; const M = b.exportMaterial(info); M.name = m.material.name || M.name;
        const mesh = new THREE.SkinnedMesh(flatGeo, M); mesh.name = m.name.replace(':', '_'); mesh.userData = { js_name: m.name, kind: 'suit' };
        scene.add(mesh); mesh.bind(sk, m.bindMatrix.clone());
      }
      const exporter = new GLTFExporter(); exporter.register((w) => new UriTextures(w, b));
      const buf = await exporter.parseAsync(scene, { binary: true, onlyVisible: false, trs: true, animations: [], includeCustomExtensions: false });
      await put('suits/' + id + '_' + cid + '.glb', new Blob([buf]));
      const make = mod.WEARABLE_SUITS[id], spec = make(an.B && an.B.id);
      await put('suits/' + id + '_' + cid + '.json', JSON.stringify({ id, character: cid, bones: sk0.bones.map((x) => x.name), colors: plain(spec.colors), glow: plain(spec.glow), retint: plain(spec.retint), paint: plain(spec.paint), meshes: meshes.map((x) => x.name) }));
      for (const t of b.usedTextures()) textures.push(t);
      out.push({ id, char: cid, kb: Math.round(buf.byteLength / 1024), meshes: meshes.length, bones: sk0.bones.length, verts: meshes.reduce((a, x) => a + x.geometry.attributes.position.count, 0), warnings: [...b.warnings.keys()] });
    }
    mod.wearSuitById(an, null);
    return { out, textures };
  }

  window.__exp = { exportLife, exportLevel, exportObject, exportWeapons, exportSuits, exportTree, sample, Build, untonemap, plain, setup: async (recv) => { RECV = recv; GLTFExporter = (await import('three/addons/exporters/GLTFExporter.js')).GLTFExporter; } };
})();
