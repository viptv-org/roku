"""Loopback-only contract fixture for transport.brs; no media/provider credentials."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def run_request(self):
        if self.headers.get('Authorization') != 'Bearer fixture-token':
            self.send_json(401, {'error': 'secret must not be echoed'})
            return
        size = int(self.headers.get('Content-Length', '0'))
        body = self.rfile.read(size) if size else b''
        if self.command in ('PUT', 'POST') and body:
            try:
                json.loads(body)
            except ValueError:
                print('INVALID_FIXTURE_BODY', repr(body[:120]), flush=True)
                self.send_json(400, {'error': 'invalid request body'})
                return
        if self.path == '/api/profiles?bad=1':
            self.send_json(200, None)
        elif self.path == '/api/profiles?large=1':
            self.send_json(200, [{'id': 1, 'name': 'x' * 2100000}])
        elif self.path == '/api/profiles?forbidden=1':
            self.send_json(403, {'error': 'https://provider.example/user/password'})
        elif self.path == '/api/profiles' and self.command == 'GET':
            self.send_json(200, [{'id': 1, 'name': 'Fixture viewer'}, None, 42])
        elif self.path == '/api/profiles' and self.command == 'POST':
            self.send_json(200, {'id': 2, 'name': json.loads(body)['name']})
        elif self.path == '/api/profiles/1/favorites' and self.command == 'PUT':
            self.send_json(200, {'ok': True})
        elif self.path == '/api/profiles/1/favorites/movie/tt1' and self.command == 'DELETE':
            self.send_response(204)
            self.send_header('Content-Length', '0')
            self.end_headers()
        elif self.path == '/api/discover?type=movie&skip=0&search=shared%20query':
            self.send_json(200, {'metas': [{'id': 'shared', 'type': 'movie', 'name': 'Shared Movie'}]})
        elif self.path == '/api/discover?type=series&skip=0&search=shared%20query':
            self.send_json(200, {'metas': [{'id': 'shared', 'type': 'series', 'name': 'Shared Series'}]})
        elif self.path == '/api/live?offset=0&limit=30&search=shared%20query':
            self.send_json(200, {'channels': [{'id': 'shared', 'name': 'Shared Live'}], 'total': 1})
        elif self.path == '/api/streams/job?after=0':
            self.send_json(200, {'events': [{'seq': 1, 'source': 'fixture', 'streams': [{'id': 's1', 'name': 'Playable'}]}], 'done': False})
        elif self.path == '/api/streams/job?after=1':
            self.send_json(200, {'events': [{'seq': 2, 'source': 'fixture', 'streams': [], 'error': 'secret URL'}], 'done': True})
        else:
            self.send_json(404, {'error': 'missing fixture'})

    def send_json(self, status, value):
        data = json.dumps(value).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        try:
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            pass

    do_GET = do_POST = do_PUT = do_DELETE = run_request

if __name__ == '__main__':
    print('ROKU_FIXTURE_READY 127.0.0.1:18764', flush=True)
    ThreadingHTTPServer(('127.0.0.1', 18764), Handler).serve_forever()
