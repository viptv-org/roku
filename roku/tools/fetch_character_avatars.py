#!/usr/bin/env python3
"""Fetch the curated, pinned character thumbnails; never search by ambiguous names."""
import concurrent.futures
import json
from pathlib import Path
import urllib.request
ROOT = Path(__file__).resolve().parents[2]
catalog = json.loads((ROOT / 'roku/data/character-avatars.json').read_text())
def fetch(item):
    with urllib.request.urlopen(item['url'], timeout=20) as response:
        data = response.read(1024 * 1024)
    if not data.startswith(b'\x89PNG') or len(data) >= 1024 * 1024:
        raise ValueError('Expected a bounded PNG for ' + item['name'])
    path = ROOT / 'roku' / item['local'].removeprefix('pkg:/')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
    list(pool.map(fetch, [item for items in catalog.values() for item in items]))
server = {style: [{key: item[key] for key in ('name','url','source')} for item in items] for style,items in catalog.items()}
(ROOT / 'server/assets/character-avatars.json').write_text(json.dumps(server, indent=2) + '\n')
print('Character thumbnails and server URL catalog synchronized.')
