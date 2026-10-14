function EnginePersonalRequest(request as object, result as object, method as string) as dynamic
    path = Txt(request.path)
    route = path.split("?")[0]
    parts = route.split("/")
    if parts.count() < 6 or parts[1] <> "api" or parts[2] <> "profiles" then return invalid
    if parts[4] <> "continue" then return invalid
    resource = parts[5]
    if resource <> "page" and resource <> "next" and resource <> "visibility" then return invalid
    if left(Txt(request.base),8) <> "https://"
        result.error = "The viewing server requires HTTPS."
        return result
    end if
    wire = EngineRequestCopy(request)
    prefix = "/api/v3/profiles/" + parts[3] + "/continue"
    if resource = "page"
        if method <> "GET" then return invalid
        wire.path = prefix + mid(path,len(route)+1)
    else
        if method <> "POST" and method <> "PUT" then return invalid
        wire.path = prefix + "/" + resource
        wire.body = EngineContinuationBody(request.body)
        if wire.body = invalid
            result.error = "The selected episode identity is incomplete."
            return result
        end if
        if resource = "visibility" then wire.body.hidden = request.body.hidden
    end if
    response = HttpRequestRaw(wire,result,method,false)
    if not response.ok then return response
    data = response.data
    if resource = "page"
        response.data = EngineQueue(data)
        if response.data <> invalid then response.data.offset = val(EngineUrlParameter(path,"offset"))
    else if resource = "next"
        if AccountIsObject(data)
            status = lcase(Txt(data.status))
            if data.status = "CaughtUp" then status = "caught_up"
            response.data = {status:status,item:EngineCard(data.item)}
        else
            response.data = invalid
        end if
    else
        if AccountIsObject(data) and GetInterface(data.hidden,"ifBoolean") <> invalid then response.data = {ok:true,hidden:data.hidden} else response.data = invalid
    end if
    if response.data = invalid
        response.ok = false
        response.error = "The server returned invalid viewing data."
    end if
    return response
end function

function EngineContinuationBody(item as dynamic) as dynamic
    if not AccountIsObject(item) or Txt(item.id) = "" then return invalid
    if Txt(item.type) <> "series" and Txt(item.type) <> "movie" then return invalid
    identity = {id:item.id,kind:item.type,ids:[],episode:invalid,edition:invalid}
    parent = invalid
    if ApiIsNumber(item.episode)
        identity.episode = {order:"aired",season:item.season,episode:item.episode}
        if Txt(item.series_id) <> "" then parent = {id:item.series_id,kind:"series",ids:[],episode:invalid,edition:invalid}
    end if
    if AccountIsObject(item.engine_card)
        identity = item.engine_card.identity
        parent = item.engine_card.parent_identity
    end if
    return {identity:identity,parent_identity:parent}
end function

function EngineUrlParameter(path as string, key as string) as string
    parts = path.split("?")
    if parts.count() <> 2 then return ""
    for each pair in parts[1].split("&")
        fields = pair.split("=")
        if fields.count() = 2 and fields[0] = key then return fields[1]
    end for
    return ""
end function
