sub uiShowDetails(item as object)
    if m.gridActive = true
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
    m.detailTitle.translation = [778,panelY]
    m.detailTitle.maxWidth = 424
    m.detailTitle.text = Txt(item.name,Txt(item.title))
    m.detailInfo.translation = [778,panelY+44]
    m.detailInfo.width = 424
    m.detailInfo.height = 60
    m.detailInfo.text = PresentationFacts(item)
    m.description.translation = [778,panelY+116]
    m.description.width = 424
    m.description.height = 208
    m.description.numLines = 7
    m.description.maxLines = 0
    m.description.font.size = 22
    m.description.text = Txt(item.description,Txt(item.overview))
    m.detailInfo.visible = m.detailInfo.text <> ""
    if not m.detailInfo.visible then m.description.translation = [778,panelY+44]
    m.art.translation = [778,panelY-48]
    m.art.width = 100
    m.art.height = 40
    m.art.uri = Txt(item.logo,Txt(item.poster))
    m.art.visible = m.art.uri <> ""
    if m.mode = "settings" or m.mode = "addons"
        m.art.visible = false
        m.detailInfo.visible = false
        m.detailTitle.translation = [778,panelY]
        m.description.translation = [778,panelY+44]
    else if m.mode = "detail" or m.mode = "episodes"
        backdrop = PresentationBackdrop(item)
        m.detailAtmosphere.visible = backdrop <> ""
        m.detailBackdrop.loadWidth = ImagePixels(1280)
        m.detailBackdrop.loadHeight = ImagePixels(720)
        m.detailBackdrop.uri = ImageUrl(backdrop,1280,720,true)
        m.heading.visible = false
        m.pageCaption.visible = false
        m.detailTitle.translation = [380,126]
        m.detailTitle.maxWidth = 804
        m.detailTitle.font.size = 46
        m.detailInfo.translation = [380,198]
        m.detailInfo.width = 706
        m.detailInfo.height = 48
        m.description.translation = [380,276]
        m.description.width = 804
        m.description.height = 122
        m.description.numLines = 4
        m.description.font.size = 23
        m.art.translation = [112,126]
        m.art.width = 236
        m.art.height = 354
        m.art.loadWidth = ImagePixels(236)
        m.art.loadHeight = ImagePixels(354)
        m.art.uri = ImageUrl(Txt(item.poster),236,354,true)
        m.art.visible = m.art.uri <> ""
        m.detailCredits.text = PresentationCredits(item)
        m.detailCredits.visible = m.mode = "detail" and m.detailCredits.text <> ""
        if m.mode = "detail"
            m.description.height = 0
            m.description.numLines = 0
            m.description.maxLines = 4
            uiLayoutDetailActions()
            m.detailLayoutTimer.control = "start"
        end if
        if m.mode = "episodes"
            m.detailTitle.translation = [112,74]
            m.detailTitle.font.size = 36
            m.detailTitle.maxWidth = 900
            m.detailInfo.translation = [112,132]
            m.description.translation = [112,186]
            m.description.width = 760
            m.description.visible = false
            m.art.visible = false
        end if
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
    m.sourceHelp.visible = count > 0
    m.sourceSpinner.visible = loading
    if loading then m.sourceSpinner.control = "start" else m.sourceSpinner.control = "stop"
    if count = 0 and loading
        m.sourceList.visible = false
        m.sourceSpinner.translation = [610,294]
        m.sourceSpinner.poster.width = 60
        m.sourceSpinner.poster.height = 60
        uiEmpty("Finding sources","Sources appear here as they arrive.")
        m.emptyTitle.translation = [250,380]
        m.emptyMessage.translation = [250,436]
    else
        m.sourceSpinner.translation = [1172,162]
        m.sourceSpinner.poster.width = 26
        m.sourceSpinner.poster.height = 26
        m.emptyState.visible = false
    end if
end sub

sub uiFocusChanged()
    if m.uiReady <> true then return
    if m.epgGrid <> invalid then m.epgGrid.active = m.epgGrid.isInFocusChain()
    rail = m.sidebar.hasFocus() and m.gatewayActive <> true and m.video.visible <> true
    m.railShade.visible = false
    m.railSurface.width = 88
    m.railSurface.visible = false
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
    for each item in [{name:seasonName,dropdown:true},{name:favoriteLabel(m.selected),dropdown:false},{name:"More info",dropdown:false}]
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
    m.fullTextBody.setFocus(true)
end sub

function uiPresentationKey(key as string) as boolean
    if m.fullTextPanel.visible
        if key = "back"
            m.fullTextPanel.visible = false
            uiRestoreFocus()
        end if
        return true
    end if
    if m.choicePanel.visible then return true
    if key = "back" and accountProfileBack() then return true
    if m.video.visible then return false
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
        if m.seasonList.hasFocus()
            if key = "down"
                m.episodeList.setFocus(true)
                return true
            else if key = "left" and m.seasonList.itemFocused = 0
                m.sidebar.setFocus(true)
                return true
            end if
        else if m.episodeList.hasFocus()
            ' A one-row MarkupGrid can leave vertical keys unhandled on hardware.
            ' Move by columns explicitly, retaining the column in the next row.
            if key = "down"
                index = m.episodeList.itemFocused
                if int(index / 4) < int((m.items.count()-1) / 4)
                    target = index + 4
                    if target >= m.items.count() then target = m.items.count()-1
                    m.episodeList.jumpToItem = target
                end if
                return true
            else if key = "up" and m.episodeList.itemFocused >= 4
                m.episodeList.jumpToItem = m.episodeList.itemFocused - 4
                return true
            else if key = "up" and m.episodeList.itemFocused < 4
                m.seasonList.setFocus(true)
                return true
            else if key = "left" and m.episodeList.itemFocused mod 4 = 0
                m.sidebar.setFocus(true)
                return true
            else if key = "left"
                return false
            end if
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
