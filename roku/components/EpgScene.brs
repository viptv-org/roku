' MainScene owns authenticated transport and playback; EpgGrid owns navigation.
sub initEpg()
    m.epgGrid = m.top.findNode("epgGrid")
    m.epgGrid.observeField("route","epgRouteChanged")
    m.epgGrid.observeField("needed","epgPump")
    m.epgGrid.observeField("watch","epgWatch")
    m.epgGrid.observeField("leave","epgLeave")
    m.epgGrid.observeField("searchRequested","epgSearch")
    m.epgPending = {}
    m.epgSerial = 0
end sub

sub openEpg(resuming = false as boolean, collection = "" as string)
    cancelBrowse()
    m.discoverActive = false
    m.mediaType = "live"
    rows("Live TV",[],"epg","")
    m.standardList.visible = false
    m.heading.visible = false
    m.pageCaption.visible = false
    m.epgPending = {}
    if resuming
        m.epgGrid.callFunc("resume")
    else
        m.epgSnapshot = invalid
        m.epgGrid.callFunc("open",m.accountEpoch.toStr()+":"+m.profile)
        if collection <> "" then m.epgGrid.callFunc("chooseFilter",collection)
        request("GET","/api/v2/iptv/live/categories?limit=100",invalid,"epg:categories")
    end if
end sub

sub epgRouteChanged()
    if m.mode <> "epg" then return
    route = m.epgGrid.route
    if route = invalid then return
    m.epgSerial++
    m.epgRoute = route
    ' Coalesce obsolete queued category/page changes, retaining active requests.
    pending = []
    for each entry in m.queue
        if left(entry.tag,13) <> "epg:channels:" and left(entry.tag,10) <> "epg:guide:" then pending.push(entry)
    end for
    m.queue = pending
    if m.tasks <> invalid
        for each task in m.tasks
            tag = Txt(task.request.tag)
            if Left(tag,13) = "epg:channels:" or Left(tag,10) = "epg:guide:" then task.cancel = true
        end for
    end if
    filter = Txt(route.filter.id)
    if filter = "__categories_next" or filter = "__categories_previous"
        m.epgCategoryPaging = true
        cursor = m.epgCategoryNext
        if filter = "__categories_previous" then cursor = m.epgCategoryPrevious
        request("GET","/api/v2/iptv/live/categories?limit=100&cursor="+Enc(Txt(cursor)),invalid,"epg:categories")
        return
    end if
    m.epgPending = {}
    path = "/api/v2/iptv/live/channels?limit=40"
    if Txt(route.cursor) <> "" then path += "&cursor="+Enc(route.cursor)
    if filter = "favorites" or filter = "recent"
        path += "&collection="+Enc(filter)
    else if filter <> "all"
        path += "&category_id="+Enc(filter)
    end if
    if Txt(route.search) <> "" then path += "&search="+Enc(route.search)
    request("GET",path,invalid,"epg:channels:"+m.epgSerial.toStr())
end sub

sub epgPump()
    if m.mode <> "epg" or m.epgGrid.visible <> true then return
    for each id in Bounded(m.epgGrid.needed,7)
        if m.epgPending.count() >= 3 then exit for
        if not m.epgPending.doesExist(id)
            m.epgPending[id] = true
            request("GET","/api/v2/iptv/guide/"+Enc(id),invalid,"epg:guide:"+m.epgSerial.toStr()+":"+id)
        end if
    end for
end sub

sub epgResponse(tag as string, result as object)
    if m.mode <> "epg" then return
    if Left(tag,13) = "epg:channels:" and val(Mid(tag,14)) <> m.epgSerial then return
    if result.ok and (tag = "epg:categories" or Left(tag,13) = "epg:channels:")
        current = {catalog_id:result.data.catalog_id,generation:result.data.generation}
        if m.epgSnapshot <> invalid
            if Txt(current.catalog_id) <> Txt(m.epgSnapshot.catalog_id) or Txt(current.generation) <> Txt(m.epgSnapshot.generation)
                result.ok = false
                result.error = "The playlist changed. Return to Live TV to reload it."
            end if
        else
            m.epgSnapshot = current
        end if
    end if
    if tag = "epg:categories"
        if result.ok
            m.epgCategoryNext = result.data.next_cursor
            m.epgCategoryPrevious = result.data.previous_cursor
            categories = result.data.items
            if Txt(m.epgCategoryPrevious) <> "" then categories.push({id:"__categories_previous",name:"Previous categories"})
            if Txt(m.epgCategoryNext) <> "" then categories.push({id:"__categories_next",name:"More categories"})
            m.epgGrid.categories = categories
        else if m.epgCategoryPaging = true or Txt(result.error) = "The playlist changed. Return to Live TV to reload it."
            m.epgGrid.data = {channels:[],offset:m.epgRoute.offset,next_cursor:"",previous_cursor:"",message:Txt(result.error,"Categories couldn't load. Press OK to retry.")}
        end if
        m.epgCategoryPaging = false
    else if left(tag,13) = "epg:channels:"
        if val(mid(tag,14)) <> m.epgSerial then return
        channels = []
        message = "No channels here yet. Choose another filter."
        if Txt(m.epgRoute.search) <> "" then message = "No channels match your search."
        if result.ok
            channels = result.data.items
        else
            message = Txt(result.error,"Channels couldn't load. Press OK to retry, or Left to choose another filter.")
        end if
        nextCursor = "" : previousCursor = ""
        if result.ok
            nextCursor = result.data.next_cursor
            previousCursor = result.data.previous_cursor
            if Txt(nextCursor) = Txt(m.epgRoute.cursor) then nextCursor = ""
            if Txt(previousCursor) = Txt(m.epgRoute.cursor) then previousCursor = ""
        end if
        m.epgGrid.data = {channels:channels,next_cursor:nextCursor,previous_cursor:previousCursor,offset:m.epgRoute.offset,focusEnd:m.epgRoute.focusEnd,message:message}
    else if left(tag,10) = "epg:guide:"
        split = Instr(11,tag,":")
        if split = 0 or val(mid(tag,11,split-11)) <> m.epgSerial then return
        id = mid(tag,split+1)
        m.epgPending.delete(id)
        update = {id:id,ok:result.ok,programs:[]}
        if result.ok then update.append(result.data)
        m.epgGrid.guide = update
    end if
end sub


sub epgWatch()
    if m.mode <> "epg" or m.pendingPlayback then return
    item = m.epgGrid.watch
    if item = invalid or Txt(item.id) = "" then return
    saveView()
    m.epgGrid.visible = false
    m.top.setFocus(true)
    resetAttempts()
    m.playItem = CopyRouteData(item)
    m.playItem.type = "live"
    m.position = 0
    beginPlayback(false)
end sub

sub epgLeave()
    if m.mode <> "epg" then return
    m.sidebar.setFocus(true)
    uiFocusChanged()
end sub

sub epgSearch()
    if m.mode = "epg" then keyboard("epgsearch","Search channels",Txt(m.epgGrid.query))
end sub
