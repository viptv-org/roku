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
