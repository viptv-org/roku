sub initLiveUX()
    m.liveEpgTimer = CreateObject("roSGNode","Timer")
    m.liveEpgTimer.duration = 0.35
    m.liveEpgTimer.repeat = false
    m.top.appendChild(m.liveEpgTimer)
    m.liveEpgTimer.observeField("fire","fetchFocusedLiveEpg")
    m.liveEpgSequence = 0
    m.liveEpgBusy = ""
end sub

function LiveBrowseActions(channels as object, category as string, searchText as string) as object
    ' Filters have a persistent tab row rather than taking channel slots.
    return Bounded(channels,82)
end function

function focusedLiveChannel() as dynamic
    if m.mode <> "browse" and m.mode <> "collection" and m.mode <> "livefavorites" then return invalid
    if m.items = invalid or m.list = invalid then return invalid
    index = m.list.itemFocused
    if index = invalid or index < 0 or index >= m.items.count() then return invalid
    item = m.items[index]
    if Txt(item.type) <> "live" or item.action <> invalid then return invalid
    return item
end function

function openFocusedLiveGuide() as boolean
    item = focusedLiveChannel()
    if item = invalid then return false
    saveView()
    m.selected = item
    cancelBrowse()
    request("GET","/api/guide/" + Enc(Txt(item.id)),invalid,"guide")
    m.status.text = "Loading guide…"
    return true
end function

sub queueLiveEpg(item as object)
    if m.liveEpgTimer = invalid then return
    m.liveEpgPending = {id:Txt(item.id),generation:m.generation}
    m.detailInfo.text = "OK · Watch live" + chr(10) + "Info · Program guide"
    m.description.text = "Loading now / next…"
    m.liveEpgTimer.control = "stop"
    m.liveEpgTimer.control = "start"
end sub

sub fetchFocusedLiveEpg()
    pending = m.liveEpgPending
    if pending = invalid then return
    item = focusedLiveChannel()
    if item = invalid then return
    if pending.generation <> m.generation or pending.id <> Txt(item.id) then return
    if m.playing = true or m.pendingPlayback = true then return
    if m.top <> invalid
        if m.top.dialog <> invalid then return
    end if
    ' At most one focused EPG request per generation, never page-wide prefetch.
    if Txt(m.liveEpgBusy) <> ""
        m.liveEpgTimer.control = "start"
        return
    end if
    if m.queue.count() >= 24
        m.liveEpgTimer.control = "start"
        return
    end if
    m.liveEpgSequence++
    m.liveEpgBusy = "liveepg:" + m.liveEpgSequence.toStr()
    m.liveEpgOwner = pending
    m.liveEpgPending = invalid
    request("GET","/api/guide/" + Enc(pending.id),invalid,m.liveEpgBusy)
end sub

sub liveEpgResponse(tag as string, result as object, generation as integer)
    if tag <> Txt(m.liveEpgBusy) then return
    owner = m.liveEpgOwner
    m.liveEpgBusy = ""
    if generation <> m.generation or owner = invalid then return
    item = focusedLiveChannel()
    if item = invalid then return
    if Txt(item.id) <> owner.id or m.playing = true or m.pendingPlayback = true then return
    if result.ok and result.data <> invalid
        now = CreateObject("roDateTime").asSeconds()
        m.description.text = LiveNowNext(result.data.programs,now)
    else
        m.description.text = "Guide unavailable. OK still starts this channel."
    end if
end sub

function LiveNowNext(programs as dynamic, now as double) as string
    current = invalid
    upcoming = invalid
    for each program in Bounded(programs,96)
        if program.start <> invalid and program.end <> invalid
            if program.start <= now and program.end > now
                if current = invalid
                    current = program
                else if program.start > current.start
                    current = program
                end if
            else if program.start > now
                if upcoming = invalid
                    upcoming = program
                else if program.start < upcoming.start
                    upcoming = program
                end if
            end if
        end if
    end for
    text = "NOW · No program information"
    if current <> invalid then text = "NOW · " + left(CleanSourceLabel(Txt(current.title),false),100)
    text += chr(10) + chr(10) + "NEXT · No program information"
    if upcoming <> invalid
        dt = CreateObject("roDateTime")
        dt.fromSeconds(upcoming.start)
        dt.toLocalTime()
        first = text.split(chr(10))[0]
        displayTime = dt.asTimeStringLoc("short")
        if Txt(upcoming.display_time) <> "" then displayTime = Txt(upcoming.display_time)
        text = first + chr(10) + chr(10) + "NEXT · " + displayTime + " · " + left(CleanSourceLabel(Txt(upcoming.title),false),100)
    end if
    return text
end function

sub liveCategories(offset as integer)
    cancelBrowse()
    if offset < 0 then offset = 0
    m.categoryOffset = offset
    m.mediaType = "live"
    rows("Categories",[{name:"Loading categories…",action:"waiting"}],"livecategories","")
    request("GET","/api/live/categories?limit=80&offset=" + offset.toStr(),invalid,"livecategories")
end sub
