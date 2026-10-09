"""Managed pause uses title coordinates, never the moving native HLS window."""
from brs_cli import brs_command
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
def routine(file, name):
    text = (root/'components'/file).read_text()
    start = text.index('sub '+name+'(')
    return text[start:text.index('end sub',start)+len('end sub')]

text = (root/'components/SeekScene.brs').read_text()
start = text.index('function checkManagedResume(')
check = text[start:text.index('end function',start)+len('end function')]
source = routine('SeekScene.brs','pauseVOD')+'\n'+routine('SeekScene.brs','clearManagedResume')+'\n'+check+'\n'+routine('PlaybackScene.brs','saveProgress')
fixture = '''
sub Main()
    m.playing = true : m.playItem = {id:"movie",type:"movie",name:"Movie"}
    m.playbackLive = false : m.seeking = false : m.playbackMode = "direct" : m.playbackDeliveryKind = "gateway"
    m.pausedVOD = false : m.video = {state:"playing",position:5,duration:20}
    m.profile = "1" : m.timelineOffset = 42 : m.position = 42 : m.duration = 120
    pauseVOD()
    if m.managedPausePosition <> 47 or m.video.control <> "pause" then throw "pause title anchor missing"
    m.video.state = "paused" : m.video.position = 5
    saveProgress()
    if m.position <> 47 or m.saved.position <> 47 or m.duration <> 120 then throw "paused window advanced title progress"
    pauseVOD()
    if m.seekTarget <> invalid then throw "resume unnecessarily replaced healthy delivery"
    if m.video.control <> "resume" or m.pausedVOD then throw "resume did not continue the native decoder"
    if m.playbackMode <> "direct" then throw "pause/resume changed the output mode"
    m.video.state = "playing" : m.video.position = 5.5
    if checkManagedResume() or m.managedResumePosition <> invalid then throw "healthy resume did not retire recovery marker"
    m.video.state = "playing" : m.video.position = 6
    pauseVOD() : m.video.state = "paused" : pauseVOD()
    m.video.state = "error"
    if not checkManagedResume() or m.seekTarget <> 48 or not m.seekManaged or not m.seekResume then throw "failed native resume did not recover exact position"
    if checkManagedResume() then throw "resume recovery repeated"
    m.seekTarget = invalid
    m.video.state = "playing" : m.video.position = 7
    pauseVOD() : m.video.state = "paused" : pauseVOD()
    m.managedResumeClock = {totalMilliseconds:StalledElapsed}
    m.video.state = "buffering"
    if not checkManagedResume() or m.seekTarget <> 49 then throw "stalled resume did not recover frozen position"
    m.playbackDeliveryKind = "" : m.managedPausePosition = invalid
    m.video.state = "paused"
    pauseVOD()
    if m.video.control <> "resume" then throw "original native pause behavior changed"
    print "MANAGED_TIMELINE_RUNTIME_OK"
end sub
function StalledElapsed() as integer
    return 8000
end function
sub seekToPosition(target as double, managed=false as boolean, resumeAfterPause=false as boolean)
    m.seekTarget = target : m.seekManaged = managed : m.seekResume = resumeAfterPause
end sub
sub request(method,path,body,tag)
    m.saved = body
end sub
sub updatePlayer()
end sub
'''
with tempfile.TemporaryDirectory(prefix='viptv-roku-timeline-') as directory:
    runner = Path(directory)/'runner.brs'
    runner.write_text(source+'\n'+fixture)
    result = subprocess.run([*brs_command(),str(runner),str(root/'source/Util.brs'),str(root/'source/SourceLabels.brs')],capture_output=True,text=True,timeout=30,cwd=directory)
    print(result.stdout)
    print(result.stderr)
    assert result.returncode == 0 and 'MANAGED_TIMELINE_RUNTIME_OK' in result.stdout
    assert 'Runtime Error' not in result.stdout + result.stderr
