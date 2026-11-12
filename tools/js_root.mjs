// Where the three.js game lives (the tools export and check against it). PROG_JS_ROOT, else beside this project (the old progectalp2 layout), else its home in progectalp2.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const PROJECT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const NAME = 'progalpha-20261016T082732Z-1-001/progalpha';
const tries = [process.env.PROG_JS_ROOT, path.resolve(PROJECT, '..', NAME), path.join('C:/Users/12147/Documents/GitHub/progectalp2', NAME)];
export const JS_ROOT = tries.find((p) => p && fs.existsSync(path.join(p, 'index.html'))) || tries[1];
