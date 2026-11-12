// Godot cannot play Opus inside Ogg (it reads Vorbis only). The JS game's track is decoded by the browser, then Blender (the one encoder on this machine) writes it as Ogg Vorbis at the port's path. A 14 minute WAV would be 141 MB.
//   node tools/export/render-music.mjs
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const PROJECT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const JS = (await import('../js_root.mjs')).JS_ROOT;
const require = createRequire(path.join(JS, 'tests/render-fx-tex.cjs'));
const fsrt = 'C:/Users/12147/AppData/Local/OpenAI/Codex/runtimes';
const tries = [process.env.PROG_PLAYWRIGHT, 'C:/Users/12147/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright', 'playwright'];
try { for (const d of fs.readdirSync(fsrt)) tries.unshift(path.join(fsrt, d, 'bin/node_modules/playwright')); } catch { /* no runtime here */ }
let pw = null;
for (const t of tries) { if (!t) continue; try { pw = require(t); break; } catch { /* next */ } }
if (!pw) throw new Error('Playwright not found: set PROG_PLAYWRIGHT');
const TRACKS = [['levels/maktar/music/death-lessons.ogg', 'assets/music/death-lessons.ogg']];
const BLENDER = process.env.PROG_BLENDER || 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe';
const SCRATCH = process.env.PROG_SCRATCH || 'F:/prog-godot-cache/tmp';
const browser = await pw.chromium.launch({ headless: true, channel: process.env.PROG_BROWSER || 'msedge' });
const page = await browser.newPage();
await page.route('http://local.test/**', (q) => q.fulfill({ body: fs.readFileSync(path.join(JS, new URL(q.request().url()).pathname)), contentType: 'audio/ogg', headers: { 'Access-Control-Allow-Origin': '*' } }));
await page.goto('about:blank');
for (const [rel, out] of TRACKS) {
  const info = await page.evaluate(async (u) => {
    const ab = await (await fetch(u)).arrayBuffer(), c = new OfflineAudioContext(2, 1, 44100), b = await c.decodeAudioData(ab);
    const chs = Math.min(2, b.numberOfChannels), n = b.length, out = new Int16Array(n * chs);
    for (let ch = 0; ch < chs; ch++) { const d = b.getChannelData(ch); for (let i = 0; i < n; i++) out[i * chs + ch] = Math.max(-32767, Math.min(32767, Math.round(d[i] * 32767))); }
    window.__pcm = new Uint8Array(out.buffer); return { n, chs, sr: b.sampleRate, size: window.__pcm.length };
  }, 'http://local.test/' + rel);
  const dst = path.join(SCRATCH, path.basename(rel).replace(/\.[^.]+$/, '.wav'));
  const fd = fs.openSync(dst, 'w'), h = Buffer.alloc(44);
  h.write('RIFF', 0); h.writeUInt32LE(36 + info.size, 4); h.write('WAVEfmt ', 8); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(info.chs, 22); h.writeUInt32LE(info.sr, 24); h.writeUInt32LE(info.sr * info.chs * 2, 28); h.writeUInt16LE(info.chs * 2, 32); h.writeUInt16LE(16, 34); h.write('data', 36); h.writeUInt32LE(info.size, 40);
  fs.writeSync(fd, h);
  const CHUNK = 4 << 20;
  for (let at = 0; at < info.size; at += CHUNK) {
    const b64 = await page.evaluate(([a, c]) => { const s = window.__pcm.subarray(a, a + c); let t = ''; for (let i = 0; i < s.length; i += 8192) t += String.fromCharCode.apply(null, s.subarray(i, i + 8192)); return btoa(t); }, [at, CHUNK]);
    fs.writeSync(fd, Buffer.from(b64, 'base64'));
  }
  fs.closeSync(fd);
  const target = path.join(PROJECT, out).replace(/\\/g, '/'), py = path.join(SCRATCH, 'mixdown.py');
  fs.writeFileSync(py, `import aud
aud.Sound.file(r'${dst.replace(/\\/g, '/')}').write(r'${target}', rate=${info.sr}, channels=aud.CHANNELS_STEREO, format=aud.FORMAT_S16, container=aud.CONTAINER_OGG, codec=aud.CODEC_VORBIS, bitrate=96000)
`);
  const r = spawnSync(BLENDER, ['-b', '--factory-startup', '--python-exit-code', '1', '--python', py], { encoding: 'utf8', maxBuffer: 1 << 26 });
  if (r.status !== 0) { console.log(String(r.stdout).slice(-800), String(r.stderr).slice(-800)); throw new Error('blender mixdown failed'); }
  fs.rmSync(dst); fs.rmSync(py);
  console.log(rel, '->', out, (info.n / info.sr).toFixed(1) + ' s', info.chs + ' ch', info.sr + ' Hz', (fs.statSync(target).size / 1048576).toFixed(1) + ' MB');
}
await browser.close();
