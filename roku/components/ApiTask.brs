sub init()
    m.top.functionName = "RunRequest"
end sub

' One request per RUN. Caller resets cancel=false before reuse; cancel=true
' cooperatively aborts within 100ms. STOP bypasses result delivery/cleanup.
sub RunRequest()
    request = m.top.request
    result = { tag: invalid, ok: false, data: invalid, error: "", status: 0 }
    if request = invalid
        result.error = "Missing request"
    else
        result.tag = request.tag
        if m.top.cancel
            result.error = "Cancelled"
        else
            method = UCase(Txt(request.method, "GET"))
            if method = "CONFIG_LOAD" or method = "CONFIG_SAVE"
                result = ConfigRequest(request, result, method)
            else
                result = HttpRequest(request, result, method)
            end if
        end if
    end if
    m.top.result = result
end sub

function ConfigRequest(request as object, result as object, method as string) as object
    registry = CreateObject("roRegistrySection", "VIPTV")
    packaged = PackagedConnection()
    if method = "CONFIG_SAVE"
        body = request.body
        if GetInterface(body, "ifAssociativeArray") = invalid
            result.error = "Configuration body must be an object"
            return result
        end if
        document = LockedConnection(body, packaged)
        if document.base = ""
            result.error = "Server must be an HTTP or HTTPS origin (no path)"
            return result
        end if
        saved = registry.Write("config", FormatJson(document))
        ' Retire all split static-key fields during the first account-only save.
        registry.Delete("token")
        registry.Delete("profile")
        registry.Delete("server")
        saved = registry.Flush() and saved
        if not saved
            result.error = "Could not save configuration"
            return result
        end if
    end if
    document = invalid
    stored = registry.Read("config")
    if stored <> "" then document = ParseJson(stored)
    if GetInterface(document, "ifAssociativeArray") = invalid
        ' Migrate only the old origin. A static registry token is deliberately ignored.
        document = {base:registry.Read("server"),last_profile_id:""}
    end if
    ' Remove split credential/profile values even if the user cancels pairing.
    registry.Delete("token")
    registry.Delete("profile")
    registry.Flush()
    result.data = LockedConnection(document, packaged)
    result.data.capabilities = DeviceCapabilities()
    result.ok = true
    return result
end function

' Optional private assembly input contains an origin only. Never log parser failures.
function PackagedConnection() as dynamic
    fs = CreateObject("roFileSystem")
    path = "pkg:/data/connection.json"
    info = fs.Stat(path)
    if info = invalid or info.size = invalid then return invalid
    if info.size <= 0 or info.size > 4096 then return invalid
    return ParsePackagedConnection(ReadAsciiFile(path))
end function

function ParsePackagedConnection(text as string) as dynamic
    if len(text) = 0 or len(text) > 4096 then return invalid
    q = chr(34)
    strPattern = q + "(?:[^" + q + "\\\x00-\x1f]|\\(?:[" + q + "\\/bfnrt]|u[0-9a-fA-F]{4}))*" + q
    shape = CreateObject("roRegex", "^\s*\{\s*" + q + "base" + q + "\s*:\s*" + strPattern + "\s*\}\s*$", "")
    if not shape.IsMatch(text) then return invalid
    value = ParseJson(text)
    if GetInterface(value, "ifAssociativeArray") = invalid or GetInterface(value.base,"ifString") = invalid then return invalid
    base = ApiOrigin(Txt(value.base).Trim())
    if base = "" then return invalid
    return {base:base}
end function

function LockedConnection(document as object, packaged as dynamic) as object
    requestedBase = ApiOrigin(Txt(document.base,Txt(document.server)).trim())
    base = requestedBase
    locked = false
    if packaged <> invalid
        base = packaged.base
        locked = true
    end if
    result = {base:base,access_token:"",refresh_token:"",account_id:"",last_profile_id:"",auth_version:3,locked:locked}
    if base = "" then return result
    sameOrigin = Txt(document.auth_origin) = base
    version = document.auth_version
    if sameOrigin and (version = 3 or version = 2)
        ' v2 stored paired access in `token`; import it only with its rotating refresh proof.
        refresh = Txt(document.refresh_token)
        access = Txt(document.access_token)
        if access = "" and refresh <> "" and version = 2 then access = Txt(document.token)
        if CreateObject("roRegex","^[!-~]{1,4096}$","").isMatch(access) and CreateObject("roRegex","^[!-~]{1,4096}$","").isMatch(refresh)
            result.access_token = access
            result.refresh_token = refresh
            result.account_id = left(Txt(document.account_id),128)
            remembered = Txt(document.last_profile_id)
            if remembered = "" and version = 2 then remembered = Txt(document.profile)
            result.last_profile_id = left(remembered,128)
            result.auth_origin = base
            result.expires_at = document.expires_at
        end if
    end if
    return result
end function

function DeviceCapabilities() as object
    caps = {max_width:1280,max_height:720,h264:true,hevc:false,aac:true,direct_play:false,hevc_sdr:false}
    device = CreateObject("roDeviceInfo")
    decoded = device.CanDecodeVideo({codec:"mpeg4 avc",profile:"high",level:"4.1",container:"hls"})
    fileDecoded = device.CanDecodeVideo({codec:"mpeg4 avc",profile:"high",level:"4.1",container:"mp4"})
    audio = device.CanDecodeAudio({codec:"aac"})
    if GetInterface(decoded,"ifAssociativeArray") <> invalid
        if decoded.result = true
            mode = lcase(device.GetVideoMode())
            if instr(1,mode,"1080") > 0 or instr(1,mode,"2160") > 0
                caps.max_width = 1920
                caps.max_height = 1080
            end if
            if GetInterface(fileDecoded,"ifAssociativeArray") <> invalid and GetInterface(audio,"ifAssociativeArray") <> invalid
                caps.direct_play = fileDecoded.result = true and audio.result = true
            end if
            hevc = device.CanDecodeVideo({codec:"hevc",profile:"main",level:"5.0",container:"hls"})
            hevcFile = device.CanDecodeVideo({codec:"hevc",profile:"main",level:"5.0",container:"mp4"})
            if GetInterface(hevc,"ifAssociativeArray") <> invalid and GetInterface(hevcFile,"ifAssociativeArray") <> invalid
                caps.hevc = hevc.result = true and hevcFile.result = true
                caps.hevc_sdr = caps.hevc
                if caps.hevc and instr(1,mode,"2160") > 0
                    caps.max_width = 3840
                    caps.max_height = 2160
                end if
            end if
        end if
    end if
    return caps
end function

function HttpRequest(request as object, result as object, method as string) as object
    ' API servers are origins only; /api paths never inherit a proxy mount.
    ' Never attach the server credential to an absolute URL supplied by a caller.
    path = Txt(request.path)
    origin = ApiOrigin(Txt(request.base))
    if origin = "" or (Left(path, 5) <> "/api/" and Left(path, 5) <> "/api?")
        result.error = "Invalid API origin or path"
        return result
    end if
    unsafePath = CreateObject("roRegex", "[\x00-\x20\\#]", "")
    if unsafePath.IsMatch(path)
        result.error = "Invalid API path"
        return result
    end if
    url = origin + path
    if method <> "GET" and method <> "POST" and method <> "PUT" and method <> "DELETE" and method <> "PATCH"
        result.error = "Unsupported HTTP method"
        return result
    end if
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.EnablePeerVerification(true)
    transfer.EnableHostVerification(true)
    transfer.RetainBodyOnError(true)
    transfer.SetUrl(url)
    transfer.AddHeader("User-Agent", "VIPTV-Roku/" + InstalledAppVersion())
    transfer.AddHeader("Accept", "application/json")
    transfer.AddHeader("Content-Type", "application/json")
    accessToken = Txt(request.access_token)
    if Instr(1, accessToken, Chr(10)) > 0 or Instr(1, accessToken, Chr(13)) > 0
        result.error = "Invalid account credential"
        return result
    end if
    if accessToken <> "" then transfer.AddHeader("Authorization", "Bearer " + accessToken)
    transfer.SetRequest(method)
    ' Large GETs are file-backed; disk can overshoot between 100ms checks.
    ' Mutation replies use the native string API (small IDs/acknowledgments).
    ' All replies are capped before JSON parsing, not before transient allocation.
    fs = CreateObject("roFileSystem")
    stem = ApiResponseStem(request, transfer.GetIdentity())
    responseFile = stem + ".response"
    requestFile = stem + ".request"
    maxBytes = 2097152
    timer = CreateObject("roTimespan")
    timer.Mark()
    deadline = 20000
    if method = "GET" and Left(request.path,13) = "/api/discover" then deadline = 35000
    if method = "POST" and request.path = "/api/playback"
        deadline = 70000
        if MatchInteger(request.timeout_ms,1,70000) then deadline = request.timeout_ms
    end if
    if method = "GET"
        started = transfer.AsyncGetToFile(responseFile)
    else
        payload = ""
        if request.body <> invalid
            body = request.body
            if path = "/api/playback" and method = "POST"
                ' Audio output/private listening may change between plays.
                body = {}
                body.append(request.body)
                body.capabilities = DeviceCapabilities()
            end if
            payload = FormatJson(body)
        end if
        bytes = CreateObject("roByteArray")
        bytes.FromAsciiString(payload)
        if bytes.Count() > maxBytes
            result.error = "Request exceeds 2 MiB"
            return result
        end if
        started = transfer.AsyncPostFromString(payload)
    end if
    if not started
        result.error = "Could not start HTTP request"
    else
        while true
            if m.top.cancel
                result.error = "Cancelled"
                exit while
            end if
            if timer.TotalMilliseconds() >= deadline
                result.error = "Request timed out"
                exit while
            end if
            info = fs.Stat(responseFile)
            if info <> invalid and ApiIsNumber(info.size)
                if info.size > maxBytes
                    result.error = "Response exceeds 2 MiB"
                    exit while
                end if
            end if
            event = wait(100, port)
            if type(event) = "roUrlEvent"
                if event.GetSourceIdentity() = transfer.GetIdentity()
                    result.status = event.GetResponseCode()
                    if m.top.cancel
                        result.error = "Cancelled"
                    else if timer.TotalMilliseconds() >= deadline
                        result.error = "Request timed out"
                    else
                        if method <> "GET"
                            reply = event.GetString()
                            bytes = CreateObject("roByteArray")
                            bytes.FromAsciiString(reply)
                            if bytes.count() > maxBytes
                                result.error = "Response exceeds 2 MiB"
                                exit while
                            end if
                            if not WriteAsciiFile(responseFile, reply)
                                result.error = "Could not stage response"
                                exit while
                            end if
                        end if
                        result = ReadResponse(responseFile, result, maxBytes)
                        if result.ok
                            clean = SanitizeApiResponse(path, method, result.data)
                            result.ok = clean.ok
                            result.data = clean.data
                            if not clean.ok then result.error = "Unexpected API response"
                        end if
                    end if
                    exit while
                end if
            end if
        end while
    end if
    transfer.AsyncCancel()
    fs.Delete(responseFile)
    fs.Delete(requestFile)
    return result
end function

' Caller sequence isolates concurrent Task files even when native/simulator
' transfer identities are reused across threads. Never put paths/tokens in names.
function ApiResponseStem(request as object, identity as integer) as string
    key = Txt(request.request_id)
    safe = CreateObject("roRegex", "^[0-9]+-[0-9]+$", "")
    if len(key) > 40 or not safe.isMatch(key) then key = "legacy"
    return "tmp:/viptv-api-" + key + "-" + identity.toStr()
end function

function ReadResponse(path as string, result as object, maxBytes as integer) as object
    if result.status <= 0
        result.error = "Network request failed (" + result.status.ToStr() + ")"
        return result
    end if
    if result.status >= 400
        info = CreateObject("roFileSystem").Stat(path)
        if info <> invalid
            if ApiIsNumber(info.size) and info.size <= 4096 then result.auth_code = AccountErrorCode(ReadAsciiFile(path))
        end if
    end if
    if result.status = 422
        result.error = "HTTP 422"
        info = CreateObject("roFileSystem").Stat(path)
        if info <> invalid and ApiIsNumber(info.size) and info.size <= 4096
            text = LCase(ReadAsciiFile(path))
            for each field in ["max_width","max_height","position","force_transcode","stream_id","channel_id","audio_track_index","subtitle_track_index","subtitles_off"]
                if Instr(1,text,field) > 0 then result.error += " " + field
            end for
            for each kind in ["floating point","string","integer","boolean","null"]
                if Instr(1,text,kind) > 0 then result.error += " " + kind
            end for
        end if
        return result
    end if
    if result.status = 400
        result.error = "HTTP 400"
        fs = CreateObject("roFileSystem")
        info = fs.Stat(path)
        if info <> invalid
            if ApiIsNumber(info.size)
                if info.size <= maxBytes and info.size <= 4096
                    text = ReadAsciiFile(path)
                    if ApiSourceExpired(text) then result.sourceExpired = true
                end if
            end if
        end if
        return result
    end if
    if result.status < 200 or result.status >= 300
        result.error = "HTTP " + result.status.ToStr()
        return result
    end if
    fs = CreateObject("roFileSystem")
    info = fs.Stat(path)
    if info = invalid or not ApiIsNumber(info.size)
        result.error = "Missing response body"
        return result
    end if
    if info.size > maxBytes
        result.error = "Response exceeds 2 MiB"
        return result
    end if
    text = ReadAsciiFile(path)
    success = result.status >= 200 and result.status < 300
    if text.Trim() = ""
        if success
            result.ok = true
        else
            result.error = "HTTP " + result.status.ToStr()
        end if
        return result
    end if
    data = ParseJson(text)
    if not success
        result.error = "HTTP " + result.status.ToStr()
    else if data = invalid and text.Trim() <> "null"
        result.error = "Invalid JSON response"
    else
        result.ok = true
        result.data = data
    end if
    return result
end function

function ApiSourceExpired(text as string) as boolean
    ' Rust Axum ApiError is {"error":...}, not a FastAPI detail envelope.
    ' Recognize only the exact safe JSON shape. ParseJSON can log malformed raw bodies.
    if len(text) > 4096 then return false
    if m.sourceExpiredPattern = invalid
        quote = chr(34)
        ws = "[ \t\r\n]*"
        pattern = "^" + ws + "\{" + ws + quote + "error" + quote + ws + ":" + ws + quote + "Stream expired; discover again" + quote + ws + "\}" + ws + "$"
        m.sourceExpiredPattern = CreateObject("roRegex",pattern,"")
    end if
    return m.sourceExpiredPattern.isMatch(text)
end function

function ApiOrigin(value as string) as string
    origin = value.Trim()
    pattern = CreateObject("roRegex", "^https?://(\[[0-9a-f:.]+\]|[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?)(:[0-9]{1,5})?/?$", "i")
    if not pattern.IsMatch(origin) then return ""
    if Instr(1, origin, "..") > 0 then return ""
    if Right(origin, 1) = "/" then origin = Left(origin, Len(origin) - 1)
    portPattern = CreateObject("roRegex", ":([0-9]+)$", "")
    portMatch = portPattern.Match(origin)
    if portMatch.Count() > 1
        portNumber = Val(portMatch[1])
        if portNumber < 1 or portNumber > 65535 then return ""
    end if
    return origin
end function

function ApiIsObject(value as dynamic) as boolean
    return GetInterface(value, "ifAssociativeArray") <> invalid
end function

function ApiIsArray(value as dynamic) as boolean
    return GetInterface(value, "ifArray") <> invalid
end function

function ApiIsNumber(value as dynamic) as boolean
    return GetInterface(value, "ifInt") <> invalid or GetInterface(value, "ifLongInt") <> invalid or GetInterface(value, "ifFloat") <> invalid or GetInterface(value, "ifDouble") <> invalid
end function

' Whitelist shallow primitives: never forward arbitrary nested addon payloads.
' Optional bad numeric fields are omitted; display strings always have safe types.
function ApiItem(value as object) as object
    output = { id: "", name: "", title: "", type: "" }
    for each key in ["id", "channel_id", "stream_id", "addon_id", "epg_channel_id", "name", "title", "type", "source", "addon_name", "category", "format", "mode", "status", "version", "language", "quality", "codec", "language_status", "audio_language_status", "video_mode", "audio_mode", "display_time", "display_date", "section", "network"]
        if value.DoesExist(key) then output[key] = Left(Txt(value[key]), 512)
    end for
    if ApiIsObject(value.now) then output.now = {title:Left(Txt(value.now.title),512),start:value.now.start,end:value.now.end}
    output.append(MatchingContext(value))
    for each key in ["source_addon_id","source_name","source_fingerprint","source_binge_group","source_release_group","source_quality","source_audio","audio_language","queue_status","queue_title_id"]
        if value.DoesExist(key) then output[key] = Left(Txt(value[key]),256)
    end for
    if value.DoesExist("title") then output.title = Left(Txt(value.title),4000)
    if output.name = "" then output.name = output.title
    if value.DoesExist("description") then output.description = Left(Txt(value.description), 4000)
    if value.DoesExist("filename") then output.filename = Left(Txt(value.filename), 512)
    if ApiIsArray(value.reported_languages)
        output.reported_languages = []
        for each language in value.reported_languages
            if output.reported_languages.Count() >= 16 then exit for
            text = Left(Txt(language), 32)
            if text <> "" then output.reported_languages.Push(text)
        end for
    end if
    if ApiIsNumber(value.size_bytes)
        if value.size_bytes > 0 and value.size_bytes <= 1125899906842624# then output.size_bytes = value.size_bytes
    end if
    ' Keep the bounded presentation fields needed by catalogs and episode cards.
    for each key in ["runtime","released","overview","episodeTitle","seriesName","posterShape","imdbRating"]
        if value.DoesExist(key) then output[key] = Left(Txt(value[key]),4000)
    end for
    for each field in ["director","cast"]
        if ApiIsArray(value[field])
            output[field] = []
            for each entry in Bounded(value[field],8)
                if GetInterface(entry,"ifString") <> invalid then output[field].push(left(entry,128))
            end for
        else if GetInterface(value[field],"ifString") <> invalid
            output[field] = left(value[field],512)
        end if
    end for
    if ApiIsArray(value.genres)
        output.genres = []
        for each entry in Bounded(value.genres,256)
            if GetInterface(entry,"ifString") <> invalid then output.genres.push(left(entry,256))
        end for
    end if
    for each key in ["supports_search","supports_skip","enabled","shouldIncludeVideos","watched"]
        if GetInterface(value[key],"ifBoolean") <> invalid then output[key] = value[key]
    end for
    if ApiIsArray(value.extra)
        output.extra = []
        for each extra in Bounded(value.extra,32)
            if ApiIsObject(extra)
                field = {name:left(Txt(extra.name),64),required:extra.is_required = true or extra.required = true,default:Txt(extra.default),options:[]}
                for each option in Bounded(extra.options,256)
                    if GetInterface(option,"ifString") <> invalid then field.options.push(left(option,256))
                end for
                output.extra.push(field)
            end if
        end for
    end if
    for each key in ["url", "poster", "logo", "background", "backdrop", "thumbnail", "image", "manifest_url"]
        if value.DoesExist(key) then output[key] = Left(Txt(value[key]), 4096)
    end for
    for each key in ["generation", "position", "duration", "original_duration", "updated_at", "start", "end", "seq", "total", "providers", "addons", "profiles", "active_sessions", "count", "input_index", "output_index"]
        number = value[key]
        if ApiIsNumber(number)
            if number >= 0 and number <= 100000000000 then output[key] = number
        end if
    end for
    for each key in ["ok", "done", "managed_live", "enabled", "ffmpeg_available", "live", "selected", "supported", "selectable", "subtitles_supported"]
        if GetInterface(value[key], "ifBoolean") <> invalid then output[key] = value[key]
    end for
    ' Provider error strings can include upstream credential-bearing URLs.
    if value.error <> invalid then output.error = "Source unavailable"
    return output
end function

function ApiItems(values as object, limit as integer) as object
    output = []
    for each value in values
        if output.Count() >= limit then exit for
        if ApiIsObject(value) then output.Push(ApiItem(value))
    end for
    return output
end function

' Validation is done in the Task before the assocarray crosses into rendering.
' A missing required envelope is a failure, never a misleading empty catalog.
function SanitizeApiResponse(path as string, method as string, data as dynamic) as object
    failure = { ok: false, data: invalid }
    route = path
    queryAt = Instr(1, route, "?")
    if queryAt > 0 then route = Left(route, queryAt - 1)
    if route = "/api/parent/unlock" then return AccountWire(route,data)
    if left(route,10) = "/api/auth/" or left(route,12) = "/api/device/" then return AccountWire(route,data)
    if route = "/api/profiles" and method = "GET"
        values = data
        if ApiIsObject(data)
            if not ApiIsArray(data.profiles) then return failure
            values = data.profiles
        end if
        if not ApiIsArray(values) then return failure
        return {ok:true,data:AccountProfileRows(values,false)}
    end if
    if right(route,12) = "/preferences" then return ProfilePreferencesWire(data)
    if instr(1,route,"/continue/") > 0
        if not ApiIsObject(data) then return failure
        if right(route,5) = "/page"
            if not ApiIsArray(data.items) or not ApiIsNumber(data.offset) then return failure
            output = {items:ApiItems(data.items,100),offset:data.offset,total:data.total,next_offset:invalid}
            if ApiIsNumber(data.next_offset) then output.next_offset = data.next_offset
            return {ok:true,data:output}
        else if right(route,5) = "/next"
            output = {status:Txt(data.status)}
            if ApiIsObject(data.item) then output.item = ApiItem(data.item)
            return {ok:true,data:output}
        else if right(route,9) = "/settings"
            if GetInterface(data.autoplay,"ifBoolean") = invalid then return failure
            return {ok:true,data:{autoplay:data.autoplay}}
        end if
    end if
    if right(route,15) = "/favorites/page" or right(route,14) = "/progress/page"
        if not ApiIsObject(data) then return failure
        if not ApiIsArray(data.items) or not ApiIsNumber(data.offset) then return failure
        output = {items:ApiItems(data.items,100),offset:data.offset,total:data.total,next_offset:invalid}
        if ApiIsNumber(data.next_offset) then output.next_offset = data.next_offset
        return {ok:true,data:output}
    end if
    if right(route,17) = "/favorites/toggle"
        if not ApiIsObject(data) then return failure
        if GetInterface(data.saved,"ifBoolean") = invalid then return failure
        return {ok:true,data:{saved:data.saved}}
    end if
    if right(route,16) = "/progress/series" and method = "GET"
        if not ApiIsArray(data) then return failure
        return {ok:true,data:ApiItems(data,2000)}
    end if
    collection = CreateObject("roRegex", "^/api/profiles/[^/]+/(favorites|progress|continue)$", "")
    arrayRoute = route = "/api/catalogs" or route = "/api/providers" or route = "/api/addons" or route = "/api/matches" or collection.IsMatch(route)
    if method = "GET" and arrayRoute
        if not ApiIsArray(data) then return failure
        limit = 500
        if route = "/api/catalogs" then limit = 2048
        return { ok: true, data: ApiItems(data, limit) }
    end if
    ' DELETE/heartbeat/mutation endpoints may legitimately return HTTP 204.
    if data = invalid
        if method = "DELETE" then return { ok: true, data: {} }
        return failure
    end if
    if not ApiIsObject(data) then return failure
    output = ApiItem(data)
    if route = "/api/discover"
        if not ApiIsArray(data.metas) then return failure
        output = { metas: ApiItems(data.metas, 200), has_more:false, aggregated:false }
        if GetInterface(data.has_more,"ifBoolean") <> invalid then output.has_more = data.has_more
        if GetInterface(data.aggregated,"ifBoolean") <> invalid then output.aggregated = data.aggregated
        if ApiIsNumber(data.next_skip)
            if data.next_skip >= 0 and data.next_skip <= 10000 then output.next_skip = data.next_skip
        end if
        if ApiIsNumber(data.max_catalogs) then output.max_catalogs = data.max_catalogs
        if ApiIsNumber(data.max_results) then output.max_results = data.max_results
    else if route = "/api/live/categories"
        if not ApiIsArray(data.categories) or not ApiIsNumber(data.total) then return failure
        if data.total < 0 then return failure
        output = {categories:ApiItems(data.categories,100),total:data.total}
    else if route = "/api/live"
        if not ApiIsArray(data.channels) or not ApiIsNumber(data.total) then return failure
        if data.total < 0 then return failure
        output = { channels: ApiItems(data.channels, 100), total: data.total }
    else if Left(route, 11) = "/api/guide/"
        if not ApiIsArray(data.programs) then return failure
        programs = []
        for each program in data.programs
            if programs.Count() >= 100 then exit for
            if ApiIsObject(program)
                if ApiIsNumber(program.start) and ApiIsNumber(program.end)
                    if program.start >= 0 and program.start <= 2147483647 and program.end >= program.start and program.end <= 2147483647 then programs.Push(ApiItem(program))
                end if
            end if
        end for
        output = { programs: programs, timezone: Left(Txt(data.timezone),64), timeline: [] }
        if ApiIsArray(data.timeline) then output.timeline = ApiItems(data.timeline,54)
    else if Left(route, 10) = "/api/meta/"
        if not ApiIsObject(data.meta) then return failure
        meta = ApiItem(data.meta)
        if meta.id = "" or (meta.type <> "movie" and meta.type <> "series" and meta.type <> "live") then return failure
        meta.videos = []
        if data.meta.videos <> invalid
            if not ApiIsArray(data.meta.videos) then return failure
            meta.videos = ApiItems(data.meta.videos, 2000)
        end if
        output = { meta: meta }
    else if route = "/api/streams" and method = "POST"
        if output.id = "" then return failure
        output = { id: output.id }
    else if Left(route, 13) = "/api/streams/" and method = "GET"
        if not ApiIsArray(data.events) or GetInterface(data.done, "ifBoolean") = invalid then return failure
        events = []
        for each entry in data.events
            if events.Count() >= 100 then exit for
            if ApiIsObject(entry)
                if not ApiIsNumber(entry.seq) or not ApiIsArray(entry.streams) then return failure
                if entry.seq < 0 or entry.seq > 2147483647 then return failure
                cleaned = ApiItem(entry)
                candidates = ApiItems(entry.streams, 1000)
                for each candidate in candidates
                    if Txt(candidate.source) = "" then candidate.source = Txt(cleaned.source,"unknown")
                end for
                ' Preserve every bounded candidate and its reported language metadata.
                ' Render-thread policy performs fair ordering without silently losing
                ' entire providers or unknown/non-English status in the Task boundary.
                cleaned.streams = candidates
                events.Push(cleaned)
            end if
        end for
        output = { events: events, done: data.done }
    else if route = "/api/playback" and method = "POST"
        if data.managed_live = true
            if not MatchInteger(data.generation,1,1000) or Txt(data.channel_id) = "" then return failure
        end if
        if output.id = "" or Txt(output.url) = "" or not ApiIsNumber(data.position) then return failure
        if data.position < 0 or data.position > 604800 then return failure
        if output.format <> "hls" and output.format <> "mp4" then return failure
        if output.mode <> "direct" and output.mode <> "remux" and output.mode <> "transcode" then return failure
        preferences = ProfilePreferencesWire(data.preferences)
        if preferences.ok then output.preferences = preferences.data
        output.audio_tracks = []
        output.subtitle_tracks = []
        if ApiIsArray(data.audio_tracks) then output.audio_tracks = ApiItems(data.audio_tracks,32)
        if ApiIsArray(data.subtitle_tracks) then output.subtitle_tracks = ApiItems(data.subtitle_tracks,32)
        if ApiIsObject(data.selected_audio) then output.selected_audio = ApiItem(data.selected_audio)
        if ApiIsObject(data.selected_subtitle) then output.selected_subtitle = ApiItem(data.selected_subtitle)
    else if route = "/api/profiles" and method = "POST"
        profile = AccountProfileRow(data)
        if profile = invalid or profile.name = "" then return failure
        output = profile
    else if CreateObject("roRegex","^/api/profiles/[^/]+$","").IsMatch(route) and method = "PATCH"
        profile = AccountProfileRow(data)
        if profile = invalid or profile.name = "" then return failure
        output = profile
    else if Left(route,14) = "/api/playback/" and method = "POST" and data.managed_live = true
        if data.state <> "playing" and data.state <> "recovering" and data.state <> "failed" then return failure
        if not MatchInteger(data.generation,1,1000) then return failure
        output = {ok:true,managed_live:true,state:data.state,generation:data.generation}
        reason = Txt(data.reason)
        for each allowed in ["recovery_budget_exhausted","recovery_deadline_exceeded","connections_busy","no_playable_backup","media_stalled","input_ended","player_failed"]
            if reason = allowed then output.reason = reason
        end for
        if data.state = "playing"
            if not ApiIsObject(data.playback) then return failure
            playback = SanitizeApiResponse("/api/playback","POST",data.playback)
            if not playback.ok then return failure
            if playback.data.generation <> data.generation then return failure
            output.playback = playback.data
        end if
    else if method = "PUT" or method = "DELETE" or (Left(route, 14) = "/api/playback/" and method = "POST")
        if GetInterface(data.ok, "ifBoolean") = invalid then return failure
        output = { ok: data.ok }
    end if
    return { ok: true, data: output }
end function

function ProfilePreferencesWire(data as dynamic) as object
    if not ApiIsObject(data) then return {ok:false,data:invalid}
    output = {}
    for each key in ["audio_language","subtitle_language","subtitle_size","subtitle_style","quality"]
        value = Txt(data[key])
        if value = "" or len(value) > 16 then return {ok:false,data:invalid}
        output[key] = value
    end for
    for each key in ["subtitles_enabled","autoplay"]
        if GetInterface(data[key],"ifBoolean") = invalid then return {ok:false,data:invalid}
        output[key] = data[key]
    end for
    return {ok:true,data:output}
end function
