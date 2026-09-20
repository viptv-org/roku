sub init()
    m.top.backgroundURI = ""
    for each id in ["list", "heading", "status", "identity", "art", "detailTitle", "detailInfo", "description", "video", "poll", "startup", "heartbeat"]
        m[id] = m.top.findNode(id)
    end for
    m.standardList = m.list
    m.posterGrid = m.top.findNode("posterGrid")
    m.sourceList = m.top.findNode("sourceList")
    m.discoverFilters = m.top.findNode("discoverFilters")
    m.profileGrid = m.top.findNode("profileGrid")
    m.homeHeroPanel = m.top.findNode("homeHeroPanel")
    for each node in [m.standardList,m.posterGrid,m.sourceList]
        node.observeField("itemSelected", "selected")
        node.observeField("itemFocused", "focused")
    end for
    if m.discoverFilters <> invalid then m.discoverFilters.observeField("itemSelected","discoverFilterSelected")
    if m.profileGrid <> invalid then m.profileGrid.observeField("itemSelected","profileGridSelected")
    m.listFocusTimer = m.top.findNode("listFocusTimer")
    m.listFocusTimer.observeField("fire","settleList")
    m.video.observeField("state", "videoNodeState")
    m.video.observeField("availableSubtitleTracks","applyPlayerSubtitles")
    m.sourceText = m.top.findNode("sourceText")
    m.detailPanel = m.top.findNode("detailPanel")
    m.playerBackdrop = m.top.findNode("playerBackdrop")
    m.playerOverlay = m.top.findNode("playerOverlay")
    m.playerOverlay.observeField("command","playerCommand")
    m.playerTick = m.top.findNode("playerTick")
    m.playerTick.observeField("fire","updatePlayer")
    m.poll.observeField("fire", "pollStreams")
    m.startup.observeField("fire", "startupFailed")
    m.seekTimer = m.top.findNode("seekTimer")
    m.seekTimer.observeField("fire","seekReplacementFailed")
    m.heartbeat.observeField("fire", "heartbeat")
    m.tasks = []
    m.queue = []
    m.pendingPlayback = false
    m.favoriteBusy = false
    m.playerHint = m.top.findNode("playerHint")
    m.hintTimer = m.top.findNode("hintTimer")
    m.hintTimer.observeField("fire", "hidePlayerHint")
    m.dispatch = m.top.findNode("dispatch")
    m.dispatch.observeField("fire", "dispatchRequests")
    m.dispatch.control = "start"
    m.generation = 0
    m.config = {base: "", access_token: "", refresh_token: "", last_profile_id: "", account_id: "", auth_version: 0, capabilities: {max_width:1280,max_height:720,h264:true,hevc:false,aac:true}}
    m.configLoaded = false
    m.profile = ""
    m.session = ""
    m.playing = false
    m.pausedVOD = false
    m.seeking = false
    m.seekNewSession = ""
    m.nextPrepping = false
    m.nextTransitionSession = ""
    m.nextTransitionConnection = invalid
    m.playerReturnDetail = invalid
    m.position = 0
    m.duration = 0
    m.cache = {}
    m.cacheKeys = []
    m.views = []
    m.budgetTimer = m.top.findNode("budgetTimer")
    m.budgetTimer.observeField("fire","prepExpired")
    initHome()
    initLiveUX()
    initAccount()
    initPresentation()
    initEpg()
    initContinuation()
    initStartup()
    accountShowLoading()
    request("CONFIG_LOAD", "", invalid, "config")
end sub

sub request(method as string, path as string, body as dynamic, tag as string, connection = invalid as dynamic)
    if connection = invalid then connection = m.config
    if tag = "home:progress" or tag = "home:favorites" then tag += ":" + homeRevision(mid(tag,6)).toStr()
    if tag = "home:recent" then tag += ":" + homeRevision("progress").toStr()
    if tag = "home:livefavorites" then tag += ":" + homeRevision("favorites").toStr()
    if m.requestSequence = invalid then m.requestSequence = 0
    m.requestSequence++
    requestId = m.generation.toStr() + "-" + m.requestSequence.toStr()
    entry = {base:connection.base,access_token:Txt(connection.access_token),path:path,method:method,body:body,tag:tag + "|" + m.generation.toStr(),request_id:requestId}
    entry.account_epoch = m.accountEpoch
    entry.last_profile_id = Txt(connection.last_profile_id)
    if (tag = "playback" or tag = "seekplayback") and body <> invalid
        if Txt(m.startupPrefix) = "" then m.startupPrefix = CreateObject("roDateTime").asSeconds().toStr()
        body.startup_id = m.startupPrefix + "-" + requestId
        m.pendingStartupId = body.startup_id
        m.pendingStartupConnection = entry
    end if
    if (tag = "playback" or tag = "seekplayback") and m.prepSpent <> invalid
        entry.timeout_ms = 180000 - m.prepSpent
        if entry.timeout_ms > 50000 then entry.timeout_ms = 50000
        if entry.timeout_ms < 1 then entry.timeout_ms = 1
    end if
    ' Coalesce pending state writes; active writes always finish before later writes.
    if tag = "sideprogress" or tag = "sideconfig" or tag = "sideheartbeat"
        for i = 0 to m.queue.count() - 1
            prior = m.queue[i]
            sameItem = true
            if tag = "sideprogress"
                sameItem = false
                if prior.body <> invalid and body <> invalid then sameItem = Txt(prior.body.id) = Txt(body.id) and Txt(prior.body.type) = Txt(body.type)
            end if
            if sameItem and prior.path = path and prior.base = entry.base and prior.access_token = entry.access_token and prior.account_epoch = entry.account_epoch and left(prior.tag,len(tag)) = tag
                m.queue[i] = entry
                return
            end if
        end for
    end if
    if m.queue.count() >= 24 and left(tag,4) <> "side" and tag <> "cleanup"
        if tag = "playback" then m.pendingPlayback = false
        if tag = "favorited" then m.favoriteBusy = false
        m.status.text = "Network queue is busy. Wait a moment and try again."
        return
    end if
    m.queue.push(entry)
end sub

sub dispatchRequests()
    active = []
    for each task in m.tasks
        if task.state = "run" then active.push(task)
    end for
    m.tasks = active
    if active.count() >= 3 or m.queue.count() = 0 then return
    index = -1
    for i = 0 to m.queue.count() - 1
        candidate = m.queue[i]
        blocked = false
        for each task in active
            if PlaybackRequestsConflict(candidate,task.request) then blocked = true
        end for
        ' Preserve mutation order, including queued account/config changes.
        for j = 0 to i - 1
            if PlaybackRequestsConflict(candidate,m.queue[j]) then blocked = true
        end for
        if not blocked
            index = i
            exit for
        end if
    end for
    if index < 0 then return
    entry = m.queue[index]
    m.queue.delete(index)
    homeMutation(entry,false)
    startRequest(entry)
end sub

sub startRequest(entry as object)
    task = CreateObject("roSGNode", "ApiTask")
    task.request = entry
    task.observeField("result", "response")
    m.tasks.push(task)
    task.control = "RUN"
end sub

sub cancelBrowse()
    m.resumeSourcePreference = invalid
    if Txt(m.pendingStartupId) <> ""
        request("DELETE","/api/playback/startups/" + Enc(m.pendingStartupId),invalid,"cleanupstartup",m.pendingStartupConnection)
        m.pendingStartupId = ""
        m.pendingPlayback = false
    end if
    if m.uiArtworkInflight <> invalid and m.uiArtworkInflight.count() > 0
        if m.uiArtworkTried <> invalid
            for each owner in m.uiArtworkInflight
                m.uiArtworkTried.delete(owner.path)
            end for
        end if
        m.uiArtworkInflight = {}
    end if
    if m.artworkTimer <> invalid then m.artworkTimer.control = "stop"
    if m.uiReady = true
        uiBusy(false)
        m.heroArtTimer.control = "stop"
        if m.uiHeroOwner <> invalid then m.uiHeroTried.delete(m.uiHeroOwner.path)
        m.uiHeroOwner = invalid
    end if
    m.generation++
    if m.liveEpgTimer <> invalid then m.liveEpgTimer.control = "stop"
    m.liveEpgPending = invalid
    m.liveEpgBusy = ""
    m.poll.control = "stop"
    if m.budgetTimer <> invalid then m.budgetTimer.control = "stop"
    m.favoriteBusy = false
    retained = []
    for each entry in m.queue
        tag = entry.tag
        cancellableStartup = false
        if entry.body <> invalid then cancellableStartup = Txt(entry.body.startup_id) <> ""
        if not cancellableStartup
            if left(tag,5) = "auth:" or left(tag,4) = "side" or left(tag,7) = "cleanup" or left(tag,8) = "playback" or left(tag,12) = "seekplayback" or left(tag,9) = "favorited" or left(tag,16) = "librarycorrected" then retained.push(entry)
        end if
    end for
    m.queue = retained
    for each task in m.tasks
        tag = Txt(task.request.tag)
        if task.request.body <> invalid
            if Txt(task.request.body.startup_id) <> "" then task.cancel = true
        end if
        if left(tag,5) <> "auth:" and left(tag,4) <> "side" and left(tag,7) <> "cleanup" and left(tag,8) <> "playback" and left(tag,12) <> "seekplayback" and left(tag,9) <> "favorited" and left(tag,16) <> "librarycorrected" then task.cancel = true
    end for
end sub

sub rows(title as string, values as object, mode as string, subtitle = "" as string, enter = true as boolean)
    uiRows(title,values,mode,subtitle,enter)
end sub

sub showSettings()
    m.discoverActive = false
    if m.configLoaded = false
        rows("Settings", [{displayName:"Loading account status…",action:"waiting"}], "settings", "Starting VIPTV…")
        return
    end if
    origin = Txt(m.config.base,"https://viptv.syek.tech")
    values = [
        {name:"Switch profile",action:"profiles",description:"Choose who's watching."},
        {name:"Playback preferences",action:"playbackpreferences",description:"Audio, subtitles and quality for this profile."},
        {name:"Manage profiles",action:"manageprofiles",description:"Add, rename, choose avatars or delete profiles."},
        {name:"About VIPTV",action:"about",description:"Version " + InstalledAppVersion() + chr(10) + origin},
        {name:"Addons",action:"addons",description:"Manage addons shared by your account."},
        {name:"Sign out",action:"signout",description:"Sign out of VIPTV on this TV."}
    ]
    if m.profile = ""
        values = [{name:"Sign in",action:"pair"}]
        rows("VIPTV",values,"settings","")
    else
        rows("Settings",values,"settings","")
    end if
end sub

sub home()
    m.discoverActive = false
    cancelBrowse()
    if m.profile = ""
        showSettings()
        return
    end if
    if m.sidebar <> invalid then m.sidebar.jumpToItem = 1
    showHome()
end sub

sub keyboard(kind as string, title as string, value as string)
    if kind = "search"
        searchOpen(value)
        return
    end if
    m.keyboardKind = kind
    m.keyboardAccountEpoch = m.accountEpoch
    m.textEntry.heading = title
    m.textEntry.value = value
    m.textEntry.limit = 256
    m.textEntry.secret = kind = "parentpin"
    if kind = "parentpin" then m.textEntry.limit = 8
    if kind = "accountprofilename" then m.textEntry.limit = 80
    if kind = "epgsearch" then m.textEntry.limit = 128
    if kind = "addon" then m.textEntry.limit = 4096
    m.textEntry.callFunc("open")
end sub

sub keyboardDone()
    result = m.textEntry.result
    if result = invalid then return
    m.textEntry.visible = false
    if m.textEntry.secret then m.textEntry.result = invalid
    if m.keyboardAccountEpoch <> m.accountEpoch then return
    if m.keyboardKind = "parentpin"
        accountSubmitParentPin(result)
        return
    end if
    if m.keyboardKind = "accountprofilename"
        if result.accepted then accountSubmitProfileName(result.text)
        m.profileEditor.callFunc("open")
        return
    end if
    if m.keyboardKind = "epgsearch"
        if result.accepted then m.epgGrid.query = result.text.trim()
        m.epgGrid.callFunc("resume")
        return
    end if
    if m.keyboardKind = "discoverSearch" or m.keyboardKind = "discoverExtra"
        if result.accepted
            if m.keyboardKind = "discoverSearch"
                m.search = result.text.trim()
            else
                m.discoverExtras[m.discoverExtraName] = result.text.trim()
            end if
            browse(m.discoverType,0)
        end if
        m.discoverFilters.setFocus(true)
        return
    end if
    uiRestoreFocus()
    if result.accepted and m.keyboardKind = "addon" and result.text.trim() <> ""
        request("POST","/api/addons",{manifest_url:result.text.trim()},"addonchanged")
        m.status.text = "Installing addon…"
    end if
end sub

sub selected()
    index = m.list.itemSelected
    if index < 0 or index >= m.items.count() then return
    selectItem(m.items[index])
end sub

sub profileGridSelected()
    if m.profileGrid = invalid then return
    index = m.profileGrid.itemSelected
    if index < 0 or index >= m.items.count() then return
    ' Preserve canonical profile IDs and booleans from the account response.
    ' Native ContentNode fields are presentation only, not the account model.
    item = m.items[index]
    accountProfileAction(item)
end sub

sub selectItem(item as object)
    if item.action = invalid
        if selectQueueItem(item) then return
    end if
    if item.action <> invalid
        action = item.action
        if action = "librarypage"
            openLibraryPage(item.offset)
        else if action = "libraryremove"
            m.favoriteItem = m.libraryItem
            m.favoriteMessage = "Removed from favorites."
            m.libraryRestoreIndex = m.list.itemFocused
            request("DELETE","/api/profiles/"+Enc(m.profile)+"/favorites/"+Enc(m.libraryItem.type)+"/"+Enc(Txt(m.libraryItem.id)),invalid,"favorited")
        else if action = "librarycorrect"
            libraryCorrect(item.value)
        else if action = "libraryrestart"
            restart = CopyRouteData(m.libraryItem)
            restart.position = 0
            findStreams(restart,true)
        else if action = "favorites"
            openLibraryPage(0)
        else if action = "queueresume" or action = "queuesources"
            resume = CopyRouteData(m.queueItem)
            if resume.previous_episode <> invalid then resume = CopyRouteData(resume.previous_episode)
            resume.delete("queue_status")
            findStreams(resume,action = "queuesources",StableResumePreference(resume))
        else if action = "queueremove"
            queueVisibility(true)
        else if action = "queueundo"
            queueVisibility(false)
        else if action = "queuepage"
            openViewingQueue(item.offset)
        else if action = "progress"
            openViewingQueue(0)
        else if action = "continuationdetails"
            showDetail(m.playItem)
        else if action = "manageprofiles"
            accountManageProfiles()
        else if action = "playbackpreferences"
            m.preferencesScope = m.profile
            rows("Playback preferences",[{name:"Loading…",action:"waiting"}],"preferences","")
            request("GET","/api/profiles/"+Enc(m.profile)+"/preferences",invalid,"profilepreferences")
        else if action = "preferencechoice"
            m.preferenceKey = item.preferenceKey
            choices = []
            for each option in item.options
                choices.push({name:option.name,action:"preferencesave",value:option.value})
            end for
            uiOpenChoice("preferences",item.name,choices)
        else if action = "preferencesave"
            body = {}
            body[m.preferenceKey] = item.value
            request("PUT","/api/profiles/"+Enc(m.profile)+"/preferences",body,"profilepreferences")
        else if action = "addons"
            cancelBrowse()
            rows("Addons",[],"addons","")
            request("GET","/api/addons",invalid,"accountaddons")
        else if action = "installaddon"
            keyboard("addon","Install addon manifest URL", "https://")
        else if action = "manageaddon"
            m.managedAddon = item
            label = "Enable"
            if item.enabled = true then label = "Disable"
            uiOpenChoice("addon","Manage " + Txt(item.name),[{name:label,action:"toggleaddon"},{name:"Remove addon",action:"removeaddon"},{name:"Cancel",action:"cancel"}])
        else if action = "discover"
            openDiscover("movie")
        else if action = "discovermovie"
            openDiscover("movie")
        else if action = "discoverseries"
            openDiscover("series")
        else if action = "profiles"
            m.managingProfiles = false
            accountOpenProfiles()
        else if action = "signout"
            uiOpenChoice("signout","Sign out of VIPTV?",[{name:"Keep watching",action:"cancel"},{name:"Sign out",action:"confirmSignout"}])
        else if action = "moreinfo"
            uiFullText("About " + Txt(m.selected.name),PresentationFullDetails(m.selected))
        else if action = "serverstatus" or action = "about" or action = "waiting"
            return
        else if action = "pair"
            accountPair()
        else if action = "paircancel"
            accountCancelPair()
        else if action = "newprofile"
            if m.accountMode = true and m.canCreateProfile <> true then return
            accountStartProfileSetup(invalid)
        else if action = "home"
            ' Preserve the cursor and matching compact/expanded presentation together.
            m.views = []
            home()
        else if action = "retryhome"
            m.homeDirty = true
            home()
        else if action = "settings"
            cancelBrowse()
            showSettings()
        else if action = "movie" or action = "series"
            m.discoverActive = false
            m.mediaType = action
            m.search = ""
            m.catalog = invalid
            m.offsetHistory = []
            m.nextOffset = invalid
            cancelBrowse()
            request("GET", "/api/catalogs", invalid, "catalogs")
            m.status.text = "Loading catalogs…"
        else if action = "search"
            m.discoverActive = false
            cancelBrowse()
            m.mediaType = "all"
            m.catalog = invalid
            m.offsetHistory = []
            m.nextOffset = invalid
            keyboard("search","Search","")
        else if left(action,6) = "search"
            m.mediaType = mid(action,7)
            m.catalog = invalid
            m.offsetHistory = []
            m.nextOffset = invalid
            keyboard("search", "Search " + m.mediaType, "")
        else if action = "live"
            openEpg()
        else if action = "livefavorites"
            openEpg(false,"favorites")
        else if action = "recentlive"
            openEpg(false,"recent")
        else if action = "livefilter"
            saveView()
            liveCategories(0)
        else if action = "allchannels" or action = "liveclear"
            m.search = ""
            m.liveCategory = ""
            m.liveCategoryName = "All channels"
            m.offsetHistory = []
            m.nextOffset = invalid
            browse("live",0)
        else if action = "livecategoriesnext"
            liveCategories(m.categoryOffset + 80)
        else if action = "livecategoriesprevious"
            liveCategories(m.categoryOffset - 80)
        else if action = "livesearch"
            m.liveCategory = ""
            m.liveCategoryName = "Search channels"
            m.mediaType = "live"
            m.offsetHistory = []
            m.nextOffset = invalid
            keyboard("search","Search channels","")
        else if action = "next"
            if m.nextOffset <> invalid
                if m.offsetHistory = invalid then m.offsetHistory = []
                m.offsetHistory.push(m.offset)
                browse(m.mediaType,m.nextOffset)
            end if
        else if action = "previous"
            offset = 0
            if m.offsetHistory <> invalid
                if m.offsetHistory.count() > 0 then offset = m.offsetHistory.pop()
            end if
            browse(m.mediaType,offset)
        else if action = "play" or action = "sources" or action = "resume"
            if action = "play"
                if selectQueueItem(m.selected) then return
            end if
            ' Every ordinary play action opens the populated explicit picker.
            findStreams(m.selected,action <> "resume",StableResumePreference(m.selected))
        else if action = "retrysources"
            m.playItem.position = m.position
            m.playItem.duration = m.duration
            findStreams(m.playItem,true)
        else if action = "retryplay"
            retrySelectedPlayback()
        else if action = "watchlive"
            saveView()
            resetAttempts()
            m.playItem = m.selected
            m.position = 0
            beginPlayback(false)
        else if action = "favorite"
            toggleFavorite()
        else if action = "episodesnext"
            showEpisodes(m.episodeOffset + 80)
        else if action = "episodesprevious"
            showEpisodes(m.episodeOffset - 80)
        end if
        return
    end if
    if m.mode = "profiles"
        updateProfileNav(item)
        accountChoose(item)
        return
    else if m.mode = "livecategories"
        saveView()
        m.liveCategory = Txt(item.id)
        m.liveCategoryName = Txt(item.name)
        m.search = ""
        m.offsetHistory = []
        m.nextOffset = invalid
        browse("live",0)
    else if m.mode = "catalogs"
        m.catalog = item
        m.offsetHistory = []
        m.nextOffset = invalid
        browse(m.mediaType,0)
    else if m.mode = "streams"
        resetAttempts()
        m.manualSources = true
        m.automaticContinuation = false
        m.continuationSourcePreference = invalid
        playSource(item)
    else if m.mode = "guide"
        showDetail(item)
    else if m.mode = "episodes"
        episode = EpisodePresentationItem(m.selected,item)
        findStreams(episode,true)
    else
        saveView()
        m.selected = item
        m.position = 0
        if item.position <> invalid then m.position = item.position
        cancelBrowse()
        if item.type = "live"
            resetAttempts()
            m.playItem = item
            m.position = 0
            beginPlayback(false)
        else
            path = "/api/meta/" + Enc(Txt(item.type,"movie")) + "/" + Enc(Txt(item.id))
            cached = m.cache[path]
            now = CreateObject("roDateTime").asSeconds()
            if cached <> invalid
                if now - cached.time < 300
                    showMetadata(cached.data)
                    return
                end if
            end if
            m.metaPath = path
            request("GET", path, invalid, "meta")
            m.status.text = "Loading details…"
        end if
    end if
end sub

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

sub openDiscover(kind as string)
    cancelBrowse()
    m.discoverActive = true
    m.discoverType = kind
    m.mediaType = kind
    m.discoverGenre = ""
    m.discoverExtras = {}
    m.search = ""
    m.discoverCatalogs = []
    m.catalog = invalid
    m.offsetHistory = []
    m.nextOffset = invalid
    rows("Discover",[{name:"Loading catalogs…",action:"waiting"}],"loading","Movies, series and live catalogs from your configured addons.")
    request("GET","/api/catalogs",invalid,"discovercatalogs")
end sub

sub discoverUseCatalogs(data as dynamic)
    m.discoverCatalogs = []
    for each catalog in Bounded(data,2048)
        m.discoverCatalogs.push(catalog)
    end for
    supported = false
    for each catalog in m.discoverCatalogs
        if DiscoverTypeMatches(Txt(catalog.type),m.discoverType) then supported = true
    end for
    if not supported and m.discoverCatalogs.count() > 0
        for each catalog in m.discoverCatalogs
            if Txt(catalog.type) <> "live"
                m.discoverType = Txt(catalog.type)
                exit for
            end if
        end for
    end if
    discoverChooseDefaultCatalog()
    discoverBuildFilters()
    browse(m.discoverType,0)
end sub

sub discoverChooseDefaultCatalog()
    m.catalog = invalid
    for each catalog in m.discoverCatalogs
        if DiscoverTypeMatches(Txt(catalog.type),m.discoverType)
            if not UiCatalogRequired(catalog,"search")
                m.catalog = catalog
                exit for
            end if
        end if
    end for
    if m.catalog = invalid and m.discoverCatalogs.count() > 0
        for each catalog in m.discoverCatalogs
            if DiscoverTypeMatches(Txt(catalog.type),m.discoverType) then m.catalog = catalog
        end for
    end if
    uiRequiredGenre()
end sub

sub discoverBuildFilters()
    uiDiscoverFilters()
end sub

sub discoverFilterSelected()
    uiDiscoverFilterSelected()
end sub

sub browse(kind as string, offset as integer)
    cancelBrowse()
    m.mediaType = kind
    m.offset = offset
    title = "Discover"
    if kind = "live" then title = "Live TV"
    rows(title,[],"browse","")
    if m.discoverActive = true and kind <> "live"
        discoverBuildFilters()
        if m.catalog = invalid
            uiEmpty("No catalogs yet","Add a movie or series catalog in your account settings.")
            return
        end if
        missing = DiscoverMissingOption(m.catalog,m.search,m.discoverGenre,m.discoverExtras)
        if missing <> ""
            uiEmpty("Choose " + missing,"Use the filters above to browse this catalog.")
            if acknowledgementMayFocus() then m.discoverFilters.setFocus(true)
            return
        end if
        if UiCatalogRequired(m.catalog,"search") and Txt(m.search).trim() = ""
            uiEmpty("Search this catalog","Choose Search above to find a title.")
            if acknowledgementMayFocus() then m.discoverFilters.setFocus(true)
            return
        end if
    end if
    if kind = "live"
        path = LiveChannelPath(Txt(m.liveCategory),Txt(m.search),offset)
    else
        path = "/api/discover?type=" + Enc(kind) + "&skip=" + offset.toStr()
        query = Txt(m.search).trim()
        ' Omitting an empty search preserves normal Stremio catalog browsing and
        ' its authoritative cursor; search= would incorrectly invoke aggregation.
        if query <> "" then path += "&search=" + Enc(query)
        if m.catalog <> invalid then path += "&catalog=" + Enc(Txt(m.catalog.id)) + "&addon_id=" + Enc(Txt(m.catalog.addon_id))
        genre = Txt(m.discoverGenre).trim()
        if m.discoverActive = true and genre <> "" then path += "&genre=" + Enc(genre)
        if m.discoverActive = true and m.discoverExtras <> invalid
            if m.discoverExtras.count() > 0 then path += "&extras=" + Enc(FormatJson(m.discoverExtras))
        end if
    end if
    request("GET",path,invalid,"browse")
    m.status.text = "Loading " + kind + "…"
end sub

function acknowledgementMayFocus() as boolean
    if m.uiReady = true
        if m.choicePanel.visible or m.fullTextPanel.visible then return false
        if m.profileEditor.visible or m.textEntry.visible then return false
    end if
    ' Focus safety applies both during response rendering and local view changes
    ' such as submitting a native keyboard dialog.
    if m.sidebar <> invalid
        if m.sidebar.hasFocus() then return false
    end if
    if m.top <> invalid
        if m.top.dialog <> invalid then return false
    end if
    if m.video <> invalid
        if m.video.visible then return false
    end if
    if m.pausedVOD = true then return false
    return true
end function

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

sub settleList()
    if m.listUpdating = true and m.mode <> "home" and m.items.count() > 0 then m.list.jumpToItem = m.listRestoreIndex
    m.listUpdating = false
    ' A content reset can suppress the first native focus notification. Repaint
    ' the local preview after releasing the guard; this does not move focus or fetch.
    if m.mode <> "home" then focused()
end sub

sub focused()
    uiQueueCardArtwork()
    if m.listUpdating = true then return
    index = m.list.itemFocused
    if index < 0 or index >= m.items.count() then index = 0
    if m.items.count() = 0 then return
    if m.mode = "detail" or m.mode = "episodes" then return
    showDetail(m.items[index])
end sub

sub showDetail(item as object)
    if m.mode = "guide" and item.action <> invalid and m.selected <> invalid then item = m.selected
    uiShowDetails(item)
end sub

function favoriteLabel(item as object) as string
    if UiIsFavorite(item) then return "Remove from My List"
    return "+ My List"
end function

sub toggleFavorite()
    if m.profile = "" or m.favoriteBusy then return
    if m.mode <> "browse" and m.mode <> "livefavorites" and m.mode <> "collection" and m.mode <> "detail" and m.mode <> "episodes" and m.mode <> "guide" and m.mode <> "home" then return
    item = m.selected
    if m.mode = "home" then item = homeCurrent()
    if m.mode = "browse" or m.mode = "collection" or m.mode = "livefavorites"
        index = m.list.itemFocused
        if index < 0 or index >= m.items.count() then return
        item = m.items[index]
    end if
    if item = invalid then return
    if item.id = invalid or item.type = invalid then return
    m.favoriteBusy = true
    m.favoriteItem = item
    request("POST", "/api/profiles/" + Enc(m.profile) + "/favorites/toggle", {id:item.id,type:item.type,name:item.name,poster:FavoriteArtwork(item)}, "favorited")
end sub

sub findStreams(item as object, manual = true as boolean, preferredSource = invalid as dynamic, automatic = false as boolean)
    ' Home-shelf playback returns to the title's detail page on Back. A running
    ' next-episode transition keeps its already-chosen return target.
    if m.nextPrepping <> true
        if m.mode = "home" and item <> invalid and Txt(item.type) <> "live" then m.playerReturnDetail = CopyRouteData(item)
        if m.mode <> "home" then m.playerReturnDetail = invalid
    end if
    saveView()
    cancelBrowse()
    if Txt(m.sourcePreferencesProfile) <> m.profile or m.sourcePreferences = invalid
        m.sourcePreferencesProfile = m.profile
        m.sourcePreferences = invalid
        request("GET","/api/profiles/"+Enc(m.profile)+"/preferences",invalid,"sourcepreferences:"+m.profile)
    end if
    resetAttempts()
    m.sourcesAt = invalid
    m.refreshingSources = false
    m.resumeSourcePreference = preferredSource
    m.automaticContinuation = automatic
    m.continuationSourcePreference = invalid
    if preferredSource <> invalid
        if preferredSource.continuation = true then m.continuationSourcePreference = CopyRouteData(preferredSource)
    end if
    m.manualSources = manual or preferredSource = invalid
    m.sourceHintCache = {}
    m.playItem = {}
    m.playItem.append(item)
    m.streams = []
    m.discoveryDone = false
    m.position = 0
    m.duration = 0
    if item.position <> invalid then m.position = item.position
    if item.duration <> invalid then m.duration = item.duration
    m.skipNearEndContinuation = NearEpisodeEnd(m.position,m.duration)
    body = {type:item.type,id:item.id,name:Txt(item.seriesName,item.name)}
    body.append(StreamContext(item))
    if m.continuationSourcePreference <> invalid
        provider = Txt(m.continuationSourcePreference.source_addon_id)
        if left(provider,5) = "iptv:"
            body.only_provider_id = val(mid(provider,6))
        else
            body.only_addons = true
        end if
    end if
    request("POST","/api/streams",body,"streamstart")
    if not m.manualSources
        ' Resume is an explicit operation, never a timer attached to the picker.
        m.mode = "resuming"
        m.status.text = "Resuming… Back to choose a source"
        if m.continuationSourcePreference <> invalid then m.status.text = "Finding next episode source… Back to choose a source"
        uiBusy(true)
    else if m.heading <> invalid
        rows("Choose a source",[],"streams","")
        uiSourceHeader()
    end if
end sub

sub pollStreams()
    m.pollCount++
    request("GET","/api/streams/" + Enc(m.job) + "?after=" + m.cursor.toStr(),invalid,"streampoll")
end sub

sub beginPlayback(force as boolean)
    if m.pendingPlayback
        m.status.text = "Playback is already preparing. Please wait."
        return
    end if
    if m.refreshingSources = true then return
    if m.refreshClock <> invalid
        m.prepSpent += m.refreshClock.totalMilliseconds()
        m.refreshClock = invalid
    end if
    issued = m.activeSourceAt
    if issued = invalid then issued = m.sourcesAt
    if m.playItem.type <> "live" and SourceIdsExpired(issued,CreateObject("roDateTime").asSeconds())
        refreshSourceIds()
        return
    end if
    cancelBrowse()
    if m.prepSpent = invalid then resetAttempts()
    if m.prepSpent >= 180000
        sourceExhausted("Playback preparation timed out.")
        return
    end if
    m.prepClock = CreateObject("roTimespan")
    m.prepClock.mark()
    if m.budgetTimer <> invalid
        m.budgetTimer.duration = (180000 - m.prepSpent) / 1000.0
        m.budgetTimer.control = "start"
    end if
    m.pendingPlayback = true
    m.pausedVOD = false
    m.forced = force
    if m.playItem.type = "live" then m.position = 0
    if m.duration > 0 and m.position >= m.duration then m.position = 0
    uiBusy(true)
    body = PlaybackBody(m.playItem,m.profile,m.config.capabilities,m.position,force)
    if m.directRetryUsed = true then body.managed_only = true
    body.append(TrackRequestFields(m.playItem,m.trackPreferences))
    if Txt(m.playItem.audio_language) <> "" then body.audio_language = m.playItem.audio_language
    request("POST","/api/playback",body,"playback")
    if m.pendingPlayback then m.pendingRequestId = m.generation.toStr() + "-" + m.requestSequence.toStr()
end sub

sub videoNodeState(event as object)
    node = event.getRoSGNode()
    if node.isSameNode(m.video)
        if m.seeking = true
            seekPrimaryVideoState()
        else
            videoState()
        end if
    end if
end sub

sub videoState()
    ' The old decoder is intentionally paused during atomic replacement.
    if m.seeking = true then return
    state = m.video.state
    if m.managedLive = true and m.playing = true and (state = "error" or state = "finished")
        requestLiveRecovery()
        return
    end if
    if m.directSeekPause = true
        pauseAgain = state = "playing"
        m.directSeekPause = DirectSeekPause(m.video,true)
        if pauseAgain
            m.pausedVOD = true
            return
        end if
    end if
    if state = "playing"
        firstFrame = m.hasPlayed <> true
        m.hasPlayed = true
        if firstFrame and m.playbackLive = true then saveProgress()
        if firstFrame
            if m.playStartClock <> invalid then print "VIPTV_PLAYBACK_START mode=";m.playbackMode;" player_ms=";m.playStartClock.totalMilliseconds()
            m.playStartClock = invalid
            prefetchContinuation()
        end if
        m.startup.control = "stop"
        if m.budgetTimer <> invalid then m.budgetTimer.control = "stop"
        if m.prepClock <> invalid
            if m.prepSpent <> invalid then m.prepSpent += m.prepClock.totalMilliseconds()
            m.prepClock = invalid
        end if
        if m.resumePosition <> invalid
            if m.resumePosition > 0 and m.playItem.type <> "live" and m.playbackLive <> true then m.video.seek = m.resumePosition
            m.resumePosition = invalid
        end if
    else if state = "error"
        retryPlayback("Video error " + m.video.errorCode.toStr() + ": " + m.video.errorMsg)
    else if state = "finished"
        if not m.playing then return
        saveProgress()
        if m.playItem.type = "live" or m.playbackLive = true
            stopPlayback(false)
            if m.liveRetunes = invalid then m.liveRetunes = 0
            if m.liveRetunes < 2
                m.liveRetunes++
                beginPlayback(false)
            else
                sourceExhausted("Live stream ended.")
            end if
        else if FarBeforeEnd(m.position,m.duration)
            stopPlayback(false)
            sourceExhausted("Selected source ended early. Choose another source.")
        else if m.playItem.type = "series" and m.hasPlayed = true and NearEpisodeEnd(m.position,m.duration)
            continuationBegin(true)
        else
            stopPlayback()
        end if
    end if
end sub

sub startupFailed()
    retryPlayback("Playback did not start within 25 seconds.")
end sub

sub retryPlayback(reason as string)
    if not m.playing then return
    category = ""
    if m.video.state = "error" and GetInterface(m.video.errorInfo,"ifAssociativeArray") <> invalid then category = lcase(Txt(m.video.errorInfo.category))
    originFailure = category = "http" or category = "drm"
    if m.playbackMode = "direct" and m.directRetryUsed <> true and not originFailure
        saveProgress()
        stopPlayback(false)
        m.directRetryUsed = true
        beginPlayback(false)
        return
    end if
    if m.managedLive = true
        requestLiveRecovery()
        return
    end if
    force = not m.forced and m.codecRetryUsed <> true and not originFailure
    stopPlayback(false)
    if force
        m.codecRetryUsed = true
        beginPlayback(true)
    else
        if retryContinuationSource() then return
        sourceExhausted("Selected source could not play. Choose another source.")
    end if
end sub

sub heartbeat()
    if m.session = "" then return
    request("POST","/api/playback/" + Enc(m.session) + "/heartbeat",{},"sideheartbeat")
    saveProgress()
end sub

sub saveProgress()
    if not m.playing then return
    if m.playItem.type = "live" or m.playbackLive = true
        if m.hasPlayed <> true then return
        body = {id:m.playItem.id,type:"live",name:m.playItem.name,poster:Txt(m.playItem.logo,Txt(m.playItem.poster)),position:0,duration:0}
        request("PUT","/api/profiles/" + Enc(m.profile) + "/progress",body,"sideprogress")
        m.homeDirty = true
        return
    end if
    if m.video.position > 0 then m.position = m.timelineOffset + m.video.position
    if m.playbackMode = "direct" and m.video.duration > 0
        if m.duration <= 0 or m.video.duration > m.duration then m.duration = m.video.duration
    end if
    ' Duration 0 honestly means unknown, never the rolling HLS window length.
    if m.position <= 0 then return
    ' Persist canonical series name so episode resume can still match IPTV fallback.
    body = {id:m.playItem.id,type:m.playItem.type,name:Txt(m.playItem.seriesName,m.playItem.name),poster:Txt(m.playItem.poster),position:m.position,duration:m.duration}
    body.append(StreamContext(m.playItem))
    body.append(StableSourcePreference(m.playItem))
    m.homeDirty = true
    request("PUT","/api/profiles/" + Enc(m.profile) + "/progress",body,"sideprogress")
end sub

sub updatePlayer()
    if m.playerOverlay = invalid or m.playItem = invalid then return
    position = m.position
    if m.playing and m.video.position <> invalid
        if m.video.state = "playing" or m.video.state = "paused" then position = m.video.position + m.timelineOffset
    end if
    state = Txt(m.video.state)
    if m.seeking = true then state = "seeking"
    if m.nextPrepping = true then state = "buffering"
    if m.playing = true and m.skipNearEndContinuation <> true and state = "playing" and m.pausedVOD <> true and m.playItem.type = "series" and m.playbackLive <> true and NearEpisodeEnd(position,m.duration)
        if m.nextOwner = Txt(m.playItem.id) and m.nextScope = m.profile and m.nextResult <> invalid
            if m.nextResult.status = "next"
                m.position = position
                continuationBegin(true)
                return
            end if
        end if
    end if
    episode = ""
    if m.playItem.type = "series" and m.playbackLive <> true
        epCoords = StreamContext(m.playItem)
        if epCoords.season <> invalid and epCoords.episode <> invalid then episode = "S" + Txt(epCoords.season) + " E" + Txt(epCoords.episode)
        epName = Txt(m.playItem.episodeTitle)
        if epName <> ""
            if episode <> "" then episode = episode + " · " + epName else episode = epName
        end if
    end if
    m.playerOverlay.model = {session:m.session,state:state,title:Txt(m.playItem.seriesName,Txt(m.playItem.name)),episode:episode,context:PresentationContext(m.playItem),logo:Txt(m.playItem.logo,Txt(m.playItem.poster)),programme:m.playItem.now,position:position,duration:m.duration,live:m.playbackLive,paused:m.pausedVOD = true or m.video.state = "paused",seeking:m.seeking = true,seek_target:m.seekTarget,next_episode:m.playItem.type = "series" and m.playbackLive <> true}
end sub

sub playerCommand(event as object)
    command = event.getData()
    if command.kind = "next"
        continuationBegin(false)
    else if command.kind = "exit"
        stopPlayback()
    else if command.kind = "pause"
        if m.playbackLive = true or m.seeking = true then return
        pauseVOD()
    else if command.kind = "seek"
        if m.playbackLive = true then return
        target = ClampPlayerSeek(command.value,m.duration)
        seekToPosition(target)
    else if command.kind = "audio" or command.kind = "subtitles"
        showPlayerTracks(command.kind)
    end if
    updatePlayer()
end sub

function nextPlayerDialogId() as string
    if m.playerDialogSequence = invalid then m.playerDialogSequence = 0
    m.playerDialogSequence++
    return "player:" + m.playerDialogSequence.toStr()
end function

function playerDialogEventMatches(event as object) as boolean
    if m.top.dialog = invalid then return false
    node = event.getRoSGNode()
    if node = invalid then return false
    return left(Txt(node.id),7) = "player:" and Txt(node.id) = Txt(m.top.dialog.id)
end function

sub showPlayerTracks(kind as string, page = 0 as integer)
    m.trackKind = kind
    m.trackPage = page
    m.trackDialogSession = m.session
    m.trackDialogOwner = TrackOwner(m.playItem)
    m.trackChoices = []
    buttons = []
    tracks = Bounded(m.audioTracks,32)
    title = "Audio tracks"
    message = "Choose any available audio track. Language labels are informational."
    if kind = "subtitles"
        tracks = Bounded(m.subtitleTracks,32)
        title = "Subtitles"
        message = "Select a supported text track. Image subtitles cannot be displayed."
        if m.subtitlesSupported <> true then message = "Subtitles are unavailable for this output. Listed tracks cannot currently be displayed."
        if m.subtitlesSupported = true
            buttons.push("Off")
            m.trackChoices.push({action:"off"})
        end if
    end if
    for index = page to page + 4
        if index >= tracks.count() then exit for
        track = tracks[index]
        label = PlayerTrackLabel(track)
        if track.selected = true then label = "Playing · " + label
        if not PlayerTrackSelectable(track) or (kind = "subtitles" and m.subtitlesSupported <> true) then label = "Unavailable · " + label
        buttons.push(left(label,100))
        m.trackChoices.push(track)
    end for
    if page + 5 < tracks.count()
        buttons.push("More tracks")
        m.trackChoices.push({action:"next"})
    end if
    if page > 0
        buttons.push("Previous tracks")
        m.trackChoices.push({action:"previous"})
    end if
    if tracks.count() = 0
        message = "This stream supplies no selectable audio tracks."
        if kind = "subtitles" then message = "This stream supplies no selectable subtitles."
    end if
    buttons.push("Back to player")
    m.trackChoices.push({action:"back"})
    dialog = CreateObject("roSGNode","Dialog")
    dialog.id = nextPlayerDialogId()
    dialog.title = title
    dialog.message = message
    dialog.buttons = buttons
    dialog.observeField("buttonSelected","playerTrackSelected")
    dialog.observeField("wasClosed","playerDialogClosed")
    m.top.dialog = dialog
end sub

sub playerTrackSelected(event as object)
    if not playerDialogEventMatches(event) then return
    index = event.getData()
    if index < 0 or index >= m.trackChoices.count() then return
    choice = m.trackChoices[index]
    closePlayerTracks()
    if m.trackDialogOwner <> TrackOwner(m.playItem) or m.trackDialogSession <> m.session then return
    if choice.action = "back" then return
    if choice.action = "next"
        showPlayerTracks(m.trackKind,m.trackPage + 5)
        return
    else if choice.action = "previous"
        showPlayerTracks(m.trackKind,m.trackPage - 5)
        return
    end if
    if choice.action <> "off"
        if not MatchInteger(choice.input_index,0,65535) then return
        if not PlayerTrackSelectable(choice) then return
        if m.trackKind = "subtitles" and m.subtitlesSupported <> true then return
    end if
    choosePlayerTrack(choice)
end sub

sub choosePlayerTrack(choice as object)
    if m.trackPreferences = invalid then m.trackPreferences = {}
    if Txt(m.trackPreferences.owner) <> TrackOwner(m.playItem) then m.trackPreferences = {}
    m.trackPreferences.owner = TrackOwner(m.playItem)
    if m.trackKind = "audio"
        m.trackPreferences.audio_track_index = choice.input_index
        language = StablePreferenceText(choice.language,16)
        if language <> "" then m.playItem.audio_language = lcase(language)
    else
        if m.captionRestore = invalid then m.captionRestore = m.video.globalCaptionMode
        if choice.action = "off"
            m.trackPreferences.delete("subtitle_track_index")
            m.trackPreferences.subtitles_off = true
            m.video.globalCaptionMode = "Off"
        else
            m.trackPreferences.subtitle_track_index = choice.input_index
            m.trackPreferences.subtitles_off = false
        end if
    end if
    saveProgress()
    seekToPosition(m.position,true)
end sub

sub applyPlayerSubtitles()
    if m.playItem = invalid or m.subtitlesSupported <> true then return
    preferences = TrackRequestFields(m.playItem,m.trackPreferences)
    if preferences.subtitle_track_index = invalid then return
    if not m.playing or m.selectedSubtitle = invalid then return
    id = MatchNativeCaption(m.video.availableSubtitleTracks,Txt(m.nativeCaptionName))
    if id <> ""
        m.nativeCaptionName = id
        m.video.subtitleTrack = id
    end if
end sub

sub playerDialogClosed(event = invalid as dynamic)
    ' A delayed close event must not steal a replacement modal or sidebar focus.
    if m.top.dialog <> invalid
        if event <> invalid
            node = event.getRoSGNode()
            if node = invalid then return
            if Txt(node.id) <> Txt(m.top.dialog.id) then return
        else if m.top.dialog.close <> true
            return
        end if
    end if
    if m.sidebar <> invalid
        if m.sidebar.hasFocus() then return
    end if
    if m.playerOverlay <> invalid
        if m.playerOverlay.visible and (m.playing or m.pausedVOD = true)
            m.playerOverlay.opened = true
            m.playerOverlay.setFocus(true)
            return
        end if
    end if
    if m.mode = "sourceerror" and m.pendingPlayback <> true then m.list.setFocus(true)
end sub

sub closePlayerTracks()
    if m.top.dialog <> invalid then m.top.dialog.close = true
    if m.playerOverlay <> invalid
        m.playerOverlay.opened = true
        m.playerOverlay.setFocus(true)
    end if
end sub

sub hidePlayerHint()
    m.playerHint.visible = false
end sub

sub stopPlayback(restore = true as boolean)
    saveProgress()
    ' Retire a still-pending next-episode transition before restoring the view.
    if m.nextPrepping = true or m.nextTransitionSession <> ""
        if m.nextTransitionSession <> "" then request("DELETE","/api/playback/" + Enc(m.nextTransitionSession),invalid,"cleanup",m.nextTransitionConnection)
        m.nextTransitionSession = ""
        m.nextTransitionConnection = invalid
    end if
    m.nextPrepping = false
    if m.playItem <> invalid
        if m.playItem.type <> "live"
            m.playItem.position = m.position
            m.playItem.duration = m.duration
        end if
    end if
    if m.budgetTimer <> invalid then m.budgetTimer.control = "stop"
    if m.prepClock <> invalid and m.prepSpent <> invalid
        m.prepSpent += m.prepClock.totalMilliseconds()
        m.prepClock = invalid
    end if
    if m.playerHint <> invalid then m.playerHint.visible = false
    if m.hintTimer <> invalid then m.hintTimer.control = "stop"
    if m.seekTimer <> invalid then m.seekTimer.control = "stop"
    if m.seeking = true
        if Txt(m.pendingStartupId) <> "" then cancelBrowse()
        m.seeking = false
        m.seekPhase = ""
        if Txt(m.seekNewSession) <> "" then request("DELETE","/api/playback/" + Enc(m.seekNewSession),invalid,"cleanup",m.seekNewConnection)
        m.seekNewSession = ""
        m.seekNewContent = invalid
        m.seekData = invalid
        m.seekOldContent = invalid
    end if
    m.playing = false
    m.managedLive = false
    m.liveRecoveryRequested = false
    m.pausedVOD = false
    if m.playerOverlay <> invalid then m.playerOverlay.visible = false
    if m.playerBackdrop <> invalid then m.playerBackdrop.visible = false
    if m.playerTick <> invalid then m.playerTick.control = "stop"
    m.startup.control = "stop"
    m.heartbeat.control = "stop"
    m.video.control = "stop"
    m.video.visible = false
    if m.session <> "" then request("DELETE","/api/playback/" + Enc(m.session),invalid,"cleanup",m.sessionConnection)
    m.session = ""
    if restore
        if m.captionRestore <> invalid
            m.video.globalCaptionMode = m.captionRestore
            m.captionRestore = invalid
        end if
        if m.playerReturnDetail <> invalid
            target = m.playerReturnDetail
            m.playerReturnDetail = invalid
            returnToDetail(target)
        else
            restoreView()
        end if
        m.status.text = ""
    end if
end sub

sub returnToDetail(item as object)
    if item = invalid then restoreView() : return
    m.selected = CopyRouteData(item)
    if item.position <> invalid then m.position = item.position else m.position = 0
    cancelBrowse()
    path = "/api/meta/" + Enc(Txt(item.type,"movie")) + "/" + Enc(PresentationMetadataId(item))
    cached = m.cache[path]
    now = CreateObject("roDateTime").asSeconds()
    if cached <> invalid
        if now - cached.time < 300
            showMetadata(cached.data)
            return
        end if
    end if
    rows(Txt(item.seriesName,Txt(item.name)),[],"loading","")
    m.metaPath = path
    request("GET", path, invalid, "meta")
    m.status.text = "Loading details…"
end sub

sub pauseVOD()
    if not m.playing or m.playItem.type = "live" or m.playbackLive = true or m.seeking = true then return
    ' Pause the current Video node in place. Never delete the server session,
    ' clear content, hide video, or replace the paused frame.
    if m.pausedVOD = true or m.video.state = "paused"
        m.directSeekPause = false
        m.video.control = "resume"
        m.pausedVOD = false
    else
        m.video.control = "pause"
        m.pausedVOD = true
    end if
    if m.playerOverlay <> invalid
        m.playerOverlay.visible = true
        m.playerOverlay.opened = true
        m.playerOverlay.setFocus(true)
        updatePlayer()
    end if
end sub

sub seekRestart(delta as integer)
    if not m.playing or m.playItem.type = "live" or m.playbackLive = true then return
    saveProgress()
    seekToPosition(m.position + delta)
end sub

sub seekToPosition(target as double, managed = false as boolean)
    if not m.playing or m.playItem.type = "live" or m.playbackLive = true or m.seeking = true then return
    target = ClampPlayerSeek(target,m.duration)
    if not managed and m.position <> invalid
        if abs(target - m.position) < 0.5 then return
    end if
    if m.playbackMode = "direct" and not managed
        m.directSeekPause = m.pausedVOD = true or m.video.state = "paused"
        m.video.autoplayAfterSeek = not m.directSeekPause
        m.video.seek = target
        return
    end if
    saveProgress()
    m.seeking = true
    m.seekPhase = "replacement"
    m.seekNewSession = ""
    m.seekNewConnection = invalid
    m.seekNewContent = invalid
    m.seekData = invalid
    m.seekFailureMessage = ""
    m.seekTarget = target
    m.seekOldSession = m.session
    m.seekOldConnection = m.sessionConnection
    m.seekOldContent = m.video.content
    m.seekOldPosition = m.position
    if m.video.position > 0 then m.seekOldPosition = m.timelineOffset + m.video.position
    m.seekOldTimelineOffset = m.timelineOffset
    m.seekWasPaused = (m.pausedVOD = true or m.video.state = "paused")
    m.video.control = "pause"
    m.pausedVOD = true
    m.pendingPlayback = true
    m.status.text = "Seeking to " + PlayerTime(target) + "…"
    if m.playerBackdrop <> invalid then m.playerBackdrop.visible = true
    m.video.visible = true
    if m.playerOverlay <> invalid
        m.playerOverlay.visible = true
        m.playerOverlay.opened = true
        m.playerOverlay.setFocus(true)
        updatePlayer()
    end if
    body = PlaybackBody(m.playItem,m.profile,m.config.capabilities,target,m.forced)
    ' Offset replacements use the generated timeline. Existing direct sessions
    ' already took the native-seek branch above.
    body.managed_only = true
    body.append(TrackRequestFields(m.playItem,m.trackPreferences))
    if Txt(m.playItem.audio_language) <> "" then body.audio_language = m.playItem.audio_language
    request("POST","/api/playback",body,"seekplayback")
    m.pendingRequestId = m.generation.toStr() + "-" + m.requestSequence.toStr()
    if m.seekTimer <> invalid
        m.seekTimer.duration = 60
        m.seekTimer.control = "start"
    end if
end sub

sub prepareSeekReplacement(data as object, connection as object)
    if m.seeking <> true
        if data.id <> invalid then request("DELETE","/api/playback/" + Enc(Txt(data.id)),invalid,"cleanup",connection)
        return
    end if
    url = ResolveUrl(connection.base,Txt(data.url))
    if url = ""
        seekReplacementFailed("Seek failed. Playback resumed at the prior position.")
        return
    end if
    m.seekNewSession = Txt(data.id)
    m.seekNewConnection = connection
    m.seekData = data
    content = CreateObject("roSGNode","ContentNode")
    content.url = url
    content.streamFormat = Txt(data.format,"hls")
    content.title = Txt(m.playItem.displayName,Txt(m.playItem.name))
    content.live = false
    m.seekNewContent = content
    beginPrimarySeekFallback()
end sub

' The ready backend session starts on the existing decoder immediately. Keep the
' old backend session/content until success so a failed decoder start can roll back.
sub beginPrimarySeekFallback()
    if m.seeking <> true or m.seekPhase <> "replacement" then return
    if Txt(m.seekNewSession) = "" or m.seekNewContent = invalid
        beginSeekRollback("Seek failed. Playback resumed at the prior position.")
        return
    end if
    if m.seekTimer <> invalid then m.seekTimer.control = "stop"
    m.seekPhase = "primary"
    m.status.text = "Seeking to " + PlayerTime(m.seekTarget) + "…"
    m.video.control = "stop"
    PrepareNativeCaptions(m.video,m.seekData.selected_subtitle <> invalid)
    m.video.content = m.seekNewContent
    m.video.visible = true
    m.video.control = "play"
    if m.seekTimer <> invalid
        m.seekTimer.duration = 25
        m.seekTimer.control = "start"
    end if
end sub

sub seekPrimaryVideoState()
    if m.seeking <> true then return
    if m.seekPhase = "primary"
        if m.video.state = "playing"
            finishSeekSuccess()
        else if m.video.state = "error"
            beginSeekRollback("Seek failed. Playback resumed at the prior position.")
        end if
    else if m.seekPhase = "rollback"
        if m.video.state = "playing"
            relative = m.seekOldPosition - m.seekOldTimelineOffset
            if relative > 0 then m.video.seek = relative
            finishSeekRollback(true)
        else if m.video.state = "error"
            finishSeekRollback(false)
        end if
    end if
end sub

sub finishSeekSuccess()
    if m.seeking <> true then return
    oldSession = m.seekOldSession
    oldConnection = m.seekOldConnection
    data = m.seekData
    m.session = m.seekNewSession
    m.sessionConnection = m.seekNewConnection
    m.timelineOffset = m.seekTarget
    if Txt(data.mode) = "direct" then m.timelineOffset = 0
    m.position = m.seekTarget
    if data.duration <> invalid then m.duration = data.duration
    m.playbackMode = Txt(data.mode)
    m.audioTracks = Bounded(data.audio_tracks,32)
    m.subtitleTracks = Bounded(data.subtitle_tracks,32)
    m.subtitlesSupported = data.subtitles_supported = true
    m.selectedSubtitle = data.selected_subtitle
    m.nativeCaptionName = ""
    m.seeking = false
    m.seekPhase = ""
    m.pendingPlayback = false
    if m.seekTimer <> invalid then m.seekTimer.control = "stop"
    m.pausedVOD = (m.seekWasPaused = true)
    if m.pausedVOD then m.video.control = "pause"
    if oldSession <> "" then request("DELETE","/api/playback/" + Enc(oldSession),invalid,"cleanup",oldConnection)
    m.seekNewSession = ""
    m.seekNewContent = invalid
    m.seekData = invalid
    m.status.text = ""
    applyPlayerSubtitles()
    updatePlayer()
end sub

sub beginSeekRollback(message as string)
    if m.seeking <> true then return
    m.seekFailureMessage = message
    if m.seekTimer <> invalid then m.seekTimer.control = "stop"
    if Txt(m.seekNewSession) <> "" then request("DELETE","/api/playback/" + Enc(m.seekNewSession),invalid,"cleanup",m.seekNewConnection)
    m.seekNewSession = ""
    if m.seekPhase = "primary" and m.seekOldContent <> invalid
        m.seekPhase = "rollback"
        m.video.control = "stop"
        PrepareNativeCaptions(m.video,m.selectedSubtitle <> invalid)
        m.video.content = m.seekOldContent
        m.video.visible = true
        m.video.control = "play"
        if m.seekTimer <> invalid then m.seekTimer.control = "start"
    else
        finishSeekRollback(true)
    end if
end sub

sub finishSeekRollback(recovered as boolean)
    if m.seekTimer <> invalid then m.seekTimer.control = "stop"
    m.pendingPlayback = false
    m.seeking = false
    m.seekPhase = ""
    m.position = m.seekOldPosition
    m.timelineOffset = m.seekOldTimelineOffset
    m.session = m.seekOldSession
    m.sessionConnection = m.seekOldConnection
    m.video.visible = true
    m.pausedVOD = (m.seekWasPaused = true)
    if recovered
        if m.pausedVOD
            m.video.control = "pause"
        else
            m.video.control = "resume"
        end if
        m.status.text = Txt(m.seekFailureMessage,"Seek failed. Playback resumed at the prior position.")
    else
        m.playing = false
        m.pausedVOD = false
        m.video.control = "stop"
        m.video.visible = false
        if Txt(m.seekOldSession) <> "" then request("DELETE","/api/playback/" + Enc(m.seekOldSession),invalid,"cleanup",m.seekOldConnection)
        m.session = ""
        m.heartbeat.control = "stop"
        if m.playerTick <> invalid then m.playerTick.control = "stop"
        if m.playerBackdrop <> invalid then m.playerBackdrop.visible = false
        m.status.text = "Seek failed and playback could not be restored. Choose the source again."
    end if
    m.seekNewContent = invalid
    m.seekData = invalid
    m.seekOldContent = invalid
    if m.playerOverlay <> invalid
        m.playerOverlay.visible = recovered
        m.playerOverlay.opened = recovered
        if recovered then m.playerOverlay.setFocus(true)
        updatePlayer()
    end if
    if not recovered then sourceExhausted("Seek failed and playback could not be restored. Choose the source again.")
end sub

sub seekReplacementFailed(message = "Seek failed. Playback resumed at the prior position." as string)
    if m.seeking <> true then return
    if Txt(m.pendingStartupId) <> "" then cancelBrowse()
    if m.seekPhase = "replacement" and Txt(m.seekNewSession) <> "" and m.seekNewContent <> invalid
        beginPrimarySeekFallback()
    else if m.seekPhase = "primary" or m.seekPhase = "rollback"
        if m.seekPhase = "primary"
            beginSeekRollback(message)
        else
            finishSeekRollback(false)
        end if
    else
        m.seekFailureMessage = message
        beginSeekRollback(message)
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if m.homeInitialLoading = true then return true
    if not press then return false
    if key = "back" and m.parentUnlockPending = true and m.parentAction = "profilemutation"
        m.accountEpoch++
        m.parentUnlockPending = false
        m.parentAction = ""
        m.profileMutation = invalid
        m.authBusy = false
        m.profileEditor.callFunc("open")
        return true
    end if
    if key = "back" and m.parentUnlockPending = true and m.parentAction = "logout"
        m.accountEpoch++
        m.parentUnlockPending = false
        m.parentAction = ""
        m.authBusy = false
        showSettings()
        return true
    end if
    if key = "back" and (m.mode = "streams" or m.mode = "resuming") and m.playing <> true
        if m.nextPrepping = true
            resumeNextTransition()
            return true
        end if
        if m.pendingPlayback = true or m.mode = "resuming"
            cancelAutomaticResume()
            return true
        end if
    end if
    if m.top <> invalid
        if m.top.dialog <> invalid then return false
    end if
    if key = "options" or key = "info"
        if queueMenu() then return true
    end if
    if m.mode = "profiles" and m.profile = "" and key = "back" then return false
    if accountProfileKey(key) then return true
    if m.uiReady = true
        if uiPresentationKey(key) then return true
    end if
    if m.mode = "pairing"
        ' Required sign-in has no alternate page; Back uses Roku app exit.
        if key = "back" then return false
        if key = "left" or key = "right" then return true
    end if
    if m.video.visible and m.playItem.type <> "live" and m.playbackLive <> true
        if key = "replay" or key = "instantreplay"
            seekToPosition(m.position - 10)
            return true
        else if key = "play"
            pauseVOD()
            return true
        end if
    end if
    if not m.video.visible and m.pausedVOD <> true
        if m.discoverActive = true and m.discoverFilters <> invalid and m.discoverFilters.visible
            if m.discoverFilters.hasFocus()
                if key = "down"
                    if m.list <> invalid and m.items.count() > 0 then m.list.setFocus(true)
                    return true
                else if key = "left" and m.discoverFilters.itemFocused mod 4 = 0
                    m.sidebar.setFocus(true)
                    return true
                end if
            else if m.list <> invalid and m.list.hasFocus() and key = "up"
                firstRow = true
                if m.gridActive = true then firstRow = m.list.itemFocused < 4
                if firstRow
                    m.discoverFilters.setFocus(true)
                    return true
                end if
            end if
        end if
        if homeKey(key) then return true
    end if
    if key = "back"
        if m.mode = "pairing"
            accountCancelPair()
            return true
        end if
        if m.pausedVOD = true
            m.pausedVOD = false
            if m.footer <> invalid then m.footer.text = "OK  Open     ←  Navigation     Back  Home     *  My List"
            restoreView()
            m.status.text = ""
            return true
        end if
        if m.video.visible
            cancelBrowse()
            stopPlayback()
            return true
        end if
        if m.mode = "home" then return false
        if m.mode = "settings" and m.profile = "" then return false
        cancelBrowse()
        restoreView()
        return true
    else if key = "options" or key = "info"
        if not m.video.visible
            if m.sidebar <> invalid
                if m.sidebar.hasFocus() then return true
            end if
            if libraryMenu() then return true
            if openFocusedLiveGuide() then return true
            toggleFavorite()
            return true
        end if
    end if
    return false
end function

function homeRevision(kind as string) as integer
    if m.homeRevisions = invalid then m.homeRevisions = {progress:0,favorites:0}
    return m.homeRevisions[kind]
end function

sub homeMutation(origin as object, completed as boolean)
    if origin.method <> "PUT" and origin.method <> "DELETE" and origin.method <> "POST" then return
    if origin.base <> m.config.base or Txt(origin.access_token) <> Txt(m.config.access_token) or origin.account_epoch <> m.accountEpoch then return
    if Txt(m.profile) = "" then return
    prefix = "/api/profiles/" + Enc(m.profile) + "/"
    kind = ""
    if origin.path = prefix + "progress" or origin.path = prefix + "progress/correct" or origin.path = prefix + "continue/visibility" then kind = "progress"
    if origin.path = prefix + "favorites" or left(origin.path,len(prefix + "favorites/")) = prefix + "favorites/" then kind = "favorites"
    if kind = "" then return
    revision = homeRevision(kind)
    m.homeRevisions[kind] = revision + 1
    m.homeDirty = true
    if m.homeDone <> invalid then m.homeDone.delete(kind)
    if completed and m.mode = "home" and m.homeData <> invalid
        ' A revision rejects older GETs that finish after the mutation acknowledgement.
        if kind = "progress"
            request("GET",prefix + "continue/page?limit=13",invalid,"home:progress")
            m.homeDone.delete("recent")
            request("GET","/api/live?view=us&collection=recent&limit=24",invalid,"home:recent")
        else
            m.homeDone.delete("livefavorites")
            request("GET",prefix + "favorites/page?limit=13&exclude_live=true",invalid,"home:" + kind)
        end if
    end if
end sub

' The rail owns no credentials. Its first entry is a presentation-only hook into
' the account chooser; the selected avatar remains a server-provided HTTPS URL.
sub updateProfileNav(item as dynamic)
    if GetInterface(item,"ifAssociativeArray") = invalid then return
    m.profileNav = {name:Txt(item.name,"Profile"),avatar_url:Txt(item.avatar_url)}
    if m.identity <> invalid then m.identity.text = m.profileNav.name
    rebuildNavigation()
end sub

sub rebuildNavigation()
    if m.sidebar = invalid or m.navItems = invalid then return
    prior = m.sidebar.itemFocused
    root = CreateObject("roSGNode","ContentNode")
    for each item in m.navItems
        node = root.createChild("ContentNode")
        node.title = item.name
        if item.action = "profiles"
            node.addFields({isProfile:true,profileName:Txt(m.identity.text,"Profile"),avatarUrl:""})
            if m.profileNav <> invalid
                node.profileName = Txt(m.profileNav.name,"Profile")
                node.avatarUrl = Txt(m.profileNav.avatar_url)
            end if
        end if
    end for
    m.sidebar.content = root
    if prior <> invalid and prior >= 0 and prior < m.navItems.count() then m.sidebar.jumpToItem = prior
end sub

' Home holds five distinct bounded shelves / eleven items each. No requests occur on focus.
sub initHome()
    m.footer = m.top.findNode("footer")
    m.homeRows = m.top.findNode("homeRows")
    m.homeRows.rowLabelFont.size = 18
    m.homePanel = m.top.findNode("homePanel")
    m.sidebar = m.top.findNode("sidebar")
    m.homeTitle = m.top.findNode("homeTitle")
    m.homeRetry = m.top.findNode("homeRetry")
    if m.homeRetry <> invalid then m.homeRetry.observeField("buttonSelected","retryHome")
    m.homeSummary = m.top.findNode("homeSummary")
    if m.homeSummary <> invalid then m.homeSummary.font.size = 20
    m.homeFocusTimer = m.top.findNode("homeFocusTimer")
    if m.homeFocusTimer <> invalid then m.homeFocusTimer.observeField("fire","homeRestoreSettled")
    m.homePosition = [0,0]
    m.homeExpanded = true
    m.homeKeyValue = ""
    m.homeDirty = false
    m.navItems = [{name:"Profile",action:"profiles"},{name:"Home",action:"home"},{name:"Discover",action:"discover"},{name:"Live TV",action:"live"},{name:"My List",action:"favorites"},{name:"Search",action:"search"},{name:"Settings",action:"settings"}]
    rebuildNavigation()
    if m.sidebar <> invalid then m.sidebar.observeField("itemSelected","navSelected")
    if m.homeRows <> invalid
        m.homeRows.observeField("rowItemSelected","homeSelected")
        m.homeRows.observeField("rowItemFocused","homeFocused")
        m.homeRows.observeField("navigation","homeNavigation")
    end if
end sub

sub homeVisible(visible as boolean)
    if visible
        accountHideQr()
        accountLayout(false)
        uiHidePageExtras()
        m.discoverActive = false
        for each node in [m.profileGrid,m.profileActions,m.profilePages,m.profilePageLabel,m.standardList,m.posterGrid,m.sourceList,m.detailActions,m.episodeList,m.channelList]
            if node <> invalid then node.visible = false
        end for
        if m.sourceText <> invalid then m.sourceText.visible = false
    end if
    if m.homePanel <> invalid then m.homePanel.visible = visible
    if visible and m.homeInitialLoading <> true then accountEndLoading()
    if m.heading <> invalid then m.heading.visible = not visible
    if m.footer <> invalid then m.footer.visible = false
    for each id in ["art","detailTitle","detailInfo","description"]
        m[id].visible = false
    end for
    if m.detailPanel <> invalid then m.detailPanel.visible = false
end sub

sub clearHomeCache()
    m.homeKeyValue = ""
    m.liveFavoriteItems = invalid
    m.uiHeroTried = {}
    m.uiHeroTriedOrder = []
    m.uiHomeActionKey = ""
    m.homeData = invalid
    m.cache = {}
    m.cacheKeys = []
end sub

sub showHome()
    if m.homeRows = invalid then return
    key = m.config.base + "|" + Txt(m.config.account_id) + "|" + m.profile
    now = CreateObject("roDateTime").asSeconds()
    if m.homeKeyValue <> key
        m.views = []
        clearHomeCache()
        m.homePosition = [0,0]
        m.homeExpanded = true
        m.homeAutoPick = true
    else
        ' Back/return must never choose a different shelf.
        m.homeAutoPick = false
    end if
    cold = m.homeData = invalid
    refresh = cold
    if not refresh then refresh = now - m.homeTime > 120 or m.homeDirty = true
    if refresh
        ' Same-profile refresh keeps cached cards/cursor visible until each replacement arrives.
        if cold then m.homeData = [[],[],[],[],[],[],[]]
        m.homeStates = ["Loading your history…","Finding trending movies…","Finding popular series…","Loading live channels…","Loading your list…","Loading favorite channels…","Loading recently watched channels…"]
        m.homeFailed = [false,false,false,false,false,false,false]
        m.homeDone = {}
        m.homeTime = now
        m.homeDirty = false
    end if
    if not refresh and m.mode <> "home"
        ' Small personal shelves refresh on return so phone corrections become visible.
        ' Keep current cards and focus while the replacement page arrives.
        m.homeDone.delete("progress")
        m.homeDone.delete("favorites")
        m.homeDone.delete("livefavorites")
    end if
    m.homeKeyValue = key
    m.mode = "home"
    if cold then startupHomeBegin()
    if m.footer <> invalid then m.footer.text = "OK  Open     *  My List     ↑ ↓  Browse rows     ←  Menu"
    m.heading.text = "Home"
    m.status.text = ""
    homeVisible(true)
    m.homeRestoring = true
    if cold or m.homeRoot = invalid
        root = CreateObject("roSGNode","ContentNode")
        m.homeRoot = root
        m.homeRowKeys = []
        for each i in HomeShelfOrder()
            if m.homeData[i].count() > 0
                root.appendChild(homeRow(i))
                m.homeRowKeys.push(i)
            end if
        end for
        m.homeRows.content = root
    end if
    homeRestore()
    homeHero()
    if acknowledgementMayFocus() then uiHomeFocus()
    if not m.homeDone.doesExist("progress") then request("GET","/api/profiles/" + Enc(m.profile) + "/continue/page?limit=13",invalid,"home:progress")
    if not m.homeDone.doesExist("favorites") then request("GET","/api/profiles/" + Enc(m.profile) + "/favorites/page?limit=13&exclude_live=true",invalid,"home:favorites")
    if not m.homeDone.doesExist("recent") then request("GET","/api/live?view=us&collection=recent&limit=24",invalid,"home:recent")
    if not m.homeDone.doesExist("live") then request("GET","/api/live?view=us&offset=0&limit=12&search=",invalid,"home:live")
    if not m.homeDone.doesExist("movie") or not m.homeDone.doesExist("series") then request("GET","/api/catalogs",invalid,"home:catalogs")
end sub

function homeValues(index as integer) as object
    return m.homeData[index]
end function

function homeRow(index as integer) as object
    titles = ["Continue Watching","Trending Movies","Popular Series","Live Now","My List","Favorite Channels","Recently Watched Live TV"]
    row = CreateObject("roSGNode","ContentNode")
    row.title = ucase(titles[index])
    for each item in homeValues(index)
        node = row.createChild("ContentNode")
        UiCardContent(node,item)
    end for
    return row
end function

function homeProgress(item as object) as float
    if item.duration = invalid or item.position = invalid then return -1
    if item.duration <= 0 then return -1
    fraction = item.position / item.duration
    if fraction < 0 then fraction = 0
    if fraction > 1 then fraction = 1
    return fraction
end function

sub homeRestore()
    m.homeRestoring = true
    r = m.homePosition[0]
    c = m.homePosition[1]
    if r < 0 or r > 6 then r = 0
    if c < 0 then c = 0
    displayRow = -1
    if m.homeRowKeys <> invalid
        for i = 0 to m.homeRowKeys.count()-1
            if m.homeRowKeys[i] = r then displayRow = i
        end for
        if displayRow < 0 and m.homeRowKeys.count() > 0
            displayRow = 0
            r = m.homeRowKeys[0]
        end if
    end if
    if c >= homeValues(r).count() then c = homeValues(r).count()-1
    if c < 0 then c = 0
    m.homePosition = [r,c]
    if r <> uiHomeHeroRow() then m.homeExpanded = false
    if displayRow >= 0 then m.homeRows.jumpToRowItem = [displayRow,c]
    if m.homeFocusTimer <> invalid then m.homeFocusTimer.control = "start"
end sub

sub homeRestoreSettled()
    if m.homeRestoring <> true then return
    ' Reassert after native content-reset focus events have drained.
    if m.mode = "home" and m.homeRowKeys <> invalid
        for i = 0 to m.homeRowKeys.count()-1
            if m.homeRowKeys[i] = m.homePosition[0] then m.homeRows.jumpToRowItem = [i,m.homePosition[1]]
        end for
    end if
    m.homeRestoring = false
    uiQueueCardArtwork()
end sub

sub homeNavigation()
    if m.mode <> "home" or not m.homeRows.hasFocus() then return
    ' Real remote input takes precedence over the saved return cursor. Cancel
    ' both the timer and an already queued callback before native focus moves.
    if m.homeFocusTimer <> invalid then m.homeFocusTimer.control = "stop"
    m.homeRestoring = false
    m.homeAutoPick = false
end sub

sub homeDefaultShelf()
    if m.homeAutoPick <> true then return
    if m.top.dialog <> invalid then m.homeAutoPick = false
    if m.sidebar <> invalid
        if m.sidebar.hasFocus() then m.homeAutoPick = false
    end if
    if m.homeAutoPick <> true then return
    kinds = ["progress","movie","series","live","favorites","livefavorites","recent"]
    for each i in HomeShelfOrder()
        if m.homeData[i].count() > 0
            m.homePosition = [i,0]
            earlierPending = false
            for each j in HomeShelfOrder()
                if j = i then exit for
                if not m.homeDone.doesExist(kinds[j]) then earlierPending = true
            end for
            m.homeAutoPick = earlierPending
            return
        end if
    end for
end sub

sub homeResponse(kind as string, result as object)
    if m.mode <> "home" or m.homeData = invalid then return
    if m.homeKeyValue <> m.config.base + "|" + Txt(m.config.account_id) + "|" + m.profile then return
    if kind = "catalogs"
        for each media in ["movie","series"]
            if not m.homeDone.doesExist(media)
                chosen = invalid
                if result.ok
                    for each catalog in Bounded(result.data,100)
                        if catalog.type = media
                            chosen = catalog
                            exit for
                        end if
                    end for
                end if
                if chosen <> invalid
                    request("GET","/api/discover?type=" + media + "&addon_id=" + Enc(Txt(chosen.addon_id)) + "&catalog=" + Enc(Txt(chosen.id)) + "&skip=0",invalid,"home:" + media)
                else
                    homeResponse(media,{ok:false})
                end if
            end if
        end for
        return
    end if
    slots = {progress:0,movie:1,series:2,live:3,favorites:4,livefavorites:5,recent:6}
    if not slots.doesExist(kind) then return
    if m.homeDone.doesExist(kind) then return
    index = slots[kind]
    retainedItem = invalid
    if m.homePosition[0] = index then retainedItem = homeCurrent()
    m.homeDone[kind] = true
    m.homeStates[index] = "Nothing here yet."
    if m.homeFailed = invalid then m.homeFailed = [false,false,false,false]
    m.homeFailed[index] = not result.ok
    if result.ok
        incoming = result.data
        if kind = "favorites"
            if GetInterface(incoming,"ifAssociativeArray") <> invalid then incoming = incoming.items
            m.liveFavoriteItems = Bounded(incoming,40)
            request("GET","/api/live?view=us&collection=favorites&limit=24",invalid,"home:livefavorites")
        end if
        if kind = "progress"
            if GetInterface(incoming,"ifAssociativeArray") <> invalid then incoming = incoming.items
            incoming = ContinueWatchingItems(incoming)
        end if
        if kind = "recent" or kind = "livefavorites" then incoming = result.data.channels
        if kind = "favorites" then incoming = OnDemandItems(incoming)
        if kind = "movie" or kind = "series" then incoming = result.data.metas
        if kind = "live" then incoming = result.data.channels
        values = []
        for each item in Bounded(incoming,12)
            if type(item) = "roAssociativeArray"
                if Txt(item.id) <> ""
                    if kind = "movie" or kind = "series" or kind = "live" then item.type = kind
                    values.push(item)
                end if
            end if
        end for
        ' Keep longer collections reachable without retaining an unbounded shelf.
        if values.count() = 12
            values.pop()
            actions = {progress:"progress",favorites:"favorites",movie:"discovermovie",series:"discoverseries",live:"live",livefavorites:"livefavorites",recent:"recentlive"}
            values.push({name:"View all",action:actions[kind],releaseInfo:"MORE",description:"Open the full collection. Your place on Home will be kept."})
        end if
        m.homeData[index] = values
        ' Keep the selected title across server reordering; missing titles clamp below.
        if retainedItem <> invalid
            if Txt(retainedItem.id) <> "" and Txt(retainedItem.type) <> ""
                for column = 0 to values.count()-1
                    candidate = values[column]
                    if Txt(candidate.id) = Txt(retainedItem.id) and Txt(candidate.type) = Txt(retainedItem.type)
                        m.homePosition = [index,column]
                        exit for
                    end if
                end for
            end if
        end if
    else
        if kind = "favorites" then homeResponse("livefavorites",{ok:false})
        m.homeStates[index] = "This shelf is unavailable. Try Search, Live TV or Settings."
    end if
    ' Replace only the completed row. Never take remote focus from the sidebar.
    m.homeRestoring = true
    displayRow = -1
    if m.homeRowKeys = invalid then m.homeRowKeys = []
    for i = 0 to m.homeRowKeys.count()-1
        if m.homeRowKeys[i] = index then displayRow = i
    end for
    if m.homeData[index].count() > 0
        if displayRow >= 0
            m.homeRoot.replaceChild(homeRow(index),displayRow)
        else
            ' HTTP completion order must not become navigation order. Keep the
            ' native root and existing rows; only insert this logical shelf.
            insertion = 0
            orderedKeys = []
            for each logicalKey in m.homeRowKeys
                if HomeShelfRank(logicalKey) < HomeShelfRank(index)
                    orderedKeys.push(logicalKey)
                    insertion++
                end if
            end for
            orderedKeys.push(index)
            for each logicalKey in m.homeRowKeys
                if HomeShelfRank(logicalKey) > HomeShelfRank(index) then orderedKeys.push(logicalKey)
            end for
            m.homeRoot.insertChild(homeRow(index),insertion)
            m.homeRowKeys = orderedKeys
        end if
    else if displayRow >= 0
        m.homeRoot.removeChildIndex(displayRow)
        m.homeRowKeys.delete(displayRow)
        if m.homePosition[0] = index and m.homeRowKeys.count() > 0
            nextRow = displayRow
            if nextRow >= m.homeRowKeys.count() then nextRow = m.homeRowKeys.count()-1
            m.homePosition = [m.homeRowKeys[nextRow],m.homePosition[1]]
        end if
    end if
    if m.homeRowKeys.count() = 0
        m.status.text = "Loading…"
        if m.homeDone.count() >= 7 then m.status.text = "No titles yet. Search or try again."
    else
        m.status.text = ""
    end if
    homeDefaultShelf()
    homeRestore()
    homeHero()
end sub

function homeCurrent() as dynamic
    if m.homeData = invalid then return invalid
    r = m.homePosition[0]
    c = m.homePosition[1]
    if r < 0 or r > 6 then return invalid
    values = homeValues(r)
    if c < 0 or c >= values.count() then return invalid
    return values[c]
end function

sub homeFocused()
    if m.mode <> "home" or m.homeRestoring = true then return
    coordinates = m.homeRows.rowItemFocused
    if coordinates <> invalid
        if coordinates.count() = 2
            if m.homeRowKeys = invalid then return
            if coordinates[0] < 0 or coordinates[0] >= m.homeRowKeys.count() then return
            logicalRow = m.homeRowKeys[coordinates[0]]
            if logicalRow <> m.homePosition[0] or coordinates[1] <> m.homePosition[1] then m.homeAutoPick = false
            m.homePosition = [logicalRow,coordinates[1]]
            if m.homeRows.hasFocus() then m.homeExpanded = logicalRow = uiHomeHeroRow()
        end if
    end if
    uiHomeLayout()
    ' Update the hero immediately on focus, rather than after the artwork timer.
    homeHero()
    uiQueueCardArtwork()
end sub

sub retryHome()
    m.homeDirty = true
    home()
end sub

sub homeHero()
    if m.homeExpanded <> true then return
    if m.homeRetry <> invalid
        failed = false
        for each flag in m.homeFailed
            if flag then failed = true
        end for
        empty = m.homeRowKeys.count() = 0 and m.homeDone.count() >= 7
        m.homeRetry.visible = failed or empty or m.homeRetry.hasFocus()
        m.homeRetry.translation = [1030,64]
        if empty
            uiEmpty("Your library is empty","Add your services in Settings, or search for a title.")
            if failed then uiEmpty("Your library couldn't load","Check your connection or try again.")
            m.homeRetry.translation = [540,494]
        else
            m.emptyState.visible = false
        end if
    end if
    item = homeCurrent()
    if item = invalid
        m.homeTitle.text = ""
        m.uiHomeAwaitingContent = true
        m.homeActions.visible = false
        if m.homeHeroPanel <> invalid then m.homeHeroPanel.model = {name:"VIPTV",type:"",description:""}
        m.uiHeroFingerprint = ""
        return
    end if
    m.homeTitle.text = Txt(item.seriesName,Txt(item.name,"Untitled"))
    m.homeSummary.text = Txt(item.description)
    if m.homeHeroPanel <> invalid
        hero = {}
        hero.append(item)
        path = "/api/meta/" + Enc(Txt(item.type,"movie")) + "/" + Enc(PresentationMetadataId(item))
        cached = m.cache[path]
        if cached <> invalid
            meta = cached.data.meta
            if meta <> invalid
                for each field in ["background","backdrop","description","overview","genres","runtime","releaseInfo"]
                    if hero[field] = invalid or Txt(hero[field]) = ""
                        if meta[field] <> invalid then hero[field] = meta[field]
                    end if
                end for
            end if
        end if
        if m.uiHeroMetadata <> invalid and m.uiHeroMetadata[path] <> invalid
            for each field in ["background","backdrop","description","overview","genres","runtime","releaseInfo"]
                if hero[field] = invalid or Txt(hero[field]) = ""
                    if m.uiHeroMetadata[path][field] <> invalid then hero[field] = m.uiHeroMetadata[path][field]
                end if
            end for
        end if
        hero.name = m.homeTitle.text
        hero.context = PresentationContext(item)
        hero.background = PresentationBackdrop(hero)
        if hero.background = "" and m.uiLandscapeCache[path] <> invalid then hero.background = m.uiLandscapeCache[path]
        hero.backdrop = hero.background
        hero.progressFraction = homeProgress(item)
        fingerprint = FormatJson(hero)
        if m.uiHeroFingerprint <> fingerprint
            m.uiHeroFingerprint = fingerprint
            m.homeHeroPanel.model = hero
        end if
        uiHomeArtwork(PresentationMetadataId(item),Txt(item.type),PresentationBackdrop(hero))
        uiHomeActions(item)

    end if
    if m.uiHomeAwaitingContent = true
        m.uiHomeAwaitingContent = false
        if m.homeExpanded = true and m.homeRows.hasFocus() and acknowledgementMayFocus() then uiHomeFocus()
    end if
    uiFocusChanged()
end sub

sub homeSelected()
    m.homeAutoPick = false
    coordinates = m.homeRows.rowItemSelected
    if coordinates.count() <> 2 then return
    if m.homeRowKeys = invalid then return
    if coordinates[0] < 0 or coordinates[0] >= m.homeRowKeys.count() then return
    m.homePosition = [m.homeRowKeys[coordinates[0]],coordinates[1]]
    item = homeCurrent()
    if item = invalid then return
    selectItem(item)
end sub

sub navSelected()
    m.homeAutoPick = false
    index = m.sidebar.itemSelected
    if index < 0 or index >= m.navItems.count() then return
    if m.navItems[index].action <> "home" then saveView()
    m.top.setFocus(true)
    selectItem(m.navItems[index])
    uiFocusChanged()
end sub

function homeKey(key as string) as boolean
    ' The profile-entry OK can bubble after its selection handler opens Home.
    ' Actual card/sidebar selections already disable auto-pick in their observers.
    if m.mode = "home" and key <> "OK" and key <> "select" then m.homeAutoPick = false
    if m.sidebar = invalid then return false
    if m.gatewayActive = true then return false
    if m.top.dialog <> invalid then return false
    if m.mode = "home"
        if uiHomeKey(key) then return true
    end if
    if m.mode = "home" and m.homeRetry <> invalid
        if m.homeRetry.hasFocus() and key = "up"
            m.homeRows.setFocus(true)
            return true
        end if
        if key = "down" and m.homeRetry.visible
            m.homeRetry.setFocus(true)
            return true
        end if
    end if
    if m.sidebar.hasFocus()
        ' A second Back from Home leaves the scene instead of trapping focus.
        if key = "back" and m.mode = "home" then return false
        if key = "right" or key = "back"
            if m.mode = "epg"
                m.epgGrid.callFunc("resume")
            else if m.mode = "home"
                homeRestore()
                uiHomeFocus()
            else
                m.list.setFocus(true)
            end if
            return true
        end if
    else if key = "left" or (key = "back" and m.mode = "home")
        if m.mode = "detail" and key = "left" and m.list.itemFocused > 0 then return false
        if m.mode = "episodes" and key = "left" and m.episodeList.hasFocus() and m.list.itemFocused mod 4 <> 0 then return false
        if m.gridActive = true and m.mode <> "home" and key = "left"
            if m.list.itemFocused mod 4 <> 0 then return false
        end if
        if m.mode = "home" and key = "left"
            if m.homePosition[1] > 0 then return false
        end if
        if m.pendingPlayback = true then cancelBrowse()
        m.sidebar.setFocus(true)
        return true
    end if
    return false
end function

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

sub acceptPlayback(data as object,origin as object)
        uiBusy(false)
        m.session = Txt(data.id)
        if m.nextPrepping = true or m.nextTransitionSession <> ""
            if m.nextTransitionSession <> "" and m.nextTransitionSession <> m.session
                request("DELETE","/api/playback/" + Enc(m.nextTransitionSession),invalid,"cleanup",m.nextTransitionConnection)
            end if
            m.nextTransitionSession = ""
            m.nextTransitionConnection = invalid
            m.nextPrepping = false
        end if
        m.managedLive = data.managed_live = true
        m.liveGeneration = data.generation
        m.liveRecoveryRequested = false
        m.liveHeartbeatFailures = 0
        if m.managedLive then m.heartbeat.duration = 3 else m.heartbeat.duration = 15
        m.audioTracks = Bounded(data.audio_tracks,32)
        m.subtitleTracks = Bounded(data.subtitle_tracks,32)
        m.subtitlesSupported = data.subtitles_supported = true
        m.selectedSubtitle = data.selected_subtitle
        for each track in m.audioTracks
            if track.selected = true
                language = StablePreferenceText(track.language,16)
                if language <> "" then m.playItem.audio_language = lcase(language)
            end if
        end for
        m.sessionConnection = origin
        url = ResolveUrl(origin.base,Txt(data.url))
        if url = ""
            m.status.text = "Server returned an unsupported playback URL."
            stopPlayback()
            return
        end if
        content = CreateObject("roSGNode","ContentNode")
        content.url = url
        content.streamFormat = Txt(data.format,"hls")
        content.title = Txt(m.playItem.displayName,Txt(m.playItem.name))
        m.playbackLive = m.playItem.type = "live"
        if data.live <> invalid then m.playbackLive = data.live
        content.live = m.playbackLive
        ' Jellyfin-derived caption ordering: Off→On must happen before content
        ' starts. Waiting for availableSubtitleTracks can otherwise deadlock on Roku.
        if m.captionRestore = invalid then m.captionRestore = m.video.globalCaptionMode
        m.nativeCaptionName = ""
        ApplyProfileCaptionStyle(m.video, data.preferences)
        PrepareNativeCaptions(m.video, data.selected_subtitle <> invalid)
        m.directSeekPause = false
        m.video.autoplayAfterSeek = true
        m.video.content = content
        m.timelineOffset = 0
        m.resumePosition = data.position
        if Txt(data.mode) <> "direct"
            ' FFmpeg has already sought the input; generated HLS starts at zero.
            m.timelineOffset = data.position
            m.resumePosition = invalid
        end if
        if data.duration <> invalid then m.duration = data.duration
        m.playbackMode = Txt(data.mode)
        uiHidePageExtras()
        if m.playerBackdrop <> invalid then m.playerBackdrop.visible = true
        m.video.visible = true
        m.playing = true
        if m.playerOverlay <> invalid
            m.playerOverlay.visible = true
            m.playerOverlay.opened = true
            m.playerOverlay.setFocus(true)
            updatePlayer()
            m.playerTick.control = "start"
        else
            m.top.setFocus(true)
        end if
        m.playStartClock = CreateObject("roTimespan")
        m.playStartClock.mark()
        m.video.control = "play"
        applyPlayerSubtitles()
        m.startup.control = "start"
        m.heartbeat.control = "start"
end sub

sub requestLiveRecovery()
    if m.managedLive <> true or not m.playing or Txt(m.session) = "" or m.liveRecoveryRequested = true then return
    m.liveRecoveryRequested = true
    m.startup.control = "stop"
    m.video.control = "stop"
    m.status.text = "Reconnecting channel…"
    uiBusy(true)
    request("POST","/api/playback/" + Enc(m.session) + "/recover",{generation:m.liveGeneration},"sideliverecover",m.sessionConnection)
end sub

sub managedLiveResponse(result as object,origin as object)
    if m.managedLive <> true or not m.playing or Txt(m.session) = "" then return
    expected = "/api/playback/" + Enc(m.session)
    if origin.path <> expected + "/heartbeat" and origin.path <> expected + "/recover" then return
    if not result.ok
        m.liveHeartbeatFailures++
        if m.liveHeartbeatFailures >= 3
            stopPlayback(false)
            sourceExhausted("Connection to the server was lost. Try again.")
        end if
        return
    end if
    m.liveHeartbeatFailures = 0
    data = result.data
    if data.managed_live <> true then return
    if data.state = "failed"
        stopPlayback(false)
        message = "No playable backup is available for this channel. Try again later."
        if data.reason = "recovery_budget_exhausted" then message = "This channel reached its recovery limit. Try again later."
        if data.reason = "recovery_deadline_exceeded" then message = "The backup took too long to start. Try again later."
        if data.reason = "connections_busy" then message = "All backup connections are busy. Try again shortly."
        sourceExhausted(message)
    else if data.state = "recovering"
        m.status.text = "Reconnecting channel…"
        uiBusy(true)
    else if data.state = "playing" and data.generation > m.liveGeneration
        if Txt(data.playback.id) <> m.session then return
        m.video.control = "stop"
        acceptPlayback(data.playback,m.sessionConnection)
        m.status.text = ""
    end if
end sub

function HomeShelfOrder() as object
    return [0,6,1,2,3,4,5]
end function

function HomeShelfRank(key as integer) as integer
    for i = 0 to 6
        if HomeShelfOrder()[i] = key then return i
    end for
    return 7
end function

sub applyEpisodeProgress(result as object, preserveNavigation = false as boolean)
    if m.selected = invalid or m.episodes = invalid then return
    if preserveNavigation and not result.ok then return
    records = []
    if result.ok then records = Bounded(result.data,2000)
    byId = {} : byCoordinates = {}
    for each record in records
        if record.type = "series"
            id = Txt(record.id)
            if not byId.doesExist(id) then byId[id] = record
            if Txt(record.series_id) = Txt(m.selected.id)
                key = Txt(record.season)+":"+Txt(record.episode)
                if not byCoordinates.doesExist(key) then byCoordinates[key] = record
            end if
        end if
    end for
    latest = invalid
    latestTime = -1
    for each episode in m.episodes
        record = byId[Txt(episode.id)]
        if record = invalid then record = byCoordinates[Txt(episode.season)+":"+Txt(episode.episode)]
        episode.watched = false
        episode.position = 0
        if record <> invalid
            for each key in ["position","duration","source_addon_id","source_name","source_fingerprint"]
                if record[key] <> invalid then episode[key] = record[key]
            end for
            episode.watched = record.watched = true or UiProgressFraction(record) >= 0.95
            if record.updated_at <> invalid
                if record.updated_at > latestTime
                    latestTime = record.updated_at
                    latest = episode
                end if
            end if
        end if
    end for
    if preserveNavigation
        ' A correction refresh owns badges/progress, not subsequent remote navigation.
        ' Non-entering rows retain the focused episode and leave sidebar/dialog focus alone.
        showEpisodes(m.episodeOffset,false)
        return
    end if
    target = latest
    if latest <> invalid
        if latest.watched = true
            found = false
            now = CreateObject("roDateTime").asSeconds()
            for each episode in m.episodes
                if found and episode.watched <> true and Txt(episode.season) <> "0"
                    released = CreateObject("roDateTime")
                    released.fromISO8601String(Txt(episode.released))
                    if Txt(episode.released) = "" or released.asSeconds() <= now
                        target = episode
                        exit for
                    end if
                end if
                if Txt(episode.id) = Txt(latest.id) then found = true
            end for
        end if
        m.episodeSeason = Txt(target.season)
    end if
    offset = 0
    if target <> invalid
        seasonIndex = 0
        for each episode in m.episodes
            if Txt(episode.season) = Txt(m.episodeSeason)
                if Txt(episode.id) = Txt(target.id)
                    offset = int(seasonIndex / 80) * 80
                    exit for
                end if
                seasonIndex++
            end if
        end for
    end if
    showEpisodes(offset)
    if target <> invalid
        for i = 0 to m.items.count()-1
            if Txt(m.items[i].id) = Txt(target.id)
                m.episodeList.jumpToItem = i
                if acknowledgementMayFocus() then m.episodeList.setFocus(true)
                exit for
            end if
        end for
    end if
end sub

sub cancelAutomaticResume()
    cancelBrowse()
    m.pendingPlayback = false
    m.manualSources = true
    m.resumeSourcePreference = invalid
    m.automaticContinuation = false
    m.continuationSourcePreference = invalid
    m.status.text = ""
    uiBusy(false)
    if m.streams.count() > 0
        rows("Choose a source",m.streams,"streams","")
        uiSourceHeader()
        m.sourceList.setFocus(true)
    else
        findStreams(m.playItem,true)
    end if
end sub

sub showPlaybackPreferences(prefs as object)
    m.sourcePreferences = prefs
    m.sourcePreferencesProfile = m.profile
    languages = [{name:"English",value:"en"},{name:"Spanish",value:"es"},{name:"French",value:"fr"},{name:"German",value:"de"},{name:"Italian",value:"it"},{name:"Portuguese",value:"pt"},{name:"Japanese",value:"ja"},{name:"Korean",value:"ko"},{name:"Chinese",value:"zh"},{name:"Hindi",value:"hi"},{name:"Arabic",value:"ar"}]
    switches = [{name:"On",value:true},{name:"Off",value:false}]
    definitions = [
        {name:"Preferred audio",key:"audio_language",options:languages},
        {name:"Preferred subtitles",key:"subtitle_language",options:languages},
        {name:"Start with subtitles",key:"subtitles_enabled",options:switches},
        {name:"Subtitle size",key:"subtitle_size",options:[{name:"Small",value:"small"},{name:"System default",value:"normal"},{name:"Large",value:"large"}]},
        {name:"Subtitle appearance",key:"subtitle_style",options:[{name:"System default",value:"system"},{name:"Text with shadow",value:"shadow"},{name:"White text on black",value:"opaque"}]},
        {name:"Maximum quality",key:"quality",options:[{name:"Auto",value:"auto"},{name:"1080p",value:"1080p"},{name:"720p",value:"720p"},{name:"480p",value:"480p"}]}
    ]
    values = []
    for each definition in definitions
        selectedLabel = ""
        for each option in definition.options
            if option.value = prefs[definition.key] then selectedLabel = option.name
        end for
        values.push({name:definition.name,description:selectedLabel,action:"preferencechoice",preferenceKey:definition.key,options:definition.options})
    end for
    rows("Playback preferences",values,"preferences","Applies to your next playback. Manual track choices take priority.")
end sub
