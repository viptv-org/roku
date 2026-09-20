"""Headless production handlers: next intent, end trigger and previous-episode actions."""
from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
def routine(file,name,kind='sub'):
    s=(root/'components'/file).read_text();a=s.index(kind+' '+name+'(')
    end='end '+kind
    return s[a:s.index(end,a)+len(end)]
cases={
'decision':routine('SourcesScene.brs','tryResumeSource')+'''
sub Main()
 m.config={capabilities:{max_height:1080}}:m.sourcePreferences={}
 m.mode="resuming":m.manualSources=false:m.playing=false:m.pendingPlayback=false
 m.streams=[{id:"weak",source_addon_id:"addon:1",title:"1080p x264 English"},{id:"dub",source_addon_id:"addon:2",title:"1080p x264 English dubbed"}]
 m.resumeSourcePreference={continuation:true,source_addon_id:"addon:1"}
 m.discoveryDone=false
 tryResumeSource()
 if m.started<>invalid then throw "addon choice made before discovery completed"
 m.discoveryDone=true:tryResumeSource()
 if m.started<>"dub" then throw "next did not use weighted best match"
 m.started=invalid:tryResumeSource()
 if m.started<>invalid then throw "consumed next intent replayed"
 m.resumeSourcePreference={continuation:true,source_addon_id:"iptv:2"}
 m.streams=[{id:"other",source_addon_id:"iptv:3"},{id:"next",source_addon_id:"iptv:2"}]
 m.discoveryDone=false:tryResumeSource()
 if m.started<>"next" then throw "IPTV waited for scoring/discovery completion"
 m.started=invalid:m.mode="streams":m.resumeSourcePreference={continuation:true,source_addon_id:"iptv:2"}
 tryResumeSource()
 if m.started<>invalid then throw "return to Sources rearmed next"
 print "NEXT_DECISION_OK"
end sub
sub playSource(source)
 m.started=source.id
end sub
sub uiBusy(active)
end sub
sub rows(title,items,mode,subtitle="")
 m.mode=mode
end sub
sub uiSourceHeader()
end sub
''',
'end':routine('PlaybackScene.brs','updatePlayer')+'''
sub Main()
 m.playerOverlay={}:m.playItem={id:"e1",type:"series",season:1,episode:3,episodeTitle:"Pilot"}:m.playing=true:m.hasPlayed=true
 m.video={position:990,state:"playing"}:m.position=0:m.timelineOffset=0:m.duration=1000
 m.nextResult={status:"next"}:m.nextOwner="e1":m.nextScope="1":m.profile="1"
 updatePlayer()
 if m.calls<>1 then throw "final ten seconds did not advance"
 m.calls=0:m.video.state="paused":updatePlayer()
 if m.playerOverlay.model.episode<>"S1 E3 · Pilot" then throw "player does not surface the episode"
 m.video.state="playing":m.seeking=true:updatePlayer()
 m.seeking=false:m.video.position=980:updatePlayer()
 m.video.position=995:m.nextOwner="old":updatePlayer()
 m.nextOwner="e1":m.nextResult.status="caught_up":updatePlayer()
 m.nextResult.status="next":m.skipNearEndContinuation=true:updatePlayer()
 m.skipNearEndContinuation=false:m.playing=false:updatePlayer()
 if m.calls<>0 then throw "ineligible playback triggered next"
 print "NEXT_END_OK"
end sub
sub continuationBegin(automatic)
 if m.calls=invalid then m.calls=0
 m.calls++
end sub
''',
'menu':routine('ContinuationScene.brs','queueMenu','function')+'''
sub Main()
 m.mode="home":m.homePosition=[0,0]
 m.homeRows={hasFocus:NoFocus}:m.homeActions={hasFocus:Focus}
 m.item={id:"e2",name:"Show",type:"series",queue_status:"next",position:0,previous_episode:{id:"e1",position:995}}
 if not queueMenu() then throw "hold OK on next action did not open menu"
 if m.choices[0].action<>"queueresume" then throw "regular Resume missing"
 if m.queueItem.previous_episode.id<>"e1" then throw "previous episode lost"
 print "NEXT_MENU_OK"
end sub
function Focus()
 return true
end function
function NoFocus()
 return false
end function
function homeCurrent()
 return m.item
end function
sub uiOpenChoice(kind,title,choices)
 m.choices=choices
end sub
'''
}
cases['resume']=routine('NavigationScene.brs','selectItem')+'''
sub Main()
 m.mode="home"
 m.queueItem={id:"e2",type:"series",queue_status:"next",position:0,previous_episode:{id:"e1",type:"series",position:995,duration:1000,source_addon_id:"iptv:2",source_name:"Provider",source_fingerprint:"saved"}}
 selectItem({action:"queueresume"})
 if m.chosen.item.id<>"e1" or m.chosen.item.position<>995 then throw "Resume targeted next episode"
 if m.chosen.manual or m.chosen.preference.source_fingerprint<>"saved" then throw "Resume lost saved source"
 selectItem({action:"queuesources"})
 if not m.chosen.manual then throw "menu source browsing autoplays"
 print "NEXT_RESUME_OK"
end sub
sub findStreams(item,manual=true,preference=invalid,automatic=false)
 m.chosen={item:item,manual:manual,preference:preference}
end sub
'''
cases['fallback']=routine('ContinuationScene.brs','retryContinuationSource','function')+'''
sub Main()
 m.config={capabilities:{max_height:1080}}:m.sourcePreferences={}
 m.continuationSourcePreference={source_addon_id:"addon:1"}
 m.pendingPlayback=false:m.attempted={bad:true}:m.prepSpent=0
 m.sourcesAt=CreateObject("roDateTime").asSeconds()
 m.streams=[{id:"bad",source_addon_id:"addon:1",title:"1080p English dubbed"},{id:"next",source_addon_id:"addon:2",title:"1080p English dubbed"}]
 if not retryContinuationSource() or m.started<>"next" then throw "failed ranked source was not skipped"
 m.started=invalid:m.attempted={bad:true,next:true,third:true}
 if retryContinuationSource() or m.started<>invalid then throw "fallback exceeded three sources"
 m.attempted={bad:true}:m.continuationSourcePreference={source_addon_id:"iptv:2"}
 if retryContinuationSource() then throw "IPTV failure switched to addon"
 print "NEXT_FALLBACK_OK"
end sub
sub playSource(source)
 m.started=source.id
end sub
'''
cases['hold']=routine('PresentationArtworkScene.brs','uiResumeAction')+'''
sub Main()
 m.homeActions={hasFocus:Focused,itemFocused:0}
 m.item={id:"e2",type:"series",season:1,episode:2,queue_status:"next"}
 event={getData:Data}
 event.held=false:uiResumeAction(event)
 if m.selected<>true or m.menu=true then throw "short OK opened hold menu"
 m.selected=false:event.held=true:uiResumeAction(event)
 if m.menu<>true or m.selected then throw "hold OK started playback"
 print "NEXT_HOLD_OK"
end sub
function Focused()
 return true
end function
function Data()
 return {held:m.held}
end function
function homeCurrent()
 return m.item
end function
function queueMenu()
 m.menu=true
 return true
end function
sub uiHomeActionSelected()
 m.selected=true
end sub
'''
with tempfile.TemporaryDirectory(prefix='viptv-next-') as folder:
    for name,code in cases.items():
        path=Path(folder)/(name+'.brs');path.write_text(code)
        result=subprocess.run([os.environ.get('VIPTV_BRS_CLI','/home/node/air-roku/node_modules/.bin/brs-cli'),str(path),*[str(root/'source'/f) for f in ['Util.brs','PresentationPolicy.brs','ContinuationPolicy.brs']]],capture_output=True,text=True,timeout=30)
        print(result.stdout,result.stderr)
        if result.returncode or '_OK' not in result.stdout or 'Error' in result.stdout:raise SystemExit(1)
