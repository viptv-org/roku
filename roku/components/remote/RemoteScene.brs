sub init()
    m.top.backgroundURI = ""
    for each id in ["librarySheet","filterPage","passwordForm","libraryHeader","navigation","heading","hero","backdrop","heroLogo","heroTitle","heroMeta","heroDescription","actions","filters","shelves","grid","rows","message","skeleton","pairing","pairAddress","pairCode","qr","drawer","drawerPanel","drawerTitle","drawerSubtitle","drawerRows","drawerMessage","drawerMotion","drawerSlide","networkTick","pollTick","heroTick","player","playerInput","playerUi","playerTitle","playerTime","playerProgress","playerActions","hideControls","settingsSidebar","settingsNav"]
        m[id] = m.top.findNode(id)
    end for
    m.epoch = 1
    m.generation = 1
    m.sequence = 0
    m.sourceEpoch = 0
    m.searchTerm = ""
    m.profileUiVersion = 0
    m.profileForm = invalid
    m.pinUiVersion = 0
    m.pinForm = invalid
    m.searchVersion = 0
    m.searchChannelVersion = 0
    m.searchMediaAllowed = false
    m.searchChannelsAllowed = false
    m.searchFailures = {}
    m.searchMediaRows = []
    m.searchChannelPages = []
    m.searchPagingFocus = invalid
    m.searchPagingDirection = ""
    m.searchExpectedFocus = invalid
    m.libraryPages = []
    m.libraryCursors = []
    m.libraryFirst = 0
    m.libraryRefresh = invalid
    m.libraryRefreshDue = 0
    m.libraryRevisionPending = false
    m.catalogExpectedFocus = invalid
    m.restoreKey = invalid
    m.catalogVersion = 0
    m.liveExpectedFocus = invalid
    m.liveFocusIndex = 0
    m.livePagingDirection = ""
    m.liveGuideRefreshDue = 0
    m.liveVersion = 0
    m.liveFailureText = ""
    m.liveRetryTag = ""
    m.calendarVersion = 0
    m.episodeVersion = 0
    m.episodeFailed = invalid
    m.heroIndex = 0
    m.heroSlideDue = 0
    m.backdrop.observeField("loadStatus","rHeroReady")
    m.heroLogo.observeField("loadStatus","rLogoReady")
    m.historyClear = m.top.findNode("historyClear")
    m.historyClear.observeField("itemSelected","rHistoryClearSelected")
    m.entryServer = m.top.findNode("entryServer")
    m.entryServer.observeField("itemSelected","rEntryServerSelected")
    m.librarySheet.observeField("submitted","rLibrarySheetSubmit")
    m.librarySheet.observeField("dismissed","rLibrarySheetDismiss")
    m.filterPage.observeField("submitted","rFiltersSubmit")
    m.filterPage.observeField("cancelled","rFiltersCancel")
    m.passwordForm.observeField("submitted","rPasswordSubmit")
    m.passwordForm.observeField("cancelled","rPasswordCancel")
    m.passwordForm.observeField("serverRequested","rPasswordServer")
    m.keyboard = m.top.findNode("keyboard")
    m.formDialog = m.top.findNode("formDialog")
    m.formEditing = false
    m.formOpener = invalid
    m.formDialog.observeField("submitted","rFormSubmit")
    m.formDialog.observeField("cancelled","rTextCancel")
    m.formDialog.observeField("editRequested","rFormEdit")
    m.sourceQuality = invalid
    m.sourceProvider = ""
    m.sourceStreams = []
    m.sourceBest = ""
    m.sourceFilters = m.top.findNode("sourceFilters")
    m.sourceFilters.observeField("itemSelected","rSourceFilterSelected")
    m.providerFilters = m.top.findNode("providerFilters")
    m.providerFilters.observeField("itemSelected","rProviderFilterSelected")
    m.retryBar = m.top.findNode("retryBar")
    m.retryBar.observeField("itemSelected","rRetrySelected")
    m.catalogLayoutTick = m.top.findNode("catalogLayoutTick")
    m.catalogLayoutTick.observeField("fire","rCatalogEnsureVisible")
    m.top.observeField("focusedChild","rCatalogQueueVisibility")
    m.searchTick = m.top.findNode("searchTick")
    m.keyboard.observeField("submitted","rTextDone")
    m.keyboard.observeField("cancelled","rTextCancel")
    m.keyboard.observeField("text","rTextChanged")
    m.keyboard.observeField("exitRight","rSearchResultsFocus")
    m.searchTick.observeField("fire","rSearchSubmit")
    m.pending = {}
    m.queue = []
    m.workers = []
    m.running = {}
    m.retryAuth = []
    m.snapshots = []
    m.homeRefreshPending = false
    m.homeRenderVersion = 0
    m.homeFocusClock = CreateObject("roTimespan")
    m.homeLastFocusTime = -1000
    m.homeRebuilding = false
    m.profilesRefreshPending = false
    m.bootstrapScope = invalid
    m.config = {base:"",access_token:"",refresh_token:"",capabilities:{max_width:1280,max_height:720,h264:true,aac:true}}
    m.profile = ""
    m.route = "startup"
    m.deferredBootstrap = invalid
    m.bootstrapDeferred = false
    m.resumePairingAfterServer = false
    m.refreshDue = 0
    m.revisionDue = rNow()+30
    m.revisions = invalid
    m.homeDue = 0
    m.discovery = invalid
    m.pairChallenge = invalid
    m.playback = invalid
    m.admission = invalid
    m.replacement = invalid
    m.nextCard = invalid
    m.lastProgress = 0
    m.drawerKind = ""
    m.drawerStack = []
    m.drawerClosing = false
    m.drawerMotion.observeField("state","rDrawerMotionChanged")
    m.menuMotion = m.top.findNode("menuMotion")
    m.menuMotion.observeField("state","rMenuMotionChanged")
    m.featured = []
    m.cards = []
    m.homeRows = []
    m.navigation.destinations = []
    m.navigation.observeField("selected","rNavSelected")
    m.navigation.observeField("down","rFocusContent")
    m.shelves.observeField("rowItemSelected","rShelfSelected")
    m.shelves.observeField("rowItemFocused","rShelfFocused")
    m.grid.observeField("itemSelected","rGridSelected")
    m.grid.observeField("itemFocused","rGridFocused")
    m.rows.observeField("itemSelected","rRowSelected")
    m.rows.observeField("itemFocused","rRowFocused")
    m.actions.observeField("itemSelected","rActionSelected")
    m.libraryHeader.observeField("itemSelected","rLibraryHeaderSelected")
    m.filters.observeField("itemSelected","rFilterSelected")
    m.drawerRows.observeField("itemSelected","rDrawerSelected")
    m.drawerRows.observeField("itemFocused","rDrawerFocused")
    m.playerActions.observeField("itemSelected","rPlayerSelected")
    m.settingsNav.observeField("itemSelected","rSettingsNavSelected")
    m.playerInput.observeField("keyPressed","rPlayerInputPressed")
    m.player.observeField("state","rVideoState")
    m.networkTick.observeField("fire","rDispatch")
    m.pollTick.observeField("fire","rPoll")
    m.heroTick.observeField("fire","rSettleHero")
    m.hideControls.observeField("fire","rHideControls")
    m.networkTick.control = "start"
    m.pollTick.control = "start"
    m.navigation.visible = false
    m.heading.text = ""
    m.top.findNode("entry").mode = "startup"
    m.top.findNode("entry").visible = true
    m.skeleton.visible = false
    m.top.setFocus(true)
    rSend("CONFIG_LOAD","",invalid,"auth:config")
end sub

function rContent(values as object, width as integer, height as integer, imageHeight = 0 as integer, role = "landscape" as string, describe = "metadata" as string) as object
    root = CreateObject("roSGNode","ContentNode")
    for each value in values
        node = root.createChild("ContentNode")
        node.addFields({wire:value,uiWidth:width,uiHeight:height,imageHeight:imageHeight,progressFraction:0.0,showLabels:true,uiRole:role,uiButton:RGet(value,"button",false),focusedCaptions:role = "poster" and not RObject(RGet(value,"profile"))})
        node.title = RText(RGet(value,"title"),RText(RGet(value,"name")))
        node.description = RText(RGet(value,"subtitle"),RText(RGet(value,"detail")))
        if RCard(value) and role <> "episode"
            node.description = RArray(RGet(RGet(value,"view",{}),"compact_metadata_parts")).join(" · ")
            ' Continue Watching describes the episode in progress; its own compact
            ' metadata only repeated the release year.
            if describe = "subtitle" and RText(value.subtitle) <> "" then node.description = value.subtitle
        end if
        uri = RText(RGet(value,role))
        if left(uri,5) = "/api/" then uri = m.config.base+uri
        node.HDPosterUrl = uri
        p = RGet(RGet(value,"view",{}),"progress")
        if p <> invalid
            if p >= 0 and p <= 1 then node.progressFraction = p
        end if
    end for
    return root
end function

sub rReset(route as string)
    m.homeRenderVersion++
    m.pendingHomeHero = invalid
    m.homeExpectedFocus = invalid
    m.homeFocus = invalid
    m.heroTick.control = "stop"
    m.top.findNode("homeMotion").control = "stop"
    m.top.findNode("homeNavMotion").control = "stop"
    ' Animations are stopped, not completed: drop the shelf back to its resting
    ' offset so the next Home paints the same layout its state describes.
    m.shelves.translation = [96,824]
    m.navigation.opacity = 1
    m.navigation.focusable = true
    m.top.findNode("homePoster").visible = false
    m.top.findNode("homePosterArt").uri = ""
    rRetireProfileEditor()
    rRetirePinEditor()
    m.afterParent = invalid
    m.formOpener = invalid
    rRetireSearch()
    m.liveGuideRefreshDue = 0
    m.liveExpectedFocus = invalid
    m.liveFocusIndex = 0
    m.livePagingDirection = ""
    m.catalogExpectedFocus = invalid
    m.restoreKey = invalid
    m.libraryPages = []
    m.libraryCursors = []
    m.libraryFirst = 0
    m.libraryRefresh = invalid
    m.libraryRefreshDue = 0
    m.libraryRevisionPending = false
    rCancelDiscovery()
    m.generation++
    for each worker in m.workers
        if left(worker.request.tag,7) <> "player:" and left(worker.request.tag,5) <> "auth:" and left(worker.request.tag,5) <> "save:"
            if worker.request.method = "GET" then worker.cancel = true
            if m.pending[worker.request.tag] = worker.request.request_id then m.pending.delete(worker.request.tag)
        end if
    end for
    retained = []
    for each queued in m.queue
        if queued.method <> "GET" or left(queued.tag,7) = "player:" or left(queued.tag,5) = "auth:"
            retained.push(queued)
        else
            m.pending.delete(queued.tag)
        end if
    end for
    m.queue = retained
    m.route = route
    m.failedRequest = invalid
    m.retryBar.visible = false
    m.message.text = ""
    m.message.translation = [96,940]
    m.message.width = 1728
    m.message.height = 90
    m.message.font.size = 24
    m.message.color = "#B6B4AF"
    m.message.horizAlign = "left"
    m.retryBar.translation = [1540,940]
    m.heading.text = ""
    m.cards = []
    m.nextCursor = ""
    m.pageCursors = {}
    m.drawerKind = ""
    m.drawerStack = []
    m.drawerClosing = false
    m.drawerMotion.control = "stop"
    m.menuMotion.control = "stop"
    for each id in ["librarySheet","filterPage","passwordForm","libraryHeader","hero","actions","filters","shelves","grid","rows","skeleton","pairing","drawer","settingsSidebar","keyboard","formDialog"]
        m[id].visible = false
    end for
    m.navigation.visible = m.profile <> ""
    m.navigation.active = route
    m.historyClear.visible = false
    m.top.findNode("historyExplanation").visible = false
    m.top.findNode("historyEmpty").visible = false
    m.top.findNode("rowClip").clippingRect = [0,0,1920,1080]
    m.rows.translation = [96,270]
    m.rows.itemComponentName = "RemoteItem"
    m.rows.itemSpacing = [0,16]
    m.rows.itemSize = [1728,104]
    m.rows.numRows = 6
    m.grid.itemSize = [232,424]
    m.grid.itemSpacing = [16,36]
    m.grid.numColumns = 7
    m.grid.numRows = 2
    m.catalogLayoutTick.control = "stop"
    m.catalogViewportY = 360
    m.catalogOffset = 0
    m.top.findNode("catalogClip").clippingRect = [80,0,1760,1080]
    m.grid.translation = [96,360]
    m.filters.translation = [96,260]
    m.filters.itemSize = [260,64]
    m.filters.numColumns = 6
    m.actions.translation = [96,648]
    m.shelves.translation = [96,824]
    m.top.findNode("shelfClip").clippingRect = [80,0,1760,1080]
    m.shelves.rowHeights = []
    m.shelves.rowLabelOffset = [[0,16]]
    m.shelves.rowSpacings = []
    m.shelves.rowItemSize = [[320,252]]
    m.shelves.showRowLabel = [true]
    m.shelves.numRows = 3
    m.shelves.itemSize = [1728,304]
    m.shelves.rowItemSpacing = [[24,0]]
    m.heading.translation = [96,160]
    m.heading.width = 1700
    m.heading.height = 76
    m.heading.horizAlign = "left"
    m.heading.font.uri = "pkg:/fonts/remote_onest_700.ttf"
    m.heading.font.size = 48
    m.homeBrowsing = false
    m.top.findNode("settingsHeading").visible = false
    m.top.findNode("settingsExplanation").text = ""
    m.entryServer.visible = false
    m.top.findNode("entryHeading").visible = false
    m.top.findNode("entry").visible = false
    m.top.findNode("entry").mode = ""
    m.top.findNode("calendarPreview").visible = false
    m.top.findNode("heroIndicators").visible = false
    m.top.findNode("scrimX").visible = true
    m.top.findNode("scrimY").visible = true
    m.heroTitle.width = 800
    m.searchTick.control = "stop"
    m.keyboard.text = ""
    m.top.setFocus(true)
end sub

sub rNavigate(route as string, queryOverride = invalid as dynamic)
    if route = "menu"
        rOpenDrawer("Profile",[{title:"Switch profile",action:"profiles"},{title:"Settings",action:"settings"},{title:"History",action:"history"}],"menu")
        return
    end if
    rReset(route)
    m.navigation.setFocus(true)
    m.skeleton.visible = true
    if route = "home"
        rSend("GET",rProfilePath("/home"),invalid,"home")
    else if route = "movie" or route = "series" or route = "anime"
        rRetireCatalog()
        m.browseQuery = {type:route,skip:"0"}
        if RObject(queryOverride) then m.browseQuery = RCopy(queryOverride)
        m.browseQuery.skip = "0"
        m.heading.text = ""
        m.grid.translation = [96,180]
        rSend("GET","/api/discovery-controls?type="+route,invalid,"controls")
        rBrowsePage()
    else if route = "library"
        m.heading.text = ""
        m.grid.translation = [96,236]
        m.grid.itemSpacing = [16,22]
        rRetireCatalog()
        m.libraryQuery = {offset:"0",limit:"100"}
        if RObject(queryOverride) then m.libraryQuery = queryOverride
        m.libraryQuery.offset = "0"
        rLibraryPage()
    else if route = "history"
        m.heading.text = "History"
        m.heading.translation = [96,225]
        m.heading.font.size = 40
        m.historyOffset = 0
        m.historyEntries = []
        rSend("GET",rProfilePath("/history?offset=0&limit=100"),invalid,"history")
    else if route = "calendar"
        rCalendarStart()
    else if route = "live"
        m.heading.text = "Live TV"
        rLiveGroup("")
    else if route = "search"
        m.heading.text = "Search"
        m.skeleton.visible = false
        rTextInput("Search","search",false,"")
    else if route = "settings"
        rSettings()
    else if route = "profiles"
        rSend("GET","/api/profiles",invalid,"profiles")
    end if
end sub

sub rNavSelected()
    rNavigate(m.navigation.selected)
end sub

sub rFocusContent()
    if m.formDialog.visible
        m.formDialog.setFocus(true)
        return
    end if
    if m.formEditing and m.keyboard.visible
        m.keyboard.setFocus(true)
        return
    end if
    if m.route = "live" then rLoadGuides()
    if m.route = "home" and m.homeBrowsing and m.shelves.visible
        rHomeEnterShelves()
        return
    end if
    if m.route = "calendar" and m.filters.visible
        m.filters.setFocus(true)
        return
    end if
    for each id in ["actions","libraryHeader","filters","shelves","grid","rows"]
        if m[id].visible and m[id].content <> invalid
            if m[id].content.getChildCount() > 0
                m[id].setFocus(true)
                return
            end if
        end if
    end for
    if m.settingsSidebar.visible then m.settingsNav.setFocus(true) else m.navigation.setFocus(true)
end sub

sub rError(message as string)
    m.skeleton.visible = false
    if m.drawer.visible
        m.drawerMessage.text = message
        if m.failedRequest <> invalid
            if m.drawerRows.content = invalid or m.drawerRows.content.getChildCount() = 0
                m.drawerRows.content = rContent([{title:"Try again",action:"retry"}],800,104)
            end if
        end if
    else
        m.message.text = message
        if m.route = "library" then rLibraryStatus(true)
        if m.failedRequest <> invalid
            m.message.width = 1400
            m.retryBar.content = rContent([{title:"Try again",action:"retry"}],280,72)
            m.retryBar.visible = true
            if not rInputVisible() and not m.rows.visible and not m.grid.visible and not m.shelves.visible then m.retryBar.setFocus(true)
        end if
        if m.route = "settings"
            m.message.translation = [640,940]
            m.message.width = 1184
            if m.retryBar.visible then m.message.width = 870
        end if
    end if
end sub

sub rRetrySelected()
    rRun({action:"retry"})
end sub

sub rShowActions(values as object, centered = false as boolean, containerWidth = 0 as integer)
    ' Anything rendered in an action bar is a button, so RemoteItem centres its
    ' icon and label instead of padding them against one edge.
    for each value in values
        value.button = true
    end for
    m.actions.content = rContent(values,250,72)
    m.actions.align = "left"
    m.actions.containerWidth = 0
    if centered
        m.actions.align = "center"
        m.actions.containerWidth = containerWidth
    end if
    m.actions.visible = values.count() > 0
end sub

sub rShowRows(values as object)
    m.rows.content = rContent(values,int(m.rows.itemSize[0]),int(m.rows.itemSize[1]))
    m.rows.visible = true
    m.skeleton.visible = false
end sub

sub rOpenDrawer(title as string, values as object, kind as string)
    if not m.drawer.visible
        m.drawerOpener = m.top.focusedChild
        if m.grid.isInFocusChain() then m.drawerOpener = m.grid
    end if
    if m.drawer.visible and not m.drawerClosing and m.drawerKind <> kind
        previous = -1
        for i = 0 to m.drawerStack.count()-1
            if m.drawerStack[i].kind = kind then previous = i
        end for
        if previous >= 0
            while m.drawerStack.count() > previous
                m.drawerStack.pop()
            end while
        else if m.drawerStack.count() < 6
            m.drawerStack.push({title:m.drawerTitle.text,subtitle:m.drawerSubtitle.text,content:m.drawerRows.content,kind:m.drawerKind,focus:m.drawerRows.itemFocused})
        end if
    end if
    entering = not m.drawer.visible or m.drawerClosing
    m.drawerClosing = false
    m.menuMotion.control = "stop"
    m.drawerPanel.opacity = 1
    m.top.findNode("drawerScrim").visible = kind <> "menu"
    m.top.findNode("drawerGround").visible = kind <> "menu"
    m.top.findNode("menuGround").visible = false
    m.top.findNode("menuPanel").visible = (kind = "menu")
    m.drawerTitle.visible = kind <> "menu"
    m.drawerSubtitle.visible = kind <> "menu"
    m.drawerMessage.visible = kind <> "menu"
    m.drawerRows.itemSpacing = [0,10]
    m.drawerKind = kind
    m.drawerTitle.text = title
    m.drawerSubtitle.text = ""
    m.drawerMessage.text = ""
    m.drawerRows.itemSize = [800,104]
    m.drawerRows.numRows = 6
    m.drawerRows.content = rContent(values,800,104)
    m.sourceFilters.visible = false
    m.providerFilters.visible = false
    m.drawerRows.translation = [64,250]
    m.drawer.visible = true
    m.drawerRows.setFocus(true)
    if kind = "menu"
        for each value in values
            value.menu = true
        end for
        ' The profile menu is a real menu, not a two-line tooltip.
        panel = m.top.findNode("menuPanel")
        panel.width = 340
        panel.height = values.count()*72+32
        m.drawerPanel.translation = [1540,96]
        m.drawerRows.translation = [16,16]
        m.drawerRows.itemSize = [308,72]
        m.drawerRows.itemSpacing = [0,0]
        m.drawerRows.numRows = values.count()
        m.drawerRows.content = rContent(values,308,72)
        m.top.findNode("menuFade").keyValue = [0,1]
        m.menuMotion.control = "start"
        return
    end if
    if entering
        m.drawerMotion.control = "stop"
        m.drawerMotion.duration = 0.3
        m.drawerMotion.easeFunction = "outQuad"
        m.drawerSlide.keyValue = [[1920,0],[960,0]]
        m.drawerMotion.control = "start"
    end if
end sub

sub rDrawerFocused()
    if m.drawerKind = "episodes" and m.episodeFailed = invalid and m.drawerRows.content <> invalid and RText(m.episodeCursor) <> ""
        if m.drawerRows.itemFocused >= m.drawerRows.content.getChildCount()-3 then rPlayerEpisodes(m.episodeCursor,true)
    end if
end sub

sub rCloseDrawer()
    if m.drawerClosing then return
    if m.drawerKind = "profiles" or m.drawerKind = "editProfile" or m.drawerKind = "avatar" or m.drawerKind = "profileConfirm" then rRetireProfileEditor()
    if m.drawerKind = "episodes" then rRetireEpisodeRequests()
    if m.drawerKind = "sources" or m.drawerKind = "tracks" then rCancelAdmission()
    if m.drawerStack.count() > 0
        previous = m.drawerStack.pop()
        m.drawerTitle.text = previous.title
        m.drawerSubtitle.text = previous.subtitle
        m.drawerRows.content = previous.content
        m.drawerRows.jumpToItem = previous.focus
        m.drawerKind = previous.kind
        m.drawerRows.setFocus(true)
        return
    end if
    if m.drawerKind = "menu"
        m.drawerClosing = true
        m.menuMotion.control = "stop"
        m.top.findNode("menuFade").keyValue = [m.drawerPanel.opacity,0]
        m.menuMotion.control = "start"
        return
    end if
    if m.drawerKind = "sources" then rCancelDiscovery()
    if m.drawerKind = "sourceForm" or m.drawerKind = "sourceProviders"
        m.sourceDraft = {}
        m.sourceProviders = []
    end if
    m.drawerMotion.control = "stop"
    m.drawerClosing = true
    m.drawerMotion.duration = 0.2
    m.drawerMotion.easeFunction = "inQuad"
    m.drawerSlide.keyValue = [m.drawerPanel.translation,[1920,0]]
    m.drawerMotion.control = "start"
end sub

sub rDrawerMotionChanged()
    if not m.drawerClosing or m.drawerMotion.state <> "stopped" then return
    rCompleteDrawerClose()
end sub

sub rMenuMotionChanged()
    if not m.drawerClosing or m.menuMotion.state <> "stopped" then return
    rCompleteDrawerClose()
end sub

sub rCompleteDrawerClose()
    m.drawerClosing = false
    m.drawer.visible = false
    m.drawerKind = ""
    if m.playback <> invalid
        rShowControls()
    else if m.drawerOpener <> invalid and m.drawerOpener.visible
        m.drawerOpener.setFocus(true)
    else
        rFocusContent()
    end if
    if m.route = "live" and m.playback = invalid then rLoadGuides()
end sub

sub rPush()
    if m.snapshots.count() >= 8 then m.snapshots.shift()
    failure = invalid
    if m.route = "library" and rLibraryRetryRequired()
        q = m.failedRequest
        failure = {request:{method:q.method,path:q.path,body:RCopy(q.body),query:RCopy(q.query),tag:q.tag,context:RCopy(q.context)},message:m.message.text,refresh:RCopy(m.libraryRefresh)}
    end if
    gridKey = ""
    if m.grid.visible and m.grid.content <> invalid
        selected = m.grid.content.getChild(m.grid.itemFocused)
        if selected <> invalid and RCard(selected.wire) then gridKey = RIdentityKey(selected.wire)
    end if
    m.snapshots.push({homeFocus:m.homeFocus,homeBrowsing:m.homeBrowsing,gridKey:gridKey,libraryFailure:failure,libraryRevisionPending:m.libraryRevisionPending,route:m.route,card:m.detailCard,home:m.homeData,cards:m.cards,gridIndex:m.grid.itemFocused,browse:m.browseQuery,controls:m.controls,catalog:m.selectedCatalog,cursor:m.nextCursor,library:m.libraryQuery,libraryPages:m.libraryPages,libraryCursors:m.libraryCursors,libraryFirst:m.libraryFirst,libraryDue:m.libraryRefreshDue,search:m.searchTerm})
end sub

sub rBack()
    if rInputVisible()
        rTextCancel()
        return
    end if
    if m.seekPosition <> invalid
        m.seekPosition = invalid
        rShowControls()
    else if m.top.dialog <> invalid
        m.top.dialog = invalid
        rFocusContent()
    else if m.drawer.visible
        rCloseDrawer()
    else if m.playback <> invalid or m.admission <> invalid
        rStopPlayer()
        rFocusContent()
    else if m.route = "home" and m.homeBrowsing
        rHomeLeaveShelves()
    else if m.snapshots.count() > 0
        snap = m.snapshots.pop()
        rReset(snap.route)
        if snap.route = "detail"
            rDetail(snap.card,false)
        else if snap.route = "home" and snap.home <> invalid
            m.homeBrowsing = RGet(snap,"homeBrowsing",false)
            rHome(snap.home,RGet(snap,"homeFocus"))
        else if RArray(snap.cards).count() > 0
            m.cards = snap.cards
            m.browseQuery = snap.browse
            if snap.route = "library"
                m.libraryQuery = snap.library
                m.libraryPages = RArray(snap.libraryPages)
                m.libraryCursors = RArray(snap.libraryCursors)
                m.libraryFirst = RGet(snap,"libraryFirst",0)
                m.libraryRefreshDue = RGet(snap,"libraryDue",0)
                m.libraryRevisionPending = RGet(snap,"libraryRevisionPending",false)
                if m.libraryPages.count() > 0
                    data = m.libraryPages[m.libraryPages.count()-1].data
                    m.libraryDefaults = RQueryFields(data.default_query)
                    m.libraryControls = data.controls
                    rLibraryHeader(data)
                end if
                m.message.text = ""
                for each page in m.libraryPages
                    if RText(page.data.reason) <> "" then m.message.text = page.data.reason
                end for
                rLibraryStatus(false)
                if RObject(RGet(snap,"libraryFailure"))
                    m.failedRequest = RCopy(snap.libraryFailure.request)
                    m.libraryRefresh = RCopy(RGet(snap.libraryFailure,"refresh"))
                    m.failedRequest.epoch = m.epoch
                    m.failedRequest.generation = m.generation
                    m.failedRequest.context.catalog_version = m.catalogVersion
                    rError(snap.libraryFailure.message)
                end if
            end if
            m.controls = snap.controls
            m.selectedCatalog = snap.catalog
            m.nextCursor = snap.cursor
            if snap.gridIndex > 0 then m.catalogExpectedFocus = snap.gridIndex
            m.grid.content = rContent(m.cards,232,424,348,"poster")
            m.grid.visible = true
            m.grid.jumpToItem = snap.gridIndex
            m.grid.setFocus(true)
            if snap.route <> "library" and RObject(m.controls) then rBrowseFilters()
        else
            if snap.route = "library"
                rNavigate(snap.route,snap.library)
            else if snap.route = "movie" or snap.route = "series" or snap.route = "anime"
                rNavigate(snap.route,snap.browse)
            else
                rNavigate(snap.route)
                if snap.route = "search" then m.keyboard.text = RText(snap.search)
            end if
            m.restoreKey = RText(RGet(snap,"gridKey"))
        end if
    else if m.route <> "home" and m.profile <> ""
        rNavigate("home")
    else if m.route = "password"
        rPasswordCancel()
    else if m.route = "pairing"
        rCancelPairing()
        rSignInChoice()
    else if m.route = "choice"
        rWelcome()
    else
        m.navigation.setFocus(true)
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back"
        rBack()
        return true
    end if
    if m.drawer.visible
        if key = "up" and m.drawerRows.isInFocusChain()
            if m.sourceFilters.visible
                m.sourceFilters.setFocus(true)
            else if m.providerFilters.visible
                m.providerFilters.setFocus(true)
            else
                return false
            end if
            return true
        else if key = "down" and m.sourceFilters.isInFocusChain()
            if m.providerFilters.visible then m.providerFilters.setFocus(true) else m.drawerRows.setFocus(true)
            return true
        else if key = "down" and m.providerFilters.isInFocusChain()
            m.drawerRows.setFocus(true)
            return true
        else if key = "up" and m.providerFilters.isInFocusChain()
            if m.sourceFilters.visible then m.sourceFilters.setFocus(true)
            return true
        end if
    end if
    if m.playback <> invalid
        return rPlayerKey(key)
    end if
    if m.route = "settings" and not m.drawer.visible
        ' Settings is one page with a sidebar and a content column. Focus moves
        ' between them explicitly so the two setFocus calls can never race into
        ' a dead remote.
        if key = "right" and m.settingsNav.isInFocusChain()
            if m.rows.visible and m.rows.content <> invalid and m.rows.content.getChildCount() > 0
                m.rows.setFocus(true)
                return true
            end if
        else if key = "left" and m.rows.isInFocusChain() and m.settingsSidebar.visible
            m.settingsNav.setFocus(true)
            return true
        end if
    end if
    if m.route = "live" and rLiveKey(key) then return true
    if m.route = "search" and m.retryBar.visible
        if key = "down" and m.shelves.isInFocusChain()
            m.retryBar.setFocus(true)
            return true
        else if key = "up" and m.retryBar.isInFocusChain()
            if m.searchFirstResult <> invalid then m.shelves.setFocus(true) else m.keyboard.setFocus(true)
            return true
        end if
    end if
    if m.route = "search" and key = "left" and m.shelves.isInFocusChain()
        if rSearchPreviousKey() then return true
        m.keyboard.setFocus(true)
        return true
    end if
    if m.route = "profiles"
        if key = "down" and m.shelves.isInFocusChain() and m.actions.visible
            m.actions.setFocus(true)
            return true
        else if key = "up" and m.actions.isInFocusChain()
            m.shelves.setFocus(true)
            return true
        end if
    end if
    if m.route = "history" and key = "up" and m.rows.isInFocusChain()
        if m.historyClear.visible then m.historyClear.setFocus(true)
        return true
    else if m.route = "history" and key = "down" and m.historyClear.isInFocusChain()
        m.rows.setFocus(true)
        return true
    end if
    if m.route = "detail" and key = "up" and m.actions.isInFocusChain() then return true
    if m.route = "pairing" and key = "up"
        if m.entryServer.visible then m.entryServer.setFocus(true)
        return true
    else if m.route = "pairing" and key = "down"
        m.actions.setFocus(true)
        return true
    end if
    if key = "options" and m.failedRequest <> invalid
        rRun({action:"retry"})
        return true
    end if
    if m.route = "live" and m.retryBar.visible and not m.drawer.visible
        if key = "down" and m.rows.isInFocusChain()
            m.retryBar.setFocus(true)
            return true
        else if key = "up" and m.retryBar.isInFocusChain()
            m.rows.setFocus(true)
            return true
        end if
    end if
    if m.route = "library" and m.retryBar.visible and not m.drawer.visible
        if key = "down" and m.grid.isInFocusChain()
            m.retryBar.setFocus(true)
            return true
        else if key = "up" and m.retryBar.isInFocusChain()
            m.grid.setFocus(true)
            return true
        else if key = "up" and m.grid.isInFocusChain() and m.libraryFirst > 0
            m.retryBar.setFocus(true)
            return true
        end if
    end if
    if key = "up" and not m.drawer.visible
        if m.shelves.isInFocusChain() and m.route = "home"
            rHomeLeaveShelves()
        else if m.grid.isInFocusChain() and m.libraryHeader.visible
            if rLibraryPrevious() then return true
            m.libraryHeader.setFocus(true)
        else if (m.route = "detail" and m.shelves.isInFocusChain()) or (m.rows.isInFocusChain() and m.filters.visible)
            if m.filters.visible then m.filters.setFocus(true) else m.actions.setFocus(true)
        else if m.filters.isInFocusChain() and m.actions.visible
            m.actions.setFocus(true)
        else
            m.navigation.setFocus(true)
        end if
        return true
    end if
    if key = "down" and not m.drawer.visible
        if m.libraryHeader.isInFocusChain() and m.grid.visible
            m.grid.setFocus(true)
        else if m.actions.isInFocusChain() and m.filters.visible
            m.filters.setFocus(true)
        else if m.filters.isInFocusChain() and m.shelves.visible
            m.shelves.setFocus(true)
        else if m.filters.isInFocusChain() and m.rows.visible
            m.rows.setFocus(true)
        else if m.actions.isInFocusChain() and m.shelves.visible
            if m.route = "home"
                rHomeEnterShelves()
            else
                m.shelves.translation = [96,545]
                m.shelves.setFocus(true)
            end if
        else if m.filters.isInFocusChain() and m.grid.visible
            m.grid.setFocus(true)
        else
            rFocusContent()
        end if
        return true
    end if
    if m.route = "settings" and key = "left" and m.settingsSidebar.visible
        m.settingsNav.setFocus(true)
        return true
    else if m.route = "settings" and key = "right" and m.settingsNav.isInFocusChain()
        rFocusContent()
        return true
    end if
    return false
end function

sub rEntryServerSelected()
    rRun({action:"server"})
end sub

sub rStartupActions()
    if m.route <> "startup" or m.config.locked = true then return
    m.message.text = "Getting VIPTV ready…"
    m.message.translation = [96,664]
    m.message.horizAlign = "center"
    m.message.font.size = 26
    rShowActions([{title:"Change connection",action:"server",width:360}])
    m.actions.translation = [780,736]
    m.actions.setFocus(true)
end sub

sub rInvalidateReturnViews()
    for each snapshot in m.snapshots
        snapshot.home = invalid
        snapshot.cards = []
        snapshot.controls = invalid
        snapshot.catalog = invalid
        snapshot.cursor = ""
        snapshot.libraryPages = []
        snapshot.libraryCursors = []
        snapshot.libraryFirst = 0
        snapshot.libraryDue = 0
        snapshot.libraryFailure = invalid
        snapshot.libraryRevisionPending = false
    end for
end sub

sub rPlayerInputPressed(event as object)
    onKeyEvent(event.getData(),true)
end sub
