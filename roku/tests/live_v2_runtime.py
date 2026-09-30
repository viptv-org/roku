"""Exercise production raw guide cursor routing and live-source transport boundaries."""
from pathlib import Path
import os, subprocess, tempfile
root = Path(__file__).resolve().parents[1]
grid = (root/'components/EpgGrid.brs').read_text()
playback = (root/'components/PlaybackScene.brs').read_text()
def routine(source, start, end):
    begin = source.index(start)
    return source[begin:source.index(end, begin)+len(end)]
production = routine(grid, 'sub epgRoute(', 'end sub')
production += '\n' + routine(grid, 'sub epgData(', 'end sub')
production += '\n' + routine(grid, 'sub epgGuide(', 'end sub')
production += '\n' + routine(grid, 'sub epgCategories(', 'end sub')
production += '\n' + routine(grid, 'sub epgCategoryState(', 'end sub')
production += '\n' + routine(grid, 'function onKeyEvent(', 'end function')
production += '\n' + routine(playback, 'sub beginPlayback(', 'end sub')
fixture = '''
sub Main()
 m.top = {route:{cursor:"page2"},query:""}
 m.filtersData = [{id:"all"}] : m.menu = 0
 m.offset = 40 : m.nextCursor = "page3" : m.previousCursor = "page1"
 m.channels = [{id:"raw:41"}] : m.details = {visible:false}
 m.window = 1800 : m.anchor = 1900
 epgRoute(80)
 if m.top.route.cursor <> "page3" or m.anchor <> 1900 then throw "forward cursor or time changed"
 m.offset = 80 : m.previousCursor = "page2"
 epgRoute(40,true)
 if m.top.route.cursor <> "page2" or m.top.route.focusEnd <> true then throw "reverse cursor/focus lost"
 m.offset = 40
 epgRoute(40)
 if m.top.route.cursor <> "page2" then throw "retry lost cursor"
 epgRoute(0)
 if m.top.route.cursor <> "" then throw "new filter retained cursor"
 m.guideReveal = {} : m.holdingGuides = true : m.cache = {} : m.order = []
 m.visibleFirst = 0 : m.visibleLast = -1
 rows = [] : programmes = []
 for i = 1 to 100
  rows.push({id:"raw:"+i.toStr()})
  programmes.push({title:"show",start:i,end:i+1})
 end for
 for pageIndex = 0 to 99
  m.top.data = {channels:rows,offset:pageIndex*40,next_cursor:"next",previous_cursor:"previous",focusEnd:true}
  epgData()
  if m.channels.count() <> 40 or m.row <> 39 or m.anchor <> 1900 then throw "bounded page or focus lost"
  m.top.guide = {id:"channel:"+pageIndex.toStr(),ok:true,programs:programmes}
  epgGuide()
  if m.cache.count() > 40 then throw "EPG cache unbounded"
 end for

 m.playItem = {id:"raw:1",type:"live"} : m.pendingPlayback = false
 m.sent = []
 beginPlayback(false)
 if m.sent.count() <> 1 or m.sent[0].path <> "/api/v2/iptv/live/raw%3A1/source" then throw "live did not resolve exact source"
 if not m.pendingPlayback or not m.liveSourcePending then throw "source admission not owned"
 beginPlayback(false)
 if m.sent.count() <> 1 then throw "duplicate source admission"

 page = SanitizeApiResponse("/api/v2/iptv/live/channels?limit=40","GET",{catalog_id:1,generation:2,items:[{id:"raw:1",name:"Channel",logo:"http://logo.test/a.png"}],next_cursor:"next",previous_cursor:invalid})
 if not page.ok or page.data.items[0].type <> "live" or page.data.next_cursor <> "next" then throw "raw page sanitization failed"
 if page.data.items[0].logo <> "http://logo.test/a.png" then throw "HTTP logo lost"
 good = {catalog_id:1,generation:2,items:[{id:"iptv:1:1",name:"Channel"}],next_cursor:invalid,previous_cursor:invalid}
 ' Integer metadata retains exact native LongInteger identity, without Int32 conversion.
 for each value in [ParseJson("2147483647"),ParseJson("2147483648"),9007199254740993&,9223372036854775807&]
  large = {} : large.append(good) : large.catalog_id = value : large.generation = value
  for each route in ["/api/v2/iptv/live/channels","/api/v2/iptv/live/categories"]
   decoded = SanitizeApiResponse(route,"GET",large)
   if not decoded.ok then throw "valid long metadata rejected"
   if Txt(decoded.data.catalog_id) <> value.ToStr() or Txt(decoded.data.generation) <> value.ToStr() then throw "long metadata narrowed"
  end for
 end for
 if not ApiLiveMetadataInteger(0&,false) or ApiLiveMetadataInteger(0&,true) then throw "zero metadata semantics lost"
 for each value in [-1,-1&,0.5,1.0,1.0#,9007199254740992#,9007199254740993#,"2147483648",true,{}]
  if ApiLiveMetadataInteger(value,true) or ApiLiveMetadataInteger(value,false) then throw "unsafe metadata accepted"
 end for
 ' Both directions preserve opaque tokens through the backend's public 4096 bound.
 token = ""
 for i = 1 to 4097
  token += "A"
  if i = 2048 or i = 2049 or i = 4096 or i = 4097
   for each field in ["next_cursor","previous_cursor"]
    bounded = {} : bounded.append(good) : bounded[field] = token
    for each route in ["/api/v2/iptv/live/channels","/api/v2/iptv/live/categories"]
     decoded = SanitizeApiResponse(route,"GET",bounded)
     if i <= 4096
      if not decoded.ok or decoded.data[field] <> token then throw "bounded cursor rejected or changed"
     else
      if decoded.ok then throw "oversized cursor accepted"
     end if
    end for
   end for
  end if
 end for
 for each field in ["catalog_id","generation","previous_cursor","next_cursor"]
  bad = {} : bad.append(good) : bad.delete(field)
  if SanitizeApiResponse("/api/v2/iptv/live/channels","GET",bad).ok then throw "missing metadata accepted"
 end for
 for each token in ["", "https://private.test/token", "bad token", "bad"+chr(10), 123]
  bad = {} : bad.append(good) : bad.next_cursor = token
  if SanitizeApiResponse("/api/v2/iptv/live/channels","GET",bad).ok then throw "bad cursor accepted"
 end for
 bad = {} : bad.append(good) : bad.generation = "2"
 if SanitizeApiResponse("/api/v2/iptv/live/channels","GET",bad).ok then throw "string generation accepted"
 bad.generation = 0.5
 if SanitizeApiResponse("/api/v2/iptv/live/channels","GET",bad).ok then throw "fractional generation accepted"
 bad = {} : bad.append(good) : bad.items = [good.items[0],good.items[0]]
 if SanitizeApiResponse("/api/v2/iptv/live/channels","GET",bad).ok then throw "duplicate channels accepted"
 card = {id:"opaque",source:"iptv:1",source_addon_id:"iptv:1"}
 source = SanitizeApiResponse("/api/v2/iptv/live/iptv%3A1%3A1/source","POST",{source:card})
 if not source.ok or source.data.source.id <> "opaque" then throw "source id lost"
 if source.data.source.url <> invalid or source.data.source.headers <> invalid then throw "source leaked URL authority"
 for each field in ["url","headers","authorization","integration_key"]
  badCard = {} : badCard.append(card) : badCard[field] = "private"
  if SanitizeApiResponse("/api/v2/iptv/live/iptv%3A1%3A1/source","POST",{source:badCard}).ok then throw "source authority accepted"
 end for
 for each identity in ["", "http://private.test/source", "bad id",string(129,"x")]
  badCard = {} : badCard.append(card) : badCard.id = identity
  if SanitizeApiResponse("/api/v2/iptv/live/iptv%3A1%3A1/source","POST",{source:badCard}).ok then throw "invalid opaque identity accepted"
 end for
 badCard = {} : badCard.append(card) : badCard.source_addon_id = "iptv:2"
 if SanitizeApiResponse("/api/v2/iptv/live/iptv%3A1%3A1/source","POST",{source:badCard}).ok then throw "provider substitution accepted"
 if SanitizeApiResponse("/api/v2/iptv/live/iptv%3A2%3A1/source","POST",{source:card}).ok then throw "cross-provider source accepted"

 m.top.visible = true : m.menuFocus = true : m.categoryBusy = false
 m.top.categories = [{id:"__categories_next",name:"A provider's real category"},{id:"last",name:"Last"}]
 m.top.categoryPage = {next_cursor:"nextpage",previous_cursor:"",last:false}
 epgCategoryState() : epgCategories()
 if m.filtersData.count() <> 6 then throw "new category controls introduced"
 m.menu = 5 : onKeyEvent("right",true)
 if m.top.categoryNeeded.cursor <> "nextpage" or not m.categoryBusy then throw "forward category boundary lost"
 m.top.categories = [{id:"first",name:"First"},{id:"last2",name:"Last"}]
 m.top.categoryPage = {next_cursor:"",previous_cursor:"priorpage",last:false}
 epgCategoryState() : epgCategories()
 if m.menu <> 4 or m.anchor <> 1900 then throw "forward category focus/time changed"
 onKeyEvent("left",true)
 if m.top.categoryNeeded.cursor <> "priorpage" or not m.top.categoryNeeded.last then throw "reverse category boundary lost"
 m.top.categoryPage = {next_cursor:"nextpage",previous_cursor:"",last:true}
 epgCategoryState() : epgCategories()
 if m.menu <> 5 then throw "backward category focus lost"
 body = PlaybackBody({id:"raw:1",type:"live",stream_id:"opaque"},"profile",{},0,false)
 if body.stream_id <> "opaque" or body.channel_id <> invalid or body.position <> 0 then throw "live lease body not opaque"
 print "LIVE_V2_RUNTIME_OK"
end sub
sub epgRender()
end sub
sub epgRequestGuides()
end sub
sub epgReveal()
end sub
sub epgWatchChannel()
end sub
sub epgDetails()
end sub
function epgProgrammes(id)
 return []
end function
sub uiBusy(busy)
end sub
sub request(method,path,body,tag)
 m.sent.push({method:method,path:path,body:body,tag:tag})
end sub
'''
with tempfile.TemporaryDirectory(prefix='roku-live-v2-') as directory:
    runner = Path(directory)/'live.brs'
    runner.write_text(production+'\n'+fixture)
    result = subprocess.run([os.environ.get('VIPTV_BRS_CLI','brs'),str(runner),
        str(root/'components/ApiTaskSanitize.brs'),str(root/'source/Util.brs'),
        str(root/'source/SourceLabels.brs'),str(root/'source/AccountPolicy.brs')],
        capture_output=True,text=True,timeout=30,cwd=directory)
    print(result.stdout); print(result.stderr)
    assert result.returncode == 0 and 'LIVE_V2_RUNTIME_OK' in result.stdout
    assert 'Runtime Error' not in result.stdout+result.stderr
