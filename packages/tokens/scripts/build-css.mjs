// Emits dist/tokens.css from the compiled token objects.
// Runs after `tsc`, so it imports from dist rather than src.

import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { renderStylesheet } from '../dist/index.js';

const here = dirname(fileURLToPath(import.meta.url));
const target = join(here, '..', 'dist', 'tokens.css');

await mkdir(dirname(target), { recursive: true });
await writeFile(target, renderStylesheet(), 'utf8');

console.log(`@warq/tokens → ${target}`);
