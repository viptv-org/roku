sub rLive(data as object, preserve = false as boolean)
    selected = ""
    selections = {}
    if preserve and m.rows.content <> invalid
        for each row in m.rows.content.getChildren(-1,0)
            if RText(row.manualProgram) <> "" then selections[row.wire.channel.id] = row.manualProgram
        end for
    end if
    if preserve and m.rows.content <> invalid
        current = m.rows.content.getChild(m.rows.itemFocused)
        if current <> invalid then selected = current.wire.channel.id
    end if
    m.liveData = data
    if not preserve
        m.liveGuides = {}
        m.liveOrder = []
        m.livePages = [data]
    end if
    values = []
    for each channel in RArray(data.channels)
        values.push({title:channel.card.title,action:"liveChannel",channel:channel})
    end for
    m.rows.itemComponentName = "RemoteGuideRow"
    m.rows.itemSize = [1728,72]
    m.rows.itemSpacing = [0,8]
    ' Five rows end at 922px, clear of the shared message label at y=940.
    m.rows.numRows = 5
    root = rContent(values,1728,72)
    for each node in root.getChildren(-1,0)
        node.addFields({guideData:{},programIndex:-1,viewport:{start_millis:0.0#},manualProgram:""})
        if selections.doesExist(node.wire.channel.id) then node.manualProgram = selections[node.wire.channel.id]
        if m.liveGuides.doesExist(node.wire.channel.id) then rApplyGuide(node,m.liveGuides[node.wire.channel.id])
    end for
    target = 0
    index = 0
    for each node in root.getChildren(-1,0)
        if node.wire.channel.id = selected then target = index
        index++
    end for
    m.liveExpectedFocus = invalid
    if target > 0 then m.liveExpectedFocus = target
    m.liveFocusIndex = target
    m.livePagingDirection = "next"
    if preserve then m.livePagingDirection = ""
    m.rows.content = root
    m.rows.jumpToItem = target
    m.rows.visible = values.count() > 0
    if values.count() = 0 then m.hero.visible = false
    m.rows.translation = [96,530]
    groups = [{title:"All",action:"liveGroup",id:""}]
    for each group in RArray(data.groups)
        groups.push({title:group.label,action:"liveGroup",id:group.id})
    end for
    m.filters.content = rContent(groups,260,64)
    m.filters.translation = [96,456]
    m.filters.visible = values.count() > 0 or groups.count() > 1
    m.message.text = RText(data.reason)
    m.heading.text = ""
    if values.count() = 0 and not m.drawer.visible and m.playback = invalid
        if m.filters.visible then m.filters.setFocus(true) else m.navigation.setFocus(true)
    end if
    rLoadGuides()
end sub

sub rRowFocused(event = invalid as dynamic)
    if m.route = "live"
        observed = m.rows.itemFocused
        if event <> invalid then observed = event.getData()
        if m.liveExpectedFocus <> invalid
            if observed <> m.liveExpectedFocus then return
            m.liveExpectedFocus = invalid
        end if
        if observed <> m.rows.itemFocused then return
        if observed > m.liveFocusIndex then m.livePagingDirection = "next"
        if observed < m.liveFocusIndex then m.livePagingDirection = "previous"
        m.liveFocusIndex = observed
        m.heroTick.control = "stop"
        m.heroTick.control = "start"
    end if
    if m.route = "calendar" then rCalendarPreview()
    if m.route = "history" and m.historyMore = true
        if m.rows.itemFocused >= m.rows.content.getChildCount()-4 then rSend("GET",rProfilePath("/history?limit=100&offset="+m.historyOffset.toStr()),invalid,"history")
    end if
end sub

sub rLoadGuides()
    if m.route <> "live" or m.rows.content = invalid or m.liveExpectedFocus <> invalid then return
    if m.drawer.visible or rInputVisible() or m.playback <> invalid then return
    if RObject(m.afterParent)
        if rLiveDataTag(m.afterParent.tag) and rRequestCurrent(m.afterParent) then return
    end if
    if rLiveRetryRequired()
        rLivePreview()
        message = RText(m.liveFailureText,"Live information could not be loaded. Try again.")
        if not m.retryBar.visible or m.message.text <> message then rError(message)
        return
    end if
    for each request in m.retryAuth
        if rLiveDataTag(request.tag) and rRequestCurrent(request)
            rLivePreview()
            return
        end if
    end for
    at = m.rows.itemFocused
    if at < 0 then at = 0
    for i = at to at+5
        node = m.rows.content.getChild(i)
        if node <> invalid
            channel = node.wire.channel
            if not m.liveGuides.doesExist(channel.id)
                rSend("GET",rProfilePath("/live/"+REncode(channel.id)+"/guide"),invalid,"live:guide:"+channel.id,{channel:channel.id,live_version:m.liveVersion,query:m.liveQuery})
            end if
        end if
    end for
    rLivePreview()
    if m.livePagingDirection = "next" and at >= m.rows.content.getChildCount()-5 and RObject(RLiveBoundary(m.livePages,"next"))
        rLivePageFetch("next")
    else if m.livePagingDirection = "previous" and at <= 1 and RObject(RLiveBoundary(m.livePages,"previous"))
        rLivePageFetch("previous")
    end if
end sub

sub rLivePage(data as object, request as object)
    if request.context.query <> m.liveQuery then return
    if data.snapshot_id <> m.liveData.snapshot_id
        rReloadLiveDirectory()
        return
    end if
    if data.availability <> "Available"
        rRetireLiveRequests()
        rLive(data)
        return
    end if
    if request.context.direction = "next"
        m.livePages.push(data)
        if m.livePages.count() > 2 then m.livePages.shift()
    else
        m.livePages.unshift(data)
        if m.livePages.count() > 2 then m.livePages.pop()
    end if
    merged = RCopy(data)
    merged.channels = []
    merged.complete = m.livePages[m.livePages.count()-1].complete
    for each page in m.livePages
        merged.channels.append(RArray(page.channels))
    end for
    rLive(merged,true)
end sub

sub rLiveGuide(data as object, request as object)
    if data.channel_id <> request.context.channel then return
    m.liveGuides[data.channel_id] = data
    retained = []
    for each channel in m.liveOrder
        if channel <> data.channel_id then retained.push(channel)
    end for
    retained.push(data.channel_id)
    m.liveOrder = retained
    while m.liveOrder.count() > 12
        expired = m.liveOrder.shift()
        m.liveGuides.delete(expired)
        for each node in m.rows.content.getChildren(-1,0)
            if node.wire.channel.id = expired then node.guideData = {}
        end for
    end while
    for each node in m.rows.content.getChildren(-1,0)
        if node.wire.channel.id = data.channel_id
            rApplyGuide(node,data)
        end if
    end for
    rLivePreview()
end sub

sub rApplyGuide(node as object, data as object)
    viewport = {start_millis:data.view.window_start_millis}
    selected = -1
    current = -1
    manual = RText(node.manualProgram)
    index = 0
    for each program in RArray(data.programs)
        if program.id = data.view.current_program_id then current = index
        if manual <> "" and program.id = manual then selected = index
        index++
    end for
    if selected < 0
        manual = ""
        selected = current
    else
        program = data.programs[selected]
        viewport = {start_millis:RGuideWindowMillis(program.start_millis)}
    end if
    node.manualProgram = manual
    node.viewport = viewport
    node.programIndex = selected
    node.guideData = data
end sub

sub rLivePreview()
    if m.liveExpectedFocus <> invalid or m.rows.content = invalid then return
    node = m.rows.content.getChild(m.rows.itemFocused)
    if node = invalid then node = m.rows.content.getChild(0)
    if node = invalid then return
    card = node.wire.channel.card
    m.hero.visible = true
    m.heroLogo.visible = false
    m.heroTitle.visible = true
    m.heroTitle.translation = [96,178]
    m.heroTitle.width = 820
    m.heroTitle.height = 120
    m.heroTitle.numLines = 2
    m.heroTitle.text = card.title
    m.heroMeta.translation = [96,130]
    ' The title slot shows the programme when the guide has one, so the channel
    ' name belongs in the metadata line; without a programme it would repeat.
    m.heroMeta.parts = ["LIVE"]
    m.heroMeta.badges = []
    m.heroDescription.translation = [96,330]
    m.heroDescription.text = ""
    m.backdrop.translation = [1184,120]
    m.backdrop.width = 640
    m.backdrop.height = 360
    uri = RText(card.landscape,RText(card.poster))
    if left(uri,5) = "/api/" then uri = m.config.base+uri
    rBackdrop(uri)
    m.top.findNode("scrimX").visible = false
    m.top.findNode("scrimY").visible = false
    programs = RArray(RGet(node.guideData,"programs"))
    if node.programIndex >= 0 and node.programIndex < programs.count()
        program = programs[node.programIndex]
        m.heroTitle.text = program.title
        m.heroMeta.parts = ["LIVE",card.title]
        m.heroDescription.text = RText(program.description)
    end if
end sub

function rLiveKey(key as string) as boolean
    if not m.rows.isInFocusChain() then return false
    if key <> "left" and key <> "right" then return false
    node = m.rows.content.getChild(m.rows.itemFocused)
    if node = invalid then return true
    programs = RArray(RGet(node.guideData,"programs"))
    index = node.programIndex
    if key = "left" then index-- else index++
    if index >= 0 and index < programs.count()
        node.programIndex = index
        node.manualProgram = programs[index].id
        node.viewport = {start_millis:RGuideWindowMillis(programs[index].start_millis)}
        ' Republishing the guide data is what makes RemoteGuideRow rebuild its
        ' programme tiles for the newly selected window.
        node.guideData = node.guideData
        rLivePreview()
    end if
    return true
end function

function rLiveDataTag(tag as string) as boolean
    return tag = "live" or tag = "live:page" or left(tag,11) = "live:guide:"
end function

sub rRetireLiveRequests()
    m.liveExpectedFocus = invalid
    m.liveFailureText = ""
    m.liveRetryTag = ""
    m.liveVersion++
    for each worker in m.workers
        if rLiveDataTag(worker.request.tag) then worker.cancel = true
    end for
    retained = []
    for each request in m.queue
        if not rLiveDataTag(request.tag) then retained.push(request)
    end for
    m.queue = retained
    retained = []
    for each request in m.retryAuth
        if not rLiveDataTag(request.tag) then retained.push(request)
    end for
    m.retryAuth = retained
    for each tag in m.pending.keys()
        if rLiveDataTag(tag) then m.pending.delete(tag)
    end for
    if RObject(m.failedRequest)
        if rLiveDataTag(m.failedRequest.tag) then m.failedRequest = invalid
    end if
end sub

sub rLiveGroup(groupId as string)
    m.liveQuery = ""
    if groupId <> "" then m.liveQuery = "&group_id="+REncode(groupId)
    rReloadLiveDirectory(false)
end sub

sub rReloadLiveDirectory(clearGroups = true as boolean)
    rRetireLiveRequests()
    m.liveGuideRefreshDue = rNow()+30
    if clearGroups
        m.filters.content = invalid
        m.filters.visible = false
        if not m.drawer.visible and m.playback = invalid then m.navigation.setFocus(true)
    end if
    m.liveData = invalid
    m.liveGuides = {}
    m.liveOrder = []
    m.livePages = []
    m.rows.visible = false
    m.rows.content = invalid
    m.skeleton.visible = false
    m.hero.visible = false
    m.heroTick.control = "stop"
    m.retryBar.visible = false
    m.message.text = "Loading channels…"
    if m.filters.visible then m.filters.setFocus(true)
    rSend("GET",rProfilePath("/live/channels?limit=100"+m.liveQuery),invalid,"live",{live_version:m.liveVersion,query:m.liveQuery})
end sub

function rLiveRetryRequired() as boolean
    if not RObject(m.failedRequest) then return false
    return rLiveDataTag(m.failedRequest.tag) and rRequestCurrent(m.failedRequest)
end function

sub rRefreshVisibleGuides(now as double)
    if m.route <> "live" or m.rows.content = invalid or not m.rows.visible then return
    if m.liveExpectedFocus <> invalid or m.drawer.visible or rInputVisible() or m.playback <> invalid then return
    if rLiveRetryRequired() then return
    if RObject(m.afterParent)
        if rLiveDataTag(m.afterParent.tag) and rRequestCurrent(m.afterParent) then return
    end if
    for each request in m.retryAuth
        if rLiveDataTag(request.tag) and rRequestCurrent(request) then return
    end for
    if m.liveGuideRefreshDue <= 0 then m.liveGuideRefreshDue = now+30
    if now < m.liveGuideRefreshDue then return
    first = m.rows.itemFocused-4
    if first < 0 then first = 0
    channels = []
    for i = first to m.rows.itemFocused+5
        node = m.rows.content.getChild(i)
        if node <> invalid
            channel = node.wire.channel
            if not m.pending.doesExist("live:guide:"+channel.id) then channels.push(channel.id)
        end if
    end for
    if m.queue.count()+channels.count() > 24 then return
    m.liveGuideRefreshDue = now+30
    for each id in channels
        rSend("GET",rProfilePath("/live/"+REncode(id)+"/guide"),invalid,"live:guide:"+id,{channel:id,live_version:m.liveVersion,query:m.liveQuery})
    end for
end sub

sub rLivePageFetch(direction as string)
    descriptor = RLiveBoundary(m.livePages,direction)
    if not RObject(descriptor) then return
    path = "/live/channels?limit="+descriptor.limit.toStr()+"&page_size="+descriptor.page_size.toStr()+m.liveQuery+"&offset="+REncode(descriptor.cursor)
    rSend("GET",rProfilePath(path),invalid,"live:page",{paging:RCopy(descriptor),direction:direction,query:m.liveQuery,live_version:m.liveVersion})
end sub

function rLivePageCurrent(request as object) as boolean
    descriptor = RLiveBoundary(m.livePages,RText(RGet(request.context,"direction")))
    return RObject(descriptor) and REqual(RGet(request.context,"paging"),descriptor)
end function
