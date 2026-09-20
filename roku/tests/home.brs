' Production Home tests with field fakes: no network, no fixture credentials.
sub Main()
    m.config = {base:"https://library.example",access_token:"fixture-access",last_profile_id:"p1",account_id:"account"}
    m.profile = "p1"
    m.queue = []
    m.tasks = []
    m.generation = 1
    m.poll = {control:""}
    m.status = {text:""}
    m.heading = {text:""}
    m.list = {visible:true,setFocus:HomeFocus,itemFocused:0}
    m.art = {visible:true}
    m.detailTitle = {visible:true}
    m.detailInfo = {visible:true}
    m.description = {visible:true}
    m.homePanel = {visible:false}
    m.homeRows = {rowItemFocused:[],setFocus:HomeFocus,focused:false}
    m.homeTitle = {text:""}
    m.homeSummary = {text:""}
    m.top = {findNode:HomeFind,dialog:invalid}
    m.sidebar = {focused:false,setFocus:HomeFocus,hasFocus:HomeHasFocus}
    m.homePosition = [0,0]
    m.homeKeyValue = ""
    testColdHomeRequests()
    testCatalogDispatchAndStaleResponses()
    testProfileSwitchAndSidebarNavigation()
    testHomeResumeDispatch()
    testSettingsNavigation()
    testMutationRevisions()
    testColdHomeAutoPick()
    testReturnCursorAndCacheRefresh()
    testReorderedRefreshFocus()
    testProgressFractions()
    testViewAllHistory()
    testKeyboardDialogDismissal()
    testProfileChooser()
    testBrowsePageRestore()
    testShelfRemoval()
    testStreamsFocusGuards()
    testGuideWiring()
    testSourceRouteIdentity()
    testOrdinaryAcknowledgementFocus()
    testStableShelfCompletionOrder()
    testSettledSearchPreview()
    testSettingsGroups()
    testManualSourcesAndCategories()
    testPosterRouteRestore()
    print "ROKU_HOME_OK"
end sub

sub testColdHomeRequests()
    showHome()
    homeAssert(m.queue.count() = 4,"independent history/list/live/catalog requests")
    homeAssert(m.queue[0].request_id <> m.queue[1].request_id and m.queue[1].request_id <> m.queue[2].request_id and m.queue[2].request_id <> m.queue[3].request_id,"concurrent requests receive distinct temporary-file IDs")
    ignored = homeKey("OK")
    homeAssert(m.homeAutoPick,"profile-entry OK bubbling does not suppress cold-home discovery")
    homeAssert(m.homeRoot.getChildCount() = 0,"cold Home renders no filler shelves")
    homeAssert(homeValues(0).count() = 0,"empty history has no fake poster actions")
    m.homeItems = []
    for i = 1 to 30
        m.homeItems.push({id:i.toStr(),type:"movie",name:"Title " + i.toStr()})
    end for
    homeResponse("favorites",{ok:true,data:m.homeItems})
    homeAssert(m.homeData[4].count() = 12,"twelve item shelf cap")
    homeAssert(m.homeData[4][11].action = "favorites","long collections retain a View all route within the item budget")
    m.homePosition = [4,8]
    m.homeRows.focused = false
    m.sidebar.focused = true
    homeResponse("progress",{ok:false})
    homeAssert(m.homePosition[0] = 4 and m.homePosition[1] = 8,"partial response preserves row and column")
    homeAssert(not m.homeRows.focused and m.sidebar.focused,"partial response never steals sidebar focus")
    homeAssert(homeValues(0).count() = 0 and m.homeFailed[0],"failure retains retry state without filler shelf")
    homeAssert(m.homeRoot.getChildCount() = 1,"only populated My List shelf is rendered")
end sub

sub testCatalogDispatchAndStaleResponses()
    m.queue = []
    homeResponse("catalogs",{ok:true,data:[{type:"series",id:"first-series",addon_id:"custom"},{type:"movie",id:"first-movie",addon_id:"other"},{type:"movie",id:"second-movie",addon_id:"ignored"}]})
    homeAssert(m.queue.count() = 2,"one discover per metadata type")
    homeAssert(instr(1,m.queue[0].path,"addon_id=other&catalog=first-movie") > 0,"first ordered custom movie catalog")
    homeAssert(instr(1,m.queue[1].path,"addon_id=custom&catalog=first-series") > 0,"first ordered custom series catalog")
    event = {getData:HomeGetData,getRoSGNode:HomeGetNode,data:{tag:"home:movie|0",ok:true,data:{metas:items}},node:{request:{}}}
    response(event)
    homeAssert(m.homeData[1].count() = 0,"stale generation ignored")
    m.profile = "p2"
    homeResponse("movie",{ok:true,data:{metas:items}})
    homeAssert(m.homeData[1].count() = 0,"profile mismatch ignored")
end sub

sub testProfileSwitchAndSidebarNavigation()
    m.queue = []
    showHome()
    homeAssert(m.homeData[4].count() = 0 and m.homePosition[0] = 0,"profile switch clears cache and cursor")
    homeAssert(m.queue.count() = 4,"new profile independently loads shelves")
    m.homePosition = [0,2]
    m.sidebar.focused = false
    homeAssert(not homeKey("left"),"left inside shelf remains native")
    m.homePosition = [0,0]
    homeAssert(homeKey("left") and m.sidebar.focused,"left at first card enters sidebar")
    homeAssert(not homeKey("back"),"second Back from Home sidebar permits scene exit")
    homeAssert(homeKey("right") and m.homeRows.focused,"right returns to retained shelf")
    m.top.dialog = {}
    homeAssert(not homeKey("left"),"dialog routing untouched")
    m.top.dialog = invalid
    m.homePosition = [9,99]
    homeRestore()
    homeAssert(m.homePosition[0] = 0 and m.homePosition[1] = 0,"empty Home cursor remains safe")
end sub

sub testHomeResumeDispatch()
    m.homeRowKeys = [0]
    m.homeData[0] = [{id:"series:2:4",type:"series",name:"Canonical series",position:540,duration:1800}]
    m.homeRows.rowItemSelected = [0,0]
    m.queue = []
    homeSelected()
    homeAssert(m.queue.count() = 1 and m.queue[0].path = "/api/streams","series resume directly discovers sources")
    homeAssert(m.queue[0].body.id = "series:2:4" and m.queue[0].body.name = "Canonical series","resume retains original episode ID and canonical name")
    homeAssert(m.position = 540,"resume retains saved position")
    m.homeData[0] = [{id:"opaque-episode",type:"series",name:"Canonical parent",series_id:"parent",season:2,episode:4,year:2024,imdb_id:"tt7654321",tmdb_id:"456",position:540,duration:1800}]
    m.mode = "home"
    m.queue = []
    homeSelected()
    resumedBody = m.queue[0].body
    homeAssert(resumedBody.id = "opaque-episode" and resumedBody.series_id = "parent" and resumedBody.name = "Canonical parent","Home opaque resume retains original ID parent and canonical name")
    homeAssert(resumedBody.season = 2 and resumedBody.episode = 4 and resumedBody.year = 2024,"Home opaque resume forwards saved coordinates and numeric year")
    homeAssert(resumedBody.imdb_id = "tt7654321" and resumedBody.tmdb_id = "456","Home resume forwards alternate matching IDs")
    homeAssert(m.mode = "streams","resume remains in the explicit populated source destination")
    response({getData:HomeGetData,getRoSGNode:HomeGetNode,data:{tag:"streamstart|" + m.generation.toStr(),ok:false,error:"Unavailable"},node:{request:{}}})
    homeAssert(m.mode = "sourceerror","failed resume offers a retry destination")
    restoreView()
    m.homeRowKeys = [0,1,2,3,4]
    m.homeData[2] = [{id:"normal-series",type:"series",name:"Normal series"}]
    m.homeRows.rowItemSelected = [2,0]
    m.queue = []
    homeSelected()
    homeAssert(m.queue[0].path = "/api/meta/series/normal-series","normal series after resume failure opens metadata")
end sub

sub testSettingsNavigation()
    m.video = {visible:false}
    m.sidebar.focused = true
    m.queue = []
    homeAssert(onKeyEvent("options",true) and m.queue.count() = 0,"star on sidebar cannot toggle old title")
    m.sidebar.focused = false
    m.mode = "settings"
    homeAssert(onKeyEvent("back",true) and m.mode = "home","signed in Settings Back returns home")
    m.profile = ""
    m.mode = "settings"
    homeAssert(not onKeyEvent("back",true),"cold Settings Back permits exit")
    m.profile = "p2"
end sub

sub testMutationRevisions()
    m.mode = "home"
    m.queue = []
    origin = {base:m.config.base,access_token:m.config.access_token,account_epoch:m.accountEpoch,last_profile_id:m.profile,path:"/api/profiles/p2/progress",method:"PUT",tag:"sideprogress|0"}
    homeMutation(origin,false)
    oldRevision = homeRevision("progress")
    homeResponse("progress",{ok:true,data:[{id:"old",type:"movie",name:"Old history",position:1}]})
    m.homeDirty = false
    response({getData:HomeGetData,getRoSGNode:HomeGetNode,data:{tag:"sideprogress|0",ok:true,data:{}},node:{request:origin}})
    homeAssert(m.homeDirty and m.queue.count() = 1,"stale UI mutation ack invalidates and refreshes active home")
    response({getData:HomeGetData,getRoSGNode:HomeGetNode,data:{tag:"home:progress:" + oldRevision.toStr() + "|" + m.generation.toStr(),ok:true,data:[{id:"older",type:"movie"}]},node:{request:{}}})
    homeAssert(m.homeData[0][0].id = "old","old GET after held PUT ack rejected")
    response({getData:HomeGetData,getRoSGNode:HomeGetNode,data:{tag:m.queue[0].tag,ok:true,data:[{id:"correct",type:"movie",position:900}]},node:{request:{}}})
    homeAssert(m.homeData[0][0].id = "correct","post-write GET reconciles final history")
    m.homePosition = [4,8]
    m.homeData[4] = m.homeItems
    origin.path = "/api/profiles/p2/favorites/movie/id"
    origin.method = "DELETE"
    homeMutation(origin,false)
    homeAssert(m.homeDirty,"favorite dispatch invalidates before acknowledgement")
    m.queue = []
    response({getData:HomeGetData,getRoSGNode:HomeGetNode,data:{tag:"favorited|0",ok:true,data:{}},node:{request:origin}})
    homeAssert(m.queue.count() = 1,"canceled-generation favorite ack refreshes visible shelf")
    response({getData:HomeGetData,getRoSGNode:HomeGetNode,data:{tag:m.queue[0].tag,ok:true,data:[{id:"remaining",type:"movie"}]},node:{request:{}}})
    homeAssert(m.homePosition[0] = 4 and m.homePosition[1] = 0,"favorite deletion clamps retained shelf focus")
    revision = homeRevision("favorites")
    origin.base = "https://other.example"
    homeMutation(origin,true)
    homeAssert(homeRevision("favorites") = revision,"other server mutation cannot invalidate active profile")
    origin.base = m.config.base
    origin.path = "/api/profiles/another/favorites"
    homeMutation(origin,true)
    homeAssert(homeRevision("favorites") = revision,"other profile mutation cannot invalidate active profile")
    m.tasks = [{request:{tag:"favorited|0"},cancel:false},{request:{tag:"streampoll|0"},cancel:false}]
    m.queue = [{tag:"playback|0"}]
    m.list.itemFocused = 0
    before = m.generation
    selectItem({action:"settings"})
    homeAssert(m.generation > before and m.mode = "settings","Settings navigation cancels old browse generation")
    homeAssert(m.tasks[1].cancel and not m.tasks[0].cancel,"cancel stops discovery but retains favorite acknowledgement")
    homeAssert(m.queue[0].tag = "playback|0","navigation retains orphan playback cleanup")
end sub

sub testColdHomeAutoPick()
    ' Native Search dialog/wasClosed routing is exercised by SceneGraph previews;
    ' standalone interpreter has no host node for native dialog observers.
    m.profile = "cold"
    m.sidebar.focused = false
    showHome()
    homeRestoreSettled()
    homeResponse("progress",{ok:true,data:[]})
    homeResponse("favorites",{ok:true,data:[]})
    homeResponse("movie",{ok:true,data:{metas:m.homeItems}})
    homeAssert(m.homePosition[0] = 1,"cold empty history chooses loaded movie shelf")
end sub

sub testReturnCursorAndCacheRefresh()
    m.homePosition = [1,7]
    m.homeRows.rowItemFocused = [0,0]
    showHome()
    homeFocused()
    homeAssert(m.homePosition[0] = 1 and m.homePosition[1] = 7,"content reset event cannot overwrite return cursor")
    homeRestoreSettled()
    homeAssert(m.homeRows.jumpToRowItem[1] = 7,"settled restore reasserts retained column")
    cachedRoot = m.homeRoot
    retainedId = m.homeData[1][7].id
    m.homeTime = CreateObject("roDateTime").asSeconds() - 121
    m.queue = []
    showHome()
    homeAssert(m.homeData[1].count() = 12 and m.homeData[1][7].id = retainedId,"expired cache retains populated shelf until response")
    homeAssert(m.homePosition[0] = 1 and m.homePosition[1] = 7,"expired cache return retains column seven")
    homeAssert(m.homeRoot.isSameNode(cachedRoot),"same-profile TTL refresh retains native content tree")
    homeAssert(m.queue.count() = 4,"expired cache still requests bounded independent refresh")
    reordered = [m.homeItems[7],m.homeItems[0],m.homeItems[1],m.homeItems[2],m.homeItems[3],m.homeItems[4],m.homeItems[5],m.homeItems[6]]
    m.homeRows.focused = false
    m.sidebar.focused = true
    homeResponse("movie",{ok:true,data:{metas:reordered}})
    homeAssert(m.homePosition[0] = 1 and m.homePosition[1] = 0 and homeCurrent().id = retainedId,"reordered refresh retains selected title identity")
    homeAssert(m.sidebar.focused and not m.homeRows.focused,"reordered refresh does not steal sidebar focus")
    m.homePosition = [1,7]
    m.homeDirty = true
    showHome()
    homeAssert(m.homeData[1].count() = 8 and m.homePosition[1] = 7,"dirty refresh also keeps stale data and cursor")
    homeResponse("movie",{ok:false})
    homeAssert(m.homeData[1].count() = 8 and m.homePosition[1] = 7,"failed refresh preserves usable cached shelf")
    m.homeDone.delete("movie")
    homeResponse("movie",{ok:true,data:{metas:[{id:"replacement",type:"movie",name:"Replacement"}]}})
    homeAssert(m.homePosition[0] = 1 and m.homePosition[1] = 0,"missing selected identity clamps to refreshed bounds")
    m.profile = "moved"
    showHome()
    homeAssert(m.homeData[1].count() = 0 and m.homePosition[0] = 0 and m.homePosition[1] = 0,"profile change clears stale cards and saved cursor")
end sub

sub testReorderedRefreshFocus()
    m.sidebar.focused = false
    homeResponse("favorites",{ok:true,data:m.homeItems})
    homeRestoreSettled()
    m.homeRows.rowItemFocused = [0,1]
    homeFocused()
    homeResponse("movie",{ok:true,data:{metas:m.homeItems}})
    homeAssert(m.homePosition[0] = 4 and m.homePosition[1] = 1,"user movement prevents default shelf jump")
    m.profile = "menu"
    showHome()
    m.sidebar.focused = true
    homeResponse("movie",{ok:true,data:{metas:m.homeItems}})
    homeAssert(m.sidebar.focused and m.homeAutoPick = false,"sidebar prevents automatic focus transfer")
end sub

sub testProgressFractions()
    homeAssert(homeProgress({position:50,duration:100}) = 0.5,"meaningful progress fraction")
    homeAssert(homeProgress({position:200,duration:100}) = 1,"progress upper bound")
    homeAssert(homeProgress({position:-1,duration:100}) = 0,"progress lower bound")
    homeAssert(homeProgress({position:10,duration:0}) = -1,"unknown duration hides progress")
end sub

sub testViewAllHistory()
    m.profile = "long-history"
    m.sidebar.focused = false
    showHome()
    homeResponse("progress",{ok:true,data:m.homeItems})
    homeAssert(m.homeData[0][11].action = "progress","older Continue Watching entries remain reachable")
    m.queue = []
    m.homeRows.rowItemSelected = [0,11]
    homeSelected()
    homeAssert(m.collection = "progress" and instr(1,m.queue[0].path,"/progress") > 0,"View all opens the full history collection")
end sub

sub testKeyboardDialogDismissal()
    closed = CreateObject("roSGNode","ContentNode")
    newer = CreateObject("roSGNode","ContentNode")
    m.keyboardDialog = closed
    m.top.dialog = closed
    m.mode = "home"
    m.homeRows.focused = false
    keyboardClosed({getRoSGNode:HomeGetNode,node:closed})
    homeAssert(m.top.dialog = invalid and m.homeRows.focused,"native Back dismissal clears dialog and restores visible home focus")
    m.keyboardDialog = newer
    m.top.dialog = newer
    keyboardClosed({getRoSGNode:HomeGetNode,node:closed})
    homeAssert(m.top.dialog.isSameNode(newer),"late old dialog closure cannot dismiss a newer dialog")
    m.top.dialog = invalid
end sub

sub testProfileChooser()
    m.identity = {text:""}
    m.chooseProfile = false
    m.canCreateProfile = true
    m.queue = []
    m.sidebar.jumpToItem = 6
    response({getData:HomeGetData,getRoSGNode:HomeGetNode,data:{tag:"profiles|" + m.generation.toStr(),ok:true,data:[{id:"single",name:"Only viewer",setup_complete:true}]},node:{request:{}}})
    homeAssert(m.mode = "profiles" and m.items.count() = 2 and m.profile <> "single","an unremembered sole profile still requires an explicit choice")
    m.sidebar.jumpToItem = 6
    selectItem({action:"home"})
    homeAssert(m.mode = "home" and m.sidebar.jumpToItem = 1,"explicit Home action resets stale sidebar icon")
    m.chooseProfile = true
    response({getData:HomeGetData,getRoSGNode:HomeGetNode,data:{tag:"profiles|" + m.generation.toStr(),ok:true,data:[{id:"single",name:"Only viewer",setup_complete:true}]},node:{request:{}}})
    homeAssert(m.mode = "profiles" and m.items.count() = 2,"explicit profile switch still permits creating another profile")
    response({getData:HomeGetData,getRoSGNode:HomeGetNode,data:{tag:"profiles|" + m.generation.toStr(),ok:true,data:[{id:"one",name:"One",setup_complete:true},{id:"two",name:"Two",setup_complete:true}]},node:{request:{}}})
    homeAssert(m.mode = "profiles" and m.items.count() = 3,"multiple profiles require choice")
    zeroRows = AccountProfileRows([],true)
    homeAssert(zeroRows.count() = 1 and zeroRows[0].action = "newprofile","zero profiles expose creation without a fake viewer")
end sub

sub testBrowsePageRestore()
    m.profile = "single"
    m.views = []
    m.mode = "browse"
    m.mediaType = "movie"
    m.search = "Café"
    m.offset = 80
    m.items = m.homeItems
    m.list.itemFocused = 7
    m.heading.text = "Search Café"
    saveView()
    m.mode = "detail"
    m.items = []
    restoreView()
    homeAssert(m.mode = "browse" and m.list.jumpToItem = 7 and m.search = "Café" and m.offset = 80,"Back restores non-Home query page and cursor")
end sub

sub testShelfRemoval()
    m.profile = "rails"
    m.sidebar.focused = false
    showHome()
    homeResponse("progress",{ok:true,data:[{id:"p",type:"movie",name:"Progress"}]})
    homeResponse("favorites",{ok:true,data:[{id:"f",type:"movie",name:"Favorite"}]})
    homeResponse("movie",{ok:true,data:{metas:[{id:"m",type:"movie",name:"Movie"}]}})
    m.homePosition = [1,0]
    m.homeRows.focused = false
    m.sidebar.focused = true
    m.homeDone.delete("favorites")
    homeResponse("favorites",{ok:true,data:[]})
    homeAssert(m.homeRoot.getChildCount() = 2 and m.homePosition[0] = 1,"removing final favorite removes shelf and retains nearest logical neighbor")
    homeAssert(m.sidebar.focused and not m.homeRows.focused,"empty shelf removal cannot steal focus")
end sub

sub testStreamsFocusGuards()
    m.playItem = {id:"movie",type:"movie",name:"Film"}
    m.mode = "streams"
    m.manualSources = true
    m.list.focused = false
    m.queue = []
    response({getData:HomeGetData,getRoSGNode:HomeGetNode,data:{tag:"streamstart|" + m.generation.toStr(),ok:true,data:{id:"job"}},node:{request:{}}})
    homeAssert(not m.list.focused and m.sidebar.focused,"initial source job acknowledgement cannot steal sidebar focus")
    m.streams = [{id:"pinned",source:"z",name:"Source",title:"Film 720p"}]
    m.items = m.streams
    m.list.itemFocused = 0
    m.list.focused = false
    m.listUpdating = false
    m.sidebar.focused = true
    m.mode = "streams"
    m.manualSources = true
    m.playing = false
    m.cursor = 0
    m.pollCount = 1
    response({getData:HomeGetData,getRoSGNode:HomeGetNode,data:{tag:"streampoll|" + m.generation.toStr(),ok:true,data:{events:[{seq:1,streams:[{id:"new",source:"a",name:"Other",title:"Film"}]}],done:false}},node:{request:{}}})
    homeAssert(not m.list.focused and m.sidebar.focused,"incremental Sources never steals sidebar focus")
    homeAssert(m.items[m.list.jumpToItem].id = "pinned","source group reordering retains focused source ID")
    m.streams = []
    for group = 0 to 7
        for column = 0 to 9
            m.streams.push({id:group.toStr()+":"+column.toStr(),source:group.toStr(),name:"Source",title:"Film"})
        end for
    end for
    m.poll.control = "stop"
    response({getData:HomeGetData,getRoSGNode:HomeGetNode,data:{tag:"streampoll|" + m.generation.toStr(),ok:true,data:{events:[{seq:2,streams:[]}],done:false}},node:{request:{}}})
    homeAssert(m.streams.count() = 80 and m.poll.control = "start","full candidate quota does not stop discovery polling")
    before = m.queue.count()
    settleList()
    focused()
    homeAssert(m.queue.count() = before,"focus-only browsing performs no requests")
end sub

sub testGuideWiring()
    m.selected = {id:"live",type:"live",name:"Live channel"}
    program = {start:1700000000,title:"Dr. Café_日本語 🔴️���",description:"News. 🎬"}
    response({getData:HomeGetData,getRoSGNode:HomeGetNode,data:{tag:"guide|" + m.generation.toStr(),ok:true,data:{programs:[program]}},node:{request:{}}})
    homeAssert(instr(1,m.items[2].name,"Dr. Café_日本語") > 0 and instr(1,m.items[2].name,"🔴") = 0,"guide rows use Unicode-safe display cleanup")
end sub

sub testSettingsGroups()
    m.config.locked = true
    m.configLoaded = true
    showSettings()
    homeAssert(m.items.count() = 10 and m.items[1].action = "profiles" and m.items[3].action = "waiting" and m.items[4].action = "waiting" and m.items[9].action = "signout", "account Settings exposes profile playback help status about and sign-out groups")
    homeAssert(instr(1,m.items[3].displayName,"Choose in player") > 0 and instr(1,m.items[4].displayName,"Manual selection") > 0,"playback settings accurately describe nonpersistent in-player choices")
    for each setting in m.items
        homeAssert(setting.action <> "server", "account Settings exposes no connection editor")
    end for
    m.config.locked = false
    showSettings()
    homeAssert(m.items.count() = 10 and m.items[9].action = "signout", "settings remain account-only regardless of stale lock state")
    m.configLoaded = false
    showSettings()
    homeAssert(m.items.count() = 1 and m.items[0].action = "waiting", "startup shows only a noninteractive account loading row")
end sub

sub testManualSourcesAndCategories()
    m.configLoaded = true
    m.top.dialog = invalid
    m.sidebar.focused = false
    m.list.focused = false
    m.list.hasFocus = HomeHasFocus
    m.list.itemFocused = 0
    m.listUpdating = false
    m.video = {visible:false,state:"stopped",position:0}
    m.sourceText = {visible:false,text:"",focused:false,setFocus:HomeFocus,hasFocus:HomeHasFocus}
    m.selected = {id:"tt12345",type:"movie",name:"Movie"}
    m.mode = "detail"
    m.pendingPlayback = false
    m.playing = false
    m.queue = []
    findStreams(m.selected,true)
    homeAssert(m.mode = "streams" and m.list.focused and m.items[0].action = "waiting","manual Sources claims list focus on first explicit click")
    m.sourcesAt = CreateObject("roDateTime").asSeconds()
    m.streams = []
    m.cursor = 0
    m.pollCount = 1
    response({getData:HomeGetData,getRoSGNode:HomeGetNode,data:{tag:"streampoll|" + m.generation.toStr(),ok:true,data:{events:[{seq:1,streams:[{id:"source-first",source:"provider",name:"English source",title:"Movie 🇬🇧 1080p"}]}],done:true}},node:{request:{}}})
    settleList()
    homeAssert(m.list.focused and m.items[0].id = "source-first","first discovered source stays directly selectable without second entry")
    selectItem(m.items[0])
    homeAssert(m.pendingPlayback and m.queue[m.queue.count()-1].body.stream_id = "source-first","one source OK issues playback rather than another Sources screen")
    m.pendingPlayback = false
    m.queue = []
    m.views = []
    liveCategories(80)
    homeAssert(m.categoryOffset = 80 and instr(1,m.queue[0].path,"offset=80") > 0,"category paging requests exact next offset")
    response({getData:HomeGetData,getRoSGNode:HomeGetNode,data:{tag:"livecategories|" + m.generation.toStr(),ok:true,data:{categories:[{id:"category:UK & News",name:"UK & News",count:123}],total:81}},node:{request:{}}})
    homeAssert(m.items.count() = 4 and m.items[3].action = "livecategoriesprevious","last category page has Previous but no phantom Next")
    selectItem(m.items[2])
    homeAssert(m.liveCategory = "category:UK & News" and instr(1,m.queue[m.queue.count()-1].path,"category=" + Enc("category:UK & News")) > 0,"category ID passed opaque and safely encoded")
    m.pageCount = 80
    m.offset = 80
    m.mode = "browse"
    m.items = [{id:"iptv:2:42",type:"live",name:"News"}]
    m.list.itemFocused = 0
    saveView()
    m.liveCategory = "different"
    m.pageCount = 0
    restoreView()
    homeAssert(m.liveCategory = "category:UK & News" and m.offset = 80 and m.pageCount = 80,"Back restores channel category and page context")
    m.playItem = {id:"iptv:2:218",type:"live",name:"News"}
    m.position = 0
    m.duration = 0
    m.pendingPlayback = false
    m.playing = false
    m.top.dialog = invalid
    m.queue = []
    response({getData:HomeGetData,getRoSGNode:HomeGetNode,data:{tag:"playback|" + m.generation.toStr(),ok:false,status:400,error:"Source unavailable."},node:{request:{}}})
    homeAssert(m.mode = "sourceerror" and m.items.count() = 1 and m.items[0].action = "retryplay","playback failure offers explicit retry without language consent or fallback")
    homeAssert(m.queue.count() = 0,"selected live source failure cannot start an alternative")
    m.playerOverlay = {visible:true,opened:false,focused:false,setFocus:HomeFocus}
    m.playing = true
    m.sidebar.focused = false
    m.top.dialog = {close:false}
    playerDialogClosed()
    homeAssert(not m.playerOverlay.focused,"delayed close cannot steal replacement modal focus")
    m.top.dialog = invalid
    playerDialogClosed()
    homeAssert(m.playerOverlay.focused and m.playerOverlay.opened,"Back-closing player dialog restores reachable controls")
end sub

sub testPosterRouteRestore()
    m.standardList = {visible:true,setFocus:HomeFocus,itemFocused:0}
    m.posterGrid = {visible:false,setFocus:HomeFocus,itemFocused:8}
    m.sourceList = {visible:false,setFocus:HomeFocus,itemFocused:0}
    m.list = m.standardList
    m.listFocusTimer = {control:""}
    m.mediaType = "series"
    m.search = "coast"
    m.catalog = {id:"opaque-catalog",addon_id:"7"}
    m.offset = 80
    m.views = []
    data = []
    for i = 0 to 11
        data.push({id:"series:" + i.toStr(),type:"series",name:"Series " + i.toStr()})
    end for
    rows("Series",data,"browse","")
    m.list.itemFocused = 8
    saveView()
    rows("Details",[{name:"Episodes",action:"episodes"}],"detail","")
    homeAssert(m.standardList.visible and not m.posterGrid.visible,"details hide prior poster grid")
    m.search = "changed"
    m.offset = 0
    restoreView()
    homeAssert(m.posterGrid.visible and not m.standardList.visible,"Back restores poster renderer")
    homeAssert(m.list.jumpToItem = 8 and m.listRestoreIndex = 8 and m.listUpdating,"Back restores exact second-row card through settling guard")
    homeAssert(m.search = "coast" and m.offset = 80 and m.catalog.id = "opaque-catalog" and m.mediaType = "series","Back preserves search, page, catalog and media context")
    before = m.queue.count()
    settleList()
    homeAssert(m.queue.count() = before,"restoring cached grid does not refetch metadata")
end sub

sub testSettledSearchPreview()
    m.search = "Inception"
    m.list.itemFocused = 0
    m.listUpdating = false
    m.queue = []
    searchEverything()
    m.sidebar.focused = true
    m.list.focused = false
    m.detailInfo.text = "VIPTV"
    searchBatch("movie",{ok:true,data:{metas:[{id:"tt1375666",type:"movie",name:"Inception",releaseInfo:"2010",description:"A local synopsis"}]}})
    homeAssert(m.listUpdating,"initial search result uses content-settling guard")
    before = m.queue.count()
    settleList()
    homeAssert(m.gridActive and m.status.text = "Inception · 2010","settled search poster paints its selected title and year without a competing detail pane")
    homeAssert(m.queue.count() = before and m.sidebar.focused and not m.list.focused,"preview repaint performs no HTTP and never takes focus")
    showMetadata({meta:{id:"tt1375666",type:"movie",name:"Inception",releaseInfo:"2010"}})
    homeAssert(m.status.text = "" and m.detailInfo.text = "2010","detail year remains in metadata panel without duplicate footer")
end sub

sub testStableShelfCompletionOrder()
    m.profile = "stable-shelf-order"
    m.sidebar.focused = false
    showHome()
    root = m.homeRoot
    homeResponse("series",{ok:true,data:{metas:[{id:"series-zero",name:"Series zero"},{id:"series-selected",name:"Selected series"}]}})
    homeAssert(m.homeRowKeys.count() = 1 and m.homeRowKeys[0] = 2,"series may finish first without inventing other shelves")
    seriesRow = root.getChild(0)
    m.homeAutoPick = false
    m.homePosition = [2,1]
    homeRestore()
    homeRestoreSettled()
    m.sidebar.focused = true
    m.homeRows.focused = false
    for each kind in ["progress","movie","favorites"]
        data = [{id:kind+"-item",type:"movie",name:kind+" item"}]
        if kind = "movie" then data = {metas:data}
        homeResponse(kind,{ok:true,data:data})
        homeAssert(m.homeRoot.isSameNode(root),"ordered insertion retains native content root")
        previous = -1
        for each logicalKey in m.homeRowKeys
            homeAssert(logicalKey > previous,"populated shelves always follow logical order, not HTTP order")
            previous = logicalKey
        end for
        displaySeries = -1
        for index = 0 to m.homeRowKeys.count()-1
            if m.homeRowKeys[index] = 2 then displaySeries = index
        end for
        homeAssert(displaySeries >= 0 and root.getChild(displaySeries).isSameNode(seriesRow),"inserting surrounding shelves preserves the selected native row")
        homeAssert(m.homePosition[0] = 2 and m.homePosition[1] = 1 and homeCurrent().id = "series-selected","inserting earlier shelves preserves selected logical title")
        homeAssert(m.homeRows.jumpToRowItem[0] = displaySeries and m.homeRows.jumpToRowItem[1] = 1,"native cursor follows selected shelf's new display index")
        homeAssert(m.sidebar.focused and not m.homeRows.focused,"ordered insertion never takes sidebar focus")
    end for
    homeAssert(m.homeRowKeys.count() = 4,"four populated responses produce four shelves")
    expectedKeys = [0,1,2,4]
    for index = 0 to 3
        homeAssert(m.homeRowKeys[index] = expectedKeys[index],"Continue Movies Series My List order is stable after out-of-order callbacks")
    end for
end sub

sub testSourceRouteIdentity()
    m.accountEpoch = 1
    m.sidebar.focused = false
    m.top.dialog = invalid
    m.startup = {control:""}
    m.heartbeat = {control:""}
    m.video = {visible:false,position:0,duration:0}
    m.session = ""
    for each kind in ["movie","series"]
        m.queue = []
        m.tasks = []
        m.views = []
        m.mode = "streams"
        m.list.itemFocused = 0
        m.position = 345
        m.duration = 1800
        m.sourcesAt = CreateObject("roDateTime").asSeconds()-60
        epoch = m.sourcesAt
        a = {id:"opaque-A",type:kind,name:"Title A",year:2020,imdb_id:"tt1234567"}
        b = {id:"opaque-B",type:kind,name:"Title B"}
        if kind = "series"
            a.series_id = "same-parent"
            a.season = 1
            a.episode = 1
            b.series_id = "same-parent"
            b.season = 1
            b.episode = 2
        end if
        m.playItem = a
        m.streams = [{id:"A-one",name:"Source",source:"A",title:"720p H264",sourceEpoch:epoch},{id:"A-two",name:"Source",source:"A",title:"Unknown",sourceEpoch:epoch}]
        m.items = m.streams
        m.job = "job-A"
        m.cursor = 4
        m.pollCount = 2
        m.discoveryDone = true
        saveView()
        a.name = "mutated"
        m.streams[0].id = "mutated"
        homeAssert(m.views[0].sourceState.playItem.name = "Title A" and m.views[0].items[0].id = "A-one","source snapshot is deep immutable plain data")
        homeAssert(m.views[0].sourceState.access_token = m.config.access_token and m.views[0].sourceState.account_id = m.config.account_id and m.views[0].sourceState.account_epoch = m.accountEpoch and m.views[0].sourceState.last_profile_id = m.profile,"source snapshot freezes canonical account and selected-profile scope")
        homeAssert(m.views[0].sourceState.token = invalid and m.views[0].sourceState.profile = invalid,"source snapshot has no retired config aliases")
        m.playItem = b
        m.streams = [{id:"B-one",name:"B"}]
        m.items = m.streams
        m.position = 999
        m.duration = 3600
        m.sourcesAt = CreateObject("roDateTime").asSeconds()
        saveView()
        homeAssert(m.views.count() = 2,"same cursor cannot deduplicate different movie or episode source routes")
        ignored = m.views.pop()
        m.pendingPlayback = false
        m.playing = false
        restoreView()
        homeAssert(m.playItem.id = "opaque-A" and m.playItem.type = kind and m.playItem.year = 2020 and m.playItem.imdb_id = "tt1234567","Back restores original matching identity")
        if kind = "series" then homeAssert(m.playItem.episode = 1 and m.playItem.series_id = "same-parent","Back never borrows another episode's coordinates")
        homeAssert(m.position = 345 and m.duration = 1800 and m.sourcesAt = epoch and m.items[0].sourceEpoch = epoch,"Back restores original progress duration and candidate age")
        homeAssert(m.streams[0].id = "A-one" and m.job = "job-A" and m.cursor = 4,"Back restores the same-media discovery pool")
        m.queue = []
        selectItem(m.items[0])
        entry = m.queue[m.queue.count()-1]
        homeAssert(entry.body.stream_id = "A-one" and entry.body.position = 345,"restored source starts A at A position")
        beforeFailure = m.queue.count()
        response({getData:HomeGetData,getRoSGNode:HomeGetNode,node:{request:entry},data:{tag:entry.tag,ok:false,status:400,error:"HTTP 400"}})
        homeAssert(m.queue.count() = beforeFailure and m.playItem.id = "opaque-A" and m.mode = "sourceerror","selected source failure never starts A-two automatically")
        m.pendingPlayback = false
        m.playing = true
        m.playbackLive = false
        m.playbackMode = "transcode"
        m.video.position = 10
        m.timelineOffset = 345
        saveProgress()
        homeAssert(m.queue[m.queue.count()-1].body.id = "opaque-A" and m.queue[m.queue.count()-1].body.position = 355,"restored playback progress remains under A identity")
        m.playing = false
        restoreView()
        homeAssert(m.position = 355,"returning from A playback retains its newest actual progress")
        oldEpoch = CreateObject("roDateTime").asSeconds()-1501
        m.sourcesAt = oldEpoch
        m.items[0].sourceEpoch = oldEpoch
        m.streams[0].sourceEpoch = oldEpoch
        saveView()
        m.playItem = b
        m.position = 999
        restoreView()
        m.queue = []
        selectItem(m.items[0])
        homeAssert(m.queue.count() = 1,"expired restored source emits one request")
        homeAssert(m.queue[0].path = "/api/streams","expired restored source rediscovery instead of stale playback")
        homeAssert(m.queue[0].body.id = "opaque-A","expired restored source keeps media A")
        homeAssert(m.position = 355,"expired restored source keeps A progress")
    end for
    m.accountEpoch = invalid
end sub

sub testOrdinaryAcknowledgementFocus()
    m.pendingPlayback = false
    m.playing = false
    m.pausedVOD = false
    m.video.visible = false
    m.config.capabilities = {max_height:720}
    for each tag in ["browse","guide","catalogs","profiles"]
        m.queue = []
        m.mode = "browse"
        m.mediaType = "live"
        m.offset = 0
        m.chooseProfile = true
        m.selected = {id:"channel",type:"live",name:"Channel"}
        m.sidebar.focused = false
        homeAssert(homeKey("left"),"Left owns sidebar during outstanding acknowledgement")
        m.list.focused = false
        m.homeRows.focused = false
        data = {channels:[{id:"channel",name:"Channel"}],total:1}
        if tag = "guide" then data = {programs:[]}
        if tag = "catalogs"
            m.mediaType = "movie"
            data = [{id:"catalog",type:"movie",name:"Catalog"}]
        end if
        if tag = "profiles" then data = [{id:"viewer",name:"Viewer",setup_complete:true}]
        response({getData:HomeGetData,getRoSGNode:HomeGetNode,node:{request:{}},data:{tag:tag+"|"+m.generation.toStr(),ok:true,data:data}})
        homeAssert(m.sidebar.focused and not m.list.focused and not m.homeRows.focused,"late "+tag+" ack cannot steal sidebar focus")
    end for
    m.chooseProfile = false
    m.homeRows.focused = false
    m.sidebar.focused = false
    m.list.focused = false
    m.list.focused = false
    rows("Explicit user navigation",[],"settings")
    homeAssert(m.list.focused,"acknowledgement guard does not suppress later explicit navigation")
end sub

sub HomeFocus(value as boolean)
    m.focused = value
end sub
function HomeHasFocus() as boolean
    return m.focused
end function
function HomeFind(id as string) as dynamic
    return invalid
end function
function HomeGetData() as object
    return m.data
end function
function HomeGetNode() as object
    return m.node
end function
sub homeAssert(value as boolean, message as string)
    if not value then throw "Home assertion failed: " + message
end sub
