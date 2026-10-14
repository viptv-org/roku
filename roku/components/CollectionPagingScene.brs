' One scoped page at a time; native grids retain the loaded content and focus during append.
sub collectionPage(result as object, title as string, help as string, action as string)
    if m.mode <> "collection" then return
    m.collectionLoading = false
    if not result.ok
        m.collectionRetryAfter = CreateObject("roDateTime").asSeconds() + 5
        if m.collectionAppending = true
            m.status.text = "Could not load more titles."
        else
            rows(title,[{name:"Try again",action:action,offset:0}],"collection","Could not load titles.")
        end if
        return
    end if
    values = []
    if m.collectionAppending = true and GetInterface(m.collectionItems,"ifArray") <> invalid then values.append(m.collectionItems)
    seen = {}
    for each item in values
        seen[Txt(item.type)+"|"+Txt(item.id)] = true
    end for
    for each item in Bounded(result.data.items,100)
        key = Txt(item.type)+"|"+Txt(item.id)
        if not seen.doesExist(key)
            values.push(item)
            seen[key] = true
        end if
    end for
    m.collectionItems = values
    m.collectionNextOffset = result.data.next_offset
    if m.collectionNextOffset <> invalid
        if m.collectionNextOffset <= result.data.offset then m.collectionNextOffset = invalid
    end if
    restore = m.collectionRestoreIndex
    if restore <> invalid and restore >= values.count() and m.collectionNextOffset <> invalid
        m.collectionAppending = true
        collectionMaybeLoad(true)
        return
    end if
    index = 0
    if m.collectionAppending = true then index = m.list.itemFocused
    if restore <> invalid then index = restore
    rows(title,values,"collection",help,m.collectionAppending <> true)
    if values.count() > 0 then m.list.jumpToItem = RestoreCardIndex(index,values.count())
    m.collectionRestoreIndex = invalid
    m.collectionAppending = true
    collectionMaybeLoad()
end sub

sub collectionMaybeLoad(force = false as boolean)
    if m.mode <> "collection" or m.collectionLoading = true or m.collectionNextOffset = invalid then return
    if m.collection <> "favorites" and m.collection <> "progress" then return
    if m.collectionRetryAfter <> invalid
        if CreateObject("roDateTime").asSeconds() < m.collectionRetryAfter then return
    end if
    count = 0
    if GetInterface(m.collectionItems,"ifArray") <> invalid then count = m.collectionItems.count()
    if not force and m.list.itemFocused < count-8 then return
    m.collectionLoading = true
    offset = m.collectionNextOffset.toStr()
    path = "/api/profiles/" + Enc(m.profile) + "/favorites/page"
    tag = "librarypage"
    if m.collection = "progress"
        path = continuationPath("page")
        tag = "queuepage"
    end if
    request("GET",path+"?limit=40&offset="+offset,invalid,tag)
end sub
