"""Exercise production transition handlers with network/decoder edges recorded."""
from pathlib import Path
import subprocess, tempfile, os
root=Path(__file__).resolve().parents[1]
def routine(file,start,end):
 text=(root/file).read_text();a=text.index(start);return text[a:text.index(end,a)+len(end)]
tests=[('end',routine('components/PlaybackScene.brs','sub videoState()','end sub'),'''
sub Main()
 m.video={state:"finished"} : m.playing=true : m.hasPlayed=true
 m.playItem={type:"series"} : m.duration=1000 : m.position=1000
 videoState()
 if m.nextCalled<>true then throw "finished series has no next transition"
 m.nextCalled=false : m.position=100
 videoState()
 if m.nextCalled then throw "early failure autoplays"
 m.playItem.type="movie" : m.position=1000
 videoState()
 if m.nextCalled then throw "movie autoplays"
 m.playItem.type="series" : m.duration=0
 videoState()
 if m.nextCalled then throw "unknown duration autoplays"
 print "CONTINUATION_END_OK"
end sub
sub saveProgress()
end sub
sub stopPlayback(restore=true as boolean)
end sub
sub continuationBegin(automatic as boolean)
 m.nextCalled=true
end sub
sub sourceExhausted(reason as string)
end sub
sub beginPlayback(force as boolean)
end sub
sub retryPlayback(reason as string)
end sub
sub requestLiveRecovery()
end sub
sub prefetchContinuation()
end sub
'''),('next',routine('components/ContinuationScene.brs','sub continuationPlay()','end sub'),'''
sub Main()
 m.top={dialog:{id:"continuation"}}:m.nextScope="1":m.profile="1"
 m.continuationItem={id:"next",type:"series"}
 continuationPlay()
 if m.started.id<>"next" or m.started.manual<>false then throw "Next episode must select its best source"
 m.started=invalid:m.nextScope="old-profile"
 continuationPlay()
 if m.started<>invalid then throw "stale Next action accepted"
 print "CONTINUATION_NEXT_OK"
end sub
sub findStreams(item,manual=true,preference=invalid,automatic=false)
 m.started={id:item.id,manual:manual}
end sub
''')]
tests.append(('progress',routine('components/MainScene.brs','sub request(', 'end sub'),'''
sub Main()
 m.queue=[] : m.config={base:"http://fixture.invalid",access_token:"fixture",last_profile_id:"1"}
 m.generation=1 : m.accountEpoch=1
 request("PUT","/api/profiles/1/progress",{id:"episode1",type:"series",position:10},"sideprogress")
 request("PUT","/api/profiles/1/progress",{id:"episode1",type:"series",position:100},"sideprogress")
 request("PUT","/api/profiles/1/progress",{id:"episode2",type:"series",position:5},"sideprogress")
 if m.queue.count()<>2 then throw "next episode erased pending completion write"
 if m.queue[0].body.position<>100 then throw "same-episode progress did not coalesce"
 print "CONTINUATION_PROGRESS_OK"
end sub
function homeRevision(kind as string) as integer
 return 0
end function
'''))
with tempfile.TemporaryDirectory(prefix='viptv-continuation-runtime-') as directory:
 for name,production,fixture in tests:
  path=Path(directory)/(name+'.brs');path.write_text(production+'\n'+fixture)
  r=subprocess.run([os.environ.get('VIPTV_BRS_CLI','/home/node/air-roku/node_modules/.bin/brs-cli'),str(path),str(root/'source/Util.brs'),str(root/'source/ContinuationPolicy.brs')],capture_output=True,text=True,timeout=30)
  print(r.stdout);print(r.stderr)
  if r.returncode or '_OK' not in r.stdout or 'Error' in r.stdout: raise SystemExit(1)
