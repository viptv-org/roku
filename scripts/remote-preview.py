"""Build a new networkless production-renderer fixture; never package it."""
from pathlib import Path
import shutil
import sys

root = Path(__file__).resolve().parents[1]
out = Path(sys.argv[1]).resolve()
state = sys.argv[2] if len(sys.argv) > 2 else 'home'
if state not in ('library-filters', 'library-filter-choices', 'filters-text', 'filters', 'password', 'welcome', 'choice', 'pairing', 'home', 'library', 'browse', 'sources', 'settings', 'profiles', 'detail', 'search', 'live', 'calendar', 'player', 'empty', 'error'):
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
 m.libraryDefaults = {source:"favorites",type:"all",offset:0,limit:100,sort:"last_watched",show:"all"}
 m.navigation.profileName = "Alex"
 card = {identity:{kind:"movie",id:"preview",ids:[]},provider_id:"simkl",view:{saved:false,hero_metadata_parts:["1998","Comedy, Fantasy","1h 44m"],metadata_parts:["Movie","1998","Comedy, Fantasy","1h 44m"],compact_metadata_parts:["1998","1h 44m"],hero_badges:[],progress:0.4},title:"Practical Magic",subtitle:"1998 · 1h 44m · Comedy, Fantasy",description:"Two sisters discover that the strongest magic is the bond between them.",poster:"pkg:/images/poster1.jpg",landscape:"pkg:/images/landscape.jpg",badges:[],progress:0.4}
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
render_state = "filters" if state == "filters-text" else state
if state == "library-filter-choices": render_state = "library-filters"
source += {
 'home':'',
 'library':'''rReset("library")
m.libraryQuery = {type:"all",offset:"0",limit:"100"}
rPageResponse("library",{cards:cards,default_query:m.libraryDefaults,query:{type:"all"},controls:[{id:"type",choices:[{label:"All",value:"all"},{label:"Movies",value:"movie"},{label:"Series",value:"series"},{label:"Anime",value:"anime"}]}],complete:true},{})
m.libraryHeader.setFocus(true)
''',
 'library-filters':'''rReset("library")
m.navigation.visible = false
m.libraryQuery = {source:"favorites",offset:0,limit:100,sort:"title",show:"all",type:"series",genre:"Drama"}
m.libraryControls = [{id:"sort",label:"Sort",kind:"SingleChoice",choices:[{value:"last_watched",label:"Last watched"},{value:"title",label:"Title"}]},{id:"genre",label:"Genre",kind:"SingleChoice",choices:[{value:"",label:"Any"},{value:"Drama",label:"Drama"},{value:"Comedy",label:"Comedy"}]},{id:"show",label:"Show",kind:"SingleChoice",choices:[{value:"all",label:"All titles"},{value:"unwatched",label:"Unwatched"}]}]
rLibrarySheetOpen()
''',
 'filters':''' rReset("movie")
m.browseQuery = {type:"movie",skip:"0",values:[]}
m.controls = {controls:[{id:"genre",label:"Genre",kind:"MultiChoice",required:false,maximum_selections:2,choices:[{value:"Action",label:"Action"},{value:"Comedy",label:"Comedy"},{value:"Drama",label:"Drama"},{value:"Fantasy",label:"Fantasy"},{value:"History",label:"History"},{value:"Mystery",label:"Mystery"}]},{id:"search",label:"Search",kind:"Text",required:false,choices:[]},{id:"sort",label:"Sort",kind:"SingleChoice",required:false,choices:[{value:"Latest",label:"Latest"},{value:"Trending",label:"Trending"},{value:"Alphabetical",label:"Alphabetical"}]}]}
m.selectedCatalog = invalid
rFiltersOpen()
''',
 'password':'m.profile = ""\nrPassword()\n',
 'welcome':'m.profile = ""\nrWelcome()\n',
 'choice':'m.profile = ""\nrSignInChoice()\n',
 'pairing':'m.profile = ""\nrShowPair({verification_uri:"https://example.test/device",user_code:"12345678",qr_uri:""})\n',
 'browse':'rReset("movie")\nm.heading.text = "Movies"\nrPageResponse("browse",{cards:cards,complete:true},{})\nm.grid.setFocus(true)\n',
 'sources':'rOpenDrawer("Choose a source",[],"sources")\nrShowSources([{id:"a",view:{title:"Provider A",body:"H.264 · 2.1 GB",quality_label:"1080p",format_label:"HDR",addon_label:"Fixture add-on"}},{id:"b",view:{title:"Provider B",body:"H.264",quality_label:"720p",format_label:""}}])\n',
 'settings':"""m.navigation.profileName = "vynxc"
rSettingsSection("Playback")
rSettingsResponse("settings:preferences",{revision:1,preferences:{source_selection:"best",max_quality_height:invalid,hdr_preference:"any"},controls:[{id:"source_selection",group:"playback",label:"Default source",description:"How Play chooses between sources",choices:[{label:"Best match",value:"best"},{label:"Ask every time",value:"ask"}]},{id:"max_quality_height",group:"playback",label:"Preferred quality",description:"Best match aims for this, then falls back",choices:[{label:"Auto",value:invalid},{label:"4K",value:2160}]},{id:"hdr_preference",group:"playback",label:"HDR preference",choices:[{label:"Any",value:"any"},{label:"Prefer HDR",value:"prefer"}]}]},{})
m.rows.setFocus(true)
""",

 'profiles':'rProfiles({profiles:[{id:"7",name:"Alex"},{id:"8",name:"Kids"}],capabilities:{create:{availability:"Available"},rename:{availability:"Available"}},avatar_ids:[]})\n',
 'detail':'rDetail(card,false)\n',
 'search':'rReset("search")\nrTextInput("Search","search",false,"Practical")\nrPageResponse("search",{rows:[{id:"films",title:"Movies",cards:cards},{id:"series",title:"Series",cards:cards}],complete:true},{})\n',
 'empty':'rReset("library")\nm.heading.text = "My List"\nrPageResponse("library",{cards:[],default_query:m.libraryDefaults,query:{source:"favorites",type:"all",sort:"last_watched",show:"all",offset:0,limit:100},controls:[],complete:true},{})\n',
 'error':'rReset("movie")\nm.heading.text = "Movies"\nm.failedRequest = {method:"GET",path:"/api/discover?type=movie",tag:"browse"}\nrError("Could not reach the server. Try again.")\n',
 'calendar':'''rReset("calendar")
m.calendarVersion = 1
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
rLive({snapshot_id:"synthetic-preview-directory",channels:channels,groups:[{id:"movies",label:"Movies"}],connections:[],availability:"Available",complete:true,paging:{origin:"0",limit:100,page_size:100,previous:invalid,next:invalid}})
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
m.playback={card:card,session:{id:"preview",actions:{pause:true,seek:true,change_source:true,tracks:true,report_progress:true},delivery:{duration:6240,live:false,audio_tracks:[{input_index:0,language:"English",selectable:true,supported:true}],subtitle_tracks:[],subtitles_supported:true}}}
m.playerTitle.text=card.title
m.top.findNode("playerSubtitle").text=card.subtitle
m.playerTime.text="12:34"
m.top.findNode("playerRemaining").text="−91:26"
m.playerProgress.width=210
m.top.findNode("playerThumb").translation=[284,923]
rShowControls()
m.hideControls.control="stop"
''',
}[render_state]
if state == 'filters-text':
    source += 'm.filterPage.callFunc("onKeyEvent","down",true)\nm.filterPage.callFunc("onKeyEvent","OK",true)\n'
    control_xml = out/'components/remote/RemoteFilters.xml'
    control_xml.write_text(control_xml.read_text().replace('<interface>', '<interface><function name="onKeyEvent" />', 1))
if state == 'library-filter-choices':
    source += 'm.librarySheet.callFunc("onKeyEvent","OK",true)\n'
    control_xml = out/'components/remote/RemoteLibrarySheet.xml'
    control_xml.write_text(control_xml.read_text().replace('<interface>', '<interface><function name="onKeyEvent" />', 1))
source += 'end sub\n'
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
