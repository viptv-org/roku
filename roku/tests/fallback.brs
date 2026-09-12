sub Main()
    m.config = {base:"https://library.example",access_token:"fixture-access",last_profile_id:"viewer",account_id:"account",capabilities:{max_height:720}}
    m.profile = "viewer"
    m.queue = []
    m.tasks = []
    m.generation = 1
    m.requestSequence = 0
    m.poll = {control:""}
    m.status = {text:""}
    m.list = {itemFocused:0,setFocus:Noop}
    m.startup = {control:""}
    m.heartbeat = {control:""}
    m.budgetTimer = {control:"",duration:0}
    m.video = {visible:false,position:0,duration:0,control:"",state:"",setFocus:Noop}
    m.top = {setFocus:Noop,dialog:invalid}
    m.session = ""
    m.playing = false
    m.pendingPlayback = false
    m.refreshingSources = false
    m.playbackLive = false
    m.playbackMode = "transcode"
    m.playItem = {id:"movie-id",type:"movie",name:"Movie",position:500,duration:2770}
    m.position = 500
    m.duration = 2770
    m.sourcesAt = CreateObject("roDateTime").asSeconds()
    m.activeSourceAt = m.sourcesAt
    m.discoveryDone = true
    m.streams = [{id:"ephemeral-other",source_addon_id:"addon.other",name:"Other"},{id:"ephemeral-new",source_addon_id:"addon.chosen",name:"Chosen"}]
    resetAttempts()

    preferred = StableResumePreference({id:"movie",position:500,source_addon_id:"addon.chosen",source_name:"Chosen"})
    check(preferred.source_addon_id = "addon.chosen" and preferred.source_name = "Chosen","resume accepts a bounded stable addon/name preference")
    check(StableResumePreference({id:"movie",position:500,stream_id:"ephemeral-old"}) = invalid,"ephemeral stream UUID alone is never a resume preference")
    check(StableResumePreference({id:"movie",position:0,source_addon_id:"addon.chosen",source_name:"Chosen"}) = invalid,"fresh playback never auto-selects")
    check(StableResumePreference({id:"movie",position:500,source_addon_id:string(257,"x"),source_name:"Chosen"}) = invalid,"oversized preference is discarded")

    m.manualSources = false
    m.resumeSourcePreference = preferred
    tryResumeSource()
    check(m.queue.count() = 1 and m.queue[0].path = "/api/playback","resume starts one exact prior source")
    check(m.queue[0].body.stream_id = "ephemeral-new" and m.playItem.stream_id = "ephemeral-new","resume resolves the stable pair to the current ephemeral ID")
    check(m.playItem.source_addon_id = "addon.chosen" and m.playItem.source_name = "Chosen","selected source carries only bounded stable preference metadata")

    m.queue = []
    m.pendingPlayback = false
    m.playing = false
    m.attempted = {}
    m.manualSources = false
    m.resumeSourcePreference = {source_addon_id:"addon.missing",source_name:"Missing"}
    m.discoveryDone = true
    tryResumeSource()
    check(m.queue.count() = 0 and m.manualSources,"stale preference falls back to explicit picker, not another source")
    check(instr(1,m.status.text,"Choose another source") > 0,"stale resume explains explicit choice")

    m.queue = []
    m.manualSources = false
    m.resumeSourcePreference = invalid
    tryResumeSource()
    check(m.queue.count() = 0 and m.manualSources,"ordinary playback with no preference always remains manual")
    print "ROKU_FALLBACK_OK"
end sub
sub Noop(value as boolean)
end sub
sub check(value as boolean,message as string)
    if not value then throw message
end sub
