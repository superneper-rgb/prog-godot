// One-command project check: node tools/check.mjs  (--quick skips booting the game, --level-proof <id> proves an exported level, --parity also replays movement against the three.js recordings)
// Compiles every script, enforces the project rules below, then boots the game headless. Must print `all checks passed`.
// New project-wide checks go in this file, never as a separate script.
import fs from 'node:fs';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const GODOT = process.env.PROG_GODOT || 'F:/godot/Godot_v4.7.2-stable_win64_console.exe';
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const quick = process.argv.includes('--quick');
const clean = (s) => s.replace(/\x1b\[[0-9;]*m/g, '');
let fails = 0;
const fail = (m) => { console.log('FAIL: ' + m); fails++; };

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name === '.godot' || e.name === '.git') continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out); else out.push(p);
  }
  return out;
}
// ---- coverage (--coverage): what the three.js game has that the port does not yet. A report, not a pass or fail: names can move, so a miss is a thing to look at, and a hit does not prove it works. ----
if (process.argv.includes('--coverage')) {
  const JS = path.resolve(ROOT, '../progalpha-20261016T082732Z-1-001/progalpha');
  const SKIP_JS = /^(tests|devtools|blender|assets|node_modules|release|levels\/bloodgulch)(\/|$)/;      // tools, or left out by the user's decision (PORT_STATUS.md)
  const NOISE = new Set(['constructor', 'if', 'for', 'while', 'switch', 'catch', 'function', 'return', 'main', 'init', 'update', 'dispose']);
  const snake = (s) => s.replace(/([a-z0-9])([A-Z])/g, '$1_$2').replace(/([A-Z])([A-Z][a-z])/g, '$1_$2').toLowerCase().replace(/^_+|_+$/g, '');
  const gdFiles = walk(ROOT).filter((f) => f.endsWith('.gd') && !rel0(f).startsWith('assets/') && !rel0(f).startsWith('tools/'));
  function rel0(p) { return path.relative(ROOT, p).replaceAll('\\', '/'); }
  const decls = (txt) => { const o = new Set(); for (const m of txt.matchAll(/^\s*(?:static\s+)?(?:func|var|const|class|class_name|signal)\s+([A-Za-z_]\w*)/gm)) o.add(m[1].replace(/^_+|_+$/g, '').toLowerCase()); return o; };
  const texts = new Map(gdFiles.map((f) => [rel0(f), fs.readFileSync(f, 'utf8')]));
  const all = new Set(); for (const t of texts.values()) for (const d of decls(t)) all.add(d);
  const has = (name, set = all) => set.has(snake(name)) || set.has(name.replace(/^_+/, '').toLowerCase());
  const short = (a, n = 14) => a.slice(0, n).join(' ') + (a.length > n ? ` ... +${a.length - n}` : '');
  const html = fs.readFileSync(path.join(JS, 'index.html'), 'utf8').split('\n');
  // 1. classes in index.html, method by method, against the Godot files that hold them
  const HOME = { Input: ['core/game_input.gd'], Solid: ['core/world.gd'], World: ['core/world.gd'], Target: ['combat/target.gd'], Combat: ['combat/'], Barks: ['enemies/barks.gd'], Robot: ['enemies/robot.gd'], Drone: ['enemies/drone.gd'], Enemies: ['enemies/enemies.gd'], Player: ['player/player.gd'], CameraRig: ['player/camera_rig.gd'], ArmHelix: ['combat/'], WeaponView: ['combat/weapon_view.gd'], Animator: ['player/'], LightPool: ['core/', 'levels/exported_level.gd'], View: ['core/'], BotView: ['enemies/'], PartBuilder: ['enemies/'], RobotView: ['enemies/'], DroneView: ['enemies/'], FX: ['fx/'], Sfx: ['audio/'], Gadgets: ['fx/'], Ecg: ['ui/'], Hud: ['ui/'], Wheel: ['ui/'], UI: ['ui/'] };
  console.log('\n== classes in index.html: methods found in their Godot home ==');
  let tot = 0, got = 0;
  html.forEach((line, i) => {
    const c = /^class ([A-Z]\w*)/.exec(line); if (!c) return;
    const ms = [];
    for (let j = i + 1; j < html.length && !html[j].startsWith('}'); j++) { const m = /^  (?:(?:static|async|get|set)\s+)*([A-Za-z_$][\w$]*)\s*\([^;]*\{/.exec(html[j]); if (m && !NOISE.has(m[1]) && !ms.includes(m[1])) ms.push(m[1]); }
    const home = HOME[c[1]] || [], set = new Set(); for (const [f, t] of texts) if (home.some((h) => f === h || (h.endsWith('/') && f.startsWith(h)))) for (const d of decls(t)) set.add(d);
    const miss = ms.filter((m) => !has(m, set)); tot += ms.length; got += ms.length - miss.length;
    console.log(`${String(ms.length - miss.length).padStart(4)}/${String(ms.length).padEnd(4)} ${c[1]}${home.length ? '' : ' (no Godot home yet)'}${miss.length ? '  missing: ' + short(miss) : ''}`);
  });
  console.log(`${got}/${tot} methods`);
  // 2. top-level functions of index.html (the main loop, shops, doors, menus)
  const fnames = [...new Set(html.map((l) => /^(?:async\s+)?function\s+([A-Za-z_$][\w$]*)/.exec(l)?.[1]).filter(Boolean))].filter((n) => !NOISE.has(n));
  const fmiss = fnames.filter((n) => !has(n));
  console.log(`\n== top-level functions in index.html: ${fnames.length - fmiss.length}/${fnames.length} ==\nmissing: ${short(fmiss, 60)}`);
  // 3. every other JS file, by folder: its named functions and classes, and the lines behind them
  console.log('\n== other JS files, by folder (names found anywhere in the port; files with none are listed) ==');
  const dirs = new Map();
  for (const f of walk(JS)) {
    const r = path.relative(JS, f).replaceAll('\\', '/');
    if (!r.endsWith('.js') || SKIP_JS.test(r)) continue;
    const txt = fs.readFileSync(f, 'utf8'), names = new Set();
    for (const m of txt.matchAll(/^(?:export\s+)?(?:default\s+)?(?:async\s+)?(?:function\*?|class)\s+([A-Za-z_$][\w$]*)/gm)) names.add(m[1]);
    for (const m of txt.matchAll(/^(?:export\s+)?const\s+([A-Za-z_$][\w$]*)\s*=\s*(?:async\s*)?(?:\(|[a-z]\w*\s*=>|function)/gm)) names.add(m[1]);
    const d = r.startsWith('levels/') ? r.split('/').slice(0, 2).join('/') : (r.includes('/') ? r.split('/')[0] : '(root)');
    const e = dirs.get(d) || { files: 0, lines: 0, names: 0, hit: 0, none: [] };
    const list = [...names].filter((n) => !NOISE.has(n)), hit = list.filter((n) => has(n)).length;
    e.files++; e.lines += txt.split('\n').length; e.names += list.length; e.hit += hit;
    if (hit === 0) e.none.push(path.basename(r, '.js'));
    dirs.set(d, e);
  }
  for (const [d, e] of [...dirs].sort((a, b) => a[0].localeCompare(b[0]))) console.log(`${String(e.hit).padStart(4)}/${String(e.names).padEnd(4)} ${d.padEnd(24)} ${String(e.lines).padStart(6)} lines, ${e.files} files${e.none.length ? '  nothing yet: ' + short(e.none, 10) : ''}`);
  // 4. things the player can name: guns, levels, console commands
  const jsHtml = html.join('\n'), wpn = /const WEAPONS = \[([\s\S]*?)\n\];/.exec(jsHtml)?.[1] || '', ids = [...wpn.matchAll(/\bid:\s*'([\w-]+)'/g)].map((m) => m[1]);
  const wtxt = texts.get('combat/weapons.gd') || '';
  console.log(`\n== registries ==\nguns: ${ids.filter((i) => wtxt.includes(`"${i}"`)).length}/${ids.length}${ids.some((i) => !wtxt.includes(`"${i}"`)) ? '  missing: ' + ids.filter((i) => !wtxt.includes(`"${i}"`)).join(' ') : ''}`);
  const cmds = [...new Set([...fs.readFileSync(path.join(JS, 'devtools/commands.js'), 'utf8').matchAll(/name:\s*'([\w-]+)'/g), ...jsHtml.matchAll(/devConsole\.register\(\{\s*name:\s*'([\w-]+)'/g)].map((m) => m[1]))], ctxt = texts.get('ui/console_commands.gd') || '';
  const cmiss = cmds.filter((c) => !ctxt.includes(`"${c}"`));
  console.log(`console commands: ${cmds.length - cmiss.length}/${cmds.length}${cmiss.length ? '  missing: ' + cmiss.join(' ') : ''}`);
  const lvl = /const LEVELS := \{([\s\S]*?)\n\}/.exec(texts.get('core/game.gd') || '')?.[1] || '', lids = [...lvl.matchAll(/"([\w-]+)":\s*"res:\/\/([^"]+)"/g)];
  const noWorld = lids.filter((m) => m[1] !== 'arena' && !fs.existsSync(path.join(ROOT, 'assets/levels', m[1], 'level.json'))).map((m) => m[1]), noLogic = lids.filter((m) => m[2].endsWith('exported_level.gd')).map((m) => m[1]);
  console.log(`levels: ${lids.length} registered; no exported world yet: ${noWorld.join(' ') || 'none'}; world only, no level logic: ${noLogic.length}`);
  // 5. what the code itself says it left out
  const LEFT = /\b(TODO|FIXME|not ported|not yet|stub|placeholder|comes? with|for now|later package|until .* (?:is|are) ported)\b/i;
  const left = []; for (const [f, t] of texts) t.split('\n').forEach((l, i) => { const cm = l.indexOf('#'); if (cm >= 0 && LEFT.test(l.slice(cm))) left.push(`${f}:${i + 1} ${l.slice(cm).trim().slice(0, 130)}`); });
  console.log(`\n== the port's own notes of things left out: ${left.length} ==\n${left.join('\n')}`);
  process.exit(0);
}

const files = walk(ROOT);
const rel = (p) => path.relative(ROOT, p).replaceAll('\\', '/');

// ---- rules on source text ----
const GODOT3 = [[/\byield\s*\(/, 'yield( is Godot 3: use await'], [/^\s*onready\s+var/, 'onready var: use @onready'], [/^\s*export\s*(\(|var)/, 'export var: use @export'],
  [/\.connect\(\s*"[^"]+"\s*,/, 'old connect("sig", obj, "fn"): use sig.connect(callable)'], [/\bKinematicBody\b|\bSpatial\b/, 'Godot 3 class name']];
for (const f of files) {
  const r = rel(f), ext = path.extname(f).toLowerCase();
  if (['.gd', '.gdshader', '.tscn', '.tres', '.mjs', '.json', '.cfg'].includes(ext)) {
    const txt = fs.readFileSync(f, 'utf8');
    if (ext === '.gd') {
      const lines = txt.split('\n');
      lines.forEach((l, i) => { if (!l.trim().startsWith('#')) for (const [re, msg] of GODOT3) if (re.test(l)) fail(`${r}:${i + 1} ${msg}`); });
      if (!/^(@tool\s+)?(@abstract\s+)?(class_name\s+\w+\s*)?(extends\s+[\w".\/]+\s*)?(##|\n*#)/m.test(txt.slice(0, 400)) && !txt.slice(0, 400).includes('##')) fail(`${r}: needs a ## header line saying what it is`);
    }
    // no base64 / long blobs in source
    if (/[A-Za-z0-9+/=]{300,}/.test(txt) && ext !== '.json') fail(`${r}: long base64-like blob`);
    if (/data:[a-z]+\/[a-z0-9.+-]+;base64,/.test(txt)) fail(`${r}: embedded data URI`);
  }
  // screenshots and scratch images belong in the OS temp folder, never the project
  if (['.png', '.jpg', '.jpeg', '.webp'].includes(ext) && !r.startsWith('assets/') && r !== 'icon.png') fail(`${r}: image outside assets/`);
}

// ---- level registry points at real files ----
const game = fs.readFileSync(path.join(ROOT, 'core/game.gd'), 'utf8');
for (const m of game.matchAll(/"res:\/\/(levels\/[^"]+\.gd)"/g)) if (!fs.existsSync(path.join(ROOT, m[1]))) fail(`Game.LEVELS points at missing ${m[1]}`);

// ---- every sound in audio/sfx_bank.gd has its rendered takes on disk ----
{
  const bankFile = path.join(ROOT, 'audio/sfx_bank.gd');
  if (fs.existsSync(bankFile)) {
    let missing = 0;
    for (const m of fs.readFileSync(bankFile, 'utf8').matchAll(/^\t"([^"]+)": \{"n":(\d+)/gm)) {
      for (let i = 0; i < +m[2]; i++) if (!fs.existsSync(path.join(ROOT, `assets/sfx/synth/${m[1]}_${i}.wav`))) { if (missing++ < 10) fail(`sfx bank: missing ${m[1]}_${i}.wav (node tools/export/render-sfx.mjs)`); }
    }
    if (missing > 10) fail(`sfx bank: ${missing} rendered takes missing in all`);
  }
}

// ---- every script compiles ----
{
  const r = spawnSync(GODOT, ['--headless', '--path', ROOT, '--', '--check-scripts'], { encoding: 'utf8', maxBuffer: 1 << 28, timeout: 300000 });
  const out = clean((r.stdout || '') + (r.stderr || ''));
  const errs = out.split('\n').filter((l) => /SCRIPT ERROR|Parse Error|Compile Error|BAD SCRIPT|Failed to load script/i.test(l));
  for (const l of errs.slice(0, 60)) fail(l.trim());
  const sum = out.split('\n').find((l) => l.startsWith('scripts checked'));
  console.log(sum || 'script check produced no summary');
  if (!sum) fail('script check did not finish');
}

// ---- a shader that includes common.gdshaderinc must not name a uniform like the locals in there: the compiler reads the uniform inside those functions, add_display comes out wrong and the glows nearly vanish (the Spire's additive points) ----
{
  const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => (e.name.startsWith('.') || e.name === 'assets') ? [] : e.isDirectory() ? walk(path.join(d, e.name)) : /\.(gd|gdshader)$/.test(e.name) ? [path.join(d, e.name)] : []);
  const clash = /^\s*uniform\s+\w+\s+(?:\w+\s*:\s*)?(a|b|c|d|l|v|y|px|dist|viewport|p11|radiance|alpha)\b/m;
  for (const f of walk(ROOT)) {
    const src = fs.readFileSync(f, 'utf8');
    if (src.includes('common.gdshaderinc') && clash.test(src)) fail(path.relative(ROOT, f) + ': a uniform named like a local of common.gdshaderinc (' + clash.exec(src)[1] + '): rename it');
  }
}

// ---- an additive 3D shader must opt out of fog: fog on an additive surface adds the fog colour, so a particle near the lens tints the whole frame --
{
  const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => (e.name.startsWith('.') || e.name === 'assets') ? [] : e.isDirectory() ? walk(path.join(d, e.name)) : e.name.endsWith('.gdshader') ? [path.join(d, e.name)] : []);
  for (const f of walk(ROOT)) {
    const src = fs.readFileSync(f, 'utf8');
    const rm = /render_mode\s+([^;]*);/.exec(src);
    if (/shader_type\s+spatial/.test(src) && rm && /blend_add/.test(rm[1]) && !/fog_disabled/.test(rm[1])) fail(path.relative(ROOT, f) + ': an additive spatial shader without fog_disabled');
  }
}

// ---- a talker's on_start / on_end gets the talker: a lambda taking nothing is a script error when the line ends, and whatever it was to start (the MOTHERSHIP's toast into the brawl) never starts ----
{
  const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => (e.name.startsWith('.') || e.name === 'assets') ? [] : e.isDirectory() ? walk(path.join(d, e.name)) : e.name.endsWith('.gd') ? [path.join(d, e.name)] : []);
  for (const f of walk(ROOT)) {
    const src = fs.readFileSync(f, 'utf8');
    if (/"on_(start|end)":\s*func\(\s*\)/.test(src)) fail(path.relative(ROOT, f) + ': a talker\'s on_start / on_end lambda must take the talker: func(_t: Dictionary)');
    if (/"on_exit":\s*func\([^,)]*:\s*Vehicles\.Veh\)/.test(src)) fail(path.relative(ROOT, f) + ': a vehicle\'s on_exit is called with (veh, force): the lambda must take both');
  }
}

// ---- the game boots ----
if (!quick) {
  const r = spawnSync(GODOT, ['--headless', '--path', ROOT, '--quit-after', '120'], { encoding: 'utf8', maxBuffer: 1 << 28, timeout: 300000 });
  const out = clean((r.stdout || '') + (r.stderr || ''));
  const errs = out.split('\n').filter((l) => /SCRIPT ERROR|^ERROR:|Parse Error|Compile Error/i.test(l) && !/headless/i.test(l));
  for (const l of errs.slice(0, 40)) fail('boot: ' + l.trim());
}

// ---- movement parity with the three.js game (--parity): replays tools/golden in the arena, headless ----
if (process.argv.includes('--parity')) {
  const port = 9399, ev = `return (load("res://tools/golden/replay.gd").new()).run()`;
  const game = spawn(GODOT, ['--headless', '--path', ROOT, '--', `--peek=${port}`, '--level=arena'], { stdio: 'ignore' });
  let txt = '';
  for (let i = 0; i < 60 && !txt.includes('WORST'); i++) {
    await new Promise((r) => setTimeout(r, 1000));
    const r = spawnSync('node', [path.join(ROOT, 'tools/peek.mjs'), 'eval', ev], { encoding: 'utf8', env: { ...process.env, PEEK_PORT: String(port) }, timeout: 120000 });
    txt = (r.stdout || '');
  }
  spawnSync('node', [path.join(ROOT, 'tools/peek.mjs'), 'quit'], { env: { ...process.env, PEEK_PORT: String(port) } });
  game.kill();
  const m = txt.match(/WORST body ([\d.]+) m, camera ([\d.]+) m/);
  console.log(m ? `parity: ${m[0]}` : 'parity: no result');
  if (!m) fail('parity run produced no result');
  else if (+m[1] > 0.2) fail(`movement drifted from the three.js game: ${m[0]}\n${txt}`);
}

// ---- an exported level against the three.js game (--level-proof <id>): the World's answers on the points the exporter recorded, the walk, the cost (tools/export/level_probe.gd) ----
{
  const i = process.argv.indexOf('--level-proof');
  if (i > 0) {
    const r = spawnSync('node', [path.join(ROOT, 'tools/export/export.mjs'), 'check', process.argv[i + 1]], { encoding: 'utf8', maxBuffer: 1 << 26, timeout: 600000 });
    console.log(r.stdout || '');
    const m = /ground: (\d+) points, (\d+) mismatches/.exec(r.stdout || '');
    if (!m) fail('level check produced no result');
    else if (+m[2] > +m[1] * 0.01) fail(`${process.argv[i + 1]}: ground differs from the JS World at ${m[2]} of ${m[1]} points`);
  }
}

if (fails) { console.log(`${fails} problems`); process.exit(1); }
console.log('all checks passed');
