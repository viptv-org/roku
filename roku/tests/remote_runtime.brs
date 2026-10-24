sub runChecks()
    defaultLibrary = {source:"favorites",type:"all",offset:0,limit:100,sort:"last_watched",show:"all",genre:invalid}
    producer = ParseJson(ReadAsciiFile("pkg:/tests/fixtures/producer-viewing-v3.json"))
    ' Shared snapshot examples are partial; complete them with explicit current
    ' paging facts. The shared reverse fixture below asserts the full producer contract.
    producer.live_pagination_snapshot.first_page.paging = {origin:"0",limit:1,page_size:1,previous:invalid,next:{cursor:"1",limit:1,page_size:1}}
    producer.live_pagination_snapshot.compatible_next_page.paging = {origin:"1",limit:1,page_size:1,previous:{cursor:"0",limit:1,page_size:1},next:invalid}
    producer.live_pagination_snapshot.configuration_changed_next_page.paging = RCopy(producer.live_pagination_snapshot.compatible_next_page.paging)
    producer.live_pagination_snapshot.reload_first_page.paging = RCopy(producer.live_pagination_snapshot.first_page.paging)

    rCheck(m.navigation.focusable,"navigation explicitly accepts native Roku focus")
    rNavigation(producer.navigation.movie_and_live)
    contracts = ParseJson(ReadAsciiFile("pkg:/tests/fixtures/remote-v3.json"))
    rCheck(RHomeWire(contracts.home),"shared producer Home fixture")
    rCheck(RemoteWireResponse({path:"/api/profiles/7/viewing-action"},{ok:true,data:contracts.viewing_action.response}).ok,"shared producer viewing-action fixture")
    m.networkTick.control = "stop"
    m.pollTick.control = "stop"
    m.config = {base:"https://example.test",access_token:"fixture",refresh_token:"fixture-refresh",capabilities:{max_width:1920,max_height:1080,h264:true,aac:true,hevc:false}}
    m.profile = "7"
    card = {identity:{kind:"movie",id:"opaque-17",ids:[]},provider_id:"simkl",view:{saved:false},title:"The server title",subtitle:"Server caption",description:"The original server description.",badges:[],poster:"",landscape:"",progress:0.4}
    second = ParseJson(FormatJson(card))
    second.identity.id = "opaque-1"
    second.title = "Second in server order"
    rReset("home")
    homeStates = {scope:{account_id:"2",profile_id:"7",revision:1},revision:1,hero:invalid,featured:[],complete:false,rows:[
        {id:"pending-row",title:"Loading from server",provider_id:"simkl",state:"Pending",view:{card_shape:"landscape"},cards:[],next_cursor:invalid},
        {id:"empty-row",title:"Hidden empty",provider_id:"simkl",state:"Empty",view:{card_shape:"landscape"},cards:[],next_cursor:invalid},
        {id:"failed-row",title:"Recoverable",provider_id:"simkl",state:"Failed",message:"Provider failed",view:{card_shape:"poster"},cards:[],next_cursor:invalid},
        {id:"server-row",title:"From your server",provider_id:"simkl",state:"Ready",view:{card_shape:"landscape"},cards:[card,second],next_cursor:invalid}
    ]}
    rHome(homeStates)
    rCheck(m.homeRows.count() = 3 and m.shelves.content.getChildCount() = 3,"Home keeps server pending/failed rows and omits empty rows")
    rCheck(m.shelves.content.getChild(0).getChildCount() = 6 and m.shelves.content.getChild(0).getChild(0).wire.homeSkeleton = true,"pending row uses six bounded skeleton cards")
    failedNode = m.shelves.content.getChild(1).getChild(0)
    rCheck(failedNode.wire.homeRowRetry = true and failedNode.description = "Provider failed","failed row renders server message with explicit recovery")
    rHomeTarget({row_id:"failed-row",key:"",index:[1,0]})
    m.queue = []
    rRun(failedNode.wire)
    rCheck(m.queue[m.queue.count()-1].path = "/api/profiles/7/home" and m.queue[m.queue.count()-1].tag = "home","failed row retry asks the current server Home snapshot")
    rReset("home")
    rHome({scope:{account_id:"2",profile_id:"7",revision:1},revision:1,hero:invalid,featured:[],rows:[{id:"only-empty",title:"Empty",provider_id:"simkl",state:"Empty",view:{card_shape:"landscape"},cards:[],next_cursor:invalid}],complete:true})
    rCheck(m.retryBar.visible and m.retryBar.content.getChild(0).wire.action = "settings","complete empty Home exposes the server-supported settings action")
    rReset("home")
    rHome({scope:{account_id:"2",profile_id:"7",revision:1},revision:1,hero:card,featured:[],rows:[{id:"server-row",title:"From your server",state:"Ready",view:{card_shape:"landscape"},cards:[card,second],next_cursor:invalid}],complete:true})
    rCheck(m.shelves.content.getChild(0).getChild(0).wire.identity.id = "opaque-17","server row order")
    rReset("detail")
    episode = ParseJson(FormatJson(card))
    episode.identity.episode = {order:"aired",season:1,episode:1}
    episode.view.preview = {background:invalid,caption:invalid,progress:invalid,action:"play"}
    m.detailData = {item:card,episodes:[episode],recommendations:[],next_cursor:invalid,seasons:[]}
    m.shelves.visible = true
    m.shelves.translation = [96,888]
    rShelfFocused({getData:function() : return [0,0] : end function})
    rCheck(m.top.findNode("homeSlide").keyValue[1][1] = 691,"episode focus scrolls the full episode card into view")
    rDetailScroll(false)
    rCheck(m.top.findNode("homeSlide").keyValue[1][1] = 888,"returning detail focus restores the hero position")
    rCheck(m.heroTitle.text = card.title,"hero title")
    rCheck(m.actions.content.getChildCount() = 3,"home actions")
    rCheck(m.navigation.destinations[1].id = "home","top navigation")
    rRun({action:"play",card:second})
    q = m.queue[m.queue.count()-1]
    if q.path <> "/api/profiles/7/viewing-action" then print "ENCODE_DIAGNOSTIC: ";q.path
    rCheck(q.path = "/api/profiles/7/viewing-action","Play goes to server")
    rCheck(q.body.card.identity.id = "opaque-1","Play preserves canonical identity")
    rCheck(q.body.restart = false,"Play sends intent rather than local resume")
    rPageResponse("viewing",{card:second,label:"Resume",resume:true,source_selection:"ask"},{})
    q = m.queue[m.queue.count()-1]
    rCheck(q.path = "/api/streams" and q.body.id = "opaque-1","discovery uses resolved target")
    rCheck(m.drawer.visible and m.drawerKind = "sources","source drawer")
    sources = [{id:"server-second",name:"Wrong raw title",view:{title:"Server winner",body:"Server body",quality_label:"Server quality",format_label:"Server format",addon_label:"Addon Z"},presentation:{quality:"1080p",provider_name:"Provider Z"}},{id:"server-first",name:"Other",presentation:{quality:"2160p",provider_name:"Provider A"}}]
    rShowSources(sources)
    rCheck(m.drawerRows.content.getChild(0).wire.source.id = "server-second","server rank beats quality/name heuristics")
    rCheck(m.drawerRows.content.getChild(0).title = "Server winner" and m.drawerRows.content.getChild(0).description = "Server body","source display uses server projection instead of raw title")
    rCheck(m.admission = invalid,"ranking does not invent auto-start authority")
    rStartSource(sources[0])
    q = m.queue[m.queue.count()-1]
    rCheck(q.path = "/api/playback","current playback endpoint")
    rCheck(q.body.stream_id = "server-second" and q.body.resume = true,"server resume survives")
    rCheck(q.body.client.can_play_direct = false and q.body.force_gateway,"gateway only")
    rCheck(not q.body.client.doesExist("native_torrent"),"no local torrent")
    rCheck(q.body.client.max_height = 1080,"observed device facts")
    rStopPlayer()
    rCheck(m.admission = invalid,"cancel admission")
    rCheck(left(m.queue[m.queue.count()-1].path,23) = "/api/playback-requests/","cancel request before lease id")
    m.pending = {}
    m.discovery = {id:"rank-job",after:2,streams:sources,done:true,due:9999999999#}
    m.viewingAction = {card:second,resume:true,source_selection:"best"}
    m.playIntent = {explicit:false}
    m.sourceQuality = invalid
    rPageResponse("sources:rank",{streams:sources,best_match_id:"server-first",quality_filters:[],total:2},{context:{after:2,quality:invalid}})
    q = m.queue[m.queue.count()-1]
    rCheck(q.body.stream_id = "server-first","named server best-match overrides even row order")
    rStopPlayer()
    m.membership = {identities:[card.identity],complete:true}
    card.view = {saved:false}
    rCheck(not rIsSaved(card),"saved presentation overrides local membership")
    m.pending = {}
    m.section = "Playback"
    rSettingsResponse("settings:preferences",{revision:5,preferences:{server_choice:"b"},controls:[{id:"server_choice",group:"playback",label:"Server choice",choices:[{label:"B",value:"b"}]}]},{})
    rCheck(m.rows.content.getChildCount() = 1 and m.rows.content.getChild(0).title = "Server choice","settings controls are server-owned")
    rSettingsSection("Display")
    rSettingsResponse("settings:preferences",{revision:5,preferences:{subtitle_mode:"always"},display:{accent_color:"#F5C542",show_ratings:true,text_size:"default",reduce_motion:"follow",screen_saver_minutes:5,screen_inset:0},controls:[{id:"accent_color",group:"display",label:"Accent colour",description:"Progress bars, marks and toggles",kind:"swatches",choices:[{label:"Amber",value:"#F5C542"},{label:"Mint",value:"#62D9BC"}]},{id:"screen_inset",group:"display",label:"Fit to screen",kind:"calibration",min:0,max:20,step:1}]},{})
    rCheck(m.rows.content.getChildCount() = 2 and m.rows.content.getChild(0).title = "Accent colour","Display renders current producer controls")
    m.queue = []
    m.pending = {}
    rRun({action:"savePreference",field:"accent_color",value:"#62D9BC"})
    q = m.queue[m.queue.count()-1]
    rCheck(q.body.doesExist("display") and not q.body.doesExist("preferences") and q.body.display.accent_color = "#62D9BC","Display saves a display-only server-owned update")
    rRun({action:"toggleAddon",connection:{id:"addon:opaque"},enabled:false})
    q = m.queue[m.queue.count()-1]
    rCheck(q.method = "PUT" and q.path = "/api/profiles/7/addon-activation" and q.body.count() = 2,"addon intent does not construct assignments")
    rReset("profiles")
    management = {profiles:[{id:"7",name:"A",can_delete:false}],capabilities:{create:{availability:"Unavailable"},rename:{availability:"Unavailable"},avatar:{availability:"Unavailable"},delete:{availability:"Unavailable"}},parent:{restricted:false},avatar_ids:[]}
    rProfiles(management)
    rCheck(not m.actions.visible,"unsupported profile actions omitted")
    rCheck(m.grid.content.getChildCount() = 1,"profile renders server data")
    management.profiles = []
    for i = 1 to 12
        management.profiles.push({id:i.toStr(),name:"Profile "+i.toStr(),can_delete:false})
    end for
    rProfiles(management)
    rCheck(m.shelves.numRows = 1 and m.shelves.content.getChild(0).getChildCount() = 12,"large accounts retain one horizontal virtual profile row")
    rReset("movie")
    m.browseQuery = {type:"movie",skip:"0"}
    m.controls = {catalogs:[],controls:[]}
    rPageResponse("browse",{cards:[second,card],next_cursor:"opaque-cursor",complete:false},{})
    rCheck(m.grid.content.getChild(0).wire.identity.id = "opaque-1","catalog server order")
    rCheck(m.nextCursor = "opaque-cursor","opaque cursor preserved")
    m.pending = {}
    rGridFocused()
    m.grid.jumpToItem = 1
    rGridFocused()
    rCheck(m.browseQuery.skip = "opaque-cursor","cursor not incremented")
    rReset("settings")
    m.section = "Source integrations"
    rSettingsResponse("settings:sources",{revision:1,schemas:[{plugin_id:"off",name:"Hidden",runtime_enabled:false,state:"Unavailable"},{plugin_id:"m3u",name:"M3U",runtime_enabled:true,state:"NeedsConfiguration",credential_fields:[]}]},{})
    rCheck(m.rows.content.getChildCount() = 1,"unavailable integration omitted")
    rCheck(m.rows.content.getChild(0).title = "M3U","supported configuration retained")
    bad = RemoteWireResponse({path:"/api/bootstrap"},{ok:true,data:{contract_version:2,identity:{},profile_management:{}}})
    rCheck(not bad.ok and bad.contract_error,"old contract refuses local fallback")
    m.pending["sources:start"] = "1-current"
    rResponse({getData:remoteStaleSourceData,getRoSGNode:remoteStaleSourceNode})
    rCheck(m.pending["sources:start"] = "1-current","stale result cannot clear newer request ownership")
    rCheck(m.queue[m.queue.count()-1].path = "/api/streams/stale-job","late discovery admission is retired")
    m.config.refresh_token = "keep-refresh"
    m.config.access_token = "keep-access"
    rResponse({getData:remoteTransientData,getRoSGNode:remoteRefreshNode})
    rCheck(m.config.refresh_token = "keep-refresh" and m.config.access_token = "keep-access","transient restore retains rotating credentials")
    rResponse({getData:remoteDeniedData,getRoSGNode:remoteLogoutNode})
    rCheck(m.config.refresh_token = "keep-refresh","denied sign-out retains session")
    m.keyboard.prompt = "Password"
    m.keyboard.secret = true
    m.keyboard.text = "private-test"
    rCheck(m.keyboard.findNode("value").text <> "private-test","secret input is masked")
    m.keyboard.text = ""
    rOpenDrawer("Parent",[{title:"Child",action:"close"}],"test-parent")
    rOpenDrawer("Child",[{title:"Done",action:"close"}],"test-child")
    rCloseDrawer()
    rCheck(m.drawerTitle.text = "Parent" and m.drawerKind = "test-parent","nested Back restores parent panel")
    m.pending = {}
    m.queue = []
    m.persistLatest = {base:"https://example.test",auth_origin:"https://example.test",auth_version:3,access_token:"latest-access",refresh_token:"latest-refresh"}
    rResponse({getData:remotePersistData,getRoSGNode:remotePersistOldNode})
    rCheck(m.queue[m.queue.count()-1].body.refresh_token = "latest-refresh","credential persistence drains across retired epochs")
    rReset("home")
    m.pending = {}
    m.queue = []
    delivery = {kind:"gateway",url:"https://media.example.test/lease.m3u8",format:"hls",position:0,timeline_offset_seconds:30,duration:120,live:false}
    lease = {session:{id:"lease-test",delivery:delivery,actions:producer.playback_actions.vod},card:card,source:{id:"server-source"},body:{},owner:{base:"https://example.test",access_token:"fixture",epoch:m.epoch},firstFrame:true,sequence:0,started:rNow()}
    rLeaseClock(lease,{expires_at:rNow()+60,renew_after_seconds:20})
    m.playback = lease
    m.replacement = invalid
    remaining = lease.remaining
    rPlayerFailure("player:renew:lease-test",{status:503,error:"Temporary"},{})
    rCheck(m.playback <> invalid and m.playback.remaining = remaining,"transient heartbeat retains media without extending authority")
    rPlayerFailure("player:first-frame",{status:403,error:"Old refusal"},{context:{id:"retired-lease"}})
    rCheck(m.playback <> invalid,"stale first-frame refusal cannot stop replacement")
    m.playback.remaining = 0
    rPlayerPoll(rNow())
    rCheck(m.playback = invalid,"expired authorization stops the decoder")
    rReset("live")
    m.liveQuery = ""
    channel = {id:"channel-one",card:card}
    page = {channels:[channel],groups:[],connections:[],reason:"",next_cursor:""}
    rLive(page)
    guide = {channel_id:"channel-one",programs:[{id:"server-current",title:"Current program",start_millis:5000,end_millis:9000}],view:{current_program_id:"server-current",window_start_millis:5000}}
    rLiveGuide(guide,{context:{channel:"channel-one"}})
    rCheck(m.rows.content.getChild(0).guideData.channel_id = "channel-one","initial guide loaded")
    rLive(page,true)
    rCheck(RGet(m.rows.content.getChild(0).guideData,"channel_id") = "channel-one","cached guide survives channel page replacement")
    rCheck(m.rows.content.getChild(0).programIndex = 0,"restored guide uses server current program")
    rCheck(m.rows.content.getChild(0).viewport.start_millis = 5000,"restored guide uses server window")
    m.config.locked = true
    m.profile = ""
    rWelcome()
    rCheck(m.top.findNode("entry").mode = "welcome","KMP poster-wall welcome is first entry state")
    rCheck(m.actions.content.getChildCount() = 1,"only supported welcome action")
    rRun(m.actions.content.getChild(0).wire)
    rCheck(m.route = "choice" and m.rows.content.getChildCount() = 3,"supported KMP sign-in choices")
    rCheck(m.rows.content.getChild(0).wire.icon = "entry-phone","sign-in option icon")
    rCheck(m.rows.content.getChild(0).uiHeight = 100,"KMP entry option geometry")
    rRun(m.rows.content.getChild(0).wire)
    rCheck(m.route = "pairing" and m.pairCode.text = "Waiting","pairing loading uses the KMP two-column screen")
    m.pairingRequestFromTest = m.queue[m.queue.count()-1]
    rBack()
    rCheck(m.route = "choice","pairing Back restores choices")
    rResponse({getRoSGNode:remotePairingNode,getData:remotePairingData,pairingRequestFromTest:m.pairingRequestFromTest})
    rCheck(m.route = "choice","late pairing challenge cannot reopen a cancelled screen")
    rBack()
    rCheck(m.route = "welcome","choice Back restores welcome")
    m.queue = []
    m.pending = {}
    rReset("startup")
    rTextInput("Server address","server",false,"http://invalid.test")
    rTextDone()
    rCheck(m.keyboard.visible and m.keyboard.text = "http://invalid.test" and m.keyboard.error <> "","invalid origin retains the editable draft")
    boot = {identity:{profile_id:"7"},profile_management:{profiles:[]},preferences:{},library_membership:{},revisions:{},home:contracts.home}
    request = {tag:"auth:bootstrap",request_id:"draft-bootstrap",epoch:m.epoch,generation:m.generation,method:"GET",path:"/api/bootstrap"}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:request,result:{ok:true,status:200,data:boot}})
    rCheck(m.keyboard.visible and m.route = "startup","late bootstrap cannot dismiss a server draft")
    rTextCancel()
    rCheck(m.route = "home" and not m.keyboard.visible,"cancelling the draft applies the accepted bootstrap")
    rReset("movie")
    m.browseQuery = {type:"movie",skip:"0"}
    m.pending = {}
    rBrowsePage()
    retired = m.queue[m.queue.count()-1]
    rRetireCatalog()
    m.browseQuery.catalog = "new-catalog"
    rBrowsePage()
    currentPending = m.pending.browse
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:retired,result:{ok:true,status:200,data:{cards:[card],complete:true}}})
    rCheck(m.cards.count() = 0 and m.pending.browse = currentPending,"retired catalog cannot populate the new query or clear its request")
    m.route = "library"
    m.libraryQuery = {type:"all",offset:"0",limit:"100"}
    rLibraryHeader({query:{type:"series"},controls:[{id:"type",choices:[{label:"Series first",value:"series"},{label:"Everything",value:"all"}]}]})
    rCheck(m.libraryHeader.content.getChild(0).title = "Series first","library preserves server type order and labels")
    rCheck(m.libraryHeader.content.getChild(0).wire.selected = true,"library selected type comes from accepted server query")
    rRun(m.libraryHeader.content.getChild(0).wire)
    rCheck(m.libraryQuery.type = "series" and m.libraryQuery.offset = "0","library type activation resets pagination")
    rCheck(m.pending.doesExist("library"),"library type activation requests server data")
    projected = ParseJson(FormatJson(card))
    projected.subtitle = "Wrong raw subtitle"
    projected.badges = ["uhd","hdr"]
    projected.view = {saved:false,metadata_parts:["Server kind","Server year"],hero_metadata_parts:["Server year"],hero_badges:[{label:"HDR first",role:"capability"},{label:"4K second",role:"capability"}]}
    m.route = "detail"
    rHero(projected)
    rCheck(m.heroMeta.parts[0] = "Server kind" and m.heroMeta.badges[0].label = "HDR first","metadata and badges preserve server projection and order")
    rDetailActions(projected,{label:"Server resume",resume:true,remaining_label:"Server remaining",progress:0.123})
    rCheck(m.actions.content.getChild(0).wire.remainingLabel = "Server remaining" and m.actions.content.getChild(0).wire.resumeProgress = 0.123,"resume display consumes server label and progress")
    projected.progress = 0.99
    projected.view.progress = 0.17
    projected.view.compact_metadata_parts = ["Server compact","Caption"]
    tile = rContent([projected],232,424,348,"poster").getChild(0)
    rCheck(tile.progressFraction = 0.17 and tile.description = "Server compact · Caption","tile caption and progress use server projection")
    projected.view.tile_badge = {label:"Server watched label",role:"watched"}
    tileNode = CreateObject("roSGNode","RemoteItem")
    tileNode.itemContent = rContent([projected],232,424,348,"poster").getChild(0)
    rCheck(tileNode.findNode("watchedBadge").visible,"typed watched badge is rendered")
    projected.view.tile_badge = {label:"Server new label",role:"new_episodes"}
    tileNode.itemContent = rContent([projected],232,424,348,"poster").getChild(0)
    rCheck(not tileNode.findNode("watchedBadge").visible and tileNode.findNode("tileBadgeLabel").text = "Server new label","tile reuse replaces server badge without raw badge inference")
    rPassword()
    rCheck(m.passwordForm.visible and not m.keyboard.visible,"password uses combined form")
    input = m.passwordForm.findNode("input")
    input.callFunc("onKeyEvent","OK",true)
    rCheck(m.passwordForm.username = "q","initial password keyboard focus is q")
    input.exitUp = true
    rCheck(m.passwordForm.findNode("fields").isInFocusChain() and not input.isInFocusChain(),"field activation owns native focus")
    m.passwordForm.callFunc("onKeyEvent","OK",true)
    input.callFunc("onKeyEvent","OK",true)
    rCheck(m.passwordForm.password = "q" and m.passwordForm.username = "q","editing target changes without losing username")
    input.exitRight = true
    rCheck(m.passwordForm.findNode("buttons").isInFocusChain() and not input.isInFocusChain(),"password actions own native focus")
    m.passwordForm.callFunc("onKeyEvent","OK",true)
    m.request = m.queue[m.queue.count()-1]
    rCheck(m.request.tag = "auth:login" and m.request.body.password = "q","sign in sends exact draft once")
    rCheck(m.passwordForm.password = "" and input.text = "","submitted password clears both UI drafts")
    m.result = {ok:false,status:401,error:"Unauthorized"}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rCheck(m.passwordForm.username = "q" and not m.passwordForm.busy and m.passwordForm.error <> "","failed login keeps username and usable form")
    rCheck(m.request.body.password = "","completed login request no longer retains password")
    m.passwordForm.password = "another synthetic password"
    rPasswordSubmit()
    m.request = m.queue[m.queue.count()-1]
    tokenBeforeCancel = m.config.access_token
    rPasswordCancel()
    m.result = {ok:true,status:200,data:{access_token:"cancelled-grant",refresh_token:"cancelled-refresh",expires_in:300}}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rCheck(m.config.access_token = tokenBeforeCancel and m.route = "choice","cancelled login cannot replace credentials or route")
    revoked = false
    for each queued in m.queue
        if queued.path = "/api/auth/logout" and queued.method = "POST" and queued.access_token = "cancelled-grant" then revoked = true
    end for
    rCheck(revoked,"late successful login is revoked with its own credential")
    rPassword()
    input = m.passwordForm.findNode("input")
    input.callFunc("onKeyEvent","OK",true)
    rCheck(m.passwordForm.username = "q" and m.passwordForm.password = "","reopening password form resets key and clears drafts")
    draftQuery = {values:[{id:"genre",values:["server-first","server-second"]}],offset:0}
    draftBody = {nested:{value:"original"}}
    draftContext = {generation:17}
    m.queue = []
    m.pending = {}
    rSend("GET","/api/discover",draftBody,"query-snapshot",draftContext,draftQuery)
    draftQuery.values[0].values[0] = "changed draft"
    draftBody.nested.value = "changed body"
    draftContext.generation = 18
    frozen = m.queue[0]
    rCheck(frozen.query.values[0].values[0] = "server-first" and frozen.body.nested.value = "original" and frozen.context.generation = 17,"queued request owns immutable draft snapshots")
    rCheck(REqual({b:false,a:[1,"1",invalid]},{a:[1,"1",invalid],b:false}),"wire equality ignores object insertion order")
    rCheck(not REqual([1,"1"],["1",1]) and not REqual(false,0),"wire equality preserves array order and scalar types")
    rCheck(RValueKey({a:"x",b:"y"}) = RValueKey({b:"y",a:"x"}),"identity keys are independent of field insertion order")
    rCheck(RValueKey(["ab","c"]) <> RValueKey(["a","bc"]),"identity key framing avoids concatenation collisions")
    m.route = "movie"
    m.selectedCatalog = invalid
    m.controls = {catalogs:[],controls:[{id:"genre",label:"Genre",kind:"MultiChoice",maximum_selections:2,choices:[{value:"b",label:"Server B"},{value:"a",label:"Server A"},{value:"c",label:"Server C"}]}]}
    m.browseQuery = {type:"movie",skip:"opaque-cursor",values:[{id:"genre",values:["a"]}]}
    rFiltersOpen()
    rCheck(m.filterPage.draft.genre[0] = "a","filter draft starts from accepted selections")
    m.filterPage.callFunc("onKeyEvent","right",true)
    m.filterPage.callFunc("onKeyEvent","OK",true)
    rCheck(REqual(m.filterPage.draft.genre,["a","b"]),"multichoice preserves server values and draft order")
    rCheck(m.browseQuery.values[0].values.count() = 1,"draft editing does not mutate accepted query")
    m.filterPage.callFunc("onKeyEvent","right",true)
    m.filterPage.callFunc("onKeyEvent","right",true)
    rCheck(m.filterPage.findNode("choices").getChild(1).getChild(4).visible and not m.filterPage.findNode("choices").getChild(2).getChild(4).visible,"selection cap keeps focus off disabled choices")
    rCheck(m.filterPage.draft.genre.count() = 2,"navigation at the cap does not mutate selections")
    m.filterPage.callFunc("onKeyEvent","left",true)
    m.filterPage.callFunc("onKeyEvent","OK",true)
    m.filterPage.callFunc("onKeyEvent","right",true)
    m.filterPage.callFunc("onKeyEvent","right",true)
    m.filterPage.callFunc("onKeyEvent","OK",true)
    rCheck(REqual(m.filterPage.draft.genre,["a","c"]),"removing a choice makes an unselected choice focusable again")
    rFiltersCancel()
    rCheck(m.browseQuery.skip = "opaque-cursor" and m.browseQuery.values[0].values.count() = 1,"cancel leaves applied query unchanged")
    rFiltersOpen()
    m.filterPage.callFunc("onKeyEvent","right",true)
    m.filterPage.callFunc("onKeyEvent","OK",true)
    rFiltersSubmit()
    rCheck(m.browseQuery.skip = "0" and REqual(m.browseQuery.values[0].values,["a","b"]),"Show results applies complete draft and resets cursor")
    request = m.queue[m.queue.count()-1]
    rCheck(request.path = "/api/discover" and request.query.values[0].values[0] = "a","filter query stays structured until Task encoding")
    choices = []
    for i = 0 to 99
        choices.push({value:"opaque-"+i.toStr(),label:"Server choice "+i.toStr()})
    end for
    m.controls = {catalogs:[],controls:[{id:"long",label:"Long choices",kind:"MultiChoice",required:true,choices:choices}]}
    m.browseQuery = {type:"movie",values:[]}
    rFiltersOpen()
    m.filterPage.callFunc("onKeyEvent","right",true)
    for i = 1 to 33
        m.filterPage.callFunc("onKeyEvent","down",true)
    end for
    m.filterPage.callFunc("onKeyEvent","OK",true)
    rCheck(m.filterPage.draft.long[0] = "opaque-99","virtualized filter choices reach the final server item")
    rCheck(m.filterPage.findNode("choices").getChildCount() = 21 and m.filterPage.findNode("facets").getChildCount() = 7,"filter node pools stay bounded across scrolling")
    rFiltersCancel()
    m.controls = {catalogs:[],controls:[{id:"search",label:"Search",kind:"Text",required:false,choices:[]}]}
    m.browseQuery = {type:"movie",values:[{id:"search",values:["Server draft"]}]}
    rFiltersOpen()
    rCheck(m.filterPage.findNode("textEditor").visible,"text facet uses inline editor")
    textKeyboard = m.filterPage.findNode("textKeyboard")
    rCheck(textKeyboard.isInFocusChain(),"opening a text facet focuses its keyboard")
    textKeyboard.exitUp = true
    rCheck(m.filterPage.findNode("textField").isInFocusChain(),"text field owns focus")
    m.filterPage.callFunc("onKeyEvent","down",true)
    rCheck(textKeyboard.isInFocusChain() and textKeyboard.entryWidth = 1024,"inline keyboard uses available column width")
    keys = textKeyboard.findNode("keys")
    rCheck(keys.getChild(1).translation[0] = 104 and keys.getChild(9).translation[0] = 931,"fluid keyboard matches Compose pixel remainder distribution")
    textKeyboard.callFunc("onKeyEvent","OK",true)
    rCheck(m.filterPage.draft.search[0] = "Server draftq" and m.browseQuery.values[0].values[0] = "Server draft","inline editing remains a transient draft")
    textKeyboard.exitDown = true
    rCheck(m.filterPage.findNode("textClear").isInFocusChain(),"nonempty editor reaches Clear")
    m.filterPage.callFunc("onKeyEvent","OK",true)
    rCheck(m.filterPage.draft.search.count() = 0 and textKeyboard.isInFocusChain(),"Clear empties draft and returns usable keyboard focus")
    textKeyboard.exitLeft = true
    rCheck(m.filterPage.findNode("facets").isInFocusChain() and not textKeyboard.isInFocusChain(),"inline keyboard returns to facets without stale child focus")
    rFiltersCancel()
    rCheck(m.browseQuery.values[0].values[0] = "Server draft","text draft cancellation preserves accepted query")
    many = []
    for i = 0 to 500
        many.push("accepted-"+i.toStr())
    end for
    m.controls = {catalogs:[],controls:[{id:"uncapped",label:"Server uncapped",kind:"MultiChoice",choices:[{value:"another",label:"Another"}]}]}
    m.browseQuery = {type:"movie",values:[{id:"uncapped",values:many}]}
    rFiltersOpen()
    m.filterPage.callFunc("onKeyEvent","right",true)
    m.filterPage.callFunc("onKeyEvent","OK",true)
    rCheck(m.filterPage.draft.uncapped.count() = 502,"omitted server selection limit does not acquire a local cap")
    rFiltersCancel()
    m.route = "library"
    m.cards = []
    m.libraryQuery = {source:"requested-source",type:"all",sort:"requested-sort",genre:"old",offset:0,limit:100}
    accepted = {source:"favorites",type:"series",sort:"title",show:"all",genre:invalid,offset:0,limit:24}
    rPageResponse("library",{cards:[],query:accepted,default_query:defaultLibrary,controls:[],complete:true},{})
    rCheck(m.libraryQuery.source = "favorites" and m.libraryQuery.type = "series" and m.libraryQuery.sort = "title" and m.libraryQuery.limit = 24,"library adopts exact server-normalized query")
    rCheck(not m.libraryQuery.doesExist("genre"),"null optional library fields are omitted from subsequent HTTP queries")
    rCheck(not RemoteWireResponse({method:"GET",path:"/api/profiles/7/library"},{ok:true,data:{cards:[]}}).ok,"current library contract requires its authoritative query")
    m.libraryQuery = {source:"favorites",type:"series",sort:"title",show:"all",genre:"Drama",offset:100,limit:24}
    m.libraryControls = [{id:"source",label:"Source",choices:[]},{id:"type",label:"Type",choices:[]},{id:"sort",label:"Sort",choices:[{value:"last_watched",label:"Last watched"},{value:"title",label:"Title"}]},{id:"genre",label:"Genre",choices:[{value:"",label:"All genres"},{value:"Drama",label:"Drama"},{value:"Comedy",label:"Comedy"}]},{id:"show",label:"Show",choices:[{value:"all",label:"All titles"}]}]
    rLibrarySheetOpen()
    rCheck(m.librarySheet.findNode("fields").getChild(0).getChild(0).text = "Sort","library sheet omits source/type controls already in header")
    rCheck(m.librarySheet.draft.sort = "title" and m.librarySheet.draft.genre = "Drama","library sheet starts from complete accepted query")
    m.librarySheet.callFunc("onKeyEvent","OK",true)
    rCheck(m.librarySheet.findNode("menu").visible and m.librarySheet.findNode("menuRows").getChild(1).getChild(2).visible,"choice menu marks accepted value")
    m.librarySheet.callFunc("onKeyEvent","down",true)
    rCheck(m.librarySheet.draft.sort = "title","menu focus does not mutate draft")
    m.librarySheet.callFunc("onKeyEvent","OK",true)
    rCheck(m.librarySheet.draft.sort = "last_watched" and m.libraryQuery.sort = "title","choice changes only the sheet draft")
    m.librarySheet.callFunc("onKeyEvent","down",true)
    m.librarySheet.callFunc("onKeyEvent","OK",true)
    m.librarySheet.callFunc("onKeyEvent","back",true)
    rCheck(not m.librarySheet.findNode("menu").visible and m.librarySheet.visible,"Back closes choices before the sheet")
    m.librarySheet.callFunc("onKeyEvent","OK",true)
    m.librarySheet.callFunc("onKeyEvent","down",true)
    m.librarySheet.callFunc("onKeyEvent","OK",true)
    rCheck(not m.librarySheet.draft.doesExist("genre"),"empty optional choice removes the HTTP filter parameter")
    rCheck(m.librarySheet.findNode("fields").getChild(1).getChild(1).getChild(1).text = "All genres","empty selection displays the producer choice label")
    rLibrarySheetDismiss()
    rCheck(m.libraryQuery.genre = "Drama" and m.libraryQuery.sort = "title","sheet cancellation leaves accepted query untouched")
    rLibrarySheetOpen()
    for i = 1 to 3
        m.librarySheet.callFunc("onKeyEvent","down",true)
    end for
    m.librarySheet.callFunc("onKeyEvent","OK",true)
    rCheck(REqual(m.librarySheet.draft,RQueryFields(defaultLibrary)) and m.libraryQuery.sort = "title","Clear consumes the full server default query without applying it")
    rLibrarySheetSubmit()
    queued = m.queue[m.queue.count()-1]
    rCheck(queued.tag = "library" and queued.query.offset = "0" and queued.query.type = "all" and queued.query.sort = defaultLibrary.sort,"Apply submits the projected defaults")
    rCheck(m.librarySheet.findNode("fields").getChildCount() = 8 and m.librarySheet.findNode("menuRows").getChildCount() = 8,"library sheet keeps bounded field and menu node pools")
    rLibrarySheetDismiss()
    m.config.locked = true
    rPassword()
    rCheck(not m.passwordForm.findNode("buttons").getChild(3).visible,"fixed-server package omits unavailable server action")
    rPasswordServer()
    rRun({action:"server"})
    rCheck(not m.keyboard.visible,"fixed-server configuration cannot open a server draft")
    m.config.locked = false
    rPassword()
    rCheck(m.passwordForm.findNode("buttons").getChild(3).visible,"public package retains supported server selection")
    longChoices = []
    for i = 0 to 128
        longChoices.push({value:"genre-"+i.toStr(),label:"Genre "+i.toStr()})
    end for
    m.libraryQuery = {source:"favorites",type:"series",sort:"name_asc",show:"all",genre:"genre-128",offset:0,limit:24}
    m.libraryControls = [{id:"genre",label:"Genre",kind:"SingleChoice",choices:longChoices}]
    rLibrarySheetOpen()
    m.librarySheet.callFunc("onKeyEvent","OK",true)
    menuRows = m.librarySheet.findNode("menuRows")
    rCheck(menuRows.getChild(0).getChild(1).text = "Genre 0" and not menuRows.getChild(0).getChild(0).visible,"menu opens at the first row with no implicit keyboard selection")
    m.librarySheet.callFunc("onKeyEvent","OK",true)
    rCheck(m.librarySheet.findNode("menu").visible and m.librarySheet.draft.genre = "genre-128","Enter without menu focus does not change the server selection")
    for i = 1 to 8
        m.librarySheet.callFunc("onKeyEvent","down",true)
    end for
    rCheck(menuRows.getChild(0).getChild(1).text = "Genre 7" and menuRows.getChild(0).getChild(0).visible,"KMP menu keyboard focus scrolls to the top")
    m.librarySheet.callFunc("onKeyEvent","back",true)
    m.librarySheet.callFunc("onKeyEvent","OK",true)
    m.librarySheet.callFunc("onKeyEvent","up",true)
    rCheck(menuRows.getChild(7).getChild(1).text = "Genre 128" and menuRows.getChild(7).translation[1] = 400,"Up enters the final menu item with bottom-clamped scrolling")
    m.librarySheet.callFunc("onKeyEvent","down",true)
    rCheck(menuRows.getChild(0).getChild(1).text = "Genre 0" and menuRows.getChild(0).getChild(0).visible,"menu keyboard navigation wraps at the end")
    rLibrarySheetDismiss()
    m.route = "library"
    m.libraryQuery = {source:"favorites",type:"series",sort:"name_asc",show:"all",episodes_left_max:9,offset:0,limit:24}
    m.libraryControls = [{id:"episodes_left_max",label:"Left",choices:[{value:"",label:"Any"},{value:"9",label:"Under 10 episodes"}]}]
    rLibrarySheetOpen()
    rCheck(m.librarySheet.findNode("fields").getChild(0).getChild(1).getChild(1).text = "Under 10 episodes","numeric accepted query values use string-valued producer choice labels")
    rLibrarySheetDismiss()
    m.libraryDefaults = {source:"favorites",type:"anime",offset:0,limit:24,sort:"name_desc",show:"watched"}
    rLibrarySheetOpen()
    m.librarySheet.callFunc("onKeyEvent","down",true)
    count = m.queue.count()
    m.librarySheet.callFunc("onKeyEvent","OK",true)
    rCheck(m.librarySheet.draft.sort = "name_desc" and m.librarySheet.draft.type = "anime" and m.queue.count() = count,"Clear preserves unexpected producer defaults without a request or local reset policy")
    rLibrarySheetDismiss()
    m.pending = {}
    m.queue = []
    m.searchVersion = 42
    oldSearch = {method:"GET",path:"/api/search",tag:"search",epoch:m.epoch,generation:m.generation,context:{search_version:41},query:{query:"old"}}
    newSearch = {method:"GET",path:"/api/search",tag:"search",epoch:m.epoch,generation:m.generation,context:{search_version:42},query:{query:"current"}}
    m.retryAuth = [oldSearch,newSearch]
    m.request = {method:"POST",path:"/api/auth/device/refresh",tag:"auth:refresh",request_id:"scope-refresh",epoch:m.epoch,generation:m.generation,base:m.config.base,body:{refresh_token:m.config.refresh_token}}
    m.result = {ok:true,status:200,data:{access_token:"scope-access",refresh_token:"scope-refresh",expires_in:300}}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    searchCount = 0
    for each request in m.queue
        if request.tag = "search"
            searchCount++
            rCheck(request.query.query = "current","authentication refresh replays only the current query owner")
        end if
    end for
    rCheck(searchCount = 1,"stale auth retry cannot take the current request's deduplication slot")
    m.playback = {session:{id:"current-session",delivery:{},actions:{change_source:true,next_episode:true}},card:card}
    m.nextCard = card
    rPlayerResponse("player:next",{status:"Next",item:second},{context:{id:"retired-session"}})
    rCheck(m.nextCard.identity.id = card.identity.id,"retired playback session cannot supply current next-episode identity")
    rCheck(not rRequestCurrent({tag:"player:next",epoch:m.epoch,generation:m.generation,context:{id:"retired-session"}}),"retired playback request is not replayed after auth refresh")
    rPlayerResponse("player:next",{status:"Next",item:second},{context:{id:"current-session"}})
    rCheck(m.nextCard.identity.id = second.identity.id,"current session consumes the exact server next identity")
    rPlayerResponse("player:next",{status:"NoNext"},{context:{id:"current-session"}})
    rCheck(m.nextCard = invalid and m.playerActions.content.getChildCount() = 1,"server NoNext removes any previous next action")
    m.playback = invalid
    m.admission = invalid
    m.replacement = invalid
    rCheck(not rRequestCurrent({tag:"player:renew:retired",epoch:m.epoch,generation:m.generation}),"retired leases are not renewed after auth refresh")
    m.replacement = {session:{id:"rollback"}}
    rCheck(rRequestCurrent({tag:"player:renew:rollback",epoch:m.epoch,generation:m.generation}),"retained decoder recovery lease remains renewable")
    m.replacement = invalid
    m.pending = {}
    m.queue = []
    m.config.last_profile_id = "7"
    serverProfiles = {profiles:[{id:"7",name:"Remembered",locked:false,selection_requires_parent:false},{id:"9",name:"Server selected"}],capabilities:{},avatar_ids:[]}
    rBootstrap({identity:{account_id:"account-a"},profile_management:serverProfiles,preferences:{},library_membership:{},revisions:{}})
    rCheck(m.route = "profiles" and m.profile = "","bootstrap without a selected profile never auto-selects client registry metadata")
    for each request in m.queue
        rCheck(request.tag <> "auth:profile","profile selection requires server identity or explicit user action")
    end for
    selectedBoot = {identity:{account_id:"account-a",profile_id:"9"},profile_management:serverProfiles,preferences:{},library_membership:{},revisions:{}}
    rBootstrap(selectedBoot)
    rCheck(m.profile = "9" and m.queue[m.queue.count()-1].path = "/api/profiles/9/home","server-selected profile owns subsequent requests")
    rReset("library")
    m.editProfile = {id:"7",name:"Original profile"}
    rTextInput("Draft","renameProfile",false,"Keep this draft")
    generation = m.generation
    rBootstrap(selectedBoot)
    rCheck(m.route = "library" and m.generation = generation and m.formDialog.visible and m.formDialog.isInFocusChain() and m.formDialog.text = "Keep this draft","same-identity bootstrap preserves route and transient form")
    m.homeData = {private:"old-account"}
    m.snapshots = [{route:"home",home:m.homeData}]
    m.liveGuides = {old:{private:"old-guide"}}
    m.afterParent = {body:{secret:"old-draft"}}
    m.sourceDraft = {password:"old-draft"}
    m.config.base = "https://other.example.test"
    m.config.access_token = "other-origin-fixture"
    epoch = m.epoch
    rBootstrap(selectedBoot)
    rCheck(m.epoch > epoch and m.homeData = invalid and m.snapshots.count() = 0 and m.liveGuides.count() = 0,"same numeric profile on a different origin cannot retain old view caches")
    rCheck(m.afterParent = invalid and m.sourceDraft = invalid and m.keyboard.text = "","identity boundary clears pending parent action and form drafts")
    rCheck(m.filterPage.controls.count() = 0 and m.librarySheet.controls.count() = 0,"identity boundary releases component-owned models")
    rProfiles({profiles:[{id:"first",name:"First"},{id:"second",name:"Second"}],capabilities:{},avatar_ids:[]})
    m.shelves.jumpToRowItem = [0,0]
    rProfiles({profiles:[{id:"second",name:"Second renamed"},{id:"first",name:"First"}],capabilities:{},avatar_ids:[]})
    rCheck(m.shelves.jumpToRowItem[1] = 1,"profile-list refresh restores focus by server ID rather than row position")
    m.keyboard.visible = false
    m.inputPurpose = "renameProfile"
    m.editProfile = invalid
    count = m.queue.count()
    rTextDone()
    rCheck(m.queue.count() = count,"retired keyboard submission cannot mutate the new identity")
    episodeCard = RCopy(card)
    episodeCard.identity = {kind:"series",id:"episode-current",ids:[],episode:{order:"aired",season:1,episode:1}}
    episodeCard.parent_identity = {kind:"series",id:"series-parent",ids:[]}
    m.playback = {session:{id:"episode-session",delivery:delivery,actions:{episodes:true,change_source:true}},card:episodeCard,source:{id:"source-current"},body:{},owner:{base:m.config.base,access_token:m.config.access_token,epoch:m.epoch}}
    m.admission = invalid
    m.replacement = invalid
    m.pending = {}
    m.queue = []
    decoder = CreateObject("roSGNode","ContentNode")
    decoder.title = "Existing decoder content"
    m.player.content = decoder
    rPlayerAction({action:"player:episodes"})
    m.request = m.queue[m.queue.count()-1]
    m.result = {ok:false,status:503,error:"Episode list temporarily unavailable"}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rCheck(m.playback.session.id = "episode-session" and m.player.content.title = "Existing decoder content","episode metadata failure preserves lease and decoder content")
    rCheck(m.drawerRows.content.getChild(0).wire.action = "player:retryEpisodes" and m.drawerMessage.text = "Episode list temporarily unavailable","episode failure exposes an in-drawer retry")
    for each queued in m.queue
        rCheck(left(queued.tag,8) <> "cleanup:","episode-list failure must not delete playback")
    end for
    rRun(m.drawerRows.content.getChild(0).wire)
    m.request = m.queue[m.queue.count()-1]
    nextEpisode = RCopy(episodeCard)
    nextEpisode.identity.id = "server-episode-9"
    m.result = {ok:true,status:200,data:{item:episodeCard,episodes:[nextEpisode],seasons:[{season:1,offset:0},{season:9,offset:100}],next_cursor:"107"}}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rCheck(m.episodeFailed = invalid and m.playerEpisodes[0].identity.id = "server-episode-9" and m.episodeCursor = "107","retry consumes server episode identity/order/cursor")
    rPlayerEpisodes("107",true)
    oldPage = m.queue[m.queue.count()-1]
    rPlayerEpisodes("100",false)
    currentPage = m.queue[m.queue.count()-1]
    rCheck(oldPage.context.episode_version <> currentPage.context.episode_version,"season change retires previous episode page ownership")
    rPlayerEpisodesResponse({episodes:[episodeCard],seasons:[],next_cursor:"999"},oldPage)
    rCheck(m.playerEpisodes.count() = 0 and m.episodeCursor = "","late previous-season page cannot populate the new list")
    rPlayerEpisodesResponse({episodes:[nextEpisode],seasons:[],next_cursor:"124"},currentPage)
    m.pending.delete("player:episodes")
    rPlayerEpisodes("124",true)
    m.request = m.queue[m.queue.count()-1]
    m.result = {ok:false,status:503,error:"Page temporarily unavailable"}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    count = m.queue.count()
    rDrawerFocused()
    rCheck(m.queue.count() = count and m.playerEpisodes.count() = 1,"failed append keeps loaded episodes and does not auto-retry in a loop")
    rPlayerEpisodes("0",false)
    m.request = m.queue[m.queue.count()-1]
    m.result = {ok:false,status:403,auth_code:"parent_required",error:"Parent permission required"}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rCheck(m.formDialog.visible,"episode permission request opens the supported parent PIN flow")
    rTextCancel()
    rCheck(m.playback.session.id = "episode-session" and m.episodeFailed <> invalid and m.drawerMessage.text = "Episode access cancelled.","cancelling parent access leaves playback intact and episode retry usable")
    rCloseDrawer()
    rCheck(not rRequestCurrent(m.request) and m.playback.session.id = "episode-session","closing episode drawer retires metadata requests without stopping playback")
    m.player.content = invalid
    m.playback = invalid
    m.config.access_token = "rotated-current"
    rCleanup("/api/playback/rotated",{base:m.config.base,access_token:"expired-owner",epoch:m.epoch})
    rCheck(m.queue[m.queue.count()-1].access_token = "rotated-current","same-identity cleanup uses the refreshed credential")
    rCleanup("/api/playback/foreign",{base:"https://foreign.example.test",access_token:"foreign-owner",epoch:m.epoch})
    rCheck(m.queue[m.queue.count()-1].access_token = "foreign-owner","cleanup never sends current credentials to another origin")
    rCleanup("/api/playback/retired-owner",{base:m.config.base,access_token:"retired-owner",epoch:m.epoch-1})
    rCheck(m.queue[m.queue.count()-1].access_token = "retired-owner","cleanup never borrows credentials across identity epochs")
    rCleanup("/api/auth/logout",{base:m.config.base,access_token:"cancelled-grant",epoch:m.epoch},"POST")
    rCheck(m.queue[m.queue.count()-1].access_token = "cancelled-grant","cancelled login revokes its exact grant rather than the active one")
    m.retryAuth = []
    m.request = {method:"POST",path:"/api/auth/device/refresh",tag:"auth:refresh",request_id:"cleanup-refresh",epoch:m.epoch,generation:m.generation,base:m.config.base,body:{refresh_token:m.config.refresh_token}}
    m.result = {ok:true,status:200,data:{access_token:"rotated-again",refresh_token:"refresh-again",expires_in:300}}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    for each queued in m.queue
        if queued.path = "/api/playback/rotated" then rCheck(queued.access_token = "rotated-again","queued same-identity cleanup follows token rotation")
        if queued.path = "/api/playback/foreign" then rCheck(queued.access_token = "foreign-owner","token rotation preserves foreign-origin cleanup credentials")
        if queued.path = "/api/playback/retired-owner" then rCheck(queued.access_token = "retired-owner","token rotation preserves retired identity credentials")
        if queued.path = "/api/auth/logout" and left(queued.tag,8) = "cleanup:" then rCheck(queued.access_token = "cancelled-grant","token rotation does not redirect cancelled-grant revocation")
    end for
    m.route = "calendar"
    m.calendarType = "series"
    m.queue = []
    m.pending = {}
    m.retryAuth = [{tag:"calendar",context:{version:-1}}]
    retired = invalid
    for i = 1 to 50
        date = "2026-10-"+right("0"+((i mod 28)+1).toStr(),2)
        rRun({action:"calendarDay",date:date})
        if i = 1 then retired = m.queue[0]
    end for
    rCheck(m.queue.count() = 1 and m.queue[0].context.day = date,"rapid calendar navigation retains only the latest queued day")
    rCheck(m.retryAuth.count() = 0,"retired calendar requests cannot return through authentication retry")
    current = m.queue[0]
    pending = m.pending.calendar
    m.request = retired
    m.result = {ok:true,status:200,data:{entries:[],complete:true}}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rCheck(m.pending.calendar = pending and m.calendarEntries.count() = 0,"retired date reply cannot consume latest request ownership")
    rCalendar({entries:[{id:"calendar-current",date:date+"T12:00:00Z",card:card}],complete:true},current)
    rCheck(m.calendarEntries[0].id = "calendar-current" and m.message.text = "","latest day is rendered and loading state clears")
    stalePage = RCopy(current)
    stalePage.context.cursor = "old-page"
    m.calendarCursor = "new-page"
    rCheck(not rRequestCurrent(stalePage),"outdated calendar pagination cannot replay after authentication refresh")
    failedRequest = RCopy(current)
    m.result = {ok:false,status:503,error:"Calendar provider failed"}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:failedRequest,result:m.result})
    rCheck(m.retryBar.visible and m.retryBar.isInFocusChain() and m.message.text = "Calendar provider failed","calendar failure exposes scoped retry")
    beforeRetry = m.queue.count()
    rRetrySelected()
    rCheck(m.queue.count() = beforeRetry+1 and m.queue[m.queue.count()-1].context.day = date,"calendar retry replays the visible day")
    oldFailure = RCopy(current)
    oldFailure.context.day = "2026-10-01"
    rCalendarFailure(oldFailure,"Old day failed")
    rCheck(m.message.text <> "Old day failed","stale calendar failure cannot overwrite the selected day")
    m.retryBar.visible = false
    m.failedRequest = invalid
    emptyRequest = RCopy(m.queue[m.queue.count()-1])
    emptyRequest.context.cursor = ""
    m.calendarCursor = ""
    rCalendar({entries:[],complete:true},emptyRequest)
    rCheck(m.message.text = "No releases for this day." and m.actions.content.getChild(0).wire.action = "home" and m.actions.isInFocusChain(),"empty calendar exposes a reachable Home action")
    sharedSource = {id:"opaque-producer-source",name:"Do not parse 2160p HDR",view:RCopy(producer.source_view)}
    rShowSources([sharedSource])
    sourceRow = m.drawerRows.content.getChild(0)
    rCheck(sourceRow.title = producer.source_view.title and sourceRow.description = producer.source_view.body,"source title and body use shared producer display fields")
    sourceNode = CreateObject("roSGNode","RemoteItem")
    sourceNode.itemContent = sourceRow
    rCheck(sourceNode.findNode("quality").text = producer.source_view.quality_label and sourceNode.findNode("format").text = producer.source_view.format_label and sourceNode.findNode("sourceAddon").text = producer.source_view.addon_label,"source display chips preserve exact producer labels")
    rShowSources([{id:"first",view:producer.source_view},sharedSource],sharedSource.id)
    rCheck(not m.drawerRows.content.getChild(0).wire.bestMatch and m.drawerRows.content.getChild(1).wire.bestMatch,"best badge follows server ID even when it is not the first row")
    sourceNode.itemContent = m.drawerRows.content.getChild(1)
    rCheck(sourceNode.findNode("sourceBest").visible,"named server best match gets the KMP badge")
    rCheck(sourceNode.findNode("sourceBestGround").width = 119,"fixed badge preserves measured KMP shaped advance plus padding")
    rCheck(sourceNode.findNode("ground").uri = "pkg:/images/design/remote-source-row.9.png" and sourceNode.findNode("sourceBestGround").translation[1] = 23,"source row uses pinned KMP corners and centers the best tag in its title line")
    rShowSources([sharedSource],"filtered-out-best")
    sourceNode.itemContent = m.drawerRows.content.getChild(0)
    rCheck(not sourceNode.findNode("sourceBest").visible,"filtering the best source out never transfers its badge to another row")
    projected = RCopy(producer.card)
    projected.view = RCopy(producer.card_view)
    m.route = "detail"
    rHero(projected)
    rCheck(REqual(m.heroMeta.parts,producer.card_view.metadata_parts) and REqual(m.heroMeta.badges,producer.card_view.hero_badges),"shared producer presentation fixture is consumed without normalization")
    m.drawer.visible = false
    m.drawerKind = ""
    m.pending = {}
    m.queue = []
    m.admission = invalid
    m.replacement = invalid
    m.playback = {session:{id:"fixture-prior-lease",delivery:{live:false,duration:120,timeline_offset_seconds:63.25,audio_tracks:[{input_index:0,selectable:true}]},actions:RCopy(producer.playback_actions.live)},card:episodeCard,source:{id:"prior-source"},body:{},firstFrame:true,sequence:0}
    m.nextCard = nextEpisode
    rShowControls()
    rCheck(m.playerActions.content.getChildCount() = 1 and m.playerActions.content.getChild(0).wire.action = "player:sources","server actions override parent identity, VOD flag and available track metadata")
    m.playerUi.visible = false
    control = m.player.control
    rPlayerAction({action:"player:pause"})
    rPlayerAction({action:"player:episodes"})
    rPlayerAction({action:"player:tracks"})
    rPlayerKey("right")
    rSaveProgress(false)
    rPlaybackEvent("pause",false)
    rCheck(m.player.control = control and m.seekPosition = invalid and not m.drawer.visible and m.queue.count() = 0,"denied playback actions do not execute or write progress")
    m.playback.session.actions = RCopy(producer.playback_actions.vod)
    m.playCard = episodeCard
    m.playIntent = {explicit:true,replace_id:m.playback.session.id}
    rStartSource({id:"replacement-source"})
    request = m.queue[m.queue.count()-1]
    rCheck(CreateObject("roRegex","^[A-Za-z0-9_-]{1,128}$", "").isMatch(request.body.request_id),"playback idempotency identifier obeys the current producer grammar")
    rCheck(request.body.position = 0 and request.body.resume = false and REqual(request.body.replace_source,producer.source_replacement.request.replace_source),"source switch sends the shared replacement intent and leaves clock resolution to server")
    rPlayerFailure("player:start",{status:409,error:"Replacement rejected"},request)
    rCheck(m.admission = invalid and m.playback.session.id = "fixture-prior-lease","failed replacement admission preserves existing playback")
    for each queued in m.queue
        rCheck(not (queued.method = "POST" and queued.path = "/api/playback"),"cancelled queued admission cannot start later")
    end for
    m.pending = {}
    m.queue = []
    m.playIntent = {explicit:true,replace_id:m.playback.session.id}
    rStartSource({id:"cancelled-source"})
    m.drawerKind = "sources"
    m.drawer.visible = true
    m.drawerClosing = false
    m.drawerStack = []
    rCloseDrawer()
    rCheck(m.admission = invalid and m.playback.session.id = "fixture-prior-lease","Back cancels replacement preparation while preserving active playback")
    for each queued in m.queue
        rCheck(not (queued.method = "POST" and queued.path = "/api/playback"),"Back retires queued replacement admission")
    end for
    m.drawerClosing = false
    m.drawer.visible = false
    m.pending = {}
    m.queue = []
    m.playback.session.actions.tracks = true
    m.playback.session.delivery.audio_tracks = [{input_index:0,title:"Allowed",selectable:true,supported:true},{input_index:1,title:"Not selectable",selectable:false},{input_index:2,title:"Unsupported",selectable:true,supported:false}]
    rPlayerAction({action:"player:tracks"})
    rCheck(m.drawerRows.content.getChildCount() = 1 and m.drawerRows.content.getChild(0).wire.track.audio_track = 0,"track controls preserve server eligibility instead of offering every stream")
    rCheck(m.drawerRows.isInFocusChain(),"track drawer owns native input after being raised above video")
    rCheck(not RPlaybackAllowed({actions:{}} ,"pause") and not RPlaybackAllowed({},"change_source"),"absent action directives never acquire local defaults")
    m.playback = invalid
    m.admission = invalid
    m.hideControls.control = "stop"
    m.section = "Add-ons"
    m.addonStates = invalid
    rSettingsResponse("settings:integrations",{connections:[{id:"addon:opaque",name:"Fixture add-on",plugin_id:"stremio"}],configuration:{assignments:[{connection_id:"addon:opaque",enabled:["stream"]}]}},{})
    rSettingsResponse("settings:addonStates",{addons:[{connection_id:"addon:opaque",enabled:false}]},{})
    rCheck(m.rows.content.getChild(1).description = "Disabled" and m.rows.content.getChild(1).wire.enabled = false,"add-on toggle consumes server-confirmed activation rather than inferring from assignments")
    rNavigation(producer.navigation.movie_and_live)
    rCheck(m.navigation.destinations.count() = 6 and m.navigation.destinations[2].id = "movie" and m.navigation.destinations[3].id = "live","navigation preserves server ordering and omits unavailable genres")
    m.navigation.cursor = 4
    rNavigation(producer.navigation.unconfigured)
    rCheck(m.navigation.destinations.count() = 3 and m.navigation.cursor = 1 and m.navigation.destinations[1].label = "My List","navigation refresh preserves focused destination identity and server labels")
    rNavigation([{id:"unknown",label:"Unsupported"},{id:"home",label:"Server Home"}])
    rCheck(m.navigation.destinations.count() = 1 and m.navigation.destinations[0].label = "Server Home" and m.navigation.cursor = 0,"unknown destinations are omitted without inventing replacements")
    rNavigation(producer.navigation.no_selected_profile)
    rCheck(m.navigation.destinations.count() = 1 and m.navigation.destinations[0].id = "menu","unselected profile navigation exposes only server-authorized profile entry")
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.afterParent = invalid
    m.preferences = {revision:17,preferences:{source_selection:"ask"}}
    m.route = "settings"
    m.section = "Playback"
    m.drawer.visible = false
    rSettingsAction({action:"savePreference",field:"source_selection",value:"best"})
    savedRequest = m.queue[0]
    rSettingsAction({action:"savePreference",field:"source_selection",value:"ask"})
    rCheck(m.queue.count() = 1 and m.message.text = "Saving…" and savedRequest.body.preferences.source_selection = "best","pending preference input is visibly busy and cannot replace the submitted intent")
    rCheck(m.preferences.preferences.source_selection = "ask","pending save retains server-confirmed values")
    m.pending = {}
    m.queue = []
    m.retryAuth = [savedRequest]
    rSettingsAction({action:"savePreference",field:"source_selection",value:"ask"})
    rCheck(m.queue.count() = 0,"preference save remains busy during authentication refresh")
    m.retryAuth = []
    m.afterParent = savedRequest
    rCheck(rPreferenceBusy(),"preference save remains busy during parent authorization")
    m.keyboard.visible = true
    m.inputPurpose = "unlockResume"
    rTextCancel()
    rCheck(not rPreferenceBusy() and m.message.text = "Changes were not saved.","cancelling parent authorization clears busy state without claiming a save")
    m.pending["settings:preferences"] = "authoritative-read"
    rCheck(rPreferenceBusy(),"revision conflict read prevents writing an obsolete preference snapshot")
    m.pending = {}
    m.route = "home"
    m.generation++
    m.drawer.visible = true
    m.drawerKind = "menu"
    rSaved("save:preferences",{revision:18,preferences:{source_selection:"best"}},savedRequest)
    rCheck(m.route = "home" and m.drawer.visible and m.drawerKind = "menu" and m.queue.count() = 0,"late preference acceptance cannot navigate back or close an unrelated drawer")
    rCheck(m.preferences.revision = 18,"late acceptance still updates the confirmed server model")
    m.message.text = "Current screen status"
    m.request = savedRequest
    m.result = {ok:false,status:403,auth_code:"parent_required",error:"Parent required"}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rCheck(m.message.text = "Current screen status" and m.afterParent = invalid and m.drawerKind = "menu","late preference failure cannot launch parent input over a newer screen")
    rReset("library")
    rRetireCatalog()
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.keyboard.visible = false
    m.drawer.visible = false
    m.librarySheet.visible = false
    libraryPage = {cards:[card],query:{offset:0,limit:1,sort:"name_desc",type:"movie"},default_query:defaultLibrary,controls:[],next_cursor:"1",refresh_after_millis:4000,reason:"Server metadata is loading"}
    rPageResponse("library",libraryPage,{context:{}})
    firstDue = m.libraryRefreshDue
    rCheck(firstDue > rNow() and m.message.text = libraryPage.reason,"library consumes server delay and loading reason")
    libraryPage2 = RCopy(libraryPage)
    libraryPage2.cards = [second]
    libraryPage2.query.offset = 1
    libraryPage2.next_cursor = invalid
    libraryPage2.refresh_after_millis = invalid
    libraryPage2.reason = invalid
    rPageResponse("library",libraryPage2,{context:{}})
    rCheck(m.cards.count() = 2 and m.libraryRefreshDue = firstDue,"a later complete page does not erase an earlier hydration deadline")
    m.grid.jumpToItem = 1
    m.librarySheet.visible = true
    rLibraryRefreshPoll(firstDue)
    rCheck(m.queue.count() = 0,"hydration refresh waits while filter draft is open")
    m.librarySheet.visible = false
    rLibraryRefreshPoll(firstDue-1)
    rCheck(m.queue.count() = 0,"hydration refresh cannot precede producer delay")
    rLibraryRefreshPoll(firstDue)
    refreshRequest = m.queue[0]
    rCheck(refreshRequest.context.refresh and refreshRequest.query.offset = 0 and refreshRequest.query.sort = "name_desc","refresh uses the first retained accepted server query")
    m.pending = {}
    m.queue = []
    refreshedPage = RCopy(libraryPage)
    refreshedPage.cards[0].title = "Hydrated first"
    refreshedPage.refresh_after_millis = invalid
    refreshedPage.reason = invalid
    rPageResponse("library",refreshedPage,refreshRequest)
    rCheck(m.cards[0].title = card.title and m.cards.count() = 2,"partial replacement remains offscreen")
    refreshRequest2 = m.queue[0]
    rCheck(refreshRequest2.query.offset = "1","refresh follows server pagination cursor")
    m.pending = {}
    m.queue = []
    m.request = refreshRequest2
    m.result = {ok:false,status:503,error:"Temporary metadata failure"}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rCheck(m.cards.count() = 2 and m.cards[0].title = card.title and m.failedRequest.request_id = refreshRequest2.request_id,"failed refresh retains visible window and explicit retry ownership")
    rLibraryRefreshPoll(firstDue+30)
    rCheck(m.queue.count() = 0,"failed refresh does not create an automatic retry loop")
    rPageResponse("library",libraryPage2,refreshRequest2)
    rCheck(m.cards.count() = 2 and m.cards[0].title = "Hydrated first" and m.cards[1].identity.id = second.identity.id,"completed refresh swaps pages without duplication or reordering")
    rCheck(m.grid.itemFocused = 1 and m.libraryRefreshDue = 0 and not m.retryBar.visible,"refresh preserves focused identity and absent directive stops polling")
    rPageResponse("library",libraryPage,{context:{}})
    rLibraryRefreshPoll(m.libraryRefreshDue)
    staleRefresh = m.queue[0]
    rRetireCatalog()
    rCheck(m.libraryRefresh = invalid and m.libraryPages.count() = 0 and m.libraryRefreshDue = 0 and not rRequestCurrent(staleRefresh),"filter changes retire refresh and partial page ownership")
    for pageIndex = 0 to 3
        page = RCopy(libraryPage2)
        page.query.offset = pageIndex
        page.cards[0].identity.id = "page-"+pageIndex.toStr()
        window = rLibraryWindow(page,{context:{}})
    end for
    rCheck(m.libraryPages.count() = 3 and window.cards.count() = 3 and window.cards[0].identity.id = "page-1","Library retains a bounded three-page window in server order")
    m.libraryRefreshDue = rNow()
    m.pending = {}
    m.queue = []
    for i = 0 to 23
        m.queue.push({tag:"unrelated"})
    end for
    rLibraryRefreshPoll(m.libraryRefreshDue)
    rCheck(m.libraryRefresh.nextQuery <> invalid and m.queue.count() = 24,"full dispatcher defers hydration without discarding its intent")
    m.queue = []
    rLibraryRefreshPoll(m.libraryRefreshDue)
    rCheck(m.queue.count() = 1 and m.queue[0].query.offset = 1,"deferred hydration resumes from first retained page when capacity returns")
    rClearProfileViews()
    rCheck(m.libraryPages.count() = 0 and m.libraryRefresh = invalid and m.libraryRefreshDue = 0,"profile retirement clears all hydration state")
    rReset("library")
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.revisions = {library:1}
    page = RCopy(libraryPage2)
    page.query.offset = 0
    rPageResponse("library",page,{context:{}})
    m.librarySheet.visible = true
    m.librarySheet.draft = {sort:"name_asc"}
    draftBefore = RCopy(m.librarySheet.draft)
    rPageResponse("state:revisions",{library:2},{})
    rCheck(m.libraryRevisionPending and m.pending.doesExist("auth:bootstrap"),"changed revisions refresh shared bootstrap and invalidate visible Library")
    rLibraryRefreshPoll(rNow())
    rCheck(not m.pending.doesExist("library") and REqual(m.librarySheet.draft,draftBefore),"cross-client refresh cannot discard or apply an open filter draft")
    m.librarySheet.visible = false
    priorVersion = m.catalogVersion
    rLibraryRefreshPoll(rNow())
    rCheck(m.pending.doesExist("library") and m.catalogVersion = priorVersion+1 and not m.libraryRevisionPending,"closed overlay allows current window refresh under new request ownership")
    countBefore = m.queue.count()
    rPageResponse("state:revisions",{library:2},{})
    rCheck(m.queue.count() = countBefore and not m.libraryRevisionPending,"unchanged revision poll does not reschedule work")
    rPageResponse("state:revisions",{library:3},{})
    rRetireCatalog()
    rCheck(not m.libraryRevisionPending,"a new query retires obsolete revision invalidation")
    m.profile = "7"
    rReset("home")
    rHome({scope:{profile_id:"7"},hero:invalid,featured:[],rows:[{id:"empty",title:"Continue Watching",state:"Empty",cards:[],view:{card_shape:"landscape"}}],complete:true})
    rCheck(m.retryBar.visible and m.retryBar.isInFocusChain() and not m.actions.visible,"empty Home exposes the current Settings recovery action")
    m.actions.content = invalid
    rActionSelected()
    rCheck(m.route = "home","retired empty action selection is a no-op")
    for each target in [m.keyboard,m.libraryHeader,m.librarySheet,m.filterPage,m.passwordForm,m.passwordForm.findNode("fields"),m.passwordForm.findNode("buttons"),m.filterPage.findNode("facets"),m.filterPage.findNode("buttons"),m.filterPage.findNode("textField"),m.filterPage.findNode("textClear")]
        rCheck(target.focusable,"custom input focus target explicitly opts into native focus")
    end for
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.drawer.visible = false
    m.admission = invalid
    m.replacement = invalid
    m.nextCard = invalid
    m.seekPosition = invalid
    m.lastProgress = rNow()-30
    m.playback = {session:{id:"completed-attempt",delivery:{duration:120,live:false},actions:{report_progress:true,next_episode:true}},card:episodeCard,source:{id:"opaque-source"},body:{},firstFrame:true,sequence:0,clock:CreateObject("roTimespan"),remaining:120,renew:rNow()+60,started:rNow()-60}
    rVideoFinished()
    rCheck(m.playback.ended and m.queue.count() = 3,"decoder finish reports stop/progress and requests server continuation")
    for each q in m.queue
        if left(q.tag,5) = "save:" then rCheck(q.body.ended = true,"completion reports remain explicit decoder facts")
    end for
    countBefore = m.queue.count()
    rVideoFinished()
    rPlayerPoll(rNow())
    rSaveProgress(false)
    rPlaybackEvent("pause",false)
    rCheck(m.queue.count() = countBefore,"repeated finish and progress polling cannot duplicate or downgrade completion")
    m.playback = invalid
    m.hideControls.control = "stop"
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.admission = invalid
    m.replacement = invalid
    m.drawer.visible = false
    m.playback = {session:{id:"permissions-lease",status:"ready",delivery:{url:"https://example.test/opaque",duration:120,live:false},actions:{tracks:true,change_source:false,seek:true,next_episode:true}},card:episodeCard,source:{id:"source-current"},body:{},firstFrame:true,sequence:0,owner:{base:m.config.base,access_token:m.config.access_token,epoch:m.epoch}}
    rPlayerAction({action:"player:track",track:{audio_track:0}})
    trackRequest = m.queue[0]
    rCheck(m.admission <> invalid and trackRequest.body.replace_source.playback_id = "permissions-lease" and m.admission.permission = "tracks","track permission authorizes replacement independently of source-change permission")
    heartbeat = RCopy(m.playback.session)
    heartbeat.expires_at = rNow()+120
    heartbeat.actions.tracks = false
    heartbeat.actions.next_episode = false
    rPlayerResponse("player:renew:permissions-lease",heartbeat,{})
    rCheck(m.admission = invalid and m.playback.session.id = "permissions-lease" and not rRequestCurrent(trackRequest),"withdrawn track permission cancels pending admission without stopping current playback")
    for each queued in m.queue
        rCheck(not (queued.method = "POST" and queued.path = "/api/playback"),"revoked replacement cannot remain queued")
    end for
    m.nextCard = invalid
    nextRequest = {tag:"player:next",epoch:m.epoch,generation:m.generation,context:{id:"permissions-lease"}}
    rCheck(not rRequestCurrent(nextRequest),"continuation reply is retired when server removes next permission")
    rPlayerResponse("player:next",{status:"Next",item:nextEpisode},nextRequest)
    rCheck(m.nextCard = invalid,"late next target cannot be cached for later permission re-enablement")
    m.pending = {}
    m.queue = []
    m.playCard = episodeCard
    rStartSource(m.playback.source,11)
    rCheck(m.admission.permission = "seek","seek admission records its separate required permission")
    heartbeat.actions.seek = false
    rPlayerResponse("player:renew:permissions-lease",heartbeat,{})
    rCheck(m.admission = invalid and m.playback.session.id = "permissions-lease","withdrawn seek permission retires pending seek while preserving playback")
    m.playerActions.content = invalid
    rPlayerSelected()
    m.playback = invalid
    m.hideControls.control = "stop"
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.workers = []
    m.admission = invalid
    m.drawer.visible = false
    owner = {base:m.config.base,access_token:m.config.access_token,epoch:m.epoch}
    currentLease = {session:{id:"candidate-current",status:"ready",delivery:{url:"https://example.test/current",duration:120,live:false},actions:{seek:true,tracks:true,change_source:true}},card:card,source:{id:"source-current"},body:{},firstFrame:true,sequence:0,owner:owner,clock:CreateObject("roTimespan"),remaining:120,renew:rNow()+60,started:rNow()}
    oldLease = {session:{id:"recovery-old",status:"ready",delivery:{url:"https://example.test/old",duration:120,live:false},actions:{seek:true}},card:card,source:{id:"source-old"},body:{},firstFrame:true,sequence:0,owner:owner,clock:CreateObject("roTimespan"),remaining:120,renew:rNow()+60}
    m.playback = currentLease
    m.replacement = oldLease
    rStartSource({id:"third-source"},20)
    rCheck(m.admission = invalid and m.queue.count() = 0 and m.replacement.session.id = "recovery-old","third admission cannot overwrite retained recovery ownership")
    rPlayerFailure("player:renew:recovery-old",{status:503,error:"Temporary renewal error"},{})
    rCheck(m.replacement <> invalid,"transient recovery renewal failure retains an unexpired lease")
    m.queue = [{tag:"player:renew:recovery-old",method:"POST"}]
    m.retryAuth = [{tag:"player:renew:recovery-old"}]
    rPlayerFailure("player:renew:recovery-old",{status:403,error:"Revoked"},{})
    rCheck(m.replacement = invalid and m.playback.session.id = "candidate-current" and m.retryAuth.count() = 0,"revoked recovery lease is retired without rolling back the current candidate")
    for each queued in m.queue
        rCheck(queued.tag <> "player:renew:recovery-old","recovery release retires queued heartbeats")
    end for
    m.pending = {}
    m.queue = []
    m.replacement = oldLease
    rPlayerResponse("player:renew:recovery-old",{id:"recovery-old",status:"failed"},{})
    rCheck(m.replacement = invalid and m.playback.session.id = "candidate-current","invalid recovery heartbeat cannot restore that invalid lease")
    m.replacement = oldLease
    m.replacement.remaining = 0
    m.lastProgress = rNow()
    rPlayerPoll(rNow())
    rCheck(m.replacement = invalid and m.playback.session.id = "candidate-current","expired recovery lease is pruned before checking current playback authority")
    m.pending = {}
    m.queue = []
    m.playCard = card
    m.playIntent = {explicit:true,replace_id:"candidate-current"}
    rStartSource({id:"preparing-source"})
    m.admission.id = "preparing-lease"
    rPlayerFailure("player:renew:preparing-lease",{status:403,error:"Preparation revoked"},{})
    rCheck(m.admission = invalid and m.playback.session.id = "candidate-current","preparation heartbeat failure preserves active playback")
    m.replacement = oldLease
    m.replacement.remaining = 0
    rPlaybackError("Candidate failed")
    rCheck(m.playback = invalid and m.replacement = invalid,"candidate failure cannot recover a lease that expired before the next poll")
    m.playback = invalid
    m.hideControls.control = "stop"
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.playback = invalid
    m.replacement = invalid
    m.admission = invalid
    m.discovery = invalid
    m.drawer.visible = false
    liveCard = RCopy(producer.live_source_action.card)
    rRun({action:"liveChannel",channel:{id:liveCard.identity.id,connection_id:"m3u:1",card:liveCard}})
    directRequest = m.queue[m.queue.count()-1]
    liveReply = {streams:[{id:"source-first",view:producer.source_view},{id:"source-best",view:producer.source_view}],action:RCopy(producer.live_source_action)}
    rCheck(RemoteWireResponse(directRequest,{ok:true,data:liveReply}).ok,"current Live source action producer fixture satisfies wire validation")
    missingAction = RCopy(liveReply)
    missingAction.delete("action")
    rCheck(not RemoteWireResponse(directRequest,{ok:true,data:missingAction}).ok,"Live response without current action is incompatible rather than locally defaulted")
    liveReply.action.resume = true
    m.pending = {}
    m.queue = []
    rPageResponse("live:sources",liveReply,directRequest)
    rCheck(REqual(m.viewingAction,liveReply.action) and REqual(m.playCard,liveReply.action.card),"Live preserves all server viewing-action facts")
    rankRequest = m.queue[0]
    rCheck(REqual(rankRequest.body.ids,["source-first","source-best"]),"direct Live candidates use shared source-ranking API")
    m.pending = {}
    m.queue = []
    ranking = {streams:liveReply.streams,best_match_id:"source-best",quality_filters:[],total:2}
    rPageResponse("sources:rank",ranking,rankRequest)
    rCheck(m.admission <> invalid and m.admission.body.stream_id = "source-best" and m.admission.body.resume = true,"Watch honors named best source and server resume without first-row or Live defaults")
    rCancelAdmission()
    rCancelDiscovery()
    for each q in m.queue
        rCheck(left(q.path,13) <> "/api/streams/","direct Live never creates a stream-job polling or cleanup URL")
    end for
    m.pending = {}
    m.queue = []
    m.playIntent = {explicit:true}
    rLiveSources(liveCard)
    explicitRequest = m.queue[0]
    m.pending = {}
    m.queue = []
    rPageResponse("live:sources",liveReply,explicitRequest)
    rankRequest = m.queue[0]
    m.pending = {}
    m.queue = []
    rPageResponse("sources:rank",ranking,rankRequest)
    rCheck(m.admission = invalid,"explicit Live source picker does not auto-start under best preference")
    m.retryAuth = [explicitRequest]
    rLiveSources(liveCard)
    rCheck(not rRequestCurrent(explicitRequest) and m.retryAuth.count() = 0,"new channel intent retires stale direct-source response and auth retry")
    rRun({action:"play",card:card})
    oldViewing = m.queue[m.queue.count()-1]
    rRun({action:"play",card:second})
    rCheck(not rRequestCurrent(oldViewing) and m.queue.count() = 1,"new Play intent replaces old viewing request ownership in the same route")
    rStartSource({id:"superseded-source"})
    rCheck(m.admission <> invalid,"fixture has pending admission before a new Play intent")
    rRun({action:"play",card:card})
    rCheck(m.admission = invalid,"new Play intent cancels superseded playback preparation")
    for each q in m.queue
        rCheck(not (q.method = "POST" and q.path = "/api/playback"),"superseded admission cannot run after a newer Play intent")
    end for
    rReset("library")
    rRetireCatalog()
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.admission = invalid
    m.playback = invalid
    m.replacement = invalid
    offsets = [17,43,88,120]
    pages = []
    for pageIndex = 0 to 3
        page = {cards:[],query:{offset:offsets[pageIndex],limit:10,sort:"name_desc",type:"movie"},default_query:defaultLibrary,controls:[],next_cursor:invalid}
        if pageIndex < 3 then page.next_cursor = offsets[pageIndex+1].toStr()
        for j = 0 to 9
            item = RCopy(card)
            item.identity.id = "window-"+pageIndex.toStr()+"-"+j.toStr()
            page.cards.push(item)
        end for
        pages.push(page)
        rPageResponse("library",page,{context:{}})
    end for
    rCheck(m.libraryFirst = 1 and m.libraryPages.count() = 3 and m.cards.count() = 30,"forward Library paging evicts only card payload while retaining prior offsets")
    m.grid.jumpToItem = 2
    selectedBefore = RIdentityKey(m.cards[2])
    m.pending = {}
    m.queue = []
    rCheck(rLibraryPrevious(),"previous retained offset remains reachable")
    previousRequest = m.queue[0]
    rCheck(previousRequest.query.offset = 17 and previousRequest.query.sort = "name_desc","reverse traversal reuses exact uneven producer offset instead of subtracting page size")
    m.pending = {}
    m.queue = []
    rPageResponse("library",pages[0],previousRequest)
    rCheck(m.libraryFirst = 0 and m.libraryPages.count() = 3 and m.nextCursor = "120","prepend preserves the tail page next cursor and cache bound")
    rCheck(m.grid.itemFocused = 12 and RIdentityKey(m.cards[12]) = selectedBefore,"reverse page insertion restores focus by canonical identity")
    rCheck(not rLibraryPrevious(),"first page allows Up to leave the grid")
    rGridFocused() ' Deliver the restored-focus notification before subsequent input.
    m.pending = {}
    m.queue = []
    m.grid.jumpToItem = 29
    rGridFocused()
    nextRequest = m.queue[0]
    rCheck(nextRequest.query.offset = "120","forward paging remains available after reverse traversal")
    m.pending = {}
    m.queue = []
    rPageResponse("library",pages[3],nextRequest)
    m.snapshots = []
    rPush()
    rReset("detail")
    rBack()
    rCheck(m.libraryFirst = 1 and REqual(m.libraryCursors,offsets) and m.libraryPages.count() = 3,"return from details restores Library cursor history and window position")
    rGridFocused() ' Acknowledge native jumpToItem restoration.
    m.pending = {}
    m.queue = []
    m.nextCursor = "88"
    m.grid.jumpToItem = 29
    rGridFocused()
    rCheck(m.queue.count() = 0,"a cursor pointing into the retained window cannot trigger duplicate append loops")
    rRetireCatalog()
    rCheck(m.libraryFirst = 0 and m.libraryCursors.count() = 0,"filter changes retire previous-page history")
    rReset("library")
    rRetireCatalog()
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    for each page in pages
        rPageResponse("library",page,{context:{}})
    end for
    m.pending = {}
    m.queue = []
    m.grid.jumpToItem = 2
    m.grid.setFocus(true)
    rLibraryPrevious()
    failedPage = m.queue[0]
    m.queue = []
    m.request = failedPage
    m.result = {ok:false,status:503,error:"Page temporarily unavailable"}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rCheck(rLibraryRetryRequired() and m.cards.count() = 30 and m.retryBar.visible,"reverse page failure preserves visible cards and exposes explicit retry")
    rGridFocused()
    rLibraryPrevious()
    m.libraryRefreshDue = rNow()
    rLibraryRefreshPoll(rNow())
    rCheck(m.queue.count() = 0,"focus lookahead reverse paging and hydration cannot retry a failed page implicitly")
    onKeyEvent("up",true)
    rCheck(m.retryBar.isInFocusChain(),"Up at a failed reverse boundary reaches Retry")
    onKeyEvent("up",true)
    rCheck(m.grid.isInFocusChain(),"Up from Retry restores grid focus")
    for i = 0 to 23
        m.queue.push({tag:"busy"})
    end for
    rRetrySelected()
    rCheck(m.failedRequest <> invalid and m.retryBar.visible,"full request queue retains failed-query ownership and visible Retry")
    m.queue = []
    m.retryBar.setFocus(true)
    rRetrySelected()
    rCheck(m.queue.count() = 1 and REqual(m.queue[0].query,failedPage.query) and REqual(m.queue[0].context,failedPage.context),"Retry resubmits the exact failed page query and context")
    rCheck(m.failedRequest = invalid and not m.retryBar.visible and m.grid.isInFocusChain(),"accepted Retry restores card focus and releases failure state")
    rRetrySelected()
    rCheck(m.queue.count() = 1,"repeated Retry activation cannot duplicate the accepted request")
    m.pending = {}
    m.queue = []
    m.retryAuth = [failedPage]
    m.nextCursor = "future-page"
    m.pageCursors = {}
    m.grid.jumpToItem = 29
    rGridFocused()
    rCheck(m.queue.count() = 0,"Library lookahead waits for current page authentication replay")
    m.retryAuth = []
    rCheck(m.grid.vertFocusAnimationStyle = "floatingFocus","catalog boundary does not wrap before parent retry/navigation handling")
    rCheck(m.retryBar.focusable and m.actions.focusable and m.playerActions.focusable,"custom action bars explicitly accept native focus")
    m.catalogExpectedFocus = 42
    countBefore = m.queue.count()
    rGridFocused({getData:qaFocusZero})
    rCheck(m.catalogExpectedFocus = 42 and m.queue.count() = countBefore,"transient content-reset focus cannot trigger reverse paging")
    rGridFocused({getData:qaFocusTarget})
    rCheck(m.catalogExpectedFocus = invalid and m.queue.count() = countBefore,"restored focus acknowledgement does not itself page")
    rReset("library")
    rRetireCatalog()
    rPageResponse("library",pages[0],{context:{}})
    rRetireCatalog()
    m.cards = []
    emptyPage = RCopy(pages[0])
    emptyPage.cards = []
    emptyPage.next_cursor = invalid
    rPageResponse("library",emptyPage,{context:{}})
    rCheck(m.grid.content.getChildCount() = 0,"empty accepted query clears old rendered cards even after the model was reset")
    m.route = "library"
    m.drawer.visible = false
    rError("Page unavailable.")
    rCheck(m.message.translation[1] = 236 and m.grid.translation[1] = 267,"Library error reserves space above cards instead of overlapping artwork")
    m.message.text = "First line"+chr(10)+"Second line"
    rLibraryStatus(false)
    rCheck(m.grid.translation[1] = 298 and m.message.height = 62,"two-line Library status reserves both lines")
    m.message.text = ""
    rLibraryStatus(false)
    rCheck(m.grid.translation[1] = 236 and m.message.height = 0,"cleared Library status restores normal grid geometry")
    rReset("library")
    rRetireCatalog()
    m.pending = {}
    m.queue = []
    m.snapshots = []
    m.admission = invalid
    m.playback = invalid
    m.drawer.visible = false
    page = RCopy(pages[0])
    page.reason = "Metadata still loading"
    rPageResponse("library",page,{context:{}})
    m.controls = {catalogs:[{name:"Obsolete browse catalog"}],controls:[]}
    m.libraryRevisionPending = true
    rPush()
    rReset("detail")
    rBack()
    rCheck(m.message.text = page.reason and m.grid.translation[1] = 267 and not m.filters.visible,"Library return preserves server reason without restoring unrelated Browse controls")
    rCheck(m.libraryRevisionPending and REqual(m.libraryDefaults,RQueryFields(page.default_query)),"Library return restores pending revision and server defaults")
    m.libraryRevisionPending = false
    m.pending = {}
    m.queue = []
    rLibraryPage()
    failedPage = m.queue[0]
    m.queue = []
    m.request = failedPage
    m.result = {ok:false,status:503,error:"Retry this Library page"}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rPush()
    savedFailure = m.snapshots[m.snapshots.count()-1].libraryFailure.request
    rCheck(not savedFailure.doesExist("access_token") and not savedFailure.doesExist("base"),"Library return cache stores retry intent without credentials")
    rReset("detail")
    rBack()
    rCheck(rLibraryRetryRequired() and m.retryBar.visible and m.message.text = "Retry this Library page","Back restores explicit failed-page recovery instead of hiding it")
    rCheck(m.failedRequest.generation = m.generation and m.failedRequest.context.catalog_version = m.catalogVersion and REqual(m.failedRequest.query,failedPage.query),"restored retry retains exact query under current renderer ownership")
    m.failedRequest.context.refresh = true
    m.failedRequest.query = RCopy(pages[1].query)
    m.libraryRefresh = {pages:[{data:RCopy(pages[0]),due:0}],target:2,nextQuery:invalid}
    m.libraryRevisionPending = true
    m.snapshots = []
    rPush()
    rReset("detail")
    rBack()
    rCheck(m.libraryRefresh <> invalid and m.libraryRefresh.pages.count() = 1 and rLibraryRetryRequired(),"return from details restores failed hydration staging with its retry intent")
    m.pending = {}
    m.queue = []
    rRetrySelected()
    hydrationRetry = m.queue[0]
    rCheck(not m.libraryRevisionPending,"explicit retry reads current state instead of being cancelled by an older revision invalidation")
    m.pending = {}
    m.queue = []
    rPageResponse("library",pages[1],hydrationRetry)
    rCheck(m.libraryRefresh = invalid and m.cards.count() = 20 and m.failedRequest = invalid,"restored hydration retry can commit the complete replacement window")
    rReset("library")
    rRetireCatalog()
    m.pending = {}
    m.queue = []
    m.snapshots = []
    m.playback = invalid
    m.admission = invalid
    m.drawer.visible = false
    page = RCopy(pages[0])
    page.query.genre = "Drama"
    rPageResponse("library",page,{context:{}})
    rPush()
    rReset("detail")
    m.detailCard = card
    rSaved("save:library",{}, {method:"PUT",generation:m.generation})
    rCheck(m.snapshots.count() = 1 and m.snapshots[0].route = "library" and m.snapshots[0].cards.count() = 0 and m.snapshots[0].libraryPages.count() = 0,"accepted membership mutation retires cached cards but preserves Library return route")
    rBack()
    rCheck(m.route = "library" and m.pending.doesExist("library") and m.libraryQuery.genre = "Drama","Back after mutation refetches Library with its preserved filter instead of jumping Home")
    m.snapshots = [{route:"home",home:{rows:[]},cards:[card]},{route:"library",cards:[card],library:{type:"movie"},libraryPages:[{data:page}],libraryCursors:[0]}]
    rSaved("save:progress:attempt:1",{}, {generation:m.generation})
    rCheck(m.snapshots.count() = 2 and m.snapshots[0].home = invalid and m.snapshots[1].cards.count() = 0,"accepted progress also retires return-view facts without erasing navigation")
    m.revisions = {library:1}
    rPageResponse("state:revisions",{library:2},{})
    rCheck(m.snapshots.count() = 2,"cross-client revision updates preserve the return path")
    m.snapshots = [{route:"movie",cards:[],browse:{type:"movie",catalog:"catalog:opaque",skip:"84",values:[{id:"genre",value:"Drama"}]},gridIndex:0}]
    m.pending = {}
    m.queue = []
    rBack()
    rCheck(m.route = "movie" and m.browseQuery.catalog = "catalog:opaque" and m.browseQuery.skip = "0" and m.browseQuery.values[0].value = "Drama","invalidated Browse return keeps query intent and restarts pagination")
    rPageResponse("controls",{catalogs:[{id:"catalog:opaque",name:"Current catalog label",controls:[]}],controls:[]},{})
    rCheck(m.selectedCatalog.name = "Current catalog label" and m.filters.content.getChild(0).title = "Current catalog label","refreshed Browse controls resolve the preserved catalog from current server descriptors")
    rReset("library")
    rRetireCatalog()
    m.pending = {}
    m.queue = []
    m.snapshots = []
    m.playback = invalid
    m.admission = invalid
    m.drawer.visible = false
    originA = RCopy(card)
    originA.metadata_origin = {key:"origin-a"}
    originB = RCopy(card)
    originB.metadata_origin = {key:"origin-b"}
    page = RCopy(pages[0])
    page.cards = [originA,originB]
    rPageResponse("library",page,{context:{}})
    m.grid.jumpToItem = 1
    rPush()
    rInvalidateReturnViews()
    rReset("detail")
    rBack()
    rCheck(m.restoreKey = RIdentityKey(originB),"invalidated return retains selected canonical identity independently of cached cards")
    page.cards = [originB,originA]
    rPageResponse("library",page,{context:{}})
    rCheck(m.grid.itemFocused = 0 and m.cards[0].metadata_origin.key = "origin-b" and m.restoreKey = invalid,"refetch follows the same origin-specific card after server reordering rather than the old index")
    rReset("library")
    rRetireCatalog()
    m.restoreKey = RIdentityKey(originB)
    page.cards = [originA]
    rPageResponse("library",page,{context:{}})
    rCheck(m.grid.itemFocused = 0 and m.cards.count() = 1 and m.restoreKey = invalid,"absent identity keeps server order and clears restoration intent")
    m.restoreKey = RIdentityKey(originB)
    rRetireCatalog()
    rCheck(m.restoreKey = invalid,"new query retires pending identity restoration")
    rReset("live")
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.workers = []
    m.afterParent = invalid
    rLiveGroup("first-group")
    oldGroup = m.queue[0]
    rSend("GET",rProfilePath("/live/channel-old/guide"),invalid,"live:guide:channel-old",{channel:"channel-old",live_version:m.liveVersion,query:m.liveQuery})
    oldGuide = m.queue[1]
    m.retryAuth = [oldGuide]
    oldWorker = {request:oldGroup,cancel:false}
    m.workers = [oldWorker]
    for i = 0 to 49
        rLiveGroup("group-"+i.toStr())
    end for
    rCheck(m.queue.count() = 1 and m.queue[0].context.query = "&group_id=group-49" and oldWorker.cancel and m.retryAuth.count() = 0,"rapid Live groups retain only the latest request and retire guide auth retries")
    latestGroup = m.queue[0]
    pendingGroup = m.pending.live
    m.request = oldGroup
    m.result = {ok:false,status:403,auth_code:"parent_required",error:"Old group denied"}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rCheck(m.pending.live = pendingGroup and m.afterParent = invalid and m.message.text = "Loading channels…","retired Live failure cannot clear newer ownership or open parent authorization")
    m.request = oldGuide
    m.result = {ok:true,status:200,data:{channel_id:"channel-old",programs:[]}}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rCheck(m.liveGuides.count() = 0 and not m.rows.visible,"stale guide cannot repopulate hidden old-group rows")
    m.workers = []
    m.queue = []
    m.request = latestGroup
    m.result = {ok:true,status:200,data:{channels:[],groups:[],reason:"No channels in selected group."}}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rCheck(m.liveData.reason = "No channels in selected group." and m.message.text = m.liveData.reason,"latest Live response replaces loading with server state")
    stalePage = RCopy(latestGroup)
    stalePage.tag = "live:page"
    stalePage.context.direction = "next"
    stalePage.context.paging = {cursor:"retired-cursor",limit:100,page_size:100}
    rCheck(not rRequestCurrent(stalePage),"outdated Live page cursor cannot replay after authentication refresh")
    rCheck(rRequestCurrent({tag:"live:sources",epoch:m.epoch,generation:m.generation,context:{source_epoch:m.sourceEpoch}}),"Live viewing intent retains its independent source ownership")
    rReset("live")
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.playback = invalid
    m.drawer.visible = false
    rLiveGroup("")
    m.pending = {}
    m.queue = []
    channel = {id:producer.live_source_action.card.identity.id,connection_id:"m3u:1",card:producer.live_source_action.card}
    rLive({channels:[channel],groups:[],reason:"",next_cursor:invalid})
    guideRequest = m.queue[0]
    m.queue = []
    m.drawer.visible = true
    m.drawerKind = "sources"
    m.drawerMessage.text = "Finding sources…"
    m.request = guideRequest
    m.result = {ok:false,status:503,error:"Guide temporarily unavailable"}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rCheck(rLiveRetryRequired() and m.drawerMessage.text = "Finding sources…","background guide error cannot overwrite the source drawer")
    m.drawer.visible = false
    rLoadGuides()
    rCheck(m.message.text = "Guide temporarily unavailable" and m.retryBar.visible and m.queue.count() = 0,"return to Live exposes deferred guide failure without retrying it")
    rLoadGuides()
    rCheck(m.queue.count() = 0,"focus-driven guide reads cannot loop after failure")
    m.retryBar.setFocus(true)
    rRetrySelected()
    guideRetry = m.queue[0]
    rCheck(guideRetry.path = guideRequest.path and guideRetry.method = guideRequest.method and REqual(guideRetry.context,guideRequest.context) and m.rows.isInFocusChain(),"explicit guide retry preserves transport intent and returns row focus")
    m.queue = []
    m.pending = {}
    rPageResponse(guideRetry.tag,{channel_id:channel.id,programs:[],view:{window_start_millis:0,current_program_id:invalid}},guideRetry)
    rCheck(m.liveFailureText = "" and m.message.text = "" and not m.retryBar.visible,"successful guide retry clears its failure presentation")
    m.liveGuides = {}
    m.retryAuth = [guideRetry]
    rLoadGuides()
    rCheck(m.queue.count() = 0,"guide lookahead waits for authentication replay")
    m.retryAuth = []
    m.failedRequest = guideRetry
    m.liveVersion++
    rRetrySelected()
    rCheck(m.failedRequest = invalid and m.queue.count() = 0,"Retry cannot resubmit retired Live ownership")
    rReset("live")
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.playback = invalid
    m.drawer.visible = false
    rLiveGroup("")
    m.pending = {}
    m.queue = []
    channel = {id:producer.live_source_action.card.identity.id,card:producer.live_source_action.card,connection_id:"m3u:1"}
    rLive({channels:[channel],groups:[],reason:"",next_cursor:invalid})
    for i = 1 to 20
        rLiveGuide({channel_id:channel.id,programs:[],view:{window_start_millis:0,current_program_id:invalid},revision:i},{context:{channel:channel.id}})
    end for
    rCheck(m.liveOrder.count() = 1 and m.liveGuides.count() = 1 and m.liveGuides[channel.id].revision = 20,"repeated guide refresh uses one slot and retains its newest server payload")
    m.pending = {}
    m.queue = []
    rLoadGuides()
    rCheck(m.queue.count() = 0,"a refreshed cached guide does not trigger another focus-driven fetch")
    for i = 1 to 12
        id = "other-channel-"+i.toStr()
        rLiveGuide({channel_id:id,programs:[],view:{window_start_millis:0,current_program_id:invalid}},{context:{channel:id}})
    end for
    rCheck(m.liveOrder.count() = 12 and m.liveGuides.count() = 12 and not m.liveGuides.doesExist(channel.id),"cache evicts only distinct older channel slots at its bound")
    rCheck(m.rows.content.getChild(0).guideData.count() = 0,"evicted guide is also removed from its attached visible row")
    m.pending = {}
    m.queue = []
    rLoadGuides()
    rCheck(m.queue.count() = 1 and m.queue[0].context.channel = channel.id,"evicted current channel can be refetched once")
    rReset("live")
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.drawer.visible = false
    m.playback = invalid
    rLiveGroup("")
    m.pending = {}
    m.queue = []
    channel = {id:producer.live_source_action.card.identity.id,card:producer.live_source_action.card,connection_id:"m3u:1"}
    rLive({channels:[channel],groups:[],reason:"",next_cursor:invalid})
    programmeA = {id:"programme-a",title:"A",start_millis:0,end_millis:1800000}
    programmeB = {id:"programme-b",title:"B",start_millis:1800000,end_millis:3600000}
    programmeC = {id:"programme-c",title:"C",start_millis:3600000,end_millis:5400000}
    guide = {channel_id:channel.id,programs:[programmeA,programmeB,programmeC],view:{window_start_millis:0,current_program_id:"programme-a"}}
    rLiveGuide(guide,{context:{channel:channel.id}})
    row = m.rows.content.getChild(0)
    rCheck(row.programIndex = 0 and row.manualProgram = "","initial guide uses server current programme")
    m.rows.setFocus(true)
    rLiveKey("right")
    rCheck(row.manualProgram = "programme-b","explicit guide browsing records programme identity")
    guide.programs = [programmeB,programmeA,programmeC]
    guide.view = {window_start_millis:3600000,current_program_id:"programme-c"}
    rLiveGuide(guide,{context:{channel:channel.id}})
    rCheck(row.programIndex = 0 and row.viewport.start_millis = 1800000# and row.guideData.view.current_program_id = "programme-c","refresh preserves manual identity after reordering without changing server current marker")
    rLive(m.liveData,true)
    row = m.rows.content.getChild(0)
    rCheck(row.manualProgram = "programme-b" and row.programIndex = 0,"retained channel-page replacement preserves explicit programme selection")
    guide.programs = [programmeA,programmeC]
    rLiveGuide(guide,{context:{channel:channel.id}})
    rCheck(row.manualProgram = "" and row.programIndex = 1 and row.viewport.start_millis = 3600000#,"missing selected programme falls back only to server current programme and window")
    rReset("live")
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.workers = []
    m.playback = invalid
    m.drawer.visible = false
    rLiveGroup("")
    m.pending = {}
    m.queue = []
    channelA = {id:"live-a",connection_id:"connection:1",card:producer.live_source_action.card}
    channelB = {id:"live-b",connection_id:"connection:1",card:producer.live_source_action.card}
    firstPage = {snapshot_id:"directory-a",channels:[channelA],groups:[{id:"g",label:"Old label"}],connections:[{id:"connection:1",name:"Old connection"}],reason:"Old reason",availability:"Available",complete:false,next_cursor:"100"}
    firstPage.paging = {origin:"0",limit:100,page_size:100,previous:invalid,next:{cursor:"100",limit:100,page_size:100}}
    rLive(firstPage)
    oldGuide = m.queue[0]
    secondPage = {snapshot_id:"directory-a",channels:[channelB],groups:[{id:"g",label:"Current label"}],connections:[{id:"connection:1",name:"Current connection"}],reason:"Current server reason",availability:"Available",complete:false,next_cursor:"200"}
    secondPage.paging = {origin:"100",limit:100,page_size:100,previous:{cursor:"0",limit:100,page_size:100},next:{cursor:"200",limit:100,page_size:100}}
    rLivePage(secondPage,{context:{query:m.liveQuery,direction:"next",cursor:"100"}})
    rCheck(m.rows.content.getChildCount() = 2 and m.rows.content.getChild(0).wire.channel.id = "live-a" and m.rows.content.getChild(1).wire.channel.id = "live-b","Live page merge preserves server page ordering")
    rCheck(m.liveData.groups[0].label = "Current label" and m.liveData.connections[0].name = "Current connection" and m.message.text = "Current server reason","latest Live page owns global metadata rather than retaining old labels or reason")
    unavailable = {snapshot_id:"directory-a",channels:[],groups:[],connections:[],reason:"Assign a live TV connection",availability:"NeedsConfiguration",complete:true,next_cursor:invalid}
    m.retryAuth = [oldGuide]
    versionBefore = m.liveVersion
    unavailableRequest = {tag:"live:page",epoch:m.epoch,generation:m.generation,context:{query:m.liveQuery,live_version:m.liveVersion,direction:"next",paging:secondPage.paging.next}}
    rCheck(rRequestCurrent(unavailableRequest),"unavailable response belongs to the currently advertised next page")
    rLivePage(unavailable,unavailableRequest)
    rCheck(m.liveVersion > versionBefore and m.retryAuth.count() = 0 and not rRequestCurrent(oldGuide),"unavailable transition retires prior guide work")
    rCheck(m.livePages.count() = 1 and m.rows.content.getChildCount() = 0 and not m.rows.visible and not m.hero.visible,"unavailable response replaces old channels instead of merging cached availability")
    rCheck(not m.filters.visible and m.navigation.isInFocusChain() and m.message.text = unavailable.reason,"empty unconfigured Live leaves usable navigation without an inert group control")
    m.drawer.visible = true
    m.drawerRows.content = rContent([{title:"Source",action:"close"}],800,104)
    m.drawerRows.setFocus(true)
    rLive(unavailable)
    rCheck(m.drawerRows.isInFocusChain(),"empty background Live response cannot steal overlay focus")
    m.drawer.visible = false
    liveRequest = {method:"GET",path:"/api/profiles/7/live/channels"}
    rCheck(RemoteWireResponse(liveRequest,{ok:true,data:secondPage}).ok,"current Live page shape passes transport validation")
    incompleteLive = RCopy(secondPage)
    incompleteLive.delete("availability")
    rCheck(not RemoteWireResponse(liveRequest,{ok:true,data:incompleteLive}).ok,"missing Live availability is incompatible rather than treated as an unavailable page")
    rReset("live")
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.drawer.visible = false
    m.playback = invalid
    rLiveGroup("")
    m.pending = {}
    m.queue = []
    livePages = []
    for pageIndex = 0 to 2
        livePage = {snapshot_id:"directory-a",channels:[],groups:[],connections:[],reason:"",availability:"Available",complete:false,next_cursor:((pageIndex+1)*20).toStr()}
        for i = 0 to 19
            id = "channel-"+(pageIndex*20+i).toStr()
            liveCard = RCopy(producer.live_source_action.card)
            liveCard.identity.id = id
            liveCard.title = id
            livePage.channels.push({id:id,connection_id:"qa",card:liveCard})
        end for
        previous = invalid
        if pageIndex > 0 then previous = {cursor:((pageIndex-1)*20).toStr(),limit:20,page_size:20}
        livePage.paging = {origin:(pageIndex*20).toStr(),limit:20,page_size:20,previous:previous,next:{cursor:((pageIndex+1)*20).toStr(),limit:20,page_size:20}}
        livePages.push(livePage)
    end for
    rLive(livePages[0])
    rLivePage(livePages[1],{context:{query:m.liveQuery,direction:"next",cursor:"20"}})
    m.pending = {}
    m.queue = []
    m.rows.jumpToItem = 35
    rLivePage(livePages[2],{context:{query:m.liveQuery,direction:"next",cursor:"40"}})
    rCheck(m.liveExpectedFocus = 15 and m.queue.count() = 0,"Live page replacement waits for identity-restored focus before reading guides or pages")
    rRowFocused({getData:qaFocusZero})
    rLoadGuides()
    rCheck(m.liveExpectedFocus = 15 and m.queue.count() = 0,"transient Live focus zero cannot request the previous page")
    rRowFocused({getData:qaLiveFocusTarget})
    rLoadGuides()
    rCheck(m.liveExpectedFocus = invalid and m.rows.content.getChild(m.rows.itemFocused).wire.channel.id = "channel-35","acknowledged focus retains the same channel after eviction")
    for each q in m.queue
        rCheck(q.tag <> "live:page","restored middle-window focus cannot oscillate into paging")
    end for
    m.heroTick.control = "stop"
    guideRequest = {method:"GET",path:"/api/profiles/7/live/channel-1/guide"}
    rCheck(RemoteWireResponse(guideRequest,{ok:true,data:contracts.guide}).ok,"current empty guide with authoritative window passes wire validation")
    wireGuide = RCopy(contracts.guide)
    wireGuide.programs = [{id:"later",title:"Later",start_millis:2000,end_millis:3000},{id:"earlier",title:"Earlier",start_millis:1000,end_millis:2000}]
    validated = RemoteWireResponse(guideRequest,{ok:true,data:wireGuide})
    rCheck(validated.ok and REqual(validated.data.programs,wireGuide.programs),"guide validation preserves surprising server programme order")
    wireGuide.programs[0].start_millis = "2000"
    rCheck(not RemoteWireResponse(guideRequest,{ok:true,data:wireGuide}).ok,"guide timestamp strings are rejected instead of coerced")
    wireGuide = RCopy(contracts.guide)
    wireGuide.view.delete("window_start_millis")
    rCheck(not RemoteWireResponse(guideRequest,{ok:true,data:wireGuide}).ok,"missing server guide window cannot fall back to local epoch zero")
    wireGuide = RCopy(contracts.guide)
    wireGuide.view.window_end_millis = wireGuide.view.window_start_millis
    rCheck(not RemoteWireResponse(guideRequest,{ok:true,data:wireGuide}).ok,"invalid guide window is rejected before rendering")
    wireGuide = RCopy(contracts.guide)
    wireGuide.programs = [{id:"bad",title:"Bad",start_millis:3000,end_millis:2000}]
    rCheck(not RemoteWireResponse(guideRequest,{ok:true,data:wireGuide}).ok,"reversed programme interval is rejected before renderer arithmetic")
    guideRequest.context = {channel:"different-channel"}
    rCheck(not RemoteWireResponse(guideRequest,{ok:true,data:contracts.guide}).ok,"guide for a different requested channel is rejected before caching")
    stamp = 1800001800000#
    preciseGuide = {channel_id:"channel-35",programs:[{id:"precise",title:"Precise",start_millis:stamp+1000#,end_millis:stamp+1800000#}],view:{window_start_millis:stamp,current_program_id:"precise"}}
    preciseNode = CreateObject("roSGNode","ContentNode")
    preciseNode.addFields({viewport:{start_millis:0#},manualProgram:"",programIndex:-1,guideData:{}})
    rApplyGuide(preciseNode,preciseGuide)
    rCheck(preciseNode.viewport.start_millis = stamp,"guide viewport preserves large epoch milliseconds without scalar float coercion")
    guideTile = CreateObject("roSGNode","RemoteGuideRow")
    guideTile.itemContent = preciseNode
    programmeTile = guideTile.findNode("programs").getChild(0)
    rCheck(abs(programmeTile.translation[0]-1400#/7200#) < 0.001,"guide projection subtracts epoch origin before producing fractional pixel offsets")
    rCheck(RGuideWindowMillis(1800003601000#) = 1800003600000&,"manual guide alignment returns an exact 64-bit millisecond boundary")
    rReset("live")
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.afterParent = invalid
    m.playback = invalid
    m.drawer.visible = false
    m.keyboard.visible = false
    rLiveGroup("")
    m.pending = {}
    m.queue = []
    rLive(livePages[0])
    m.pending = {}
    m.queue = []
    m.rows.jumpToItem = 8
    due = rNow()+30
    m.liveGuideRefreshDue = due
    rRefreshVisibleGuides(due-1)
    rCheck(m.queue.count() = 0,"guide freshness waits for its bounded transport cadence")
    m.drawer.visible = true
    rRefreshVisibleGuides(due)
    rCheck(m.queue.count() = 0 and m.liveGuideRefreshDue = due,"guide freshness defers while a foreground drawer is open")
    m.drawer.visible = false
    rRefreshVisibleGuides(due)
    rCheck(m.queue.count() = 10 and m.queue[0].context.channel = "channel-4" and m.queue[9].context.channel = "channel-13","guide refresh is bounded to focused and nearby rows")
    rRefreshVisibleGuides(due+1)
    rCheck(m.queue.count() = 10,"poll ticks cannot multiply refresh requests inside the cadence")
    parentGuide = m.queue[0]
    m.queue = []
    m.pending = {}
    m.drawer.visible = true
    m.drawerMessage.text = "Foreground source status"
    m.request = parentGuide
    m.result = {ok:false,status:403,auth_code:"parent_required",error:"Parent authorization required"}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rCheck(m.afterParent = invalid and not m.keyboard.visible and m.drawerMessage.text = "Foreground source status","background guide authorization cannot open a PIN over another operation")
    m.drawer.visible = false
    rRetrySelected()
    parentRetry = m.queue[0]
    m.queue = []
    m.request = parentRetry
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rCheck(m.formDialog.visible and m.afterParent.tag = parentRetry.tag,"explicit guide retry may request parent authorization")
    rRefreshVisibleGuides(due+60)
    rCheck(m.queue.count() = 0,"parent authorization owns the guide request slot")
    rTextCancel()
    rCheck(rLiveRetryRequired() and m.afterParent = invalid and m.liveRetryTag = "","cancelled guide authorization restores explicit retry rather than looping")
    rRefreshVisibleGuides(due+90)
    rCheck(m.queue.count() = 0,"guide freshness remains paused after authorization cancellation")
    m.heroTick.control = "stop"
    rLiveGroup("")
    m.pending = {}
    m.queue = []
    rLive(livePages[0])
    m.pending = {}
    m.queue = []
    m.rows.jumpToItem = 8
    m.liveGuideRefreshDue = due
    for i = 0 to 23
        m.queue.push({tag:"busy"})
    end for
    statusBefore = m.message.text
    rRefreshVisibleGuides(due)
    rCheck(m.queue.count() = 24 and m.liveGuideRefreshDue = due and m.message.text = statusBefore,"background guide freshness defers without a busy error when the dispatcher is full")
    m.queue = []
    rRefreshVisibleGuides(due)
    rCheck(m.queue.count() = 10,"deferred guide refresh resumes when request capacity returns")
    m.heroTick.control = "stop"
    programmeTile.id = "retained-guide-tile"
    nextGuide = RCopy(preciseGuide)
    nextGuide.view.now_millis = stamp+2000#
    nextNode = CreateObject("roSGNode","ContentNode")
    nextNode.addFields({viewport:{start_millis:stamp},programIndex:0,guideData:nextGuide})
    guideTile.itemContent = nextNode
    rCheck(guideTile.findNode("programs").getChild(0).id = "retained-guide-tile","clock-only guide update preserves programme nodes")
    nextGuide.programs[0].title = "Updated title"
    nextNode = CreateObject("roSGNode","ContentNode")
    nextNode.addFields({viewport:{start_millis:stamp},programIndex:0,guideData:nextGuide})
    guideTile.itemContent = nextNode
    rCheck(guideTile.findNode("programs").getChild(0).id = "retained-guide-tile" and guideTile.findNode("programs").getChild(0).getChild(1).text = "Updated title","changed guide text updates an existing tile")
    nextGuide.programs = []
    for i = 0 to 39
        nextGuide.programs.push({id:"pool-"+i.toStr(),title:"Pool "+i.toStr(),start_millis:stamp+i*120000#,end_millis:stamp+(i+1)*120000#})
    end for
    nextNode = CreateObject("roSGNode","ContentNode")
    nextNode.addFields({viewport:{start_millis:stamp},programIndex:0,guideData:nextGuide})
    guideTile.itemContent = nextNode
    rCheck(guideTile.findNode("programs").getChildCount() = 32,"guide tile pool has a fixed32-node-group ceiling")
    rCheck(not guideTile.findNode("programs").getChild(0).getChild(1).visible and guideTile.findNode("programs").getChild(0).getChild(1).width = 0,"narrow programme cells never receive a negative text width")
    nextGuide.programs = []
    nextGuide.reason = "No schedule supplied"
    nextNode = CreateObject("roSGNode","ContentNode")
    nextNode.addFields({viewport:{start_millis:stamp},programIndex:-1,guideData:nextGuide})
    guideTile.itemContent = nextNode
    rCheck(guideTile.findNode("emptyProgram").visible and guideTile.findNode("emptyProgram").text = "No schedule supplied","empty guide uses the dedicated server-reason label")
    for each tile in guideTile.findNode("programs").getChildren(-1,0)
        rCheck(not tile.visible and tile.getChild(1).text = "","unused guide pool entries release text and stay hidden")
    end for
    guideTile.itemContent = invalid
    rCheck(not guideTile.findNode("emptyProgram").visible and guideTile.findNode("emptyProgram").text = "" and guideTile.findNode("name").text = "","retired guide content clears retained text")
    m.liveExpectedFocus = invalid
    rLivePreview()
    rCheck(m.backdrop.loadWidth = 640 and m.backdrop.loadHeight = 360,"Live preview bounds decoded artwork to its displayed box")
    m.route = "home"
    m.homeBrowsing = true
    rHero(card)
    rCheck(m.backdrop.loadWidth = 1160 and m.backdrop.loadHeight = 620,"compact Home browsing uses compact decode bounds")
    m.homeBrowsing = false
    rHero(card)
    rCheck(m.backdrop.loadWidth = 1920 and m.backdrop.loadHeight = 1080,"full Home restores decode bounds after compact views")
    rReset("live")
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.workers = []
    m.playback = invalid
    m.drawer.visible = false
    m.liveQuery = "&group_id=server-group"
    snapshot = producer.live_pagination_snapshot
    rLive(snapshot.first_page)
    rLivePage(snapshot.compatible_next_page,{context:{query:m.liveQuery,direction:"next",paging:snapshot.first_page.paging.next}})
    rCheck(m.rows.content.getChildCount() = 2,"equal producer snapshot IDs allow ordered Live page merge")
    oldGuide = m.queue[0]
    rLivePage(snapshot.configuration_changed_next_page,{context:{query:m.liveQuery,direction:"next",cursor:"2"}})
    rCheck(m.liveData = invalid and m.livePages.count() = 0 and RLiveBoundary(m.livePages,"next") = invalid,"changed producer snapshot discards incompatible window and cursor")
    rCheck(m.rows.content = invalid and not m.rows.visible and not m.hero.visible and not m.filters.visible,"snapshot mismatch hides all incompatible directory content")
    rCheck(not rRequestCurrent(oldGuide),"snapshot mismatch retires old guide response ownership")
    request = m.queue[m.queue.count()-1]
    rCheck(request.tag = "live" and request.path = rProfilePath("/live/channels?limit=100&group_id=server-group"),"snapshot mismatch reloads offset zero with unchanged query")
    m.queue = []
    m.request = request
    m.result = {ok:false,status:503,error:"Directory temporarily unavailable"}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rCheck(m.retryBar.visible and m.rows.content = invalid and m.liveData = invalid,"failed snapshot reload offers Retry without restoring incompatible content")
    rRetrySelected()
    rCheck(m.queue.count() = 1 and m.queue[0].path = request.path and REqual(m.queue[0].context,request.context),"snapshot reload Retry preserves the unchanged query and current generation")
    m.pending = {}
    m.queue = []
    rLive(snapshot.reload_first_page)
    rCheck(m.liveData.snapshot_id = snapshot.reload_first_page.snapshot_id and m.rows.content.getChild(0).wire.channel.id = "channel-changed-one","reload publishes only the new producer snapshot")
    rLivePage(snapshot.compatible_next_page,{context:{query:m.liveQuery,direction:"previous",cursor:""}})
    rCheck(m.liveData = invalid and m.livePages.count() = 0,"backward snapshot mismatch also discards the incompatible window")
    missingSnapshot = RCopy(snapshot.first_page)
    missingSnapshot.delete("snapshot_id")
    rCheck(not RemoteWireResponse(liveRequest,{ok:true,data:missingSnapshot}).ok,"missing current snapshot identity rejects legacy response")
    missingSnapshot.snapshot_id = ""
    rCheck(not RemoteWireResponse(liveRequest,{ok:true,data:missingSnapshot}).ok,"empty snapshot identity is incompatible")
    rReset("search")
    rNavigation(producer.navigation.live_only)
    m.searchTerm = "News & sport"
    rSearchSubmit()
    rCheck(m.queue.count() = 1 and m.queue[0].tag = "search:channels","Live-only search sends no unsupported media request")
    channelRequest = m.queue[0]
    rCheck(channelRequest.path = rProfilePath("/live/channels?limit=40&search=News%20%26%20sport"),"channel search transmits the exact escaped draft")
    m.pending = {}
    m.queue = []
    rSearchChannelResponse(snapshot.first_page,channelRequest)
    rCheck(m.shelves.content.getChildCount() = 1 and m.shelves.content.getChild(0).title = "Channels","Live-only result set renders a Channels shelf")
    row = m.shelves.content.getChild(0)
    rCheck(row.getChild(0).wire.channel.id = snapshot.first_page.channels[0].id,"channel result preserves server action identity")
    rCheck(row.getChild(0).uiWidth = 356 and row.getChild(0).imageHeight = 200,"channel result uses KMP image geometry")
    rSearchChannelResponse(snapshot.compatible_next_page,{context:{direction:"next",paging:snapshot.first_page.paging.next}})
    row = m.shelves.content.getChild(0)
    rCheck(row.getChildCount() = 2 and row.getChild(1).wire.channel.id = "channel-two","channel pages preserve server order")
    thirdPage = RCopy(snapshot.compatible_next_page)
    thirdPage.channels[0].id = "channel-three"
    thirdPage.channels[0].card.identity.id = "channel-three"
    thirdPage.paging = {origin:"opaque-tail",limit:1,page_size:1,previous:{cursor:"1",limit:1,page_size:1},next:invalid}
    rSearchChannelResponse(thirdPage,{context:{direction:"next",paging:thirdPage.paging.next}})
    rCheck(m.searchChannelPages.count() = 2 and RLiveBoundary(m.searchChannelPages,"previous").cursor = "0","channel search bounds payload and paging metadata to the retained server pages")
    rSearchChannelResponse(snapshot.first_page,{context:{direction:"previous",cursor:""}})
    rCheck(m.searchChannelPages.count() = 2 and RLiveBoundary(m.searchChannelPages,"previous") = invalid and m.shelves.content.getChild(0).getChild(0).wire.channel.id = "channel-one","channel search prepends the previous server page without reordering")
    rSearchChannelResponse(snapshot.configuration_changed_next_page,{context:{direction:"next",cursor:"2"}})
    rCheck(m.searchChannelPages.count() = 0 and m.queue[m.queue.count()-1].context.direction = "initial","channel search snapshot mismatch discards incompatible pages and reloads")
    m.retryAuth = [channelRequest]
    m.inputPurpose = "search"
    m.keyboard.text = "new search"
    m.keyboard.visible = true
    rTextChanged()
    rCheck(not rRequestCurrent(channelRequest) and m.retryAuth.count() = 0 and m.queue.count() = 0 and not m.shelves.visible,"query edit immediately retires requests, auth replay and old results before debounce")
    rNavigation(producer.navigation.movie_and_live)
    rSearchSubmit()
    rCheck(m.queue.count() = 2,"mixed capability search requests both independent server sets")
    m.pending = {}
    m.queue = []
    rPageResponse("search",{rows:[{title:"Server group",cards:[second,card]}]},{})
    rSearchChannelResponse(snapshot.first_page,{context:{direction:"initial",paging:invalid}})
    rCheck(m.shelves.content.getChild(0).title = "Server group" and m.shelves.content.getChild(0).getChild(0).wire.identity.id = second.identity.id and m.shelves.content.getChild(1).title = "Channels","media groups and channel rows keep independent producer ordering")
    m.searchFailures = {}
    mediaFailed = {tag:"search",path:"/api/search",method:"GET",epoch:m.epoch,generation:m.generation,context:{search_version:m.searchVersion}}
    channelFailed = {tag:"search:channels",path:rProfilePath("/live/channels?search=new"),method:"GET",epoch:m.epoch,generation:m.generation,context:{search_version:m.searchVersion,channel_version:m.searchChannelVersion,direction:"next",paging:snapshot.first_page.paging.next}}
    rSearchFailure(mediaFailed,"Media unavailable")
    rSearchFailure(channelFailed,"Channels unavailable")
    rCheck(m.failedRequest.tag = "search" and m.shelves.content.getChildCount() = 2,"independent search failures preserve successful result sets")
    rPageResponse("search",{rows:[{title:"Server group",cards:[card]}]},mediaFailed)
    rCheck(m.failedRequest.tag = "search:channels" and m.message.text = "Channels unavailable","successful media retry still exposes independent channel failure")
    m.searchFailures = {}
    m.failedRequest = invalid
    rNavigation(producer.navigation.restricted_without_parent)
    rCheck(m.queue.count() = 1 and m.queue[0].tag = "search" and m.searchChannelPages.count() = 0,"revoked channel capability retires results and issues only authorized media search")
    rNavigation([{id:"search",label:"Search"}])
    rCheck(m.queue.count() = 0 and not m.searchMediaAllowed and not m.searchChannelsAllowed,"missing current capability flags grant no search authority")
    m.searchTerm = invalid
    rSearchSubmit()
    rCheck(m.queue.count() = 0,"capability refresh before typing handles an unset query on native Roku")
    m.searchTerm = ""
    rSearchSubmit()
    rCheck(m.queue.count() = 0 and m.searchMediaRows.count() = 0 and m.searchChannelPages.count() = 0,"blank search clears both result sets")
    rReset("search")
    m.keyboard.visible = true
    m.keyboard.setFocus(true)
    m.searchMediaRows = [{id:"empty",title:"Empty provider",cards:[]},{id:"failed",title:"Failed provider",message:"Server failure message",cards:[]}]
    rSearchRender()
    rCheck(m.shelves.content.getChild(0).searchMessage = "No matches." and m.shelves.content.getChild(1).searchMessage = "Server failure message","empty and failed groups retain their producer order and exact status")
    rSearchResultsFocus()
    rCheck(m.searchFirstResult = invalid and m.keyboard.isInFocusChain(),"empty search groups never receive result focus")
    titleNode = CreateObject("roSGNode","RemoteShelfTitle")
    titleNode.content = m.shelves.content.getChild(1)
    rCheck(titleNode.findNode("message").visible and titleNode.findNode("message").text = "Server failure message" and titleNode.findNode("spacer").height = 86,"provider message uses the KMP heading gap and status line")
    m.searchMediaRows = [{id:"media",title:"Media",cards:[card,second]}]
    rSearchRender()
    m.shelves.jumpToRowItem = [0,1]
    m.shelves.setFocus(true)
    m.searchMediaRows = [{id:"earlier",title:"Earlier",cards:[]},{id:"media",title:"Media",cards:[second,card]}]
    rSearchRender()
    rCheck(REqual(m.shelves.jumpToRowItem,[1,0]),"search focus follows group and canonical card identity across reorder")
    m.searchMediaRows = [{id:"media",title:"Media",cards:[card]}]
    rSearchRender()
    rCheck(REqual(m.shelves.jumpToRowItem,[0,0]),"removed focused card falls back to the first real result")
    m.searchMediaRows = [{id:"empty",title:"Empty",cards:[]}]
    rSearchRender()
    rCheck(m.keyboard.isInFocusChain() and m.searchExpectedFocus = invalid,"removing all results restores keyboard focus without an impossible pending target")
    m.searchTerm = "query"
    request = {tag:"search",path:"/api/search?query=query",method:"GET",epoch:m.epoch,generation:m.generation,context:{search_version:m.searchVersion}}
    rPageResponse("search",{rows:[{id:"provider",title:"Provider",cards:[card],message:"Server partial result"}],complete:false},request)
    rCheck(m.failedRequest.path = request.path and m.retryBar.visible and m.shelves.content.getChild(0).getChildCount() = 1,"server partial results expose Retry while preserving usable cards")
    rPageResponse("search",{rows:[{id:"provider",title:"Provider",cards:[card]}],complete:true},request)
    rCheck(not m.retryBar.visible and m.failedRequest = invalid and m.shelves.content.getChild(0).searchMessage = "","complete retry removes only its obsolete failure state")
    m.searchMediaRows = []
    unavailable = RCopy(snapshot.reload_first_page)
    unavailable.channels = []
    unavailable.availability = "NeedsConfiguration"
    unavailable.reason = "Assign a server connection"
    unavailable.complete = true
    unavailable.next_cursor = invalid
    m.searchChannelPages = []
    rSearchChannelResponse(unavailable,{context:{direction:"initial",paging:invalid}})
    rCheck(m.shelves.content.getChild(0).searchMessage = unavailable.reason and m.searchFirstResult = invalid,"channel unavailability preserves the server reason without a selectable placeholder")
    rReset("search")
    m.searchChannelsAllowed = true
    m.searchTerm = "same query"
    rSearchChannelFetch(invalid,"initial")
    initialSearchPage = m.queue[m.queue.count()-1]
    rCheck(rRequestCurrent(initialSearchPage),"empty channel window accepts its initial request")
    m.pending = {}
    m.queue = []
    rSearchChannelResponse(snapshot.first_page,initialSearchPage)
    rCheck(not rRequestCurrent(initialSearchPage),"an already-applied initial search page cannot overwrite the retained window")
    rSearchChannelFetch(snapshot.first_page.paging.next,"next")
    oldPage = m.queue[m.queue.count()-1]
    rCheck(rRequestCurrent(oldPage),"current next cursor retains channel request ownership")
    wrongCursor = RCopy(oldPage)
    wrongCursor.context.paging.cursor = "other-server-cursor"
    rCheck(not rRequestCurrent(wrongCursor),"wrong next cursor cannot replay into current channel window")
    mediaRequest = {tag:"search",path:"/api/search",method:"GET",epoch:m.epoch,generation:m.generation,context:{search_version:m.searchVersion}}
    m.retryAuth = [oldPage,mediaRequest]
    m.searchMediaRows = [{id:"kept",title:"Keep media",cards:[card]}]
    channelVersion = m.searchChannelVersion
    rSearchChannelResponse(snapshot.configuration_changed_next_page,oldPage)
    rCheck(m.searchChannelVersion = channelVersion+1 and not rRequestCurrent(oldPage),"snapshot replacement retires even same-query channel replies")
    rCheck(m.retryAuth.count() = 1 and m.retryAuth[0].tag = "search" and rRequestCurrent(mediaRequest),"channel-only reset preserves independent media auth replay")
    rCheck(m.searchMediaRows[0].id = "kept" and m.searchChannelPages.count() = 0,"channel-only reset preserves successful media results")
    reloaded = m.queue[m.queue.count()-1]
    rCheck(reloaded.context.direction = "initial" and rRequestCurrent(reloaded),"snapshot reload owns a fresh initial generation")
    m.request = oldPage
    m.result = {ok:true,status:200,data:snapshot.compatible_next_page}
    rResponse({getRoSGNode:remoteOwnedNode,getData:remoteOwnedData,request:m.request,result:m.result})
    rCheck(m.searchChannelPages.count() = 0 and m.pending["search:channels"] = reloaded.request_id,"late pre-snapshot response cannot populate the new window or clear its pending owner")
    m.pending = {}
    m.queue = []
    rSearchChannelResponse(snapshot.reload_first_page,reloaded)
    rCheck(not rRequestCurrent(oldPage) and not rRequestCurrent(reloaded),"retired page and duplicate initial response stay stale after reload success")
    rReset("search")
    m.searchChannelsAllowed = true
    m.searchTerm = "paging"
    rSearchChannelResponse(snapshot.first_page,{context:{direction:"initial",paging:invalid}})
    rSearchChannelResponse(snapshot.compatible_next_page,{context:{direction:"next",paging:snapshot.first_page.paging.next}})
    rSearchChannelResponse(snapshot.compatible_next_page,{context:{direction:"next",cursor:"2"}})
    m.pending = {}
    m.queue = []
    m.searchExpectedFocus = invalid
    m.shelves.jumpToRowItem = [0,0]
    m.shelves.setFocus(true)
    rCheck(rSearchPreviousKey() and m.shelves.isInFocusChain() and m.queue.count() = 1,"Left at an evicted channel boundary waits for previous page without leaving results")
    rCheck(rSearchPreviousKey() and m.queue.count() = 1,"repeated boundary Left does not duplicate pending page requests")
    previousRequest = m.queue[0]
    m.pending = {}
    m.queue = []
    m.retryAuth = [previousRequest]
    rSearchChannelFetch(previousRequest.context.paging,"previous")
    rCheck(m.queue.count() = 0,"channel paging waits for current authentication replay")
    m.retryAuth = []
    m.afterParent = previousRequest
    rSearchChannelFetch(previousRequest.context.paging,"previous")
    rCheck(m.queue.count() = 0,"channel paging waits for current parent authorization")
    m.afterParent = invalid
    m.failedRequest = previousRequest
    rCheck(not rSearchPreviousKey(),"failed page leaves keyboard and explicit Retry accessible")
    m.failedRequest = invalid
    m.searchChannelPages[0].paging.previous = invalid
    rCheck(not rSearchPreviousKey(),"true first channel permits Left to keyboard")
    m.shelves.jumpToRowItem = [0,1]
    rSearchFocused()
    m.keyboard.setFocus(true)
    rSearchResultsFocus()
    rCheck(REqual(m.shelves.jumpToRowItem,[0,1]) and m.shelves.isInFocusChain(),"return from keyboard restores the current result rather than resetting to first")
    rCheck(rCatalogVisibleOffset({y:704,height:424},244,0) = -48,"catalog visibility includes the complete focused caption below the artwork")
    rCheck(rCatalogVisibleOffset({y:196,height:424},244,-48) = 0,"returning to top row restores original catalog origin")
    rCheck(rCatalogVisibleOffset({y:656,height:424},244,-48) = -48,"a fully visible corrected card does not drift on repeated focus updates")
    rCheck(rCatalogVisibleOffset({y:758,height:424},298,0) = -102,"Library status height participates in full-card visibility")
    rReset("movie")
    rCatalogViewport(244)
    rCheck(m.top.findNode("catalogClip").clippingRect.x = 80 and m.top.findNode("catalogClip").clippingRect.y = 244 and m.top.findNode("catalogClip").clippingRect.width = 1760 and m.top.findNode("catalogClip").clippingRect.height = 836,"catalog clipping protects the original header and filter region")
    m.catalogOffset = -48
    rCatalogViewport(298)
    rCheck(REqual(m.grid.translation,[96,250]) and m.top.findNode("catalogClip").clippingRect.y = 298 and m.top.findNode("catalogClip").clippingRect.height = 782,"viewport changes retain current renderer correction until measured focus settles")
    m.grid.content = rContent([card],232,424,348,"poster")
    m.grid.visible = true
    m.grid.setFocus(true)
    rOpenDrawer("Test",[{title:"Close",action:"close"}],"test")
    rCheck(m.drawerOpener.id = "grid","catalog drawer records the actual grid rather than its clipping container")
    rCompleteDrawerClose()
    rCheck(m.grid.isInFocusChain(),"drawer Back restores catalog focus through its clipping container")
    rReset("profiles")
    rCheck(m.catalogOffset = 0 and m.top.findNode("catalogClip").clippingRect.y = 0 and m.top.findNode("catalogClip").clippingRect.height = 1080,"leaving catalog retires its viewport correction and clipping")
    rReset("live")
    m.playback = invalid
    m.drawer.visible = false
    m.keyboard.visible = false
    m.afterParent = invalid
    m.retryAuth = []
    m.pending = {}
    m.queue = []
    m.liveQuery = ""
    latePage = RCopy(producer.live_pagination_snapshot.first_page)
    latePage.next_cursor = producer.live_offset_boundary.first_expected.next_cursor
    latePage.paging = {origin:"10000",limit:40,page_size:40,previous:{cursor:"9960",limit:40,page_size:40},next:{cursor:"10040",limit:40,page_size:40}}
    rLive(latePage)
    request = m.queue[m.queue.count()-1]
    rCheck(request.tag = "live:page" and request.context.paging.cursor = "10040" and instr(1,request.path,"offset=10040") > 0,"Live follows the producer cursor beyond ten thousand without local truncation")
    rReset("search")
    m.searchChannelsAllowed = true
    m.searchTerm = "large directory"
    m.pending = {}
    m.queue = []
    rSearchChannelResponse(latePage,{context:{direction:"initial",paging:invalid}})
    m.searchExpectedFocus = invalid
    rSearchFocused()
    request = m.queue[m.queue.count()-1]
    rCheck(request.tag = "search:channels" and request.context.paging.cursor = "10040" and instr(1,request.path,"offset=10040") > 0,"channel search follows the same producer boundary cursor unchanged")
    m.pending = {}
    m.queue = []
    rSearchChannelFetch({cursor:"4294967295",limit:200,page_size:200},"next")
    rCheck(instr(1,m.queue[0].path,"offset=4294967295") > 0,"transport preserves the current producer's full unsigned cursor range as an opaque string")
    rReset("settings")
    rSettingsSection("Parental controls")
    rCheck(m.settingsNav.itemFocused = 7,"read-only settings section restores its matching sidebar focus")
    rSettingsResponse("settings:parent",{pin_configured:true,unlocked:false,restricted:true},{})
    rCheck(m.rows.content.getChildCount() = 1 and m.rows.content.getChild(0).wire.action = "unlock","configured locked parental status exposes supported PIN unlock")
    rSettingsResponse("settings:parent",{pin_configured:true,unlocked:true,restricted:true},{})
    rCheck(m.rows.content.getChildCount() = 0 and m.message.text = "Parent PIN unlocked" and REqual(m.message.translation,[640,220]),"accepted grant exposes readable status without an account-only parental editor")
    rSettingsResponse("settings:parent",{pin_configured:false,unlocked:false,restricted:false},{})
    rCheck(m.rows.content.getChildCount() = 0 and instr(1,m.message.text,m.config.base) > 0,"unconfigured PIN points to account setup without a device-side policy editor")
    rReset("profiles")
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.afterParent = invalid
    m.workers = []
    m.playback = invalid
    m.config.refresh_token = "keep-profile-refresh"
    rReset("search")
    rTextInput("Search","search",false,"Preserved search draft")
    m.searchTerm = "Preserved search draft"
    m.searchTick.control = "stop"
    rTextInput("Parent PIN","unlockResume",true,"")
    rFormEdit()
    m.keyboard.text = "5274"
    rCheck(m.searchTerm = "Preserved search draft" and m.searchTick.control <> "start","secret input over Search cannot become a search draft or schedule a query")
    rTextDone()
    rTextCancel()
    rCheck(m.keyboard.visible and m.keyboard.searchMode and m.inputPurpose = "search" and m.keyboard.text = "Preserved search draft","cancelling parent modal restores the underlying Search input and draft")
    rReset("profiles")
    m.pending = {}
    m.queue = []
    rTextInput("Profile name","createProfile",false,"Original modal draft")
    rCheck(m.formDialog.visible and not m.keyboard.visible and m.formDialog.text = "Original modal draft","profile entry opens the KMP modal rather than a full-page form")
    rFormEdit()
    m.keyboard.text = "Discarded input-method edit"
    rTextCancel()
    rCheck(m.formDialog.visible and not m.keyboard.visible and m.formDialog.text = "Original modal draft" and m.queue.count() = 0,"Back from the input method returns the unchanged modal draft without cancelling the form")
    rFormEdit()
    m.keyboard.text = "Accepted input-method edit"
    rTextDone()
    rCheck(m.formDialog.visible and not m.keyboard.visible and m.formDialog.text = "Accepted input-method edit" and m.profileForm.text = m.formDialog.text and m.queue.count() = 0,"Done returns the edited name to the dialog without sending a mutation")
    rFocusContent()
    rCheck(m.formDialog.isInFocusChain(),"background content focus restoration cannot escape a visible modal")
    m.formDialog.callFunc("onKeyEvent","right",true)
    rCheck(m.formDialog.focusIndex = 2,"modal directional focus reaches the confirmation button")
    m.formDialog.callFunc("onKeyEvent","left",true)
    rCheck(m.formDialog.focusIndex = 1,"modal focus returns to Cancel")
    m.formDialog.callFunc("onKeyEvent","up",true)
    rCheck(m.formDialog.focusIndex = 0,"modal focus returns to its field")
    rTextCancel()
    rTextInput("Profile name","createProfile",false,"Nonempty rejected draft")
    rFormSubmit()
    profileSave = m.queue[0]
    rCheck(profileSave.body.name = "Nonempty rejected draft" and m.formDialog.visible and m.formDialog.busy and m.formDialog.text = profileSave.body.name,"profile submit retains the draft until server acceptance")
    rFormSubmit()
    m.formDialog.callFunc("onKeyEvent","OK",true)
    rCheck(m.queue.count() = 1 and m.formDialog.text = profileSave.body.name,"busy profile form blocks duplicate submit and editing")
    remoteFormResponse(profileSave,{ok:false,status:400,error:"Name rejected by server"})
    rCheck(m.formDialog.visible and not m.formDialog.busy and m.formDialog.text = "Nonempty rejected draft" and m.formDialog.error = "Name rejected by server","rejected profile save preserves an editable name and server error")
    m.formDialog.text = "Edited after rejection"
    rFormSubmit()
    queuedSave = m.queue[0]
    rTextCancel()
    rCheck(m.queue.count() = 0 and not m.pending.doesExist("save:profile") and not m.formDialog.visible and m.profileForm = invalid,"Back retires an unissued profile mutation and clears its transient draft")
    rTextInput("Profile name","createProfile",false,"In-flight old draft")
    rFormSubmit()
    lateSave = m.queue[0]
    m.queue = []
    rTextCancel()
    rTextInput("Profile name","createProfile",false,"Current draft")
    m.profilesRefreshPending = false
    remoteFormResponse(lateSave,{ok:true,status:200,data:{id:"server-created-profile"}})
    rCheck(m.formDialog.visible and m.formDialog.text = "Current draft" and not m.formDialog.busy and m.queue.count() = 0,"late accepted profile mutation cannot replace or navigate a newer editor")
    rCheck(m.profilesRefreshPending and m.revisionDue = 0,"late profile acceptance still invalidates dependent server views")
    rFormSubmit()
    acceptedSave = m.queue[0]
    remoteFormResponse(acceptedSave,{ok:true,status:200,data:{id:"server-current-profile"}})
    rCheck(not m.formDialog.visible and m.formDialog.text = "" and m.profileForm = invalid and m.queue[m.queue.count()-1].tag = "profiles","accepted current save clears the draft and refetches the authoritative profile list")
    m.pending = {}
    m.queue = []
    m.editProfile = {id:"7",name:"Original name"}
    rTextInput("Profile name","renameProfile",false,"Name awaiting parent")
    rFormSubmit()
    protectedSave = m.queue[0]
    remoteFormResponse(protectedSave,{ok:false,status:403,auth_code:"parent_required",error:"Parent PIN required"})
    rCheck(m.inputPurpose = "unlockResume" and m.formDialog.visible and m.formDialog.purpose = "unlockResume" and m.profileForm.text = "Name awaiting parent","parent challenge preserves the original name while opening secret PIN entry")
    m.formDialog.text = "0000"
    rFormSubmit()
    pinSave = m.queue[0]
    rCheck(m.formDialog.busy and m.formDialog.text = "0000" and pinSave.body.pin = "0000","PIN submission retains only the masked transient dialog and waits for server authority")
    remoteFormResponse(pinSave,{ok:false,status:403,auth_code:"parent_pin_invalid",error:"PIN rejected by server"})
    rCheck(not m.formDialog.busy and m.formDialog.visible and m.formDialog.text = "0000" and m.formDialog.error = "That parent PIN was not accepted. Try again." and m.profileForm.text = "Name awaiting parent","invalid PIN can retry without losing the original profile draft")
    rCheck(pinSave.body.pin = "","completed PIN request is scrubbed after transport processing")
    m.formDialog.text = "5274"
    rFormSubmit()
    cancelledPin = m.queue[0]
    m.queue = []
    rTextCancel()
    rCheck(m.formDialog.busy and m.inputPurpose = "unlockResume","busy parent dialog prevents Back cancellation as KMP does")
    remoteFormResponse(cancelledPin,{ok:false,status:403,auth_code:"parent_pin_invalid",error:"Try again"})
    rTextCancel()
    rCheck(m.inputPurpose = "renameProfile" and m.formDialog.purpose = "renameProfile" and m.formDialog.text = "Name awaiting parent" and m.afterParent = invalid,"cancelling authorization returns to the unsaved name draft")
    remoteFormResponse(cancelledPin,{ok:true,status:200,data:{unlocked:true}})
    rCheck(m.queue.count() = 0 and m.formDialog.text = "Name awaiting parent" and not m.formDialog.busy,"late parent grant cannot replay a cancelled profile mutation")
    rFormSubmit()
    protectedSave = m.queue[0]
    remoteFormResponse(protectedSave,{ok:false,status:403,auth_code:"parent_required",error:"Parent PIN required"})
    m.formDialog.text = "5274"
    rFormSubmit()
    pinSave = m.queue[0]
    remoteFormResponse(pinSave,{ok:true,status:200,data:{unlocked:true}})
    resumedSave = m.queue[m.queue.count()-1]
    rCheck(resumedSave.tag = "save:profile" and resumedSave.body.name = "Name awaiting parent" and resumedSave.path = protectedSave.path and m.formDialog.visible and m.formDialog.busy and m.formDialog.purpose = "renameProfile","accepted parent authorization resumes only the current original profile intent")
    remoteFormResponse(resumedSave,{ok:true,status:200,data:{id:"7",name:"Name awaiting parent"}})
    rCheck(not m.formDialog.visible and m.queue[m.queue.count()-1].tag = "profiles","authorized profile acceptance returns to fresh server profiles")
    m.pending = {}
    m.queue = []
    rTextInput("Profile name","createProfile",false,"Refresh-safe draft")
    rFormSubmit()
    needsRefresh = m.queue[0]
    remoteFormResponse(needsRefresh,{ok:false,status:401,error:"Access expired"})
    refresh = m.queue[m.queue.count()-1]
    rCheck(refresh.tag = "auth:refresh" and m.retryAuth.count() = 1,"profile mutation participates in bounded credential refresh")
    remoteFormResponse(refresh,{ok:false,status:503,error:"Refresh temporarily unavailable"})
    rCheck(m.formDialog.visible and not m.formDialog.busy and m.formDialog.text = "Refresh-safe draft" and m.retryAuth.count() = 0 and m.config.refresh_token = "keep-profile-refresh","transient refresh failure preserves credentials and releases the editable profile draft")
    m.formDialog.text = "New intent after refresh failure"
    rFormSubmit()
    rCheck(m.queue[m.queue.count()-1].body.name = "New intent after refresh failure","retry after refresh failure uses the current draft rather than an old queued mutation")
    lateSave = m.queue[m.queue.count()-1]
    m.queue = []
    rReset("home")
    remoteFormResponse(lateSave,{ok:true,status:200,data:{id:"late-created"}})
    rCheck(m.route = "home" and not m.formDialog.visible and m.queue.count() = 0,"accepted profile mutation after route change cannot reopen the old form")
    rReset("profiles")
    m.pending = {}
    m.queue = []
    m.management = {capabilities:{rename:{availability:"Available"},avatar:{availability:"Available"},delete:{availability:"Available"}},avatar_ids:["zayne","vynxc"]}
    rSettingsAction({action:"editProfile",profile:{id:"7",name:"First profile",can_delete:true}})
    rSettingsAction({action:"avatar"})
    rSettingsAction({action:"saveAvatar",value:"zayne"})
    avatarSave = m.queue[0]
    rCheck(avatarSave.context.target_profile = "7" and avatarSave.body.avatar_id = "zayne","avatar mutation captures exact server target and choice")
    m.queue = []
    rCloseDrawer()
    rSettingsAction({action:"editProfile",profile:{id:"8",name:"Second profile",can_delete:true}})
    remoteFormResponse(avatarSave,{ok:true,status:200,data:{id:"7",avatar_id:"zayne"}})
    rCheck(m.drawer.visible and m.drawerTitle.text = "Second profile" and m.editProfile.id = "8" and m.queue.count() = 0,"late avatar acceptance cannot close another profile editor")
    rSettingsAction({action:"confirmDeleteProfile"})
    rSettingsAction({action:"deleteProfile"})
    deleteSave = m.queue[0]
    rCheck(deleteSave.method = "DELETE" and deleteSave.context.target_profile = "8","delete intent captures its original profile target")
    m.queue = []
    rReset("home")
    remoteFormResponse(deleteSave,{ok:true,status:204,data:{ok:true}})
    rCheck(m.route = "home" and not m.drawer.visible and m.queue.count() = 0,"late delete acceptance cannot navigate to a retired profile editor")
    rReset("settings")
    m.section = "Parental controls"
    m.pending = {}
    m.queue = []
    rTextInput("Parent PIN","unlock",true,"")
    m.formDialog.text = "5274"
    rFormSubmit()
    latePin = m.queue[0]
    m.queue = []
    rReset("settings")
    m.section = "Parental controls"
    remoteFormResponse(latePin,{ok:true,status:200,data:{unlocked:true}})
    rCheck(not m.formDialog.visible and m.route = "settings" and m.queue.count() = 1 and m.queue[0].tag = "settings:parent","late standalone PIN grant refreshes current permission status without reopening its cancelled form")
    rCheck(latePin.body.pin = "","retired PIN acknowledgement also scrubs the secret payload")
    rReset("profiles")
    m.pending = {}
    m.queue = []
    m.afterParent = invalid
    switch = {tag:"auth:profile",method:"POST",path:"/api/auth/profile",body:{profile_id:"server-target"},epoch:m.epoch,generation:m.generation,context:{},request_id:"late-switch"}
    m.afterParent = switch
    rReset("home")
    rCheck(m.afterParent = invalid,"route replacement retires pending parent-authorized intent")
    remoteFormResponse(switch,{ok:false,status:403,auth_code:"parent_required",error:"Parent required"})
    rCheck(m.route = "home" and not m.keyboard.visible and m.afterParent = invalid,"late rejected profile selection cannot open a PIN over the new route")
    remoteFormResponse(switch,{ok:false,status:401,error:"Access expired"})
    rCheck(m.queue.count() = 0 and m.retryAuth.count() = 0,"retired rejected selection cannot replay through token refresh")
    remoteFormResponse(switch,{ok:false,status:503,error:"Could not confirm selection"})
    rCheck(m.route = "home" and not m.keyboard.visible and m.queue[m.queue.count()-1].tag = "auth:bootstrap","unknown retired selection outcome reconciles server identity without replaying the old mutation")
    oldBootstrap = m.queue[m.queue.count()-1]
    bootstrapWorker = CreateObject("roSGNode","RemoteTask")
    bootstrapWorker.request = oldBootstrap
    m.workers = [bootstrapWorker]
    remoteFormResponse(switch,{ok:true,status:200,data:{profile_id:"server-target"}})
    rCheck(bootstrapWorker.cancel,"accepted selection cancels an earlier bootstrap worker")
    rCheck(m.profile = "" and m.queue[m.queue.count()-1].tag = "auth:bootstrap","accepted server selection retires old profile views and re-resolves bootstrap identity")
    freshBootstrap = m.queue[m.queue.count()-1]
    remoteFormResponse(oldBootstrap,{ok:false,status:401,error:"Retired bootstrap"})
    rCheck(m.pending["auth:bootstrap"] = freshBootstrap.request_id,"retired bootstrap cannot clear the fresh identity read owner")
    m.workers = []
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.config.access_token = "owner-access"
    m.config.refresh_token = "owner-refresh"
    refreshOwner = {tag:"auth:refresh",method:"POST",path:"/api/auth/device/refresh",body:{refresh_token:"owner-refresh"},base:m.config.base,access_token:m.config.access_token,request_id:"owned-rotation",epoch:m.epoch,generation:m.generation,context:{}}
    m.epoch++
    rCheck(rRequestCurrent(refreshOwner),"same credential owner retains refresh across profile epoch changes")
    remoteFormResponse(refreshOwner,{ok:true,status:200,data:{access_token:"rotated-access",refresh_token:"rotated-refresh",expires_in:300}})
    rCheck(m.config.access_token = "rotated-access" and m.config.refresh_token = "rotated-refresh","profile epoch cannot discard accepted current credential rotation")
    remoteFormResponse(refreshOwner,{ok:true,status:200,data:{access_token:"retired-access",refresh_token:"retired-refresh",expires_in:300}})
    rCheck(m.config.access_token = "rotated-access" and m.queue[m.queue.count()-1].path = "/api/auth/logout" and m.queue[m.queue.count()-1].access_token = "retired-access","changed credential owner retires late rotation without adopting its tokens")
    m.pending = {}
    m.queue = []
    rSend("POST","/api/auth/device/refresh",{refresh_token:m.config.refresh_token},"auth:refresh")
    rSend("GET","/api/bootstrap",invalid,"auth:bootstrap")
    rForgetSession()
    forbiddenAuthWork = false
    for each request in m.queue
        if request.tag = "auth:refresh" or request.tag = "auth:bootstrap" then forbiddenAuthWork = true
    end for
    rCheck(not forbiddenAuthWork and m.config.refresh_token = "","forgetting identity retires unissued refresh and bootstrap work")
    rReset("history")
    m.historyEntries = []
    m.historyOffset = 0
    projected = RCopy(card)
    projected.identity.id = "server-first-z"
    projected.subtitle = "Server says continue this item"
    projected.progress = 0.999
    projected.landscape = ""
    projected.poster = "pkg:/images/design/remote-avatar-vynxc.png"
    silent = RCopy(projected)
    silent.identity.id = "server-second-a"
    silent.subtitle = invalid
    m.skeleton.visible = true
    rPageResponse("history",[{card:projected,completed_at_millis:123,updated_at_millis:456},{card:silent,completed_at_millis:789,updated_at_millis:999}],{})
    rCheck(not m.skeleton.visible,"accepted history response retires its loading presentation")
    first = m.rows.content.getChild(0)
    second = m.rows.content.getChild(1)
    rCheck(first.description = "Server says continue this item" and second.description = "","history uses producer subtitle unchanged even when timestamps disagree or presentation is absent")
    rCheck(first.wire.card.identity.id = "server-first-z" and second.wire.card.identity.id = "server-second-a","history preserves producer ordering instead of sorting by identity or timestamps")
    rCheck(first.HDPosterUrl = "" and not first.wire.doesExist("historyProgress"),"history neither selects another artwork role nor derives a watched percentage label")
    rReset("player")
    m.pending = {}
    m.queue = []
    m.playback = {session:{id:"input-gate",actions:{pause:false,seek:false}},card:card,source:{id:"input-source"},body:{},firstFrame:true,sequence:0}
    rShowControls()
    rCheck(m.playerInput.hasFocus() and not m.player.isInFocusChain() and not m.player.focusable,"no-action player keeps native keys on the server-gated Scene")
    rHideControls()
    rCheck(m.playerInput.hasFocus() and not m.player.isInFocusChain() and not m.playerUi.visible,"hidden controls cannot give native Video an input path around server decisions")
    before = m.player.control
    m.playerInput.callFunc("onKeyEvent","play",true)
    m.playerInput.callFunc("onKeyEvent","fastforward",true)
    rCheck(m.player.control = before and m.queue.count() = 0 and m.seekPosition = invalid,"denied pause and seek intents do not operate the decoder or submit admission")
    m.playback.session.actions = {pause:true,seek:true,tracks:true}
    m.playback.session.delivery = {duration:120,live:false,timeline_offset_seconds:0}
    rShowControls()
    rCheck(m.playerActions.isInFocusChain(),"supported controls can own the player action row")
    m.playerInput.callFunc("onKeyEvent","fastforward",true)
    rCheck(m.seekPosition <> invalid and m.playerInput.hasFocus(),"dedicated input press enters the Scene's server-authorized seek draft even with the action row focused")
    draft = m.seekPosition
    rPlayerInputPressed({getData:qaRewindInput})
    rCheck(m.seekPosition < draft,"queued input uses the event payload even when the component's latest key still says forward")
    m.seekPosition = invalid
    m.playback = invalid
    qaBidirectionalPaging(producer)
    qaHomePreviewChecks(producer,contracts)
    print "REMOTE_ROKU_RUNTIME_OK"
end sub

function remoteStaleSourceNode() as object
    return {request:{tag:"sources:start",request_id:"1-old",epoch:1,generation:0,path:"/api/streams",method:"POST",base:"https://example.test",access_token:"fixture",context:{source_epoch:-1}}}
end function
function remoteStaleSourceData() as object
    return {ok:true,status:200,data:{id:"stale-job"}}
end function
function remoteRefreshNode() as object
    return {request:{tag:"auth:refresh",request_id:"1-refresh",epoch:1,generation:0,path:"/api/auth/device/refresh",method:"POST",base:"https://example.test",access_token:"fixture",body:{refresh_token:"keep-refresh"}}}
end function
function remoteLogoutNode() as object
    return {request:{tag:"auth:logout",request_id:"1-logout",epoch:1,generation:0,path:"/api/auth/logout",method:"POST",base:"https://example.test",access_token:"fixture"}}
end function
function remoteTransientData() as object
    return {ok:false,status:503,error:"Temporary failure"}
end function
function remoteDeniedData() as object
    return {ok:false,status:403,error:"Not permitted"}
end function
function remotePersistOldNode() as object
    return {request:{tag:"auth:persist",request_id:"old-persist",epoch:0,generation:0,method:"CONFIG_SAVE"}}
end function
function remotePersistData() as object
    return {ok:true,status:0,data:{}}
end function

sub rCheck(condition as boolean, label as string)
    if not condition
        print "REMOTE_CHECK_FAILED: ";label
        stop
    end if
end sub

function remotePairingNode() as object
    return {request:m.pairingRequestFromTest}
end function
function remotePairingData() as object
    return {ok:true,status:200,data:{user_code:"12345678",device_code:"fixture-cancelled"}}
end function

function remoteOwnedNode() as object
    return {request:m.request}
end function
function remoteOwnedData() as object
    return m.result
end function

function qaFocusZero() as integer
    return 0
end function
function qaFocusTarget() as integer
    return 42
end function

function qaLiveFocusTarget() as integer
    return 15
end function

sub remoteFormResponse(request as object, result as object)
    ' The fixture dispatcher is disabled; model its dequeue before the real callback.
    m.queue = []
    m.request = request
    m.result = result
    rResponse({request:request,result:result,getRoSGNode:remoteOwnedNode,getData:remoteOwnedData})
end sub

sub qaBidirectionalPaging(producer as object)
    spec = producer.live_reverse_paging
    first = qaPagingPage(producer,spec.first_response_paging,["0","1"])
    middle = qaPagingPage(producer,spec.previous_response_paging,["2","3","4"])
    last = qaPagingPage(producer,spec.paging,["5","6"])
    wireRequest = {path:"/api/profiles/7/live/channels",method:"GET"}
    rCheck(RemoteWireResponse(wireRequest,{ok:true,data:first}).ok,"current full reverse page passes wire validation")
    missing = RCopy(first)
    missing.delete("paging")
    rCheck(not RemoteWireResponse(wireRequest,{ok:true,data:missing}).ok,"missing shared paging rejects an old server even when next_cursor exists")
    for each field in ["previous","next","page_size"]
        broken = RCopy(first)
        broken.paging.delete(field)
        rCheck(not RemoteWireResponse(wireRequest,{ok:true,data:broken}).ok,"missing current paging field is incompatible")
    end for
    for each size in [0,201]
        broken = RCopy(first)
        broken.paging.next.limit = size
        rCheck(not RemoteWireResponse(wireRequest,{ok:true,data:broken}).ok,"unbounded/empty producer page descriptor is rejected before rendering")
    end for
    rReset("live")
    m.pending = {}
    m.queue = []
    m.retryAuth = []
    m.afterParent = invalid
    m.playback = invalid
    m.liveQuery = "&group_id=authority-group"
    rLive(last)
    m.pending = {}
    m.queue = []
    rLivePageFetch("previous")
    request = m.queue[0]
    rCheck(request.path = rProfilePath("/live/channels?limit=3&page_size=3&group_id=authority-group&offset=2") and rRequestCurrent(request),"Live sends the exact server reverse descriptor with unchanged query scope")
    changed = RCopy(request)
    changed.context.paging.limit = 2
    rCheck(not rRequestCurrent(changed),"same Live cursor with a changed row limit is stale")
    changed = RCopy(request)
    changed.context.paging.page_size = 2
    rCheck(not rRequestCurrent(changed),"same Live cursor with a changed navigation budget is stale")
    rLivePage(middle,request)
    m.pending = {}
    m.queue = []
    rLivePageFetch("previous")
    request = m.queue[0]
    rCheck(request.context.paging.limit = 2 and request.context.paging.page_size = 3 and instr(1,request.path,"offset=0") > 0,"short reverse slice retains the producer navigation budget")
    m.rows.jumpToItem = 0
    rLivePage(first,request)
    m.pending = {}
    m.queue = []
    m.rows.jumpToItem = 2
    rRowFocused()
    rLoadGuides()
    for each queued in m.queue
        rCheck(queued.tag <> "live:page","restored Live focus on a short reverse window cannot immediately prefetch the opposite page")
    end for
    rCheck(m.rows.content.getChildCount() = 5 and m.rows.content.getChild(0).wire.channel.id = "0" and m.rows.content.getChild(4).wire.channel.id = "4","reverse page prepend preserves non-overlapping server order")
    m.pending = {}
    m.queue = []
    rLivePageFetch("next")
    rCheck(m.queue[0].context.paging.limit = 3 and m.queue[0].context.paging.cursor = "5","forward after a short reverse slice restores the server's row budget")
    for cycle = 1 to 100
        rLivePage(last,{context:{query:m.liveQuery,direction:"next"}})
        rLivePage(first,{context:{query:m.liveQuery,direction:"previous"}})
        rCheck(m.livePages.count() = 2 and m.rows.content.getChildCount() = 5,"many Live traversals retain only two server pages with no cursor history")
    end for
    rReset("search")
    m.searchChannelsAllowed = true
    m.searchTerm = "Authority & scope"
    m.pending = {}
    m.queue = []
    rSearchChannelResponse(last,{context:{direction:"initial"}})
    m.pending = {}
    m.queue = []
    rSearchChannelFetch(last.paging.previous,"previous")
    request = m.queue[0]
    rCheck(request.path = rProfilePath("/live/channels?limit=3&page_size=3&search=Authority%20%26%20scope&offset=2") and rRequestCurrent(request),"channel Search sends the same shared server descriptor and escaped query")
    changed = RCopy(request)
    changed.context.paging.page_size = 2
    rCheck(not rRequestCurrent(changed),"channel Search rejects same-cursor changed-budget auth replay")
    rSearchChannelResponse(middle,request)
    m.pending = {}
    m.queue = []
    rSearchChannelFetch(middle.paging.previous,"previous")
    rCheck(m.queue[0].context.paging.limit = 2 and m.queue[0].context.paging.page_size = 3,"channel Search preserves short reverse descriptor fields")
    m.shelves.jumpToRowItem = [0,0]
    rSearchChannelResponse(first,m.queue[0])
    m.pending = {}
    m.queue = []
    m.shelves.jumpToRowItem = [0,2]
    rSearchFocused()
    rCheck(m.queue.count() = 0,"restored channel Search focus cannot bounce forward after a short reverse prepend")
    m.shelves.jumpToRowItem = [0,3]
    rSearchFocused()
    rCheck(m.queue.count() = 1 and m.queue[0].context.paging.cursor = "5","actual forward focus movement may resume the producer-directed lookahead")
    for cycle = 1 to 100
        rSearchChannelResponse(last,{context:{direction:"next"}})
        rSearchChannelResponse(first,{context:{direction:"previous"}})
        rCheck(m.searchChannelPages.count() = 2 and m.shelves.content.getChild(0).getChildCount() = 5,"many channel Search traversals retain a constant two-page working set")
    end for
    rCheck(RLiveBoundary(m.searchChannelPages,"previous") = invalid,"null previous descriptor is the only first-page boundary")
    rSearchChannelResponse(last,{context:{direction:"next"}})
    m.shelves.jumpToRowItem = [0,0]
    m.shelves.setFocus(true)
    m.pending = {}
    m.queue = []
    m.searchFailures["search:channels"] = {request:{tag:"search:channels"},message:"Channel failure"}
    m.failedRequest = {tag:"search"}
    rCheck(not rSearchPreviousKey() and m.queue.count() = 0,"a media error shown first cannot hide the channel failure's explicit Retry gate")
end sub

function qaPagingPage(producer as object, paging as object, ids as object) as object
    value = RCopy(producer.live_pagination_snapshot.first_page)
    value.paging = RCopy(paging)
    value.channels = []
    for each id in ids
        channel = RCopy(producer.live_pagination_snapshot.first_page.channels[0])
        channel.id = id
        channel.card.identity.id = id
        channel.card.title = "Channel "+id
        value.channels.push(channel)
    end for
    return value
end function

function qaRewindInput() as string
    return "rewind"
end function

sub qaHomePreviewChecks(producer as object, contracts as object)
    m.profile = "7"
    m.config.base = "https://example.test"
    m.config.access_token = "fixture"
    m.config.refresh_token = "fixture-refresh"
    m.playback = invalid
    m.admission = invalid
    m.pending = {}
    m.queue = []
    valid = RCopy(contracts.home)
    bad = RCopy(valid)
    bad.rows[0].cards[0].view.delete("preview")
    rCheck(not RHomeWire(bad) and not RemoteWireResponse({path:"/api/profiles/7/home"},{ok:true,data:bad}).ok,"Home without the current producer preview requires a server update")
    for each key in ["continue","saved_same_title","unavailable_hint"]
        rCheck(RHomePreview(producer.home_preview[key]),"shared producer preview accepted including explicit null hints")
    end for
    oversized = RCopy(valid)
    for i = 1 to 25
        oversized.rows[0].cards.push(valid.rows[0].cards[0])
    end for
    rCheck(not RHomeWire(oversized),"Home validates the current producer row bound before creating native content")
    invalidPreview = RCopy(producer.home_preview.continue)
    invalidPreview.progress = 1.1
    rCheck(not RHomePreview(invalidPreview),"invalid preview progress is rejected instead of normalized")
    a = RCopy(valid.rows[0].cards[0])
    a.identity.id = "z-first"
    a.title = "Projected play"
    a.landscape = producer.home_preview.episode_tile_landscape
    a.view.preview = RCopy(producer.home_preview.continue)
    b = RCopy(a)
    b.identity.id = "a-second"
    b.title = "Projected details"
    b.view.preview = RCopy(producer.home_preview.saved_same_title)
    row = {id:"not-continue",title:"Server row",state:"Ready",view:{card_shape:"landscape"},cards:[a,b]}
    home = {scope:{profile_id:"7",revision:1},hero:a,featured:[a],rows:[row],complete:true}
    rReset("home")
    rHome(home)
    m.queue = []
    m.pending = {}
    rShelfSelected({value:[0,0],getData:qaHomeEventData})
    rCheck(m.queue[m.queue.count()-1].path = "/api/profiles/7/viewing-action" and m.queue[m.queue.count()-1].body.card.identity.id = a.identity.id,"arbitrary Home row obeys server play intent through fresh viewing authority")
    rReset("home")
    home.rows[0].id = "continue"
    rHome(home)
    m.queue = []
    m.pending = {}
    rShelfSelected({value:[0,1],getData:qaHomeEventData})
    rCheck(m.route = "detail" and m.detailCard.identity.id = b.identity.id,"Continue row obeys details intent even when resume caption and progress exist")
    rReset("home")
    rHome(home)
    m.shelves.jumpToRowItem = [0,1]
    rHomeEnterShelves()
    rCheck(not m.navigation.focusable and not m.actions.visible,"Home browsing removes navigation and hero controls from focus")
    m.top.findNode("homeMotion").control = "stop"
    rSettleHero()
    rCheck(m.backdrop.uri = producer.home_preview.saved_same_title.background and m.shelves.content.getChild(0).getChild(1).HDPosterUrl = producer.home_preview.episode_tile_landscape,"preview background is server projected without replacing the episode tile")
    rCheck(m.heroTitle.width = 1000 and m.heroDescription.width = 700,"focused summary uses the measured KMP text boxes")
    ' Reordered refresh follows exact identity, retaining the new server order.
    newer = RCopy(home)
    newer.scope.revision = 2
    newer.rows[0].cards = [b,a]
    rHome(newer)
    rCheck(REqual(m.shelves.jumpToRowItem,[0,0]) and m.shelves.content.getChild(0).getChild(0).wire.identity.id = b.identity.id,"Home refresh restores canonical focus through server reorder")
    retained = m.shelves.content.getChild(0).getChild(0)
    retained.id = "unchanged-home-node"
    rHome(newer)
    rCheck(m.shelves.content.getChild(0).getChild(0).id = "unchanged-home-node","unchanged Home rows retain native nodes")
    newer.rows[0].cards = [a]
    newer.scope.revision = 3
    rHome(newer)
    rCheck(REqual(m.shelves.jumpToRowItem,[0,0]) and m.shelves.content.getChild(0).getChild(0).wire.identity.id = a.identity.id,"removed Home card chooses a surviving neighbor")
    m.homeExpectedFocus = [0,1]
    m.pendingHomeHero = invalid
    rShelfFocused({value:[0,0],getData:qaHomeEventData})
    rCheck(m.pendingHomeHero = invalid,"transient first-item focus cannot override an unresolved identity restoration")
    m.homeExpectedFocus = invalid
    m.top.findNode("homeMotion").control = "stop"
    rHero(b,"poster")
    rCheck(m.top.findNode("homePoster").visible = (RText(b.poster) <> "") and m.backdrop.uri = "","poster preview never substitutes a landscape for the missing producer soft-art role")
    rShelfFocused()
    stale = m.pendingHomeHero
    rReset("library")
    m.pendingHomeHero = stale
    oldTitle = m.heroTitle.text
    rSettleHero()
    rCheck(m.heroTitle.text = oldTitle and m.pendingHomeHero = invalid,"retired Home timer cannot render on a new route")
    rReset("home")
    rHome(home)
    m.shelves.jumpToRowItem = [0,1]
    rHomeEnterShelves()
    rPush()
    rReset("detail")
    rBack()
    rCheck(m.route = "home" and m.homeBrowsing and REqual(m.shelves.jumpToRowItem,[0,1]),"detail Back restores the exact Home item and browsing plane")
    m.snapshots.push({route:"library"})
    rBack()
    rCheck(m.route = "home" and m.snapshots.count() > 0,"Back from Home browsing returns to its billboard before popping an older route")
    rCheck(m.navigation.focusable and not m.homeBrowsing and m.pendingHomeHero = invalid,"billboard return retires focused previews and restores navigation")
    m.heroTick.control = "stop"
end sub

function qaHomeEventData() as dynamic
    return m.value
end function
