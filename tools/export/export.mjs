// LEVEL EXPORTER: boots the real three.js game (tests/lib/level-harness.cjs there), enters a level, lets it build and warm, and writes it out as real Godot assets.
// The levels are never rewritten: they run exactly as they ship, and whatever they built is taken from the page (tools/export/page.js).
//   node tools/export/export.mjs list                         what can be exported, and what has been
//   node tools/export/export.mjs all                          a fresh checkout: makes the assets/levels junction, then every level of the JS registries, the guns and the suits (then run node tools/import.mjs)
//   node tools/export/export.mjs level <id> [--sample=6000] [--max-tex=2048] [--cell=64] [--probes=3000]   -> assets/levels/<id>/
//   node tools/export/export.mjs life [id]                    only the city's life data of a level with a JS CityView (city_life.json, and for the hub life.json + life.bin): cars, people, plan, talkers, sprites
//   (object also takes --level=<id> for the level it boots, --tm=none for a level without tone mapping)
//   node tools/export/export.mjs object "<js expr>" <name>    anything reachable from the page (window.__game = the game; an async expression returning an Object3D) -> assets/objects/<name>.glb
//   node tools/export/export.mjs weapons [id,id]              every gun of the JS BUILD table -> assets/weapons/<id>.glb + <id>.json (grips, muzzle, moving parts)
//   node tools/export/export.mjs suits [prog,tommy]           the armor suits, skinned to each character's skeleton with its bone names -> assets/suits/<id>_<character>.glb + .json
//   node tools/export/export.mjs check <id>                   drives the Godot game on PEEK_PORT (default 9307): collision against the JS answers, walk, perf
// After writing assets run `node tools/import.mjs`. assets/levels is a junction to F:/prog-godot-levels (CLAUDE.md); it is not in git because this tool regenerates it.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const PROJECT = path.resolve(HERE, '../..');
const JS_ROOT = path.resolve(PROJECT, '../progalpha-20261016T082732Z-1-001/progalpha');
const ASSETS = path.join(PROJECT, 'assets');
// the harness keeps its sheets and peek state in the OS temp folder: a private one here, so no other worker's run gets in the way
const TMP = 'F:/prog-godot-cache/tmp/export';
fs.mkdirSync(TMP, { recursive: true });
process.env.TEMP = TMP; process.env.TMP = TMP;

const require = createRequire(import.meta.url);
const { boot } = require(path.join(JS_ROOT, 'tests/lib/level-harness.cjs'));
// The harness's page.goto has Playwright's 30 s limit, which a level misses on a machine that is busy importing: the same Playwright module (the harness finds it the same way) with a longer one.
{
  const tries = [process.env.PROG_PLAYWRIGHT], rt = 'C:/Users/12147/AppData/Local/OpenAI/Codex/runtimes';
  try { for (const d of fs.readdirSync(rt)) tries.push(path.join(rt, d, 'bin/node_modules/playwright')); } catch { /* no Codex runtime on this machine */ }
  tries.push('C:/Users/12147/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright', 'playwright');
  for (const t of tries) {
    if (!t) continue;
    let pw; try { pw = require(t); } catch { continue; }
    const launch = pw.chromium.launch.bind(pw.chromium);
    pw.chromium.launch = async (...a) => { const b = await launch(...a), nc = b.newContext.bind(b); b.newContext = async (...c) => { const ctx = await nc(...c); ctx.setDefaultNavigationTimeout(300000); return ctx; }; return b; };
    break;
  }
}

const [cmd, ...rest] = process.argv.slice(2);
const flags = {}; const args = [];
for (const a of rest) { const m = a.match(/^--([\w-]+)(?:=(.*))?$/); if (m) flags[m[1]] = m[2] ?? true; else args.push(a); }

/** assets/levels is a junction to F:/prog-godot-levels (C: is nearly full) and not in git. A fresh checkout gets it here, with the files the JS game itself keeps under assets/levels. */
function ensureLevelsDir() {
  const link = path.join(ASSETS, 'levels'), target = 'F:/prog-godot-levels';
  if (fs.existsSync(link)) return;
  if (fs.existsSync('F:/')) { fs.mkdirSync(target, { recursive: true }); fs.symlinkSync(target, link, 'junction'); } else fs.mkdirSync(link, { recursive: true });
  fs.cpSync(path.join(JS_ROOT, 'assets/levels'), link, { recursive: true, force: false, filter: (src) => ![...NOT_PORTED].some((id) => path.basename(src).startsWith(id)) });
}
/** Levels left out of the Godot game by the user's decision: never exported, and their files never copied in. */
const NOT_PORTED = new Set(['bloodgulch', 'jetpack-yard', 'parkour-yard', 'reality-slip', 'ship-combat']);
/** every level the JS game knows and the Godot game keeps: LEVELS in index.html, then levels/registry.js */
function allLevels() {
  const html = fs.readFileSync(path.join(JS_ROOT, 'index.html'), 'utf8'), reg = fs.readFileSync(path.join(JS_ROOT, 'levels/registry.js'), 'utf8');
  const a = /const LEVELS = \{([\s\S]*?)\n\};/.exec(html)[1], ids = [...a.matchAll(/^\s*(\w[\w-]*):/gm)].map((m) => m[1]);
  for (const m of reg.matchAll(/\{ id: '([\w-]+)'/g)) if (!ids.includes(m[1])) ids.push(m[1]);
  return ids.filter((id) => !NOT_PORTED.has(id));
}

/** POST /put?f=<relative path under assets/>: how the page hands files over */
function receiver() {
  const written = [];
  const srv = http.createServer((req, res) => {
    const u = new URL(req.url, 'http://x');
    res.setHeader('Access-Control-Allow-Origin', '*');
    if (u.pathname !== '/put' || req.method !== 'POST') { res.writeHead(404); return res.end(); }
    const rel = u.searchParams.get('f'), file = path.join(ASSETS, rel);
    if (!path.resolve(file).startsWith(path.resolve(ASSETS))) { res.writeHead(403); return res.end(); }
    fs.mkdirSync(path.dirname(file), { recursive: true });
    const out = fs.createWriteStream(file + '.part');
    req.pipe(out);
    out.on('finish', () => { fs.renameSync(file + '.part', file); written.push(rel); res.writeHead(200); res.end('ok'); });
    out.on('error', (e) => { console.error('write failed', rel, e.message); res.writeHead(500); res.end(); });
  });
  return new Promise((ok) => srv.listen(0, '127.0.0.1', () => ok({ url: 'http://127.0.0.1:' + srv.address().port, close: () => srv.close(), written })));
}

/** a booted game with the exporter in its page. One browser at a time on this machine, and others use it too: a boot that times out is tried again */
async function bootGame(levelId, opt = {}) {
  for (let attempt = 1; ; attempt++) {
    try {
      const h = await boot(levelId, { timeout: 300000, patch: { 'index.html': (src) => src.replace(/<head[^>]*>/i, (m) => m + '<script>window.__expBoot = 1;</script>') }, ...opt });      // (window.__expBoot: a level can tell it is being exported while it is being built: the exporter's own page code only arrives after that)
      const vendor = (name) => fs.readFileSync(path.join(HERE, 'vendor', name));
      await h.page.route('**/examples/jsm/exporters/GLTFExporter.js', (r) => r.fulfill({ body: vendor('GLTFExporter.js'), contentType: 'application/javascript', headers: { 'access-control-allow-origin': '*' } }));
      await h.page.route('**/examples/jsm/utils/TextureUtils.js', (r) => r.fulfill({ body: vendor('TextureUtils.js'), contentType: 'application/javascript', headers: { 'access-control-allow-origin': '*' } }));
      await h.page.addScriptTag({ content: fs.readFileSync(path.join(HERE, 'page.js'), 'utf8') });
      h.page.on('console', (m) => { const t = m.text(); if (t.startsWith('[export] ')) console.log(t.slice(9)); });
      return h;
    } catch (e) {
      console.log(`boot of ${levelId} failed (attempt ${attempt}): ${e.message.split('\n')[0]}`);
      if (attempt >= 4) throw e;
      await new Promise((r) => setTimeout(r, 20000 * attempt));
    }
  }
}

// ---- Godot import settings, written once per file so a re-export keeps its uid ----
function textureImport(file, purpose, srcRes) {
  const imp = file + '.import';
  if (fs.existsSync(imp)) return false;
  fs.writeFileSync(imp, `[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="${srcRes}"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=${purpose === 'normal' ? 1 : 0}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
`);
  return true;
}
function glbImport(file, srcRes, opt = {}) {
  const imp = file + '.import';
  if (fs.existsSync(imp) && !flags['reset-import']) {
    if (!opt.tangents) return false;
    const txt = fs.readFileSync(imp, 'utf8');
    if (txt.includes('meshes/ensure_tangents=true')) return false;
    fs.writeFileSync(imp, txt.replace('meshes/ensure_tangents=false', 'meshes/ensure_tangents=true'));
    return true;
  }
  fs.writeFileSync(imp, `[remap]

importer="scene"
importer_version=1
type="PackedScene"

[deps]

source_file="${srcRes}"

[params]

nodes/root_type=""
nodes/root_name=""
nodes/root_script=null
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
nodes/use_name_suffixes=false
nodes/use_node_type_suffixes=false
meshes/ensure_tangents=${opt.tangents ? 'true' : 'false'}
meshes/generate_lods=${opt.lods === false ? 'false' : 'true'}
meshes/create_shadow_meshes=true
meshes/light_baking=0
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=false
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=true
animation/import_rest_as_RESET=false
import_script/path="res://tools/export/glb_post_import.gd"
materials/extract=0
materials/extract_format=0
materials/extract_path=""
_subresources={}
gltf/naming_version=2
gltf/embedded_image_handling=0
`);
  return true;
}
function writeTextureImports(dirRel, textures) {
  let n = 0;
  for (const t of textures) if (textureImport(path.join(ASSETS, dirRel, t.file), t.purpose, `res://assets/${dirRel}/${t.file}`)) n++;
  return n;
}

// ---- commands ----
async function exportLevel(id) {
  const rc = await receiver();
  const h = await bootGame(id, { god: true });
  try {
    await waitMerge(h);
    const r = await h.page.evaluate((o) => window.__exp.exportLevel(o), { recv: rc.url, sampleMs: +(flags.sample || 6000), maxTex: +(flags['max-tex'] || 2048), cell: +(flags.cell || 64), cellInst: +(flags['cell-inst'] || 128), probes: +(flags.probes || 3000), ignoreName: flags['ignore-name'] || null, name: id });
    writeTextureImports('levels/_tex', [...r.textures, ...r.life_textures]);
    glbImport(path.join(ASSETS, 'levels', id, 'scene.glb'), `res://assets/levels/${id}/scene.glb`, { tangents: r.normal_maps, lods: !flags['no-lods'] });
    const pageErrs = h.errors.length;
    await refShots(h, id).catch((e) => console.log('reference shots failed: ' + e.message.split('\n')[0]));
    console.log(JSON.stringify({ id, counts: r.counts, colliders: r.colliders, lights: r.lights, spawn: r.spawn, shaders: r.shaders, dynamic: r.dynamic, normal_maps: r.normal_maps, textures: r.textures.length, warnings: r.warnings, pageErrs }));
  } finally { await h.close(); rc.close(); }
}
/** Reference pictures of the three.js build beside each export, in the temp folder (look once, never keep): the level as it starts, and two later F6 checkpoints of a kit level.
 *  The view (body, camera yaw and pitch) goes in views-<id>.json, so `eval level_probe.view(k)` shows the same thing in Godot. */
async function refShots(h, id) {
  const views = [];
  const shot = async (i, cp) => {
    const v = await h.page.evaluate(async (c) => {
      const G = window.__game;
      try { G.setPaused(false); } catch { /* no pause in this mode */ }
      if (c >= 0) { G.level.load(c); await new Promise((r) => setTimeout(r, 1500)); }
      const cam = G.view.camera, dir = cam.getWorldDirection(new G.THREE.Vector3());
      return { x: G.player.x, y: G.player.y, z: G.player.z, yaw: G.player.yaw, rig_yaw: G.rig.yaw, rig_pitch: G.rig.pitch, cam: [cam.position.x, cam.position.y, cam.position.z], look: [cam.position.x + dir.x * 10, cam.position.y + dir.y * 10, cam.position.z + dir.z * 10], name: c >= 0 ? G.level.checkpoints[c].name : 'start' };
    }, cp);
    await h.page.screenshot({ type: 'jpeg', quality: 60, path: path.join(TMP, `ref-${id}-${i}.jpg`) });
    views.push(v);
  };
  await shot(0, -1);
  const n = await h.page.evaluate(() => { const L = window.__game.level; return L && typeof L.load === 'function' && Array.isArray(L.checkpoints) ? L.checkpoints.length : 0; });
  if (n >= 3) { await shot(1, Math.floor(n / 3)); await shot(2, Math.floor(2 * n / 3)); }
  fs.writeFileSync(path.join(TMP, `views-${id}.json`), JSON.stringify(views));
}
/** auto-merge and the level's own warm-up have finished (the originals are what get exported; this only makes sure everything has been placed) */
async function waitMerge(h) {
  await h.page.waitForFunction(() => { const G = window.__game; const a = G.view.autoMerges[G.view.autoMerges.length - 1]; return !a || a.stats.phase === 'watch' || a.stats.phase === 'disposed'; }, null, { timeout: 60000 }).catch(() => console.log('auto-merge did not finish: going on'));
}
/** the data of the city's life alone (city_life.json, life.json, life.bin), when only that changed: about a minute instead of the scene's six */
async function exportLifeOnly(id) {
  const rc = await receiver();
  const h = await bootGame(id, { god: true });
  try {
    await waitMerge(h);
    const r = await h.page.evaluate((o) => window.__exp.exportLife(o), { recv: rc.url });
    writeTextureImports('levels/_tex', r.textures);
    console.log(JSON.stringify({ id, textures: r.textures.length, species: r.bytes, errors: h.errors.length }));
  } finally { await h.close(); rc.close(); }
}
async function exportObject(expr, name) {
  const rc = await receiver();
  const h = await bootGame(flags.level || 'club');
  try {
    const r = await h.page.evaluate((o) => window.__exp.exportObject(o), { recv: rc.url, expr, name, tm: flags.tm });
    writeTextureImports('objects/_tex', r.textures);
    glbImport(path.join(ASSETS, 'objects', name + '.glb'), `res://assets/objects/${name}.glb`, { lods: false });
    console.log(JSON.stringify({ name, kb: Math.round(r.size / 1024), counts: r.counts, warnings: r.warnings, textures: r.textures.length }));
  } finally { await h.close(); rc.close(); }
}
async function exportWeapons() {
  const rc = await receiver();
  const h = await bootGame(flags.level || 'club');
  try {
    const r = await h.page.evaluate((o) => window.__exp.exportWeapons(o), { recv: rc.url, only: args[0] || null });
    writeTextureImports('weapons/_tex', r.textures);
    for (const w of r.out) { if (w.error) { console.log(`${w.id}: FAILED ${w.error}`); continue; } glbImport(path.join(ASSETS, 'weapons', w.id + '.glb'), `res://assets/weapons/${w.id}.glb`, { lods: false }); console.log(`${w.id}: ${w.kb} KB, ${w.tris} tris, ${w.nodes} nodes${w.warnings.length ? ', warnings: ' + w.warnings.join('; ') : ''}`); }
  } finally { await h.close(); rc.close(); }
}
/** one boot per playable character: the suits are fitted to each body */
async function exportSuits() {
  for (const character of (args[0] || 'prog,tommy').split(',')) {
    const rc = await receiver();
    const h = await bootGame(flags.level || 'club', { character, costume: flags.costume || undefined });
    try {
      const r = await h.page.evaluate((o) => window.__exp.exportSuits(o), { recv: rc.url });
      writeTextureImports('suits/_tex', r.textures);
      for (const w of r.out) { if (w.error) { console.log(`${character} ${w.id}: FAILED ${w.error}`); continue; } glbImport(path.join(ASSETS, 'suits', `${w.id}_${w.char}.glb`), `res://assets/suits/${w.id}_${w.char}.glb`, { lods: false }); console.log(`${w.id}_${w.char}: ${w.kb} KB, ${w.meshes} meshes, ${w.bones} bones, ${w.verts} verts${w.warnings.length ? ', warnings: ' + w.warnings.join('; ') : ''}`); }
    } finally { await h.close(); rc.close(); }
  }
}
function list() {
  for (const id of allLevels()) {
    const f = path.join(ASSETS, 'levels', id, 'scene.glb');
    console.log(id.padEnd(16) + (fs.existsSync(f) ? `${(fs.statSync(f).size / 1048576).toFixed(1)} MB glb` : '-'));
  }
}
/** the next import redoes these GLBs (after a change to glb_post_import.gd, which Godot does not notice by itself) */
function reimport(ids) {
  for (const id of ids) {
    const imp = path.join(ASSETS, 'levels', id, 'scene.glb.import');
    if (!fs.existsSync(imp)) continue;
    const m = /dest_files=\["res:\/\/\.godot\/imported\/([^"]+)\.scn"/.exec(fs.readFileSync(imp, 'utf8'));
    if (m) fs.rmSync(path.join(PROJECT, '.godot/imported', m[1] + '.md5'), { force: true });
  }
}
function check(id) {
  const peek = (...a) => spawnSync('node', [path.join(PROJECT, 'tools/peek.mjs'), ...a], { encoding: 'utf8', env: { ...process.env, PEEK_PORT: process.env.PEEK_PORT || '9307', TEMP: os.tmpdir() }, timeout: 600000 }).stdout || '';
  console.log(peek('restart', id).trim());
  console.log(peek('eval', `return await load("res://tools/export/level_probe.gd").new().run(${flags['no-walk'] ? 'false' : 'true'})`).trim());
}

switch (cmd) {
  case 'list': list(); break;
  case 'level': ensureLevelsDir(); for (const id of args) await exportLevel(id); break;
  case 'all': ensureLevelsDir(); for (const id of allLevels()) await exportLevel(id); await exportWeapons(); await exportSuits(); break;
  case 'life': for (const id of (args.length ? args : ['hub'])) await exportLifeOnly(id); break;
  case 'object': await exportObject(args[0], args[1]); break;
  case 'weapons': await exportWeapons(); break;
  case 'suits': await exportSuits(); break;
  case 'check': check(args[0]); break;
  case 'reimport': reimport(args); break;
  default: console.log(fs.readFileSync(fileURLToPath(import.meta.url), 'utf8').split('\n').slice(0, 9).join('\n'));
}
process.exit(0);
