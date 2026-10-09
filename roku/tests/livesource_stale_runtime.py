"""A stale live-source reply must release pending admission flags.

Reproduces the freeze-lookalike: cancelBrowse() bumps the generation after the
live source request is issued; the reply previously hit the generation guard
and was silently dropped while m.pendingPlayback stayed true, leaving a
permanent busy spinner and 'Playback is already preparing' dead end.
"""
from brs_cli import brs_command
from pathlib import Path
import subprocess, tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "components" / "ResponseScene.brs").read_text()

def routine(source, start, end):
    begin = source.index(start)
    return source[begin:source.index(end, begin) + len(end)]

production = routine(source, "sub handleResponse(", "end sub")

fixture = '''
sub Main()
 m.acknowledgementRendering = false
 ' A live source request was issued under generation 5, then navigation
 ' bumped the generation to 6 before the reply landed.
 m.generation = 6
 m.accountEpoch = 0
 m.accountMode = false
 m.pendingPlayback = true
 m.liveSourcePending = true
 m.busyCalls = 0
 m.started = 0
 m.exhausted = ""
 m.playItem = {id:"raw:1",type:"live"}
 handleResponse({getData:LiveReply,getRoSGNode:StaleNode})
 if m.pendingPlayback then throw "stale livesource reply left pendingPlayback set"
 if m.liveSourcePending then throw "stale livesource reply left liveSourcePending set"
 if m.busyCalls <> 1 then throw "stale livesource reply did not clear the busy panel"
 if m.started <> 0 then throw "stale livesource reply must not start playback"
 ' Current-generation replies still start playback exactly as before.
 m.pendingPlayback = true
 m.liveSourcePending = true
 handleResponse({getData:OkReply,getRoSGNode:FreshNode})
 if m.started <> 1 then throw "fresh livesource reply did not begin playback"
 ' A stale reply with no pending admission changes nothing (no stray uiBusy).
 m.busyCalls = 0
 handleResponse({getData:LiveReply,getRoSGNode:StaleNode})
 if m.busyCalls <> 0 then throw "stale reply with no pending admission touched the busy panel"
 print "LIVESOURCE_STALE_OK"
end sub
function LiveReply() as object
 return {tag:"livesource|5",ok:false,data:invalid,error:"unavailable",status:0}
end function
function OkReply() as object
 return {tag:"livesource|6",ok:true,data:{source:{id:"source-1"}},status:200}
end function
function StaleNode() as object
 return {request:{request_id:"6-1",tag:"livesource|5",account_epoch:0}}
end function
function FreshNode() as object
 return {request:{request_id:"6-2",tag:"livesource|6",account_epoch:0}}
end function
sub beginPlayback(force as boolean)
 m.started += 1
end sub
sub sourceExhausted(message as string)
 m.exhausted = message
end sub
sub uiBusy(active as boolean, message = "Loading" as string)
 if not active then m.busyCalls += 1
end sub
sub stopPlayback(restore = true as boolean)
end sub
function accountResponse(tag as string, result as object, origin as object) as boolean
 return false
end function
sub rokuPlaybackHeartbeatResponse(result as object, origin as object)
end sub
sub liveEpgResponse(tag as string, result as object, generation as integer)
end sub
sub playerTitleResponse(tag as string, result as object, origin as object)
end sub
sub epgResponse(tag as string, result as object)
end sub
sub uiUpdateSources(values as object, enter as boolean)
end sub
sub showPlaybackPreferences(data as object)
end sub
sub rows(title as string, values as object, mode as string, subtitle = "" as string, enter = true as boolean)
end sub
function continuationResponse(tag as string, result as object) as boolean
 return false
end function
function libraryResponse(tag as string, result as object) as boolean
 return false
end function
sub applyEpisodeProgress(result as object)
end sub
sub startupArtworkResponse(tag as string, result as object)
end sub
sub uiCardArtworkResponse(tag as string, result as object)
end sub
sub uiHeroArtResponse(tag as string, result as object)
end sub
sub homeCatalogResponse(tag as string, result as object)
end sub
sub homeResponse(tag as string, result as object)
end sub
sub homeMutation(origin as object, reconcile as boolean)
end sub
sub accountRevoked()
end sub
sub accountRefresh()
end sub
sub accountOpenProfiles()
end sub
sub accountClearRememberedProfile()
end sub
'''

with tempfile.TemporaryDirectory() as temp:
    path = Path(temp) / "livesource_stale.brs"
    path.write_text(production + fixture)
    p = subprocess.run(
        [*brs_command(), str(path), str(root / "source" / "Util.brs"), str(root / "source" / "SourceLabels.brs")],
        capture_output=True, text=True, timeout=60,
    )
    print(p.stdout, p.stderr)
    if p.returncode or "LIVESOURCE_STALE_OK" not in p.stdout:
        raise SystemExit(1)
