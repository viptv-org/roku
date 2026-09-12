"""Next-episode transition must keep the player on screen (no tear-down, no stop)."""
from pathlib import Path
import subprocess, tempfile, os
root = Path(__file__).resolve().parents[1]

def routine(name):
    text = (root/'components'/'ContinuationScene.brs').read_text()
    a = text.index('sub ' + name + '(')
    end = 'end sub'
    return text[a:text.index(end, a) + len(end)]

cases = {
    'offer': routine('continuationBegin') + chr(10) + routine('resumeNextTransition') + chr(10) + '''
sub Main()
    m.stopped = false
    m.playItem = {id:"e2",type:"series",name:"Show",seriesName:"Show",poster:"p",season:1,episode:2}
    m.playbackLive = false
    m.session = "old-session" : m.sessionConnection = {base:"https://fixture.invalid"}
    m.playing = true : m.video = {state:"playing"}
    m.playerOverlay = {visible:false,opened:false}
    m.nextOwner = "e2" : m.nextScope = "1" : m.profile = "1"
    m.nextResult = {status:"next",item:{id:"e3"}}
    continuationBegin(false)
    if m.stopped then throw "transition tore down playback"
    if m.nextPrepping <> true then throw "transition not flagged"
    if m.nextTransitionSession <> "old-session" then throw "outgoing session not tracked"
    if m.session <> "" then throw "outgoing session not suspended"
    if m.video.control <> "pause" then throw "outgoing video not paused"
    if m.offered <> true then throw "prefetched next result not offered"
    resumeNextTransition()
    if m.nextPrepping then throw "resume did not clear transition"
    if m.session <> "old-session" then throw "resume did not restore session"
    if m.playing <> true then throw "resume did not restore playing"
    if m.video.control <> "resume" then throw "resume did not restart video"
    print "NEXT_TRANSITION_OFFER_OK"
end sub
sub stopPlayback(restore=true as boolean)
    m.stopped = true
end sub
sub saveProgress()
end sub
sub updatePlayer()
end sub
sub continuationOffer()
    m.offered = true
end sub
''',
    'resolve': routine('continuationBegin') + chr(10) + '''
sub Main()
    m.stopped = false
    m.playItem = {id:"e2",type:"series",name:"Show",seriesName:"Show",poster:"p"}
    m.playbackLive = false
    m.session = "old" : m.sessionConnection = invalid
    m.playing = true : m.video = {state:"playing"}
    m.playerOverlay = {visible:false,opened:false}
    m.nextOwner = "" : m.nextScope = "1" : m.profile = "1" : m.nextResult = invalid
    m.status = {}
    continuationBegin(false)
    if m.stopped then throw "transition tore down playback"
    if m.nextPrepping <> true then throw "transition not flagged"
    if m.resolveTag <> "continuationresolve" then throw "next identity not requested"
    print "NEXT_TRANSITION_RESOLVE_OK"
end sub
sub stopPlayback(restore=true as boolean)
    m.stopped = true
end sub
sub saveProgress()
end sub
sub updatePlayer()
end sub
sub request(method as string, path as string, body as dynamic, tag as string, connection = invalid as dynamic)
    m.resolveTag = tag
end sub
function continuationPath(suffix as string) as string
    return "/api/profiles/1/continue/" + suffix
end function
''',
}

with tempfile.TemporaryDirectory(prefix='viptv-next-transition-') as directory:
    for name, code in cases.items():
        path = Path(directory) / (name + '.brs')
        path.write_text(code)
        r = subprocess.run([
            os.environ.get('VIPTV_BRS_CLI', '/home/node/air-roku/node_modules/.bin/brs-cli'),
            str(path),
            str(root/'source'/'Util.brs'),
            str(root/'source'/'ContinuationPolicy.brs'),
        ], capture_output=True, text=True, timeout=30)
        print(r.stdout)
        print(r.stderr)
        if r.returncode or '_OK' not in r.stdout or 'Error' in r.stdout:
            raise SystemExit(1)