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
        m.epgGrid.callFunc("open",m.accountEpoch.toStr()+":"+m.profile)
        if collection <> "" then m.epgGrid.callFunc("chooseFilter",collection)
        request("GET","/api/live/categories?view=us&offset=0&limit=100",invalid,"epg:categories")
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
        if left(entry.tag,13) <> "epg:channels:" then pending.push(entry)
    end for
    m.queue = pending
    filter = Txt(route.filter.id)
    path = "/api/live?view=us&limit=40&offset="+route.offset.toStr()
    if filter = "favorites" or filter = "recent"
        path += "&collection="+Enc(filter)
    else if filter <> "all"
        path += "&category="+Enc(filter)
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
            request("GET","/api/guide/"+Enc(id),invalid,"epg:guide:"+id)
        end if
    end for
end sub

sub epgResponse(tag as string, result as object)
    if m.mode <> "epg" then return
    if tag = "epg:categories"
        if result.ok then m.epgGrid.categories = result.data.categories
    else if left(tag,13) = "epg:channels:"
        if val(mid(tag,14)) <> m.epgSerial then return
        channels = []
        total = 0
        message = "No channels here yet. Choose another filter."
        if Txt(m.epgRoute.search) <> "" then message = "No matching US channels or current programmes. Try a channel name, section, or another title."
        if result.ok
            channels = result.data.channels
            total = result.data.total
        else
            message = "Channels couldn't load. Press OK to retry, or Left to choose another filter."
        end if
        m.epgGrid.data = {channels:channels,total:total,offset:m.epgRoute.offset,focusEnd:m.epgRoute.focusEnd,message:message}
    else if left(tag,10) = "epg:guide:"
        id = mid(tag,11)
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
    if m.mode = "epg" then keyboard("epgsearch","Search Live TV",Txt(m.epgGrid.query))
end sub
