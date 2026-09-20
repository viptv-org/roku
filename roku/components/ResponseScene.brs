sub response(event as object)
    previous = m.acknowledgementRendering
    m.acknowledgementRendering = true
    handleResponse(event)
    m.acknowledgementRendering = previous
end sub

sub handleResponse(event as object)
    result = event.getData()
    origin = event.getRoSGNode().request
    parts = result.tag.split("|")
    tag = parts[0]
    ' Mutation acknowledgements reconcile profile shelves even after UI cancellation.
    if tag = "sideprogress" or tag = "favorited" or tag = "queuevisibility" or tag = "siderestorequeue" or tag = "librarycorrected" then homeMutation(origin,true)
    if tag = "playback" or tag = "seekplayback"
        if origin.request_id = invalid or origin.request_id = m.pendingRequestId
            m.pendingPlayback = false
            m.pendingStartupId = ""
        end if
        if val(parts[1]) = m.generation and m.prepClock <> invalid and m.prepSpent <> invalid
            m.prepSpent += m.prepClock.totalMilliseconds()
            m.prepClock.mark()
        end if
    end if
    if (tag = "playback" or tag = "seekplayback") and val(parts[1]) <> m.generation
        if result.ok and result.data <> invalid
            request("DELETE", "/api/playback/" + Enc(Txt(result.data.id)), invalid, "cleanup", origin)
        end if
        return
    end if
    if tag = "sideconfig" and not result.ok then m.status.text = "Settings could not be saved: " + Txt(result.error)
    if tag = "sideconfig" or tag = "cleanup" then return
    ' Account responses validate account_epoch before changing any profile/UI state.
    if accountResponse(tag,result,origin) then return
    if origin.account_epoch <> m.accountEpoch then return
    if result.status = 403 and (result.auth_code = "profile_required" or result.auth_code = "profile_policy_changed")
        stopPlayback()
        accountClearRememberedProfile()
        m.profile = ""
        m.cache = {}
        m.cacheKeys = []
        m.homeData = invalid
        m.homeRoot = invalid
        m.views = []
        accountOpenProfiles()
        return
    end if
    if m.accountMode = true and (result.status = 401 or result.auth_code = "device_revoked" or result.auth_code = "revoked")
        if Txt(origin.access_token) <> Txt(m.config.access_token) then return
        if result.auth_code = "device_revoked" or result.auth_code = "revoked" or Txt(m.config.refresh_token) = ""
            accountRevoked()
        else
            accountRefresh()
            m.status.text = "Refreshing sign-in. Retry your action shortly."
        end if
        return
    end if
    if tag = "sideheartbeat" or tag = "sideliverecover"
        if val(parts[1]) = m.generation then managedLiveResponse(result,origin)
        return
    end if
    if left(tag,4) = "side" then return
    if left(tag,8) = "liveepg:"
        liveEpgResponse(tag,result,val(parts[1]))
        return
    end if
    if val(parts[1]) <> m.generation then return
    if left(tag,4) = "epg:"
        epgResponse(tag,result)
        return
    end if
    if left(tag,18) = "sourcepreferences:"
        if result.ok and tag = "sourcepreferences:"+m.profile
            m.sourcePreferences = result.data
            if m.mode = "streams" and m.playing <> true then uiUpdateSources(m.streams,false)
        end if
        return
    end if
    if tag = "profilepreferences"
        if m.preferencesScope <> m.profile then return
        if result.ok
            showPlaybackPreferences(result.data)
        else
            rows("Playback preferences",[{name:"Try again",action:"playbackpreferences"}],"preferences",Txt(result.error))
        end if
        return
    end if
    if continuationResponse(tag,result) then return
    if libraryResponse(tag,result) then return
    if tag = "episodeprogress"
        applyEpisodeProgress(result)
        return
    end if
    if left(tag,11) = "startupArt:"
        startupArtworkResponse(tag,result)
        return
    end if
    if left(tag,7) = "uicard:"
        uiCardArtworkResponse(tag,result)
        return
    end if
    if left(tag,7) = "uihero:"
        uiHeroArtResponse(tag,result)
        return
    end if
    if left(tag,5) = "home:"
        homeParts = tag.split(":")
        if homeParts.count() > 2
            revisionKind = homeParts[1]
            if revisionKind = "recent" then revisionKind = "progress"
            if revisionKind = "livefavorites" then revisionKind = "favorites"
            if val(homeParts[2]) <> homeRevision(revisionKind) then return
        end if
        homeResponse(homeParts[1],result)
        return
    end if
    if tag = "accountaddons" or tag = "addonchanged"
        addonResponse(tag,result)
        return
    end if
    if tag = "searchcatalogs"
        searchCatalogs(result)
        return
    end if
    if left(tag,10) = "searchall:"
        searchBatch(mid(tag,11),result)
        return
    end if
    if tag = "favorited" then m.favoriteBusy = false
    if not result.ok
        if tag = "config" then showSettings()
        m.status.text = Txt(result.error,"Unable to reach server. Check Settings and try again.")
        if tag = "discovercatalogs"
            rows("Discover",[{name:"Try again",action:"discover"}],"discovererror","Catalogs are unavailable. Check your addons or try again.")
        end if
        if tag = "streamstart" or tag = "streampoll"
            m.discoveryDone = true
            sourceExhausted("Sources unavailable. Try again.")
        end if
        if tag = "seekplayback"
            seekReplacementFailed("Seek failed. Playback resumed at the prior position.")
        else if tag = "playback"
            ' Family channels exhaust verified server candidates under one startup budget.
            print "VIPTV playback request failed: "; result.status; " "; Txt(result.error)
            if m.playItem.type = "live"
                sourceExhausted(Txt(result.error,"No working stream is available for this channel. Try again later."))
            else
                if retryContinuationSource() then return
                sourceExhausted("Selected source unavailable (" + Txt(result.error,"request failed") + "). Choose another source.")
            end if
        end if
        return
    end if
    data = result.data
    if tag = "seekplayback"
        prepareSeekReplacement(data,origin)
        return
    end if
    if tag = "config"
        m.config = data
        m.configLoaded = true
        ' A remembered ID is only a hint; accountConnect validates and selects it.
        m.profile = ""
        if data.base <> ""
            accountConnect()
        else
            showSettings()
        end if
    else if tag = "profiles"
        accountUseProfiles(Bounded(data,99))
    else if tag = "newprofile"
        request("GET", "/api/profiles", invalid, "profiles")
    else if tag = "discovercatalogs"
        discoverUseCatalogs(data)
    else if tag = "catalogs"
        values = []
        for each item in Bounded(data,100)
            if DiscoverTypeMatches(Txt(item.type),m.mediaType) then values.push(item)
        end for
        rows("Explore " + DiscoverTypeName(Txt(m.mediaType)),values,"catalogs","Catalogs from your configured metadata addons.")
    else if tag = "livecategories"
        values = [{name:"All channels",action:"allchannels"},{name:"Search channels",action:"livesearch"}]
        for each category in Bounded(data.categories,80)
            category.displayName = Txt(category.name)
            if category.count <> invalid then category.displayName += "  ·  " + Txt(category.count)
            values.push(category)
        end for
        if m.categoryOffset + 80 < data.total then values.push({name:"More categories",action:"livecategoriesnext"})
        if m.categoryOffset > 0 then values.push({name:"Previous categories",action:"livecategoriesprevious"})
        rows("Live TV",values,"livecategories","")
    else if tag = "browse"
        if m.mediaType = "live" then values = Bounded(data.channels,80) else values = Bounded(data.metas,200)
        m.pageCount = values.count()
        for each item in values
            if m.mediaType = "live" then item.type = "live"
        end for
        m.nextOffset = invalid
        hasNext = false
        if m.mediaType = "live"
            hasNext = m.offset + m.pageCount < data.total
            if hasNext then m.nextOffset = m.offset + m.pageCount
        else if data.has_more = true and data.next_skip <> invalid
            if data.next_skip > m.offset
                hasNext = true
                m.nextOffset = data.next_skip
            end if
        end if
        if hasNext then values.push({name:"Next page →",action:"next"})
        if m.offsetHistory <> invalid
            if m.offsetHistory.count() > 0 then values.push({name:"← Previous page",action:"previous"})
        end if
        title = "Explore " + m.mediaType
        subtitle = "Page " + (int(m.offset / 80)+1).toStr()
        if m.discoverActive = true and m.mediaType <> "live"
            title = "Discover · " + DiscoverTypeName(m.mediaType)
            subtitle = "Page " + (m.offsetHistory.count()+1).toStr()
            if m.catalog <> invalid then subtitle += " · " + Txt(m.catalog.name,Txt(m.catalog.id))
            if Txt(m.discoverGenre) <> "" then subtitle += " · " + Txt(m.discoverGenre)
            discoverBuildFilters()
        end if
        if m.mediaType = "live"
            title = Txt(m.liveCategoryName,"Live TV")
            subtitle = Txt(data.total) + " channels · OK Watch · Info Guide"
            values = LiveBrowseActions(values,Txt(m.liveCategory),Txt(m.search))
        end if
        rows(title,values,"browse",subtitle)
        if m.mediaType = "live" and m.pageCount > 0 then m.list.jumpToItem = 0
    else if tag = "livefavorites" or tag = "livefavoritescache"
        m.liveFavoriteItems = Bounded(data,500)
        if tag = "livefavorites"
            values = []
            for each item in m.liveFavoriteItems
                if Txt(item.type) = "live" then values.push(item)
            end for
            rows("Live TV",values,"livefavorites","",m.mode <> "livefavorites")
        else if m.mode = "browse" and m.mediaType = "live"
            rows("Live TV",m.items,"browse","",false)
        end if
    else if tag = "collection"
        title = "My List"
        if m.collection = "progress"
            title = "Continue Watching"
            data = ContinueWatchingItems(data)
        else if m.collection = "recentlive"
            title = "Recently Watched Live TV"
            data = LiveOnlyItems(data)
        end if
        rows(title,Bounded(data,100),"collection","",m.mode <> "collection")
    else if tag = "meta"
        if m.cacheKeys.count() >= 4
            m.cache.delete(m.cacheKeys.shift())
        end if
        m.cacheKeys.push(m.metaPath)
        m.cache[m.metaPath] = {time:CreateObject("roDateTime").asSeconds(),data:data}
        showMetadata(data)
    else if tag = "guide"
        values = [{name:"Watch live",action:"watchlive"},{name:favoriteLabel(m.selected),action:"favorite"}]
        for each program in Bounded(data.programs,96)
            dt = CreateObject("roDateTime")
            dt.fromSeconds(program.start)
            dt.toLocalTime()
            when = dt.asTimeStringLoc("short")
            if Txt(program.display_time) <> "" then when = Txt(program.display_time)
            displayDate = dt.asDateString("short-date")
            if Txt(program.display_date) <> "" then displayDate = Txt(program.display_date)
            now = CreateObject("roDateTime").asSeconds()
            if program.end <> invalid
                if program.start <= now and program.end > now then when = "NOW · " + when
            end if
            values.push({name:when + "  " + CleanSourceLabel(Txt(program.title),false),description:CleanSourceLabel(Txt(program.description),false),releaseInfo:displayDate,type:"program"})
        end for
        guideZone = "Times are local"
        if Txt(data.timezone) <> "" then guideZone = "Times: " + Txt(data.timezone)
        rows(m.selected.name,values,"guide",guideZone)
        showDetail(m.selected)
        if values.count() = 2 then m.description.text = "No guide data supplied for this channel."
    else if tag = "favorited"
        if result.data.saved <> invalid
            m.favoriteMessage = "Removed from favorites."
            if result.data.saved then m.favoriteMessage = "Added to favorites."
        end if
        uiFavoriteAcknowledged()
        m.homeDirty = true
        if m.mode = "detail" or m.mode = "episodes" or m.mode = "guide"
            for each action in m.items
                if action.action = "favorite"
                    action.name = favoriteLabel(m.selected)
                end if
            end for
            rows(m.heading.text,m.items,m.mode,"",false)
            showDetail(m.selected)
        end if
        m.status.text = m.favoriteMessage
        if m.mode = "collection" and m.collection = "favorites" then openLibraryPage(m.libraryOffset)
        if m.mode = "livefavorites" then openEpg(false,"favorites")
        if m.mode = "browse" and m.mediaType = "live" then rows("Live TV",m.items,"browse","",false)
    else if tag = "streamstart"
        m.sourcesAt = CreateObject("roDateTime").asSeconds()
        m.refreshingSources = false
        m.job = Txt(data.id)
        m.cursor = 0
        m.pollCount = 0
        m.streams = []
        m.discoveryDone = false
        pollStreams()
    else if tag = "streampoll"
        for each entry in Bounded(data.events,100)
            if entry.seq > m.cursor then m.cursor = entry.seq
            m.streams = AppendDistinctSources(m.streams,Bounded(entry.streams,1000),320)
        end for
        m.discoveryDone = data.done or m.pollCount >= 80
        if m.mode = "streams" and not m.playing
            values = []
            for each stream in m.streams
                item = {}
                item.append(stream)
                item.sourceEpoch = m.sourcesAt
                values.push(item)
            end for
            rows("Choose a source",values,"streams","",false)
            uiSourceHeader()
        end if
        if not m.discoveryDone then m.poll.control = "start"
        if not m.manualSources then tryResumeSource()
        if m.discoveryDone and m.streams.count() = 0 then sourceExhausted("No sources available.")
    else if tag = "playback"
        acceptPlayback(data,origin)
    end if
end sub
sub showMetadata(data as object)
    if data.meta = invalid
        m.status.text = "Metadata unavailable. Back to browse."
        return
    end if
    meta = {}
    meta.append(data.meta)
    if m.selected <> invalid
        if Txt(m.selected.id) = Txt(meta.id)
            if m.selected.position <> invalid then meta.position = m.selected.position
            if m.selected.duration <> invalid then meta.duration = m.selected.duration
            priorContext = MatchingContext(m.selected)
            priorContext.append(StableSourcePreference(m.selected))
            for each key in priorContext
                if meta[key] = invalid then meta[key] = priorContext[key]
            end for
        end if
    end if
    m.selected = meta
    members = []
    if meta.type = "movie"
        for each video in Bounded(meta.videos,200)
            ' Some metadata aggregators omit shouldIncludeVideos; real member IDs
            ' still identify the collection. Exclude self-links to avoid recursion.
            if Txt(video.id) <> "" and Txt(video.id) <> Txt(meta.id)
                members.push({id:Txt(video.id),type:"movie",name:Txt(video.title,Txt(video.name)),poster:Txt(video.thumbnail),description:Txt(video.overview,Txt(video.description)),posterShape:"landscape"})
            end if
        end for
    end if
    if members.count() > 0
        m.discoverActive = false
        m.mediaType = "movie"
        rows(Txt(meta.name),members,"browse",Txt(meta.description))
    else if meta.type = "series"
        m.episodes = OrderedEpisodes(meta.videos)
        m.episodeSeason = Txt(meta.season)
        if m.episodeSeason = "" and m.episodes.count() > 0 then m.episodeSeason = Txt(m.episodes[0].season,"unknown")
        if Txt(m.profile) <> ""
            rows(Txt(meta.name),[],"loading","")
            request("GET","/api/profiles/" + Enc(m.profile) + "/progress/series?series_id=" + Enc(Txt(m.selected.id)),invalid,"episodeprogress")
        else
            showEpisodes(0)
        end if
    else
        label = "Choose source"
        if meta.position <> invalid
            if meta.position > 0 then label = "Resume at " + PlayerTime(meta.position)
        end if
        action = "play"
        if label <> "Choose source" then action = "resume"
        actions = [{name:label,action:action}]
        if label <> "Choose source" then actions.push({name:"Choose source",action:"sources"})
        actions.push({name:favoriteLabel(meta),action:"favorite"})
        actions.push({name:"More info",action:"moreinfo"})
        rows(Txt(meta.name),actions,"detail","")
        showDetail(meta)
    end if
end sub

sub showEpisodes(offset as integer, enter = true as boolean)
    m.episodeOffset = int(offset / 80) * 80
    if m.episodeOffset < 0 then m.episodeOffset = 0
    if Txt(m.episodeSeason) = "" and m.episodes.count() > 0 then m.episodeSeason = Txt(m.episodes[0].season,"unknown")
    values = [] : count = 0
    for each episode in Bounded(m.episodes,2000)
        if Txt(episode.season,"unknown") = Txt(m.episodeSeason)
            if count >= m.episodeOffset and values.count() < 80 then values.push(episode)
            count++
        end if
    end for
    if m.episodeOffset > 0 then values.unshift({name:"Previous episodes",title:"Previous episodes",action:"episodesprevious"})
    if count > m.episodeOffset + 80 then values.push({name:"More episodes",title:"More episodes",action:"episodesnext"})
    rows(Txt(m.selected.name),values,"episodes","*  Episode options",enter)
    showDetail(m.selected)
end sub
