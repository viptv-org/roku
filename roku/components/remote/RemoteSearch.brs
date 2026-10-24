function rSearchTag(tag as dynamic) as boolean
    return tag = "search" or tag = "search:channels"
end function

sub rRetireSearch()
    m.searchVersion++
    m.searchChannelVersion++
    for each worker in m.workers
        if rSearchTag(worker.request.tag) then worker.cancel = true
    end for
    retained = []
    for each request in m.queue
        if not rSearchTag(request.tag) then retained.push(request)
    end for
    m.queue = retained
    retained = []
    for each request in m.retryAuth
        if not rSearchTag(request.tag) then retained.push(request)
    end for
    m.retryAuth = retained
    m.pending.delete("search")
    m.pending.delete("search:channels")
    if RObject(m.failedRequest)
        if rSearchTag(m.failedRequest.tag)
            m.failedRequest = invalid
            m.retryBar.visible = false
        end if
    end if
    m.searchFailures = {}
    m.searchMediaRows = []
    m.searchChannelPages = []
    m.searchPagingFocus = invalid
    m.searchPagingDirection = ""
    m.searchExpectedFocus = invalid
    m.searchFirstResult = invalid
    m.searchResumeFocus = invalid
    if m.route = "search"
        m.shelves.content = invalid
        m.shelves.visible = false
        m.message.text = ""
    end if
end sub

sub rSearchChannelFetch(descriptor as dynamic, direction as string)
    if not m.searchChannelsAllowed or m.route <> "search" then return
    if m.searchFailures.doesExist("search:channels") then return
    for each request in m.retryAuth
        if request.tag = "search:channels" and rRequestCurrent(request) then return
    end for
    if RObject(m.afterParent)
        if m.afterParent.tag = "search:channels" and rRequestCurrent(m.afterParent) then return
    end if
    path = rProfilePath("/live/channels?limit=40&search="+REncode(m.searchTerm))
    if direction <> "initial"
        if not RObject(descriptor) then return
        path = rProfilePath("/live/channels?limit="+descriptor.limit.toStr()+"&page_size="+descriptor.page_size.toStr()+"&search="+REncode(m.searchTerm)+"&offset="+REncode(descriptor.cursor))
    end if
    rSend("GET",path,invalid,"search:channels",{search_version:m.searchVersion,channel_version:m.searchChannelVersion,paging:RCopy(descriptor),direction:direction})
end sub

sub rSearchChannelResponse(data as object, request as object)
    pages = m.searchChannelPages
    if pages.count() > 0
        if data.snapshot_id <> pages[0].snapshot_id
            rRetireSearchChannelPages()
            rSearchRender()
            rSearchChannelFetch(invalid,"initial")
            return
        end if
    end if
    direction = RText(request.context.direction)
    m.searchPagingDirection = ""
    if direction = "initial" then m.searchPagingDirection = "next"
    if direction = "initial" or data.availability <> "Available"
        m.searchChannelPages = [data]
    else if direction = "next"
        pages.push(data)
        if pages.count() > 2 then pages.shift()
    else if direction = "previous"
        pages.unshift(data)
        if pages.count() > 2 then pages.pop()
    end if
    rSearchRender()
end sub

sub rSearchRender()
    root = CreateObject("roSGNode","ContentNode")
    selected = ""
    selectedGroup = ""
    selectedCard = ""
    hadResultsFocus = m.shelves.isInFocusChain()
    if m.shelves.content <> invalid
        at = m.shelves.rowItemFocused
        if at.count() = 2
            oldRow = m.shelves.content.getChild(at[0])
            if oldRow <> invalid
                old = oldRow.getChild(at[1])
                if old <> invalid and RGet(old.wire,"action") = "liveChannel"
                    selected = old.wire.channel.id
                else if old <> invalid
                    selectedGroup = RText(oldRow.searchGroupId)
                    if RCard(old.wire) then selectedCard = RIdentityKey(old.wire)
                end if
            end if
        end if
    end if
    sizes = []
    spacing = []
    heights = []
    target = invalid
    firstResult = invalid
    for each group in m.searchMediaRows
        rowIndex = root.getChildCount()
        row = root.createChild("ContentNode")
        row.title = group.title
        cards = RArray(group.cards)
        message = RText(group.message)
        if message = "" and cards.count() = 0 then message = "No matches."
        titleHeight = 40
        rowHeight = 460
        if message <> ""
            titleHeight = 86
            rowHeight = 506
        end if
        if cards.count() = 0 then rowHeight = titleHeight+66
        row.addFields({searchTitleHeight:titleHeight,searchGroupId:RText(group.id),searchMessage:message})
        items = rContent(cards,212,394,318,"poster")
        row.appendChildren(items.getChildren(-1,0))
        if cards.count() > 0 and firstResult = invalid then firstResult = [rowIndex,0]
        if RText(group.id) = selectedGroup and selectedCard <> ""
            for i = 0 to cards.count()-1
                if RIdentityKey(cards[i]) = selectedCard then target = [rowIndex,i]
            end for
        end if
        sizes.push([212,394])
        spacing.push([16,0])
        heights.push(rowHeight)
    end for
    channels = []
    for each page in m.searchChannelPages
        channels.append(RArray(page.channels))
    end for
    channelMessage = ""
    if m.searchChannelPages.count() > 0 then channelMessage = RText(m.searchChannelPages[m.searchChannelPages.count()-1].reason)
    if channels.count() > 0 or channelMessage <> ""
        rowIndex = root.getChildCount()
        if firstResult = invalid and channels.count() > 0 then firstResult = [rowIndex,0]
        row = root.createChild("ContentNode")
        row.title = "Channels"
        titleHeight = 36
        if channelMessage <> "" then titleHeight = 82
        row.addFields({searchChannels:true,searchTitleHeight:titleHeight,searchHeadingHeight:36,searchMessage:channelMessage})
        values = []
        for each channel in channels
            value = RCopy(channel.card)
            value.action = "liveChannel"
            value.channel = channel
            if channel.id = selected then target = [rowIndex,values.count()]
            values.push(value)
        end for
        items = rContent(values,356,280,200,"logo")
        row.appendChildren(items.getChildren(-1,0))
        sizes.push([356,280])
        spacing.push([20,0])
        rowHeight = 346
        if channelMessage <> "" then rowHeight += 46
        if channels.count() = 0 then rowHeight = titleHeight+66
        heights.push(rowHeight)
    end if
    if target = invalid then target = firstResult
    m.searchFirstResult = firstResult
    m.heading.text = ""
    m.shelves.translation = [700,140]
    m.shelves.itemSize = [1124,460]
    m.shelves.rowLabelOffset = [[0,20]]
    m.shelves.rowItemSize = sizes
    m.shelves.rowItemSpacing = spacing
    m.shelves.rowHeights = heights
    m.searchResumeFocus = target
    m.searchExpectedFocus = target
    m.searchPagingFocus = target
    m.shelves.content = root
    if target <> invalid then m.shelves.jumpToRowItem = target
    if target = invalid and hadResultsFocus
        if m.retryBar.visible then m.retryBar.setFocus(true) else m.keyboard.setFocus(true)
    end if
    m.shelves.visible = root.getChildCount() > 0
    if not RObject(m.failedRequest)
        m.message.text = ""
        if root.getChildCount() = 0 and not m.pending.doesExist("search") and not m.pending.doesExist("search:channels") then m.message.text = "No matches. Try another search."
    end if
end sub

sub rSearchFocused()
    if m.shelves.content = invalid then return
    at = m.shelves.rowItemFocused
    if at.count() <> 2 then return
    if m.searchExpectedFocus <> invalid
        if not REqual(at,m.searchExpectedFocus) then return
        m.searchExpectedFocus = invalid
    else if m.searchPagingFocus <> invalid
        if m.searchPagingFocus[0] = at[0]
            if at[1] > m.searchPagingFocus[1] then m.searchPagingDirection = "next"
            if at[1] < m.searchPagingFocus[1] then m.searchPagingDirection = "previous"
        else
            m.searchPagingDirection = ""
        end if
    end if
    m.searchPagingFocus = at
    row = m.shelves.content.getChild(at[0])
    if row = invalid then return
    if row.getChild(at[1]) <> invalid then m.searchResumeFocus = at
    if row.searchChannels <> true then return
    if m.searchFailures.doesExist("search:channels") then return
    pages = m.searchChannelPages
    if pages.count() = 0 then return
    if m.searchPagingDirection = "next" and at[1] >= row.getChildCount()-3 and RObject(RLiveBoundary(pages,"next"))
        rSearchChannelFetch(RLiveBoundary(pages,"next"),"next")
    else if m.searchPagingDirection = "previous" and at[1] <= 3 and RObject(RLiveBoundary(pages,"previous"))
        rSearchChannelFetch(RLiveBoundary(pages,"previous"),"previous")
    end if
end sub

sub rSearchFailure(request as object, message as string)
    m.searchFailures[request.tag] = {request:request,message:message}
    rSearchErrors()
end sub

sub rSearchErrors()
    m.retryBar.visible = false
    m.failedRequest = invalid
    for each tag in ["search","search:channels"]
        if m.searchFailures.doesExist(tag) and not m.pending.doesExist(tag)
            failure = m.searchFailures[tag]
            if rRequestCurrent(failure.request)
                m.failedRequest = failure.request
                rError(failure.message)
                return
            end if
        end if
    end for
    m.message.text = ""
end sub

sub rRetireSearchChannelPages()
    m.searchChannelVersion++
    for each worker in m.workers
        if worker.request.tag = "search:channels" then worker.cancel = true
    end for
    retained = []
    for each request in m.queue
        if request.tag <> "search:channels" then retained.push(request)
    end for
    m.queue = retained
    retained = []
    for each request in m.retryAuth
        if request.tag <> "search:channels" then retained.push(request)
    end for
    m.retryAuth = retained
    m.pending.delete("search:channels")
    m.searchFailures.delete("search:channels")
    if RObject(m.failedRequest)
        if m.failedRequest.tag = "search:channels" then m.failedRequest = invalid
    end if
    m.searchChannelPages = []
    m.searchPagingFocus = invalid
    m.searchPagingDirection = ""
end sub

function rSearchChannelCurrent(request as object) as boolean
    if RGet(request.context,"channel_version") <> m.searchChannelVersion then return false
    direction = RText(RGet(request.context,"direction"))
    pages = m.searchChannelPages
    if direction = "initial" then return pages.count() = 0 and RGet(request.context,"paging") = invalid
    descriptor = RLiveBoundary(pages,direction)
    return RObject(descriptor) and REqual(RGet(request.context,"paging"),descriptor)
end function

function rSearchPreviousKey() as boolean
    if not m.shelves.isInFocusChain() or not RObject(RLiveBoundary(m.searchChannelPages,"previous")) then return false
    if m.searchFailures.doesExist("search:channels") then return false
    if RObject(m.failedRequest)
        if m.failedRequest.tag = "search:channels" then return false
    end if
    at = m.shelves.rowItemFocused
    if at.count() <> 2 or m.shelves.content = invalid then return false
    row = m.shelves.content.getChild(at[0])
    if row = invalid then return false
    if row.searchChannels <> true or at[1] <> 0 then return false
    rSearchChannelFetch(RLiveBoundary(m.searchChannelPages,"previous"),"previous")
    return true
end function
