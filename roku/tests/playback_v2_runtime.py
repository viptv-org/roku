"""Execute actual Task orchestration with only transport/device boundaries replaced."""
from brs_cli import brs_command
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
task = (root / 'components/ApiTask.brs').read_text()
def routine(name):
    start = task.index('function ' + name + '(')
    return task[start:task.index('end function', start) + len('end function')]

fixture = '''
sub Main()
    m.calls = []
    insecure = HttpRequest({path:"/api/v2/playback",base:"http://backend.invalid"},RokuPlaybackV2Empty("insecure"),"POST")
    if insecure.ok or instr(1,insecure.error,"HTTPS") = 0 or m.calls.count() <> 0 then throw "plaintext control attempted"
    for each scenario in ["pending","ambiguous","cancelled","refused","invalid"]
        m.top = {cancel:false}
        m.scenario = scenario : m.calls = []
        request = {path:"/api/v2/playback",base:"https://backend.invalid",tag:"playback|1",request_id:"1-2",body:{startup_id:"stable_1",stream_id:"exact_source",position:42}}
        result = RokuPlaybackV2Start(request,RokuPlaybackV2Empty(request.tag))
        if scenario = "pending"
            if not result.ok or result.data.id <> "pb2_fixture" or result.data.delivery_kind <> "gateway" then throw "pending failed"
            if result.data.position <> 42 or result.data.mode <> "direct" then throw "timeline facts lost"
            if m.calls.count() <> 3 or m.calls[1].method <> "GET" or right(m.calls[1].path,9) <> "/progress" or m.calls[2].method <> "GET" then throw "pending did not poll"
            if m.top.startupStage <> "Fetching metadata…" then throw "measured stage did not reach the Task field"
        else if scenario = "refused"
            if result.ok or m.calls.count() <> 1 or result.error <> "Configure a playback gateway." then throw "definitive refusal retried"
        else
            if result.ok or result.data <> invalid then throw "failed admission exposed media"
            if m.calls[m.calls.count()-1].method <> "DELETE" then throw "failed admission not released"
            if scenario = "ambiguous" or scenario = "cancelled"
                if m.calls.count() <> 3 then throw "ambiguous admission not reconciled"
                if m.calls[0].body <> m.calls[1].body then throw "idempotency body changed"
                if m.calls[1].cleanup <> true or m.calls[2].cleanup <> true then throw "cancelled scope used for cleanup"
                if m.calls[1].timeout > 5000 or m.calls[2].timeout > 5000 then throw "cleanup deadline unbounded"
            end if
            if scenario = "cancelled" and result.error <> "Cancelled" then throw "cancellation lost"
        end if
        for each call in m.calls
            if left(call.path,16) <> "/api/v2/playback" then throw "control followed media URL"
        end for
    end for
    print "PLAYBACK_V2_RUNTIME_OK"
end sub

function DeviceCapabilities() as object
    return {max_width:3840,max_height:2160,h264:true,hevc:true,aac:true}
end function

function HttpRequestRaw(request as object, result as object, method as string, sanitize as boolean) as object
    m.calls.push({path:request.path,method:method,body:FormatJson(request.body),cleanup:request.cleanup,timeout:request.timeout_ms})
    result.status = 200 : result.ok = true
    if right(request.path,9) = "/progress"
        result.data = {stage:"fetching_metadata"}
        return result
    end if
    if method = "DELETE"
        result.data = {}
        return result
    end if
    if m.calls.count() = 1
        if m.scenario = "ambiguous" or m.scenario = "cancelled"
            if m.scenario = "cancelled" then m.top.cancel = true
            result.status = 0 : result.ok = false : result.error = "Network request failed"
            return result
        else if m.scenario = "refused"
            result.status = 409 : result.ok = false : result.error = "Configure a playback gateway."
            return result
        end if
    end if
    result.data = {id:"pb2_fixture",status:"ready",expires_at:CreateObject("roDateTime").asSeconds()+60,renew_after_seconds:20,delivery:{kind:"gateway",url:"https://gateway.invalid/base/media/viewer/cap/index.m3u8",format:"hls",mode:"direct",video_mode:"copy",audio_mode:"copy",position:42,duration:120,live:false,audio_tracks:[],subtitle_tracks:[],subtitles_supported:false}}
    if m.calls.count() = 1 and m.scenario = "pending" then result.data.status = "starting"
    if m.scenario = "invalid" then result.data.delivery.kind = "direct"
    return result
end function
'''
production = (root / 'components/ApiPlaybackV2.brs').read_text()
production += '\n' + routine('ApiDisplayError') + '\n' + routine('ApiErrorField') + '\n' + routine('HttpRequest')
with tempfile.TemporaryDirectory(prefix='viptv-roku-v2-') as directory:
    runner = Path(directory) / 'runner.brs'
    runner.write_text(production + '\n' + fixture)
    result = subprocess.run([
        *brs_command(), str(runner),
        str(root/'components/ApiPlaybackV2Policy.brs'), str(root/'components/ApiTaskSanitize.brs'),
        str(root/'source/Util.brs'), str(root/'source/SourceLabels.brs'), str(root/'source/AccountPolicy.brs'),
    ], capture_output=True, text=True, timeout=30, cwd=directory)
    print(result.stdout)
    print(result.stderr)
    assert result.returncode == 0 and 'PLAYBACK_V2_RUNTIME_OK' in result.stdout
    assert 'Runtime Error' not in result.stdout + result.stderr
