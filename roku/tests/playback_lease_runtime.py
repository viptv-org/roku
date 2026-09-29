"""Real render-thread lease callbacks, with only SceneGraph/effect boundaries stubbed."""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
main = (root/'components/MainScene.brs').read_text()
start = main.index('sub request(')
request = main[start:main.index('end sub',start)+len('end sub')]
fixture = '''
sub Main()
    m.playbackLeases = {} : m.leaseTick = {}
    m.generation = 1 : m.accountEpoch = 1 : m.requestSequence = 0 : m.queue = []
    connection = {path:"/api/v2/playback",base:"https://backend.invalid",access_token:"fixture",last_profile_id:"1"}
    data = {id:"lease",delivery_kind:"gateway",url:"https://gateway.invalid/media/viewer/cap/index.m3u8",expires_at:CreateObject("roDateTime").asSeconds()+60,renew_after_seconds:20}
    registerRokuPlaybackLease(data,connection)
    m.playbackLeases.lease.clock = {TotalMilliseconds:Elapsed}
    origin = {path:"/api/v2/playback/lease/heartbeat",access_token:"fixture"}
    rokuPlaybackHeartbeatResponse({ok:false,status:0,error:"Network request failed"},origin)
    if m.playbackLeases.lease.clock.TotalMilliseconds() <> 6000 then throw "network failure extended lease"
    if m.playbackLeases.lease.renew_after_seconds <> 2 then throw "retry interval lost"
    m.playbackLeases.lease.renew_after_seconds = 0
    rokuPlaybackLeaseTick()
    if m.queue.count() <> 1 or m.queue[0].path <> origin.path then throw "renewal used media origin"
    if m.playbackLeases.lease.pending <> true then throw "renewal not coalesced"
    request("DELETE","/api/v2/playback/lease",invalid,"cleanup",connection)
    rokuPlaybackHeartbeatResponse({ok:true,data:data,status:200},origin)
    if m.playbackLeases.count() <> 0 then throw "late heartbeat restored released lease"
    m.queue = []
    registerRokuPlaybackLease(data,connection)
    rokuPlaybackHeartbeatResponse({ok:false,status:403,error:"Gateway access revoked"},origin)
    if m.failure <> "Gateway access revoked" or m.stopped <> true or m.cancelled <> true then throw "refusal did not stop playback"
    if m.playbackLeases.count() <> 0 then throw "revoked media retained"
    m.stopped = false : m.cancelled = false
    registerRokuPlaybackLease(data,connection)
    m.playbackLeases.lease.remaining_seconds = 0
    rokuPlaybackLeaseTick()
    if not m.stopped or instr(1,m.failure,"expired") = 0 then throw "expiry did not stop media"
    registerRokuPlaybackLease(data,connection)
    mismatched = {} : mismatched.append(data) : mismatched.url = "https://gateway.invalid/media/different"
    rokuPlaybackHeartbeatResponse({ok:true,status:200,data:mismatched},origin)
    if instr(1,m.failure,"different playback") = 0 then throw "changed delivery accepted"
    if PlaybackSessionPath(connection,"x") <> "/api/v2/playback/x" then throw "v2 release route lost"
    if PlaybackSessionPath({path:"/api/playback"},"x") <> "/api/playback/x" then throw "legacy live release changed"
    print "PLAYBACK_LEASE_RUNTIME_OK"
end sub
sub cancelBrowse()
    m.cancelled = true
end sub
sub stopPlayback(restore=true as boolean)
    m.stopped = true
end sub
sub sourceExhausted(reason as string)
    m.failure = reason
end sub
function Elapsed() as integer
    return 6000
end function
'''
with tempfile.TemporaryDirectory(prefix='viptv-roku-lease-') as directory:
    runner = Path(directory)/'runner.brs'
    runner.write_text((root/'components/PlaybackLeaseScene.brs').read_text()+'\n'+request+'\n'+fixture)
    result = subprocess.run([os.environ.get('VIPTV_BRS_CLI','brs'),str(runner),str(root/'source/Util.brs'),str(root/'source/SourceLabels.brs')], capture_output=True,text=True,timeout=30,cwd=directory)
    print(result.stdout)
    print(result.stderr)
    assert result.returncode == 0 and 'PLAYBACK_LEASE_RUNTIME_OK' in result.stdout
    assert 'Runtime Error' not in result.stdout + result.stderr
