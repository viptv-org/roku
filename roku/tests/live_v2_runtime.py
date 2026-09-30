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
 source = SanitizeApiResponse("/api/v2/iptv/live/raw%3A1/source","POST",{source:{id:"opaque",url:"http://private.test/input",headers:{Authorization:"private"}}})
 if not source.ok or source.data.source.id <> "opaque" then throw "source id lost"
 if source.data.source.url <> invalid or source.data.source.headers <> invalid then throw "source leaked URL authority"
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
