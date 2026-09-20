"""Bounded episode pages and explicit watched/progress correction at native handlers."""
from pathlib import Path
import os,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'components/ResponseScene.brs').read_text()+'\n'+(root/'components/HomeScene.brs').read_text()
library=(root/'components/LibraryScene.brs').read_text()
start=library.index('function libraryResponse(')
response_handler=library[start:library.index('end function',start)+12]
def routine(name):
 start=source.index('sub '+name+'(');return source[start:source.index('end sub',start)+7]
fixture='''
sub Main()
 m.selected={id:"series",name:"Show"} : m.episodeSeason="1" : m.episodes=[] : m.episodeList={}
 for i=1 to 161
  m.episodes.push({id:"ep"+i.toStr(),type:"series",season:1,episode:i,title:"Episode "+i.toStr()})
 end for
 showEpisodes(80)
 if m.items.count()>82 or m.episodeOffset<>80 then throw "episode nodes not bounded to one page"
 if m.items[0].action<>"episodesprevious" or m.items[1].id<>"ep81" then throw "episode page lost navigation or identity"
 if m.items[m.items.count()-1].action<>"episodesnext" then throw "next episode page inaccessible"
 applyEpisodeProgress({ok:true,data:[{id:"ep90",type:"series",series_id:"series",season:1,episode:90,position:0,duration:0,watched:true,updated_at:100}]})
 if m.episodeOffset<>80 or m.episodeList.jumpToItem<>11 then throw "next unwatched focus did not stay on episode page"
 if m.episodes[89].watched<>true then throw "explicit watched flag lost for unknown duration"
 applyEpisodeProgress({ok:true,data:[{id:"ep90",type:"series",series_id:"series",season:1,episode:90,position:0,duration:0,watched:false,updated_at:101}]})
 if m.episodeList.jumpToItem<>10 or m.episodes[89].watched<>false then throw "unwatched correction did not restore selected episode"
 ' Move to another season/page while a correction response is outstanding.
 for i=1 to 100
  m.episodes.push({id:"s2ep"+i.toStr(),type:"series",season:2,episode:i,title:"Season two"})
 end for
 m.mode="episodes" : m.profile="7" : m.status={}
 libraryResponse("librarycorrected",{ok:true})
 if m.sent.tag<>"episoderefresh" then throw "correction reused initial resume selection handler"
 m.episodeSeason="2" : showEpisodes(80)
 m.episodeList.jumpToItem=12 : m.focusOwner="sidebar"
 libraryResponse(m.sent.tag,{ok:true,data:[{id:"ep90",type:"series",series_id:"series",season:1,episode:90,position:0,duration:0,watched:true,updated_at:102}]})
 if m.episodeSeason<>"2" or m.episodeOffset<>80 then throw "late correction changed the user-selected season or page"
 if m.episodeList.jumpToItem<>12 or m.focusOwner<>"sidebar" then throw "late correction stole sidebar or episode focus"
 if m.episodes[89].watched<>true then throw "in-place correction failed to update watched state"
 m.focusOwner="dialog" : m.episodeList.jumpToItem=5
 libraryResponse(m.sent.tag,{ok:true,data:[{id:"s2ep85",type:"series",series_id:"series",season:2,episode:85,position:50,duration:100,updated_at:103}]})
 if m.episodeList.jumpToItem<>5 or m.focusOwner<>"dialog" then throw "correction disturbed the open dialog"
 if m.items[5].position<>50 then throw "visible episode progress was not refreshed"
 print "EPISODE_LIBRARY_OK"
end sub
sub rows(title as string,items as object,mode as string,status as string,enter=true as boolean)
 m.items=items
 if enter then m.episodeList.jumpToItem=0 : m.focusOwner="episodes"
end sub
sub request(method as string,path as string,body as dynamic,tag as string)
 m.sent={tag:tag,path:path}
end sub
sub showDetail(item as object)
end sub
function acknowledgementMayFocus() as boolean
 return false
end function
'''
with tempfile.TemporaryDirectory() as temp:
 path=Path(temp)/'episodes.brs';path.write_text('\n'.join(routine(n) for n in ['showEpisodes','applyEpisodeProgress'])+ '\n'+response_handler+'\n'+fixture)
 p=subprocess.run([os.environ.get('VIPTV_BRS_CLI','/home/node/air-roku/node_modules/.bin/brs-cli'),str(path),str(root/'source/Util.brs'),str(root/'source/PresentationPolicy.brs')],capture_output=True,text=True,timeout=40)
 print(p.stdout,p.stderr)
 if p.returncode or 'EPISODE_LIBRARY_OK' not in p.stdout:raise SystemExit(1)
