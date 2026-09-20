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
