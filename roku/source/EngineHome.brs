function EngineQuery(action as dynamic, key as string) as string
    if not AccountIsObject(action) or not EngineIsArray(action.query) then return ""
    for each value in action.query
        if AccountIsObject(value) and Txt(value.id) = key
            if EngineIsArray(value.values) and value.values.count() = 1 then return Txt(value.values[0])
        end if
    end for
    return ""
end function

function EngineCatalogs(home as dynamic) as object
    output = []
    if not AccountIsObject(home) or not EngineIsArray(home.rows) then return output
    for each row in home.rows
        if AccountIsObject(row) and AccountIsObject(row.browse)
            if row.browse.target = "Discover"
                kind = EngineQuery(row.browse,"type")
                catalog = EngineQuery(row.browse,"catalog")
                if kind <> "" and catalog <> ""
                    value = {id:catalog,type:kind,name:Txt(row.title),supports_search:true,supports_skip:true,extra:[],genres:[],engine_cards:EngineCards(row.cards),engine_ready:row.state = "Ready",engine_next:row.next_cursor}
                    addon = EngineQuery(row.browse,"addon_id")
                    if addon <> "" then value.addon_id = addon
                    output.push(value)
                end if
            end if
        end if
    end for
    return output
end function

function EngineQueue(page as dynamic) as dynamic
    if not AccountIsObject(page) or not EngineIsArray(page.entries) then return invalid
    items = []
    for each entry in page.entries
        item = EngineContinuation(entry)
        if item <> invalid then items.push(item)
    end for
    nextOffset = invalid
    if page.next_cursor <> invalid then nextOffset = val(Txt(page.next_cursor))
    total = items.count()
    if nextOffset <> invalid then total = nextOffset + 1
    return {items:items,offset:0,total:total,next_offset:nextOffset}
end function

function EngineBootstrap(data as dynamic) as dynamic
    if not AccountIsObject(data) or not AccountIsObject(data.identity) then return invalid
    if not AccountIsObject(data.home) or not AccountIsObject(data.library) then return invalid
    queue = EngineQueue(data.continuation)
    if queue = invalid then return invalid
    membership = []
    if AccountIsObject(data.library_membership) and EngineIsArray(data.library_membership.identities) then membership = data.library_membership.identities
    subtitles = false
    if AccountIsObject(data.subtitle_availability) then subtitles = data.subtitle_availability.available = true
    return {queue:queue,favorites:EngineCards(data.library.cards),membership:membership,catalogs:EngineCatalogs(data.home),hero:EngineCard(data.home.hero),profile_id:Txt(data.identity.profile_id),subtitles_available:subtitles}
end function

function EngineRequestCopy(request as object) as object
    copy = {}
    copy.append(request)
    return copy
end function
