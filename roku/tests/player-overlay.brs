sub Main()
    m.row = 0
    m.button = 1
    m.preview = invalid
    m.scrubKey = ""
    m.scrubRepeats = 0
    m.justCommittedSeek = false
    m.hideTimer = {}
    m.seekDebounceTimer = {}
    m.top = {nodes:{},opened:true,model:{title:"Show",episode:"S1 E3 · Pilot",position:650,duration:3600,live:false,paused:false,session:"A",state:"playing"},findNode:TestNode,hasFocus:TestFocus}
    render()
    ensure(m.top.nodes.controlRow.translation[0]=64 and m.top.nodes.btnExitIcon.translation[0]=1106,"controls span seek bar edges")
    ensure(not m.top.nodes.controlSurface.visible,"no enclosing control tray")
    ensure(m.top.nodes.timeLeft.text = "10:50","full original timeline")
    ensure(m.top.nodes.brandWordmark.text = "S1 E3 · Pilot" and m.top.nodes.brandWordmark.visible = true and m.top.nodes.brandMark.visible = true,"VOD header surfaces the episode instead of VIPTV")
    onKeyEvent("right",true)
    ensure(m.preview = 660 and m.top.command = invalid,"seek remains a preview")
    onKeyEvent("OK",true)
    ensure(m.top.command.kind = "seek" and m.top.command.value = 660,"one confirmed seek")
    m.top.command = invalid
    for i = 0 to 12
        onKeyEvent("right",true)
    end for
    target = m.preview
    ensure(target>m.top.model.position+130,"holding accelerates seeking")
    onKeyEvent("right",false)
    ensure(m.top.command=invalid and m.preview=target,"release waits for debounce instead of starting a request")
    ensure(m.seekDebounceTimer.control="start","release arms debounce")
    commitSeekPreview()
    ensure(m.top.command.kind="seek" and m.top.command.value=target and m.preview=invalid,"debounce commits one seek")
    m.top.command = invalid
    onKeyEvent("right",false)
    ensure(m.top.command=invalid,"duplicate release does not seek twice")
    m.row = 0
    onKeyEvent("right",true)
    onKeyEvent("right",false)
    onKeyEvent("right",true)
    onKeyEvent("right",false)
    ensure(m.preview=670 and m.top.command=invalid,"rapid taps coalesce into one pending seek")
    onKeyEvent("back",true)
    commitSeekPreview()
    ensure(m.preview=invalid and m.top.command=invalid,"Back cancels pending seek")
    onKeyEvent("down",true)
    onKeyEvent("right",true)
    onKeyEvent("right",true)
    onKeyEvent("OK",true)
    ensure(m.top.command.kind = "audio","audio icon action")
    m.top.command = invalid
    m.button = 0
    onKeyEvent("OK",true)
    onKeyEvent("OK",false)
    commitSeekPreview()
    ensure(m.top.command.kind = "seek" and m.top.command.value = 640,"visible rewind skips ten seconds")
    m.justCommittedSeek = false
    m.button = 2
    onKeyEvent("OK",true)
    onKeyEvent("OK",false)
    commitSeekPreview()
    ensure(m.top.command.kind = "seek" and m.top.command.value = 680,"visible forward skips thirty seconds")
    m.justCommittedSeek = false
    m.top.model.position = 3595
    onKeyEvent("OK",true)
    onKeyEvent("OK",false)
    commitSeekPreview()
    ensure(m.top.command.value = 3599,"forward clamps to timeline")
    m.justCommittedSeek = false
    m.button = 4
    onKeyEvent("OK",true)
    ensure(m.top.command.kind = "subtitles","captions action")
    m.button = 5
    onKeyEvent("OK",true)
    ensure(m.top.command.kind = "exit","visible exit action")
    m.button = 1
    m.top.command = invalid
    m.top.model.live = true
    m.row = 0
    m.preview = 400
    render()
    ensure(m.row = 1 and m.preview = invalid,"transition to live removes seek focus and preview")
    ensure(m.top.nodes.brandMark.visible = false and m.top.nodes.brandWordmark.visible = false,"live header hides the VIPTV mark")
    ensure(m.top.nodes.channelIdentity.visible = true,"live header shows channel identity in place of the V")
    ensure(m.top.nodes.seekRow.visible = false,"live has no seekbar")
    ensure(not m.top.nodes.btnAudioLabel.visible and not m.top.nodes.hint.visible,"controls are icon-only")
    for each key in ["up","right","up","left","fastforward","rewind","replay"]
        onKeyEvent(key,true)
        ensure(m.row = 1 and m.preview = invalid and m.top.command = invalid,"live navigation cannot seek")
    end for
    onKeyEvent("play",true)
    ensure(m.top.command = invalid,"live cannot pause")
    ensure(m.top.nodes.btnPauseIcon.visible = false and m.top.nodes.btnAudioIcon.visible,"live only shows supported actions")
    m.top.opened = false
    onKeyEvent("left",true)
    ensure(m.row = 1,"hidden live chrome reopens on icons")
    print "PASS: player icons, explicit seeking and live focus"
end sub
function TestNode(id as string) as object
    if not m.nodes.doesExist(id) then m.nodes[id] = {poster:{}}
    return m.nodes[id]
end function
function TestFocus() as boolean
    return true
end function
sub ensure(ok as boolean, label as string)
    if not ok
        print "FAIL: " + label
        stop
    end if
end sub
