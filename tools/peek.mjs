// Peek: keep one game open and drive it (Godot twin of tests/lib/peek.cjs). Never boot the game repeatedly; use this.
//   node tools/peek.mjs start [level]     start the game windowed and off-screen, prints READY
//   node tools/peek.mjs eval "<gdscript>" run a function body inside the game (may await); `return x` prints x
//   node tools/peek.mjs run <file.gd>     same, body read from a file
//   node tools/peek.mjs shot [width]      screenshot into a temp folder, prints the path (look once, never keep)
//   node tools/peek.mjs frames <n>        wait n rendered frames
//   node tools/peek.mjs logs              errors / prints since the last call
//   node tools/peek.mjs restart [level]   after a change that hot reload cannot take
//   node tools/peek.mjs quit              asks the game to quit, waits for it to be gone, and ends it if it hangs (a game left running keeps rendering
//                                         off screen: four of them once pinned the GPU and made every timing worthless)
import net from 'node:net';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const GODOT = process.env.PROG_GODOT || 'F:/godot/Godot_v4.7.2-stable_win64_console.exe';
const PROJECT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PORT = +(process.env.PEEK_PORT || 9231);
const TMP = path.join(process.env.PEEK_TMP || 'F:/prog-godot-cache/tmp', 'prog-peek');   // on F: because C: is nearly full
fs.mkdirSync(TMP, { recursive: true });
const LOG = path.join(TMP, `game-${PORT}.log`);
const PIDFILE = path.join(TMP, `game-${PORT}.pid`);      // the game this port's peek started (its console wrapper: ending it with /T ends the game)

function send(obj, timeoutMs = 120000) {
  return new Promise((resolve, reject) => {
    const s = net.connect(PORT, '127.0.0.1');
    let buf = '';
    const t = setTimeout(() => { s.destroy(); reject(new Error('timeout')); }, timeoutMs);
    s.on('connect', () => s.write(JSON.stringify(obj) + '\n'));
    s.on('data', (d) => { buf += d; if (buf.includes('\n')) { clearTimeout(t); s.destroy(); resolve(JSON.parse(buf.split('\n')[0])); } });
    s.on('error', (e) => { clearTimeout(t); reject(e); });
    s.on('close', () => { clearTimeout(t); if (!buf.includes('\n')) reject(new Error('connection closed')); });
  });
}

function show(r) {
  if (r.logs) for (const l of r.logs) console.log(l);
  if (r.error) console.log('ERROR: ' + r.error);
  if (r.value !== undefined && r.value !== 'null') console.log(r.value);
  if (r.path) console.log(r.path);
}

async function waitReady(ms) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) {
    try { const r = await send({ cmd: 'logs' }, 3000); if (r.ok) return true; } catch { /* not up yet */ }
    await new Promise((r) => setTimeout(r, 250));
  }
  return false;
}

// is this process id still a Godot game? (a pid file can outlive its game, and Windows reuses ids: never end a process that is not one)
function isGodot(pid) {
  if (!pid) return false;
  if (process.platform !== 'win32') { try { process.kill(pid, 0); return true; } catch { return false; } }
  const r = spawnSync('tasklist', ['/FI', `PID eq ${pid}`, '/NH', '/FO', 'CSV'], { encoding: 'utf8' });
  return /godot/i.test(r.stdout || '');
}

// quit the game and make sure it is gone: ask it, wait up to 15 s (the hub takes a while to free), then end it
async function stop() {
  let said = null;
  try { said = await send({ cmd: 'quit' }, 3000); } catch { /* not answering */ }
  const pid = fs.existsSync(PIDFILE) ? +fs.readFileSync(PIDFILE, 'utf8') : 0;
  const t0 = Date.now();
  while (isGodot(pid) && Date.now() - t0 < 15000) await new Promise((r) => setTimeout(r, 300));
  let ended = false;
  if (isGodot(pid)) {
    if (process.platform === 'win32') spawnSync('taskkill', ['/PID', String(pid), '/T', '/F']);
    else { try { process.kill(pid, 'SIGKILL'); } catch { /* gone */ } }
    ended = true;
  }
  fs.rmSync(PIDFILE, { force: true });
  return said ? (ended ? 'quit asked; it hung, ended' : 'quit') : (ended ? 'not answering; ended' : 'not running');
}

async function start(level) {
  try { if ((await send({ cmd: 'logs' }, 1500)).ok) { console.log('already running'); return; } } catch { /* start it */ }
  const out = fs.openSync(LOG, 'w');
  const args = ['--path', PROJECT, '--windowed', '--resolution', process.env.PEEK_RES || '1280x720', '--position', process.env.PEEK_POS || '-3000,100', '--', `--peek=${PORT}`];
  if (level) args.push(`--level=${level}`);
  const ch = spawn(GODOT, args, { detached: true, stdio: ['ignore', out, out], windowsHide: true });
  ch.unref();
  fs.writeFileSync(PIDFILE, String(ch.pid));
  if (await waitReady(180000)) console.log('READY'); else { console.log('NOT READY, log tail:'); console.log(fs.readFileSync(LOG, 'utf8').slice(-3000)); process.exit(1); }
}

const [cmd, ...a] = process.argv.slice(2);
try {
  switch (cmd) {
    case 'start': await start(a[0]); break;
    case 'restart': await stop(); await start(a[0]); break;
    case 'quit': console.log(await stop()); break;
    case 'eval': show(await send({ cmd: 'eval', code: a.join(' ') })); break;
    case 'run': show(await send({ cmd: 'eval', code: fs.readFileSync(a[0], 'utf8') })); break;
    case 'frames': show(await send({ cmd: 'frames', n: +a[0] || 1 })); break;
    case 'logs': show(await send({ cmd: 'logs' })); break;
    case 'shot': show(await send({ cmd: 'shot', path: path.join(TMP, `shot-${Date.now()}.png`).replaceAll('\\', '/'), w: +a[0] || 0 })); break;
    default: console.log(fs.readFileSync(fileURLToPath(import.meta.url), 'utf8').split('\n').slice(0, 11).join('\n'));
  }
} catch (e) { console.log('peek: ' + e.message); process.exit(1); }
