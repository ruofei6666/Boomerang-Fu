import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const url = 'http://localhost:8060';

async function ready() {
  try { return (await (await fetch(url + '/health', { signal: AbortSignal.timeout(1000) })).json()).game === 'StrawberryWalk'; }
  catch { return false; }
}

if (!await ready()) {
  if (!fs.existsSync(path.join(root, 'build/web/index.html'))) throw new Error('Export the Godot Web preset first.');
  const output = fs.openSync(path.join(root, 'artifacts/web-server.log'), 'a');
  const errors = fs.openSync(path.join(root, 'artifacts/web-server-errors.log'), 'a');
  const server = spawn(process.execPath, [path.join(root, 'tools/serve_web.mjs')], {
    cwd: root, detached: true, windowsHide: true, stdio: ['ignore', output, errors],
  });
  server.unref();
  fs.closeSync(output);
  fs.closeSync(errors);
  for (let attempt = 0; attempt < 30 && !await ready(); attempt++) await new Promise(resolve => setTimeout(resolve, 200));
}
if (!await ready()) throw new Error('The game server did not start. Check artifacts/web-server-errors.log.');
console.log('STRAWBERRY_GAME_READY: ' + url);
if (!process.argv.includes('--no-browser')) {
  const browser = spawn('cmd.exe', ['/c', 'start', '', url], { detached: true, windowsHide: true, stdio: 'ignore' });
  browser.unref();
}
