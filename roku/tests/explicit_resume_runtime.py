"""Exercise actual source entry and resume handlers; browsing never starts playback."""
from pathlib import Path
import os, subprocess, tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'components/MainScene.brs').read_text()
def routine(name):
    start = source.index('sub ' + name + '(')
    return source[start:source.index('end sub', start) + 7]

cases = {
    'entry': routine('selectItem') + '''
sub Main()
 m.mode="episodes":m.selected={id:"series",type:"series"}
 selectItem({id:"episode",type:"series",position:90})
 if m.chosen.manual<>true then throw "opening an episode armed automatic resume"
 m.mode="detail":m.selected={id:"movie",type:"movie",position:90}
 selectItem({action:"sources"})
 if m.chosen.manual<>true then throw "Choose source armed automatic resume"
 selectItem({action:"play"})
 if m.chosen.manual<>true then throw "ordinary Play armed automatic resume"
 selectItem({action:"resume"})
 if m.chosen.manual<>false then throw "explicit Resume did not request the saved source"
 print "EXPLICIT_RESUME_ENTRY_OK"
end sub
function selectQueueItem(item)
 return false
end function
function EpisodePresentationItem(series,episode)
 return episode
end function
function StableResumePreference(item)
 return {source_fingerprint:"saved"}
end function
sub findStreams(item,manual=true,preference=invalid,automatic=false)
 m.chosen={manual:manual}
end sub
''',
    'decision': routine('tryResumeSource') + '''
sub Main()
 m.pendingPlayback=false:m.playing=false:m.manualSources=true
 m.streams=[{id:"saved"}]:m.resumeSourcePreference={}:m.discoveryDone=true
 m.mode="streams":m.resumeTimer={}
 tryResumeSource():tryResumeSource()
 if m.started<>invalid then throw "source polling started playback while browsing"
 m.mode="resuming":m.manualSources=false
 tryResumeSource()
 if m.started<>"saved" then throw "explicit Resume delayed instead of playing the match"
 m.started=invalid
 tryResumeSource()
 if m.started<>invalid then throw "resume intent was reusable"
 m.mode="streams":m.manualSources=false:m.resumeSourcePreference={}
 tryResumeSource()
 if m.started<>invalid then throw "stale resume intent started playback on Sources"
 print "EXPLICIT_RESUME_DECISION_OK"
end sub
function SourceMatchesPreference(source,preference)
 return true
end function
function BestContinuationSource(streams,preference)
 return invalid
end function
sub playSource(source)
 m.started=source.id
end sub
sub uiSourceHeader()
end sub
sub rows(title,items,mode,subtitle="",enter=true)
 m.mode=mode
end sub
sub uiBusy(active)
end sub
'''
}
cases['transient_route']=routine('saveView')+'''
sub Main()
 m.mode="resuming":m.views=[]:m.list={itemFocused:0}:m.homeActions={itemFocused:0}
 saveView()
 if m.views.count()<>0 then throw "navigation saved a transient Resume screen as a return destination"
 print "EXPLICIT_RESUME_ROUTE_OK"
end sub
function CopyRouteData(value)
 return value
end function
'''
with tempfile.TemporaryDirectory(prefix='viptv-explicit-resume-') as folder:
    failures = []
    for name, code in cases.items():
        path = Path(folder) / (name + '.brs')
        path.write_text(code + '\nfunction Txt(value, fallback="")\n if value=invalid then return fallback\n return value.toStr()\nend function\n')
        result = subprocess.run([os.environ.get('VIPTV_BRS_CLI', '/home/node/air-roku/node_modules/.bin/brs-cli'), str(path)], capture_output=True, text=True, timeout=30)
        print(result.stdout, result.stderr)
        if result.returncode or '_OK' not in result.stdout:
            failures.append(name)
    if failures:
        raise SystemExit('Failed: ' + ', '.join(failures))
