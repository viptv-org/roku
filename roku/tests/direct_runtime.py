"""Actual discovery, recovery and seek handlers for original-media delivery."""
from pathlib import Path
import os,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'components/MainScene.brs').read_text()
def routine(name):
 a=source.index('sub '+name+'(');return source[a:source.index('end sub',a)+7]
fixture='\n'.join(routine(n) for n in ['findStreams','retryPlayback','seekToPosition','playerCommand','acceptPlayback','choosePlayerTrack'])+'\n'+(root/'source/Util.brs').read_text()+'\n'+(root/'source/ContinuationPolicy.brs').read_text()+'''
sub Main()
 m.profile="2":m.requests=[]:m.heading=invalid
 findStreams({id:"movie1",type:"movie",name:"Movie"})
 if m.requests.count()<>2 or m.requests[0].tag<>"sourcepreferences:2" then throw "discovery cancelled or mis-scoped preference loading"
 m.playing=true:m.playbackMode="direct":m.managedLive=true:m.directRetryUsed=false:m.video={state:"error",errorInfo:{category:"mediaerror"}}
 retryPlayback("unsupported format")
 if m.directRetryUsed<>true or m.startedForce<>false or m.recovery<>invalid then throw "direct format failure must use managed delivery before provider failover"
 m.playing=true:m.playbackMode="direct":m.managedLive=true:m.directRetryUsed=false:m.video={state:"error",errorInfo:{category:"http"}}:m.startedForce=invalid
 retryPlayback("origin 403")
 if m.recovery<>true or m.startedForce<>invalid then throw "origin error must not trigger transcoding"
 m.playing=true:m.playbackMode="direct":m.playItem={type:"movie"}:m.playbackLive=false:m.seeking=false:m.duration=600:m.pausedVOD=true:m.video={state:"paused"}
 playerCommand({getData:GetCommand,command:{kind:"seek",value:125}})
 if m.video.seek<>125 or m.video.autoplayAfterSeek<>false or m.directSeekPause<>true then throw "direct seek must preserve paused intent"
 m.video.state="playing"
 if DirectSeekPause(m.video,m.directSeekPause)<>false or m.video.control<>"pause" then throw "firmware native-seek autoplay ignored pause intent"
 m.video.state="paused"
 if DirectSeekPause(m.video,true)<>false then throw "honored pause must not interfere with later Play"
 m.heartbeat={}:m.startup={}:m.top={setFocus:Focus}:m.playerOverlay=invalid:m.captionRestore="Off":m.nextPrepping=false:m.nextTransitionSession="":m.nextTransitionConnection=invalid
 acceptPlayback({id:"new",url:"/media/new/cap/source.mp4",format:"mp4",mode:"direct",position:50,live:false,audio_tracks:[],subtitle_tracks:[],subtitles_supported:false},{base:"https://fixture.invalid"})
 if m.video.autoplayAfterSeek<>true then throw "new direct resume inherited paused seek state"
 m.trackKind="subtitles":m.playItem={type:"movie",stream_id:"source1"}:m.position=50:m.seeking=false:m.pausedVOD=true:m.video.state="paused":m.video.position=50:m.replacementVideo={}:m.status={}:m.config={capabilities:{}}:m.seekTimer={}:m.forced=false
 choosePlayerTrack({input_index:2,supported:true})
 if m.requests[m.requests.count()-1].body.managed_only<>true or m.requests[m.requests.count()-1].body.subtitle_track_index<>2 then throw "caption selection failed to request managed replacement"
 m.seeking=false:m.playbackMode="remux":m.directRetryUsed=false
 seekToPosition(100)
 if m.requests[m.requests.count()-1].body.managed_only<>true then throw "offset replacement could unexpectedly restart as direct at zero"
 print "DIRECT_RUNTIME_OK"
end sub
sub uiBusy(value)
end sub
sub ApplyProfileCaptionStyle(video,prefs)
end sub
sub PrepareNativeCaptions(video,enabled)
end sub
sub uiHidePageExtras()
end sub
sub applyPlayerSubtitles()
end sub
sub Focus(value)
end sub
function GetCommand()
 return m.command
end function
sub updatePlayer()
end sub
sub saveView()
end sub
sub cancelBrowse()
 m.requests=[]
end sub
sub resetAttempts()
end sub
sub request(method,path,body,tag)
 m.requests.push({tag:tag,path:path,body:body})
end sub
sub saveProgress()
end sub
sub stopPlayback(restore=true)
 m.playing=false
end sub
sub beginPlayback(force)
 m.startedForce=force
end sub
sub requestLiveRecovery()
 m.recovery=true
end sub
function retryContinuationSource()
 return false
end function
sub sourceExhausted(message)
end sub
'''
with tempfile.TemporaryDirectory() as directory:
 p=Path(directory)/'direct.brs';p.write_text(fixture)
 result=subprocess.run([os.environ.get('VIPTV_BRS_CLI','brs-cli'),str(p)],capture_output=True,text=True,timeout=30,cwd=directory)
 print(result.stdout,end='');print(result.stderr,end='')
 if result.returncode or 'DIRECT_RUNTIME_OK' not in result.stdout:raise SystemExit(1)
