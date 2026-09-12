' One startup transaction: settle shelves, visible metadata, then image textures.
' Cached Home returns never acquire this cover; unavailable services have a deadline.
sub initStartup()
    m.startupReadyTimer = m.top.findNode("startupReadyTimer")
    m.startupReadyTimer.observeField("fire","startupReadyTick")
    m.startupText = m.top.findNode("startupText")
    m.homeInitialLoading = false
end sub

sub startupStatus(text as string)
    if m.startupText <> invalid then m.startupText.text = text
end sub

sub startupHomeBegin()
    m.homeInitialLoading = true
    m.startupScope = m.homeKeyValue
    m.startupClock = CreateObject("roTimespan")
    m.startupArtPending = {}
    m.startupArtStarted = false
    m.startupArtSequence = 0
    m.startupStable = 0
    m.authLoading.visible = true
    m.authLoadingSpinner.control = "start"
    startupStatus("Loading your library…")
    m.startupReadyTimer.control = "start"
end sub

sub startupCancel()
    m.homeInitialLoading = false
    if m.startupReadyTimer <> invalid then m.startupReadyTimer.control = "stop"
    m.startupArtPending = {}
end sub

function startupVisibleCards() as object
    result = []
    if m.homeRoot = invalid or m.homeRowKeys.count() = 0 then return result
    ' Hero + first shelf are visible on entry. One lookahead card is included.
    row = m.homeRoot.getChild(0)
    if row <> invalid
        for i = 0 to 4
            node = row.getChild(i)
            if node <> invalid then result.push(node)
        end for
    end if
    return result
end function

sub startupReadyTick()
    if m.homeInitialLoading <> true then return
    if m.mode <> "home" or m.homeKeyValue <> m.startupScope
        startupCancel()
        return
    end if
    elapsed = m.startupClock.totalMilliseconds()
    ' One budget includes shelf requests, metadata and decoded visible artwork.
    ' Leave room for native launch before Roku's 15-second launch target.
    deadline = 12000
    if m.homeDone.count() < 7
        startupStatus("Loading your library · " + m.homeDone.count().toStr() + " of 7")
        if elapsed < deadline then return
        ' Freeze timed-out shelves as failed; late responses cannot move the first view.
        for each kind in ["progress","movie","series","live","favorites","livefavorites","recent"]
            if not m.homeDone.doesExist(kind) then homeResponse(kind,{ok:false})
        end for
    end if
    if not m.startupArtStarted
        m.startupArtStarted = true
        homeDefaultShelf()
        homeRestore()
        homeHero()
        for each node in startupVisibleCards()
            if elapsed < deadline and node.mediaType <> "live" and Txt(node.metadataId) <> ""
                path = node.metadataPath
                current = homeCurrent()
                hero = false
                if current <> invalid then hero = PresentationMetadataId(current) = node.metadataId
                if node.HDPosterUrl = "" or hero
                    if not m.uiArtworkTried.doesExist(path)
                        m.uiArtworkTried[path] = true
                        m.uiArtworkOrder.push(path)
                        m.startupArtSequence++
                        tag = "startupArt:" + m.startupArtSequence.toStr()
                        m.startupArtPending[tag] = {tag:tag,path:path,node:node,id:node.metadataId,mediaType:node.mediaType}
                        request("GET",path,invalid,tag)
                    end if
                end if
            end if
        end for
    end if
    if m.startupArtPending.count() > 0 and elapsed < deadline
        startupStatus("Finding artwork · " + m.startupArtPending.count().toStr() + " remaining")
        return
    end if
    ' Discard stale metadata owners at the deadline, without changing later navigation.
    if elapsed >= deadline then m.startupArtPending = {}
    pending = 0
    for each node in startupVisibleCards()
        if node.HDPosterUrl <> ""
            if not node.hasField("artState")
                pending++
            else if node.artState <> "ready" and node.artState <> "failed"
                pending++
            end if
        end if
    end for
    if m.homeHeroPanel.artState = "loading" then pending++
    if pending > 0 and elapsed < deadline
        startupStatus("Loading images · " + pending.toStr() + " remaining")
        m.startupStable = 0
        return
    end if
    ' Two rendered timer turns prevent the cover and the final texture changing together.
    m.startupStable++
    startupStatus("Ready")
    if m.startupStable < 2 then return
    startupCancel()
    accountEndLoading()
    if acknowledgementMayFocus() then uiHomeFocus()
    uiQueueCardArtwork()
end sub

sub startupArtworkResponse(tag as string, result as object)
    if m.homeInitialLoading <> true or m.startupArtPending = invalid then return
    owner = m.startupArtPending[tag]
    if owner = invalid then return
    m.startupArtPending.delete(tag)
    ' Reuse the normal identity-checked metadata/cache adapter.
    if m.uiArtworkInflight = invalid then m.uiArtworkInflight = {}
    m.uiArtworkInflight[owner.tag] = owner
    uiCardArtworkResponse(tag,result)
end sub
