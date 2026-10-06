// Publish the already exported and patched Godot build from main:/docs.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const exported = path.join(root, 'build', 'web');
const output = path.join(root, 'docs');
const runtimeFiles = [
  'index.html', 'index.js', 'index.wasm', 'index.pck', 'index.png',
  'index.audio.worklet.js', 'index.audio.position.worklet.js',
];
const notices = [
  ['assets/fonts/OFL.txt', 'licenses/noto-sans-sc-OFL.txt'],
  ['assets/licenses/godot-license.txt', 'licenses/godot-license.txt'],
  ['assets/licenses/godot-copyright.txt', 'licenses/godot-copyright.txt'],
];
const sources = runtimeFiles.map(name => [path.join(exported, name), name]);
sources.push(...notices.map(([source, name]) => [path.join(root, source), name]));
for (const [source] of sources) {
  if (!fs.existsSync(source)) throw new Error(`Missing required export file: ${source}`);
}
const wasm = fs.readFileSync(path.join(exported, 'index.wasm'));
if (!wasm.subarray(0, 8).equals(Buffer.from([0, 97, 115, 109, 1, 0, 0, 0]))) {
  throw new Error('Export is not a valid WebAssembly v1 module.');
}
const html = fs.readFileSync(path.join(exported, 'index.html'), 'utf8');
if (!html.includes('src="index.js"') || !html.includes('"executable":"index"')) {
  throw new Error('Expected relative asset paths for GitHub Pages repository hosting.');
}
const files = [];
for (const [source, name] of sources) {
  const target = path.join(output, name);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(source, target);
  const bytes = fs.readFileSync(target);
  files.push({
    path: name, bytes: bytes.length,
    sha256: crypto.createHash('sha256').update(bytes).digest('hex'),
  });
}
fs.writeFileSync(path.join(output, '.nojekyll'), '');
fs.writeFileSync(path.join(output, '.gdignore'), '');
fs.writeFileSync(path.join(output, 'build-manifest.json'), JSON.stringify({
  game: 'Strawberry Walk', engine: 'Godot 4.7.2', files,
}, null, 2) + '\n');
console.log(`PAGES_READY: ${files.length} files, ${files.reduce((sum, file) => sum + file.bytes, 0)} bytes`);
