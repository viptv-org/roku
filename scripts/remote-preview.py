"""Build a new networkless production-renderer fixture; never package it."""
from pathlib import Path
import shutil
import sys

root = Path(__file__).resolve().parents[1]
out = Path(sys.argv[1]).resolve()
state = sys.argv[2] if len(sys.argv) > 2 else 'home'
if state not in ('home', 'browse', 'sources', 'settings', 'profiles', 'detail', 'search', 'live', 'calendar', 'player', 'empty', 'error'):
    raise SystemExit('Unsupported preview state')
out.mkdir(parents=True,exist_ok=False)
for folder in ('components','source','fonts','images'):
    shutil.copytree(root/'roku'/folder,out/folder)
shutil.copyfile(root/'roku/manifest',out/'manifest')
fixture = root.parent/'app/composeApp/src/commonMain/composeResources/files/ui-preview'
for name in ('landscape.jpg','poster1.jpg','poster2.jpg','tv3movie-0.jpg','player.jpg'):
    if (fixture/name).exists(): shutil.copyfile(fixture/name,out/'images'/name)
scene = out/'components/remote/RemoteScene.brs'
source = scene.read_text().replace('rSend("CONFIG_LOAD","",invalid,"auth:config")',"' No registry in preview")
source += '''
sub rPreview()
 m.networkTick.control = "stop"
 m.pollTick.control = "stop"
 m.config = {base:"https://example.test",access_token:"",capabilities:{max_width:1920,max_height:1080,h264:true,aac:true}}
 m.profile = "7"
 m.navigation.profileName = "Alex"
 card = {identity:{kind:"movie",id:"preview",ids:[]},provider_id:"simkl",view:{saved:false},title:"Practical Magic",subtitle:"1998 · 1h 44m · Comedy, Fantasy",description:"Two sisters discover that the strongest magic is the bond between them.",poster:"pkg:/images/poster1.jpg",landscape:"pkg:/images/landscape.jpg",badges:[],progress:0.4}
 cards = []
 for i = 0 to 13
  item = ParseJson(FormatJson(card))
  item.identity.id = "preview-"+i.toStr()
  if i mod 2 = 1 then item.poster = "pkg:/images/poster2.jpg"
  cards.push(item)
 end for
 rReset("home")
 rHome({scope:{profile_id:"7",account_id:"2",revision:1},hero:card,featured:[card],rows:[{id:"continue",title:"Continue Watching",state:"Ready",view:{card_shape:"landscape"},cards:cards,next_cursor:invalid},{id:"movies",title:"Popular movies",state:"Ready",view:{card_shape:"landscape"},cards:cards,next_cursor:invalid}],complete:true})
'''
source += {
 'home':'',
 'browse':'rReset("movie")\nm.heading.text = "Movies"\nrPageResponse("browse",{cards:cards,complete:true},{})\nm.grid.setFocus(true)\n',
 'sources':'rOpenDrawer("Sources",[],"sources")\nrShowSources([{id:"a",name:"Provider A",presentation:{provider_name:"Provider A",quality:"1080p",video_codec:"H.264",size_label:"2.1 GB"}},{id:"b",name:"Provider B",presentation:{provider_name:"Provider B",quality:"720p",video_codec:"H.264"}}])\n',
 'settings':'rNavigate("settings")\n',
 'profiles':'rProfiles({profiles:[{id:"7",name:"Alex"},{id:"8",name:"Kids"}],capabilities:{create:{availability:"Available"},rename:{availability:"Available"}},avatar_ids:[]})\n',
 'detail':'rDetail(card,false)\n',
 'search':'rReset("search")\nrTextInput("Search","search",false,"Practical")\nrPageResponse("search",{rows:[{id:"films",title:"Movies",cards:cards},{id:"series",title:"Series",cards:cards}],complete:true},{})\n',
 'empty':'rReset("library")\nm.heading.text = "My List"\nrPageResponse("library",{cards:[],controls:[],complete:true},{})\n',
 'error':'rReset("movie")\nm.heading.text = "Movies"\nm.failedRequest = {method:"GET",path:"/api/discover?type=movie",tag:"browse"}\nrError("Could not reach the server. Try again.")\n',
 'calendar':'''rReset("calendar")
m.calendarDay = "2026-10-23"
m.calendarType = "series"
m.calendarEntries = []
rCalendar({entries:[{id:"release",date:"2026-10-23T12:30:00Z",card:card,episode_title:"A new beginning"}],complete:true},{context:{day:m.calendarDay,type:m.calendarType,cursor:""}})
m.rows.setFocus(true)
''',
 'live':'''rReset("live")
m.liveQuery = ""
channels = []
for i=0 to 8
 channelCard=ParseJson(FormatJson(card))
 channelCard.title="Channel "+(i+1).toStr()
 channels.push({id:"channel-"+i.toStr(),connection_id:"server-live",card:channelCard})
end for
rLive({channels:channels,groups:[{id:"movies",label:"Movies"}],connections:[],complete:true})
start=int(rNow()/1800)*1800
for each channel in channels
 rLiveGuide({channel_id:channel.id,programs:[{id:"one",title:"Now showing",start_millis:start*1000#,end_millis:(start+3600)*1000#},{id:"two",title:"Up next",start_millis:(start+3600)*1000#,end_millis:(start+7200)*1000#}],view:{current_program_id:"one",window_start_millis:start*1000#}},{context:{channel:channel.id}})
end for
m.rows.setFocus(true)
''',
 'player':'''rReset("player")
frame=CreateObject("roSGNode","Poster")
frame.uri="pkg:/images/player.jpg"
frame.width=1920:frame.height=1080:frame.loadDisplayMode="scaleToZoom"
m.top.insertChild(frame,1)
m.navigation.visible=false
m.playback={card:card,session:{id:"preview",delivery:{duration:6240,live:false,audio_tracks:[{input_index:0,language:"English"}],subtitle_tracks:[],subtitles_supported:true}}}
m.playerTitle.text=card.title
m.top.findNode("playerSubtitle").text=card.subtitle
m.playerTime.text="12:34"
m.top.findNode("playerRemaining").text="−91:26"
m.playerProgress.width=210
m.top.findNode("playerThumb").translation=[284,923]
rShowControls()
m.hideControls.control="stop"
''',
}[state] + 'end sub\n'
scene.write_text(source)
transport=out/'components/remote/RemoteTransport.brs'
transport.write_text(transport.read_text().replace('sub rDispatch()\n','sub rDispatch()\n return\n'))
xml=out/'components/remote/RemoteScene.xml'
xml.write_text(xml.read_text().replace('<component name="RemoteScene" extends="Scene">','<component name="RemoteScene" extends="Scene"><interface><function name="rPreview" /></interface>'))
(out/'source/main.brs').write_text('''sub Main()
 screen=CreateObject("roSGScreen")
 port=CreateObject("roMessagePort")
 screen.setMessagePort(port)
 scene=screen.createScene("RemoteScene")
 screen.show()
 scene.callFunc("rPreview")
 while true
  event=wait(100,port)
  if type(event)="roSGScreenEvent" then return
 end while
end sub
''')
print(out)
