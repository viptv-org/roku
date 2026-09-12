#!/usr/bin/env node
// Derive the V mark from the original artwork and regenerate Roku branding.
// First run: --extract OLD-splash.jpg; later runs use viptv-wordmark.png.
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('../../artifacts/hulu-overhaul/image-tools-r1/node_modules/sharp');
async function main() {
  const images = path.resolve(__dirname, '../images');
  const wordmark = path.join(images, 'viptv-wordmark.png');
  if (process.argv[2] === '--extract') {
    if (fs.existsSync(wordmark)) throw new Error('The extracted wordmark must be new');
    const { data, info } = await sharp(process.argv[3]).extract({left:260,top:274,width:768,height:184}).removeAlpha().raw().toBuffer({resolveWithObject:true});
    const rgba = Buffer.alloc(info.width * info.height * 4);
    for (let i = 0; i < info.width * info.height; i++) {
      const value = Math.min(data[i*3], data[i*3+1], data[i*3+2]);
      rgba[i*4] = rgba[i*4+1] = rgba[i*4+2] = 245;
      rgba[i*4+3] = Math.round(255 * Math.max(0,Math.min(1,(value-180)/60)));
    }
    await sharp(rgba,{raw:{width:info.width,height:info.height,channels:4}}).png().toFile(wordmark);
  }
  const mark = path.join(images, 'viptv-mark.png');
  await sharp(wordmark).extract({left:10,top:8,width:195,height:167}).png().toFile(mark);
  for (const [name,width,height,logoWidth] of [['splash-hd.jpg',1280,720,180],['channel-poster-hd.jpg',336,210,110]]) {
    const logo = await sharp(mark).resize({width:logoWidth}).png().toBuffer();
    await sharp({create:{width,height,channels:3,background:'#101112'}}).composite([{input:logo,gravity:'centre'}]).jpeg({quality:94}).toFile(path.join(images,name));
    console.log(name);
  }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
