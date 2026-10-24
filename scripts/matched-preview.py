"""Render production Roku with private JSON exported by the KMP reference test.

No account, registry, or backend is contacted. The output is a disposable visual
fixture and is never accepted by the runtime packager.
"""
import argparse
import json
from pathlib import Path
import shutil
from urllib.parse import urlparse, unquote

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('exports',type=Path)
parser.add_argument('output',type=Path)
parser.add_argument('state',choices=['home','movie','series'])
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
app=args.output.resolve();app.mkdir(parents=True,exist_ok=False)
for folder in ('components','source','fonts','images'):
    shutil.copytree(root/'roku'/folder,app/folder)
shutil.copyfile(root/'roku/manifest',app/'manifest')
(app/'data').mkdir();(app/'images/matched').mkdir()
allowed=(root.parent/'app/composeApp/build/processedResources').resolve()
def rewrite(value):
    if isinstance(value,dict):
        result={k:rewrite(v) for k,v in value.items()}
        if 'identity' in result and 'title' in result:
            result['view']={'saved':False}
        return result
    if isinstance(value,list):return [rewrite(v) for v in value]
    if isinstance(value,str) and value.startswith('file:'):
        path=Path(unquote(urlparse(value).path)).resolve();path.relative_to(allowed)
        assert path.suffix.lower() in {'.png','.jpg','.jpeg','.webp'},path
        shutil.copyfile(path,app/'images/matched'/path.name)
        return 'pkg:/images/matched/'+path.name
    return value
payload=rewrite(json.loads((args.exports/(args.state+'.json')).read_text()))
if args.state=='home':
    payload['scope']['profile_id']='7'
    for index,row in enumerate(payload['rows']):
        # Explicit fixture layout facts, matching the two exported KMP shelves.
        row['view']={'card_shape':['landscape','poster'][index]}
else:
    # Explicit shared projection fixture; do not run KMP metadata heuristics in Roku.
    if args.state == 'movie':
        payload['item']['view'].update(metadata_parts=['Movie','2026','Action, Adventure','1h 40m'],hero_metadata_parts=['2026','Action, Adventure','1h 40m'],hero_badges=[{'label':label,'role':role} for label,role in [('4K','capability'),('HDR','capability'),('5.1','capability'),('PG-13','certification')]])
    payload['recommendations']=rewrite(json.loads((args.exports/'recommendations.json').read_text()))
(app/'data/reference.json').write_text(json.dumps(payload))
scene=app/'components/remote/RemoteScene.brs'
s=scene.read_text().replace('rSend("CONFIG_LOAD","",invalid,"auth:config")',"' Fixture owns startup.")
s+='''
sub matchedPreview()
    m.networkTick.control = "stop"
    m.pollTick.control = "stop"
    m.config = {base:"https://example.test",access_token:"",locked:true,capabilities:{max_width:1920,max_height:1080,h264:true,aac:true}}
    m.profile = "7"
    m.navigation.profileName = "vynxc"
    m.navigation.avatarUri = "pkg:/images/design/remote-avatar-vynxc.png"
    data = ParseJson(ReadAsciiFile("pkg:/data/reference.json"))
'''
if args.state=='home':s+='    rReset("home")\n    rHome(data)\n'
else:
    s+='    rDetail(data.item,false)\n    rPageResponse("detail",data,{context:{append:false}})\n'
    if args.state=='series':s+='    rDetailActions(data.item,{label:"Resume S1 E2",resume:true})\n'
s+='end sub\n';scene.write_text(s)
p=app/'components/remote/RemoteTransport.brs';p.write_text(p.read_text().replace('sub rDispatch()\n','sub rDispatch()\n    return\n'))
p=app/'components/remote/RemoteScene.xml';p.write_text(p.read_text().replace('<component name="RemoteScene" extends="Scene">','<component name="RemoteScene" extends="Scene"><interface><function name="matchedPreview" /></interface>'))
(app/'source/main.brs').write_text('''sub Main()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSGScreen")
    screen.setMessagePort(port)
    scene = screen.createScene("RemoteScene")
    screen.show()
    scene.callFunc("matchedPreview")
    while true
        event = wait(100,port)
        if type(event) = "roSGScreenEvent" then return
    end while
end sub
''')
print(app)
