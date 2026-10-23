' Current server contracts. These adapters validate shape; they never rank,
' infer media identity, parse release names, or manufacture presentation data.
function RObject(value as dynamic) as boolean
    return GetInterface(value,"ifAssociativeArray") <> invalid
end function

function RArray(value as dynamic) as object
    if GetInterface(value,"ifArray") <> invalid then return value
    return []
end function

function RGet(value as dynamic, key as string, fallback = invalid as dynamic) as dynamic
    if RObject(value)
        if value[key] <> invalid then return value[key]
    end if
    return fallback
end function

function RText(value as dynamic, fallback = "" as string) as string
    if GetInterface(value,"ifString") <> invalid then return value
    return fallback
end function

function REncode(value as dynamic) as string
    ' Pure UTF-8 encoding: roUrlTransfer cannot be created on the render thread.
    bytes = CreateObject("roByteArray")
    bytes.fromAsciiString(RText(value))
    hex = "0123456789ABCDEF"
    output = ""
    for i = 0 to bytes.count()-1
        b = bytes[i]
        if (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or (b >= 48 and b <= 57) or b = 45 or b = 46 or b = 95 or b = 126
            output += chr(b)
        else
            output += "%"+mid(hex,int(b/16)+1,1)+mid(hex,(b mod 16)+1,1)
        end if
    end for
    return output
end function

function RCard(value as dynamic) as boolean
    if not RObject(value) then return false
    identity = RGet(value,"identity",{})
    if not RObject(identity) then return false
    if value.progress <> invalid
        number = GetInterface(value.progress,"ifInt") <> invalid or GetInterface(value.progress,"ifFloat") <> invalid or GetInterface(value.progress,"ifDouble") <> invalid
        if not number then return false
        if value.progress < 0 or value.progress > 1 then return false
    end if
    return RText(identity.id) <> "" and RText(identity.kind) <> "" and RText(value.title) <> "" and RText(value.provider_id) <> ""
end function

function RCards(value as dynamic) as boolean
    if GetInterface(value,"ifArray") = invalid then return false
    if value.count() > 500 then return false
    for each item in value
        if not RCard(item) then return false
    end for
    return true
end function

function RemoteWireResponse(request as object, result as object) as object
    data = result.data
    route = RText(request.path).split("?")[0]
    valid = RObject(data) or GetInterface(data,"ifArray") <> invalid
    if request.method = "DELETE" and result.status = 204
        result.data = {ok:true}
        return result
    end if
    if route = "/api/bootstrap"
        valid = RObject(data)
        if valid then valid = data.contract_version = 3 and RObject(data.identity) and RObject(data.profile_management)
        if valid and RObject(data.home) then valid = RHomeWire(data.home)
    else if right(route,5) = "/home"
        valid = RHomeWire(data)
    else if route = "/api/discover" or (right(route,8) = "/library" and request.method = "GET")
        valid = RCards(RGet(data,"cards"))
    else if left(route,10) = "/api/meta/"
        valid = RCard(RGet(data,"item")) and RCards(RGet(data,"episodes"))
    else if route = "/api/search"
        valid = GetInterface(RGet(data,"rows"),"ifArray") <> invalid
        if valid
            for each row in data.rows
                if not RCards(RGet(row,"cards")) then valid = false
            end for
        end if
    else if right(route,8) = "/history" and request.method = "GET"
        valid = GetInterface(data,"ifArray") <> invalid
        if valid
            for each entry in data
                if not RCard(RGet(entry,"card")) then valid = false
            end for
        end if
    else if right(route,15) = "/source-ranking"
        valid = GetInterface(RGet(data,"streams"),"ifArray") <> invalid
        if valid
            if data.streams.count() > 500 then valid = false
            for each source in data.streams
                if RText(RGet(source,"id")) = "" then valid = false
            end for
        end if
    else if route = "/api/streams" and request.method = "POST"
        valid = RText(RGet(data,"id")) <> ""
    else if left(route,13) = "/api/streams/" and request.method = "GET"
        valid = GetInterface(RGet(data,"events"),"ifArray") <> invalid and GetInterface(RGet(data,"done"),"ifBoolean") <> invalid
    else if right(route,15) = "/viewing-action"
        valid = RCard(RGet(data,"card")) and GetInterface(RGet(data,"resume"),"ifBoolean") <> invalid
    end if
    if not valid
        result.ok = false
        result.data = invalid
        result.error = "This server needs an update to support this Roku app."
        result.contract_error = true
    end if
    return result
end function

function RHomeWire(data as dynamic) as boolean
    if not RObject(data) then return false
    if not RObject(data.scope) or GetInterface(data.rows,"ifArray") = invalid then return false
    if data.rows.count() > 128 then return false
    for each row in data.rows
        if not RObject(row) or not RCards(RGet(row,"cards")) then return false
        shape = RGet(RGet(row,"view",{}),"card_shape")
        if shape <> "landscape" and shape <> "poster" then return false
    end for
    return true
end function

function RIdentityKey(card as object) as string
    ' Exact wire identity including metadata origin; no ID parsing or fallback.
    return FormatJson({identity:card.identity,metadata_origin:card.metadata_origin})
end function

function RMetadataFields(card as object) as object
    body = {}
    if card.metadata_origin <> invalid
        body.metadata_origin = card.metadata_origin
        body.card = card
    else
        body.metadata_provider_id = card.provider_id
    end if
    return body
end function

function RPlaybackFacts(caps as object) as object
    codecs = []
    audio = []
    if caps.h264 = true then codecs.push("h264")
    if caps.hevc = true then codecs.push("hevc")
    if caps.aac = true then audio.push("aac")
    return {platform:"roku",can_play_direct:false,max_width:caps.max_width,max_height:caps.max_height,video_codecs:codecs,audio_codecs:audio}
end function

function RGateway(value as dynamic) as boolean
    if not RObject(value) then return false
    if RText(value.id) = "" or value.status <> "ready" then return false
    d = value.delivery
    if not RObject(d) then return false
    if d.kind <> "gateway" or (d.format <> "hls" and d.format <> "mp4") then return false
    if left(RText(d.url),8) <> "https://" then return false
    if RObject(d.headers) and d.headers.count() > 0 then return false
    if GetInterface(d.position,"ifFloat") = invalid and GetInterface(d.position,"ifInt") = invalid and GetInterface(d.position,"ifDouble") = invalid then return false
    return d.position >= 0
end function

function ROrigin(value as dynamic) as string
    value = RText(value).trim()
    if right(value,1) = "/" then value = left(value,len(value)-1)
    pattern = CreateObject("roRegex","^https://([a-z0-9]([a-z0-9.-]*[a-z0-9])?|\[[0-9a-f:]+\])(:[0-9]{1,5})?$","i")
    if not pattern.isMatch(value) then return ""
    return value
end function
