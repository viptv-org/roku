"""Explicit Resume cancellation uses the populated manual picker, without rediscovery."""
from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'components/MainScene.brs').read_text();a=s.index('sub cancelAutomaticResume()');production=s[a:s.index('end sub',a)+7]
fixture='''
sub Main()
 m.streams=[{id:"saved"}]:m.sourceList={setFocus:Focus}:m.status={}
 m.pendingPlayback=true:m.mode="resuming":m.resumeSourcePreference={}
 cancelAutomaticResume()
 if m.mode<>"streams" or m.manualSources<>true or m.pendingPlayback<>false then throw "cancel did not restore manual source choice"
 if m.resumeSourcePreference<>invalid or m.cancelled<>true then throw "cancel retained pending resume work"
 print "RESUME_CONTROLS_OK"
end sub
sub cancelBrowse()
 m.cancelled=true
end sub
sub rows(title,items,mode,subtitle="")
 m.mode=mode
end sub
sub uiSourceHeader()
end sub
sub uiBusy(active)
end sub
sub findStreams(item,manual=true)
 throw "cancel rediscovered already populated sources"
end sub
sub Focus(active)
end sub
'''
with tempfile.TemporaryDirectory() as folder:
 p=Path(folder)/'cancel.brs';p.write_text(production+fixture)
 r=subprocess.run([os.environ.get('VIPTV_BRS_CLI','/home/node/air-roku/node_modules/.bin/brs-cli'),str(p)],capture_output=True,text=True,timeout=30)
 print(r.stdout,r.stderr)
 if r.returncode or 'RESUME_CONTROLS_OK' not in r.stdout:raise SystemExit(1)
