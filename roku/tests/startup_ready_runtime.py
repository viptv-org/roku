"""Actual startup handlers: pending data/art, cold-only cover, failure and stale scope."""
from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
def routine(file,start):
 s=(root/file).read_text();a=s.index(start);return s[a:s.index('end sub',a)+7]
production=(root/'components/StartupScene.brs').read_text()+'\n'+routine('components/MainScene.brs','sub homeVisible(')+'\n'+routine('components/AccountScene.brs','sub accountEndLoading()')
fixture='''
sub Main()
 m.authLoading={visible:true} : m.authLoadingSpinner={} : m.startupText={}
 m.homeInitialLoading=true : m.startupScope="profile1" : m.homeKeyValue="profile1" : m.mode="home"
 m.startupClock={totalMilliseconds:clockTime} : m.startupReadyTimer={}
 m.homePanel={} : m.top={findNode:emptyNode}
 m.homeRoot=invalid : m.homeRowKeys=[] : m.homeDone={}
 m.homeHeroPanel={artState:"ready"} : m.startupStable=0
 m.startupArtStarted=false : m.startupArtPending={}
 GetGlobalAA().elapsed=100
 for each id in ["art","detailTitle","detailInfo","description"]
 m[id]={}
 end for
 homeVisible(true)
 if not m.authLoading.visible then throw "Home revealed before data and artwork"
 startupReadyTick()
 if not m.authLoading.visible then throw "Pending shelves revealed"
 for each kind in ["progress","movie","series","live","favorites","livefavorites","recent"]
 m.homeDone[kind]=true
 end for
 m.startupArtStarted=true : m.startupArtPending={outstanding:{}}
 startupReadyTick()
 if not m.authLoading.visible then throw "Pending metadata revealed"
 m.startupArtPending={}
 m.homeHeroPanel.artState="loading"
 startupReadyTick()
 if not m.authLoading.visible then throw "Pending hero revealed"
 m.homeHeroPanel.artState="ready"
 startupReadyTick()
 if not m.authLoading.visible then throw "No render settling turn"
 startupReadyTick()
 if m.authLoading.visible or m.homeInitialLoading then throw "Ready Home stayed covered"
 homeVisible(true)
 if m.authLoading.visible then throw "Cached return showed splash"
 m.homeInitialLoading=true : m.authLoading.visible=true : m.homeDone={}
 m.startupArtStarted=false : m.startupStable=0 : m.homeHeroPanel.artState="loading"
 GetGlobalAA().elapsed=12000
 startupReadyTick() : startupReadyTick()
 if m.homeDone.count()<>7 or m.authLoading.visible then throw "Unavailable services trapped startup"
 m.homeInitialLoading=true : m.authLoading.visible=true : m.homeKeyValue="profile2"
 startupReadyTick()
 if m.homeInitialLoading or not m.authLoading.visible then throw "Old profile revealed new profile"
 print "STARTUP_READY_OK"
end sub
function clockTime() as integer
 return GetGlobalAA().elapsed
end function
function emptyNode(id as string) as dynamic
 return invalid
end function
sub accountHideQr()
end sub
sub accountLayout(value as boolean)
end sub
sub uiHidePageExtras()
end sub
sub homeDefaultShelf()
end sub
sub homeRestore()
end sub
sub homeHero()
end sub
sub homeResponse(kind as string,result as object)
 m.homeDone[kind]=true
end sub
function acknowledgementMayFocus() as boolean
 return true
end function
sub uiHomeFocus()
end sub
sub uiQueueCardArtwork()
end sub
sub uiCardArtworkResponse(tag as string,result as object)
end sub
'''
with tempfile.TemporaryDirectory() as folder:
 p=Path(folder)/'startup.brs';p.write_text(production+'\n'+fixture)
 r=subprocess.run([os.environ.get('VIPTV_BRS_CLI','/home/node/air-roku/node_modules/.bin/brs-cli'),str(p),str(root/'source/Util.brs')],capture_output=True,text=True,timeout=30)
 print(r.stdout);print(r.stderr)
 if r.returncode or 'STARTUP_READY_OK' not in r.stdout:raise SystemExit(1)
