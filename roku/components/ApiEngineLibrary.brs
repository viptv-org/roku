function EngineLibraryRequest(request as object, result as object, method as string) as dynamic
    path = Txt(request.path)
    route = path.split("?")[0]
    parts = route.split("/")
    if parts.count() < 5 or parts[1] <> "api" or parts[2] <> "profiles" or parts[4] <> "favorites" then return invalid
    if AccountIsObject(request.body) and request.body.type = "live" then return invalid
    if parts.count() = 7 and parts[5] = "live" then return invalid
    if left(Txt(request.base),8) <> "https://"
        result.error = "The viewing server requires HTTPS."
        return result
    end if
    wire = EngineRequestCopy(request)
    prefix = "/api/v3/profiles/" + parts[3] + "/library"
    pageRead = method = "GET" and (parts.count() = 5 or (parts.count() = 6 and parts[5] = "page"))
    if pageRead
        offset = EngineUrlParameter(path,"offset") : limit = EngineUrlParameter(path,"limit")
        if offset = "" then offset = "0"
        if limit = "" then limit = "100"
        wire.path = prefix + "?offset=" + offset + "&limit=" + limit
    else if method = "DELETE" and parts.count() = 7
        wire.path = prefix + "/" + parts[5] + "/" + parts[6]
    else if method = "PUT" and parts.count() = 5
        wire.path = prefix
        card = EngineLibraryCard(request.body)
        if card = invalid then return invalid
        wire.body = {card:card}
    else if method = "POST" and parts.count() = 6 and parts[5] = "toggle"
        return EngineLibraryToggle(request,result,prefix)
    else
        return invalid
    end if
    response = HttpRequestRaw(wire,result,method,false)
    if not response.ok then return response
    if pageRead
        if not AccountIsObject(response.data) or not ApiIsArray(response.data.cards)
            response.ok = false
            response.error = "The server returned invalid library data."
        else
            items = EngineCards(response.data.cards)
            cursor = response.data.next_cursor
            if parts.count() = 5
                response.data = items
            else
                nextOffset = invalid : total = val(offset) + items.count()
                if cursor <> invalid then nextOffset = val(Txt(cursor)) : total = nextOffset + 1
                response.data = {items:items,offset:val(offset),total:total,next_offset:nextOffset}
            end if
        end if
    end if
    return response
end function

function EngineLibraryCard(item as dynamic) as dynamic
    if not AccountIsObject(item) or Txt(item.id) = "" or Txt(item.name) = "" then return invalid
    if item.type <> "movie" and item.type <> "series" then return invalid
    if AccountIsObject(item.engine_card) then return item.engine_card
    return {identity:{id:item.id,kind:item.type,ids:[],episode:invalid,edition:invalid},title:item.name,
        provider_id:"library",category:invalid,metadata:invalid,subtitle:invalid,description:invalid,
        poster:item.poster,landscape:invalid,logo:invalid,progress:invalid,badges:[],parent_identity:invalid,added_at_millis:invalid}
end function

function EngineLibraryToggle(request as object, result as object, prefix as string) as object
    card = EngineLibraryCard(request.body)
    if card = invalid
        result.error = "The selected title identity is incomplete."
        return result
    end if
    saved = false
    if GetInterface(request.body.desired_saved,"ifBoolean") <> invalid
        saved = not request.body.desired_saved
    else
        readRequest = EngineRequestCopy(request) : readRequest.path = "/api/v3/bootstrap" : readRequest.body = invalid
        bootstrap = HttpRequestRaw(readRequest,result,"GET",false)
        if not bootstrap.ok then return bootstrap
        if not AccountIsObject(bootstrap.data) or not AccountIsObject(bootstrap.data.library_membership) or not ApiIsArray(bootstrap.data.library_membership.identities)
            bootstrap.ok = false : bootstrap.error = "Library membership is unavailable."
            return bootstrap
        end if
        for each identity in bootstrap.data.library_membership.identities
            if EngineSameIdentity(identity,card.identity) then saved = true
        end for
    end if
    wire = EngineRequestCopy(request) : wire.path = prefix : wire.body = {card:card} : method = "PUT"
    if saved
        wire.path += "/" + Enc(Txt(card.identity.kind)) + "/" + Enc(Txt(card.identity.id))
        wire.body = invalid : method = "DELETE"
    end if
    response = HttpRequestRaw(wire,{tag:result.tag,ok:false,status:0,error:"",data:invalid},method,false)
    if response.ok
        membership = invalid
        if AccountIsObject(response.data) then membership = response.data.library_membership
        response.data = {ok:true,saved:not saved,library_membership:membership}
    end if
    return response
end function
