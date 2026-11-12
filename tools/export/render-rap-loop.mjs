// Cuts the saucer's rap loop out of its track the way the JS rap-loop.js does when it starts (peak: the loudest 8 seconds at or after minStart, on half-second blocks). The port cannot read PCM from an MP3 at run time and an MP3 cannot loop a window, so the window is written once as a WAV: assets/sfx/beatdown-kontraamusic-369.loop.wav.
//   node tools/export/render-rap-loop.mjs
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
const SRC = path.join(PROJECT, 'assets/sfx/beatdown-kontraamusic-369.mp3');
const browser = await pw.chromium.launch({ headless: true, channel: process.env.PROG_BROWSER || 'msedge' });
const page = await browser.newPage();
const r = await page.evaluate(async ([b64, minStart]) => {
  const bin = atob(b64), ab = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) ab[i] = bin.charCodeAt(i);
  const c = new OfflineAudioContext(2, 1, 44100), buffer = await c.decodeAudioData(ab.buffer);
  const blockSize = Math.max(1, Math.floor(buffer.sampleRate * 0.5)), energies = [];
  for (let start = 0; start < buffer.length; start += blockSize) {
    const end = Math.min(buffer.length, start + blockSize); let sum = 0, count = 0;
    for (let ch = 0; ch < buffer.numberOfChannels; ch++) { const data = buffer.getChannelData(ch); for (let i = start; i < end; i++) { sum += data[i] * data[i]; count++; } }
    energies.push(sum / Math.max(1, count));
  }
  const windowBlocks = Math.min(energies.length, Math.round(8 * buffer.sampleRate / blockSize));
  const minBlock = Math.max(0, Math.floor(minStart * buffer.sampleRate / blockSize));
  let bestStart = minBlock, bestEnergy = -1, sum = 0;
  for (let i = minBlock; i < minBlock + windowBlocks; i++) sum += energies[i];
  bestEnergy = sum;
  for (let i = minBlock + 1; i + windowBlocks <= energies.length; i++) { sum += energies[i + windowBlocks - 1] - energies[i - 1]; if (sum > bestEnergy) { bestEnergy = sum; bestStart = i; } }
  const a = bestStart * blockSize, b = Math.min(buffer.length, (bestStart + windowBlocks) * blockSize), n = b - a, chs = Math.min(2, buffer.numberOfChannels), u = new Int16Array(n * chs);
  for (let ch = 0; ch < chs; ch++) { const d = buffer.getChannelData(ch); for (let i = 0; i < n; i++) u[i * chs + ch] = Math.max(-32767, Math.min(32767, Math.round(d[a + i] * 32767))); }
  let s = ''; const by = new Uint8Array(u.buffer); for (let i = 0; i < by.length; i += 8192) s += String.fromCharCode.apply(null, by.subarray(i, i + 8192));
  return { pcm: btoa(s), sr: buffer.sampleRate, chs, from: a / buffer.sampleRate, to: b / buffer.sampleRate, duration: buffer.duration };
}, [fs.readFileSync(SRC).toString('base64'), 12.5]);
await browser.close();
const pcm = Buffer.from(r.pcm, 'base64'), h = Buffer.alloc(44);
h.write('RIFF', 0); h.writeUInt32LE(36 + pcm.length, 4); h.write('WAVEfmt ', 8); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(r.chs, 22); h.writeUInt32LE(r.sr, 24); h.writeUInt32LE(r.sr * r.chs * 2, 28); h.writeUInt16LE(r.chs * 2, 32); h.writeUInt16LE(16, 34); h.write('data', 36); h.writeUInt32LE(pcm.length, 40);
fs.writeFileSync(SRC.replace(/\.mp3$/, '.loop.wav'), Buffer.concat([h, pcm]));
console.log('track', r.duration.toFixed(2), 's, loop', r.from.toFixed(2), '-', r.to.toFixed(2), 's,', r.chs, 'channels at', r.sr);
