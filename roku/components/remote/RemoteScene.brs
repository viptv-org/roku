sub init()
    m.top.backgroundURI = ""
    for each id in ["navigation","heading","hero","backdrop","heroLogo","heroTitle","heroMeta","heroDescription","actions","filters","shelves","grid","rows","message","skeleton","pairing","pairAddress","pairCode","qr","drawer","drawerPanel","drawerTitle","drawerSubtitle","drawerRows","drawerMessage","drawerMotion","drawerSlide","networkTick","pollTick","heroTick","player","playerUi","playerTitle","playerTime","playerProgress","playerActions","hideControls","settingsSidebar","settingsNav"]
        m[id] = m.top.findNode(id)
    end for
    m.epoch = 1
    m.generation = 1
    m.sequence = 0
    m.sourceEpoch = 0
    m.searchVersion = 0
    m.heroIndex = 0
    m.heroSlideDue = 0
    m.backdrop.observeField("loadStatus","rHeroReady")
    m.keyboard = m.top.findNode("keyboard")
    m.sourceFilters = m.top.findNode("sourceFilters")
    m.sourceFilters.observeField("itemSelected","rSourceFilterSelected")
    m.retryBar = m.top.findNode("retryBar")
    m.retryBar.observeField("itemSelected","rRetrySelected")
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
    m.config = {base:"",access_token:"",refresh_token:"",last_profile_id:"",capabilities:{max_width:1280,max_height:720,h264:true,aac:true}}
    m.profile = ""
    m.route = "startup"
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
    m.featured = []
    m.cards = []
    m.homeRows = []
    m.navigation.destinations = [
        {id:"search",label:"",icon:"search",width:56},{id:"home",label:"Home",width:104},
        {id:"movie",label:"Movies",width:118},{id:"series",label:"Series",width:108},
        {id:"anime",label:"Anime",width:115},{id:"live",label:"Live",width:80},
        {id:"calendar",label:"Calendar",width:146},{id:"library",label:"My List",width:121},
        {id:"menu",label:"",icon:"profile",width:56}]
    m.navigation.observeField("selected","rNavSelected")
    m.navigation.observeField("down","rFocusContent")
    m.shelves.observeField("rowItemSelected","rShelfSelected")
    m.shelves.observeField("rowItemFocused","rShelfFocused")
    m.grid.observeField("itemSelected","rGridSelected")
    m.grid.observeField("itemFocused","rGridFocused")
    m.rows.observeField("itemSelected","rRowSelected")
    m.rows.observeField("itemFocused","rRowFocused")
    m.actions.observeField("itemSelected","rActionSelected")
    m.filters.observeField("itemSelected","rFilterSelected")
    m.drawerRows.observeField("itemSelected","rDrawerSelected")
    m.drawerRows.observeField("itemFocused","rDrawerFocused")
    m.playerActions.observeField("itemSelected","rPlayerSelected")
    m.settingsNav.observeField("itemSelected","rSettingsNavSelected")
    m.player.observeField("state","rVideoState")
    m.networkTick.observeField("fire","rDispatch")
    m.pollTick.observeField("fire","rPoll")
    m.heroTick.observeField("fire","rSettleHero")
    m.hideControls.observeField("fire","rHideControls")
    m.networkTick.control = "start"
    m.pollTick.control = "start"
    m.navigation.visible = false
    m.heading.text = "VIPTV"
    m.skeleton.visible = true
    m.top.setFocus(true)
    rSend("CONFIG_LOAD","",invalid,"auth:config")
end sub

function rContent(values as object, width as integer, height as integer, imageHeight = 0 as integer, role = "landscape" as string) as object
    root = CreateObject("roSGNode","ContentNode")
    for each value in values
        node = root.createChild("ContentNode")
        node.addFields({wire:value,uiWidth:width,uiHeight:height,imageHeight:imageHeight,progressFraction:0.0})
        node.title = RText(RGet(value,"title"),RText(RGet(value,"name")))
        node.description = RText(RGet(value,"subtitle"),RText(RGet(value,"detail")))
        uri = RText(RGet(value,role))
        if left(uri,5) = "/api/" then uri = m.config.base+uri
        node.HDPosterUrl = uri
        p = RGet(value,"progress")
        if p <> invalid
            if p >= 0 and p <= 1 then node.progressFraction = p
        end if
    end for
    return root
end function

sub rReset(route as string)
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
    m.heading.text = ""
    m.cards = []
    m.nextCursor = ""
    m.pageCursors = {}
    m.drawerKind = ""
    m.drawerStack = []
    m.drawerClosing = false
    m.drawerMotion.control = "stop"
    for each id in ["hero","actions","filters","shelves","grid","rows","skeleton","pairing","drawer","settingsSidebar","keyboard"]
        m[id].visible = false
    end for
    m.navigation.visible = m.profile <> ""
    m.navigation.active = route
    m.rows.translation = [96,270]
    m.rows.itemComponentName = "RemoteItem"
    m.rows.itemSpacing = [0,16]
    m.rows.itemSize = [1728,104]
    m.rows.numRows = 6
    m.grid.itemSize = [232,410]
    m.grid.itemSpacing = [16,36]
    m.grid.numColumns = 7
    m.grid.numRows = 2
    m.grid.translation = [96,360]
    m.filters.translation = [96,260]
    m.filters.itemSize = [260,64]
    m.filters.numColumns = 6
    m.actions.translation = [96,648]
    m.shelves.translation = [96,824]
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
    m.top.findNode("welcomeArt").visible = false
    m.top.findNode("calendarPreview").visible = false
    m.top.findNode("heroIndicators").visible = false
    m.top.findNode("scrimX").visible = true
    m.top.findNode("scrimY").visible = true
    m.heroTitle.width = 800
    m.searchTick.control = "stop"
    m.keyboard.text = ""
    m.top.setFocus(true)
end sub

sub rNavigate(route as string)
    if route = "menu"
        rOpenDrawer("Profile",[{title:"Switch profile",action:"profiles"},{title:"History",action:"history"},{title:"Settings",action:"settings"}],"menu")
        return
    end if
    rReset(route)
    m.navigation.setFocus(true)
    m.skeleton.visible = true
    if route = "home"
        rSend("GET",rProfilePath("/home"),invalid,"home")
    else if route = "movie" or route = "series" or route = "anime"
        m.browseQuery = {type:route,skip:"0"}
        m.heading.text = {movie:"Movies",series:"Series",anime:"Anime"}[route]
        rSend("GET","/api/discovery-controls?type="+route,invalid,"controls")
        rBrowsePage()
    else if route = "library"
        m.heading.text = "My List"
        m.libraryQuery = {offset:"0",limit:"100"}
        rSend("GET",rProfilePath("/library?offset=0&limit=100"),invalid,"library")
    else if route = "history"
        m.heading.text = "History"
        m.historyOffset = 0
        m.historyEntries = []
        rSend("GET",rProfilePath("/history?offset=0&limit=100"),invalid,"history")
    else if route = "calendar"
        rCalendarStart()
    else if route = "live"
        m.heading.text = "Live TV"
        m.liveQuery = ""
        rSend("GET",rProfilePath("/live/channels?limit=100"),invalid,"live")
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
    for each id in ["actions","filters","shelves","grid","rows"]
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
        if m.failedRequest <> invalid
            m.message.width = 1400
            m.retryBar.content = rContent([{title:"Try again",action:"retry"}],280,72)
            m.retryBar.visible = true
            if not m.rows.visible and not m.grid.visible and not m.shelves.visible then m.retryBar.setFocus(true)
        end if
    end if
end sub

sub rRetrySelected()
    m.retryBar.visible = false
    rRun({action:"retry"})
end sub

sub rShowActions(values as object)
    m.actions.content = rContent(values,250,72)
    m.actions.visible = values.count() > 0
end sub

sub rShowRows(values as object)
    m.rows.content = rContent(values,int(m.rows.itemSize[0]),104)
    m.rows.visible = true
    m.skeleton.visible = false
end sub

sub rOpenDrawer(title as string, values as object, kind as string)
    if not m.drawer.visible then m.drawerOpener = m.top.focusedChild
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
    m.drawerKind = kind
    m.drawerTitle.text = title
    m.drawerSubtitle.text = ""
    m.drawerMessage.text = ""
    m.drawerRows.itemSize = [800,104]
    m.drawerRows.numRows = 6
    m.drawerRows.content = rContent(values,800,104)
    m.sourceFilters.visible = false
    m.drawerRows.translation = [64,250]
    m.drawer.visible = true
    m.drawerRows.setFocus(true)
    if entering
        m.drawerMotion.control = "stop"
        m.drawerMotion.duration = 0.3
        m.drawerMotion.easeFunction = "outQuad"
        m.drawerSlide.keyValue = [[1920,0],[960,0]]
        m.drawerMotion.control = "start"
    end if
end sub

sub rDrawerFocused()
    if m.drawerKind = "episodes" and m.drawerRows.content <> invalid and RText(m.episodeCursor) <> ""
        if m.drawerRows.itemFocused >= m.drawerRows.content.getChildCount()-3 then rPlayerEpisodes(m.episodeCursor,true)
    end if
end sub

sub rCloseDrawer()
    if m.drawerClosing then return
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
end sub

sub rPush()
    if m.snapshots.count() >= 8 then m.snapshots.shift()
    m.snapshots.push({route:m.route,card:m.detailCard,home:m.homeData,cards:m.cards,gridIndex:m.grid.itemFocused,shelfIndex:m.shelves.rowItemFocused,browse:m.browseQuery,controls:m.controls,catalog:m.selectedCatalog,cursor:m.nextCursor})
end sub

sub rBack()
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
    else if m.snapshots.count() > 0
        snap = m.snapshots.pop()
        rReset(snap.route)
        if snap.route = "detail"
            rDetail(snap.card,false)
        else if snap.route = "home" and snap.home <> invalid
            rHome(snap.home)
            m.shelves.jumpToRowItem = snap.shelfIndex
            m.shelves.setFocus(true)
        else if RArray(snap.cards).count() > 0
            m.cards = snap.cards
            m.browseQuery = snap.browse
            m.controls = snap.controls
            m.selectedCatalog = snap.catalog
            m.nextCursor = snap.cursor
            m.grid.content = rContent(m.cards,232,410,348,"poster")
            m.grid.visible = true
            m.grid.jumpToItem = snap.gridIndex
            m.grid.setFocus(true)
            if RObject(m.controls) then rBrowseFilters()
        else
            rNavigate(snap.route)
            m.restoreIndex = snap.gridIndex
        end if
    else if m.route <> "home" and m.profile <> ""
        rNavigate("home")
    else if m.route = "pairing" or m.route = "welcome"
        m.pairChallenge = invalid
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
        if key = "up" and m.drawerRows.isInFocusChain() and m.sourceFilters.visible
            m.sourceFilters.setFocus(true)
            return true
        else if key = "down" and m.sourceFilters.isInFocusChain()
            m.drawerRows.setFocus(true)
            return true
        end if
    end if
    if m.playback <> invalid
        return rPlayerKey(key)
    end if
    if m.route = "live" and rLiveKey(key) then return true
    if m.route = "search" and key = "left" and m.shelves.isInFocusChain()
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
    if key = "options" and m.failedRequest <> invalid
        q = m.failedRequest
        m.failedRequest = invalid
        rSend(q.method,q.path,q.body,q.tag,q.context)
        return true
    end if
    if key = "up" and not m.drawer.visible
        if m.shelves.isInFocusChain() and m.route = "home"
            m.homeBrowsing = false
            rHomeScroll(false)
            if RCard(m.heroCard) then rHero(m.heroCard)
            m.actions.visible = true
            m.actions.setFocus(true)
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
        if m.actions.isInFocusChain() and m.filters.visible
            m.filters.setFocus(true)
        else if m.filters.isInFocusChain() and m.shelves.visible
            m.shelves.setFocus(true)
        else if m.filters.isInFocusChain() and m.rows.visible
            m.rows.setFocus(true)
        else if m.actions.isInFocusChain() and m.shelves.visible
            m.homeBrowsing = m.route = "home"
            if m.homeBrowsing then m.actions.visible = false
            if m.homeBrowsing then rHomeScroll(true) else m.shelves.translation = [96,545]
            m.shelves.setFocus(true)
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
