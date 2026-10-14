function EngineLiveRequest(request as object, result as object, method as string) as dynamic
    path = Txt(request.path) : route = path.split("?")[0]
    channels = route = "/api/v2/iptv/live/channels"
    categories = route = "/api/v2/iptv/live/categories"
    guide = left(route,19) = "/api/v2/iptv/guide/"
    source = left(route,18) = "/api/v2/iptv/live/" and right(route,7) = "/source"
    if not channels and not categories and not guide and not source then return invalid
    if EngineUrlParameter(path,"collection") <> ""
        result.error = "Saved live channel collections are unavailable."
        return result
    end if
    if Txt(request.last_profile_id) = "" or left(Txt(request.base),8) <> "https://"
        result.error = "Choose a profile on an HTTPS server."
        return result
    end if
    prefix = "/api/v3/profiles/" + Enc(Txt(request.last_profile_id)) + "/live"
    wire = EngineRequestCopy(request)
    offset = 0 : limit = val(EngineUrlParameter(path,"limit"))
    if limit < 1 then limit = 40
    cursor = EngineUrlParameter(path,"cursor")
    if cursor <> ""
        if not CreateObject("roRegex","^[0-9]{1,6}$","").isMatch(cursor)
            result.error = "Reload Live TV to refresh this playlist."
            return result
        end if
        offset = val(cursor)
    end if
    if channels or categories
        readLimit = limit
        readOffset = offset
        if categories then readLimit = 1 : readOffset = 0
        wire.path = prefix+"/channels?limit="+readLimit.toStr()+"&offset="+readOffset.toStr()
        for each pair in [["catalog_id","connection_id"],["category_id","group_id"],["search","search"]]
            value = EngineUrlParameter(path,pair[0])
            if value <> "" then wire.path += "&"+pair[1]+"="+value
        end for
    else if guide
        channel = mid(route,20)
        wire.path = prefix+"/"+channel+"/guide"
    else
        channel = mid(route,19,len(route)-18-7)
        wire.path = prefix+"/"+channel+"/sources"
    end if
    response = HttpRequestRaw(wire,result,method,false)
    if not response.ok then return response
    projected = invalid
    if channels or categories
        projected = EngineLivePage(response.data,offset,limit,categories)
    else if guide
        if AccountIsObject(response.data)
            if Enc(Txt(response.data.channel_id)) = channel then projected = EngineLiveGuide(response.data)
        end if
    else if AccountIsObject(response.data) and ApiIsArray(response.data.streams)
        if response.data.streams.count() > 0
            value = response.data.streams[0]
            safe = AccountIsObject(value) and RokuPlaybackV2Id(value.id)
            for each key in ["url","headers","authorization","integration_key","gateway_key"]
                if AccountIsObject(value) and value.doesExist(key) then safe = false
            end for
            if safe then projected = {source:ApiItem(value)}
        end if
    end if
    response.data = projected
    if projected = invalid
        response.ok = false
        response.error = "The server returned invalid live TV data."
    end if
    return response
end function
