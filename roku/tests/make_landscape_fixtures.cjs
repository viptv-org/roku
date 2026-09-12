#!/usr/bin/env node
// UI-only fictional stills, deliberately derived from existing fixture artwork.
// This is NOT production backdrop selection, and these files are not packaged.
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('../../artifacts/hulu-overhaul/image-tools-r1/node_modules/sharp');
async function main() {
  const dir = path.join(__dirname, 'fixtures');
  for (const name of ['signal','northline','afterhours','wildcoast','sunward','deepcurrent']) {
    const input = path.join(dir, name + '.jpg');
    const output = path.join(dir, 'fixture-' + name + '-wide.jpg');
    if (fs.existsSync(output)) throw new Error('Fixture output must be new: ' + output);
    const { width, height } = await sharp(input).metadata();
    const cropHeight = Math.min(height, Math.round(width * 9 / 16));
    const top = Math.min(height - cropHeight, Math.round(height * .18));
    await sharp(input).extract({left:0,top,width,height:cropHeight}).resize(960,540).jpeg({quality:90}).toFile(output);
    console.log(path.basename(output));
  }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
