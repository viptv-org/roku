sub initContinuation()
    m.nextResult = invalid
    m.nextOwner = ""
    m.continuationWaiting = false
    m.homeRows.observeField("activation","queueActivation")
    m.posterGrid.observeField("activation","queueActivation")
end sub

function continuationPath(suffix as string) as string
    return "/api/profiles/"+Enc(m.profile)+"/continue/"+suffix
end function

sub prefetchContinuation()
    if m.playItem.type <> "series" or m.playbackLive = true then return
    m.nextResult = invalid
    m.nextOwner = Txt(m.playItem.id)
    m.nextScope = m.profile
    body = {id:m.playItem.id,type:"series",name:Txt(m.playItem.seriesName,m.playItem.name),poster:Txt(m.playItem.poster)}
    body.append(StreamContext(m.playItem))
    body.append(StableSourcePreference(m.playItem))
    request("POST",continuationPath("next"),body,"continuationprefetch")
end sub

function continuationResponse(tag as string, result as object) as boolean
    if tag = "continuationprefetch" or tag = "continuationresolve"
        if m.nextScope <> m.profile or m.nextOwner <> Txt(m.playItem.id) then return true
        m.nextResult = {status:"unavailable"}
        if result.ok then m.nextResult = result.data
        if tag = "continuationresolve" and m.continuationWaiting = true then continuationOffer()
        return true
    end if
    if tag = "queuepage"
        if not result.ok
            rows("Continue Watching",[{name:"Try again",action:"queuepage",offset:m.queueOffset}],"collection",Txt(result.error))
            return true
        end if
        items = result.data.items
        if result.data.offset > 0 then items.unshift({name:"Previous page",action:"queuepage",offset:result.data.offset-40})
        if result.data.next_offset <> invalid then items.push({name:"Next page",action:"queuepage",offset:result.data.next_offset})
        rows("Continue Watching",items,"collection","Hold OK or press * to manage a title")
        if m.queueRestoreIndex <> invalid
            m.list.jumpToItem = RestoreCardIndex(m.queueRestoreIndex,items.count())
            m.queueRestoreIndex = invalid
        end if
        return true
    end if
    if tag = "queuevisibility"
        if result.ok
            m.homeDirty = true
            if m.mode = "collection" and m.collection = "progress" then openViewingQueue(m.queueOffset) else home()
            if m.queueHidden = true
                uiOpenChoice("queueUndo","Removed from Continue Watching",[{name:"Undo",action:"queueundo"},{name:"Done",action:"cancel"}])
            end if
        else
            m.status.text = "Could not update Continue Watching. Try again."
        end if
        return true
    end if
    return false
end function

sub continuationBegin(automatic as boolean)
    if m.playItem = invalid or m.playItem.type <> "series" or m.playbackLive = true then return
    m.continuationAutomatic = automatic
    m.continuationPreference = StableSourcePreference(m.playItem)
    m.continuationWaiting = true
    current = CopyRouteData(m.playItem)
    ' Keep the outgoing frame on screen and let the player overlay carry a LOADING
    ' cue instead of tearing down to Home behind a full-screen spinner. The
    ' outgoing session is retired when the replacement is accepted (acceptPlayback).
    saveProgress()
    m.nextTransitionSession = m.session
    m.nextTransitionConnection = m.sessionConnection
    m.session = ""
    m.playing = false
    m.pausedVOD = true
    if m.video <> invalid then m.video.control = "pause"
    m.nextPrepping = true
    if m.playerOverlay <> invalid
        m.playerOverlay.visible = true
        m.playerOverlay.opened = true
    end if
    m.playItem = current
    updatePlayer()
    if m.nextOwner = Txt(m.playItem.id) and m.nextScope = m.profile and m.nextResult <> invalid
        continuationOffer()
    else
        m.status.text = "Finding the next episode…"
        m.nextOwner = Txt(m.playItem.id)
        m.nextScope = m.profile
        body = {id:m.playItem.id,type:"series",name:Txt(m.playItem.seriesName,m.playItem.name),poster:Txt(m.playItem.poster)}
        body.append(StreamContext(m.playItem))
        request("POST",continuationPath("next"),body,"continuationresolve")
    end if
end sub

sub resumeNextTransition()
    ' No next episode, or the user backed out: resume the outgoing session in place.
    if m.nextPrepping <> true then return
    m.nextPrepping = false
    m.session = m.nextTransitionSession
    m.sessionConnection = m.nextTransitionConnection
    m.nextTransitionSession = ""
    m.nextTransitionConnection = invalid
    m.playing = true
    m.pausedVOD = false
    if m.video <> invalid then m.video.control = "resume"
    updatePlayer()
end sub

sub continuationOffer()
    m.continuationWaiting = false
    if m.nextResult.status <> "next"
        resumeNextTransition()
        message = "Episode information is unavailable. Open the series to choose an episode."
        if m.nextResult.status = "caught_up" then message = "You're caught up. No next episode is listed yet."
        if m.nextResult.status = "upcoming" then message = "The next episode hasn't been released yet."
        uiOpenChoice("continuationUnavailable",message,[{name:"Open series",action:"continuationdetails"},{name:"Done",action:"cancel"}])
        return
    end if
    m.continuationItem = m.nextResult.item
    m.continuationItem.append(m.continuationPreference)
    continuationPlay()

end sub

sub continuationDialogSelected(event as object)
    if event.getData() = 0
        continuationPlay()
    else
        m.top.dialog.close = true
        m.top.dialog = invalid
    end if
end sub
sub continuationPlay()
    if m.top.dialog <> invalid
        m.top.dialog.close = true
        m.top.dialog = invalid
    end if
    if m.nextScope <> m.profile or m.continuationItem = invalid then return
    item = CopyRouteData(m.continuationItem)
    preference = StableSourcePreference(item)
    preference.continuation = true
    findStreams(item,false,preference,true)
end sub

function selectQueueItem(item as object) as boolean
    if Txt(item.queue_status) = "" then return false
    if item.queue_status = "next"
        findStreams(item,true)
    else
        m.playItem = CopyRouteData(item)
        m.playbackLive = false
        m.nextResult = invalid
        continuationBegin(false)
    end if
    return true
end function
sub openViewingQueue(offset = 0 as integer)
    cancelBrowse()
    m.collection = "progress"
    m.queueOffset = offset
    if m.queueOffset < 0 then m.queueOffset = 0
    rows("Continue Watching",[],"collection","Loading…")
    request("GET",continuationPath("page")+"?limit=40&offset="+m.queueOffset.toStr(),invalid,"queuepage")
end sub

sub queueActivation(event as object)
    data = event.getData()
    if data.held = true
        if libraryMenu() then return
        if queueMenu() then return
    end if
    if m.mode = "home"
        item = homeCurrent()
        if item <> invalid then selectItem(item)
    else
        index = m.posterGrid.itemFocused
        if index >= 0 and index < m.items.count() then selectItem(m.items[index])
    end if
end sub
function queueMenu() as boolean
    item = invalid
    if m.mode = "home" and (m.homeRows.hasFocus() or m.homeActions.hasFocus()) and m.homePosition[0] = 0 then item = homeCurrent()
    if m.mode = "collection" and m.collection = "progress" and m.list.hasFocus()
        index = m.list.itemFocused
        if index >= 0 and index < m.items.count() then item = m.items[index]
    end if
    if item = invalid then return false
    if item.action <> invalid or item.type = "live" then return false
    m.queueItem = CopyRouteData(item)
    choices = []
    resume = item
    if item.previous_episode <> invalid then resume = item.previous_episode
    if resume.position <> invalid and resume.position > 0 then choices.push({name:"Resume",action:"queueresume"})
    choices.push({name:"Choose source",action:"queuesources"})
    choices.push({name:"Remove from Continue Watching",action:"queueremove"})
    choices.push({name:"Cancel",action:"cancel"})
    uiOpenChoice("queueManage",Txt(item.name),choices)
    return true
end function
sub queueVisibility(hidden as boolean)
    m.homeDirty = true
    if m.mode = "collection" then m.queueRestoreIndex = m.list.itemFocused
    m.queueHidden = hidden
    body = {id:m.queueItem.id,type:m.queueItem.type,hidden:hidden}
    body.append(StreamContext(m.queueItem))
    request("PUT",continuationPath("visibility"),body,"queuevisibility")
end sub

function retryContinuationSource() as boolean
    if m.continuationSourcePreference = invalid or m.pendingPlayback = true then return false
    if m.attempted = invalid or m.attempted.count() >= 3 then return false
    if m.prepSpent >= 180000 or SourceIdsExpired(m.sourcesAt,CreateObject("roDateTime").asSeconds()) then return false
    candidates = []
    for each source in m.streams
        if not m.attempted.doesExist(Txt(source.id)) then candidates.push(source)
    end for
    source = BestContinuationSource(candidates,m.continuationSourcePreference,m.config.capabilities,m.sourcePreferences)
    if source = invalid then return false
    playSource(source)
    return true
end function
