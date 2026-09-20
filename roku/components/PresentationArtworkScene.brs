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
        if Txt(m.sourceFilter) <> "" and SourceGroup(source) = m.sourceFilter then name = SourceProviderName(source)
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
        key = SourceGroup(source)
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
        if Txt(m.sourceFilter) = "" or SourceGroup(source) = m.sourceFilter
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
