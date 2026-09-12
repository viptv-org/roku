' Inline native input and bounded results, preserving each manifest catalog's identity.
sub initSearch()
    m.searchPanel = m.top.findNode("searchPanel")
    m.searchDelay = m.top.findNode("searchDelay")
    m.searchPanel.observeField("query","searchChanged")
    m.searchPanel.observeField("selected","searchSelected")
    m.searchDelay.observeField("fire","searchEverything")
end sub

sub searchOpen(value as string)
    m.searchOpening = true
    m.searchScope = Txt(m.mediaType)
    m.searchCatalog = m.catalog
    rows("Search",[],"searchall","")
    m.search = value
    m.searchPanel.query = value
    m.searchPanel.results = CreateObject("roSGNode","ContentNode")
    m.emptyState.visible = false
    m.searchPanel.status = "Find your next favorite."
    m.searchPanel.callFunc("open")
    m.searchOpening = false
    searchChanged()
end sub

sub searchChanged()
    if m.searchOpening = true or m.mode <> "searchall" then return
    cancelBrowse()
    m.search = m.searchPanel.query.trim()
    m.searchDelay.control = "stop"
    m.searchPanel.results = CreateObject("roSGNode","ContentNode")
    m.searchItems = []
    m.searchPanel.status = "Find your next favorite."
    if m.search <> ""
        m.searchPanel.status = "Searching…"
        m.searchDelay.control = "start"
    end if
end sub

sub searchEverything()
    if m.mode <> "searchall" or Txt(m.search).trim() = "" then return
    m.searchSections = []
    m.searchPending = 0
    m.searchInFlight = 0
    m.searchNext = 0
    m.searchErrors = 0
    request("GET","/api/catalogs",invalid,"searchcatalogs")
end sub

sub searchCatalogs(result as object)
    if m.mode <> "searchall" then return
    if result.ok
        for each catalog in Bounded(result.data,128)
            if catalog.supports_search = true and (catalog.type = "movie" or catalog.type = "series") and (m.searchScope <> "live") and (m.searchScope <> "movie" or catalog.type = "movie") and (m.searchScope <> "series" or catalog.type = "series")
                if m.searchCatalog = invalid or (Txt(catalog.id) = Txt(m.searchCatalog.id) and Txt(catalog.addon_id) = Txt(m.searchCatalog.addon_id))
                section = {name:Txt(catalog.addon_name) + " · " + Txt(catalog.name,Txt(catalog.id)),kind:Txt(catalog.type),items:[],done:false}
                m.searchSections.push(section)
                path = "/api/discover?type=" + Enc(section.kind) + "&addon_id=" + Enc(Txt(catalog.addon_id)) + "&catalog=" + Enc(Txt(catalog.id)) + "&skip=0&search=" + Enc(m.search)
                m.searchPending++
                if UiCatalogRequired(catalog,"genre") and Bounded(catalog.genres,64).count() > 0 then path += "&genre=" + Enc(Txt(catalog.genres[0]))
                section.path = path
                end if
            end if
        end for
    else
        m.searchErrors++
    end if
    if m.searchScope <> "movie" and m.searchScope <> "series"
    m.searchSections.push({name:"Live TV",kind:"live",items:[],done:false,path:"/api/live?view=us&offset=0&limit=80&search=" + Enc(m.search)})
    m.searchPending++
    end if
    searchRender()
    searchPump()
end sub

sub searchBatch(key as string, result as object)
    if m.mode <> "searchall" then return
    index = val(key)
    if index < 0 or index >= m.searchSections.count() then return
    section = m.searchSections[index]
    if section.done then return
    section.done = true
    m.searchPending--
    m.searchInFlight--
    if result.ok
        incoming = result.data.metas
        if section.kind = "live" then incoming = result.data.channels
        seen = {}
        for each item in Bounded(incoming,24)
            id = Txt(item.id)
            if id <> "" and not seen.doesExist(id)
                seen[id] = true
                item.type = section.kind
                if section.kind = "live" and item.now <> invalid then item.releaseInfo = "ON NOW · "+Txt(item.now.title)
                section.items.push(item)
            end if
        end for
    else
        m.searchErrors++
    end if
    searchRender()
    searchPump()
end sub

sub searchRender()
    root = CreateObject("roSGNode","ContentNode")
    m.searchRowKeys = []
    count = 0
    for i = 0 to m.searchSections.count()-1
        section = m.searchSections[i]
        if section.items.count() > 0
            row = root.createChild("ContentNode")
            row.title = section.name
            m.searchRowKeys.push(i)
            for each item in section.items
                node = row.createChild("ContentNode")
                UiCardContent(node,item)
                node.id = section.name + "|" + Txt(item.id)
                count++
            end for
        end if
    end for
    m.searchPanel.results = root
    uiQueueCardArtwork()
    m.searchPanel.status = count.toStr() + " results"
    if m.searchPending > 0
        m.searchPanel.status = "Searching…  " + count.toStr() + " results"
    else if count = 0
        m.searchPanel.status = "No results. Try another title."
    end if
    if m.searchErrors > 0 then m.searchPanel.status += "  Some sources couldn't load."
end sub

sub searchSelected()
    position = m.searchPanel.selected
    if position = invalid or m.searchRowKeys = invalid then return
    if position.count() <> 2 then return
    if position[0] < 0 or position[0] >= m.searchRowKeys.count() then return
    section = m.searchSections[m.searchRowKeys[position[0]]]
    if position[1] < 0 or position[1] >= section.items.count() then return
    selectItem(section.items[position[1]])
end sub

sub searchPump()
    while m.mode = "searchall" and m.searchInFlight < 3 and m.searchNext < m.searchSections.count()
        index = m.searchNext
        m.searchNext++
        if not m.searchSections[index].done
            m.searchInFlight++
            request("GET",m.searchSections[index].path,invalid,"searchall:" + index.toStr())
        end if
    end while
end sub

sub searchRestore(state as dynamic)
    if state = invalid
        searchOpen(Txt(m.search))
        return
    end if
    cancelBrowse()
    rows("Search",[],"searchall","")
    m.searchPanel.unobserveField("query")
    m.searchPanel.query = Txt(m.search)
    m.searchPanel.callFunc("open")
    m.searchPanel.observeField("query","searchChanged")
    m.searchSections = state.sections
    m.searchErrors = state.errors
    m.searchScope = state.scope
    m.searchCatalog = state.catalog
    m.searchPending = 0
    m.searchInFlight = 0
    m.searchNext = 0
    for each section in m.searchSections
        if not section.done then m.searchPending++
    end for
    searchRender()
    m.searchPanel.callFunc("focusResults",state.index)
    searchPump()
end sub
