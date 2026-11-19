// Rebuilds every sound of UNDERFOINT's chase: node tools/underfoint_audio/build.mjs [--force] [--no-import]
// 1. Fish takes of the Sigil's lines (lines.json) and the moans, scream and growl the beast is made from, into the scratch folder (F:/prog-godot-cache/underfoint-audio, UF_AUDIO_SCRATCH)
// 2. the project's own effects it borrows from (assets/sfx/omnisphere, assets/sfx/frug-showdown) decoded to WAV there
// 3. sigil_voice.py: the voice chain -> assets/sfx/underfoint/sigil-*.wav   4. sfx.py: beast-*, train-*, crash-*.wav   5. node tools/import.mjs
// Nothing but the finished WAVs lands in the project. The music (assets/music/hyperreal-apocalypse.mp3) is a download, not built here: see assets/third-party/CREDITS.json.
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '../..');
const SCRATCH = process.env.UF_AUDIO_SCRATCH || 'F:/prog-godot-cache/underfoint-audio';
const force = process.argv.includes('--force') ? ['--force'] : [];
const run = (cmd, args) => {
  const r = spawnSync(cmd, args, { stdio: 'inherit', cwd: ROOT });
  if (r.status !== 0) throw new Error(`${cmd} ${args.join(' ')} failed`);
};
// raw material: [file, Fish voice, text, speed] (generic library voices, never clones of real people)
const MATERIAL = [
  ['moan-horror-o', 'ef9c79b62ef34530bf452c0e50e3c260', 'Ohhhhhhhhhhhhhh...', 0.8], ['moan-horror-a', 'ef9c79b62ef34530bf452c0e50e3c260', 'Aaaaaaaaaahhhhhh...', 0.8],
  ['moan-adrian-o', 'bf322df2096a46f18c579d0baa36f41d', 'Ohhhhhhhhhhhhhh...', 0.8], ['moan-adrian-a', 'bf322df2096a46f18c579d0baa36f41d', 'Aaaaaaaaaahhhhhh...', 0.8],
  ['moan-analog-o', '502eaf4758c348a6bf0b1686647f8c77', 'Ohhhhhhhhhhhhhh...', 0.8], ['moan-analog-a', '502eaf4758c348a6bf0b1686647f8c77', 'Aaaaaaaaaahhhhhh...', 0.8],
  ['moan-robot-o', '175d7d5358b644d2ad2e8b7e4e13ece3', 'Ohhhhhhhhhhhhhh...', 0.8], ['moan-robot-a', '175d7d5358b644d2ad2e8b7e4e13ece3', 'Aaaaaaaaaahhhhhh...', 0.8],
  ['moan-devesto-o', '95506b329b1f482495afa3c9f9294a6f', 'Ohhhhhhhhhhhhhh...', 0.8], ['moan-devesto-a', '95506b329b1f482495afa3c9f9294a6f', 'Aaaaaaaaaahhhhhh...', 0.8],
  ['scream-a', 'f4594f5451c048fe85841c94e879a940', 'AAAAAAAAAAAAAAAAHHHHHHHHHH!', 1.0], ['growl-a', '9ef1568dbcb041969b70f17a83a2d9a9', 'Grrrrrrraaaaaaaaaaaahhhhhh!', 0.9],
];
const BORROWED = ['omnisphere/boom-big', 'omnisphere/boom', 'omnisphere/detonate', 'omnisphere/implode', 'omnisphere/sphere-break', 'omnisphere/sphere-groan', 'omnisphere/groan', 'omnisphere/em-blow',
  'omnisphere/bolt', 'omnisphere/arc', 'omnisphere/sparks', 'omnisphere/cable-taut', 'omnisphere/lift-snap', 'omnisphere/lift-start', 'omnisphere/ff-land', 'omnisphere/ff-tug-hit', 'omnisphere/harpoon',
  'frug-showdown/roar', 'frug-showdown/scream', 'frug-showdown/huff', 'frug-showdown/tackle', 'frug-showdown/charge'];

run('node', [path.join(HERE, 'fish_fetch.mjs'), ...force]);
for (const [id, voice, text, speed] of MATERIAL) run('node', [path.join(HERE, 'fish_fetch.mjs'), '--tag', 'moan', '--id', id, '--voice', voice, '--text', text, '--speed', String(speed), ...force]);
const dec = [];
for (const b of BORROWED) {
  const out = path.join(SCRATCH, 'src', path.basename(b) + '.wav');
  if (force.length || !fs.existsSync(out)) dec.push(path.join(ROOT, 'assets/sfx', b + '.mp3'), out);
}
if (dec.length) run('node', [path.join(HERE, 'decode.mjs'), ...dec]);
run('python', ['-I', path.join(HERE, 'sigil_voice.py')]);
run('python', ['-I', path.join(HERE, 'sfx.py')]);
if (!process.argv.includes('--no-import')) run('node', [path.join(ROOT, 'tools/import.mjs')]);
