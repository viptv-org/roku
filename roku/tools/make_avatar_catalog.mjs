// Reproducible CC0 avatar catalog; install dependencies in the ignored tools directory.
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { Avatar, Style } from '../../artifacts/avatar-tools-20260909/node_modules/@dicebear/core/lib/index.js';
import sharp from '../../artifacts/avatar-tools-20260909/node_modules/sharp/lib/index.js';
const categories = [['critters','Creatures'],['pixelbot','Robots'],['voxel-bot','Block bots'],['pixel-art','Pixel heroes'],['pixel-art-neutral','Pixel pals'],['sprouts','Sprouts'],['planets','Space'],['clay','Clay friends'],['moods','Moods'],['thumbs','Thumb buddies'],['lorelei','People'],['notionists','Doodles']];
await mkdir(new URL('../images/avatar-catalog/',import.meta.url),{recursive:true});
for (const [id,name] of categories) {
 const definition=JSON.parse(await readFile(new URL(`../../artifacts/avatar-tools-20260909/node_modules/@dicebear/styles/dist/${id}.min.json`,import.meta.url)));
 const style=new Style(definition);
 for(let choice=1;choice<=48;choice++) {
  const svg=new Avatar(style,{seed:`viptv-${id}-${choice}`,size:256}).toString();
  await sharp(Buffer.from(svg)).resize(160,160).png().toFile(new URL(`../images/avatar-catalog/${id}-${choice}.png`,import.meta.url).pathname);
 }
 console.log(name,48);
}
await mkdir(new URL('../data/',import.meta.url),{recursive:true});
const characters=JSON.parse(await readFile(new URL('../data/character-avatars.json',import.meta.url)));
const labels={disney:'Disney favorites',princesses:'Princesses','animal-friends':'Animal friends',villains:'Villains'};
const groups=[...Object.entries(characters).map(([style,items])=>({style,name:labels[style],items})),...categories.map(([style,name])=>({style,name}))];
const total=576+Object.values(characters).reduce((sum,items)=>sum+items.length,0);
await writeFile(new URL('../data/avatar-catalog.json',import.meta.url),JSON.stringify({version:1,per_category:48,categories:groups,total},null,2)+'\n');
