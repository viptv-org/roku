"""Render actual episode cards with Roku's render-thread component restriction."""
from pathlib import Path
import os, subprocess, tempfile
root = Path(__file__).resolve().parents[1]
card = (root / 'components/EpisodeCard.brs').read_text()
start = card.index('sub render()')
render = card[start:card.index('end sub', start) + 7]
policy = (root / 'source/ImagePolicy.brs').read_text().replace('CreateObject(', 'RenderCreateObject(')
fixture = '''
sub Main()
 m.imageScale=1 : m.thumbnail={uri:"",visible:false}
 m.nodes={}
 for each name in ["placeholder","watchedBadge","progress","number","title","summary"]
  m.nodes[name]={font:{}}
 end for
 item={HDPosterUrl:"https://wsrv.nl/?url=https%3A%2F%2Fartworks.thetvdb.com%2Fbanners%2Fepisode%2Ftest.jpg&w=500",title:"Pilot",description:"Episode one",hasField:HasField}
 m.top={itemContent:item,findNode:FindNode,nodes:m.nodes}
 render()
 if instr(1,m.thumbnail.uri,"&w=256&h=144")=0 then throw "episode did not finish rendering a resized thumbnail"
 if instr(1,m.thumbnail.uri,"wsrv.nl%2F")>0 then throw "episode nested the image proxy"
 if m.nodes.title.text<>"Pilot" then throw "episode title never rendered"
 for each uri in ["", "https://wsrv.nl/?url=%ZZ", "https://private.invalid/image.jpg?token=private"]
  item.HDPosterUrl=uri
  render()
  if m.thumbnail.uri<>uri then throw "invalid/private artwork must retain its original fallback"
 end for
 print "EPISODE_IMAGE_RENDER_OK"
end sub
function RenderCreateObject(name as string,a=invalid as dynamic,b=invalid as dynamic) as dynamic
 if lcase(name)="rourltransfer" then throw "MAIN/TASK-only roUrlTransfer created on episode RENDER thread"
 if a=invalid then return CreateObject(name)
 return CreateObject(name,a,b)
end function
function HasField(name as string) as boolean
 return m.doesExist(name)
end function
function FindNode(name as string) as object
 return m.nodes[name]
end function
sub renderFocus()
end sub
sub artLoaded()
end sub
'''
with tempfile.TemporaryDirectory() as temp:
 p=Path(temp)/'episode-image.brs';p.write_text(render+'\n'+policy+'\n'+fixture)
 result=subprocess.run([os.environ.get('VIPTV_BRS_CLI','/home/node/air-roku/node_modules/.bin/brs-cli'),str(p),str(root/'source/Util.brs')],capture_output=True,text=True,timeout=30)
 print(result.stdout,result.stderr)
 if result.returncode or 'EPISODE_IMAGE_RENDER_OK' not in result.stdout:raise SystemExit(1)
