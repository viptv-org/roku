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
