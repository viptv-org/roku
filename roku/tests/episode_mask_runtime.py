"""Actual card init maps layout coordinates to the graphics-plane mask size."""
from pathlib import Path
import os,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'components/EpisodeCard.brs').read_text();start=s.index('sub init()');init=s[start:s.index('end sub',start)+7].replace('CreateObject(', 'TestCreateObject(')
fixture='''
sub Main()
 m.nodes={artworkClip:{},thumbnail:{observeField:Observe}}
 m.top={nodes:m.nodes,findNode:FindNode}
 m.testDevice={GetDisplaySize:Display,GetUIResolution:Pixels,layout:{w:1280,h:720},pixels:{width:1920,height:1080}}
 init()
 if m.nodes.artworkClip.maskSize[0]<>384 or m.nodes.artworkClip.maskSize[1]<>216 then throw "mask ignores graphics/layout scale"
 m.testDevice.pixels={width:1280,height:720}
 init()
 if m.nodes.artworkClip.maskSize[0]<>256 or m.nodes.artworkClip.maskSize[1]<>144 then throw "mask hard-coded for FHD graphics"
 print "EPISODE_MASK_SCALE_OK"
end sub
function TestCreateObject(name as string) as object
 if name<>"roDeviceInfo" then throw "unexpected render component"
 return m.testDevice
end function
function Display() as object
 return m.layout
end function
function Pixels() as object
 return m.pixels
end function
function FindNode(id as string) as object
 return m.nodes[id]
end function
sub Observe(field as string,handler as string)
end sub
'''
with tempfile.TemporaryDirectory() as temp:
 p=Path(temp)/'mask.brs';p.write_text(init+'\n'+fixture)
 r=subprocess.run([os.environ.get('VIPTV_BRS_CLI','/home/node/air-roku/node_modules/.bin/brs-cli'),str(p)],capture_output=True,text=True,timeout=30)
 print(r.stdout,r.stderr)
 if r.returncode or 'EPISODE_MASK_SCALE_OK' not in r.stdout:raise SystemExit(1)
