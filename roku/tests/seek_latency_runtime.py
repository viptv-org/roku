"""Actual scheduling, seek preparation, no-op and cancellation behavior."""
from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
scene=(root/'components/MainScene.brs').read_text()
def routine(name):
    start=scene.index('sub '+name+'(')
    return scene[start:scene.index('end sub',start)+7]
cases={
 'queue':routine('dispatchRequests')+'''
sub Main()
 m.tasks=[{state:"run",request:{method:"POST",tag:"sideprogress|0"}}]
 m.queue=[{method:"POST",path:"/progress",tag:"sideprogress|0"},{method:"POST",path:"/api/playback",tag:"seekplayback|0"}]
 dispatchRequests()
 if m.sent=invalid then throw "seek waited behind history"
 if m.sent.tag<>"seekplayback|0" then throw "history overtook seek"
 m.sent=invalid
 dispatchRequests()
 if m.sent<>invalid then throw "history writes lost serialization"
 m.tasks=[{state:"run",request:{method:"POST",tag:"auth:profile|0"}}]
 m.queue=[{method:"POST",path:"/api/playback",tag:"seekplayback|0"}]
 dispatchRequests()
 if m.sent<>invalid then throw "seek overtook an authentication mutation"
 print "SEEK_QUEUE_OK"
end sub
sub startRequest(entry)
 m.sent=entry
end sub
sub homeMutation(entry,value)
end sub
''',
 'prepared':routine('prepareSeekReplacement')+'''
sub Main()
 m.seeking=true:m.playItem={name:"Movie"}:m.seekTimer={}:m.replacementVideo={}:m.video={}
 prepareSeekReplacement({id:"ready",url:"/media/ready/cap/index.m3u8",format:"hls"},{base:"https://fixture.invalid"})
 if m.primary<>true then throw "prepared seek waits for a second decoder"
 if m.deleted=true then throw "prepared seek deleted rollback session"
 print "SEEK_PREPARED_OK"
end sub
sub beginPrimarySeekFallback()
 m.primary=true
end sub
sub request(method,path,body,tag,connection=invalid)
 m.deleted=true
end sub
sub PrepareNativeCaptions(video,enabled)
end sub
''',
 'cancel':routine('request')+'''
sub Main()
 m.config={base:"https://fixture.invalid",access_token:"fixture",last_profile_id:"1"}
 m.queue=[]:m.generation=1:m.accountEpoch=1:m.prepSpent=0
 request("POST","/api/playback",{stream_id:"source",position:100},"seekplayback")
 if Txt(m.queue[0].body.startup_id)="" then throw "VOD seek has no server cancellation identity"
 print "SEEK_CANCEL_OK"
end sub
'''
}
overlay=(root/'components/PlayerOverlay.brs').read_text()
def overlay_routine(name):
    start=overlay.index('sub '+name+'(')
    return overlay[start:overlay.index('end sub',start)+7]
cases['noop']=overlay_routine('commitSeekPreview')+'\n'+overlay_routine('cancelSeekPreview')+'''
sub Main()
 m.seekDebounceTimer={}:m.preview=100
 m.top={model:{position:100,duration:600,live:false,seeking:false},hasFocus:HasFocus}
 commitSeekPreview()
 if m.emitted=true then throw "unchanged target emitted a seek"
 m.preview=130
 commitSeekPreview()
 if m.target<>130 then throw "changed target failed to emit"
 print "SEEK_NOOP_OK"
end sub
function HasFocus()
 return true
end function
sub emit(kind,value)
 m.emitted=true:m.target=value
end sub
sub render()
end sub
'''
with tempfile.TemporaryDirectory(prefix='viptv-seek-latency-') as folder:
    failed=[]
    for name,code in cases.items():
        path=Path(folder)/(name+'.brs');path.write_text(code)
        result=subprocess.run([os.environ.get('VIPTV_BRS_CLI','/home/node/air-roku/node_modules/.bin/brs-cli'),str(path),str(root/'source/Util.brs')],capture_output=True,text=True,timeout=30)
        print(result.stdout,result.stderr)
        if result.returncode or '_OK' not in result.stdout:failed.append(name)
    if failed:raise SystemExit('Failed: '+', '.join(failed))
