"""Actual hero metadata projection and inline layout, including the lost-title path."""
from brs_cli import brs_command
from pathlib import Path
import os,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
panel=(root/'components/HeroPanel.brs').read_text()
layout=panel[panel.index('sub layoutMetadata()'):]
artwork=(root/'components/PresentationArtworkScene.brs').read_text()
def routine(name):
 a=artwork.index('sub '+name+'(')
 return artwork[a:artwork.index('end sub',a)+7]
flow=routine('uiCardArtworkResponse')+'\n'+routine('uiHomeEpisodeMetadata')
fixture='''
sub Main()
 queue={id:"episode-current",type:"series",series_id:"series-a",season:2,episode:1,position:40,duration:1440}
 meta={id:"series-a",logo:"https://art.invalid/logo.png",imdbRating:"8.2",videos:[{id:"episode-other",season:1,episode:1,title:"Wrong season"},{id:"episode-current",season:2,episode:1,title:"The Old Country Bumpkin Takes on a New Position"}]}
 projected=HeroMetadataProjection(meta,[queue])
 if projected.logo<>meta.logo or projected.imdbRating<>"8.2" then throw "projection dropped logo/rating"
 if projected.videos<>invalid then throw "retained unbounded episode payload"
 queue.episodeTitle=HeroEpisodeTitle(queue,projected)
 if queue.episodeTitle<>meta.videos[1].title then throw "metadata episode title lost before hero render"
 if left(HomeCardContext(queue),9)<>"S2 E1 · T" then throw "card wastes its caption on verbose coordinates"
 short={id:"episode-short",type:"series",series_id:"series-a",season:1,episode:8,episodeTitle:"Pie",position:422,duration:3240}
 if HomeCardContext(short)<>"S1 E8 · Pie · 7:02" then throw "short card title/time not visible together"
 if HomeCardContext({id:"film",type:"movie",position:41,duration:6000})<>"Resume at 0:41" then throw "movie card reserved episode words"
 if HeroContext(queue)<>"S2 E1 · The Old Country Bumpkin Takes on a New Position" then throw "hero context omitted episode title"
 queue.episodeTitle="":queue.episode_title="A supplied title"
 if HeroEpisodeTitle(queue,meta)<>"A supplied title" then throw "supplied title overridden"
 queue.delete("episode_title")
 wrong={id:"another-series",videos:meta.videos}
 if HeroEpisodeTitle(queue,wrong)<>"" then throw "cross-series metadata applied"
 queue.id="opaque-id"
 if HeroEpisodeTitle(queue,meta)<>meta.videos[1].title then throw "S/E fallback missing"
 queue.season=0:queue.episode=1
 if HeroEpisodeTitle(queue,meta)<>"" then throw "special got a regular-season title"
 meta.videos.push({id:"special",season:0,episode:1,title:"",name:"Special"})
 if HeroEpisodeTitle(queue,meta)<>"Special" then throw "season zero or name fallback broken"
 queue.queue_status="next":queue.episodeTitle="Special"
 if HeroContext(queue)<>"Up next · S0 E1 · Special" then throw "Up Next dropped title"
 movie={type:"movie",id:"movie",episodeTitle:"stale",season:2,episode:1}
 if HeroContext(movie)<>"" or HeroEpisodeTitle(movie,meta)<>"" then throw "movie rendered episode fields"
 ' Run the real asynchronous response adapter, not only the formatter.
 a={id:"episode-current",type:"series",series_id:"series-a",season:2,episode:1}
 b={id:"other:1:1",type:"series",series_id:"other",season:1,episode:1}
 m.homeData=[[a,b]]:m.testCurrent=b:m.mode="home":m.homeExpanded=true:m.heroCalls=0
 m.homeRoot=invalid:m.uiHeroMetadata={}:m.uiLandscapeOrder=[]:m.uiLandscapeCache={}
 m.uiArtworkInflight={late:{tag:"late",id:"series-a",path:"series-a",mediaType:"series",node:{}}}
 uiCardArtworkResponse("late",{ok:true,data:{meta:meta}})
 if m.heroCalls<>0 or b.episodeTitle<>invalid then throw "late metadata replaced the newly focused hero"
 if a.episodeTitle<>meta.videos[1].title then throw "response adapter dropped queue episode title"
 ' A refreshed queue points at a different episode of the same cached series.
 newer={id:"episode-two",type:"series",series_id:"series-a",season:2,episode:2}
 meta.videos.push({id:"episode-two",season:2,episode:2,title:"Another episode"})
 m.homeData[0][0]=newer:m.testCurrent=newer
 m.uiArtworkInflight={next:{tag:"next",id:"series-a",path:"series-a",mediaType:"series",node:{}}}
 uiCardArtworkResponse("next",{ok:true,data:{meta:meta}})
 if newer.episodeTitle<>"Another episode" or m.heroCalls<>1 then throw "cached series used stale episode name"
 ' Natural label widths feed the production layout; there is no fixed column.
 m.nodes={episode:{visible:true,naturalWidth:56,localBoundingRect:Bounds},progressTrack:{visible:true},progressFill:{},elapsed:{}}
 m.top={findNode:FindNode,nodes:m.nodes}
 layoutMetadata()
 if m.nodes.progressTrack.translation[0]<>196 then throw "short context left an empty column"
 if m.nodes.elapsed.translation[0]<>328 then throw "elapsed gap wrong"
 m.nodes.episode.naturalWidth=900:layoutMetadata()
 if m.nodes.episode.width<>340 or m.nodes.progressTrack.translation[0]<>480 then throw "long title not clamped safely"
 m.nodes.episode.visible=false:layoutMetadata()
 if m.nodes.progressTrack.translation[0]<>128 then throw "movie retained episode spacing"
 m.nodes.progressTrack.visible=false:layoutMetadata()
 if m.nodes.elapsed.translation[0]<>128 then throw "unknown duration reserved progress slot"
 print "HERO_METADATA_RUNTIME_OK"
end sub
function homeCurrent() as object
 return m.testCurrent
end function
sub homeHero()
 m.heroCalls++
end sub
sub uiHomeArtwork(id as string,mediaType as string,uri as string)
end sub
sub uiQueueCardArtwork()
end sub
function Bounds() as object
 return {width:m.naturalWidth,height:24}
end function
function FindNode(id as string) as object
 return m.nodes[id]
end function
'''
with tempfile.TemporaryDirectory() as folder:
 p=Path(folder)/'hero.brs';p.write_text(layout+'\n'+flow+'\n'+fixture)
 r=subprocess.run([*brs_command(),str(p),str(root/'source/PresentationPolicy.brs'),str(root/'source/Util.brs'),str(root/'source/SourceLabels.brs')],capture_output=True,text=True,timeout=40)
 print(r.stdout,r.stderr)
 assert r.returncode==0 and 'HERO_METADATA_RUNTIME_OK' in r.stdout
