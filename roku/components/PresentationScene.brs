' Presentation-only screen ownership, geometry and remote-focus coordination.
' Authentication, HTTP scheduling, playback sessions and Video replacement stay in MainScene.
sub initPresentation()
    ids = ["pageCaption","detailAtmosphere","detailBackdrop","detailActions","episodeList","seasonList","seasonHeading","episodesHeading","liveTabs","channelList","liveListHeading","sourceFilters","detailCredits","sourceContext","sourceState","sourceHelp","sourceSpinner","emptyState","emptyTitle","emptyMessage","busyPanel","busySpinner","busyMessage","busyShade","noticePanel","noticeText","noticeTimer","choicePanel","fullTextPanel","fullTextTitle","fullTextBody","railSurface","railShade","homeActions","homeShelves","heroArtTimer"]
    for each id in ids
        m[id] = m.top.findNode(id)
    end for
    for each node in [m.episodeList,m.channelList]
        node.observeField("itemSelected","selected")
        node.observeField("itemFocused","focused")
    end for
    m.profileEditor = m.top.findNode("profileEditor")
    m.textEntry = m.top.findNode("textEntry")
    m.profileEditor.observeField("action","accountEditorAction")
    m.textEntry.observeField("result","keyboardDone")
    initSearch()
    m.sourceFilters.observeField("itemSelected","uiSourceFilterSelected")
    m.seasonList.observeField("itemSelected","uiSeasonSelected")
    m.liveTabs.observeField("itemSelected","uiLiveTabSelected")
    m.choicePanel.observeField("selection","uiChoiceSelected")
    m.choicePanel.observeField("dismissed","uiChoiceDismissed")
    m.status.observeField("text","uiStatusChanged")
    m.noticeTimer.observeField("fire","uiHideNotice")
    m.top.observeField("focusedChild","uiFocusChanged")
    m.busySpinner.poster.uri = "pkg:/images/ui-spinner.png"
    m.sourceSpinner.poster.uri = "pkg:/images/ui-spinner.png"
    m.busySpinner.poster.width = 60
    m.busySpinner.poster.height = 60
    m.sourceSpinner.poster.width = 26
    m.sourceSpinner.poster.height = 26
    m.homeActions.observeField("activation","uiResumeAction")
    m.detailActions.observeField("activation","uiResumeAction")
    m.detailActions.observeField("itemFocused","focused")
    m.homeActions.observeField("focusedChild","uiFocusChanged")
    m.homeRows.observeField("focusedChild","uiFocusChanged")
    m.homePanel.observeField("focusedChild","uiFocusChanged")
    m.heroArtTimer.observeField("fire","uiLoadHeroArt")
    m.uiHeroSequence = 0
    m.uiHeroTried = {}
    m.uiHeroTriedOrder = []
    m.detailLayoutTimer = m.top.findNode("detailLayoutTimer")
    m.detailLayoutTimer.observeField("fire","uiLayoutDetailActions")
    m.uiLandscapeCache = {}
    m.uiLandscapeOrder = []
    m.uiArtworkTried = {}
    m.uiArtworkOrder = []
    m.uiArtworkInflight = {}
    m.uiArtworkSequence = 0
    m.artworkTimer = m.top.findNode("artworkTimer")
    m.artworkTimer.observeField("fire","uiLoadCardArtwork")
    m.searchPanel.observeField("position","uiQueueCardArtwork")
    m.uiReady = true
end sub

sub uiHideNotice()
    m.noticePanel.visible = false
    m.noticeTimer.control = "stop"
end sub

sub uiNotice(message as string)
    if message = "" then return
    m.noticeText.text = message
    m.noticePanel.visible = true
    m.noticeTimer.control = "start"
end sub

sub uiBusy(active as boolean, message = "Loading" as string)
    if m.busyPanel = invalid then return
    ' Never bury an in-flight playback frame under the full-screen cover; the
    ' player overlay carries its own buffering spinner during transitions.
    if active and m.video <> invalid
        if m.video.visible
            m.busyPanel.visible = false
            m.busySpinner.control = "stop"
            return
        end if
    end if
    m.busyMessage.text = message
    m.busyMessage.font.size = 22
    m.busyPanel.visible = active
    if active then m.busySpinner.control = "start" else m.busySpinner.control = "stop"
end sub

sub uiStatusChanged()
    if m.uiReady <> true then return
    m.status.visible = false
    text = Txt(m.status.text)
    lower = lcase(text)
    if text = ""
        uiBusy(false)
        return
    end if
    loading = left(lower,7) = "loading" or left(lower,7) = "finding" or left(lower,8) = "starting" or left(lower,9) = "searching" or left(lower,9) = "preparing" or left(lower,10) = "refreshing" or left(lower,7) = "opening"
    if loading
        uiHideNotice()
        if m.mode = "streams" and m.pendingPlayback <> true
            uiSourceHeader()
        else
            uiBusy(true,text)
        end if
        return
    end if
    uiBusy(false)
    if m.mode = "streams" then uiSourceHeader()
    errorText = instr(1,lower,"unavailable") > 0 or instr(1,lower,"failed") > 0 or instr(1,lower,"could not") > 0 or instr(1,lower,"unable") > 0 or instr(1,lower,"timed out") > 0 or instr(1,lower,"busy") > 0
    if errorText
        if m.mode <> "sourceerror" and m.mode <> "discovererror" then uiNotice("That couldn't load. Please try again.")
    else if instr(1,lower,"favorites") > 0 or instr(1,lower,"my list") > 0
        if left(lower,5) = "added" or left(lower,7) = "removed" then uiNotice(text)
    end if
end sub

sub uiHidePageExtras()
    if m.epgGrid <> invalid then m.epgGrid.visible = false
    if m.searchPanel <> invalid then m.searchPanel.visible = false
    if m.searchDelay <> invalid then m.searchDelay.control = "stop"
    if m.uiReady <> true then return
    for each id in ["detailAtmosphere","detailActions","episodeList","seasonList","seasonHeading","episodesHeading","liveTabs","channelList","liveListHeading","sourceFilters","detailCredits","sourceContext","sourceState","sourceHelp","sourceSpinner","emptyState","pageCaption","discoverFilters"]
        m[id].visible = false
    end for
    m.sourceSpinner.control = "stop"
    m.detailPanel.visible = false
    m.status.visible = false
    m.footer.visible = false
    uiHideNotice()
    uiBusy(false)
end sub

sub uiRows(title as string, values as object, mode as string, subtitle as string, enter as boolean)
    if mode = "streams" and not enter and m.mode = "streams"
        uiUpdateSources(values)
        return
    end if
    if mode = "streams" and enter then m.sourceFilter = ""
    priorIndex = m.list.itemFocused
    if m.listUpdating = true and m.listRestoreIndex <> invalid then priorIndex = m.listRestoreIndex
    priorId = ""
    priorType = ""
    if not enter and m.items <> invalid and priorIndex <> invalid
        if priorIndex >= 0 and priorIndex < m.items.count()
            priorId = Txt(m.items[priorIndex].id)
            priorType = Txt(m.items[priorIndex].type)
        end if
    end if
    homeVisible(false)
    uiHidePageExtras()
    if mode <> "pairing" then accountHideQr()
    m.mode = mode
    m.profileGrid.visible = false
    for each node in [m.profileActions,m.profilePages,m.profilePageLabel]
        if node <> invalid then node.visible = false
    end for
    for each node in [m.standardList,m.posterGrid,m.sourceList,m.detailActions,m.episodeList,m.channelList]
        node.visible = false
    end for
    m.gridActive = UsesPosterGrid(mode,m.mediaType,values)
    m.list = m.standardList
    if m.gridActive then m.list = m.posterGrid
    if mode = "streams" then m.list = m.sourceList
    if mode = "detail" then m.list = m.detailActions
    if mode = "episodes" then m.list = m.episodeList
    if (mode = "browse" and m.mediaType = "live") or mode = "livefavorites" or (mode = "collection" and m.collection = "recentlive") then m.list = m.channelList
    limit = 100
    if m.gridActive then limit = 480
    if mode = "episodes" then limit = 82
    if mode = "streams" then limit = 320
    m.items = Bounded(values,limit)
    m.heading.text = title
    m.status.text = ""
    accountLayout(mode = "pairing" or mode = "profiles" or m.profile = "")
    uiLayoutPage(mode,subtitle)
    root = CreateObject("roSGNode","ContentNode")
    for each item in m.items
        node = root.createChild("ContentNode")
        node.title = Txt(item.displayName,Txt(item.name,Txt(item.title,"Untitled")))
        node.description = Txt(item.description)
        node.addFields({uiWidth:m.list.itemSize[0],uiHeight:m.list.itemSize[1],uiOwnerFocused:false})
        if m.gridActive
            UiCardContent(node,item)
        else if mode = "streams"
            node.title = CreateObject("roRegex",chr(10),"").replaceAll(ReadableSourceText(OriginalSourceName(item))," · ")
            node.description = SourceCardText(item)
            node.addFields({sourceBadges:SourceBadges(item,m.playItem)})
        else if mode = "episodes"
            node.title = "E" + Txt(item.episode,"?") + "  " + EpisodeTitle(item)
            node.HDPosterUrl = Txt(item.thumbnail,Txt(item.image))
            node.description = Txt(item.overview,Txt(item.description))
            if node.description = "" then node.description = Txt(item.released)
            node.addFields({episodeNumber:Txt(item.episode,"?"),episodeTitle:EpisodeTitle(item),watched:item.watched = true,progressFraction:UiProgressFraction(item),pageAction:item.action <> invalid})
            if item.action <> invalid
                node.episodeTitle = Txt(item.name)
                node.title = Txt(item.name)
                node.description = "Open another page in this season"
            end if
        else if m.list.isSameNode(m.channelList)
            node.HDPosterUrl = Txt(item.logo,Txt(item.poster))
            node.addFields({saved:UiIsFavorite(item)})
        end if
    end for
    m.listUpdating = not enter
    m.list.content = root
    m.list.visible = m.items.count() > 0 and mode <> "profiles" and mode <> "loading"
    if enter
        m.listFocusTimer.control = "stop"
        if m.items.count() > 0 then m.list.jumpToItem = 0
        if acknowledgementMayFocus() then m.list.setFocus(true)
    else
        if priorIndex = invalid then priorIndex = 0
        for i = 0 to m.items.count()-1
            if priorId <> "" and Txt(m.items[i].id) = priorId and Txt(m.items[i].type) = priorType then priorIndex = i
        end for
        priorIndex = RestoreCardIndex(priorIndex,m.items.count())
        m.listRestoreIndex = priorIndex
        if m.items.count() > 0 then m.list.jumpToItem = priorIndex
        m.listFocusTimer.control = "start"
    end if
    if mode = "detail" or mode = "episodes"
        if m.selected <> invalid then uiShowDetails(m.selected)
    else if m.items.count() > 0
        focused()
    end if
    if mode = "streams" then uiSourceHeader()
    if mode = "pairing" and m.items.count() = 0 then m.top.setFocus(true)
    if m.items.count() = 0 and mode <> "profiles" and mode <> "loading" and mode <> "streams" and mode <> "pairing"
        uiEmpty("Nothing here yet","Choose another filter, or come back later.")
        if mode = "livefavorites" then uiEmpty("Your favorite channels","Press * on a channel and choose Add to favorites.")
        if mode = "episodes" then uiEmpty("No episodes available","Try another season.")
        ' Empty lists are hidden: keep keyboard focus on an actual visible control.
        target = invalid
        if m.liveTabs.visible
            target = m.liveTabs
            if mode = "livefavorites" then target.jumpToItem = 1
        else if m.discoverFilters.visible
            target = m.discoverFilters
        else if m.seasonList.visible
            target = m.seasonList
        end if
        if target <> invalid and acknowledgementMayFocus()
            m.listFocusTimer.control = "stop"
            m.listUpdating = false
            target.setFocus(true)
        end if
    end if
    if mode = "loading" then uiBusy(true)
    if mode = "sourceerror" or mode = "discovererror"
        uiEmpty("Couldn't load this",subtitle)
        m.pageCaption.visible = false
        m.standardList.translation = [380,456]
        m.standardList.itemSize = [520,56]
        uiActionSizes(m.standardList,520,56)
        uiLayoutDetailActions()
        m.detailLayoutTimer.control = "start"
    end if
    if mode <> "pairing" or m.items.count() > 0 then accountEndLoading()
    uiFocusChanged()
end sub

sub uiActionSizes(list as object, width as integer, height as integer)
    if list.content = invalid then return
    for i = 0 to list.content.getChildCount()-1
        node = list.content.getChild(i)
        node.uiWidth = width
        node.uiHeight = height
    end for
end sub

sub uiLayoutPage(mode as string, subtitle = "" as string)
    if m.gatewayActive = true
        m.pageCaption.translation = [96,242]
        m.pageCaption.maxWidth = 580
        m.pageCaption.text = subtitle
        m.pageCaption.visible = subtitle <> ""
        if m.mode = "pairing" then m.standardList.translation = [96,322]
        m.status.visible = false
        m.footer.visible = false
        return
    end if
    m.heading.translation = [100,54]
    m.heading.width = 1096
    m.heading.height = 62
    m.heading.wrap = false
    m.heading.font.size = 42
    m.heading.visible = true
    m.pageCaption.translation = [100,126]
    m.pageCaption.maxWidth = 1096
    m.pageCaption.text = subtitle
    m.pageCaption.visible = subtitle <> ""
    m.standardList.translation = [100,176]
    if subtitle = "" then m.standardList.translation = [100,144]
    m.standardList.itemSize = [536,56]
    m.standardList.numRows = 7
    m.posterGrid.translation = [100,198]
    for each id in ["art","detailTitle","detailInfo","description"]
        m[id].visible = false
    end for
    if m.discoverActive = true and mode = "browse" and m.mediaType <> "live"
        m.discoverFilters.visible = true
        m.posterGrid.translation = [100,248]
    end if
    if mode = "streams"
        m.heading.text = "Choose a source"
        m.pageCaption.visible = false
        m.sourceFilters.visible = true
        m.sourceContext.visible = true
        m.sourceState.visible = true
    else if mode = "episodes"
        m.pageCaption.visible = false
        m.seasonList.visible = true
        m.seasonHeading.visible = true
        m.episodesHeading.visible = true
        uiBuildSeasons()
    else if mode = "livecategories"
        m.standardList.itemSize = [1096,56]
        uiLiveTabs()
        m.standardList.translation = [100,234]
        m.standardList.numRows = 5
    else if (mode = "browse" and m.mediaType = "live") or mode = "livefavorites"
        uiLiveTabs()
        m.pageCaption.visible = false
        m.liveListHeading.visible = true
        m.heading.text = "Live TV"
    end if
end sub

sub uiEmpty(title as string, message as string)
    m.emptyTitle.translation = [250,304]
    m.emptyMessage.translation = [250,360]
    m.emptyState.visible = true
    m.emptyTitle.text = title
    m.emptyMessage.text = message
end sub

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

sub uiOpenChoice(kind as string, title as string, values as object, index = 0 as integer)
    m.choiceKind = kind
    m.choiceGeneration = m.generation
    m.choicePanel.model = {title:title,items:values,index:index}
end sub

sub uiChoiceDismissed()
    if m.choiceKind = "sourceProvider" and m.mode = "streams"
        m.sourceFilters.setFocus(true)
        uiFocusChanged()
    else if m.choiceKind = "episodeSeason" and m.mode = "episodes"
        m.seasonList.setFocus(true)
        uiFocusChanged()
    else
        uiRestoreFocus()
    end if
end sub

sub uiRestoreFocus()
    if m.mode = "epg"
        m.epgGrid.callFunc("resume")
    else if m.mode = "searchall"
        m.searchPanel.callFunc("focusResults")
    else if m.mode = "home"
        uiHomeFocus()
    else if m.mode = "episodes"
        m.episodeList.setFocus(true)
    else if m.discoverActive = true and m.discoverFilters.visible
        m.discoverFilters.setFocus(true)
    else
        m.list.setFocus(true)
    end if
    uiFocusChanged()
end sub

sub uiChoiceSelected(event as object)
    choice = event.getData().item
    if m.choiceGeneration <> m.generation
        uiRestoreFocus()
        return
    end if
    kind = m.choiceKind
    uiRestoreFocus()
    if kind = "libraryManage" or kind = "queueManage" or kind = "queueUndo" or kind = "autoplay" or kind = "continuationUnavailable" or kind = "preferences" or kind = "profilehelp"
        selectItem(choice)
        return
    end if
    if kind = "sourceProvider"
        m.sourceFilter = Txt(choice.value)
        uiUpdateSources(m.streams,true)
        m.sourceFilters.setFocus(true)
        uiFocusChanged()
        return
    else if kind = "episodeSeason"
        m.episodeSeason = choice.value
        showEpisodes(0)
        m.episodeList.setFocus(true)
        uiFocusChanged()
        return
    end if
    if kind = "discoverType"
        m.discoverType = choice.value
        m.mediaType = choice.value
        m.discoverGenre = ""
        m.search = ""
        discoverChooseDefaultCatalog()
    else if kind = "discoverCatalog"
        m.catalog = m.discoverCatalogs[choice.catalogIndex]
        m.discoverGenre = ""
        m.search = ""
        uiRequiredGenre()
    else if kind = "discoverGenre"
        m.discoverGenre = choice.value
    else if kind = "discoverExtra"
        m.discoverExtras[m.discoverExtraName] = choice.value
    else if kind = "liveOptions"
        if choice.action = "favorite" then toggleFavorite()
        if choice.action = "guide" then openFocusedLiveGuide()
        if choice.action = "watch" then selectItem(m.liveOptionItem)
        return
    else if kind = "addon" or kind = "removeAddon"
        addonChoice(choice)
        return
    else if kind = "signout"
        if choice.action = "confirmSignout"
            accountSignOut()
        end if
        return
    else
        return
    end if
    m.offsetHistory = []
    m.nextOffset = invalid
    discoverBuildFilters()
    browse(m.discoverType,0)
end sub

sub uiRequiredGenre()
    m.discoverGenre = ""
    m.discoverExtras = {}
    m.search = ""
    if m.catalog = invalid then return
    for each extra in Bounded(m.catalog.extra,16)
        if extra.required = true
            value = Txt(extra.default)
            options = Bounded(extra.options,256)
            if value = "" and options.count() > 0 then value = Txt(options[0])
            if extra.name = "genre"
                m.discoverGenre = value
            else if extra.name <> "search" and extra.name <> "skip" and value <> ""
                m.discoverExtras[extra.name] = value
            end if
        end if
    end for
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
        for each catalog in m.discoverCatalogs
            kind = Txt(catalog.type)
            if not seen.doesExist(kind)
                seen[kind] = true
                values.push({name:DiscoverTypeName(kind),value:kind})
            end if
        end for
        uiOpenChoice("discoverType","Browse",values)
    else if item.action = "dcat"
        values = []
        selectedIndex = 0
        for i = 0 to m.discoverCatalogs.count()-1
            catalog = m.discoverCatalogs[i]
            if Txt(catalog.type) = m.discoverType
                if m.catalog <> invalid
                    if Txt(catalog.id) = Txt(m.catalog.id) and Txt(catalog.addon_id) = Txt(m.catalog.addon_id) then selectedIndex = values.count()
                end if
                values.push({name:Txt(catalog.name,Txt(catalog.id))+"  ·  "+Txt(catalog.addon_name),catalogIndex:i})
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

sub uiQueueHeroArt(item as object)
    uiQueueCardArtwork()
end sub

sub uiLoadHeroArt()
    if m.mode <> "home" or m.uiHeroOwner <> invalid then return
    item = homeCurrent()
    if item = invalid or item.action <> invalid or item.type = "live" then return
    if PresentationBackdrop(item) <> "" then return
    path = "/api/meta/" + Enc(Txt(item.type,"movie")) + "/" + Enc(PresentationMetadataId(item))
    if m.cache[path] <> invalid or m.uiHeroTried.doesExist(path) then return
    if m.uiHeroTriedOrder.count() >= 64 then m.uiHeroTried.delete(m.uiHeroTriedOrder.shift())
    m.uiHeroTried[path] = true
    m.uiHeroTriedOrder.push(path)
    m.uiHeroSequence++
    tag = "uihero:" + m.uiHeroSequence.toStr()
    m.uiHeroOwner = {tag:tag,path:path,id:PresentationMetadataId(item),mediaType:Txt(item.type)}
    request("GET",path,invalid,tag)
end sub

sub uiHeroArtResponse(tag as string, result as object)
    owner = m.uiHeroOwner
    if owner = invalid then return
    if owner.tag <> tag then return
    m.uiHeroOwner = invalid
    if result.ok and result.data <> invalid
        meta = result.data.meta
        if meta <> invalid
            if Txt(meta.id) = owner.id and m.cache[owner.path] = invalid
                if m.cacheKeys.count() >= 4 then m.cache.delete(m.cacheKeys.shift())
                m.cacheKeys.push(owner.path)
                m.cache[owner.path] = {time:CreateObject("roDateTime").asSeconds(),data:result.data}
                uiHomeArtwork(owner.id,owner.mediaType,PresentationBackdrop(meta))
            end if
        end if
    end if
    if m.mode = "home" then homeHero()
end sub

sub uiHomeArtwork(id as string, mediaType as string, uri as string)
    if uri = "" or m.mode <> "home" or m.homeRoot = invalid then return
    for r = 0 to m.homeRowKeys.count()-1
        values = homeValues(m.homeRowKeys[r])
        row = m.homeRoot.getChild(r)
        for c = 0 to row.getChildCount()-1
            if c < values.count()
                item = values[c]
                if PresentationMetadataId(item) = id and Txt(item.type) = mediaType
                    node = row.getChild(c)
                    node.artworkKind = "landscape"
                    node.HDPosterUrl = uri
                end if
            end if
        end for
    end for
    ' Warm the full-quality hero texture behind hidden posters so focus swaps
    ' straight to the sharp image instead of a blurry upscale.
    prefetchHeroBackdrop(uri)
end sub

sub prefetchHeroBackdrop(backdrop as string)
    if backdrop = "" then return
    hiRes = ImageUrl(backdrop,1280,720,true)
    if hiRes = "" then return
    if m.heroPrefetchLast = invalid then m.heroPrefetchLast = ["","","",""]
    for each pending in m.heroPrefetchLast
        if pending = hiRes then return
    end for
    if m.heroPrefetchIndex = invalid then m.heroPrefetchIndex = 0
    slot = m.heroPrefetchIndex mod 4
    node = m.top.findNode("heroPf" + slot.toStr())
    m.heroPrefetchLast[slot] = hiRes
    m.heroPrefetchIndex++
    if node <> invalid
        node.loadWidth = ImagePixels(1280)
        node.loadHeight = ImagePixels(720)
        node.uri = hiRes
    end if
end sub

' Measure natural wrapped text rather than reserving four lines for every synopsis.
sub uiLayoutDetailActions()
    if m.mode = "sourceerror" or m.mode = "discovererror"
        bounds = m.emptyMessage.localBoundingRect()
        m.standardList.translation = [380,360+bounds.height+32]
        return
    end if
    if m.mode <> "detail" then return
    bounds = m.description.localBoundingRect()
    height = bounds.height
    if m.description.text = "" then height = 0
    if height > 128 then height = 128
    m.detailActions.translation = [380,276+height+28]
    m.detailCredits.translation = [380,276+height+108]
end sub

' Only visible cards plus one lookahead column request metadata, one at a time.
sub uiQueueCardArtwork()
    if m.artworkTimer = invalid then return
    m.artworkTimer.control = "stop"
    m.artworkTimer.control = "start"
end sub

function uiVisibleArtwork() as object
    nodes = []
    root = invalid
    position = [0,0]
    columns = 5
    visibleRows = 2
    if m.mode = "home"
        root = m.homeRoot
        position = m.homeRows.rowItemFocused
        if m.homeExpanded <> true then visibleRows = 3
    else if m.mode = "searchall"
        root = m.searchPanel.results
        position = m.searchPanel.position
        columns = 4
    else if m.posterGrid.visible and m.posterGrid.content <> invalid
        first = int(m.posterGrid.itemFocused/4)*4
        for i = first to first+11
            node = m.posterGrid.content.getChild(i)
            if node <> invalid then nodes.push(node)
        end for
        return nodes
    end if
    if root = invalid then return nodes
    if position = invalid or position.count() <> 2 then position = [0,0]
    for r = position[0] to position[0]+visibleRows-1
        row = root.getChild(r)
        if row <> invalid
            first = 0
            if r = position[0] then first = position[1]
            for c = first to first+columns-1
                node = row.getChild(c)
                if node <> invalid then nodes.push(node)
            end for
        end if
    end for
    return nodes
end function

sub uiLoadCardArtwork()
    if m.homeInitialLoading = true then return
    if m.mode = "home" and m.homeExpanded = true then homeHero()
    if m.uiArtworkInflight = invalid then m.uiArtworkInflight = {}
    if m.queue.count() >= 20
        uiQueueCardArtwork()
        return
    end if
    issued = 0
    for each node in uiVisibleArtwork()
        if node.mediaType <> "live" and Txt(node.metadataId) <> ""
            path = node.metadataPath
            if Txt(m.uiLandscapeCache[path]) <> "" then node.HDPosterUrl = m.uiLandscapeCache[path]
            needsMetadata = node.HDPosterUrl = ""
            if m.mode = "home" and m.homeExpanded = true
                current = homeCurrent()
                if current <> invalid
                    if PresentationMetadataId(current) = node.metadataId and Txt(current.type) = node.mediaType then needsMetadata = true
                end if
            end if
            if needsMetadata and not m.uiArtworkTried.doesExist(path)
                if m.uiArtworkOrder.count() >= 96 then m.uiArtworkTried.delete(m.uiArtworkOrder.shift())
                m.uiArtworkOrder.push(path)
                m.uiArtworkTried[path] = true
                m.uiArtworkSequence++
                tag = "uicard:" + m.uiArtworkSequence.toStr()
                m.uiArtworkInflight[tag] = {tag:tag,path:path,node:node,id:node.metadataId,mediaType:node.mediaType}
                request("GET",path,invalid,tag)
                issued++
                if issued >= 3 then exit for
            end if
        end if
    end for
end sub

sub uiCardArtworkResponse(tag as string,result as object)
    owner = m.uiArtworkInflight[tag]
    if owner = invalid or owner.tag <> tag then return
    m.uiArtworkInflight.delete(tag)
    if result.ok and result.data <> invalid and result.data.meta <> invalid
        meta = result.data.meta
        uri = PresentationBackdrop(meta)
        if Txt(meta.id) = owner.id
            if m.uiHeroMetadata = invalid then m.uiHeroMetadata = {}
            if m.uiLandscapeOrder.count() >= 96 then m.uiHeroMetadata.delete(m.uiLandscapeOrder[0])
            details = {}
            for each field in ["background","backdrop","description","overview","genres","runtime","releaseInfo"]
                if meta[field] <> invalid then details[field] = meta[field]
            end for
            m.uiHeroMetadata[owner.path] = details
            if m.uiLandscapeOrder.count() >= 96 then m.uiLandscapeCache.delete(m.uiLandscapeOrder.shift())
            m.uiLandscapeOrder.push(owner.path)
            m.uiLandscapeCache[owner.path] = uri
            if uri <> "" then owner.node.HDPosterUrl = uri
            uiHomeArtwork(owner.id,owner.mediaType,uri)
            if m.mode = "searchall"
                root = m.searchPanel.results
                if root <> invalid
                    for r = 0 to root.getChildCount()-1
                        row = root.getChild(r)
                        for c = 0 to row.getChildCount()-1
                            node = row.getChild(c)
                            if node.metadataPath = owner.path and uri <> "" then node.HDPosterUrl = uri
                        end for
                    end for
                end if
            end if
            if m.mode = "home" and m.homeExpanded = true
                current = homeCurrent()
                if current <> invalid and PresentationMetadataId(current) = owner.id then homeHero()
            end if
        end if
    end if
    uiQueueCardArtwork()
end sub

sub uiSourceFilterChip()
    name = "All providers"
    for each source in Bounded(m.streams,320)
        if Txt(m.sourceFilter) <> "" and SourceProviderKey(source) = m.sourceFilter then name = SourceProviderName(source)
    end for
    if m.sourceFilters.content = invalid
        root = CreateObject("roSGNode","ContentNode")
        node = root.createChild("ContentNode")
        node.addFields({dropdown:true,selected:false,uiOwnerFocused:false})
        m.sourceFilters.content = root
    end if
    node = m.sourceFilters.content.getChild(0)
    node.title = name
    node.selected = Txt(m.sourceFilter) <> ""
end sub

sub uiSourceFilterSelected()
    choices = [{name:"All providers",value:""}]
    seen = {}
    for each source in Bounded(m.streams,320)
        key = SourceProviderKey(source)
        if not seen.doesExist(key)
            seen[key] = true
            choices.push({name:SourceProviderName(source),value:key})
        end if
    end for
    uiOpenChoice("sourceProvider","Filter sources",choices)
end sub

sub uiUpdateSources(values as object, reset = false as boolean)
    filtered = []
    for each source in Bounded(values,320)
        if Txt(m.sourceFilter) = "" or SourceProviderKey(source) = m.sourceFilter
            item = {}
            item.append(source)
            if item.sourceEpoch = invalid then item.sourceEpoch = m.sourcesAt
            if m.sourceHintCache = invalid then m.sourceHintCache = {}
            key = Txt(item.id)
            if not m.sourceHintCache.doesExist(key) then m.sourceHintCache[key] = SourceLanguageScore(item)
            item.audioEvidenceScore = m.sourceHintCache[key]
            filtered.push(item)
        end if
    end for
    ranked = []
    caps = invalid
    if m.config <> invalid then caps = m.config.capabilities
    for each item in filtered
        match = SourceMatch(item,caps,m.sourcePreferences)
        item.matchRank = match.rank
        item.likelyDirect = match.likely
        item.bestMatch = false
        item.bestCandidate = match.best
    end for
    for rank = 0 to 95
        for each item in filtered
            if item.matchRank = rank then ranked.push(item)
        end for
    end for
    ' Keep the existing order during incremental delivery, then append ranked
    ' newcomers. A focused row never jumps when a faster addon finishes late.
    if not reset and m.items <> invalid
        stable = []
        used = {}
        for each old in m.items
            for each item in ranked
                if Txt(item.id) = Txt(old.id)
                    stable.push(item)
                    used[Txt(item.id)] = true
                    exit for
                end if
            end for
        end for
        for each item in ranked
            if not used.doesExist(Txt(item.id)) then stable.push(item)
        end for
        ranked = stable
    end if
    filtered = ranked
    for each item in filtered
        if item.bestCandidate = true
            item.bestMatch = true
            exit for
        end if
    end for
    focusedId = ""
    oldIndex = m.sourceList.itemFocused
    if oldIndex >= 0 and oldIndex < m.items.count() then focusedId = Txt(m.items[oldIndex].id)
    root = m.sourceList.content
    samePrefix = root <> invalid and not reset
    previousCount = m.items.count()
    if filtered.count() < previousCount then samePrefix = false
    if samePrefix
        for i = 0 to previousCount-1
            if Txt(m.items[i].id) <> Txt(filtered[i].id) then samePrefix = false
        end for
    end if
    m.listFocusTimer.control = "stop"
    m.listUpdating = false
    if not samePrefix then root = CreateObject("roSGNode","ContentNode")
    startAt = root.getChildCount()
    for i = 0 to startAt-1
        node = root.getChild(i)
        badges = SourceBadges(filtered[i],m.playItem)
        if node.sourceBadges <> badges then node.sourceBadges = badges
    end for
    for i = startAt to filtered.count()-1
        item = filtered[i]
        node = root.createChild("ContentNode")
        node.title = CreateObject("roRegex",chr(10),"").replaceAll(ReadableSourceText(OriginalSourceName(item))," · ")
        node.description = SourceCardText(item)
        node.addFields({sourceBadges:SourceBadges(item,m.playItem),uiWidth:1096,uiHeight:216,uiOwnerFocused:m.sourceList.hasFocus()})
    end for
    m.items = filtered
    if not samePrefix
        m.sourceList.content = root
        if not reset and focusedId <> ""
            for i = 0 to filtered.count()-1
                if Txt(filtered[i].id) = focusedId then m.sourceList.jumpToItem = i
            end for
        end if
    end if
    m.sourceList.visible = filtered.count() > 0
    if reset and filtered.count() > 0 then m.sourceList.jumpToItem = 0
    if filtered.count() = 0 and m.sourceList.hasFocus() then m.sourceFilters.setFocus(true)
    uiSourceHeader()
    if filtered.count() = 0 and m.discoveryDone = true
        uiEmpty("No sources from this provider","Choose another provider above.")
    end if
    uiFocusChanged()
end sub

sub uiResumeAction(event as object)
    held = event.getData().held = true
    if m.homeActions.hasFocus()
        item = homeCurrent()
        if item = invalid then return
        context = StreamContext(item)
        if held and queueMenu() then return
        if held and m.homeActions.itemFocused = 0 and item.type <> "live" and (item.type <> "series" or context.episode <> invalid)
            findStreams(item,true)
        else
            uiHomeActionSelected()
        end if
    else if m.detailActions.hasFocus()
        index = m.detailActions.itemFocused
        if index < 0 or index >= m.items.count() then return
        if held and m.items[index].action = "play"
            findStreams(m.selected,true)
        else
            selectItem(m.items[index])
        end if
    end if
end sub
