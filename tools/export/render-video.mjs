// Turns a video into files Godot can play (it has no MP4 decoder and this machine has no ffmpeg): the browser decodes it. <out>.frames = [u32 count, u32 fps*1000, u32 w, u32 h, then per frame u32 byte length + its JPEG bytes], <out>.wav = the sound (played by props/video_frames.gd).
//   node tools/export/render-video.mjs                    the gunshop TV: assets/video/gunshop.mp4 -> gunshop.frames + gunshop.wav, 15 fps, 320 wide
//   node tools/export/render-video.mjs <src> <out.frames> [--fps 15] [--width 320] [--quality 0.72] [--no-audio]
//   node tools/export/render-video.mjs <src> --probe      size, length and frame rate only
// Changed 2026-11-18: takes a source, an output and the settings, so the FOINT CITY billboard ad (assets/video/alien_times_square.frames, no sound) is made by the same tool.
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

const argv = process.argv.slice(2), pos = [], opt = {};
for (let i = 0; i < argv.length; i++) {
  if (argv[i].startsWith('--')) { const k = argv[i].slice(2); opt[k] = (argv[i + 1] && !argv[i + 1].startsWith('--')) ? argv[++i] : true; } else pos.push(argv[i]);
}
const src = path.resolve(PROJECT, pos[0] || 'assets/video/gunshop.mp4');
const out = path.resolve(PROJECT, pos[1] || 'assets/video/gunshop.frames');
const FPS = +(opt.fps || 15), W = +(opt.width || 320) & ~1, Q = +(opt.quality || 0.72);
const AUDIO = !opt['no-audio'];

const browser = await pw.chromium.launch({ headless: true, channel: process.env.PROG_BROWSER || 'msedge', args: ['--autoplay-policy=no-user-gesture-required'] });
const page = await browser.newPage();
await page.route('http://local.test/**', (r) => r.fulfill({ body: fs.readFileSync(src), contentType: 'video/mp4', headers: { 'Access-Control-Allow-Origin': '*', 'Accept-Ranges': 'bytes' } }));
await page.goto('about:blank');
await page.setContent('<video id="v" muted playsinline crossorigin="anonymous" src="http://local.test/video.mp4"></video><canvas id="c"></canvas>');
const meta = await page.evaluate(async () => { const v = document.getElementById('v'); if (v.readyState < 2) await new Promise((r, x) => { v.onloadeddata = r; v.onerror = () => x(new Error('video error')); }); return { d: v.duration, w: v.videoWidth, h: v.videoHeight }; });
if (opt.probe) {      // the source's own frame rate: play a second of it and time the frames
  meta.fps = await page.evaluate(async () => { const v = document.getElementById('v'), ts = []; await new Promise((r) => { const f = (_n, m) => { ts.push(m.mediaTime); if (ts.length < 40) v.requestVideoFrameCallback(f); else r(); }; v.requestVideoFrameCallback(f); v.play(); setTimeout(r, 4000); }); v.pause(); const d = []; for (let i = 1; i < ts.length; i++) if (ts[i] > ts[i - 1]) d.push(ts[i] - ts[i - 1]); d.sort((a, b) => a - b); return d.length ? +(1 / d[d.length >> 1]).toFixed(3) : null; });
  console.log(JSON.stringify(meta));
  await browser.close();
  process.exit(0);
}
const H = Math.round(W * meta.h / meta.w) & ~1, n = Math.floor(meta.d * FPS + 1e-6);
console.log('video', JSON.stringify(meta), 'frames', n, `${W}x${H}`, 'fps', FPS);
const chunks = [], head = Buffer.alloc(16); head.writeUInt32LE(n, 0); head.writeUInt32LE(Math.round(FPS * 1000), 4); head.writeUInt32LE(W, 8); head.writeUInt32LE(H, 12); chunks.push(head);
for (let i = 0; i < n; i++) {
  const url = await page.evaluate(async ([t, w, h, q]) => { const v = document.getElementById('v'), c = document.getElementById('c'); c.width = w; c.height = h; v.currentTime = t; await new Promise((r) => { v.onseeked = r; }); const g = c.getContext('2d'); g.imageSmoothingQuality = 'high'; g.drawImage(v, 0, 0, w, h); return c.toDataURL('image/jpeg', q); }, [i / FPS, W, H, Q]);
  const b = Buffer.from(url.split(',')[1], 'base64'), l = Buffer.alloc(4); l.writeUInt32LE(b.length, 0); chunks.push(l, b);
}
fs.writeFileSync(out, Buffer.concat(chunks));
const wav = out.replace(/\.frames$/, '.wav');
const b64 = !AUDIO ? null : await page.evaluate(async () => { const ab = await (await fetch('http://local.test/video.mp4')).arrayBuffer(), c = new OfflineAudioContext(1, 1, 44100), buf = await c.decodeAudioData(ab); const n = buf.length, ch = buf.getChannelData(0), u = new Int16Array(n); for (let i = 0; i < n; i++) u[i] = Math.max(-32767, Math.min(32767, Math.round(ch[i] * 32767))); let bin = ''; const by = new Uint8Array(u.buffer); for (let i = 0; i < by.length; i += 8192) bin += String.fromCharCode.apply(null, by.subarray(i, i + 8192)); return { d: btoa(bin), sr: buf.sampleRate }; }).catch((e) => { console.log('no audio', String(e).slice(0, 100)); return null; });
if (b64) { const pcm = Buffer.from(b64.d, 'base64'), h = Buffer.alloc(44); h.write('RIFF', 0); h.writeUInt32LE(36 + pcm.length, 4); h.write('WAVEfmt ', 8); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(b64.sr, 24); h.writeUInt32LE(b64.sr * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34); h.write('data', 36); h.writeUInt32LE(pcm.length, 40); fs.writeFileSync(wav, Buffer.concat([h, pcm])); }
await browser.close();
console.log('done', path.relative(PROJECT, out), fs.statSync(out).size);
