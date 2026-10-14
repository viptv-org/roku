' Render server-ranked results by the categories carried by the host cards.
sub engineSearchResponse(result as object)
    if m.mode <> "searchall" then return
    m.searchPending = 0
    m.searchInFlight = 0
    m.searchSections = []
    if not result.ok
        m.searchErrors = 1
        searchRender()
        return
    end if
    groups = {}
    for each item in Bounded(result.data.metas,200)
        key = Txt(item.type)
        if Txt(item.category) = "anime" then key = "anime"
        if not groups.doesExist(key)
            label = "TV Shows"
            if key = "movie" then label = "Movies"
            if key = "anime" then label = "Anime"
            section = {name:label,kind:Txt(item.type),items:[],done:true}
            groups[key] = section
            m.searchSections.push(section)
        end if
        groups[key].items.push(item)
    end for
    searchRender()
end sub
