sub homeResponse(kind as string, result as object)
    if m.mode <> "home" or m.homeData = invalid then return
    if m.homeKeyValue <> m.config.base + "|" + Txt(m.config.account_id) + "|" + m.profile then return
    if kind = "catalogs"
        for each media in ["movie","series"]
            if not m.homeDone.doesExist(media)
                chosen = invalid
                if result.ok
                    for each catalog in Bounded(result.data,100)
                        if catalog.type = media
                            chosen = catalog
                            exit for
                        end if
                    end for
                end if
                if chosen <> invalid
                    request("GET","/api/discover?type=" + media + "&addon_id=" + Enc(Txt(chosen.addon_id)) + "&catalog=" + Enc(Txt(chosen.id)) + "&skip=0",invalid,"home:" + media)
                else
                    homeResponse(media,{ok:false})
                end if
            end if
        end for
        return
    end if
    slots = {progress:0,movie:1,series:2,live:3,favorites:4,livefavorites:5,recent:6}
    if not slots.doesExist(kind) then return
    if m.homeDone.doesExist(kind) then return
    index = slots[kind]
    retainedItem = invalid
    if m.homePosition[0] = index then retainedItem = homeCurrent()
    m.homeDone[kind] = true
    m.homeStates[index] = "Nothing here yet."
    if m.homeFailed = invalid then m.homeFailed = [false,false,false,false]
    m.homeFailed[index] = not result.ok
    if result.ok
        incoming = result.data
        if kind = "favorites"
            if GetInterface(incoming,"ifAssociativeArray") <> invalid then incoming = incoming.items
            m.liveFavoriteItems = Bounded(incoming,40)
            request("GET","/api/live?view=us&collection=favorites&limit=24",invalid,"home:livefavorites")
        end if
        if kind = "progress"
            if GetInterface(incoming,"ifAssociativeArray") <> invalid then incoming = incoming.items
            incoming = ContinueWatchingItems(incoming)
        end if
        if kind = "recent" or kind = "livefavorites" then incoming = result.data.channels
        if kind = "favorites" then incoming = OnDemandItems(incoming)
        if kind = "movie" or kind = "series" then incoming = result.data.metas
        if kind = "live" then incoming = result.data.channels
        values = []
        for each item in Bounded(incoming,12)
            if type(item) = "roAssociativeArray"
                if Txt(item.id) <> ""
                    if kind = "movie" or kind = "series" or kind = "live" then item.type = kind
                    values.push(item)
                end if
            end if
        end for
        ' Keep longer collections reachable without retaining an unbounded shelf.
        if values.count() = 12
            values.pop()
            actions = {progress:"progress",favorites:"favorites",movie:"discovermovie",series:"discoverseries",live:"live",livefavorites:"livefavorites",recent:"recentlive"}
            values.push({name:"View all",action:actions[kind],releaseInfo:"MORE",description:"Open the full collection. Your place on Home will be kept."})
        end if
        m.homeData[index] = values
        ' Keep the selected title across server reordering; missing titles clamp below.
        if retainedItem <> invalid
            if Txt(retainedItem.id) <> "" and Txt(retainedItem.type) <> ""
                for column = 0 to values.count()-1
                    candidate = values[column]
                    if Txt(candidate.id) = Txt(retainedItem.id) and Txt(candidate.type) = Txt(retainedItem.type)
                        m.homePosition = [index,column]
                        exit for
                    end if
                end for
            end if
        end if
    else
        if kind = "favorites" then homeResponse("livefavorites",{ok:false})
        m.homeStates[index] = "This shelf is unavailable. Try Search, Live TV or Settings."
    end if
    ' Replace only the completed row. Never take remote focus from the sidebar.
    m.homeRestoring = true
    displayRow = -1
    if m.homeRowKeys = invalid then m.homeRowKeys = []
    for i = 0 to m.homeRowKeys.count()-1
        if m.homeRowKeys[i] = index then displayRow = i
    end for
    if m.homeData[index].count() > 0
        if displayRow >= 0
            m.homeRoot.replaceChild(homeRow(index),displayRow)
        else
            ' HTTP completion order must not become navigation order. Keep the
            ' native root and existing rows; only insert this logical shelf.
            insertion = 0
            orderedKeys = []
            for each logicalKey in m.homeRowKeys
                if HomeShelfRank(logicalKey) < HomeShelfRank(index)
                    orderedKeys.push(logicalKey)
                    insertion++
                end if
            end for
            orderedKeys.push(index)
            for each logicalKey in m.homeRowKeys
                if HomeShelfRank(logicalKey) > HomeShelfRank(index) then orderedKeys.push(logicalKey)
            end for
            m.homeRoot.insertChild(homeRow(index),insertion)
            m.homeRowKeys = orderedKeys
        end if
    else if displayRow >= 0
        m.homeRoot.removeChildIndex(displayRow)
        m.homeRowKeys.delete(displayRow)
        if m.homePosition[0] = index and m.homeRowKeys.count() > 0
            nextRow = displayRow
            if nextRow >= m.homeRowKeys.count() then nextRow = m.homeRowKeys.count()-1
            m.homePosition = [m.homeRowKeys[nextRow],m.homePosition[1]]
        end if
    end if
    if m.homeRowKeys.count() = 0
        m.status.text = "Loading…"
        if m.homeDone.count() >= 7 then m.status.text = "No titles yet. Search or try again."
    else
        m.status.text = ""
    end if
    homeDefaultShelf()
    homeRestore()
    homeHero()
end sub

function homeCurrent() as dynamic
    if m.homeData = invalid then return invalid
    r = m.homePosition[0]
    c = m.homePosition[1]
    if r < 0 or r > 6 then return invalid
    values = homeValues(r)
    if c < 0 or c >= values.count() then return invalid
    return values[c]
end function

sub homeFocused()
    if m.mode <> "home" or m.homeRestoring = true then return
    coordinates = m.homeRows.rowItemFocused
    if coordinates <> invalid
        if coordinates.count() = 2
            if m.homeRowKeys = invalid then return
            if coordinates[0] < 0 or coordinates[0] >= m.homeRowKeys.count() then return
            logicalRow = m.homeRowKeys[coordinates[0]]
            if logicalRow <> m.homePosition[0] or coordinates[1] <> m.homePosition[1] then m.homeAutoPick = false
            m.homePosition = [logicalRow,coordinates[1]]
            if m.homeRows.hasFocus() then m.homeExpanded = logicalRow = uiHomeHeroRow()
        end if
    end if
    uiHomeLayout()
    ' Update the hero immediately on focus, rather than after the artwork timer.
    homeHero()
    uiQueueCardArtwork()
end sub

sub retryHome()
    m.homeDirty = true
    home()
end sub

sub homeHero()
    if m.homeExpanded <> true then return
    if m.homeRetry <> invalid
        failed = false
        for each flag in m.homeFailed
            if flag then failed = true
        end for
        empty = m.homeRowKeys.count() = 0 and m.homeDone.count() >= 7
        m.homeRetry.visible = failed or empty or m.homeRetry.hasFocus()
        m.homeRetry.translation = [1030,64]
        if empty
            uiEmpty("Your library is empty","Add your services in Settings, or search for a title.")
            if failed then uiEmpty("Your library couldn't load","Check your connection or try again.")
            m.homeRetry.translation = [540,494]
        else
            m.emptyState.visible = false
        end if
    end if
    item = homeCurrent()
    if item = invalid
        m.homeTitle.text = ""
        m.uiHomeAwaitingContent = true
        m.homeActions.visible = false
        if m.homeHeroPanel <> invalid then m.homeHeroPanel.model = {name:"VIPTV",type:"",description:""}
        m.uiHeroFingerprint = ""
        return
    end if
    m.homeTitle.text = Txt(item.seriesName,Txt(item.name,"Untitled"))
    m.homeSummary.text = Txt(item.description)
    if m.homeHeroPanel <> invalid
        hero = {}
        hero.append(item)
        path = "/api/meta/" + Enc(Txt(item.type,"movie")) + "/" + Enc(PresentationMetadataId(item))
        cached = m.cache[path]
        if cached <> invalid
            meta = cached.data.meta
            if meta <> invalid
                for each field in ["background","backdrop","description","overview","genres","runtime","releaseInfo"]
                    if hero[field] = invalid or Txt(hero[field]) = ""
                        if meta[field] <> invalid then hero[field] = meta[field]
                    end if
                end for
            end if
        end if
        if m.uiHeroMetadata <> invalid and m.uiHeroMetadata[path] <> invalid
            for each field in ["background","backdrop","description","overview","genres","runtime","releaseInfo"]
                if hero[field] = invalid or Txt(hero[field]) = ""
                    if m.uiHeroMetadata[path][field] <> invalid then hero[field] = m.uiHeroMetadata[path][field]
                end if
            end for
        end if
        hero.name = m.homeTitle.text
        hero.context = PresentationContext(item)
        hero.background = PresentationBackdrop(hero)
        if hero.background = "" and m.uiLandscapeCache[path] <> invalid then hero.background = m.uiLandscapeCache[path]
        hero.backdrop = hero.background
        hero.progressFraction = homeProgress(item)
        fingerprint = FormatJson(hero)
        if m.uiHeroFingerprint <> fingerprint
            m.uiHeroFingerprint = fingerprint
            m.homeHeroPanel.model = hero
        end if
        uiHomeArtwork(PresentationMetadataId(item),Txt(item.type),PresentationBackdrop(hero))
        uiHomeActions(item)

    end if
    if m.uiHomeAwaitingContent = true
        m.uiHomeAwaitingContent = false
        if m.homeExpanded = true and m.homeRows.hasFocus() and acknowledgementMayFocus() then uiHomeFocus()
    end if
    uiFocusChanged()
end sub

sub homeSelected()
    m.homeAutoPick = false
    coordinates = m.homeRows.rowItemSelected
    if coordinates.count() <> 2 then return
    if m.homeRowKeys = invalid then return
    if coordinates[0] < 0 or coordinates[0] >= m.homeRowKeys.count() then return
    m.homePosition = [m.homeRowKeys[coordinates[0]],coordinates[1]]
    item = homeCurrent()
    if item = invalid then return
    selectItem(item)
end sub

sub navSelected()
    m.homeAutoPick = false
    index = m.sidebar.itemSelected
    if index < 0 or index >= m.navItems.count() then return
    if m.navItems[index].action <> "home" then saveView()
    m.top.setFocus(true)
    selectItem(m.navItems[index])
    uiFocusChanged()
end sub

function homeKey(key as string) as boolean
    ' The profile-entry OK can bubble after its selection handler opens Home.
    ' Actual card/sidebar selections already disable auto-pick in their observers.
    if m.mode = "home" and key <> "OK" and key <> "select" then m.homeAutoPick = false
    if m.sidebar = invalid then return false
    if m.gatewayActive = true then return false
    if m.top.dialog <> invalid then return false
    if m.mode = "home"
        if uiHomeKey(key) then return true
    end if
    if m.mode = "home" and m.homeRetry <> invalid
        if m.homeRetry.hasFocus() and key = "up"
            m.homeRows.setFocus(true)
            return true
        end if
        if key = "down" and m.homeRetry.visible
            m.homeRetry.setFocus(true)
            return true
        end if
    end if
    if m.sidebar.hasFocus()
        ' A second Back from Home leaves the scene instead of trapping focus.
        if key = "back" and m.mode = "home" then return false
        if key = "right" or key = "back"
            if m.mode = "epg"
                m.epgGrid.callFunc("resume")
            else if m.mode = "home"
                homeRestore()
                uiHomeFocus()
            else
                m.list.setFocus(true)
            end if
            return true
        end if
    else if key = "left" or (key = "back" and m.mode = "home")
        if m.mode = "detail" and key = "left" and m.list.itemFocused > 0 then return false
        if m.mode = "episodes" and key = "left" and m.episodeList.hasFocus() and m.list.itemFocused mod 4 <> 0 then return false
        if m.gridActive = true and m.mode <> "home" and key = "left"
            if m.list.itemFocused mod 4 <> 0 then return false
        end if
        if m.mode = "home" and key = "left"
            if m.homePosition[1] > 0 then return false
        end if
        if m.pendingPlayback = true then cancelBrowse()
        m.sidebar.setFocus(true)
        return true
    end if
    return false
end function
