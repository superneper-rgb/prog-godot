// Runs the rebuilt Prog's test bench off screen: node tools/prog3_bench/run.mjs check (every clip against the file's own numbers) | shots <list.json> (photographs into the temp folder)
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const GODOT = process.env.PROG_GODOT || 'F:/godot/Godot_v4.7.2-stable_win64_console.exe';
const PROJECT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const TMP = 'F:/prog-godot-cache/tmp/prog3-bench';
fs.mkdirSync(TMP, { recursive: true });
const WATCH = ['pelvis', 'chest', 'head', 'hand.L', 'hand.R', 'foot.L', 'foot.R', 'index_3.R', 'upper_arm.L', 'belly'];

// Where each watched bone should be half way through each clip, walked down the chain from the GLB without Godot
function expected() {
  const raw = fs.readFileSync(path.join(PROJECT, 'assets/prog3/prog3_moves.glb'));
  const n = raw.readUInt32LE(12); const J = JSON.parse(raw.toString('utf8', 20, 20 + n)); const bin = 20 + n + 8;
  const W = { SCALAR: 1, VEC3: 3, VEC4: 4 };
  const acc = (i) => { const a = J.accessors[i]; const w = W[a.type]; return (k) => Array.from({ length: w }, (_, c) => raw.readFloatLE(bin + 8 - 8 + a.byteOffset + (k * w + c) * 4)); };
  const rot = ([x, y, z, w], [a, b, c]) => { const tx = 2 * (y * c - z * b), ty = 2 * (z * a - x * c), tz = 2 * (x * b - y * a); return [a + w * tx + y * tz - z * ty, b + w * ty + z * tx - x * tz, c + w * tz + x * ty - y * tx]; };
  const mul = ([x, y, z, w], [a, b, c, d]) => [w * a + x * d + y * c - z * b, w * b - x * c + y * d + z * a, w * c + x * b - y * a + z * d, w * d - x * a - y * b - z * c];
  const par = {}; J.nodes.forEach((nd, i) => (nd.children || []).forEach((c) => { par[c] = i; }));
  const byName = Object.fromEntries(J.nodes.map((nd, i) => [nd.name, i]));
  const out = {};
  for (const an of J.animations) {
    const count = Math.max(1, ...an.channels.map((c) => J.accessors[an.samplers[c.sampler].input].count));
    const k = Math.floor(count / 2); const vals = {};
    for (const ch of an.channels) { const o = an.samplers[ch.sampler].output; vals[`${ch.target.node}/${ch.target.path}`] = acc(o)(J.accessors[o].count > 1 ? k : 0); }
    const memo = {};
    const world = (i) => {
      if (memo[i]) return memo[i];
      const nd = J.nodes[i]; const t = vals[`${i}/translation`] || nd.translation || [0, 0, 0]; const q = vals[`${i}/rotation`] || nd.rotation || [0, 0, 0, 1];
      if (par[i] === undefined) return (memo[i] = { q, t });
      const p = world(par[i]); const r = rot(p.q, t);
      return (memo[i] = { q: mul(p.q, q), t: [p.t[0] + r[0], p.t[1] + r[1], p.t[2] + r[2]] });
    };
    out[an.name] = { t: k / 24, bones: Object.fromEntries(WATCH.map((b) => [b, world(byName[b]).t])) };
  }
  fs.writeFileSync(path.join(TMP, 'expected.json'), JSON.stringify(out));
}

const mode = process.argv[2] || 'check';
if (mode === 'check') expected();
const arg = mode === 'check' ? 'check' : path.resolve(process.argv[3]);
const r = spawnSync(GODOT, ['--path', PROJECT, '--position', '-4000,0', '--resolution', '640x360', 'res://tools/prog3_bench/prog3_bench.tscn', '--', arg, TMP], { encoding: 'utf8', maxBuffer: 1 << 28, timeout: 300000 });
const lines = ((r.stdout || '') + (r.stderr || '')).split('\n').map((l) => l.replace(/\x1b\[[0-9;]*m/g, '').trim());
for (const l of lines) if (/^BENCH|SCRIPT ERROR|Invalid/.test(l)) console.log(l);
