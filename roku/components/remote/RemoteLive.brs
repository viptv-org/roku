sub rLive(data as object, preserve = false as boolean)
    selected = ""
    if preserve and m.rows.content <> invalid
        current = m.rows.content.getChild(m.rows.itemFocused)
        if current <> invalid then selected = current.wire.channel.id
    end if
    m.liveData = data
    if not preserve
        m.liveGuides = {}
        m.liveOrder = []
        m.livePages = [data]
        m.liveCursors = [""]
        m.liveFirst = 0
        m.liveNext = RText(data.next_cursor)
    end if
    values = []
    for each channel in RArray(data.channels)
        values.push({title:channel.card.title,action:"liveChannel",channel:channel})
    end for
    m.rows.itemComponentName = "RemoteGuideRow"
    m.rows.itemSize = [1728,72]
    m.rows.itemSpacing = [0,8]
    m.rows.numRows = 5
    root = rContent(values,1728,72)
    for each node in root.getChildren(-1,0)
        node.addFields({guideData:{},programIndex:-1,windowStart:0.0})
    end for
    m.rows.content = root
    index = 0
    for each node in root.getChildren(-1,0)
        if node.wire.channel.id = selected then m.rows.jumpToItem = index
        index++
    end for
    m.rows.visible = true
    m.rows.translation = [96,636]
    groups = [{title:"All",action:"liveGroup",id:""}]
    for each group in RArray(data.groups)
        groups.push({title:group.label,action:"liveGroup",id:group.id})
    end for
    m.filters.content = rContent(groups,260,64)
    m.filters.translation = [96,512]
    m.filters.visible = true
    m.message.text = RText(data.reason)
    m.heading.text = ""
    rLoadGuides()
end sub

sub rRowFocused()
    if m.route = "live"
        m.heroTick.control = "stop"
        m.heroTick.control = "start"
    end if
    if m.route = "calendar" then rCalendarPreview()
    if m.route = "history" and m.historyMore = true
        if m.rows.itemFocused >= m.rows.content.getChildCount()-4 then rSend("GET",rProfilePath("/history?limit=100&offset="+m.historyOffset.toStr()),invalid,"history")
    end if
end sub

sub rLoadGuides()
    if m.route <> "live" or m.rows.content = invalid then return
    at = m.rows.itemFocused
    if at < 0 then at = 0
    for i = at to at+5
        node = m.rows.content.getChild(i)
        if node <> invalid
            channel = node.wire.channel
            if not m.liveGuides.doesExist(channel.id)
                rSend("GET",rProfilePath("/live/"+REncode(channel.id)+"/guide"),invalid,"live:guide:"+channel.id,{channel:channel.id})
            end if
        end if
    end for
    rLivePreview()
    if at >= m.rows.content.getChildCount()-5 and RText(m.liveNext) <> ""
        rSend("GET",rProfilePath("/live/channels?limit=100"+m.liveQuery+"&offset="+REncode(m.liveNext)),invalid,"live:page",{cursor:m.liveNext,direction:"next",query:m.liveQuery})
    else if at <= 1 and m.liveFirst > 0
        cursor = m.liveCursors[m.liveFirst-1]
        path = "/live/channels?limit=100"+m.liveQuery
        if cursor <> "" then path += "&offset="+REncode(cursor)
        rSend("GET",rProfilePath(path),invalid,"live:page",{cursor:cursor,direction:"previous",query:m.liveQuery})
    end if
end sub

sub rLivePage(data as object, request as object)
    if request.context.query <> m.liveQuery then return
    if request.context.direction = "next"
        nextIndex = m.liveFirst+m.livePages.count()
        if m.liveCursors.count() <= nextIndex then m.liveCursors.push(request.context.cursor)
        m.livePages.push(data)
        if m.livePages.count() > 2
            m.livePages.shift()
            m.liveFirst++
        end if
        m.liveNext = RText(data.next_cursor)
    else
        m.liveFirst--
        m.livePages.unshift(data)
        if m.livePages.count() > 2 then m.livePages.pop()
        m.liveNext = RText(m.livePages[m.livePages.count()-1].next_cursor)
    end if
    merged = {channels:[],groups:m.liveData.groups,connections:m.liveData.connections,reason:m.liveData.reason}
    for each page in m.livePages
        merged.channels.append(RArray(page.channels))
    end for
    rLive(merged,true)
end sub

sub rLiveGuide(data as object, request as object)
    if data.channel_id <> request.context.channel then return
    m.liveGuides[data.channel_id] = data
    m.liveOrder.push(data.channel_id)
    while m.liveOrder.count() > 12
        expired = m.liveOrder.shift()
        m.liveGuides.delete(expired)
        for each node in m.rows.content.getChildren(-1,0)
            if node.wire.channel.id = expired then node.guideData = {}
        end for
    end while
    for each node in m.rows.content.getChildren(-1,0)
        if node.wire.channel.id = data.channel_id
            node.windowStart = RGet(RGet(data,"view",{}),"window_start_millis",0)/1000
            node.programIndex = -1
            index = 0
            for each program in RArray(data.programs)
                if program.id = RGet(RGet(data,"view",{}),"current_program_id") then node.programIndex = index
                index++
            end for
            node.guideData = data
        end if
    end for
    rLivePreview()
end sub

sub rLivePreview()
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
    m.heroMeta.text = "LIVE · "+card.title
    m.heroDescription.translation = [96,330]
    m.heroDescription.text = ""
    m.backdrop.translation = [1184,120]
    m.backdrop.width = 640
    m.backdrop.height = 360
    m.backdrop.uri = RText(card.landscape,RText(card.poster))
    m.top.findNode("scrimX").visible = false
    m.top.findNode("scrimY").visible = false
    programs = RArray(RGet(node.guideData,"programs"))
    if node.programIndex >= 0 and node.programIndex < programs.count()
        program = programs[node.programIndex]
        m.heroTitle.text = program.title
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
        node.windowStart = int((programs[index].start_millis/1000)/1800)*1800
        ' Re-publish the data only on a time-window change, never per frame.
        node.guideData = node.guideData
        rLivePreview()
    end if
    return true
end function
