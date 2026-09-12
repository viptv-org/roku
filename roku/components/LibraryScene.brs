' Library operations share the scene's bounded queue and generation ownership.
sub openLibraryPage(offset = 0 as integer)
    cancelBrowse()
    m.collection = "favorites"
    m.libraryOffset = offset
    if m.libraryOffset < 0 then m.libraryOffset = 0
    rows("My List",[],"collection","Loading…")
    request("GET","/api/profiles/"+Enc(m.profile)+"/favorites/page?limit=40&offset="+m.libraryOffset.toStr(),invalid,"librarypage")
end sub

function libraryResponse(tag as string,result as object) as boolean
    if tag = "episoderefresh"
        if m.mode = "episodes" then applyEpisodeProgress(result,true)
        return true
    end if
    if tag = "librarypage"
        if not result.ok
            rows("My List",[{name:"Try again",action:"librarypage",offset:m.libraryOffset}],"collection","Could not load My List.")
            return true
        end if
        items = Bounded(result.data.items,40)
        if items.count() = 0 and m.libraryOffset > 0 then openLibraryPage(m.libraryOffset-40) : return true
        if result.data.offset > 0 then items.unshift({name:"Previous page",action:"librarypage",offset:result.data.offset-40})
        if result.data.next_offset <> invalid then items.push({name:"Next page",action:"librarypage",offset:result.data.next_offset})
        rows("My List",items,"collection","Hold OK or press * to remove a title")
        if m.libraryRestoreIndex <> invalid
            m.list.jumpToItem = RestoreCardIndex(m.libraryRestoreIndex,items.count())
            m.libraryRestoreIndex = invalid
        end if
        return true
    end if
    if tag = "librarycorrected"
        if result.ok
            m.homeDirty = true
            m.status.text = "Viewing progress updated."
            if m.mode = "episodes" then request("GET","/api/profiles/"+Enc(m.profile)+"/progress/series?series_id="+Enc(Txt(m.selected.id)),invalid,"episoderefresh")
        else
            m.status.text = "Could not update progress. Try again."
        end if
        return true
    end if
    return false
end function

function libraryMenu() as boolean
    if m.list = invalid or not m.list.hasFocus() then return false
    index = m.list.itemFocused
    if index < 0 or index >= m.items.count() then return false
    item = m.items[index]
    if item.action <> invalid then return false
    if m.mode = "collection" and m.collection = "favorites"
        m.libraryItem = CopyRouteData(item)
        uiOpenChoice("libraryManage",Txt(item.name),[{name:"Remove from My List",action:"libraryremove"},{name:"Cancel",action:"cancel"}])
        return true
    end if
    if m.mode = "episodes"
        m.libraryItem = EpisodePresentationItem(m.selected,item)
        action = "watched" : label = "Mark watched"
        if item.watched = true then action = "unwatched" : label = "Mark unwatched"
        uiOpenChoice("libraryManage",Txt(item.title,Txt(item.name)),[{name:label,action:"librarycorrect",value:action},{name:"Watch from the beginning",action:"libraryrestart"},{name:"Cancel",action:"cancel"}])
        return true
    end if
    return false
end function

sub libraryCorrect(action as string)
    body = CopyRouteData(m.libraryItem)
    body.action = action
    request("PUT","/api/profiles/"+Enc(m.profile)+"/progress/correct",body,"librarycorrected")
end sub

sub retrySelectedPlayback()
    if m.playItem.type = "live"
        resetAttempts()
        beginPlayback(false)
        return
    end if
    item = CopyRouteData(m.playItem)
    if m.position > 0 then item.position = m.position
    if m.duration <> invalid then item.duration = m.duration
    preference = StableSourcePreference(item)
    if Txt(preference.source_fingerprint) = "" then preference = invalid
    findStreams(item,false,preference)
end sub
