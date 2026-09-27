sub uiShowDetails(item as object)
    if m.gridActive = true
        if m.discoverActive = true then return
        m.pageCaption.text = Txt(item.name,Txt(item.title))
        facts = PresentationFacts(item)
        if facts <> "" then m.pageCaption.text += "  ·  " + facts
        m.pageCaption.visible = true
        return
    end if
    if m.mode = "streams"
        m.sourceText.text = OriginalSourceDetails(item)
        return
    end if
    if m.mode = "profiles" or m.mode = "pairing" or m.mode = "loading" or m.mode = "livecategories" or m.mode = "sourceerror" or m.mode = "discovererror" then return
    for each id in ["art","detailTitle","detailInfo","description"]
        m[id].visible = true
    end for
    m.detailTitle.font.size = 28
    panelY = m.standardList.translation[1] + 8
    if m.list.isSameNode(m.channelList) then panelY = 242
    m.detailTitle.translation = [693,panelY]
    m.detailTitle.maxWidth = 523
    m.detailTitle.text = Txt(item.name,Txt(item.title))
    m.detailInfo.translation = [693,panelY+44]
    m.detailInfo.width = 523
    m.detailInfo.height = 60
    m.detailInfo.text = PresentationFacts(item)
    m.description.translation = [693,panelY+116]
    m.description.width = 523
    m.description.height = 208
    m.description.numLines = 7
    m.description.maxLines = 0
    m.description.font.size = 17
    m.description.text = Txt(item.description,Txt(item.overview))
    m.detailInfo.visible = m.detailInfo.text <> ""
    if not m.detailInfo.visible then m.description.translation = [693,panelY+44]
    m.art.translation = [693,panelY-48]
    m.art.width = 100
    m.art.height = 40
    m.art.uri = Txt(item.logo,Txt(item.poster))
    m.art.visible = m.art.uri <> ""
    if m.mode = "settings" or m.mode = "addons"
        m.art.visible = false
        m.detailInfo.visible = false
        m.detailTitle.translation = [693,panelY]
        m.description.translation = [693,panelY+44]
    else if m.mode = "detail" or m.mode = "episodes"
        backdrop = PresentationBackdrop(item)
        m.detailAtmosphere.visible = backdrop <> ""
        m.detailBackdrop.uri = ImageUrl(backdrop,1120,720,true)
        if m.detailAmbient <> invalid then m.detailAmbient.uri = ImageUrl(backdrop,80,45,false)
        m.heading.visible = false
        m.pageCaption.visible = false
        m.detailTitle.translation = [128,64]
        m.detailTitle.maxWidth = 760
        m.detailTitle.font.size = 37
        m.detailInfo.translation = [128,142]
        m.detailInfo.width = 900
        m.detailInfo.height = 28
        m.description.translation = [128,178]
        m.description.width = 520
        m.description.height = 0
        m.description.numLines = 0
        m.description.maxLines = 2
        m.description.font.size = 17
        m.art.translation = [128,64]
        m.art.width = 273
        m.art.height = 60
        m.art.loadWidth = 410
        m.art.loadHeight = 90
        m.art.uri = ImageUrl(Txt(item.logo),410,90,false,true)
        m.art.visible = m.art.uri <> ""
        m.detailTitle.visible = not m.art.visible
        m.detailCredits.text = PresentationCredits(item)
        m.detailCredits.visible = false
        uiLayoutDetailActions()
        m.detailLayoutTimer.control = "start"
        if m.mode = "episodes" then uiSeriesActions()
    else if item.type = "live" and (m.mode = "browse" or m.mode = "livefavorites" or m.mode = "collection")
        queueLiveEpg(item)
    end if
end sub

sub uiSourceHeader()
    if m.mode <> "streams" then return
    context = ""
    if m.playItem <> invalid
        context = Txt(m.playItem.seriesName,Txt(m.playItem.name))
        episode = PresentationContext(m.playItem)
        if episode <> "" then context += "  ·  " + episode
    end if
    m.sourceContext.text = context
    count = 0
    if m.streams <> invalid then count = m.streams.count()
    if count = 0 and m.items <> invalid
        for each item in m.items
            if item.action = invalid then count++
        end for
    end if
    uiSourceFilterChip()
    shown = m.items.count()
    m.sourceState.text = shown.toStr() + " sources"
    if Txt(m.sourceFilter) <> "" then m.sourceState.text += " / " + count.toStr() + " total"
    loading = m.discoveryDone <> true
    if loading then m.sourceState.text += "  ·  Finding more…" else m.sourceState.text += "  ·  Search complete"
    m.sourceHelp.visible = false
    m.sourceSpinner.visible = loading
    if loading then m.sourceSpinner.control = "start" else m.sourceSpinner.control = "stop"
    if count = 0 and loading
        m.sourceList.visible = false
        m.sourceSpinner.translation = [987,260]
        m.sourceSpinner.poster.width = 38
        m.sourceSpinner.poster.height = 38
        uiEmpty("Finding sources","Sources appear here as they arrive.")
        m.emptyTitle.width = 440
        m.emptyMessage.width = 440
        m.emptyTitle.translation = [770,340]
        m.emptyMessage.translation = [770,390]
    else
        m.sourceSpinner.translation = [1182,128]
        m.sourceSpinner.poster.width = 26
        m.sourceSpinner.poster.height = 26
        m.emptyState.visible = false
    end if
end sub

sub uiFocusChanged()
    if m.uiReady <> true then return
    if m.searchPanel <> invalid then m.searchPanel.callFunc("syncFocus")
    if m.epgGrid <> invalid then m.epgGrid.active = m.epgGrid.isInFocusChain()
    if m.episodeList <> invalid then m.episodeList.active = m.episodeList.hasFocus()
    if m.discoverFilters <> invalid then m.discoverFilters.active = m.discoverFilters.hasFocus()
    rail = m.sidebar.hasFocus() and m.gatewayActive <> true and m.video.visible <> true
    m.sidebar.active = rail
    for each collection in [m.profileGrid,m.profileActions,m.profilePages,m.homeActions,m.homeRows,m.posterGrid,m.sourceList,m.sourceFilters,m.detailActions,m.standardList,m.episodeList,m.seasonList,m.channelList,m.liveTabs,m.discoverFilters]
        if collection <> invalid and collection.content <> invalid
            ownsFocus = collection.hasFocus() and collection.visible and not m.choicePanel.visible and not m.fullTextPanel.visible
            for i = 0 to collection.content.getChildCount()-1
                item = collection.content.getChild(i)
                if collection.isSameNode(m.homeRows)
                    for j = 0 to item.getChildCount()-1
                        child = item.getChild(j)
                        if child.hasField("uiOwnerFocused") then child.uiOwnerFocused = ownsFocus
                    end for
                else if item.hasField("uiOwnerFocused")
                    item.uiOwnerFocused = ownsFocus
                end if
            end for
        end if
    end for
end sub

sub uiBuildSeasons()
    m.seasonItems = []
    seen = {}
    seasonName = "Season " + Txt(m.episodeSeason)
    for each episode in Bounded(m.episodes,2000)
        season = Txt(episode.season,"unknown")
        if not seen.doesExist(season)
            seen[season] = true
            name = "Season " + season
            if season = "0" then name = "Specials"
            if season = "unknown" then name = "Other episodes"
            if season = Txt(m.episodeSeason) then seasonName = name
            m.seasonItems.push({name:name,value:season})
        end if
    end for
    root = CreateObject("roSGNode","ContentNode")
    for each item in [{name:seasonName,dropdown:true}]
        node = root.createChild("ContentNode")
        node.title = item.name
        node.addFields({dropdown:item.dropdown,selected:false,uiOwnerFocused:false})
    end for
    m.seasonList.content = root
    m.seasonHeading.visible = false
    m.episodesHeading.text = m.items.count().toStr() + " episodes"
end sub

sub uiSeasonSelected()
    index = m.seasonList.itemSelected
    if index = 0
        uiOpenChoice("episodeSeason","Choose season",m.seasonItems)
    else if index = 1
        toggleFavorite()
    else if index = 2
        uiFullText(Txt(m.selected.name),PresentationFullDetails(m.selected))
    end if
end sub

sub uiLiveTabs()
    m.liveTabItems = [{name:"All channels",action:"allchannels"},{name:"Favorites",action:"livefavorites"},{name:"Categories",action:"livefilter"},{name:"Search",action:"livesearch"}]
    root = CreateObject("roSGNode","ContentNode")
    for each item in m.liveTabItems
        node = root.createChild("ContentNode")
        node.title = item.name
        node.addFields({selected:(item.action = "livefavorites" and m.mode = "livefavorites"),uiOwnerFocused:false})
    end for
    m.liveTabs.content = root
    m.liveTabs.visible = true
end sub

sub uiLiveTabSelected()
    index = m.liveTabs.itemSelected
    if index < 0 or index >= m.liveTabItems.count() then return
    selectItem(m.liveTabItems[index])
end sub
sub uiFullText(title as string, text as string)
    m.fullTextTitle.text = title
    m.fullTextBody.text = text
    m.fullTextPanel.visible = true
    m.fullTextClose.setFocus(true)
end sub

function uiPresentationKey(key as string) as boolean
    if m.fullTextPanel.visible
        if key = "up" and m.fullTextClose.hasFocus() then m.fullTextBody.setFocus(true)
        if key = "down" and m.fullTextBody.hasFocus() then m.fullTextClose.setFocus(true)
        if key = "back"
            m.fullTextPanel.visible = false
            uiRestoreFocus()
        end if
        return true
    end if
    if m.choicePanel.visible then return true
    if key = "back" and accountProfileBack() then return true
    if m.video.visible then return false
    if m.libraryTabs.visible
        if m.libraryTabs.hasFocus() and key = "down"
            if m.items.count() > 0 then m.list.setFocus(true)
            return true
        else if m.list.hasFocus() and m.list.itemFocused < 4 and key = "up"
            m.libraryTabs.setFocus(true)
            return true
        end if
    end if
    if m.mode = "browse" and m.discoverActive = true
        if m.discoverTypes.hasFocus()
            if key = "down"
                m.discoverFilters.setFocus(true)
                return true
            else if key = "left" and m.discoverTypes.itemFocused = 0
                m.sidebar.setFocus(true)
                return true
            end if
        else if m.discoverFilters.hasFocus() and key = "up"
            m.discoverTypes.setFocus(true)
            return true
        end if
    end if
    if m.mode = "searchall"
        if m.sidebar.hasFocus() and key = "right"
            m.searchPanel.setFocus(true)
            m.searchPanel.callFunc("focusField")
            return true
        end if
        if key = "left"
            m.sidebar.setFocus(true)
            return true
        end if
    end if
    if m.mode = "streams"
        if m.sourceFilters.hasFocus()
            if key = "down" and m.items.count() > 0
                m.sourceList.setFocus(true)
                return true
            else if key = "left"
                m.sidebar.setFocus(true)
                return true
            end if
        else if m.sourceList.hasFocus() and key = "up" and m.sourceList.itemFocused = 0
            m.sourceFilters.setFocus(true)
            return true
        end if
    end if
    if m.mode = "episodes"
        if m.detailActions.hasFocus()
            if key = "down"
                m.seasonList.setFocus(true)
                return true
            end if
        else if m.seasonList.hasFocus()
            if key = "down"
                m.episodeList.setFocus(true)
                return true
            else if key = "up"
                m.detailActions.setFocus(true)
                return true
            else if key = "left" or key = "right"
                uiOpenChoice("episodeSeason","Choose season",m.seasonItems)
                return true
            end if
        else if m.episodeList.hasFocus() and key = "down"
            return true
        else if m.episodeList.hasFocus() and key = "up"
            m.seasonList.setFocus(true)
            return true
        end if
    end if
    if m.liveTabs.visible
        if m.liveTabs.hasFocus()
            if key = "down"
                m.list.setFocus(true)
                return true
            else if key = "left" and m.liveTabs.itemFocused = 0
                m.sidebar.setFocus(true)
                return true
            end if
        else if m.list.hasFocus() and key = "up" and m.list.itemFocused = 0
            m.liveTabs.setFocus(true)
            return true
        end if
    end if
    if key = "info" or key = "options"
        if m.sidebar.hasFocus() then return true
        if m.mode = "streams"
            index = m.sourceList.itemFocused
            if index >= 0 and index < m.items.count() then uiFullText("Source details",OriginalSourceDetails(m.items[index]))
            return true
        end if
        item = focusedLiveChannel()
        if item <> invalid
            m.liveOptionItem = item
            label = "Add to favorites"
            if UiIsFavorite(item) then label = "Remove from favorites"
            uiOpenChoice("liveOptions",Txt(item.name),[{name:"Watch live",action:"watch"},{name:label,action:"favorite"},{name:"Program guide",action:"guide"}])
            return true
        end if
    end if
    return false
end function

sub uiSeriesActions()
    if m.mode <> "episodes" then return
    target = invalid
    index = m.episodeList.itemFocused
    if index >= 0 and index < m.items.count() then target = m.items[index]
    if target = invalid or target.action <> invalid
        for each candidate in m.items
            if candidate.action = invalid
                target = candidate
                exit for
            end if
        end for
    end if
    m.seriesPlayItem = invalid
    label = "Play"
    if target <> invalid and target.action = invalid
        m.seriesPlayItem = EpisodePresentationItem(m.selected,target)
        if target.position <> invalid and target.position > 0 then label = "Resume"
        if target.season <> invalid and target.episode <> invalid then label += " S"+Txt(target.season)+" E"+Txt(target.episode)
    end if
    source = Txt(m.selected.source_name,"Choose source")
    if len(source) > 26 then source = left(source,25)+"…"
    names = [label,source,favoriteLabel(m.selected),"More info"]
    icons = ["play","source","plus","info"]
    if UiIsFavorite(m.selected) then icons[2] = "check"
    root = CreateObject("roSGNode","ContentNode")
    for i = 0 to names.count()-1
        node = root.createChild("ContentNode")
        node.title = names[i]
        node.addFields({uiWidth:216,uiHeight:48,uiIcon:icons[i],uiOwnerFocused:false})
    end for
    m.detailActions.itemSize = [216,48]
    m.detailActions.numColumns = 4
    m.detailActions.content = root
    m.detailActions.visible = true
    m.detailActions.translation = [128,244]
end sub

sub uiSeriesActionSelected(held as boolean)
    index = m.detailActions.itemFocused
    if index = 0 or index = 1
        if m.seriesPlayItem = invalid then return
        manual = index = 1 or held
        findStreams(m.seriesPlayItem,manual,StableResumePreference(m.seriesPlayItem))
    else if index = 2
        toggleFavorite()
    else if index = 3
        uiFullText(Txt(m.selected.name),PresentationFullDetails(m.selected))
    end if
end sub

sub uiCloseFullText()
    m.fullTextPanel.visible = false
    uiRestoreFocus()
end sub

sub uiTitleLogoLoaded()
    if m.mode <> "detail" and m.mode <> "episodes" then return
    ready = m.art.uri <> "" and m.art.loadStatus = "ready"
    if ready and m.art.bitmapHeight > 0
        width = 60.0*m.art.bitmapWidth/m.art.bitmapHeight
        if width > 506 then width = 506
        m.art.width = width
    end if
    m.art.visible = ready
    m.detailTitle.visible = not ready
end sub

sub uiLibraryTabs()
    root = CreateObject("roSGNode","ContentNode")
    for each name in ["My List","Continue Watching"]
        node = root.createChild("ContentNode")
        node.title = name
        current = (name = "My List" and m.collection = "favorites") or (name = "Continue Watching" and m.collection = "progress")
        node.addFields({uiWidth:220,selected:current,dropdown:false,uiOwnerFocused:false})
    end for
    m.libraryTabs.content = root
    m.libraryTabs.visible = true
end sub
sub uiLibraryTabSelected()
    if m.libraryTabs.itemSelected = 0 then openLibraryPage(0) else openViewingQueue(0)
end sub
