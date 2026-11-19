// Rebuilds FOINT CITY's fleet (assets/vehicles/city/*.glb) from tools/cars/build_cars.py: every kind twice, the full model you drive and the lighter one the street draws. Then run node tools/import.mjs.
//   node tools/cars/build_all.mjs [kind ...]      (Blender 5.2: BLENDER=<path to blender.exe> if it is not in Program Files)
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const BLENDER = process.env.BLENDER || 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe';
const OUT = path.resolve(HERE, '../../assets/vehicles/city');
const KINDS = ['sedan', 'hatch', 'taxi', 'van', 'truck', 'bus', 'saucerG', 'saucerN', 'saucerB', 'skyLimo', 'skyDart'];
const want = process.argv.slice(2).length ? process.argv.slice(2) : KINDS;
let bad = 0;
for (const k of want) {
  for (const lod of [[], ['lod']]) {
    const r = spawnSync(BLENDER, ['-b', '--factory-startup', '--python', path.join(HERE, 'build_cars.py'), '--', k, OUT, ...lod], { encoding: 'utf8' });
    const out = (r.stdout || '') + (r.stderr || '');
    const tris = out.split('\n').find((l) => l.startsWith('TRIS'));
    const err = out.split('\n').filter((l) => /Traceback|Error|missed/.test(l));
    console.log(tris ? tris.trim() : `${k}: no model`, err.length ? '\n  ' + err.join('\n  ') : '');
    if (!tris || /Traceback|Error/.test(out)) bad++;
  }
}
process.exit(bad ? 1 : 0);
