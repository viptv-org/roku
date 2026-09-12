"""Run production library navigation/mutation handlers against user actions."""
from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'components/LibraryScene.brs').read_text() if (root/'components/LibraryScene.brs').exists() else ''
fixture='''
sub Main()
 m.profile="7" : m.list={itemFocused:3} : m.mode="collection" : m.collection="favorites"
 openLibraryPage(80)
 if m.sent.path<>"/api/profiles/7/favorites/page?limit=40&offset=80" then throw "library page not bounded"
 if m.libraryOffset<>80 then throw "library lost current page"
 m.libraryItem={id:"opaque:ep",type:"series",name:"Show",series_id:"show",season:2,episode:3}
 libraryCorrect("unwatched")
 if m.sent.body.id<>"opaque:ep" or m.sent.body.series_id<>"show" or m.sent.body.action<>"unwatched" then throw "correction lost episode identity"
 m.position=123 : m.playItem={id:"opaque:ep",type:"series",series_id:"show",name:"Show",source_addon_id:"addon1",source_fingerprint:"fingerprint"}
 retrySelectedPlayback()
 if m.retryItem.position<>123 or m.retryItem.id<>"opaque:ep" then throw "retry lost position or episode"
 if m.preference.source_fingerprint<>"fingerprint" then throw "retry lost source preference"
 if m.manual=true then throw "retry opened picker instead of retrying selected source"
 m.position=0 : m.playItem.position=0
 retrySelectedPlayback()
 if m.preference=invalid then throw "startup failure lost retry identity at position zero"
 if m.preference.source_fingerprint<>"fingerprint" then throw "startup retry changed source"
 print "LIBRARY_RUNTIME_OK"
end sub
sub request(method as string,path as string,body as dynamic,tag as string)
 m.sent={method:method,path:path,body:body,tag:tag}
end sub
sub cancelBrowse()
end sub
sub rows(title as string,items as object,mode as string,status as string)
end sub




sub findStreams(item as object,manual as boolean,preference as dynamic)
 m.retryItem=item : m.manual=manual : m.preference=preference
end sub
sub resetAttempts()
end sub
sub beginPlayback(force as boolean)
end sub
'''
# Only invoke public event entry points; SG display dependencies are inert here.
def routine(name):
 if 'sub '+name+'(' not in source:return 'sub '+name+'()\nend sub'
 start=source.index('sub '+name+'(');return source[start:source.index('end sub',start)+7]
with tempfile.TemporaryDirectory() as temp:
 path=Path(temp)/'library.brs';path.write_text('\n'.join(routine(n) for n in ['openLibraryPage','libraryCorrect','retrySelectedPlayback'])+fixture)
 p=subprocess.run([os.environ.get('VIPTV_BRS_CLI','/home/node/air-roku/node_modules/.bin/brs-cli'),str(path),str(root/'source/Util.brs')],capture_output=True,text=True,timeout=40)
 print(p.stdout,p.stderr)
 if p.returncode or 'LIBRARY_RUNTIME_OK' not in p.stdout:raise SystemExit(1)
