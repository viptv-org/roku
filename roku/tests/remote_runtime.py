"""Execute production remote SceneGraph handlers; no real network or registry."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile
from brs_cli import brs_command

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='viptv-remote-runtime-') as directory:
    app = Path(directory) / 'app'
    for name in ('components', 'source', 'fonts', 'images'):
        shutil.copytree(root / name, app / name)
    shutil.copyfile(root / 'manifest', app / 'manifest')
    (app / 'tests/fixtures').mkdir(parents=True)
    shutil.copyfile(root / 'tests/fixtures/remote-v3.json', app / 'tests/fixtures/remote-v3.json')
    scene = app / 'components/remote/RemoteScene.brs'
    text = scene.read_text().replace('rSend("CONFIG_LOAD","",invalid,"auth:config")', "' Fixture: no real registry.")
    scene.write_text(text + '\n' + (root / 'tests/remote_runtime.brs').read_text())
    transport = app / 'components/remote/RemoteTransport.brs'
    transport.write_text(transport.read_text().replace('sub rDispatch()\n', 'sub rDispatch()\n    return\n'))
    xml = app / 'components/remote/RemoteScene.xml'
    xml.write_text(xml.read_text().replace('<component name="RemoteScene" extends="Scene">', '<component name="RemoteScene" extends="Scene"><interface><function name="runChecks" /></interface>'))
    (app / 'source/main.brs').write_text('''sub Main()
    screen = CreateObject("roSGScreen")
    scene = screen.createScene("RemoteScene")
    screen.show()
    scene.callFunc("runChecks")
end sub
''')
    package = Path(directory) / 'fixture.zip'
    with zipfile.ZipFile(package, 'w') as archive:
        for path in sorted(app.rglob('*')):
            if path.is_file():
                archive.write(path, path.relative_to(app))
    result = subprocess.run([*brs_command(), str(package)], capture_output=True, text=True, timeout=120)
    print(result.stdout, result.stderr)
    if result.returncode or 'REMOTE_ROKU_RUNTIME_OK' not in result.stdout or 'REMOTE_CHECK_FAILED' in result.stdout:
        raise SystemExit('Remote SceneGraph runtime failed')
