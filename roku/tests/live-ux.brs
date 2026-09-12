sub Main()
    m.config = {base:"https://fixture.invalid",access_token:"fixture-access",last_profile_id:"viewer",account_id:"account",capabilities:{}}
    m.generation = 1
    m.queue = []
    m.tasks = []
    m.poll = {control:""}
    m.status = {text:""}
    m.description = {text:""}
    m.detailInfo = {text:""}
    m.detailTitle = {text:""}
    m.heading = {text:""}
    m.art = {uri:""}
    m.list = {itemFocused:0,itemSelected:0,itemSize:[],content:invalid,jumpToItem:0,setFocus:NoopFocus}
    m.top = {dialog:invalid}
    m.liveEpgTimer = {control:""}
    m.liveEpgSequence = 0
    m.liveEpgBusy = ""
    m.mode = "browse"
    m.mediaType = "live"
    m.items = [{id:"opaque/channel:A",type:"live",name:"Channel A"},{id:"opaque/channel:B",type:"live",name:"Channel B"}]
    channels = m.items
    m.duration = 0
    m.position = 0
    m.profile = "p1"
    m.pendingPlayback = false
    m.playing = false
    m.search = ""
    m.views = []
    selectItem({action:"live"})
    check(m.queue.count() = 1 and m.queue[0].path = "/api/live/categories?limit=80&offset=0","Live opens categories before any all-channel request")
    m.queue = []
    m.items = channels
    m.liveCategory = "category:World News"
    m.search = "news"
    selectItem({action:"liveclear"})
    check(m.liveCategory = "" and m.search = "" and m.queue.count() = 1,"clear category and search explicitly")
    m.mode = "browse"
    values = LiveBrowseActions(m.items,"category:World News","")
    check(values[0].action = "livefilter" and values[1].action = "liveclear" and values[3].id = "opaque/channel:A","filter controls preserve opaque channel IDs")
    check(LiveBrowseActions(m.items,"","").count() = 4,"clear filter hidden when no filter")
    m.queue = []
    queueLiveEpg(m.items[0])
    check(m.queue.count() = 0 and m.liveEpgTimer.control = "start","focus is debounced, never requests immediately")
    m.list.itemFocused = 1
    queueLiveEpg(m.items[1])
    fetchFocusedLiveEpg()
    check(m.queue.count() = 1 and instr(1,m.queue[0].path,"opaque%2Fchannel%3AB") > 0,"rapid focus requests only latest channel")
    tagB = m.liveEpgBusy
    m.list.itemFocused = 0
    queueLiveEpg(m.items[0])
    fetchFocusedLiveEpg()
    check(m.queue.count() = 1,"only one focused EPG in flight")
    m.description.text = "keep A"
    liveEpgResponse(tagB,{ok:true,data:{programs:[]}},m.generation)
    check(m.description.text = "keep A","old focused channel response cannot overwrite new channel")
    fetchFocusedLiveEpg()
    check(m.queue.count() = 2,"latest pending channel follows completion")
    tagA = m.liveEpgBusy
    liveEpgResponse(tagA,{ok:true,data:{programs:[]}},m.generation)
    check(instr(1,m.description.text,"NOW") > 0 and instr(1,m.description.text,"NEXT") > 0,"empty guide has useful explicit now next fallback")
    queued = m.queue.count()
    fetchFocusedLiveEpg()
    check(m.queue.count() = queued,"settled timer never repeats same-channel fetch")
    queueLiveEpg(m.items[0])
    fetchFocusedLiveEpg()
    staleTag = m.liveEpgBusy
    oldGeneration = m.generation
    cancelBrowse()
    m.description.text = "new view"
    liveEpgResponse(staleTag,{ok:true,data:{programs:[]}},oldGeneration)
    check(m.description.text = "new view" and m.liveEpgTimer.control = "stop","navigation invalidates EPG timer and stale response")
    text = LiveNowNext([{title:"later",start:300,end:400},{title:"current",start:100,end:200},{title:"next",start:200,end:300}],150)
    check(instr(1,text,"current") > 0 and instr(1,text,"next") > 0 and instr(1,text,"later") = 0,"unsorted guide selects current and earliest next")
    m.queue = []
    for i = 1 to 24
        m.queue.push({path:"/busy",tag:"busy"})
    end for
    queueLiveEpg(m.items[0])
    fetchFocusedLiveEpg()
    check(m.queue.count() = 24 and m.liveEpgBusy = "","EPG respects existing ordinary queue bound")
    m.queue = []
    m.liveEpgPending = invalid
    check(openFocusedLiveGuide(),"Info explicitly opens selected channel guide")
    check(m.queue.count() = 1 and left(m.queue[0].path,11) = "/api/guide/","Info requests guide, not playback")
    check(m.views[m.views.count()-1].index = 0,"guide return retains exact channel focus snapshot")
    m.queue = []
    selectItem(m.items[0])
    check(m.queue.count() = 1 and m.queue[0].path = "/api/playback" and m.queue[0].method = "POST","channel Select directly plays without guide maze")
    body = m.queue[0].body
    check(body.channel_id = "opaque/channel:A" and body.position = 0 and body.allow_unknown_audio = invalid,"direct live preserves opaque ID without language gating")
    print "ROKU_LIVE_UX_OK"
end sub
sub NoopFocus(value as boolean)
end sub
sub check(condition as boolean, message as string)
    if not condition
        print "FAIL ";message
        stop
    end if
end sub
