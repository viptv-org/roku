"""Guard the actual shipped entry point and server-only runtime boundary."""
from pathlib import Path
import json
import hashlib
import re
import xml.etree.ElementTree as ET

root=Path(__file__).resolve().parents[1]
config=json.loads((root/'bsconfig.json').read_text())
shipped=set()
for pattern in config['files']:
    shipped.update(p.relative_to(root).as_posix() for p in root.glob(pattern) if p.is_file())
assert 'source/main.brs' in shipped
assert 'CreateScene("RemoteScene")' in (root/'source/main.brs').read_text()
assert {p.name for p in (root/'source').glob('*.brs')} == {'main.brs', 'RemoteWire.brs'}, 'Retired source must be removed, not excluded'
assert not any(p.is_file() for p in (root/'components').glob('*')), 'Only the current SceneGraph components are supported'
assert not (root/'tools').exists() or not any((root/'tools').glob('*')), 'Retired asset generators must be removed'
for source in [root/'manifest', *(root/'components/remote').glob('*')]:
    for path in re.findall(r'pkg:/((?:images|fonts)/[\w./-]+\.(?:png|jpg|ttf))', source.read_text()):
        assert path in shipped, f'Missing runtime resource: {path}'
store = (root/'components/remote/RemoteStore.brs').read_text()
assert 'auth_version = 2' not in store and 'registry.read("server")' not in store

for name in shipped:
    if name.endswith('.xml'):
        for node in ET.parse(root/name).iter('script'):
            dependency=node.attrib.get('uri','').removeprefix('pkg:/')
            assert dependency in shipped, f'Unpackaged script dependency: {dependency}'
    if not name.endswith('.brs'): continue
    source=(root/name).read_text()
    assert '/api/v2/' not in source, f'Retired API in production: {name}'
    assert not re.search(r'/api/parent/(?:search|pin)|/approvals|"/kids"|kidsAge|kidsToggle',source), f'Account-only parental editor shipped to device session: {name}'
    assert not re.search(r'BestContinuationSource|SourceLanguageScore|FairSources|SourceMatch\(',source), name
    if re.search(r'\b(?:ParseJson|FormatJson)\s*\(', source, re.I):
        assert name in {'components/remote/RemoteTask.brs', 'components/remote/RemoteStore.brs'}, f'JSON processing escaped Task nodes: {name}'
    if 'CreateObject("roUrlTransfer")' in source:
        assert name=='components/remote/RemoteTask.brs', 'HTTP effect escaped the Task thread'
    if 'CreateObject("roRegistrySection"' in source:
        assert name=='components/remote/RemoteStore.brs', 'Durable state escaped credential adapter'
assert not any(name.startswith('tests/') or ('preview' in name.lower() and name.endswith(('.brs','.xml','.json'))) for name in shipped)
pinned=json.loads((root.parent/'DESIGN_ASSETS.json').read_text())['files']
assert all('roku/'+name in pinned for name in shipped if name.startswith('images/')), 'Only pinned production artwork may ship'
print('REMOTE_RUNTIME_BOUNDARY_OK')

for node in ET.parse(root/"components/remote/RemoteScene.xml").iter("MarkupList"):
    if node.attrib.get("id") == "drawerRows":
        # The drawer's source/episode list is a vertical carousel: the focused
        # row stays in the first slot and the list scrolls under it.
        assert node.attrib.get("vertFocusAnimationStyle") == "fixedFocus"
    else:
        assert node.attrib.get("vertFocusAnimationStyle") == "floatingFocus", "Native default wraps and reorders short lists"

producer_ref=json.loads((root.parent/'docs/PRODUCER_FIXTURE_REF.json').read_text())
assert hashlib.sha256((root/'tests/fixtures/producer-viewing-v3.json').read_bytes()).hexdigest()==producer_ref['sha256'], 'Producer fixture drift requires explicit adoption'

# History status is a producer projection, never a local timestamp/percentage rule.
history = (root/'components/remote/RemoteHistory.brs').read_text()
assert 'completed_at_millis' not in history and '% watched' not in history
assert 'historyProgress' not in (root/'components/remote/RemoteItem.xml').read_text()

# Current Live/channel Search requests must use bounded producer descriptors.
for name in ['RemoteLive.brs','RemoteSearch.brs','RemoteTransport.brs','RemoteScene.brs']:
    text = (root/'components/remote'/name).read_text()
    assert not re.search(r'liveCursors|liveFirst|liveNext|searchChannelCursors|searchChannelFirst', text), name
for name in ['RemoteLive.brs','RemoteSearch.brs']:
    assert 'next_cursor' not in (root/'components/remote'/name).read_text(), 'No legacy Live cursor fallback'
