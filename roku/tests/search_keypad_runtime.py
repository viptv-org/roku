"""Actual six-column keypad input, bounds, deletion and mobile literal entry."""
from pathlib import Path
import os,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'components/SearchKeypad.brs').read_text();s=s[s.index('function onKeyEvent'):]
fixture='''
sub Main()
 m.index=0:m.top={text:"",active:true,textEditBox:{cursorPosition:0,maxTextLength:3}}:m.keys=[]
 alphabet="abcdefghijklmnopqrstuvwxyz1234567890"
 for i=1 to 36
  m.keys.push({label:{text:mid(alphabet,i,1)}})
 end for
 if onKeyEvent("left",true) then throw "first key hides rail exit"
 onKeyEvent("OK",true)
 if m.top.text<>"a" then throw "key activation lost literal"
 onKeyEvent("Lit_b",true):onKeyEvent("Lit_c",true):onKeyEvent("Lit_d",true)
 if m.top.text<>"abc" then throw "mobile input bypassed max length"
 m.index=37:onKeyEvent("OK",true)
 if m.top.text<>"ab" then throw "backspace key failed"
 m.index=38:onKeyEvent("OK",true)
 if m.top.text<>"" then throw "clear key failed"
 m.index=5
 if onKeyEvent("right",true) then throw "last column cannot reach results"
 m.index=35:onKeyEvent("down",true)
 if m.index<>38 then throw "bottom utility row missing"
 onKeyEvent("up",true)
 if m.index<>34 then throw "utility return column lost"
 print "SEARCH_KEYPAD_RUNTIME_OK"
end sub
sub paint()
end sub
'''
with tempfile.TemporaryDirectory() as folder:
 p=Path(folder)/'keys.brs';p.write_text(s+fixture)
 r=subprocess.run([os.environ['VIPTV_BRS_CLI'],str(p),str(root/'source/KeyboardInput.brs')],capture_output=True,text=True,timeout=30)
 print(r.stdout,r.stderr)
 assert r.returncode==0 and 'SEARCH_KEYPAD_RUNTIME_OK' in r.stdout
