// Render the real SceneGraph fixture with brs-node. Output is private evidence.
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
const [directory, output, resolution = '1080p'] = process.argv.slice(2);
if (!directory || !output) throw Error('Usage: render-remote.mjs <fixture-dir> <new.png> [720p|1080p]');
if (fs.existsSync(output)) throw Error('Refusing to replace evidence');
const cli = execFileSync('npx',['--yes','-p','brs-node@2.5.3','-c','command -v brs-cli'],{encoding:'utf8'}).trim();
const require = createRequire(fs.realpathSync(cli));
const brs = require('brs-node');
const {createCanvas, ImageData} = require('canvas');
const files = new Map();
function scan(root, relative = '') {
 for (const entry of fs.readdirSync(path.join(root,relative),{withFileTypes:true})) {
  const name = path.join(relative,entry.name);
  if (entry.isDirectory()) scan(root,name);
  else files.set(name.replaceAll(path.sep,'/'),new Blob([fs.readFileSync(path.join(root,name))]));
 }
}
scan(directory);
const payload = await brs.createPayloadFromFileMap(files,{...brs.DefaultDeviceInfo,displayMode:resolution});
payload.device.extensions = new Map([['brs-scenegraph','brs-sg.node.js']]);
payload.extensions = ['brs-scenegraph'];
let latest;
brs.subscribeHost('capture',(event,value)=>{
 if (event === 'frame') latest = value;
 if (event === 'error' || event === 'stderr') process.stderr.write(String(value));
 if (event === 'stdout') process.stdout.write(String(value));
 if (event === 'message' && typeof value === 'string' && /^(error|warning|print),/.test(value)) process.stdout.write(value+'\n');
});
const timer = setTimeout(()=>brs.terminateApp(),6000);
const result = await brs.executeApp(payload);
clearTimeout(timer);
if (!latest) throw Error('No rendered frame: '+JSON.stringify(result));
const frame = latest.imageData ?? latest;
if (!frame.width || !frame.height || !frame.data) throw Error(`Unexpected frame: ${Object.keys(frame)}`);
const canvas = createCanvas(frame.width,frame.height);
canvas.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(frame.data),frame.width,frame.height),0,0);
fs.mkdirSync(path.dirname(output),{recursive:true});
const scaled = resolution === '720p' && frame.width === 1920;
let rendered = canvas;
if (scaled) {
 rendered = createCanvas(1280,720);
 rendered.getContext('2d').drawImage(canvas,0,0,1280,720);
}
fs.writeFileSync(output,rendered.toBuffer('image/png'));
fs.writeFileSync(output+'.json',JSON.stringify({source:[frame.width,frame.height],output:[rendered.width,rendered.height],scaledPreview:scaled,physicalDevice:false},null,2)+'\n');
console.log(`Rendered ${rendered.width}x${rendered.height}${scaled?' (scaled preview of the simulator design canvas)':''}: ${output}`);
