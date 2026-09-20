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
