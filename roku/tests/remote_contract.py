"""Guard the actual shipped entry point and server-only runtime boundary."""
from pathlib import Path
import json
import re
import xml.etree.ElementTree as ET

root=Path(__file__).resolve().parents[1]
config=json.loads((root/'bsconfig.json').read_text())
shipped=set()
for pattern in config['files']:
    shipped.update(p.relative_to(root).as_posix() for p in root.glob(pattern) if p.is_file())
assert 'source/main.brs' in shipped
assert 'CreateScene("RemoteScene")' in (root/'source/main.brs').read_text()
assert 'components/MainScene.xml' not in shipped, 'Legacy controller must not enter the runtime ZIP'
for name in shipped:
    if name.endswith('.xml'):
        for node in ET.parse(root/name).iter('script'):
            dependency=node.attrib.get('uri','').removeprefix('pkg:/')
            assert dependency in shipped, f'Unpackaged script dependency: {dependency}'
    if not name.endswith('.brs'): continue
    source=(root/name).read_text()
    assert '/api/v2/' not in source, f'Retired API in production: {name}'
    assert not re.search(r'BestContinuationSource|SourceLanguageScore|FairSources|SourceMatch\(',source), name
    if 'CreateObject("roUrlTransfer")' in source:
        assert name=='components/remote/RemoteTask.brs', 'HTTP effect escaped the Task thread'
    if 'CreateObject("roRegistrySection"' in source:
        assert name=='components/remote/RemoteStore.brs', 'Durable state escaped credential adapter'
assert not any(name.startswith('tests/') or 'preview' in name.lower() for name in shipped)
print('REMOTE_RUNTIME_BOUNDARY_OK')
