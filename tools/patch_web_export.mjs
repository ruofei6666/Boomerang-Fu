// Godot 4.7.2's sample-position initialization assumes AudioWorklet is available.
// HTTP LAN pages lack it. Guard the unused sample module and let Godot select its
// existing ScriptProcessor audio backend. HTTPS keeps its normal AudioWorklet.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const filename = path.join(root, 'build/web/index.js');
const source = fs.readFileSync(filename, 'utf8');
const original = 'GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet.addModule(path);';
const guarded = 'GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet?ctx.audioWorklet.addModule(path):Promise.resolve();';
if (source.includes(guarded)) {
  console.log('WEB_HTTP_AUDIO_GUARD: already applied');
} else {
  if (source.split(original).length !== 2) throw new Error('Unexpected Godot JS template: review the audio initialization before patching.');
  fs.writeFileSync(filename, source.replace(original, guarded));
  console.log('WEB_HTTP_AUDIO_GUARD: applied');
}
