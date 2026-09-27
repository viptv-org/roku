' Lazy Stremio shelves. Descriptor order is stable; only the viewport window owns payloads.
sub homeUseCatalogs(result as object)
    if not result.ok
        m.homeDone.catalogs = true
        return
    end if
    if m.homeCatalogs <> invalid then return
    m.homeCatalogs = []
    m.homeCatalogPending = {}
    m.homeCatalogSerial = 0
    seen = {}
    for each catalog in Bounded(result.data,2048)
        identity = Txt(catalog.addon_id)+"|"+Txt(catalog.type)+"|"+Txt(catalog.id)
        if Txt(catalog.id) <> "" and Txt(catalog.type) <> "" and not seen.doesExist(identity)
            seen[identity] = true
            title = Txt(catalog.name,Txt(catalog.id))
            if Txt(catalog.addon_name) <> "" then title = Txt(catalog.addon_name)+" · "+title
            entry = {catalog:catalog,title:title,loaded:false,failed:false,empty:false,nextSkip:0,column:0}
            index = m.homeCatalogs.count()+7
            m.homeCatalogs.push(entry)
            m.homeData.push(homeCatalogPlaceholder(index))
            m.homeStates.push("Loading catalog…")
            m.homeFailed.push(false)
            m.homeRoot.appendChild(homeRow(index))
            m.homeRowKeys.push(index)
        end if
    end for
    m.homeDone.catalogs = true
    homeCatalogPump(true)
end sub

function homeCatalogPlaceholder(index as integer) as object
    values = []
    for i = 0 to 4
        values.push({name:"",action:"homecatalogload",homeCatalog:index,description:"",uiSkeleton:true})
    end for
    return values
end function

sub homeCatalogReplace(index as integer)
    for position = 0 to m.homeRowKeys.count()-1
        if m.homeRowKeys[position] = index
            m.homeRestoring = true
            if m.homeData[index].count() = 0
                m.homeRoot.removeChildIndex(position)
                m.homeRowKeys.delete(position)
            else
                m.homeRoot.replaceChild(homeRow(index),position)
            end if
            homeRestore()
            exit for
        end if
    end for
end sub

sub homeCatalogPump(advanceWindow = false as boolean)
    if m.mode <> "home" or m.homeCatalogs = invalid or m.homeRowKeys = invalid then return
    if m.homeCatalogPending = invalid then m.homeCatalogPending = {}
    current = 0
    for i = 0 to m.homeRowKeys.count()-1
        if m.homeRowKeys[i] = m.homePosition[0] then current = i
    end for
    visible = 3
    if m.homeExpanded = true then visible = 1
    first = current-1
    if first < 0 then first = 0
    last = current+visible
    if last >= m.homeRowKeys.count() then last = m.homeRowKeys.count()-1
    if advanceWindow or m.homeCatalogWindowEnd = invalid then m.homeCatalogWindowEnd = m.homeRowKeys[last]
    while last > current and HomeShelfRank(m.homeRowKeys[last]) > HomeShelfRank(m.homeCatalogWindowEnd)
        last--
    end while
    keep = {}
    for i = first to last
        keep[m.homeRowKeys[i].toStr()] = true
    end for
    ' Cancel superseded reads as well as dropping their owners.
    obsolete = []
    for each tag in m.homeCatalogPending
        owner = m.homeCatalogPending[tag]
        if not keep.doesExist(owner.index.toStr()) then obsolete.push(tag)
    end for
    for each tag in obsolete
        for each task in m.tasks
            if left(Txt(task.request.tag),len(tag)+1) = tag+"|" then task.cancel = true
        end for
        retained = []
        for each requestEntry in m.queue
            if left(Txt(requestEntry.tag),len(tag)+1) <> tag+"|" then retained.push(requestEntry)
        end for
        m.queue = retained
        m.homeCatalogPending.delete(tag)
    end for
    for i = 0 to m.homeCatalogs.count()-1
        index = i+7
        entry = m.homeCatalogs[i]
        if entry.loaded and not entry.empty and not keep.doesExist(index.toStr())
            entry.loaded = false
            entry.nextSkip = 0
            m.homeData[index] = homeCatalogPlaceholder(index)
            homeCatalogReplace(index)
        end if
    end for
    occupied = m.homeCatalogPending.count()
    for each task in m.tasks
        tag = Txt(task.request.tag).split("|")[0]
        if task.state = "run" and left(tag,12) = "homecatalog:" and not m.homeCatalogPending.doesExist(tag) then occupied++
    end for
    for position = current to last
        index = m.homeRowKeys[position]
        if index >= 7
            entry = m.homeCatalogs[index-7]
            active = false
            for each tag in m.homeCatalogPending
                if m.homeCatalogPending[tag].index = index then active = true
            end for
            if index = m.homePosition[0] then entry.column = m.homePosition[1]
            more = entry.loaded and entry.nextSkip <> invalid and index = m.homePosition[0] and m.homePosition[1] >= m.homeData[index].count()-5
            if not active and not entry.failed and not entry.empty and (not entry.loaded or more) and occupied < 2
                catalog = entry.catalog
                missing = DiscoverMissingOption(catalog,"","",{})
                if missing <> ""
                    entry.loaded = true
                    entry.nextSkip = invalid
                    m.homeData[index] = [{name:"Choose "+missing,action:"homecatalogfilter",homeCatalog:index,description:"Open this catalog's filters to browse."}]
                    homeCatalogReplace(index)
                else
                    skip = 0
                    if entry.loaded then skip = entry.nextSkip
                    m.homeCatalogSerial++
                    tag = "homecatalog:"+m.homeCatalogSerial.toStr()
                    m.homeCatalogPending[tag] = {index:index,skip:skip,scope:m.homeKeyValue}
                    path = "/api/discover?type="+Enc(Txt(catalog.type))+"&addon_id="+Enc(Txt(catalog.addon_id))+"&catalog="+Enc(Txt(catalog.id))+"&skip="+skip.toStr()
                    occupied++
                    request("GET",path,invalid,tag)
                end if
            end if
        end if
    end for
end sub

sub homeCatalogResponse(tag as string, result as object)
    if m.mode <> "home" or m.homeCatalogPending = invalid then return
    owner = m.homeCatalogPending[tag]
    if owner = invalid then return
    m.homeCatalogPending.delete(tag)
    if owner.scope <> m.homeKeyValue then return
    index = owner.index
    entry = m.homeCatalogs[index-7]
    if not result.ok
        entry.failed = true
        m.homeData[index] = [{name:"Retry "+Txt(entry.catalog.name,"catalog"),action:"homecatalogretry",homeCatalog:index,description:"This catalog couldn't load. Select to try again."}]
    else
        values = []
        if owner.skip > 0 then values = m.homeData[index]
        seen = {}
        for each item in values
            seen[Txt(item.type)+"|"+Txt(item.id)] = true
        end for
        added = 0
        for each item in Bounded(result.data.metas,200)
            key = Txt(item.type,Txt(entry.catalog.type))+"|"+Txt(item.id)
            if Txt(item.id) <> "" and not seen.doesExist(key)
                item.type = Txt(item.type,Txt(entry.catalog.type))
                values.push(item)
                seen[key] = true
                added++
            end if
        end for
        entry.loaded = true
        entry.empty = values.count() = 0
        entry.nextSkip = invalid
        if added > 0 and result.data.has_more = true and result.data.next_skip <> invalid
            if result.data.next_skip > owner.skip then entry.nextSkip = result.data.next_skip
        end if
        m.homeData[index] = values
        if m.homePosition[0] = index then m.homePosition[1] = RestoreCardIndex(entry.column,values.count())
    end if
    homeCatalogReplace(index)
    homeHero()
    homeCatalogPump()
end sub

sub homeCatalogAction(item as object)
    index = item.homeCatalog
    if index = invalid or m.homeCatalogs = invalid then return
    if item.action = "homecatalogfilter"
        catalog = m.homeCatalogs[index-7].catalog
        saveView()
        cancelBrowse()
        m.discoverActive = true
        m.discoverType = Txt(catalog.type)
        m.discoverCatalogs = []
        for each entry in m.homeCatalogs
            m.discoverCatalogs.push(entry.catalog)
        end for
        m.catalog = catalog
        m.discoverGenre = ""
        m.discoverExtras = {}
        m.search = ""
        m.offsetHistory = []
        browse(m.discoverType,0)
    else
        m.homeCatalogs[index-7].failed = false
        m.homeCatalogs[index-7].loaded = false
        m.homeData[index] = homeCatalogPlaceholder(index)
        homeCatalogReplace(index)
        homeCatalogPump()
    end if
end sub
