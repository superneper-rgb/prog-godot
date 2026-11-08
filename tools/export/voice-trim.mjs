// Measures the dead air of the cutscene voice recordings (JS cutscenes/voice-clips.js trim: threshold 0.012, 0.04 s lead-in, 0.12 s tail) and writes assets/sfx/voice_trim.json: { "<dir>/<file>": [start seconds, length seconds] }. Godot cannot read an MP3's samples, so the browser does it.
//   node tools/export/voice-trim.mjs
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const PROJECT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const JS = path.resolve(PROJECT, '../progalpha-20261016T082732Z-1-001/progalpha');
const require = createRequire(path.join(JS, 'tests/render-fx-tex.cjs'));
const fsrt = 'C:/Users/12147/AppData/Local/OpenAI/Codex/runtimes';
const tries = [process.env.PROG_PLAYWRIGHT, 'C:/Users/12147/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright', 'playwright'];
try { for (const d of fs.readdirSync(fsrt)) tries.unshift(path.join(fsrt, d, 'bin/node_modules/playwright')); } catch { /* no runtime here */ }
let pw = null;
for (const t of tries) { if (!t) continue; try { pw = require(t); break; } catch { /* next */ } }
if (!pw) throw new Error('Playwright not found: set PROG_PLAYWRIGHT');
const SFX = path.join(PROJECT, 'assets/sfx');
const files = [];
for (const d of fs.readdirSync(SFX, { withFileTypes: true })) {
  if (!d.isDirectory() || d.name === 'synth') continue;
  for (const f of fs.readdirSync(path.join(SFX, d.name))) if (/\.(mp3|wav)$/.test(f) && !/^(ad\d|engine|horn|tick|siren|noise|steam|thunder|whine)/.test(f)) files.push(d.name + '/' + f);
}
const browser = await pw.chromium.launch({ headless: true, channel: process.env.PROG_BROWSER || 'msedge' });
const page = await browser.newPage();
const out = {};
for (const rel of files) {
  const b64 = fs.readFileSync(path.join(SFX, rel)).toString('base64');
  const r = await page.evaluate(async (b) => {
    const bin = atob(b), u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i);
    const c = new OfflineAudioContext(1, 1, 44100), buf = await c.decodeAudioData(u.buffer), ch = buf.getChannelData(0), n = buf.length, thr = 0.012;
    let a = 0, e = n - 1;
    while (a < n && Math.abs(ch[a]) < thr) a++;
    while (e > a && Math.abs(ch[e]) < thr) e--;
    a = Math.max(0, a - Math.round(buf.sampleRate * 0.04)); e = Math.min(n - 1, e + Math.round(buf.sampleRate * 0.12));
    return [+(a / buf.sampleRate).toFixed(4), +((e - a + 1) / buf.sampleRate).toFixed(4)];
  }, b64).catch(() => null);
  if (r) out[rel] = r;
}
await browser.close();
fs.writeFileSync(path.join(SFX, 'voice_trim.json'), JSON.stringify(out, null, 0));
console.log('measured ' + Object.keys(out).length + ' recordings');
