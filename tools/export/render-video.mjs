// Turns the gunshop TV's video into files Godot can play (it has no MP4 decoder and this machine has no ffmpeg): the browser decodes it. assets/video/gunshop.frames = [u32 count, u32 fps*1000, u32 w, u32 h, then per frame u32 byte length + its JPEG bytes], assets/video/gunshop.wav = the sound.
//   node tools/export/render-video.mjs
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const PROJECT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const JS = (await import('../js_root.mjs')).JS_ROOT;
const require = createRequire(path.join(JS, 'tests/render-fx-tex.cjs'));
const fsrt = 'C:/Users/12147/AppData/Local/OpenAI/Codex/runtimes';
const tries = [process.env.PROG_PLAYWRIGHT, 'C:/Users/12147/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright', 'playwright'];
try { for (const d of fs.readdirSync(fsrt)) tries.unshift(path.join(fsrt, d, 'bin/node_modules/playwright')); } catch { /* no runtime here */ }
let pw = null;
for (const t of tries) { if (!t) continue; try { pw = require(t); break; } catch { /* next */ } }
if (!pw) throw new Error('Playwright not found: set PROG_PLAYWRIGHT');
const FPS = 15, W = 320;
const src = path.join(PROJECT, 'assets/video/gunshop.mp4');
const browser = await pw.chromium.launch({ headless: true, channel: process.env.PROG_BROWSER || 'msedge', args: ['--autoplay-policy=no-user-gesture-required'] });
const page = await browser.newPage();
await page.route('http://local.test/**', (r) => r.fulfill({ body: fs.readFileSync(src), contentType: 'video/mp4', headers: { 'Access-Control-Allow-Origin': '*', 'Accept-Ranges': 'bytes' } }));
await page.goto('about:blank');
await page.setContent('<video id="v" muted playsinline crossorigin="anonymous" src="http://local.test/gunshop.mp4"></video><canvas id="c"></canvas>');
const meta = await page.evaluate(async () => { const v = document.getElementById('v'); if (v.readyState < 2) await new Promise((r, x) => { v.onloadeddata = r; v.onerror = () => x(new Error('video error')); }); return { d: v.duration, w: v.videoWidth, h: v.videoHeight }; });
const H = Math.round(W * meta.h / meta.w) & ~1, n = Math.floor(meta.d * FPS);
console.log('video', JSON.stringify(meta), 'frames', n);
const chunks = [], head = Buffer.alloc(16); head.writeUInt32LE(n, 0); head.writeUInt32LE(FPS * 1000, 4); head.writeUInt32LE(W, 8); head.writeUInt32LE(H, 12); chunks.push(head);
for (let i = 0; i < n; i++) {
  const url = await page.evaluate(async ([t, w, h]) => { const v = document.getElementById('v'), c = document.getElementById('c'); c.width = w; c.height = h; v.currentTime = t; await new Promise((r) => { v.onseeked = r; }); c.getContext('2d').drawImage(v, 0, 0, w, h); return c.toDataURL('image/jpeg', 0.72); }, [i / FPS, W, H]);
  const b = Buffer.from(url.split(',')[1], 'base64'), l = Buffer.alloc(4); l.writeUInt32LE(b.length, 0); chunks.push(l, b);
}
fs.writeFileSync(path.join(PROJECT, 'assets/video/gunshop.frames'), Buffer.concat(chunks));
const b64 = await page.evaluate(async () => { const ab = await (await fetch('http://local.test/gunshop.mp4')).arrayBuffer(), c = new OfflineAudioContext(1, 1, 44100), buf = await c.decodeAudioData(ab); const n = buf.length, ch = buf.getChannelData(0), u = new Int16Array(n); for (let i = 0; i < n; i++) u[i] = Math.max(-32767, Math.min(32767, Math.round(ch[i] * 32767))); let bin = ''; const by = new Uint8Array(u.buffer); for (let i = 0; i < by.length; i += 8192) bin += String.fromCharCode.apply(null, by.subarray(i, i + 8192)); return { d: btoa(bin), sr: buf.sampleRate }; }).catch((e) => { console.log('no audio', String(e).slice(0, 100)); return null; });
if (b64) { const pcm = Buffer.from(b64.d, 'base64'), h = Buffer.alloc(44); h.write('RIFF', 0); h.writeUInt32LE(36 + pcm.length, 4); h.write('WAVEfmt ', 8); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(b64.sr, 24); h.writeUInt32LE(b64.sr * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34); h.write('data', 36); h.writeUInt32LE(pcm.length, 40); fs.writeFileSync(path.join(PROJECT, 'assets/video/gunshop.wav'), Buffer.concat([h, pcm])); }
await browser.close();
console.log('done', fs.statSync(path.join(PROJECT, 'assets/video/gunshop.frames')).size);
