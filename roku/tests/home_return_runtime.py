"""Actual Home handlers: a remote move must beat a pending restore callback."""
from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'components/MainScene.brs').read_text()
hold=(root/'components/HoldSelect.brs').read_text()
start=hold.index('function onKeyEvent(')
key_handler=hold[start:hold.index('end function',start)+12]
import xml.etree.ElementTree as ET
xml=ET.parse(root/'components/HoldRowList.xml').getroot()
assert xml.find("./interface/field[@id='navigation']").get('alwaysNotify')=='true'
assert 'observeField("navigation","homeNavigation")' in source
def routine(name):
 start=source.find('sub '+name+'(')
 if start<0:return 'sub '+name+'()\nend sub'
 return source[start:source.index('end sub',start)+7]
fixture='''
sub Main()
 m.top={hasField:HasNavigation}
 if onKeyEvent("right",true) then throw "direction swallowed instead of native navigation"
 if m.top.navigation<>"right" then throw "direction did not cancel restore before focus"
 m.mode="home" : m.homePosition=[0,0] : m.homeRowKeys=[0,1]
 m.homeData=[[{}, {}, {}],[{}]] : m.homeFocusTimer={control:"stop"}
 m.homeRows={rowItemFocused:[0,0],hasFocus:Focused} : m.homeAutoPick=false
 homeRestore()
 ' Right arrives before the queued timer/native restoration has settled.
 homeNavigation()
 m.homeRows.rowItemFocused=[0,1]
 homeFocused()
 m.homeRows.jumpToRowItem=[-1,-1]
 homeRestoreSettled()
 if m.homePosition[1]<>1 then throw "first Right discarded during Home restoration"
 if m.homeRows.jumpToRowItem[1]=0 then throw "late restore snapped back to previous movie"
 ' A later shelf refresh restores the NEW cursor, not the playback title.
 homeRestore()
 homeRestoreSettled()
 if m.homeRows.jumpToRowItem[1]<>1 then throw "refresh restored stale cursor"
 ' Native reset events still cannot overwrite an undisturbed restore.
 m.homePosition=[0,2]
 homeRestore()
 m.homeRows.rowItemFocused=[0,0]
 homeFocused()
 homeRestoreSettled()
 if m.homePosition[1]<>2 then throw "native reset overwrote saved cursor"
 print "HOME_RETURN_NAVIGATION_OK"
end sub
function HasNavigation(field as string) as boolean
 return field="navigation"
end function
function Focused() as boolean
 return true
end function
function homeValues(i as integer) as object
 return m.homeData[i]
end function
function uiHomeHeroRow() as integer
 return 0
end function
sub uiQueueCardArtwork()
end sub
sub uiHomeLayout()
end sub
sub homeHero()
end sub
'''
with tempfile.TemporaryDirectory(prefix='viptv-home-return-') as directory:
 path=Path(directory)/'test.brs'
 path.write_text(key_handler+'\n'+'\n'.join(routine(n) for n in ['homeRestore','homeRestoreSettled','homeNavigation','homeFocused'])+fixture)
 p=subprocess.run([os.environ.get('VIPTV_BRS_CLI','/home/node/air-roku/node_modules/.bin/brs-cli'),str(path)],capture_output=True,text=True,timeout=30)
 print(p.stdout);print(p.stderr)
 if p.returncode or 'HOME_RETURN_NAVIGATION_OK' not in p.stdout:raise SystemExit(1)
