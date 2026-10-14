' Content transport only; authentication and opaque playback grants keep their established envelopes.
function EngineContentRequest(request as object, result as object, method as string) as dynamic
    if method <> "GET" then return invalid
    path = Txt(request.path)
    route = path.split("?")[0]
    target = ""
    if route = "/api/catalogs" then target = "/api/v3/bootstrap"
    if route = "/api/v3/bootstrap" then target = path
    if route = "/api/discover" then target = "/api/v3/discover" + mid(path,len(route)+1)
    if route = "/api/v3/discover" then target = path
    if left(route,10) = "/api/meta/" then target = "/api/v3/meta/" + mid(path,11)
    if target = "" then return invalid
    if left(Txt(request.base),8) <> "https://"
        result.error = "The viewing server requires HTTPS."
        return result
    end if
    wire = EngineRequestCopy(request)
    wire.path = target
    response = HttpRequestRaw(wire,result,method,false)
    if not response.ok then return response
    data = response.data
    projected = invalid
    if route = "/api/catalogs"
        if AccountIsObject(data) and AccountIsObject(data.home) then projected = EngineCatalogs(data.home)
    else if route = "/api/v3/bootstrap"
        projected = EngineBootstrap(data)
    else if route = "/api/discover" or route = "/api/v3/discover"
        if AccountIsObject(data) and ApiIsArray(data.cards)
            nextSkip = invalid
            if data.next_cursor <> invalid then nextSkip = val(Txt(data.next_cursor))
            projected = {metas:EngineCards(data.cards),has_more:nextSkip <> invalid,next_skip:nextSkip}
        end if
    else
        projected = EngineDetailPages(wire,response)
    end if
    if projected = invalid
        response.ok = false
        response.error = "The server returned invalid media data."
    end if
    response.data = projected
    return response
end function

function EngineDetailPages(request as object, response as object) as dynamic
    value = response.data
    if not AccountIsObject(value) or not ApiIsArray(value.episodes) then return invalid
    item = EngineCard(value.item)
    if item = invalid then return invalid
    item.videos = EngineCards(value.episodes)
    cursor = Txt(value.next_cursor)
    seen = {}
    for each episode in item.videos
        seen[episode.id] = true
    end for
    prior = -1
    while cursor <> ""
        if not CreateObject("roRegex","^[0-9]{1,6}$","").isMatch(cursor) then return invalid
        offset = val(cursor)
        if offset <= prior or offset > 100000 or m.top.cancel then return invalid
        prior = offset
        pageRequest = EngineRequestCopy(request)
        pageRequest.path = request.path.split("?")[0] + "?offset=" + cursor + "&limit=128"
        page = HttpRequestRaw(pageRequest,{ok:false,status:0,error:"",data:invalid},"GET",false)
        if not page.ok or not AccountIsObject(page.data) then return invalid
        if not AccountIsObject(page.data.item) then return invalid
        if not EngineSameIdentity(item.engine_identity,page.data.item.identity) then return invalid
        if Txt(value.item.provider_id) <> Txt(page.data.item.provider_id) then return invalid
        if not ApiIsArray(page.data.episodes) then return invalid
        for each episode in EngineCards(page.data.episodes)
            if not seen.doesExist(episode.id)
                seen[episode.id] = true
                item.videos.push(episode)
            end if
        end for
        cursor = Txt(page.data.next_cursor)
    end while
    return {meta:item,recommendations:EngineCards(value.recommendations)}
end function
