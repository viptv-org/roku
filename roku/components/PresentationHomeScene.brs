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
        m.homeRows.itemSize = [1088,237]
        m.homeRows.numRows = 1
        m.homeShelves.translation = [120,466]
        m.homeShelves.clippingRect = [0,0,1096,218]
    else
        m.homeHeroPanel.model = {name:"",type:""}
        m.uiHeroFingerprint = ""
        m.homeRows.itemSize = [1088,214]
        m.homeRows.numRows = 3
        m.homeShelves.translation = [120,36]
        m.homeShelves.clippingRect = [0,0,1096,648]
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
    actionY = 366
    if PresentationContext(item) = "" and UiProgressFraction(item) <= 0 then actionY = 332
    m.homeActions.translation = [128,actionY]
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
    if item.action <> invalid then label = Txt(item.name,"View all")
    saved = UiIsFavorite(item)
    key = label + "|" + secondary + "|" + Txt(saved)
    if key <> Txt(m.uiHomeActionKey)
        m.uiHomeActionKey = key
        width = 152
        if item.queue_status = "next" then width = 236
        m.homeActions.itemSize = [width,48]
        root = CreateObject("roSGNode","ContentNode")
        names = [label,secondary]
        if item.action <> invalid then names = [label]
        for each name in names
            node = root.createChild("ContentNode")
            node.title = name
            node.addFields({uiWidth:width,uiHeight:48,uiOwnerFocused:false})
        end for
        m.homeActions.numColumns = names.count()
        if item.type <> "live" and item.action = invalid
            m.homeActions.numColumns = 3
            icon = "plus"
            if saved then icon = "check"
            node = root.createChild("ContentNode")
            node.title = ""
            node.addFields({uiWidth:48,uiHeight:48,uiIcon:icon,uiOwnerFocused:false})
        end if
        m.homeActions.content = root
    end if
    uiHomeLayout()
end sub

sub uiHomeActionSelected()
    item = homeCurrent()
    if item = invalid then return
    m.homeAutoPick = false
    if m.homeActions.itemFocused = 2
        toggleFavorite()
        return
    end if
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
        request("GET","/api/v2/iptv/guide/" + Enc(Txt(item.id)),invalid,"guide")
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

sub uiDiscoverTypeSelected()
    index = m.discoverTypes.itemSelected
    if index < 0 or index >= m.discoverTypeItems.count() then return
    openDiscover(m.discoverTypeItems[index])
end sub
