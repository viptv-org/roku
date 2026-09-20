' TEST ONLY. Inject into a disposable copy. No registry, network or media.
sub uxFixtureChanged()
    m.dispatch.control = "stop"
    m.config = {base:"",access_token:"",last_profile_id:"fixture",account_id:"fixture-account",capabilities:{}}
    m.profile = "fixture"
    m.identity.text = "Alex"
    updateProfileNav({name:"Alex",avatar_url:"https://api.dicebear.com/10.x/critters/png?seed=fixture-alex&size=256"})
    m.sidebar.jumpToItem = 1
    names = ["The Last Signal","Northline","After Hours","Wild Coast","Sunward","Deep Current"]
    art = ["signal","northline","afterhours","wildcoast","sunward","deepcurrent"]
    values = []
    for i = 0 to 11
        values.push({id:"fixture." + i.toStr(),name:names[i mod 6],type:"movie",poster:"pkg:/images/" + art[i mod 6] + ".jpg",background:"pkg:/images/fixture-" + art[i mod 6] + "-wide.jpg",description:"A lone transmission draws a rescue crew beyond the edge of known space.",releaseInfo:"2025"})
    end for
    kind = m.top.fixture
    if kind = "home-no-backdrop"
        for each item in values
            item.background = ""
        end for
    end if
    if kind = "anime-sources" or kind = "anime-progress-contract" or kind = "anime-episodes"
        english = {id:"english",addon_id:"1",name:"Provider · 1080p",title:"Re.Zero.S04E01.1080p.WEB-DL.DUAL.AUDIO.mkv"+chr(10)+"💾 1.3 GB   👥 28"+chr(10)+"🔊 🇺🇸 🇯🇵"+chr(10)+"H.264 · AAC 2.0"+chr(10)+"⚡ Cached",source_fingerprint:"match"}
        japanese = {id:"japanese",addon_id:"1",name:"Provider · 1080p",title:"ReZero Japanese audio"+chr(10)+"English subtitles",source_fingerprint:"other"}
        multi = {id:"multi",addon_id:"1",name:"Provider · 720p",title:"ReZero Multi Audio",source_fingerprint:"multi"}
        uxCheck(SourceAudioHint(english)=0 and SourceAudioHint(multi)=1 and SourceAudioHint(japanese)=2,"English audio outranks generic multi and subtitle-only English")
        uxCheck(instr(1,ReadableSourceText(english.title),"English")>0 and instr(1,ReadableSourceText(english.title),"🇺🇸")=0,"flags become readable language labels")
        m.playItem = {id:"tt123:4:1",type:"series",name:"ReZero",position:30,source_addon_id:"1",source_name:"Provider · 1080p",source_fingerprint:"match"}
        rows("Choose a source",[],"streams","")
        m.streams = [japanese,multi,english]
        uiUpdateSources(m.streams,true)
        uxCheck(m.items[0].id="english","English source moves to the top")
        uxCheck(instr(1,m.sourceList.content.getChild(0).sourceBadges,"LAST PLAYED")>0,"last source has a visible indicator")
        if kind <> "anime-sources"
            m.selected = {id:"tt123",type:"series",name:"ReZero"}
            m.episodes = [{id:"tt123:4:1",season:4,episode:1,name:"The beginning",thumbnail:"pkg:/images/fixture-signal-wide.jpg",released:"2020-01-01T00:00:00Z"},{id:"tt123:4:2",season:4,episode:2,name:"A new path",thumbnail:"",released:"2020-01-02T00:00:00Z"},{id:"tt123:5:1",season:5,episode:1,name:"Next chapter",released:"2020-01-03T00:00:00Z"}]
            history = [{id:"tt123:4:1",type:"series",position:990,duration:1000,updated_at:1},{id:"tt123:4:2",type:"series",position:300,duration:1000,updated_at:2,source_addon_id:"1",source_name:"Provider",source_fingerprint:"match"}]
            applyEpisodeProgress({ok:true,data:history})
            uxCheck(m.episodeSeason="4" and m.episodeList.jumpToItem=1,"series returns to the in-progress season and episode")
            uxCheck(m.items[0].watched and m.items[1].position=300,"watched and partial progress are distinct")
            episode = EpisodePresentationItem(m.selected,m.items[1])
            uxCheck(episode.source_fingerprint="match" and StableResumePreference(episode)<>invalid,"episode resume retains the selected source")
            if kind = "anime-progress-contract"
                history[1].position = 990
                applyEpisodeProgress({ok:true,data:history})
                uxCheck(m.episodeSeason="5" and m.items[0].episode=1,"completed episode advances to the next released season")
                print "ANIME_PROGRESS_OK"
            end if
        else
            print "ANIME_SOURCES_OK"
        end if
    else if kind = "search-playback-contract"
        m.mediaType = "live"
        searchOpen("cart")
        m.searchDelay.control = "stop"
        m.searchSections = [{name:"Live TV",kind:"live",items:[{id:"cartoon",name:"Cartoon Network",type:"live"}],done:true}]
        m.searchPending = 0
        m.searchErrors = 0
        searchRender()
        m.searchPanel.callFunc("focusResults",[0,0])
        saveView()
        ' The successful playback response invokes this same screen teardown.
        uiHidePageExtras()
        uxCheck(not m.searchPanel.visible,"search cannot cover playback")
        uxCheck(m.searchDelay.control = "stop","hidden search cannot start a delayed query")
        restoreView()
        uxCheck(m.searchPanel.visible and m.search = "cart","return restores live query")
        uxCheck(m.searchPanel.results.getChild(0).getChild(0).title = "Cartoon Network","return restores live carousel")
        print "SEARCH_PLAYBACK_RETURN_OK"
    else if kind = "discover-options-contract"
        languages = []
        for i = 0 to 185
            languages.push("Language " + i.toStr())
        end for
        catalogs = [{id:"lang",type:"movie",name:"By Language",addon_id:"1",addon_name:"Fixture",genres:languages,extra:[{name:"genre",required:true,default:"Language 100",options:languages}]},{id:"anime-search",type:"anime.series",name:"Anime search",addon_id:"1",extra:[{name:"search",required:true,options:[]}]},{id:"calendar",type:"series",name:"Calendar",addon_id:"1",extra:[{name:"calendarVideosIds",required:true,options:[]}]}]
        m.discoverActive = true
        m.discoverType = "movie"
        m.offsetHistory = []
        discoverUseCatalogs(catalogs)
        uxCheck(m.discoverCatalogs.count()=3,"Discover retains search and custom-type catalogs")
        uxCheck(m.discoverGenre="Language 100","required advertised default is retained")
        uxCheck(m.discoverFilterItems[2].name="Language 100","language picker shows selected value")
        m.discoverType = "anime.series"
        discoverChooseDefaultCatalog()
        browse(m.discoverType,0)
        uxCheck(m.discoverFilterItems[2].action="dsearch","search-only catalog has a real search control")
        uxCheck(m.emptyState.visible,"required search waits for input rather than requesting an invalid catalog")
        m.search = "Naruto"
        browse(m.discoverType,0)
        uxCheck(instr(1,m.queue[m.queue.count()-1].path,"search=Naruto")>0,"catalog search stays in Discover")
        catalogResult = {ok:true,tag:"browse|" + m.generation.toStr(),data:{metas:[{id:"tt0409591",type:"series",name:"Naruto"}],has_more:false}}
        handleResponse({data:catalogResult,getData:uxResult,node:{request:{account_epoch:m.accountEpoch}},getRoSGNode:uxNode})
        uxCheck(m.heading.text="Discover · Anime" and m.items[0].name="Naruto","custom-type response renders without a missing type label")
        m.discoverType = "series"
        discoverChooseDefaultCatalog()
        uxCheck(DiscoverMissingOption(m.catalog,"","",m.discoverExtras)<>"","calendar requires its advertised input")
        showMetadata({meta:{id:"tvdbc:fixture",type:"movie",name:"Movie collection",videos:[{id:"tt0001",title:"First film",overview:"First summary"},{id:"tt0002",title:"Second film"}]}})
        uxCheck(m.mode="browse" and m.items.count()=2,"collection opens its member films even when aggregator omits its optional flag")
        uxCheck(m.items[0].id="tt0001" and m.items[0].type="movie","collection preserves playable member identities")
        print "DISCOVER_OPTIONS_OK"
    else if kind = "input-contract"
        m.queue = []
        accountStartProfileSetup(invalid)
        uxCheck(m.profileEditor.visible and not m.textEntry.visible,"profile opens before keyboard")
        uxCheck(m.queue.count() = 0,"opening profile does not create it")
        accountSubmitProfileName("  Test Kid  ")
        uxCheck(m.profileDraft.name = "Test Kid","name is trimmed and retained")
        m.profileDraft.avatar_style = "pixelbot"
        m.profileDraft.avatar_choice = 48
        accountFinishProfileSetup("pixelbot")
        uxCheck(m.queue.count() = 1,"one explicit profile submission")
        uxCheck(m.queue[0].body.avatar_choice = 48,"exact avatar sent to API")
        accountResponse("auth:newprofile",{ok:false,status:503},{account_epoch:m.accountEpoch})
        uxCheck(m.profileDraft.name = "Test Kid" and m.profileEditor.saving = false,"failed save retains editable draft")
        m.profileEditor.visible = false
        m.mediaType = "all"
        m.catalog = invalid
        searchOpen("")
        uxCheck(m.searchPanel.visible and m.search = "","search opens empty without request")
        m.searchPanel.query = "first"
        searchChanged()
        generation = m.generation
        m.searchPanel.query = "second"
        searchChanged()
        uxCheck(m.generation > generation and m.search = "second","new query invalidates previous requests")
        m.searchDelay.control = "stop"
        print "INPUT_FLOW_OK"
    else if left(kind,4) = "home"
        m.homeExpanded = kind <> "home-shelf"
        m.homeKeyValue = "|fixture-account|fixture"
        m.homeData = [[],[],[],[],[],[],[]]
        for i = 0 to 5
            item = {}
            item.append(values[i])
            item.position = 450 + i * 120
            item.duration = 3600
            m.homeData[0].push(item)
            movie = {}
            movie.append(values[5-i])
            movie.type = "movie"
            m.homeData[1].push(movie)
            series = {}
            series.append(values[i+3])
            series.type = "series"
            m.homeData[2].push(series)
            m.homeData[4].push(values[5-i])
        end for
        m.homeData[3] = [{id:"live.coast",name:"Wild Coast Live",type:"live",poster:"pkg:/images/wildcoast.jpg",description:"Nature, live now."},{id:"live.news",name:"World Today",type:"live",poster:"pkg:/images/northline.jpg",description:"News, live now."}]
        m.homeStates = ["","","","","","",""]
        m.homeFailed = [false,false,false,false,false,false,false]
        m.homeDone = {progress:true,favorites:true,movie:true,series:true,live:true,livefavorites:true,recent:true}
        m.homeTime = CreateObject("roDateTime").asSeconds()
        if kind = "home-no-continue" or kind = "home-no-continue-contract" then m.homeData[0] = []
        showHome()
        if kind = "home-return-contract"
            m.homeDone.delete("recent")
            homeResponse("recent",{ok:true,data:{channels:[{id:"cn",type:"live",name:"Cartoon Network"}]}})
            m.homePosition = [6,0]
            m.homeExpanded = false
            homeRestore()
            saveView()
            rows("Other page",[],"settings","")
            selectItem({action:"home"})
            uxCheck(not m.homeExpanded or m.homePosition[0]=uiHomeHeroRow(),"Home return cannot combine lower-row cursor with expanded hero")
            uxCheck(m.homeRowKeys[1]=6,"recent live belongs immediately after Continue Watching")
            print "HOME_RETURN_OK"
        end if
        if kind = "home-no-continue-contract"
            uxCheck(uiHomeHeroRow() = 1,"first available row owns hero without history")
            uiHomeKey("down")
            uxCheck(m.homeExpanded and m.homeHeroPanel.visible,"fallback row retains hero")
            print "HOME_FALLBACK_OK"
        end if
        if kind = "home-response-order-contract"
            savedData = m.homeData
            savedDone = m.homeDone
            savedPosition = m.homePosition
            m.homeData = [[],[],[],[{id:"first-live",type:"live"}],[],[],[]]
            m.homeDone = {live:true}
            m.homeAutoPick = true
            homeDefaultShelf()
            uxCheck(m.homePosition[0] = 3 and m.homeAutoPick,"fast live response keeps initial selection provisional")
            m.homeData[1] = [values[0]]
            m.homeDone.movie = true
            homeDefaultShelf()
            uxCheck(m.homePosition[0] = 1 and m.homeAutoPick,"earlier movie row replaces provisional live hero")
            m.homeDone.progress = true
            m.homeDone.recent = true
            homeDefaultShelf()
            uxCheck(m.homePosition[0] = 1 and not m.homeAutoPick,"empty history settles on first movie row")
            m.homePosition = [3,0]
            homeDefaultShelf()
            uxCheck(m.homePosition[0] = 3,"settled or user selection stays unchanged")
            m.homeData = savedData
            m.homeDone = savedDone
            m.homePosition = savedPosition
            print "HOME_RESPONSE_ORDER_OK"
        end if
        if kind = "home-metadata-contract"
            current = homeCurrent()
            current.description = ""
            path = "/api/meta/movie/" + Enc(PresentationMetadataId(current))
            node = m.homeRoot.getChild(0).getChild(0)
            if m.uiArtworkInflight = invalid then m.uiArtworkInflight = {}
            m.uiArtworkInflight["uicard:fixture"] = {tag:"uicard:fixture",path:path,node:node,id:current.id,mediaType:"movie"}
            uiCardArtworkResponse("uicard:fixture",{ok:true,data:{meta:{id:current.id,description:"Restored synopsis from metadata.",background:current.background}}})
            uxCheck(m.homeHeroPanel.model.description = "Restored synopsis from metadata.","artwork enrichment retains hero description")
            print "HERO_METADATA_OK"
        end if
        if kind = "home-pin-contract"
            uiHomeKey("down")
            uxCheck(m.homeExpanded and m.homeRows.hasFocus(),"continue row keeps full hero without stealing focus")
            uxCheck(m.homeShelves.translation[1] = 466,"continue row retains screen position")
            m.homeExpanded = false
            uiHomeLayout()
            uxCheck(not m.homeHeroPanel.visible and m.homeShelves.translation[1] = 100,"other shelves hide hero and use full screen")
            print "HOME_PIN_OK"
        end if
    else if kind = "discover" or kind = "discover-long"
        if kind = "discover-long" then values[0].name = "The Last Signal: Beyond the Edge of the Known Universe — A Very Long Title"
        m.discoverActive = true
        m.discoverType = "movie"
        m.mediaType = "movie"
        m.discoverGenre = "Drama"
        m.discoverCatalogs = [{id:"trending",addon_id:"fixture.addon",name:"Trending",type:"movie",genres:["Drama","Comedy","Family"],supports_search:true}]
        for i = 1 to 24
            m.discoverCatalogs.push({id:"catalog-" + i.toStr(),addon_id:"fixture.addon",name:"Curated collection " + i.toStr(),type:"movie",genres:["Drama","Action","Adventure","Comedy","Crime","Documentary","Family","Fantasy","History","Horror","Music","Mystery","Romance","Science Fiction","Thriller","War","Western"],supports_search:true})
        end for
        if kind = "discover-long" then m.discoverCatalogs[0].name = "An Unabridged Catalog Name from the Addon's Own Configuration"
        m.catalog = m.discoverCatalogs[0]
        m.offset = 0
        m.offsetHistory = []
        discoverBuildFilters()
        rows("Discover · Movies",values,"browse","Trending · Drama")
    else if kind = "profile-form" or kind = "avatar-picker" or kind = "profile-keyboard"
        accountStartProfileSetup(invalid)
        if kind = "profile-keyboard" then keyboard("accountprofilename","Name this profile","")
    else if kind = "search" or kind = "search-empty"
        m.mediaType = "all"
        searchOpen("")
        if kind = "search"
            m.searchSections = [{name:"Cinemeta · Movies",kind:"movie",items:values,done:true}]
            m.searchPending = 0
            m.searchErrors = 0
            searchRender()
        end if
    else if kind = "browse"
        m.mediaType = "movie"
        m.offset = 0
        m.search = ""
        if kind = "search" then m.search = "journey"
        rows("Movies",values,"browse","Select a title to explore sources")
    else if kind = "profiles"
        m.canCreateProfile = true
        accountShowProfileGrid([{id:"1",name:"Alex",avatar_url:"https://api.dicebear.com/10.x/critters/png?seed=fixture-alex&size=256",setup_complete:true,presentation_complete:true},{id:"2",name:"Kids",avatar_url:"https://api.dicebear.com/10.x/pixel-art/png?seed=fixture-kids&size=256",setup_complete:true,presentation_complete:true},{name:"Add profile",action:"newprofile",avatar_url:"",setup_complete:true,presentation_complete:true}])
    else if kind = "addons"
        addonResponse("accountaddons",{ok:true,data:[{id:"fixture",name:"Cinemeta",enabled:true}]})
    else if kind = "error"
        rows("Discover",[{name:"Try again",action:"retry"}],"discovererror","Please try again in a moment.")
    else if kind = "auth-loading"
        accountShowLoading()
    else if kind = "pairing-manual"
        accountShowQr({qr_uri:"",verification_uri:"viptv.syek.tech/device",user_code:"ABCD EFGH"})
    else if kind = "pairing-retry"
        m.profile = ""
        accountRetry("That code expired. Request a new one to continue.")
    else if kind = "choice" or kind = "choice-long"
        m.configLoaded = true
        showSettings()
        uiOpenChoice("fixture","Choose a catalog",[{name:"Trending movies"},{name:"Popular series"},{name:"Recently added"}])
        if kind = "choice-long"
            choices = []
            for i = 1 to 12
                choices.push({name:"Catalog " + i.toStr()})
            end for
            uiOpenChoice("fixture","Choose a catalog",choices)
        end if
    else if kind = "pairing"
        m.profile = ""
        rows("Sign in to VIPTV",[],"pairing","")
        accountShowLoading()
        m.pairVisual = {data:{verification_uri:"viptv.syek.tech/device",user_code:"ABCD EFGH"},epoch:m.accountEpoch,uri:"pkg:/images/fixture-qr.png"}
        m.pairQr.uri = "pkg:/images/fixture-qr.png"
        accountQrLoaded()
    else if kind = "detail" or kind = "detail-long" or kind = "detail-empty"
        m.selected = values[0]
        if kind = "detail-long" then m.selected.description = "A lone transmission draws a rescue crew beyond the edge of known space. When their search uncovers a forgotten colony, the crew must choose between completing their mission and helping the people who have waited generations for rescue. An unexpected arrival challenges everything they believe about the signal and its origin. As time runs out, each member must confront the cost of returning home."
        if kind = "detail-empty" then m.selected.description = ""
        rows(m.selected.name,[{name:"Choose source",action:"play"},{name:"+ My List",action:"favorite"},{name:"More info",action:"moreinfo"}],"detail","")
        showDetail(m.selected)
    else if kind = "episodes" or kind = "episode-controls"
        m.selected = values[0]
        m.selected.type = "series"
        m.episodeSeason = "1"
        m.episodes = []
        for season = 1 to 8
            for episode = 1 to 5
                m.episodes.push({id:"fixture:" + season.toStr() + ":" + episode.toStr(),season:season,episode:episode,name:["The transmission","Beyond the signal","The long way home","Under distant skies","A world apart"][episode-1],thumbnail:"pkg:/images/fixture-" + art[(episode-1) mod 6] + "-wide.jpg",overview:"A mysterious signal brings the crew closer to an unexpected discovery, while a difficult decision changes their journey."})
            end for
        end for
        showEpisodes(0)
        if kind = "episode-controls"
            uxCheck(uiPresentationKey("up") and m.seasonList.hasFocus(),"Up from first episode row reaches season controls")
            uxCheck(uiPresentationKey("down") and m.episodeList.hasFocus(),"Down returns to episodes")
            m.episodeList.jumpToItem = 0
            uxCheck(uiPresentationKey("down"),"single visible row consumes Down")
            uxCheck(m.episodeList.jumpToItem=4,"Down reaches the next episode row")
            m.episodeList.jumpToItem = 0
            m.episodeList.jumpToItem = 1
            uxCheck(not uiPresentationKey("left"),"Left in right grid column stays native")
            m.episodeSeason = "8"
            showEpisodes(0)
            uxCheck(m.items.count()=5 and Txt(m.items[0].season)="8","season selection shows only requested episodes")
            uxCheck(m.seasonList.content.getChildCount()=3,"season controls remain compact for many seasons")
            print "EPISODE_CONTROLS_OK"
        end if
    else if kind = "settings" or kind = "about"
        m.sidebar.jumpToItem = 6
        m.configLoaded = true
        m.config.base = "https://viptv.syek.tech"
        m.config.locked = true
        showSettings()
        if kind = "about" then m.standardList.jumpToItem = 2
    else if kind = "source-arrival-focus"
        m.playItem = values[0]
        m.discoveryDone = false
        m.streams = [{id:"a",name:"One",type:"movie"},{id:"b",name:"Two",type:"movie"},{id:"c",name:"Three",type:"movie"}]
        rows("Choose a source",m.streams,"streams","")
        m.sourceList.jumpToItem = 1
        m.streams.push({id:"d",name:"Four",type:"movie"})
        rows("Choose a source",m.streams,"streams","",false)
        ' Remote input after a source batch, before the old delayed restore fires.
        m.sourceList.jumpToItem = 2
        settleList()
        uxCheck(m.sourceList.itemFocused = 2,"source arrival must not undo the user's next focus move")
        root = m.sourceList.content
        m.sourceFilter = "addon:2"
        m.streams = [{id:"a",source:"addon:1",source_name:"Archive",name:"A"},{id:"b",source:"addon:2",source_name:"Cinema",name:"B"}]
        uiUpdateSources(m.streams,true)
        uxCheck(m.items.count()=1 and m.items[0].id="b","provider filter uses producer identity")
        m.sourceFilters.setFocus(true)
        m.streams.push({id:"c",source:"addon:1",source_name:"Archive",name:"C"})
        root = m.sourceList.content
        uiUpdateSources(m.streams)
        uxCheck(root.isSameNode(m.sourceList.content),"unrelated arrivals do not replace list nodes")
        uxCheck(m.sourceFilters.hasFocus(),"new sources cannot steal provider control focus")
        m.streams.push({id:"d",source:"addon:2",source_name:"Cinema",name:"D"})
        uiUpdateSources(m.streams)
        uxCheck(m.items.count()=2 and m.items[1].id="d","matching arrivals append inside the filter")
        m.sourceFilter = "missing"
        uiUpdateSources(m.streams,true)
        uxCheck(m.items.count()=0 and m.sourceFilters.hasFocus(),"empty filter remains escapable")
        print "SOURCE_ARRIVAL_FOCUS_OK"
    else if left(kind,7) = "sources"
        source = {id:"opaque-fixture-A",name:"An Extremely Long Provider Name With More Decoration 1080p HEVC",title:"The.Last.Signal.2025.1080p.WEB-DL.English.Italian",description:"Complete release notes and provider details remain readable here.",reported_languages:["English","Italian"],source:"fixture",type:"movie"}
        source2 = {id:"opaque-fixture-B",name:"Cinema Archive" + chr(10) + "2160p",title:"The.Last.Signal.2160p.HDR.English",description:"Alternative fictional source with English metadata.",reported_languages:["English"],source:"fixture",type:"movie"}
        m.playItem = values[0]
        m.playItem.position = 450
        m.playItem.duration = 3600
        if kind = "sources-resume"
            m.playItem = {id:"tt1234567",name:"Northline",seriesName:"Northline",type:"series",season:2,episode:3,episodeTitle:"Beyond the horizon",stream_id:"tt1234567:2:3",position:564,duration:2640}
        end if
        source.title += chr(10) + "Original provider text, not inferred metadata" + chr(10) + "Additional original release information"
        m.streams = [source,source2]
        if kind = "sources-three"
            source3 = {id:"opaque-fixture-C",name:"Provider archive" + chr(10) + "1080p · Original label" + chr(10) + "Third provider line",title:"Complete original release details remain available.",source:"fixture",type:"movie"}
            m.streams.push(source3)
        end if
        if kind = "sources-loading" then m.streams = []
        m.discoveryDone = kind <> "sources-progress" and kind <> "sources-loading"
        rows("Choose a source",m.streams,"streams","")
        uiSourceHeader()
    else if kind = "live" or kind = "guide"
        channels = [{id:"channel:coast",name:"Wild Coast Live",type:"live",category:"Nature"},{id:"channel:news",name:"World Today",type:"live",category:"News"},{id:"channel:films",name:"Cinema Classics",type:"live",category:"Movies"},{id:"channel:travel",name:"Journeys",type:"live",category:"Travel"}]
        m.mediaType = "live"
        m.liveCategoryName = "All channels"
        m.offset = 0
        result = {ok:true,tag:"browse|" + m.generation.toStr(),data:{channels:channels,total:4}}
        handleResponse({data:result,getData:uxResult,node:{request:{account_epoch:m.accountEpoch}},getRoSGNode:uxNode})
        if kind = "live"
            timer = CreateObject("roSGNode","Timer")
            timer.duration = 0.7
            timer.repeat = false
            timer.observeField("fire","uxLiveData")
            m.top.appendChild(timer)
            timer.control = "start"
        end if
        if kind = "guide"
            m.selected = channels[0]
            now = CreateObject("roDateTime").asSeconds()
            result = {ok:true,tag:"guide|" + m.generation.toStr(),data:{programs:[{title:"Along the Wild Coast",description:"Tidal pools and wildlife along a spectacular coastline.",start:now-900,end:now+900},{title:"Hidden Coves",description:"Discover the quieter corners of the coast.",start:now+900,end:now+2700},{title:"Ocean After Dark",description:"Life beneath the waves as the sun sets.",start:now+2700,end:now+4500}]}}
            handleResponse({data:result,getData:uxResult,node:{request:{account_epoch:m.accountEpoch}},getRoSGNode:uxNode})
        end if
    else if kind = "player" or kind = "player-bright" or kind = "player-loading" or kind = "player-live"
        accountEndLoading()
        homeVisible(false)
        for each id in ["heading","status","list","art","detailTitle","detailInfo","description"]
            m[id].visible = false
        end for
        frame = CreateObject("roSGNode","Poster")
        frame.width = 1280
        frame.height = 720
        frame.uri = "pkg:/images/fixture-signal-wide.jpg"
        if kind = "player-bright"
            frame = CreateObject("roSGNode","Rectangle")
            frame.width = 1280
            frame.height = 720
            frame.color = "#FFFFFFFF"
        end if
        for i = 0 to m.top.getChildCount()-1
            if m.top.getChild(i).isSameNode(m.playerBackdrop)
                m.top.insertChild(frame,i)
                exit for
            end if
        end for
        m.playerBackdrop.visible = false
        m.playerOverlay.visible = true
        state = "playing"
        if kind = "player-loading" then state = "buffering"
        m.playerOverlay.model = {session:"fixture",state:state,title:"The Last Signal",context:"Season 2 · Episode 3 · Beyond the horizon",position:1250,duration:3600,live:kind = "player-live",paused:false}
        m.playerOverlay.opened = true
        m.playerOverlay.setFocus(true)
        m.playerOverlay.model = m.playerOverlay.model
    end if
end sub
sub uxLiveData()
    item = focusedLiveChannel()
    if item = invalid then return
    now = CreateObject("roDateTime").asSeconds()
    m.liveEpgOwner = {id:item.id,generation:m.generation}
    m.liveEpgBusy = "fixture"
    liveEpgResponse("fixture",{ok:true,data:{programs:[{title:"Along the Wild Coast",start:now-900,end:now+900},{title:"Hidden Coves",start:now+900,end:now+2700}]}},m.generation)
end sub
function uxResult() as object
    return m.data
end function
function uxNode() as object
    return m.node
end function

sub uxCheck(value as boolean,label as string)
    if not value
        print "INPUT_FLOW_FAIL: " + label
        stop
    end if
end sub
