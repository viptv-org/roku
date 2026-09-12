#!/usr/bin/env python3
"""Create a NEW networkless UI-only fixture from production Roku sources.
Never package/distribute this directory. No registry or private config copied.
"""
import shutil
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = Path(sys.argv[1]).resolve()
if out.exists():
    raise SystemExit('Output must be new')
out.mkdir(parents=True)
for folder in ('components', 'source', 'images', 'data'):
    shutil.copytree(root / folder, out / folder)
shutil.copyfile(root / 'manifest', out / 'manifest')
for image in (root / 'tests' / 'fixtures').iterdir():
    if image.suffix in ('.jpg', '.png'):
        shutil.copyfile(image, out / 'images' / image.name)
main = out / 'components' / 'MainScene.brs'
text = main.read_text()
text = text.replace('m.dispatch.control = "start"', 'm.dispatch.control = "stop"')
text = text.replace('    request("CONFIG_LOAD", "", invalid, "config")', '    \' Network and config intentionally disabled in this UI fixture.')
# Hard-disable network dispatch even if a timer is accidentally started.
text = text.replace('sub dispatchRequests()\n', 'sub dispatchRequests()\n    return\n')
main.write_text(text + '\n' + (root / 'tests' / 'ux_preview.brs').read_text())
xml = out / 'components' / 'MainScene.xml'
text = xml.read_text().replace('<component name="MainScene" extends="Scene">', '<component name="MainScene" extends="Scene">\n <interface><field id="fixture" type="string" onChange="uxFixtureChanged"/></interface>')
xml.write_text(text)
(out / 'source' / 'main.brs').write_text('''sub Main(args as object)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    scene = screen.createScene("MainScene")
    scene.fixture = args.case
    screen.show()
    while true
        event = wait(0,port)
        if type(event) = "roSGScreenEvent" and event.isScreenClosed() then return
    end while
end sub
''')
print(out)
