"""Exercise the real virtual strip across both edges with more than eight episodes."""
from brs_cli import brs_command
from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'components/HorizontalStrip.brs').read_text()
fixture='''
sub Main()
 m.views=[]:m.scroll=0:m.items={createChild:Card}
 m.top={itemSize:[240,248],itemSpacing:[24,0],viewportWidth:1088,itemFocused:0,active:true,itemComponentName:"EpisodeCard",content:{getChild:GetChild,getChildCount:Count,children:[]}}
 for i=0 to 31
  m.top.content.children.push({id:i,isSameNode:Same})
 end for
 render()
 if m.views.count()<>6 then throw "strip not virtualized"
 for i=0 to 50
  onKeyEvent("right",true)
 end for
 if m.top.itemFocused<>31 then throw "right wrapped out of episode strip"
 if m.views.count()<>6 then throw "navigation allocated offscreen card nodes"
 checked=false
 for each card in m.views
  if card.visible and card.focusPercent=1
   if card.translation[0]<0 or card.translation[0]+240>1088 then throw "last episode clipped"
   checked=true
  end if
 end for
 if not checked then throw "focus ring vanished"
 onKeyEvent("OK",true)
 if m.top.itemSelected<>31 then throw "wrong episode activation"
 if onKeyEvent("up",true) then throw "Up swallowed instead of returning to Season"
 for i=0 to 50
  onKeyEvent("left",true)
 end for
 if m.top.itemFocused<>0 or m.scroll<>0 then throw "left edge escaped"
 print "HORIZONTAL_STRIP_RUNTIME_OK"
end sub
function Card(kind as string) as object
 return {itemContent:invalid}
end function
function Count() as integer
 return m.children.count()
end function
function GetChild(index as integer) as object
 return m.children[index]
end function
function Same(other as object) as boolean
 return m.id=other.id
end function
'''
with tempfile.TemporaryDirectory() as folder:
 p=Path(folder)/'strip.brs';p.write_text(source+'\n'+fixture)
 r=subprocess.run([*brs_command(),str(p)],capture_output=True,text=True,timeout=30)
 print(r.stdout,r.stderr)
 assert r.returncode==0 and 'HORIZONTAL_STRIP_RUNTIME_OK' in r.stdout
