"""Fast playback keeps only matching episode metadata through preparation."""
from brs_cli import brs_command
from pathlib import Path
import os,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'components/PlayerTitleScene.brs').read_text()
response=(root/'components/ResponseScene.brs').read_text()
gate=response.index('if left(tag,12) = "playertitle:"')
assert gate < response.index('if val(parts[1]) <> m.generation then return',gate), 'late metadata blocked by generation gate'
transport=(root/'components/MainScene.brs').read_text()
assert 'or playerTitleOwnsTag(tag) then retained.push(entry)' in transport
assert 'and not playerTitleOwnsTag(tag) then task.cancel = true' in transport
fixture='''
sub Main()
 m.config={base:"https://fixture.invalid"}:m.accountEpoch=3:m.profile="p1":m.cache={}:m.cacheKeys=[]:m.uiHeroMetadata={}
 m.mode="resuming":m.homeData=invalid:m.playItem={id:"episode-a",type:"series",series_id:"series-a",season:1,episode:2}
 m.playerOverlay={visible:true}:m.updated=0:m.sent=[]:m.generation=10
 playerTitleBegin(m.playItem)
 if m.sent.count()<>1 or m.sent[0].path<>"/api/meta/series/series-a" then throw "fast selection did not fetch title metadata"
 tag=m.sent[0].tag
 if not playerTitleOwnsTag(tag+"|10") or playerTitleOwnsTag("playertitle:wrong|10") then throw "preparation owner not retained exactly"
 m.generation=11 ' Playback preparation cancels unrelated reads.
 meta={id:"series-a",logo:"logo",imdbRating:"8.4",videos:[{id:"episode-a",season:1,episode:2,title:"Pilot"}]}
 playerTitleResponse(tag,{ok:true,data:{meta:meta}},{base:"https://fixture.invalid",account_epoch:3})
 if m.playItem.episodeTitle<>"Pilot" or m.updated<>1 then throw "late title did not reach visible player"
 if m.cache["/api/meta/series/series-a"] = invalid then throw "title metadata not reusable on return"
 m.playItem={id:"episode-a",type:"series",series_id:"series-a",season:1,episode:2}
 m.sent=[]:playerTitleBegin(m.playItem)
 if m.sent.count()<>0 or m.playItem.episodeTitle<>"Pilot" then throw "cached title required a new request"
 m.cache={}:m.uiHeroMetadata={}:m.playItem={id:"episode-b",type:"series",series_id:"series-a",season:1,episode:3}
 playerTitleBegin(m.playItem):tag=m.sent[m.sent.count()-1].tag
 m.playItem={id:"episode-c",type:"series",series_id:"series-a",season:1,episode:4}
 playerTitleResponse(tag,{ok:true,data:{meta:meta}},{base:"https://fixture.invalid",account_epoch:3})
 if m.playItem.episodeTitle<>invalid then throw "earlier episode relabelled replacement"
 m.playItem={id:"episode-b",type:"series",series_id:"series-a",season:1,episode:3}
 playerTitleBegin(m.playItem):tag=m.sent[m.sent.count()-1].tag
 m.profile="p2"
 playerTitleResponse(tag,{ok:true,data:{meta:meta}},{base:"https://fixture.invalid",account_epoch:3})
 if m.playItem.episodeTitle<>invalid then throw "old profile title reached new profile"
 m.playItem={id:"film",type:"movie",position:2}
 playerTitleBegin(m.playItem)
 if m.playerTitleOwner<>invalid then throw "movie requested episode metadata"
 print "PLAYER_TITLE_RUNTIME_OK"
end sub
sub request(method as string,path as string,body as dynamic,tag as string)
 m.sent.push({path:path,tag:tag})
end sub
sub uiHomeEpisodeMetadata(id as string,details as object)
end sub
sub uiSourceHeader()
end sub
sub updatePlayer()
 m.updated++
end sub
'''
with tempfile.TemporaryDirectory() as folder:
 p=Path(folder)/'title.brs';p.write_text(source+'\n'+fixture)
 r=subprocess.run([*brs_command(),str(p),str(root/'source/PresentationPolicy.brs'),str(root/'source/Util.brs'),str(root/'source/SourceLabels.brs')],capture_output=True,text=True,timeout=40)
 print(r.stdout,r.stderr)
 assert r.returncode==0 and 'PLAYER_TITLE_RUNTIME_OK' in r.stdout
