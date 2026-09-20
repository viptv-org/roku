"""Run the actual movie action builder for fresh and resumable titles."""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'components/ResponseScene.brs').read_text()
start = source.index('sub showMetadata(')
routine = source[start:source.index('end sub', start) + 7]
fixture = '''
sub Main()
 m.selected=invalid
 showMetadata({meta:{id:"fresh",type:"movie",name:"Fresh"}})
 if m.actions.count()<>3 then throw "fresh movie has duplicate source controls"
 if m.actions[0].name<>"Choose source" or m.actions[0].action<>"play" then throw "fresh primary behavior changed"
 if m.actions[1].action<>"favorite" then throw "fresh movie actions out of order"
 m.selected=invalid
 showMetadata({meta:{id:"resume",type:"movie",name:"Resume",position:60}})
 if m.actions.count()<>4 then throw "resume lost explicit source choice"
 if m.actions[0].action<>"resume" or m.actions[0].name<>"Resume at 1:00" then throw "resume primary changed"
 if m.actions[1].action<>"sources" or m.actions[1].name<>"Choose source" then throw "resume source override changed"
 print "MOVIE_DETAIL_ACTIONS_OK"
end sub
function Txt(value as dynamic, fallback="" as string) as string
 if value=invalid then return fallback
 return value
end function
function Bounded(value as dynamic, limit as integer) as object
 return []
end function
function PlayerTime(position as dynamic) as string
 return "1:00"
end function
function favoriteLabel(meta as object) as string
 return "Add to list"
end function
sub rows(title as string, actions as object, mode as string, status as string)
 m.actions=actions
end sub
sub showDetail(meta as object)
end sub
'''
with tempfile.TemporaryDirectory(prefix='viptv-movie-actions-') as directory:
    path = Path(directory) / 'actions.brs'
    path.write_text(routine + fixture)
    result = subprocess.run([os.environ.get('VIPTV_BRS_CLI', '/home/node/air-roku/node_modules/.bin/brs-cli'), str(path)], capture_output=True, text=True, timeout=30)
    print(result.stdout)
    print(result.stderr)
    if result.returncode or 'MOVIE_DETAIL_ACTIONS_OK' not in result.stdout:
        raise SystemExit(1)
