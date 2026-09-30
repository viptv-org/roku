"""Exercise actual native settings, caption, transport and track override boundaries."""
from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
def routine(file,start,end):
    text=(root/file).read_text();a=text.index(start);return text[a:text.index(end,a)+len(end)]
source=routine('components/HomeScene.brs','sub showPlaybackPreferences','end sub')+'\n'+routine('components/NavigationScene.brs','sub selectItem(','end sub')+'\n'+routine('components/ApiTaskSanitize.brs','function ProfilePreferencesWire','end function')+'\n'+(root/'source/JellyfinCaptionPolicy.brs').read_text()+'\n'+(root/'source/Util.brs').read_text()+'''
sub Main()
 m.profile="2":m.preferencesScope="2":m.config={base:"https://fixture.invalid"}
 prefs={audio_language:"en",subtitle_language:"en",subtitle_size:"large",subtitle_style:"opaque",subtitles_enabled:true,autoplay:false}
 clean=ProfilePreferencesWire(prefs)
 if clean.ok<>true or clean.data.DoesExist("quality") then throw "active settings require a retired quality field"
 prefs.quality="720p"
 legacy=ProfilePreferencesWire(prefs)
 if legacy.ok<>true or legacy.data.DoesExist("quality") then throw "legacy quality value remains active"
 showPlaybackPreferences(clean.data)
 if m.rendered.count()<>5 then throw "settings are not a bounded five-row view"
 if m.rendered[4].preferenceKey<>"subtitle_style" then throw "remaining final setting lost"
 selectItem(m.rendered[0])
 if m.options.count()<>11 then throw "audio language choices missing"
 selectItem(m.options[6])
 if m.savedPath<>"/api/profiles/2/preferences" or m.savedBody.audio_language<>"ja" then throw "native preference choice not saved to selected profile"
 m.savedPath=invalid:m.options=invalid
 selectItem({action:"preferencechoice",preferenceKey:"quality",name:"Retired",options:[]})
 if m.options<>invalid then throw "retired quality choice reopened"
 m.preferenceKey="quality"
 selectItem({action:"preferencesave",value:"480p"})
 if m.savedPath<>invalid then throw "retired quality mutation sent"
 video={}
 ApplyProfileCaptionStyle(video,clean.data)
 if video.captionStyle["Text/Size"]<>"Large" or video.captionStyle["Background/Opacity"]<>"100%" then throw "caption presentation not applied"
 ApplyProfileCaptionStyle(video,invalid)
 if video.captionStyle.count()<>0 then throw "previous profile caption appearance leaked"
 item={type:"movie",stream_id:"source1"}
 fields=TrackRequestFields(item,{owner:"source:source1",subtitle_track_index:2,audio_track_index:3,subtitles_off:true})
 if fields.subtitles_off<>true or fields.audio_track_index<>3 then throw "manual overrides lost"
 fields=TrackRequestFields(item,{owner:"source:source2",subtitles_off:true})
 if fields.count()<>0 then throw "another source inherited manual tracks"
 print "PROFILE_PREFERENCES_RUNTIME_OK"
end sub
sub rows(title,values,mode,description)
 m.rendered=values
end sub
sub uiOpenChoice(kind,title,values)
 m.options=values
end sub
sub request(method,path,body,tag)
 m.savedPath=path:m.savedBody=body
end sub
function AccountIsObject(value)
 return GetInterface(value,"ifAssociativeArray")<>invalid
end function
'''
with tempfile.TemporaryDirectory() as directory:
    fixture=Path(directory)/'preferences.brs';fixture.write_text(source)
    result=subprocess.run([os.environ.get('VIPTV_BRS_CLI','brs-cli'),str(fixture)],text=True,capture_output=True,cwd=directory,timeout=30)
    print(result.stdout,end='');print(result.stderr,end='')
    if result.returncode or 'PROFILE_PREFERENCES_RUNTIME_OK' not in result.stdout:raise SystemExit(1)
