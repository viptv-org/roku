"""Production queue/observers/Timer with controlled asynchronous Task completion.

Task I/O is substituted; dispatcher and response handlers are unchanged. Real HTTPS
is covered separately by remote_transport_runtime.py.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile
from brs_cli import brs_command

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='roku-dispatch-') as directory:
    app = Path(directory) / 'app'
    for name in ('components', 'source', 'fonts', 'images'):
        shutil.copytree(root / name, app / name)
    shutil.copyfile(root / 'manifest', app / 'manifest')
    scene = app / 'components/remote/RemoteScene.brs'
    scene.write_text(scene.read_text().replace('rSend("CONFIG_LOAD","",invalid,"auth:config")', "' Test owns entry.") + '''
sub beginDispatchChecks()
    m.pollTick.control = "stop"
    m.config.base = "https://fixture.test"
    m.config.access_token = "fixture"
    m.dispatchElapsed = CreateObject("roTimespan")
    m.dispatchTimer = m.top.createChild("Timer")
    m.dispatchTimer.duration = 0.05
    m.dispatchTimer.repeat = true
    m.dispatchTimer.observeField("fire","checkDispatch")
    for i = 0 to 11
        method = "GET"
        if i mod 3 = 0 then method = "POST"
        rSend(method,"/api/fixture",invalid,"cleanup:test-"+i.toStr())
    end for
    ' Duplicate tags must never occupy a second slot.
    rSend("GET","/api/fixture",invalid,"cleanup:test-11")
    dispatchAssert(m.sequence = 12,"deduplicated request tag")
    dispatchAssert(m.workers.count() = 3,"three concurrent workers")
    m.dispatchTimer.control = "start"
end sub
sub checkDispatch()
    dispatchAssert(m.workers.count() <= 3,"worker bound")
    mutations = 0
    for each worker in m.workers
        if m.running.doesExist(worker.request.request_id) and worker.request.method <> "GET" then mutations++
    end for
    dispatchAssert(mutations <= 1,"mutations serialized across asynchronous tasks")
    if m.running.count() = 0 and m.queue.count() = 0
        dispatchAssert(m.pending.count() = 0,"all completion observers cleared ownership")
        m.dispatchTimer.control = "stop"
        m.networkTick.control = "stop"
        print "REMOTE_DISPATCH_OK"
        m.top.dispatchDone = true
    end if
    dispatchAssert(m.dispatchElapsed.totalMilliseconds() < 15000,"queue drains without manual dispatch")
end sub
sub dispatchAssert(ok as boolean, message as string)
    if not ok
        print "REMOTE_DISPATCH_FAILED: ";message
        stop
    end if
end sub
''')
    xml = app / 'components/remote/RemoteScene.xml'
    xml.write_text(xml.read_text().replace('<component name="RemoteScene" extends="Scene">', '<component name="RemoteScene" extends="Scene"><interface><field id="dispatchDone" type="boolean" /><function name="beginDispatchChecks" /></interface>'))
    (app / 'components/remote/RemoteTask.brs').write_text('''sub init()
    m.top.functionName = "runRemoteRequest"
end sub
sub runRemoteRequest()
    sleep(250)
    m.top.result = {ok:true,status:200,data:{}}
end sub
''')
    (app / 'source/main.brs').write_text('''sub Main()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSGScreen")
    screen.setMessagePort(port)
    scene = screen.createScene("RemoteScene")
    scene.observeField("dispatchDone",port)
    screen.show()
    scene.callFunc("beginDispatchChecks")
    deadline = CreateObject("roTimespan")
    while not scene.dispatchDone and deadline.totalMilliseconds() < 20000
        event = wait(100,port)
    end while
    if not scene.dispatchDone then print "REMOTE_DISPATCH_FAILED: no completion"
end sub
''')
    package = Path(directory) / 'fixture.zip'
    with zipfile.ZipFile(package, 'w') as archive:
        for path in sorted(app.rglob('*')):
            if path.is_file(): archive.write(path, path.relative_to(app))
    result = subprocess.run([*brs_command(), str(package)], capture_output=True, text=True, timeout=60)
    print(result.stdout, result.stderr)
    if result.returncode or 'REMOTE_DISPATCH_OK' not in result.stdout or 'REMOTE_DISPATCH_FAILED' in result.stdout:
        raise SystemExit('Production dispatcher check failed')
