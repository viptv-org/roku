sub runChecks()
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
    rHome({scope:{account_id:"2",profile_id:"7",revision:1},revision:1,hero:card,featured:[],rows:[{id:"server-row",title:"From your server",state:"Ready",view:{card_shape:"landscape"},cards:[card,second],next_cursor:invalid}],complete:true})
    rCheck(m.shelves.content.getChild(0).getChild(0).wire.identity.id = "opaque-17","server row order")
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
    sources = [{id:"server-second",name:"Server winner",presentation:{quality:"1080p",provider_name:"Provider Z"}},{id:"server-first",name:"Other",presentation:{quality:"2160p",provider_name:"Provider A"}}]
    rShowSources(sources)
    rCheck(m.drawerRows.content.getChild(0).wire.source.id = "server-second","server rank beats quality/name heuristics")
    rCheck(m.drawerRows.content.getChild(0).wire.source.presentation.quality = "1080p","structured source metadata")
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
    rRun({action:"toggleAddon",connection:{id:"addon:opaque"},enabled:false})
    q = m.queue[m.queue.count()-1]
    rCheck(q.path = "/api/profiles/7/addon-activation" and q.body.count() = 2,"addon intent does not construct assignments")
    rReset("profiles")
    management = {profiles:[{id:"7",name:"A",can_delete:false}],capabilities:{create:{availability:"Unavailable"},rename:{availability:"Unavailable"},avatar:{availability:"Unavailable"},delete:{availability:"Unavailable"}},parent:{restricted:false},avatar_ids:[]}
    rProfiles(management)
    rCheck(not m.actions.visible,"unsupported profile actions omitted")
    rCheck(m.grid.content.getChildCount() = 1,"profile renders server data")
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
    lease = {session:{id:"lease-test",delivery:delivery},card:card,source:{id:"server-source"},body:{},owner:{base:"https://example.test",access_token:"fixture",epoch:m.epoch},firstFrame:true,sequence:0,started:rNow()}
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
    print "REMOTE_ROKU_RUNTIME_OK"
end sub

function remoteStaleSourceNode() as object
    return {request:{tag:"sources:start",request_id:"1-old",epoch:1,generation:0,path:"/api/streams",method:"POST",base:"https://example.test",access_token:"fixture",context:{source_epoch:-1}}}
end function
function remoteStaleSourceData() as object
    return {ok:true,status:200,data:{id:"stale-job"}}
end function
function remoteRefreshNode() as object
    return {request:{tag:"auth:refresh",request_id:"1-refresh",epoch:1,generation:0,path:"/api/auth/device/refresh",method:"POST",base:"https://example.test",access_token:"fixture"}}
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
