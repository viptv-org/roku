"""Run the native rail input handler: bounded rows and release-only activation."""
from brs_cli import brs_command
from pathlib import Path
import os, subprocess, tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "components/DesignRail.brs").read_text()
handler = source[source.index("function onKeyEvent"):]
fixture = '''
sub Main()
 m.top={itemFocused:0,itemSelected:-1}
 m.icons=[0,1,2,3,4,5,6]
 onKeyEvent("up",true)
 if m.top.itemFocused<>0 then throw "rail wrapped above profile"
 for i=1 to 10
  onKeyEvent("down",true)
 end for
 if m.top.itemFocused<>6 then throw "rail escaped settings"
 onKeyEvent("OK",true)
 if m.top.itemSelected<>-1 then throw "rail activated on key down"
 onKeyEvent("OK",false)
 if m.top.itemSelected<>6 then throw "rail release lost selected destination"
 if onKeyEvent("right",true) or onKeyEvent("back",true) then throw "rail swallowed content restoration"
 onKeyEvent("up",true)
 if m.top.itemFocused<>5 then throw "rail did not move one destination"
 print "ROKU_DESIGN_RAIL_OK"
end sub
sub render()
end sub
'''
with tempfile.TemporaryDirectory() as temp:
    path=Path(temp)/"rail.brs"
    path.write_text(handler + fixture)
    result=subprocess.run([*brs_command(),str(path)],text=True,capture_output=True,timeout=30)
    print(result.stdout, result.stderr)
    assert result.returncode == 0 and "ROKU_DESIGN_RAIL_OK" in result.stdout
