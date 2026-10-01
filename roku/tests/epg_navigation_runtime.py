"""Run the real EpgGrid component in a disposable SceneGraph app (no network, no media).

epg_preview.brs hosts the grid with fictional channels; epg_navigation.brs is injected
into EpgGrid.brs and exposed as runChecks. Never packaged or distributed.
"""
from brs_cli import brs_command
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

root = Path(__file__).resolve().parents[1]
tests = root / 'tests'
SCENE = '''<?xml version="1.0" encoding="utf-8"?>
<component name="EpgPreviewScene" extends="Scene">
 <script type="text/brightscript" uri="pkg:/components/EpgPreviewScene.brs" />
 <children><EpgGrid id="grid" /></children>
</component>
'''
MAIN = '''sub Main()
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    scene = screen.CreateScene("EpgPreviewScene")
    screen.show()
    scene.findNode("grid").callFunc("runChecks")
end sub
'''

with tempfile.TemporaryDirectory(prefix='viptv-epg-navigation-') as folder:
    app = Path(folder) / 'app'
    for name in ('components', 'source', 'fonts'):
        shutil.copytree(root / name, app / name)
    shutil.copyfile(root / 'manifest', app / 'manifest')
    grid = app / 'components' / 'EpgGrid.brs'
    grid.write_text(grid.read_text() + '\n' + (tests / 'epg_navigation.brs').read_text())
    xml = app / 'components' / 'EpgGrid.xml'
    marker = '  <function name="resume" />\n'
    text = xml.read_text()
    assert marker in text, 'EpgGrid interface changed; update the preview injection'
    xml.write_text(text.replace(marker, marker + '  <function name="runChecks" />\n'))
    (app / 'components' / 'EpgPreviewScene.brs').write_text((tests / 'epg_preview.brs').read_text())
    (app / 'components' / 'EpgPreviewScene.xml').write_text(SCENE)
    (app / 'source' / 'main.brs').write_text(MAIN)
    package = Path(folder) / 'epg-preview.zip'
    with zipfile.ZipFile(package, 'w') as archive:
        for path in sorted(app.rglob('*')):
            if path.is_file():
                archive.write(path, path.relative_to(app).as_posix())
    result = subprocess.run([*brs_command(), str(package)], capture_output=True, text=True, timeout=120)
    print(result.stdout, result.stderr)
    if result.returncode or 'EPG_NAVIGATION_OK' not in result.stdout:
        raise SystemExit('EPG navigation runtime failed')
