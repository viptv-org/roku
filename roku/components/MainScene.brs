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
    origin = Txt(m.config.base, "")
    if origin = "" then origin = "Not set"
    ' The origin-locked production package has no server editor; every other
    ' build (including the public flavor) lets the household point the client
    ' at any compatible backend.
    server = {name:"Server",action:"server",description:origin}
    values = [
        {name:"Switch profile",action:"profiles",description:"Choose who's watching."},
        {name:"Playback preferences",action:"playbackpreferences",description:"Audio, subtitles and quality for this profile."},
        {name:"Manage profiles",action:"manageprofiles",description:"Add, rename, choose avatars or delete profiles."}
    ]
    if m.config.locked <> true then values.push(server)
    values.push({name:"About VIPTV",action:"about",description:"Version " + InstalledAppVersion() + chr(10) + origin})
    values.push({name:"Addons",action:"addons",description:"Manage addons shared by your account."})
    values.push({name:"Sign out",action:"signout",description:"Sign out of VIPTV on this TV."})
    if m.profile = ""
        entryValues = []
        if m.config.locked <> true then entryValues.push(server)
        entryValues.push({name:"Sign in",action:"pair"})
        rows("VIPTV",entryValues,"settings","")
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
    if m.keyboardKind = "server"
        if result.accepted and result.text.Trim() <> ""
            base = AccountOrigin(result.text.Trim())
            if base = ""
                m.status.text = "Enter an HTTP or HTTPS origin without a path, for example https://example.com"
                showSettings()
                return
            end if
            if base <> Txt(m.config.base)
                ' A different server invalidates every stored credential, the
                ' remembered profile, and any in-flight request against the old origin.
                m.config.base = base
                stopPlayback()
                accountReset()
                accountCancelCredentials()
                request("CONFIG_SAVE","",m.config,"sideconfig")
            end if
            accountConnect()
        else
            showSettings()
        end if
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
