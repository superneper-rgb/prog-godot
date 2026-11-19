// Fetches the Sigil's raw takes from Fish Audio (free model, WAV) into the scratch folder: node tools/underfoint_audio/fish_fetch.mjs [--only id,id] [--force] [--voice <reference_id>] [--speed s] [--tag name] [--text "..." --id name]
// The key is FISH_API_KEY from the environment or the progectalp2 .env.local, read as tools/apis.mjs does and never printed. Scratch: F:/prog-godot-cache/underfoint-audio (UF_AUDIO_SCRATCH), never the project.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SCRATCH = process.env.UF_AUDIO_SCRATCH || 'F:/prog-godot-cache/underfoint-audio';
const ENV_FILES = ['C:/Users/12147/Documents/GitHub/progectalp2/.env.local'];
const argv = process.argv.slice(2);
const flag = (k, d) => { const i = argv.indexOf('--' + k); return i >= 0 ? argv[i + 1] : d; };
function key(name) {
  if (process.env[name]) return process.env[name];
  for (const f of ENV_FILES) {
    if (!fs.existsSync(f)) continue;
    const m = fs.readFileSync(f, 'utf8').match(new RegExp(`^${name}=(.+)$`, 'm'));
    if (m) return m[1].trim();
  }
  throw new Error(`${name} not found`);
}
// Fish streams its WAV with 0xFFFFFFFF sizes: write the real ones so every reader takes it
function fixWav(b) {
  const data = b.indexOf('data', 12);
  if (b.toString('ascii', 0, 4) !== 'RIFF' || data < 0) return b;
  b.writeUInt32LE(b.length - 8, 4);
  b.writeUInt32LE(b.length - data - 8, data + 4);
  return b;
}
const cfg = JSON.parse(fs.readFileSync(path.join(HERE, 'lines.json'), 'utf8'));
let lines = cfg.lines;
if (flag('text')) lines = [{ id: flag('id', 'test'), text: flag('text'), style: flag('style', 'calm') }];
const only = (flag('only', '') || '').split(',').filter(Boolean);
if (only.length) lines = lines.filter((l) => only.includes(l.id));
const voice = flag('voice', cfg.voice);
const out = path.join(SCRATCH, flag('tag', 'raw'));
fs.mkdirSync(out, { recursive: true });
const speedOf = (l) => +flag('speed', l.speed ?? (l.style === 'shout' ? 0.95 : 0.88));      // (long calm lines carry their own, slower)
const auth = { Authorization: 'Bearer ' + key('FISH_API_KEY'), model: 's2.1-pro-free', 'Content-Type': 'application/json' };
async function one(l) {
  const file = path.join(out, l.id + '.wav');
  if (!argv.includes('--force') && fs.existsSync(file)) return console.log('have', l.id);
  const body = { text: l.tts || l.text, format: 'wav', reference_id: voice, prosody: { speed: speedOf(l), volume: 0 }, latency: 'normal' };
  for (let a = 0; a < 4; a++) {
    const r = await fetch('https://api.fish.audio/v1/tts', { method: 'POST', headers: auth, body: JSON.stringify(body) }).catch((e) => ({ ok: false, status: 0, text: async () => String(e) }));
    if (r.ok) { fs.writeFileSync(file, fixWav(Buffer.from(await r.arrayBuffer()))); return console.log('got', l.id); }
    console.log('retry', l.id, r.status, (await r.text()).slice(0, 160));
    await new Promise((res) => setTimeout(res, 1500 * (a + 1)));
  }
  console.log('FAILED', l.id);
}
const q = [...lines];
await Promise.all([0, 1, 2].map(async () => { while (q.length) await one(q.shift()); }));
