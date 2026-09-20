sub prepExpired()
    cancelBrowse()
    if m.playing then stopPlayback(false)
    m.prepSpent = 180000
    sourceExhausted("Playback preparation timed out.")
end sub

sub resetAttempts()
    m.refreshingSources = false
    m.refreshClock = invalid
    m.activeSourceAt = invalid
    m.attempted = {}
    m.retiredSources = {}
    m.hasPlayed = false
    m.prepSpent = 0
    m.codecRetryUsed = false
    m.directRetryUsed = false
    m.liveRetunes = 0
end sub

sub refreshSourceIds(newEpoch = true as boolean)
    if m.refreshingSources = true then return
    cancelBrowse()
    m.refreshingSources = true
    retired = {}
    if m.attempted <> invalid then retired.append(m.attempted)
    if m.retiredSources <> invalid
        for each id in m.retiredSources
            if retired.count() < 6 then retired[id] = true
        end for
    end if
    m.retiredSources = retired
    if newEpoch
        m.attempted = {}
        m.prepSpent = 0
        m.codecRetryUsed = false
    m.directRetryUsed = false
    else
        m.refreshClock = CreateObject("roTimespan")
        m.refreshClock.mark()
        if m.budgetTimer <> invalid
            m.budgetTimer.duration = (180000-m.prepSpent)/1000.0
            m.budgetTimer.control = "start"
        end if
    end if
    m.prepClock = invalid
    m.sourcesAt = invalid
    m.streams = []
    m.discoveryDone = false
    m.manualSources = true
    m.resumeSourcePreference = invalid
    m.pausedVOD = false
    m.playItem.position = m.position
    m.playItem.duration = m.duration
    body = {id:m.playItem.id,type:m.playItem.type,name:Txt(m.playItem.seriesName,m.playItem.name)}
    body.append(StreamContext(m.playItem))
    request("POST","/api/streams",body,"streamstart")
    if m.heading <> invalid
        rows("Choose a source",[],"streams","",false)
        uiSourceHeader()
    else
        m.mode = "preparing"
    end if
end sub

' Preserve addon discovery order exactly. The picker never ranks, autoplays, or
' silently promotes a stream; duplicate opaque IDs are ignored and memory is bounded.
function AppendDistinctSources(existing as object, incoming as object, limit as integer) as object
    output = []
    seen = {}
    for each source in existing
        id = Txt(source.id)
        if id <> "" and not seen.doesExist(id) and output.count() < limit
            output.push(source)
            seen[id] = true
        end if
    end for
    for each source in incoming
        id = Txt(source.id)
        if id <> "" and not seen.doesExist(id) and output.count() < limit
            output.push(source)
            seen[id] = true
        end if
    end for
    return output
end function

sub tryResumeSource()
    if m.mode <> "resuming" or m.manualSources = true or m.pendingPlayback = true or m.playing = true then return
    if m.resumeSourcePreference = invalid then return
    if m.resumeSourcePreference.continuation = true
        iptv = left(Txt(m.resumeSourcePreference.source_addon_id),5) = "iptv:"
        if not iptv and not m.discoveryDone then return
        source = BestContinuationSource(m.streams,m.resumeSourcePreference,m.config.capabilities,m.sourcePreferences)
        if source <> invalid
            m.resumeSourcePreference = invalid
            playSource(source)
            return
        end if
    else
    for each source in m.streams
        if SourceMatchesPreference(source,m.resumeSourcePreference)
            ' Consume the intent before starting; late discovery cannot replay it.
            m.resumeSourcePreference = invalid
            playSource(source)
            return
        end if
    end for
    end if
    if m.discoveryDone
        m.resumeSourcePreference = invalid
        m.manualSources = true
        uiBusy(false)
        rows("Choose a source",m.streams,"streams","")
        uiSourceHeader()
    end if
end sub

sub playSource(item as object)
    if m.pendingPlayback = true then return
    if m.attempted = invalid then resetAttempts()
    id = Txt(item.id)
    if id = "" or m.attempted.doesExist(id) or m.attempted.count() >= 3
        sourceExhausted("Try another source.")
        return
    end if
    if m.manualSources = true and m.mode = "streams" then saveView()
    m.attempted[id] = true
    preference = StableSourcePreference(item)
    for each key in ["source_addon_id","source_name","source_fingerprint","source_binge_group","source_release_group","source_quality","source_audio"]
        m.playItem.delete(key)
    end for
    m.playItem.append(preference)
    if m.manualSources = true then m.playItem.delete("audio_language")
    quality = ContinuationQuality(item)
    if quality <> "" then m.playItem.source_quality = quality
    m.playItem.source_audio = ContinuationAudio(item)
    ' Explicit source selection restores a hidden title; periodic progress never does.
    body = {id:m.playItem.id,type:m.playItem.type,hidden:false}
    body.append(StreamContext(m.playItem))
    if m.automaticContinuation <> true then request("PUT",continuationPath("visibility"),body,"siderestorequeue")
    m.playItem.stream_id = id
    m.activeSourceAt = item.sourceEpoch
    if m.activeSourceAt = invalid then m.activeSourceAt = m.sourcesAt
    beginPlayback(false)
end sub

sub sourceExhausted(reason as string)
    uiBusy(false)
    if m.captionRestore <> invalid
        m.video.globalCaptionMode = m.captionRestore
        m.captionRestore = invalid
    end if
    m.poll.control = "stop"
    if m.budgetTimer <> invalid then m.budgetTimer.control = "stop"
    m.status.text = reason
    if m.heading <> invalid
        actions = [{name:"Try again",action:"retryplay"}]
        if m.playItem.type <> "live" then actions.push({name:"Choose another source",action:"retrysources"})
        takeFocus = true
        if m.sidebar <> invalid
            if m.sidebar.hasFocus() then takeFocus = false
        end if
        if m.top.dialog <> invalid then takeFocus = false
        rows(Txt(m.playItem.name),actions,"sourceerror",reason,takeFocus)
    end if
end sub

function sameMedia(a as dynamic, b as dynamic) as boolean
    if GetInterface(a,"ifAssociativeArray") = invalid or GetInterface(b,"ifAssociativeArray") = invalid then return false
    return Txt(a.id) <> "" and Txt(a.id) = Txt(b.id) and Txt(a.type) = Txt(b.type) and Txt(a.series_id) = Txt(b.series_id) and Txt(a.season) = Txt(b.season) and Txt(a.episode) = Txt(b.episode)
end function

function sourceViewState() as object
    state = {base:m.config.base,access_token:Txt(m.config.access_token),account_id:Txt(m.config.account_id),account_epoch:m.accountEpoch,last_profile_id:m.profile,playItem:m.playItem,streams:Bounded(m.streams,320),sourcesAt:m.sourcesAt,position:m.position,duration:m.duration,job:m.job,cursor:m.cursor,pollCount:m.pollCount,discoveryDone:m.discoveryDone}
    ' Only bounded plain data: no SG nodes, tasks, timers, or mutable references.
    return CopyRouteData(state)
end function

function restoreSourceView(saved as object) as boolean
    state = saved.sourceState
    if state = invalid then return false
    if state.base <> m.config.base or Txt(state.access_token) <> Txt(m.config.access_token) or Txt(state.account_id) <> Txt(m.config.account_id) or state.account_epoch <> m.accountEpoch or Txt(state.last_profile_id) <> Txt(m.profile) then return false
    state = CopyRouteData(state)
    ' Returning from this very playback keeps its latest real position; another
    ' movie/episode cannot overwrite the saved source route's resume position.
    if sameMedia(m.playItem,state.playItem)
        state.position = m.position
        state.duration = m.duration
        state.playItem.append(StableSourcePreference(m.playItem))
    end if
    cancelBrowse()
    resetAttempts()
    for each key in ["playItem","streams","sourcesAt","position","duration","job","cursor","pollCount","discoveryDone"]
        m[key] = state[key]
    end for
    m.playItem.position = m.position
    m.playItem.duration = m.duration
    m.manualSources = true
    m.refreshingSources = false
    m.pausedVOD = false
    return true
end function
sub saveView()
    if m.views = invalid then m.views = []
    if m.mode = invalid or m.mode = "preparing" or m.mode = "resuming" or m.mode = "sourceerror" then return
    snapshot = {mode:m.mode,items:m.items,selected:m.selected,mediaType:m.mediaType,catalog:m.catalog,search:m.search,offset:m.offset,nextOffset:m.nextOffset,offsetHistory:m.offsetHistory,collection:m.collection,episodes:m.episodes,episodeOffset:m.episodeOffset,position:m.homePosition,index:m.list.itemFocused,liveCategory:m.liveCategory,liveCategoryName:m.liveCategoryName,categoryOffset:m.categoryOffset,pageCount:m.pageCount,discoverActive:m.discoverActive,discoverType:m.discoverType,discoverGenre:m.discoverGenre,discoverExtras:CopyRouteData(m.discoverExtras),discoverCatalogs:m.discoverCatalogs,episodeSeason:m.episodeSeason,homeExpanded:m.homeExpanded,homeActionIndex:m.homeActions.itemFocused,queueOffset:m.queueOffset,libraryOffset:m.libraryOffset}
    if m.mode = "searchall"
        snapshot.searchState = {sections:CopyRouteData(Bounded(m.searchSections,128)),errors:m.searchErrors,index:m.searchPanel.position,scope:m.searchScope,catalog:m.searchCatalog}
    end if
    if m.mode = "streams"
        snapshot.sourceState = sourceViewState()
        snapshot.items = CopyRouteData(Bounded(m.items,80))
    end if
    if m.mode <> "episodes" then snapshot.episodes = invalid
    if m.mode <> "episodes" and m.mode <> "detail" and m.mode <> "guide" then snapshot.selected = invalid
    if m.mode = "home" then snapshot.items = []
    if m.heading <> invalid then snapshot.heading = m.heading.text
    if m.views.count() > 0
        last = m.views[m.views.count()-1]
        sameSource = true
        if snapshot.mode = "streams"
            sameSource = false
            if last.sourceState <> invalid
                sameSource = sameMedia(last.sourceState.playItem,snapshot.sourceState.playItem)
            end if
        end if
        if sameSource and last.mode = snapshot.mode and last.index = snapshot.index and Txt(last.search) = Txt(snapshot.search) and last.offset = snapshot.offset
            ' Replace with a fresh immutable snapshot, rather than keeping an old cursor epoch.
            m.views[m.views.count()-1] = snapshot
            return
        end if
    end if
    if m.views.count() >= 6 then m.views.shift()
    m.views.push(snapshot)
end sub

sub restoreView()
    if m.views = invalid
        m.list.setFocus(true)
        return
    end if
    if m.views.count() = 0
        home()
        return
    end if
    saved = m.views.pop()
    if saved.mode = "epg"
        openEpg(true)
        return
    end if
    if saved.mode = "streams"
        if not restoreSourceView(saved)
            m.views = []
            home()
            return
        end if
    end if
    for each key in ["selected","mediaType","catalog","search","offset","nextOffset","offsetHistory","collection","episodes","episodeOffset","liveCategory","liveCategoryName","categoryOffset","pageCount","discoverActive","discoverType","discoverGenre","discoverExtras","discoverCatalogs","episodeSeason","queueOffset","libraryOffset"]
        m[key] = saved[key]
    end for
    if saved.mode = "episodes" and Txt(m.profile) <> ""
        rows(Txt(m.selected.name),[],"loading","")
        request("GET","/api/profiles/" + Enc(m.profile) + "/progress/series?series_id=" + Enc(Txt(m.selected.id)),invalid,"episodeprogress")
        return
    end if
    if saved.mode = "searchall"
        searchRestore(saved.searchState)
        return
    end if
    if saved.mode = "home"
        m.homePosition = saved.position
        m.homeExpanded = saved.homeExpanded
        if saved.homeActionIndex <> invalid then m.homeActions.jumpToItem = saved.homeActionIndex
        home()
    else
        if m.discoverActive = true and saved.mode = "browse" then discoverBuildFilters()
        limit = 480
        if saved.mode = "episodes" then limit = 2000
        rows(Txt(saved.heading),Bounded(saved.items,limit),saved.mode,"")
        if saved.mode = "streams"
            uiSourceHeader()
            if m.discoveryDone <> true then m.poll.control = "start"
        end if
        if saved.index <> invalid
            index = RestoreCardIndex(saved.index,m.items.count())
            m.listRestoreIndex = index
            m.listUpdating = true
            if m.items.count() > 0 then m.list.jumpToItem = index
            if m.listFocusTimer <> invalid then m.listFocusTimer.control = "start"
        end if
        if saved.mode = "detail" or saved.mode = "episodes" or saved.mode = "guide"
            if m.selected <> invalid then showDetail(m.selected)
        end if
        if saved.mode = "collection" and m.homeDirty = true
            if m.collection = "progress"
                openViewingQueue(m.queueOffset)
            else if m.collection = "favorites"
                openLibraryPage(m.libraryOffset)
            else
                request("GET",ProfileCollectionPath(m.profile,m.collection),invalid,"collection")
            end if
        end if
    end if
end sub
