sub Main()
    m.config = {base:"https://library.example",access_token:"fixture-access",last_profile_id:"viewer",account_id:"account",capabilities:{max_height:720}}
    m.profile = "viewer"
    m.queue = []
    m.tasks = []
    m.generation = 1
    m.requestSequence = 0
    m.poll = {control:""}
    m.status = {text:""}
    m.startup = {control:""}
    m.heartbeat = {control:""}
    m.budgetTimer = {control:"",duration:0}
    m.video = {visible:false,position:0,duration:0,control:"",state:"",setFocus:Noop}
    m.top = {setFocus:Noop,dialog:invalid}
    m.list = {itemFocused:0,setFocus:Noop}
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
    m.streams = [{id:"ephemeral-other",source_addon_id:"addon.other",name:"Other",source_fingerprint:"fp-other"},{id:"ephemeral-name-twin",source_addon_id:"addon.chosen",name:"Chosen",source_fingerprint:"fp-twin"},{id:"ephemeral-new",source_addon_id:"addon.chosen",name:"Chosen",source_fingerprint:"fp-chosen"}]
    resetAttempts()

    preferred = StableResumePreference({id:"movie",position:500,source_addon_id:"addon.chosen",source_name:"Chosen",source_fingerprint:"fp-chosen"})
    check(preferred.source_addon_id = "addon.chosen" and preferred.source_fingerprint = "fp-chosen","resume accepts a bounded stable addon/fingerprint preference")
    check(StableResumePreference({id:"movie",position:500,source_addon_id:"addon.chosen",source_name:"Chosen"}) = invalid,"addon/name text alone never authorizes resume")
    check(StableResumePreference({id:"movie",position:500,stream_id:"ephemeral-old"}) = invalid,"ephemeral stream UUID alone is never a resume preference")
    check(StableResumePreference({id:"movie",position:0,source_addon_id:"addon.chosen",source_name:"Chosen",source_fingerprint:"fp-chosen"}) = invalid,"fresh playback never auto-selects")
    check(StableResumePreference({id:"movie",position:500,source_addon_id:string(257,"x"),source_name:"Chosen",source_fingerprint:"fp-chosen"}) = invalid,"oversized preference is discarded")

    m.mode = "resuming"
    m.manualSources = false
    m.resumeSourcePreference = preferred
    tryResumeSource()
    starts = FallbackPlaybackStarts()
    check(starts.count() = 1 and starts[0].method = "POST","resume starts one exact prior source through v2 playback")
    check(starts[0].body.stream_id = "ephemeral-new" and m.playItem.stream_id = "ephemeral-new","resume resolves the stable fingerprint, not a same-name twin, to the current ephemeral ID")
    check(m.playItem.source_addon_id = "addon.chosen" and m.playItem.source_name = "Chosen","selected source carries only bounded stable preference metadata")

    ' Stale preferences reopening the explicit picker: explicit_resume_runtime.py (decision case).
    m.queue = []
    m.pendingPlayback = false
    m.playing = false
    m.mode = "resuming"
    m.manualSources = false
    m.resumeSourcePreference = invalid
    tryResumeSource()
    check(FallbackPlaybackStarts().count() = 0,"ordinary playback with no preference never auto-starts a source")
    print "ROKU_FALLBACK_OK"
end sub
sub Noop(value as boolean)
end sub
sub check(value as boolean,message as string)
    if not value then throw message
end sub
function FallbackPlaybackStarts() as object
    starts = []
    for each entry in m.queue
        if entry.path = "/api/v2/playback" then starts.push(entry)
    end for
    return starts
end function
