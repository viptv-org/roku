"""Actual startup handlers: Home never waits for metadata/artwork or reopens a cover."""
from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
def routine(file,start):
 s=(root/file).read_text();a=s.index(start);return s[a:s.index('end sub',a)+7]
production=(root/'components/StartupScene.brs').read_text()+'\n'+routine('components/HomeScene.brs','sub homeVisible(')+'\n'+routine('components/AccountScene.brs','sub accountEndLoading()')
fixture='''
sub Main()
 m.authLoading={visible:true} : m.authLoadingSpinner={} : m.startupText={}
 m.homeInitialLoading=true : m.homePanel={} : m.top={findNode:emptyNode}
 for each id in ["art","detailTitle","detailInfo","description"]
 m[id]={}
 end for
 ' Missing shelves, unresolved metadata and pending textures never block Home.
 m.homeRoot=invalid : m.homeHeroPanel={artState:"loading"}
 startupHomeBegin()
 homeVisible(true)
 if m.authLoading.visible or m.homeInitialLoading then throw "Home waited for artwork"
 if m.authLoadingSpinner.control<>"stop" then throw "Startup spinner kept running"
 ' A later refresh/cache miss must not show a cover either.
 m.homeRoot=invalid
 startupHomeBegin()
 if m.authLoading.visible then throw "Refresh reopened loading cover"
 startupArtworkResponse("startupArt:late",{ok:true})
 if m.authLoading.visible then throw "Late artwork reopened loading cover"
 print "STARTUP_READY_OK"
end sub
function emptyNode(id as string) as dynamic
 return invalid
end function
sub accountHideQr()
end sub
sub accountLayout(value as boolean)
end sub
sub uiHidePageExtras()
end sub
'''
with tempfile.TemporaryDirectory() as folder:
 p=Path(folder)/'startup.brs';p.write_text(production+'\n'+fixture)
 r=subprocess.run([os.environ.get('VIPTV_BRS_CLI','brs'),str(p),str(root/'source/Util.brs')],capture_output=True,text=True,timeout=30)
 print(r.stdout);print(r.stderr)
 if r.returncode or 'STARTUP_READY_OK' not in r.stdout:raise SystemExit(1)
