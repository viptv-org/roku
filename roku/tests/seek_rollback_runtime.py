"""Actual seek transaction: primary decoder, pause intent, rollback and cleanup."""
from pathlib import Path
import subprocess,os,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'components/MainScene.brs').read_text()
def routine(name):
 a=s.index('sub '+name+'(');return s[a:s.index('end sub',a)+7]
code='\n'.join(routine(n) for n in ['seekToPosition','prepareSeekReplacement','beginPrimarySeekFallback','seekPrimaryVideoState','finishSeekSuccess','beginSeekRollback','finishSeekRollback','seekReplacementFailed'])+'''
sub Main()
 m.playing=true:m.playItem={type:"movie",stream_id:"source",name:"Movie"}:m.playbackLive=false
 m.video={state:"paused",position:35,content:{url:"old.m3u8"}}
 m.session="old":m.sessionConnection={base:"https://fixture.invalid"}:m.timelineOffset=600
 m.position=635:m.duration=3600:m.pausedVOD=true:m.seeking=false:m.playbackMode="transcode"
 m.config={capabilities:{}}:m.profile="1":m.forced=false:m.seekTimer={}:m.status={}:m.queue=[]
 m.generation=1:m.requestSequence=0
 seekToPosition(900)
 if m.video.control<>"pause" or m.session<>"old" then throw "preparation lost rollback session"
 prepareSeekReplacement({id:"new",url:"/media/new.m3u8",mode:"transcode",duration:3600},m.sessionConnection)
 if m.video.control<>"play" or m.seekPhase<>"primary" then throw "seek did not immediately start the ready primary"
 if m.session<>"old" then throw "old session released before new decoder played"
 m.video.state="playing":seekPrimaryVideoState()
 if m.session<>"new" or m.timelineOffset<>900 or m.video.control<>"pause" then throw "paused seek did not commit timeline and pause intent"
 if m.queue[m.queue.count()-1].path<>"/api/playback/old" then throw "successful seek leaked old session"
 m.video.state="playing":m.video.position=10:m.position=910:m.pausedVOD=false
 seekToPosition(1200)
 prepareSeekReplacement({id:"failed",url:"/media/failed.m3u8",mode:"transcode",duration:3600},m.sessionConnection)
 m.video.state="error":seekPrimaryVideoState()
 if m.seekPhase<>"rollback" or m.video.content.url<>"https://fixture.invalid/media/new.m3u8" then throw "decoder failure did not restore old content"
 if m.queue[m.queue.count()-1].path<>"/api/playback/failed" then throw "failed seek leaked replacement session"
 m.video.state="playing":seekPrimaryVideoState()
 if m.session<>"new" or m.position<>910 or m.video.seek<>10 or m.video.control<>"resume" then throw "rollback lost original clock or playing intent"
 if m.seeking or m.pendingPlayback then throw "rollback left seek busy"
 m.queue=[]:m.position=910:seekToPosition(910)
 if m.queue.count()<>0 then throw "unchanged seek allocated work"
 print "SEEK_ROLLBACK_OK"
end sub
sub request(method,path,body,tag,connection=invalid)
 m.requestSequence++:m.queue.push({method:method,path:path,body:body})
end sub
sub saveProgress()
end sub
sub updatePlayer()
end sub
sub PrepareNativeCaptions(video,enabled)
end sub
sub applyPlayerSubtitles()
end sub
sub cancelBrowse()
end sub
sub sourceExhausted(message)
 throw "unexpected rollback failure"
end sub
'''
with tempfile.TemporaryDirectory() as folder:
 p=Path(folder)/'seek.brs';p.write_text(code)
 r=subprocess.run([os.environ.get('VIPTV_BRS_CLI','/home/node/air-roku/node_modules/.bin/brs-cli'),str(p),str(root/'source/Util.brs')],capture_output=True,text=True,timeout=30)
 print(r.stdout,r.stderr)
 if r.returncode or 'SEEK_ROLLBACK_OK' not in r.stdout:raise SystemExit(1)
