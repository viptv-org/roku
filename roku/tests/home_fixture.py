#!/usr/bin/env python3
"""Loopback-only, fictional UI fixtures. Never contacts a real VIPTV server/provider.
Run with --scenario populated|empty|partial|slow; /fixture/report exposes request
counts so focus-only navigation can be checked for accidental metadata requests.
Artwork is original generated test artwork, excluded from the production ZIP.
"""
import argparse
import copy
import json
import threading
import time
from collections import Counter
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlsplit

TOKEN = 'viptv-ui-fixture-only'
TITLES = [
    ('signal', 'The Last Signal', 'movie', '2025', 'A quiet transmission from a vanished station sends a pilot beyond the edge of the known world.'),
    ('northline', 'Northline', 'series', '2024', 'A remote mountain town. One unanswered question. A detective follows a trail through the winter silence.'),
    ('afterhours', 'After Hours', 'series', '2025', 'Three lives cross in a city that never quite sleeps. Every night is a chance to start again.'),
    ('wildcoast', 'Wild Coast', 'series', '2024', 'Explore remarkable coastlines, secret coves and the wildlife that calls the edge of the ocean home.'),
    ('sunward', 'Sunward', 'movie', '2025', 'An unexpected road trip brings two old friends back together beneath a wide-open desert sky.'),
    ('deepcurrent', 'Deep Current', 'movie', '2025', 'Below the surface, a diver discovers that the ocean still has stories left to tell.'),
]


def run(port=18770, scenario='populated'):
    base = f'http://127.0.0.1:{port}'
    records = [dict(id='fixture.'+key, name=name, type=kind, releaseInfo=year,
                    description=description, poster=f'{base}/posters/{key}.jpg')
               for key, name, kind, year, description in TITLES]
    progress = []
    for index, item in enumerate(records):
        value = dict(item, position=(index+1)*450, duration=7200 if item['type']=='movie' else 3000)
        if value['type']=='series':
            value.update(id=value['id']+':1:2', season=1, episode=2)
        progress.append(value)
    favorites = {'1': copy.deepcopy(records), '2': []}
    history = {'1': progress, '2': []}
    state = {'scenario': scenario, 'counts': Counter(), 'last_stream_request': None}
    lock = threading.Lock()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def send(self, data, status=200, content_type='application/json'):
            body = data if isinstance(data, bytes) else json.dumps(data).encode()
            self.send_response(status)
            self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass

        def do_GET(self):
            split = urlsplit(self.path)
            route = unquote(split.path)
            query = parse_qs(split.query)
            if route=='/fixture/report':
                with lock:
                    self.send(dict(scenario=state['scenario'], counts=dict(state['counts']), last_stream_request=state['last_stream_request']))
                return
            if route=='/fixture/scenario':
                value = query.get('name', ['populated'])[0]
                if value not in ('populated', 'empty', 'partial', 'slow'):
                    self.send({}, 400); return
                state['scenario'] = value
                self.send({'scenario': value}); return
            if route.startswith('/posters/'):
                name = route.removeprefix('/posters/')
                if name not in [key+'.jpg' for key, *_ in TITLES]:
                    self.send({}, 404); return
                self.send((Path(__file__).parent/'fixtures'/name).read_bytes(), content_type='image/jpeg'); return
            if self.headers.get('Authorization')!='Bearer '+TOKEN:
                self.send({'error': 'Fixture authentication required'}, 401); return
            with lock:
                state['counts']['GET '+route] += 1
            mode = state['scenario']
            if mode=='slow' and route.endswith('/progress'):
                time.sleep(3)
            if mode=='partial' and route.endswith('/favorites'):
                self.send({'error': 'Fixture shelf unavailable'}, 503); return
            if route=='/api/auth/me':
                self.send({'account_id': 'fixture-account', 'can_create_profile': True, 'profiles': [{'id': '1', 'name': 'Alex', 'setup_complete': True}, {'id': '2', 'name': 'Guest', 'setup_complete': True}]})
            elif route=='/api/profiles':
                self.send([{'id': '1', 'name': 'Alex', 'setup_complete': True}, {'id': '2', 'name': 'Guest', 'setup_complete': True}])
            elif route=='/api/catalogs':
                self.send([] if mode=='empty' else [
                    {'addon_id': '7', 'id': 'fixture-movies', 'type': 'movie', 'name': 'Movie picks'},
                    {'addon_id': '7', 'id': 'fixture-series', 'type': 'series', 'name': 'Series picks'}])
            elif route=='/api/discover':
                kind = query.get('type', ['movie'])[0]
                term = query.get('search', [''])[0].lower()
                self.send({'metas': [] if mode=='empty' else [r for r in records if r['type']==kind and term in r['name'].lower()]})
            elif route.startswith('/api/profiles/') and route.endswith(('/progress', '/favorites')):
                who = route.split('/')[3]
                collection = history if route.endswith('/progress') else favorites
                self.send([] if mode=='empty' else collection.get(who, []))
            elif route.startswith('/api/meta/'):
                ident = route.split('/', 4)[4]
                item = next((r for r in records if r['id']==ident), None)
                if not item:
                    self.send({'error': 'Fixture title not found'}, 404); return
                meta = dict(item)
                if meta['type']=='series':
                    meta['videos'] = [dict(id=ident+f':1:{episode}', title=f'Chapter {episode}', season=1, episode=episode) for episode in range(1, 7)]
                self.send({'meta': meta})
            elif route=='/api/live':
                channels = [dict(id='iptv:fixture:1', name='Wild Coast Live', type='live', category='Nature', logo=f'{base}/posters/wildcoast.jpg')]
                term = query.get('search', [''])[0].lower()
                channels = [c for c in channels if term in c['name'].lower()]
                self.send({'channels': channels, 'total': len(channels)})
            elif route.startswith('/api/guide/'):
                now = int(time.time())
                self.send({'programs': [dict(id='program1', title='Along the Wild Coast', description='A fictional guide entry for UI testing.', start=now-600, end=now+3000)]})
            elif route.startswith('/api/streams/'):
                self.send({'events': [{'seq': 1, 'source': 'fixture', 'streams': [{'id': 'fixture-stream', 'name': 'Preview source', 'title': 'UI fixture — no real media', 'source': 'fixture'}]}], 'done': True})
            else:
                self.send({'error': 'Unknown fixture route'}, 404)

        def mutation(self):
            route = unquote(urlsplit(self.path).path)
            length = int(self.headers.get('Content-Length', 0))
            body = json.loads(self.rfile.read(length)) if length else {}
            with lock:
                state['counts'][self.command+' '+route] += 1
            if route=='/api/device/refresh' and self.command=='POST':
                if body.get('refresh_token') != 'fixture-refresh':
                    self.send({'error': 'invalid fixture refresh'}, 401); return
                self.send({'access_token': TOKEN, 'refresh_token': 'fixture-refresh', 'expires_in': 3600}); return
            if self.headers.get('Authorization')!='Bearer '+TOKEN:
                self.send({}, 401); return
            if route=='/api/streams':
                state['last_stream_request'] = body
                self.send({'id': 'fixture-job'})
            elif route=='/api/playback':
                self.send({'error': 'Playback intentionally disabled in UI fixtures'}, 503)
            elif route.startswith('/api/profiles/'):
                parts = route.split('/')
                who = parts[3]
                target = favorites if len(parts)>4 and parts[4]=='favorites' else history
                if self.command=='PUT':
                    target[who] = [v for v in target.get(who, []) if v['id']!=body.get('id')]+[body]
                elif self.command=='DELETE' and len(parts)>6:
                    target[who] = [v for v in target.get(who, []) if v['id']!=parts[6]]
                self.send({'ok': True})
            else:
                self.send({}, 404)

        do_POST = mutation
        do_PUT = mutation
        do_DELETE = mutation

    server = ThreadingHTTPServer(('127.0.0.1', port), Handler)
    server.daemon_threads = True
    print(f'Fictional Roku UI fixture listening on 127.0.0.1:{port}; scenario={scenario}', flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()


if __name__=='__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=18770)
    parser.add_argument('--scenario', choices=['populated', 'empty', 'partial', 'slow'], default='populated')
    options = parser.parse_args()
    run(options.port, options.scenario)
