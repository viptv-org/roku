' Deterministic tests of production lifecycle/queue functions, with node-field fakes.
sub Main()
    m.config = {base:"https://a.example",access_token:"a",last_profile_id:"1",account_id:"account-a",capabilities:{max_width:1280,max_height:720}}
    m.queue = []
    m.tasks = []
    m.cache = {}
    m.cacheKeys = []
    m.homeActions = {itemFocused:0}
    m.generation = 1
    m.poll = {control:""}
    m.status = {text:""}
    m.startup = {control:""}
    m.heartbeat = {control:""}
    m.list = {setFocus:NoopFocus}
    m.video = {position:25,duration:32,control:"",visible:true,state:"playing",setFocus:NoopFocus,globalCaptionMode:"Off"}
    m.replacementVideo = {position:0,duration:0,control:"",visible:false,state:"",setFocus:NoopFocus,globalCaptionMode:"Off"}
    m.seekTimer = {control:""}
    m.seeking = false
    m.seekNewSession = ""
    m.pendingPlayback = false
    m.playing = true
    m.profile = "1"
    m.playItem = {id:"tt123:2:4",type:"series",name:"Episode",stream_id:"ephemeral-opaque",source_addon_id:"addon.stable",source_name:"Provider stable"}
    m.timelineOffset = 600
    m.position = 600
    m.duration = 3600
    m.playbackMode = "transcode"
    m.session = "session-a"
    m.sessionConnection = {base:"https://a.example",access_token:"a",last_profile_id:"1",account_id:"account-a"}
    saveProgress()
    assertThat(m.queue.count() = 1,"progress enqueued")
    assertThat(m.queue[0].body.position = 625,"session offset added once")
    assertThat(m.queue[0].body.duration = 3600,"rolling duration ignored")
    assertThat(m.queue[0].body.source_addon_id = "addon.stable" and m.queue[0].body.source_name = "Provider stable","progress persists bounded stable source preference")
    assertThat(m.queue[0].body.stream_id = invalid and m.queue[0].body.url = invalid,"progress never persists ephemeral stream UUID or URL")
    m.video.position = 40
    saveProgress()
    assertThat(m.queue.count() = 1,"pending progress coalesced")
    assertThat(m.queue[0].body.position = 640,"latest progress retained")
    m.config = {base:"https://b.example",access_token:"b",last_profile_id:"1",account_id:"account-b",capabilities:{}}
    m.status.text = "Preparing playback…"
    stopPlayback()
    assertThat(m.status.text = "","exiting playback clears stale preparation status")
    last = m.queue[m.queue.count()-1]
    assertThat(last.method = "DELETE" and last.base = "https://a.example" and last.access_token = "a" and last.account_epoch = m.accountEpoch,"cleanup uses original account connection")
    assertThat(not m.playing and not m.video.visible,"stop hides player")
    m.queue = []
    m.position = 900
    m.duration = 3600
    findStreams({id:"tt123:2:5",type:"series",name:"Next episode"})
    assertThat(m.position = 0 and m.duration = 0,"new episode resets progress")
    discovery = m.queue[m.queue.count()-1]
    assertThat(discovery.path = "/api/v2/streams" and discovery.body.id = "tt123:2:5","episode ID retained through v2 discovery")
    m.queue = []
    m.playItem = {id:"tt1",type:"movie",stream_id:"s1",name:"Movie"}
    beginPlayback(false)
    beginPlayback(false)
    assertThat(m.queue.count() = 1,"double OK debounced")
    assertThat(m.queue[0].body.force_transcode = false,"initial request conservative")
    assertThat(not m.queue[0].body.DoesExist("profile_id"),"initial playback relies on authenticated session profile only")
    request("GET","/api/meta/movie/tt1",invalid,"meta")
    request("PUT","/api/profiles/1/progress",{position:5},"sideprogress")
    cancelBrowse()
    assertThat(m.queue.count() = 1,"cancel retains progress and drops the unsent v2 admission")
    assertThat(m.queue[0].tag = "sideprogress|" + (m.generation-1).toStr() and Txt(m.pendingStartupId) = "" and not m.pendingPlayback,"cancel removes queued playback; an in-flight v2 admission releases itself in ApiTask")
    m.pendingPlayback = false
    m.queue = []
    beginPlayback(true)
    assertThat(m.queue[0].body.force_transcode,"retry forces transcode")
    m.queue = []
    m.forced = false
    m.pendingPlayback = true
    event = {data:{tag:"playback|" + m.generation.toStr(),ok:false,error:"Preparation failed"},node:{request:{base:"https://a.example",access_token:"a",account_epoch:m.accountEpoch,last_profile_id:"1"}},getData:FakeGetData,getRoSGNode:FakeGetNode}
    response(event)
    assertThat(m.queue.count() = 0,"preparation failure never blindly force-retries same source")
    m.queue = []
    event.data = {tag:"playback|" + (m.generation-1).toStr(),ok:true,data:{id:"orphan"}}
    response(event)
    assertThat(m.queue[0].method = "DELETE" and m.queue[0].base = "https://a.example","stale result cleanup captures original server")
    m.queue = []
    m.pendingPlayback = false
    m.playing = true
    m.playbackMode = "transcode"
    m.session = "seek-session"
    m.position = 600
    m.timelineOffset = 600
    m.video.position = 25
    m.duration = 3600
    m.forced = true
    seekRestart(60)
    entry = m.queue[m.queue.count()-1]
    assertThat(entry.path = "/api/v2/playback" and entry.body.position = 685 and entry.body.managed_only = true,"FF replacement prepares a managed v2 timeline at absolute offset")
    assertThat(entry.body.force_transcode,"seek preserves forced mode")
    assertThat(not entry.body.DoesExist("profile_id"),"seek replacement cannot override authenticated profile")
    assertThat(m.video.visible and m.video.control = "pause" and m.session = "seek-session","seek keeps old visible session paused while replacement prepares")
    assertThat(m.seeking and m.seekTimer.control = "start","one bounded atomic seek is active")
    m.queue = []
    findStreams({id:"tt123:2:5",type:"series",name:"Canonical Show — Pilot",seriesName:"Canonical Show",releaseInfo:"2020–",season:2,episode:5})
    assertThat(m.queue[m.queue.count()-1].body.name = "Canonical Show","matching uses canonical series title")
    assertThat(m.queue[m.queue.count()-1].body.year = 2020 and m.queue[m.queue.count()-1].body.episode = 5,"episode matching includes year and numbers")
    m.queue = []
    m.seeking = false
    m.pausedVOD = false
    m.playing = true
    m.position = 600
    m.timelineOffset = 600
    m.video.position = 25
    m.video.visible = true
    m.video.state = "playing"
    m.session = "paused-session"
    m.pendingPlayback = false
    m.heartbeat.control = "start"
    m.top = {setFocus:NoopFocus,dialog:invalid,findNode:NoNode}
    pauseVOD()
    assertThat(m.pausedVOD and m.playing and m.session = "paused-session","pause preserves active backend session")
    assertThat(m.video.visible and m.video.control = "pause","pause preserves the current frame and native Video content")
    assertThat(m.queue.count() = 0 and m.heartbeat.control <> "stop","pause never saves, deletes, or tears down playback")
    m.video.state = "paused"
    pauseVOD()
    assertThat(not m.pausedVOD and m.video.control = "resume" and m.session = "paused-session","resume continues the exact same Video and session")
    m.queue = []
    m.pendingPlayback = false
    m.position = 3600
    m.duration = 3600
    beginPlayback(false)
    assertThat(m.queue[0].body.position = 0,"completed VOD restarts before duration boundary")
    m.queue = []
    m.pendingPlayback = false
    m.playItem = {type:"live",id:"channel",name:"Live"}
    m.position = 120
    beginPlayback(false)
    assertThat(m.queue[m.queue.count()-1].path = "/api/v2/iptv/live/channel/source","live first resolves its exact opaque source")
    m.queue = []
    m.pendingPlayback = false
    m.liveSourcePending = false
    m.playItem.stream_id = "live-source"
    m.position = 120
    beginPlayback(false)
    assertThat(m.queue[m.queue.count()-1].body.position = 0 and m.queue[m.queue.count()-1].body.stream_id = "live-source","live request never seeks")
    m.queue = []
    m.mode = "episodes"
    m.selected = {id:"tt999",name:"Canonical Series",releaseInfo:"2022"}
    m.items = [{id:"tt999:1:2",title:"Decorated Episode",season:1,episode:2}]
    m.list.itemSelected = 0
    selected()
    assertThat(m.playItem.name = "Canonical Series","actual episode selection keeps canonical name")
    assertThat(m.playItem.displayName = "Canonical Series — Decorated Episode","actual episode selection keeps separate display name")
    assertThat(m.queue[m.queue.count()-1].body.name = "Canonical Series" and m.queue[m.queue.count()-1].body.year = 2022,"actual selection request matches canonical series and year")
    ' Catalog-driven global search: searchable catalogs plus raw Live TV, three requests in flight.
    m.queue = []
    m.top.dialog = invalid
    m.video.visible = false
    m.pausedVOD = false
    m.mode = "searchall"
    m.searchScope = ""
    m.searchCatalog = invalid
    m.searchPanel = {results:invalid,status:"",selected:invalid}
    m.search = "shared query"
    searchEverything()
    assertThat(m.queue.count() = 1 and m.queue[0].path = "/api/catalogs","global search first reads searchable catalogs")
    m.queue = []
    currentGeneration = m.generation
    event = {data:{tag:"searchcatalogs|" + currentGeneration.toStr(),ok:true,data:[{id:"top",addon_id:"a1",addon_name:"Addon",name:"Top",type:"movie",supports_search:true},{id:"shows",addon_id:"a1",addon_name:"Addon",name:"Shows",type:"series",supports_search:true},{id:"plain",addon_id:"a1",name:"Plain",type:"movie",supports_search:false},{id:"tv",addon_id:"a2",addon_name:"Other",name:"TV",type:"tv",supports_search:true}]},node:{request:m.config},getData:FakeGetData,getRoSGNode:FakeGetNode}
    response(event)
    assertThat(m.searchSections.count() = 3 and m.searchSections[2].kind = "live","only searchable movie/series catalogs plus Live TV become sections")
    assertThat(m.queue.count() = 3 and m.searchInFlight = 3,"at most three section requests are in flight")
    for each pending in m.queue
        assertThat(instr(1,pending.path,"search=shared%20query") > 0,"one encoded query shared across sections")
    end for
    assertThat(m.queue[2].path = "/api/v2/iptv/live/channels?limit=80&search=shared%20query","live search uses the raw v2 channel route")
    movies = []
    for i = 1 to 30
        movies.push({id:"movie" + i.toStr(),name:"Movie match"})
    end for
    movies.push({id:"movie1",name:"Duplicate"})
    event.data = {tag:"searchall:0|" + currentGeneration.toStr(),ok:true,data:{metas:movies}}
    response(event)
    assertThat(m.searchSections[0].items.count() = 24 and m.searchSections[0].items[0].type = "movie","section results are typed and bounded")
    event.data = {tag:"searchall:0|" + currentGeneration.toStr(),ok:true,data:{metas:[{id:"late",name:"Late"}]}}
    response(event)
    assertThat(m.searchSections[0].items.count() = 24 and m.searchPending = 2,"a repeated section response cannot append twice")
    event.data = {tag:"searchall:2|" + currentGeneration.toStr(),ok:true,data:{items:[{id:"shared-id",name:"Live match",now:{title:"News"}}]}}
    response(event)
    assertThat(m.searchSections[2].items[0].type = "live" and m.searchSections[2].items[0].releaseInfo = "ON NOW · News","live result appends typed with what is on now")
    event.data = {tag:"searchall:1|" + currentGeneration.toStr(),ok:false,error:"HTTP 503"}
    response(event)
    assertThat(m.searchErrors = 1 and m.searchPending = 0 and instr(1,m.searchPanel.status,"Some sources couldn't load") > 0,"failed section leaves other results and reports partial failure")
    assertThat(m.searchRowKeys.count() = 2 and m.searchRowKeys[1] = 2,"empty and failed sections render no row")
    m.pendingPlayback = false
    m.queue = []
    ' Discover catalog routing renders the full page; see browse-policy.brs and home_catalog_runtime.py.
    m.queue = []
    findStreams({id:"numeric-year-movie",type:"movie",name:"Movie",year:2023,imdb_id:"tt7654321",tmdb_id:"54321"})
    assertThat(LifecycleDiscovery().body.year = 2023,"numeric year works without release info")
    assertThat(LifecycleDiscovery().body.imdb_id = "tt7654321" and LifecycleDiscovery().body.tmdb_id = "54321","stream request includes alternate IDs")
    assertThat(StreamContext({year:2023,releaseInfo:"2020"}).year = 2023,"numeric year takes precedence over release info")
    m.selected = {id:"canonical-parent",name:"Canonical parent",year:2022,releaseInfo:"2021–",imdb_id:"tt9876543",tmdb_id:"4321"}
    m.mode = "episodes"
    m.items = [{id:"opaque-video-A",title:"Episode label",season:3,episode:4}]
    m.list.itemSelected = 0
    m.queue = []
    selected()
    body = LifecycleDiscovery().body
    assertThat(body.id = "opaque-video-A" and body.series_id = "canonical-parent","episode keeps opaque ID and separate parent identity")
    assertThat(body.name = "Canonical parent" and body.season = 3 and body.episode = 4,"opaque episode request retains canonical name and coordinates")
    assertThat(body.year = 2022 and body.imdb_id = "tt9876543" and body.tmdb_id = "4321","episode inherits parent year and alternate IDs")
    m.queue = []
    m.playing = true
    m.playbackLive = false
    m.playbackMode = "transcode"
    m.timelineOffset = 500
    m.video.position = 40
    m.duration = 1800
    saveProgress()
    saved = m.queue[0].body
    assertThat(saved.id = "opaque-video-A" and saved.name = "Canonical parent" and saved.series_id = "canonical-parent","opaque episode progress persists canonical matching context")
    assertThat(saved.season = 3 and saved.episode = 4 and saved.year = 2022 and saved.releaseInfo = "2021–","progress persists coordinates year and release info")
    assertThat(saved.imdb_id = "tt9876543" and saved.tmdb_id = "4321","progress persists alternate IDs")
    m.queue = []
    findStreams(saved)
    assertThat(m.position = 540 and LifecycleDiscovery().body.id = "opaque-video-A" and LifecycleDiscovery().body.episode = 4,"saved opaque episode resumes without ID rewriting")
    suffix = StreamContext({id:"tt123:2:9",type:"series"})
    assertThat(suffix.series_id = "tt123" and suffix.season = 2 and suffix.episode = 9,"canonical numeric suffix fills missing matching context")
    suffix = StreamContext({id:"tt123:2:9",type:"series",series_id:"explicit",season:4,episode:5})
    assertThat(suffix.series_id = "explicit" and suffix.season = 4 and suffix.episode = 5,"explicit validated coordinates win over suffix")
    video = {id:"original-opaque-child",title:"Pilot",season:2,episode:3,series_id:"untrusted-parent",year:2024,releaseInfo:"2024-01-01",imdb_id:"tt9999999",tmdb_id:"999"}
    clean = EpisodeItem({name:"Unknown parent"},video)
    assertThat(clean.id = "original-opaque-child" and clean.season = 2 and clean.episode = 3,"episode original ID and video coordinates survive missing parent identity")
    for each key in ["series_id","year","releaseInfo","imdb_id","tmdb_id"]
        assertThat(not clean.doesExist(key),"missing parent cannot inherit video identity field "+key)
    end for
    clean = EpisodeItem({id:"real-parent",name:"Parent",year:2008,releaseInfo:"2008–",imdb_id:"tt1234567",tmdb_id:"123"},video)
    assertThat(clean.series_id = "real-parent" and clean.year = 2008 and clean.releaseInfo = "2008–" and clean.imdb_id = "tt1234567" and clean.tmdb_id = "123","only parent identity and release evidence can reach episode matching")
    testEpisodeOrderingAndTitles()
    testPlayerIntegration()
    print "ROKU_LIFECYCLE_OK"
end sub

sub testPlayerIntegration()
    m.queue = []
    m.tasks = []
    m.pendingPlayback = false
    m.playing = true
    m.video = {state:"playing",position:25,duration:40,control:"",visible:true,setFocus:NoopFocus,globalCaptionMode:"Off"}
    m.replacementVideo = {state:"",position:0,duration:0,control:"",visible:false,setFocus:NoopFocus,globalCaptionMode:"Off"}
    m.seekTimer = {control:""}
    m.seeking = false
    m.seekNewSession = ""
    m.playItem = {id:"tt123:2:4",type:"series",name:"Episode",stream_id:"source-A",series_id:"tt123",season:2,episode:4}
    m.profile = "1"
    m.session = "session-A"
    m.sessionConnection = m.config
    m.timelineOffset = 600
    m.position = 600
    m.duration = 3600
    m.playbackMode = "transcode"
    m.playbackLive = false
    m.forced = true
    m.hasPlayed = true
    m.prepSpent = 90000
    m.sourcesAt = CreateObject("roDateTime").asSeconds()
    m.activeSourceAt = m.sourcesAt
    m.trackPreferences = invalid
    playerCommand({getData:FakeGetData,data:{kind:"seek",value:900.375}})
    body = m.queue[m.queue.count()-1].body
    assertThat(body.position = 900.375 and body.stream_id = "source-A","overlay absolute seek prepares a replacement at the full-input position")
    assertThat(body.allow_unknown_audio = invalid,"ordinary playback sends no language-gating policy")
    assertThat(m.video.visible and m.video.control = "pause" and m.session = "session-A","old frame and session remain until replacement succeeds")
    m.seekNewSession = "failed-replacement"
    m.seekNewConnection = m.config
    seekReplacementFailed()
    assertThat(not m.seeking and m.video.visible and m.video.control = "resume" and m.session = "session-A","seek failure before preparation resumes old content without revealing sources")
    assertThat(m.queue[m.queue.count()-1].method = "DELETE","failed replacement session is cleaned independently")

    ' A one-decoder television rejects hidden replacement playback. The same prepared
    ' session must then start on the primary Video without deleting the old session first.
    m.queue = []
    m.pendingPlayback = false
    m.video.state = "playing"
    m.video.position = 35
    m.video.content = {url:"old-session.m3u8"}
    m.timelineOffset = 600
    m.position = 635
    m.session = "single-decoder-old"
    m.pausedVOD = true
    playerCommand({getData:FakeGetData,data:{kind:"seek",value:1200.5}})
    prepareSeekReplacement({id:"single-decoder-new",url:"/media/new.m3u8",format:"hls",mode:"transcode",position:1200.5,duration:3600,audio_tracks:[],subtitle_tracks:[],subtitles_supported:true},m.config)
    assertThat(m.seekPhase = "primary","prepared seek immediately uses primary decoder")
    assertThat(m.video.control = "play","primary fallback starts validated seek media on the visible Video")
    assertThat(m.video.content.url = "https://b.example/media/new.m3u8","primary fallback keeps the validated prepared media URL")
    assertThat(m.session = "single-decoder-old","primary fallback retains old backend session until playback succeeds")
    m.video.state = "playing"
    seekPrimaryVideoState()
    assertThat(not m.seeking and m.session = "single-decoder-new" and m.position = 1200.5,"primary fallback commits the exact requested source timeline")
    assertThat(m.pausedVOD and m.video.control = "pause","primary fallback preserves the user's pre-seek pause intent")
    assertThat(m.queue[m.queue.count()-1].method = "DELETE" and instr(1,m.queue[m.queue.count()-1].path,"single-decoder-old") > 0,"old session is deleted only after primary fallback plays")

    ' If primary fallback also fails, reload the still-valid old session/content and
    ' restore its full timeline before giving up.
    m.queue = []
    m.pausedVOD = false
    m.video.state = "playing"
    m.video.position = 10
    m.video.content = {url:"rollback-old.m3u8"}
    m.timelineOffset = 1200.5
    m.position = 1210.5
    playerCommand({getData:FakeGetData,data:{kind:"seek",value:1500}})
    prepareSeekReplacement({id:"rollback-new",url:"/media/rollback-new.m3u8",format:"hls",mode:"transcode",position:1500,duration:3600,audio_tracks:[],subtitle_tracks:[],subtitles_supported:true},m.config)
    m.video.state = "error"
    seekPrimaryVideoState()
    assertThat(m.seekPhase = "rollback" and m.video.control = "play" and m.video.content.url = "rollback-old.m3u8","failed primary fallback reloads old content before declaring failure")
    assertThat(m.session = "single-decoder-new" and m.queue[m.queue.count()-1].method = "DELETE" and instr(1,m.queue[m.queue.count()-1].path,"rollback-new") > 0,"rollback retains old session and deletes only failed seek session")
    m.video.state = "playing"
    seekPrimaryVideoState()
    assertThat(not m.seeking and m.playing and m.video.control = "resume" and m.position = 1210.5,"successful rollback resumes old timeline and user play intent")

    m.queue = []
    m.pendingPlayback = false
    m.video.state = "playing"
    m.video.position = 30
    m.pausedVOD = false
    m.playbackMode = "transcode"
    m.session = "old-before-swap"
    playerCommand({getData:FakeGetData,data:{kind:"seek",value:1000.25}})
    prepareSeekReplacement({id:"replacement-session",url:"/media/replacement.m3u8",format:"hls",mode:"transcode",position:1000.25,duration:3600,audio_tracks:[],subtitle_tracks:[],subtitles_supported:true},m.config)
    assertThat(m.video.visible and m.video.control = "play" and m.session = "old-before-swap","ready seek starts on primary while retaining old backend")
    m.video.state = "playing"
    seekPrimaryVideoState()
    assertThat(m.session = "replacement-session" and m.video.visible,"successful primary seek commits the new session")
    assertThat(m.timelineOffset = 1000.25 and m.queue[m.queue.count()-1].method = "DELETE","seek adopts absolute timeline then cleans old session")
    m.queue = []
    m.pendingPlayback = false
    m.playing = true
    m.session = "session-B"
    m.playbackMode = "direct"
    m.video.state = "playing"
    playerCommand({getData:FakeGetData,data:{kind:"seek",value:980}})
    assertThat(m.video.seek = 980 and m.queue.count() = 0,"direct media seeks natively with no session restart")
    playerCommand({getData:FakeGetData,data:{kind:"pause"}})
    assertThat(m.video.control = "pause","direct media pause remains native")
    m.video.state = "paused"
    playerCommand({getData:FakeGetData,data:{kind:"pause"}})
    assertThat(m.video.control = "resume","direct media resumes natively")
    m.queue = []
    m.pendingPlayback = false
    m.playing = true
    m.playbackMode = "transcode"
    m.video.state = "playing"
    m.video.position = 25
    m.timelineOffset = 600
    m.position = 600
    m.trackKind = "audio"
    choosePlayerTrack({input_index:2})
    body = m.queue[m.queue.count()-1].body
    assertThat(body.audio_track_index = 2 and body.position = 625,"audio switch preserves explicit input index and full position")
    assertThat(body.allow_unknown_audio = invalid,"audio selection is not gated by language consent")
    seekReplacementFailed()
    m.trackPreferences.subtitle_track_index = 5
    m.subtitlesSupported = true
    m.selectedSubtitle = {input_index:5,output_index:0}
    m.captionRestore = m.video.globalCaptionMode
    PrepareNativeCaptions(m.video,true)
    assertThat(m.video.globalCaptionMode = "On","caption mode enabled before content starts and native discovery")
    m.video.availableSubtitleTracks = [{TrackName:"native-vtt-track"}]
    m.playing = true
    applyPlayerSubtitles()
    assertThat(m.video.subtitleTrack = "native-vtt-track" and m.video.globalCaptionMode = "On","subtitle control uses native identifier, never source input index")
    m.top.dialog = {close:false}
    queued = m.queue.count()
    assertThat(not onKeyEvent("right",true) and m.queue.count() = queued,"modal track dialog arrows never bubble into video seek")
    m.top.dialog = invalid
    m.queue = []
    m.pendingPlayback = false
    m.playing = true
    m.session = "chosen-audio"
    m.video.state = "playing"
    m.video.position = 40
    m.timelineOffset = 625
    pauseVOD()
    assertThat(m.pausedVOD and m.session = "chosen-audio" and m.trackPreferences.audio_track_index = 2,"pause keeps session and explicit audio choice")
    m.video.state = "paused"
    playerCommand({getData:FakeGetData,data:{kind:"pause"}})
    assertThat(not m.pausedVOD and m.video.control = "resume" and m.queue.count() = 0,"resume is native and does not prepare a new source")
    m.video.state = "playing"
    playerCommand({getData:FakeGetData,data:{kind:"seek",value:950.125}})
    body = m.queue[m.queue.count()-1].body
    assertThat(body.audio_track_index = 2 and body.position = 950.125,"same-source seek retains explicit audio and exact absolute target")
    assertThat(m.playItem.stream_id = "source-A","seek never chooses an alternative source")
end sub

sub testEpisodeOrderingAndTitles()
    videos = [
        {id:"opaque-seven",season:1,episode:7,title:"Seven"}
        {id:"opaque-six",season:1,episode:6,title:"Six"}
        {id:"opaque-pilot",season:1,episode:1,title:"",name:"Pilot"}
        {id:"unknown-first",season:1,episode:"bad",name:"Unknown"}
        {id:"opaque-six-tie",season:1,episode:6,name:"Another six"}
        {id:"season-two",season:2,episode:1,name:"Two"}
        {id:"large-coordinate",season:100000,episode:100000,name:"Large"}
        {id:"unknown-second",season:1,episode:1.5,name:"Unknown"}
    ]
    sorted = OrderedEpisodes(videos)
    expected = ["opaque-pilot","opaque-six","opaque-six-tie","opaque-seven","season-two","large-coordinate","unknown-first","unknown-second"]
    for i = 0 to expected.count()-1
        assertThat(sorted[i].id = expected[i],"episode order at " + i.toStr() + ": " + sorted[i].id + " expected " + expected[i])
    end for
    assertThat(videos[0].id = "opaque-seven" and videos[2].title = "" and videos[2].name = "Pilot","ordering never mutates original metadata or IDs")
    assertThat(EpisodeTitle({title:"   ",name:"Pilot"}) = "Pilot","blank title falls back to name")
    assertThat(EpisodeTitle({title:"Actual title",name:"Other name"}) = "Actual title","nonblank title takes precedence")
    m.selected = invalid
    m.playing = false
    m.pendingPlayback = false
    ' Episode cards render through the page layout; selection keeps canonical parent matching.
    m.selected = {id:"canonical-bb",type:"series",name:"Breaking Bad",year:2008}
    m.mode = "episodes"
    m.items = sorted
    m.queue = []
    m.list.itemSelected = 0
    selected()
    body = LifecycleDiscovery().body
    assertThat(body.id = "opaque-pilot" and body.name = "Breaking Bad" and body.series_id = "canonical-bb" and body.year = 2008,"Pilot display fallback preserves opaque ID and canonical parent matching")
    assertThat(body.season = 1 and body.episode = 1 and m.playItem.displayName = "Breaking Bad — Pilot","selected episode coordinates and human title remain correct")
    assertThat(videos[2].name = "Pilot" and videos[2].title = "","selection never decorates or erases source metadata")
    many = []
    for i = 0 to 2000
        many.push({id:i.toStr()})
    end for
    bounded = OrderedEpisodes(many)
    assertThat(bounded.count() = 2000 and bounded[0].id = "0" and bounded[1999].id = "1999","unknown coordinate order stays stable within 2000-episode cap")
end sub

function FakeGetData() as object
    return m.data
end function

function FakeGetNode() as object
    return m.node
end function

sub NoopFocus(value as boolean)
end sub

sub CaptureFocus(value as boolean)
    if value then m.focusCounter.value++
end sub

sub assertThat(condition as boolean, name as string)
    if not condition
        print "TEST_FAIL "; name
        stop
    end if
end sub
function NoNode(id as string) as dynamic
    return invalid
end function
function LifecycleDiscovery() as dynamic
    for i = m.queue.count()-1 to 0 step -1
        if m.queue[i].path = "/api/v2/streams" then return m.queue[i]
    end for
    return invalid
end function
