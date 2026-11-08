// Import new or changed assets, one worker at a time: node tools/import.mjs
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const GODOT = process.env.PROG_GODOT || 'F:/godot/Godot_v4.7.2-stable_win64_console.exe';
const PROJECT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const LOCK = 'F:/prog-godot-cache/import.lock';
const t0 = Date.now();
for (;;) {
  try { fs.closeSync(fs.openSync(LOCK, 'wx')); break; } catch {
    // a stale lock: only one waiter may break it, or every waiter imports at once. The rename succeeds for one; the others land in the catch and go round again
    try { if (Date.now() - fs.statSync(LOCK).mtimeMs > 30 * 60 * 1000) { const old = `${LOCK}.stale.${process.pid}`; fs.renameSync(LOCK, old); fs.rmSync(old, { force: true }); continue; } } catch { continue; }
    if (Date.now() - t0 > 30 * 60 * 1000) { console.log('import: lock held too long'); process.exit(1); }
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1000);
  }
}
try {
  const r = spawnSync(GODOT, ['--headless', '--path', PROJECT, '--import'], { encoding: 'utf8', maxBuffer: 1 << 28 });
  const out = (r.stdout || '') + (r.stderr || '');
  const bad = out.split('\n').filter((l) => /ERROR|Failed|error:/i.test(l) && !/reimport \|/.test(l));
  for (const l of bad.slice(0, 40)) console.log(l.replace(/\x1b\[[0-9;]*m/g, '').trim());
  console.log(`import done in ${((Date.now() - t0) / 1000).toFixed(0)} s, ${bad.length} error lines`);
} finally { fs.rmSync(LOCK, { force: true }); }
