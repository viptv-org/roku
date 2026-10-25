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
        if valid then valid = data.contract_version = 3 and RObject(data.identity) and RObject(data.profile_management) and GetInterface(data.navigation,"ifArray") <> invalid
        if valid and RObject(data.home) then valid = RHomeWire(data.home)
    else if right(route,5) = "/home"
        valid = RHomeWire(data)
    else if right(route,14) = "/live/channels" and request.method = "GET"
        valid = GetInterface(RGet(data,"channels"),"ifArray") <> invalid and GetInterface(RGet(data,"groups"),"ifArray") <> invalid and GetInterface(RGet(data,"connections"),"ifArray") <> invalid
        if valid then valid = GetInterface(RGet(data,"complete"),"ifBoolean") <> invalid and RText(RGet(data,"availability")) <> "" and data.channels.count() <= 200 and RText(RGet(data,"snapshot_id")) <> ""
        if valid then valid = RLivePagingWire(RGet(data,"paging"))
        if valid then valid = data.channels.count() <= data.paging.limit
        if valid
            for each channel in data.channels
                if not RCard(RGet(channel,"card")) or RText(RGet(channel,"id")) = "" or RText(RGet(channel,"connection_id")) = "" then valid = false
            end for
        end if
    else if instr(1,route,"/live/") > 0 and right(route,6) = "/guide" and request.method = "GET"
        valid = RGuideWire(data)
        channel = RText(RGet(request.context,"channel"))
        if valid and channel <> "" then valid = data.channel_id = channel
    else if route = "/api/discover"
        valid = RCards(RGet(data,"cards"))
    else if right(route,8) = "/library" and request.method = "GET"
        valid = RCards(RGet(data,"cards")) and RObject(RGet(data,"query")) and RObject(RGet(data,"default_query"))
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
    else if instr(1,route,"/live/") > 0 and right(route,8) = "/sources" and request.method = "POST"
        action = RGet(data,"action",{})
        valid = GetInterface(RGet(data,"streams"),"ifArray") <> invalid and RCard(RGet(action,"card")) and GetInterface(RGet(action,"resume"),"ifBoolean") <> invalid
        if valid then valid = action.source_selection = "best" or action.source_selection = "ask"
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
    if data.rows.count() > 16 then return false
    for each row in data.rows
        if not RObject(row) or not RCards(RGet(row,"cards")) then return false
        if row.cards.count() > 24 then return false
        state = RText(RGet(row,"state"))
        if state <> "Pending" and state <> "Ready" and state <> "Empty" and state <> "Failed" then return false
        if state = "Failed" and GetInterface(RGet(row,"message"),"ifString") = invalid then return false
        if state <> "Ready" and row.cards.count() > 0 then return false
        shape = RGet(RGet(row,"view",{}),"card_shape")
        if shape <> "landscape" and shape <> "poster" then return false
        for each card in row.cards
            if not RHomePreview(RGet(RGet(card,"view",{}),"preview")) then return false
        end for
    end for
    return true
end function

function RHomePreview(value as dynamic) as boolean
    if not RObject(value) then return false
    for each key in ["background","caption","progress","action"]
        if not value.doesExist(key) then return false
    end for
    if value.action <> "play" and value.action <> "details" then return false
    for each key in ["background","caption"]
        if value[key] <> invalid and GetInterface(value[key],"ifString") = invalid then return false
    end for
    if value.progress <> invalid
        number = GetInterface(value.progress,"ifInt") <> invalid or GetInterface(value.progress,"ifFloat") <> invalid or GetInterface(value.progress,"ifDouble") <> invalid
        if not number then return false
        if value.progress < 0 or value.progress > 1 then return false
    end if
    return true
end function

function RIdentityKey(card as object) as string
    ' Exact wire identity including metadata origin; no ID parsing or fallback.
    return RValueKey({identity:card.identity,metadata_origin:card.metadata_origin})
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
    if RText(value.id) = "" or value.status <> "ready" or not RObject(value.actions) then return false
    d = value.delivery
    if not RObject(d) then return false
    if d.kind <> "gateway" or (d.format <> "hls" and d.format <> "mp4") then return false
    if left(RText(d.url),8) <> "https://" then return false
    if RObject(d.headers) and d.headers.count() > 0 then return false
    if GetInterface(d.position,"ifFloat") = invalid and GetInterface(d.position,"ifInt") = invalid and GetInterface(d.position,"ifDouble") = invalid then return false
    return d.position >= 0
end function

' Ambient artwork for the hero stage. The URI is the server's own image
' descriptor, so the blur is a documented transform of that URL rather than a
' client-built proxy or a provider-host decision.
' This display family ships no font with emoji or CJK coverage: every one of
' them draws tofu, and the Smallest/Largest system font URIs do not exist here at
' all. Rather than paint boxes, drop code points the panel cannot draw and keep
' the readable part of a provider's free-text name.
function RRenderable(value as string) as string
    out = ""
    i = 1
    n = len(value)
    while i <= n
        b = asc(mid(value,i,1))
        if b < 128
            out += chr(b)
            i++
        else
            size = 0
            if b >= 194 and b <= 223 then size = 2
            if b >= 224 and b <= 239 then size = 3
            if b >= 240 and b <= 244 then size = 4
            if size = 0
                i++
            else
                seq = mid(value,i,size)
                ' U+2605 BLACK STAR is the one symbol the bundled font does carry.
                if size = 3 and asc(mid(seq,1,1)) = 226 and asc(mid(seq,2,1)) = 152 and asc(mid(seq,3,1)) = 133
                    out += chr(42)
                end if
                i += size
            end if
        end if
    end while
    ' Removed glyphs leave doubled spaces and dangling separators behind.
    while instr(1,out,"  ") > 0
        out = out.replace("  "," ")
    end while
    out = out.trim()
    while left(out,2) = "· " or left(out,2) = "/ "
        out = mid(out,3).trim()
    end while
    while right(out,2) = " ·" or right(out,2) = " /"
        out = left(out,len(out)-2).trim()
    end while
    return out
end function

function RSoftArt(uri as string) as string
    if uri = "" then return ""
    if left(uri,23) <> "https://wsrv.nl/?" then return ""
    if instr(1,uri,"blur=") > 0 then return uri
    return uri+"&blur=24"
end function

function ROrigin(value as dynamic) as string
    value = RText(value).trim()
    if right(value,1) = "/" then value = left(value,len(value)-1)
    pattern = CreateObject("roRegex","^https://([a-z0-9]([a-z0-9.-]*[a-z0-9])?|\[[0-9a-f:]+\])(:[0-9]{1,5})?$","i")
    if not pattern.isMatch(value) then return ""
    return value
end function

' Snapshot wire values without serializing JSON on the SceneGraph thread.
function RCopy(value as dynamic) as dynamic
    if RObject(value)
        copy = CreateObject("roAssociativeArray")
        copy.setModeCaseSensitive()
        for each key in value
            copy[key] = RCopy(value[key])
        end for
        return copy
    else if GetInterface(value,"ifArray") <> invalid
        copy = []
        for each item in value
            copy.push(RCopy(item))
        end for
        return copy
    end if
    return value
end function

function REqual(a as dynamic,b as dynamic) as boolean
    if a = invalid then return b = invalid
    if b = invalid then return false
    if RObject(a)
        if not RObject(b) then return false
        if a.count() <> b.count() then return false
        for each key in a
            if not b.doesExist(key) then return false
            if not REqual(a[key],b[key]) then return false
        end for
        return true
    end if
    if GetInterface(a,"ifArray") <> invalid
        if GetInterface(b,"ifArray") = invalid then return false
        if a.count() <> b.count() then return false
        for i = 0 to a.count()-1
            if not REqual(a[i],b[i]) then return false
        end for
        return true
    end if
    if RObject(b) or GetInterface(b,"ifArray") <> invalid then return false
    if (GetInterface(a,"ifString") <> invalid) <> (GetInterface(b,"ifString") <> invalid) then return false
    if (GetInterface(a,"ifBoolean") <> invalid) <> (GetInterface(b,"ifBoolean") <> invalid) then return false
    return a = b
end function

function RValueKey(value as dynamic) as string
    if value = invalid then return "n"
    if RObject(value)
        keys = value.keys()
        keys.sort()
        key = "o"+keys.count().toStr()+":"
        for each name in keys
            key += RValueKey(name)+RValueKey(value[name])
        end for
        return key
    end if
    if GetInterface(value,"ifArray") <> invalid
        key = "a"+value.count().toStr()+":"
        for each item in value
            key += RValueKey(item)
        end for
        return key
    end if
    if GetInterface(value,"ifString") <> invalid then return "s"+len(value).toStr()+":"+value
    if GetInterface(value,"ifBoolean") <> invalid
        if value then return "t" else return "f"
    end if
    return "d"+value.toStr()+":"
end function

' Optional query fields are absent in HTTP when the server returns JSON null.
function RQueryFields(value as object) as object
    query = CreateObject("roAssociativeArray")
    query.setModeCaseSensitive()
    for each key in value
        if value[key] <> invalid then query[key] = RCopy(value[key])
    end for
    return query
end function

function RPlaybackAllowed(session as dynamic,action as string) as boolean
    return RGet(RGet(session,"actions",{}),action,false) = true
end function
function RTrackSelectable(track as dynamic) as boolean
    if not RObject(track) then return false
    if RGet(track,"selectable",false) <> true or RGet(track,"supported",true) = false then return false
    index = RGet(track,"input_index")
    if GetInterface(index,"ifInt") = invalid and GetInterface(index,"ifFloat") = invalid and GetInterface(index,"ifDouble") = invalid then return false
    return index >= 0 and index <= 65535 and int(index) = index
end function

function RGuideNumber(value as dynamic) as boolean
    return GetInterface(value,"ifInt") <> invalid or GetInterface(value,"ifFloat") <> invalid or GetInterface(value,"ifDouble") <> invalid or type(value) = "LongInteger" or type(value) = "roLongInteger"
end function

function RGuideWire(data as dynamic) as boolean
    if not RObject(data) then return false
    if RText(data.channel_id) = "" or RText(data.availability) = "" then return false
    if GetInterface(data.programs,"ifArray") = invalid or not RObject(data.view) then return false
    view = data.view
    if not view.doesExist("current_program_id") then return false
    if view.current_program_id <> invalid and GetInterface(view.current_program_id,"ifString") = invalid then return false
    for each field in ["now_millis","window_start_millis","window_end_millis"]
        if not RGuideNumber(view[field]) then return false
        if view[field] < 0 then return false
    end for
    if view.window_end_millis <= view.window_start_millis then return false
    for each program in data.programs
        if not RObject(program) then return false
        if RText(program.id) = "" or GetInterface(program.title,"ifString") = invalid then return false
        if not RGuideNumber(program.start_millis) or not RGuideNumber(program.end_millis) then return false
        if program.start_millis < 0 or program.end_millis < program.start_millis then return false
    end for
    return true
end function

function RGuideWindowMillis(value as double) as longinteger
    bucket& = int(value/1800000#)
    return bucket& * 1800000&
end function

' Current shared producer paging contract; no legacy next_cursor fallback.
function RLivePageSize(value as dynamic) as boolean
    if GetInterface(value,"ifInt") = invalid then return false
    return value >= 1 and value <= 200
end function

function RLiveRequestWire(value as dynamic) as boolean
    if not RObject(value) then return false
    return RText(value.cursor) <> "" and len(RText(value.cursor)) <= 512 and RLivePageSize(value.limit) and RLivePageSize(value.page_size)
end function

function RLivePagingWire(value as dynamic) as boolean
    if not RObject(value) then return false
    if RText(value.origin) = "" or not RLivePageSize(value.limit) or not RLivePageSize(value.page_size) then return false
    if not value.doesExist("previous") or not value.doesExist("next") then return false
    for each direction in ["previous","next"]
        if value[direction] <> invalid
            if not RLiveRequestWire(value[direction]) then return false
        end if
    end for
    return true
end function

function RLiveBoundary(pages as object, direction as string) as dynamic
    if pages.count() = 0 then return invalid
    if direction = "previous" then return RGet(RGet(pages[0],"paging"),"previous")
    if direction = "next" then return RGet(RGet(pages[pages.count()-1],"paging"),"next")
    return invalid
end function
