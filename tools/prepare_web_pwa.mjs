// Add our user-confirmed PWA to the Godot export. No runtime dependencies.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = path.join(root, 'web');
const output = path.join(root, 'build/web');
const runtime = [
  'index.html', 'index.js', 'index.wasm', 'index.pck', 'index.png',
  'index.audio.worklet.js', 'index.audio.position.worklet.js',
];
const additions = [
  'pwa.js', 'pwa.css', 'manifest.webmanifest', 'icons/icon-192.png',
  'icons/icon-512.png', 'icons/icon-maskable-512.png', 'icons/apple-touch-icon.png',
];
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
if (!fs.readFileSync(path.join(output, 'index.html'), 'utf8').includes('src="pwa.js"')) {
  throw new Error('Export Godot with the updated web/shell.html first.');
}
for (const name of additions) {
  const target = path.join(output, name);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(path.join(source, name), target);
}
const files = [...runtime, ...additions].map(name => {
  const bytes = fs.readFileSync(path.join(output, name));
  return { path: name, bytes: bytes.length, sha256: hash(bytes) };
});
const template = fs.readFileSync(path.join(source, 'sw.js'), 'utf8');
// Worker code changes also get a new cache; a failed install cannot delete the active release.
const version = hash(JSON.stringify(files) + template).slice(0, 20);
fs.writeFileSync(path.join(output, 'sw.js'), template
  .replace("'__BUILD_VERSION__'", JSON.stringify(version))
  .replace('/* __PRECACHE_FILES__ */ []', JSON.stringify(files)));
console.log(`PWA_READY: ${version}, ${files.length} files, ${files.reduce((sum, file) => sum + file.bytes, 0)} bytes`);
