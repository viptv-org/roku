"""Production Task HTTP against a disposable HTTPS fixture, no account data."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import os
import shutil
import ssl
import subprocess
import tempfile
import threading
from brs_cli import brs_command

root=Path(__file__).resolve().parents[1]
class Handler(BaseHTTPRequestHandler):
    def log_message(self,*args): pass
    def request(self):
        status=200
        body=None
        if self.command!='GET':
            raw=self.rfile.read(int(self.headers.get('Content-Length','0')))
            body=json.loads(raw) if raw else None
        if self.path=='/api/bootstrap': value={'contract_version':3,'identity':{},'profile_management':{}}
        elif self.path=='/api/empty': status=204; value=None
        elif self.path=='/api/denied': status=403; value={'error':'private-fixture-must-not-leak'}
        elif self.path=='/api/old': value=None
        elif self.path=='/api/large': value={'large':'x'*2_100_000}
        else: value={'method':self.command,'body':body,'authenticated':self.headers.get('Authorization')=='Bearer fixture-access'}
        raw=b'' if status==204 else json.dumps(value).encode()
        self.send_response(status);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(raw)));self.end_headers()
        try:self.wfile.write(raw)
        except (BrokenPipeError,ssl.SSLError):pass
    do_GET=request;do_POST=request;do_PUT=request;do_DELETE=request
with tempfile.TemporaryDirectory(prefix='roku-remote-tls-') as directory:
    tmp=Path(directory)
    cert=tmp/'ca.pem';key=tmp/'key.pem'
    subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(key),'-out',str(cert),'-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost,IP:127.0.0.1'],check=True,capture_output=True)
    server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
    context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(cert,key)
    server.socket=context.wrap_socket(server.socket,server_side=True)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    script=tmp/'checks.brs';script.write_text((root/'tests/remote_transport.brs').read_text().replace('FIXTURE_ORIGIN',f'https://localhost:{server.server_port}'))
    task=tmp/'RemoteTask.brs'
    # Only the fixture's trusted CA location differs; verification stays enabled.
    task.write_text((root/'components/remote/RemoteTask.brs').read_text().replace('common:/certs/ca-bundle.crt','pkg:/ca.pem'))
    shutil.copyfile(root/'source/RemoteWire.brs',tmp/'RemoteWire.brs')
    shutil.copyfile(root/'components/remote/RemoteStore.brs',tmp/'RemoteStore.brs')
    env=dict(os.environ,NODE_EXTRA_CA_CERTS=str(cert))
    try:
        result=subprocess.run([*brs_command(),'--root',str(tmp),'RemoteWire.brs','RemoteStore.brs','RemoteTask.brs','checks.brs'],cwd=tmp,env=env,capture_output=True,text=True,timeout=120)
    finally:server.shutdown();server.server_close()
    print(result.stdout,result.stderr)
    if result.returncode or 'REMOTE_TRANSPORT_OK' not in result.stdout or 'REMOTE_TRANSPORT_FAILED' in result.stdout:
        raise SystemExit('Remote HTTPS transport failed')
