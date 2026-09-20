sub uiDiscoverFilters()
    if m.discoverFilters = invalid then return
    name = DiscoverTypeName(m.discoverType)
    values = [{name:name,action:"dtype",selected:true}]
    catalogName = "Choose catalog"
    if m.catalog <> invalid then catalogName = Txt(m.catalog.name,Txt(m.catalog.id))
    values.push({name:catalogName,action:"dcat",selected:false})
    if m.catalog <> invalid
        genres = Bounded(m.catalog.genres,256)
        if genres.count() > 0
            genreName = Txt(m.discoverGenre)
            if genreName = "" then genreName = "All " + lcase(DiscoverGenreLabel(m.catalog))
            values.push({name:genreName,action:"dgenre",selected:Txt(m.discoverGenre) <> ""})
        end if
        for each extra in Bounded(m.catalog.extra,16)
            if extra.name = "search"
                label = "Search catalog"
                if Txt(m.search) <> "" then label = Txt(m.search)
                values.push({name:label,action:"dsearch",selected:Txt(m.search) <> ""})
            else if extra.name <> "genre" and extra.name <> "skip"
                label = DiscoverExtraLabel(extra.name)
                if m.discoverExtras <> invalid
                    if Txt(m.discoverExtras[extra.name]) <> "" then label = Txt(m.discoverExtras[extra.name])
                end if
                values.push({name:label,action:"dextra",extra:extra,selected:false})
            end if
        end for
    end if
    m.discoverFilterItems = values
    root = CreateObject("roSGNode","ContentNode")
    for each value in values
        node = root.createChild("ContentNode")
        node.title = value.name
        node.addFields({selected:value.selected,dropdown:value.action <> "dsearch",uiOwnerFocused:false})
    end for
    m.discoverFilters.content = root
    m.discoverFilters.visible = m.mode = "browse" and m.discoverActive = true
end sub

sub uiDiscoverFilterSelected()
    index = m.discoverFilters.itemSelected
    if index < 0 or index >= m.discoverFilterItems.count() then return
    item = m.discoverFilterItems[index]
    if item.action = "dtype"
        values = []
        seen = {}
        for each group in ["movie","series","anime","other"]
            hasGroup = false
            for each catalog in m.discoverCatalogs
                if DiscoverTypeMatches(Txt(catalog.type),group) then hasGroup = true
            end for
            if hasGroup then values.push({name:DiscoverGroupLabel(group),value:group})
        end for
        uiOpenChoice("discoverType","Browse",values)
    else if item.action = "dcat"
        values = []
        selectedIndex = 0
        for i = 0 to m.discoverCatalogs.count()-1
            catalog = m.discoverCatalogs[i]
            if DiscoverTypeMatches(Txt(catalog.type),m.discoverType)
                if m.catalog <> invalid
                    if Txt(catalog.id) = Txt(m.catalog.id) and Txt(catalog.addon_id) = Txt(m.catalog.addon_id) then selectedIndex = values.count()
                end if
                label = Txt(catalog.name,Txt(catalog.id))
                if Txt(catalog.addon_name) <> "" then label = Txt(catalog.addon_name) + "  ·  " + label
                values.push({name:label,catalogIndex:i})
            end if
        end for
        uiOpenChoice("discoverCatalog","Catalogs",values,selectedIndex)
    else if item.action = "dgenre" and m.catalog <> invalid
        values = []
        selectedIndex = 0
        if not UiCatalogRequired(m.catalog,"genre") then values.push({name:"All " + lcase(DiscoverGenreLabel(m.catalog)),value:""})
        for each genre in Bounded(m.catalog.genres,256)
            if Txt(genre) = Txt(m.discoverGenre) then selectedIndex = values.count()
            values.push({name:Txt(genre),value:Txt(genre)})
        end for
        uiOpenChoice("discoverGenre",DiscoverGenreLabel(m.catalog),values,selectedIndex)
    else if item.action = "dsearch"
        m.mediaType = m.discoverType
        keyboard("discoverSearch","Search this catalog",Txt(m.search))
    else if item.action = "dextra"
        m.discoverExtraName = item.extra.name
        if m.discoverExtras = invalid then m.discoverExtras = {}
        values = []
        if item.extra.required <> true then values.push({name:"Any",value:""})
        for each option in Bounded(item.extra.options,256)
            values.push({name:Txt(option),value:Txt(option)})
        end for
        if Bounded(item.extra.options,256).count() > 0
            uiOpenChoice("discoverExtra",DiscoverExtraLabel(item.extra.name),values)
        else
            keyboard("discoverExtra",DiscoverExtraLabel(item.extra.name),Txt(m.discoverExtras[item.extra.name]))
        end if
    end if
end sub

sub uiFavoriteAcknowledged()
    saved = []
    item = m.favoriteItem
    if item = invalid then return
    for each favorite in Bounded(m.liveFavoriteItems,500)
        if Txt(favorite.id) <> Txt(item.id) or Txt(favorite.type) <> Txt(item.type) then saved.push(favorite)
    end for
    if m.favoriteMessage = "Added to favorites." then saved.push(item)
    m.liveFavoriteItems = saved
end sub

function uiHomeHeroRow() as integer
    if m.homeRowKeys <> invalid and m.homeRowKeys.count() > 0 then return m.homeRowKeys[0]
    return 0
end function

sub uiHomeLayout()
    expanded = m.homeExpanded = true
    m.homeHeroPanel.visible = expanded
    m.homeHeroPanel.compact = false
    m.homeActions.visible = expanded and m.mode = "home" and homeCurrent() <> invalid
    if expanded
        m.homeShelves.translation = [92,466]
        m.homeShelves.clippingRect = [0,0,1188,254]
    else
        m.homeShelves.translation = [92,100]
        m.homeShelves.clippingRect = [0,0,1188,620]
    end if
end sub

sub uiHomeFocus()
    if m.homeInitialLoading = true
        m.top.setFocus(true)
        return
    end if
    uiHomeLayout()
    if m.homeActions.visible then m.homeActions.setFocus(true) else m.homeRows.setFocus(true)
    uiFocusChanged()
end sub

sub uiHomeActions(item as object)
    label = "Play"
    context = StreamContext(item)
    if item.type = "series" and context.episode = invalid then label = "Episodes"
    if item.position <> invalid
        if item.position > 0 then label = "Resume"
    end if
    if item.queue_status = "next" then label = "Play next episode"
    secondary = "Details"
    if item.type = "live"
        label = "Watch live"
        secondary = "Guide"
    end if
    key = label + "|" + secondary
    if key <> Txt(m.uiHomeActionKey)
        m.uiHomeActionKey = key
        width = 144
        if item.queue_status = "next" then width = 236
        m.homeActions.itemSize = [width,50]
        root = CreateObject("roSGNode","ContentNode")
        for each name in [label,secondary]
            node = root.createChild("ContentNode")
            node.title = name
            node.addFields({uiWidth:width,uiHeight:50,uiOwnerFocused:false})
        end for
        m.homeActions.content = root
    end if
    uiHomeLayout()
end sub

sub uiHomeActionSelected()
    item = homeCurrent()
    if item = invalid then return
    m.homeAutoPick = false
    if m.homeActions.itemFocused = 0
        if item.queue_status = "next"
            m.nextScope = m.profile
            m.continuationItem = CopyRouteData(item)
            continuationPlay()
        else if item.position <> invalid and item.position > 0 and item.type <> "live"
            findStreams(item,false,StableResumePreference(item))
        else if item.type = "movie"
            findStreams(item,true)
        else
            selectItem(item)
        end if
    else if item.type = "live"
        saveView()
        m.selected = item
        cancelBrowse()
        request("GET","/api/guide/" + Enc(Txt(item.id)),invalid,"guide")
        m.status.text = "Loading guide…"
    else
        details = {}
        details.append(item)
        details.id = PresentationMetadataId(item)
        selectItem(details)
    end if
end sub

function uiHomeKey(key as string) as boolean
    if m.homeActions.hasFocus()
        if key = "down"
            m.homeAutoPick = false
            m.homeExpanded = m.homePosition[0] = uiHomeHeroRow()
            uiHomeLayout()
            m.homeRows.setFocus(true)
            return true
        else if key = "back" or (key = "left" and m.homeActions.itemFocused = 0)
            m.sidebar.setFocus(true)
            return true
        end if
    else if m.homeRows.hasFocus()
        coordinates = m.homeRows.rowItemFocused
        if key = "back" or (key = "up" and coordinates[0] = 0)
            if coordinates[0] > 0
                m.homePosition = [m.homeRowKeys[0],0]
                m.homeRows.jumpToRowItem = [0,0]
            end if
            m.homeExpanded = true
            homeHero()
            uiHomeFocus()
            return true
        end if
    end if
    return false
end function
