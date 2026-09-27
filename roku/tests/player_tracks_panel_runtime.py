"""Track UI exposes one complete right-panel list and rejects stale selections."""
from pathlib import Path
import os,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
text=(root/'components/PlaybackScene.brs').read_text()
def routine(name):
 a=text.index('sub '+name+'(');return text[a:text.index('end sub',a)+7]
fixture='''
sub Main()
 m.session="session-a":m.playItem={type:"movie",id:"film"}:m.generation=7:m.choicePanel={}
 m.audioTracks=[]:m.subtitleTracks=[]:m.subtitlesSupported=true
 for i=0 to 11
  m.audioTracks.push({input_index:i,language:"en",codec:"aac",selectable:true,selected:i=7})
 end for
 showPlayerTracks("audio")
 if m.choiceKind<>"playerTracks" or m.choicePanel.model.items.count()<>13 then throw "tracks split across pages or wrong panel"
 if m.choicePanel.model.index<>7 then throw "current track not focused"
 if instr(1,m.choicePanel.model.items[7].name,"Current")=0 then throw "current track unmarked"
 m.chosen=invalid
 uiPlayerTrackChosen(4)
 if m.chosen.input_index<>4 then throw "track panel changed identity"
 showPlayerTracks("audio")
 m.session="replacement":m.chosen=invalid
 uiPlayerTrackChosen(3)
 if m.chosen<>invalid then throw "stale session track was applied"
 showPlayerTracks("subtitles")
 if m.choicePanel.model.items[0].action<>"off" then throw "subtitle Off missing"
 if instr(1,m.choicePanel.model.description,"no selectable subtitles")=0 then throw "empty track state unexplained"
 print "PLAYER_TRACKS_PANEL_OK"
end sub
sub closePlayerTracks()
end sub
sub choosePlayerTrack(choice as object)
 m.chosen=choice
end sub
'''
with tempfile.TemporaryDirectory() as temp:
 p=Path(temp)/'tracks.brs';p.write_text(routine('showPlayerTracks')+'\n'+routine('uiPlayerTrackChosen')+'\n'+fixture)
 r=subprocess.run([os.environ['VIPTV_BRS_CLI'],str(p),str(root/'source/Util.brs')],capture_output=True,text=True,timeout=30)
 print(r.stdout,r.stderr)
 assert r.returncode==0 and 'PLAYER_TRACKS_PANEL_OK' in r.stdout
