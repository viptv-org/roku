"""Run the real guide key handler with rendering isolated from navigation state."""
from pathlib import Path
import subprocess, tempfile, os
root = Path(__file__).resolve().parents[1]
source = (root/'components/EpgGrid.brs').read_text()
def extract(start, end):
    return source[source.index(start):source.index(end, source.index(start))+len(end)]
checks = '''sub Main()
    m.top = {visible:true,query:"",route:{filter:{id:"all"},search:""}}
    m.details = {visible:false}
    m.channels = [{id:"one"},{id:"two"}]
    m.filtersData = [{id:"search"},{id:"all"},{id:"kids"}]
    m.menu = 1 : m.row = 1 : m.offset = 0 : m.total = 2
    m.menuFocus = false
    now = CreateObject("roDateTime").asSeconds()
    boundary = (now \\ 1800)*1800
    m.window = boundary+7200 : m.anchor = m.window
    onKeyEvent("left",true)
    if m.menuFocus or m.window >= boundary+7200 then print "FAIL: Left escapes future window" else print "PASS: Left returns earlier"
    m.menuFocus = true
    before = m.window
    onKeyEvent("right",true)
    if m.channels.count() <> 2 or m.row <> 1 or m.window <> before then print "FAIL: unchanged category resets guide" else print "PASS: unchanged category preserves guide"
end sub
sub epgRender()
end sub
function epgProgrammes(id as string) as object
    return []
end function
sub epgWatchChannel()
end sub
sub epgDetails()
end sub
'''
with tempfile.TemporaryDirectory(prefix='viptv-guide-test-') as d:
    f = Path(d)/'test.brs'
    f.write_text(checks+'\n'+extract('function onKeyEvent(', 'end function')+'\n'+extract('sub epgRoute(', 'end sub'))
    r = subprocess.run([os.environ.get('VIPTV_BRS_CLI','/home/node/air-roku/node_modules/.bin/brs-cli'),str(f),str(root/'source/Util.brs'),str(root/'source/EpgPolicy.brs')],text=True,capture_output=True,timeout=30)
    print(r.stdout); print(r.stderr)
    raise SystemExit(0 if r.returncode == 0 and 'FAIL:' not in r.stdout and r.stdout.count('PASS:') == 2 else 1)
